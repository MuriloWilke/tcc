BEGIN;
DO $$
DECLARE
    v_cliente_id INT := (floor(random() * 2) + 1) * 1000 + 1;
    v_produto_id INT := (floor(random() * 3) + 1);
    v_novo_pedido_id INT;
BEGIN
    INSERT INTO pedidos (id, id_cliente, status) 
    VALUES (nextval('pedidos_id_seq'), v_cliente_id, 'PROCESSANDO')
    RETURNING id INTO v_novo_pedido_id;

    INSERT INTO itens_pedido (id, id_pedido, id_cliente, id_produto, quantidade, preco_unidade) 
    VALUES (nextval('itens_pedido_id_seq'), v_novo_pedido_id, v_cliente_id, v_produto_id, 1, 100.00);
END $$;
COMMIT;