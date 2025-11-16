print("--- EXECUTANDO CENARIO 2: ROLLBACK ---");

(async () => {
    const session = db.getMongo().startSession();
    const funcCollection = session.getDatabase('tcc_rh').getCollection('funcionario');

    session.startTransaction();
    try {
        await funcCollection.updateOne(
            { _id: 101, id_filial: 1 },
            { $set: { salario: NumberDecimal('9999.00') } }
        );

        const divisor = 0;
        const resultado = 1 / divisor;
        print("--> Resultado da divisao:", resultado);

        if (!isFinite(resultado)) {
            throw new Error("Erro: tentativa de divisão por zero detectada!");
        }

        await funcCollection.updateOne(
            { _id: 301, id_filial: 2 },
            { $mul: { salario: resultado } },
            { session }
        );

        await session.commitTransaction();
        print("--> Transação commitada (NÃO deveria acontecer aqui)");
    } catch (error) {
        print('--> Ocorreu um erro, abortando a transacao!');
        printjson(error);
        await session.abortTransaction();
    } finally {
        await session.endSession();
    }

    print("\nVERIFICACAO DO ROLLBACK:");
    const resultado = db.getSiblingDB('tcc_rh')
        .getCollection('funcionario')
        .find({ _id: { $in: [101, 301] } })
        .toArray();
    printjson(resultado);
})();
