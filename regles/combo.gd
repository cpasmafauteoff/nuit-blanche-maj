class_name Combo
extends RefCounted
## Le combo du loup qui marche sans bruit. Deux façons selon le sol :
## - « suite » (graviers, planches) : enchaîner des flèches dans l'ordre, vite ;
## - « rythme » (flaques, feuilles) : appuyer sur Espace en cadence, sur chaque battement.
## Raté = un bruit. Terre battue et place : aucun combo.

const FLECHES := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
const TEMPS_PAR_FLECHE := 0.75
const PERIODE := 0.55
const FENETRE := 0.15

const MODES := {"graviers": "suite", "planches": "suite", "flaques": "rythme", "feuilles": "rythme"}
const BASE := {"graviers": 3, "planches": 4, "flaques": 4, "feuilles": 5}

var mode := ""
var attendu: Array[int] = []     # flèches (suite)
var battements := 0              # nombre de battements (rythme)
var index := 0                   # flèches ou battements réussis
var temps := 0.0
var etat := "en_cours"           # en_cours, reussi, rate


static func mode_du_sol(sol: String) -> String:
	return MODES.get(sol, "")


## Plus on court, plus c'est long ; la faim et une porte gardée allongent encore.
static func longueur(sol: String, course: bool, faim: int, gardee: bool) -> int:
	var n: int = BASE.get(sol, 0)
	if n == 0:
		return 0
	n += 2 if course else 0
	n += mini(faim, 3)
	return n * 2 if gardee else n


func _init(mode_voulu: String, n: int, rng: RandomNumberGenerator) -> void:
	mode = mode_voulu
	if mode == "suite":
		for i in n:
			attendu.append(FLECHES[rng.randi_range(0, 3)])
	else:
		battements = n


func total() -> int:
	return attendu.size() if mode == "suite" else battements


func appuyer(touche: int) -> void:
	if etat != "en_cours":
		return
	if mode == "suite":
		if not FLECHES.has(touche):
			return
		if touche == attendu[index]:
			index += 1
			if index >= attendu.size():
				etat = "reussi"
		else:
			etat = "rate"
		return
	if touche != KEY_SPACE:
		return
	var cible := PERIODE * (index + 1)
	if absf(temps - cible) <= FENETRE:
		index += 1
		if index >= battements:
			etat = "reussi"
	else:
		etat = "rate"


func avancer(dt: float) -> void:
	if etat != "en_cours":
		return
	temps += dt
	if mode == "suite":
		if temps > TEMPS_PAR_FLECHE * attendu.size():
			etat = "rate"
	elif temps > PERIODE * (index + 1) + FENETRE:
		etat = "rate"


## Pour l'affichage du rythme : 0 juste après un battement, 1 au battement suivant.
func phase_battement() -> float:
	return clampf((temps - PERIODE * index) / PERIODE, 0.0, 1.0)


func temps_restant() -> float:
	return maxf(TEMPS_PAR_FLECHE * attendu.size() - temps, 0.0)
