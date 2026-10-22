class_name Loc
extends RefCounted
## Idiomas. Textos de interface: Loc.t("texto em PT-BR") usa locale/translations.csv (chave = texto PT-BR).
## Textos de dados (monstros, itens, hunts...): objetos {"pt_BR": .., "en": .., "es": ..} lidos com Loc.tx().
## O market é único para todos os idiomas: ele guarda apenas ids (base do item, raridade, tipo) e cada
## jogador vê os nomes traduzidos no próprio idioma.

const LANGS := ["pt_BR", "en", "es"]
const LANG_NAMES := {"pt_BR": "Português", "en": "English", "es": "Español"}

static var locale := "pt_BR"


static func set_locale(l: String) -> void:
	if not LANGS.has(l):
		l = "pt_BR"
	locale = l
	TranslationServer.set_locale(l)


## Idioma inicial a partir do sistema: pt → pt_BR, es → es, demais → en.
static func detect() -> String:
	var lang := OS.get_locale_language()
	if lang == "pt":
		return "pt_BR"
	if lang == "es":
		return "es"
	return "en"


static func tx(v) -> String:
	if v is Dictionary:
		if v.has(locale):
			return str(v[locale])
		return str(v.get("pt_BR", v.values()[0] if not v.is_empty() else ""))
	return str(v)


static func t(s: String) -> String:
	if locale == "pt_BR":
		return s
	return String(TranslationServer.translate(s))
