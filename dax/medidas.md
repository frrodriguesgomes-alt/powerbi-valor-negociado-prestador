# Medidas DAX — Valor Negociado por Prestador

> Todas as medidas estão organizadas na tabela auxiliar `_medidas`.
> O modelo conta com **48 medidas** no total. Abaixo estão documentadas as principais.

---

## Valor Negociado

```dax
-- Valor negociado do prestador no contexto de filtro atual.
-- Retorna o valor da tabela valor_consolidado já hierarquizado.
Valor Negociado =
CALCULATE(
    AVERAGE( valor_consolidado[VALOR] )
)
```

---

## Média da Rede

```dax
-- Média aritmética dos valores negociados de todos os prestadores
-- no contexto de filtro atual. Alimenta a linha de referência
-- laranja no gráfico de barras.
Média da Rede =
AVERAGEX(
    VALUES( dim_prestadores[HANDLE] ),
    CALCULATE( AVERAGE( valor_consolidado[VALOR] ) )
)
```

---

## Mediana da Rede

```dax
-- Valor central da distribuição — não é distorcido por outliers.
-- Indicador mais robusto que a média para orientar renegociações.
Mediana da Rede =
MEDIANX(
    VALUES( dim_prestadores[HANDLE] ),
    CALCULATE( AVERAGE( valor_consolidado[VALOR] ) )
)
```

---

## Menor Valor da Rede

```dax
-- Menor valor negociado no contexto de filtro atual.
Menor Valor da Rede =
MINX(
    VALUES( dim_prestadores[HANDLE] ),
    CALCULATE( AVERAGE( valor_consolidado[VALOR] ) )
)
```

---

## Maior Valor da Rede

```dax
-- Maior valor negociado no contexto de filtro atual.
Maior Valor da Rede =
MAXX(
    VALUES( dim_prestadores[HANDLE] ),
    CALCULATE( AVERAGE( valor_consolidado[VALOR] ) )
)
```

---

## Prestadores Acima da Média

```dax
-- Contagem de prestadores com valor negociado superior à média da rede.
-- Exibido em destaque abaixo do card de Valor Médio.
Prestadores Acima da Média =
VAR _media = [Média da Rede]
RETURN
COUNTROWS(
    FILTER(
        VALUES( dim_prestadores[HANDLE] ),
        CALCULATE( AVERAGE( valor_consolidado[VALOR] ) ) > _media
    )
)
```

---

## Total Atendimentos

```dax
-- Soma do volume de atendimentos no período filtrado.
Total Atendimentos =
SUM( faturamento_resumo[QTDE_PAGA] )
```

---

## Total Pago

```dax
-- Soma do valor pago aos prestadores no período filtrado.
Total Pago =
SUM( faturamento_resumo[VALOR_PAGO] )
```

---

## Valor Com Produção

```dax
-- Valor negociado calculado apenas para prestadores
-- com atendimentos registrados no período.
Valor Com Producao =
CALCULATE(
    [Valor Negociado],
    dim_tem_producao[TEM_PRODUCAO] = "Sim"
)
```

---

## Valor Sem Produção

```dax
-- Valor negociado para prestadores sem atendimentos registrados.
-- Útil para auditoria de cadastros inativos.
Valor Sem Producao =
CALCULATE(
    [Valor Negociado],
    dim_tem_producao[TEM_PRODUCAO] = "Não"
)
```

---

## Nome — Menor Valor

```dax
-- Retorna o nome do prestador com o menor valor negociado.
-- Exibido como subtítulo do card Menor Valor da Rede.
Nome Menor Valor =
VAR _minVal = [Menor Valor da Rede]
RETURN
CALCULATE(
    FIRSTNONBLANK( dim_prestadores[PRESTADOR], 1 ),
    FILTER(
        ALL( dim_prestadores ),
        CALCULATE( AVERAGE( valor_consolidado[VALOR] ) ) = _minVal
    )
)
```

---

## Nome — Maior Valor

```dax
-- Retorna o nome do prestador com o maior valor negociado.
Nome Maior Valor =
VAR _maxVal = [Maior Valor da Rede]
RETURN
CALCULATE(
    FIRSTNONBLANK( dim_prestadores[PRESTADOR], 1 ),
    FILTER(
        ALL( dim_prestadores ),
        CALCULATE( AVERAGE( valor_consolidado[VALOR] ) ) = _maxVal
    )
)
```

---

## Última Atualização

```dax
-- Exibe a data e hora da última atualização dos dados.
-- Alimentado pela tabela auxiliar [Última Atualização].
Ultima Atualizacao =
"Atualizado em " &
FORMAT(
    MAX( 'Última Atualização'[Atualização] ),
    "DD/MM/YYYY \à\s HH:mm"
)
```

---

## Notas sobre a hierarquização no Power Query

A consolidação dos 5 níveis é feita em M (Power Query), não em DAX:

```
1. As 5 consultas SQL são executadas e unidas via Table.Combine
2. Uma coluna MIN_PRIORIDADE é calculada por chave composta:
   HANDLE + ESTRUTURA + CBOS_NORM + FAIXA_ETARIA
3. Table.Group retém apenas o registro de menor prioridade numérica
4. O resultado é carregado como tabela valor_consolidado
```

Essa abordagem garante que a hierarquização ocorra uma única vez,
no carregamento, sem impacto na performance dos visuais DAX.
