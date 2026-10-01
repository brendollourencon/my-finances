# Tasks

## 1. Fundação do monorepo

- [x] 1.1 Inicializar git, `pnpm-workspace.yaml`, `package.json` raiz, `.editorconfig`, `.gitignore`, `.nvmrc`; verificar `pnpm install` na raiz sem erros
- [x] 1.2 Criar `packages/tsconfig` e `packages/eslint-config` (flat config + Prettier); verificar `pnpm lint` rodando em um pacote de exemplo
- [x] 1.3 Configurar Turborepo (`turbo.json` com `build`, `lint`, `typecheck`, `test`, `dev` e dependências entre tarefas); verificar que a 2ª execução de `turbo build` usa cache
- [x] 1.4 Configurar Husky + lint-staged (pre-commit) e commitlint (commit-msg); verificar que commit com mensagem "ajustes" é rejeitado e `feat: x` aceito
- [x] 1.5 Criar `infra/docker-compose.yml` com MariaDB 10.11, `.env.example` e script `pnpm infra:up`; verificar conexão via cliente SQL
- [x] 1.6 Criar workflow de CI (lint, typecheck, test, build com `--filter` de afetados); verificar execução verde localmente (ex.: `act`) ou no primeiro push
- [x] 1.7 Completar `README.md` raiz (comandos reais) e conferir `docs/` (`architecture.md`, `adr/0001`, `adr/0002`, já rascunhados); verificar que os comandos do README funcionam como descritos
- [x] 1.8 Atualizar `AGENTS.md` trocando os comandos *(planejado)* pelos reais após o scaffold; verificar que cada comando listado executa na raiz

## 2. Contratos compartilhados e esqueleto das apps

- [ ] 2.1 Criar `packages/contracts` com Zod e um schema de exemplo (`HealthResponse`) com build e testes Vitest; verificar `turbo test --filter=contracts` verde
- [ ] 2.2 Scaffold `apps/api` (NestJS) com Swagger, config tipada validada por Zod, `nestjs-pino` com `correlation_id` e rota `/health`; verificar `GET /health` e log JSON com correlation-id em teste e2e
- [ ] 2.3 Configurar convenções do Nest na API (`nest-cli`, path aliases, ESLint compartilhado, pastas `common/`, `config/`, `database/`) e registrar o padrão de módulos no README; verificar que `nest g resource` gera um módulo que compila e passa no lint
- [ ] 2.4 Scaffold `apps/web` (Nuxt 4, Tailwind, Pinia, Vitest) consumindo `contracts`; verificar que a página inicial exibe o status do `/health` e o teste de componente passa
- [ ] 2.5 Configurar TypeORM + conexão MariaDB + runner de migrations (`migration:run/revert`) e Testcontainers/serviço para testes de integração; verificar migration inicial aplicada e revertida

## 3. Identidade e autenticação (`user-auth`)

- [ ] 3.1 Gerar módulos `users` e `auth` (`nest g resource`) com entities `User`/`RefreshToken`, DTOs e função pura de política de senha/e-mail; verificar testes unitários da política
- [ ] 3.2 Implementar em `AuthService`: cadastro, login, renovação e logout com exceções HTTP do Nest; verificar testes unitários cobrindo cenários da spec (e-mail duplicado, credencial inválida, token revogado)
- [ ] 3.3 Migration `users` e `refresh_tokens`, hash argon2id, JWT + refresh rotativo armazenado como hash; verificar testes de integração contra MariaDB
- [ ] 3.4 Controllers de auth, guard global + `@Public()`, throttler com limite estrito no login, cookies HttpOnly; verificar testes e2e (cadastro, login, renovação, logout, 401, 429)
- [ ] 3.5 Front de auth: páginas em `pages/`, componentes em `components/auth/`, composable `useAuthSession`, store de sessão, middleware de rota em `middleware/` e renovação automática; verificar teste de componente/fluxo e redirecionamento de rota protegida
- [ ] 3.6 Documentar fluxo de auth em `docs/auth.md`; verificar que o Swagger exibe os endpoints com exemplos

## 4. Carteira de ativos (`asset-portfolio`)

- [ ] 4.1 Gerar módulos `assets` e `transactions` com entities, enum de categoria e `position.calculator.ts` puro (decimal.js: preço médio, venda acima da posição); verificar testes unitários (incl. 0,1+0,2=0,3)
- [ ] 4.2 Services de CRUD de ativos e registro de movimentações, sempre escopados por `userId` do token; escritas executadas na transação da requisição (ver 5.3); verificar testes unitários e teste de acesso cruzado entre usuários (retorna não encontrado)
- [ ] 4.3 Migrations `assets`, `transactions` (DECIMAL(20,8)) e integração dos services com o TypeORM; verificar testes de integração
- [ ] 4.4 Query de valor consolidado (por ativo/categoria/total) com fallback "sem cotação" e renda fixa por taxa; verificar testes com cenários da spec
- [ ] 4.5 Controllers + contratos Zod em `packages/contracts`; verificar e2e HTTP dos cenários de validação (ticker obrigatório, vencimento obrigatório)
- [ ] 4.6 Front da carteira: páginas em `pages/`, componentes em `components/asset/` (listagem, formulários por tipo de ativo e movimentações) e peças base reutilizáveis em `components/ui/`, composable `useAssets`; verificar testes de componente e navegação manual no dev server

## 5. Auditoria (`audit-logging`)

- [ ] 5.1 Spike no MariaDB real: tabela `db_audit_log` particionada por mês (PK `(id, created_at)`), helper de migration `createAuditTriggers` e triggers em `assets`; verificar via teste de integração insert/update/delete com ator da sessão, fallback `db:<usuário>` e que o definer do trigger permite a API ter só `SELECT`; registrar achados no ADR
- [ ] 5.2 Aplicar triggers a `users` (omitindo `password_hash`/tokens), `assets`, `transactions`, `allocation_targets`, gravando só colunas alteradas no UPDATE; verificar teste que lista as tabelas auditadas e falha se faltar algum dos 3 triggers, e teste de que senha nunca aparece
- [ ] 5.3 Interceptor global de escrita: transação por requisição, `SET @app_user_id/@correlation_id`, limpeza ao final e `EntityManager` acessível aos services via contexto assíncrono; verificar teste e2e com requisições concorrentes de usuários distintos (ator correto em cada registro)
- [ ] 5.4 Tabela `app_audit_log` (eventos de segurança e contexto das escritas) com usuário do banco `INSERT, SELECT`; verificar que UPDATE/DELETE em ambas as trilhas falha no banco e que os dois registros compartilham o `correlation_id`
- [ ] 5.5 Endpoint paginado de consulta da própria auditoria (filtros por período, tabela e ação) e tela no front; verificar teste e2e de isolamento por usuário e filtro de datas, e `EXPLAIN` mostrando poda de partições
- [ ] 5.6 Rotina agendada que cria a próxima partição mensal e descarta/arquiva as expiradas conforme retenção configurável; verificar teste de integração (partição nova criada, antiga removida sem afetar as recentes)
- [ ] 5.7 Teste de carga: popular milhões de linhas em `db_audit_log` e medir overhead de escrita com e sem triggers e latência de consultas por período/ator; registrar números em `docs/audit.md`
- [ ] 5.8 Documentar auditoria em `docs/audit.md` (arquitetura, como consultar, retenção, alternativas CDC/plugin/System Versioning); verificar que as queries documentadas executam

## 6. Dados de mercado (`market-data-ingestion`)

- [ ] 6.1 Gerar módulo `market-data` com interface `MarketDataProvider` (injetada por token), entities `Quote`/`Indicators` e função pura de frescor; verificar testes unitários
- [ ] 6.2 Adaptador `Investidor10Provider` (fetch + cheerio) com parser isolado e fixtures HTML de uma ação e um FII; verificar testes de parser incluindo campo ausente → erro explícito
- [ ] 6.3 Cortesia: rate limit configurável, User-Agent, checagem de `robots.txt`, retry com backoff; verificar testes com provedor/HTTP simulado
- [ ] 6.4 Migrations `market_quotes`/`market_indicators` + visão de último valor; `MarketDataService.collect()` tolerante a falhas por ticker; verificar teste de integração (falha em um ticker mantém o último dado e os demais seguem)
- [ ] 6.5 Agendamento (`@nestjs/schedule`) e endpoint administrativo de execução manual; verificar teste de que o cron aciona a coleta e execução manual funciona
- [ ] 6.6 Integrar cotações ao valor da carteira (evento/consulta); verificar teste e2e: nova cotação altera o total consolidado
- [ ] 6.7 Documentar o crawler e o aviso de termos de uso em `docs/market-data.md`, incluindo como trocar o provedor; verificar revisão do passo a passo

## 7. Dashboard de saúde financeira (`financial-health-dashboard`)

- [ ] 7.1 Read models: alocação por categoria/ativo, indicadores-resumo, evolução patrimonial (snapshots diários/por movimento) e desbalanceamento vs. meta; verificar testes de integração com cenários da spec
- [ ] 7.2 Endpoints de dashboard com contratos Zod; verificar e2e (carteira vazia, com dados, período de 12 meses)
- [ ] 7.3 Front do dashboard (`components/dashboard/`, composable `useDashboard`): gráficos ECharts (pizza/donut, linha), cards de indicadores, estado vazio, alerta de desbalanceamento e visão tabular alternativa; verificar testes de componente e checagem manual em tela móvel
- [ ] 7.4 Teste E2E Playwright do fluxo login → cadastrar ativo → ver dashboard; verificar execução verde local e no CI

## 8. Recomendações de investimento (`investment-recommendations`)

- [ ] 8.1 Módulo `recommendations`: metas de alocação (soma = 100%) e função pura de distribuição de aporte por déficit; verificar testes em tabela em `recommendations.calculator.ts` (abaixo da meta, balanceada, metas inválidas)
- [ ] 8.2 Ranqueamento de ativos por categoria com score configurável e justificativa estruturada; verificar testes unitários e caso de dados desatualizados
- [ ] 8.3 Persistência do histórico mensal de recomendações (migration versionada) e services gerar/consultar; verificar teste de integração de consulta por mês
- [ ] 8.4 Endpoints e contratos; verificar e2e do fluxo metas → aporte → sugestão com justificativa
- [ ] 8.5 Front de recomendações (`components/recommendation/`, composable `useRecommendations`): edição de metas, simulação de aporte, cartões de sugestão com justificativa, aviso educacional permanente e histórico; verificar testes de componente (aviso sempre visível)

## 9. Fechamento e integração

- [ ] 9.1 Executar `pnpm lint && pnpm typecheck && pnpm test && pnpm build` na raiz e `turbo` com cache; verificar tudo verde
- [ ] 9.2 Revisar que todos os cenários das 7 specs têm teste correspondente (checklist em `docs/spec-coverage.md`); verificar lacunas fechadas
- [ ] 9.3 Executar fluxo manual completo com `pnpm infra:up`, migrations e `dev`; verificar que auth, carteira, auditoria, crawler, dashboard e recomendações funcionam juntos
- [ ] 9.4 Finalizar README/ADRs com aprendizados e alternativas a estudar (Nx, Drizzle, BullMQ, Nuxt Layers); verificar revisão do conteúdo
