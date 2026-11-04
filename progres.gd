class_name Progres
extends RefCounted
## Ce que ce joueur a accompli, enregistré sur ce PC (user://progression.cfg) : expérience et niveau
## de villageois, parties jouées, succès débloqués. Les règles sont dans regles/progression.gd et
## regles/succes.gd ; ici, seulement le fichier et la liaison avec Steam.
##
## Un succès se débloque sur Steam (setAchievement + storeStats) seulement si Steam est ouvert avec
## le VRAI numéro du jeu ; sous Spacewar (480) il est simplement enregistré ici, et visible dans le
## jeu. Quand le vrai numéro arrive, `pousser_vers_steam` envoie ceux déjà gagnés.

## Changeable pour les tests.
static var fichier := "user://progression.cfg"


static func _lire() -> ConfigFile:
	var f := ConfigFile.new()
	f.load(fichier)
	return f


static func xp() -> int:
	return int(_lire().get_value("progression", "xp", 0))


static func niveau() -> int:
	return Progression.niveau(xp())


static func cumul() -> Dictionary:
	var f := _lire()
	return {"parties": int(f.get_value("progression", "parties", 0)),
		"victoires": int(f.get_value("progression", "victoires", 0)),
		"roles": f.get_value("progression", "roles", []), "xp": int(f.get_value("progression", "xp", 0)),
		"niveau": Progression.niveau(int(f.get_value("progression", "xp", 0)))}


## {id: date (secondes Unix)} des succès gagnés.
static func succes_gagnes() -> Dictionary:
	var f := _lire()
	var d := {}
	if f.has_section("succes"):
		for k in f.get_section_keys("succes"):
			d[k] = int(f.get_value("succes", k, 0))
	return d


static func a_le_succes(id: String) -> bool:
	return _lire().has_section_key("succes", id)


## Une partie vient de finir pour ce joueur. `faits` : ses faits (Succes.faits_partie).
## Renvoie le compte rendu : {xp_gagnee, detail, xp, niveau_avant, niveau_apres, barre, succes: [ids
## nouveaux], articles: [ids gagnés]}.
static func enregistrer_partie(faits: Dictionary) -> Dictionary:
	var f := _lire()
	var xp_avant := int(f.get_value("progression", "xp", 0))
	var gain := Progression.xp_partie(faits)
	var xp_apres := xp_avant + int(gain["total"])
	var roles: Array = f.get_value("progression", "roles", [])
	var r: String = str(faits.get("role", ""))
	if r != "" and not r in roles:
		roles.append(r)
	var parties := int(f.get_value("progression", "parties", 0)) + (1 if not faits.is_empty() else 0)
	var victoires := int(f.get_value("progression", "victoires", 0)) + (1 if faits.get("gagne", false) else 0)
	f.set_value("progression", "xp", xp_apres)
	f.set_value("progression", "parties", parties)
	f.set_value("progression", "victoires", victoires)
	f.set_value("progression", "roles", roles)
	var n_avant := Progression.niveau(xp_avant)
	var n_apres := Progression.niveau(xp_apres)
	var nouveaux := []
	var cumul_apres := {"parties": parties, "victoires": victoires, "roles": roles, "niveau": n_apres}
	var remplis: PackedStringArray = Succes.remplis(faits, cumul_apres) if not faits.is_empty() else PackedStringArray()
	for id in remplis:
		if not f.has_section_key("succes", id):
			f.set_value("succes", id, int(Time.get_unix_time_from_system()))
			nouveaux.append(id)
	f.save(fichier)
	for id: String in nouveaux:
		_vers_steam(id)
	return {"xp_gagnee": int(gain["total"]), "detail": gain["detail"], "xp": xp_apres, "niveau_avant": n_avant,
		"niveau_apres": n_apres, "barre": Progression.barre(xp_apres), "succes": nouveaux,
		"articles": Progression.articles_gagnes(n_avant, n_apres)}


## Steam, quand il est ouvert avec le vrai numéro du jeu (sinon null).
static func _steam() -> Node:
	var arbre := Engine.get_main_loop() as SceneTree
	var p: Node = arbre.root.get_node_or_null("Plateforme") if arbre else null
	return p if p and p.succes_ouverts() else null


static func _vers_steam(id: String) -> void:
	var p := _steam()
	if p:
		p.debloquer_succes(id)


## Au démarrage de Steam : envoie ceux qu'on avait déjà gagnés avant d'avoir le vrai numéro.
static func pousser_vers_steam() -> void:
	var p := _steam()
	if p == null:
		return
	for id in succes_gagnes():
		p.debloquer_succes(id)
