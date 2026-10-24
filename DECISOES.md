# Decisões de design e técnicas

Registro das decisões tomadas sem consulta (modo autônomo), com o motivo.

## Tecnologia

| # | Decisão | Por quê |
|---|---|---|
| T1 | **Godot 4.3 stable**, renderer **GL Compatibility** | Versão estável e madura da 4.x; o renderer de compatibilidade (OpenGL ES 3) roda em celulares intermediários e permite testes headless. |
| T2 | UI construída **por código** (sem .tscn por tela) com tema próprio | Tudo versionável, fácil de revisar e testar headless; uma única cena (`scenes/main.tscn`). |
| T3 | Fonte **DejaVu Sans Condensed Bold** embutida | A fonte padrão do Godot não tem ★ ✦ ▶ ◀ ▲ ▼ ☑; a DejaVu tem licença livre, acentos PT-BR e esses símbolos. |
| T4 | Arte placeholder **gerada por código** (SpriteFactory/TileFactory/HubArt) com *override* por PNG em `assets/` | Distingue tipo (cor), família (formato) e estágio (tamanho); trocar a arte não exige mudar código. |
| T5 | Mapa da hunt em **SubViewport** acima do painel inferior | Garante que o banner e a UI nunca cobrem o combate; zoom independente da UI. |
| T6 | Simulação em **passo fixo de 50 ms** | Determinística e estável; o "acelerar tempo" do debug apenas executa mais passos por quadro (até 400). |
| T7 | Nós leves: `Sprite2D` com `hframes/vframes`, efeitos e textos desenhados em **um único `_draw()`** (FxLayer) | Medido: **0,23 ms por passo** com 54 inimigos ativos (smoke test) → sobra muito para 60 FPS em celulares intermediários. |
| T8 | A hunt **continua rodando** enquanto o jogador navega nos menus | É um idle: o progresso não para; o SubViewport deixa de renderizar quando oculto para poupar GPU. |
| T9 | Camada de serviço `BackendService` com `request(acao, args)` e duas implementações (Mock e Supabase) | Interface única; o mock aplica exatamente as mesmas regras (`ServerLogic`) que a Edge Function (`logic.ts`). |
| T10 | APK debug **sem gradle** (template pronto) | `dl.google.com` estava bloqueado no ambiente; apksigner/zipalign vieram do apt. O AdMob exige gradle → preset separado de release (AAB). |
| T11 | Nome provisório **"Bestiário Idle"**, pacote `com.bestiarioidle.game` | Original, em PT-BR, sem marca de terceiros. |

## Combate

- **Dano** = `ATQ × poder × ATQ / (ATQ + DEF) × tipo × variação(±10%) × crítico(1,5x, 5% base)`. Mínimo 1. A razão ATQ/(ATQ+DEF) é invariante de escala: monstros do mesmo nível sempre levam ~o mesmo número de golpes, em qualquer faixa.
- **Atributos**: `base_família × (1 + 0,08·(nível−1)) × estágio[1; 1,35; 1,8] × (1 + 6%·estrelas) × qualidade × shiny + itens` — qualidade dá até +30%, shiny +50%. Velocidade não cresce por nível (só estágio, estrelas e itens); intervalo de ataque = 1,25 s × 100/VEL.
- **Inimigos** usam a mesma fórmula com modificadores (`enemy_mods`: HP 0,42, ATQ 0,55, DEF 0,7) para que o monstro do jogador mate em ~3-4 golpes e possa ser cercado. No Mundo 2 os modificadores sobem gradualmente (rampa de 30 níveis a partir do 90) para não criar um "muro" antes do nível 110.
- **IA do jogador**: sai de áreas de perigo → escolhe alvo (prioriza quem o ataca; "focar" segue o alvo do líder, "espalhar" penaliza alvos já escolhidos) → usa habilidades (cura <55% HP, área com ≥1-2 inimigos no raio, ataques no alvo) → ataca ou persegue com `AStarGrid2D` (diagonal sem cortar quinas; re-caminho a cada 0,45 s e desvio de criaturas quando bloqueado).
- **Selvagens**: vagam perto do spawn, *aggro* a 5 tiles, coleira de 12 tiles.
- **Regeneração** de 0,8% HP/s sempre ativa; monstro do jogador revive em 5 s (exceto em Desafios). 3 derrotas do grupo em 5 min → a UI sugere uma hunt mais fácil.
- **Corpos** ficam 6 s no chão; o loot "voa" até o monstro (coleta automática).

## Curva de XP e tempo de jogo

- Abates necessários por nível: `K(L) = 6 + 2,9·L^1,5 · (1 + 0,026·max(0, L−80))` (0,022 até a revisão 3)
- XP por abate de inimigo nível `Le`: `xp(Le) = ⌊4·Le^1,35⌋`
- XP para subir: `xp_to_next(L) = ⌈K(L) · xp(L)⌉`
- Penalidade por caçar muito abaixo: −4% por nível de diferença além de 10 (mínimo 20%).
- **Estimativa (simulação, sem 2x XP)** — detalhes em `docs/RELATORIO_BALANCEAMENTO.md`:

| Faixa | Horas de caça | Casual (~8 h de caça/dia: 1h ativa + 8h offline) | Dedicado (~17 h/dia) |
|---|---|---|---|
| 1 → 16 | ~2 h | 1º dia | 1º dia |
| 16 → 35 | ~8 h | 1-2 dias | 1 dia |
| 35 → 80 | ~55 h | ~1 semana | ~4 dias |
| 80 → 110 | ~100 h | ~2 semanas | ~1 semana |
| 110 → 210 | ~970 h | ~4 meses | ~2 meses |
| 210 → 300 | ~2.300 h | ~9 meses | ~4,5 meses |

  "Horas de caça" = online + offline (o offline rende 90% do online e é limitado a 8 h por sessão).

## Grupo

- Até 3 monstros. Lutam no mapa: 1 (níveis 1-109), 2 (110+), 3 (210+) — pelo nível do **principal** (1º do grupo).
- Quem luta recebe 100% da XP do abate; quem está na reserva, 50%.
- Recrutados entram automaticamente no grupo se houver vaga.

## Hunts

- **Mundo 1**: 144 hunts — 45 de Filhotes (15 liberadas no nível 1: Água/Planta/Vento; 15 no 6: Fogo/Terra/Luz; 15 no 12: Gelo/Elétrico/Sombra — grupos espalhados no ciclo para que todo inicial tenha alvos favoráveis cedo), 45 de Adolescentes (16→34), 45 de Adultos (35→80) e 9 mistas em biomas de transição (Pântano, Fontes Termais, Deserto de Cinzas...). Todas as 135 formas aparecem até o 80.
- **Bloqueio por Desafio**: hunts de nível 11-20 exigem o Desafio 10, 21-30 o Desafio 20, etc. (o Desafio N "libera o próximo bloco").
- **Mundo 2**: gerado por `config.world2` (90 a 300, a cada 10 níveis, 3 hunts por nível = 66 hunts), biomas corrompidos (paleta tingida + cristais), mapas 64x64, 30 inimigos simultâneos, 3 tipos por hunt, sem recrutamento, raridade ×1,5, ouro ×1,5 e tiers de item 7-9 exclusivos.
- Mapas procedurais com **seed fixa por hunt**: 4 estilos (aberto, caverna, ilhas, salas) por bioma; só a maior região conectada é mantida (todos os spawns alcançáveis — testado).

## Desafios

- 9 chefes (10..90) com fases (enfurece em 50% de HP), invocações e áreas de dano com aviso (a IA sai dos tiles marcados).
- **Sem reviver durante o desafio**; derrota = cooldown de 60 s; limite de 4 min.
- 1ª vitória: ouro, Essência do tipo do chefe e item garantido (Raro até o 30, Épico até o 60, Lendário depois); vitórias seguintes rendem 25% (sem item). O 80 abre o Mundo 2.
- HP/ataque dos chefes calibrados com o combate real (`tools/challenge_sim.gd`): um inicial com **vantagem** de tipo vence ~3 níveis acima; **neutro** ~3-8 níveis acima; com **desvantagem** é preciso grupo/itens/estrelas melhores — a escolha estratégica importa.
- Para adicionar desafios acima de 90, basta incluir entradas em `data/challenges.json`.

## Itens, Essência e Estrelas

- Raridades e chances por abate (reduzidas na revisão 2): Comum 1/80, Incomum ~1/333 (cliente, **vinculados**), Raro ~1/333, Épico ~1/3.333, Lendário ~1/33.333, Mítico 1/400.000 (servidor).
- 4 slots: Amuleto (HP), Garra (ATQ), Armadura (DEF), Relíquia (VEL% + Crítico). 9 tiers (níveis 1, 12, 25, 40, 60, 80, 120, 170, 230), 1 tema por tipo (+15% no atributo principal se o monstro for do mesmo tipo). Afixos aleatórios a partir de Épico (1/2/3 para Épico/Lendário/Mítico).
- Aprimoramento +1..+10 (+8% por nível); +1..+5 sempre funciona; a partir do +6: 75%, 60%, 45%, 30%, 20%. **Nunca destrói.**
- Essência ao trocar monstro: `base_estágio[5; 15; 40] × (1 + nível/20) × mult_família × (1 + 0,2·estrelas) × (50 se shiny)`. Shiny pede confirmação dupla.
- Estrelas: custos 30/90/250/600/1500 Essência do tipo; +6% atributos cada; 3ª e 5ª: habilidades +25% poder e −10% recarga.
- Inventário 60 (+10 por expansão, custo crescente, máx. 300); Depot de itens 300. Itens negociáveis nunca se perdem por inventário cheio (vão para o Depot). Trava contra venda, confirmação para vender Raro+, auto-venda opcional de Comum/Incomum.
- Coleção: substituída pelos **Marcos de Caça** na revisão 3 (ver R16).

## Anti-trapaça (servidor autoritativo)

- **Carteira no servidor**: ouro e Essência só mudam por ações validadas (abates aceitos, vendas, Altar, Desafios, market).
- **Itens negociáveis** (Raro+) só existem no servidor (`items`); o cliente cria apenas Comum/Incomum vinculados. Venda de vinculados ao NPC é limitada por um "orçamento" que só cresce com abates aceitos (impede imprimir ouro).
- **Abates em lote** (a cada 10 s): o servidor calcula o máximo plausível = `taxa_de_abates(grupo, hunt) × tempo_real × 1,6 + 3`, usando os níveis validados e equipamento generoso; o excesso é descartado.
- **Shiny** por *tickets de spawn* sorteados no servidor (1/5000); o abate só conta como shiny com ticket válido, da mesma hunt e não usado.
- **Recrutamento** (0,2% por abate; ×10 em shiny) e drops Raro+ sorteados no servidor no momento do abate aceito.
- **Estrelas** registradas no servidor (ranking de Estrelas usa o servidor).
- **XP/nível**: no `sync_save` o servidor calcula o maior nível alcançável desde a última validação (taxa de XP muito generosa) e corrige/sinaliza saves impossíveis.
- **Offline**: o servidor mede o tempo real desde o último contato (limite 8 h) e calcula os abates com os atributos do cliente limitados ao máximo plausível.
- **Market**: funções Postgres atômicas (`DELETE ... RETURNING` + `FOR UPDATE`): impossível comprar duas vezes, duplicar item ou vender o que não tem.
- O mock local segue as mesmas regras; os "forçar drop/shiny/recrutamento" do debug só funcionam no mock em build debug.

## Market

- Venda por ouro, taxa de 5% sobre a venda, até 10 listagens por jogador, filtros por slot, raridade, aprimoramento mínimo, atributo e tipo de Essência. Monstros não entram.
- No mock: 60 ofertas de vendedores fictícios (reabastecidas) e compradores fictícios que compram suas listagens após ~45 s (35% de chance por consulta), para testar compra e venda.

## Monetização

- Banner fixo no rodapé fora do mapa; *rewarded* opcionais: 2x XP por 30 min (acumula), dobrar recompensa offline (1x por resumo) e reviver instantâneo; intersticial só ao abrir o Hub, no máximo 1 a cada 5 min, bloqueado durante Desafio e no resumo offline. UMP/GDPR antes de inicializar o SDK.

## Online

- Login anônimo automático; "Vincular Google" via OAuth do Supabase (linkIdentity). Save na nuvem a cada 2 min (e restauração automática se o save local estiver vazio).
- Rankings: Nível (validado), Coleção, Shinies, Estrelas e tempo de cada Desafio — global e semanal (semanal = ganho desde o início da semana; para desafios, melhor tempo da semana).


## Revisão 2 (pedido de melhorias)

| # | Decisão | Por quê |
|---|---|---|
| R1 | **45 famílias novas = animal + elemento** (raposa de fogo, pinguim de gelo, ovelha elétrica, morcego sombrio, polvo das sombras...) com nomes próprios originais em PT-BR (trocadilhos: Picolino, Ursorvete, Lãmpadinha, Torreminho...). Os nomes de monstros são iguais em todos os idiomas, como nomes próprios. | Mais carisma e identidade; nada de nomes genéricos; sem material protegido. |
| R2 | Sprites placeholder agora têm **traços do animal** (orelhas, caudas, chifres, casco, juba, lã, asas, bico, pinças, tentáculos...) + **acento do elemento** (chama, gota, cristais, folhas, pedra, raio, redemoinho, auréola, fumaça sombria), olhos grandes com brilho, bochechas nos filhotes e sobrancelha brava nos adultos. Prévia em `docs/sprites_preview.png`. | Reconhecível em 32 px e coerente com o tema. |
| R3 | **Qualidade 0–100%** sorteada no servidor ao recrutar: `100·u^1,8` (maioria baixa — média ~36%; ≥90% ≈ 5%). Bônus de atributos = 30% × qualidade. Faixas: Comum <40, Bom 40–69, Ótimo 70–89, Perfeito 90+. Inicial vem com 50%. Aumenta a Essência no Altar (×(1+q)). | Cria o "caçar um parceiro bom" e retenção de longo prazo. |
| R4 | **Shiny**: capturável, **+50% de atributos** e qualidade 50–100% (`50 + 50·u^1,3`). Abate de shiny tem chance de recrutamento ×10. | Pedido; shiny vira o grande prêmio. |
| R5 | **Revezamento do time**: quem cai é substituído pelo próximo membro vivo do grupo; o time só renasce (após 5 s) quando todos caíram. Todo monstro que entrou em campo no ciclo recebe a XP de quem luta (100%), mesmo caído; quem não entrou recebe 50%. Em Desafios/Chefe Diário a substituição também vale, mas não há renascimento. | Pedido; evita "morri e fiquei parado". |
| R6 | O mundo confere a cada 0,5 s se o número de monstros vivos em campo bate com o nível do principal e **corrige sozinho** (inclusive ao cruzar 110/210 por XP). | Corrige o bug "2 ativos no grupo mas só 1 no mapa". |
| R7 | **Chefe Diário**: 1 chefe por dia (rotação pelas 45 formas adultas, nível acompanha o principal), **3 entradas/dia** (dia UTC, servidor). Recompensa = ouro (120 abates do nível) e Essência do tipo, proporcional ao dano (mínimo 20%); vitória garante item Raro (22% Épico, 3% Lendário). O servidor limita o dano informado ao máximo plausível do grupo no tempo da luta. | Pedido; dá motivo para voltar todo dia. |
| R8 | **Início mais rápido**: nos níveis 1–14 os abates necessários são multiplicados de 0,14 (nível 1) até 1 (nível 15). Nível 5 em ~2 min, 10 em ~20 min, 16 em ~1 h. Resto da curva igual. | Ritmo que fisga nos primeiros minutos. |
| R9 | **Drops menores** (ver tabela acima). | Pedido; valoriza cada drop e o Market. |
| R10 | Aviso de "hunt difícil": se o jogador escolher **Ficar**, não pergunta de novo por **60 s**. | Pedido. |
| R11 | **3 idiomas (PT-BR, EN, ES)**. Interface via `Loc.t("texto PT")` + `locale/translations.csv` (gerado por `tools/build_translations.py`, que acusa textos sem tradução); dados (tipos, itens, habilidades, biomas, hunts, raridades, descrições) com objetos `{pt_BR, en, es}` gerados por `tools/gen_data.py`. Idioma inicial detectado pelo sistema. **Um único Market** para todos: as listagens guardam só ids (base, raridade, tipo) e cada jogador vê os nomes no próprio idioma. | Pedido. |
| R12 | Nomes de hunts com **concordância de gênero** (PT/ES): "Templo Esquecido", "Clareira Selvagem". | Corrige "Templo Esquecida". |
| R13 | **Visual refinado**: molduras pixel art 9-patch geradas por código (borda com luz/sombra), botões com relevo e variantes (principal dourado, perigo vermelho, anúncio verde), 33 ícones pixel art, chips, etiquetas de tipo/raridade/qualidade, retratos com moldura da cor do tipo, fundo texturizado. | "Cara de bem feito" e coerente com o jogo. |
| R14 | **Avisos** num único centro de notificações, centralizado no topo, empilhado (máx. 3) com ícone e animação. | Corrige avisos desalinhados no topo. |
| R15 | **Rolagem por toque**: cards e botões deixam o toque "atravessar" (`MOUSE_FILTER_PASS`) para o ScrollContainer arrastar; zona morta de 12 px. Reproduzido e validado com evento de toque simulado. | Corrige "lista de hunts não rola". |


## Revisão 3 (segundo pedido de melhorias)

| # | Decisão | Por quê |
|---|---|---|
| R16 | **Marcos de Caça** (mecânica central de longo prazo): cada forma tem 6 marcos de abates — Bronze 10, Prata 50, Ouro 250, Platina 1.000, Diamante 4.000, Lenda 15.000 — que valem 1/1/2/2/3/3 pontos (12 por forma). Cada ponto dá um bônus **permanente da conta** no atributo ligado ao **tipo** da forma: Água = Vida (0,25%), Fogo = Ataque (0,25%), Gelo = Defesa (0,3%), Planta = XP (0,25%), Terra = Ouro (0,5%), Elétrico = Velocidade (0,12%), Vento = Sorte de drop (0,4%), Luz = Recrutamento (0,5%), Sombra = Crítico (+0,08 ponto). | Pedido: "mais vida, mais XP, mais drop". Dá motivo para caçar tipos diferentes (cada elemento fortalece um atributo) e um "próximo objetivo" a cada poucos minutos — os primeiros marcos chegam rápido (10 e 50 abates). |
| R17 | O **servidor conta os abates aceitos por forma** (`players.mastery`) e aplica ele mesmo os bônus de **ouro, drop e recrutamento** (o cliente só informa o ouro do equipamento). Os limites anti-trapaça de atributos também incluem os Marcos do servidor. O perfil devolve os Marcos (recupera progresso após reinstalar). | Economia continua autoritativa. |
| R18 | **Recalibragem**: com os Marcos, a simulação ficou ~11% mais rápida do 80 ao 300. `xp.late_slope` 0,022 → 0,026 devolve os tempos-alvo (80 ≈ 62 h, 210 ≈ 1.110 h, 300 ≈ 3.460 h). O início não mudou (nível 10 ≈ 20 min). Chefes dos Desafios ganharam +0,3% (nível 10) a +8% (nível 90) de Vida/Ataque, iguais aos Marcos típicos de cada faixa; o `challenge_sim` agora roda com esses bônus (tabela no relatório). | Pedido. |
| R19 | Na tela de caça, a faixa de **Marco** mostra a forma abatida por último: abates/próximo marco, bônus do próximo marco e bônus já conquistado; tocar abre todas as formas da hunt. Coleção mostra o total por atributo e o marco de cada forma. | Pedido. |
| R20 | **Troca rápida**: tocar num monstro do HUD da caça abre a lista do Depot (ordenada por Poder) e substitui aquele monstro na hora. O mesmo seletor é usado no Grupo. Bloqueado durante chefes. | Pedido. |
| R21 | **Ações em lote**: Altar troca vários monstros (seleção rápida "Todos sem shiny", "Qualidade < 40%/70%"; shiny pede confirmação extra) e Inventário vende vários itens ("Comuns", "Até Incomum", "Até Raro"; travados e equipados nunca entram). Endpoints `convert_monsters` (até 50) e `npc_sell_many` (até 100) no mock e na Edge Function. Marcar itens não reconstrói a tela (a rolagem não pula). | Pedido. |
| R22 | **Filtro por tipo** nas Hunts: barra com os 9 elementos + "Todos". | Pedido. |
| R23 | **Movimento liso**: a simulação continua em passo fixo de 50 ms, mas o desenho interpola entre os dois últimos passos (60 fps) e o tempo que "sobra" ao terminar um tile é usado no próximo (sem micro-paradas). A câmera segue a posição interpolada. | Corrige "andar lagado". |
| R24 | **Avisos e janelas no centro**: o bug era do Godot 4 — `set_anchors_preset` chamado depois de o nó entrar na árvore mantém o tamanho atual (zero), então diálogos e avisos ficavam presos no canto. Agora tudo usa `set_anchors_and_offsets_preset`; avisos ficam no centro da tela (posicionados a cada quadro). | Pedido ("mensagens desalinhadas"). |
| R25 | **Ícones novos**: 50 ícones vetoriais com contorno, sombreamento e sombra, gerados por `tools/gen_icons.py` em 64 px (com mipmaps) — inclui os 9 elementos e os ícones dos atributos dos Marcos. | "Ícones mais refinados". |
| R26 | **Hub**: cenário panorâmico mais baixo e os monstros do grupo grandes, animados, com nome e nível; ícones dos atalhos maiores. | "Personagens pequenos, fundo grande". |
| R27 | **Desafios**: botão Lutar numa linha própria dentro do card; textos quebram linha. | O botão saía da tela com textos longos. |


## Revisão 4 (identidade visual definitiva, usos do ouro, tutorial)

| # | Decisão | Por quê |
|---|---|---|
| R28 | **Arte final dos 135 monstros (+ shiny)** gerada em duas etapas: `tools/export_raw_sprites.gd` desenha as folhas "cruas" e `tools/shade_sprites.py` (numpy) aplica luz volumétrica de cima/esquerda em degraus (estilo pixel art), sombras puxando para o frio/roxo, luzes quentes, rim light no topo e **contorno seletivo colorido** (escuro da própria cor, mais forte embaixo). Resultado em `assets/sprites/monsters/` (5 MB), carregado direto pelo jogo. | Mesmo traço e mesma luz em todos os monstros = identidade; sai do visual "chapado com contorno preto". |
| R29 | **Mapas**: atlas novo por bioma com 8 variações de chão texturizado (ruído), trilhas de segundo piso e **transições orgânicas por cantos** (marching squares) para a "massa" de cada bioma — água com espuma na margem, lava com crosta, céu com borda de nuvem, rocha/gelo/mata com contorno, topo iluminado, face de penhasco e sombra projetada; muralhas de tijolo nas ruínas, templo e cemitério. | Fim do "tabuleiro quadriculado"; cada bioma tem leitura própria. |
| R30 | **Objetos com altura** (árvores, rochas, cristais, colunas, lápides, corais) como sprites em pé com sombra, ordenados por profundidade com os monstros (passam atrás/na frente). Obstáculos isolados sempre têm um objeto, então nada bloqueia "invisível". | Profundidade e clareza de onde dá para andar. |
| R31 | **Clima por bioma**: partículas (brasas, neve, pétalas, folhas, vagalumes, esporos, faíscas, bolhas, poeira, penas, brilhos, espíritos), luz ambiente por bioma (cavernas e florestas sombrias mais escuras, vulcões quentes, Mundo 2 arroxeado) e vinheta nas bordas. Barras de vida com moldura e brilho; o principal tem borda dourada. | "Vida" no mapa sem custo de jogabilidade. |
| R32 | **Loja rotativa**: 5 ofertas por jogador, novas a cada 6 h (período global), itens perto do nível validado, raridade por peso (Comum 38, Incomum 32, Raro 20, Épico 8, Lendário 2). Preço = ouro de N abates no nível do item: Comum 60, Incomum 160, **Raro 1.400, Épico 5.000, Lendário 20.000** (≈1,5 h / 5 h / 20 h de caça). Itens vinculados (não vão ao Market). Trocar as ofertas custa 150 abates de ouro ×1,6 a cada troca no período. Servidor guarda e cobra (`players.shop`). | Pedido: "5 itens rotativos, raros bem caros" — grande destino do ouro sem inflacionar o Market. |
| R33 | **Treino de monstros** com ouro: até +15; cada nível +4% Ataque e Defesa e +2% Vida (+60%/+30% no máximo). Custo = ouro de 40 abates no nível validado do principal × 1,42^nível (≈ 18 h de ouro do +0 ao +15 no nível 80). **Brilho**: +5 aura da cor do tipo, +10 aura intensa com faíscas, +15 radiante dourado — no mapa e nos retratos. O servidor registra (`monsters.train`) e inclui o treino nos limites anti-trapaça. | Pedido: "aprimorar monstros… ganha um brilho, entre normal e shiny". O custo usa o nível da conta para não valer a pena treinar monstro de nível 1. |
| R34 | **Tutorial** de 6 passos na primeira caçada, destacando cada área (mapa, grupo, Marcos, feed, navegação, offline), com "Pular". **Dica única** na primeira visita a cada área do Hub (13 telas). Ambos podem ser revistos em Ajustes. | Pedido. |


## Revisão 5 (diamantes, bônus, Market de monstros, tutorial com shiny, Altar claro)

| # | Decisão | Por quê |
|---|---|---|
| R35 | **Diamantes**: moeda premium que só entra por compra com dinheiro real (ou vendendo monstros a outros jogadores). Não viram ouro nem dinheiro. Pacotes (`data/iap.json`): 500 (4,99), 1.000+100 (9,99), 2.000+300 (19,99), 3.000+600 (29,99), 5.000+1.500 (49,99), 10.000+4.000 (99,99); **primeira compra em dobro**. | Pedido; ids prontos para cadastrar no Play Console. |
| R36 | Compras via **Google Play Billing** (autoload `Billing`, produtos consumíveis). O app só consome a compra depois que o servidor credita. A Edge Function **valida o token na API do Google Play** (conta de serviço) e grava o token em `iap_purchases` (um token = um crédito). Sem plugin, compra **simulada** aceita só pelo mock (ou pela Edge Function com `IAP_TEST_MODE=1`). | Segurança: diamantes nunca são criados pelo cliente. |
| R37 | **Bônus** (2x XP, 2x shiny, 2x recrutamento, 2x drop, 2x ouro): **8 h por diamantes** (120/200/150/150/100; pacote com os 5 por 550) ou **15 min por anúncio premiado** (acumula até 2 h restantes). O servidor guarda (`players.boosts`) e aplica shiny/recrutamento/drop/ouro; offline aplica na proporção do tempo em que o bônus estava ativo. O antigo "2x XP por 30 min" virou o bônus de XP (15 min por anúncio). | Pedido. |
| R38 | **Monstros no Market só por diamantes** (taxa 10%, 10–1.000.000 💎). O monstro sai do jogador (dono nulo) até ser vendido/cancelado e chega com nível (limitado ao validado + 10), qualidade, estrelas, treino e shiny. O inicial não pode ser vendido. Itens e Essências continuam por ouro. | Pedido; diamantes circulam entre jogadores sem criar diamantes do nada. |
| R39 | **Tutorial com shiny**: um shiny de demonstração aparece ao lado do grupo; ninguém o ataca, ele não luta, não gera ticket, recompensa nem recrutamento e some ao fim do tutorial. Texto avisa (com humor) que ele não pode ser recrutado. | Pedido; impossível de explorar. |
| R40 | **Ganhos sempre visíveis**: Altar mostra "Ganho: Defesa 48 → 55 (+7)" antes de aprimorar e um resumo depois (e quem está usando o item); falha explica que nada se perdeu além do custo. Card "Para que serve a Essência?". Estrela e Treino mostram antes → depois de HP/Ataque/Defesa. | "Fiz upgrade e não sei o que melhorou." |


## Revisão 6 (três mundos, Chefes de Mundo, mais monstros por mapa, câmera, tela inicial)

| # | Decisão | Por quê |
|---|---|---|
| R41 | **Bug do Desafio 20** ("tempo de vitória implausível"): o servidor exigia no mínimo 15 s. Agora o mínimo é calculado: vida do chefe ÷ dano máximo possível do grupo informado (atributos limitados pelo servidor, vantagem de tipo e crítico sempre), entre 0,5 s e 15 s. Um time nível 300 vence o Desafio 20 em 1 s sem ser recusado; um time no nível do desafio não. | Pedido (bug). |
| R42 | **Três mundos**: Mundo 1 = níveis 1 a 110, 1 monstro em campo (hunts originais até o 79 + **Fronteira** 80–105 gerada, liberada pelos Desafios 80/90, com recrutamento). **Mundo 2 (Abismo)** = 110 a 200, 2 monstros em campo. **Mundo 3 (Reino Astral)** = 210 a 300, 3 monstros, inimigos um pouco mais fortes (rampa a partir do Mundo 2), drops e ouro maiores, visual azul-estrelado próprio. Todas as hunts geradas vêm de `config.world1x/world2/world3`. | Pedido. |
| R43 | **Chefes de Mundo**: Gorilamonte (110, libera o Mundo 2, exige 2 monstros em campo) e Krakenoite (210, libera o Mundo 3, exige 3). Não são recrutáveis. Calibrados com o combate real: grupo completo de monstros comuns (qualidade 20, sem treino) no nível vence em ~50–75% das tentativas; grupo com um monstro fraco quase nunca vence. Os Desafios 10–90 continuam liberando os blocos de hunts. | "Prova de força do mundo": precisa de quantidade de monstros upados, não de qualidade. |
| R44 | **Mais monstros selvagens com mais monstros em campo**: densidade × 1,45 com 2 em campo e × 1,9 com 3 (além da densidade maior dos Mundos 2 e 3). O mesmo fator entra no modelo de abates/hora (offline e anti-trapaça, GDScript e Edge Function). Com isso o fim de jogo ficou mais rápido; `xp.late_slope` 0,026 → 0,034 devolve o 210 a ~1.115 h (o 300 ficou em ~3.050 h). | Pedido. |
| R45 | **Câmera**: com 2+ monstros em campo aparece o botão de câmera no mapa; cada toque passa para o próximo monstro vivo (o nome dele fica dourado no HUD). Se o seguido cair, a câmera vai para outro e volta quando ele renascer. | Pedido. |
| R46 | **Tela inicial nova**: cena noturna em tela cheia (céu estrelado, lua com halo, montanhas em camadas, vila, torre do altar, colina), vagalumes, logo grande com contorno e sombra flutuando, os 9 iniciais desfilando na colina com animação de caminhada (um deles shiny), botão Jogar pulsando e idiomas embaixo. | "A tela inicial precisa melhorar drasticamente." |

## Revisão 7 (abas do Mundo 1, Sem anúncios)
- As abas do Mundo 1 são calculadas pelo nível da hunt na tela (não mudam os dados): ≤40 Iniciante, ≤70 Intermediário, resto Avançado. A Fronteira (80–105) entra em Avançado, pois leva ao Chefe de Mundo do 110. As hunts "mistas" caem na faixa do seu nível.
- "Sem anúncios" remove só os interstitials (os únicos anúncios forçados). O banner fica, como pedido, e os premiados continuam como escolha do jogador para ganhar bônus de 15 min.
- É um direito permanente da conta no servidor (`no_ads`), não um item local: vale em qualquer aparelho com a mesma conta. Não conta como "primeira compra" para não queimar o dobro de diamantes.

## Revisão 9
- Nenhum anúncio forçado além do banner: todo vídeo é escolha do jogador em troca de recompensa. O "Sem anúncios" foi ocultado com `hidden: true` em vez de apagado, para poder voltar com outra função sem mexer no servidor.

## Revisão 10
- O Passe VIP reaproveita o produto não consumível do antigo "Sem anúncios" (a migration ainda não tinha ido para produção, então foi renomeada para `vip`). O limite de 120 min acumulados por bônus vale também para o VIP, para não quebrar o valor dos bônus de 8 h por diamantes.
- O status da caça fica só no cliente (é informativo) e mede tempo de jogo com o mapa aberto, para a média por hora refletir a hunt de verdade.

## Revisão 12
- Shiny por tempo, não por abate: como os Mundos 2 e 3 matam 2–3× mais por hora, a chance por monstro é dividida por mundo para manter ~1 shiny a cada 7–8 min em todo o jogo.
- Com 40× mais encontros, o multiplicador de recrutamento de shiny caiu de 10× para 3×; sem isso viriam ~4 shinies recrutados por dia de jogo ativo e eles perderiam valor (inclusive no Market por diamantes).
