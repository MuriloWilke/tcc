print("--- VERIFICANDO UPDATE EM 'Carlos Lima' ---");
const resultado = db.getSiblingDB("tcc_rh").getCollection("funcionario").findOne(
  { nome: "Carlos Lima" },
  { salario: 1 }
);
printjson(resultado);