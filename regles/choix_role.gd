class_name ChoixRole
extends RefCounted
## Le choix du rôle unique d'une quête (marcheur, guide, lecteur…) par une ZONE au sol : le
## premier joueur qui s'y met prend le rôle ; si personne n'y entre avant la fin du délai, le
## hasard désigne quelqu'un (un bot compris). Aucun nœud ici : l'hôte donne, à chaque image, la
## liste de ceux qui sont dans la zone (cf. Meneur._tick_role, tests/test_choix_role.gd).

var ids: Array[int] = []
var delai := 15.0
var reste := 15.0
var elu := -1
var par_hasard := false
var _rng: RandomNumberGenerator
var _entrees := {}      # id -> rang d'entrée dans la zone
var _compte := 0


func _init(ids_: Array, delai_: float, rng: RandomNumberGenerator) -> void:
	ids.assign(ids_)
	delai = delai_
	reste = delai_
	_rng = rng


## Un pas de temps. `dedans` : ceux qui se tiennent dans la zone à cet instant.
func avancer(delta: float, dedans: Array) -> void:
	if elu >= 0 or ids.is_empty():
		return
	for id in dedans:
		if ids.has(id) and not _entrees.has(id):
			_entrees[id] = _compte
			_compte += 1
	var premier := -1
	for id in dedans:
		if ids.has(id) and (premier < 0 or int(_entrees[id]) < int(_entrees[premier])):
			premier = id
	if premier >= 0:
		elu = premier
		return
	reste = maxf(reste - delta, 0.0)
	if reste <= 0.0:
		elu = ids[_rng.randi_range(0, ids.size() - 1)]
		par_hasard = true
