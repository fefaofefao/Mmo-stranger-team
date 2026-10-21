# Relatório de balanceamento (simulação 1 → 300)

Gerado por `tools/balance_sim.gd` com o modelo analítico `KillRate` (o mesmo do progresso offline e do servidor). 
O smoke test compara esse modelo com o combate real em tempo real (diferença típica < 10%).

**Premissas do jogador simulado:** escolhe sempre a hunt liberada com mais XP/h que não seja perigosa; 
vence cada Desafio ao atingir nível do desafio + 3; recruta 2 monstros extras (após ~500 e ~1000 abates); 
equipamento do tier do nível (Incomum até 40, Raro até 110, Épico até 210, Lendário depois) com aprimoramento crescente; 
estrelas no principal a cada 30 níveis (máx. 5). Sem boost de 2x XP.


## Inicial: Brasito

| Nível | Horas acumuladas | Hunt escolhida | Abates/h | XP/h | Em campo |
|---|---|---|---|---|---|
| 5 | 8min | Colina Azulada (Nv 3) | 889 | 15.1k | 1 |
| 10 | 44min | Planície Selvagem (Nv 7) | 893 | 49.2k | 1 |
| 16 | 1.7h | Planície Sombria (Nv 15) | 978 | 150.7k | 1 |
| 20 | 2.6h | Galeria Dourada (Nv 20) | 942 | 215.0k | 1 |
| 30 | 6.3h | Caverna Eterna (Nv 28) | 920 | 330.6k | 1 |
| 35 | 9.2h | Morena Alta (Nv 32) | 1089 | 468.3k | 1 |
| 50 | 20.5h | Campina Rasa (Nv 46) | 1074 | 754.3k | 1 |
| 60 | 31.5h | Caverna Perdida (Nv 55) | 1169 | 1.05M | 1 |
| 80 | 63.3h | Gruta Antiga (Nv 73) | 1158 | 1.52M | 1 |
| 90 | 88.4h | Necrópole Selvagem (Nv 79) | 1102 | 1.61M | 1 |
| 100 | 117.1h | Abismo · Deserto de Cinzas III (Nv 90) | 1339 | 2.33M | 1 |
| 110 | 159.2h | Abismo · Ruínas Energizadas III (Nv 100) | 1293 | 2.59M | 1 |
| 130 | 244.8h | Abismo · Deserto de Cinzas III (Nv 130) | 1690 | 4.83M | 2 |
| 150 | 375.6h | Abismo · Cordilheira Ventosa I (Nv 150) | 1729 | 5.99M | 2 |
| 180 | 666.7h | Abismo · Geleira Rochosa II (Nv 180) | 1804 | 8.00M | 2 |
| 210 | 1124.5h | Abismo · Cordilheira Ventosa I (Nv 210) | 1839 | 10.04M | 2 |
| 240 | 1673.1h | Abismo · Vulcão I (Nv 240) | 2248 | 14.70M | 3 |
| 270 | 2430.1h | Abismo · Picos Montanhosos II (Nv 270) | 2256 | 17.29M | 3 |
| 300 | 3435.1h | Abismo · Planalto da Tempestade III (Nv 300) | 2309 | 20.40M | 3 |

## Inicial: Gotelo

| Nível | Horas acumuladas | Hunt escolhida | Abates/h | XP/h | Em campo |
|---|---|---|---|---|---|
| 5 | 21min | Pico Dourada (Nv 1) | 909 | 3636 | 1 |
| 10 | 1.0h | Chaminé Velha (Nv 8) | 940 | 62.1k | 1 |
| 16 | 2.3h | Templo Esquecida (Nv 10) | 914 | 81.4k | 1 |
| 20 | 3.5h | Ruína Eterna (Nv 15) | 966 | 148.8k | 1 |
| 30 | 7.7h | Encosta Rasa (Nv 27) | 923 | 315.7k | 1 |
| 35 | 10.9h | Planície Brilhante (Nv 31) | 918 | 378.3k | 1 |
| 50 | 23.2h | Fenda Tranquila (Nv 45) | 1117 | 762.0k | 1 |
| 60 | 35.0h | Chaminé Selvagem (Nv 54) | 1097 | 957.1k | 1 |
| 80 | 70.7h | Cratera Baixa (Nv 72) | 1014 | 1.30M | 1 |
| 90 | 100.9h | Planalto Estreita (Nv 76) | 1027 | 1.25M | 1 |
| 100 | 133.5h | Abismo · Deserto de Cinzas III (Nv 90) | 1374 | 2.39M | 1 |
| 110 | 186.8h | Abismo · Deserto de Cinzas III (Nv 90) | 1408 | 1.57M | 1 |
| 130 | 274.3h | Abismo · Deserto de Cinzas III (Nv 130) | 1688 | 4.82M | 2 |
| 150 | 405.7h | Abismo · Cordilheira Ventosa I (Nv 150) | 1707 | 5.92M | 2 |
| 180 | 701.0h | Abismo · Geleira Rochosa II (Nv 180) | 1788 | 7.93M | 2 |
| 210 | 1166.7h | Abismo · Cordilheira Ventosa I (Nv 210) | 1819 | 9.93M | 2 |
| 240 | 1720.0h | Abismo · Vulcão I (Nv 240) | 2244 | 14.67M | 3 |
| 270 | 2482.6h | Abismo · Picos Montanhosos II (Nv 270) | 2246 | 17.21M | 3 |
| 300 | 3497.5h | Abismo · Planalto da Tempestade III (Nv 300) | 2278 | 20.13M | 3 |

## Inicial: Lumito

| Nível | Horas acumuladas | Hunt escolhida | Abates/h | XP/h | Em campo |
|---|---|---|---|---|---|
| 5 | 20min | Baía Profunda (Nv 1) | 938 | 3754 | 1 |
| 10 | 1.8h | Colina Azulada (Nv 3) | 966 | 16.4k | 1 |
| 16 | 3.3h | Bosque Sussurrante (Nv 15) | 1006 | 155.0k | 1 |
| 20 | 4.3h | Bosque Sussurrante (Nv 15) | 1099 | 169.4k | 1 |
| 30 | 8.7h | Floresta Rubra (Nv 26) | 1066 | 346.7k | 1 |
| 35 | 11.4h | Bosque Dourada (Nv 34) | 1076 | 502.9k | 1 |
| 50 | 24.5h | Necrópole Distante (Nv 43) | 1085 | 696.1k | 1 |
| 60 | 36.6h | Bosque Velha (Nv 52) | 1180 | 979.0k | 1 |
| 80 | 67.6h | Necrópole Selvagem (Nv 79) | 1168 | 1.70M | 1 |
| 90 | 90.5h | Necrópole Selvagem (Nv 79) | 1205 | 1.76M | 1 |
| 100 | 123.8h | Abismo · Fontes Termais I (Nv 90) | 1417 | 2.46M | 1 |
| 110 | 175.5h | Abismo · Fontes Termais I (Nv 90) | 1451 | 1.61M | 1 |
| 130 | 260.6h | Abismo · Tempestade Luminosa II (Nv 130) | 1706 | 4.87M | 2 |
| 150 | 390.5h | Abismo · Cordilheira Ventosa I (Nv 150) | 1718 | 5.95M | 2 |
| 180 | 682.0h | Abismo · Geleira Rochosa II (Nv 180) | 1813 | 8.04M | 2 |
| 210 | 1140.9h | Abismo · Cordilheira Ventosa I (Nv 210) | 1841 | 10.05M | 2 |
| 240 | 1687.3h | Abismo · Brejo Sombrio II (Nv 240) | 2272 | 14.85M | 3 |
| 270 | 2439.1h | Abismo · Picos Montanhosos II (Nv 270) | 2252 | 17.26M | 3 |
| 300 | 3446.1h | Abismo · Planalto da Tempestade III (Nv 300) | 2310 | 20.41M | 3 |

## Comparação entre iniciais (horas de jogo acumuladas)

| Nível | Brasito | Gotelo | Lumito |
|---|---|---|---|
| 5 | 8min | 21min | 20min |
| 10 | 44min | 1.0h | 1.8h |
| 16 | 1.7h | 2.3h | 3.3h |
| 20 | 2.6h | 3.5h | 4.3h |
| 30 | 6.3h | 7.7h | 8.7h |
| 35 | 9.2h | 10.9h | 11.4h |
| 50 | 20.5h | 23.2h | 24.5h |
| 60 | 31.5h | 35.0h | 36.6h |
| 80 | 63.3h | 70.7h | 67.6h |
| 90 | 88.4h | 100.9h | 90.5h |
| 100 | 117.1h | 133.5h | 123.8h |
| 110 | 159.2h | 186.8h | 175.5h |
| 130 | 244.8h | 274.3h | 260.6h |
| 150 | 375.6h | 405.7h | 390.5h |
| 180 | 666.7h | 701.0h | 682.0h |
| 210 | 1124.5h | 1166.7h | 1140.9h |
| 240 | 1673.1h | 1720.0h | 1687.3h |
| 270 | 2430.1h | 2482.6h | 2439.1h |
| 300 | 3435.1h | 3497.5h | 3446.1h |

## Tempo de calendário estimado (Brasito)

- **Casual**: 1h ativa + 1 sessão offline de 8h por dia ≈ 8.2h de caça/dia
- **Dedicado**: 3h ativas + 2 sessões offline de 8h por dia ≈ 17.4h de caça/dia

| Nível | Horas | Dias (casual) | Dias (dedicado) |
|---|---|---|---|
| 16 | 1.7h | 0 | 0 |
| 35 | 9.2h | 1 | 1 |
| 80 | 63.3h | 8 | 4 |
| 110 | 159.2h | 19 | 9 |
| 150 | 375.6h | 46 | 22 |
| 210 | 1124.5h | 137 | 65 |
| 250 | - | -0 | -0 |
| 300 | 3435.1h | 419 | 197 |

## Calibração dos Desafios (combate real, `tools/challenge_sim.gd`)

Inicial solo com equipamento Incomum do tier e estrelas = nível/25. 2 lutas por caso.

| Desafio | Nível | Inicial (relação de tipo) | Vitórias | Tempo médio |
|---|---|---|---|---|
| c10 | 13 | Breuzinho (vantagem) | 2/2 | 47s |
| c10 | 13 | Brotim (neutro) | 0/2 | - |
| c10 | 13 | Brasito (desvantagem) | 0/2 | - |
| c10 | 18 | Breuzinho (vantagem) | 2/2 | 25s |
| c10 | 18 | Brotim (neutro) | 2/2 | 42s |
| c10 | 18 | Brasito (desvantagem) | 2/2 | 54s |
| c20 | 23 | Gotelo (vantagem) | 2/2 | 58s |
| c20 | 23 | Seixinho (neutro) | 2/2 | 80s |
| c20 | 23 | Flocote (desvantagem) | 0/2 | - |
| c20 | 28 | Gotelo (vantagem) | 2/2 | 42s |
| c20 | 28 | Seixinho (neutro) | 2/2 | 56s |
| c20 | 28 | Flocote (desvantagem) | 2/2 | 71s |
| c30 | 33 | Flocote (vantagem) | 2/2 | 42s |
| c30 | 33 | Plumito (neutro) | 0/2 | - |
| c30 | 33 | Seixinho (desvantagem) | 0/2 | - |
| c30 | 38 | Flocote (vantagem) | 2/2 | 28s |
| c30 | 38 | Plumito (neutro) | 2/2 | 45s |
| c30 | 38 | Seixinho (desvantagem) | 2/2 | 80s |
| c40 | 43 | Brotim (vantagem) | 2/2 | 65s |
| c40 | 43 | Lumito (neutro) | 2/2 | 74s |
| c40 | 43 | Choquito (desvantagem) | 2/2 | 117s |
| c40 | 48 | Brotim (vantagem) | 2/2 | 57s |
| c40 | 48 | Lumito (neutro) | 2/2 | 67s |
| c40 | 48 | Choquito (desvantagem) | 1/2 | 106s |
| c50 | 53 | Brasito (vantagem) | 2/2 | 46s |
| c50 | 53 | Choquito (neutro) | 1/2 | 67s |
| c50 | 53 | Brotim (desvantagem) | 0/2 | - |
| c50 | 58 | Brasito (vantagem) | 2/2 | 42s |
| c50 | 58 | Choquito (neutro) | 2/2 | 62s |
| c50 | 58 | Brotim (desvantagem) | 0/2 | - |
| c60 | 63 | Seixinho (vantagem) | 2/2 | 67s |
| c60 | 63 | Breuzinho (neutro) | 1/2 | 82s |
| c60 | 63 | Plumito (desvantagem) | 0/2 | - |
| c60 | 68 | Seixinho (vantagem) | 2/2 | 61s |
| c60 | 68 | Breuzinho (neutro) | 1/2 | 75s |
| c60 | 68 | Plumito (desvantagem) | 0/2 | - |
| c70 | 73 | Choquito (vantagem) | 2/2 | 51s |
| c70 | 73 | Gotelo (neutro) | 2/2 | 92s |
| c70 | 73 | Lumito (desvantagem) | 0/2 | - |
| c70 | 78 | Choquito (vantagem) | 2/2 | 41s |
| c70 | 78 | Gotelo (neutro) | 2/2 | 72s |
| c70 | 78 | Lumito (desvantagem) | 0/2 | - |
| c80 | 83 | Plumito (vantagem) | 2/2 | 54s |
| c80 | 83 | Brasito (neutro) | 0/2 | - |
| c80 | 83 | Breuzinho (desvantagem) | 0/2 | - |
| c80 | 88 | Plumito (vantagem) | 2/2 | 50s |
| c80 | 88 | Brasito (neutro) | 2/2 | 69s |
| c80 | 88 | Breuzinho (desvantagem) | 0/2 | - |
| c90 | 93 | Lumito (vantagem) | 1/2 | 32s |
| c90 | 98 | Lumito (vantagem) | 2/2 | 30s |
| c90 | 98 | Flocote (neutro) | 1/2 | 46s |
| c90 | 98 | Gotelo (desvantagem) | 0/2 | - |
