print("--- VERIFICANDO UPDATE NO NO RECUPERADO ---");
db.getMongo().setReadPref('secondary');
const resultado = db.getSiblingDB("tcc_rh").getCollection("funcionario").findOne(
  { nome: "Carlos Lima" },
  { salario: 1 }
);
printjson(resultado);