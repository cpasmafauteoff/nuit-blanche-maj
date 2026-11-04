class_name Objets
extends RefCounted
## Les objets qu'on prend en main : un carnet dans chaque maison, les pages qu'on en déchire et
## les cailloux du village (décisions d'Edwin, 28/10 puis 31/10). Côté HÔTE, sans nœud : il décide
## de tout, les joueurs n'envoient que des intentions. Tout se teste sans moteur (tests/test_objets.gd).
##
## Un objet : {id, sorte: "carnet" | "page" | "caillou", maison: int (carnet, -1 sinon),
## pages: Array[String] (carnet), texte: String (page), porteur: int, pos: Vector3, angle: float,
## slot: int (0..3 chez son porteur, -1 sinon), main: bool (en main), ouvert: bool (carnet ouvert),
## plume: bool (le stylo écrit)}.
## `porteur` : un joueur, -1 = posé, EN_VOL = lancé (il n'existe plus pour personne jusqu'à l'atterrissage).
## Un joueur a QUATRE emplacements (touches 1 à 4) ; un caillou en prend un entier (pas de pile).

const PAGES_CARNET := 8
const MAX_TEXTE := 600          # caractères par page : un message, pas un roman
const PORTEE := 2.6             # pour prendre ou donner
const SLOTS := 4
const EN_VOL := -3
const MAX_CAILLOUX := 60        # au sol + portés + en vol : le village n'en croule jamais
const CAILLOUX_DEPART := 32
const CAILLOUX_MIN_SOL := 20    # en dessous, il en repousse un de temps en temps
const ECART_CAILLOUX := 2.0     # deux cailloux posés ne se touchent pas

var liste := {}                 # id -> objet
var _suivant := 1


## Un carnet vierge par maison, posé à l'endroit donné (sur la table).
func poser_carnets(positions: Array) -> void:
	for i in positions.size():
		var pages: Array[String] = []
		pages.resize(PAGES_CARNET)
		pages.fill("")
		_ajouter({"sorte": "carnet", "maison": i, "pages": pages, "texte": "", "porteur": -1,
			"pos": positions[i], "angle": 0.0})


## La première page de chaque carnet : « Les bandeaux ». `paires` : [[nom de la couleur, pseudo], …],
## une ligne par joueur de la partie (Edwin, 01/11). Elle se récrit comme les autres, mais ne se déchire pas.
static func page_bandeaux(paires: Array) -> String:
	var t := ""
	for p: Array in paires:
		var pseudo := str(p[1]).replace("\n", " ").strip_edges().substr(0, 22)
		t += "%s : %s\n" % [p[0], pseudo]
	return t.substr(0, MAX_TEXTE)


const SEP_BANDEAU := " : "


## La page des bandeaux en lignes [couleur, pseudo]. Une ligne qui n'a pas la forme « couleur : pseudo »
## (écrite à la main avant le sélecteur) garde tout son texte dans la couleur, pseudo vide.
static func lignes_bandeaux(texte: String) -> Array:
	var r: Array = []
	for l in texte.split("\n"):
		if (l as String).strip_edges() == "":
			continue
		var k := (l as String).find(SEP_BANDEAU)
		if k < 0:
			r.append([l, ""])
		else:
			r.append([(l as String).substr(0, k), (l as String).substr(k + SEP_BANDEAU.length())])
	return r


static func texte_bandeaux(lignes: Array) -> String:
	var t := ""
	for l: Array in lignes:
		t += ("%s%s%s\n" % [l[0], SEP_BANDEAU, l[1]]) if str(l[1]) != "" else "%s\n" % l[0]
	return t.substr(0, MAX_TEXTE)


## Inverse les pseudos des lignes i et j de la page des bandeaux.
static func echanger_bandeaux(texte: String, i: int, j: int) -> String:
	var l := lignes_bandeaux(texte)
	if i < 0 or j < 0 or i >= l.size() or j >= l.size() or i == j:
		return texte
	var tmp = l[i][1]
	l[i][1] = l[j][1]
	l[j][1] = tmp
	return texte_bandeaux(l)


## Donne le pseudo à la ligne i. S'il était sur une autre ligne, celle-ci prend l'ancien pseudo de i
## (les deux s'inversent : personne n'apparaît deux fois, personne ne disparaît).
static func attribuer_bandeau(texte: String, i: int, pseudo: String) -> String:
	var l := lignes_bandeaux(texte)
	if i < 0 or i >= l.size():
		return texte
	for j in l.size():
		if j != i and str(l[j][1]) == pseudo:
			return echanger_bandeaux(texte, i, j)
	l[i][1] = pseudo.replace("\n", " ").strip_edges().substr(0, 22)
	return texte_bandeaux(l)


## Glisse la page des bandeaux en tête de chaque carnet (une seule fois).
func ajouter_page_bandeaux(texte: String) -> void:
	for id in liste:
		var o: Dictionary = liste[id]
		if o["sorte"] == "carnet" and not o.get("bandeaux", false):
			(o["pages"] as Array).push_front(texte)
			o["bandeaux"] = true


func _ajouter(o: Dictionary) -> int:
	o["id"] = _suivant
	o["slot"] = -1
	o["main"] = false
	o["ouvert"] = false
	o["plume"] = false
	liste[_suivant] = o
	_suivant += 1
	return o["id"]


# ---------------------------------------------------------------- l'inventaire

## Les quatre emplacements de ce joueur : l'id de l'objet, ou -1 si vide.
func slots_de(joueur: int) -> Array[int]:
	var r: Array[int] = []
	r.resize(SLOTS)
	r.fill(-1)
	for id in liste:
		var o: Dictionary = liste[id]
		if o["porteur"] == joueur and o["slot"] >= 0 and o["slot"] < SLOTS:
			r[o["slot"]] = id
	return r


## Ce que porte ce joueur, dans l'ordre des emplacements.
func portes_par(joueur: int) -> Array[int]:
	var r: Array[int] = []
	for id in slots_de(joueur):
		if id >= 0:
			r.append(id)
	return r


func plein(joueur: int) -> bool:
	return portes_par(joueur).size() >= SLOTS


func en_main(joueur: int) -> int:
	for id in liste:
		if liste[id]["porteur"] == joueur and liste[id]["main"]:
			return id
	return -1


func _slot_libre(joueur: int) -> int:
	return slots_de(joueur).find(-1)


## Met l'objet dans le premier emplacement libre de `joueur`, et dans sa main.
func _prendre_en_main(id: int, joueur: int) -> void:
	var o: Dictionary = liste[id]
	var s := _slot_libre(joueur) if o["porteur"] != joueur else int(o["slot"])
	for autre in portes_par(joueur):
		liste[autre]["main"] = false
		liste[autre]["ouvert"] = false
		liste[autre]["plume"] = false
	o["porteur"] = joueur
	o["slot"] = s
	o["main"] = true
	o["ouvert"] = false
	o["plume"] = false


func _lacher(id: int) -> void:
	var o: Dictionary = liste[id]
	o["porteur"] = -1
	o["slot"] = -1
	o["main"] = false
	o["ouvert"] = false
	o["plume"] = false


## Touche 1 à 4 : prend en main l'objet de l'emplacement ; la même touche le range.
func choisir(joueur: int, slot: int) -> String:
	if slot < 0 or slot >= SLOTS:
		return "Il n'y a pas d'emplacement %d." % (slot + 1)
	var id: int = slots_de(joueur)[slot]
	if id < 0:
		# Une case vide se choisit aussi : les mains sont vides, comme si on n'avait rien (Edwin, 01/11).
		mains_vides(joueur)
		return ""
	var o: Dictionary = liste[id]
	if o["main"]:
		o["main"] = false
		o["ouvert"] = false
		o["plume"] = false
		return ""
	_prendre_en_main(id, joueur)
	return ""


## Range ce qu'on a en main (tout reste dans l'inventaire) : on n'a plus rien entre les doigts.
func mains_vides(joueur: int) -> void:
	for id in portes_par(joueur):
		liste[id]["main"] = false
		liste[id]["ouvert"] = false
		liste[id]["plume"] = false


## La case suivante (sens +1) ou précédente (-1) : la molette tourne en boucle sur les quatre cases.
static func slot_voisin(courant: int, sens: int) -> int:
	return posmod(courant + sens, SLOTS)


## Au poste d'un mini-jeu (états « role » et « jeu » de la quête), l'inventaire est masqué et inutilisable :
## ni livre, ni changement d'objet, ni lâcher. Il revient dès qu'on sort du jeu (Edwin, 01/11).
static func inventaire_bloque(etat_quete: String) -> bool:
	return etat_quete in ["role", "jeu"]


## Un livre ou une page posés PAR TERRE (pas sur un meuble) reposent sur une feuille claire pour se voir :
## `y` est la hauteur de l'objet, `sol` celle du terrain dessous.
static func repere_au_sol(sorte: String, y: float, sol: float) -> bool:
	return sorte in ["carnet", "page"] and y - sol < 0.25


## Les intentions d'inventaire que l'hôte ignore pendant un mini-jeu (écrire et fermer restent permis :
## rien ne se perd).
static func intention_bloquee_au_poste(type: String, a: Variant) -> bool:
	match type:
		"obj_prendre", "obj_poser", "obj_donner", "obj_dechirer", "obj_choisir", "obj_lancer":
			return true
		"obj_ouvrir", "obj_plume":
			return bool(a)
	return false


## Ouvrir ou fermer le carnet qu'on tient (les autres le voient ouvert).
func ouvrir(joueur: int, oui: bool) -> String:
	var id := en_main(joueur)
	if id < 0 or liste[id]["sorte"] != "carnet":
		return "Tu ne tiens pas de carnet."
	liste[id]["ouvert"] = oui
	if not oui:
		liste[id]["plume"] = false
	return ""


## Le stylo écrit (ou s'arrête) : seulement dans un carnet ouvert qu'on tient.
func plume(joueur: int, oui: bool) -> String:
	var id := en_main(joueur)
	if id < 0 or liste[id]["sorte"] != "carnet" or not liste[id]["ouvert"]:
		if id >= 0:
			liste[id]["plume"] = false
		return "Ouvre ton carnet d'abord."
	liste[id]["plume"] = oui
	return ""


## Prendre un objet posé à portée. Renvoie "" ou la raison du refus.
func prendre(joueur: int, id: int, pos_joueur: Vector3) -> String:
	if not liste.has(id):
		return "Il n'y a plus rien ici."
	var o: Dictionary = liste[id]
	if o["porteur"] != -1:
		return "Quelqu'un l'a déjà."
	if (o["pos"] as Vector3).distance_to(pos_joueur) > PORTEE:
		return "Trop loin."
	if plein(joueur):
		return "Ton inventaire est plein (%d/%d)." % [SLOTS, SLOTS]
	_prendre_en_main(id, joueur)
	return ""


## Poser l'objet en main là où l'on est.
func poser(joueur: int, pos: Vector3, angle := 0.0) -> String:
	var id := en_main(joueur)
	if id < 0:
		return "Tu ne tiens rien."
	_lacher(id)
	liste[id]["pos"] = pos
	liste[id]["angle"] = angle
	return ""


## Donner l'objet en main à quelqu'un de proche, qui a une place libre.
func donner(joueur: int, autre: int, pos_joueur: Vector3, pos_autre: Vector3) -> String:
	var id := en_main(joueur)
	if id < 0:
		return "Tu ne tiens rien."
	if autre == joueur:
		return ""
	if pos_joueur.distance_to(pos_autre) > PORTEE + 0.6:
		return "Approche-toi pour le lui tendre."
	if plein(autre):
		return "Son inventaire est plein."
	_lacher(id)
	_prendre_en_main(id, autre)
	return ""


## Écrire sur une page (du carnet tenu, ou sur la page tenue : alors `page` est ignoré).
func ecrire(joueur: int, id: int, page: int, texte: String) -> String:
	if not liste.has(id) or liste[id]["porteur"] != joueur:
		return "Tu ne le tiens pas."
	var o: Dictionary = liste[id]
	texte = texte.substr(0, MAX_TEXTE)
	if o["sorte"] == "page":
		o["texte"] = texte
		return ""
	if o["sorte"] != "carnet":
		return "On n'écrit pas sur ça."
	var pages: Array = o["pages"]
	if page < 0 or page >= pages.size():
		return "Cette page n'existe plus."
	pages[page] = texte
	return ""


## Déchirer une page du carnet tenu : elle devient un objet à part, dans un emplacement libre
## et dans la main (le carnet, lui, retourne dans sa poche).
## Renvoie [refus, id de la page créée].
func dechirer(joueur: int, id: int, page: int) -> Array:
	if not liste.has(id) or liste[id]["porteur"] != joueur:
		return ["Tu ne le tiens pas.", -1]
	var o: Dictionary = liste[id]
	if o["sorte"] != "carnet":
		return ["Ce n'est pas un carnet.", -1]
	var pages: Array = o["pages"]
	if page < 0 or page >= pages.size():
		return ["Cette page n'existe plus.", -1]
	if page == 0 and o.get("bandeaux", false):
		return ["La page des bandeaux est cousue au carnet.", -1]
	if plein(joueur):
		return ["Il te faut un emplacement libre pour la page.", -1]
	var texte: String = pages[page]
	pages.remove_at(page)
	var p := _ajouter({"sorte": "page", "maison": o["maison"], "pages": [], "texte": texte, "porteur": -1,
		"pos": o["pos"], "angle": 0.0})
	_prendre_en_main(p, joueur)
	return ["", p]


## Mort ou parti : tout ce qu'il portait tombe à ses pieds.
func lacher_tout(joueur: int, pos: Vector3) -> void:
	var k := 0
	for id in portes_par(joueur):
		_lacher(id)
		liste[id]["pos"] = pos + Vector3(0.3 * k, 0, 0.2)
		k += 1


## L'objet posé le plus proche à portée, ou -1.
func proche(pos: Vector3) -> int:
	var meilleur := -1
	var d_min := PORTEE
	for id in liste:
		var o: Dictionary = liste[id]
		if o["porteur"] != -1:
			continue
		var d := (o["pos"] as Vector3).distance_to(pos)
		if d < d_min:
			d_min = d
			meilleur = id
	return meilleur


# ---------------------------------------------------------------- les cailloux

func nb_cailloux() -> int:
	var n := 0
	for id in liste:
		if liste[id]["sorte"] == "caillou":
			n += 1
	return n


func cailloux_au_sol() -> Array[int]:
	var r: Array[int] = []
	for id in liste:
		if liste[id]["sorte"] == "caillou" and liste[id]["porteur"] == -1:
			r.append(id)
	return r


## Pose un caillou là où on le dit (refus : trop près d'un autre, ou le village en est plein).
func poser_caillou(pos: Vector3) -> int:
	if nb_cailloux() >= MAX_CAILLOUX:
		return -1
	for id in cailloux_au_sol():
		if (liste[id]["pos"] as Vector3).distance_to(pos) < ECART_CAILLOUX:
			return -1
	return _ajouter({"sorte": "caillou", "maison": -1, "pages": [], "texte": "", "porteur": -1,
		"pos": pos, "angle": 0.0})


## Sème les cailloux du départ parmi des emplacements possibles (tirés dans `candidats`).
func semer_cailloux(candidats: Array) -> void:
	for p in candidats:
		if cailloux_au_sol().size() >= CAILLOUX_DEPART:
			break
		poser_caillou(p)


## Un caillou repousse (sur un des `candidats`) s'il n'en reste pas assez au sol. -1 : rien fait.
func reapprovisionner(candidats: Array) -> int:
	if cailloux_au_sol().size() >= CAILLOUX_MIN_SOL:
		return -1
	for p in candidats:
		var id := poser_caillou(p)
		if id >= 0:
			return id
	return -1


## Lancer l'objet en main (un caillou, mais aussi un carnet ou une page : 01/11) : il n'est plus à
## personne jusqu'à ce qu'il atterrisse. Renvoie [refus, id].
func lancer(joueur: int) -> Array:
	var id := en_main(joueur)
	if id < 0:
		return ["Tu ne tiens rien à jeter.", -1]
	_lacher(id)
	liste[id]["porteur"] = EN_VOL
	return ["", id]


func atterrir(id: int, pos: Vector3) -> void:
	if liste.has(id) and liste[id]["porteur"] == EN_VOL:
		liste[id]["porteur"] = -1
		liste[id]["pos"] = pos
		liste[id]["angle"] = 0.0


## Pour le réseau : une copie à plat (les textes voyagent avec : quelques Ko au plus).
func etat() -> Array:
	var r := []
	for id in liste:
		r.append((liste[id] as Dictionary).duplicate(true))
	return r
