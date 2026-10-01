# my-finances

Projeto de estudo: sistema de finanças pessoais (carteira de ativos, saúde financeira, recomendação mensal de aportes) usado para praticar **NestJS**, **Nuxt 4**, **monorepo**, componentização/modularização, auditoria e boas práticas de engenharia.

> Status: fundação do monorepo pronta (workspace, Turborepo, hooks, CI, MariaDB em Docker); apps em construção. O plano completo está em [`openspec/changes/bootstrap-personal-finance-monorepo/`](openspec/changes/bootstrap-personal-finance-monorepo/) (`proposal.md`, `design.md`, `specs/`, `tasks.md`). As apps `api` e `web` ainda não existem.

> Para agentes de IA e outras ferramentas de spec: leia [`AGENTS.md`](AGENTS.md), [`docs/architecture.md`](docs/architecture.md) e [`docs/adr/`](docs/adr/).

## Stack e estrutura

```
apps/
  api/            NestJS (módulos por feature)
  web/            Nuxt 4
packages/
  contracts/      schemas Zod + tipos compartilhados API ↔ Web
  eslint-config/  regras de lint compartilhadas
  tsconfig/       tsconfigs base
infra/            docker-compose, scripts de inicialização do MariaDB
```

Escopo dos pacotes: `@repo/*` (convenção do Turborepo; pode ser trocado por escopo próprio).

## Comandos

Pré-requisitos: Node 24 (`.nvmrc`), pnpm 10 (versão fixada em `packageManager`; use `corepack enable`) e Docker.

```bash
pnpm install        # instala tudo e ativa os hooks do Husky
pnpm infra:up       # sobe o MariaDB (requer .env; veja abaixo)
pnpm dev            # roda as apps em watch via Turborepo
pnpm lint           # ESLint em todos os workspaces
pnpm typecheck      # tsc em todos os workspaces
pnpm test           # testes de todos os workspaces
pnpm build          # build com cache do Turborepo
pnpm format         # Prettier (format:check só verifica)
pnpm infra:down     # para o MariaDB (mantém os dados)
```

`dev`, `typecheck` e `test` passam a ter efeito quando `apps/*` e `packages/contracts` existirem (grupo 2 do plano); hoje rodam sem tarefas.

### Commits e hooks

- **pre-commit:** `lint-staged` roda ESLint e Prettier nos arquivos em stage.
- **commit-msg:** `commitlint` exige [Conventional Commits](https://www.conventionalcommits.org/pt-br/v1.0.0/) (ex.: `feat: cadastra ativo`).
- **CI:** `.github/workflows/ci.yml` roda format, lint, typecheck, test e build (em PRs, só os workspaces afetados).
- TypeScript está fixado em 6.0 porque `typescript-eslint` ainda não aceita 7.x.

## Ambiente local (Docker)

Pré-requisito: Docker com Compose v2.

```bash
cp .env.example .env
pnpm infra:up   # equivale a: docker compose --env-file .env -f infra/docker-compose.yml up -d --wait
```

| Serviço       | URL / porta      | Observação                                |
| ------------- | ---------------- | ----------------------------------------- |
| MariaDB 10.11 | `localhost:3306` | bancos `my_finances` e `my_finances_test` |

Comandos úteis:

```bash
docker compose --env-file .env -f infra/docker-compose.yml logs -f mariadb   # logs
docker compose --env-file .env -f infra/docker-compose.yml down              # parar (mantém dados)
docker compose --env-file .env -f infra/docker-compose.yml down -v           # parar e APAGAR dados
```

- Os scripts de `infra/mariadb/init/` rodam **só na primeira criação do volume**. Para reexecutar: `down -v` e `up` de novo.
- **API e Web** rodam no host, fora do Docker (WebStorm ou `pnpm dev`), com watch/hot reload; o compose sobe só o MariaDB.
- Verificado: o MariaDB sobe saudável e aceita triggers com variável de sessão (base da auditoria automática com o usuário do sistema).

## Fontes oficiais por decisão

Cada item mapeia para uma decisão do [`design.md`](openspec/changes/bootstrap-personal-finance-monorepo/design.md). Leia primeiro a doc oficial; as escolhas de pastas e nomes que não aparecem nelas são **convenções da comunidade**, e estão marcadas.

### D1 — Monorepo, pnpm, Turborepo e qualidade automatizada

- Turborepo — visão geral: https://turborepo.dev/docs
- Estrutura do repositório (`apps/` para aplicações, `packages/` para o resto): https://turborepo.dev/docs/crafting-your-repository/structuring-a-repository
- Pacotes internos (escopo `@repo/`, `package.json`, `src/`, propósito único): https://turborepo.dev/docs/crafting-your-repository/creating-an-internal-package
- Cache de tarefas: https://turborepo.dev/docs/crafting-your-repository/caching
- pnpm workspaces: https://pnpm.io/workspaces
- Husky: https://typicode.github.io/husky
- lint-staged: https://github.com/lint-staged/lint-staged
- commitlint: https://commitlint.js.org
- Conventional Commits: https://www.conventionalcommits.org/pt-br/v1.0.0/
- ESLint (flat config): https://eslint.org/docs/latest/use/configure/configuration-files
- Prettier: https://prettier.io/docs/en/
- GitHub Actions: https://docs.github.com/en/actions
- ADRs (registro de decisões): https://adr.github.io
- _Convenção da comunidade:_ nomes `contracts`, `eslint-config`, `tsconfig` e a pasta `infra/` (a doc dá só a divisão `apps`/`packages`).

### D2 — API NestJS: módulos por feature

- Módulos (feature modules, encapsulamento, `exports`): https://docs.nestjs.com/modules
- Gerador `nest g resource` (estrutura de arquivos): https://docs.nestjs.com/recipes/crud-generator
- Pipes: https://docs.nestjs.com/pipes
- Interceptors: https://docs.nestjs.com/interceptors
- Eventos (`@nestjs/event-emitter`): https://docs.nestjs.com/techniques/events
- Monolith First (Martin Fowler), contexto para "monólito modular": https://martinfowler.com/bliki/MonolithFirst.html
- _Convenção da comunidade:_ pastas `common/`, `config/`, `database/` e arquivos `*.calculator.ts` (escolha do projeto).

### D3 — Persistência (MariaDB + TypeORM)

- NestJS + banco de dados / TypeORM: https://docs.nestjs.com/techniques/database
- TypeORM migrations: https://typeorm.io/docs/migrations/why
- Imagem oficial do MariaDB (variáveis `MARIADB_*`, init scripts, healthcheck): https://hub.docker.com/_/mariadb
- decimal.js (valores monetários sem erro de ponto flutuante): https://mikemcl.github.io/decimal.js/

### D4 — Auditoria

- MariaDB — triggers: https://mariadb.com/kb/en/trigger-overview/ _(não verificado; o site bloqueia requisições automatizadas, abra no navegador)_
- MariaDB — particionamento (`RANGE`, `DROP PARTITION`): https://mariadb.com/kb/en/partitioning-overview/ _(idem)_
- MariaDB — System-Versioned Tables (avaliadas e descartadas, úteis para estudo): https://mariadb.com/kb/en/system-versioned-tables/ _(idem)_
- MariaDB Audit Plugin (auditoria de conexões e queries no servidor): https://mariadb.com/docs/server/reference/plugins/mariadb-audit-plugin/mariadb-audit-plugin-overview
- Debezium — audit logs com CDC: https://debezium.io/blog/2019/10/01/audit-logs-with-change-data-capture-and-stream-processing/
- Comparativo triggers × CDC × event sourcing (artigo, não oficial): https://adhdecode.com/databases/data-modeling-and-schema-design/audit-logging-schema-patterns/
- OWASP Logging Cheat Sheet (o que registrar e o que nunca registrar): https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html
- pino (logs JSON): https://getpino.io

### D5 — Autenticação

- NestJS Authentication (JWT, guards): https://docs.nestjs.com/security/authentication
- Rate limiting (`@nestjs/throttler`): https://docs.nestjs.com/security/rate-limiting
- OWASP Password Storage Cheat Sheet (argon2id): https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html

### D6 — Contratos compartilhados

- Zod: https://zod.dev
- OpenAPI no NestJS (Swagger): https://docs.nestjs.com/openapi/introduction

### D7 — Crawler de dados de mercado

- `@nestjs/schedule` (cron): https://docs.nestjs.com/techniques/task-scheduling
- Robots Exclusion Protocol (RFC 9309): https://www.rfc-editor.org/rfc/rfc9309
- cheerio: https://cheerio.js.org
- Antes de coletar do Investidor10, leia os termos de uso do site; o plano prevê uso pessoal e uma interface `MarketDataProvider` substituível.

### D8 — Recomendação

- Sem fonte oficial: são regras determinísticas definidas pelo projeto (educacional, não é aconselhamento financeiro).

### D9 — Frontend Nuxt 4

- Nuxt Layers: https://nuxt.com/docs/guide/going-further/layers
- Modos de renderização: https://nuxt.com/docs/guide/concepts/rendering
- Vue — componentes: https://vuejs.org/guide/essentials/component-basics.html
- Vue — composables: https://vuejs.org/guide/reusability/composables.html
- Pinia: https://pinia.vuejs.org
- Apache ECharts: https://echarts.apache.org/en/index.html
- Nuxt 4 — estrutura de diretórios (`app/`): https://nuxt.com/docs/4.x/directory-structure
- Nuxt 4 — `components/` (auto-import e nomes por subpasta): https://nuxt.com/docs/4.x/directory-structure/app/components
- Nuxt 4 — `composables/` (escaneia só o nível superior): https://nuxt.com/docs/4.x/directory-structure/app/composables
- _Convenção do projeto (não do Nuxt):_ subpastas por assunto em `components/` (`ui/`, `asset/`, `dashboard/`...) e prefixo de assunto nos composables.

### D10 — Testes

- NestJS Testing: https://docs.nestjs.com/fundamentals/testing
- Vitest: https://vitest.dev
- Playwright: https://playwright.dev
- Testcontainers: https://testcontainers.com
- Docker Compose: https://docs.docker.com/compose/

## Observação sobre as fontes

Os links acima foram verificados em 2026-09-30 (resposta HTTP 200), exceto o do MariaDB, que bloqueia requisições automatizadas. A confirmação do conteúdo sobre `apps/`/`packages/`, módulos por feature e `nest g resource` foi feita lendo a documentação oficial; as demais páginas foram checadas apenas quanto à existência do link.
