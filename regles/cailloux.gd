class_name Cailloux
extends RefCounted
## Où posent les cailloux du village : sur la terre, jamais dans ni contre une maison, ni sur le temple,
## le tableau, devant une porte, ni sur les chemins de passage de la forêt (au-delà du chemin de ronde).
## Tout se teste sans moteur (tests/test_cailloux.gd).

const DEGAGE_MAISON := 3.9      # du centre d'une maison (la façade s'arrête à ~3,3 m en diagonale)
const DEGAGE_TEMPLE := 5.0
const DEGAGE_TABLEAU := 3.0
const DEGAGE_PORTE := 1.8
const DEGAGE_FEUILLES := 1.6


static func valide(p: Vector3) -> bool:
	var r := Vector2(p.x, p.z).length()
	if r < Ronde.R_SOUCHES + 1.4 or r > Ronde.R_CHEMIN_MAX - 0.6:
		return false
	if Ronde.hors_village(p, 2.0):
		return false
	for i in Ronde.NB_MAISONS:
		var c := Ronde.centre_maison(i)
		if Vector2(p.x - c.x, p.z - c.z).length() < DEGAGE_MAISON:
			return false
		var d := Ronde.devant_porte(i, "avant")
		if Vector2(p.x - d.x, p.z - d.z).length() < DEGAGE_PORTE:
			return false
	var t := Ronde.centre_temple()
	if Vector2(p.x - t.x, p.z - t.z).length() < DEGAGE_TEMPLE:
		return false
	if Vector2(p.x - Ronde.TABLEAU.x, p.z - Ronde.TABLEAU.z).length() < DEGAGE_TABLEAU:
		return false
	for f in Ronde.tas_de_feuilles():
		if Vector2(p.x - f.x, p.z - f.z).length() < DEGAGE_FEUILLES:
			return false
	return true


## Des emplacements valides tirés au hasard (`n` au plus).
static func tirer(rng: RandomNumberGenerator, n: int) -> Array:
	var r := []
	var essais := 0
	while r.size() < n and essais < n * 60:
		essais += 1
		var a := rng.randf() * TAU
		var rayon := rng.randf_range(Ronde.R_SOUCHES + 1.4, Ronde.R_CHEMIN_MAX - 0.6)
		var p := Vector3(sin(a), 0, cos(a)) * rayon
		if valide(p):
			p.y = Ronde.hauteur_sol(p) + 0.05
			r.append(p)
	return r
