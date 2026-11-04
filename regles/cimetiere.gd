class_name Cimetiere
extends RefCounted
## Le cimetière de la Dame blanche, en règles pures (sans nœud, testé sans fenêtre) : où sont les
## vingt lieux, combien de temps dure une manche, combien de manches, et qui la Dame attrape.
## Le décor (decor_dame.gd) bâtit les lieux là où `lieu_pos` les met ; le jeu (jeux/dame.gd) juge les
## pieds des fuyards avec `verdict`. Tout est en local à la clairière (le centre du cimetière = 0, 0).

const NB_LIEUX := 20
const R_INTERIEUR := 5.6        # la couronne de lieux la plus proche du centre
const R_EXTERIEUR := 7.3        # la couronne extérieure
const R_ENCEINTE := 8.7         # le mur d'enceinte, juste en deçà de la limite des quêtes
const EMPREINTE := 1.2          # un lieu occupe au plus ce rayon (pierres, caveau…) : on ne le traverse pas
## Les lieux de la couronne extérieure (les gros : caveau, arbre mort, puits, grand rocher…), dans l'ordre
## des angles ; les dix autres sont sur la couronne intérieure, décalés d'un demi-pas.
const EXTERIEURS: Array[int] = [0, 1, 6, 10, 11, 19, 15, 9, 3, 13]

## Une manche : préparation (tout le monde y voit, les lieux de la manche s'éclairent), manche (les
## fuyards sont dans le noir et marchent), bilan (la lumière revient, la Dame se montre).
## Le MINIMUM de durée d'une partie est le temps d'une équipe qui joue bien : une manche dure toujours
## autant, rien ne l'abrège. Le temps limite du niveau (Quetes.duree_max) n'est jamais atteint.
const CYCLES := {
	"simple": {"prep": 4.0, "actif": 24.0, "bilan": 4.0},
	"normal": {"prep": 4.0, "actif": 20.0, "bilan": 4.0},
	"dur": {"prep": 3.5, "actif": 16.0, "bilan": 3.5},
	"extreme": {"prep": 3.0, "actif": 12.0, "bilan": 3.0},
}
const MARGE_MIN := 1.05         # on vise 5 % au-dessus du minimum : un bot lent ne passe jamais dessous
const MARGE_FIN := 2.0          # secondes gardées avant le temps limite
## Le rayon autour du lieu de la Dame où l'on est attrapé, selon le niveau.
const RAYONS := {"simple": 2.2, "normal": 2.5, "dur": 2.8, "extreme": 3.0}
## Qui n'a pas bougé d'au moins ça, entre le début et la fin de la manche, est retrouvé.
const DEPLACEMENT_MIN := 1.6
## La Dame glisse jusqu'à son lieu pendant cette part de la manche, puis l'attend.
const PART_TRAJET := 0.6


static func cycle(niveau: String) -> Dictionary:
	return CYCLES.get(niveau, CYCLES["simple"])


static func duree_cycle(niveau: String) -> float:
	var c := cycle(niveau)
	return float(c["prep"]) + float(c["actif"]) + float(c["bilan"])


static func manches_min(niveau: String) -> int:
	return ceili(Quetes.duree_min(niveau) * MARGE_MIN / duree_cycle(niveau))


static func manches_max(niveau: String) -> int:
	return floori((Quetes.duree_max(niveau) - MARGE_FIN) / duree_cycle(niveau))


## Combien de manches : une par joueur (chacun guide une fois), mais jamais sous le minimum du niveau
## ni au-delà de son maximum.
static func nb_manches(niveau: String, joueurs: int) -> int:
	return clampi(joueurs, manches_min(niveau), manches_max(niveau))


## La durée d'une partie menée à son terme (secondes).
static func duree_partie(niveau: String, joueurs: int) -> float:
	return nb_manches(niveau, joueurs) * duree_cycle(niveau)


## Combien de manches on peut se faire attraper et réussir quand même.
static func tolerees(niveau: String, manches: int) -> int:
	match niveau:
		"simple":
			return maxi(1, manches / 3)
		"normal", "dur":
			return maxi(1, manches / 4)
	return 0


static func rayon_attrape(niveau: String) -> float:
	return float(RAYONS.get(niveau, RAYONS["simple"]))


## Le centre du lieu k (0..19, l'ordre de Catalogue.REPERES), en local à la clairière.
static func lieu_pos(k: int) -> Vector3:
	var ext := EXTERIEURS.find(k)
	if ext >= 0:
		var a := TAU * ext / EXTERIEURS.size() + 0.22
		var r := R_EXTERIEUR + 0.35 * sin(k * 2.3)
		return Vector3(sin(a), 0, cos(a)) * r
	var reste: Array[int] = []
	for j in NB_LIEUX:
		if not EXTERIEURS.has(j):
			reste.append(j)
	var i := reste.find(k)
	var a2 := TAU * (i + 0.5) / reste.size() + 0.22
	var r2 := R_INTERIEUR + 0.3 * sin(k * 1.7)
	return Vector3(sin(a2), 0, cos(a2)) * r2


## Le cercle des joueurs au centre, au début : serré (les tombes commencent à 5 m).
static func rayon_depart(n: int) -> float:
	return maxf(1.9, n * 1.2 / TAU)


## Distance à plat (x, z) entre deux points.
static func plat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Le lieu (0..19) le plus proche de p, et sa distance, pour dire « il est près de… ».
static func lieu_proche(p: Vector3) -> int:
	var meilleur := 0
	var dmin := INF
	for k in NB_LIEUX:
		var d := plat(p, lieu_pos(k))
		if d < dmin:
			dmin = d
			meilleur = k
	return meilleur


## Vrai si p est hors de l'emprise d'un lieu (on peut y poser le pied).
static func hors_lieux(p: Vector3, marge := 0.0) -> bool:
	for k in NB_LIEUX:
		if plat(p, lieu_pos(k)) < EMPREINTE + marge:
			return false
	return true


## Où est la Dame à la fraction t (0..1) de son trajet de `depart` à `but` : elle accélère, ralentit,
## et s'écarte un peu de la ligne droite (`cote` ±1 : de quel côté), comme si elle flottait.
static func pos_dame(depart: Vector3, but: Vector3, t: float, cote := 1.0) -> Vector3:
	var u := clampf(t, 0.0, 1.0)
	var e := u * u * (3.0 - 2.0 * u)
	var p := depart.lerp(but, e)
	var d := but - depart
	d.y = 0.0
	if d.length() > 0.01:
		var perp := Vector3(-d.z, 0, d.x).normalized()
		p += perp * sin(PI * e) * 0.9 * cote * minf(1.0, d.length() / 6.0)
	return p


## La fraction du trajet de la Dame après `t` secondes d'une manche de `actif` secondes.
static func fraction_trajet(t: float, actif: float) -> float:
	return clampf(t / maxf(actif * PART_TRAJET, 0.01), 0.0, 1.0)


## Qui attrape le fuyard qui commence la manche en `debut` et la finit en `fin` : "dame" s'il est à
## moins de `rayon` d'une Dame (`dames` : les lieux où elles sont allées), "immobile" s'il n'a presque
## pas bougé, "" s'il s'en sort. La Dame prime : on ne peut pas être « à la fois » les deux.
static func verdict(debut: Vector3, fin: Vector3, dames: Array, rayon: float) -> String:
	for d: Vector3 in dames:
		if plat(fin, d) < rayon:
			return "dame"
	if plat(debut, fin) < DEPLACEMENT_MIN:
		return "immobile"
	return ""


## Un refuge pour un fuyard : un point loin de tous les lieux `interdits` (à `rayon` + `air`), à au
## moins `DEPLACEMENT_MIN` + 1,4 m de `depuis`, dans le cimetière et hors de l'emprise des tombes.
## Hasard seulement : `rng` ; rend Vector3.INF si rien ne convient (la vue d'un bot, jamais d'un joueur).
static func refuge(interdits: Array, rayon: float, depuis: Vector3, rng: RandomNumberGenerator, air := 1.0) -> Vector3:
	for essai in 80:
		var a := rng.randf() * TAU
		var r := rng.randf_range(1.2, R_EXTERIEUR + 0.6)
		var p := Vector3(sin(a), 0, cos(a)) * r
		if plat(p, depuis) < DEPLACEMENT_MIN + 1.4 or not hors_lieux(p, 0.2):
			continue
		var bon := true
		for d: Vector3 in interdits:
			if plat(p, d) < rayon + air:
				bon = false
				break
		if bon:
			return p
	return Vector3.INF
