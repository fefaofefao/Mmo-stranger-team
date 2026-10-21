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
- **Atributos**: `base_família × (1 + 0,08·(nível−1)) × estágio[1; 1,35; 1,8] × (1 + 6%·estrelas) + itens`, shiny +5%. Velocidade não cresce por nível (só estágio, estrelas e itens); intervalo de ataque = 1,25 s × 100/VEL.
- **Inimigos** usam a mesma fórmula com modificadores (`enemy_mods`: HP 0,42, ATQ 0,55, DEF 0,7) para que o monstro do jogador mate em ~3-4 golpes e possa ser cercado. No Mundo 2 os modificadores sobem gradualmente (rampa de 30 níveis a partir do 90) para não criar um "muro" antes do nível 110.
- **IA do jogador**: sai de áreas de perigo → escolhe alvo (prioriza quem o ataca; "focar" segue o alvo do líder, "espalhar" penaliza alvos já escolhidos) → usa habilidades (cura <55% HP, área com ≥1-2 inimigos no raio, ataques no alvo) → ataca ou persegue com `AStarGrid2D` (diagonal sem cortar quinas; re-caminho a cada 0,45 s e desvio de criaturas quando bloqueado).
- **Selvagens**: vagam perto do spawn, *aggro* a 5 tiles, coleira de 12 tiles.
- **Regeneração** de 0,8% HP/s sempre ativa; monstro do jogador revive em 5 s (exceto em Desafios). 3 derrotas do grupo em 5 min → a UI sugere uma hunt mais fácil.
- **Corpos** ficam 6 s no chão; o loot "voa" até o monstro (coleta automática).

## Curva de XP e tempo de jogo

- Abates necessários por nível: `K(L) = 6 + 2,9·L^1,5 · (1 + 0,022·max(0, L−80))`
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

- Raridades e chances por abate: Comum 1/40, Incomum 1/160 (cliente, **vinculados**), Raro 1/200, Épico 1/2.000, Lendário 1/20.000, Mítico 1/250.000 (servidor).
- 4 slots: Amuleto (HP), Garra (ATQ), Armadura (DEF), Relíquia (VEL% + Crítico). 9 tiers (níveis 1, 12, 25, 40, 60, 80, 120, 170, 230), 1 tema por tipo (+15% no atributo principal se o monstro for do mesmo tipo). Afixos aleatórios a partir de Épico (1/2/3 para Épico/Lendário/Mítico).
- Aprimoramento +1..+10 (+8% por nível); +1..+5 sempre funciona; a partir do +6: 75%, 60%, 45%, 30%, 20%. **Nunca destrói.**
- Essência ao trocar monstro: `base_estágio[5; 15; 40] × (1 + nível/20) × mult_família × (1 + 0,2·estrelas) × (50 se shiny)`. Shiny pede confirmação dupla.
- Estrelas: custos 30/90/250/600/1500 Essência do tipo; +6% atributos cada; 3ª e 5ª: habilidades +25% poder e −10% recarga.
- Inventário 60 (+10 por expansão, custo crescente, máx. 300); Depot de itens 300. Itens negociáveis nunca se perdem por inventário cheio (vão para o Depot). Trava contra venda, confirmação para vender Raro+, auto-venda opcional de Comum/Incomum.
- Coleção: marcos de 100 / 1.000 / 10.000 abates por forma, cada um +0,1% ataque e +0,1% XP permanentes.

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
