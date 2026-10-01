-- Executado apenas na primeira inicialização do volume do MariaDB.
-- O banco principal e o usuário da aplicação são criados pelas variáveis MARIADB_* do compose.
-- Aqui criamos o banco usado pelos testes de integração e damos acesso ao usuário da aplicação.
CREATE DATABASE IF NOT EXISTS my_finances_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON my_finances_test.* TO 'finances'@'%';
FLUSH PRIVILEGES;
