-- =====================================================================
-- PRIORIDADE 3 — PACOTE
-- Aplica-se quando o procedimento faz parte de um pacote contratado
-- entre a operadora e o prestador. O valor é o do evento que será
-- gerado (EVENTOAGERAR), não o evento principal do pacote.
-- =====================================================================

SELECT DISTINCT
    P.HANDLE                                            AS HANDLE,
    T2.ESTRUTURA                                        AS ESTRUTURA,
    NULL                                                AS CBOS,
    NULL                                                AS IDADE_MAXIMA,
    NULL                                                AS REGIME_ATENDIMENTO,
    3                                                   AS PRIORIDADE,
    CAST(
        (PCG.QTDUSHONORARIO        * USV.VALORUSHONORARIO)
      + (PCG.QTDUSCUSTOOPERACIONAL * OPV.VALORUSCUSTOOPERACIONAL)
    AS DECIMAL(10,2))                                   AS VALOR,
    'ADULTO'                                            AS FAIXA_ETARIA

FROM SAM_PRESTADOR               P   (NOLOCK)
LEFT JOIN SAM_PCTNEGPREST        PC  (NOLOCK) ON PC.PRESTADOR       = P.HANDLE
LEFT JOIN SAM_PCTNEGPREST_GRAU   PCG (NOLOCK) ON PCG.PACOTE         = PC.HANDLE
LEFT JOIN SAM_TGE                T   (NOLOCK) ON T.HANDLE           = PC.EVENTO
LEFT JOIN SAM_TGE                T2  (NOLOCK) ON T2.HANDLE          = PCG.EVENTOAGERAR
LEFT JOIN SAM_TABUS              US  (NOLOCK) ON US.HANDLE          = PCG.TABELAUSVALOR
LEFT JOIN SAM_TABUS_VLR          USV (NOLOCK) ON USV.TABELAUS       = US.HANDLE
LEFT JOIN SAM_TABCUSTOOPERAC     OP  (NOLOCK) ON OP.HANDLE          = PCG.TABELACUSTOOPERAC
LEFT JOIN SAM_TABCUSTOOPERAC_VLR OPV (NOLOCK) ON OPV.TABELACUSTOOPERACUS = OP.HANDLE

WHERE
    ((P.DATADESCREDENCIAMENTO IS NULL) OR (P.DATADESCREDENCIAMENTO > GETDATE()))
    AND ((PC.DATAFINAL IS NULL) OR (PC.DATAFINAL > GETDATE()))
    AND PC.DATAINICIAL IS NOT NULL
    AND USV.DATAFINAL IS NULL
    AND OPV.DATAFINAL IS NULL
    AND P.CATEGORIA IN (1, 2, 3, 16)
    AND NOT EXISTS (
        SELECT 1 FROM SAM_PRESTADOR_AFASTAMENTO PA1
        WHERE PA1.PRESTADOR = P.HANDLE
        AND (PA1.DATAFINAL IS NULL OR PA1.DATAFINAL >= GETDATE())
    )
    AND NOT EXISTS (
        SELECT 1
        FROM SAM_PRESTADOR       P1  (NOLOCK)
        JOIN SAM_PRESTADOR_PROC  PP1 (NOLOCK) ON PP1.PRESTADOR = P1.HANDLE
        WHERE PP1.TIPOPROCESSO = 'D'
        AND P1.HANDLE = P.HANDLE
        AND ((PP1.DATAINICIAL IS NOT NULL AND PP1.DATAINICIAL < GETDATE())
        AND  (PP1.DATAFINAL IS NULL OR PP1.DATAFINAL >= GETDATE()))
    )
