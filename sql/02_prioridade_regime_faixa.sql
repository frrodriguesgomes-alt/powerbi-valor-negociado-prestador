-- =====================================================================
-- PRIORIDADE 2 — REGIME DE ATENDIMENTO + FAIXA
-- Acionado quando não há dotação vinculada ao regime.
-- O valor é calculado a partir de uma tabela genérica de preços
-- (SAM_PRECOGENERICO) filtrada pelo intervalo de estrutura definido
-- no contrato de faixa por regime (ESTRUTURAINICIAL / ESTRUTURAFINAL).
-- =====================================================================

SELECT DISTINCT
    P2.HANDLE                                           AS HANDLE,
    T2.ESTRUTURA                                        AS ESTRUTURA,
    NULL                                                AS CBOS,
    NULL                                                AS IDADE_MAXIMA,
    CASE FX.REGIMEATENDIMENTO
        WHEN 1 THEN 'AMBULATORIAL'
        WHEN 2 THEN 'DOMICILIAR'
        WHEN 3 THEN 'INTERNAÇÃO HOSPITALAR'
        WHEN 4 THEN 'INTERNAÇÃO EM CASA'
        WHEN 5 THEN 'HOSPITAL DIA'
    END                                                 AS REGIME_ATENDIMENTO,
    2                                                   AS PRIORIDADE,
    (PGD.QTDUSHONORARIO        * ISNULL(USV2.VALORUSHONORARIO,      1) * FX.PERCENTUALPGTOUS    / 100)
  + (PGD.QTDUSCUSTOOPERACIONAL * ISNULL(OPV2.VALORUSCUSTOOPERACIONAL,1) * FX.PERCENTUALPGTOCUSTO / 100)
  + (PGD.FATORFILME            * ISNULL(FV2.FILMEVALOR,             1) * FX.PERCENTUALPGTOFILME / 100)
                                                        AS VALOR,
    'ADULTO'                                            AS FAIXA_ETARIA

FROM SAM_PRECOGENERICO                PG
LEFT JOIN SAM_PRECOGENERICO_DOTAC     PGD  ON PG.HANDLE      = PGD.TABELAPRECO
LEFT JOIN SAM_PRECOPRESTADORREGIME_FX FX   ON FX.TABELAPRECO = PG.HANDLE
LEFT JOIN SAM_PRESTADOR               P2   ON P2.HANDLE      = FX.PRESTADOR
LEFT JOIN SAM_TGE                     T2   ON T2.HANDLE      = PGD.EVENTO
JOIN  SAM_TABUS                       US2  ON US2.HANDLE     = FX.TABELAUS
JOIN  SAM_TABUS_VLR                   USV2 ON USV2.TABELAUS  = US2.HANDLE
JOIN  SAM_TABCUSTOOPERAC              OP2  ON OP2.HANDLE     = FX.TABELACUSTOOPERAC
JOIN  SAM_TABCUSTOOPERAC_VLR          OPV2 ON OPV2.TABELACUSTOOPERACUS = OP2.HANDLE
JOIN  SAM_TABFILME                    F2   ON F2.HANDLE      = FX.TABELAFILME
JOIN  SAM_TABFILME_VLR                FV2  ON FV2.TABELAFILME = F2.HANDLE

WHERE
    FX.DATAINICIAL IS NOT NULL
    -- Filtra eventos dentro do intervalo de estrutura do contrato de faixa
    AND T2.ESTRUTURA BETWEEN FX.ESTRUTURAINICIAL AND FX.ESTRUTURAFINAL
    AND ((FX.DATAFINAL   IS NULL) OR (FX.DATAFINAL   > GETDATE()))
    AND ((USV2.DATAFINAL IS NULL) OR (USV2.DATAFINAL > GETDATE()))
    AND ((OPV2.DATAFINAL IS NULL) OR (OPV2.DATAFINAL > GETDATE()))
    AND ((FV2.DATAFINAL  IS NULL) OR (FV2.DATAFINAL  > GETDATE()))
    AND P2.DATACREDENCIAMENTO IS NOT NULL
    AND P2.CATEGORIA IN (1, 2, 3, 16)
    -- Garante que o valor calculado seja positivo
    AND (
          (PGD.QTDUSHONORARIO        * ISNULL(USV2.VALORUSHONORARIO,      1) * FX.PERCENTUALPGTOUS    / 100)
        + (PGD.QTDUSCUSTOOPERACIONAL * ISNULL(OPV2.VALORUSCUSTOOPERACIONAL,1) * FX.PERCENTUALPGTOCUSTO / 100)
        + (PGD.FATORFILME            * ISNULL(FV2.FILMEVALOR,             1) * FX.PERCENTUALPGTOFILME / 100)
    ) > 0
