class_name ObjetMain
extends Node3D
## Un objet qu'on tient en main, à la première personne : il est collé à la caméra, en bas à droite,
## se balance un peu quand on marche, et s'incline quand on le bascule (verser un pot).
## Générique : n'importe quel jeu de quête peut y poser un modèle (`tenir`), régler son inclinaison
## (`incliner`, en radians, 0 = droit) et demander où est « sa bouche » dans le monde (`bouche`).
## À attacher comme enfant de la caméra du joueur.

const BASE := Vector3(0.3, -0.32, -0.6)

var _objet: Node3D
var _bouche_locale := Vector3.ZERO
var _incl := 0.0
var _incl_but := 0.0
var _t := 0.0
var _marche := 0.0                   # 0..1 : à quel point on est en train de marcher (balancement)
var _derniere := Vector3.INF


func _init() -> void:
	position = BASE


## Pose l'objet à tenir (il devient notre enfant). `bouche` : le point par où il se vide (repère de l'objet).
func tenir(objet: Node3D, bouche: Vector3 = Vector3.ZERO) -> void:
	lacher()
	_objet = objet
	_bouche_locale = bouche
	add_child(objet)
	_incl = 0.0
	_incl_but = 0.0


func lacher() -> void:
	if _objet != null and is_instance_valid(_objet):
		_objet.queue_free()
	_objet = null


func tient() -> bool:
	return _objet != null


## L'angle d'inclinaison voulu (0 droit, ~2 renversé vers l'avant).
func incliner(angle: float) -> void:
	_incl_but = angle


func inclinaison() -> float:
	return _incl


## Où se trouve la bouche de l'objet dans le monde (là d'où le liquide sort).
func bouche() -> Vector3:
	return _objet.to_global(_bouche_locale) if _objet != null else global_position


func _process(delta: float) -> void:
	_t += delta
	var ici := global_position
	if _derniere != Vector3.INF:
		var v := Vector2(ici.x - _derniere.x, ici.z - _derniere.z).length() / maxf(delta, 0.001)
		_marche = lerpf(_marche, clampf(v / 3.0, 0.0, 1.0), minf(1.0, delta * 6.0))
	_derniere = ici
	_incl = lerpf(_incl, _incl_but, minf(1.0, delta * 14.0))
	if _objet != null:
		# On avance la main vers l'avant quand on penche, et on la remonte un peu.
		var pas := sin(_t * 9.0) * 0.012 * _marche
		position = BASE + Vector3(0.0, pas + sin(_t * 1.6) * 0.004 + 0.34 * clampf(_incl / 2.0, 0.0, 1.0), -0.12 * clampf(_incl / 2.0, 0.0, 1.0) + absf(pas))
		_objet.rotation = Vector3(-_incl, 0.15 * clampf(_incl, 0.0, 1.0), sin(_t * 1.3) * 0.015)
