# Contexto do projeto — Cargos vagos no Executivo federal

> Documento de contexto, decisões e estado do trabalho.
> Mesmo papel que o `CONTEXTO-SITE.md` cumpre para o site.
> Última atualização: 2026-07-19

---

## 1. O que é e para que serve

Primeira peça de portfólio público do site theoalbuquerque.com.br, e fonte de uma
série de artigos para o blog.

Compilação de 125 planilhas mensais do Painel Estatístico de Pessoal (jan/2016 a
jun/2026) em duas tabelas analisáveis, mais o material editorial que sai delas.

**Por que este dado.** É federal (não conflita com o vínculo no GDF), é aberto,
ninguém o analisa em série longa, e permite demonstrar as duas coisas que o
posicionamento pede: rigor estatístico e leitura de gestão pública.

**Relação com o portfólio.** O painel papa-entulhos (SLU-DF) continua sendo o
case âncora — trabalho real, dado interno, impacto de gestão. Este é o **case
público**: mesmo rigor, dado aberto, integralmente reproduzível. Os dois cobrem
provas diferentes: sei fazer dentro da máquina, e sei fazer à vista de todos.

---

## 2. Decisões tomadas

### Sobre a compilação (decididas por Théo)

- ✅ **Compilar as duas abas**, em dois parquets. O agregado por órgão é leve e
  serve a gráficos rápidos; o detalhado por cargo sustenta os artigos.
- ✅ **Empilhar as duas eras numa série só**, com `NA` nas colunas que só existem
  a partir de 2021-08 e uma coluna `era` marcando a origem. Nada de informação é
  descartado; o corte da janela fica sendo decisão da análise.
- ✅ **Projeto Quarto completo**, no padrão do `dados_sustentabilidade_ufu`.

### Sobre o conteúdo (propostas minhas, sujeitas à revisão de Théo)

- ⚠️ **Não publicar ranking nominal de ministérios.** Tecnicamente viável (o
  de-para resolve), mas um ranking de "piores pastas" assinado por servidor em
  exercício pede cautela sob a Lei 840. O artigo 5 explica a escolha ao leitor
  em vez de omitir. Reversível.
- ⚠️ **Assumir os erros em público.** O artigo 1 traz um box explicando que a
  primeira versão dava 35,1% por usar mês corrompido; o artigo 6 é inteiro sobre
  os tropeços, inclusive os meus. Aposta de posicionamento: admitir constrói mais
  autoridade que esconder. Reversível sem afetar o resto.
- ⚠️ **Reordenação dos artigos.** Na pauta original o artigo 2 era "onde faltam".
  Quando a coluna `distribuida` entregou o achado da vacância fantasma, ele virou
  o texto forte da série e o ranking desceu para o 5.

### Sobre o painel

- ✅ **Shinylive (R → WASM)** para *este* painel. Reaproveita o código de análise
  já escrito em R e embute no site pelo mesmo fluxo do stlite. Théo confirmou em
  2026-07-19 que **prefere WASM nos painéis** — o que fecha a questão: nada de
  painel que dependa de servidor.
- ✅ **Ambiente Shinylive pronto** (2026-07-19): pacote `shinylive` 0.5.0 e os
  ativos webR 0.10.12 (~700 MB) já em cache local. Não precisa baixar de novo.
- 🚨 **`arrow` NÃO existe em webR.** Verificado no `repo.r-wasm.org`. O app do
  painel **não pode** usar `arrow::read_parquet()`. Substituto:
  **`nanoparquet`**, que existe em WASM e leu as sete tabelas de `painel/dados/`
  com resultado idêntico ao arrow, coluna a coluna. Use `nanoparquet` no app.
  Nos artigos e nos scripts de `code/`, que rodam localmente, o `arrow` continua.
  Também disponíveis em WASM: dplyr, ggplot2, ggiraph, tidyr, forcats, scales,
  patchwork, stringr, shiny, bslib, readr, data.table, duckdb.
- 📌 **A ferramenta de painel não é regra do projeto** — refinado por Théo em
  2026-07-19. Painel pode ser R ou Python, sem hierarquia: Shiny, Shinylive,
  Streamlit, stlite, Shiny for Python, o que servir melhor a cada caso. O que
  decide é a publicação: o Cloudflare serve estático e não executa R nem Python,
  então painel publicado roda no navegador (WASM) ou é pré-renderizado.
  (A regra fixa de R/Quarto vale para **análise e artigos**, não para painéis.)
- ❌ **Power BI está fora de qualquer painel do site** — é pago e exige licença
  para gerar link público, o que quebra a premissa de portfólio acessível. Minha
  recomendação inicial de Power BI estava errada e saiu do `CONTEXTO-SITE.md`
  desatualizado (ver seção 8).
- ✅ **Um painel só, não três.** A 3h/semana, um segundo custa um trimestre e
  divide a atenção de quem visita.
- ✅ **Meses defeituosos aparecem marcados, nunca apagados.** Regra que atravessa
  as quatro páginas. É o que separa a peça de um dashboard bonito com número
  errado.

---

## 3. Os achados, em uma linha cada

| Achado | Número |
|---|---|
| A máquina encolheu, a vacância não | Tudo −11%; taxa 32,69% → 33,13% |
| **Vacância fantasma** | Nunca distribuídos: 35,4% → 52,0% do vago |
| Composição das saídas | Aposentadoria 76,6%; 52 aposentadorias por demissão |
| Fuga interna > externa | Posse em cargo inacumulável 8,3% > exoneração 7,4% |
| Cargos extintos ocupados | 37.725 servidores, −4.400/ano, zera ~2035 |
| Vacância por nível | Intermediário 37,9% > superior 31,3% |
| Hipótese que morreu | Cargos em extinção são 99,1% ocupados — não inflam vacância |

---

## 4. Armadilhas do dado (resumo — detalhe no dicionário)

1. **`vago = aprovada − ocupada`**, sempre. Não mede posto ocioso; mede distância
   entre lei e provimento.
2. **`vacancia_por_*` é acumulada desde a origem da carreira, sem reset.** Não
   serve para fluxo mensal — 18,5% dos pares sofrem reprocessamento retroativo.
3. **`NA` em `nivel` é Nível Apoio, não valor ausente.** Leitores de planilha
   apagam 100.694 linhas silenciosamente.
4. **Sete meses fora:** 2019-02 e 2025-07 não existem; 2018-03 (dupla contagem),
   2025-04 a 2025-06 (bolha), 2026-06 (corrompido).
5. **Códigos de órgão trocam e deixam casca residual.** Use `entidade` do de-para.
6. **O escopo mudou em 2021** (entrada da ABIN) sem aviso na documentação oficial.
7. **As duas abas divergem em 141 pares**, em 4 órgãos, a partir de 2023-06.

---

## 5. Estado do trabalho

### Pronto

- [x] Compilação, validação e de-para — três scripts reproduzíveis
- [x] Dicionário de dados com as armadilhas
- [x] Seis artigos em rascunho, com **10 gráficos implementados** em ggplot2
- [x] Tema visual compartilhado (`artigos/_tema.R`) com a paleta validada
- [x] **HTML renderizado** em `_site/` para revisão
- [x] Especificação do painel + tabelas agregadas + mockup visual
- [x] Pauta editorial com hipóteses testadas

### Aguardando

- [ ] **Revisão do Théo** — os seis artigos e o painel. Nada migra antes disso.
- [ ] **Abrir o export WASM num Chrome normal** — ver `painel/COMO-RODAR.md`.
      O app roda perfeito como Shiny local; o export não montou no navegador
      automatizado, mas nem um app trivial montou ali, então a suspeita recai
      sobre o ambiente de teste, não sobre o painel.
- [ ] Imagens de capa para cada artigo

### Painel — PORTADO em 2026-07-19 ✅

- [x] **`painel/vacancia-federal.html` — 65,7 KB**, autocontido, cinco páginas.
      Abre direto no navegador, sem servidor. Contra 115 MB do Shinylive.
- [x] Pipeline de três scripts, documentado em `painel/COMO-RODAR.md`:
      `01_preparar_dados_painel.R` → `02_json_painel.R` (JSON de 27 KB, com
      **sete conferências** que matam o script se um número furar) →
      `03_montar_painel.R` (injeta o JSON no template).
- [x] **Tema escuro funciona** — herda por variáveis CSS. Era o motivo principal
      de sair do Shinylive, e está resolvido.
- [x] Verificado no navegador: as cinco páginas, crosshair com tooltip unificado,
      tabelas ordenáveis, faixas dos meses ruins, tema claro e escuro.
- 📐 Três defeitos achados e corrigidos na inspeção visual: eixo com marcas em
      9/18/27 (agora `passoBonito()`), faixa de mês excluído vazando para fora do
      gráfico (agora `corta()`), e — o mais sério — **a área empilhada atravessava
      os buracos** enquanto a linha os respeitava. Agora as duas interrompem.
- O que se edita é `painel/html/_template.html`. O `vacancia-federal.html` é
  gerado; não edite à mão.

### Painel — a decisão de portar

- 🔄 **O painel sai do Shinylive e vai para HTML + SVG à mão**, no mesmo idioma
  do painel do `Relatorios_slu`. Decisão do Théo, depois de ver os dois.
  **115 MB → ~60 KB.** O JSON dos cargos, agregado como o SLU agrega, mede
  **22,7 KB** (medido, não estimado).
- O que pesou mais não foi o tamanho: foi o **tema escuro**. O site é escuro e um
  app bslib embutido é um retângulo branco no meio da página. Sem conserto barato.
- 📓 **Todo o aprendizado do Shinylive está em `painel/APRENDIZADO-SHINYLIVE.md`**
  — armadilhas, tempos, como depurar, e quando o Shinylive voltaria a ser a
  escolha certa (filtro livre recalculando sobre a base inteira). Leia antes de
  cogitar WASM de novo.
- O `painel/app/` **não é apagado**: continua rodando como Shiny local e serve de
  especificação executável, com os números já conferidos contra os artigos.

### Painel — versão Shinylive, construída em 2026-07-19 (aposentada)

- [x] `painel/app/app.R` — cinco páginas (Panorama, Vacância fantasma, Onde
      faltam, Saídas e extinção, Método), conforme a especificação.
- [x] `painel/app/tema_painel.R` — espelha `artigos/_tema.R`, mesma paleta
      validada, mesmo padrão de interação (`banda_hover`, `girafe_painel`).
- [x] Verificado rodando como Shiny local: **cinco páginas, zero erro**, números
      batendo com os artigos (37,9% / 31,3% / 5,4% por nível; aposentadoria
      214.061 = 76,6%).
- [x] `painel/_headers` — Cloudflare Pages precisa de COOP/COEP para o
      SharedArrayBuffer do webR. Sem isso o painel cai em modo degradado.
- ⚠️ **Não use `bs_theme()`** no app: recompila Sass em tempo de execução, caro
      em WASM. Cor e fonte por CSS puro.
- 📦 Export em `painel/dist/`: 115 MB, 228 arquivos, nenhum acima do limite de
      25 MB por arquivo do Cloudflare. **Pesa muito para versionar em git** —
      decidir com Théo se entra no repo ou se o build fica fora dele.

### Decidido em 2026-07-19 — gráficos interativos

- ✅ **Os gráficos dos artigos são interativos, via `ggiraph`.** Pedido do Théo.
- ❌ **`ggplotly()` foi testado e reprovado.** Aplicado ao gráfico da série,
  destruiu o desenho: apagou as três linhas (sobraram só os pontos finais), as
  faixas de meses ruins, as linhas de lacuna, o subtítulo e a fonte. O `ggiraph`
  renderiza o próprio ggplot em SVG e só acrescenta os eventos — saiu pixel a
  pixel igual ao estático. **Não troque sem repetir o teste.**
- ⚠️ **Precisão registrada em 2026-07-19:** o reprovado é o **conversor
  `ggplotly()`**, não a biblioteca plotly inteira. O projeto `Relatorios_slu`
  usa `plot_ly()` **nativo** — traces montados do zero, sem passar por ggplot —
  e funciona bem, com `hovermode = "x unified"`. São coisas diferentes. Ver o
  quadro completo em `docs/CONTEXTO-SITE.md`, seção 9.2.
  **Para este projeto (Cargos), nada muda: continua `ggiraph`.**
- 📐 **Padrão de interação:** banda vertical invisível por período
  (`banda_hover()`), que dá alvo de hover grande e um tooltip único com todas as
  séries daquele mês — equivalente ao crosshair. Barras usam
  `geom_col_interactive` com tooltip por marca. Envelope padrão em
  `girafe_cargos()`.
- 🔗 No artigo 5, os dois painéis compartilham `data_id`: passar o mouse num
  nível o acende nos dois lados, o que é justamente a tese do gráfico.
- A paleta não mudou, então a validação de daltonismo segue valendo. O hover
  altera opacidade, nunca matiz.

### Decidido em 2026-07-19

- ❌ **Fluxo mensal de vacância: NÃO perseguir.** Decisão do Théo. O objetivo da
  peça é demonstrar capacidade analítica, não esgotar o dataset. O artigo 3 já
  documenta por que o dado não sustenta fluxo mensal — e reconhecer o limite é
  parte da demonstração, não uma lacuna dela.
- 🔒 **Nada é transferido para o repo do Astro antes da aprovação.** O projeto
  fica inteiro nesta pasta OneDrive até que Théo aprove **todos** os artigos e o
  painel. Só então os `.qmd` vão para `quarto/posts/` e o app para
  `public/apps/`. Não antecipe a migração.

### Pendências abertas
- [ ] Tentar baixar 2019-02 e 2025-07, que podem existir em outra fonte.
- [ ] Validar algum total contra número oficial publicado (validação externa).
- [ ] Revisar o de-para à mão (`dados/depara_orgaos.csv` é editável) — o
      conhecimento de Théo sobre as reformas vale mais que minha inferência
      numérica, sobretudo nos casos de confiança "média".

---

## 6. Ordem de publicação sugerida

| # | Peça | Por quê nesta posição |
|---|---|---|
| 1 | Artigo 1 (panorama) | Estabelece o terreno e a série |
| 2 | Artigo 2 (nunca distribuídos) | O achado forte, com terreno posto |
| 3 | **Painel** | Sai junto com o artigo 2, que é o gancho de divulgação |
| 4 | Artigo 6 (diário de bordo) | Consolida autoridade metodológica |
| 5 | Artigo 3 (por que vagam) | |
| 6 | Artigo 4 (cargos em extinção) | Fecha com o artigo 3 |
| 7 | Artigo 5 (onde faltam) | O mais dispensável se o tempo apertar |

A 3h/semana, isso é um plano de seis a oito meses. Um artigo por mês com número
conferido constrói mais reputação que seis em março e silêncio no resto do ano.

---

## 7. Onde está cada coisa

| Arquivo | Papel |
|---|---|
| `CONTEXTO-PROJETO.md` | **Este arquivo** — decisões, estado, pendências |
| `README.md` | Como reproduzir; o que a validação achou |
| `dicionario_de_dados.qmd` | Semântica das colunas e armadilhas, em detalhe |
| `PAUTA.md` | Plano editorial e hipóteses testadas contra o dado |
| `artigos/*.qmd` | Os seis rascunhos |
| `painel/ESPECIFICACAO.md` | Layout, paleta, checklist de publicação |
| `painel/mockup.html` | Rascunho visual das quatro páginas |
| `code/*.R` | Compilação, validação, de-para |

Fora deste projeto, na mesma pasta OneDrive:
`../../imagens/INDICE.md` (catálogo do banco de imagens),
`../../backups/LEIA-ME.md` (backups do WordPress aposentado).

---

## 8. ⚠️ Onde o site realmente vive

**Esta pasta do OneDrive não é o site.** O site é um projeto Astro em:

```
C:\Users\theoa\dev\theoalbuquerque-site     (fora do OneDrive, de propósito)
repo privado: github.com/theoadepaula/theoalbuquerque-site
no ar: https://theoalbuquerque.com.br  (Cloudflare Pages, deploy no push)
```

**O `CONTEXTO-SITE.md` desta pasta OneDrive está DESATUALIZADO** (25/06/2026).
Descreve o site em WordPress + Elementor, que foi aposentado. O documento
canônico é `docs/CONTEXTO-SITE.md` no repo, e o estado vivo é `docs/STATUS.md`.
Não tome decisão com base no arquivo do OneDrive.

### Como este projeto entra no site

| Peça | Destino no repo |
|---|---|
| Artigos (`.qmd`) | `quarto/posts/<slug>/index.qmd` → `npm run build:quarto` |
| Painel | `public/apps/<nome>/` + `src/content/paineis/<slug>.md` |
| Imagens de capa | `public/images/blog/` |

O blog do site já roda Quarto com R e Python (render local com `freeze`, saída
versionada — o Cloudflare não executa R). Os artigos deste projeto estão em
`.qmd` justamente porque encaixam nesse pipeline sem conversão.

Segundo o `docs/STATUS.md` de 2026-07-10, a **única frente aberta do site** é
"Portfólio — casos reais: papa-entulhos e/ou um exemplo de dados abertos".
Este projeto é exatamente esse item.
