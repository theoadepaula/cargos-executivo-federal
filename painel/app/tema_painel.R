# ---------------------------------------------------------------------------
# Tema, paleta e helpers do painel.
#
# Espelha artigos/_tema.R, mas com duas diferenças obrigatórias por rodar em
# WebAssembly:
#   1. `arrow` NÃO existe em webR. Leitura de parquet é com `nanoparquet`.
#   2. `here::here()` não faz sentido: o Shiny já roda na pasta do app.
#
# A paleta é a mesma dos artigos, validada para daltonismo (separação mínima
# ΔE 17,6). Não troque as cores sem revalidar.
# ---------------------------------------------------------------------------

COR <- list(
  s1      = "#2a78d6",  # azul     — aprovados / nunca distribuído
  s2      = "#008300",  # verde    — ocupados
  s3      = "#e87ba4",  # magenta  — vagos
  ink     = "#0b0b0b",
  ink2    = "#52514e",
  ink3    = "#898781",
  grid    = "#e1e0d9",
  surface = "#fcfcfb"
)

# Meses que não entram em nenhum cálculo. Os cinco primeiros existem no acervo
# mas estão quebrados; os dois últimos nunca foram publicados.
MESES_RUINS    <- c(201803, 202504, 202505, 202506, 202606)
MESES_AUSENTES <- c(201902, 202507)
ULTIMO_MES     <- 202605

comp_para_data <- function(x) {
  as.Date(paste0(substr(x, 1, 4), "-", substr(x, 5, 6), "-01"))
}

# --- formatação pt-BR ------------------------------------------------------

pt <- function(x, d = 0) {
  formatC(x, format = "f", digits = d, big.mark = ".", decimal.mark = ",")
}
mil <- function(x) paste0(pt(x / 1000), " mil")
pp  <- function(x, d = 2) paste0(if_else(x >= 0, "+", "−"), pt(abs(x), d))

# --- tema ggplot -----------------------------------------------------------

tema_painel <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      text               = element_text(colour = COR$ink2),
      plot.title         = element_text(colour = COR$ink, face = "bold",
                                        size = rel(1.02), margin = margin(b = 2)),
      plot.subtitle      = element_text(colour = COR$ink3, size = rel(.86),
                                        margin = margin(b = 10)),
      plot.caption       = element_text(colour = COR$ink3, size = rel(.76),
                                        hjust = 0, margin = margin(t = 10)),
      plot.caption.position = "plot",
      plot.title.position   = "plot",
      axis.text          = element_text(colour = COR$ink3, size = rel(.84)),
      axis.title         = element_blank(),
      panel.grid.major.y = element_line(colour = COR$grid, linewidth = .4),
      panel.grid.major.x = element_blank(),
      panel.grid.minor   = element_blank(),
      legend.position    = "none",
      # fundo transparente: o painel herda a superfície do bslib
      plot.background    = element_rect(fill = NA, colour = NA),
      panel.background   = element_rect(fill = NA, colour = NA),
      plot.margin        = margin(4, 12, 4, 4)
    )
}

# --- camada dos meses defeituosos ------------------------------------------
# Princípio que governa o painel: mês defeituoso aparece MARCADO, nunca apagado.

camada_meses_ruins <- function() {
  faixas <- data.frame(
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

# Insere NA nos sete meses fora da série para que a linha QUEBRE em vez de
# interpolar por cima do buraco. Vale para os ausentes e para os excluídos:
# ambos são ausência de dado confiável, e a linha não pode fingir que há dado.
quebrar_lacunas <- function(df, col_data = "data") {
  faltantes <- data.frame(x = comp_para_data(c(MESES_AUSENTES, MESES_RUINS)))
  names(faltantes) <- col_data
  dplyr::bind_rows(df, faltantes) |> dplyr::arrange(.data[[col_data]])
}

# --- interatividade --------------------------------------------------------

TOOLTIP_CSS <- sprintf(
  paste0("background:%s;color:%s;padding:7px 10px;border:1px solid %s;",
         "border-radius:5px;box-shadow:0 2px 10px #00000024;",
         "font-family:inherit;font-size:12.5px;line-height:1.45;"),
  COR$surface, COR$ink, COR$grid)

# Banda vertical invisível por período: alvo de hover largo e um tooltip só com
# todas as séries daquele mês. É a cruz vertical que a especificação pede.
banda_hover <- function(df, col_x = "data", col_tip = "tip", meia_largura = 16) {
  d <- df[!is.na(df[[col_x]]) & !is.na(df[[col_tip]]), ]
  d <- data.frame(x = d[[col_x]], tip = d[[col_tip]])
  geom_rect_interactive(
    data = d, inherit.aes = FALSE,
    aes(xmin = x - meia_largura, xmax = x + meia_largura,
        ymin = -Inf, ymax = Inf, tooltip = tip, data_id = as.character(x)),
    fill = "transparent")
}

# Eixo de datas com marcas de 2 em 2 anos, sempre ancorado em anos inteiros e
# sem passar do último ano com dado. Sem isso o ggplot escolhe marcas irregulares
# quando o usuário estreita o período pelo controle deslizante.
escala_x <- function(datas, dir = .13) {
  datas <- datas[!is.na(datas)]
  a1 <- as.integer(format(min(datas), "%Y"))
  a2 <- as.integer(format(max(datas), "%Y"))
  passo <- if (a2 - a1 <= 3) 1 else 2
  scale_x_date(
    breaks = seq(as.Date(paste0(a1, "-01-01")), as.Date(paste0(a2, "-01-01")),
                 by = paste(passo, "years")),
    date_labels = "%Y",
    expand = expansion(mult = c(.02, dir)))
}

# Último valor não-ausente da série, para o rótulo direto.
ultimo_valor <- function(df, col) {
  v <- df[[col]][!is.na(df[[col]])]
  v[length(v)]
}

girafe_painel <- function(p, altura = 3.8, tipo = c("serie", "barra")) {
  tipo <- match.arg(tipo)
  css <- if (tipo == "serie") "fill:#8987811c;stroke:none;"
         else                 "fill-opacity:.72;stroke:none;"
  girafe(
    ggobj = p, width_svg = 9, height_svg = altura,
    options = list(
      opts_hover(css = css),
      opts_tooltip(css = TOOLTIP_CSS, opacity = 1, use_fill = FALSE,
                   offx = 12, offy = 12),
      opts_toolbar(saveaspng = TRUE, position = "topright",
                   pngname = "painel-vacancia"),
      opts_selection(type = "none"),
      opts_sizing(rescale = TRUE, width = 1)))
}

# Rótulo direto na ponta da série. Exigência de contraste: a série magenta fica
# abaixo de 3:1 no fundo claro, então identidade nunca depende só da cor.
rotulo_fim <- function(df, x, y, texto, cor, dx = 40) {
  ultimo <- df[!is.na(df[[y]]), ]
  ultimo <- ultimo[which.max(ultimo[[x]]), ]
  list(
    geom_point(data = ultimo, aes(x = .data[[x]], y = .data[[y]]),
               colour = cor, size = 2, inherit.aes = FALSE),
    annotate("text", x = ultimo[[x]] + dx, y = ultimo[[y]],
             label = texto, colour = cor, hjust = 0, size = 3.4,
             fontface = "bold")
  )
}
