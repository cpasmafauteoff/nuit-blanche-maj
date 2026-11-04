class_name Lancer
extends RefCounted
## Lancer un caillou (décision d'Edwin, 31/10) : maintenir le clic gauche pour viser (plus on tient,
## plus ça part fort, jusqu'à ~1 s), clic droit pour lancer. L'HÔTE calcule la trajectoire et décide
## qui est touché, et où : tête ou corps. Tout est pur, sans nœud (tests/test_lancer.gd).

const MAINTIEN_MAX := 1.0       # secondes pour la force maximale
const V_MIN := 5.5              # m/s, un jet mollasson
const V_MAX := 17.0             # m/s, à pleine force (~25 m en cloche)
const FORCE_SANS_VISEE := 0.5   # clic droit sans avoir visé
const GRAVITE := 9.8
const ELEVATION := 0.1          # le caillou part un peu au-dessus du regard (rad)
const DUREE_MAX := 4.0
const PAS := 0.02

const TETE_Y := 1.62            # centre de la tête au-dessus des pieds
const TETE_R := 0.28            # un peu généreuse : la cible bouge, et son état nous arrive avec un léger retard
const CORPS_R := 0.3
const CORPS_BAS := 0.1
const CORPS_HAUT := 1.4

const PHASES_SANS_LANCER := ["salon", "fin", "nuit", "distribution"]


static func charge(duree_maintien: float) -> float:
	return clampf(duree_maintien / MAINTIEN_MAX, 0.0, 1.0)


static func vitesse(force: float) -> float:
	return lerpf(V_MIN, V_MAX, clampf(force, 0.0, 1.0))


## La vitesse de départ pour un regard `dir` et une force donnée.
static func v0(dir: Vector3, force: float) -> Vector3:
	var d := dir.normalized()
	var h := Vector2(d.x, d.z).length()
	var a := atan2(d.y, h) + ELEVATION
	var plat := Vector2(d.x, d.z).normalized() if h > 0.0001 else Vector2.ZERO
	return Vector3(plat.x * cos(a), sin(a), plat.y * cos(a)) * vitesse(force)


static func point(de: Vector3, vitesse_depart: Vector3, t: float) -> Vector3:
	return de + vitesse_depart * t + Vector3(0, -0.5 * GRAVITE * t * t, 0)


## La courbe (pour la visée) : des points tous les `pas` s jusqu'au sol (y = sol).
static func courbe(de: Vector3, vitesse_depart: Vector3, sol := 0.0, pas := 0.06) -> PackedVector3Array:
	var r := PackedVector3Array()
	var t := 0.0
	while t <= DUREE_MAX:
		var p := point(de, vitesse_depart, t)
		r.append(p)
		if p.y <= sol and t > 0.0:
			break
		t += pas
	return r


## Où est touché un corps (position aux pieds `pied`) par un point : "tete", "corps" ou "".
static func zone_touchee(p: Vector3, pied: Vector3) -> String:
	if p.distance_to(pied + Vector3(0, TETE_Y, 0)) < TETE_R:
		return "tete"
	var h := Vector2(p.x - pied.x, p.z - pied.z).length()
	if h < CORPS_R and p.y >= pied.y + CORPS_BAS and p.y <= pied.y + CORPS_HAUT:
		return "corps"
	return ""


## Ce que provoque un caillou qui arrive sur un corps (Edwin, 01/11 : « le lancer dans la tête n'a rien provoqué »).
## `zone` : "tete", "corps" ou "" (au sol). Renvoie {son, bascule (radians, la tête part en arrière), etoiles,
## secousse (la vue du touché), message_touche (au touché), message_lanceur}. Vide : rien.
static func reaction(zone: String) -> Dictionary:
	if zone == "tete":
		return {"son": "toc", "bascule": 0.5, "etoiles": true, "secousse": 0.1,
			"message_touche": "Aïe ! Un caillou en pleine tête.", "message_lanceur": "Dans la tête !"}
	if zone == "corps":
		return {"son": "choc", "bascule": 0.0, "etoiles": false, "secousse": 0.07,
			"message_touche": "", "message_lanceur": "Touché !"}
	return {}


## Vole : `cibles` = [[id, pieds]…] (sans le lanceur). `obstacle` : (a, b) -> Vector3 (le premier
## mur rencontré) ou null ; `sol` : (x, z) -> hauteur du sol.
## Renvoie {fin, duree, touche (-1 : personne), zone ("tete" | "corps" | ""), v0}.
static func simuler(de: Vector3, vitesse_depart: Vector3, cibles: Array, sol := Callable(), obstacle := Callable()) -> Dictionary:
	var t := 0.0
	var avant := de
	while t < DUREE_MAX:
		t += PAS
		var p := point(de, vitesse_depart, t)
		# Un coup de caillou entre deux pas : on regarde tous les 10 cm.
		var n := maxi(int(avant.distance_to(p) / 0.1), 1)
		for k in range(1, n + 1):
			var q := avant.lerp(p, float(k) / n)
			if t > 0.06:
				for c: Array in cibles:
					var z := zone_touchee(q, c[1])
					if z != "":
						return {"fin": q, "duree": t - PAS + PAS * float(k) / n, "touche": int(c[0]), "zone": z, "v0": vitesse_depart}
		if obstacle.is_valid():
			var mur: Variant = obstacle.call(avant, p)
			if mur is Vector3:
				# Il retombe un peu en retrait du mur : jamais collé ni enfoncé dedans (on le reprend).
				var recul: Vector3 = (avant - (mur as Vector3))
				recul.y = 0.0
				var fin_mur: Vector3 = mur
				if recul.length() > 0.001:
					fin_mur += recul.normalized() * minf(Depose.RECUL_MUR, recul.length())
				return {"fin": fin_mur, "duree": t, "touche": -1, "zone": "", "v0": vitesse_depart}
		var y_sol: float = sol.call(p.x, p.z) if sol.is_valid() else 0.0
		if p.y <= y_sol and t > PAS:
			var f := clampf((avant.y - y_sol) / maxf(avant.y - p.y, 0.0001), 0.0, 1.0)
			var fin := avant.lerp(p, f)
			fin.y = y_sol
			return {"fin": fin, "duree": t - PAS + PAS * f, "touche": -1, "zone": "", "v0": vitesse_depart}
		avant = p
	return {"fin": avant, "duree": t, "touche": -1, "zone": "", "v0": vitesse_depart}


## L'hôte accepte-t-il ce lancer ? (vivant, ni la nuit ni au salon, ni en quête dans une clairière)
static func peut_lancer(phase: String, vivant: bool, en_quete: bool) -> bool:
	return vivant and not en_quete and not PHASES_SANS_LANCER.has(phase)


## D'où vient le coup, vu de moi : 0 = devant, +PI/2 = à ma droite, PI = derrière.
## `yaw` : la rotation Y de mon corps.
static func angle_depuis(source: Vector3, ma_pos: Vector3, yaw: float) -> float:
	var local := Basis(Vector3.UP, yaw).inverse() * (source - ma_pos)
	return atan2(local.x, -local.z)
