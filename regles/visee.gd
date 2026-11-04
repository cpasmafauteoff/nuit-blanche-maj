class_name Visee
extends RefCounted
## « Est-ce que je regarde ça ? » (Edwin, 01/11 : la touche d'action ne doit pas s'afficher parce qu'on
## est À CÔTÉ de quelque chose, mais parce qu'on le REGARDE). Règle pure : sans nœud, sans rayon physique
## (le mur entre les deux se vérifie à part, cf. principal._vu_des_yeux). Tests : tests/test_visee.gd.

const CONE_DEG := 10.0          # tolérance de base autour du centre de l'écran
const MARGE_DEG := 90.0         # garde-fou : jamais plus que ça, même pour un gros objet


## Le point `cible` est-il visé depuis `origine` en regardant dans la direction `regard` ?
## `portee` : distance maximale (m). `rayon` : taille de l'objet (m) — un gros objet se vise de
## plus loin du centre, un caillou demande plus de précision. `cone_deg` : tolérance de base.
static func vise(origine: Vector3, regard: Vector3, cible: Vector3, portee: float, rayon := 0.0, cone_deg := CONE_DEG) -> bool:
	var vers := cible - origine
	var d := vers.length()
	if d > portee:
		return false
	if d < 0.05 or regard.length() < 0.001:
		return true            # on est dessus
	var tolerance := cone_deg + rad_to_deg(atan2(maxf(rayon, 0.0), d))
	return rad_to_deg(regard.angle_to(vers)) <= minf(tolerance, MARGE_DEG)


## Se tourne-t-on vers un mur ? `axe` : la direction du mur (unitaire), `regard` : le regard, à plat.
## Vrai si on le regarde à ±45° près.
static func vers_le_mur(regard: Vector3, axe: Vector3) -> bool:
	var r := Vector3(regard.x, 0, regard.z)
	var a := Vector3(axe.x, 0, axe.z)
	if r.length() < 0.001 or a.length() < 0.001:
		return false
	return r.normalized().dot(a.normalized()) >= cos(deg_to_rad(45.0))
