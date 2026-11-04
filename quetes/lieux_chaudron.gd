class_name LieuxChaudron
extends RefCounted
## Où sont les choses dans la clairière du Chaudron (repère local de la clairière) : le chaudron au
## centre, l'étagère aux pots DU CÔTÉ OPPOSÉ à l'entrée, le pupitre du grimoire. L'hôte (règle du
## jeu, bots), le décor et les tests s'en servent tous : une seule source de vérité.
## Rien ici n'a de nœud : tout se teste sans moteur.

## Les pieds du joueur doivent être à moins de ceci du centre du chaudron pour VERSER.
const RAYON_VERSER := 2.5
## ... et à moins de ceci du devant de l'étagère pour PRENDRE ou REPOSER un pot.
const RAYON_ETAGERE := 2.4
## Distance entre le cercle des joueurs et l'étagère.
const DIST_ETAGERE := 2.8
## Le bord de la marmite, au-dessus du centre (où l'on vise pour verser).
const HAUT_BORD := 1.25
## La place d'un bot qui verse : sur le cercle, face au chaudron.
const RAYON_BOT_VERSE := 1.9


## La direction (unitaire, horizontale) de l'étagère depuis le centre : à l'opposé de l'entrée.
static func sens_etagere(zone: int) -> Vector3:
	var entre := Quetes.passage(zone, Quetes.R_FOURCHE) - Quetes.zone(zone)
	entre.y = 0
	return -entre.normalized() if entre.length() > 0.01 else Vector3.BACK


## Le centre de l'étagère (au sol).
static func etagere(zone: int, n: int) -> Vector3:
	return sens_etagere(zone) * (DecorQuete.rayon(n) + DIST_ETAGERE)


## Là où l'on se tient pour se servir : devant l'étagère, côté chaudron.
static func devant_etagere(zone: int, n: int) -> Vector3:
	return sens_etagere(zone) * (DecorQuete.rayon(n) + DIST_ETAGERE - 1.2)


## Le pupitre du grimoire : sur le cercle des joueurs, entre deux d'entre eux, à gauche du chemin
## de l'étagère. Il regarde le chaudron : le lecteur se tient entre le livre et le feu.
static func pupitre(zone: int, n: int) -> Vector3:
	var sens := sens_etagere(zone)
	var voulu := atan2(sens.x, sens.z) + deg_to_rad(80.0)
	var meilleur := 0.0
	var ecart := 99.0
	for k in maxi(n, 1):
		var a := TAU * (k + 0.5) / maxi(n, 1) + PI
		var d := absf(wrapf(a - voulu, -PI, PI))
		if d < ecart:
			ecart = d
			meilleur = a
	return Vector3(sin(meilleur), 0, cos(meilleur)) * (DecorQuete.rayon(n) + 0.35)


## La place où le k-ième joueur (sur n) se tient pour verser : sur son rayon, tout près du chaudron.
static func pt_verser(k: int, n: int) -> Vector3:
	var a := TAU * k / maxi(n, 1) + PI
	return Vector3(sin(a), 0, cos(a)) * RAYON_BOT_VERSE


## À portée du chaudron (pieds `p`, local) ?
static func pres_du_chaudron(p: Vector3) -> bool:
	return Vector2(p.x, p.z).length() <= RAYON_VERSER


## À portée de l'étagère ?
static func pres_de_l_etagere(p: Vector3, zone: int, n: int) -> bool:
	var e := etagere(zone, n)
	return Vector2(p.x - e.x, p.z - e.z).length() <= RAYON_ETAGERE


## Huit pots par étage (trois étages : 24 pots, de quoi ranger la plus grosse réserve du jour).
const POTS_PAR_ETAGE := 8


## La place d'un pot (index `i`) sur l'étagère : (colonne, étage). Les étages se remplissent par le bas.
static func case_pot(i: int) -> Vector2i:
	return Vector2i(i % POTS_PAR_ETAGE, i / POTS_PAR_ETAGE)


## Un ingrédient de couleur propre (pour la mixture et le contenu des pots).
static func couleur_ingredient(ing: int) -> Color:
	return Color.from_hsv(fmod(ing * 0.137 + 0.05, 1.0), 0.62, 0.78)
