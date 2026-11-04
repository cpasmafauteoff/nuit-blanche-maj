class_name Parures
extends RefCounted
## Ce que la roulotte vend pour la maison et pour la tombe (cf. Cosmetiques) : construit en code,
## posé dans le repère de la maison (+z vers la place, la porte avant en z = PROFONDEUR / 2).

const BLEU_NOYE := Color(0.25, 0.55, 1.0)


static func _m(c: Color, rugueux := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugueux
	m.metallic = metal
	return m


static func _lueur(c: Color, force := 3.0) -> StandardMaterial3D:
	var m := _m(c, 0.5)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = force
	return m


static func _boule(p: Node3D, r: float, mat: Material, pos: Vector3, ech := Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = mat
	mi.position = pos
	mi.scale = ech
	p.add_child(mi)
	return mi


static func _boite(p: Node3D, t: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = t
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


static func _cyl(p: Node3D, r_h: float, r_b: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO, seg := 16) -> MeshInstance3D:
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


static func _tore(p: Node3D, r_i: float, r_e: float, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r_i
	t.outer_radius = r_e
	t.rings = 32
	t.ring_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


static func _pierre() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/mossy_rock_diff.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://textures/mossy_rock_nor.jpg")
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(1.6, 1.6, 1.6)
	m.albedo_color = Color(0.72, 0.72, 0.7)
	m.roughness = 0.95
	return m


## Une citrouille creusée : côtes, queue tordue, visage qui luit.
static func citrouille(p: Node3D, pos: Vector3, taille: float, rot_y: float) -> void:
	var c := Node3D.new()
	c.position = pos
	c.rotation.y = rot_y
	c.scale = Vector3.ONE * taille
	p.add_child(c)
	var orange := _m(Color(0.75, 0.32, 0.05), 0.55)
	for k in 8:
		var a := k * TAU / 8.0
		_boule(c, 0.17, orange, Vector3(sin(a) * 0.08, 0.15, cos(a) * 0.08), Vector3(0.62, 0.85, 0.62))
	_cyl(c, 0.012, 0.022, 0.09, _m(Color(0.22, 0.18, 0.08)), Vector3(0.01, 0.31, 0), Vector3(0, 0, 0.3))
	var feu := _lueur(Color(1.0, 0.55, 0.12), 4.0)
	for s: int in [-1, 1]:
		_boite(c, Vector3(0.05, 0.045, 0.02), feu, Vector3(s * 0.065, 0.19, 0.225), Vector3(0, 0, s * 0.5))
	_boite(c, Vector3(0.14, 0.03, 0.02), feu, Vector3(0, 0.1, 0.225))
	for k in 3:
		_boite(c, Vector3(0.02, 0.025, 0.021), orange, Vector3((k - 1) * 0.045, 0.112, 0.226))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.15)
	l.light_energy = 0.6
	l.omni_range = 2.0
	l.position = Vector3(0, 0.18, 0.3)
	c.add_child(l)


## Pare la maison `n` (son nœud dans la Ronde) ; `verre` est le matériau de ses vitres.
static func maison(ronde: Ronde, n: Node3D, verre: StandardMaterial3D, sorte: String) -> Node3D:
	var racine := Node3D.new()
	racine.name = "Parure"
	n.add_child(racine)
	var dz := Ronde.PROFONDEUR * 0.5
	# Ce qui est cloué sur le battant suit la porte quand elle s'ouvre (Edwin, 31/10 : ça flottait
	# dans le vide) : Ronde accroche ce nœud à son gond.
	var porte := Node3D.new()
	porte.name = "SurPorte"
	racine.add_child(porte)
	match sorte:
		"lierre":
			for s: int in [-1, 1]:
				for k in 2:
					ronde._modele("Prop_Vine4" if k == 0 else "Prop_Vine1", racine, Vector3(s * (1.2 + k * 1.1), 0.6 + k * 1.3, dz + 0.06), 0.0, Vector3.ONE * 1.2)
			citrouille(racine, Vector3(-0.95, 0, dz + 0.55), 1.15, 0.2)
			citrouille(racine, Vector3(0.9, 0, dz + 0.5), 0.8, -0.3)
			citrouille(racine, Vector3(1.25, 0, dz + 0.85), 0.55, 0.5)
		"lueur_bleue":
			if verre:
				verre.emission = BLEU_NOYE
				verre.albedo_color = Color(0.4, 0.6, 0.9, verre.albedo_color.a)
			for s: int in [-1, 1]:
				var l := OmniLight3D.new()
				l.light_color = BLEU_NOYE
				l.light_energy = 1.2
				l.omni_range = 4.0
				l.position = Vector3(s * 1.75, 1.6, dz + 0.6)
				racine.add_child(l)
		"enseigne":
			# Potence de fer forgé, enseigne de bois qui pend à deux chaînes, tête de loup peinte.
			var fer := _m(Color(0.07, 0.065, 0.06), 0.4, 0.7)
			var bras := Node3D.new()
			bras.position = Vector3(0.95, 2.45, dz + 0.04)
			racine.add_child(bras)
			_boite(bras, Vector3(0.04, 0.04, 0.9), fer, Vector3(0, 0, 0.45))
			_cyl(bras, 0.012, 0.012, 0.75, fer, Vector3(0, -0.22, 0.32), Vector3(0.95, 0, 0))
			for k in 5:
				_tore(bras, 0.03, 0.04, fer, Vector3(0, 0.04, 0.12 + k * 0.17), Vector3(0, PI / 2, 0))
			var planche := Node3D.new()
			planche.position = Vector3(0, -0.06, 0.62)
			planche.set_meta("balance", true)
			bras.add_child(planche)
			for z in [-0.18, 0.18]:
				_cyl(planche, 0.006, 0.006, 0.16, fer, Vector3(0, -0.08, z))
			var bois := StandardMaterial3D.new()
			bois.albedo_texture = load("res://modeles/village/T_WoodTrim_BaseColor.png")
			bois.albedo_color = Color(0.6, 0.45, 0.32)
			bois.roughness = 0.85
			_boite(planche, Vector3(0.05, 0.42, 0.56), bois, Vector3(0, -0.36, 0))
			for cote: int in [-1, 1]:
				var peinture := Label3D.new()
				peinture.text = "☾"
				peinture.font_size = 160
				peinture.pixel_size = 0.0018
				peinture.modulate = Color(0.85, 0.75, 0.45)
				peinture.outline_size = 0
				peinture.position = Vector3(cote * 0.027, -0.36, 0)
				peinture.rotation.y = cote * PI / 2
				planche.add_child(peinture)
			# Porte sculptée : deux têtes de loup en relief sur les vantaux, heurtoir de fer.
			var sculpte := _m(Color(0.2, 0.13, 0.08), 0.8)
			for s: int in [-1, 1]:
				var tete := Node3D.new()
				tete.position = Vector3(s * 0.3, 1.55, dz + 0.02)
				porte.add_child(tete)
				_boule(tete, 0.11, sculpte, Vector3.ZERO, Vector3(1, 1.1, 0.4))
				_cyl(tete, 0.025, 0.06, 0.14, sculpte, Vector3(0, -0.06, 0.06), Vector3(PI / 2 + 0.5, 0, 0))
				for o: int in [-1, 1]:
					_cyl(tete, 0.0, 0.04, 0.09, sculpte, Vector3(o * 0.06, 0.11, 0), Vector3(0, 0, -o * 0.3))
			_tore(porte, 0.05, 0.065, _m(Color(0.1, 0.09, 0.08), 0.4, 0.8), Vector3(0, 1.15, dz + 0.06), Vector3(PI / 2, 0, 0))
		"deuil":
			# Couronne de fleurs noires et de lierre sur la porte, deux rubans qui pendent.
			var c := Node3D.new()
			c.position = Vector3(0, 1.75, dz + 0.08)
			porte.add_child(c)
			var feuille := _m(Color(0.06, 0.12, 0.06), 0.7)
			var fleur := _m(Color(0.05, 0.02, 0.04), 0.55)
			var coeur := _m(Color(0.35, 0.04, 0.06), 0.5)
			_tore(c, 0.2, 0.28, feuille, Vector3.ZERO, Vector3(PI / 2, 0, 0))
			for k in 14:
				var a := k * TAU / 14.0
				var f := _boule(c, 0.045, fleur, Vector3(cos(a) * 0.24, sin(a) * 0.24, 0.03), Vector3(1, 1, 0.5))
				f.rotation.z = a
				_boule(c, 0.014, coeur, Vector3(cos(a) * 0.24, sin(a) * 0.24, 0.055))
			var ruban := _m(Color(0.04, 0.035, 0.04), 0.4)
			for s: int in [-1, 1]:
				_boite(c, Vector3(0.06, 0.55, 0.008), ruban, Vector3(s * 0.08, -0.48, 0.04), Vector3(0, 0, s * 0.12))
			_boule(c, 0.05, ruban, Vector3(0, -0.24, 0.05), Vector3(1.5, 0.8, 0.6))
	return racine


## La tombe : une stèle gravée, une croix de fer ou un mausolée. Repère : +z vers la place.
static func tombe(sorte: String) -> Node3D:
	var n := Node3D.new()
	var pierre := _pierre()
	match sorte:
		"gravee":
			_boite(n, Vector3(0.75, 0.95, 0.16), pierre, Vector3(0, 0.47, 0))
			_cyl(n, 0.375, 0.375, 0.16, pierre, Vector3(0, 0.95, 0), Vector3(PI / 2, 0, 0), 24)
			_boite(n, Vector3(0.9, 0.12, 0.3), pierre, Vector3(0, 0.06, 0.02))
			var lierre := _m(Color(0.1, 0.2, 0.08), 0.8)
			for k in 12:
				_boule(n, 0.05, lierre, Vector3(-0.32 + sin(k * 1.7) * 0.06, 0.1 + k * 0.075, 0.08), Vector3(1, 0.8, 0.4))
			for k in 3:
				_boite(n, Vector3(0.5 - k * 0.1, 0.012, 0.01), _m(Color(0.25, 0.25, 0.24)), Vector3(0, 0.62 - k * 0.1, 0.085))
		"croix_fer":
			var fer := _m(Color(0.09, 0.085, 0.08), 0.5, 0.75)
			_boite(n, Vector3(0.06, 1.35, 0.06), fer, Vector3(0, 0.68, 0), Vector3(0, 0, 0.06))
			_boite(n, Vector3(0.62, 0.06, 0.06), fer, Vector3(0.04, 1.05, 0), Vector3(0, 0, 0.06))
			_tore(n, 0.14, 0.17, fer, Vector3(0.04, 1.05, 0), Vector3(PI / 2, 0, 0))
			for s: int in [-1, 1]:
				_boule(n, 0.035, fer, Vector3(s * 0.31 + 0.04, 1.05 + s * 0.02, 0))
			_boite(n, Vector3(0.5, 0.08, 1.4), _m(Color(0.22, 0.16, 0.11), 1.0), Vector3(0, 0.04, 0.75))
			var lampe := Node3D.new()
			lampe.position = Vector3(0.3, 0.0, 0.3)
			n.add_child(lampe)
			_cyl(lampe, 0.06, 0.07, 0.2, _m(Color(0.1, 0.09, 0.08), 0.4, 0.7), Vector3(0, 0.1, 0), Vector3.ZERO, 6)
			_boule(lampe, 0.03, _lueur(Color(1.0, 0.6, 0.2), 5.0), Vector3(0, 0.12, 0), Vector3(1, 1.5, 1))
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.6, 0.25)
			l.light_energy = 0.8
			l.omni_range = 2.5
			l.position = Vector3(0, 0.3, 0)
			lampe.add_child(l)
		"mausolee":
			_boite(n, Vector3(1.5, 0.2, 1.4), pierre, Vector3(0, 0.1, 0.1))
			_boite(n, Vector3(1.3, 1.5, 1.1), pierre, Vector3(0, 0.95, -0.05))
			for s: int in [-1, 1]:
				_cyl(n, 0.09, 0.1, 1.5, pierre, Vector3(s * 0.5, 0.95, 0.58), Vector3.ZERO, 16)
			var toit := _cyl(n, 0.0, 1.05, 0.55, pierre, Vector3(0, 1.98, 0.05), Vector3.ZERO, 4)
			toit.rotation.y = PI / 4
			toit.scale = Vector3(1.0, 1.0, 0.85)
			var fer := _m(Color(0.07, 0.065, 0.06), 0.45, 0.8)
			for k in 7:
				_cyl(n, 0.012, 0.012, 1.05, fer, Vector3(-0.27 + k * 0.09, 0.75, 0.52))
			_boite(n, Vector3(0.6, 0.03, 0.03), fer, Vector3(0, 1.25, 0.52))
			_boite(n, Vector3(0.55, 1.15, 0.02), _m(Color(0.02, 0.02, 0.02), 1.0), Vector3(0, 0.78, 0.5))
			var l := OmniLight3D.new()
			l.light_color = Color(0.6, 0.7, 1.0)
			l.light_energy = 0.5
			l.omni_range = 2.0
			l.position = Vector3(0, 1.0, 0.2)
			n.add_child(l)
	return n
