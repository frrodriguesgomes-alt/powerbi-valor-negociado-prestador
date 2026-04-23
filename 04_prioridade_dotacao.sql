-- =====================================================================
-- PRIORIDADE 4 — DOTAÇÃO (sem regime de atendimento)
-- Valor de dotação cadastrado diretamente para o prestador,
-- sem vínculo ao regime de atendimento.
--
-- Esta prioridade é dividida em 3 blocos para tratar a anomalia
-- de CBOS ausente no código 1.01.01.012 (Consulta em Consultório):
--
--   Bloco 1: estruturas diferentes de '1.01.01.012' → comportamento padrão
--   Bloco 2: '1.01.01.012' COM CBOS preenchido → comportamento padrão
--   Bloco 3: '1.01.01.012' SEM CBOS → usa especialidade cadastrada
--            como substituto (correção da anomalia)
-- =====================================================================

-- CTE auxiliar de dotações
WITH CTE_DOTACOES AS (
    SELECT DISTINCT
        P.HANDLE                                                                AS HANDLE,
        T.ESTRUTURA                                                             AS ESTRUTURA,
        CASE WHEN T.ESTRUTURA = '1.01.01.012' THEN CB.DESCRICAO ELSE NULL END  AS CBOS,
        PD.ATEANOS                                                              AS IDADE_MAXIMA,
        NULL                                                                    AS REGIME_ATENDIMENTO,
        4                                                                       AS PRIORIDADE,
        (PD.QTDUSHONORARIO      * ISNULL(USV.VALORUSHONORARIO,      1) * (ISNULL(PD.PERCENTUALPGTOUS,    100) / 100))
      + (PD.QTDUSCUSTOOPERACIONAL * ISNULL(OPV.VALORUSCUSTOOPERACIONAL, 1) * (ISNULL(PD.PERCENTUALPGTOCUSTO, 100) / 100))
      + (PD.FATORFILME          * ISNULL(FV.FILMEVALOR,             1) * (ISNULL(PD.PERCENTUALPGTOFILME, 100) / 100))
                                                                                AS VALOR
    FROM SAM_PRESTADOR               P
    LEFT JOIN SAM_PRECOPRESTADOR_DOTAC  PD  ON PD.PRESTADOR = P.HANDLE
    LEFT JOIN SAM_TGE                   T   ON T.HANDLE     = PD.EVENTO
    LEFT JOIN SAM_TABUS                 US  ON US.HANDLE    = PD.TABELAUS
    LEFT JOIN SAM_TABUS_VLR             USV ON USV.TABELAUS = US.HANDLE
    LEFT JOIN SAM_TABCUSTOOPERAC        OP  ON OP.HANDLE    = PD.TABELACUSTOOPERAC
    LEFT JOIN SAM_TABCUSTOOPERAC_VLR    OPV ON OPV.TABELACUSTOOPERACUS = OP.HANDLE
    LEFT JOIN SAM_TABFILME              F   ON F.HANDLE     = PD.TABELAFILME
    LEFT JOIN SAM_TABFILME_VLR          FV  ON FV.TABELAFILME = F.HANDLE
    LEFT JOIN TIS_CBOS                  CB  (NOLOCK) ON CB.HANDLE = PD.CBOSPESQUISA
    WHERE
        P.DATACREDENCIAMENTO IS NOT NULL
        AND P.CATEGORIA IN (1, 2, 3, 16)
        AND PD.DATAINICIAL IS NOT NULL
        AND PD.DATAFINAL IS NULL
        AND ((USV.DATAFINAL IS NULL) OR (USV.DATAFINAL > GETDATE()))
        AND ((OPV.DATAFINAL IS NULL) OR (OPV.DATAFINAL > GETDATE()))
        AND ((FV.DATAFINAL  IS NULL) OR (FV.DATAFINAL  > GETDATE()))
),

-- CTE auxiliar de especialidades (usada no Bloco 3)
CTE_ESPECIALIDADES AS (
    SELECT DISTINCT
        P.HANDLE,
        E.Z_DESCRICAO AS ESPECIALIDADE
    FROM SAM_PRESTADOR                    P
    LEFT JOIN SAM_CATEGORIA_PRESTADOR     CP  (NOLOCK) ON CP.HANDLE = P.CATEGORIA
    LEFT JOIN SAM_PRESTADOR_ESPECIALIDADE PE  (NOLOCK) ON PE.PRESTADOR = P.HANDLE
    LEFT JOIN SAM_ESPECIALIDADE           E   (NOLOCK) ON E.HANDLE = PE.ESPECIALIDADE
    WHERE
        ((P.DATADESCREDENCIAMENTO IS NULL) OR (P.DATADESCREDENCIAMENTO > GETDATE()))
        AND P.DATACREDENCIAMENTO IS NOT NULL
        AND ((P.DATABLOQUEIO IS NULL) OR (P.DATABLOQUEIO > GETDATE()))
        AND PE.DATAINICIAL IS NOT NULL
        AND ((PE.DATAFINAL IS NULL) OR (PE.DATAFINAL > GETDATE()))
        AND CP.HANDLE IN (1, 2, 3, 16)
        AND E.Z_DESCRICAO NOT IN (
            'MAT/MED -  MATERIAIS E MEDICAMENTOS', 'HOSPITAL', 'MATERNIDADE',
            'SAUDE EM CASA', 'TERAPIA INTENSIVA', 'MEDICINA INTENSIVA',
            'ALIMENTACAO PARENTERAL E ENTERAL', 'VACINAS'
        )
        AND NOT EXISTS (
            SELECT 1 FROM SAM_PRESTADOR_AFASTAMENTO PA1
            WHERE PA1.PRESTADOR = P.HANDLE
            AND (PA1.DATAFINAL IS NULL OR PA1.DATAFINAL >= GETDATE())
        )
)

-- ─────────────────────────────────────────────────
-- BLOCO 1: estruturas diferentes de '1.01.01.012'
-- Comportamento padrão — sem necessidade de CBOS
-- ─────────────────────────────────────────────────
SELECT
    D.HANDLE, D.ESTRUTURA, D.CBOS, D.IDADE_MAXIMA, D.REGIME_ATENDIMENTO, D.PRIORIDADE, D.VALOR,
    CASE WHEN D.IDADE_MAXIMA < 18 THEN 'PED' ELSE 'ADULTO' END AS FAIXA_ETARIA
FROM CTE_DOTACOES D
WHERE D.ESTRUTURA <> '1.01.01.012'

UNION ALL

-- ─────────────────────────────────────────────────
-- BLOCO 2: '1.01.01.012' com CBOS preenchido
-- Comportamento padrão
-- ─────────────────────────────────────────────────
SELECT
    D.HANDLE, D.ESTRUTURA, D.CBOS, D.IDADE_MAXIMA, D.REGIME_ATENDIMENTO, D.PRIORIDADE, D.VALOR,
    CASE WHEN D.IDADE_MAXIMA < 18 THEN 'PED' ELSE 'ADULTO' END AS FAIXA_ETARIA
FROM CTE_DOTACOES D
WHERE D.ESTRUTURA = '1.01.01.012'
  AND D.CBOS IS NOT NULL
  AND D.CBOS <> ''

UNION ALL

-- ─────────────────────────────────────────────────
-- BLOCO 3: '1.01.01.012' sem CBOS → usa ESPECIALIDADE
-- CORREÇÃO DA ANOMALIA: expande uma linha por especialidade
-- cadastrada do prestador, usando a especialidade como CBOS
-- ─────────────────────────────────────────────────
SELECT
    D.HANDLE,
    D.ESTRUTURA,
    E.ESPECIALIDADE     AS CBOS,      -- ← especialidade substitui CBOS ausente
    D.IDADE_MAXIMA,
    D.REGIME_ATENDIMENTO,
    D.PRIORIDADE,
    D.VALOR,
    CASE WHEN D.IDADE_MAXIMA < 18 THEN 'PED' ELSE 'ADULTO' END AS FAIXA_ETARIA
FROM CTE_DOTACOES D
INNER JOIN CTE_ESPECIALIDADES E ON E.HANDLE = D.HANDLE
WHERE D.ESTRUTURA = '1.01.01.012'
  AND (D.CBOS IS NULL OR D.CBOS = '')
