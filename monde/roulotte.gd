class_name Roulotte
extends Node3D
## La roulotte du colporteur (onglet Cosmétique) : une verdine peinte posée sur la place, son flanc
## ouvert en étal, ses malles, son miroir. Elle n'est là qu'au menu : en partie, la place est libre.
## Repère : +z vers le centre du village (l'étal), +x le long de la roulotte.

const BOIS := "res://modeles/village/T_WoodTrim_BaseColor.png"
const BOIS_N := "res://modeles/village/T_WoodTrim_Normal.png"

var colporteur: Bouille
var _lampes: Array[OmniLight3D] = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1873
	_caisse()
	_etal()
	_devant()
	_colporteur()


func _bois(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(BOIS)
	m.normal_enabled = true
	m.normal_texture = load(BOIS_N)
	m.albedo_color = c
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.9, 0.9, 0.9)
	m.roughness = 0.8
	return m


func _m(c: Color, rugueux := 0.7, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugueux
	m.metallic = metal
	return m


func _boite(p: Node3D, t: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = t
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


func _cyl(p: Node3D, r_h: float, r_b: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO, seg := 20) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_h
	c.bottom_radius = r_b
	c.height = h
	c.radial_segments = seg
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


func _modele(nom: String, pos: Vector3, rot_y := 0.0, echelle := 1.0) -> Node3D:
	var n := (load("res://modeles/nature/%s/%s.gltf" % [nom, nom]) as PackedScene).instantiate() as Node3D
	n.position = pos
	n.rotation.y = rot_y
	n.scale = Vector3.ONE * echelle
	add_child(n)
	return n


## La caisse peinte : vert sombre, filets d'or, toit en berceau, deux roues hautes.
func _caisse() -> void:
	var vert := _bois(Color(0.16, 0.3, 0.22))
	var rouge := _bois(Color(0.5, 0.1, 0.07))
	var or_m := _m(Color(0.78, 0.58, 0.22), 0.3, 0.85)
	var L := 3.4
	var P := 1.9
	var bas := 0.75
	var H := 1.75
	_boite(self, Vector3(L, 0.12, P + 0.1), rouge, Vector3(0, bas, 0))
	# Le flanc arrière et les deux bouts ; le flanc avant est ouvert en étal (cf. _etal).
	_boite(self, Vector3(L, H, 0.08), vert, Vector3(0, bas + H * 0.5, -P * 0.5))
	for s: int in [-1, 1]:
		_boite(self, Vector3(0.08, H, P), vert, Vector3(s * L * 0.5, bas + H * 0.5, 0))
	_boite(self, Vector3(L, 0.35, 0.08), vert, Vector3(0, bas + H - 0.17, P * 0.5))
	# Filets d'or et pilastres sculptés.
	for x in [-L * 0.5, -L * 0.17, L * 0.17, L * 0.5]:
		_boite(self, Vector3(0.1, H + 0.05, 0.1), rouge, Vector3(x, bas + H * 0.5, P * 0.5 + 0.02))
		_cyl(self, 0.06, 0.06, 0.05, or_m, Vector3(x, bas + H - 0.05, P * 0.5 + 0.08), Vector3(PI / 2, 0, 0))
	for y in [bas + 0.08, bas + H - 0.36]:
		_boite(self, Vector3(L + 0.1, 0.03, 0.03), or_m, Vector3(0, y, P * 0.5 + 0.08))
	# Le toit en berceau, tuilé de planches rouges.
	var toit := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = P * 0.62
	c.bottom_radius = P * 0.62
	c.height = L + 0.35
	c.radial_segments = 28
	toit.mesh = c
	toit.material_override = rouge
	toit.rotation.z = PI / 2
	toit.position = Vector3(0, bas + H, 0)
	toit.scale = Vector3(0.42, 1, 1)
	add_child(toit)
	# Le plafond : on ne voit pas le dedans du berceau depuis l'étal.
	_boite(self, Vector3(L, 0.05, P), _bois(Color(0.3, 0.2, 0.12)), Vector3(0, bas + H - 0.02, 0))
	# Les roues : jante, rayons, moyeu.
	var fer := _m(Color(0.08, 0.07, 0.06), 0.45, 0.7)
	for x in [-L * 0.3, L * 0.3]:
		for z: float in [-P * 0.5 - 0.1, P * 0.5 + 0.1]:
			var roue := Node3D.new()
			roue.position = Vector3(x, 0.58, z)
			add_child(roue)
			var j := TorusMesh.new()
			j.inner_radius = 0.5
			j.outer_radius = 0.58
			j.rings = 32
			var jm := MeshInstance3D.new()
			jm.mesh = j
			jm.material_override = rouge
			jm.rotation.x = PI / 2
			roue.add_child(jm)
			for k in 10:
				var a := k * TAU / 10.0
				_boite(roue, Vector3(0.035, 0.5, 0.03), rouge, Vector3(cos(a), sin(a), 0) * 0.27, Vector3(0, 0, a + PI / 2))
			_cyl(roue, 0.08, 0.08, 0.12, or_m, Vector3.ZERO, Vector3(PI / 2, 0, 0))
	# Une petite fenêtre éclairée au bout, et la cheminée de poêle.
	var vitre := _m(Color(1.0, 0.7, 0.35), 0.3)
	vitre.emission_enabled = true
	vitre.emission = Color(1.0, 0.6, 0.25)
	vitre.emission_energy_multiplier = 2.5
	_boite(self, Vector3(0.05, 0.5, 0.6), vitre, Vector3(L * 0.5 + 0.03, bas + 1.0, 0))
	_cyl(self, 0.07, 0.07, 0.9, fer, Vector3(-L * 0.3, bas + H + 0.75, -0.3))
	# Les brancards, posés au sol.
	for z in [-0.45, 0.45]:
		_boite(self, Vector3(1.9, 0.08, 0.08), rouge, Vector3(L * 0.5 + 0.9, 0.35, z), Vector3(0, 0, 0.32))


## Le flanc ouvert : un comptoir, des étagères chargées, un auvent de toile rayée, des lanternes.
func _etal() -> void:
	var P := 1.9
	var bas := 0.75
	var bois := _bois(Color(0.42, 0.28, 0.17))
	_boite(self, Vector3(3.0, 0.08, 0.6), bois, Vector3(0, bas + 0.85, P * 0.5 + 0.2))
	_boite(self, Vector3(3.0, 0.8, 0.06), _bois(Color(0.5, 0.1, 0.07)), Vector3(0, bas + 0.4, P * 0.5 + 0.48))
	for y in [bas + 1.3, bas + 1.65]:
		_boite(self, Vector3(3.0, 0.05, 0.35), bois, Vector3(0, y, -P * 0.5 + 0.25))
	# Sur les étagères : chapeaux, fioles, crânes, bougies.
	for k in 9:
		var x := -1.3 + k * 0.32
		match k % 3:
			0:
				var feutre := _m(Color(0.08, 0.06, 0.05), 0.85)
				_cyl(self, 0.09, 0.12, 0.012, feutre, Vector3(x, bas + 1.34, -P * 0.5 + 0.25))
				_cyl(self, 0.06, 0.07, 0.1, feutre, Vector3(x, bas + 1.4, -P * 0.5 + 0.25))
			1:
				var fiole := _m(Color.from_hsv(_rng.randf(), 0.7, 0.6, 0.8), 0.1)
				fiole.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				fiole.emission_enabled = true
				fiole.emission = fiole.albedo_color
				fiole.emission_energy_multiplier = 0.7
				_cyl(self, 0.03, 0.05, 0.14, fiole, Vector3(x, bas + 1.72, -P * 0.5 + 0.25))
			2:
				var os_m := _m(Color(0.85, 0.79, 0.65), 0.7)
				var cr := MeshInstance3D.new()
				var s := SphereMesh.new()
				s.radius = 0.07
				s.height = 0.14
				cr.mesh = s
				cr.material_override = os_m
				cr.position = Vector3(x, bas + 1.4, -P * 0.5 + 0.25)
				add_child(cr)
	_modele("brass_candleholders", Vector3(-1.1, bas + 0.89, P * 0.5 + 0.2), 0.3, 1.0)
	_modele("vintage_pocket_watch", Vector3(0.6, bas + 0.89, P * 0.5 + 0.25), 0.8, 2.5)
	_modele("vintage_oil_lamp", Vector3(1.2, bas + 0.89, P * 0.5 + 0.2), 0.0, 1.0)
	_modele("hanging_picture_frame_02", Vector3(1.75, bas + 1.0, 0.2), PI / 2, 1.0)
	# L'auvent de toile rayée, qui pend en festons.
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
void vertex() {
	VERTEX.y -= sin(UV.x * 3.14159 * 6.0) * 0.04 * UV.y + sin(TIME * 1.3 + UV.x * 4.0) * 0.01 * UV.y;
}
void fragment() {
	float raie = step(0.5, fract(UV.x * 9.0));
	vec3 c = mix(vec3(0.55, 0.06, 0.05), vec3(0.85, 0.72, 0.45), raie);
	if (UV.y > 0.9 && fract(UV.x * 18.0) > 0.5 && UV.y > 0.9 + 0.1 * (1.0 - abs(fract(UV.x * 18.0) * 2.0 - 1.0))) { discard; }
	ALBEDO = c * 0.8;
	ROUGHNESS = 0.95;
}
"""
	var toile := ShaderMaterial.new()
	toile.shader = sh
	var auvent := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3.4, 1.4)
	pm.subdivide_width = 30
	pm.subdivide_depth = 6
	auvent.mesh = pm
	auvent.material_override = toile
	auvent.position = Vector3(0, bas + 2.15, P * 0.5 + 0.62)
	auvent.rotation.x = 0.42
	add_child(auvent)
	var fer := _m(Color(0.08, 0.07, 0.06), 0.4, 0.7)
	for s: int in [-1, 1]:
		_cyl(self, 0.025, 0.025, 2.6, fer, Vector3(s * 1.65, 1.3, P * 0.5 + 1.25))
		var lampe := _modele("caged_hanging_light", Vector3(s * 1.2, bas + 1.55, P * 0.5 + 1.0), 0.0, 0.7)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.62, 0.3)
		l.light_energy = 2.2
		l.omni_range = 6.0
		l.shadow_enabled = true
		l.position = lampe.position + Vector3(0, -0.15, 0)
		add_child(l)
		_lampes.append(l)
	# Des étoffes qui pendent sur une corde, du bout de la roulotte au poteau.
	var corde := _m(Color(0.25, 0.2, 0.14), 0.9)
	_cyl(self, 0.01, 0.01, 2.4, corde, Vector3(-2.6, 2.15, 0.6), Vector3(0, 0, PI / 2))
	_cyl(self, 0.04, 0.05, 2.3, _bois(Color(0.4, 0.28, 0.17)), Vector3(-3.8, 1.15, 0.6))
	for k in 6:
		var tissu := _m(Color.from_hsv([0.0, 0.08, 0.6, 0.78, 0.95, 0.12][k], 0.7, 0.45), 0.9)
		var bande := _boite(self, Vector3(0.3, 0.7 + _rng.randf() * 0.4, 0.01), tissu, Vector3(-3.55 + k * 0.33, 1.75, 0.6), Vector3(0, 0, _rng.randf_range(-0.08, 0.08)))
		bande.set_meta("flotte", k)


## Devant l'étal : les malles ouvertes, les tonneaux, la valise, le grand miroir.
func _devant() -> void:
	var P := 1.9
	_modele("treasure_chest", Vector3(-1.4, 0, P * 0.5 + 1.4), 0.25, 1.0)
	_modele("treasure_chest", Vector3(-0.55, 0, P * 0.5 + 1.9), -0.4, 0.85)
	_modele("vintage_suitcase", Vector3(1.0, 0, P * 0.5 + 1.6), 0.6, 1.0)
	_modele("wine_barrel_01", Vector3(2.15, 0, P * 0.5 + 0.6), 0.0, 1.0)
	_modele("wicker_basket_02", Vector3(2.0, 0, P * 0.5 + 1.4), 0.0, 1.0)
	_modele("wooden_barrels_01", Vector3(-2.4, 0, -0.4), 1.2, 1.0)
	# Le grand miroir où le personnage se regarde (cf. principal, essai).
	_modele("ornate_mirror_01", Vector3(2.75, 0, P * 0.5 + 2.4), -1.9, 1.3)
	# Un tapis élimé sous les pieds de celui qui essaie.
	var tapis := _m(Color(0.32, 0.07, 0.08), 0.95)
	_boite(self, Vector3(1.6, 0.012, 1.2), tapis, Vector3(1.75, 0.006, P * 0.5 + 2.3), Vector3(0, -0.3, 0))
	_boite(self, Vector3(1.4, 0.014, 1.0), _m(Color(0.55, 0.4, 0.18), 0.95), Vector3(1.75, 0.007, P * 0.5 + 2.3), Vector3(0, -0.3, 0))
	_boite(self, Vector3(1.3, 0.016, 0.9), tapis, Vector3(1.75, 0.008, P * 0.5 + 2.3), Vector3(0, -0.3, 0))


## Le colporteur, posté devant son étal : chapeau de pèlerin, lanterne bleue, l'air de rien.
func _colporteur() -> void:
	colporteur = Bouille.new()
	colporteur.autonome = true
	var a := Bouille.decoder(0)
	a["tete"] = Bouille.TETES.find("courts")
	a["visage"] = Bouille.VISAGES.find("vieux")
	a["yeux"] = Bouille.YEUX.find("lueur")
	a["tenue"] = "pelerin"
	a["objet"] = Bouille.OBJETS.find("lanterne_bleue")
	colporteur.apparence = a
	colporteur.position = Vector3(-0.15, 0, 2.05)
	add_child(colporteur)
	# Une lueur chaude sur son visage, sinon il se perd dans l'ombre de l'auvent.
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.42)
	l.light_energy = 1.4
	l.omni_range = 2.2
	l.position = Vector3(-0.15, 2.4, 2.9)
	add_child(l)


## L'endroit où se tient celui qui essaie (repère de la roulotte), et où regarde la caméra.
static func place_essai() -> Vector3:
	return Vector3(1.75, 0, 1.9 * 0.5 + 2.3)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	for k in _lampes.size():
		_lampes[k].light_energy = 2.0 + sin(_t * 7.0 + k * 2.0) * 0.15 + sin(_t * 13.0 + k) * 0.1
	for e in get_children():
		if e.has_meta("flotte"):
			(e as Node3D).rotation.x = sin(_t * 1.4 + float(e.get_meta("flotte"))) * 0.12
