#!/bin/bash
set -e

/usr/local/bin/docker-entrypoint.sh postgres &
pid="$!"

echo "Subscriber: Aguardando o servidor PostgreSQL local iniciar..."

until pg_isready -h localhost -p 5432 -U postgres; do
  sleep 2
done
echo "Subscriber: Servidor local iniciado."

if [ "$(psql -U postgres -qtAX -c "SELECT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename  = 'funcionario');")" = "t" ]; then
    echo "Subscriber: Banco de dados ja inicializado. Pulando a criacao de tabelas e assinatura."
else
    echo "Subscriber: Banco de dados nao inicializado. Configurando..."
    echo "Subscriber: Aguardando o Publisher (pg_publisher) ficar pronto..."
    until pg_isready -h pg_publisher -p 5432 -U postgres; do
      sleep 2
    done
    echo "Subscriber: Publisher pronto."

    echo "Subscriber: Criando tabelas e assinatura..."
    psql -v ON_ERROR_STOP=1 --username "postgres" <<-EOSQL
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

        CREATE SUBSCRIPTION sub_tcc 
            CONNECTION 'host=pg_publisher port=5432 user=postgres password=postgres dbname=postgres' 
            PUBLICATION pub_tcc;
EOSQL
    echo "Subscriber: Configuracao inicial concluida."
fi

wait "$pid"