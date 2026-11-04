class_name Passerelle
extends RefCounted
## Le pont de planches, sans rien d'affiché : sa géométrie (le jeu juge les pieds du marcheur, le décor dessine
## les mêmes planches), sa longueur selon le niveau et l'effectif (c'est elle qui donne sa durée au jeu), les
## planches pourries et les rafales. cf. jeux/pont.gd (la règle) et decors/decor_pont.gd (le décor).
##
## Le pont court du sud vers le nord : la première planche est en Z_DEPART, les suivantes de PAS en PAS vers
## les z décroissants. Le marcheur le traverse À PIED, planche par planche ; les autres, de part et d'autre de
## la gorge, tiennent leur corde.

const PAS := 0.45               # entre deux planches (m)
const DEMI := 0.6               # demi-largeur du tablier
const GORGE_DEMI := 1.4         # demi-largeur de la gorge (le vide de part et d'autre du tablier)
const Z_DEPART := 5.0           # le bord sud de la première planche (local à la clairière)
const N_MAX := 50
const N_MIN := 14
const ECART_POSTES := 1.4       # entre deux tenants d'une même rive, le long de la gorge
const X_POSTES := 2.15          # où se tiennent les tenants (de part et d'autre du tablier)


## Le centre de la planche i (0 = la plus au sud).
static func z_planche(i: int) -> float:
	return Z_DEPART - (float(i) + 0.5) * PAS


## Le bord nord de la dernière planche d'un pont de n planches.
static func z_fin(n: int) -> float:
	return Z_DEPART - float(n) * PAS


## La planche sous ce point (local à la clairière), ou -1 s'il n'y en a pas.
static func indice_sous(x: float, z: float, n: int) -> int:
	if absf(x) > DEMI:
		return -1
	var i := int(floorf((Z_DEPART - z) / PAS))
	if (Z_DEPART - z) < 0.0 or i >= n:
		return -1
	return i


## Ce point est-il au-dessus du vide (dans la gorge, hors du tablier) ?
static func dans_la_gorge(x: float, z: float, n: int) -> bool:
	return absf(x) < GORGE_DEMI and z < Z_DEPART and z > z_fin(n) and absf(x) > DEMI


## Où se tient le tenant de rang r (0, 1, 2…) : alternativement à gauche et à droite du tablier, les
## premiers près du départ. (Les marcheurs n'y sont qu'un instant : ils reviennent y tenir leur corde.)
static func poste(r: int) -> Vector3:
	var cote := -1.0 if r % 2 == 0 else 1.0
	return Vector3(cote * X_POSTES, 0.0, Z_DEPART - 1.2 - float(r / 2) * ECART_POSTES)


## Le nombre minimum de planches pour que tous les tenants aient leur place le long du tablier.
static func planches_min(joueurs: int) -> int:
	var dernier := Z_DEPART - 1.2 - float((joueurs - 1) / 2) * ECART_POSTES
	return maxi(N_MIN, int(ceil((Z_DEPART - dernier + 2.2) / PAS)))


## Les secondes qu'une équipe qui guide bien met à poser le pied sur une planche, selon le niveau.
static func tp(niveau: String) -> float:
	return {"simple": 0.9, "normal": 0.8, "dur": 0.6, "extreme": 0.4}.get(niveau, 0.8)


## Le temps d'un relais (installer le suivant, caler les cordes, première planche) en plus de la traversée :
## de plus en plus court avec le niveau (en extrême, 90 s pour toute l'équipe).
static func relais(niveau: String) -> float:
	return pause(niveau) + 1.5


## La pause entre deux marcheurs (le temps que le suivant monte et que les cordes soient calées).
static func pause(niveau: String) -> float:
	return {"simple": 3.0, "normal": 2.5, "dur": 2.0, "extreme": 1.2}.get(niveau, 2.5)


## La durée qu'on attend d'une équipe qui joue bien : tout le monde traverse, un par un.
static func temps_estime(niveau: String, joueurs: int, nb: int) -> float:
	return float(joueurs) * (float(nb) * tp(niveau) + relais(niveau))


## Combien de planches pour que la partie dure au moins le minimum du niveau (avec une marge de 25 %),
## sans dépasser 80 % du temps limite quand c'est possible.
static func nb_planches(niveau: String, joueurs: int) -> int:
	var j := maxi(joueurs, 1)
	var cible := Quetes.duree_min(niveau) * 1.25
	var nb := roundi((cible / float(j) - relais(niveau)) / tp(niveau))
	var mini_ := planches_min(j)
	nb = clampi(nb, mini_, N_MAX)
	while nb > mini_ and temps_estime(niveau, j, nb) > Quetes.duree_max(niveau) * 0.8:
		nb -= 1
	return nb


## Une planche pourrie sur n : plus il y en a, plus le niveau est haut.
static func ecart_pourries(niveau: String) -> int:
	return {"simple": 8, "normal": 6, "dur": 5, "extreme": 4}.get(niveau, 6)


## Les planches pourries d'un pont de n planches : jamais les deux premières ni les deux dernières, jamais
## deux de suite. Les tenants les voient (marquées en rouge) ; le marcheur, non.
static func pourries(niveau: String, n: int, rng: RandomNumberGenerator) -> Array[int]:
	var r: Array[int] = []
	var voulues := maxi(1, n / ecart_pourries(niveau))
	for essai in voulues * 12:
		if r.size() >= voulues:
			break
		var i := rng.randi_range(3, n - 4)
		var libre := true
		for j in r:
			if absi(i - j) < 3:
				libre = false
		if libre:
			r.append(i)
	r.sort()
	return r


## La période des rafales (s) : de plus en plus rapprochées.
static func periode_rafale(niveau: String) -> float:
	return {"simple": 13.0, "normal": 11.0, "dur": 9.0, "extreme": 8.0}.get(niveau, 11.0)


## 0 : calme · 1 : une rafale se lève (les tenants la voient venir, pas le marcheur) · 2 : la rafale secoue
## le pont. `t` : les secondes depuis que le marcheur est sur les planches.
static func rafale(t: float, niveau: String) -> int:
	if t < 0.0:
		return 0
	var p := periode_rafale(niveau)
	var ph := fposmod(t, p)
	if ph >= p - 2.0:
		return 2
	if ph >= p - 3.4:
		return 1
	return 0


## Le temps limite du pont. C'est le maximum du niveau tant qu'une équipe qui guide bien peut y tenir ;
## mais une grande équipe en extrême (10 personnes, tous doivent traverser, 90 s) ne le peut pas : le pont a
## un minimum de planches pour que chacun ait sa place, et 10 traversées de ce pont dépassent déjà 90 s.
## On lui donne alors le temps estimé de la descente, plus une marge d'un tiers (jamais moins que le maximum).
static func duree_pont(niveau: String, joueurs: int, nb: int) -> float:
	var estime := temps_estime(niveau, joueurs, nb)
	if estime <= Quetes.duree_max(niveau) * 0.8:
		return Quetes.duree_max(niveau)
	return maxf(Quetes.duree_max(niveau), estime * 1.35)
