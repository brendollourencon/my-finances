# 0002. Auditoria por triggers com ator da aplicação

- Status: aceita
- Data: 2026-09-30

## Contexto

É preciso registrar automaticamente cada alteração no banco e saber qual usuário do sistema a fez, em um cenário que pode chegar a milhões de registros.

## Decisão

- **Triggers** `AFTER INSERT/UPDATE/DELETE` nas tabelas críticas gravam antes/depois (JSON) em `db_audit_log`.
- O ator vem das variáveis de sessão `@app_user_id` e `@correlation_id`, definidas pela API em uma **transação por requisição de escrita**; sem variável, o ator é `db:<usuário do banco>`.
- Trilha complementar na aplicação (`app_audit_log`) para eventos de segurança e contexto, ligada por `correlation_id`.
- Escala: índices, **partição mensal** por `created_at` (PK `(id, created_at)`), retenção configurável e teste de carga.
- Fora da auditoria: `market_quotes`/`market_indicators` e as próprias tabelas de auditoria.

## Alternativas consideradas

- **System-Versioned Tables do MariaDB**: guardam versões e permitem consulta temporal, e com `updated_by` registram o último autor, mas não registram quem **deletou** sem soft delete.
- **CDC (Debezium)**: fora da transação de escrita, mas exige infraestrutura extra (Kafka).
- **Plugin de auditoria do MariaDB**: registra conexões e queries, não antes/depois por linha.
- **Somente aplicação**: não vê SQL manual nem migrations.

## Consequências

- Cobre qualquer origem de escrita; custo extra de uma gravação por linha alterada.
- Updates em lote grandes geram um registro por linha.
- A transação por requisição é obrigatória (variáveis são por conexão e a API usa pool).
- Pontos a confirmar no spike da tarefa 5.1: privilégios do definer dos triggers e forma de compartilhar a transação com os services.
