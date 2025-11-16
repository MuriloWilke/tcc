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
        { _id: 2, host: 'shard-a-3:27017' }, 
    ]
})
EOF

# Inicia o Replica Set do Shard B
mongosh --host shard-b-1:27017 <<EOF
rs.initiate({ 
    _id: 'rs-shard-b', 
    members: [
        { _id: 0, host: 'shard-b-1:27017' }, 
        { _id: 1, host: 'shard-b-2:27017' },
        { _id: 2, host: 'shard-b-3:27017' }, 

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

echo "Configurando o banco de dados 'tcc_ecommerce' para os testes..."

mongosh --host mongos:27017 <<EOF

const NOME_DO_BANCO = "tcc_ecommerce";
const COLECAO_PEDIDOS = "pedidos";
const COLECAO_PRODUTOS = "produtos";
const SHARD_KEY = { id_cliente: 1 };

use(NOME_DO_BANCO);

// Habilita o sharding para o banco
sh.enableSharding(NOME_DO_BANCO);

// Cria as coleções
db.createCollection(COLECAO_PRODUTOS);
db.createCollection(COLECAO_PEDIDOS);

// Distribui a coleção 'pedidos' pela 'id_cliente'
sh.shardCollection(NOME_DO_BANCO + "." + COLECAO_PEDIDOS, SHARD_KEY);

print("Sharding configurado para a coleção: " + COLECAO_PEDIDOS);

print("Inserindo 100.000 produtos...");
var bulk = [];
var categories = ['Eletronicos', 'Livros', 'Roupas', 'Alimentos', 'Esportes', 'Moveis', 'Brinquedos', 'Ferramentas', 'Cosmeticos', 'Outros'];

for (var i = 1; i <= 100000; i++) {
    bulk.push({
        _id: i,
        nome: "Produto " + i,
        categoria: categories[i % 10], // Lógica idêntica ao Citus (10% Eletronicos)
        preco: NumberDecimal("100.00") // Preço fixo para simplificar
    });

    // Insere em lotes de 1000 para ser rápido
    if (i % 1000 == 0) {
        db.produtos.insertMany(bulk);
        bulk = [];
    }
}
// Insere o lote final se sobrar algum
if (bulk.length > 0) {
    db.produtos.insertMany(bulk);
}
print("100.000 produtos inseridos com sucesso!");

// Insere dados de exemplo na coleção de pedidos (denormalizada)
db.pedidos.insertMany([
    {
        _id: 1,
        id_cliente: 1001,
        data_pedido: new Date(),
        status: "PAGO",
        itens: [
            { id_produto: 1, nome: "Notebook Pro", quantidade: 1, preco_unidade: NumberDecimal("5000.00") },
            { id_produto: 2, nome: "Mouse Gamer", quantidade: 1, preco_unidade: NumberDecimal("250.00") }
        ]
    },
    {
        _id: 2,
        id_cliente: 2001,
        data_pedido: new Date(),
        status: "ENVIADO",
        itens: [
            { id_produto: 3, nome: "Livro SQL", quantidade: 2, preco_unidade: NumberDecimal("120.00") }
        ]
    }
]);

print("Dados de e-commerce inseridos com sucesso!");
EOF

echo "Cluster e banco de dados configurados!"