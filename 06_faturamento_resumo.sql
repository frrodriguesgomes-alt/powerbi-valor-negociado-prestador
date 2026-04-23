-- =====================================================================
-- FATURAMENTO RESUMO
-- Consolida os atendimentos realizados nos últimos 12 meses fechados,
-- agrupados por prestador, estrutura, CBOS, faixa etária, mês e regime.
-- Esta consulta alimenta os visuais de volume e evolução temporal.
--
-- Filtros aplicados:
--   - Apenas guias pagas (SITUACAO = 4)
--   - Exclui materiais e medicamentos
--   - Exclui prestadores em afastamento ou processo de desligamento
--   - Janela: últimos 12 meses fechados (mês anterior até 12 meses atrás)
-- =====================================================================

SELECT
    P.HANDLE                                                AS HANDLE,
    T.ESTRUTURA                                             AS ESTRUTURA,
    CB.DESCRICAO                                            AS CBOS,
    CASE WHEN DATEDIFF(YEAR, SM.DATANASCIMENTO,
         GE.DATAATENDIMENTO) < 18
         THEN 'PED' ELSE 'ADULTO' END                       AS FAIXA_ETARIA,
    YEAR(GE.DATAATENDIMENTO)                                AS ANO,
    MONTH(GE.DATAATENDIMENTO)                               AS MES,
    UPPER(RA.DESCRICAO)                                     AS REGIME_ATENDIMENTO,
    SUM(GE.QTDPAGTO)                                        AS QTDE_PAGA,
    SUM(GE.VALORPAGTO)                                      AS VALOR_PAGO

FROM SAM_GUIA                       G
JOIN SAM_GUIA_EVENTOS               GE   (NOLOCK) ON GE.GUIA = G.HANDLE
JOIN SAM_PEG                        PEG  (NOLOCK) ON PEG.HANDLE = G.PEG
JOIN SAM_TGE                        T    (NOLOCK) ON T.HANDLE = GE.EVENTO
JOIN SAM_GRAU                       GRAU (NOLOCK) ON GRAU.HANDLE = GE.GRAU
JOIN SAM_TIPOGRAU                   TG   (NOLOCK) ON TG.HANDLE = GRAU.TIPOGRAU
JOIN SAM_REGIMEATENDIMENTO          RA   (NOLOCK) ON RA.HANDLE = G.REGIMEATENDIMENTO
JOIN SAM_BENEFICIARIO               B    (NOLOCK) ON B.HANDLE = G.BENEFICIARIO
JOIN SAM_MATRICULA                  SM   (NOLOCK) ON SM.HANDLE = B.MATRICULA
LEFT JOIN SAM_PRESTADOR             P    (NOLOCK) ON P.HANDLE = G.RECEBEDOR
LEFT JOIN SAM_TIPOPRESTADOR         TP   (NOLOCK) ON TP.HANDLE = P.TIPOPRESTADOR
LEFT JOIN SAM_CATEGORIA_PRESTADOR   CP   (NOLOCK) ON CP.HANDLE = P.CATEGORIA
LEFT JOIN TIS_CBOS                  CB   (NOLOCK) ON CB.HANDLE = GE.CBOS

WHERE
    (GE.QTDPAGTO > 0 OR GE.VALORPAGTO > 0)
    AND G.SITUACAO = 4                          -- apenas guias pagas
    AND PEG.PEGORIGINAL IS NULL                 -- exclui re-apresentações
    AND TP.HANDLE NOT IN (21)                   -- exclui tipo específico
    AND CP.HANDLE IN (1, 2, 3)                  -- categorias credenciadas
    AND TG.DESCRICAO NOT IN ('Materiais', 'Medicamentos')
    -- Janela: últimos 12 meses fechados
    AND GE.DATAATENDIMENTO BETWEEN
        DATEADD(MONTH, DATEDIFF(MONTH, 0, DATEADD(MONTH, -12, GETDATE())), 0)
        AND EOMONTH(DATEADD(MONTH, -1, GETDATE()))
    AND NOT EXISTS (
        SELECT 1 FROM SAM_PRESTADOR_AFASTAMENTO PA1
        WHERE PA1.PRESTADOR = P.HANDLE
        AND (PA1.DATAFINAL IS NULL OR PA1.DATAFINAL >= GETDATE())
    )
    AND NOT EXISTS (
        SELECT 1
        FROM SAM_PRESTADOR P1 (NOLOCK)
        JOIN SAM_PRESTADOR_PROC PP1 (NOLOCK) ON PP1.PRESTADOR = P1.HANDLE
        WHERE PP1.TIPOPROCESSO = 'D'
        AND P1.HANDLE = P.HANDLE
        AND ((PP1.DATAINICIAL IS NOT NULL AND PP1.DATAINICIAL < GETDATE())
        AND (PP1.DATAFINAL IS NULL OR PP1.DATAFINAL >= GETDATE()))
    )

GROUP BY
    P.HANDLE,
    T.ESTRUTURA,
    CB.DESCRICAO,
    DATEDIFF(YEAR, SM.DATANASCIMENTO, GE.DATAATENDIMENTO),
    YEAR(GE.DATAATENDIMENTO),
    MONTH(GE.DATAATENDIMENTO),
    UPPER(RA.DESCRICAO)
