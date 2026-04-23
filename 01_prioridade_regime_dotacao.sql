-- =====================================================================
-- CTE_ESPECIALIDADES
-- Retorna todas as especialidades ativas por prestador.
-- Usada como fallback quando o CBOS está ausente na tabela de valores
-- (estrutura 1.01.01.012 — Consulta em Consultório).
-- =====================================================================

WITH CTE_ESPECIALIDADES AS (
    SELECT DISTINCT
        P.HANDLE,
        E.Z_DESCRICAO AS ESPECIALIDADE
    FROM SAM_PRESTADOR                    P
    LEFT JOIN SAM_CATEGORIA_PRESTADOR     CP  (NOLOCK) ON CP.HANDLE = P.CATEGORIA
    LEFT JOIN SAM_PRESTADOR_ESPECIALIDADE PE  (NOLOCK) ON PE.PRESTADOR = P.HANDLE
    LEFT JOIN SAM_ESPECIALIDADE           E   (NOLOCK) ON E.HANDLE = PE.ESPECIALIDADE
    WHERE
        -- Prestador ativo (sem descredenciamento, sem bloqueio)
        ((P.DATADESCREDENCIAMENTO IS NULL) OR (P.DATADESCREDENCIAMENTO > GETDATE()))
        AND P.DATACREDENCIAMENTO IS NOT NULL
        AND ((P.DATABLOQUEIO IS NULL) OR (P.DATABLOQUEIO > GETDATE()))
        -- Especialidade ativa
        AND PE.DATAINICIAL IS NOT NULL
        AND ((PE.DATAFINAL IS NULL) OR (PE.DATAFINAL > GETDATE()))
        -- Apenas categorias credenciadas (ambulatorial/médico)
        AND CP.HANDLE IN (1, 2, 3, 16)
        -- Exclui especialidades não clínicas
        AND E.Z_DESCRICAO NOT IN (
            'MAT/MED -  MATERIAIS E MEDICAMENTOS',
            'HOSPITAL',
            'MATERNIDADE',
            'SAUDE EM CASA',
            'TERAPIA INTENSIVA',
            'MEDICINA INTENSIVA',
            'ALIMENTACAO PARENTERAL E ENTERAL',
            'VACINAS'
        )
        -- Sem afastamento ativo
        AND NOT EXISTS (
            SELECT 1 FROM SAM_PRESTADOR_AFASTAMENTO PA1
            WHERE PA1.PRESTADOR = P.HANDLE
            AND (PA1.DATAFINAL IS NULL OR PA1.DATAFINAL >= GETDATE())
        )
        -- Sem processo de desligamento ativo
        AND NOT EXISTS (
            SELECT 1
            FROM SAM_PRESTADOR       P1  (NOLOCK)
            JOIN SAM_PRESTADOR_PROC  PP1 (NOLOCK) ON PP1.PRESTADOR = P1.HANDLE
            WHERE PP1.TIPOPROCESSO = 'D'
            AND P1.HANDLE = P.HANDLE
            AND ((PP1.DATAINICIAL IS NOT NULL AND PP1.DATAINICIAL < GETDATE())
            AND  (PP1.DATAFINAL IS NULL OR PP1.DATAFINAL >= GETDATE()))
        )
)


-- =====================================================================
-- PRIORIDADE 1 — REGIME DE ATENDIMENTO + DOTAÇÃO
-- Nível mais específico da hierarquia.
-- Valor calculado a partir das tabelas de US honorário, custo
-- operacional e filme, ponderadas pelos percentuais de pagamento
-- definidos no contrato de dotação por regime de atendimento.
-- =====================================================================

SELECT DISTINCT
    P.HANDLE                                            AS HANDLE,
    T.ESTRUTURA                                         AS ESTRUTURA,
    NULL                                                AS CBOS,
    NULL                                                AS IDADE_MAXIMA,
    CASE PR.REGIMEATENDIMENTO
        WHEN 1 THEN 'AMBULATORIAL'
        WHEN 2 THEN 'DOMICILIAR'
        WHEN 3 THEN 'INTERNAÇÃO HOSPITALAR'
        WHEN 4 THEN 'INTERNAÇÃO EM CASA'
        WHEN 5 THEN 'HOSPITAL DIA'
    END                                                 AS REGIME_ATENDIMENTO,
    1                                                   AS PRIORIDADE,
    -- Fórmula de valor: US honorário + custo operacional + filme
    (PR.QTDUSHONORARIO         * USV.VALORUSHONORARIO         * (PR.PERCENTUALPGTOUS    / 100))
  + (PR.QTDUSCUSTOOPERACIONAL  * OPV.VALORUSCUSTOOPERACIONAL  * (PR.PERCENTUALPGTOCUSTO / 100))
  + (PR.FATORFILME             * ISNULL(FV.FILMEVALOR, 0)     * (PR.PERCENTUALPGTOFILME / 100))
                                                        AS VALOR,
    'ADULTO'                                            AS FAIXA_ETARIA

FROM SAM_PRESTADOR                    P
JOIN  SAM_PRECOPRESTADORREGIME_DOTAC  PR  (NOLOCK) ON PR.PRESTADOR  = P.HANDLE
JOIN  SAM_TGE                         T   (NOLOCK) ON T.HANDLE      = PR.EVENTO
LEFT JOIN SAM_TABUS                   US  (NOLOCK) ON US.HANDLE     = PR.TABELAUS
LEFT JOIN SAM_TABUS_VLR               USV (NOLOCK) ON USV.TABELAUS  = US.HANDLE
LEFT JOIN SAM_TABCUSTOOPERAC          OP  (NOLOCK) ON OP.HANDLE     = PR.TABELACUSTOOPERAC
LEFT JOIN SAM_TABCUSTOOPERAC_VLR      OPV (NOLOCK) ON OPV.TABELACUSTOOPERACUS = OP.HANDLE
LEFT JOIN SAM_TABFILME                F   (NOLOCK) ON F.HANDLE      = PR.TABELAFILME
LEFT JOIN SAM_TABFILME_VLR            FV  (NOLOCK) ON FV.TABELAFILME = F.HANDLE

WHERE
    PR.DATAINICIAL IS NOT NULL
    AND ((PR.DATAFINAL  IS NULL) OR (PR.DATAFINAL  > GETDATE()))
    AND ((USV.DATAFINAL IS NULL) OR (USV.DATAFINAL > GETDATE()))
    AND ((OPV.DATAFINAL IS NULL) OR (OPV.DATAFINAL > GETDATE()))
    AND ((FV.DATAFINAL  IS NULL) OR (FV.DATAFINAL  > GETDATE()))
    AND P.DATACREDENCIAMENTO IS NOT NULL
    AND P.CATEGORIA IN (1, 2, 3, 16)
