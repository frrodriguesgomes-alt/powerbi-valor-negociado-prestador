# 📊 Power BI — Valor Negociado por Prestador

> Painel gerencial para análise de valores negociados com a rede credenciada de uma operadora de saúde, com lógica de hierarquização contratual em 5 níveis de prioridade.

---

## 🎯 Contexto e Objetivo

Operadoras de saúde possuem contratos com prestadores (clínicas, hospitais, médicos) que definem o valor a ser pago por cada procedimento realizado. Esses contratos existem em **diferentes modalidades contratuais**, e determinar qual valor deve prevalecer para cada prestador não é trivial.

Este projeto resolve esse problema construindo uma **lógica de hierarquização contratual** que consulta 5 fontes de dados em ordem de prioridade, garantindo que o contrato mais específico de cada prestador seja sempre utilizado como referência — e não o mais genérico.

O resultado é um painel Power BI que permite à equipe de relacionamento com prestadores:

- Identificar prestadores com valores acima ou abaixo da média da rede
- Priorizar renegociações com base em volume de atendimentos e valor negociado
- Analisar a distribuição geográfica dos valores por estado
- Comparar prestadores por especialidade, regime e tipo de negociação

---

## 🏗️ Arquitetura da Solução

### Modelo de Dados (Star Schema)

```
                    ┌─────────────────────┐
                    │   _medidas (48)      │
                    │   repositório DAX    │
                    └─────────────────────┘

┌──────────────────┐        ┌──────────────────────┐        ┌──────────────────┐
│  dim_prestadores │───────▶│   valor_consolidado  │◀───────│   dim_eventos    │
│  dim_especialid. │        │   (tabela fato)      │        │   dim_cbos_norm  │
│  dim_tem_produca │        └──────────┬───────────┘        └──────────────────┘
│  dCalendario     │                   │
└──────────────────┘        ┌──────────▼───────────┐
                            │  faturamento_resumo  │
                            │  (tabela fato)       │
                            └──────────────────────┘
```

**12 tabelas · 7 relacionamentos ativos · 48 medidas DAX**

| Tabela | Tipo | Função |
|--------|------|--------|
| `faturamento_resumo` | Fato | Atendimentos realizados — volumes e valores pagos por período |
| `valor_consolidado` | Fato | Valor negociado hierarquizado (resultado das 5 consultas) |
| `dim_prestadores` | Dimensão | Cadastro: handle, nome, CPF/CNPJ, município, categoria |
| `dim_eventos` | Dimensão | Descrição e estrutura dos procedimentos |
| `dim_especialidades` | Dimensão | Especialidades por prestador — usada na correção da anomalia de CBOS |
| `dim_cbos_normalizado` | Dimensão | De-para de CBOS originais → versão normalizada |
| `dim_tem_producao` | Dimensão | Suporte ao filtro Tem Produção? (Sim / Não / Todos) |
| `dCalendario` | Dimensão | Tabela de datas para análise temporal |
| `_medidas` | Auxiliar | Repositório das 48 medidas DAX |
| `Última Atualização` | Auxiliar | Registro do último carregamento dos dados |

**Chave de vínculo entre as tabelas fato:**
```
HANDLE (prestador) + ESTRUTURA (evento) + CBOS_NORM + FAIXA_ETARIA
```

---

## 🔗 Lógica de Hierarquização Contratual

O principal desafio técnico do projeto foi determinar **qual valor negociado usar para cada prestador**, dado que contratos podem existir em 5 modalidades diferentes, do mais específico ao mais genérico.

```
┌─────────────────────────────────────────────────────────────────┐
│  PRIORIDADE 1 — Regime de Atendimento + Dotação  (+ específico) │
├─────────────────────────────────────────────────────────────────┤
│  PRIORIDADE 2 — Regime de Atendimento + Faixa                   │
├─────────────────────────────────────────────────────────────────┤
│  PRIORIDADE 3 — Pacote                                          │
├─────────────────────────────────────────────────────────────────┤
│  PRIORIDADE 4 — Dotação (sem regime)                            │
├─────────────────────────────────────────────────────────────────┤
│  PRIORIDADE 5 — Faixa de Evento                (+ genérico)    │
└─────────────────────────────────────────────────────────────────┘
         ↓ primeira prioridade com valor cadastrado vence
```

Cada nível é extraído por uma consulta SQL independente com o campo `PRIORIDADE` (1 a 5). No Power Query, as 5 consultas são unidas e agrupadas pela chave composta, mantendo apenas o registro de menor prioridade numérica (mais específico).

> Ver detalhes em [`/sql/`](./sql/)

---

## ⚠️ Anomalia Identificada e Solução

### Problema
Alguns prestadores possuíam **especialidade cadastrada** no sistema mas **sem CBOS preenchido** na tabela de valores contratuais. Isso impedia o vínculo pela chave de lookup, fazendo o prestador ficar sem valor negociado mesmo tendo contrato vigente.

### Solução
Para o código de estrutura `1.01.01.012` (Consulta em Consultório), quando o CBOS está ausente, a query da **Prioridade 4 — Dotação** executa um `INNER JOIN` com a CTE de especialidades do prestador, **expandindo o resultado em uma linha por especialidade cadastrada**, e utiliza a descrição da especialidade como substituto do CBOS.

```sql
-- PRIORIDADE 4 — DOTAÇÃO (BLOCO 3: '1.01.01.012' sem CBOS → usa ESPECIALIDADE)
SELECT
    D.HANDLE,
    D.ESTRUTURA,
    E.ESPECIALIDADE AS CBOS,   -- ← especialidade substituindo CBOS ausente
    ...
FROM CTE_DOTACOES D
INNER JOIN CTE_ESPECIALIDADES E ON E.HANDLE = D.HANDLE
WHERE D.ESTRUTURA = '1.01.01.012'
  AND (D.CBOS IS NULL OR D.CBOS = '')
```

> Ver query completa em [`/sql/04_prioridade_dotacao.sql`](./sql/04_prioridade_dotacao.sql)

---

## 📁 Estrutura do Repositório

```
📁 powerbi-valor-negociado-prestador/
│
├── 📄 README.md
│
├── 📁 sql/                          ← queries SQL das 5 fontes
│   ├── 00_cte_especialidades.sql    ← CTE auxiliar de especialidades
│   ├── 01_prioridade_regime_dotacao.sql
│   ├── 02_prioridade_regime_faixa.sql
│   ├── 03_prioridade_pacote.sql
│   ├── 04_prioridade_dotacao.sql
│   ├── 05_prioridade_faixa_evento.sql
│   └── 06_faturamento_resumo.sql    ← consulta de produção/atendimentos
│
├── 📁 dax/                          ← medidas DAX principais
│   └── medidas.md
│
├── 📁 data/                         ← dados fictícios para demonstração
│   ├── dim_prestadores.csv
│   ├── dim_eventos.csv
│   ├── dim_especialidades.csv
│   ├── dim_cbos_normalizado.csv
│   ├── valor_consolidado.csv
│   └── faturamento_resumo.csv
│
└── 📁 docs/                         ← documentação visual
    ├── orientacoes.png
    ├── documentacao.png
    └── modelo_dados.png
```

---

## 🛠️ Stack Técnica

| Tecnologia | Uso |
|------------|-----|
| **SQL Server** | Fonte de dados — sistema BENNERAG (ERP de saúde) |
| **Power Query (M)** | ETL — extração, união e hierarquização das 5 consultas |
| **DAX** | 48 medidas de negócio — médias, medianas, rankings, KPIs |
| **Power BI Desktop** | Modelagem dimensional e construção dos visuais |
| **Power BI Service** | Publicação e atualização agendada |

---

## 📊 Visuais do Painel

| Visual | Descrição |
|--------|-----------|
| KPIs | Menor, médio, mediana e maior valor da rede com identificação do prestador |
| Gráfico de barras | Prestadores ordenados por valor com linha de média dinâmica |
| Gráfico de dispersão | Valor negociado × volume de atendimentos com codificação de cor e tamanho |
| Mapa de calor | Distribuição dos valores médios por UF |
| Barras temporais | Volume de atendimentos mês a mês (últimos 12 meses) |
| Tabela | Top prestadores por faturamento com volume e valor negociado |
| Rosca | Proporção de prestadores com e sem produção |

---

## 👤 Autor

**Felipe Rodrigues**  
Economista · Analista de Dados  
[LinkedIn](https://www.linkedin.com/in/felipe-rodrigues) · [GitHub](https://github.com/felipe-rodrigues)

---

> ⚠️ **Aviso:** Os dados contidos neste repositório são **100% fictícios**, gerados para fins de demonstração. Nenhum dado real de prestadores ou valores contratuais foi exposto.
