#!/bin/bash
set -e

if [ -z "$(ls -A "$PGDATA")" ]; then
    gosu postgres initdb
    echo "listen_addresses = '*'" >> "$PGDATA/postgresql.conf"
    echo "shared_preload_libraries = 'citus'" >> "$PGDATA/postgresql.conf"
    echo "host all all 0.0.0.0/0 trust" >> "$PGDATA/pg_hba.conf"
fi

gosu postgres postgres &
pid="$!"

until pg_isready -h localhost -p 5432 -U postgres; do
  sleep 1
done

psql -v ON_ERROR_STOP=1 --username "postgres" --dbname "postgres" -c "CREATE EXTENSION IF NOT EXISTS citus;"

if [ "$CITUS_ROLE" = "coordinator" ]; then
    echo "Nó Coordenador detectado. Iniciando configuração do cluster..."

    echo "Aguardando workers ficarem prontos..."
    until pg_isready -h worker-1 -p 5432 -U postgres && pg_isready -h worker-2 -p 5432 -U postgres; do
      echo "Workers ainda não estão prontos..."
      sleep 1
    done
    echo "Workers estão prontos."

    if [ "$(psql -U postgres -d postgres -tAc "SELECT 1 FROM pg_tables WHERE tablename = 'departamento'")" != "1" ]; then
        echo "Adicionando workers e configurando o banco de dados..."
        psql -v ON_ERROR_STOP=1 --username "postgres" --dbname "postgres" <<-EOSQL
            SELECT citus_add_node('worker-1', 5432);
            SELECT citus_add_node('worker-2', 5432);

            SET citus.shard_replication_factor = 1;

            CREATE TABLE departamento (
                id INT PRIMARY KEY,
                nome_departamento VARCHAR(50) NOT NULL
            );

            CREATE TABLE funcionario (
                id INT NOT NULL,
                nome_funcionario VARCHAR(50) NOT NULL,
                salario NUMERIC(10, 2),
                id_departamento INT,
                id_filial INT NOT NULL,
                PRIMARY KEY (id_filial, id),
                CONSTRAINT fk_departamento
                    FOREIGN KEY(id_departamento) 
                    REFERENCES departamento(id)
            );
            
            SELECT create_reference_table('departamento');
            SELECT create_distributed_table('funcionario', 'id_filial');

            INSERT INTO departamento (id, nome_departamento) VALUES (1, 'Vendas'), (2, 'Engenharia'), (3, 'Marketing'), (4, 'Recursos Humanos');
            INSERT INTO funcionario (id, nome_funcionario, id_departamento, id_filial) VALUES (101, 'Ana Silva', 1, 1), (102, 'Bruno Costa', 1, 1), (201, 'Carlos Lima', 2, 1), (202, 'Diana Souza', 2, 1);
            INSERT INTO funcionario (id, nome_funcionario, id_departamento, id_filial) VALUES (301, 'Eduardo Faria', 3, 2), (302, 'Fernanda Mota', 3, 2), (401, 'Gabriel Pires', 4, 2), (402, 'Helena Rosa', 4, 2);

            UPDATE funcionario SET salario = (id_departamento * 1500.00) + 2000.00;

EOSQL
        echo "Cluster configurado e dados populados."
    else
        echo "Cluster já configurado."
    fi
fi

wait "$pid"