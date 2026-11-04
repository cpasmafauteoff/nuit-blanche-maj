class_name CinemaLoup
extends Node3D
## Le loup de la cinématique : une bête sombre en primitives, animée par code.
## Il regarde vers -Z (comme look_at) ; l'origine est au sol, sous le ventre.
## `poser(phase, gueule, tendu)` règle la course (phase), la gueule (0 à 1) et l'élan du bond (0 à 1).

var _pattes: Array[Dictionary] = []     # {hanche, genou, avant, decal}
var _cou: Node3D
var _tete: Node3D
var _machoire: Node3D
var _queue: Node3D
var _corps: Node3D
var lueur: OmniLight3D


func _ready() -> void:
	_construire()


func _forme(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _cone(h: float, r_haut: float, r_bas: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.height = h
	c.top_radius = r_haut
	c.bottom_radius = r_bas
	c.radial_segments = 10
	c.rings = 1
	return c


func _construire() -> void:
	var poil := Bouille.materiau(Color(0.2, 0.18, 0.17), 0.0)
	var poil2 := Bouille.materiau(Color(0.34, 0.32, 0.3), 0.0)
	var dent := Bouille.materiau(Color(0.95, 0.92, 0.8), 0.0)
	var braise := Bouille.materiau(Color(1.0, 0.75, 0.2), 0.0, Color(1.0, 0.55, 0.1))
	braise.emission_energy_multiplier = 5.0
	_corps = Node3D.new()
	add_child(_corps)
	# Le tronc : poitrail large, flanc étroit, croupe.
	var torse := Bouille.sphere(0.3, poil, Vector3(0.75, 0.85, 1.7))
	torse.position = Vector3(0, 0.72, 0.0)
	_corps.add_child(torse)
	var poitrail := Bouille.sphere(0.3, poil, Vector3(0.85, 1.05, 1.0))
	poitrail.position = Vector3(0, 0.76, -0.36)
	_corps.add_child(poitrail)
	var criniere := Bouille.sphere(0.26, poil2, Vector3(0.95, 0.8, 1.2))
	criniere.position = Vector3(0, 0.95, -0.38)
	_corps.add_child(criniere)
	var croupe := Bouille.sphere(0.27, poil, Vector3(0.9, 1.0, 1.0))
	croupe.position = Vector3(0, 0.72, 0.4)
	_corps.add_child(croupe)
	# Le cou et la tête.
	_cou = Node3D.new()
	_cou.position = Vector3(0, 0.86, -0.52)
	_corps.add_child(_cou)
	_forme(_cou, _cone(0.34, 0.12, 0.2), poil, Vector3(0, 0.0, -0.17), Vector3(-PI * 0.5 + 0.35, 0, 0))
	_tete = Node3D.new()
	_tete.position = Vector3(0, 0.07, -0.36)
	_cou.add_child(_tete)
	var crane := Bouille.sphere(0.14, poil, Vector3(0.9, 0.85, 1.1))
	_tete.add_child(crane)
	_forme(_tete, _cone(0.3, 0.045, 0.09), poil, Vector3(0, -0.03, -0.2), Vector3(-PI * 0.5 + 0.12, 0, 0))
	var truffe := Bouille.sphere(0.03, Bouille.materiau(Color(0.02, 0.02, 0.02), 0.0))
	truffe.position = Vector3(0, -0.01, -0.36)
	_tete.add_child(truffe)
	_machoire = Node3D.new()
	_machoire.position = Vector3(0, -0.07, -0.08)
	_tete.add_child(_machoire)
	_forme(_machoire, _cone(0.26, 0.035, 0.07), poil, Vector3(0, -0.01, -0.13), Vector3(-PI * 0.5 + 0.03, 0, 0))
	for c: int in [-1, 1]:
		# Les crocs, en haut et en bas.
		_forme(_tete, _cone(0.075, 0.0, 0.016), dent, Vector3(c * 0.035, -0.095, -0.3), Vector3(PI, 0, 0))
		_forme(_machoire, _cone(0.06, 0.0, 0.014), dent, Vector3(c * 0.03, 0.04, -0.22))
		_forme(_tete, _cone(0.17, 0.0, 0.06), poil, Vector3(c * 0.075, 0.15, 0.02), Vector3(-0.2, 0, -c * 0.25))
		var oeil := Bouille.sphere(0.024, braise, Vector3(1.3, 0.7, 1.0))
		oeil.position = Vector3(c * 0.07, 0.04, -0.12)
		oeil.rotation.y = -c * 0.5
		_tete.add_child(oeil)
	lueur = OmniLight3D.new()
	lueur.light_color = Color(1.0, 0.3, 0.1)
	lueur.omni_range = 2.2
	lueur.light_energy = 0.0
	lueur.position = Vector3(0, 0.0, -0.3)
	_tete.add_child(lueur)
	# La queue, basse et touffue.
	_queue = Node3D.new()
	_queue.position = Vector3(0, 0.78, 0.62)
	_corps.add_child(_queue)
	_forme(_queue, _cone(0.55, 0.03, 0.09), poil, Vector3(0, 0, 0.26), Vector3(PI * 0.5 + 0.45, 0, 0))
	# Quatre pattes : hanche, genou, pied.
	for k in 4:
		var avant := k < 2
		var cote := -1.0 if k % 2 == 0 else 1.0
		var hanche := Node3D.new()
		hanche.position = Vector3(cote * 0.16, 0.66, -0.4 if avant else 0.42)
		_corps.add_child(hanche)
		_forme(hanche, _cone(0.36, 0.04, 0.075 if avant else 0.09), poil, Vector3(0, -0.17, 0))
		var genou := Node3D.new()
		genou.position = Vector3(0, -0.34, 0)
		hanche.add_child(genou)
		_forme(genou, _cone(0.34, 0.03, 0.045), poil, Vector3(0, -0.17, 0))
		var pied := Bouille.sphere(0.06, poil, Vector3(1.0, 0.7, 1.7))
		pied.position = Vector3(0, -0.35, -0.04)
		genou.add_child(pied)
		_pattes.append({"hanche": hanche, "genou": genou, "avant": avant, "decal": 0.0 if k < 2 else PI * 0.9})


## Règle toute la bête. phase : course ; gueule : 0 fermée, 1 grande ouverte ; tendu : 0 course, 1 corps étiré en plein bond.
func poser(phase: float, gueule: float, tendu: float) -> void:
	var cadence := 1.0 - tendu
	for p: Dictionary in _pattes:
		var s := sin(phase + float(p["decal"]))
		var c := cos(phase + float(p["decal"]))
		var avant: bool = p["avant"]
		var balancier := 0.85 * s * cadence
		var plie := (0.55 + 0.55 * c) * cadence
		if avant:
			(p["hanche"] as Node3D).rotation.x = balancier + 0.95 * tendu
			(p["genou"] as Node3D).rotation.x = -plie - 0.1 * tendu
		else:
			(p["hanche"] as Node3D).rotation.x = balancier - 1.05 * tendu
			(p["genou"] as Node3D).rotation.x = -plie - 0.3 * tendu
	_corps.position.y = 0.06 * cadence * absf(sin(phase)) - 0.02
	_corps.rotation.x = 0.07 * sin(phase) * cadence
	_cou.rotation.x = 0.2 - 0.35 * tendu - 0.1 * sin(phase) * cadence
	_machoire.rotation.x = -gueule * 0.75
	_queue.rotation.x = -0.5 * tendu + 0.15 * sin(phase * 0.5)
