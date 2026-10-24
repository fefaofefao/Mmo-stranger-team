# Bestiário Idle

| Campo | Valor |
|---|---|
| Gênero | RPG idle de monstros (coleção + caça automática) |
| Plataforma | Android (retrato) |
| Engine | Godot 4.3 · backend Supabase (servidor autoritativo) |
| Pacote | `com.bestiarioidle.game` · versão 0.1.0 |
| Idiomas | Português, Inglês, Espanhol (Market único entre idiomas) |
| Visual | Pixel art em tiles 32x32 inspirado em Tibia |
| Status | APK de debug pronto; ainda não publicado (sem métricas reais) |
| Monetização | Compras no app (diamantes + Sem anúncios) e AdMob (banner, tela cheia, premiado) |

---

## 1. O jogo

O jogador escolhe 1 de 9 monstros iniciais e caça automaticamente em mapas cheios de monstros selvagens. O combate é 100% automático e continua offline. Cada abate dá XP, ouro, essências, itens e uma pequena chance de **recrutar** o monstro derrotado.

**Conteúdo**
- **135 formas de monstro:** 45 famílias × 3 estágios (filhote → adolescente → adulto), em 9 tipos elementais com ciclo de vantagens.
- **Qualidade de 0 a 100%:** sorteada ao recrutar (Comum, Bom, Ótimo, Perfeito). Dá até +30% de atributos.
- **Shiny:** chance de 1 em 5.000. Tem visual especial, qualidade mínima de 50% e rende 50× mais essência.
- **Nível máximo 300**, em 3 mundos:

| Mundo | Níveis | Monstros em campo | Como libera |
|---|---|---|---|
| 1 | 1–110 | 1 | Abas Iniciante (até 40), Intermediário (até 70) e Avançado (até 110) |
| 2 (Abismo) | 110–210 | 2 | Chefe de Mundo do nível 110 |
| 3 (Reino Astral) | 210–300 | 3 | Chefe de Mundo do nível 210 |

**Loop principal**
1. Caçar.
2. Subir de nível e ganhar ouro, essência, itens e recrutas.
3. Fortalecer os monstros:
   - **Estrelas:** custam essência.
   - **Treino:** custa ouro e dá um brilho visual.
   - **Equipamentos:** 4 slots, aprimoráveis no Altar.
4. Vencer Desafios para liberar hunts melhores.
5. Vencer Chefes de Mundo para liberar o mundo seguinte.

**Sistemas**
- **Marcos de Caça:** abates de cada forma dão bônus permanentes da conta, em 6 marcos de Bronze a Lendário.
- **Desafios:** chefes que liberam hunts. Os Chefes de Mundo não podem ser recrutados e exigem um time completo e upado.
- **Chefe Diário:** 3 entradas por dia; a recompensa é proporcional ao dano.
- **Loja rotativa:** 5 itens trocados a cada 6 h. Os itens raros são caros e são o grande destino do ouro.
- **Market entre jogadores:** itens e essências por ouro; monstros só por diamantes.
- **Rankings:** global e semanal.
- **Tutorial inicial,** com um shiny de demonstração que não pode ser recrutado, e dicas únicas em cada área do Hub.

**Ritmo de progressão** (simulação com o combate real, jogando de forma ativa)

| Nível | Tempo acumulado |
|---|---|
| 10 | ~20 min |
| 50 | ~19 h |
| 110 | ~165 h |
| 210 | ~1.100 h |
| 300 | ~3.050 h |

---

## 2. Retenção

O jogo ainda não tem dados reais de retenção. Abaixo estão os mecanismos que o jogo usa e as metas a acompanhar depois do lançamento.

**Primeira sessão (D0)**
- O nível 10 sai em cerca de 20 minutos.
- O tutorial é curto e mostra um shiny logo no começo, para criar desejo.
- O primeiro recrutamento e o primeiro marco acontecem cedo.

**Motivos para voltar no dia seguinte (D1)**
- **Ganho offline:** até 8 h, com 90% de eficiência. Um anúncio premiado dobra a recompensa.
- **Chefe Diário:** 3 entradas por dia, reiniciadas no dia UTC.
- **Loja:** troca os itens a cada 6 h.

**Médio prazo (D7)**
- Desafios a cada poucos níveis, com hunts novas.
- Marcos de Caça: um objetivo por forma, e são 135 formas.
- Completar a coleção de 135 formas.
- Caça a shinies e a monstros de qualidade alta.
- Estrelas, treino e equipamentos.

**Longo prazo (D30 em diante)**
- Mundos 2 e 3, cada um com um chefe que exige o time completo.
- Ranking semanal.
- Market entre jogadores (vender monstros raros por diamantes).
- Curva até o nível 300 com mais de 3.000 h.

**O que falta para melhorar a retenção**
- **Notificações push** ("ganho offline cheio", "Chefe Diário disponível", "loja renovada"). Ainda não existem.
- **Login diário com recompensa progressiva.** Ainda não existe.
- **Eventos semanais** com shiny temporário e ranking de evento.

**Metas sugeridas para o gênero idle:** D1 de 40% ou mais, D7 de 15% ou mais, D30 de 5% ou mais.

---

## 3. Produtos (compras no app, Google Play)

**Diamantes:** consumíveis. Só entram por compra real ou por venda de monstros no Market. A **primeira compra de diamantes vem em dobro.**

| ID | Diamantes | Bônus | Total | Preço |
|---|---|---|---|---|
| `diamonds_500` | 500 | — | 500 | US$ 4,99 |
| `diamonds_1100` | 1.000 | +100 (10%) | 1.100 | US$ 9,99 |
| `diamonds_2300` | 2.000 | +300 (15%) | 2.300 | US$ 19,99 |
| `diamonds_3600` | 3.000 | +600 (20%, "Popular") | 3.600 | US$ 29,99 |
| `diamonds_6500` | 5.000 | +1.500 (30%) | 6.500 | US$ 49,99 |
| `diamonds_14000` | 10.000 | +4.000 (40%, "Melhor valor") | 14.000 | US$ 99,99 |

**Sem anúncios:** não consumível.

| ID | O que faz | Preço |
|---|---|---|
| `no_ads` | Remove os anúncios em tela cheia para sempre. O banner continua e os premiados seguem opcionais. Fica salvo na conta. | US$ 4,99 |

**Onde os diamantes são gastos**

Bônus de 2× por **8 horas**:

| Bônus | Preço |
|---|---|
| XP | 120 💎 |
| Shiny | 200 💎 |
| Recrutamento | 150 💎 |
| Drop | 150 💎 |
| Ouro | 100 💎 |
| Pacote com os 5 bônus | 550 💎 |

- **Market de monstros:** compra entre jogadores, só por diamantes, com taxa de 10% sobre a venda.

Todas as compras são validadas no servidor pela API do Google Play, e o mesmo token não pode ser usado duas vezes.

---

## 4. AdMob

**Status:** os IDs de teste do Google estão em `data/ads.json`. É preciso trocar pelos IDs reais antes de publicar.

| Formato | Onde aparece | Frequência | Remove com "Sem anúncios"? |
|---|---|---|---|
| **Banner** | Rodapé de todas as telas (exceto tela inicial e escolha do inicial) | Sempre visível | Não |
| **Tela cheia** | Ao abrir o Hub | No máximo 1 a cada 5 min; nunca em desafio nem no resumo offline | **Sim** |
| **Premiado:** Bônus de 15 min | Tela de Bônus (XP, shiny, recrutamento, drop, ouro) | Opcional; soma até 120 min acumulados por bônus | Não (é opcional) |
| **Premiado:** dobrar recompensa offline | Resumo ao voltar ao jogo | Opcional, 1 por retorno | Não (é opcional) |
| **Premiado:** reviver instantâneo | Na caça, quando o monstro cai | Opcional | Não (é opcional) |

**Configuração**
- Consentimento (personalizado ou não) é perguntado na primeira abertura.
- Público não infantil (`tag_for_under_age_of_consent: false`).

**Ideias para aumentar a receita de anúncios** (ainda não feitas)
- Premiado para atualizar a loja de graça 1 vez por dia.
- Premiado para uma entrada extra no Chefe Diário.
