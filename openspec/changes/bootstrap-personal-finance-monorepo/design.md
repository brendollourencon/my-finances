# Design

## Context

Repositório greenfield (apenas `openspec/` e `.claude/`). O objetivo primário é **aprendizado de arquitetura**, então decisões priorizam módulos coesos e práticas correntes de mercado, mesmo quando um CRUD simples bastaria. Motivação e escopo em `proposal.md`; requisitos de comportamento em `specs/`. Ambiente de desenvolvimento: Windows 11, Docker para o MariaDB.

## Goals / Non-Goals

**Goals:**
- Módulos coesos por feature, seguindo a convenção nativa do NestJS (`nest g resource`), com regras de cálculo isoladas em funções puras testáveis.
- Um caminho fino de ponta a ponta (auth → ativo → dashboard) cedo, depois recomendação e crawler.
- Auditoria automática no banco (com o usuário do sistema) e trilha na aplicação, preparadas para alto volume de registros.

**Non-Goals:**
- Multi-tenant corporativo, billing, integrações com corretoras/Open Finance, app mobile nativo.
- Microsserviços: é um **monólito modular** (API única); o crawler roda como módulo/job da mesma API, extraível depois.
- Deploy em produção/Kubernetes (apenas CI + Docker Compose local).

## Decisions

### D1. Monorepo: pnpm workspaces + Turborepo
```
apps/
  api/            NestJS
  web/            Nuxt 4
packages/
  contracts/      schemas Zod + tipos (DTOs compartilhados API↔Web)
  eslint-config/  regras compartilhadas
  tsconfig/       tsconfigs base
infra/            docker-compose, scripts SQL de apoio
```
- **Por quê**: pnpm é rápido e estrito (evita dependências fantasma); Turborepo dá grafo de tarefas + cache local/remoto com pouca configuração.
- **Alternativas**: Nx (mais poderoso, mais opinativo/curva maior — bom estudo futuro); npm/yarn workspaces puros (sem cache de tarefas).
- **Qualidade**: Husky + lint-staged (arquivos staged), commitlint (Conventional Commits), Prettier + ESLint flat config, `knip` opcional para código morto, Changesets só se pacotes forem publicados (provavelmente adiado). CI no GitHub Actions com `turbo --filter=...[origin/main]`.

### D2. API NestJS com estrutura padrão do framework (módulos por feature)
```
apps/api/src/
  auth/  users/  assets/  transactions/  market-data/
  recommendations/  dashboard/  audit/
  common/      guards, interceptors, filters, pipes, decorators
  config/      configuração tipada
  database/    migrations, data-source
```
Cada módulo segue o que `nest g resource` gera: `*.module.ts`, `*.controller.ts`, `*.service.ts`, `dto/`, `entities/` (+ `guards/`, `pipes/` quando necessário).
- Módulos se comunicam por **injeção de dependência** (`exports` do módulo) e por eventos (`@nestjs/event-emitter`) quando o acoplamento direto não faz sentido (ex.: auditoria).
- A entidade TypeORM é o modelo único; services usam `@InjectRepository`. Erros esperados via exceções HTTP do Nest (`NotFoundException`, `ConflictException`...) e filtros globais.
- **Regras puras fora dos services**: cálculos como preço médio, valor consolidado, distribuição de aporte e ranking ficam em arquivos `*.calculator.ts`/`*.rules.ts` sem dependência do Nest, testáveis sem subir o app.
- **Única abstração formal**: `MarketDataProvider` (ver D7).
- **Alternativa descartada**: Clean Architecture com camadas `domain/application/infrastructure/presentation`, portas/adaptadores e mappers — treina inversão de dependência, porém adiciona boilerplate que o usuário preferiu evitar.
- Leituras agregadas (dashboard) podem usar queries dedicadas no próprio módulo `dashboard`, sem passar pelas regras de escrita.

### D3. Persistência: MariaDB + TypeORM (migrations em SQL explícito)
- MariaDB ≥ 10.11 (LTS). Valores monetários em `DECIMAL(20,8)` e `decimal.js` nos cálculos (nunca `number`).
- **ORM**: TypeORM por integração madura com Nest e migrations com SQL cru (necessário para triggers e particionamento). **Alternativas**: Prisma (schema não modela triggers/particionamento; precisaria de SQL cru e perde parte do valor), Drizzle (excelente, menos integrado ao Nest — bom candidato para estudo posterior).
- Migrations versionadas e executadas em CI contra MariaDB real (Testcontainers/serviço Docker) para testes de integração.

### D4. Auditoria: triggers no banco + trilha na aplicação
Duas trilhas, em tabelas separadas, ligadas por `correlation_id`:
1. **`db_audit_log` (banco, automática)** — triggers `AFTER INSERT/UPDATE/DELETE` nas tabelas críticas (`users`, `assets`, `transactions`, `allocation_targets`) gravam: tabela, `row_id`, ação, `actor`, `correlation_id`, `before_data`/`after_data` (JSON), `created_at`. Captura qualquer origem de escrita, inclusive SQL manual e migrations.
   - **Ator**: lido das variáveis de sessão `@app_user_id` e `@correlation_id`; se vazias, `db:<CURRENT_USER()>`. Validado em experimento no MariaDB 10.11 (insert/update com ator da aplicação; delete manual registrado com o usuário do banco).
   - **Propagação do ator**: interceptor global abre **uma transação por requisição de escrita**, executa `SET @app_user_id=..., @correlation_id=...` na conexão da transação e limpa ao final. O `EntityManager` da transação fica disponível aos services via contexto assíncrono (`AsyncLocalStorage`; candidato a verificar: `nestjs-cls` + plugin transacional). Necessário porque as variáveis são por conexão e a API usa pool.
   - **Dados sensíveis**: triggers omitem colunas como `password_hash` e tokens.
   - **UPDATE**: grava apenas as colunas alteradas (antes/depois) para reduzir volume.
   - **Geração dos triggers**: helper em migrations (`createAuditTriggers(table, {exclude})`) para evitar divergência; teste de integração garante que toda tabela auditada tem os 3 triggers.
   - **Tabelas fora**: `market_quotes`/`market_indicators` (alta rotatividade) e as próprias tabelas de auditoria.
2. **`app_audit_log` (aplicação, semântica)** — ator, ação, recurso, resultado, ip, `correlation_id`; eventos de segurança (login, falha, logout) e contexto das escritas. Alimentada por interceptor/eventos Nest. Mantida também para escritas (decisão do usuário) para comparar com a trilha do banco.
- **Imutabilidade**: o usuário do banco da API tem apenas `SELECT` em `db_audit_log` (triggers executam com os privilégios do *definer*, logo a API não precisa de `INSERT`) e `INSERT, SELECT` em `app_audit_log`. A confirmar no spike que o definer dos triggers é o usuário de migrations.
- **Escala (milhões de registros)**:
  - Índices: `(actor, created_at)`, `(table_name, row_id, created_at)`, `(correlation_id)`.
  - **Particionamento `RANGE` mensal por `created_at`**; a chave de partição integra a PK (`PRIMARY KEY (id, created_at)`). Rotina agendada cria a próxima partição e descarta/arquiva as expiradas (`ALTER TABLE ... DROP PARTITION`), sem varrer a tabela.
  - Retenção configurável (ex.: 24 meses online; depois exportar e comprimir).
  - Teste de carga: popular milhões de linhas e medir overhead de escrita dos triggers e latência das consultas por período/ator.
  - Limitação conhecida: triggers são por linha; updates em lote grandes disparam um registro por linha — evitar em tabelas auditadas ou desabilitar de forma controlada em migrations.
- **Logs**: `nestjs-pino` (JSON) com `AsyncLocalStorage` para `correlation_id` (header `x-request-id`), com redação de `authorization`/senhas.
- **Alternativas**:
  - *System-Versioned Tables do MariaDB* (`WITH SYSTEM VERSIONING`) — testadas: guardam versões e permitem consulta temporal, e com coluna `updated_by` + trigger registram o último autor, mas **não registram quem deletou** (precisaria de soft delete) e não geram eventos em JSON. Descartadas para esta change; podem ser estudadas depois.
  - *CDC (Debezium)* — lê o log de transações fora da transação de escrita, sem overhead nos triggers, mas exige Kafka/infra extra.
  - *Plugin de auditoria do MariaDB* — registra conexões e queries, não antes/depois por linha; útil para compliance.
  - *Auditoria só na aplicação* — não vê SQL manual nem migrations.

### D5. Autenticação
- Senha com **argon2id**; JWT de acesso curto (~15 min) + refresh token opaco **rotativo**, armazenado como hash no banco, revogável; refresh em cookie `HttpOnly; Secure; SameSite=Lax`, access em memória no front.
- `@nestjs/throttler` para rate limit global e limite mais estrito no login. Guard global com decorador `@Public()` para exceções. Escopo por usuário aplicado nos services (sempre `userId` do token como filtro das consultas), com teste dedicado de acesso cruzado.
- **Alternativas**: Passport (aceitável como adaptador), Auth providers externos (Keycloak/Auth0) — fora do escopo de estudo atual.

### D6. Contratos compartilhados com Zod
`packages/contracts` exporta schemas Zod e tipos inferidos usados na validação da API (pipe Zod) e no front. Gera uma única fonte de verdade para DTOs. OpenAPI via `@nestjs/swagger` para documentação; cliente tipado do front pode ser gerado depois (`openapi-typescript`).
- **Alternativa**: `class-validator` + decorators (idiomático Nest, mas duplica tipos no front).

### D7. Crawler de dados de mercado
- Interface `MarketDataProvider` em `market-data/providers/`, injetada por token; implementação `Investidor10Provider` (fetch + **cheerio**; Playwright somente se o conteúdo exigir JS). Parser isolado e testado com **fixtures HTML salvas**.
- Execução por `@nestjs/schedule` (cron, dias úteis após fechamento), fila interna com concorrência 1 e atraso entre requisições; `robots.txt` verificado; retry com backoff exponencial. Sem Redis/BullMQ nesta fase (simplicidade); migrar para BullMQ se precisar de persistência de jobs.
- Persistência: `market_quotes`/`market_indicators` (append por coleta) + visão "último valor" por ticker.
- Aviso legal: uso pessoal/educacional; checar termos da fonte. Fallback documentado: provedor alternativo via mesma interface (ex.: brapi).

### D8. Recomendação (regras determinísticas)
Função pura em `recommendations.calculator.ts`: (1) calcula desvio atual-vs-meta por categoria e distribui o aporte proporcionalmente ao déficit; (2) ranqueia ativos por score simples e configurável (ex.: FIIs por P/VP e DY; ações por P/L e DY) com limiares explícitos; (3) retorna a justificativa estruturada. Facilmente testável (tabela de casos). Sem ML.

### D9. Frontend Nuxt 4 na estrutura padrão do framework
Segue a estrutura oficial (Nuxt 4.x, diretório `app/`), sem pastas inventadas:
```
apps/web/
  app/
    assets/  components/  composables/  layouts/  middleware/
    pages/   plugins/     utils/        stores/ (módulo Pinia)
    app.vue  app.config.ts  error.vue
  public/
  test/                 (local recomendado pela doc para testes)
  nuxt.config.ts
```
- **Componentização com subpastas de `components/`**: o Nuxt auto-importa componentes e deriva o nome do caminho (`components/base/foo/Button.vue` → `<BaseFooButton />`). Usamos subpastas por assunto: `components/ui/` (peças base, sem regra de negócio; ex.: `UiButton`), `components/asset/` (`AssetForm`, `AssetTable`), `components/dashboard/` (`DashboardAllocationChart`), `components/recommendation/`, `components/auth/`. Páginas finas em `pages/` apenas montam componentes.
- **`composables/`**: o Nuxt escaneia só o **nível superior** da pasta; por isso arquivos planos com prefixo de assunto (`useAssets.ts`, `useDashboard.ts`, `useAuthSession.ts`). Subpastas exigiriam re-export em `index.ts` ou configuração do scanner, e não serão usadas.
- **Dados do servidor**: `useFetch`/`useAsyncData`/`$fetch` encapsulados em composables; tipos e schemas vêm de `@repo/contracts`. Lógica pura reutilizável (formatação de moeda, cálculos de gráfico) em `utils/`.
- **Estado**: Pinia (módulo `@pinia/nuxt`) apenas para sessão/UI; `stores/` é convenção do módulo, não do núcleo do Nuxt (confirmar no scaffold).
- **Não usados**: `server/` (a API é o NestJS) e `shared/` (o compartilhamento é feito pelo pacote `@repo/contracts`).
- **Escala futura**: Nuxt Layers (`layers/`, recurso oficial) se for preciso isolar assuntos como mini-apps. Organização por *features* (`features/...`) foi **descartada**: não é padrão do Nuxt e exigiria configuração extra de auto-import.
- Tailwind + Nuxt UI (ou shadcn-vue). Gráficos com **ECharts** (`vue-echarts`), com visão tabular alternativa para acessibilidade.
- Testes: Vitest + `@nuxt/test-utils` + Vue Test Utils em `test/`; Playwright para 1–2 fluxos E2E (login → cadastrar ativo → ver dashboard).

### D10. Estratégia de testes
Pirâmide: unitários de regras puras e services (rápidos) → integração de repositórios com MariaDB real em container → e2e HTTP (supertest) → E2E de UI mínimo. Jest na API (padrão Nest), Vitest no web e pacotes.

## Risks / Trade-offs

- **Scraping frágil / termos de uso** → parser isolado + fixtures, falha tolerante mantendo último dado, interface substituível, uso pessoal.
- **Over-engineering para um app pequeno** → é intencional (estudo); mitigar com entrega vertical por fatia e ADRs curtos registrando o porquê.
- **Services engordando com o tempo** → extrair regras para `*.calculator.ts` puros e manter módulos coesos; revisar acoplamento entre módulos nos ADRs.
- **Crescimento do `db_audit_log` e overhead dos triggers** → partição mensal, índices, retenção, só tabelas críticas auditadas, gravar só colunas alteradas e teste de carga com milhões de linhas.
- **Ator errado por reutilização de conexão do pool** → variáveis setadas e limpas dentro da transação da requisição; teste de integração com requisições concorrentes de usuários distintos.
- **Triggers divergindo do schema** → criados por helper de migration e verificados por teste.
- **Escopo amplo** → tasks organizadas em marcos; cada marco entrega valor demonstrável e pode ser arquivado como change própria.
- **Recomendação interpretada como conselho financeiro** → aviso educacional obrigatório e justificativa transparente.

## Migration Plan

Greenfield: sem migração de dados. Ordem: fundação do monorepo → banco/migrations → auth → portfolio → auditoria → dashboard → market-data → recomendações. Rollback = reverter commits/migrations (migrations `down` removem triggers e partições junto com as tabelas).

## Open Questions

- Hospedagem futura (VPS/Docker) e remoto de cache do Turborepo — definir quando houver deploy.
- Fórmulas/limiares exatos de ranqueamento de ativos — calibrar durante a implementação do marco de recomendações.
