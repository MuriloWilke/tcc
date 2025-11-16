print("--- EXECUTANDO CENARIO 3: COMMIT ---");

(async () => {
    const session = db.getMongo().startSession();
    const funcCollection = session.getDatabase('tcc_rh').getCollection('funcionario');

    session.startTransaction();
    try {
        await funcCollection.updateOne(
            { _id: 102, id_filial: 1 },
            { $set: { salario: NumberDecimal('5500.00') } }
        );
        await funcCollection.updateOne(
            { _id: 301, id_filial: 2 },
            { $set: { salario: NumberDecimal('8500.00') } }
        );
        await session.commitTransaction();
        print("--> Transação commitada com sucesso!");
    } catch (error) {
        print("--> Ocorreu um erro inesperado, abortando a transação!");
        printjson(error);
        await session.abortTransaction();
    } finally {
        await session.endSession();
    }

    print("\nVERIFICAÇÃO DO COMMIT:");
    const resultado = db.getSiblingDB('tcc_rh')
        .getCollection('funcionario')
        .find({ _id: { $in: [102, 301] } })
        .toArray();
    printjson(resultado);
})();
