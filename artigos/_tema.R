# ---------------------------------------------------------------------------
# Tema e paleta compartilhados pelos artigos.
#
# A paleta foi validada para daltonismo (protanopia, deuteranopia, tritanopia):
# separação mínima ΔE 17,6 entre pares adjacentes, acima do piso de 8. Não troque
# as cores sem revalidar.
#
# Uso no início de cada artigo:  source(here::here("artigos", "_tema.R"))
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(scales); library(ggiraph)
  library(theoviz)
})

# --- tabelas --------------------------------------------------------------
# Tema canonico das tabelas gt, aprovado por Theo em 2026-07-19 e comum a todos
# os projetos. Vem do pacote `theoviz` (antes era um source() do _comum, que
# subia um nivel na arvore do OneDrive e quebraria ao migrar para o site).
# Hoje os artigos deste projeto nao tem nenhuma tabela -- so graficos --, mas
# quando tiverem, e por aqui:
#
#     dados |> tabela(titulo = "...", subtitulo = "...")
#
# Nao reimplemente o estilo aqui; edite o pacote theoviz.
#
# O `modo = "escuro"` nao e detalhe: sem ele o gt crava `background-color:
# #FFFFFF` inline, e nenhuma folha de estilo derruba estilo inline -- a tabela
# sairia como retangulo branco no meio da pagina escura do artigo.
tabela <- function(...) tabela_gt(..., modo = "escuro")

# --- paleta ---------------------------------------------------------------
# As cores vem do theoviz, que e a fonte unica -- nao literais aqui. A validacao
# para daltonismo e os limites de contraste estao documentados la.
# Os NOMES locais (COR$s1, COR$ink2, ...) sao preservados de proposito: os .qmd
# ja escritos dependem deles.

#
# MODO ESCURO (2026-08-15): os artigos vao ao ar em pagina escura e ate aqui
# pediam ao theoviz o modo CLARO. O efeito era visivel em toda figura -- o
# `surface` abaixo e pintado no `plot.background`, entao cada grafico levava um
# retangulo #fcfcfb, quase branco, para dentro da pagina quase preta.
.p <- paleta(modo = "escuro")
.t <- tinta(modo = "escuro")

COR <- list(
  s1      = unname(.p[["s1"]]),  # azul     — aprovados / nunca distribuído
  s2      = unname(.p[["s2"]]),  # verde    — ocupados
  s3      = unname(.p[["s3"]]),  # magenta  — vagos
  ink     = unname(.t[["forte"]]),
  ink2    = unname(.t[["media"]]),
  ink3    = unname(.t[["fraca"]]),
  grid    = unname(.t[["grade"]]),
  eixo    = unname(.t[["eixo"]]),
  surface = unname(.t[["fundo"]])
)

# --- meses que não entram em nenhum gráfico -------------------------------
# Ver artigo 6 e painel/dados/meses_excluidos.csv

MESES_RUINS    <- c(201803, 202504, 202505, 202506, 202606)
MESES_AUSENTES <- c(201902, 202507)

comp_para_data <- function(x) {
  as.Date(paste0(substr(x, 1, 4), "-", substr(x, 5, 6), "-01"))
}

# --- tema ------------------------------------------------------------------

tema_cargos <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      text             = element_text(colour = COR$ink2),
      plot.title       = element_text(colour = COR$ink, face = "bold",
                                      size = rel(1.05), margin = margin(b = 2)),
      plot.subtitle    = element_text(colour = COR$ink3, size = rel(.88),
                                      margin = margin(b = 12)),
      plot.caption     = element_text(colour = COR$ink3, size = rel(.78),
                                      hjust = 0, margin = margin(t = 12)),
      plot.caption.position = "plot",
      plot.title.position   = "plot",
      axis.text        = element_text(colour = COR$ink3, size = rel(.85)),
      axis.title       = element_blank(),
      panel.grid.major.y = element_line(colour = COR$grid, linewidth = .4),
      panel.grid.major.x = element_blank(),
      panel.grid.minor   = element_blank(),
      legend.position  = "none",
      plot.background  = element_rect(fill = COR$surface, colour = NA),
      panel.background = element_rect(fill = COR$surface, colour = NA),
      plot.margin      = margin(6, 14, 6, 6)
    )
}

# --- camada que marca os meses defeituosos --------------------------------
# Regra do projeto: meses ruins aparecem MARCADOS, nunca apagados.

camada_meses_ruins <- function(rotular = TRUE) {
  faixas <- tibble::tibble(
    ini = comp_para_data(c(201803, 202504, 202606)),
    fim = comp_para_data(c(201804, 202507, 202607))
  )
  lacunas <- comp_para_data(MESES_AUSENTES)
  list(
    annotate("rect", xmin = faixas$ini, xmax = faixas$fim,
             ymin = -Inf, ymax = Inf, fill = COR$ink3, alpha = .13),
    annotate("segment", x = lacunas, xend = lacunas, y = -Inf, yend = Inf,
             colour = COR$ink3, linetype = "22", linewidth = .4, alpha = .7)
  )
}

# --- helpers ---------------------------------------------------------------

# Insere NA nos meses ausentes para que a linha QUEBRE em vez de interpolar.
quebrar_lacunas <- function(df, col_data = "data") {
  faltantes <- tibble::tibble(!!col_data := comp_para_data(MESES_AUSENTES))
  dplyr::bind_rows(df, faltantes) |> dplyr::arrange(.data[[col_data]])
}

# Eixo de datas da série: marcas a cada 2 anos, sem passar de 2026.
# (a expansão à direita abre espaço para os rótulos diretos, mas não deve
#  criar marcas em anos onde não existe dado)
escala_x_serie <- function(dir = .13) {
  scale_x_date(breaks = seq(as.Date("2016-01-01"), as.Date("2026-01-01"),
                            by = "2 years"),
               date_labels = "%Y",
               expand = expansion(mult = c(.02, dir)))
}

mil <- function(x) format(round(x / 1000), big.mark = ".", trim = TRUE)
pt  <- function(x, d = 0) format(round(x, d), big.mark = ".", decimal.mark = ",",
                                 nsmall = d, trim = TRUE)

# rótulo direto no fim da linha
rotulo_fim <- function(df, x, y, texto, cor, dx = 40) {
  ultimo <- df |> dplyr::filter(!is.na(.data[[y]])) |> dplyr::slice_max(.data[[x]], n = 1)
  list(
    # inherit.aes = FALSE: o rótulo vem de um data.frame largo próprio e não deve
    # herdar mapeamentos globais (quebra quando o gráfico usa formato longo)
    geom_point(data = ultimo, aes(x = .data[[x]], y = .data[[y]]),
               colour = cor, size = 1.9, inherit.aes = FALSE),
    annotate("text", x = ultimo[[x]] + dx, y = ultimo[[y]],
             label = texto, colour = cor, hjust = 0, size = 3.5,
             fontface = "bold")
  )
}

# --- interatividade (ggiraph) ---------------------------------------------
#
# Por que ggiraph e não plotly: o ggiraph renderiza o PRÓPRIO ggplot em SVG e
# só acrescenta os eventos. Tema, faixas de meses ruins, rótulos diretos,
# subtítulo e fonte sobrevivem intactos. O ggplotly() foi testado em 2026-07-19
# e destruiu o gráfico — apagou as três linhas, as faixas, o subtítulo e a
# fonte. Não troque sem repetir o teste.

# O tooltip NAO usa COR$surface. No modo escuro o `surface` e o proprio chao da
# pagina (#0d1014), e um tooltip da cor do chao nao se destaca da figura -- ele
# flutua ACIMA dela, e no sistema visual do site o que fica acima do chao e a
# chapa. Sombra tambem sai: o sistema separa plano por superficie e filete, nao
# por sombra.
TOOLTIP_CSS <- sprintf(
  paste0("background:%s;color:%s;padding:7px 10px;border:1px solid %s;",
         "border-radius:0;",
         "font-family:inherit;font-size:12.5px;line-height:1.45;"),
  site("chapa"), site("titulo"), site("filete"))

# Banda vertical invisível, uma por período. Serve de alvo de hover — bem maior
# que a linha — e mostra num tooltip só todas as séries daquele mês. É o
# equivalente ao crosshair dos gráficos de linha.
banda_hover <- function(df, col_x = "data", col_tip = "tip", meia_largura = 16) {
  d <- df[!is.na(df[[col_x]]) & !is.na(df[[col_tip]]), ]
  d <- data.frame(x = d[[col_x]], tip = d[[col_tip]])
  geom_rect_interactive(
    data = d, inherit.aes = FALSE,
    aes(xmin = x - meia_largura, xmax = x + meia_largura,
        ymin = -Inf, ymax = Inf, tooltip = tip, data_id = as.character(x)),
    fill = "transparent")
}

# Envelope padrão. `tipo` decide só o realce de hover: na série quem acende é a
# banda; na barra, a própria barra.
girafe_cargos <- function(p, altura = 4.2, tipo = c("serie", "barra")) {
  tipo <- match.arg(tipo)
  # O realce da banda era `#8987811c` -- o cinza QUENTE do sistema visual
  # anterior, com 11% de alfa, cravado a mao. Passa a sair do pacote: a chapa do
  # site com alfa e o "algo acabou de acender aqui" do sistema novo.
  css <- if (tipo == "serie") paste0("fill:", site("filete"), "80;stroke:none;")
         else                 "fill-opacity:.72;stroke:none;"
  girafe(
    ggobj = p, width_svg = 8, height_svg = altura,
    options = list(
      opts_hover(css = css),
      opts_tooltip(css = TOOLTIP_CSS, opacity = 1, use_fill = FALSE,
                   offx = 12, offy = 12),
      opts_toolbar(saveaspng = TRUE, position = "topright",
                   pngname = "grafico-cargos"),
      opts_selection(type = "none"),
      opts_sizing(rescale = TRUE, width = 1)))
}

# Formatação dos tooltips
tip_data <- function(d) format(d, "%b/%Y")
tip_n    <- function(x) format(x, big.mark = ".", decimal.mark = ",", trim = TRUE)

knitr::opts_chunk$set(
  dev = "png", dpi = 160, fig.width = 8, fig.height = 4.2,
  fig.showtext = FALSE, warning = FALSE, message = FALSE, echo = FALSE
)
