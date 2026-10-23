# Bestiário Idle

RPG idle de monstros para Android, com visual em tiles 32x32 inspirado em Tibia (só o visual), combate 100% automático em mapa, grupo de até 3 monstros, 135 formas, 3 mundos (até o nível 300) com Chefes de Mundo, ranking online, market entre jogadores e AdMob.

- Engine: **Godot 4.3 stable** (GDScript), renderer *GL Compatibility*.
- Backend: **Supabase** (Auth anônima + Google, Postgres com RLS, Edge Function) — com **servidor mock local** que roda o jogo inteiro sem credenciais.
- Anúncios: **AdMob** (plugin Poing Studios) com IDs de teste — com **modo simulado** quando o plugin não está instalado.

Telas: veja `docs/screenshots/` (geradas automaticamente por `tools/screenshots.gd`).

---

## 1. Rodar o jogo

1. Instale o [Godot 4.3 stable](https://godotengine.org/download/archive/4.3-stable/).
2. Abra a pasta do projeto no Godot (`project.godot`) e aperte **F5**.
   - Na primeira abertura o Godot importa as fontes e as traduções.
   - Sem `data/backend.json` preenchido, o jogo usa o **servidor mock** (`user://mock_server.json`).
3. No PC a janela abre em 405x720 (retrato). O botão discreto **dbg** (canto inferior esquerdo) abre o menu de debug.

Linha de comando (headless):

```bash
godot --headless --path . --import                 # importa recursos
godot --headless --path . -s tests/run_tests.gd    # testes unitários (~4.700 asserções)
godot --headless --path . -s tests/smoke_test.gd   # teste de integração: joga de verdade com o mock
godot --headless --path . -s tools/balance_sim.gd  # simulação 1→300, gera docs/RELATORIO_BALANCEAMENTO.md
godot --headless --path . -s tools/challenge_sim.gd   # calibra os Desafios com o combate real
xvfb-run -s "-screen 0 1280x1400x24" godot --path . --rendering-driver opengl3 --resolution 720x1280 -s tools/screenshots.gd
```

> Os testes e ferramentas apagam/criam saves locais de teste (`user://save.json`, `user://mock_server.json`).

## 2. Estrutura

```
data/                 balanceamento em JSON (edite aqui, sem mexer no código)
  config.json           fórmulas, curva de XP, raridades, mundos gerados (world1x, world2, world3), anti-trapaça, market, ads...
  types.json            ciclo de tipos (ordem e multiplicadores)
  families.json         45 famílias x 3 estágios (nomes, descrições, atributos, habilidades)
  abilities.json        63 habilidades (7 por tipo)
  biomes.json           paletas e estilos de geração dos 28 biomas
  hunts_world1.json     144 hunts do Mundo 1 (Fronteira, Mundo 2 e Mundo 3 são gerados pelo config.json)
  challenges.json       Desafios 10..90 (adicione entradas para >90)
  items.json            bases de itens (slot x tipo x tier) e afixos
  ads.json              ÚNICO arquivo com IDs do AdMob
  backend.json          URL/chave do Supabase
src/
  core/               DataDB, Formulas, TypeChart, GameClock
  world/              HuntWorld (mapa, spawns, combate, chefes), MapGenerator (procedural com seed)
  biomes/ art/        TileFactory (tilesets por bioma), SpriteFactory (spritesheets), HubArt
  ai/                 CreatureAI (caça/selvagens/chefe), GridNav (AStarGrid2D + ocupação)
  combat/             Creature, FxLayer (efeitos, projéteis, números de dano, loot)
  party/              PartyLogic (quem luta, divisão de XP)
  progression/        MonsterLogic, KillRate (modelo de abates/hora)
  loot/               ItemLogic, LootTable
  essence/            EssenceLogic (Altar, estrelas, aprimoramento)
  network/            BackendService (interface), MockBackend, SupabaseBackend, ServerLogic
  ads/                AdMobAdapter
  autoload/           Data, Backend, Game (estado/save), Ads
  ui/                 Main, telas (screens/), tema e widgets
  debug/              menu de debug (só em build debug)
supabase/
  migrations/         schema + RLS + funções atômicas do market
  functions/game/     Edge Function com as regras autoritativas
  functions/_shared/  logic.ts (espelho das fórmulas) + gamedata.json (exportado)
tests/                testes unitários e smoke test
tools/                gerador de dados, simulações, screenshots, export para o servidor
```

## 3. Exportar APK / AAB

O `export_presets.cfg` já tem dois presets:

| Preset | Saída | Observação |
|---|---|---|
| **Android Debug** | `build/bestiario-idle-debug.apk` | Sem gradle (template pronto). Usado para gerar o APK de teste. |
| **Android Release (AAB)** | `build/bestiario-idle-release.aab` | Com gradle build, `target_sdk=35`, `min_sdk=24`. Necessário para o plugin AdMob e para a Play Store. |

### Pré-requisitos
1. Templates de export do Godot 4.3 (Editor → *Manage Export Templates* → *Download*).
2. Android SDK (Android Studio ou *command-line tools*) com `platform-tools`, `build-tools;34.0.0` e `platforms;android-35`.
3. JDK 17+.
4. Editor → *Editor Settings* → *Export/Android*: caminho do SDK, do JDK e do *debug keystore*.
   Para criar o keystore de debug:
   ```bash
   keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore \
     -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
   ```

### Comandos
```bash
# APK debug
godot --headless --path . --export-debug "Android Debug" build/bestiario-idle-debug.apk
adb install -r build/bestiario-idle-debug.apk

# AAB de release (antes: Projeto → Instalar Template de Build Android, e configure o keystore de release no preset)
godot --headless --path . --export-release "Android Release (AAB)" build/bestiario-idle-release.aab
```

## 4. Configurar o Supabase

1. Crie um projeto em https://supabase.com.
2. **Authentication → Providers**: ative *Anonymous sign-ins* e *Google* (Client ID/Secret do Google Cloud). Em *URL Configuration* adicione o redirect `monstroidle://auth-callback` (ou o que estiver em `data/backend.json`).
3. Instale a CLI (`npm i -g supabase`), depois na pasta do projeto:
   ```bash
   supabase login
   supabase link --project-ref SEU_PROJECT_REF
   supabase db push                                    # aplica supabase/migrations (tabelas, RLS, funções do market)
   godot --headless --path . -s tools/export_server_data.gd   # gera functions/_shared/gamedata.json
   supabase functions deploy game
   ```
4. Preencha `data/backend.json` com `supabase_url` e `supabase_anon_key` (Settings → API). Com `"mode": "auto"` o jogo passa a usar o Supabase.
5. Sempre que alterar `data/*.json`, rode de novo o `export_server_data.gd` e faça o deploy da função — cliente e servidor precisam das mesmas tabelas.

**Anti-trapaça:** ouro, Essência, itens Raro+ (negociáveis), shinies, recrutamentos, estrelas e recompensas de Desafio só são criados pela Edge Function / funções SQL. O cliente só cria itens Comum/Incomum *vinculados* (não negociáveis). XP/nível é validado contra o tempo real decorrido. Detalhes em `DECISOES.md`.

## 5. Configurar o AdMob

1. No Godot: **AssetLib** → instale o plugin **"Godot AdMob" (Poing Studios)** compatível com Godot 4.3 e ative-o em *Projeto → Configurações → Plugins*.
2. *Projeto → Instalar Template de Build Android* e use o preset **Android Release (AAB)** (gradle).
3. Coloque o **App ID** do AdMob na configuração do plugin (ele grava o `meta-data` `com.google.android.gms.ads.APPLICATION_ID` no AndroidManifest).
4. Em `data/ads.json`: preencha o bloco `"real"` e mude `"use_test_ids": false`.
5. No console do AdMob, crie a mensagem de **consentimento GDPR (UMP)** para EEE/Reino Unido — o jogo chama o fluxo UMP antes de inicializar os anúncios.

Sem o plugin, o jogo roda em **modo simulado**: banner falso no rodapé, anúncio premiado/intersticial com contagem regressiva e diálogo de consentimento simulado — todo o fluxo de recompensas funciona.

Regras implementadas: banner fixo no rodapé **fora do mapa** (o mapa fica num SubViewport acima); rewarded opcionais (*2x XP por 30 min*, *dobrar recompensa offline*, *reviver instantâneo*); intersticial no máximo 1 a cada 5 min (ao abrir o Hub), nunca durante Desafio nem no resumo offline.

## 6. Substituir sprites e tilesets (sem mexer em código)

### Monstros
A arte atual dos monstros já é a versão final gerada (`assets/sprites/monsters/*.png`). Para regerar depois de mudar formatos/cores em `src/art/sprite_factory.gd`:
```bash
godot --headless --path . -s tools/export_raw_sprites.gd -- /tmp/raw_sprites
python3 tools/shade_sprites.py /tmp/raw_sprites      # luz, sombra e contorno colorido
godot --headless --path . --import
```
Salve `assets/sprites/monsters/<form_id>.png` (ex.: `fogo_1_2.png`). Opcional: `<form_id>_shiny.png` (senão a versão shiny é gerada recolorindo a arte).

Layout do spritesheet: **10 colunas x 4 linhas**, quadros de qualquer tamanho igual (32, 48, 64 px...):

| Linha | Direção | | Colunas | Animação |
|---|---|---|---|---|
| 0 | baixo | | 0-1 | parado |
| 1 | esquerda | | 2-4 | andar (3 quadros) |
| 2 | direita | | 5-6 | ataque |
| 3 | cima | | 7-9 | morte (9 = corpo no chão) |

A base do quadro fica alinhada à base do tile. Os `form_id` estão em `data/families.json` (`stages[].form_id`). Para ter um modelo, use o menu de debug → *Exportar spritesheets placeholder* (gera todos os PNG em `user://placeholder_art/`).

### Tilesets
Formato novo (512x128, 16x4 tiles): linha 0 chão (0-7) e decorações (8-15); linha 1 transições para a trilha; linha 2 transições para a massa do bioma (água, lava, rocha...) pela máscara de cantos (1 = sup.esq, 2 = sup.dir, 4 = inf.esq, 8 = inf.dir); linha 3 massa cheia (0-3) e corrupção (4-7). Objetos em pé: `<bioma>_prop0..2.png`. Prévia de todos os biomas: `tools/map_preview.gd` → `docs/maps_preview.png`.
Salve `assets/tilesets/<bioma>.png` nesse formato; os Mundos 2 e 3 aplicam suas paletas (Abismo e Astral, em `config.themes`) automaticamente. Os ids dos biomas estão em `data/biomes.json`. Debug → "Exportar spritesheets placeholder" gera modelos de todos os biomas para o artista.

### Hub
`assets/ui/hub.png` substitui a ilustração do Hub/título.

### Ícones da interface
Os 50 ícones ficam em `assets/ui/icons/<nome>.png` (64x64), gerados por `python3 tools/gen_icons.py --sheet` (prévia em `docs/icons_preview.png`). Substitua qualquer PNG pelo seu (mesmo nome, qualquer tamanho quadrado) e rode `godot --headless --path . --import`. Sem o PNG, o jogo usa a versão pixel art 12x12 de `src/art/icons.gd`.

## 7. Ajustar o balanceamento

**Marcos de Caça** (`config.mastery`): `tiers` (abates por marco), `points` (pontos de cada marco) e `by_type` (atributo e valor por ponto de cada tipo). O mesmo cálculo está em `src/progression/mastery.gd` e `supabase/functions/_shared/logic.ts` (rode `tools/export_server_data.gd` e o teste de paridade depois de mudar). `tools/balance_sim.gd -- sem-marcos` e `tools/challenge_sim.gd -- sem-marcos` comparam sem a mecânica.

Tudo em `data/*.json` (ver `DECISOES.md` para as fórmulas). Para regerar o conteúdo base (nomes, hunts, itens): `python3 tools/gen_data.py` — **sobrescreve** os JSON de conteúdo (não toca em `config.json`, `ads.json`, `backend.json`). Depois de mexer na curva, rode `tools/balance_sim.gd` para ver o novo tempo por faixa de nível.

## 8. Idiomas (PT-BR, EN, ES)

- **Interface**: todo texto passa por `Loc.t("texto em PT-BR")` (`src/core/loc.gd`). As traduções ficam em `tools/i18n_table.py`; `python3 tools/build_translations.py` gera `locale/translations.csv` e acusa textos sem tradução ou com `%s/%d` divergentes (`python3 tools/extract_strings.py` lista os textos usados no código).
- **Dados** (tipos, itens, habilidades, biomas, hunts, raridades, descrições): objetos `{pt_BR, en, es}` gerados por `tools/gen_data.py` e lidos com `Loc.tx(...)` / helpers do `DataDB` (`hunt_name`, `form_desc`, `ability_name`...).
- O idioma inicial vem do sistema; o jogador troca em *Configurações* ou na tela de título.
- **Market único**: as listagens guardam só ids, então jogadores de qualquer idioma compram e vendem no mesmo mercado e cada um lê os nomes no próprio idioma.

## Licenças
Fonte DejaVu Sans (licença livre, ver `assets/fonts/DejaVu-LICENSE.txt`). Toda a arte placeholder é gerada por código.
