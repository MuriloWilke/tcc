import com.mongodb.client.MongoClient
import com.mongodb.client.MongoCollection
import org.bson.Document
import java.math.BigDecimal
import java.util.Random
import java.util.Date
import java.util.Arrays
import org.bson.types.Decimal128

MongoClient mongoClient = props.get("mongoClientGlobal")

if (mongoClient == null) {
    SampleResult.setSuccessful(false)
    SampleResult.setResponseMessage("Erro: MongoClient não foi inicializado pelo setUp Thread Group")
    return
}

try {
    MongoCollection<Document> collection = mongoClient.getDatabase("tcc_ecommerce").getCollection("pedidos")
    
    int[] filiais = [1001, 2001]
    int clienteId = filiais[new Random().nextInt(filiais.length)]
    int produtoId = new Random().nextInt(3) + 1

    Document pedido = new Document()
        .append("id_cliente", clienteId)
        .append("data_pedido", new Date())
        .append("status", "PROCESSANDO")
        .append("itens", Arrays.asList(
            new Document("id_produto", produtoId)
                .append("quantidade", 1)
                .append("preco_unidade", new Decimal128(new BigDecimal("100.00")))
        ));
    
    collection.insertOne(pedido)
    
    SampleResult.setSuccessful(true)
    SampleResult.setResponseMessage("Pedido inserido para cliente " + clienteId)
    
} catch (Exception e) {
    SampleResult.setSuccessful(false)
    SampleResult.setResponseMessage("Erro: " + e.getMessage())
    log.error("Erro ao inserir no Mongo: ", e)
}