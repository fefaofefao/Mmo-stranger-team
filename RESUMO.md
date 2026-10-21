# Resumo da entrega — Bestiário Idle

## O que foi feito
Um RPG idle completo para Android em **Godot 4.3**, todas as 8 fases da especificação:

- **Combate em mapa** (nada de "dois bonecos parados"): tiles 32x32 em pixel art, câmera seguindo o monstro, zoom, criaturas andando tile a tile em 4 direções, barras de HP, números de dano coloridos, efeitos de ataque/habilidade, corpos no chão e loot coletado automaticamente. IA 100% automática com AStarGrid2D; o jogador só decide estratégia (hunt, grupo, itens, estrelas e "focar/espalhar").
- **Conteúdo**: 9 tipos em ciclo, 45 famílias / 135 formas com nomes e descrições originais em PT-BR, 63 habilidades, 28 biomas (incluindo 9 de transição e versões corrompidas), 144 hunts no Mundo 1 + 66 no Mundo 2 (90→300, geradas por config), 9 Desafios com chefes, 324 bases de item com afixos.
- **Progressão**: grupo de 3 (2 lutando no 110, 3 no 210), offline de até 8 h, recrutamento, shiny, Coleção com marcos, Altar de Essências, Estrelas, aprimoramento +10, inventário/Depot/Loja NPC.
- **Online**: camada de serviço única com **mock local completo** (servidor, ranking e market com jogadores fictícios) e **Supabase real** (migrations, RLS, funções atômicas do market, Edge Function com todas as regras anti-trapaça).
- **Monetização**: banner fora do mapa, 3 rewarded opcionais, intersticial com limite de 5 min, consentimento UMP — com modo simulado quando o plugin não está instalado.
- **Qualidade**: 4.755 asserções em testes unitários, smoke test que joga de verdade (combate real bate com o modelo de abates/hora: ~600 vs ~615/h), paridade das fórmulas GDScript × TypeScript, simulação de balanceamento 1→300, calibração dos chefes com o combate real, screenshots automáticos (`docs/screenshots/`).

## APK
- Arquivo: **`dist/bestiario-idle-debug.apk`** (debug, assinado com keystore de debug, armeabi-v7a + arm64-v8a, ~47 MB).
- Instalar:
  1. No celular: *Configurações → Segurança → permitir instalar apps desconhecidos* (para o app que vai abrir o APK).
  2. Copie o APK para o celular e toque nele; **ou** com cabo e depuração USB: `adb install -r dist/bestiario-idle-debug.apk`.
- Testar: toque em **Jogar** → aceite o consentimento simulado → escolha um inicial → o monstro começa a caçar sozinho. Use **Hub** para todas as telas. Feche o app e volte depois de alguns minutos para ver o **resumo offline**.
- O APK usa o **servidor mock** (sem credenciais) e **anúncios simulados** (sem plugin AdMob). Tudo funciona offline.

## Menu de debug (só no APK debug)
Botão discreto **dbg** no canto inferior esquerdo (acima do painel de ações):
- **Nível do grupo**: 1, 10, 16, 35, 60, 80, 110, 150, 210, 300 ou +10 (testa evoluções e o 2º/3º monstro em campo).
- **Velocidade do tempo**: x1, x10, x100 (o combate roda mais passos; o servidor mock acompanha o relógio).
- **Simular 8h offline agora**.
- **Forçar**: próximo shiny, próximo recrutamento, próximo drop Raro/Épico/Lendário/Mítico, drop Incomum.
- **Recursos**: +100k ouro, +1000 de cada Essência; **desbloquear todas as hunts e desafios**; recrutar 3.
- **Spawnar monstros** (5 de uma vez, para testar ser cercado e desempenho).
- **Trocar bioma** do mapa atual (todos os 28 biomas).
- **Exportar spritesheets placeholder** (modelos PNG para o artista).

## Pendências (detalhes em PENDENCIAS.md)
1. Criar o projeto Supabase, aplicar migrations, publicar a Edge Function e preencher `data/backend.json`.
2. Deep link do login Google (intent-filter no build gradle).
3. Instalar o plugin AdMob (Poing), usar o preset gradle e colocar os IDs reais em `data/ads.json`; mensagem UMP no console.
4. SDK Android completo + keystore de release para gerar o AAB da Play Store (`target_sdk 35` já configurado no preset de release).
5. Arte final (pipeline pronto: PNG por forma/bioma, sem mexer em código).

## Ajustes de balanceamento sugeridos para você testar
Todos em `data/*.json` (sem recompilar nada; para o servidor real, rode `tools/export_server_data.gd` e faça o deploy da função).

1. **Ritmo do início** (`config.xp.kills_a`, hoje 2,9): nível 16 em ~2 h de caça. Se quiser a 1ª evolução na primeira sessão, teste 2,0.
2. **Mundo 1 → 80** (~65 h de caça ≈ 1 semana casual): para alongar/encurtar mexa em `kills_a`; para mexer só no endgame use `late_slope` (0,022).
3. **210 em ~1.150 h** (≈2 a 4,5 meses): ajuste `late_slope` (+0,005 ≈ +15% de tempo no endgame).
4. **Dificuldade das hunts**: `enemy_mods` (HP 0,42 / ATQ 0,55 / DEF 0,7). Se o monstro morrer demais nas hunts recomendadas, baixe ATQ para 0,5.
5. **Mundo 2**: `world2.enemy_mods` e `mods_ramp_levels` (30) controlam a transição 90→120; `world2.density` (30) e `respawn` (8 s) controlam o ritmo.
6. **Desafios**: `challenges.json` → `hp_mult`/`atk_mult` por chefe. O 50 e o 60 ficaram justos para tipos neutros; o 90 é propositalmente o mais difícil. Teste com `tools/challenge_sim.gd -- 50`.
7. **Drops**: Comum 1/40 pode lotar o inventário em sessões longas — teste 1/60 (`rarities[0].chance` = 0,0167) ou deixe a auto-venda ligada por padrão.
8. **Recrutamento** 0,2%: dá ~2 recrutas por hora de caça. Para colecionadores, 0,3%; para escassez, 0,1%.
9. **Essência/Estrelas**: a 5ª estrela (1.500) exige ~40 monstros adultos trocados; se ficar pesado, baixe para 1.000.
10. **Aprimoramento**: chances do +6 ao +10 (75/60/45/30/20%). Para um market mais aquecido, reduza o +9/+10.
11. **Offline**: eficiência 0,9 e limite 8 h (`offline`). Um limite de 12 h favorece quem joga 1x por dia.
12. **Anúncio 2x XP**: 30 min por anúncio, acumulável. Se monetizar pouco, teste 20 min; se incomodar, 60 min.
