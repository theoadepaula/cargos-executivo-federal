# ---------------------------------------------------------------------------
# De-para de órgãos: identidade institucional estável ao longo da década
#
# O código do órgão NÃO é estável. Reformas ministeriais renomeiam, trocam o
# código, partem e fundem pastas. Somar por `orgao` ou por `nome_orgao` numa
# série de dez anos produz séries quebradas.
#
# Este script produz dados/depara_orgaos.parquet, com três chaves:
#
#   orgao      código original, como vem na fonte
#   entidade   identidade institucional estável — use ESTA em séries longas
#   bloco      agrupamento maior, para os casos de cisão que não têm
#              correspondência 1:1 (ver seção "cisões" abaixo)
#
# Para os ~178 códigos estáveis, entidade == orgao. O de-para só age sobre os
# casos problemáticos, todos documentados com evidência e nível de confiança.
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tibble)
})

o <- read_parquet(here::here("dados", "cargos_por_orgao.parquet"))

# --- sucessões 1:1 ---------------------------------------------------------
# Casos em que uma instituição trocou de código. Verificados um a um: mesma
# sigla, períodos encadeados, e o código antigo vira uma casca residual (poucos
# cargos, zero ocupados) em vez de morrer de imediato.

sucessoes <- tribble(
  ~orgao, ~entidade, ~entidade_nome,                         ~confianca, ~evidencia,
  40111L, 40211L, "Ministério do Meio Ambiente",             "alta",  "40111 encerra 202309 com 1.211 aprovados; 40211 abre 202310 com exatamente 1.211",
  40211L, 40211L, "Ministério do Meio Ambiente",             "alta",  "código vigente",
  40105L, 40115L, "Ministério da Defesa",                    "alta",  "sobreposição de 2 meses; 40105 vira casca",
  40115L, 40115L, "Ministério da Defesa",                    "alta",  "código vigente",
  40106L, 40116L, "Advocacia-Geral da União",                "alta",  "40106 cai de 8.856 para 1 cargo em 202310, com 0 ocupados, enquanto 40116 abre com 9.074",
  40116L, 40116L, "Advocacia-Geral da União",                "alta",  "código vigente",
  13000L, 13300L, "Ministério da Agricultura e Pecuária",    "alta",  "migração gradual 202311-202405; soma dos dois preserva o total",
  13300L, 13300L, "Ministério da Agricultura e Pecuária",    "alta",  "código vigente",
  40112L, 40100L, "Min. da Integração e Desenv. Regional",   "alta",  "40112 encerra 202304 com 1.160; 40100 abre 202305 com 1.051 (-9,4%)",
  40100L, 40100L, "Min. da Integração e Desenv. Regional",   "alta",  "código vigente",
  40107L, 54100L, "Ministério da Cultura",                   "media", "mesma sigla MINC; lacuna de 2019 a 2023 (pasta extinta e recriada)",
  54100L, 54100L, "Ministério da Cultura",                   "media", "código vigente",
  23000L, 33100L, "Ministério da Previdência Social",        "media", "mesma sigla MPS; lacuna 2019-2023",
  33100L, 33100L, "Ministério da Previdência Social",        "media", "código vigente",
  56000L, 40200L, "Ministério das Cidades",                  "media", "mesma sigla MCID; lacuna 2019-2023",
  40200L, 40200L, "Ministério das Cidades",                  "media", "código vigente",
  42000L, 13100L, "Min. do Desenv. Agrário e Agric. Familiar","media","mesma sigla MDA; lacuna 2017-2023",
  13100L, 13100L, "Min. do Desenv. Agrário e Agric. Familiar","media","código vigente",
  32100L, 32396L, "Agência Nacional de Mineração",           "alta",  "DNPM encerra 201906, ANM abre 201906 — sucessão legal (Lei 13.575/2017)",
  32396L, 32396L, "Agência Nacional de Mineração",           "alta",  "código vigente",
  40403L, 40403L, "Fundação Casa de Rui Barbosa",            "alta",  "código estável",
  40413L, 40403L, "Fundação Casa de Rui Barbosa",            "baixa", "aparece SÓ em 202606, o mês corrompido — provável artefato"
)

# --- cisões: o núcleo econômico -------------------------------------------
# O antigo Ministério da Fazenda (17000) virou Ministério da Economia e depois
# se desdobrou em cinco pastas. Não existe correspondência 1:1: nenhum código
# novo "é" o 17000. A única comparação honesta ao longo da década é no nível do
# BLOCO — somando todas as pastas do núcleo econômico.
#
# O mesmo vale para o Ministério do Trabalho e Previdência (33000), que se
# partiu em MPS (33100) e MTE (33200) em 2023/2024.

blocos <- tribble(
  ~orgao, ~bloco,             ~bloco_nome,
  17000L, "economico",        "Núcleo econômico (ex-Fazenda/Economia)",
  17300L, "economico",        "Núcleo econômico (ex-Fazenda/Economia)",
  17400L, "economico",        "Núcleo econômico (ex-Fazenda/Economia)",
  17500L, "economico",        "Núcleo econômico (ex-Fazenda/Economia)",
  17600L, "economico",        "Núcleo econômico (ex-Fazenda/Economia)",
  17700L, "economico",        "Núcleo econômico (ex-Fazenda/Economia)",
  20113L, "economico",        "Núcleo econômico (ex-Fazenda/Economia)",
  28000L, "economico",        "Núcleo econômico (ex-Fazenda/Economia)",
  33000L, "trabalho_prev",    "Trabalho e Previdência",
  33100L, "trabalho_prev",    "Trabalho e Previdência",
  33200L, "trabalho_prev",    "Trabalho e Previdência",
  26000L, "trabalho_prev",    "Trabalho e Previdência",
  23000L, "trabalho_prev",    "Trabalho e Previdência"
)

# --- monta a tabela final --------------------------------------------------

base <- o |>
  group_by(orgao) |>
  summarise(sigla_orgao = last(sigla_orgao), nome_orgao = last(nome_orgao),
            primeiro = min(competencia), ultimo = max(competencia),
            meses = n(), aprovada_max = max(aprovada), .groups = "drop")

depara <- base |>
  left_join(sucessoes, by = "orgao") |>
  left_join(blocos, by = "orgao") |>
  mutate(
    # códigos sem regra explícita são estáveis: entidade == o próprio código
    entidade      = coalesce(entidade, orgao),
    entidade_nome = coalesce(entidade_nome, nome_orgao),
    confianca     = coalesce(confianca, "estavel"),
    evidencia     = coalesce(evidencia, "código presente sem troca ao longo da série"),
    bloco         = coalesce(bloco, as.character(orgao)),
    bloco_nome    = coalesce(bloco_nome, nome_orgao)
  ) |>
  relocate(orgao, entidade, bloco)

write_parquet(depara, here::here("dados", "depara_orgaos.parquet"))
write.csv(depara, here::here("dados", "depara_orgaos.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")

# --- conferência -----------------------------------------------------------

message("códigos mapeados: ", nrow(depara))
message("entidades distintas: ", n_distinct(depara$entidade))
message("")
message("por nível de confiança:")
print(table(depara$confianca))

message("\ncódigos que o de-para reagrupa (entidade != orgao):")
depara |>
  filter(entidade != orgao) |>
  select(orgao, sigla_orgao, entidade, entidade_nome, confianca) |>
  as.data.frame() |> print(row.names = FALSE)

message("\n== teste: a soma por entidade preserva o total do mês? ==")
teste <- o |>
  left_join(depara |> select(orgao, entidade), by = "orgao") |>
  group_by(competencia) |>
  summarise(total_orgao = sum(aprovada),
            total_entidade = sum(aprovada), .groups = "drop") |>
  mutate(bate = total_orgao == total_entidade)
message("meses em que o total se preserva: ", sum(teste$bate), " de ", nrow(teste))
