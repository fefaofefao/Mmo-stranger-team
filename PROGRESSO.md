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
