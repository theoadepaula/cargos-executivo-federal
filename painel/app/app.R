# ---------------------------------------------------------------------------
# Explorador da vacância no Executivo federal — Shiny (exportado em Shinylive)
#
# Roda inteiramente no navegador, via WebAssembly. Não há servidor de R por
# trás: o Cloudflare Pages serve só arquivos estáticos.
#
# ⚠️ `arrow` NÃO existe em webR. A leitura de parquet é com `nanoparquet`.
#    Ver CONTEXTO-PROJETO.md, seção "Sobre o painel".
#
# Especificação: painel/ESPECIFICACAO.md
# ---------------------------------------------------------------------------

library(shiny)
library(bslib)
library(dplyr)
library(tidyr)
library(ggplot2)
library(ggiraph)
library(reactable)
library(nanoparquet)   # explícito para o detector de dependências do shinylive

source("tema_painel.R")

# --- dados ------------------------------------------------------------------

ler <- function(nome) nanoparquet::read_parquet(file.path("dados", nome))

serie_mensal   <- ler("serie_mensal.parquet")
serie_entidade <- ler("serie_entidade.parquet")
serie_nivel    <- ler("serie_nivel.parquet")
serie_carreira <- ler("serie_carreira.parquet")
saidas         <- ler("saidas_acumuladas.parquet")
extincao       <- ler("cargos_em_extincao.parquet")
excluidos      <- ler("meses_excluidos.parquet")

# pontas da série, para os cartões e para a figura herói
ini <- serie_mensal |> filter(competencia == 201601)
fim <- serie_mensal |> filter(competencia == ULTIMO_MES)

NIVEIS <- c("NA" = "Apoio", "NI" = "Intermediário", "NS" = "Superior")

# --- peças de interface -----------------------------------------------------

cartao <- function(rotulo, valor, var, sentido_bom = "baixo") {
  # a seta indica direção; a cor NÃO julga, porque "menos cargos aprovados" não
  # é bom nem ruim — depende da pergunta de quem lê
  seta <- if (var >= 0) "▲" else "▼"
  div(
    class = "cartao",
    div(class = "cartao-rotulo", rotulo),
    div(class = "cartao-valor", pt(valor)),
    div(class = "cartao-var", paste0(seta, " ", pp(var, 1), "%"))
  )
}

nota <- function(...) div(class = "nota", ...)

aviso_acumulado <- div(
  class = "aviso",
  strong("Atenção: estes números são acumulados desde a origem da carreira."),
  " Não são fluxo mensal. Um cargo que vagou por aposentadoria em 1998 ainda",
  " conta aqui. A base não permite calcular quantos cargos vagaram em cada mês",
  " — o artigo 3 da série explica por quê."
)

css <- "
:root { --bs-primary: #2a78d6; --bs-link-color: #2a78d6;
        --bs-link-hover-color: #1f5aa3; }
body, .navbar { font-family: 'IBM Plex Sans', system-ui, -apple-system,
                'Segoe UI', Roboto, sans-serif; }
.nav-link.active { color: #2a78d6 !important; font-weight: 600; }
.navbar { border-bottom: 1px solid #e1e0d9; }
.cartao { padding: 14px 16px; border: 1px solid var(--bs-border-color);
          border-radius: 8px; height: 100%; }
.cartao-rotulo { font-size: 11.5px; letter-spacing: .06em; text-transform: uppercase;
                 color: #898781; margin-bottom: 4px; }
.cartao-valor { font-size: 26px; font-weight: 600; font-variant-numeric: tabular-nums;
                line-height: 1.15; }
.cartao-var { font-size: 12.5px; color: #52514e; font-variant-numeric: tabular-nums; }
.heroi { font-size: 60px; font-weight: 700; line-height: 1; letter-spacing: -.02em; }
.heroi-sub { font-size: 17px; color: #52514e; margin-top: 6px; }
.heroi-pe { font-size: 13px; color: #898781; margin-top: 2px; }
.nota { font-size: 12.5px; color: #898781; margin-top: 8px; line-height: 1.5; }
.aviso { background: #fff6e5; border-left: 3px solid #b8860b; padding: 11px 14px;
         border-radius: 5px; font-size: 13.5px; line-height: 1.55; margin-bottom: 16px; }
.girafe_container_std { margin: 0 auto; }
"

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

ui <- page_navbar(
  title = "Vacância no Executivo federal",
  # ⚠️ NÃO use bs_theme() aqui. Ele recompila Sass em tempo de execução, e em
  # WebAssembly isso trava o carregamento indefinidamente (testado em
  # 2026-07-19: o app parou por mais de 3 min; sem ele, sobe em ~1 min).
  # A cor de destaque e a fonte vão por CSS puro, que não custa nada.
  header = tags$head(tags$style(HTML(css))),
  fillable = FALSE,

  # --- 1. Panorama ---------------------------------------------------------
  nav_panel(
    "Panorama",
    layout_columns(
      col_widths = c(5, 7),
      div(
        div(class = "heroi", paste0(pt(fim$taxa_vacancia, 1), "%")),
        div(class = "heroi-sub", "dos cargos aprovados em lei estão vagos"),
        div(class = "heroi-pe",
            paste0("maio de 2026 · ",
                   pp(fim$taxa_vacancia - ini$taxa_vacancia),
                   " p.p. desde janeiro de 2016"))
      ),
      layout_columns(
        col_widths = c(6, 6, 6, 6),
        cartao("Aprovados em lei", fim$aprovada,
               100 * (fim$aprovada / ini$aprovada - 1)),
        cartao("Ocupados", fim$ocupada,
               100 * (fim$ocupada / ini$ocupada - 1)),
        cartao("Vagos", fim$vago,
               100 * (fim$vago / ini$vago - 1)),
        cartao("Nunca distribuídos", fim$nunca_distribuido,
               100 * (fim$nunca_distribuido / ini$nunca_distribuido - 1))
      )
    ),
    hr(),
    sliderInput("anos", "Período", min = 2016, max = 2026,
                value = c(2016, 2026), step = 1, sep = "",
                width = "100%", ticks = FALSE),
    card(full_screen = TRUE, girafeOutput("g_serie", height = "380px")),
    nota("Faixas cinza marcam meses com quebra de série; o tracejado vertical, ",
         "os dois meses que nunca foram publicados. A linha interrompe nos dois ",
         "casos — não interpola por cima do buraco."),
    card(full_screen = TRUE, girafeOutput("g_taxa", height = "300px"))
  ),

  # --- 2. Vacância fantasma ------------------------------------------------
  nav_panel(
    "Vacância fantasma",
    p(class = "lead",
      "Metade dos cargos ditos vagos nunca foi distribuída a órgão nenhum. ",
      "Existem em lei, mas não têm sala, chefia nem concurso previsto."),
    card(full_screen = TRUE, girafeOutput("g_decomp", height = "400px")),
    nota("Entre 2023 e 2025 a fração nunca distribuída salta de 35% para 52%. ",
         "Coincide com as reformas ministeriais — parte do movimento pode ser ",
         "reclassificação administrativa, não decisão de política de pessoal. ",
         "Separar as duas exige documentação normativa que o dado não traz."),
    hr(),
    h5("Onde se concentra"),
    card(full_screen = TRUE, girafeOutput("g_conc", height = "400px")),
    nota("Treze órgãos concentram 80% de todos os cargos nunca distribuídos.")
  ),

  # --- 3. Onde faltam ------------------------------------------------------
  nav_panel(
    "Onde faltam",
    layout_columns(
      col_widths = c(5, 7),
      card(full_screen = TRUE, girafeOutput("g_nivel", height = "300px")),
      card(full_screen = TRUE, girafeOutput("g_nivel_tempo", height = "300px"))
    ),
    nota(strong("Leia com cuidado: "),
         "o nível de apoio cai porque os cargos estão sendo extintos, não ",
         "porque foram providos. Sem essa ressalva o gráfico sugere melhora ",
         "onde há desaparecimento."),
    hr(),
    h5("Carreiras com maior vacância"),
    p(class = "text-muted", style = "font-size:13px;",
      "Planos de carreira com pelo menos 2.000 cargos aprovados, em maio de 2026. ",
      "Clique no cabeçalho para reordenar."),
    reactableOutput("t_carreira")
  ),

  # --- 4. Saídas e extinção ------------------------------------------------
  nav_panel(
    "Saídas e extinção",
    aviso_acumulado,
    card(full_screen = TRUE, girafeOutput("g_saidas", height = "330px")),
    nota("Barras ordenadas, não pizza nem barra empilhada: com um motivo ",
         "valendo 77%, as outras seis ficariam ilegíveis."),
    hr(),
    h5("Servidores em cargos já extintos por lei"),
    card(full_screen = TRUE, girafeOutput("g_extincao", height = "300px")),
    reactableOutput("t_extincao")
  ),

  # --- método --------------------------------------------------------------
  nav_panel(
    "Método",
    h5("O que este painel não faz"),
    p("Esta página é parte do argumento, não apêndice. Um painel que esconde ",
      "os defeitos da base mente por omissão."),
    h6("1. Os sete meses que ficaram de fora"),
    reactableOutput("t_excluidos"),
    nota("Cinco meses existem no acervo mas estão quebrados; dois nunca foram ",
         "publicados. Em nenhum caso a série interpola por cima."),
    hr(),
    h6("2. \"Cargo vago\" não quer dizer posto de trabalho ocioso"),
    p("Em toda a série, sem uma única exceção em 24.196 linhas, vale a ",
      "identidade ", tags$code("vago = aprovada − ocupada"), ". É definição ",
      "contábil, não medição. Um cargo criado em 2012 e nunca distribuído conta ",
      "igual a um cargo do qual alguém se aposentou no mês passado."),
    h6("3. Os acumulados não são fluxo"),
    p("As colunas ", tags$code("vacancia_por_*"), " acumulam desde a origem da ",
      "carreira, sem reinício. Não servem para calcular quantos cargos vagaram ",
      "em um mês. Além disso, 18,5% dos pares sofrem reprocessamento retroativo."),
    h6("4. O escopo mudou em 2021"),
    p("A entrada da ABIN na base, em agosto de 2021, alterou o escopo sem aviso ",
      "na documentação oficial."),
    h6("5. \"NA\" no nível é Nível Apoio"),
    p("Não é valor ausente. Lido como ausente, apaga 100.694 linhas em silêncio."),
    hr(),
    p(class = "text-muted", style = "font-size:13px;",
      "Fonte: Painel Estatístico de Pessoal (MGI), 125 planilhas mensais de ",
      "janeiro de 2016 a junho de 2026. Elaboração própria. Todo o processamento ",
      "é reproduzível a partir dos dados brutos versionados.")
  ),

  nav_spacer(),
  nav_item(tags$a("theoalbuquerque.com.br", href = "https://theoalbuquerque.com.br",
                  target = "_blank"))
)

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------

server <- function(input, output, session) {

  serie_f <- reactive({
    serie_mensal |>
      filter(ano >= input$anos[1], ano <= input$anos[2])
  })

  # --- página 1 ------------------------------------------------------------

  output$g_serie <- renderGirafe({
    d <- serie_f() |>
      mutate(tip = paste0(
        "<b>", format(data, "%b/%Y"), "</b><br>",
        "Aprovados em lei: ", pt(aprovada), "<br>",
        "Ocupados: ", pt(ocupada), "<br>",
        "Vagos: ", pt(vago), "<br>",
        "<span style='color:", COR$ink3, "'>Taxa: ",
        pt(taxa_vacancia, 2), "%</span>")) |>
      quebrar_lacunas()

    p <- ggplot(d, aes(x = data)) +
      camada_meses_ruins() +
      banda_hover(d) +
      geom_line(aes(y = aprovada), colour = COR$s1, linewidth = .8) +
      geom_line(aes(y = ocupada),  colour = COR$s2, linewidth = .8) +
      geom_line(aes(y = vago),     colour = COR$s3, linewidth = .8) +
      rotulo_fim(d, "data", "aprovada", "Aprovados\nem lei", COR$s1) +
      rotulo_fim(d, "data", "ocupada",  "Ocupados",          COR$s2) +
      rotulo_fim(d, "data", "vago",     "Vagos",             COR$s3) +
      scale_y_continuous(labels = mil, limits = c(0, 850000),
                         breaks = seq(0, 800000, 200000)) +
      escala_x(d$data, .17) +
      labs(title = "Cargos aprovados, ocupados e vagos",
           subtitle = "Passe o mouse para ver os três valores do mês",
           caption = "Fonte: Painel Estatístico de Pessoal (MGI).") +
      tema_painel()

    girafe_painel(p, altura = 3.9)
  })

  output$g_taxa <- renderGirafe({
    d <- serie_f() |>
      mutate(tip = paste0("<b>", format(data, "%b/%Y"), "</b><br>",
                          "Taxa de vacância: ", pt(taxa_vacancia, 2), "%")) |>
      quebrar_lacunas()

    p <- ggplot(d, aes(data, taxa_vacancia)) +
      camada_meses_ruins() +
      banda_hover(d) +
      geom_line(colour = COR$s3, linewidth = .85) +
      rotulo_fim(d, "data", "taxa_vacancia",
                 paste0(pt(ultimo_valor(d, "taxa_vacancia"), 1), "%"), COR$s3) +
      scale_y_continuous(labels = function(x) paste0(pt(x), "%"),
                         limits = c(0, 45), breaks = seq(0, 40, 10)) +
      escala_x(d$data, .10) +
      labs(title = "Taxa de vacância",
           subtitle = "Escala começando em zero, para não exagerar a variação",
           caption = "Fonte: Painel Estatístico de Pessoal (MGI).") +
      tema_painel()

    girafe_painel(p, altura = 3.1)
  })

  # --- página 2 ------------------------------------------------------------

  output$g_decomp <- renderGirafe({
    base <- serie_mensal |>
      mutate(tip = paste0(
        "<b>", format(data, "%b/%Y"), "</b><br>",
        "Nunca distribuído: ", pt(nunca_distribuido),
        " (", pt(pct_fantasma, 1), "%)<br>",
        "Vago após distribuição: ", pt(vago_pos_distrib), "<br>",
        "<span style='color:", COR$ink3, "'>Total vago: ", pt(vago), "</span>"))

    longo <- base |>
      select(data, nunca_distribuido, vago_pos_distrib) |>
      pivot_longer(-data, names_to = "tipo", values_to = "n") |>
      mutate(tipo = factor(tipo,
                           levels = c("vago_pos_distrib", "nunca_distribuido"),
                           labels = c("Vago após distribuição",
                                      "Nunca distribuído")))

    p <- ggplot(longo, aes(data, n, fill = tipo)) +
      camada_meses_ruins() +
      geom_area(colour = COR$surface, linewidth = .4) +
      banda_hover(base) +
      annotate("text", x = as.Date("2017-06-01"), y = 42000,
               label = "Nunca distribuído", colour = "white", size = 3.5,
               fontface = "bold", hjust = 0) +
      annotate("text", x = as.Date("2017-06-01"), y = 178000,
               label = "Vago após distribuição", colour = COR$ink, size = 3.5,
               fontface = "bold", hjust = 0) +
      scale_fill_manual(values = c("Nunca distribuído" = COR$s1,
                                   "Vago após distribuição" = COR$s3)) +
      scale_y_continuous(labels = mil, expand = expansion(mult = c(0, .05))) +
      escala_x(base$data, .02) +
      labs(title = "Do que o cargo vago é feito",
           subtitle = "Decomposição mensal do total de cargos vagos",
           caption = "Fonte: Painel Estatístico de Pessoal (MGI).") +
      tema_painel()

    girafe_painel(p, altura = 4.1)
  })

  output$g_conc <- renderGirafe({
    d <- serie_entidade |>
      filter(competencia == ULTIMO_MES) |>
      arrange(desc(nunca_distribuido)) |>
      head(12) |>
      mutate(
        pct  = 100 * nunca_distribuido / aprovada,
        nome = substr(entidade_nome, 1, 42),
        nome = reorder(nome, nunca_distribuido),
        tip  = paste0("<b>", entidade_nome, "</b><br>",
                      "Nunca distribuídos: ", pt(nunca_distribuido), "<br>",
                      "Aprovados na pasta: ", pt(aprovada), "<br>",
                      "<span style='color:", COR$ink3, "'>",
                      pt(pct, 1), "% da pasta nunca foi distribuída</span>"))

    p <- ggplot(d, aes(nunca_distribuido, nome)) +
      geom_col_interactive(aes(tooltip = tip, data_id = nome),
                           fill = COR$s1, width = .68) +
      geom_text(aes(label = paste0(pt(nunca_distribuido), "   ",
                                   pt(pct, 1), "% da pasta")),
                hjust = -0.05, size = 3.1, colour = COR$ink2) +
      scale_x_continuous(expand = expansion(mult = c(0, .36))) +
      labs(title = "Onde a vacância fantasma se concentra",
           subtitle = "Cargos nunca distribuídos, maio de 2026",
           caption = "Fonte: Painel Estatístico de Pessoal (MGI).") +
      tema_painel() +
      theme(panel.grid.major.y = element_blank(),
            axis.text.x = element_blank())

    girafe_painel(p, altura = 4.1, tipo = "barra")
  })

  # --- página 3 ------------------------------------------------------------

  output$g_nivel <- renderGirafe({
    d <- serie_nivel |>
      filter(competencia == ULTIMO_MES, nivel %in% names(NIVEIS)) |>
      mutate(taxa = 100 * vago / aprovada,
             nome = unname(NIVEIS[nivel]),
             nome = reorder(nome, taxa),
             tip  = paste0("<b>Nível ", nome, "</b><br>",
                           "Aprovados: ", pt(aprovada), "<br>",
                           "Vagos: ", pt(vago), "<br>",
                           "<span style='color:", COR$ink3, "'>Taxa: ",
                           pt(taxa, 1), "%</span>"))

    p <- ggplot(d, aes(taxa, nome)) +
      geom_col_interactive(aes(tooltip = tip, data_id = nome),
                           fill = COR$s1, width = .62) +
      geom_text(aes(label = paste0(pt(taxa, 1), "%")), hjust = -0.12,
                size = 3.3, colour = COR$ink2) +
      scale_x_continuous(expand = expansion(mult = c(0, .22))) +
      labs(title = "Taxa de vacância por nível",
           subtitle = "Maio de 2026",
           caption = "Fonte: Painel Estatístico de Pessoal (MGI).") +
      tema_painel() +
      theme(panel.grid.major.y = element_blank(),
            axis.text.x = element_blank())

    girafe_painel(p, altura = 3.1, tipo = "barra")
  })

  output$g_nivel_tempo <- renderGirafe({
    d <- serie_nivel |>
      filter(nivel %in% names(NIVEIS), competencia %% 100 == 1) |>
      mutate(taxa = 100 * vago / aprovada, nome = unname(NIVEIS[nivel]))

    bandas <- d |>
      group_by(ano) |>
      summarise(tip = paste0("<b>Janeiro de ", first(ano), "</b><br>",
                             paste(sprintf("%s: %s%%", nome, pt(taxa, 1)),
                                   collapse = "<br>")), .groups = "drop")

    fins <- d |> group_by(nome) |> filter(ano == max(ano)) |> ungroup()

    p <- ggplot(d, aes(ano, taxa, colour = nome)) +
      banda_hover(bandas, col_x = "ano", meia_largura = 0.5) +
      geom_line(linewidth = .85) +
      geom_point(data = fins, size = 2) +
      geom_text(data = fins, aes(label = paste0(nome, " ", pt(taxa, 1), "%")),
                hjust = -0.08, size = 3.1, fontface = "bold") +
      scale_colour_manual(values = c("Intermediário" = COR$s3,
                                     "Superior" = COR$s1, "Apoio" = COR$s2)) +
      scale_y_continuous(labels = function(x) paste0(pt(x), "%"),
                         limits = c(0, 45), breaks = seq(0, 40, 10)) +
      scale_x_continuous(breaks = seq(2016, 2026, 2),
                         expand = expansion(mult = c(.02, .34))) +
      labs(title = "Taxa de vacância por nível ao longo do tempo",
           subtitle = "Janeiro de cada ano",
           caption = "Fonte: Painel Estatístico de Pessoal (MGI).") +
      tema_painel()

    girafe_painel(p, altura = 3.1)
  })

  output$t_carreira <- renderReactable({
    d <- serie_carreira |>
      filter(competencia == ULTIMO_MES, aprovada >= 2000) |>
      arrange(desc(taxa_vacancia)) |>
      transmute(Carreira = plano_carreira, Aprovados = aprovada,
                Ocupados = ocupada, Vagos = vago,
                `Taxa` = round(taxa_vacancia, 1))

    reactable(
      d, defaultPageSize = 12, searchable = TRUE, highlight = TRUE,
      compact = TRUE, striped = FALSE, borderless = TRUE,
      defaultSorted = list(Taxa = "desc"),
      defaultColDef = colDef(
        headerStyle = list(fontWeight = 600, fontSize = "12.5px"),
        style = list(fontVariantNumeric = "tabular-nums")),
      columns = list(
        Carreira  = colDef(minWidth = 260),
        Aprovados = colDef(format = colFormat(separators = TRUE, locales = "pt-BR")),
        Ocupados  = colDef(format = colFormat(separators = TRUE, locales = "pt-BR")),
        Vagos     = colDef(format = colFormat(separators = TRUE, locales = "pt-BR")),
        Taxa      = colDef(name = "Taxa de vacância",
                           format = colFormat(suffix = "%", locales = "pt-BR"))))
  })

  # --- página 4 ------------------------------------------------------------

  output$g_saidas <- renderGirafe({
    d <- saidas |>
      filter(competencia == ULTIMO_MES) |>
      mutate(pct    = 100 * acumulado / sum(acumulado),
             motivo = reorder(motivo, acumulado),
             tip    = paste0("<b>", motivo, "</b><br>",
                             pt(acumulado), " cargos vagaram<br>",
                             "<span style='color:", COR$ink3, "'>",
                             pt(pct, 1), "% do total acumulado</span>"))

    p <- ggplot(d, aes(acumulado, motivo)) +
      geom_col_interactive(aes(tooltip = tip, data_id = motivo),
                           fill = COR$s1, width = .68) +
      geom_text(aes(label = paste0(pt(acumulado), "   ", pt(pct, 1), "%")),
                hjust = -0.05, size = 3.1, colour = COR$ink2) +
      scale_x_continuous(expand = expansion(mult = c(0, .28))) +
      labs(title = "Por que os cargos vagaram",
           subtitle = "Acumulado desde a origem da carreira até maio de 2026",
           caption = "Fonte: Painel Estatístico de Pessoal (MGI).") +
      tema_painel() +
      theme(panel.grid.major.y = element_blank(),
            axis.text.x = element_blank())

    girafe_painel(p, altura = 3.4, tipo = "barra")
  })

  output$g_extincao <- renderGirafe({
    d <- extincao |>
      filter(competencia %% 100 == 1) |>
      group_by(ano) |>
      summarise(ocupada = sum(ocupada, na.rm = TRUE),
                tipos   = n_distinct(nome_cargo), .groups = "drop") |>
      mutate(tip = paste0("<b>Janeiro de ", ano, "</b><br>",
                          pt(ocupada), " servidores<br>",
                          pt(tipos), " tipos de cargo"))

    p <- ggplot(d, aes(ano, ocupada)) +
      geom_area(fill = COR$s1, alpha = .13) +
      banda_hover(d, col_x = "ano", meia_largura = 0.5) +
      geom_line(colour = COR$s1, linewidth = .85) +
      geom_point(colour = COR$s1, size = 2.1) +
      geom_text(aes(label = pt(ocupada)), vjust = -1.4, size = 3,
                colour = COR$ink2) +
      scale_y_continuous(labels = mil, limits = c(0, 66000),
                         breaks = seq(0, 60000, 20000)) +
      scale_x_continuous(breaks = d$ano) +
      labs(title = "A massa em extinção está encolhendo",
           subtitle = "Servidores em cargos extintos por lei, janeiro de cada ano",
           caption = "Fonte: Painel Estatístico de Pessoal (MGI).") +
      tema_painel()

    girafe_painel(p, altura = 3.1)
  })

  output$t_extincao <- renderReactable({
    d <- extincao |>
      filter(competencia == ULTIMO_MES) |>
      group_by(nome_cargo) |>
      summarise(Servidores = sum(ocupada, na.rm = TRUE),
                `Órgãos`   = sum(orgaos, na.rm = TRUE), .groups = "drop") |>
      arrange(desc(Servidores)) |>
      rename(Cargo = nome_cargo)

    reactable(
      d, defaultPageSize = 10, searchable = TRUE, highlight = TRUE,
      compact = TRUE, borderless = TRUE,
      defaultColDef = colDef(
        headerStyle = list(fontWeight = 600, fontSize = "12.5px"),
        style = list(fontVariantNumeric = "tabular-nums")),
      columns = list(
        Cargo      = colDef(minWidth = 260),
        Servidores = colDef(format = colFormat(separators = TRUE, locales = "pt-BR"))))
  })

  # --- método --------------------------------------------------------------

  output$t_excluidos <- renderReactable({
    d <- excluidos |>
      arrange(competencia) |>
      transmute(`Competência` = as.character(competencia),
                Tipo = tipo, Motivo = motivo)

    reactable(d, pagination = FALSE, compact = TRUE, borderless = TRUE,
              defaultColDef = colDef(
                headerStyle = list(fontWeight = 600, fontSize = "12.5px")),
              columns = list(Motivo = colDef(minWidth = 300)))
  })
}

shinyApp(ui, server)
