# Painel: Explorador da vacância federal

Quatro páginas, uma pergunta por página.

> ## Ferramenta: Shinylive (R → WASM) — decidido
>
> Definido em 2026-07-19: **toda análise e painel deste projeto é em R, via
> Quarto**. Painel em **Shinylive**, que compila R para WebAssembly e embute no
> site pelo mesmo fluxo do stlite.
>
> A primeira versão desta especificação assumia Power BI. Estava errado — a
> recomendação saiu do `CONTEXTO-SITE.md` do OneDrive, que está desatualizado e
> descreve o WordPress aposentado. Power BI não embute sem publish-to-web, e
> obrigaria a reescrever a análise em DAX. Fica para os casos internos do SLU-DF.
>
> Publicação:
> ```
> exportar app para  <repo>\public\apps\vacancia-federal\
> criar             <repo>\src\content\paineis\vacancia-federal.md
>                   com  app: /apps/vacancia-federal/
> ```
> onde `<repo>` é `C:\Users\theoa\dev\theoalbuquerque-site`.
>
> Layout, formas, paleta e regras abaixo independem da ferramenta. As tabelas de
> `painel/dados/` já estão prontas — em Parquet, que o Shinylive lê com `arrow`.

**Princípio que governa o painel inteiro:** os meses defeituosos aparecem
marcados, nunca apagados. Um painel que esconde a lacuna mente por omissão; um
que a mostra e explica é a própria demonstração de método.

---

## Dados de entrada

Rode `painel/01_preparar_dados_painel.R`. Ele gera sete tabelas em
`painel/dados/`, em CSV e Parquet, já sem os meses quebrados:

| Tabela | Linhas | Serve a |
|---|---|---|
| `serie_mensal` | 119 | Páginas 1 e 2 — a espinha dorsal |
| `serie_entidade` | 23.155 | Filtros e detalhamento por órgão |
| `serie_nivel` | 476 | Página 3 |
| `serie_carreira` | 8.485 | Página 3 |
| `saidas_acumuladas` | 378 | Página 4 |
| `cargos_em_extincao` | 36.937 | Página 4 |
| `meses_excluidos` | 7 | Camada de marcação em todas as páginas |

Não conecte o painel ao parquet de 1,6 milhão de linhas. As agregadas dão conta
e mantêm o arquivo leve.

**Modelo:** `serie_mensal` como tabela-fato principal; `meses_excluidos` como
tabela auxiliar relacionada por `competencia`, usada só para desenhar as faixas
de exclusão. `serie_entidade` conecta-se ao de-para por `entidade`.

---

## Sistema visual

### Cores

Paleta validada para daltonismo (verificada com o validador do método — todos os
testes passam em claro e escuro).

| Papel | Claro | Escuro |
|---|---|---|
| Série 1 (aprovados) | `#2a78d6` | `#3987e5` |
| Série 2 (ocupados) | `#008300` | `#008300` |
| Série 3 (vagos) | `#e87ba4` | `#d55181` |
| Superfície | `#fcfcfb` | `#1a1a19` |
| Texto primário | `#0b0b0b` | `#ffffff` |
| Texto secundário | `#52514e` | `#c3c2b7` |
| Eixos e rótulos | `#898781` | `#898781` |
| Grade (fio) | `#e1e0d9` | `#2c2c2a` |

Para magnitude (rankings, mapas de calor) use **um hue só**, azul claro→escuro —
nunca arco-íris.

::: atenção
O magenta da série 3 fica abaixo de 3:1 de contraste no fundo claro. A regra do
método exige compensação: **rótulos diretos visíveis** nessa série. Já está
previsto nos gráficos abaixo.
:::

### Regras de marca

- Linhas de 2px; marcadores de no mínimo 8px.
- Barras com ponta arredondada de 4px, ancoradas na linha de base.
- Vão de 2px entre segmentos empilhados e entre barras adjacentes.
- Grade e eixos discretos, nunca competindo com o dado.
- Rótulo direto seletivo — o último ponto de cada série, não todos os pontos.
- Números grandes na fonte do sistema; `tabular-nums` só em colunas de tabela.

### Regras que não se negociam

- **Um eixo por gráfico.** Nunca dois eixos Y. Se duas medidas têm escalas
  diferentes, são dois gráficos.
- **A cor segue a entidade, não a posição no ranking.** Filtrar não pode
  repintar as séries que sobraram.
- **Legenda sempre presente com duas ou mais séries**, e rótulo direto até
  quatro. Identidade nunca depende só de cor.

---

## Página 1 — Panorama

**Pergunta:** o que aconteceu com a vacância em dez anos?

```
┌──────────────────────────────────────────────────────────────────┐
│  VACÂNCIA NO EXECUTIVO FEDERAL          [ano ▾] [órgão ▾] [nível ▾]│
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│     33,1%              ← figura herói, ≥48px                     │
│     dos cargos aprovados em lei estão vagos                      │
│     maio de 2026 · +0,44 p.p. desde janeiro de 2016              │
│                                                                  │
├────────────┬────────────┬────────────┬───────────────────────────┤
│ APROVADOS  │ OCUPADOS   │ VAGOS      │ NUNCA DISTRIBUÍDOS        │
│ 699.858    │ 467.971    │ 231.887    │ 114.737                   │
│ −11,3% ▼   │ −11,8% ▼   │ −10,0% ▼   │ +25,8% ▲                  │
├────────────┴────────────┴────────────┴───────────────────────────┤
│                                                                  │
│  Aprovados, ocupados e vagos · 2016–2026                         │
│  [gráfico de linhas, 3 séries, rótulo direto no último ponto]    │
│  [faixas cinza verticais nos meses excluídos]                    │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Formas:** figura herói (um número é a manchete, não um gráfico de uma barra);
fila de quatro cartões com valor e variação; gráfico de linhas com três séries.

**A camada de exclusão é obrigatória.** Faixa vertical cinza claro nos meses de
`meses_excluidos`, com dica de contexto ao passar o mouse explicando o motivo.
Nos dois meses não publicados (2019-02 e 2025-07) a linha **interrompe** — não
interpola.

**Interação:** cruz vertical seguindo o cursor, com dica mostrando os três
valores e a taxa daquele mês.

---

## Página 2 — A vacância fantasma

**Pergunta:** metade dos cargos vagos jamais foi distribuída a um órgão. Desde
quando?

Esta é a página mais original do painel — o achado que nenhuma outra análise
pública desta base mostra.

```
┌──────────────────────────────────────────────────────────────────┐
│  DE ONDE VEM A VACÂNCIA                                          │
├──────────────────────────────────────────────────────────────────┤
│  Composição do cargo vago · 2016–2026                            │
│                                                                  │
│  [área empilhada, 2 séries]                                      │
│    ■ Nunca distribuído  (cargo existe em lei, não foi alocado)   │
│    ■ Vago após distribuição  (cargo alocado, sem servidor)       │
│                                                                  │
│  ┌─ anotação ancorada em 2023-2025 ───────────────────────────┐  │
│  │ Em dois anos a fração nunca distribuída salta de 35% a 52%.│  │
│  │ Coincide com as reformas ministeriais — parte pode ser      │  │
│  │ reclassificação, não decisão de pessoal.                    │  │
│  └─────────────────────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────────────────────┤
│  Onde se concentra · maio de 2026                                │
│  [barras horizontais, hue único, ordenadas]                      │
│  MEC ████████████████████████ 26.687  (93,4% da pasta)           │
│  MF  ████████████████████████ 26.655  (57,1%)                    │
│  MGI ███████████ 12.194  (50,5%)                                 │
│  ...                                                             │
│  → 13 órgãos concentram 80% do total                             │
└──────────────────────────────────────────────────────────────────┘
```

**Formas:** área empilhada para parte-do-todo ao longo do tempo; barras
horizontais com hue único para magnitude ordenada (nomes de órgão são longos —
horizontal).

**Não use pizza** para a composição. São duas partes que mudam ao longo do
tempo; pizza joga o tempo fora.

---

## Página 3 — Onde faltam

**Pergunta:** a vacância não é distribuída por igual. Onde ela morde?

```
┌──────────────────────────────────────────────────────────────────┐
│  RECORTES                        [ano ▾] [carreira ▾] [entidade ▾]│
├────────────────────────────┬─────────────────────────────────────┤
│ Taxa por nível · 2026-05   │ Taxa por nível ao longo do tempo    │
│                            │                                     │
│ Intermediário  ███████ 37,9│ [linhas, 3 séries]                  │
│ Superior       ██████ 31,3 │  superior ── reta em ~32%           │
│ Apoio          █ 5,4       │  intermediário ── sobe até 40% (2024)│
│                            │  apoio ── despenca (efeito extinção) │
├────────────────────────────┴─────────────────────────────────────┤
│  Carreiras com maior vacância · mínimo 2.000 cargos aprovados     │
│  [tabela ordenável: carreira, aprovados, ocupados, vagos, taxa]   │
└──────────────────────────────────────────────────────────────────┘
```

**Por que tabela e não gráfico para carreiras:** são 161 planos de carreira. Mais
de sete classes com significado próprio pedem tabela, não mais cores.

**Nota de rodapé obrigatória nesta página:** o nível de apoio cai porque os
cargos estão sendo extintos, não porque foram providos. Sem isso, o gráfico
sugere melhora onde há desaparecimento.

---

## Página 4 — Por que vagam e o que vai sumir

**Pergunta:** quais são as portas de saída, e o que acontece com os cargos em
extinção?

```
┌──────────────────────────────────────────────────────────────────┐
│  SAÍDAS E EXTINÇÃO                                               │
├──────────────────────────────────────────────────────────────────┤
│  ⚠ Números acumulados desde a origem da carreira, não fluxo mensal│
│                                                                  │
│  Composição das saídas · acumulado até 2026-05                   │
│  [barras horizontais ordenadas, hue único]                       │
│  Aposentadoria              ████████████████████ 214.061  76,6%  │
│  Posse em cargo inacumulável ██ 23.067  8,3%                     │
│  Exoneração                  ██ 20.672  7,4%                     │
│  Falecimento                 █ 16.927  6,1%                      │
│  Demissão                    ▌ 4.099  1,5%                       │
├──────────────────────────────────────────────────────────────────┤
│  Servidores em cargos extintos · janeiro de cada ano             │
│  [linha única com área]                                          │
│  56.432 (2022) → 38.784 (2026) · −4.400/ano                      │
│                                                                  │
│  [tabela: cargo, servidores, órgãos]                             │
└──────────────────────────────────────────────────────────────────┘
```

**O aviso sobre acumulado é obrigatório e fica no topo da página**, não em nota
de rodapé. É a armadilha mais séria da base inteira.

**Não empilhe as saídas numa barra só.** A aposentadoria com 76,6% esmaga
visualmente as outras seis; barras horizontais ordenadas deixam todas legíveis.

---

## Página de método (fora da navegação principal)

Uma página final, acessível por link discreto, com:

- Os sete meses excluídos e o motivo de cada um.
- A identidade `vago = aprovada − ocupada` e o que ela implica.
- A mudança de escopo de 2021 (entrada da ABIN).
- A advertência sobre acumulados.
- Link para o repositório e para o `dicionario_de_dados`.

Esta página é parte do argumento, não apêndice: é ela que separa este painel de
um dashboard bonito com número errado.

---

## Checagem antes de publicar

- [ ] Rodar `01_preparar_dados_painel.R` e conferir: último mês válido é 202605.
- [ ] Nenhum gráfico com dois eixos Y.
- [ ] Meses excluídos marcados em todas as páginas com série temporal.
- [ ] Lacunas de 2019-02 e 2025-07 interrompem a linha, sem interpolação.
- [ ] Legenda presente em todo gráfico com duas ou mais séries.
- [ ] Série magenta com rótulo direto (exigência de contraste).
- [ ] Aviso de "acumulado" no topo da página 4.
- [ ] Nota do nível de apoio na página 3.
- [ ] Modo escuro conferido, se o tema for publicado nos dois modos.
- [ ] Abrir o painel e olhar: rótulos colidindo, números estourando caixa.

---

## A escolha da ferramenta

| | stlite (Streamlit WASM) | Shinylive (R) | Power BI |
|---|---|---|---|
| Embute no site | ✅ padrão já estabelecido | ✅ mesmo fluxo | ❌ exige publish-to-web |
| Linguagem | Python | **R — a sua** | DAX |
| Roda sem servidor | ✅ WASM no navegador | ✅ WASM | ❌ |
| Já demonstrado no portfólio | ✅ exemplo no ar | ❌ | ✅ papa-entulhos |
| Manutenção | zero (estático) | zero (estático) | republicar |

**Decidido: Shinylive.** A análise inteira já está em R, os parquets estão
prontos, e o resultado embute no site pelo mesmo fluxo do stlite. Nada é
reescrito em Python nem em DAX.

O stlite é a contingência se o Shinylive der trabalho — o padrão já está provado
no site, ao custo de portar as agregações para pandas.

**Cuidado de tamanho:** o Shinylive baixa o runtime R para o navegador. Use
apenas as tabelas de `painel/dados/` (a maior tem 23 mil linhas), nunca o parquet
de 1,6 milhão, e limite os pacotes a `shiny`, `arrow`, `dplyr` e `ggplot2`.

**Power BI fica para o case papa-entulhos**, onde faz sentido — dado interno,
consumo corporativo, e já é o repertório demonstrável. Misturar as duas
ferramentas no portfólio não é inconsistência: é mostrar que você escolhe a
ferramenta pelo problema.

Se optar por Shinylive ou stlite, exporte também imagens estáticas dos gráficos
para ilustrar os artigos — o post do Quarto não deve depender do painel carregar.
