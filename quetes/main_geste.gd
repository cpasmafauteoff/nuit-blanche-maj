class_name MainGeste
extends RefCounted
## Ma main dans les quêtes : fermée ou ouverte, et où elle est. Deux sources, la même règle :
##   - la webcam : un poing fermé (doigts pliés) serre ; le poignet, vu par le suivi du corps
##     (épaule → coude → poignet), donne la position de la main ;
##   - la souris : le clic gauche tenu serre ; tant qu'on serre, la souris déplace la main (et plus
##     la tête, cf. MondeQuete.absorber_souris).
## Aucun nœud ici : `lire` reçoit ce qu'on a vu, tout se teste sans moteur (tests/test_gestes.gd).

## Pli moyen des quatre doigts (radians par phalange) au-delà duquel la main est un poing.
const POING := 0.95
## Sous ce pli, la main est ouverte (entre les deux, elle garde son état : pas de clignotement).
const OUVERTE := 0.6

var serre := false
var pos := Vector2.ZERO          # la main, devant moi (x à droite, y en haut, ~ -2..2)
var centre := Vector2.ZERO       # le centre de ses derniers mouvements (pour la manivelle)
var vue := false                 # une main est-elle suivie (webcam) ?
var _souris := Vector2.ZERO


## Le pli moyen des quatre doigts d'une main (0 droite, 1 gauche), ou -1 si elle n'est pas vue.
static func pli(mains: PackedFloat32Array, c: int) -> float:
	var b := c * 22
	if mains.size() < b + 22 or mains[b] < 0.5:
		return -1.0
	var s := 0.0
	for i in range(3, 15):          # index, majeur, annulaire, auriculaire (le pouce plie mal)
		s += mains[b + 7 + i]
	return s / 12.0


## Le poignet d'un bras (0 droit, 1 gauche) par rapport à l'épaule, en longueurs de segment ;
## Vector2.INF s'il n'est pas vu.
static func poignet(corps: PackedFloat32Array, c: int) -> Vector2:
	var b := c * 8
	if corps.size() < b + 8 or corps[b + 3] < 0.5 or corps[b + 7] < 0.5:
		return Vector2.INF
	return Vector2(corps[b] + corps[b + 4], corps[b + 1] + corps[b + 5])


## Une image : la webcam (mains, corps) si une main y est vue, sinon la souris.
func lire(mains: PackedFloat32Array, corps: PackedFloat32Array, clic: bool, delta: float) -> void:
	var meilleur := -1
	var plis := [pli(mains, 0), pli(mains, 1)]
	for c in 2:
		if plis[c] >= 0.0 and (meilleur < 0 or plis[c] > plis[meilleur]):
			meilleur = c
	vue = meilleur >= 0
	var avant := serre
	if vue:
		var p: float = plis[meilleur]
		serre = p > POING or (serre and p > OUVERTE) or clic
		var w := poignet(corps, meilleur)
		if w != Vector2.INF:
			pos = pos.lerp(w, minf(1.0, delta * 15.0))
	else:
		serre = clic
		pos = _souris
	if serre and not avant:
		centre = pos
	# Le centre glisse lentement vers la main : un cercle tracé n'importe où se reconnaît.
	centre = centre.lerp(pos, minf(1.0, delta * 0.8))


## Ce que fait la souris pendant qu'on serre (pixels) : la main bouge, pas la tête.
func souris(rel: Vector2) -> void:
	_souris += Vector2(rel.x, -rel.y) * 0.006
	if _souris.length() > 1.6:
		_souris = _souris.normalized() * 1.6


## La main se relâche : la souris repart du milieu.
func lacher_souris() -> void:
	_souris = Vector2.ZERO


## L'angle de la main autour du centre de son geste (0 = en haut, sens des aiguilles d'une montre).
func angle() -> float:
	var d := pos - centre
	if d.length() < 0.12:
		return -1.0
	return fposmod(atan2(d.x, d.y) / TAU, 1.0)
