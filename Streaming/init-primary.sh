#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL

    CREATE ROLE replicator WITH LOGIN SUPERUSER REPLICATION PASSWORD 'pass_replicacao';
    SELECT * FROM pg_create_physical_replication_slot('standby1_slot');
    SELECT * FROM pg_create_physical_replication_slot('standby2_slot');

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

EOSQL

echo "host replication replicator all scram-sha-256" >> "$PGDATA/pg_hba.conf"