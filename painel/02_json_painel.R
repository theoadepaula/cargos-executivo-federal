# ---------------------------------------------------------------------------
# Monta o JSON compacto que alimenta o painel HTML.
#
# Equivale ao `code/05_dados_painel.py` do Relatorios_slu — mesma ideia, em R,
# pela regra fixa de que análise deste projeto é em R.
#
# Princípio: **agregue aqui, não no navegador.** As 36.937 linhas de cargos em
# extinção viram 25 do topo mais 5 totais anuais, que é tudo que o painel mostra.
# O JSON inteiro cabe em ~23 KB, contra 115 MB da versão em Shinylive.
#
# Rode depois de `01_preparar_dados_painel.R`. Saída: painel/dados_painel.json
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr); library(arrow); library(jsonlite)
})

RAIZ <- if (basename(getwd()) == "painel") getwd() else file.path(getwd(), "painel")
setwd(RAIZ)

ler <- function(n) arrow::read_parquet(file.path("dados", n))

ULTIMO_MES <- 202605
MESES_RUINS    <- c(201803, 202504, 202505, 202506, 202606)
MESES_AUSENTES <- c(201902, 202507)

sm <- ler("serie_mensal.parquet")
se <- ler("serie_entidade.parquet")
sn <- ler("serie_nivel.parquet")
sc <- ler("serie_carreira.parquet")
sa <- ler("saidas_acumuladas.parquet")
ce <- ler("cargos_em_extincao.parquet")
me <- ler("meses_excluidos.parquet")

stopifnot(max(sm$competencia) == ULTIMO_MES)

NIVEIS <- c("NA" = "Apoio", "NI" = "Intermediário", "NS" = "Superior")

# arredonda o que é taxa: em JSON cada decimal a mais é byte a mais, e nenhuma
# leitura do painel precisa de mais de duas casas
r2 <- function(x) round(x, 2)

payload <- list(

  meta = list(
    ultimo_mes    = ULTIMO_MES,
    ultimo_rotulo = "maio de 2026",
    primeiro_mes  = min(sm$competencia),
    fonte         = "Painel Estatístico de Pessoal (MGI)",
    gerado_em     = format(Sys.Date(), "%Y-%m-%d"),
    meses_ruins    = MESES_RUINS,
    meses_ausentes = MESES_AUSENTES
  ),

  # espinha dorsal: 119 meses
  mensal = sm |>
    arrange(competencia) |>
    transmute(competencia, aprovada, ocupada, vago,
              nunca = nunca_distribuido, pos = vago_pos_distrib,
              taxa = r2(taxa_vacancia), fantasma = r2(pct_fantasma)),

  # taxa por nível, mês a mês
  nivel = sn |>
    filter(nivel %in% names(NIVEIS)) |>
    arrange(competencia) |>
    transmute(competencia, nivel = unname(NIVEIS[nivel]),
              aprovada, ocupada, vago, taxa = r2(100 * vago / aprovada)),

  # concentração da vacância fantasma — só o último mês, só o topo
  orgaos = se |>
    filter(competencia == ULTIMO_MES) |>
    arrange(desc(nunca_distribuido)) |>
    head(15) |>
    transmute(nome = entidade_nome, aprovada, nunca = nunca_distribuido,
              pct = r2(100 * nunca_distribuido / aprovada)),

  # carreiras: só as de porte, senão a tabela vira ruído
  carreiras = sc |>
    filter(competencia == ULTIMO_MES, aprovada >= 2000) |>
    arrange(desc(taxa_vacancia)) |>
    transmute(nome = plano_carreira, aprovada, ocupada, vago,
              taxa = r2(taxa_vacancia)),

  saidas = sa |>
    filter(competencia == ULTIMO_MES) |>
    arrange(desc(acumulado)) |>
    transmute(motivo, n = acumulado,
              pct = r2(100 * acumulado / sum(acumulado))),

  extincao_ano = ce |>
    filter(competencia %% 100 == 1) |>
    group_by(ano) |>
    summarise(ocupada = sum(ocupada, na.rm = TRUE),
              tipos   = n_distinct(nome_cargo), .groups = "drop") |>
    arrange(ano),

  extincao_top = ce |>
    filter(competencia == ULTIMO_MES) |>
    group_by(nome_cargo) |>
    summarise(ocupada = sum(ocupada, na.rm = TRUE),
              orgaos  = sum(orgaos, na.rm = TRUE), .groups = "drop") |>
    arrange(desc(ocupada)) |>
    head(25) |>
    transmute(cargo = nome_cargo, ocupada, orgaos),

  # a camada que impede o painel de mentir por omissão
  excluidos = me |>
    arrange(competencia) |>
    transmute(competencia, tipo, motivo)
)

# --- conferências antes de escrever ----------------------------------------
# O JSON é a fonte do painel. Se ele sair errado, o painel mente com confiança.

conferir <- function(cond, msg) if (!isTRUE(cond)) stop("CONFERÊNCIA FALHOU: ", msg)

ult <- payload$mensal |> filter(competencia == ULTIMO_MES)
conferir(nrow(payload$mensal) == 119, "mensal deveria ter 119 meses")
conferir(all(!MESES_RUINS %in% payload$mensal$competencia),
         "mês defeituoso vazou para a série")
conferir(all(!MESES_AUSENTES %in% payload$mensal$competencia),
         "mês ausente vazou para a série")
conferir(abs(ult$taxa - 33.13) < 0.05, "taxa final deveria ser ~33,13%")
conferir(ult$aprovada - ult$ocupada == ult$vago,
         "identidade vago = aprovada - ocupada quebrou")
conferir(abs(sum(payload$saidas$pct) - 100) < 0.2, "saídas não somam 100%")
conferir(nrow(payload$orgaos) == 15, "esperado 15 órgãos")

json <- toJSON(payload, dataframe = "columns", auto_unbox = TRUE, digits = 4)
writeLines(json, "dados_painel.json")

cat(sprintf("dados_painel.json: %.1f KB\n", file.size("dados_painel.json") / 1024))
for (n in names(payload)) {
  x <- payload[[n]]
  if (is.data.frame(x)) cat(sprintf("  %-14s %5d linhas\n", n, nrow(x)))
}
cat("\ntodas as conferências passaram\n")
