class_name Familier
extends Node3D
## Le familier acheté à la roulotte (cf. Cosmetiques) : il suit son maître partout, même mort.
## Corbeau sur l'épaule (il s'envole quand on court), chat noir dans les pas, chouette qui tourne
## au-dessus de la tête, rat qui trottine derrière. Construit en code, sauf le rat (Poly Haven, CC0).

const RAT := preload("res://modeles/nature/street_rat/street_rat.gltf")

var sorte := "corbeau"
var maitre: Bouille

var _corps: Node3D
var _ailes: Array[Node3D] = []
var _pattes: Array[Node3D] = []
var _queue: Array[Node3D] = []
var _tete: Node3D
var _t := randf() * 10.0
var _vol := 0.0           # 0 posé, 1 en vol (corbeau)
var _immobile := 0.0
var _vitesse := Vector3.ZERO
var _assis := 0.0
var _etendue := 0.0       # ouverture des ailes (0 repliées, 1 déployées)
var _cap_lisse := 0.0


func _ready() -> void:
	top_level = true
	_corps = Node3D.new()
	add_child(_corps)
	match sorte:
		"corbeau":
			_oiseau(Color(0.025, 0.025, 0.035), Color(0.15, 0.16, 0.18), 2.3, false)
		"chouette":
			_oiseau(Color(0.42, 0.32, 0.2), Color(0.9, 0.55, 0.1), 2.6, true)
		"chat":
			_chat()
		"rat":
			var r := RAT.instantiate() as Node3D
			r.scale = Vector3.ONE * 2.4
			r.rotation.y = PI
			_corps.add_child(r)
	if maitre:
		global_position = maitre.global_position + Vector3(0.6, 0, -0.6)


func _m(c: Color, rugueux := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugueux
	m.metallic = metal
	m.rim_enabled = true
	m.rim = 0.25
	return m


func _boule(p: Node3D, r: float, mat: Material, pos: Vector3, ech := Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 18
	s.rings = 9
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = mat
	mi.position = pos
	mi.scale = ech
	p.add_child(mi)
	return mi


func _cone(p: Node3D, r_haut: float, r_bas: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_haut
	c.bottom_radius = r_bas
	c.height = h
	c.radial_segments = 12
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


## Une aile faite de rémiges : des plumes en éventail qui partent de l'épaule vers le côté (x), du bord
## d'attaque (devant) au bord de fuite (derrière). Repliée, elle pend le long du flanc, bout vers l'arrière.
func _aile(p: Node3D, cote: int, plume: Material, longueur: float) -> Node3D:
	var a := Node3D.new()
	a.position = Vector3(cote * 0.052, 0.085, 0.01)
	a.set_meta("cote", cote)
	p.add_child(a)
	for k in 7:
		var f := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var l := longueur * (1.0 - k * 0.075)
		bm.size = Vector3(l, 0.004, 0.026)
		f.mesh = bm
		f.material_override = plume
		f.position = Vector3(cote * l * 0.5, 0.0, -k * 0.019)
		f.rotation.y = cote * k * 0.05
		a.add_child(f)
	_ailes.append(a)
	return a


func _oiseau(plumage: Color, bec_c: Color, taille: float, chouette: bool) -> void:
	var plume := _m(plumage, 0.38 if not chouette else 0.8, 0.15 if not chouette else 0.0)
	var o := Node3D.new()
	o.scale = Vector3.ONE * taille
	_corps.add_child(o)
	_boule(o, 0.06, plume, Vector3(0, 0.07, 0), Vector3(0.85, 0.9, 1.35) if not chouette else Vector3(1.0, 1.25, 0.95))
	if chouette:
		_boule(o, 0.05, _m(Color(0.82, 0.76, 0.66), 0.85), Vector3(0, 0.06, 0.03), Vector3(0.9, 1.15, 0.6))   # poitrail
	_tete = Node3D.new()
	_tete.position = Vector3(0, 0.13, 0.05) if not chouette else Vector3(0, 0.15, 0.0)
	o.add_child(_tete)
	_boule(_tete, 0.04 if not chouette else 0.055, plume, Vector3.ZERO, Vector3(0.9, 0.95, 1.1) if not chouette else Vector3(1.1, 0.9, 0.95))
	var bec := _m(bec_c, 0.3, 0.2)
	if chouette:
		var disque := _m(Color(0.88, 0.82, 0.7), 0.85)
		for c: int in [-1, 1]:
			_boule(_tete, 0.026, disque, Vector3(c * 0.024, 0.0, 0.04), Vector3(1, 1, 0.4))
			var iris := _m(Color(1.0, 0.6, 0.05), 0.1)
			iris.emission_enabled = true
			iris.emission = Color(1.0, 0.5, 0.0)
			iris.emission_energy_multiplier = 0.8
			_boule(_tete, 0.014, iris, Vector3(c * 0.024, 0.003, 0.05), Vector3(1, 1, 0.5))
			_boule(_tete, 0.007, _m(Color(0, 0, 0), 0.05), Vector3(c * 0.024, 0.003, 0.057), Vector3(1, 1, 0.4))
			_cone(_tete, 0.0, 0.012, 0.035, plume, Vector3(c * 0.032, 0.05, 0.0), Vector3(0, 0, -c * 0.4))   # aigrettes
		_cone(_tete, 0.0, 0.009, 0.022, bec, Vector3(0, -0.015, 0.05), Vector3(PI / 2 + 0.6, 0, 0))
	else:
		_cone(_tete, 0.0, 0.013, 0.06, bec, Vector3(0, -0.005, 0.065), Vector3(PI / 2, 0, 0))
		for c: int in [-1, 1]:
			_boule(_tete, 0.007, _m(Color(0.02, 0.02, 0.02), 0.05, 0.5), Vector3(c * 0.025, 0.012, 0.02))
	for c: int in [-1, 1]:
		_aile(o, c, plume, 0.13 if not chouette else 0.15)
		var patte := _cone(o, 0.004, 0.004, 0.05, bec, Vector3(c * 0.018, 0.0, 0.0))
		_pattes.append(patte)
	for k in 5:
		var q := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.012, 0.004, 0.09 if not chouette else 0.06)
		q.mesh = bm
		q.material_override = plume
		q.position = Vector3((k - 2) * 0.008, 0.055, -0.1)
		q.rotation = Vector3(0.35, (k - 2) * 0.12, 0)
		o.add_child(q)


func _chat() -> void:
	var poil := _m(Color(0.03, 0.03, 0.035), 0.75)
	var c := Node3D.new()
	_corps.add_child(c)
	_boule(c, 0.1, poil, Vector3(0, 0.2, 0), Vector3(0.8, 0.75, 1.55))
	_tete = Node3D.new()
	_tete.position = Vector3(0, 0.29, 0.16)
	c.add_child(_tete)
	_boule(_tete, 0.065, poil, Vector3.ZERO, Vector3(1.05, 0.92, 0.95))
	_boule(_tete, 0.03, poil, Vector3(0, -0.02, 0.05), Vector3(1.1, 0.8, 0.9))
	for s: int in [-1, 1]:
		_cone(_tete, 0.0, 0.025, 0.05, poil, Vector3(s * 0.035, 0.065, -0.005), Vector3(-0.15, 0, -s * 0.35))
		var oeil := _m(Color(0.75, 0.9, 0.15), 0.1)
		oeil.emission_enabled = true
		oeil.emission = Color(0.6, 0.85, 0.1)
		oeil.emission_energy_multiplier = 1.6
		_boule(_tete, 0.014, oeil, Vector3(s * 0.027, 0.012, 0.055), Vector3(1, 1, 0.5))
		_boule(_tete, 0.004, _m(Color(0, 0, 0)), Vector3(s * 0.027, 0.012, 0.062), Vector3(0.4, 1.4, 0.5))
	for k in 4:
		var avant := k < 2
		var cote := -1 if k % 2 == 0 else 1
		var hanche := Node3D.new()
		hanche.position = Vector3(cote * 0.05, 0.19, 0.1 if avant else -0.1)
		c.add_child(hanche)
		_cone(hanche, 0.016, 0.022, 0.18, poil, Vector3(0, -0.09, 0))
		_boule(hanche, 0.02, poil, Vector3(0, -0.18, 0.01), Vector3(1, 0.6, 1.3))
		_pattes.append(hanche)
	var base := Node3D.new()
	base.position = Vector3(0, 0.24, -0.16)
	c.add_child(base)
	var p := base
	for k in 7:
		var seg := Node3D.new()
		seg.position = Vector3(0, 0.0, -0.045) if k > 0 else Vector3.ZERO
		p.add_child(seg)
		_boule(seg, 0.018 - k * 0.0012, poil, Vector3(0, 0, -0.022), Vector3(1, 1, 1.6))
		_queue.append(seg)
		p = seg


func _process(delta: float) -> void:
	if maitre == null or not is_instance_valid(maitre):
		return
	_t += delta
	var marche := maitre._marche
	_immobile = _immobile + delta if marche < 0.1 else 0.0
	# À plat : couché dans son lit ou sur l'autel, le maître regarde le ciel, et un look_at
	# vers le haut n'a plus de sens (avertissement « colinear » à chaque image).
	var fwd := maitre.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.BACK
	match sorte:
		"corbeau":
			_corbeau(delta, marche, fwd)
		"chouette":
			_chouette(delta, fwd)
		"chat", "rat":
			_au_sol(delta, marche, fwd)


## Pose des ailes : `etendue` 0 repliées le long du flanc, 1 déployées ; `battement` : angle ajouté (rad).
func _poser_ailes(etendue: float, battement: float) -> void:
	for ai: Node3D in _ailes:
		var c: float = float(ai.get_meta("cote"))
		ai.rotation = Vector3(0.0, c * lerpf(0.55, 0.12, etendue), c * (lerpf(-1.3, 0.1, etendue) + battement))


func _battre(vitesse: float, amplitude: float) -> void:
	_etendue = lerpf(_etendue, 1.0, 0.25)
	_poser_ailes(_etendue, sin(_t * vitesse) * amplitude * 0.8)


func _replier() -> void:
	_etendue = lerpf(_etendue, 0.0, 0.2)
	_poser_ailes(_etendue, 0.0)


func _corbeau(delta: float, marche: float, fwd: Vector3) -> void:
	var epaule := maitre._torse.global_transform * Vector3(0.16, 1.5, -0.02) if maitre._torse else maitre.global_position + Vector3(0, 1.5, 0)
	if marche > 1.05:
		_vol = minf(_vol + delta * 1.5, 1.0)
	elif _immobile > 1.2:
		_vol = maxf(_vol - delta * 0.8, 0.0)
	var a := _t * 1.3
	var en_l_air := maitre.global_position + Vector3(cos(a) * 1.6, 3.0 + sin(_t * 2.0) * 0.25, sin(a) * 1.6)
	var cible := epaule.lerp(en_l_air, smoothstep(0.0, 1.0, _vol))
	global_position = global_position.lerp(cible, clampf(delta * (14.0 if _vol < 0.05 else 4.0), 0, 1))
	if _vol > 0.05:
		var tangente := Vector3(-sin(a), 0, cos(a))
		look_at(global_position + tangente, Vector3.UP)
		rotate_object_local(Vector3.UP, PI)
		_battre(16.0, 0.9)
	else:
		look_at(global_position + fwd, Vector3.UP)
		rotate_object_local(Vector3.UP, PI)
		_replier()
		# Il tourne la tête par à-coups, comme les vrais.
		if _tete:
			_tete.rotation.y = round(sin(_t * 0.7) * 3.0) * 0.3
			_tete.rotation.x = 0.2 if fmod(_t, 4.0) < 0.15 else 0.0


## Elle reste en vol, mais sur place : derrière l'épaule du maître, un peu au-dessus, elle flotte et bat
## doucement des ailes. Elle regarde dans le sens du maître ; sa tête se tourne vers le joueur le plus
## proche (ou vers la caméra des autres), c'est tout.
func _chouette(delta: float, fwd: Vector3) -> void:
	var droite := fwd.cross(Vector3.UP).normalized()
	var flotte := sin(_t * 1.7) * 0.06
	var cible := maitre.global_position - fwd * 0.85 + droite * 0.5 + Vector3(0, 2.0 + flotte, 0)
	global_position = global_position.lerp(cible, clampf(delta * 2.5, 0, 1))
	var cap := atan2(fwd.x, fwd.z)
	_cap_lisse = lerp_angle(_cap_lisse, cap, clampf(delta * 3.0, 0, 1))
	rotation = Vector3(0.0, _cap_lisse, 0.0)
	_etendue = lerpf(_etendue, 0.8, 0.1)
	_poser_ailes(_etendue, sin(_t * 9.0) * 0.28 + 0.1)
	if _tete:
		var voir := _qui_regarder()
		if voir != Vector3.INF:
			var vers := _tete.global_position.direction_to(voir)
			var local := global_transform.basis.inverse() * vers
			_tete.rotation.y = lerp_angle(_tete.rotation.y, clampf(atan2(local.x, local.z), -1.9, 1.9), clampf(delta * 4.0, 0, 1))
		else:
			_tete.rotation.y = lerp_angle(_tete.rotation.y, 0.0, clampf(delta * 2.0, 0, 1))


## Le joueur proche à fixer (à moins de 6 m, hors son maître), ou Vector3.INF.
func _qui_regarder() -> Vector3:
	var meilleur := Vector3.INF
	var d_min := 6.0
	if maitre.get_parent() == null:
		return meilleur
	for n: Node in maitre.get_parent().get_children():
		var b := n as Bouille
		if b == null or b == maitre or not b.is_visible_in_tree():
			continue
		var d := b.global_position.distance_to(global_position)
		if d < d_min:
			d_min = d
			meilleur = b.global_position + Vector3(0, 1.6, 0)
	return meilleur


func _au_sol(delta: float, marche: float, fwd: Vector3) -> void:
	var droite := fwd.cross(Vector3.UP).normalized()
	var ecart := 0.7 if sorte == "chat" else 0.55
	var cible := maitre.global_position - fwd * ecart + droite * (0.45 if sorte == "chat" else -0.55)
	cible.y = maitre.global_position.y
	var vers := cible - global_position
	vers.y = 0.0
	var vit := vers * (3.2 if sorte == "chat" else 4.5)
	if vit.length() > 4.5:
		vit = vit.normalized() * 4.5
	_vitesse = _vitesse.lerp(vit, clampf(delta * 6.0, 0, 1))
	global_position += _vitesse * delta
	global_position.y = maitre.global_position.y
	var v := _vitesse.length()
	if v > 0.15:
		look_at(global_position + _vitesse, Vector3.UP)
		rotate_object_local(Vector3.UP, PI)
	elif sorte == "chat":
		var vers_maitre := maitre.global_position - global_position
		vers_maitre.y = 0
		if vers_maitre.length() > 0.1:
			var voulu := global_transform.looking_at(global_position + vers_maitre, Vector3.UP).rotated_local(Vector3.UP, PI)
			global_transform = global_transform.interpolate_with(voulu, clampf(delta * 2.0, 0, 1))
	var pas := _t * (9.0 + v * 4.0)
	if sorte == "chat":
		_assis = lerpf(_assis, 1.0 if v < 0.1 and _immobile > 0.8 else 0.0, clampf(delta * 3.0, 0, 1))
		_corps.rotation.x = -0.45 * _assis
		_corps.position.y = -0.04 * _assis
		for i in _pattes.size():
			var phase := 0.0 if i in [0, 3] else PI
			_pattes[i].rotation.x = sin(pas + phase) * 0.6 * minf(v, 1.0) + (0.55 * _assis if i >= 2 else -0.25 * _assis)
		for i in _queue.size():
			_queue[i].rotation.x = 0.25 + sin(_t * 2.0 - i * 0.6) * 0.12 - (0.35 * _assis if i < 2 else 0.0)
			_queue[i].rotation.y = sin(_t * 1.3 - i * 0.5) * 0.25
		if _tete:
			_tete.rotation.y = sin(_t * 0.4) * 0.4
	else:
		_corps.position.y = absf(sin(pas)) * 0.02 * minf(v, 1.0)
		_corps.rotation.y = sin(_t * 0.9) * 0.1 if v < 0.1 else 0.0
