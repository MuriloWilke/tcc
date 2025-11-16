#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE TABLE departamento (
        id INT PRIMARY KEY,
        nome_departamento VARCHAR(50) NOT NULL
    );

    CREATE TABLE funcionario (
        id INT PRIMARY KEY,
        nome_funcionario VARCHAR(50) NOT NULL,
        salario NUMERIC(10, 2),
        id_departamento INT,
        CONSTRAINT fk_departamento
            FOREIGN KEY(id_departamento) 
            REFERENCES departamento(id)
    );

    INSERT INTO departamento (id, nome_departamento) VALUES (1, 'Vendas');
    INSERT INTO departamento (id, nome_departamento) VALUES (2, 'Engenharia');
    INSERT INTO departamento (id, nome_departamento) VALUES (3, 'Marketing');

    INSERT INTO funcionario (id, nome_funcionario, id_departamento) VALUES (101, 'Ana Silva', 1);
    INSERT INTO funcionario (id, nome_funcionario, id_departamento) VALUES (102, 'Bruno Costa', 1);
    INSERT INTO funcionario (id, nome_funcionario, id_departamento) VALUES (201, 'Carlos Lima', 2);
    INSERT INTO funcionario (id, nome_funcionario, id_departamento) VALUES (202, 'Diana Souza', 2);
    INSERT INTO funcionario (id, nome_funcionario, id_departamento) VALUES (301, 'Eduardo Faria', 3);
    INSERT INTO funcionario (id, nome_funcionario, id_departamento) VALUES (302, 'Fernanda Mota', 3);

    UPDATE funcionario SET salario = (id_departamento * 1500.00) + 2000.00;

    CREATE PUBLICATION pub_tcc FOR TABLE departamento, funcionario;
EOSQL