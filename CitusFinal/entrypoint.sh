#!/bin/bash
set -e

if [ -z "$(ls -A "$PGDATA")" ]; then
    gosu postgres initdb
fi

sed -i -e "/^max_connections =/d" "$PGDATA/postgresql.conf"
sed -i -e "/^max_locks_per_transaction =/d" "$PGDATA/postgresql.conf"
sed -i -e "/^listen_addresses =/d" "$PGDATA/postgresql.conf"
sed -i -e "/^shared_preload_libraries =/d" "$PGDATA/postgresql.conf"

echo "max_connections = 300" >> "$PGDATA/postgresql.conf"
echo "max_locks_per_transaction = 128" >> "$PGDATA/postgresql.conf"
echo "listen_addresses = '*'" >> "$PGDATA/postgresql.conf"
echo "shared_preload_libraries = 'citus'" >> "$PGDATA/postgresql.conf"

sed -i -e "/0.0.0.0\/0 trust/d" "$PGDATA/pg_hba.conf"
sed -i '1i host all all 0.0.0.0/0 trust' "$PGDATA/pg_hba.conf"

gosu postgres postgres &
pid="$!"

until pg_isready -h localhost -p 5432 -U postgres; do
  sleep 1
done

psql -v ON_ERROR_STOP=1 --username "postgres" --dbname "postgres" -c "CREATE EXTENSION IF NOT EXISTS citus;"

if [ "$CITUS_ROLE" = "coordinator" ]; then
    echo "Nó Coordenador detectado. Iniciando configuração do cluster..."

    echo "Aguardando workers ficarem prontos..."
    until \
      (psql -h worker-1 -U postgres -d postgres -t -c "\dx citus" 2>/dev/null | grep -q "citus") && \
      (psql -h worker-2 -U postgres -d postgres -t -c "\dx citus" 2>/dev/null | grep -q "citus")
    do
      echo "Workers ainda não estão prontos (aguardando a extensão Citus)..."
      sleep 2
    done
    echo "Workers estão prontos."

    if [ "$(psql -U postgres -d postgres -tAc "SELECT 1 FROM pg_tables WHERE tablename = 'pedidos'")" != "1" ]; then
        echo "Adicionando workers e configurando o banco de dados..."
        psql -v ON_ERROR_STOP=1 --username "postgres" --dbname "postgres" <<-EOSQL
            SELECT citus_add_node('worker-1', 5432);
            SELECT citus_add_node('worker-2', 5432);

            SET citus.shard_replication_factor = 1;

            CREATE TABLE produtos (
                id INT PRIMARY KEY,
                nome VARCHAR(100) NOT NULL,
                categoria VARCHAR(50),
                preco NUMERIC(10, 2)
            );

            CREATE TABLE clientes (
                id INT PRIMARY KEY,
                nome VARCHAR(100)
            );

            CREATE TABLE pedidos (
                id INT NOT NULL,
                id_cliente INT NOT NULL REFERENCES clientes(id),
                data_pedido TIMESTAMPTZ DEFAULT now(),
                status VARCHAR(20),
                PRIMARY KEY (id_cliente, id)
            );

            CREATE TABLE itens_pedido (
                id INT NOT NULL,
                id_pedido INT NOT NULL,
                id_cliente INT NOT NULL,
                id_produto INT REFERENCES produtos(id),
                quantidade INT,
                preco_unidade NUMERIC(10, 2),
                PRIMARY KEY (id_cliente, id_pedido, id),
                FOREIGN KEY (id_cliente, id_pedido) REFERENCES pedidos(id_cliente, id)
            );

            CREATE SEQUENCE pedidos_id_seq;
            CREATE SEQUENCE itens_pedido_id_seq;
            
            SELECT create_reference_table('produtos');
            SELECT create_reference_table('clientes');
            SELECT create_distributed_table('pedidos', 'id_cliente');
            SELECT create_distributed_table('itens_pedido', 'id_cliente');

            INSERT INTO produtos (id, nome, categoria, preco)
            SELECT
                i,
                'Produto ' || i,
                CASE (i % 10)
                    WHEN 0 THEN 'Eletronicos'
                    WHEN 1 THEN 'Livros'
                    WHEN 2 THEN 'Roupas'
                    WHEN 3 THEN 'Alimentos'
                    WHEN 4 THEN 'Esportes'
                    WHEN 5 THEN 'Moveis'
                    WHEN 6 THEN 'Brinquedos'
                    WHEN 7 THEN 'Ferramentas'
                    WHEN 8 THEN 'Cosmeticos'
                    ELSE 'Outros'
                END,
                (random() * 1000 + 50)::numeric(10, 2)
            FROM generate_series(1, 100000) AS i;

            INSERT INTO clientes (id, nome)
            SELECT i, 'Cliente ' || i FROM generate_series(1, 10000) AS i;

            INSERT INTO pedidos (id, id_cliente, status) VALUES
            (nextval('pedidos_id_seq'), 1, 'PAGO'),
            (nextval('pedidos_id_seq'), 2, 'ENVIADO');

            INSERT INTO itens_pedido (id, id_pedido, id_cliente, id_produto, quantidade, preco_unidade) VALUES
            (nextval('itens_pedido_id_seq'), 1, 1, 1, 1, 5000.00),
            (nextval('itens_pedido_id_seq'), 2, 2, 3, 2, 120.00);

EOSQL
        echo "Cluster configurado e dados populados."
    else
        echo "Cluster já configurado."
    fi
fi

wait "$pid"