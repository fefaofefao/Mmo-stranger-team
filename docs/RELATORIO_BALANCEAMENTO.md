# Relatório de balanceamento (simulação 1 → 300)

Gerado por `tools/balance_sim.gd` com o modelo analítico `KillRate` (o mesmo do progresso offline e do servidor). 
O smoke test compara esse modelo com o combate real em tempo real (diferença típica < 10%).

**Premissas do jogador simulado:** escolhe sempre a hunt liberada com mais XP/h que não seja perigosa; 
vence cada Desafio ao atingir nível do desafio + 3; recruta 2 monstros extras (após ~500 e ~1000 abates); 
equipamento do tier do nível (Incomum até 40, Raro até 110, Épico até 210, Lendário depois) com aprimoramento crescente; 
estrelas no principal a cada 30 níveis (máx. 5). Sem boost de 2x XP.


## Inicial: Fogarito

| Nível | Horas acumuladas | Hunt escolhida | Abates/h | XP/h | Em campo |
|---|---|---|---|---|---|
| 5 | 1min | { "pt_BR": "Pradaria Antiga", "en": "Ancient Prairie", "es": "Pradera Antigua" } (Nv 3) | 890 | 15.1k | 1 |
| 10 | 21min | { "pt_BR": "Pradaria Dourada", "en": "Golden Prairie", "es": "Pradera Dorada" } (Nv 5) | 946 | 33.1k | 1 |
| 16 | 1.1h | { "pt_BR": "Planura Escondida", "en": "Hidden Flats", "es": "Llanura Escondida" } (Nv 15) | 1024 | 157.7k | 1 |
| 20 | 2.0h | { "pt_BR": "Galeria Esquecida", "en": "Forgotten Gallery", "es": "Galería Olvidada" } (Nv 20) | 942 | 215.0k | 1 |
| 30 | 5.7h | { "pt_BR": "Galeria Escondida", "en": "Hidden Gallery", "es": "Galería Escondida" } (Nv 28) | 1030 | 370.1k | 1 |
| 35 | 8.4h | { "pt_BR": "Planura Antiga", "en": "Ancient Flats", "es": "Llanura Antigua" } (Nv 32) | 1107 | 476.2k | 1 |
| 50 | 19.7h | { "pt_BR": "Planura Dourada", "en": "Golden Flats", "es": "Llanura Dorada" } (Nv 46) | 1074 | 754.3k | 1 |
| 60 | 31.8h | { "pt_BR": "Caverna Distante", "en": "Distant Cavern", "es": "Caverna Lejana" } (Nv 55) | 1008 | 901.6k | 1 |
| 80 | 62.8h | { "pt_BR": "Caverna Azulada", "en": "Bluish Cavern", "es": "Caverna Azulada" } (Nv 73) | 1205 | 1.58M | 1 |
| 90 | 87.9h | { "pt_BR": "Cripta Larga", "en": "Wide Crypt", "es": "Cripta Ancha" } (Nv 79) | 1087 | 1.59M | 1 |
| 100 | 124.4h | { "pt_BR": "Abismo · Campo de Lava II", "en": "Abyss · Lava Field II", "es": "Abismo · Campo de Lava II" } (Nv 90) | 1303 | 2.27M | 1 |
| 110 | 166.9h | { "pt_BR": "Abismo · Ruínas Energizadas III", "en": "Abyss · Charged Ruins III", "es": "Abismo · Ruinas Energizadas III" } (Nv 100) | 1293 | 2.59M | 1 |
| 130 | 252.4h | { "pt_BR": "Abismo · Deserto de Cinzas III", "en": "Abyss · Ash Desert III", "es": "Abismo · Desierto de Ceniza III" } (Nv 130) | 1693 | 4.84M | 2 |
| 150 | 381.1h | { "pt_BR": "Abismo · Cordilheira Ventosa I", "en": "Abyss · Windy Range I", "es": "Abismo · Cordillera Ventosa I" } (Nv 150) | 1716 | 5.95M | 2 |
| 180 | 675.1h | { "pt_BR": "Abismo · Deserto de Cinzas III", "en": "Abyss · Ash Desert III", "es": "Abismo · Desierto de Ceniza III" } (Nv 180) | 1841 | 8.16M | 2 |
| 210 | 1128.8h | { "pt_BR": "Abismo · Cordilheira Ventosa I", "en": "Abyss · Windy Range I", "es": "Abismo · Cordillera Ventosa I" } (Nv 210) | 1851 | 10.10M | 2 |
| 240 | 1671.0h | { "pt_BR": "Abismo · Brejo Sombrio II", "en": "Abyss · Dark Marsh II", "es": "Abismo · Ciénaga Sombría II" } (Nv 240) | 2244 | 14.67M | 3 |
| 270 | 2428.7h | { "pt_BR": "Abismo · Picos Montanhosos II", "en": "Abyss · Mountain Peaks II", "es": "Abismo · Picos Montañosos II" } (Nv 270) | 2263 | 17.35M | 3 |
| 300 | 3436.6h | { "pt_BR": "Abismo · Planalto da Tempestade III", "en": "Abyss · Storm Plateau III", "es": "Abismo · Meseta Tormentosa III" } (Nv 300) | 2309 | 20.40M | 3 |

## Inicial: Marolinho

| Nível | Horas acumuladas | Hunt escolhida | Abates/h | XP/h | Em campo |
|---|---|---|---|---|---|
| 5 | 3min | { "pt_BR": "Lagoa Dourada", "en": "Golden Lagoon", "es": "Laguna Dorada" } (Nv 2) | 898 | 8981 | 1 |
| 10 | 17min | { "pt_BR": "Cratera Rubra", "en": "Crimson Crater", "es": "Cráter Carmesí" } (Nv 8) | 988 | 65.3k | 1 |
| 16 | 1.2h | { "pt_BR": "Campina Bravia", "en": "Untamed Meadow", "es": "Campiña Bravía" } (Nv 12) | 926 | 105.6k | 1 |
| 20 | 2.2h | { "pt_BR": "Cidadela Rubra", "en": "Crimson Citadel", "es": "Ciudadela Carmesí" } (Nv 15) | 1046 | 161.1k | 1 |
| 30 | 6.2h | { "pt_BR": "Chaminé Brilhante", "en": "Shining Vent", "es": "Chimenea Brillante" } (Nv 27) | 968 | 331.3k | 1 |
| 35 | 9.1h | { "pt_BR": "Fenda Serena", "en": "Serene Rift", "es": "Grieta Serena" } (Nv 31) | 1106 | 456.0k | 1 |
| 50 | 20.9h | { "pt_BR": "Planície Eterna", "en": "Eternal Plain", "es": "Llanura Eterna" } (Nv 45) | 1137 | 776.0k | 1 |
| 60 | 32.1h | { "pt_BR": "Encosta Perdida", "en": "Lost Slope", "es": "Ladera Perdida" } (Nv 54) | 1149 | 1.00M | 1 |
| 80 | 64.5h | { "pt_BR": "Chaminé Bravia", "en": "Untamed Vent", "es": "Chimenea Bravía" } (Nv 72) | 1201 | 1.55M | 1 |
| 90 | 91.7h | { "pt_BR": "Meseta Profunda", "en": "Deep Highland", "es": "Altiplano Profundo" } (Nv 76) | 1134 | 1.38M | 1 |
| 100 | 127.9h | { "pt_BR": "Abismo · Campo de Lava II", "en": "Abyss · Lava Field II", "es": "Abismo · Campo de Lava II" } (Nv 90) | 1401 | 2.44M | 1 |
| 110 | 180.0h | { "pt_BR": "Abismo · Campo de Lava II", "en": "Abyss · Lava Field II", "es": "Abismo · Campo de Lava II" } (Nv 90) | 1438 | 1.60M | 1 |
| 130 | 264.1h | { "pt_BR": "Abismo · Deserto de Cinzas III", "en": "Abyss · Ash Desert III", "es": "Abismo · Desierto de Ceniza III" } (Nv 130) | 1723 | 4.92M | 2 |
| 150 | 391.1h | { "pt_BR": "Abismo · Cordilheira Ventosa I", "en": "Abyss · Windy Range I", "es": "Abismo · Cordillera Ventosa I" } (Nv 150) | 1722 | 5.97M | 2 |
| 180 | 683.6h | { "pt_BR": "Abismo · Deserto de Cinzas III", "en": "Abyss · Ash Desert III", "es": "Abismo · Desierto de Ceniza III" } (Nv 180) | 1863 | 8.26M | 2 |
| 210 | 1132.0h | { "pt_BR": "Abismo · Cordilheira Ventosa I", "en": "Abyss · Windy Range I", "es": "Abismo · Cordillera Ventosa I" } (Nv 210) | 1855 | 10.13M | 2 |
| 240 | 1675.7h | { "pt_BR": "Abismo · Brejo Sombrio II", "en": "Abyss · Dark Marsh II", "es": "Abismo · Ciénaga Sombría II" } (Nv 240) | 2241 | 14.65M | 3 |
| 270 | 2432.8h | { "pt_BR": "Abismo · Picos Montanhosos II", "en": "Abyss · Mountain Peaks II", "es": "Abismo · Picos Montañosos II" } (Nv 270) | 2270 | 17.40M | 3 |
| 300 | 3444.8h | { "pt_BR": "Abismo · Planalto da Tempestade III", "en": "Abyss · Storm Plateau III", "es": "Abismo · Meseta Tormentosa III" } (Nv 300) | 2291 | 20.24M | 3 |

## Inicial: Potrilume

| Nível | Horas acumuladas | Hunt escolhida | Abates/h | XP/h | Em campo |
|---|---|---|---|---|---|
| 5 | 1min | { "pt_BR": "Recife Dourado", "en": "Golden Reef", "es": "Arrecife Dorado" } (Nv 3) | 878 | 14.9k | 1 |
| 10 | 20min | { "pt_BR": "Pradaria Dourada", "en": "Golden Prairie", "es": "Pradera Dorada" } (Nv 5) | 933 | 32.7k | 1 |
| 16 | 1.2h | { "pt_BR": "Mata Silenciosa", "en": "Silent Wildwood", "es": "Espesura Silenciosa" } (Nv 15) | 979 | 150.8k | 1 |
| 20 | 2.1h | { "pt_BR": "Floresta Bravia", "en": "Untamed Woods", "es": "Bosque Bravío" } (Nv 19) | 922 | 195.5k | 1 |
| 30 | 5.8h | { "pt_BR": "Necrópole Encantada", "en": "Enchanted Necropolis", "es": "Necrópolis Encantada" } (Nv 30) | 947 | 373.4k | 1 |
| 35 | 8.4h | { "pt_BR": "Mata Azulada", "en": "Bluish Wildwood", "es": "Espesura Azulada" } (Nv 34) | 1045 | 488.2k | 1 |
| 50 | 20.8h | { "pt_BR": "Lodaçal Velho", "en": "Old Mire", "es": "Lodazal Viejo" } (Nv 42) | 1103 | 685.0k | 1 |
| 60 | 32.7h | { "pt_BR": "Mata Brilhante", "en": "Shining Wildwood", "es": "Espesura Brillante" } (Nv 52) | 1163 | 964.3k | 1 |
| 80 | 64.1h | { "pt_BR": "Cripta Larga", "en": "Wide Crypt", "es": "Cripta Ancha" } (Nv 79) | 1136 | 1.66M | 1 |
| 90 | 85.7h | { "pt_BR": "Abismo · Fontes Termais I", "en": "Abyss · Hot Springs I", "es": "Abismo · Aguas Termales I" } (Nv 90) | 1279 | 2.22M | 1 |
| 100 | 112.8h | { "pt_BR": "Abismo · Brejo Sombrio II", "en": "Abyss · Dark Marsh II", "es": "Abismo · Ciénaga Sombría II" } (Nv 100) | 1279 | 2.56M | 1 |
| 110 | 151.2h | { "pt_BR": "Abismo · Vale do Crepúsculo I", "en": "Abyss · Twilight Vale I", "es": "Abismo · Valle del Crepúsculo I" } (Nv 100) | 1345 | 2.70M | 1 |
| 130 | 237.4h | { "pt_BR": "Abismo · Tempestade Luminosa II", "en": "Abyss · Luminous Storm II", "es": "Abismo · Tormenta Luminosa II" } (Nv 130) | 1685 | 4.81M | 2 |
| 150 | 367.0h | { "pt_BR": "Abismo · Cordilheira Ventosa I", "en": "Abyss · Windy Range I", "es": "Abismo · Cordillera Ventosa I" } (Nv 150) | 1690 | 5.86M | 2 |
| 180 | 663.4h | { "pt_BR": "Abismo · Deserto de Cinzas III", "en": "Abyss · Ash Desert III", "es": "Abismo · Desierto de Ceniza III" } (Nv 180) | 1834 | 8.13M | 2 |
| 210 | 1115.9h | { "pt_BR": "Abismo · Cordilheira Ventosa I", "en": "Abyss · Windy Range I", "es": "Abismo · Cordillera Ventosa I" } (Nv 210) | 1843 | 10.06M | 2 |
| 240 | 1658.5h | { "pt_BR": "Abismo · Brejo Sombrio II", "en": "Abyss · Dark Marsh II", "es": "Abismo · Ciénaga Sombría II" } (Nv 240) | 2266 | 14.81M | 3 |
| 270 | 2412.6h | { "pt_BR": "Abismo · Picos Montanhosos II", "en": "Abyss · Mountain Peaks II", "es": "Abismo · Picos Montañosos II" } (Nv 270) | 2254 | 17.27M | 3 |
| 300 | 3426.2h | { "pt_BR": "Abismo · Planalto da Tempestade III", "en": "Abyss · Storm Plateau III", "es": "Abismo · Meseta Tormentosa III" } (Nv 300) | 2304 | 20.36M | 3 |

## Comparação entre iniciais (horas de jogo acumuladas)

| Nível | Fogarito | Marolinho | Potrilume |
|---|---|---|---|
| 5 | 1min | 3min | 1min |
| 10 | 21min | 17min | 20min |
| 16 | 1.1h | 1.2h | 1.2h |
| 20 | 2.0h | 2.2h | 2.1h |
| 30 | 5.7h | 6.2h | 5.8h |
| 35 | 8.4h | 9.1h | 8.4h |
| 50 | 19.7h | 20.9h | 20.8h |
| 60 | 31.8h | 32.1h | 32.7h |
| 80 | 62.8h | 64.5h | 64.1h |
| 90 | 87.9h | 91.7h | 85.7h |
| 100 | 124.4h | 127.9h | 112.8h |
| 110 | 166.9h | 180.0h | 151.2h |
| 130 | 252.4h | 264.1h | 237.4h |
| 150 | 381.1h | 391.1h | 367.0h |
| 180 | 675.1h | 683.6h | 663.4h |
| 210 | 1128.8h | 1132.0h | 1115.9h |
| 240 | 1671.0h | 1675.7h | 1658.5h |
| 270 | 2428.7h | 2432.8h | 2412.6h |
| 300 | 3436.6h | 3444.8h | 3426.2h |

## Tempo de calendário estimado (Fogarito)

- **Casual**: 1h ativa + 1 sessão offline de 8h por dia ≈ 8.2h de caça/dia
- **Dedicado**: 3h ativas + 2 sessões offline de 8h por dia ≈ 17.4h de caça/dia

| Nível | Horas | Dias (casual) | Dias (dedicado) |
|---|---|---|---|
| 16 | 1.1h | 0 | 0 |
| 35 | 8.4h | 1 | 0 |
| 80 | 62.8h | 8 | 4 |
| 110 | 166.9h | 20 | 10 |
| 150 | 381.1h | 46 | 22 |
| 210 | 1128.8h | 138 | 65 |
| 240 | 1671.0h | 204 | 96 |
| 300 | 3436.6h | 419 | 198 |

## Calibração dos Desafios (combate real, `tools/challenge_sim.gd`)

Inicial solo com equipamento Incomum do tier e estrelas = nível/25. 2 lutas por caso. Com vantagem de tipo vence ~3 níveis acima; neutro ~3-8; desvantagem pede grupo/itens/estrelas melhores.

| Desafio | Nível | Inicial (relação de tipo) | Vitórias | Tempo médio |
|---|---|---|---|---|
| c10 | 13 | Breuzinho (vantagem) | 2/2 | 46s |
| c10 | 13 | Brotilho (neutro) | 0/2 | - |
| c10 | 13 | Fogarito (desvantagem) | 0/2 | - |
| c10 | 18 | Breuzinho (vantagem) | 2/2 | 23s |
| c10 | 18 | Brotilho (neutro) | 2/2 | 37s |
| c10 | 18 | Fogarito (desvantagem) | 1/2 | 50s |
| c20 | 23 | Marolinho (vantagem) | 2/2 | 51s |
| c20 | 23 | Tatuzito (neutro) | 2/2 | 66s |
| c20 | 23 | Picolino (desvantagem) | 0/2 | - |
| c20 | 28 | Marolinho (vantagem) | 2/2 | 38s |
| c20 | 28 | Tatuzito (neutro) | 2/2 | 48s |
| c20 | 28 | Picolino (desvantagem) | 2/2 | 71s |
| c30 | 33 | Picolino (vantagem) | 2/2 | 41s |
| c30 | 33 | Brisinho (neutro) | 0/2 | - |
| c30 | 33 | Tatuzito (desvantagem) | 0/2 | - |
| c30 | 38 | Picolino (vantagem) | 2/2 | 28s |
| c30 | 38 | Brisinho (neutro) | 2/2 | 41s |
| c30 | 38 | Tatuzito (desvantagem) | 2/2 | 62s |
| c40 | 43 | Brotilho (vantagem) | 2/2 | 49s |
| c40 | 43 | Potrilume (neutro) | 2/2 | 69s |
| c40 | 43 | Lãmpadinha (desvantagem) | 2/2 | 98s |
| c40 | 48 | Brotilho (vantagem) | 2/2 | 45s |
| c40 | 48 | Potrilume (neutro) | 2/2 | 64s |
| c40 | 48 | Lãmpadinha (desvantagem) | 2/2 | 88s |
| c50 | 53 | Fogarito (vantagem) | 2/2 | 47s |
| c50 | 53 | Lãmpadinha (neutro) | 0/2 | - |
| c50 | 53 | Brotilho (desvantagem) | 0/2 | - |
| c50 | 58 | Fogarito (vantagem) | 2/2 | 42s |
| c50 | 58 | Lãmpadinha (neutro) | 1/2 | 64s |
| c50 | 58 | Brotilho (desvantagem) | 0/2 | - |
| c60 | 63 | Tatuzito (vantagem) | 2/2 | 57s |
| c60 | 63 | Breuzinho (neutro) | 0/2 | - |
| c60 | 63 | Brisinho (desvantagem) | 0/2 | - |
| c60 | 68 | Tatuzito (vantagem) | 2/2 | 52s |
| c60 | 68 | Breuzinho (neutro) | 1/2 | 80s |
| c60 | 68 | Brisinho (desvantagem) | 0/2 | - |
| c70 | 73 | Lãmpadinha (vantagem) | 2/2 | 59s |
| c70 | 73 | Marolinho (neutro) | 1/2 | 83s |
| c70 | 73 | Potrilume (desvantagem) | 0/2 | - |
| c70 | 78 | Lãmpadinha (vantagem) | 2/2 | 51s |
| c70 | 78 | Marolinho (neutro) | 2/2 | 62s |
| c70 | 78 | Potrilume (desvantagem) | 0/2 | - |
| c80 | 83 | Brisinho (vantagem) | 2/2 | 34s |
| c80 | 83 | Fogarito (neutro) | 0/2 | - |
| c80 | 83 | Breuzinho (desvantagem) | 0/2 | - |
| c80 | 88 | Brisinho (vantagem) | 2/2 | 32s |
| c80 | 88 | Fogarito (neutro) | 2/2 | 48s |
| c80 | 88 | Breuzinho (desvantagem) | 0/2 | - |
| c90 | 93 | Potrilume (vantagem) | 2/2 | 35s |
| c90 | 93 | Picolino (neutro) | 2/2 | 56s |
| c90 | 93 | Marolinho (desvantagem) | 1/2 | 73s |
| c90 | 98 | Potrilume (vantagem) | 2/2 | 32s |
| c90 | 98 | Picolino (neutro) | 2/2 | 50s |
| c90 | 98 | Marolinho (desvantagem) | 0/2 | - |
