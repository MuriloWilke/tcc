import com.mongodb.client.MongoClient

log.info("--- [TearDown] Fechando o MongoClient compartilhado ---")

MongoClient mongoClient = (MongoClient) props.get("mongoClientGlobal")

if (mongoClient != null) {
    mongoClient.close()
    props.remove("mongoClientGlobal")
    log.info("--- [TearDown] MongoClient fechado com sucesso. ---")
} else {
    log.warn("--- [TearDown] Não foi possível encontrar o MongoClient para fechar. ---")
}