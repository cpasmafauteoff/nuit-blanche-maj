class_name Gestes
extends RefCounted
## Les gestes face à quelqu'un (touche « interagir », une petite roue autour du viseur) : chut,
## pousser, taper sur l'épaule, poignée de main, chuchoter à l'oreille, accolade, montrer du doigt.
## Ici, les règles — sans scène, donc testables : l'hôte tient un `Gestes` (anti-spam, propositions à
## accepter, poussées) et le client s'en sert pour dessiner la roue et calculer le côté d'une tape.

## id, nom court (secteur de la roue), nom complet, ce que ça demande à l'autre.
const CHOIX := [
	["chut", "Chut", "Chut !", "solo"],
	["pousser", "Pousser", "Pousser", "libre"],
	["epaule", "Épaule", "Taper sur l'épaule", "libre"],
	["main", "Main", "Poignée de main / pacte", "accord"],
	["chuchoter", "Chuchoter", "Chuchoter à l'oreille", "accord"],
	["accolade", "Accolade", "Accolade / check", "accord"],
	["pointer", "Doigt", "Montrer du doigt / accuser", "libre"],
]
## Les gestes à deux, soumis à l'anti-spam : trois secondes entre deux, par joueur (côté hôte).
const A_DEUX := ["main", "chuchoter", "accolade", "pointer"]
const ANTISPAM := 3.0
const ANTISPAM_LEGER := 1.2        # pousser et taper sur l'épaule : on ne harcèle pas non plus
const PORTEE_INVITE := 2.2         # côté client : l'invite apparaît en deçà
const PORTEE_HOTE := 3.2           # côté hôte : un peu de marge (latence, pas de côté)
const DELAI_ACCORD := 8.0          # l'autre a ce temps pour accepter
const POUSSEE := 1.0               # mètres
const VITESSE_POUSSEE := 8.0       # m/s au départ, décroît en exp(-8 t) : 8 / 8 = 1 m
const FRAIN_POUSSEE := 8.0
const FENETRE_CHOC := 2.0          # un « choc » n'est cru que s'il suit une poussée de moins de 2 s
const DUREE_YEUX := 1.0
const DUREE_ETOURDI := 1.0
const DUREE_MARQUE := 4.0
const PHASES_INTERDITES := ["nuit", "distribution", "fin", "vote", "vote_maire", "depouillement", "tranche"]
## Ce que joue le personnage pour chaque geste (cf. Emotes.SOCIAUX).
const EMOTE_DE := {"main": "poignee", "chuchoter": "chuchoter", "accolade": "accolade",
	"check": "check", "pointer": "montrer", "epaule": "epaule", "pousser": "pousser", "chut": "chut"}

var _dernier := {}          # joueur -> instant de son dernier geste à deux
var _dernier_leger := {}    # joueur -> instant de sa dernière poussée / tape
var _propositions := {}     # cible -> {de, type, t}
var _poussees := {}         # cible -> instant de la dernière poussée


static func existe(type: String) -> bool:
	for c: Array in CHOIX:
		if c[0] == type:
			return true
	return false


static func exige_accord(type: String) -> bool:
	for c: Array in CHOIX:
		if c[0] == type:
			return c[3] == "accord"
	return false


static func nom(type: String) -> String:
	for c: Array in CHOIX:
		if c[0] == type:
			return Langue.t(c[2])
	return type


static func phase_permise(phase: String) -> bool:
	return phase not in PHASES_INTERDITES


## De quel côté de `cible` (qui regarde vers `yaw`) se trouve `source` ? -1 : à sa gauche, +1 : à sa droite.
## Même convention que le jeu : un corps qui regarde vers -Z a sa droite vers +X.
static func cote(source: Vector3, cible: Vector3, yaw: float) -> int:
	var v := Vector3(source.x - cible.x, 0, source.z - cible.z)
	var droite := Vector3(cos(yaw), 0, -sin(yaw))     # la droite du corps (basis.x)
	return 1 if v.dot(droite) >= 0.0 else -1


## Ce que la touche « interagir » trouve : le secteur visé (0..CHOIX.size()-1) d'après le curseur de la roue.
## `curseur` : le déplacement accumulé de la souris (px) ; sous `zone_morte`, rien n'est visé (-1).
static func secteur(curseur: Vector2, zone_morte := 30.0) -> int:
	if curseur.length() < zone_morte:
		return -1
	var n := CHOIX.size()
	var a := fposmod(atan2(curseur.x, -curseur.y), TAU)       # 0 en haut, sens horaire
	return int(round(a / (TAU / n))) % n


## La poussée a-t-elle cogné un mur ? Regarde les collisions du dernier `move_and_slide`.
static func choc_mur(corps: CharacterBody3D, pousse: Vector3) -> bool:
	var p := Vector3(pousse.x, 0, pousse.z)
	if p.length() < 0.5:
		return false
	p = p.normalized()
	for i in corps.get_slide_collision_count():
		var c := corps.get_slide_collision(i)
		var n := c.get_normal()
		if absf(n.y) < 0.5 and n.dot(p) < -0.5 and not (c.get_collider() is CharacterBody3D):
			return true
	return false


# ================================================================ hôte

## Un joueur veut faire `type` à `cible`. Rend {ok, refus, etat, ...} :
## `etat` = "propose" (l'autre doit accepter) ou "fait" (c'est joué). `dir` pour une poussée.
func tenter(de: int, cible: int, type: String, pos_de: Vector3, pos_cible: Vector3, maintenant: float) -> Dictionary:
	if not existe(type) or type == "chut":
		return {"ok": false, "refus": "Geste inconnu."}
	if de == cible:
		return {"ok": false, "refus": "Pas à soi-même."}
	if Vector2(pos_de.x, pos_de.z).distance_to(Vector2(pos_cible.x, pos_cible.z)) > PORTEE_HOTE:
		return {"ok": false, "refus": "Trop loin."}
	if type in A_DEUX:
		if _dernier.has(de) and maintenant - float(_dernier[de]) < ANTISPAM:
			return {"ok": false, "refus": "Doucement : laisse-lui un instant."}
		_dernier[de] = maintenant
	else:
		if _dernier_leger.has(de) and maintenant - float(_dernier_leger[de]) < ANTISPAM_LEGER:
			return {"ok": false, "refus": "Doucement."}
		_dernier_leger[de] = maintenant
	var plat := Vector3(pos_cible.x - pos_de.x, 0, pos_cible.z - pos_de.z)
	var dir := plat.normalized() if plat.length() > 0.01 else Vector3.FORWARD
	if exige_accord(type):
		_propositions[cible] = {"de": de, "type": type, "t": maintenant}
		return {"ok": true, "etat": "propose", "type": type, "dir": dir}
	if type == "pousser":
		_poussees[cible] = maintenant
	return {"ok": true, "etat": "fait", "type": type, "dir": dir}


## `cible` accepte ce qu'on lui propose. {ok, de, type} — ou un refus si rien (ou trop tard).
func accepter(cible: int, maintenant: float) -> Dictionary:
	if not _propositions.has(cible):
		return {"ok": false, "refus": "Rien à accepter."}
	var p: Dictionary = _propositions[cible]
	_propositions.erase(cible)
	if maintenant - float(p["t"]) > DELAI_ACCORD:
		return {"ok": false, "refus": "Trop tard."}
	return {"ok": true, "de": p["de"], "type": p["type"]}


func en_attente(cible: int) -> bool:
	return _propositions.has(cible)


## `id` dit s'être cogné : on le croit s'il vient d'être poussé (une fois par poussée).
func choc(id: int, maintenant: float) -> bool:
	if not _poussees.has(id) or maintenant - float(_poussees[id]) > FENETRE_CHOC:
		return false
	_poussees.erase(id)
	return true


func oublier(id: int) -> void:
	_dernier.erase(id)
	_dernier_leger.erase(id)
	_propositions.erase(id)
	_poussees.erase(id)
