# Pauta: o que este dado sustenta

Avaliação do potencial editorial do projeto, com as hipóteses testadas contra o
dado real — não contra o que seria bom que o dado dissesse.

**Veredito: 6 artigos fortes, 2 condicionais, 1 painel principal.**

Não são 15. A tentação de fatiar um dataset em vinte posts produz vinte textos
fracos; a autoridade vem de seis textos que ninguém mais escreveu.

---

## Os 6 artigos que se sustentam

### 1. Metade dos cargos "vagos" nunca existiu de verdade ⭐

**O achado mais forte do conjunto, e o mais contraintuitivo.**

A coluna `distribuida` separa duas coisas que o indicador oficial mistura: cargo
criado em lei mas **nunca alocado a nenhum órgão**, e cargo que foi distribuído e
está esperando alguém.

| | 2016-01 | 2026-05 |
|---|---|---|
| Vagos (total) | 257.779 | 231.887 |
| Nunca distribuídos | 91.195 | **116.049** |
| **Fração nunca distribuída** | **35,4%** | **50,0%** |

A vacância total caiu 10% na década. A vacância *fantasma* — cargo que existe só
no papel da lei — **subiu 27%** e hoje é metade do total.

Ou seja: quando se diz "o Executivo tem 232 mil cargos vagos", metade desse
número não é posto de trabalho esperando servidor. É autorização legislativa que
nunca virou estrutura. São coisas diferentes e a conversa pública trata como uma.

Por que é forte: contraria a leitura padrão, usa uma coluna que ninguém olha, e a
metodologia é simples de explicar. É o artigo que eu publicaria primeiro.

### 2. Panorama: a década em que a máquina encolheu e a vacância não mexeu

Aprovados −11,3%, ocupados −11,8%, vagos −10,0%, taxa de 32,69% → 33,13%.

Tudo encolheu junto, quase na mesma proporção. A máquina não foi enxugada
cortando o que estava vago — encolheu inteira, mantendo a mesma fração de
buracos. Serve de artigo de abertura e de base para os outros.

### 3. Por que os cargos vagam: 77% é aposentadoria

Composição acumulada das saídas (2026-05):

| Motivo | Total | % |
|---|---|---|
| Aposentadoria | 214.061 | 76,6% |
| Posse em cargo inacumulável | 23.067 | 8,3% |
| Exoneração | 20.672 | 7,4% |
| Falecimento | 16.927 | 6,1% |
| Demissão | 4.099 | 1,5% |
| Promoção / readaptação | 611 | 0,2% |

Dois ganchos: a dominância da aposentadoria como sinal demográfico, e o dado de
que **posse em cargo inacumulável supera exoneração** — mais gente troca de
carreira dentro do Estado do que sai dele.

Ressalva obrigatória: o dado é acumulado e não sustenta fluxo mensal. O artigo
fica no terreno da composição.

### 4. Onde faltam: por nível de escolaridade

| Nível | Aprovados | Taxa de vacância | % do vago total |
|---|---|---|---|
| Nível superior | 438.397 | 31,3% | 59,1% |
| Nível intermediário | 247.417 | **37,9%** | 40,4% |
| Nível de apoio | 13.478 | 5,4% | 0,3% |

O nível intermediário tem a maior taxa; o superior concentra o volume. O nível de
apoio, quase sem vacância, é a pista para o artigo 5.

### 5. Os 38 mil servidores em cargos que a lei já extinguiu

**Este artigo nasceu de uma hipótese minha que deu errado** — e ficou melhor.

Eu apostava que cargos em extinção inflavam a vacância (estrutura fantasma). O
dado desmente: cargos em extinção são **99,1% ocupados** e respondem por 0,1% da
vacância.

O achado real é o oposto: 3.519 tipos de cargo em extinção abrigam **37.725
servidores ativos**. É uma força de trabalho que a lei condenou a desaparecer por
atrito — sem reposição, sem concurso, sem sucessão planejada. Ninguém está vago
ali hoje; o problema chega quando essa gente se aposentar.

Cruzar com o artigo 3 (76,6% das saídas já são aposentadoria) fecha o argumento.

### 6. Diário de bordo: o que a planilha não conta ⭐

O artigo metodológico — e o mais alinhado ao seu posicionamento e à série "mão na
massa".

Material real acumulado neste projeto:

- Uma **linha de total geral** escondida no rodapé de um arquivo, que dobrou 2019-01
  na primeira versão da compilação. Erro meu, encontrado pela validação.
- **2026-06 corrompido**: vacâncias inflando de 1,2× a 4,4× de um mês para o outro.
- **2018-03 com dupla contagem**: sete códigos novos publicados sobre os antigos.
- **Contadores acumulados** que parecem fluxo mensal e destroem qualquer análise
  de quem não perceber.
- **Códigos de órgão que trocam** e deixam cascas residuais (a AGU 40106 cai de
  8.856 para 1 cargo com zero ocupados).
- Duas abas do mesmo arquivo que **divergem em 141 pares** órgão-mês.

O texto se escreve sozinho e demonstra exatamente o que diferencia você: não é
saber rodar um `group_by`, é saber que o número não é o número até passar pela
conferência. É o artigo que gera convite para palestra.

---

## Os 2 condicionais

### 7. Ranking por órgão — depende de decisão editorial

Tecnicamente pronto (o de-para resolve a comparação). O problema é político: um
ranking de "piores ministérios" assinado por servidor público em exercício, sob
a Lei 840, pede cautela. **Sugestão:** publicar como análise por *bloco* e por
*carreira*, não como ranking nominal de pastas. Preserva o valor analítico sem o
atrito.

### 8. Guia prático do Painel Estatístico de Pessoal — página, não artigo

Onde achar, o que cada coluna significa, as armadilhas. Alto tráfego orgânico e
generoso. Mas o lugar natural é a página **Materiais**, reaproveitando o
`dicionario_de_dados.qmd` que já existe.

---

## Ideias que eu descartaria

- **Um artigo por ministério.** Vinte textos iguais com números trocados.
- **Atualização mensal da série.** Vira obrigação, não autoridade — e o dado se
  move devagar demais para justificar.
- **Comparação com estados ou com o DF.** O dado não existe aqui. Seria outro
  projeto, não um artigo deste.
- **"O que a IA diz sobre os dados."** Fora do posicionamento.

---

## Painéis para o portfólio

### 1 painel principal — "Explorador da vacância federal" ⭐

Granularidade disponível: 124 meses × 233 órgãos × 3.253 cargos × 161 planos de
carreira. Sobra dado para um painel de verdade.

Estrutura sugerida:

- **Visão geral:** série da taxa de vacância, com os meses descartados marcados
  visualmente (não escondidos — a honestidade metodológica é parte da peça).
- **Decomposição:** o corte nunca-distribuído vs. vago-após-distribuir, que é o
  achado do artigo 1 e a coisa mais original do painel.
- **Recorte:** filtros por entidade, carreira e nível.
- **Saídas:** composição acumulada por motivo.

Formato: **Power BI**, pelos mesmos motivos do case papa-entulhos — é a
ferramenta em que você já tem repertório demonstrável, e conversa com o público
de gestor público. Um Shiny/Quarto seria mais elegante tecnicamente e menos
legível para quem contrata palestra.

### Por que só um

Com ~3h/semana, um segundo painel custa um trimestre inteiro e divide a atenção
de quem visita. Portfólio não se avalia por contagem: um painel excelente com
seis artigos que o sustentam vale mais que três painéis medianos.

O papa-entulhos continua sendo o case âncora (trabalho real, dado interno,
impacto de gestão). Este vira o **case público**: mesmo rigor, dado aberto,
totalmente reproduzível — qualquer pessoa pode rodar `01_compilar.R` e chegar aos
seus números. Os dois juntos cobrem as duas provas que importam: sei fazer dentro
da máquina, e sei fazer à vista de todos.

---

## Ordem sugerida de publicação

| # | Peça | Por quê nesta posição |
|---|---|---|
| 1 | Artigo 2 (panorama) | Estabelece o terreno e a série |
| 2 | Artigo 1 (nunca distribuídos) | O achado forte, com o terreno já posto |
| 3 | **Painel** | Publicar junto com o artigo 2, que é o gancho de divulgação |
| 4 | Artigo 6 (diário de bordo) | Consolida autoridade metodológica |
| 5 | Artigo 3 (por que vagam) | |
| 6 | Artigo 5 (cargos em extinção) | Fecha com o artigo 3 |
| 7 | Artigo 4 (nível de escolaridade) | O mais dispensável se o tempo apertar |

A 3h/semana, isso é um plano de aproximadamente seis a oito meses. Não tente
comprimir: um artigo por mês com número conferido constrói mais reputação que
seis em março e silêncio no resto do ano.
