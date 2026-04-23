-- =====================================================================
-- PRIORIDADE 5 — FAIXA DE EVENTOS
-- Nível mais genérico da hierarquia. Fallback para prestadores sem
-- contrato específico nos níveis 1 a 4. O valor é extraído de uma
-- tabela genérica de preços filtrada pelo intervalo de estrutura
-- definido no contrato de faixa do prestador.
-- Prestadores enquadrados apenas neste nível não possuem
-- contrato específico negociado.
-- =====================================================================

SELECT DISTINCT
    P.HANDLE                                            AS HANDLE,
    TGE.ESTRUTURA                                       AS ESTRUTURA,
    NULL                                                AS CBOS,
    NULL                                                AS IDADE_MAXIMA,
    NULL                                                AS REGIME_ATENDIMENTO,
    5                                                   AS PRIORIDADE,
    (PGD.QTDUSHONORARIO        * ISNULL(USV.VALORUSHONORARIO,       1) * PFX.PERCENTUALPGTOUS    / 100)
  + (PGD.QTDUSCUSTOOPERACIONAL * ISNULL(UCOV.VALORUSCUSTOOPERACIONAL,1) * PFX.PERCENTUALPGTOCUSTO / 100)
  + (PGD.FATORFILME            * ISNULL(FV.FILMEVALOR,              1) * PFX.PERCENTUALPGTOFILME / 100)
                                                        AS VALOR,
    'ADULTO'                                            AS FAIXA_ETARIA

FROM SAM_PRECOGENERICO            PG
LEFT JOIN SAM_PRECOGENERICO_DOTAC PGD  ON PG.HANDLE          = PGD.TABELAPRECO
LEFT JOIN SAM_PRECOPRESTADOR_FX   PFX  ON PG.HANDLE          = PFX.TABELAPRECO
LEFT JOIN SAM_PRESTADOR           P    ON P.HANDLE            = PFX.PRESTADOR
LEFT JOIN SAM_TGE                 TGE  ON TGE.HANDLE          = PGD.EVENTO
LEFT JOIN SAM_TABCUSTOOPERAC_VLR  UCOV ON PFX.TABELACUSTOOPERAC = UCOV.TABELACUSTOOPERACUS
LEFT JOIN SAM_TABUS_VLR           USV  ON PFX.TABELAUS        = USV.TABELAUS
LEFT JOIN SAM_TABFILME_VLR        FV   ON PFX.TABELAFILME     = FV.TABELAFILME

WHERE
    TGE.INATIVO = 'N'
    AND PGD.DATAFINAL IS NULL
    AND PFX.DATAFINAL IS NULL
    AND (P.DATADESCREDENCIAMENTO IS NULL OR P.DATADESCREDENCIAMENTO > GETDATE())
    AND (P.DATABLOQUEIO          IS NULL OR P.DATABLOQUEIO          > GETDATE())
    AND P.DATACREDENCIAMENTO <= GETDATE()
    AND P.CATEGORIA IN (1, 2, 3, 16)
    -- Filtra eventos dentro do intervalo de estrutura do contrato
    AND TGE.ESTRUTURA BETWEEN PFX.ESTRUTURAINICIAL AND PFX.ESTRUTURAFINAL
    AND USV.DATAFINAL  IS NULL
    AND UCOV.DATAFINAL IS NULL
    AND FV.DATAFINAL   IS NULL
    AND NOT EXISTS (
        SELECT 1 FROM SAM_PRESTADOR_AFASTAMENTO PA1
        WHERE PA1.PRESTADOR = P.HANDLE
        AND (PA1.DATAFINAL IS NULL OR PA1.DATAFINAL >= GETDATE())
    )
