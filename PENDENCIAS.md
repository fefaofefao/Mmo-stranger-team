# Pendências (dependem de você)

O jogo roda completo sem nenhum destes itens (servidor mock + anúncios simulados). Faça-os para publicar.

## 1. Supabase (online real)
1. Crie o projeto em https://supabase.com e anote **Project URL**, **anon key** e **project ref** (Settings → API).
2. Authentication → Providers:
   - ative **Anonymous sign-ins**;
   - ative **Google** (crie um OAuth Client "Web application" no Google Cloud Console; cole Client ID e Secret).
3. Authentication → URL Configuration → *Redirect URLs*: adicione `monstroidle://auth-callback`.
4. Terminal, na pasta do projeto:
   ```bash
   npm i -g supabase
   supabase login
   supabase link --project-ref SEU_PROJECT_REF
   supabase db push          # inclui as migrations 20261022000003 (qualidade + Chefe Diário) 20261023000004 (Marcos de Caça) 20261024000005 (loja rotativa e treino) e 20261025000006 (diamantes, bônus, monstros no Market)
   godot --headless --path . -s tools/export_server_data.gd
   supabase functions deploy game
   ```
5. Edite `data/backend.json`: `"supabase_url": "https://SEU_REF.supabase.co"`, `"supabase_anon_key": "..."`.
6. (Opcional) Ative a extensão **pg_cron** e agende a limpeza de tickets (comando no fim de `supabase/migrations/20261021000002_market_functions.sql`).

## 2. Login com Google — retorno ao app (deep link)
O botão "Vincular Google" abre o fluxo OAuth do Supabase no navegador. Para o app receber o retorno automaticamente:
1. Use o preset com **gradle** (Projeto → Instalar Template de Build Android).
2. Em `android/build/AndroidManifest.xml`, dentro da `<activity>` principal, adicione:
   ```xml
   <intent-filter>
     <action android:name="android.intent.action.VIEW" />
     <category android:name="android.intent.category.DEFAULT" />
     <category android:name="android.intent.category.BROWSABLE" />
     <data android:scheme="monstroidle" android:host="auth-callback" />
   </intent-filter>
   ```
3. Alternativa sem deep link: depois de logar no navegador, volte ao app e toque em "Vincular Google" de novo — a Edge Function confirma o vínculo pela identidade da conta.

## 3. AdMob
1. Crie o app e os blocos (banner, intersticial, premiado) em https://admob.google.com.
2. Godot → AssetLib → instale **Godot AdMob (Poing Studios)** para Godot 4.3 → ative o plugin.
3. Projeto → Instalar Template de Build Android; exporte com o preset **Android Release (AAB)** (gradle).
4. Coloque o **App ID** real na configuração do plugin (AndroidManifest `com.google.android.gms.ads.APPLICATION_ID`).
5. `data/ads.json`: preencha `"real"` e mude `"use_test_ids": false`.
6. AdMob → Privacidade e mensagens → crie a mensagem **GDPR** (UMP).
7. (Recomendado) Ative a *verificação do lado do servidor (SSV)* do premiado e valide na Edge Function antes de `double_offline` (hoje o servidor confia no cliente para o anúncio assistido; o efeito é limitado a 1 dobra por resumo offline).
8. Observação: `src/ads/admob_adapter.gd` acessa o plugin por nome de classe (API v3.x). Se a versão instalada tiver nomes diferentes, ajuste apenas esse arquivo.

## 4. Android SDK / publicação
O APK debug foi gerado neste ambiente com o template pronto do Godot (sem gradle). Para a Play Store:
1. Instale o Android SDK (Android Studio) com `platform-tools`, `build-tools;34.0.0`, `platforms;android-35` e JDK 17.
2. Editor Settings → Export → Android: caminhos do SDK/JDK.
3. Crie um **keystore de release** e configure-o no preset "Android Release (AAB)":
   ```bash
   keytool -genkeypair -v -keystore release.keystore -alias bestiario -keyalg RSA -keysize 2048 -validity 10000
   ```
4. Exporte: `godot --headless --path . --export-release "Android Release (AAB)" build/bestiario-idle-release.aab`
5. Play Console: política de privacidade (obrigatória com anúncios e login), classificação etária, formulário de segurança de dados (ID de anúncios, conta).
6. Ícones: preencha `launcher_icons/*` no preset (192x192 e adaptativos 432x432).

## 5. Arte final
Substitua os placeholders (ver README, seção 6): 135 spritesheets de monstros, 28 tilesets de bioma, ilustração do Hub.

## 6. Traduções
EN e ES foram escritos por mim; vale uma revisão por falante nativo antes de publicar (`tools/i18n_table.py` e os textos `{pt_BR, en, es}` em `tools/gen_data.py`). Para um novo idioma: acrescente a coluna nesses dois arquivos, rode `python3 tools/build_translations.py` e `python3 tools/gen_data.py`, inclua o código em `Loc.LANGS` e o `.translation` em `project.godot`.

## 7. Compras com dinheiro real (diamantes)
1. Play Console → Monetizar → Produtos no app: crie **produtos gerenciados (consumíveis)** com os ids de `data/iap.json` (`diamonds_500`, `diamonds_1100`, `diamonds_2300`, `diamonds_3600`, `diamonds_6500`, `diamonds_14000`) e defina os preços (4,99 / 9,99 / 19,99 / 29,99 / 49,99 / 99,99 ou equivalentes por país). Crie também o **`vip_pass` (Passe VIP, US$ 4,99) como produto NÃO consumível** — o app só o reconhece (acknowledge), nunca consome. Para criar outros produtos, acrescente em `data/iap.json` e rode `tools/export_server_data.gd`.
2. Godot → AssetLib → instale **Godot Google Play Billing** (plugin oficial) no build gradle e ative em Exportar → Android. O jogo detecta o singleton `GodotGooglePlayBilling`; se a versão do plugin tiver nomes diferentes, ajuste só `src/autoload/billing.gd`.
3. Google Cloud: crie uma **conta de serviço**, dê acesso a ela no Play Console (Usuários e permissões → "Ver dados financeiros" / "Gerenciar pedidos") e baixe a chave JSON.
4. Supabase → Edge Functions → Secrets: `GOOGLE_SERVICE_ACCOUNT_JSON` (conteúdo da chave), `GOOGLE_PLAY_PACKAGE` (ex.: `com.seuestudio.bestiario`). Para testar no servidor real sem cobrança, `IAP_TEST_MODE=1` aceita compras simuladas — **remova antes de publicar**.
5. Teste com contas de "testador de licença" do Play Console (compras de teste não são cobradas).
6. Recomendado: ativar as Notificações em tempo real do Play (RTDN) para tratar reembolsos (remover diamantes) — não implementado.
