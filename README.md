# Cargos vagos no Poder Executivo Federal (2016–2026)

Compilação e análise da série mensal de cargos aprovados, distribuídos, ocupados
e vagos no Executivo federal, publicada pelo Painel Estatístico de Pessoal.

> **Começando agora?** Leia o [`CONTEXTO-PROJETO.md`](CONTEXTO-PROJETO.md)
> primeiro — decisões tomadas, estado do trabalho e pendências abertas.

## Estrutura

```
CONTEXTO-PROJETO.md    decisões, estado, pendências  ← comece aqui
PAUTA.md               plano editorial e hipóteses testadas
dicionario_de_dados.qmd  semântica das colunas e armadilhas

dados_brutos/   125 planilhas mensais (.ods / .xlsx) + a nota técnica em PDF
code/           compilação, validação e de-para de órgãos
dados/          os parquets gerados — é daqui que as análises leem
artigos/        os seis textos do blog, em Quarto
painel/         especificação, tabelas agregadas e mockup do painel
```

## Como reproduzir

```r
source("code/01_compilar.R")        # ~10 min: lê 250 abas de planilha
source("code/02_validar.R")         # confere a integridade do resultado
source("code/03_depara_orgaos.R")   # identidade institucional estável
```

Gera:

| Arquivo | Linhas | Colunas | Tamanho |
|---|---|---|---|
| `dados/cargos_por_orgao.parquet` | 24.196 | 14 | 0,3 MB |
| `dados/cargos_por_orgao_cargo.parquet` | 1.672.409 | 27 | 11,8 MB |
| `dados/depara_orgaos.parquet` | 233 | 12 | — |

124 meses compilados, de 2016-01 a 2026-06 — dos quais **119 são utilizáveis**
depois de excluir os meses com quebra de série (ver abaixo). A pasta `dados/` é
derivada: pode ser apagada e refeita a qualquer momento.

### O que a validação confirmou

- `vago = aprovada - ocupada` vale em **todas** as 24.196 linhas, sem exceção.
- As colunas exclusivas da era 2 estão corretamente vazias na era 1.
- Nenhuma linha de "total geral" vaza para os dados (ver abaixo).
- O de-para preserva o total do mês nos 124 meses.

### O que a validação encontrou de errado

- **Linha de total geral em 2019-01.** O arquivo traz um total no rodapé, sem
  código de órgão. A primeira versão do script o somou junto e dobrou o mês.
  Corrigido; `02_validar.R` agora testa isso explicitamente.
- **2026-06 está corrompido.** Todas as colunas de vacância inflam de 1,19× a
  4,39× e `aprovada` salta 3,3%. **Descarte esse mês.**
- **2018-03 tem dupla contagem** de sete códigos em transição (+23.440, devolvidos
  no mês seguinte).
- **2025-04 a 2025-06 formam uma bolha:** `aprovada` sobe 5,8% e devolve 5,6%.
- **As colunas `vacancia_por_*` são acumuladas desde a origem da carreira, sem
  reset.** Diferenciá-las não produz fluxo mensal limpo — 18,5% dos pares
  órgão-cargo sofrem reprocessamento retroativo.
- **`NA` na coluna `nivel` é o código de Nível Apoio, não valor ausente.**
  Leitores de planilha o convertem em nulo por padrão e apagam 100.694 linhas em
  silêncio. Use `read_excel(..., na = character())`.
- **As duas abas divergem em 141 pares** órgão-mês (0,6%), em 4 órgãos a partir
  de 2023-06 — inconsistência da fonte.

Sete meses no total ficam de fora das análises. A lista completa, com motivo,
está em `painel/dados/meses_excluidos.csv` e na
[especificação do painel](painel/ESPECIFICACAO.md).

## Como usar

```r
library(arrow)
library(dplyr)

# leve — cabe na memória sem esforço
orgaos <- read_parquet("dados/cargos_por_orgao.parquet")

# pesado — vale abrir como dataset e filtrar antes de coletar
cargos <- open_dataset("dados/cargos_por_orgao_cargo.parquet")

cargos |>
  filter(ano >= 2022, sigla_orgao == "MGI") |>
  collect()
```

## O que precisa ser sabido antes de analisar

Três coisas atrapalham quem chega neste dado sem aviso:

**A série tem dois layouts.** Até 2021-07 os arquivos se chamam
`LotOrgao_DistOcupVagas` e trazem só os estoques. De 2021-08 em diante viram
`CargosVagosVacancias` e ganham as colunas de vacância por motivo, o plano de
carreira e a marcação de cargo em extinção. A coluna `era` (1 ou 2) identifica a
origem de cada linha; as colunas exclusivas da era 2 são `NA` antes de 2021-08.

**Faltam dois meses:** 2019-02 e 2025-07 não existem no acervo baixado. Qualquer
série temporal precisa tratar essas lacunas explicitamente — não interpole sem
dizer que interpolou.

**Os órgãos mudam de código e de nome ao longo da década.** Reformas
ministeriais partem, fundem e renomeiam pastas. Somar por `orgao` ou por
`nome_orgao` ao longo de dez anos produz séries quebradas — use a coluna
`entidade` do de-para (`dados/depara_orgaos.parquet`).

Para as cisões sem correspondência 1:1 — o Ministério da Fazenda (17000) virou
Economia e se partiu em MF (17600), MGI (17500), MPO (17300), MDIC (17400) e
MEMP (17700) — só a coluna `bloco` permite comparação honesta ao longo do tempo.

## Fonte

Painel Estatístico de Pessoal / Ministério da Gestão e da Inovação em Serviços
Públicos. A nota técnica em `dados_brutos/` documenta os conceitos originais.

---

## Como reproduzir

### 1. Dependências

```r
pak::pak("theoadepaula/theoviz")   # paleta, tabelas gt, formatação pt-BR
```

Os artigos dependem também de `arrow`, `dplyr`, `ggplot2`, `ggiraph`, `scales`
e `patchwork`. R 4.5.2, Quarto 1.9.

### 2. Dados brutos — não versionados

As 125 planilhas mensais do Painel Estatístico de Pessoal (MGI) somam **103 MB**
e ficam fora do repositório: são republicadas pela origem e rebaixáveis. Os
`.parquet` já tratados, em `dados/`, **estão** versionados — dá para reproduzir
todos os gráficos e tabelas sem baixar nada.

Para refazer a compilação desde o começo, coloque as planilhas em
`dados_brutos/` e confira se são exatamente as mesmas que geraram esta análise:

```bash
sha256sum -c MANIFEST-dados-brutos.sha256
```

> As planilhas rendem **124 competências**, não 125: faltam fev/2019 e jul/2025
> na origem. As duas grandezas são afirmadas separadamente pelo conferidor de
> prosa, justamente para que ninguém "corrija" a errada.

### 3. Rodar

```bash
Rscript code/01_compilar.R
Rscript code/02_validar.R
Rscript code/03_depara_orgaos.R
Rscript code/07_conferir_prosa.R    # tem que sair 0 antes de publicar
quarto render
```

### 4. O conferidor de prosa

`code/07_conferir_prosa.R` afirma **contra o dado** todo número que os artigos
citam em texto corrido, e sai com código 1 se algum quebrar. Existe porque os
blocos de código leem o dado na hora e nunca mentem — a prosa em volta é escrita
à mão e envelhece calada quando o pipeline muda.

Rode depois de qualquer mudança no pipeline e antes de publicar.
