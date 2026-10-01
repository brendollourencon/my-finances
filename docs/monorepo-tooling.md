# Monorepo com pnpm, Turborepo e Husky: o que foi implementado e por quê

Guia de estudo sobre o que existe hoje no repositório (grupo 1 do plano). Cada trecho aponta o arquivo real. Onde a afirmação vem da documentação oficial, há link no fim; o que é conhecimento geral das ferramentas está dito como tal.

## 1. A ideia em uma frase

Um **monorepo** guarda várias apps e bibliotecas no mesmo repositório. O **pnpm** instala as dependências e liga os pacotes entre si. O **Turborepo** decide **em que ordem** rodar as tarefas (build, lint, test) e **evita refazer** o que já foi feito. O **Husky** roda verificações automáticas **antes de cada commit** para que código fora do padrão não entre no repositório.

```
pnpm      → "quem são os pacotes e como se enxergam"   (instalação e links)
Turborepo → "o que rodar, em que ordem, e o que pular" (tarefas e cache)
Husky     → "o que checar antes de aceitar um commit"     (Git hooks)
```

## 2. pnpm

### 2.1 `pnpm-workspace.yaml`: define quem faz parte do monorepo

```yaml
packages:
  - apps/*
  - packages/*
```

Cada pasta dentro de `apps/` e `packages/` que tiver um `package.json` vira um **workspace** (um pacote do monorepo). É daí que vem a convenção do Turborepo: `apps/` para aplicações e `packages/` para bibliotecas e ferramentas.

Hoje existem dois: `packages/tsconfig` e `packages/eslint-config`. As apps (`api`, `web`) e o `contracts` virão no grupo 2.

### 2.2 `package.json` da raiz

| Campo                              | O que faz                                                                                                       |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `"private": true`                  | Impede publicar a raiz no npm por engano.                                                                       |
| `"packageManager": "pnpm@10.33.0"` | Fixa a versão do pnpm. Com `corepack enable`, o Node usa exatamente essa versão (e o CI também).                |
| `"engines": { "node": ">=22" }`    | Avisa se a versão do Node for antiga demais. Quem escolhe a versão é o `.nvmrc`.                                |
| `scripts`                          | Atalhos: `pnpm build` roda `turbo run build`, `pnpm lint` roda `turbo run lint`, etc.                           |
| `"prepare": "husky"`               | O pnpm roda esse script depois do `pnpm install`; ele instala os hooks do Git (veja a seção 4).                 |
| `devDependencies`                  | Ferramentas usadas por todo o repositório: turbo, typescript, eslint, prettier, husky, lint-staged, commitlint. |

O `-w` ou `--workspace-root` em `pnpm add -D -w turbo` significa "instale na **raiz**" (sem isso o pnpm reclama, porque você está num monorepo).

### 2.3 O protocolo `workspace:`

No `package.json` da raiz há:

```json
"@repo/eslint-config": "workspace:*"
```

`workspace:*` diz ao pnpm: "use **o pacote local**, nunca baixe do npm". Se a pasta `packages/eslint-config` não existisse, a instalação falharia, em vez de buscar um pacote com o mesmo nome na internet.

Na prática o pnpm cria um **link simbólico**. Confira no seu disco:

```
node_modules/@repo/eslint-config  →  packages/eslint-config
```

Quando você edita `packages/eslint-config/base.mjs`, a raiz já enxerga a mudança, sem publicar nem copiar nada.

### 2.4 O escopo `@repo/`

O nome do pacote vem do campo `name` do seu `package.json` (`@repo/eslint-config`, `@repo/tsconfig`). O prefixo `@repo/` é só um agrupador (escopo) para diferenciar pacotes internos de pacotes externos. É a convenção usada na documentação do Turborepo e pode ser trocado por outro, como `@my-finances/`.

### 2.5 `pnpm-lock.yaml`

Registra a versão exata de **cada** dependência instalada (inclusive as indiretas). Garante que você, o colega e o CI instalem exatamente o mesmo. Deve ser versionado. O CI usa `pnpm install --frozen-lockfile`, que **falha** se o lock estiver desatualizado, em vez de alterá-lo.

### 2.6 Comandos do dia a dia

```bash
pnpm install                       # instala tudo (e roda "prepare")
pnpm add -D -w <pacote>            # dependência de desenvolvimento na raiz
pnpm --filter @repo/eslint-config add <pacote>   # dependência em um workspace específico
pnpm --filter @repo/eslint-config lint           # roda um script em um workspace
pnpm -r run <script>               # roda em todos os workspaces (sem Turborepo)
```

`--filter` escolhe qual workspace recebe o comando.

### 2.7 Como o pnpm guarda os pacotes (conhecimento geral)

O pnpm mantém um **armazém global** de pacotes e liga cada projeto a ele (por links), em vez de copiar tudo para cada `node_modules`. Em `node_modules/.pnpm/` ficam as versões reais. Por isso é rápido e ocupa pouco disco. Ele também é **estrito**: um pacote só enxerga o que declarou no próprio `package.json` (sem "dependências fantasma").

## 3. Turborepo

### 3.1 `turbo.json`: o grafo de tarefas

```json
{
  "tasks": {
    "build": { "dependsOn": ["^build"], "outputs": ["dist/**", ".nuxt/**", ".output/**"] },
    "lint": { "dependsOn": ["^build"] },
    "typecheck": { "dependsOn": ["^build"] },
    "test": { "dependsOn": ["^build"], "outputs": ["coverage/**"] },
    "dev": { "cache": false, "persistent": true }
  }
}
```

**`dependsOn` com `^`**

- `"^build"` significa: "antes de rodar esta tarefa no pacote X, rode `build` nos pacotes dos quais **X depende**".
- Sem o `^` (ex.: `"build"`), a dependência é uma tarefa **no mesmo pacote**.

Exemplo futuro: `apps/api` depende de `@repo/contracts`. Ao rodar `pnpm build`, o Turborepo faz o build do `contracts` primeiro e só depois o da `api`. Em `lint`, `typecheck` e `test` usamos `^build` porque, para checar o código da `api`, o `contracts` já precisa estar compilado.

**`outputs`**

Lista o que deve ser guardado no cache depois que a tarefa termina bem. **Sem `outputs`, o Turborepo não guarda arquivos**: ele só lembraria "essa tarefa já rodou", sem restaurar o `dist/`. Por isso `build` lista `dist/**` (e as pastas do Nuxt).

**`dev`: `cache: false` e `persistent: true`**

- `cache: false`: o servidor de desenvolvimento nunca deve ser "pulado".
- `persistent: true`: a tarefa nunca termina (fica observando arquivos). O Turborepo sabe disso e não espera por ela.

### 3.2 Como o cache decide pular uma tarefa

O Turborepo calcula uma "impressão digital" (hash) de: arquivos do pacote, dependências, variáveis de ambiente relevantes, a configuração da tarefa e os hashes das tarefas das quais ela depende. Se a impressão digital já foi vista, ele **restaura os `outputs` do cache** e mostra o log gravado, sem executar.

Você viu isso na prática (tarefa 1.3):

```
1ª execução:  Cached: 0 cached, 1 total
2ª execução:  Cached: 1 cached, 1 total   >>> FULL TURBO
```

`FULL TURBO` aparece quando **tudo** veio do cache. O cache local fica em `.turbo/cache` (ignorado pelo Git).

### 3.3 O que acontece quando você roda `pnpm build`

1. `pnpm build` executa o script da raiz: `turbo run build`.
2. O Turborepo lê os pacotes do workspace e monta o **grafo** de dependências entre eles.
3. Aplica as regras do `turbo.json` (`^build` = primeiro os pacotes de que eu dependo).
4. Para cada pacote, calcula o hash. Se há cache, restaura; se não, roda o script `build` daquele pacote.
5. Tarefas independentes rodam **em paralelo**.

Importante: o Turborepo só roda a tarefa em pacotes que **têm** o script com esse nome. Hoje nenhum workspace tem `build`, `test` ou `dev`, por isso esses comandos rodam "0 tarefas" e terminam com sucesso. Só o `lint` faz algo (no `@repo/eslint-config`).

### 3.4 Filtro por pacotes afetados

No CI (que mantemos só localmente), em pull requests usamos `--filter=...[origin/main]`: roda só nos pacotes que **mudaram** em relação à `main` e nos que dependem deles. É o que mantém o CI rápido quando o monorepo cresce.

```bash
pnpm turbo run lint --filter=@repo/eslint-config   # só um pacote
pnpm turbo run build --filter=...[origin/main]     # só afetados
```

## 4. Husky: verificações automáticas no commit

### 4.1 O que é um Git hook

O Git permite rodar um script em momentos fixos (antes do commit, depois do commit, antes do push...). Esses scripts são os **hooks**. Por padrão ficam em `.git/hooks/`, que **não é versionado**: cada pessoa teria que copiá-los à mão. O **Husky** resolve isso guardando os hooks numa pasta versionada (`.husky/`) e configurando o Git para usá-los.

### 4.2 Como foi instalado, passo a passo

1. `pnpm add -D -w husky` coloca o Husky nas `devDependencies` da raiz.
2. O `package.json` tem `"prepare": "husky"`. O pnpm roda o script `prepare` **depois de todo `pnpm install`**.
3. O comando `husky` faz duas coisas:
   - cria a pasta `.husky/_/` com os scripts de cada hook do Git (`pre-commit`, `commit-msg`, `pre-push`...);
   - roda `git config core.hooksPath .husky/_`, dizendo ao Git: "procure os hooks aqui".
4. Nós criamos os hooks que queremos, na pasta `.husky/`:

```sh
# .husky/pre-commit
pnpm exec lint-staged

# .husky/commit-msg
pnpm exec commitlint --edit "$1"
```

Confira no seu repositório: `git config core.hooksPath` responde `.husky/_`.

**Por isso um colega que clona o projeto já recebe os hooks:** ele só precisa rodar `pnpm install`, que dispara o `prepare`.

### 4.3 O que a pasta `.husky/_` tem

São arquivos gerados pelo Husky. Dentro há um `.gitignore` com `*`, então essa subpasta **não é versionada** (só `pre-commit` e `commit-msg` da pasta `.husky/` vão para o Git). Cada hook em `.husky/_/` chama um script comum (`h`) que:

- adiciona `node_modules/.bin` ao `PATH` (por isso `pnpm exec` e os binários locais funcionam);
- executa o seu arquivo de `.husky/` (`sh -e`);
- se o hook falhar, imprime `husky - <hook> script failed (code N)` e devolve o mesmo código ao Git, o que **cancela o commit**;
- respeita `HUSKY=0` (desliga tudo) e `HUSKY=2` (liga `set -x` para depurar).

### 4.4 O que acontece num `git commit`

```
git commit -m "feat: x"
   │
   ├─ 1. pre-commit  →  lint-staged   (olha os arquivos em stage)
   │        falhou? → commit cancelado
   │
   ├─ 2. (você escreve a mensagem)
   │
   ├─ 3. commit-msg  →  commitlint    (olha a mensagem)
   │        falhou? → commit cancelado
   │
   └─ 4. commit criado
```

### 4.5 lint-staged: checar só o que mudou

Rodar o ESLint no projeto inteiro a cada commit seria lento. O **lint-staged** executa comandos **apenas nos arquivos em stage**, conforme `.lintstagedrc.json`:

```json
{
  "*.{js,mjs,cjs,ts,vue}": ["eslint --fix --no-warn-ignored", "prettier --write"],
  "*.{json,md,yml,yaml,css}": "prettier --write"
}
```

- Arquivos de código: ESLint corrige o que pode (`--fix`) e depois o Prettier formata.
- Outros arquivos: só o Prettier.
- Os comandos rodam em ordem; se algum falhar (ex.: erro de lint que não tem correção automática), o commit é cancelado e o erro aparece.
- O lint-staged recoloca em stage os arquivos que os comandos alteraram (você viu `Staging changes from tasks…`).
- `--no-warn-ignored` evita aviso quando um arquivo em stage está no `ignores` do ESLint.

### 4.6 commitlint: padronizar as mensagens

O **commitlint** valida a mensagem contra as regras de `commitlint.config.mjs` (`@commitlint/config-conventional`), o padrão **Conventional Commits**:

```
<tipo>: <descrição>            ex.: feat: cadastra ativo de renda fixa
<tipo>(<escopo>): <descrição>  ex.: fix(auth): corrige renovação de token
```

Tipos comuns (do `config-conventional`, conhecimento geral): `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

Teste que fizemos: a mensagem `ajustes` foi recusada com `type may not be empty`, e `feat: x` foi aceita. Benefícios: histórico legível e possibilidade de gerar changelog e versões automáticas no futuro.

### 4.7 Pular os hooks (e quando não fazer isso)

- `git commit --no-verify`: ignora os hooks só naquele commit.
- `HUSKY=0 git commit ...`: desliga o Husky.

O Husky **não obriga** ninguém: é uma rede de segurança local. Por isso o ideal é que o CI também rode `lint`, `typecheck` e `format:check`, para pegar o que passou sem hooks.

### 4.8 Problemas comuns

| Sintoma                                       | Causa provável                              | O que fazer                                                                |
| --------------------------------------------- | ------------------------------------------- | -------------------------------------------------------------------------- |
| Hooks não rodam                               | `core.hooksPath` não aponta para `.husky/_` | `pnpm install` (ou `pnpm exec husky`); confira `git config core.hooksPath` |
| `command not found` (código 127)              | binário não está instalado                  | `pnpm install`                                                             |
| Hook se comporta de forma estranha no Windows | fim de linha `CRLF` nos arquivos de hook    | o `.gitattributes` força `LF`; reabra/normalize o arquivo                  |
| Quer ver o que o hook executa                 | —                                           | `HUSKY=2 git commit ...` mostra cada comando                               |

Caso real: ao reconfigurar o Git deste projeto (pasta `.git` incompleta), foi preciso rodar `pnpm exec husky` de novo para o `core.hooksPath` voltar.

### 4.9 Ideia para estudar depois: `pre-push`

Dá para criar `.husky/pre-push` com `pnpm typecheck && pnpm test` para impedir `git push` com testes quebrando. Fica mais lento que o `pre-commit`, então costuma-se deixar as checagens pesadas para o push ou para o CI.

## 5. Peças que se apoiam no monorepo

| Arquivo                                       | Função                                                                                                                                              |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `packages/tsconfig`                           | `base.json` (regras estritas), `library.json` (para bibliotecas) e `nest.json` (para a API). Cada app/pacote usa `"extends": "@repo/tsconfig/..."`. |
| `packages/eslint-config`                      | Regras de ESLint em _flat config_ + Prettier. A raiz e os pacotes importam `@repo/eslint-config/base`.                                              |
| `.husky/pre-commit`                           | Antes de cada commit roda `lint-staged`: ESLint e Prettier **só nos arquivos em stage**, conforme `.lintstagedrc.json`.                             |
| `.husky/commit-msg` + `commitlint.config.mjs` | Recusa mensagens fora do padrão **Conventional Commits** (`feat: ...`, `fix: ...`, `chore: ...`).                                                   |
| `.prettierrc.json` / `.prettierignore`        | Formatação única para todos.                                                                                                                        |
| `.editorconfig` / `.gitattributes`            | Fim de linha `LF` e indentação consistentes entre Windows e Linux.                                                                                  |
| `.nvmrc`                                      | Versão do Node (24).                                                                                                                                |
| `infra/docker-compose.yml`                    | MariaDB para desenvolvimento. As apps rodam no host, não em container.                                                                              |

## 6. Decisões e armadilhas encontradas

- **TypeScript fixado em 6.0.** O `pnpm add typescript` instalou o 7.0.2, mas o `typescript-eslint` só aceita versões abaixo de 6.1; por isso o `package.json` usa `^6.0.3`.
- **Sem `build` de mentira.** Para provar o cache usei um script temporário e depois o removi; o `build` real virá com o `@repo/contracts`.
- **Hooks só funcionam depois do `pnpm install`**, porque o script `prepare` é quem configura o Git para usar `.husky/`.
- **Turborepo ignora pacotes sem o script.** É normal ver "0 tasks" enquanto o monorepo está vazio.

## 7. Como explorar sozinho

```bash
pnpm turbo run build --graph        # mostra o grafo de tarefas
pnpm turbo run lint --dry=json      # simula e mostra o que rodaria e os hashes
pnpm turbo run lint --force         # ignora o cache
pnpm why <pacote>                   # por que este pacote está instalado
```

Todos testados na versão instalada (turbo 2.11.5, pnpm 10.33). Em outras versões, confira `pnpm turbo run --help`.

## 8. Fontes oficiais

- Turborepo — estrutura do repositório: https://turborepo.dev/docs/crafting-your-repository/structuring-a-repository
- Turborepo — configuração de tarefas (`dependsOn`, `outputs`, `persistent`): https://turborepo.dev/docs/crafting-your-repository/configuring-tasks
- Turborepo — cache: https://turborepo.dev/docs/crafting-your-repository/caching
- Turborepo — pacotes internos: https://turborepo.dev/docs/crafting-your-repository/creating-an-internal-package
- pnpm — workspaces (`pnpm-workspace.yaml`, `workspace:`, `--filter`): https://pnpm.io/workspaces
- Husky: https://typicode.github.io/husky
- Husky — primeiros passos (`prepare`, `core.hooksPath`, `--no-verify`, `HUSKY=0`): https://typicode.github.io/husky/get-started.html
- lint-staged: https://github.com/lint-staged/lint-staged
- commitlint: https://commitlint.js.org
- Conventional Commits: https://www.conventionalcommits.org/pt-br/v1.0.0/
