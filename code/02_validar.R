# Conferências de integridade sobre os parquets compilados.
# Roda depois de 01_compilar.R. Serve para pegar erro de empilhamento antes
# que ele vire número errado em artigo publicado.

suppressPackageStartupMessages({library(arrow); library(dplyr)})

orgaos <- read_parquet(here::here("dados", "cargos_por_orgao.parquet"))
cargos <- read_parquet(here::here("dados", "cargos_por_orgao_cargo.parquet"))

cat("== dimensões ==\n")
cat("por_orgao:      ", nrow(orgaos), "x", ncol(orgaos), "\n")
cat("por_orgao_cargo:", nrow(cargos), "x", ncol(cargos), "\n")
cat("meses:", n_distinct(orgaos$competencia), "| de", min(orgaos$competencia),
    "a", max(orgaos$competencia), "\n\n")

cat("== linhas de TOTAL GERAL vazaram? ==\n")
# alguns arquivos trazem um total no rodapé, sem código de órgão
cat("linhas com orgao NA em por_orgao:      ", sum(is.na(orgaos$orgao)), "\n")
cat("linhas com orgao NA em por_orgao_cargo:", sum(is.na(cargos$orgao)), "\n")

cat("\n== meses com variação mensal anômala (>2%) ==\n")
# a variação normal do painel é < 1% ao mês; acima disso é quebra de série
serie <- orgaos |>
  group_by(competencia) |>
  summarise(aprovada = sum(aprovada), ocupada = sum(ocupada), .groups = "drop") |>
  arrange(competencia) |>
  mutate(var_aprov = round(100 * (aprovada - lag(aprovada)) / lag(aprovada), 2),
         var_ocup  = round(100 * (ocupada  - lag(ocupada))  / lag(ocupada),  2))
anomalos <- serie |> filter(abs(var_aprov) > 2 | abs(var_ocup) > 2)
if (nrow(anomalos) == 0) cat("nenhum\n") else
  print(as.data.frame(anomalos), row.names = FALSE)

cat("\n== identidade vago == aprovada - ocupada ==\n")
quebras <- orgaos |> filter(abs(vago - (aprovada - ocupada)) > 0)
cat("linhas que violam:", nrow(quebras), "de", nrow(orgaos), "\n")
if (nrow(quebras) > 0) print(head(as.data.frame(quebras), 10))

cat("\n== as duas abas batem entre si? ==\n")
# agregando a aba detalhada por órgão-mês, deve reproduzir a aba agregada
comparacao <- cargos |>
  group_by(competencia, orgao) |>
  summarise(across(c(aprovada, ocupada, vago), \(x) sum(x, na.rm = TRUE)), .groups = "drop") |>
  inner_join(orgaos, by = c("competencia", "orgao"), suffix = c("_cargo", "_orgao")) |>
  mutate(dif_aprovada = aprovada_cargo - aprovada_orgao,
         dif_ocupada  = ocupada_cargo  - ocupada_orgao)

cat("pares órgão-mês comparados:", nrow(comparacao), "\n")
cat("divergentes em aprovada:", sum(comparacao$dif_aprovada != 0), "\n")
cat("divergentes em ocupada: ", sum(comparacao$dif_ocupada  != 0), "\n")

cat("\n== colunas da era 2 estão realmente vazias na era 1? ==\n")
era2 <- c("plano_carreira", "cargo_em_extincao", "vacancia_por_aposentadoria")
for (v in intersect(era2, names(cargos))) {
  n1 <- sum(!is.na(cargos[[v]][cargos$era == 1]))
  cat(sprintf("  %-30s não-NA na era 1: %d\n", v, n1))
}

cat("\n== vacância: fluxo mensal ou acumulado? ==\n")
# se for fluxo, os valores de um mesmo par órgão-cargo oscilam mês a mês;
# se for acumulado, crescem de forma monotônica
amostra <- cargos |>
  filter(era == 2, !is.na(vacancia_por_aposentadoria)) |>
  arrange(orgao, cargo, competencia) |>
  group_by(orgao, cargo) |>
  filter(n() >= 12) |>
  mutate(delta = vacancia_por_aposentadoria - lag(vacancia_por_aposentadoria)) |>
  ungroup()

cat("proporção de deltas negativos:",
    round(mean(amostra$delta < 0, na.rm = TRUE), 4), "\n")
cat("  (perto de 0 => série acumulada; bem acima de 0 => fluxo mensal)\n")

cat("\n== total de cargos vagos, primeiro e último mês ==\n")
orgaos |>
  filter(competencia %in% range(orgaos$competencia)) |>
  group_by(competencia) |>
  summarise(orgaos = n(), across(c(aprovada, ocupada, vago), \(x) sum(x, na.rm = TRUE))) |>
  as.data.frame() |>
  print(row.names = FALSE)
