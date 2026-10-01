# Spec Delta

## Purpose

Permitir ao usuário registrar e consultar seus ativos de renda fixa e variável, com classificação por categoria e valor consolidado da carteira.

## ADDED Requirements

### Requirement: Categorias e tipos de ativo
O sistema SHALL classificar ativos em categorias (ao menos: renda fixa, ações, FIIs) e SHALL exigir campos específicos por tipo: renda fixa com emissor, indexador, taxa e vencimento; renda variável com ticker.

#### Scenario: Renda variável sem ticker
- **WHEN** o usuário cria uma ação sem ticker
- **THEN** a criação é recusada com erro de validação

#### Scenario: Renda fixa sem vencimento
- **WHEN** o usuário cria um título de renda fixa sem data de vencimento
- **THEN** a criação é recusada com erro de validação

### Requirement: Registro de ativos e movimentações
O sistema SHALL permitir criar, listar, editar e remover ativos do usuário, e registrar movimentações de compra e venda com data, quantidade e preço, mantendo quantidade e preço médio atualizados.

#### Scenario: Compra adicional
- **WHEN** o usuário registra nova compra de um ativo já existente
- **THEN** a quantidade total e o preço médio são recalculados

#### Scenario: Venda acima da posição
- **WHEN** o usuário registra venda de quantidade maior que a posição
- **THEN** a movimentação é recusada

#### Scenario: Remoção
- **WHEN** o usuário remove um ativo
- **THEN** ele deixa de aparecer na carteira e a remoção fica registrada na auditoria

### Requirement: Valor consolidado da carteira
O sistema SHALL calcular o valor atual por ativo, por categoria e total, usando a última cotação conhecida para renda variável e o valor atualizado conforme taxa para renda fixa.

#### Scenario: Cotação atualizada
- **WHEN** uma nova cotação de um ticker é ingerida
- **THEN** o valor da posição e o total da carteira refletem a nova cotação

#### Scenario: Ativo sem cotação
- **WHEN** não há cotação para um ticker
- **THEN** o ativo é exibido pelo preço médio e sinalizado como sem cotação

### Requirement: Precisão monetária
O sistema SHALL representar valores monetários e quantidades sem erros de ponto flutuante binário.

#### Scenario: Soma de valores decimais
- **WHEN** valores como 0,1 e 0,2 são somados na carteira
- **THEN** o resultado é exatamente 0,3
