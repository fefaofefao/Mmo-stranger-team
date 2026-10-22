class_name StarterStyle
extends RefCounted


static func name(s: String) -> String:
	return {"melee": Loc.t("Corpo a corpo"), "ranged": Loc.t("Distância"), "magic": Loc.t("Mágico")}.get(s, s)
