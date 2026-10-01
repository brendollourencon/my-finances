# Spec Delta

## Purpose

Define a estrutura do monorepo e a automação de qualidade que garantem que apps e pacotes sejam construídos, testados e validados de forma consistente e incremental.

## ADDED Requirements

### Requirement: Workspace único com apps e pacotes
O repositório SHALL conter `apps/api`, `apps/web` e `packages/*` gerenciados como workspaces de um único gerenciador de pacotes, com dependências internas resolvidas localmente.

#### Scenario: Instalação a partir da raiz
- **WHEN** o desenvolvedor executa a instalação de dependências na raiz
- **THEN** todas as apps e pacotes ficam instalados e vinculados entre si

#### Scenario: Pacote compartilhado consumido por ambas as apps
- **WHEN** um contrato é alterado em `packages/contracts`
- **THEN** `apps/api` e `apps/web` enxergam a alteração sem publicar o pacote

### Requirement: Tarefas orquestradas com cache
O repositório SHALL expor, a partir da raiz, os comandos `build`, `lint`, `typecheck`, `test` e `dev`, executados respeitando a ordem de dependências entre workspaces e reutilizando cache quando as entradas não mudaram.

#### Scenario: Reexecução sem mudanças
- **WHEN** `build` é executado duas vezes seguidas sem alterar arquivos
- **THEN** a segunda execução reaproveita o resultado em cache de todos os workspaces

#### Scenario: Mudança isolada
- **WHEN** apenas um workspace é alterado
- **THEN** somente esse workspace e seus dependentes são reexecutados

### Requirement: Verificações automáticas antes do commit
O repositório SHALL bloquear commits cujos arquivos alterados falhem em lint/format e commits cuja mensagem não siga Conventional Commits.

#### Scenario: Mensagem inválida
- **WHEN** o desenvolvedor faz commit com a mensagem "ajustes"
- **THEN** o commit é rejeitado com explicação do formato esperado

#### Scenario: Arquivo com erro de lint
- **WHEN** um arquivo staged viola a regra de lint
- **THEN** o commit é rejeitado e o erro é exibido

### Requirement: Pipeline de integração contínua
O repositório SHALL ter uma pipeline de CI que execute lint, typecheck, testes e build para todos os workspaces afetados em cada push/pull request.

#### Scenario: Falha em testes
- **WHEN** um teste falha em um pull request
- **THEN** a pipeline é marcada como falha

### Requirement: Ambiente local reproduzível
O repositório SHALL oferecer um comando único para subir as dependências de infraestrutura locais (MariaDB) e variáveis de ambiente documentadas por um arquivo de exemplo.

#### Scenario: Subir ambiente do zero
- **WHEN** o desenvolvedor copia o arquivo de exemplo de ambiente e sobe a infraestrutura
- **THEN** o banco fica acessível e as migrations podem ser aplicadas
