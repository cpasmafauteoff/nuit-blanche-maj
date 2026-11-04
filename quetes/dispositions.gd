class_name Dispositions
extends RefCounted
## Où se tiennent les objets de la prise (Prise) dans les jeux « prendre et poser » : l'hôte (qui place les
## objets et les cases) et le décor (qui bâtit l'autel, les tables, les plateaux) lisent les MÊMES nombres.
## Repère : celui de la clairière (cf. DecorQuete). Rien ici ne touche un nœud : tout se teste sans moteur.

# ---------------------------------------------------------------- Les Runes : l'autel de chacun

const HAUT_AUTEL := 0.78          # dessus de l'autel
const AVANCE_AUTEL := 1.2         # le centre de l'autel, devant le poste du joueur
const COLONNES_RUNES := 7         # encoches (et galets) par rangée
const PAS_RUNES := 0.27           # écart entre deux encoches
const RANGEES_GALETS := 3
const MAX_GALETS := COLONNES_RUNES * RANGEES_GALETS
const MAX_ENCOCHES := COLONNES_RUNES * 2


## Le repère de l'autel du joueur k (sur n) : l'avant est -Z, la droite +X.
static func autel(k: int, n: int) -> Transform3D:
	return Prise.banc("runes", k, n, AVANCE_AUTEL)


## La j-ième encoche (sur `total`) : deux rangées au plus, la première (1 à 7) la plus proche du joueur.
static func encoche(k: int, n: int, j: int, total: int) -> Vector3:
	return autel(k, n) * encoche_locale(j, total)


static func encoche_locale(j: int, total: int) -> Vector3:
	var rang := j / COLONNES_RUNES
	var dans := mini(COLONNES_RUNES, total - rang * COLONNES_RUNES)
	var x := ((j % COLONNES_RUNES) - (dans - 1) * 0.5) * PAS_RUNES
	return Vector3(x, HAUT_AUTEL, -0.24 - rang * 0.28)


## Le g-ième galet au repos (sur `total`) : trois rangées au plus, le long du bord proche de l'autel.
static func galet(k: int, n: int, g: int, total: int) -> Vector3:
	return autel(k, n) * galet_local(g, total)


static func galet_local(g: int, total: int) -> Vector3:
	var rang := g / COLONNES_RUNES
	var dans := mini(COLONNES_RUNES, total - rang * COLONNES_RUNES)
	var x := ((g % COLONNES_RUNES) - (dans - 1) * 0.5) * PAS_RUNES
	return Vector3(x, HAUT_AUTEL, 0.60 - rang * 0.27)


# ---------------------------------------------------------------- La Balance : plateaux et tables

const HAUT_TABLE := 0.85          # dessus de la table (cf. DecorQuete.TABLE_HAUT)
const RAYON_PLATEAUX := 1.15      # les plateaux, autour du mât central
const HAUT_PLATEAU := 1.55        # un plateau au repos (centre du plat)
const RAYON_PLAT := 0.5
const MAX_PAR_PLATEAU := 48
const PAR_COUCHE := 16
const COLONNES_TABLE := 6
const MAX_TABLE := COLONNES_TABLE * 3     # trois rangées de six


## Le plateau p (sur P) : sous l'extrémité de son bras, au repos. Répartis autour du mât.
static func plateau(p: int, nb: int) -> Vector3:
	var a := TAU * p / maxi(nb, 1) + 0.5
	return Vector3(sin(a), HAUT_PLATEAU, cos(a)) * Vector3(RAYON_PLATEAUX, 1.0, RAYON_PLATEAUX)


## Le repère de la table du joueur k (sur n).
static func table(k: int, n: int) -> Transform3D:
	return Prise.banc("balance", k, n, 0.75)


## La j-ième place sur la table (trois rangées de six), vue du joueur : de gauche à droite, devant puis derrière.
static func place_table(k: int, n: int, j: int) -> Vector3:
	var rang := j / COLONNES_TABLE
	var x := ((j % COLONNES_TABLE) - (COLONNES_TABLE - 1) * 0.5) * 0.235
	return table(k, n) * Vector3(x, HAUT_TABLE, 0.17 - rang * 0.17)


## La j-ième place d'un objet sur un plat (spirale de tournesol, du centre vers le bord, par couches de
## PAR_COUCHE), en repère du plat : le pied de l'objet.
static func place_plat(j: int) -> Vector3:
	var couche := j / PAR_COUCHE
	var k := j % PAR_COUCHE
	var r := 0.098 * sqrt(float(k) + 0.45)
	var a := float(k) * 2.399963 + couche * 0.9
	return Vector3(cos(a) * r, couche * 0.085, sin(a) * r)
