class_name Quetes
extends RefCounted
## Les quêtes du jour, sans rien d'affiché : le tableau, les niveaux, les récompenses et les rôles
## qu'on y gagne. Décidé avec Edwin le 28/10 (docs/superpowers/specs/2026-10-28-quetes-design.md).

## Quatre niveaux (Edwin, 31/10) : simple -> normal -> dur (3 vies) -> extrême.
const NIVEAUX := ["simple", "normal", "dur", "extreme"]
const NOMS_NIVEAUX := {"simple": "Simple", "normal": "Normale", "dur": "Dure", "extreme": "Extrême"}
## Le tirage du niveau (jours 2 et suivants) : l'extrême reste rare, le dur est occasionnel.
const POIDS_NIVEAUX := {"simple": 30, "normal": 40, "dur": 22, "extreme": 8}
## Au niveau dur, l'équipe a 3 vies PARTAGÉES : chaque faute (selon le jeu) en coûte une à tout le monde ;
## à 0, la quête échoue. Les autres niveaux n'ont pas ce compteur commun (certains jeux ont le leur).
const VIES_DUR := 3
## Une quête part avec au moins 3 joueurs, sinon elle est annulée. Pas de plafond.
const MIN_INSCRITS := 3
const NB_DU_JOUR := 3
## Le 4e choix du vote du matin : rester au village.
const RESTER := 3

## Les rôles qu'une quête réussie fait gagner, selon son niveau.
const ROLES_FORTS := ["liseuse", "herboriste", "veilleur"]
const ROLES_UTILES := ["trappeur", "oreille", "doyen", "simplet", "fossoyeur", "guetteuse", "medium",
	"entremetteuse", "enfant"]
## Tirés la première nuit avec les loups, à partir de cette taille de village (Edwin, 30/10).
const SEUIL_TRAITRE := 10
const SEUIL_SOLITAIRE := 12
## Niveau simple : un nom, aucun pouvoir.
const TITRES := ["Meunier", "Forgeron", "Sonneur", "Puisatier", "Bûcheron", "Berger", "Tisserande",
	"Boulangère", "Vannier", "Charron", "Lavandière", "Chandelier"]

## Les loups tirés la première nuit, dans cet ordre selon leur nombre.
const TYPES_LOUPS := ["loup", "vampire", "souffleur", "loup", "loup"]
## Ce que l'hôte peut retirer d'une partie (décision d'Edwin, 29/10) : tous les rôles, sauf le loup.
const ROLES_RETIRABLES := ["liseuse", "herboriste", "veilleur", "trappeur", "oreille", "doyen", "simplet",
	"fossoyeur", "guetteuse", "medium", "entremetteuse", "enfant", "vampire", "souffleur", "traitre", "solitaire"]


## Les types de loups tirés la première nuit, sans ceux que l'hôte a retirés (le loup reste).
static func types_loups(retires: Array) -> Array:
	return TYPES_LOUPS.filter(func(t): return t == "loup" or not retires.has(t))

## id -> [nom, ce qu'on y fait, script]
const JEUX := {
	"runes": ["Les Runes", "Chacun voit un bout de la suite : reconstituez-la en parlant.", "res://quetes/jeux/runes.gd"],
	"pont": ["Le Pont de planches", "Chacun tient une planche pendant que les autres passent.", "res://quetes/jeux/pont.gd"],
	"coffre": ["Le Grand Coffre", "Chacun a son code, dont les chiffres sont dispersés entre vous : parlez, méfiez-vous.", "res://quetes/jeux/coffre.gd"],
	"dame": ["La Dame blanche", "Fermez les yeux. Le guide, lui, la regarde et dit où elle va.", "res://quetes/jeux/dame.gd"],
	"lanternes": ["Les Lanternes du marais", "Un seul voit la carte : il guide les autres à la voix.", "res://quetes/jeux/lanternes.gd"],
	"cloches": ["Les Cloches", "Chacun sonne sa cloche au bon moment de la mélodie.", "res://quetes/jeux/cloches.gd"],
	"chaudron": ["Le Chaudron", "Un lit le grimoire, chacun apporte son ingrédient dans l'ordre.", "res://quetes/jeux/chaudron.gd"],
	"puits": ["Le Puits", "Hissez le seau, chacun son tour à la corde.", "res://quetes/jeux/puits.gd"],
	"moulin": ["Le Moulin", "Chacun tourne une manivelle : gardez le même rythme.", "res://quetes/jeux/moulin.gd"],
	"balance": ["La Balance", "Répartissez les poids pour que tous les plateaux s'équilibrent.", "res://quetes/jeux/balance.gd"],
	"radeau": ["Le Radeau des rapides", "Chacun rame d'un côté : évitez les rochers.", "res://quetes/jeux/radeau.gd"],
	"incendie": ["L'Incendie de la grange", "Une chaîne de seaux, chacun à son poste.", "res://quetes/jeux/incendie.gd"],
}

## Les jeux qui ont un effectif : {min, max (facultatif), sauf (facultatif : nombres refusés)}. Un jeu
## absent d'ici se joue à partir de MIN_INSCRITS, sans limite. On s'inscrit librement ; AU DÉPART,
## si le nombre d'inscrits ne convient pas, un autre jeu compatible se joue à la place.
const EFFECTIFS := {
	"coffre": {"min": 3, "sauf": [5]},
}


static func effectif_valide(jeu: String, n: int) -> bool:
	var e: Dictionary = EFFECTIFS.get(jeu, {})
	return n >= int(e.get("min", MIN_INSCRITS)) and n <= int(e.get("max", 9999)) and not (e.get("sauf", []) as Array).has(n)


## « 3 min (pas 5) » pour les seuls jeux qui ont un effectif ; "" pour les autres.
static func joueurs_requis(jeu: String) -> String:
	if not EFFECTIFS.has(jeu):
		return ""
	var e: Dictionary = EFFECTIFS[jeu]
	var mini_: int = int(e.get("min", MIN_INSCRITS))
	var sauf: Array = e.get("sauf", [])
	var pas: String = " ni ".join(sauf.map(func(x): return str(x)))
	# Des phrases entières (jamais de morceaux collés) : chacune a sa traduction.
	if e.has("max"):
		if sauf.is_empty():
			return "%d min, %d max" % [mini_, int(e["max"])]
		return "%d min, %d max (pas %s)" % [mini_, int(e["max"]), pas]
	if sauf.is_empty():
		return "%d min" % mini_
	return "%d min (pas %s)" % [mini_, pas]


## Le jeu qui prend la place de `jeu` quand `n` inscrits ne lui conviennent pas : un autre jeu
## compatible avec n, de préférence pas déjà au tableau (`evite`). "" si `jeu` convient déjà.
static func remplacant(jeu: String, n: int, rng: RandomNumberGenerator, evite: Array = []) -> String:
	if effectif_valide(jeu, n):
		return ""
	var ok := JEUX.keys().filter(func(j): return j != jeu and effectif_valide(j, n))
	var frais := ok.filter(func(j): return not evite.has(j))
	var pool: Array = frais if not frais.is_empty() else ok
	return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else ""


## Les trois clairières de quête, derrière la lisière : angle (degrés) depuis le centre du village.
## Un seul départ (Edwin, 29/10) : le sentier part de la ruelle entre le temple et la maison I,
## traverse la lisière (un portail), puis se divise à la fourche en trois branches, une par
## clairière. `ANGLES_ZONES` : l'orientation de chaque branche depuis la fourche (degrés).
## `passage(k, r)` : sur le tronc tant que r < R_FOURCHE, puis le long de la branche k ; la
## clairière est au bout (r = R_ZONE).
static var ANGLES_ZONES := [-60.0, 15.0, 90.0]
static var ANGLE_TRONC := 15.0
static var R_FOURCHE := 30.0
static var R_ZONE := 56.0
const LONGUEUR_BRANCHE := 26.0


## Le village a grandi ou rapetissé : chaque clairière se met dans la ruelle la plus proche de
## son angle de toujours (75°, 195°, 285°), pour que son sentier passe entre deux maisons.
static func configurer(_ecart: float, places: int) -> void:
	ANGLE_TRONC = 0.5 * 360.0 / places
	R_FOURCHE = Ronde.R_LISIERE + 2.5
	R_ZONE = R_FOURCHE + LONGUEUR_BRANCHE
	ANGLES_ZONES = [ANGLE_TRONC - 75.0, ANGLE_TRONC, ANGLE_TRONC + 75.0]
const RAYON_ZONE := 6.0
## Les jeux où l'on doit marcher dans la clairière. Pour tous les autres, on reste à son poste :
## seule la tête bouge (Edwin, 30/10). Aucun aujourd'hui : tout se joue du regard et des mains.
const JEUX_A_PIED: Array[String] = []

## Les jeux où UN joueur a un rôle à part. À l'arrivée dans la clairière, ce rôle se choisit par une
## ZONE lumineuse au sol (cf. ChoixRole) ; les autres sont placés à leur poste.
const ROLES_UNIQUES := {"lanternes": "Marcheur", "pont": "Marcheur", "dame": "Guide", "chaudron": "Lecteur"}
## Sans volontaire au bout de ce délai (secondes), le hasard désigne quelqu'un.
const DELAI_ROLE := 15.0
const RAYON_ROLE := 1.4
## Une fois le rôle pris, on laisse ce temps (secondes) pour lire l'annonce avant de rejoindre les postes
## (31/10, testeur : « trop de temps avant que le jeu commence » : on démarre dès que le rôle est pris).
const PAUSE_ROLE := 0.8


## Le trajet vers la clairière attend les retardataires, mais pas indéfiniment : tout le monde est là (départ
## immédiat) ; ou les HUMAINS sont tous à leur place et seuls des bots traînent (au plus `ATTENTE_BOTS` s : un bot
## coincé laissait les joueurs plantés à leur poste sans rien voir démarrer) ; ou, quoi qu'il arrive, `ATTENTE_MAX` s.
const ATTENTE_BOTS := 18.0
const ATTENTE_MAX := 40.0


static func depart_pret(t: float, tous_la: bool, humains_la: bool) -> bool:
	return tous_la or t > ATTENTE_MAX or (humains_la and t > ATTENTE_BOTS)


## Le nom du rôle unique d'un jeu (« Marcheur »), ou "" s'il n'en a pas.
static func role_unique(jeu: String) -> String:
	return ROLES_UNIQUES.get(jeu, "")


## Les lanternes de vie du marcheur du marais selon le niveau de la quête (0 = illimitées : seul le
## temps compte). Décidé avec Edwin le 31/10 : facile illimitées · normal 10 · difficile 3 · extrême 1.
static func vies_marais(niveau: String) -> int:
	return {"simple": 0, "normal": 10, "dur": 3, "extreme": 1}.get(niveau, 0)


static func nom_jeu(jeu: String) -> String:
	return JEUX[jeu][0] if JEUX.has(jeu) else jeu


static func zone(k: int) -> Vector3:
	return passage(k, R_ZONE)


## La clairière la plus proche d'un point (pour retrouver la trouée qui y mène).
static func zone_proche(p: Vector3) -> int:
	var meilleure := 0
	for k in ANGLES_ZONES.size():
		if zone(k).distance_to(p) < zone(meilleure).distance_to(p):
			meilleure = k
	return meilleure


## Le marais des Lanternes : les pierres (une par case), en local à la clairière. Le décor les dessine,
## le jeu y mesure les pieds du marcheur : une seule source pour les deux. La rangée sud est toujours
## au même endroit (la rive des guides) ; le marais s'étend vers le nord selon sa profondeur (cf. Marais).
const MARAIS_SUD := 2.0
const MARAIS_PAS := 1.15
const R_PIERRE := 0.45


## Le centre de la pierre k d'un marais de l pierres de large et h de profondeur (h = l si on ne le dit pas),
## légèrement décalée : un gué, pas un damier.
static func case_marais(k: int, l: int, h: int = -1) -> Vector3:
	if h < 0:
		h = l
	var x := k % l
	var y := k / l
	return Vector3((x - (l - 1) * 0.5) * MARAIS_PAS + 0.05 * sin(k * 2.7), 0.0,
		MARAIS_SUD - (h - 1 - y) * MARAIS_PAS + 0.05 * cos(k * 1.9))


## Le portail du tronc (celui qui sépare le sentier des quêtes du village), côté village : là où l'on
## ramène une équipe à la fin de sa quête, et où on la laisse libre de ses mouvements.
static func portail_retour() -> Vector3:
	var t := deg_to_rad(ANGLE_TRONC)
	return Vector3(sin(t), 0, cos(t)) * (Ronde.r_limite(t) - 0.4)


## Le passage dans la lisière vers la zone k, à rayon r.
static func passage(k: int, r: float) -> Vector3:
	var t := deg_to_rad(ANGLE_TRONC)
	var axe := Vector3(sin(t), 0, cos(t))
	if r <= R_FOURCHE:
		return axe * r
	var b := deg_to_rad(ANGLES_ZONES[k % ANGLES_ZONES.size()])
	return axe * R_FOURCHE + Vector3(sin(b), 0, cos(b)) * minf(r - R_FOURCHE, LONGUEUR_BRANCHE)


## Combien doivent réussir pour que l'équipe réussisse : plus de la moitié ; tous en extrême.
static func seuil(n: int, niveau: String) -> int:
	if niveau == "extreme":
		return n
	if niveau == "dur":
		return mini(n, maxi(n / 2 + 1, (3 * n + 3) / 4))     # aux trois quarts, jamais moins que la moitié + 1
	return n / 2 + 1


## Les vies communes de l'équipe au niveau donné (-1 : pas de compteur commun).
static func vies_equipe(niveau: String) -> int:
	return VIES_DUR if niveau == "dur" else -1


## Un niveau tiré au hasard, selon POIDS_NIVEAUX.
static func tirer_niveau(rng: RandomNumberGenerator) -> String:
	var total := 0
	for n: String in NIVEAUX:
		total += int(POIDS_NIVEAUX[n])
	var k := rng.randi_range(0, total - 1)
	for n: String in NIVEAUX:
		k -= int(POIDS_NIVEAUX[n])
		if k < 0:
			return n
	return "normal"


static func reussie(nb_reussis: int, n: int, niveau: String) -> bool:
	return n > 0 and nb_reussis >= seuil(n, niveau)


## La durée d'un mini-jeu selon son niveau (Edwin, 01/11) : le MINIMUM est le temps qu'une équipe qui
## joue bien met à finir (le jeu est assez riche pour ça : pas de manche ajoutée, pas d'attente),
## le MAXIMUM est le temps limite. Facile 2–8 min, moyen 2–5, dur 1–4, extrême 45 s–1 min 30.
const DUREES := {"simple": [120.0, 480.0], "normal": [120.0, 300.0], "dur": [60.0, 240.0], "extreme": [45.0, 90.0]}


static func duree_min(niveau: String) -> float:
	return float(DUREES.get(niveau, DUREES["simple"])[0])


static func duree_max(niveau: String) -> float:
	return float(DUREES.get(niveau, DUREES["simple"])[1])


## Une durée prévue ramenée dans les bornes du niveau.
static func borner_duree(d: float, niveau: String) -> float:
	return clampf(d, duree_min(niveau), duree_max(niveau))


## Le temps de la phase « quête » est écoulé, mais des jeux tournent encore : de combien la prolonger
## (secondes), pour qu'aucun jeu ne soit coupé avant SON temps limite (un jeu facile dure jusqu'à 8 min,
## Edwin 01/11). `restes` : le temps restant de chaque jeu en cours. 0 : rien à attendre.
static func prolongation(restes: Array) -> float:
	var m := 0.0
	for r in restes:
		m = maxf(m, float(r))
	return m + 1.0 if m > 0.0 else 0.0


## Moins de temps à mesure que le niveau monte.
static func facteur_temps(niveau: String) -> float:
	return {"simple": 1.0, "normal": 0.85, "dur": 0.78, "extreme": 0.7}.get(niveau, 1.0)


## Le tableau du jour : trois quêtes, que le village départage au vote du matin (le maire ne les
## choisit plus, Edwin, 30/10). UN SEUL rôle à gagner par jour (décision du 29/10) : une quête à
## rôle, les autres à indice. Jour 1 : quêtes simples (le rôle gagné est fort), ensuite un niveau
## tiré au hasard. `recents` : jeux d'hier, à éviter si possible.
## [{jeu, niveau, recompense ("role" | "indice")}]
static func tableau(jour: int, rng: RandomNumberGenerator, recents: Array = []) -> Array[Dictionary]:
	var jeux := JEUX.keys()
	var frais := jeux.filter(func(j): return not recents.has(j))
	var nb := NB_DU_JOUR
	var tires := _tirer(frais, nb, rng)
	if tires.size() < nb:
		var autres := jeux.filter(func(j): return not tires.has(j))
		tires.append_array(_tirer(autres, nb - tires.size(), rng))
	var t: Array[Dictionary] = []
	var a_role := rng.randi_range(0, nb - 1)
	for i in nb:
		t.append({"jeu": tires[i], "niveau": "simple" if jour <= 1 else tirer_niveau(rng),
			"recompense": "role" if i == a_role else "indice"})
	return t


## Les trois quêtes que garde le maire : s'il a écarté celle à rôle, son rôle passe à la première
## qu'il garde. Il y a toujours exactement un rôle à gagner dans la journée.
static func un_seul_role(t: Array) -> Array:
	var r := []
	var vu := false
	for q: Dictionary in t:
		var c := q.duplicate()
		if c["recompense"] == "role":
			if vu:
				c["recompense"] = "indice"
			vu = true
		r.append(c)
	if not vu and not r.is_empty():
		r[0]["recompense"] = "role"
	return r


## Avec un maire, LUI SEUL choisit la quête parmi les `nb` du tableau (Edwin, 31/10). Rend son
## choix (0..nb-1, ou RESTER s'il décide de ne pas partir) ; sans choix valide, le hasard prend
## une des quêtes.
static func choix_du_maire(vote_du_maire: int, nb: int, rng: RandomNumberGenerator) -> int:
	if vote_du_maire == RESTER or (vote_du_maire >= 0 and vote_du_maire < nb):
		return vote_du_maire
	return rng.randi_range(0, nb - 1)


## Les autres, quand il y a un maire, ne répondent qu'à « participer ou non » : 0 ou RESTER.
static func participation(k: int) -> int:
	return RESTER if k == RESTER else 0


## Le vote du matin : `votes` joueur -> 0..nb-1 (une quête) ou RESTER. La voix du maire compte
## double ; à égalité, le hasard tranche (personne n'a voté : hasard entre tout). Rend le gagnant.
static func depouiller(votes: Dictionary, maire: int, nb: int, rng: RandomNumberGenerator) -> int:
	var compte := []
	compte.resize(RESTER + 1)
	compte.fill(0)
	for id in votes:
		var k := int(votes[id])
		if k == RESTER or (k >= 0 and k < nb):
			compte[k] += 2 if id == maire else 1
	var choix := range(nb) + [RESTER]
	var meilleur := -1
	for k in choix:
		meilleur = maxi(meilleur, compte[k])
	var ex_aequo := choix.filter(func(k): return compte[k] == meilleur)
	return ex_aequo[rng.randi_range(0, ex_aequo.size() - 1)]


static func _tirer(depuis: Array, n: int, rng: RandomNumberGenerator) -> Array:
	var a := depuis.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var x = a[i]
		a[i] = a[j]
		a[j] = x
	return a.slice(0, mini(n, a.size()))


## Le rôle que gagne une quête réussie. `pris` : rôles déjà tenus (chacun n'existe qu'une fois).
## Jour 1 : toujours un rôle fort. {role, titre} ; un rôle décoratif est un villageois avec un titre.
static func role_gagne(niveau: String, jour: int, pris: Array, rng: RandomNumberGenerator) -> Dictionary:
	var paliers: Array = []
	if jour <= 1 or niveau == "extreme":
		paliers = [ROLES_FORTS, ROLES_UTILES]
	elif niveau == "dur":
		# Entre les deux : un rôle fort une fois sur deux, sinon un rôle utile.
		paliers = [ROLES_FORTS, ROLES_UTILES] if rng.randf() < 0.5 else [ROLES_UTILES, ROLES_FORTS]
	elif niveau == "normal":
		paliers = [ROLES_UTILES, ROLES_FORTS]
	for pool: Array in paliers:
		var libres := pool.filter(func(r): return not pris.has(r))
		if not libres.is_empty():
			return {"role": libres[rng.randi_range(0, libres.size() - 1)], "titre": ""}
	var titres := TITRES.filter(func(t): return not pris.has(t))
	if titres.is_empty():
		titres = TITRES.duplicate()
	return {"role": "villageois", "titre": titres[rng.randi_range(0, titres.size() - 1)]}


## Une quête à rôle de ce niveau ne donnerait-elle, aujourd'hui, qu'un TITRE (tous les rôles qu'elle
## pourrait donner sont déjà pris ou retirés) ? Le tableau doit alors le dire. Le niveau simple (hors
## jour 1) donne toujours un rôle décoratif : il s'annonce comme un rôle.
static func titre_seul(niveau: String, jour: int, pris: Array) -> bool:
	if niveau == "simple" and jour > 1:
		return false
	for r: String in ROLES_FORTS + ROLES_UTILES:
		if not pris.has(r):
			return false
	return true


## Ce que le tableau écrit de la récompense d'une quête. Réussie, une quête à rôle dit seulement
## « Un rôle a été gagné » : ni lequel, ni par qui. `titre_seul` : elle n'annonçait qu'un titre.
static func texte_recompense(recompense: String, titre_seul_: bool, reussie := false) -> String:
	if recompense != "role":
		return "un indice à gagner"
	if reussie:
		return "Un titre a été gagné" if titre_seul_ else "Un rôle a été gagné"
	return "un titre à gagner" if titre_seul_ else "un rôle à gagner"
