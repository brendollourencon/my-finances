# Spec Delta

## Purpose

Manter atualizados os dados de mercado de ações e FIIs (cotação e indicadores) por meio de um crawler agendado, de forma resiliente e substituível.

## ADDED Requirements

### Requirement: Coleta agendada de dados
O sistema SHALL executar periodicamente a coleta de cotação e indicadores (ex.: P/L, P/VP, dividend yield) dos tickers presentes nas carteiras e na lista de observação, a partir do Investidor10.

#### Scenario: Execução agendada
- **WHEN** o horário agendado é atingido
- **THEN** os dados dos tickers monitorados são coletados e persistidos com data/hora da coleta

#### Scenario: Execução manual
- **WHEN** um administrador dispara a coleta manualmente
- **THEN** a coleta executa com as mesmas regras do agendamento

### Requirement: Cortesia com a fonte
O crawler SHALL respeitar limite de requisições, identificar-se com User-Agent e honrar o `robots.txt` da fonte.

#### Scenario: Limite de taxa
- **WHEN** há muitos tickers para coletar
- **THEN** as requisições são espaçadas conforme o limite configurado

### Requirement: Tolerância a falhas
Uma falha na coleta de um ticker SHALL NOT interromper os demais nem apagar o último dado válido, e SHALL ser registrada com motivo.

#### Scenario: Página com layout alterado
- **WHEN** o parser não encontra um campo esperado
- **THEN** o ticker é marcado como falho, o último dado válido é mantido e o erro é registrado

#### Scenario: Nova tentativa
- **WHEN** ocorre erro transitório de rede
- **THEN** a coleta é repetida com espera crescente até um limite de tentativas

### Requirement: Histórico e frescor dos dados
O sistema SHALL guardar histórico de cotações e indicadores e expor a data da última atualização bem-sucedida por ticker.

#### Scenario: Consulta de frescor
- **WHEN** um consumidor pede os dados de um ticker
- **THEN** recebe valores e a data da última atualização

### Requirement: Fonte substituível
A origem dos dados SHALL ser acessada por uma abstração, de modo que trocar o Investidor10 por outra fonte não altere regras de domínio nem contratos expostos.

#### Scenario: Troca de provedor
- **WHEN** outro provedor é configurado
- **THEN** cotações e indicadores continuam sendo ingeridos no mesmo formato
