# Spec Delta

## Purpose

Sugerir ao usuário, a cada mês, em quais categorias e ativos aportar, com base em metas de alocação e indicadores, de forma explicável e educacional.

## ADDED Requirements

### Requirement: Metas de alocação
O sistema SHALL permitir ao usuário definir metas percentuais por categoria que somem 100%.

#### Scenario: Metas inválidas
- **WHEN** as metas somam diferente de 100%
- **THEN** o salvamento é recusado com erro de validação

### Requirement: Sugestão mensal de categorias
O sistema SHALL, dado um valor de aporte informado, sugerir a distribuição entre categorias priorizando as mais abaixo da meta.

#### Scenario: Categoria abaixo da meta
- **WHEN** FIIs estão abaixo da meta e o usuário informa um aporte
- **THEN** a sugestão destina a maior parcela do aporte a FIIs

#### Scenario: Carteira já balanceada
- **WHEN** todas as categorias estão dentro da tolerância
- **THEN** o aporte é distribuído proporcionalmente às metas

### Requirement: Sugestão de ativos com justificativa
O sistema SHALL listar, por categoria sugerida, ativos ranqueados a partir dos indicadores ingeridos, e cada sugestão SHALL incluir a justificativa (critérios e valores usados).

#### Scenario: Justificativa visível
- **WHEN** o usuário abre uma sugestão
- **THEN** vê os indicadores e regras que levaram àquele ranking

#### Scenario: Dados desatualizados
- **WHEN** os dados de mercado estão mais antigos que o limite de frescor
- **THEN** a sugestão exibe aviso de dados desatualizados e a data da última atualização

### Requirement: Aviso de caráter educacional
Toda tela de recomendação SHALL informar que o conteúdo é educacional e não constitui aconselhamento financeiro.

#### Scenario: Aviso presente
- **WHEN** a tela de recomendações é exibida
- **THEN** o aviso é visível

### Requirement: Histórico de recomendações
O sistema SHALL guardar as recomendações geradas por mês para consulta posterior.

#### Scenario: Consulta de mês anterior
- **WHEN** o usuário seleciona um mês passado
- **THEN** vê a recomendação gerada naquele mês
