# Progresso

Legenda: [x] concluído · [~] concluído com fallback (ver PENDENCIAS.md)

## Fase 1 — Núcleo visual e de combate
- [x] Mapa em tiles 32x32 (TileMapLayer) com tilesets gerados por bioma
- [x] Câmera seguindo o monstro principal, zoom ajustável (botões, roda, pinça)
- [x] IA de caça com AStarGrid2D (alvo mais próximo, perseguição, desvio de criaturas)
- [x] Spawns/respawn por hunt, selvagens com aggro e coleira
- [x] Ataque básico (corpo a corpo / projétil) + habilidades automáticas com recarga, efeito e área
- [x] Barras de HP, números de dano coloridos, efeitos pixel art, corpos no chão, loot automático com efeito
- [x] XP, nível, evolução (16/35 configurável por família), save local

## Fase 2 — Grupo e progressão
- [x] Grupo de 3, XP compartilhada (100% em campo / 50% reserva), desbloqueios 110 e 210
- [x] Comportamento da IA (focar / espalhar)
- [x] Revive após 5 s; sugestão de hunt mais fácil após derrotas repetidas
- [x] Progresso offline (taxa de abates calculada, limite 8 h, resumo)
- [x] Hub ilustrado e Depot (monstros e itens)

## Fase 3 — Conteúdo do Mundo 1
- [x] 9 tipos com ciclo configurável; 28 biomas (19 + 9 de transição)
- [x] 45 famílias / 135 formas com nomes, descrições, atributos, estilos e habilidades
- [x] 144 hunts do Mundo 1 (todas as formas até o 80), liberações nos níveis 1/6/12
- [x] Desafios 10–80 (e 90) com fases, invocações e áreas de dano
- [x] Recrutamento (0,2%), shiny (1/5000) e Coleção com marcos

## Fase 4 — Itens e Essência
- [x] 6 raridades, 4 slots, 324 bases (9 tiers x 9 tipos x 4 slots), afixos a partir de Épico
- [x] Inventário com limite expansível, venda NPC, trava, auto-venda; Loja NPC
- [x] Altar: troca por Essência (confirmação dupla para shiny), Estrelas 1–5, aprimoramento +1..+10

## Fase 5 — Online
- [x] Camada de serviço única (BackendService) com Mock e Supabase
- [x] Login anônimo, vincular Google, save na nuvem com sync periódico
- [x] Sorteios no servidor (Raro+, shiny por ticket, recrutamento), validação de XP/tempo
- [x] Rankings (nível, coleção, shinies, estrelas, tempo de desafios) global e semanal
- [~] Migrations SQL + RLS + Edge Function prontas para deploy (precisa de projeto Supabase)

## Fase 6 — Market
- [x] Listagem por ouro, taxa 5%, filtros, limite de listagens, cancelamento, Essência negociável
- [x] Transações atômicas (funções Postgres) e mock com vendedores/compradores fictícios

## Fase 7 — AdMob
- [~] Banner, rewarded (2x XP, dobrar offline, reviver), intersticial com limite, UMP — adaptador para o plugin Poing; modo simulado sem o plugin

## Fase 8 — Mundo 2, simulação e entrega
- [x] Mundo 2 (90–300) gerado por config, biomas corrompidos, mapas 64x64, sem recrutamento, drops exclusivos
- [x] Desafio 90 e estrutura para desafios futuros
- [x] Simulação de balanceamento 1→300 (docs/RELATORIO_BALANCEAMENTO.md) e calibração dos desafios com combate real
- [x] Menu de debug (nível, tempo x10/x100, forçar drop/shiny/recrutamento, spawn, bioma, ouro/Essência, desbloquear tudo, offline)
- [x] Testes unitários (4.755 asserções), smoke test de integração, paridade GDScript x TypeScript
- [x] APK debug gerado: dist/bestiario-idle-debug.apk
- [x] README, DECISOES, PENDENCIAS, RESUMO

## Revisão 2 — melhorias pedidas
- [x] Rolagem por toque nas listas (hunts e demais telas)
- [x] Monstros em campo acompanham o nível (bug do nível 200 com 2 ativos e 1 no mapa)
- [x] 45 famílias novas animal + elemento, nomes carismáticos, sprites com traços e acento do elemento
- [x] Qualidade 0–100% (até +30%) sorteada no servidor; shiny capturável, +50%, qualidade 50–100%
- [x] Notificações centralizadas e alinhadas; telas refinadas (molduras, ícones, chips, cards)
- [x] PT-BR, EN e ES com Market único
- [x] Drops reduzidos; início acelerado até o nível 10–15
- [x] Chefe Diário com 3 entradas (servidor mock + Edge Function + SQL)
- [x] Revezamento do time; caídos ganham XP como participantes; time renasce junto
- [x] "Ficar" no aviso de hunt difícil silencia por 60 s
- [x] Testes (7.275 asserções), smoke test, paridade GDScript x TypeScript, desafios recalibrados, APK

## Revisão 3 — segundo pedido de melhorias
- [x] Troca rápida tocando no monstro do HUD da caça
- [x] Mensagens, avisos e diálogos centralizados (bug de âncoras corrigido em todo o projeto)
- [x] Filtro por tipo na lista de hunts
- [x] Andar sem "lag" (interpolação + sem micro-paradas)
- [x] Troca de monstros em lote (Altar) e venda de itens em lote (Inventário), com endpoints no servidor
- [x] Botão "Lutar" dos Desafios sempre visível
- [x] 50 ícones novos refinados; Hub com monstros grandes e cenário menor
- [x] Marcos de Caça (6 marcos por forma, bônus por tipo) na hunt e na Coleção, contados no servidor (mock + Edge Function + migration)
- [x] Recalibragem (curva final e chefes) com simulação e combate real
- [x] Testes (7.316 asserções), smoke test, paridade GDScript × TypeScript, screenshots PT/EN/ES, APK

## Revisão 4 — visual definitivo, ouro e tutorial
- [x] Arte final dos 135 monstros + shiny (luz volumétrica, contorno colorido)
- [x] Mapas: chão texturizado, trilhas, transições orgânicas (água, lava, céu, rocha, mata, muralhas), objetos com altura e sombra
- [x] Clima por bioma (partículas), luz ambiente, vinheta, barras de vida novas
- [x] Loja rotativa de 5 itens (raros muito caros) com troca paga
- [x] Treino de monstros com ouro, com brilho em +5/+10/+15
- [x] Tutorial inicial e dica única por área do Hub
- [x] Mock + Edge Function + migration 20261024000005, testes (7.367 asserções), paridade, traduções, screenshots, APK

## Revisão 5 — diamantes e bônus
- [x] Diamantes (só dinheiro real), 6 pacotes, primeira compra em dobro, Billing com modo simulado e validação no servidor
- [x] Bônus 2x XP/shiny/recrutamento/drop/ouro: 8 h por diamantes ou 15 min por anúncio
- [x] Monstros no Market só por diamantes
- [x] Tutorial com shiny de demonstração não recrutável
- [x] Altar e telas de evolução mostram antes → depois
- [x] Mock + Edge Function + migration 20261025000006, testes (7.412 asserções), smoke, paridade, traduções, screenshots, APK

## Revisão 6 — mundos e Chefes de Mundo
- [x] Bug do Desafio 20 (vitória rápida de time forte recusada)
- [x] Mundo 1 até o 110 (Fronteira 80–105), Mundo 2 110–200, Mundo 3 (Reino Astral) 210–300
- [x] Chefes de Mundo no 110 e no 210 (não recrutáveis), calibrados para exigir 2 e 3 monstros
- [x] Mais monstros selvagens com 2/3 em campo (mundo e modelo de abates)
- [x] Botão de câmera para acompanhar outro monstro
- [x] Tela inicial redesenhada
- [x] Recalibragem (late_slope 0,034), testes (7.511 asserções), smoke, paridade, traduções, screenshots, APK

## Revisão 7 — abas do Mundo 1 e "Sem anúncios"
- Mundo 1 com só 3 abas por faixa de nível: **Iniciante** (até 40), **Intermediário** (até 70) e **Avançado** (até 110, inclui a Fronteira). Mundos 2 e 3 sem mudança.
- Produto **Sem anúncios** (US$ 4,99, não consumível): remove os anúncios em tela cheia; o banner continua e os anúncios premiados seguem opcionais. Card no topo da loja de Diamantes, com selo "Ativo" após a compra.
- Servidor (mock + Edge Function) grava `players.no_ads` e devolve no `wallet`; migration `20261026000007_no_ads.sql`. Não gasta o bônus de primeira compra de diamantes.
- Testes: abas por nível e compra do Sem anúncios.

## Revisão 8 — equipamentos, qualidade no Hub e ficha do jogo
- Tela do monstro: a lista de itens abre logo abaixo do slot escolhido (amuleto, garra, armadura, relíquia) e a tela não pula mais para o topo ao trocar/equipar/tirar.
- Hub: qualidade do monstro (ex.: "Qualidade 74% Ótimo", na cor da faixa) embaixo do nome e nível.
- `docs/FICHA_DO_JOGO.md`: resumo do jogo, retenção, produtos e AdMob para o artefato de jogos.

## Revisão 9 — sem anúncio em tela cheia
- Removido o interstitial ao abrir o Hub (foco em retenção). Ficam o banner e os premiados opcionais (bônus de 15 min, dobrar offline, reviver).
- Produto "Sem anúncios" oculto da loja (não teria mais efeito); servidor e cliente continuam prontos caso ele volte.

## Revisão 10 — Passe VIP e status da caça
- **Passe VIP** (`vip_pass`, US$ 4,99, não consumível): recompensas dos anúncios premiados sem assistir o vídeo (bônus de 15 min, dobrar offline, reviver). Banner continua. Substitui o "Sem anúncios" (servidor grava `players.vip`; migration `20261026000007_vip_pass.sql`).
- **Status da caça**: botão com ícone de gráfico na tela de caça abre um painel ao vivo com tempo, monstros caçados (e por hora), XP, ouro, itens dropados (por raridade), shinies encontrados e monstros recrutados. Zera ao trocar de hunt; não conta o ganho offline.
- Novos ícones `stats` e `vip`.
