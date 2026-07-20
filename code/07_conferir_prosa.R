# Confere os numeros AFIRMADOS NA PROSA dos artigos contra os dados.
#
# Por que existe: os blocos R geram tabela e grafico a partir do parquet, entao
# eles nunca mentem. O texto em volta, sim -- ele foi escrito a mao e envelhece
# calado quando o pipeline muda. No projeto Relatorios_slu isso aconteceu de
# verdade: os artigos afirmaram "267 pontos" e "15 divergencias" por um tempo,
# enquanto os dados diziam 164 e 9.
#
# Modelo: Relatorios_slu/code/06_conferir_prosa.py (o primeiro dos tres).
# Padrao exigido por docs/CONTEXTO-SITE.md, secao 9.2.
#
# Rode depois de qualquer mudanca em 01_compilar.R / 02_validar.R, e ANTES de
# publicar qualquer artigo:
#     Rscript code/07_conferir_prosa.R
#
# Sai com codigo 1 se alguma afirmacao quebrar.

suppressMessages({
  library(arrow); library(dplyr)
})

RAIZ <- here::here()
orgaos <- read_parquet(file.path(RAIZ, "dados", "cargos_por_orgao.parquet"))
cargos <- read_parquet(file.path(RAIZ, "dados", "cargos_por_orgao_cargo.parquet"))

falhas <- character()

confere <- function(condicao, afirmacao) {
  ok <- isTRUE(condicao)
  cat(sprintf("  %-6s %s\n", if (ok) "OK" else "FALHA", afirmacao))
  if (!ok) falhas <<- c(falhas, afirmacao)
}

# soma o Executivo inteiro numa competencia
tot <- function(cmp) {
  orgaos |>
    filter(competencia == cmp) |>
    summarise(aprovada = sum(aprovada, na.rm = TRUE),
              ocupada  = sum(ocupada,  na.rm = TRUE),
              vago     = sum(vago,     na.rm = TRUE)) |>
    mutate(taxa = 100 * vago / aprovada)
}

# ---------------------------------------------------------------- artigo 01
cat("artigo 01 - a decada em que a maquina encolheu\n")

n_planilhas <- length(list.files(file.path(RAIZ, "dados_brutos"),
                                 pattern = "\\.(ods|xlsx)$"))
confere(n_planilhas == 125, "125 planilhas abertas em dados_brutos")

# 125 planilhas rendem 124 competencias: fev/2019 e jul/2025 faltam na origem.
# Sao duas grandezas distintas -- afirmar as duas evita "corrigir" a errada.
confere(n_distinct(orgaos$competencia) == 124,
        "as planilhas rendem 124 competencias na serie")
confere(min(orgaos$competencia) == 201601 && max(orgaos$competencia) == 202606,
        "a serie vai de janeiro de 2016 a junho de 2026")

meses_calendario <- as.integer(format(
  seq(as.Date("2016-01-01"), as.Date("2026-06-01"), by = "month"), "%Y%m"))
confere(setequal(setdiff(meses_calendario, unique(orgaos$competencia)),
                 c(201902, 202507)),
        "faltam exatamente dois meses na origem: fev/2019 e jul/2025")

ini <- tot(201601)
fim <- tot(202605)   # a tabela do artigo compara com MAIO de 2026, nao junho

confere(ini$aprovada == 788584 && fim$aprovada == 699858,
        "cargos aprovados: 788.584 (jan/2016) -> 699.858 (mai/2026)")
confere(ini$ocupada == 530805 && fim$ocupada == 467971,
        "cargos ocupados: 530.805 -> 467.971")
confere(ini$vago == 257779 && fim$vago == 231887,
        "cargos vagos: 257.779 -> 231.887")
confere(fim$aprovada - ini$aprovada == -88726,
        "variacao dos aprovados: -88.726")
confere(round(100 * (fim$aprovada / ini$aprovada - 1), 1) == -11.3,
        "queda de 11,3% nos aprovados")
confere(round(100 * (fim$ocupada / ini$ocupada - 1), 1) == -11.8,
        "queda de 11,8% nos ocupados")
confere(round(100 * (fim$vago / ini$vago - 1), 1) == -10.0,
        "queda de 10,0% nos vagos")
confere(round(ini$taxa, 2) == 32.69 && round(fim$taxa, 2) == 33.13,
        "taxa de vacancia: 32,69% -> 33,13%")
confere(round(fim$taxa - ini$taxa, 2) == 0.44,
        "a taxa sobe 0,44 p.p. em dez anos (praticamente parada)")

# ---------------------------------------------------------------- artigo 04
cat("\nartigo 04 - os servidores em cargos que a lei ja extinguiu\n")

# a coluna guarda "S"/"N" (nao "Sim"/"Nao") -- e ha vazio e <NA> tambem
ext <- cargos |>
  filter(competencia == 202605, cargo_em_extincao == "S") |>
  summarise(ocupada = sum(ocupada, na.rm = TRUE)) |>
  pull(ocupada)
confere(round(ext / 1000) == 38,
        sprintf("38 mil servidores em cargos em extincao (dado: %s)",
                format(ext, big.mark = ".", decimal.mark = ",")))

# ---------------------------------------------------------------- artigo 05
cat("\nartigo 05 - onde faltam\n")

# o "% do vago total" da tabela do artigo tem como denominador TODO o vago da
# competencia -- ha tambem nivel "NM" (1.423 linhas) e 11 sem nivel. Por isso a
# coluna soma 99,8% e nao 100%.
vago_total <- cargos |>
  filter(competencia == 202605) |>
  summarise(v = sum(vago, na.rm = TRUE)) |>
  pull(v)

niv <- cargos |>
  filter(competencia == 202605, nivel %in% c("NA", "NI", "NS")) |>
  group_by(nivel) |>
  summarise(aprovada = sum(aprovada, na.rm = TRUE),
            ocupada  = sum(ocupada,  na.rm = TRUE),
            vago     = sum(vago,     na.rm = TRUE), .groups = "drop") |>
  mutate(taxa = 100 * vago / aprovada,
         pct_do_vago = 100 * vago / vago_total)
g <- \(n, col) niv[[col]][niv$nivel == n]

confere(g("NS", "aprovada") == 438397 && g("NS", "ocupada") == 301334 &&
        g("NS", "vago") == 137063,
        "nivel superior: 438.397 aprovados, 301.334 ocupados, 137.063 vagos")
confere(g("NI", "aprovada") == 247417 && g("NI", "ocupada") == 153742 &&
        g("NI", "vago") == 93675,
        "nivel intermediario: 247.417 / 153.742 / 93.675")
confere(g("NA", "aprovada") == 13478 && g("NA", "ocupada") == 12749 &&
        g("NA", "vago") == 729,
        "nivel apoio: 13.478 / 12.749 / 729")
confere(round(g("NS", "taxa"), 1) == 31.3 && round(g("NI", "taxa"), 1) == 37.9 &&
        round(g("NA", "taxa"), 1) == 5.4,
        "taxas por nivel: 31,3% / 37,9% / 5,4%")
confere(round(g("NS", "pct_do_vago"), 1) == 59.1 &&
        round(g("NI", "pct_do_vago"), 1) == 40.4 &&
        round(g("NA", "pct_do_vago"), 1) == 0.3,
        "participacao no vago total: 59,1% / 40,4% / 0,3%")
confere(g("NI", "taxa") > g("NS", "taxa") && g("NS", "vago") > g("NI", "vago"),
        "o intermediario tem a pior taxa; o superior concentra o volume")

# A armadilha do "NA" lido como nulo. O artigo fala do "periodo antigo", que na
# base e a era 1 -- nao a serie inteira (que tem 177.571 linhas de apoio).
n_apoio <- cargos |> filter(nivel == "NA", era == 1) |> nrow()
confere(n_apoio == 100694,
        sprintf("100.694 linhas de apoio na era 1 (o que o na=NA apagaria) (dado: %s)",
                format(n_apoio, big.mark = ".", decimal.mark = ",")))

# serie de janeiro, por nivel -- a tabela de 2016 a 2026 do artigo
serie_niv <- cargos |>
  filter(mes == 1, nivel %in% c("NA", "NI", "NS")) |>
  group_by(ano, nivel) |>
  summarise(aprovada = sum(aprovada, na.rm = TRUE),
            ocupada  = sum(ocupada,  na.rm = TRUE), .groups = "drop") |>
  mutate(taxa = 100 * (aprovada - ocupada) / aprovada)
t_niv <- \(a, n) round(serie_niv$taxa[serie_niv$ano == a & serie_niv$nivel == n], 1)

confere(t_niv(2016, "NI") == 33.8 && t_niv(2024, "NI") == 40.1 &&
        t_niv(2026, "NI") == 37.6,
        "intermediario: 33,8% (2016) -> pico 40,1% (2024) -> 37,6% (2026)")
confere(all(abs(sapply(c(2016, 2018, 2020, 2022, 2024, 2026),
                       \(a) t_niv(a, "NS")) - 32) <= 1.1),
        "superior: uma linha reta, entre 31,7% e 32,8% na decada")
confere(t_niv(2016, "NA") == 11.0 && t_niv(2026, "NA") == 5.3,
        "apoio: cai de 11,0% para 5,3% (efeito da extincao, nao de provimento)")

# ------------------------------------------------------------------ pendente
cat("\n[pendente] artigos 02, 03 e 06 ainda nao tem afirmacoes conferidas aqui.\n")
cat("           Ler a prosa de cada um e acrescentar, como acima, antes de publicar.\n")

cat("\n")
if (length(falhas)) {
  cat(sprintf("%d afirmacao(oes) da prosa nao batem mais com os dados:\n",
              length(falhas)))
  for (f in falhas) cat("  -", f, "\n")
  quit(status = 1)
}
cat("Todas as afirmacoes conferidas batem com os dados.\n")
