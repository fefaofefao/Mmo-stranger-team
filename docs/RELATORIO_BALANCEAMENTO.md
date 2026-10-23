# Relatório de balanceamento (simulação 1 → 300)

Gerado por `tools/balance_sim.gd` com o modelo analítico `KillRate` (o mesmo do progresso offline e do servidor). 
O smoke test compara esse modelo com o combate real em tempo real (diferença típica < 10%).

**Premissas do jogador simulado:** escolhe sempre a hunt liberada com mais XP/h que não seja perigosa; 
vence cada Desafio ao atingir nível do desafio + 3; recruta 2 monstros extras (após ~500 e ~1000 abates); 
equipamento do tier do nível (Incomum até 40, Raro até 110, Épico até 210, Lendário depois) com aprimoramento crescente; 
estrelas no principal a cada 30 níveis (máx. 5). Sem boost de 2x XP. 
**Marcos de Caça** ligados: os abates de cada forma são contados e os bônus da conta (Vida, Ataque, Defesa, XP, Velocidade, Crítico...) entram nos atributos e na XP.


## Inicial: Fogarito

| Nível | Horas acumuladas | Hunt escolhida | Abates/h | XP/h | Em campo | Marcos | Vida/Ataque/Defesa/XP |
|---|---|---|---|---|---|---|---|
| 5 | 1min | Pradaria Antiga (Nv 3) | 890 | 15.1k | 1 | 0 | 0.0% / 0.0% / 0.0% / 0.0% |
| 10 | 21min | Pradaria Dourada (Nv 5) | 946 | 33.5k | 1 | 4 | 0.0% / 0.0% / 0.0% / 1.0% |
| 16 | 1.1h | Planura Escondida (Nv 15) | 1026 | 159.7k | 1 | 12 | 0.0% / 1.0% / 0.6% / 1.0% |
| 20 | 2.0h | Galeria Esquecida (Nv 20) | 947 | 218.3k | 1 | 18 | 0.0% / 1.0% / 3.0% / 1.0% |
| 30 | 5.6h | Galeria Escondida (Nv 28) | 1034 | 374.9k | 1 | 28 | 0.0% / 1.0% / 7.8% / 1.0% |
| 35 | 8.3h | Planura Antiga (Nv 32) | 1110 | 482.1k | 1 | 31 | 0.0% / 1.0% / 9.0% / 1.0% |
| 50 | 19.4h | Cidadela Alta (Nv 49) | 1009 | 780.0k | 1 | 42 | 0.0% / 1.0% / 15.0% / 1.0% |
| 60 | 31.3h | Caverna Distante (Nv 55) | 1015 | 917.1k | 1 | 52 | 0.0% / 1.0% / 17.7% / 1.0% |
| 80 | 61.4h | Caverna Azulada (Nv 73) | 1213 | 1.61M | 1 | 83 | 0.0% / 1.0% / 22.2% / 1.0% |
| 90 | 86.3h | Fronteira · Vale do Crepúsculo I (Nv 85) | 1060 | 1.72M | 1 | 100 | 0.0% / 1.0% / 23.1% / 1.0% |
| 100 | 120.5h | Fronteira · Floresta Densa II (Nv 100) | 1157 | 2.45M | 1 | 130 | 0.0% / 2.5% / 23.1% / 5.5% |
| 110 | 167.4h | Fronteira · Tempestade Luminosa II (Nv 105) | 1158 | 2.62M | 1 | 134 | 0.0% / 2.5% / 23.1% / 5.5% |
| 130 | 247.8h | Abismo · Deserto de Cinzas III (Nv 130) | 2142 | 6.68M | 2 | 169 | 3.0% / 4.8% / 23.1% / 9.2% |
| 150 | 370.6h | Abismo · Cordilheira Ventosa I (Nv 150) | 2155 | 8.16M | 2 | 199 | 3.0% / 8.5% / 23.1% / 9.2% |
| 180 | 660.3h | Abismo · Deserto de Cinzas III (Nv 180) | 2323 | 11.25M | 2 | 217 | 3.0% / 8.5% / 24.9% / 9.2% |
| 210 | 1124.1h | Abismo · Tempestade Luminosa II (Nv 200) | 2299 | 12.84M | 2 | 223 | 3.0% / 11.5% / 24.9% / 9.2% |
| 240 | 1586.8h | Astral · Tundra III (Nv 240) | 3539 | 25.27M | 3 | 253 | 9.0% / 11.5% / 24.9% / 9.2% |
| 270 | 2214.6h | Astral · Cordilheira Ventosa I (Nv 270) | 3554 | 29.76M | 3 | 262 | 9.0% / 11.5% / 27.6% / 9.2% |
| 300 | 3066.3h | Astral · Ruínas Energizadas III (Nv 300) | 3550 | 34.50M | 3 | 269 | 9.0% / 11.5% / 27.6% / 10.0% |

## Inicial: Marolinho

| Nível | Horas acumuladas | Hunt escolhida | Abates/h | XP/h | Em campo | Marcos | Vida/Ataque/Defesa/XP |
|---|---|---|---|---|---|---|---|
| 5 | 3min | Lagoa Dourada (Nv 2) | 898 | 8982 | 1 | 1 | 0.2% / 0.0% / 0.0% / 0.0% |
| 10 | 16min | Cratera Rubra (Nv 8) | 990 | 65.3k | 1 | 7 | 1.0% / 0.5% / 0.0% / 0.0% |
| 16 | 1.2h | Campina Bravia (Nv 12) | 932 | 106.4k | 1 | 11 | 1.0% / 1.8% / 0.0% / 0.0% |
| 20 | 2.2h | Planície Brilhante (Nv 16) | 987 | 166.0k | 1 | 16 | 1.0% / 1.8% / 0.6% / 0.0% |
| 30 | 6.1h | Chaminé Brilhante (Nv 27) | 997 | 341.1k | 1 | 30 | 1.0% / 6.8% / 0.6% / 0.0% |
| 35 | 8.9h | Fenda Serena (Nv 31) | 1128 | 464.9k | 1 | 38 | 1.0% / 8.2% / 0.6% / 0.0% |
| 50 | 20.4h | Planície Eterna (Nv 45) | 1174 | 800.9k | 1 | 52 | 1.0% / 12.5% / 0.6% / 0.0% |
| 60 | 31.2h | Encosta Perdida (Nv 54) | 1190 | 1.04M | 1 | 57 | 1.0% / 14.8% / 0.6% / 0.0% |
| 80 | 62.1h | Chaminé Bravia (Nv 72) | 1247 | 1.60M | 1 | 72 | 1.0% / 20.0% / 0.6% / 0.0% |
| 90 | 86.4h | Fronteira · Cordilheira Ventosa I (Nv 80) | 1201 | 1.78M | 1 | 87 | 1.0% / 20.8% / 0.6% / 0.0% |
| 100 | 119.3h | Fronteira · Floresta Densa II (Nv 100) | 1214 | 2.54M | 1 | 118 | 5.5% / 20.8% / 2.4% / 4.5% |
| 110 | 164.9h | Fronteira · Tempestade Luminosa II (Nv 105) | 1218 | 2.73M | 1 | 125 | 5.5% / 20.8% / 2.4% / 4.5% |
| 130 | 241.5h | Abismo · Deserto de Cinzas III (Nv 130) | 2265 | 7.00M | 2 | 162 | 7.0% / 20.8% / 2.4% / 8.2% |
| 150 | 360.1h | Abismo · Cordilheira Ventosa I (Nv 150) | 2229 | 8.36M | 2 | 189 | 7.0% / 20.8% / 2.4% / 8.2% |
| 180 | 643.7h | Abismo · Deserto de Cinzas III (Nv 180) | 2402 | 11.53M | 2 | 213 | 10.0% / 20.8% / 2.4% / 8.2% |
| 210 | 1096.7h | Abismo · Deserto de Cinzas III (Nv 200) | 2369 | 13.11M | 2 | 216 | 10.0% / 23.0% / 2.4% / 8.2% |
| 240 | 1552.4h | Astral · Cordilheira Ventosa I (Nv 240) | 3609 | 25.54M | 3 | 236 | 13.0% / 23.0% / 2.4% / 8.2% |
| 270 | 2175.3h | Astral · Cordilheira Ventosa I (Nv 270) | 3630 | 30.11M | 3 | 245 | 13.0% / 23.0% / 2.4% / 8.2% |
| 300 | 3014.2h | Astral · Cordilheira Ventosa I (Nv 300) | 3624 | 34.90M | 3 | 246 | 13.0% / 23.0% / 2.4% / 9.0% |

## Inicial: Potrilume

| Nível | Horas acumuladas | Hunt escolhida | Abates/h | XP/h | Em campo | Marcos | Vida/Ataque/Defesa/XP |
|---|---|---|---|---|---|---|---|
| 5 | 1min | Recife Dourado (Nv 3) | 878 | 14.9k | 1 | 0 | 0.0% / 0.0% / 0.0% / 0.0% |
| 10 | 20min | Pradaria Dourada (Nv 5) | 933 | 32.8k | 1 | 4 | 0.5% / 0.0% / 0.0% / 0.5% |
| 16 | 1.2h | Mata Silenciosa (Nv 15) | 980 | 151.8k | 1 | 11 | 0.5% / 0.5% / 0.0% / 0.5% |
| 20 | 2.1h | Floresta Bravia (Nv 19) | 925 | 197.2k | 1 | 13 | 0.5% / 0.5% / 0.0% / 0.5% |
| 30 | 5.7h | Necrópole Encantada (Nv 30) | 953 | 377.5k | 1 | 27 | 0.5% / 0.5% / 0.0% / 0.5% |
| 35 | 8.4h | Mata Azulada (Nv 34) | 1050 | 492.9k | 1 | 31 | 0.5% / 0.5% / 0.0% / 0.5% |
| 50 | 20.5h | Lodaçal Velho (Nv 42) | 1110 | 714.0k | 1 | 49 | 0.5% / 0.5% / 0.0% / 3.5% |
| 60 | 32.0h | Mata Brilhante (Nv 52) | 1170 | 1.00M | 1 | 55 | 0.5% / 0.5% / 0.0% / 3.5% |
| 80 | 62.0h | Cripta Larga (Nv 79) | 1146 | 1.73M | 1 | 71 | 0.5% / 0.5% / 0.0% / 3.5% |
| 90 | 85.4h | Fronteira · Vale do Crepúsculo I (Nv 85) | 1093 | 1.82M | 1 | 81 | 0.5% / 0.5% / 0.0% / 3.5% |
| 100 | 118.7h | Fronteira · Floresta Densa II (Nv 100) | 1141 | 2.44M | 1 | 100 | 0.5% / 2.8% / 0.0% / 6.5% |
| 110 | 162.3h | Fronteira · Floresta Sombria I (Nv 105) | 1215 | 2.81M | 1 | 110 | 3.5% / 2.8% / 0.0% / 8.0% |
| 130 | 241.9h | Abismo · Tempestade Luminosa II (Nv 130) | 2142 | 6.65M | 2 | 137 | 5.8% / 5.8% / 0.0% / 8.8% |
| 150 | 366.1h | Abismo · Cordilheira Ventosa I (Nv 150) | 2126 | 8.01M | 2 | 172 | 6.5% / 8.8% / 0.0% / 8.8% |
| 180 | 659.0h | Abismo · Deserto de Cinzas III (Nv 180) | 2316 | 11.17M | 2 | 185 | 6.5% / 8.8% / 0.0% / 8.8% |
| 210 | 1121.2h | Abismo · Vale do Crepúsculo I (Nv 200) | 2336 | 12.99M | 2 | 198 | 9.5% / 11.8% / 0.0% / 8.8% |
| 240 | 1585.7h | Astral · Tundra III (Nv 240) | 3520 | 25.02M | 3 | 237 | 9.5% / 11.8% / 7.2% / 8.8% |
| 270 | 2219.3h | Astral · Cordilheira Ventosa I (Nv 270) | 3529 | 29.41M | 3 | 261 | 9.5% / 11.8% / 14.4% / 8.8% |
| 300 | 3075.2h | Astral · Ruínas Energizadas III (Nv 300) | 3570 | 34.54M | 3 | 262 | 9.5% / 11.8% / 14.4% / 9.5% |

## Comparação entre iniciais (horas de jogo acumuladas)

| Nível | Fogarito | Marolinho | Potrilume |
|---|---|---|---|
| 5 | 1min | 3min | 1min |
| 10 | 21min | 16min | 20min |
| 16 | 1.1h | 1.2h | 1.2h |
| 20 | 2.0h | 2.2h | 2.1h |
| 30 | 5.6h | 6.1h | 5.7h |
| 35 | 8.3h | 8.9h | 8.4h |
| 50 | 19.4h | 20.4h | 20.5h |
| 60 | 31.3h | 31.2h | 32.0h |
| 80 | 61.4h | 62.1h | 62.0h |
| 90 | 86.3h | 86.4h | 85.4h |
| 100 | 120.5h | 119.3h | 118.7h |
| 110 | 167.4h | 164.9h | 162.3h |
| 130 | 247.8h | 241.5h | 241.9h |
| 150 | 370.6h | 360.1h | 366.1h |
| 180 | 660.3h | 643.7h | 659.0h |
| 210 | 1124.1h | 1096.7h | 1121.2h |
| 240 | 1586.8h | 1552.4h | 1585.7h |
| 270 | 2214.6h | 2175.3h | 2219.3h |
| 300 | 3066.3h | 3014.2h | 3075.2h |

## Tempo de calendário estimado (Fogarito)

- **Casual**: 1h ativa + 1 sessão offline de 8h por dia ≈ 8.2h de caça/dia
- **Dedicado**: 3h ativas + 2 sessões offline de 8h por dia ≈ 17.4h de caça/dia

| Nível | Horas | Dias (casual) | Dias (dedicado) |
|---|---|---|---|
| 16 | 1.1h | 0 | 0 |
| 35 | 8.3h | 1 | 0 |
| 80 | 61.4h | 7 | 4 |
| 110 | 167.4h | 20 | 10 |
| 150 | 370.6h | 45 | 21 |
| 210 | 1124.1h | 137 | 65 |
| 240 | 1586.8h | 194 | 91 |
| 300 | 3066.3h | 374 | 176 |

## Desafios e Chefes de Mundo com o combate real (tools/challenge_sim.gd)

Desafios: 1 monstro, bônus típicos de Marcos. Chefes de Mundo: grupo de 2 (nível 110) ou 3 (nível 210) monstros de qualidade 20, sem treino; 'um fraco' = um deles com 60% do nível. Meta: grupo completo vence na maioria das vezes; grupo com um monstro fraco quase nunca.

| Desafio | Nível do grupo | Grupo / inicial | Vitórias | Tempo médio |
|---|---|---|---|---|
| c10 | 13 | Breuzinho (vantagem) | 2/2 | 45s |
| c10 | 13 | Brotilho (neutro) | 0/2 | - |
| c10 | 13 | Fogarito (desvantagem) | 0/2 | - |
| c10 | 18 | Breuzinho (vantagem) | 2/2 | 24s |
| c10 | 18 | Brotilho (neutro) | 2/2 | 37s |
| c10 | 18 | Fogarito (desvantagem) | 2/2 | 51s |
| c20 | 23 | Marolinho (vantagem) | 2/2 | 55s |
| c20 | 23 | Tatuzito (neutro) | 2/2 | 65s |
| c20 | 23 | Picolino (desvantagem) | 0/2 | - |
| c20 | 28 | Marolinho (vantagem) | 2/2 | 39s |
| c20 | 28 | Tatuzito (neutro) | 2/2 | 48s |
| c20 | 28 | Picolino (desvantagem) | 2/2 | 73s |
| c30 | 33 | Picolino (vantagem) | 2/2 | 42s |
| c30 | 33 | Brisinho (neutro) | 0/2 | - |
| c30 | 33 | Tatuzito (desvantagem) | 0/2 | - |
| c30 | 38 | Picolino (vantagem) | 2/2 | 31s |
| c30 | 38 | Brisinho (neutro) | 2/2 | 42s |
| c30 | 38 | Tatuzito (desvantagem) | 2/2 | 63s |
| c40 | 43 | Brotilho (vantagem) | 2/2 | 49s |
| c40 | 43 | Potrilume (neutro) | 2/2 | 67s |
| c40 | 43 | Lãmpadinha (desvantagem) | 2/2 | 98s |
| c40 | 48 | Brotilho (vantagem) | 2/2 | 43s |
| c40 | 48 | Potrilume (neutro) | 2/2 | 62s |
| c40 | 48 | Lãmpadinha (desvantagem) | 1/2 | 88s |
| c50 | 53 | Fogarito (vantagem) | 2/2 | 47s |
| c50 | 53 | Lãmpadinha (neutro) | 1/2 | 68s |
| c50 | 53 | Brotilho (desvantagem) | 0/2 | - |
| c50 | 58 | Fogarito (vantagem) | 2/2 | 42s |
| c50 | 58 | Lãmpadinha (neutro) | 2/2 | 63s |
| c50 | 58 | Brotilho (desvantagem) | 0/2 | - |
| c60 | 63 | Tatuzito (vantagem) | 2/2 | 54s |
| c60 | 63 | Breuzinho (neutro) | 1/2 | 81s |
| c60 | 63 | Brisinho (desvantagem) | 0/2 | - |
| c60 | 68 | Tatuzito (vantagem) | 2/2 | 50s |
| c60 | 68 | Breuzinho (neutro) | 1/2 | 73s |
| c60 | 68 | Brisinho (desvantagem) | 0/2 | - |
| c70 | 73 | Lãmpadinha (vantagem) | 2/2 | 60s |
| c70 | 73 | Marolinho (neutro) | 1/2 | 82s |
| c70 | 73 | Potrilume (desvantagem) | 0/2 | - |
| c70 | 78 | Lãmpadinha (vantagem) | 2/2 | 46s |
| c70 | 78 | Marolinho (neutro) | 2/2 | 63s |
| c70 | 78 | Potrilume (desvantagem) | 0/2 | - |
| c80 | 83 | Brisinho (vantagem) | 2/2 | 35s |
| c80 | 83 | Fogarito (neutro) | 0/2 | - |
| c80 | 83 | Breuzinho (desvantagem) | 0/2 | - |
| c80 | 88 | Brisinho (vantagem) | 2/2 | 33s |
| c80 | 88 | Fogarito (neutro) | 2/2 | 49s |
| c80 | 88 | Breuzinho (desvantagem) | 0/2 | - |
| c90 | 93 | Potrilume (vantagem) | 2/2 | 32s |
| c90 | 93 | Picolino (neutro) | 2/2 | 58s |
| c90 | 93 | Marolinho (desvantagem) | 1/2 | 70s |
| c90 | 98 | Potrilume (vantagem) | 2/2 | 31s |
| c90 | 98 | Picolino (neutro) | 2/2 | 53s |
| c90 | 98 | Marolinho (desvantagem) | 0/2 | - |
| wb110 | 112 | 2 monstros (completo) | 2/4 | 57s |
| wb110 | 118 | 2 monstros (completo) | 3/4 | 59s |
| wb110 | 112 | 2 monstros (um fraco) | 0/4 | - |
| wb110 | 118 | 2 monstros (um fraco) | 0/4 | - |
| wb210 | 212 | 3 monstros (completo) | 1/4 | 48s |
| wb210 | 218 | 3 monstros (completo) | 3/4 | 56s |
| wb210 | 212 | 3 monstros (um fraco) | 0/4 | - |
| wb210 | 218 | 3 monstros (um fraco) | 0/4 | - |
