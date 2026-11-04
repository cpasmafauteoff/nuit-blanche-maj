class_name RegardVivant
extends RefCounted
## Les yeux d'un joueur SANS webcam, pour que personne ne le devine : ils clignent tout seuls
## (toutes les 2 à 6 s, parfois deux fois de suite, plus souvent sous stress), les paupières
## retombent un peu de temps en temps, et le regard a de petites saccades autour du point visé.
## Règle pure : le hasard est injecté, le test fixe la graine.

const CLIN_MIN := 2.0
const CLIN_MAX := 6.0
const PART_DOUBLE := 0.15        # un clignement sur sept est suivi d'un second
const DUREE_FERME := 0.07        # la paupière descend en 70 ms…
const DUREE_OUVRE := 0.11        # …et remonte en 110 ms
const BAS_MAX := 0.42            # paupières mi-closes au repos (0 = grand ouvert)

var rng := RandomNumberGenerator.new()
## 0 = calme, 1 = procès, frayeur : on cligne plus vite.
var stress := 0.0
## Fermeture de la paupière à cet instant, 0..1 (clignement compris).
var clignement := 0.0
## Écart du regard au point visé, en radians (x : droite, y : haut).
var saccade := Vector2.ZERO
## Petit balancement de la tête, en unités du capteur.
var balancement := Vector2.ZERO

var _t_clin := 0.0               # temps écoulé dans le clignement en cours (< 0 : aucun)
var _avant_clin := 3.0           # secondes avant le prochain clignement
var _double_en_attente := false
var _bas := 0.0                  # niveau de paupière basse voulu
var _bas_lisse := 0.0
var _avant_bas := 10.0
var _fin_bas := 0.0
var _avant_saccade := 0.5
var _cible_saccade := Vector2.ZERO
var _t := 0.0
var clignements := 0             # compte (tests)


func _init(graine := -1) -> void:
	if graine >= 0:
		rng.seed = graine
	else:
		rng.randomize()
	_t_clin = -1.0
	_avant_clin = _prochain_clin()
	_avant_bas = rng.randf_range(6.0, 20.0)
	_avant_saccade = rng.randf_range(0.2, 1.2)


## Délai avant le prochain clignement : de 2 à 6 s au calme, ~40 % plus court sous stress.
func _prochain_clin() -> float:
	var d := rng.randf_range(CLIN_MIN, CLIN_MAX)
	return d * lerpf(1.0, 0.55, clampf(stress, 0.0, 1.0))


func avancer(dt: float) -> void:
	_t += dt
	# Clignement
	if _t_clin >= 0.0:
		_t_clin += dt
		var total := DUREE_FERME + DUREE_OUVRE
		if _t_clin < DUREE_FERME:
			clignement = _t_clin / DUREE_FERME
		elif _t_clin < total:
			clignement = 1.0 - (_t_clin - DUREE_FERME) / DUREE_OUVRE
		else:
			clignement = 0.0
			_t_clin = -1.0
			if _double_en_attente:
				_double_en_attente = false
				_avant_clin = rng.randf_range(0.12, 0.3)
			else:
				_avant_clin = _prochain_clin()
	else:
		_avant_clin -= dt
		if _avant_clin <= 0.0:
			_t_clin = 0.0
			clignements += 1
			_double_en_attente = rng.randf() < PART_DOUBLE * lerpf(1.0, 1.8, clampf(stress, 0.0, 1.0))
	# Paupières un peu plus basses, par épisodes
	if _bas > 0.0:
		_fin_bas -= dt
		if _fin_bas <= 0.0:
			_bas = 0.0
			_avant_bas = rng.randf_range(8.0, 25.0)
	else:
		_avant_bas -= dt
		if _avant_bas <= 0.0:
			_bas = rng.randf_range(0.2, BAS_MAX)
			_fin_bas = rng.randf_range(1.5, 4.0)
	_bas_lisse = lerpf(_bas_lisse, _bas, clampf(dt * 3.0, 0.0, 1.0))
	# Saccades : le regard saute vite d'un petit écart à l'autre (0,5 à 2,5 degrés, rarement 4).
	_avant_saccade -= dt
	if _avant_saccade <= 0.0:
		_avant_saccade = rng.randf_range(0.25, 1.8)
		var ampleur := deg_to_rad(rng.randf_range(0.4, 2.5) if rng.randf() > 0.12 else rng.randf_range(2.5, 4.0))
		var a := rng.randf() * TAU
		_cible_saccade = Vector2(cos(a), sin(a) * 0.7) * ampleur
	saccade = saccade.lerp(_cible_saccade, clampf(dt * 40.0, 0.0, 1.0))
	balancement = Vector2(sin(_t * 0.37) * 0.6 + sin(_t * 0.91) * 0.4, sin(_t * 0.29 + 1.0) * 0.6 + sin(_t * 1.13) * 0.4) * 0.012


## La fermeture totale des paupières à fournir au capteur (eyeBlink), 0..1.
func fermeture() -> float:
	return clampf(maxf(clignement, _bas_lisse), 0.0, 1.0)
