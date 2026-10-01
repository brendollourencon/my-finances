# Arquitetura

Resumo neutro de ferramenta. O detalhe e as alternativas consideradas estão em `openspec/changes/bootstrap-personal-finance-monorepo/design.md`; os comportamentos exigidos estão em `specs/` da mesma change. Decisões individuais: [`adr/`](adr/).

## Visão geral

```
Navegador ──► apps/web (Nuxt 4) ──HTTP──► apps/api (NestJS) ──► MariaDB 10.11
                                              │
                                              └─► crawler (agendado) ──► Investidor10
packages/contracts (Zod) compartilhado entre web e api
```

Monorepo pnpm + Turborepo. API como **monólito modular**: um módulo por feature (`auth`, `users`, `assets`, `transactions`, `market-data`, `recommendations`, `dashboard`, `audit`) mais `common/` (guards, interceptors, filters, pipes).

## Capacidades

| Capacidade                 | Resumo                                                                          |
| -------------------------- | ------------------------------------------------------------------------------- |
| monorepo-tooling           | workspaces, Turborepo com cache, Husky/commitlint, CI, ambiente local em Docker |
| user-auth                  | cadastro, login, tokens de acesso e renovação, isolamento por usuário           |
| asset-portfolio            | ativos de renda fixa e variável, movimentações, valor consolidado               |
| financial-health-dashboard | alocação, evolução patrimonial, indicadores, alerta de desbalanceamento         |
| investment-recommendations | metas, sugestão mensal de aporte com justificativa                              |
| market-data-ingestion      | crawler agendado, tolerante a falhas, fonte substituível                        |
| audit-logging              | auditoria automática por triggers com ator, trilha da aplicação, retenção       |

## Pontos de atenção

- **Auditoria:** triggers no banco gravam antes/depois em `db_audit_log`; o ator vem de variáveis de sessão definidas numa transação por requisição. Tabelas de auditoria particionadas por mês.
- **Crawler:** atrás da interface `MarketDataProvider`, para trocar de fonte sem afetar o restante.
- **Recomendação:** função pura e determinística; conteúdo educacional.
