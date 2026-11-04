class_name GardeRobe
extends RefCounted
## Ce que ce joueur possède et porte, acheté à la roulotte (cf. Cosmetiques).
##
## Le paiement passe par Steam (choix d'Edwin, 30/10) : chaque article et chaque coffret y sera un
## DLC, et c'est Steam qui dit ce qu'on possède (aucun serveur à nous). Tant que le jeu n'est pas
## sur Steam, la roulotte tourne en MODE ESSAI : tout est débloqué, pour l'essayer, rien n'est payé.

## Changeable pour les tests.
static var fichier := "user://garde_robe.cfg"

## Forçable pour les tests : -1 suit Steam, 0 force la vraie boutique, 1 force l'essai.
static var forcer_essai := -1


## Plateforme (cf. plateforme.gd) quand la vraie boutique Steam est ouverte, sinon null :
## sous le jeu d'essai de Valve (Spacewar), rien n'est à vendre, on reste en essai.
static func steam() -> Node:
	var arbre := Engine.get_main_loop() as SceneTree
	var p: Node = arbre.root.get_node_or_null("Plateforme") if arbre else null
	return p if p and p.boutique_ouverte() else null


static func mode_essai() -> bool:
	if forcer_essai >= 0:
		return forcer_essai == 1
	return steam() == null


static func _lire() -> ConfigFile:
	var f := ConfigFile.new()
	f.load(fichier)
	return f


## Les articles achetés hors coffret (les coffrets se déplient : cf. possede).
static func achats() -> Array:
	return _lire().get_value("garde_robe", "achats", [])


static func possede(id: String) -> bool:
	var a := Cosmetiques.article(id)
	if a.is_empty():
		return false
	if mode_essai():
		return true
	# Un article gratuit par niveau est à soi dès que le niveau est atteint.
	var niveau := int(a.get("niveau", 0))
	if niveau > 0:
		return Progres.niveau() >= niveau
	var s := steam()
	var dlc := int(a.get("steam", 0))
	if s and s.possede_dlc(dlc):
		return true
	if id in achats():
		return true
	# Un article est à soi si l'un des packs qui le contient l'est (« Tout le colporteur » compris).
	for pack_id: String in Cosmetiques.packs_de(id):
		if pack_possede(pack_id):
			return true
	return false


## Ce pack-là est à soi (acheté, ou DLC Steam possédé).
static func pack_possede(pack_id: String) -> bool:
	var p := Cosmetiques.article(pack_id)
	if p.is_empty():
		return false
	if mode_essai():
		return true
	var s := steam()
	return pack_id in achats() or (s != null and s.possede_dlc(int(p.get("steam", 0))))


## Acheter : la page Steam du DLC s'ouvre dans le jeu ; en essai, l'article est simplement ajouté.
## Renvoie "" si c'est fait, sinon pourquoi ce n'est pas (encore) fait.
static func acheter(id: String) -> String:
	var a := Cosmetiques.article(id)
	if a.is_empty() or a.get("seul", false):
		return "Cet article ne se vend pas seul."
	if int(a.get("niveau", 0)) > 0:
		return "Cet article est offert au niveau %d." % int(a["niveau"])
	if mode_essai():
		var l := achats()
		if not id in l:
			l.append(id)
		var f := _lire()
		f.set_value("garde_robe", "achats", l)
		f.save(fichier)
		return ""
	var s := steam()
	var dlc := int(a.get("steam", 0))
	if s == null or dlc <= 0:
		return "Pas encore en vente sur Steam."
	s.ouvrir_page_dlc(dlc)
	return "La page Steam s'est ouverte : l'article arrive dès l'achat confirmé."


## L'apparence avec cet article porté (ou retiré s'il l'était déjà, avec `retirer`).
static func porter(apparence: int, id: String, retirer := false) -> int:
	var a := Cosmetiques.article(id)
	match str(a.get("famille", "")):
		"", "pack", "carte", "emote":
			return apparence
		"objet":
			var d := Bouille.decoder(apparence)
			d["objet"] = 0 if retirer else Cosmetiques.indice("objet", a["valeur"])
			return Bouille.coder(d)
		_:
			return Cosmetiques.poser(apparence, a["famille"], "" if retirer else str(a["valeur"]))


static func porte(apparence: int, id: String) -> bool:
	var a := Cosmetiques.article(id)
	match str(a.get("famille", "")):
		"", "pack":
			return false
		"objet":
			return int(Bouille.decoder(apparence)["objet"]) == Cosmetiques.indice("objet", a["valeur"])
		"carte":
			return carte() == a["valeur"]
		"emote":
			return possede(id)
		_:
			return Cosmetiques.lire(apparence)[a["famille"]] == a["valeur"]


## Le dos de carte choisi ("" : celui d'origine). Il ne se voit que sur ce PC.
static func carte() -> String:
	return str(_lire().get_value("garde_robe", "carte", ""))


static func choisir_carte(valeur: String) -> void:
	var f := _lire()
	f.set_value("garde_robe", "carte", valeur)
	f.save(fichier)


## Ce qu'on porte sans le posséder (une ancienne sauvegarde, un essai fini) est retiré.
static func nettoyer(apparence: int) -> int:
	for a: Dictionary in Cosmetiques.ARTICLES:
		if a["famille"] in Cosmetiques.EMPLACEMENTS or a["famille"] == "objet":
			if porte(apparence, a["id"]) and not possede(a["id"]):
				apparence = porter(apparence, a["id"], true)
	return apparence
