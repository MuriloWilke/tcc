import com.mongodb.client.MongoClients
import com.mongodb.client.MongoClient

log.info("--- [Setup] Criando o MongoClient compartilhado ---")

MongoClient mongoClient = MongoClients.create("mongodb://localhost:27017/")
mongoClient.getDatabase("admin").runCommand(new org.bson.Document("ping", 1))
props.put("mongoClientGlobal", mongoClient)

log.info("--- [Setup] MongoClient criado e compartilhado com sucesso! ---")