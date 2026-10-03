git add README.md
git commit -m "Fix: integrando todos os links de imagens, dados e documentacao"
git push origin main

DROP TABLE IF EXISTS dw.fact_pedidos CASCADE;
DROP TABLE IF EXISTS dw.dim_video CASCADE;
DROP TABLE IF EXISTS dw.dim_tempo CASCADE;
DROP TABLE IF EXISTS dw.dim_metodo_pagamento CASCADE;
DROP TABLE IF EXISTS dw.dim_status_pedido CASCADE;

CREATE SCHEMA IF NOT EXISTS dw;

-- =========================================================
-- 1. DIMENSÃO TEMPO

CREATE TABLE dw.dim_tempo (
    sk_tempo      SERIAL PRIMARY KEY,
    data          DATE NOT NULL UNIQUE,
    dia           INT,
    mes           INT,
    trimestre     INT,
    ano           INT,
    dia_semana    VARCHAR(15)
);

INSERT INTO dw.dim_tempo (data, dia, mes, trimestre, ano, dia_semana)
SELECT d::date,
       EXTRACT(DAY FROM d),
       EXTRACT(MONTH FROM d),
       EXTRACT(QUARTER FROM d),
       EXTRACT(YEAR FROM d),
       TO_CHAR(d, 'FMDay')
FROM generate_series('2024-01-01'::date, '2027-12-31'::date, interval '1 day') d;

-- =========================================================
-- 2. DIMENSÃO VÍDEO

CREATE TABLE dw.dim_video (
    sk_video               SERIAL PRIMARY KEY,
    id_video               VARCHAR(50) NOT NULL UNIQUE,
    id_autor               VARCHAR(50),
    autor                  VARCHAR(150),
    categoria              VARCHAR(100),
    descricao              TEXT,
    pais                   VARCHAR(100),
    data_publicacao        DATE,
    duracao_segundos       NUMERIC,
    views                  NUMERIC,
    likes                  NUMERIC,
    comentarios            NUMERIC,
    compartilhamentos      NUMERIC,
    salvamentos            NUMERIC,
    seguidores_autor       NUMERIC,
    hashtags               TEXT,
    faixa_engajamento      VARCHAR(30),
    genero_publico         VARCHAR(30),
    faixa_etaria_publico   VARCHAR(30)
);

INSERT INTO dw.dim_video (id_video, id_autor, autor, categoria, descricao, pais,
                          data_publicacao, duracao_segundos, views, likes,
                          comentarios, compartilhamentos, salvamentos,
                          seguidores_autor, hashtags, faixa_engajamento,
                          genero_publico, faixa_etaria_publico)
SELECT DISTINCT ON (id_video)
       id_video, id_autor, autor, categoria, descricao, pais,
       data_publicacao, duracao_segundos, views, likes,
       comentarios, compartilhamentos, salvamentos,
       seguidores_autor, hashtags, classificacao_desempenho,
       genero_publico, faixa_etaria_publico
FROM ods.tik_tok_shop
WHERE id_video IS NOT NULL
ORDER BY id_video;

-- =========================================================
-- 3. DIMENSÃO MÉTODO DE PAGAMENTO

CREATE TABLE dw.dim_metodo_pagamento (
    sk_metodo_pagamento SERIAL PRIMARY KEY,
    metodo_pagamento    VARCHAR(50) UNIQUE
);

INSERT INTO dw.dim_metodo_pagamento (metodo_pagamento)
SELECT DISTINCT metodo_pagamento
FROM ods.tik_tok_shop
WHERE metodo_pagamento IS NOT NULL;

-- =========================================================
-- 4. DIMENSÃO STATUS DO PEDIDO

CREATE TABLE dw.dim_status_pedido (
    sk_status_pedido SERIAL PRIMARY KEY,
    status_pedido    VARCHAR(50) UNIQUE
);

INSERT INTO dw.dim_status_pedido (status_pedido)
SELECT DISTINCT status_pedido
FROM ods.tik_tok_shop
WHERE status_pedido IS NOT NULL;

-- =========================================================
-- 5. TABELA FATO - PEDIDOS

CREATE TABLE dw.fact_pedidos (
    sk_pedido            SERIAL PRIMARY KEY,
    id_pedido            VARCHAR(50),
    sk_video             INT REFERENCES dw.dim_video(sk_video),
    sk_tempo             INT REFERENCES dw.dim_tempo(sk_tempo),
    sk_metodo_pagamento  INT REFERENCES dw.dim_metodo_pagamento(sk_metodo_pagamento),
    sk_status_pedido     INT REFERENCES dw.dim_status_pedido(sk_status_pedido),
    nome_produto         VARCHAR(150),
    categoria_produto    VARCHAR(100),
    preco_unitario_brl   NUMERIC(10,2),
    quantidade           INT,
    valor_total_brl      NUMERIC(12,2),
    desconto_percentual  NUMERIC(5,2),
    cupom_aplicado       VARCHAR(5),
    avaliacao            NUMERIC(3,1),
    taxa_engajamento     NUMERIC(6,2)
);

INSERT INTO dw.fact_pedidos (id_pedido, sk_video, sk_tempo, sk_metodo_pagamento, sk_status_pedido,
                             nome_produto, categoria_produto, preco_unitario_brl, quantidade,
                             valor_total_brl, desconto_percentual, cupom_aplicado, avaliacao,
                             taxa_engajamento)
SELECT p.id_pedido,
       v.sk_video,
       t.sk_tempo,
       mp.sk_metodo_pagamento,
       sp.sk_status_pedido,
       p.nome_produto,
       p.categoria_produto,
       p.preco_unitario_brl,
       p.quantidade,
       p.valor_total_brl,
       p.desconto_percentual,
       p.cupom_aplicado,
       p.avaliacao,
       p.taxa_engajamento
FROM ods.tik_tok_shop p
LEFT JOIN dw.dim_video v            ON v.id_video = p.id_video
LEFT JOIN dw.dim_tempo t            ON t.data = p.data_pedido::date
LEFT JOIN dw.dim_metodo_pagamento mp ON mp.metodo_pagamento = p.metodo_pagamento
LEFT JOIN dw.dim_status_pedido sp    ON sp.status_pedido = p.status_pedido;

