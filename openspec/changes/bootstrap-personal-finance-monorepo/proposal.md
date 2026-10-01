# Proposal

## Why

Projeto de estudo para aprofundar conhecimento em NestJS (com sua estrutura e boas práticas nativas), Nuxt 4, componentização, modularização e práticas modernas de monorepo (Turborepo, Husky, etc.), usando como caso prático um sistema de **finanças pessoais** com carteira de ativos, visão de saúde financeira e sugestão mensal de aportes. O repositório está vazio (greenfield), então é o momento de fixar as fundações (estrutura, módulos coesos, qualidade automatizada) antes de qualquer feature.

## What Changes

- Criar um **monorepo** (pnpm workspaces + Turborepo) com `apps/api` (NestJS), `apps/web` (Nuxt 4) e `packages/*` compartilhados (contratos/DTOs, config de lint/ts, etc.).
- Automação de qualidade: **Husky + lint-staged + commitlint** (Conventional Commits), ESLint/Prettier compartilhados, Vitest/Jest, CI com cache do Turborepo, **Changesets** opcional para versionamento.
- Backend NestJS na **estrutura padrão do framework**: módulos por feature (`module`, `controller`, `service`, `dto`, `entities`, guards, pipes), gerados com `nest g resource`, sem camadas formais. Mantém apenas a abstração `MarketDataProvider` (crawler) e funções puras testáveis para regras de cálculo (preço médio, recomendação).
- Frontend Nuxt 4 na **estrutura padrão do framework** (`app/components`, `composables`, `pages`, `layouts`, `middleware`, `utils`), componentização por subpastas de `components/`, Pinia e gráficos.
- Banco **MariaDB** (decisão do usuário) com migrations versionadas.
- **Auditoria em dois níveis**: (1) **automática no banco** via *triggers* do MariaDB que gravam cada INSERT/UPDATE/DELETE (antes/depois) em `db_audit_log`, com o usuário do sistema propagado por variável de sessão; (2) trilha na aplicação (`app_audit_log`) com contexto, eventos de segurança e correlation-id. Tabelas de auditoria projetadas para alto volume (índices, particionamento por data, retenção).
- Funcionalidades de domínio: autenticação/cadastro, cadastro de ativos (renda fixa, renda variável: ações, FIIs etc.), dashboard de saúde financeira com gráficos, módulo de recomendação mensal de onde investir, e **crawler** que atualiza cotações/indicadores de ações e FIIs a partir do Investidor10.

### Premissas registradas

- A auditoria automática no banco é feita com **triggers + variável de sessão** no MariaDB (testado: o ator da aplicação é gravado e alterações sem ator, como SQL manual, saem com o usuário do banco). *System-Versioned Tables* do MariaDB foram avaliadas e **descartadas**: guardam versões de linhas, mas não registram quem alterou nem quem deletou. CDC (Debezium) e o plugin de auditoria do servidor ficam como alternativas a estudar.
- Investidor10 não oferece API pública e seus termos podem restringir scraping: o crawler ficará atrás de uma **abstração (`MarketDataProvider`)**, com rate limit, cache e respeito a `robots.txt`, permitindo trocar por outra fonte (ex.: brapi, B3) sem afetar o restante do sistema. Uso estritamente pessoal/estudo.
- Recomendações são regras determinísticas e explicáveis (alocação-alvo vs. atual + indicadores), de caráter educacional, **não** aconselhamento financeiro.
- Uso individual, mas modelo multiusuário (dados isolados por usuário). Idioma da UI: pt-BR.

## Capabilities

### New Capabilities
- `monorepo-tooling`: estrutura do workspace, pipelines Turborepo, hooks Husky/commitlint, lint/format/test/CI compartilhados.
- `user-auth`: cadastro, login, sessão/token (access + refresh), logout e isolamento de dados por usuário.
- `asset-portfolio`: CRUD de ativos e posições (renda fixa, ações, FIIs, etc.), classificação por categoria e valor consolidado.
- `financial-health-dashboard`: indicadores e gráficos de saúde financeira (alocação, evolução patrimonial, proventos).
- `investment-recommendations`: sugestão mensal de categorias e ativos para aporte, com justificativa.
- `market-data-ingestion`: crawler agendado do Investidor10 que atualiza dados de ações e FIIs, com falha tolerante e histórico de cotações.
- `audit-logging`: auditoria automática no banco por triggers com ator da aplicação, trilha de auditoria na aplicação e estratégia de retenção para alto volume.

### Modified Capabilities
<!-- Nenhuma: projeto greenfield, sem specs existentes. -->

## Impact

- **Código novo**: todo o repositório (`apps/api`, `apps/web`, `packages/*`, configs raiz, CI).
- **Dependências principais**: pnpm, Turborepo, TypeScript, NestJS (+ TypeORM ou Prisma/Drizzle — a decidir no design), Nuxt 4, Pinia, ECharts/Chart.js, Zod/class-validator, Husky, lint-staged, commitlint, ESLint, Prettier, Vitest/Jest, Playwright (crawler), Docker Compose.
- **Infra**: MariaDB ≥ 10.3 (via Docker Compose em dev), agendador de jobs (`@nestjs/schedule`/BullMQ).
- **Riscos**: fragilidade do scraping (mudança de HTML), questões de termos de uso da fonte, escopo amplo — mitigado por entrega incremental via tasks.
