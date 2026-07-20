# ---------------------------------------------------------------------------
# Cargos vagos no Poder Executivo Federal — compilação da série mensal
#
# Lê os arquivos mensais brutos (.ods / .xlsx) publicados pelo Painel Estatístico
# de Pessoal e empilha tudo em dois parquets:
#
#   dados/cargos_por_orgao.parquet        aba 1 — órgão x mês
#   dados/cargos_por_orgao_cargo.parquet  aba 2 — órgão x cargo x mês
#
# Os arquivos vêm em dois layouts ("eras") ao longo do tempo:
#   era 1 — "LotOrgao_DistOcupVagas", 2016-01 a 2021-07
#   era 2 — "CargosVagosVacancias",   2021-08 em diante (traz vacâncias,
#           plano de carreira e cargo em extinção)
# Colunas exclusivas da era 2 ficam NA no período anterior; a coluna `era`
# registra a origem para que o corte da janela seja uma decisão da análise.
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(readxl)
  library(readODS)
  library(dplyr)
  library(purrr)
  library(stringr)
  library(janitor)
  library(arrow)
})

raiz    <- here::here()
brutos  <- file.path(raiz, "dados_brutos")
destino <- file.path(raiz, "dados")
dir.create(destino, showWarnings = FALSE)

# --- leitura ---------------------------------------------------------------

# As abas aparecem com 4 grafias diferentes ao longo da série ("por Órgão",
# "por_Órgão", "por Orgao e Cargo", "por_Órgão_e_Cargo"...), então selecionamos
# por POSIÇÃO: aba 1 = agregado por órgão, aba 2 = detalhe por cargo.
ler_aba <- function(caminho, posicao) {
  if (str_detect(caminho, "\\.ods$")) {
    read_ods(caminho, sheet = posicao, col_types = NA)
  } else {
    read_excel(caminho, sheet = posicao, guess_max = 100000)
  }
}

# ANO_MES vem como "Mar 2017" na era 1 e como 202412 na era 2.
# Normaliza os dois para uma competência inteira no formato AAAAMM.
competencia_do_arquivo <- function(nome) {
  as.integer(str_extract(nome, "20[0-9]{4}"))
}

arquivos <- tibble(
  caminho = list.files(brutos, pattern = "\\.(ods|xlsx)$", full.names = TRUE)
) |>
  mutate(
    arquivo     = basename(caminho),
    competencia = competencia_do_arquivo(arquivo),
    era         = if_else(str_detect(arquivo, regex("LotOrgao", ignore_case = TRUE)), 1L, 2L)
  ) |>
  # "CargosVagosVacancias_202206 (1).ods" é byte-idêntico ao original:
  # mantém uma linha por competência.
  arrange(competencia, arquivo) |>
  distinct(competencia, .keep_all = TRUE)

message("arquivos a processar: ", nrow(arquivos))

ler_um <- function(caminho, arquivo, competencia, era, posicao) {
  message("  [", competencia, "] ", arquivo)
  ler_aba(caminho, posicao) |>
    clean_names() |>
    # descarta a coluna de mês original (formato inconsistente entre eras) e
    # usa a competência derivada do nome do arquivo, que é sempre confiável
    select(-any_of(c("ano_mes", "nome_mes"))) |>
    mutate(
      competencia    = competencia,
      era            = era,
      arquivo_origem = arquivo,
      across(everything(), as.character)
    )
}

compilar <- function(posicao, rotulo) {
  message("\n== aba ", posicao, " (", rotulo, ") ==")
  bruto <- pmap(
    list(arquivos$caminho, arquivos$arquivo, arquivos$competencia, arquivos$era),
    \(caminho, arquivo, competencia, era) ler_um(caminho, arquivo, competencia, era, posicao)
  ) |>
    list_rbind()

  # a coluna de cargos vagos mudou de nome entre eras: VAGAS / VAGA / VAGO
  bruto |>
    mutate(vago = coalesce(!!!syms(intersect(c("vago", "vaga", "vagas"), names(bruto))))) |>
    select(-any_of(setdiff(c("vago", "vaga", "vagas"), "vago"))) |>
    # Alguns arquivos trazem uma linha de TOTAL GERAL no rodapé, sem código de
    # órgão (confirmado em 201901, aba 1). Incluí-la dobra o mês inteiro.
    filter(!is.na(orgao), orgao != "") |>
    mutate(
      competencia = as.integer(competencia),
      era         = as.integer(era),
      data        = as.Date(paste0(substr(competencia, 1, 4), "-", substr(competencia, 5, 6), "-01")),
      ano         = as.integer(substr(competencia, 1, 4)),
      mes         = as.integer(substr(competencia, 5, 6)),
      across(any_of(c("orgao", "cargo")), as.integer),
      across(any_of(c("aprovada", "distribuida", "ocupada", "vago")), as.numeric),
      across(starts_with("vacancia_por_"), as.numeric)
    ) |>
    relocate(competencia, data, ano, mes, era)
}

por_orgao       <- compilar(1, "por órgão")
por_orgao_cargo <- compilar(2, "por órgão e cargo")

write_parquet(por_orgao,       file.path(destino, "cargos_por_orgao.parquet"))
write_parquet(por_orgao_cargo, file.path(destino, "cargos_por_orgao_cargo.parquet"))

# --- conferência -----------------------------------------------------------

message("\n=== resultado ===")
message("por_orgao:       ", nrow(por_orgao), " linhas x ", ncol(por_orgao), " colunas")
message("por_orgao_cargo: ", nrow(por_orgao_cargo), " linhas x ", ncol(por_orgao_cargo), " colunas")

message("\nlinhas por competência (aba 1) — valores fora do padrão indicam mês incompleto:")
por_orgao |>
  count(competencia, era) |>
  as.data.frame() |>
  print(row.names = FALSE)

message("\nmeses ausentes na série:")
esperado <- format(seq(as.Date("2016-01-01"), max(por_orgao$data), by = "month"), "%Y%m")
print(setdiff(as.integer(esperado), unique(por_orgao$competencia)))
