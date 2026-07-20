# ---------------------------------------------------------------------------
# Prepara as tabelas que alimentam o painel.
#
# O painel NÃO deve ler o parquet de 1,6 milhão de linhas direto. Este script
# produz tabelas agregadas, pequenas e já limpas dos meses defeituosos, prontas
# para importar no Power BI.
#
# Saída em painel/dados/ — um CSV por tabela, mais um Parquet equivalente.
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tidyr)
})

raiz    <- here::here()
destino <- file.path(raiz, "painel", "dados")
dir.create(destino, recursive = TRUE, showWarnings = FALSE)

orgaos <- read_parquet(file.path(raiz, "dados", "cargos_por_orgao.parquet"))
cargos <- read_parquet(file.path(raiz, "dados", "cargos_por_orgao_cargo.parquet"))
depara <- read_parquet(file.path(raiz, "dados", "depara_orgaos.parquet"))

# Meses com quebra de série documentada — ver artigos 1 e 6.
# São EXCLUÍDOS das agregações, mas registrados na tabela `meses_excluidos`
# para que o painel possa marcá-los visualmente em vez de escondê-los.
MESES_RUINS <- c(201803, 202504, 202505, 202506, 202606)
MESES_AUSENTES <- c(201902, 202507)

salvar <- function(x, nome) {
  write.csv(x, file.path(destino, paste0(nome, ".csv")),
            row.names = FALSE, fileEncoding = "UTF-8")
  write_parquet(x, file.path(destino, paste0(nome, ".parquet")))
  message(sprintf("  %-28s %6d linhas", nome, nrow(x)))
}

message("gerando tabelas do painel...")

# --- 1. série mensal agregada (a espinha dorsal do painel) ------------------

serie_mensal <- orgaos |>
  filter(!competencia %in% MESES_RUINS) |>
  group_by(competencia, data, ano, mes, era) |>
  summarise(across(c(aprovada, distribuida, ocupada, vago), sum), .groups = "drop") |>
  mutate(
    nunca_distribuido = aprovada - distribuida,
    vago_pos_distrib  = distribuida - ocupada,
    taxa_vacancia     = round(100 * vago / aprovada, 2),
    pct_fantasma      = round(100 * nunca_distribuido / vago, 2)
  ) |>
  arrange(competencia)

salvar(serie_mensal, "serie_mensal")

# --- 2. série por entidade (usa o de-para; para filtros do painel) ---------

serie_entidade <- orgaos |>
  filter(!competencia %in% MESES_RUINS) |>
  left_join(depara |> select(orgao, entidade, entidade_nome, bloco), by = "orgao") |>
  group_by(competencia, data, ano, entidade, entidade_nome, bloco) |>
  summarise(across(c(aprovada, distribuida, ocupada, vago), sum), .groups = "drop") |>
  mutate(
    nunca_distribuido = aprovada - distribuida,
    vago_pos_distrib  = distribuida - ocupada,
    taxa_vacancia     = round(100 * vago / pmax(aprovada, 1), 2)
  )

salvar(serie_entidade, "serie_entidade")

# --- 3. recorte por nível de escolaridade ----------------------------------
# Atenção: "NA" é o código de Nível Apoio, não valor ausente.

serie_nivel <- cargos |>
  filter(!competencia %in% MESES_RUINS, !is.na(nivel)) |>
  group_by(competencia, data, ano, nivel) |>
  summarise(across(c(aprovada, distribuida, ocupada, vago),
                   \(x) sum(x, na.rm = TRUE)), .groups = "drop") |>
  mutate(
    nivel_nome    = recode(nivel, "NA" = "Nível de apoio", "NI" = "Nível intermediário",
                           "NM" = "Nível médio", "NS" = "Nível superior"),
    taxa_vacancia = round(100 * vago / pmax(aprovada, 1), 2)
  )

salvar(serie_nivel, "serie_nivel")

# --- 4. recorte por plano de carreira (só era 2) ---------------------------

serie_carreira <- cargos |>
  filter(!competencia %in% MESES_RUINS, era == 2, !is.na(plano_carreira),
         plano_carreira != "") |>
  group_by(competencia, data, ano, plano_carreira) |>
  summarise(across(c(aprovada, distribuida, ocupada, vago),
                   \(x) sum(x, na.rm = TRUE)), .groups = "drop") |>
  mutate(taxa_vacancia = round(100 * vago / pmax(aprovada, 1), 2))

salvar(serie_carreira, "serie_carreira")

# --- 5. composição das saídas (acumulada — ver ressalva do artigo 3) -------

vac <- grep("^vacancia_por_", names(cargos), value = TRUE)

saidas <- cargos |>
  filter(!competencia %in% MESES_RUINS, era == 2) |>
  group_by(competencia, data, ano) |>
  summarise(across(all_of(vac), \(x) sum(x, na.rm = TRUE)), .groups = "drop") |>
  pivot_longer(all_of(vac), names_to = "motivo", values_to = "acumulado") |>
  mutate(motivo = recode(sub("vacancia_por_", "", motivo),
    aposentadoria    = "Aposentadoria",
    posse_cargo_inac = "Posse em cargo inacumulável",
    exoneracao       = "Exoneração",
    falecimento      = "Falecimento",
    demissao         = "Demissão",
    promocao         = "Promoção",
    readaptacao      = "Readaptação"))

salvar(saidas, "saidas_acumuladas")

# --- 6. cargos em extinção -------------------------------------------------

extincao <- cargos |>
  filter(!competencia %in% MESES_RUINS, era == 2, cargo_em_extincao == "S") |>
  group_by(competencia, data, ano, nome_cargo, nivel) |>
  summarise(ocupada = sum(ocupada, na.rm = TRUE),
            aprovada = sum(aprovada, na.rm = TRUE),
            orgaos = n_distinct(orgao), .groups = "drop") |>
  filter(ocupada > 0)

salvar(extincao, "cargos_em_extincao")

# --- 7. tabela de meses problemáticos (para o painel MARCAR, não esconder) --

meses_excluidos <- bind_rows(
  tibble(competencia = MESES_RUINS,    tipo = "quebra de série"),
  tibble(competencia = MESES_AUSENTES, tipo = "não publicado")
) |>
  mutate(
    data = as.Date(paste0(substr(competencia,1,4), "-", substr(competencia,5,6), "-01")),
    motivo = case_when(
      competencia == 201803 ~ "Dupla contagem: 7 códigos novos publicados sobre os antigos",
      competencia == 202606 ~ "Vacâncias inflam de 1,2x a 4,4x; aprovada salta 3,3%",
      competencia %in% c(202504,202505,202506) ~ "Bolha em aprovada: +5,8% revertidos em 2 meses",
      competencia == 201902 ~ "Arquivo não existe no acervo publicado",
      competencia == 202507 ~ "Arquivo não existe no acervo publicado")
  )

salvar(meses_excluidos, "meses_excluidos")

message("\npronto. tabelas em painel/dados/")
message("ultimo mes valido da serie: ", max(serie_mensal$competencia))
