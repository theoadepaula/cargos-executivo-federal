# ---------------------------------------------------------------------------
# Injeta o JSON no template e escreve o painel final, autocontido.
#
# Roda depois de `02_json_painel.R`.
# Entrada:  painel/html/_template.html  +  painel/dados_painel.json
# Saída:    painel/vacancia-federal.html   (um arquivo só, sem dependência)
#
# ⚠️ Não edite o arquivo de saída — ele é gerado. Edite o template.
# ---------------------------------------------------------------------------

suppressPackageStartupMessages(library(theoviz))

RAIZ <- if (basename(getwd()) == "painel") getwd() else file.path(getwd(), "painel")
setwd(RAIZ)

tpl  <- readLines("html/_template.html", warn = FALSE, encoding = "UTF-8")
json <- readLines("dados_painel.json",   warn = FALSE, encoding = "UTF-8")

# --- cores: vêm do pacote, não do template ---------------------------------
# Regra do CLAUDE.md: estilo não se reimplementa dentro do projeto. Antes de
# existir o `theoviz`, a mesma paleta estava copiada em três projetos sob três
# nomes diferentes — e só se descobriu que eram idênticas ao compará-las.
cores <- c(as.list(paleta()), as.list(tinta()))
for (nome in names(cores)) {
  tpl <- gsub(paste0("{{", nome, "}}"), cores[[nome]], tpl, fixed = TRUE)
}

sobrou <- grep("\\{\\{[a-z0-9_]+\\}\\}", tpl, value = TRUE)
if (length(sobrou)) {
  stop("marcador de cor sem correspondente no theoviz:\n  ",
       paste(trimws(sobrou), collapse = "\n  "))
}

marcador <- "DADOS_AQUI"
linha <- grep(marcador, tpl, fixed = TRUE)
if (length(linha) != 1L) {
  stop("esperava exatamente uma ocorrência de ", marcador,
       " no template; encontrei ", length(linha))
}

tpl[linha] <- sub(marcador, paste(json, collapse = ""), tpl[linha], fixed = TRUE)

saida <- "vacancia-federal.html"
con <- file(saida, open = "wb")           # wb: não deixa o Windows trocar LF por CRLF
writeLines(tpl, con, useBytes = TRUE)
close(con)

kb <- file.size(saida) / 1024
cat(sprintf("%s: %.1f KB\n", saida, kb))

# o ganho sobre o Shinylive é o motivo de existir deste caminho; se ele sumir,
# alguma coisa deu errado
if (kb > 400) warning("painel maior que 400 KB — confira se o JSON não inchou")
