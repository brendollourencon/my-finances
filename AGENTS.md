# AGENTS.md

Instruções para agentes de IA e pessoas que trabalham neste repositório. É a **fonte única**; `CLAUDE.md` e outros arquivos de ferramenta apenas apontam para cá.

## Projeto

Sistema de finanças pessoais (carteira de ativos, saúde financeira, recomendação mensal de aportes) feito como projeto de estudo de NestJS, Nuxt, monorepo e auditoria. Idioma da UI e da documentação: pt-BR; código e identificadores em inglês.

> **Estado atual:** fundação do monorepo pronta (grupo 1 da change `bootstrap-personal-finance-monorepo`). As apps `api` e `web` e o pacote `contracts` ainda não existem; até lá `dev`, `typecheck` e `test` rodam sem tarefas.

## Onde está o planejamento

- Plano da change atual: `openspec/changes/bootstrap-personal-finance-monorepo/` (`proposal.md`, `design.md`, `specs/`, `tasks.md`).
- Resumo neutro de ferramenta: `docs/architecture.md` e `docs/adr/`.
- Fontes oficiais para estudo: `README.md`.
- Em caso de conflito, `specs/` define **o que** o sistema faz e `design.md` define **como**.

## Estrutura do monorepo

```
apps/api        NestJS (módulos por feature)
apps/web        Nuxt 4 (estrutura padrão, diretório app/)
packages/       contracts (schemas Zod), eslint-config, tsconfig  (escopo @repo/*)
infra/          docker-compose.yml e scripts de init do MariaDB
docs/           arquitetura e ADRs
```

## Comandos

```bash
cp .env.example .env
docker compose --env-file .env -f infra/docker-compose.yml up -d --wait   # MariaDB (já disponível)
pnpm install        # instala tudo e ativa os hooks do Husky
pnpm infra:up       # sobe o MariaDB (equivale ao docker compose acima)
pnpm dev            # api + web em watch via Turborepo
pnpm lint && pnpm typecheck && pnpm test && pnpm build
pnpm format:check  # Prettier
```

As apps rodam no host (ex.: WebStorm ou `pnpm dev`); o Docker sobe apenas o banco.

## Convenções

- **Gerenciador:** pnpm workspaces + Turborepo. Commits em **Conventional Commits** (verificado por commitlint/Husky).
- **API (NestJS):** estrutura padrão do framework, um módulo por feature (`*.module.ts`, `*.controller.ts`, `*.service.ts`, `dto/`, `entities/`), gerado com `nest g resource`. Sem camadas de Clean Architecture. Regras de cálculo puras em `*.calculator.ts`/`*.rules.ts`, sem dependência do Nest. Única abstração formal: `MarketDataProvider`.
- **Web (Nuxt 4):** estrutura oficial em `app/`. Componentes em subpastas por assunto de `components/` (`ui/`, `asset/`, `dashboard/`...), composables planos com prefixo de assunto em `composables/` (o Nuxt só escaneia o nível superior), páginas finas.
- **Contratos:** schemas Zod em `@repo/contracts`, usados na API e no front.
- **Banco:** MariaDB 10.11, migrations em SQL explícito (TypeORM), valores monetários em `DECIMAL(20,8)`.

## Regras que não devem ser quebradas

1. **Dinheiro nunca é `number`**: usar `decimal.js` nos cálculos e `DECIMAL` no banco.
2. **Toda escrita da API roda na transação da requisição**, que define `@app_user_id` e `@correlation_id` na conexão; é isso que faz os triggers de auditoria gravarem o ator correto.
3. **Não auditar** `market_quotes`/`market_indicators` e as próprias tabelas de auditoria. Nunca gravar senhas, hashes ou tokens na auditoria nem em logs.
4. **Isolamento por usuário:** toda consulta de dados de domínio filtra pelo `userId` do token; recurso de outro usuário responde como não encontrado.
5. **Recomendações são educacionais**, com justificativa e aviso visível; não são aconselhamento financeiro.
6. **Crawler:** respeitar `robots.txt`, limite de requisições e termos de uso do Investidor10; falha em um ticker não apaga o último dado válido.
7. **Tabelas de auditoria** são append-only e particionadas por mês; a API não tem `UPDATE`/`DELETE` nelas.

## Testes

Regras puras e services: testes unitários rápidos. Repositórios/triggers: integração contra MariaDB real em container. API: e2e HTTP com supertest. Front: Vitest + Vue Test Utils (em `test/`); Playwright para poucos fluxos E2E. Cada tarefa de `tasks.md` declara como verificá-la.

## Ao alterar o plano

Atualize juntos `proposal.md`, `specs/`, `design.md` e `tasks.md` da change (e `docs/` se a decisão mudar). Registre decisões relevantes como ADR em `docs/adr/`.

<!-- BEGIN:turborepo-agent-rules -->

# This is NOT the Turborepo you know

Turborepo configuration, task behavior, and CLI commands can vary between installed versions and may differ from your training data. Resolve the `turbo` package from this file's directory or relevant workspace; in monorepos, it may not be visible from the repository root. For example, run `node -p "require.resolve('turbo/package.json')"` from a workspace that depends on `turbo`.

Read `docs/README.md` inside that installed package first, then read the relevant pages from its `docs/` directory before changing Turborepo configuration or commands. Heed deprecation notices. These bundled docs match the installed package version and are available without network access.

This block is written and re-added by `turbo` before repository-scoped commands when an AI agent is detected. In the Turborepo source repository, its template is defined in `crates/turborepo-cli/src/cli/agent_guidance.rs`. Removing the managed block while updates are enabled means a later qualifying invocation will add it again. Set `"agentGuidance": false` in the root `turbo.json` or `turbo.jsonc` to opt out; this does not remove an existing block. Keep the block committed with your work to avoid an uncommitted change on the next agent invocation.
<!-- END:turborepo-agent-rules -->
