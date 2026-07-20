# O que aprendi construindo o painel em Shinylive

> Escrito em 2026-07-19, depois de construir o painel dos cargos em Shinylive
> e decidir portá-lo para o padrão HTML/SVG do painel do SLU.
>
> **O Shinylive funcionou.** Não foi abandonado por defeito: foi abandonado
> porque 115 MB não se justificam quando 60 KB entregam a mesma peça. Este
> documento existe para que o conhecimento não se perca com o código, e para
> que a decisão possa ser revista com base em fato, não em memória.

---

## 1. A decisão, em uma tabela

| | Shinylive | Padrão SLU (HTML + SVG) |
|---|---|---|
| Tamanho publicado | **115 MB**, 228 arquivos | ~60 KB |
| Primeiro carregamento | ~60 s (baixa o R inteiro) | instantâneo |
| Tema escuro do site | ❌ ilha clara do bslib | ✅ herda por variáveis CSS |
| Cabeçalhos COOP/COEP | **obrigatórios** | desnecessários |
| Peso no git | pesa em todo clone | irrelevante |
| Dependências | webR + shinylive + 7 pacotes | nenhuma |
| Filtro livre sobre a base toda | ✅ é o que ele faz bem | ❌ agregados prontos |

O item que mais pesou não foi o tamanho: foi o **tema escuro**. O site é escuro,
e um app bslib embutido nele é um retângulo branco no meio da página. Não há
conserto barato — corrigir exigiria reimplementar o tema de qualquer jeito.

**Quando o Shinylive voltaria a ganhar:** se o painel precisar recalcular de
verdade sobre a base inteira a partir de filtros livres do usuário. Aí o custo
do runtime se paga. Para recorte fixo e série de 119 pontos, não se paga.

---

## 2. Armadilhas técnicas — a parte que vale guardar

### 2.1 `arrow` não existe em webR. `nanoparquet` existe.

A mais séria, e a que teria custado mais caro se descoberta tarde. O `arrow`
depende de uma biblioteca C++ que não compila para Emscripten, e provavelmente
nunca estará lá.

O substituto é o **`nanoparquet`**, sem dependência nenhuma. Testado nas sete
tabelas de `painel/dados/` contra o `arrow`, coluna a coluna: **resultado
idêntico em todas**. A troca é indolor.

Isso vale além do painel: **qualquer código que vá para WASM não pode usar
`arrow`**. Nos artigos e nos scripts de `code/`, que rodam localmente, o `arrow`
continua sendo o certo.

### 2.2 Confira a disponibilidade ANTES de escrever o código

O repositório de pacotes WASM tem 23.559 pacotes e é consultável direto:

```
https://repo.r-wasm.org/bin/emscripten/contrib/4.5/PACKAGES
```

Baixe e procure `Package: <nome>`. Trinta segundos de conferência evitam
reescrever um app inteiro. Conferidos e **disponíveis**: dplyr, tidyr, ggplot2,
**ggiraph**, reactable, DT, gt, bslib, shiny, nanoparquet, duckdb, readr,
data.table, patchwork, stringr, forcats, scales, tibble, purrr.

Que o **ggiraph** exista em WASM é bom saber: o padrão de interação dos artigos
(`banda_hover`, `girafe_*`) roda igual no navegador, sem reescrever nada.

### 2.3 Não use `bs_theme()` em app Shinylive

O `bs_theme()` recompila **Sass em tempo de execução**. Em WebAssembly isso é
caro. Cor de destaque e fonte por CSS puro custam zero e dão o mesmo resultado.

O `font_google(local = FALSE)` é suspeito adicional: fonte externa dentro de um
ambiente isolado é pedir para travar.

### 2.4 O export exige isolamento cross-origin

O webR usa `SharedArrayBuffer`, que o navegador só libera quando a página está
*cross-origin isolated*. Isso exige dois cabeçalhos:

```
Cross-Origin-Embedder-Policy: require-corp
Cross-Origin-Opener-Policy: same-origin
```

Consequências práticas:

- `python -m http.server` **não serve** para testar. Sem os cabeçalhos o webR cai
  no canal `PostMessage` e avisa no console. Use `painel/servidor_coop.py`.
- No Cloudflare Pages isso vira um arquivo `_headers` (ver `painel/_headers`).
- Verifique no console do navegador: `window.crossOriginIsolated` deve ser `true`.

### 2.5 Limites do Cloudflare Pages

25 MB por arquivo, 20.000 arquivos. O export passa com folga: o maior arquivo é o
`R.wasm`, com 17,2 MB, e são 228 arquivos. **Publicar não é o problema — o git é.**

### 2.6 Tempos de carregamento em WASM

Medidos com um app de diagnóstico, servidor local:

```
bslib 2s · dplyr 13s · tidyr 9s · ggplot2 12s · ggiraph 7s
reactable 4s · nanoparquet 4s        total ≈ 51 s
```

Cada pacote a menos é ~5–13 s a menos na primeira visita.

---

## 3. Como depurar Shinylive — isto é o que faltava saber

### 3.1 O console mente sobre o que é erro

O shinylive encaminha o **stderr do R** para o console do navegador com o
prefixo `preload error:`. Mensagens normais de `library()` — "Attaching
package", "The following objects are masked" — aparecem como **ERROR** em
vermelho e **não são erros**.

### 3.2 Silêncio não é travamento

Só alguns pacotes emitem mensagem ao anexar (`bslib`, `dplyr`). Depois do
`dplyr`, o console fica mudo por ~40 s enquanto carrega tidyr, ggplot2, ggiraph,
reactable e nanoparquet — **e isso é normal**.

⚠️ Eu li esse silêncio como travamento e concluí defeito duas vezes seguidas. As
duas vezes estava errado. Antes de chamar de travamento, ponha um marcador que
prove onde parou.

### 3.3 A técnica que funcionou: app mínimo com marcadores

Em vez de adivinhar, exporte um app de três linhas que imprime onde chegou:

```r
for (p in c("bslib","dplyr","tidyr","ggplot2","ggiraph","reactable","nanoparquet")) {
  cat("### tentando:", p, "\n")
  cat("### resultado:", p, "=", requireNamespace(p, quietly = TRUE), "\n")
}
cat("### FIM\n")
```

Leia o console filtrando por `###`. Em um ciclo de export você sabe exatamente
onde parou — em vez de várias rodadas de palpite. Foi assim que ficou provado
que os sete pacotes carregam e que o `nanoparquet` lê o parquet corretamente.

Depois faça um segundo app que carregue os **dados e o tema reais**, ainda com
interface trivial. Isso separa "problema de dado" de "problema de interface".

---

## 4. O que fica pronto para reuso

Mesmo portando o painel, sobra coisa boa:

- **`painel/app/`** continua funcionando como Shiny local. É a especificação
  executável do painel: a lógica está resolvida e os números conferidos contra
  os artigos. O port traduz algo que funciona, não descobre de novo.
- **`painel/servidor_coop.py`** — servidor estático com os cabeçalhos certos.
  Serve para qualquer teste de WASM, não só deste projeto.
- **`painel/_headers`** — pronto para o Cloudflare, se algum dia um painel WASM
  for publicado.
- O mapa de pacotes disponíveis em WASM, na seção 2.2.

---

## 5. Resumo em cinco linhas

1. Em WASM, `arrow` não existe; use `nanoparquet` — leitura idêntica.
2. Confira `repo.r-wasm.org` **antes** de escrever o app.
3. Nada de `bs_theme()`; CSS puro.
4. Sem COOP/COEP o painel não sobe — nem em teste, nem no ar.
5. No console, `preload error:` quase sempre não é erro, e silêncio não é
   travamento. Prove com marcadores antes de concluir.
