# Como gerar o painel

O painel é um **arquivo HTML autocontido de ~66 KB**, no mesmo idioma do painel
do `Relatorios_slu`: dados embutidos em JSON, gráficos em SVG construído à mão,
zero script externo, tema claro/escuro por variáveis CSS.

## O caminho inteiro, três comandos

```
cd Projetos_dados_abertos\Cargos_executivo_federal\painel
Rscript 01_preparar_dados_painel.R   # parquets -> 7 tabelas agregadas
Rscript 02_json_painel.R             # tabelas  -> dados_painel.json  (~27 KB)
Rscript 03_montar_painel.R           # template + json -> vacancia-federal.html
```

Onde `Rscript` é `C:\Program Files\R\R-4.5.2\bin\Rscript.exe`.

Para ver: abra `vacancia-federal.html` direto no navegador. **Não precisa de
servidor** — não há `fetch`, os dados estão dentro do arquivo.

## Os arquivos

| Arquivo | Papel |
|---|---|
| `html/_template.html` | **O que se edita.** Layout, CSS e os gráficos em SVG. |
| `02_json_painel.R` | Agrega e confere. É aqui que os números se fixam. |
| `03_montar_painel.R` | Injeta o JSON no template. |
| `vacancia-federal.html` | **Gerado — não edite.** É o que vai para o site. |
| `dados_painel.json` | Gerado. Útil para conferir um número à mão. |

## Regras que o código sustenta

- **Mês defeituoso aparece marcado, nunca apagado.** Faixa cinza para os cinco
  quebrados, tracejado vertical para os dois não publicados.
- **Linha e área interrompem no buraco.** Nem a linha nem a área empilhada
  atravessam um mês ausente. A faixa marca a ausência e o desenho não a
  desmente. Ver `trechos` em `areaEmpilhada()`.
- **Eixo com passo redondo.** `passoBonito()` evita marcas em 9%, 18%, 27%.
- **Faixa nunca transborda a área do gráfico** — o mês excluído mais recente
  fica além do último ponto plotado e vazaria (`corta()` em `camadaRuins`).
- **Um eixo por gráfico.** Nunca dois eixos Y.
- **Sete conferências** rodam em `02_json_painel.R` antes de escrever o arquivo,
  e o script morre se alguma falhar: 119 meses, nenhum mês ruim vazado, taxa
  final 33,13%, identidade `vago = aprovada − ocupada`, saídas somando 100%.

## Publicar

```
copiar  vacancia-federal.html  ->  <repo>\public\apps\vacancia-federal\index.html
criar   <repo>\src\content\paineis\vacancia-federal.md  com  app: /apps/vacancia-federal/
```

Nada de `_headers`, nada de COOP/COEP, nada de runtime. É um arquivo estático.

---

## Sobre a versão em Shinylive (aposentada)

`painel/app/` continua rodando como Shiny local e serve de especificação
executável — a lógica está resolvida e os números conferidos.

```
Rscript -e "shiny::runApp('app', port=8911, launch.browser=TRUE)"
```

**Por que foi aposentada, e todo o aprendizado técnico do WASM:**
ver `APRENDIZADO-SHINYLIVE.md`. Leia antes de cogitar WASM de novo.

`painel/dist/` (o export em WASM, 115 MB) foi **apagado em 19/07/2026**, com
autorização do Théo. É regenerável pelo `shinylive::export()` se algum dia fizer
falta.

---

## Pendência: o modo escuro ainda não vem do pacote

As cores do **modo claro** são injetadas do `theoviz` pelo `03_montar_painel.R`,
como manda o `CLAUDE.md`. As do **modo escuro** continuam fixas no template,
porque o `theoviz` só tem a paleta clara (`paleta()` e `tinta()`).

Enquanto isso durar, mudar uma cor escura exige editar o template — e o painel
pode divergir dos artigos sem ninguém perceber. A correção certa é o pacote
ganhar as variantes escuras (algo como `paleta(modo = "escuro")`), e então o
script injetar as duas. Os valores escuros em uso estão em `ESPECIFICACAO.md`.
