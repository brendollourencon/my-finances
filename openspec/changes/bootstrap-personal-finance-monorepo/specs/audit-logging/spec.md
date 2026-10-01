# Spec Delta

## Purpose

Garantir rastreabilidade de ações e alterações de dados por meio de auditoria automática no banco de dados, com identificação do usuário do sistema, e de uma trilha complementar na aplicação, sustentáveis em alto volume de registros.

## ADDED Requirements

### Requirement: Auditoria automática de alterações no banco
O banco de dados SHALL registrar automaticamente toda inserção, alteração e exclusão nas tabelas auditadas (usuários, ativos, movimentações, metas), com tabela, identificador da linha, ação, instante, valores anteriores e novos e o ator, independentemente do código da aplicação.

#### Scenario: Alteração feita pela aplicação
- **WHEN** um usuário altera a quantidade de um ativo por meio da API
- **THEN** existe um registro com ação de atualização, valor antigo e novo da quantidade e o identificador desse usuário

#### Scenario: Alteração direta no banco
- **WHEN** uma linha é alterada ou excluída por SQL manual, migration ou script sem usuário da aplicação
- **THEN** a alteração é registrada com o usuário do banco como ator

#### Scenario: Exclusão
- **WHEN** um usuário exclui um ativo
- **THEN** o registro contém os valores da linha excluída e o usuário que a excluiu

### Requirement: Ator propagado da requisição
Toda escrita feita pela API SHALL ser associada ao usuário autenticado e ao identificador de correlação da requisição, e esse contexto SHALL NOT vazar para outra requisição que reutilize a mesma conexão.

#### Scenario: Conexões reutilizadas
- **WHEN** duas requisições de usuários diferentes usam a mesma conexão do pool em sequência
- **THEN** cada alteração é registrada com o ator da sua própria requisição

#### Scenario: Escrita sem usuário autenticado
- **WHEN** uma ação pública (ex.: cadastro) grava dados
- **THEN** o registro identifica o ator como o próprio usuário criado ou como anônimo, nunca como outro usuário

### Requirement: Dados sensíveis fora da auditoria
A auditoria no banco SHALL NOT armazenar hashes de senha, tokens ou outros segredos.

#### Scenario: Alteração de senha
- **WHEN** a senha de um usuário é alterada
- **THEN** o registro indica a alteração sem conter valor antigo nem novo da senha

### Requirement: Imutabilidade da trilha
As trilhas de auditoria SHALL ser append-only: o usuário do banco usado pela aplicação SHALL NOT ter permissão de alterar ou excluir seus registros, nem de inserir diretamente na trilha do banco.

#### Scenario: Tentativa de alteração
- **WHEN** a aplicação tenta alterar ou excluir um registro de auditoria
- **THEN** o banco nega a operação

### Requirement: Registro de auditoria de ações na aplicação
O sistema SHALL registrar na aplicação, para escritas e eventos de segurança (login, falha de login, logout), o ator, a ação, o recurso, o instante, o resultado e o identificador de correlação, complementando a auditoria do banco.

#### Scenario: Criação de ativo
- **WHEN** um usuário cria um ativo
- **THEN** existe registro na aplicação com ator, ação "criar", recurso e correlation-id, além do registro do banco

#### Scenario: Falha de login
- **WHEN** ocorre uma tentativa de login com falha
- **THEN** o evento é registrado sem armazenar a senha

### Requirement: Correlação entre trilhas
Os registros do banco e da aplicação gerados pela mesma requisição SHALL compartilhar o mesmo identificador de correlação.

#### Scenario: Cruzar as duas trilhas
- **WHEN** se busca um correlation-id
- **THEN** é possível ver o registro da aplicação e as alterações de linhas do banco daquela requisição

### Requirement: Consulta da auditoria
O sistema SHALL permitir ao usuário consultar a própria trilha, filtrável por período, tabela e tipo de ação, com paginação, com tempo de resposta estável mesmo com milhões de registros.

#### Scenario: Filtro por período
- **WHEN** o usuário filtra por um intervalo de datas
- **THEN** apenas eventos desse intervalo e do próprio usuário são listados

#### Scenario: Volume alto
- **WHEN** a trilha contém milhões de registros e a consulta usa um período recente
- **THEN** a resposta não varre registros fora do período

### Requirement: Retenção e crescimento controlado
As trilhas de auditoria SHALL ser organizadas por período de forma que registros antigos possam ser arquivados ou removidos sem bloquear a escrita nem varrer a tabela inteira.

#### Scenario: Descarte de período antigo
- **WHEN** um período excede a retenção configurada
- **THEN** ele é removido ou arquivado como unidade, sem afetar registros recentes

### Requirement: Tabelas de alta rotatividade fora da auditoria
Tabelas de dados de mercado coletados automaticamente SHALL NOT ser auditadas pelo banco.

#### Scenario: Coleta de cotações
- **WHEN** o crawler grava milhares de cotações
- **THEN** nenhuma linha de auditoria é gerada por elas

### Requirement: Logs estruturados
Os logs da aplicação SHALL ser estruturados (JSON), com nível e correlation-id, e SHALL NOT conter segredos.

#### Scenario: Rastreio por requisição
- **WHEN** uma requisição gera vários logs
- **THEN** todos compartilham o mesmo correlation-id
