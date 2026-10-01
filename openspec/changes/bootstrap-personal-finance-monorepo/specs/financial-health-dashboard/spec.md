# Spec Delta

## Purpose

Apresentar visualmente a saúde financeira do usuário por meio de indicadores e gráficos derivados da carteira.

## ADDED Requirements

### Requirement: Gráfico de alocação
O dashboard SHALL exibir a distribuição percentual da carteira por categoria e por ativo.

#### Scenario: Carteira com dados
- **WHEN** o usuário possui ativos em mais de uma categoria
- **THEN** o gráfico exibe cada categoria com seu percentual e valor

#### Scenario: Carteira vazia
- **WHEN** o usuário não possui ativos
- **THEN** o dashboard exibe um estado vazio com convite para cadastrar o primeiro ativo

### Requirement: Evolução patrimonial
O dashboard SHALL exibir a evolução do patrimônio total ao longo do tempo em um período selecionável.

#### Scenario: Seleção de período
- **WHEN** o usuário seleciona "12 meses"
- **THEN** o gráfico mostra pontos de patrimônio dos últimos 12 meses

### Requirement: Indicadores-resumo
O dashboard SHALL exibir patrimônio total, total investido, resultado (valor e percentual) e proventos recebidos no mês.

#### Scenario: Cálculo de resultado
- **WHEN** o valor atual é maior que o total investido
- **THEN** o resultado é exibido como positivo com valor e percentual corretos

### Requirement: Alerta de desbalanceamento
O dashboard SHALL sinalizar categorias cuja alocação diverge da meta do usuário além de uma tolerância configurável.

#### Scenario: Categoria acima da meta
- **WHEN** uma categoria excede sua meta além da tolerância
- **THEN** ela é destacada com a diferença em pontos percentuais

### Requirement: Acessibilidade e responsividade
Os gráficos SHALL oferecer alternativa textual/tabular e SHALL ser utilizáveis em telas móveis.

#### Scenario: Leitura em tabela
- **WHEN** o usuário alterna para a visão tabular
- **THEN** os mesmos dados do gráfico são exibidos em tabela
