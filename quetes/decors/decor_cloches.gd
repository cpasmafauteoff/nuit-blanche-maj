extends DecorQuete
## Les Cloches : un beffroi rond au centre, sur un soubassement de pierre, coiffé de tuiles. Une
## cloche de bronze par joueur pend sous la couronne, de son côté, sa corde jusqu'à sa main.
## Devant chacun, un pupitre ; sur le mien, ma partition. Quand je tire ma corde, ma cloche se
## balance ; une fausse note fait trembler tout le beffroi.

var _beffroi: Node3D
var _cloches: Array = []
var _partition: Label3D
var _ma_corde: Node3D
var _prise_pt := Node3D.new()      # le bas de ma corde, là où ma main la saisit
var _balance := 0.0
var _t := 0.0
var _n_vu := -99
var _mv_vu := -1
var _vies_swing: Array = []         # par cloche : amplitude de balancement résiduelle (les cloches des autres)
var _bougies_cloches: Array = []
const GAMME := [0.75, 0.84, 0.94, 1.0, 1.12, 1.26, 1.41, 1.5]   # une note par sonneur (pentatonique)


func construire() -> void:
	meuble = ""
	# Un beffroi rond au centre, le même pour tous : six poteaux sur un soubassement de pierre, une
	# couronne de poutres, un toit conique. Chaque cloche pend du côté de son sonneur.
	_beffroi = Node3D.new()
	add_child(_beffroi)
	var socle := _cylindre(1.55, 0.35, matiere("mousse", 0.6))
	socle.position.y = 0.17
	_beffroi.add_child(socle)
	var bois := matiere("vieux_bois", 1.0)
	# La couronne : 4 sommets par joueur ; les poteaux tombent ENTRE deux sonneurs, jamais devant
	# une cloche (chaque cloche pend au milieu de son côté).
	var nb := 4 * maxi(equipe, 3)
	var couronne: Array[Vector3] = []
	for j in nb:
		var a := TAU * j / nb + PI + TAU * 0.5 / maxi(equipe, 3)
		couronne.append(Vector3(sin(a) * 1.3, 2.75, cos(a) * 1.3))
	for j in nb:
		poutre(couronne[j], couronne[(j + 1) % nb], 0.065, bois, _beffroi)
		if j % 4 == 0:
			poutre(couronne[j] * Vector3(1, 0, 1) + Vector3(0, 0.3, 0), couronne[j] + Vector3(0, 0.1, 0), 0.08, bois, _beffroi)
			# Une jambe de force vers le centre, et un rayon jusqu'au mât.
			poutre(couronne[j] * Vector3(0.95, 0, 0.95) + Vector3(0, 1.9, 0), couronne[j] * Vector3(0.6, 1, 0.6), 0.04, bois, _beffroi)
			poutre(couronne[j], Vector3(0, 2.75, 0), 0.05, bois, _beffroi)
	poutre(Vector3(0, 0.3, 0), Vector3(0, 3.6, 0), 0.1, bois, _beffroi)
	var toit := _cylindre(1.75, 0.9, matiere("tuiles", 1.6, Color(0.72, 0.62, 0.58)), 0.02)
	toit.position.y = 3.3
	_beffroi.add_child(toit)
	# Les cloches : chacune sous la couronne, du côté de son sonneur, sa corde jusqu'à lui.
	for k in equipe:
		var ici := poste(jeu, k, equipe)
		var dir := Vector3(ici.x, 0, ici.z).normalized()
		var p := dir * 1.12 + Vector3(0, 2.68, 0)
		var joug := _boite(Vector3(0.36, 0.1, 0.1), bois)
		joug.position = p + Vector3(0, 0.06, 0)
		joug.basis = Basis.looking_at(dir, Vector3.UP)
		_beffroi.add_child(joug)
		var pivot := Node3D.new()
		pivot.position = p
		pivot.basis = Basis.looking_at(dir, Vector3.UP)
		_beffroi.add_child(pivot)
		cloche_bronze(0.2 if k != rang else 0.24, pivot)
		if k != rang:
			corde(p + Vector3(0, -0.5, 0), _main_de(k, 0.0), 0.12, 0.01, _beffroi)
		pivot.add_to_group("mobile")
		_cloches.append(pivot)
	# Un pupitre devant chaque sonneur ; sur le mien, ma partition.
	for k in equipe:
		var pupitre := _pupitre(k, bois)
		if k == rang:
			_partition = _debout("", 54, Vector3(0, 1.06, 0.03))
			_partition.width = 420.0
			_partition.rotation.x = -0.5
			pupitre.add_child(_partition)
	_ma_corde = Node3D.new()
	add_child(_ma_corde)
	add_child(_prise_pt)
	_batir_clocher()
	for k in equipe:
		_vies_swing.append(0.0)


## Plus grand : un sol dallé sous le beffroi, des vitraux et des arcs derrière, des chandeliers entre les
## sonneurs, un rayon de lune qui tombe du toit.
func _batir_clocher() -> void:
	var pierre := matiere("roche", 0.9, Color(0.5, 0.5, 0.48))
	var dalle := _cylindre(2.6, 0.06, pierre)
	dalle.position.y = 0.03
	dalle.add_to_group("traversable")
	add_child(dalle)
	var rose := anneau(2.45, 0.05, matiere("mousse", 0.6), self)
	rose.position.y = 0.07
	rose.add_to_group("traversable")
	var rose2 := anneau(1.9, 0.03, matiere("mousse", 0.6), self)
	rose2.position.y = 0.07
	rose2.add_to_group("traversable")
	# Des chandeliers entre les sonneurs, loin des cordes.
	for k in equipe:
		var p := entre(k, rayon(equipe) + 0.9)
		bougie(p + Vector3(0, 0.0, 0.0), self)
		bougie(p + Vector3(0, 0.0, 0), self).add_to_group("traversable")
	# Un rayon froid qui tombe du toit du beffroi sur la dalle.
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 5.0, 0)
	spot.rotation.x = -PI / 2
	spot.light_color = Color(0.7, 0.8, 1.0)
	spot.light_energy = 2.5
	spot.spot_range = 7.0
	spot.spot_angle = 38.0
	add_child(spot)
	accessoire("treasure_chest", Vector3(sin(2.0), 0, cos(2.0)) * (rayon(equipe) + 2.4), 1.2, 0.8, 1.8)


func _pupitre(k: int, bois: Material) -> Node3D:
	var ici := poste(jeu, k, equipe)
	var devant := Vector3(-ici.x, 0, -ici.z).normalized()
	var pupitre := Node3D.new()
	pupitre.position = ici + devant * 0.75
	pupitre.basis = Basis.looking_at(devant, Vector3.UP)
	add_child(pupitre)
	poutre(Vector3(0, -0.05, 0), Vector3(0, 1.0, 0), 0.03, bois, pupitre)
	var planche := _boite(Vector3(1.0, 0.28, 0.03), matiere("vieux_bois", 1.0, Color(0.85, 0.8, 0.75)))
	planche.position = Vector3(0, 1.05, 0)
	planche.rotation.x = -0.5
	pupitre.add_child(planche)
	return pupitre


## La main du sonneur k : un peu devant lui, à hauteur de poitrine.
func _main_de(k: int, tire: float) -> Vector3:
	# À droite du pupitre : la corde descend le long de son bord, sans le traverser.
	var ici := poste(jeu, k, equipe)
	var devant := Vector3(-ici.x, 0, -ici.z).normalized()
	return ici + devant * 0.3 + devant.cross(Vector3.UP) * 0.6 + Vector3(0, 1.05 - 0.15 * tire, 0)


func cible_geste() -> Node3D:
	return _prise_pt


func frappe() -> void:
	if _balance < 0.3:
		_balance = 1.0
	# Ma note : ma cloche sonne (une hauteur à elle : à plusieurs, ça fait une mélodie).
	_sonner(rang, 0.0)


## Fait sonner la cloche du sonneur k : sa hauteur, un balancement, un bruit de bronze qui s'éloigne.
func _sonner(k: int, db: float) -> void:
	if k < 0 or k >= _cloches.size() or not is_inside_tree():
		return
	var c: Node3D = _cloches[k]
	var son := AudioStreamPlayer3D.new()
	son.stream = Sons.cloche()
	son.pitch_scale = float(GAMME[k % GAMME.size()])
	son.position = c.position + Vector3(0, 2.0, 0)
	son.unit_size = 8.0
	son.volume_db = -4.0 + db
	son.bus = "Effets" if AudioServer.get_bus_index("Effets") >= 0 else "Master"
	add_child(son)
	son.play()
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(son):
			son.stop()
			son.queue_free())
	if k != rang and k < _vies_swing.size():
		_vies_swing[k] = 1.0


func animer(vue: Dictionary, phase: float, delta: float) -> void:
	_t += delta
	var p := texte_ton(vue, "or")
	if _partition.text != p:
		_partition.text = p
	_balance = move_toward(_balance, 0.0, delta * 1.6)
	for k in _cloches.size():
		var c: Node3D = _cloches[k]
		var balancement := 0.0
		if k == rang:
			balancement = sin(_t * 14.0) * 0.5 * _balance
		else:
			_vies_swing[k] = move_toward(float(_vies_swing[k]), 0.0, delta * 1.1)
			balancement = sin(_t * 12.0) * 0.45 * float(_vies_swing[k]) + sin(maxf(phase, 0.0) * TAU + k) * 0.03
		var ici := poste(jeu, k, equipe)
		c.basis = Basis.looking_at(Vector3(ici.x, 0, ici.z).normalized(), Vector3.UP).rotated(Vector3(ici.z, 0, -ici.x).normalized(), balancement)
	# Ma corde : de ma cloche à mes mains, tirée quand je frappe.
	if rang < _cloches.size() and (_cloches[rang] as Node3D).is_inside_tree():
		var haut := (_cloches[rang] as Node3D).position + Vector3(0, -0.5, 0)
		_prise_pt.position = _main_de(rang, 0.0)
		# Tenue, la corde suit ma main ; lâchée, elle remonte avec la cloche.
		var tire := maxf(_balance, clampf(-main.y * 1.5, 0.0, 1.0) if tenu else 0.0)
		var main := _main_de(rang, tire)
		refaire_corde(_ma_corde, haut, main, 0.1 - 0.08 * _balance, 0.009)
	# Les cloches des autres sonnent à leur temps (on entend la mélodie se construire).
	var cl: Dictionary = vue.get("cloches", {})
	if not cl.is_empty():
		var n := int(cl.get("n", -1))
		var mv := int(cl.get("mv", 0))
		if n != _n_vu or mv != _mv_vu:
			_n_vu = n
			_mv_vu = mv
			var proprio := int(cl.get("proprio", -1))
			if proprio >= 0 and proprio != rang:
				_sonner(proprio, -7.0)
	if nouvelle_annonce(vue):
		secouer(_beffroi, 0.06)
