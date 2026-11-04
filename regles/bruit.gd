class_name Bruit
extends RefCounted
## Les bruits de la nuit : on sait à peu près d'où ils viennent, jamais de quelle maison.

const ANGLE_MAX := deg_to_rad(60.0)
const SEUIL_DB := -42.0


## Où l'auditeur croit entendre le bruit : même côté à ±60°, distance faussée.
## L'Oreille fine (precise) l'entend à sa vraie place.
static func position_entendue(source: Vector3, auditeur: Vector3, rng: RandomNumberGenerator, precise := false) -> Vector3:
	if precise:
		return source
	var d := source - auditeur
	d.y = 0.0
	var tourne := d.rotated(Vector3.UP, rng.randf_range(-ANGLE_MAX, ANGLE_MAX))
	return auditeur + tourne * rng.randf_range(0.7, 1.3) + Vector3(0, source.y, 0)


## -6 dB à chaque doublement de la distance au-delà de 2 m ; un mur coûte 12 dB.
static func volume_db(distance: float, a_travers_mur: bool) -> float:
	var v := -6.0 * log(maxf(distance, 2.0) / 2.0) / log(2.0)
	return v - (12.0 if a_travers_mur else 0.0)


static func audible(distance: float, a_travers_mur: bool) -> bool:
	return volume_db(distance, a_travers_mur) > SEUIL_DB


## Portée d'un bruit localisé (pas, portes, cailloux, cris de fantôme…) : normal jusqu'à UNITE mètres,
## puis le volume s'effondre (atténuation en carré inverse), inaudible à PORTEE.
const UNITE := 2.5
const PORTEE := 26.0


## Le volume (dB, relatif au bruit entendu de tout près) à `distance` mètres de la source.
static func gain_db(distance: float, portee := PORTEE) -> float:
	if distance >= portee:
		return -80.0
	return -40.0 * log(maxf(distance, UNITE) / UNITE) / log(10.0)


## Règle un lecteur 3D pour qu'il suive cette loi (la même que gain_db).
static func regler_3d(a: AudioStreamPlayer3D, portee := PORTEE) -> void:
	a.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	a.unit_size = UNITE
	a.max_distance = portee
