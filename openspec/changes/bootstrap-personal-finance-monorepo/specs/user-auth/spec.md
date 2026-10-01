# Spec Delta

## Purpose

Permitir que usuários se cadastrem e se autentiquem com segurança, garantindo que cada usuário acesse somente os seus próprios dados.

## ADDED Requirements

### Requirement: Cadastro de usuário
O sistema SHALL permitir o cadastro com nome, e-mail único e senha que atenda a uma política mínima, armazenando a senha apenas como hash com sal.

#### Scenario: Cadastro válido
- **WHEN** um visitante envia nome, e-mail inédito e senha válida
- **THEN** a conta é criada e a senha nunca é retornada nem armazenada em texto puro

#### Scenario: E-mail já utilizado
- **WHEN** o e-mail informado já existe
- **THEN** o cadastro é recusado com erro de conflito

#### Scenario: Senha fraca
- **WHEN** a senha não atende à política
- **THEN** o cadastro é recusado com erro de validação descrevendo o problema

### Requirement: Login e emissão de tokens
O sistema SHALL autenticar por e-mail e senha e emitir um token de acesso de curta duração e um token de renovação revogável.

#### Scenario: Credenciais corretas
- **WHEN** o usuário envia credenciais válidas
- **THEN** recebe token de acesso e de renovação

#### Scenario: Credenciais incorretas
- **WHEN** e-mail ou senha estão incorretos
- **THEN** a resposta é não autorizado, sem revelar qual campo falhou

#### Scenario: Tentativas excessivas
- **WHEN** há muitas tentativas de login falhas em curto período para o mesmo alvo
- **THEN** novas tentativas são temporariamente bloqueadas

### Requirement: Renovação e logout
O sistema SHALL permitir renovar o token de acesso com um token de renovação válido e invalidar o token de renovação no logout.

#### Scenario: Renovação válida
- **WHEN** um token de renovação válido é apresentado
- **THEN** um novo token de acesso é emitido

#### Scenario: Token revogado
- **WHEN** um token de renovação já invalidado por logout é apresentado
- **THEN** a renovação é recusada

### Requirement: Isolamento de dados por usuário
O sistema SHALL restringir todo acesso a dados de domínio ao usuário autenticado proprietário, negando acesso sem token válido.

#### Scenario: Acesso sem autenticação
- **WHEN** uma rota protegida é chamada sem token válido
- **THEN** a resposta é não autorizado

#### Scenario: Acesso a recurso de outro usuário
- **WHEN** o usuário A tenta ler ou alterar um ativo do usuário B
- **THEN** o recurso é tratado como inexistente (não encontrado)
