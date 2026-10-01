# 0001. Monorepo e estrutura padrão do NestJS/Nuxt

- Status: aceita
- Data: 2026-09-30

## Contexto

Projeto de estudo com API e front. É preciso fixar a organização do repositório e das apps antes de qualquer feature.

## Decisão

- Monorepo com **pnpm workspaces + Turborepo**: `apps/` para aplicações e `packages/` para o resto, pacotes com escopo `@repo/*` (convenção da documentação do Turborepo).
- API **NestJS** com a estrutura padrão do framework (módulos por feature gerados por `nest g resource`), sem camadas de Clean Architecture. Regras de cálculo em funções puras; única abstração formal é `MarketDataProvider`.
- Front **Nuxt 4** na estrutura oficial `app/`, com componentes em subpastas por assunto e composables planos.
- Contratos compartilhados em `packages/contracts` (Zod).

## Alternativas consideradas

- Clean Architecture com camadas e portas/adaptadores (descartada: boilerplate que o autor preferiu evitar).
- Organização do front por `features/` (descartada: não é padrão do Nuxt).
- Nx no lugar de Turborepo (mais poderoso e mais opinativo; fica como estudo futuro).

## Consequências

- Estrutura previsível e alinhada à documentação oficial.
- Services podem engordar; mitigado extraindo regras para `*.calculator.ts` puros.
