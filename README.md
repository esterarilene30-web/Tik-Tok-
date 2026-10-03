# TikTok Analytics: pipeline de dados com TikTok + TikTok Shop

Projeto de dados de ponta a ponta que liga o **desempenho de vídeos do TikTok** às **vendas do TikTok Shop**. O elo entre os dois conjuntos de dados é o `id_video`: cada pedido é associado ao vídeo que o gerou, o que permite analisar conteúdo, engajamento e resultado comercial juntos.

> **Aviso:** os dados deste projeto são **fictícios (sintéticos)**, criados para estudo. Os nomes de criadores que aparecem no dashboard não representam métricas reais dessas pessoas.

## Perguntas que o projeto responde

- Quais vídeos e criadores estão associados a mais pedidos?
- Quais categorias de produto e de conteúdo aparecem mais nos pedidos?
- Como os pedidos e o valor das vendas se distribuem ao longo do tempo?
- Qual é a situação dos pedidos (entregue, em transporte, cancelado etc.)?
- Existe relação entre o engajamento de um vídeo e as vendas?

## Arquitetura

```
CSV (vídeos) + XML (pedidos)
        │  Pentaho (Spoon): validação, ordenação e Merge join
        ▼
ODS (PostgreSQL)  ──►  ods.tik_tok_shop
                       ods.video_alto / video_medio / video_baixo
        │  SQL
        ▼
Data Warehouse (schema dw, modelo estrela)
        │
        ▼
Power BI (dashboard TIK TOK ANALYTICS)
```

## Ferramentas

| Etapa | Ferramenta |
|---|---|
| Extração e transformação | Pentaho Data Integration (Spoon) |
| Armazenamento | PostgreSQL 18 (pgAdmin 4) |
| Modelagem | Modelo dimensional em estrela (SQL) |
| Visualização | Power BI (DirectQuery) |

## Dados de origem

- **Vídeos (CSV):** 500 vídeos, com autor, categoria, descrição, país, data de publicação, duração, views, likes, comentários, compartilhamentos, salvamentos, seguidores, hashtags, taxa de engajamento, classificação de desempenho e perfil do público.
- **Pedidos (XML):** 1.524 pedidos de 01/01/2026 a 28/07/2026, com produto, categoria, preço, quantidade, valor total, desconto, cupom, método de pagamento, status, avaliação e data.
- Dos 500 vídeos, **89 não têm nenhum pedido**, de propósito, para comparar conteúdos que vendem com conteúdos que não vendem.

## Pipeline no Pentaho

![Transformação no Pentaho](imagens/pentaho_transformacao.png)

A transformação tem três blocos, que devem rodar em sequência (PUBLIC, depois ODS, depois TRATAMENTO), porque cada um lê a tabela gravada pelo anterior:

| Bloco | O que faz |
|---|---|
| PUBLIC | Lê o CSV e o XML, padroniza e valida os dados, ordena os dois fluxos por `id_video` e junta tudo com um **Merge join** (LEFT OUTER) |
| ODS | Carrega o resultado em `ods.tik_tok_shop` |
| TRATAMENTO | Trata nulos, filtra e classifica os vídeos em Alto, Médio e Baixo (Number range e Switch / case), gravando em `ods.video_alto`, `ods.video_medio` e `ods.video_baixo` |

Todos os Table output usam **Truncate table**, para que rodar a transformação mais de uma vez não duplique linhas.

## Data Warehouse

Modelo estrela no schema `dw`, criado pelo script [`sql/tiktok_dataset.sql`](sql/tiktok_dataset.sql):

| Tabela | Descrição |
|---|---|
| `dw.dim_tempo` | Uma linha por dia, de 2024 a 2027: dia, mês, trimestre, ano e dia da semana |
| `dw.dim_video` | Um registro por `id_video`, com dados do vídeo, do autor e do público |
| `dw.dim_metodo_pagamento` | Métodos de pagamento |
| `dw.dim_status_pedido` | Status dos pedidos |
| `dw.fact_pedidos` | Fato: pedidos com chaves das quatro dimensões, produto, quantidade, valores, desconto, cupom, avaliação e taxa de engajamento |

A fato guarda também uma linha para cada vídeo sem pedido (1.524 pedidos + 89 vídeos sem pedido = 1.613 linhas), para que esses vídeos entrem na análise. Para contar apenas pedidos, use a contagem de `id_pedido`.

```
            dim_tempo
                │
dim_video ── fact_pedidos ── dim_metodo_pagamento
                │
         dim_status_pedido
```

## Dashboard

O dashboard **TIK TOK ANALYTICS** tem capa e quatro páginas de análise.

| Página | Conteúdo |
|---|---|
| 01 Visão Geral | Indicadores de vendas, faixas de engajamento, produtos, tipos de conteúdo e valor por trimestre |
| 02 Conteúdo & Engajamento | Likes, views, engajamento por conteúdo e por criador, tabela de vídeos e vídeos com pedidos por mês |
| 03 Pagamentos & Pedidos | Valor e quantidade de pedidos por mês e distribuição por status |
| 04 Relatório Geral | Visão consolidada com hashtags, categorias de produto e atalhos para Canva e Google Docs |

![Capa do dashboard](imagens/dashboard_00_capa.png)
![Visão Geral](imagens/dashboard_01_visao_geral.png)
![Conteúdo e Engajamento](imagens/dashboard_02_conteudo_engajamento.png)
![Pagamentos e Pedidos](imagens/dashboard_03_pagamentos_pedidos.png)
![Relatório Geral](imagens/dashboard_04_relatorio_geral.png)

### Alguns números do dashboard

- 1.524 pedidos e R$ 199 mil em vendas de janeiro a julho de 2026.
- Pedidos entregues: 55,97%. Média de avaliação: 4,09.
- 500 vídeos, com 30,35 bilhões de views e 3,03 bilhões de likes.

## Plano de marketing (Canva)

O dashboard tem um atalho para um plano de marketing criado no Canva, que liga a análise a ações de conteúdo:

[Acessar o plano de marketing no Canva](COLE-AQUI-O-LINK-DO-CANVA)

## O que aprendi

- **Cuidado com o Stream lookup em relação um-para-muitos.** A primeira versão usava um Stream lookup para juntar vídeos e pedidos. Ele devolve só uma linha por chave, então cada vídeo ficava com um único pedido: 411 pedidos em vez de 1.524, e o resto se perdia. Troquei por **Sort rows + Merge join** e conferi as contagens no banco antes de seguir.
- **Conferir os números em cada camada** (arquivo, ODS, DW e dashboard) ajudou a achar o problema. Os totais do Power BI estavam inflados, e foi a comparação com o XML de origem que mostrou onde estava o erro.
- **Rodar os blocos em sequência e usar Truncate table** evita ler tabelas incompletas e dados duplicados.
- **Dar a cada gráfico um título que descreva o que ele mede** evita leituras erradas do dashboard.

## Como reproduzir

1. Crie um banco PostgreSQL e os schemas `public` e `ods`.
2. Abra a transformação em `pentaho/` no Spoon, configure a conexão com o seu banco e os caminhos dos arquivos em `dados/`.
3. Rode os blocos na ordem: PUBLIC, ODS e TRATAMENTO.
4. Rode `sql/tiktok_dataset.sql` para criar o schema `dw`.
5. No Power BI, conecte ao banco (DirectQuery) e confira as relações entre a fato e as dimensões.

## Estrutura do repositório

```
├── README.md
├── docs/        documentação completa do projeto (PDF)
├── sql/         script do Data Warehouse
├── pentaho/     transformação do Pentaho
├── dados/       CSV e XML de exemplo (dados fictícios)
└── imagens/     capturas do Pentaho, do banco e do dashboard
```

## Autor

**[Seu nome]**: [LinkedIn](https://www.linkedin.com/in/seu-perfil)
