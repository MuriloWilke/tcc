import com.mongodb.client.MongoClient
import com.mongodb.client.MongoCollection
import com.mongodb.client.MongoDatabase
import org.bson.Document
import java.util.ArrayList


MongoClient mongoClient = props.get("mongoClientGlobal")

if (mongoClient == null) {
    SampleResult.setSuccessful(false)
    SampleResult.setResponseMessage("Erro: MongoClient não foi inicializado pelo setUp Thread Group")
    return
}

try {
    MongoDatabase database = mongoClient.getDatabase("tcc_ecommerce")
    MongoCollection<Document> collection = database.getCollection("produtos")

    def resultados = collection.find(new Document("categoria", "Eletronicos")).into(new ArrayList<Document>())
    
    SampleResult.setSuccessful(true)
    SampleResult.setResponseMessage("Encontrados " + resultados.size() + " produtos.")
    
} catch (Exception e) {
    SampleResult.setSuccessful(false)
    SampleResult.setResponseMessage("Erro: " + e.getMessage())
    log.error("Erro ao ler do Mongo: ", e)
}