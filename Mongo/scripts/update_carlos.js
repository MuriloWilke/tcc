print("--- EXECUTANDO UPDATE EM 'Carlos Lima' ---");
db.getSiblingDB("tcc_rh").getCollection("funcionario").updateOne(
  { nome: "Carlos Lima" },
  { $set: { salario: NumberDecimal("7777.77") } }
);
print("--> Update executado.");