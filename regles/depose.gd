class_name Depose
extends RefCounted
## Poser ou jeter un objet (retour d'Edwin, 01/11 : « j'ai essayé de jeter un objet et il a disparu »).
## Règles pures, sans nœud (tests/test_depose.gd) : OÙ l'objet se pose (jamais sous le sol, jamais loin
## de soi), comment il y va (un petit arc depuis la main), et comment il atterrit après un jet.

const DUREE_POSE := 0.45        # la chute de la main au sol, en secondes
const CREUX := 0.12             # le sommet de l'arc au-dessus de la droite main -> sol (m)
const REPOS := 0.012            # un objet posé flotte à peine au-dessus du sol (m)
const PORTEE_POSE := 3.0        # l'hôte refuse un point plus loin que ça de soi
const DEVANT := 0.6             # sans surface visée : posé à ce point devant les pieds (m)
const RECUL_MUR := 0.18         # un jet qui tape un mur retombe un peu en retrait (m)


## Le point où poser. `touche` : le point visé par le rayon (ou null), `normale_y` : la pente de ce
## point (1 = à plat), `pieds` : où je me tiens, `avant` : mon regard à plat, `sol` : (x, z) -> hauteur du sol.
## Jamais sous le sol, même quand le rayon ne touche rien (alors : devant mes pieds).
static func point_de_pose(touche: Variant, normale_y: float, pieds: Vector3, avant: Vector3, sol: Callable) -> Vector3:
	if touche is Vector3 and normale_y > 0.6:
		var p: Vector3 = touche
		return Vector3(p.x, maxf(p.y, _sol(sol, p)) + REPOS, p.z)
	var d := Vector3(avant.x, 0.0, avant.z)
	d = d.normalized() if d.length() > 0.001 else Vector3.FORWARD
	var p2 := pieds + d * DEVANT
	return Vector3(p2.x, maxf(pieds.y, _sol(sol, p2)) + REPOS, p2.z)


## L'hôte relit ce que dit le joueur : un point farfelu (NaN, loin, sous le sol) devient un point à ses pieds.
static func corriger_hote(ou: Vector3, ici: Vector3, sol: Callable) -> Vector3:
	if is_nan(ou.x) or is_nan(ou.y) or is_nan(ou.z) or is_inf(ou.x) or is_inf(ou.y) or is_inf(ou.z):
		ou = ici
	if ou.distance_to(ici) > PORTEE_POSE:
		ou = ici
	return Vector3(ou.x, maxf(ou.y, _sol(sol, ou) + REPOS), ou.z)


## Où retombe un objet jeté : au sol sous le point d'arrivée, ou SUR le meuble qui est là (`dessus` :
## la hauteur du plateau trouvé sous le point, null s'il n'y a rien). Edwin, 01/11 : « j'ai jeté mon
## livre sur le lit et il l'a traversé, il faut que le livre tombe sur le lit ».
static func atterrissage(fin: Vector3, sol: Callable, dessus: Variant = null) -> Vector3:
	var y := _sol(sol, fin)
	if dessus is float and dessus > y:
		y = dessus
	return Vector3(fin.x, y + REPOS, fin.z)


## La position à l'instant `k` (0..1) de la chute : la droite départ -> arrivée, creusée d'un arc.
static func arc(depart: Vector3, arrivee: Vector3, k: float) -> Vector3:
	k = clampf(k, 0.0, 1.0)
	var p := depart.lerp(arrivee, smoothstep(0.0, 1.0, k))
	p.y += 4.0 * k * (1.0 - k) * CREUX
	return p


## Le bras qui descend vers le sol puis revient (0 -> 1 -> 0) : t en secondes depuis le début du geste.
static func geste(t: float) -> float:
	if t < 0.0 or t > 0.8:
		return 0.0
	return smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.45, 0.8, t))


static func _sol(sol: Callable, p: Vector3) -> float:
	return float(sol.call(p.x, p.z)) if sol.is_valid() else 0.0
