#!/bin/bash
set -e

# Função para verificar se um host está pronto para receber comandos
wait_for_mongo() {
  local host=$1
  echo "Aguardando o host '$host' ficar pronto..."
  until mongosh --host "$host" --eval "db.adminCommand('ping')" &>/dev/null; do
    echo -n "."
    sleep 2
  done
  echo " Host '$host' está pronto!"
}

# Espera os nós principais de cada replica set ficarem disponíveis
wait_for_mongo "cfg-1:27017"
wait_for_mongo "shard-a-1:27017"
wait_for_mongo "shard-b-1:27017"

echo "Iniciando a configuração dos Replica Sets..."

# Inicia o Replica Set dos Servidores de Configuração
mongosh --host cfg-1:27017 <<EOF
rs.initiate({ 
    _id: 'rs-config', 
    configsvr: true, 
    members: [
        { _id: 0, host: 'cfg-1:27017' }, 
        { _id: 1, host: 'cfg-2:27017' }, 
        { _id: 2, host: 'cfg-3:27017' }
    ]
})
EOF

# Inicia o Replica Set do Shard A
mongosh --host shard-a-1:27017 <<EOF
rs.initiate({ 
    _id: 'rs-shard-a', 
    members: [
        { _id: 0, host: 'shard-a-1:27017' }, 
        { _id: 1, host: 'shard-a-2:27017' },
    ]
})
EOF

# Inicia o Replica Set do Shard B
mongosh --host shard-b-1:27017 <<EOF
rs.initiate({ 
    _id: 'rs-shard-b', 
    members: [
        { _id: 0, host: 'shard-b-1:27017' }, 
        { _id: 1, host: 'shard-b-2:27017' }
    ]
})
EOF

# Espera os Replica Sets elegerem um primário
echo "Aguardando 20 segundos para a eleição dos primários..."
sleep 20

# Espera o roteador mongos ficar disponível.
wait_for_mongo "mongos:27017"

echo "Adicionando shards ao cluster..."

mongosh --host mongos:27017 --eval "sh.addShard('rs-shard-a/shard-a-1:27017'); sh.addShard('rs-shard-b/shard-b-1:27017');"

echo "Configurando o banco de dados 'tcc_rh' para os testes..."

mongosh --host mongos:27017 <<EOF

const NOME_DO_BANCO = "tcc_rh";
const COLECAO_PRINCIPAL = "funcionario";
const COLECAO_SECUNDARIA = "departamento";
const SHARD_KEY = { id_filial: 1 };

use(NOME_DO_BANCO);

// Cria as coleções
db.createCollection(COLECAO_PRINCIPAL);
db.createCollection(COLECAO_SECUNDARIA);

// Habilita o sharding para o banco
sh.enableSharding(NOME_DO_BANCO);

// Distribui a coleção 'funcionario' pela 'id_filial'
sh.shardCollection(NOME_DO_BANCO + "." + COLECAO_PRINCIPAL, SHARD_KEY);

print("Sharding configurado para a coleção: " + COLECAO_PRINCIPAL);

// Insere os dados de departamento
db.departamento.insertMany([
    { _id: 1, nome: "TI", sigla: "TI" },
    { _id: 2, nome: "Recursos Humanos", sigla: "RH" },
    { _id: 3, nome: "Financeiro", sigla: "FIN" }
]);

// Insere os dados de funcionário, com id_filial para distribuição
db.funcionario.insertMany([
    { _id: 101, nome: "Ana Silva", salario: NumberDecimal("3500.00"), id_departamento: 1, id_filial: 1 },
    { _id: 102, nome: "Bruno Costa", salario: NumberDecimal("3500.00"), id_departamento: 1, id_filial: 1 },
    { _id: 201, nome: "Carlos Lima", salario: NumberDecimal("5000.00"), id_departamento: 2, id_filial: 1 },
    { _id: 202, nome: "Diana Souza", salario: NumberDecimal("5000.00"), id_departamento: 2, id_filial: 1 },
    { _id: 301, nome: "Eduardo Faria", salario: NumberDecimal("6500.00"), id_departamento: 3, id_filial: 2 },
    { _id: 302, nome: "Fernanda Mota", salario: NumberDecimal("6500.00"), id_departamento: 3, id_filial: 2 },
    { _id: 401, nome: "Gabriel Pires", salario: NumberDecimal("8000.00"), id_departamento: 3, id_filial: 2 },
    { _id: 402, nome: "Helena Rosa", salario: NumberDecimal("8000.00"), id_departamento: 3, id_filial: 2 }
]);

print("Dados de exemplo inseridos com sucesso!");
EOF

echo "Cluster e banco de dados configurados!"