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
| 90 | 86.5h | Cripta Larga (Nv 79) | 1099 | 1.62M | 1 | 89 | 0.0% / 1.0% / 23.1% / 1.0% |
| 100 | 113.8h | Abismo · Ruínas Energizadas III (Nv 100) | 1305 | 2.70M | 1 | 119 | 0.0% / 5.5% / 23.1% / 3.2% |
| 110 | 153.3h | Abismo · Ruínas Energizadas III (Nv 100) | 1344 | 2.78M | 1 | 123 | 0.0% / 5.5% / 24.0% / 3.2% |
| 130 | 237.4h | Abismo · Deserto de Cinzas III (Nv 130) | 1751 | 5.47M | 2 | 170 | 3.0% / 7.8% / 24.0% / 9.2% |
| 150 | 362.8h | Abismo · Cordilheira Ventosa I (Nv 150) | 1780 | 6.74M | 2 | 190 | 3.0% / 9.2% / 24.0% / 9.2% |
| 180 | 654.8h | Abismo · Deserto de Cinzas III (Nv 180) | 1891 | 9.16M | 2 | 207 | 3.0% / 9.2% / 25.8% / 9.2% |
| 210 | 1109.7h | Abismo · Cordilheira Ventosa I (Nv 210) | 1908 | 11.38M | 2 | 213 | 3.0% / 12.2% / 25.8% / 9.2% |
| 240 | 1660.0h | Abismo · Brejo Sombrio II (Nv 240) | 2309 | 16.49M | 3 | 232 | 3.0% / 13.0% / 27.6% / 9.2% |
| 270 | 2431.6h | Abismo · Picos Montanhosos II (Nv 270) | 2327 | 19.48M | 3 | 245 | 6.0% / 13.0% / 27.6% / 9.2% |
| 300 | 3463.4h | Abismo · Planalto da Tempestade III (Nv 300) | 2365 | 22.83M | 3 | 245 | 6.0% / 13.0% / 27.6% / 9.2% |

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
| 90 | 86.9h | Templo Alto (Nv 78) | 1166 | 1.61M | 1 | 84 | 1.0% / 20.8% / 0.6% / 0.0% |
| 100 | 113.0h | Abismo · Campo de Lava II (Nv 90) | 1496 | 2.66M | 1 | 95 | 1.0% / 21.5% / 0.6% / 2.2% |
| 110 | 163.8h | Abismo · Campo de Lava II (Nv 90) | 1526 | 1.75M | 1 | 98 | 1.0% / 22.2% / 0.6% / 3.0% |
| 130 | 244.2h | Abismo · Deserto de Cinzas III (Nv 130) | 1824 | 5.68M | 2 | 139 | 4.0% / 22.2% / 0.6% / 9.0% |
| 150 | 365.7h | Abismo · Cordilheira Ventosa I (Nv 150) | 1827 | 6.90M | 2 | 161 | 4.0% / 22.2% / 0.6% / 9.0% |
| 180 | 651.2h | Abismo · Deserto de Cinzas III (Nv 180) | 1943 | 9.39M | 2 | 188 | 7.0% / 22.2% / 0.6% / 9.0% |
| 210 | 1096.3h | Abismo · Cordilheira Ventosa I (Nv 210) | 1938 | 11.54M | 2 | 190 | 7.0% / 23.0% / 0.6% / 9.0% |
| 240 | 1643.1h | Abismo · Brejo Sombrio II (Nv 240) | 2332 | 16.62M | 3 | 216 | 7.0% / 23.0% / 4.2% / 9.0% |
| 270 | 2398.1h | Abismo · Picos Montanhosos II (Nv 270) | 2355 | 20.22M | 3 | 228 | 7.0% / 23.0% / 4.2% / 12.0% |
| 300 | 3397.7h | Abismo · Planalto da Tempestade III (Nv 300) | 2376 | 23.51M | 3 | 253 | 10.0% / 23.8% / 11.4% / 12.0% |

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
| 90 | 82.3h | Abismo · Fontes Termais I (Nv 90) | 1306 | 2.35M | 1 | 80 | 2.0% / 2.0% / 0.0% / 3.5% |
| 100 | 108.3h | Abismo · Vale do Crepúsculo I (Nv 100) | 1336 | 2.80M | 1 | 96 | 2.8% / 3.8% / 0.0% / 4.5% |
| 110 | 146.3h | Abismo · Vale do Crepúsculo I (Nv 100) | 1375 | 2.88M | 1 | 102 | 3.5% / 3.8% / 0.0% / 4.5% |
| 130 | 231.6h | Abismo · Tempestade Luminosa II (Nv 130) | 1741 | 5.35M | 2 | 136 | 5.8% / 6.8% / 0.0% / 7.5% |
| 150 | 359.9h | Abismo · Cordilheira Ventosa I (Nv 150) | 1762 | 6.57M | 2 | 170 | 6.5% / 9.8% / 0.0% / 7.5% |
| 180 | 657.7h | Abismo · Deserto de Cinzas III (Nv 180) | 1889 | 9.00M | 2 | 182 | 6.5% / 9.8% / 0.0% / 7.5% |
| 210 | 1118.2h | Abismo · Cordilheira Ventosa I (Nv 210) | 1900 | 11.31M | 2 | 192 | 9.5% / 10.5% / 0.0% / 9.0% |
| 240 | 1670.2h | Abismo · Brejo Sombrio II (Nv 240) | 2332 | 16.62M | 3 | 205 | 9.5% / 13.5% / 0.0% / 9.0% |
| 270 | 2438.9h | Abismo · Picos Montanhosos II (Nv 270) | 2324 | 19.42M | 3 | 229 | 12.5% / 13.5% / 3.6% / 9.0% |
| 300 | 3475.8h | Abismo · Planalto da Tempestade III (Nv 300) | 2366 | 22.78M | 3 | 247 | 12.5% / 13.5% / 14.4% / 9.0% |

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
| 90 | 86.5h | 86.9h | 82.3h |
| 100 | 113.8h | 113.0h | 108.3h |
| 110 | 153.3h | 163.8h | 146.3h |
| 130 | 237.4h | 244.2h | 231.6h |
| 150 | 362.8h | 365.7h | 359.9h |
| 180 | 654.8h | 651.2h | 657.7h |
| 210 | 1109.7h | 1096.3h | 1118.2h |
| 240 | 1660.0h | 1643.1h | 1670.2h |
| 270 | 2431.6h | 2398.1h | 2438.9h |
| 300 | 3463.4h | 3397.7h | 3475.8h |

## Tempo de calendário estimado (Fogarito)

- **Casual**: 1h ativa + 1 sessão offline de 8h por dia ≈ 8.2h de caça/dia
- **Dedicado**: 3h ativas + 2 sessões offline de 8h por dia ≈ 17.4h de caça/dia

| Nível | Horas | Dias (casual) | Dias (dedicado) |
|---|---|---|---|
| 16 | 1.1h | 0 | 0 |
| 35 | 8.3h | 1 | 0 |
| 80 | 61.4h | 7 | 4 |
| 110 | 153.3h | 19 | 9 |
| 150 | 362.8h | 44 | 21 |
| 210 | 1109.7h | 135 | 64 |
| 240 | 1660.0h | 202 | 95 |
| 300 | 3463.4h | 422 | 199 |

## Desafios com o combate real (tools/challenge_sim.gd, com bônus típicos de Marcos no nível)

Chefes reajustados em +0,3% (nível 10) a +8% (nível 90) de Vida e Ataque para compensar os Marcos de Caça típicos de cada faixa. 2 lutas por caso.

| Desafio | Nível do grupo | Inicial (relação de tipo) | Vitórias | Tempo médio |
|---|---|---|---|---|
| c10 | 13 | Breuzinho (vantagem) | 2/2 | 45s |
| c10 | 13 | Brotilho (neutro) | 0/2 | - |
| c10 | 13 | Fogarito (desvantagem) | 0/2 | - |
| c10 | 18 | Breuzinho (vantagem) | 2/2 | 24s |
| c10 | 18 | Brotilho (neutro) | 2/2 | 37s |
| c10 | 18 | Fogarito (desvantagem) | 2/2 | 51s |
| c20 | 23 | Marolinho (vantagem) | 2/2 | 54s |
| c20 | 23 | Tatuzito (neutro) | 2/2 | 66s |
| c20 | 23 | Picolino (desvantagem) | 0/2 | - |
| c20 | 28 | Marolinho (vantagem) | 2/2 | 40s |
| c20 | 28 | Tatuzito (neutro) | 2/2 | 47s |
| c20 | 28 | Picolino (desvantagem) | 2/2 | 73s |
| c30 | 33 | Picolino (vantagem) | 2/2 | 42s |
| c30 | 33 | Brisinho (neutro) | 0/2 | - |
| c30 | 33 | Tatuzito (desvantagem) | 0/2 | - |
| c30 | 38 | Picolino (vantagem) | 2/2 | 30s |
| c30 | 38 | Brisinho (neutro) | 2/2 | 42s |
| c30 | 38 | Tatuzito (desvantagem) | 2/2 | 62s |
| c40 | 43 | Brotilho (vantagem) | 2/2 | 49s |
| c40 | 43 | Potrilume (neutro) | 2/2 | 68s |
| c40 | 43 | Lãmpadinha (desvantagem) | 2/2 | 98s |
| c40 | 48 | Brotilho (vantagem) | 2/2 | 44s |
| c40 | 48 | Potrilume (neutro) | 2/2 | 63s |
| c40 | 48 | Lãmpadinha (desvantagem) | 2/2 | 90s |
| c50 | 53 | Fogarito (vantagem) | 2/2 | 48s |
| c50 | 53 | Lãmpadinha (neutro) | 0/2 | - |
| c50 | 53 | Brotilho (desvantagem) | 0/2 | - |
| c50 | 58 | Fogarito (vantagem) | 2/2 | 41s |
| c50 | 58 | Lãmpadinha (neutro) | 1/2 | 64s |
| c50 | 58 | Brotilho (desvantagem) | 0/2 | - |
| c60 | 63 | Tatuzito (vantagem) | 2/2 | 55s |
| c60 | 63 | Breuzinho (neutro) | 0/2 | - |
| c60 | 63 | Brisinho (desvantagem) | 0/2 | - |
| c60 | 68 | Tatuzito (vantagem) | 2/2 | 50s |
| c60 | 68 | Breuzinho (neutro) | 2/2 | 75s |
| c60 | 68 | Brisinho (desvantagem) | 0/2 | - |
| c70 | 73 | Lãmpadinha (vantagem) | 2/2 | 55s |
| c70 | 73 | Marolinho (neutro) | 2/2 | 78s |
| c70 | 73 | Potrilume (desvantagem) | 0/2 | - |
| c70 | 78 | Lãmpadinha (vantagem) | 2/2 | 46s |
| c70 | 78 | Marolinho (neutro) | 2/2 | 67s |
| c70 | 78 | Potrilume (desvantagem) | 0/2 | - |
| c80 | 83 | Brisinho (vantagem) | 2/2 | 34s |
| c80 | 83 | Fogarito (neutro) | 1/2 | 49s |
| c80 | 83 | Breuzinho (desvantagem) | 0/2 | - |
| c80 | 88 | Brisinho (vantagem) | 2/2 | 33s |
| c80 | 88 | Fogarito (neutro) | 1/2 | 51s |
| c80 | 88 | Breuzinho (desvantagem) | 0/2 | - |
| c90 | 93 | Potrilume (vantagem) | 2/2 | 33s |
| c90 | 93 | Picolino (neutro) | 2/2 | 54s |
| c90 | 93 | Marolinho (desvantagem) | 1/2 | 72s |
| c90 | 98 | Potrilume (vantagem) | 2/2 | 31s |
| c90 | 98 | Picolino (neutro) | 2/2 | 51s |
| c90 | 98 | Marolinho (desvantagem) | 1/2 | 67s |
