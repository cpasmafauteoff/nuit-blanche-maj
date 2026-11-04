class_name Village
extends Node3D
## La place du village, construite en code : sol, pavés, puits, maisons aux
## fenêtres allumées, arbres, lanternes, lune et étoiles.

var lumiere_lune: DirectionalLight3D
var environnement: Environment
var _fenetres: Array[StandardMaterial3D] = []
var _lanternes: Array[OmniLight3D] = []


func _ready() -> void:
	_ciel()
	_sol()
	_puits(Vector3(0, 0, -3.2))
	var maisons := [
		[Vector3(-6.5, 0, -6), 0.5], [Vector3(-2.2, 0, -9), 0.1], [Vector3(3.2, 0, -9.5), -0.15],
		[Vector3(7.5, 0, -5.5), -0.6], [Vector3(-9, 0, -1), 1.2], [Vector3(9.5, 0, -0.5), -1.3],
	]
	var couleurs := [Color(0.95, 0.85, 0.7), Color(0.8, 0.9, 1.0), Color(1.0, 0.8, 0.8),
		Color(0.85, 0.95, 0.8), Color(0.95, 0.9, 0.75), Color(0.9, 0.85, 1.0)]
	for i in maisons.size():
		_maison(maisons[i][0], maisons[i][1], couleurs[i])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 14:
		var a := rng.randf_range(-PI, PI * 0.1)
		var d := rng.randf_range(12, 18)
		_arbre(Vector3(cos(a) * d, 0, sin(a) * d - 2), rng.randf_range(0.8, 1.4))
	for p in [Vector3(-3, 0, -1), Vector3(3, 0, -1), Vector3(-4.5, 0, -6.5), Vector3(4.5, 0, -6.5)]:
		_lanterne(p)


func _ciel() -> void:
	var we := WorldEnvironment.new()
	environnement = Environment.new()
	var ciel := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.05, 0.06, 0.2)
	mat.sky_horizon_color = Color(0.25, 0.2, 0.45)
	mat.ground_bottom_color = Color(0.03, 0.03, 0.08)
	mat.ground_horizon_color = Color(0.2, 0.16, 0.35)
	ciel.sky_material = mat
	environnement.background_mode = Environment.BG_SKY
	environnement.sky = ciel
	environnement.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environnement.ambient_light_color = Color(0.45, 0.45, 0.75)
	environnement.ambient_light_energy = 0.55
	environnement.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environnement.glow_enabled = true
	environnement.glow_intensity = 0.9
	environnement.glow_bloom = 0.15
	environnement.fog_enabled = true
	environnement.fog_light_color = Color(0.25, 0.22, 0.45)
	environnement.fog_density = 0.018
	we.environment = environnement
	add_child(we)

	lumiere_lune = DirectionalLight3D.new()
	lumiere_lune.light_color = Color(0.7, 0.75, 1.0)
	lumiere_lune.light_energy = 0.9
	lumiere_lune.shadow_enabled = true
	lumiere_lune.rotation_degrees = Vector3(-40, 30, 0)
	add_child(lumiere_lune)

	var lune := Bouille.sphere(3.0, Bouille.materiau(Color(1, 0.97, 0.85), 0.0, Color(1, 0.95, 0.75)))
	lune.position = Vector3(-18, 22, -55)
	add_child(lune)

	var etoiles := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var petite := SphereMesh.new()
	petite.radius = 0.12
	petite.height = 0.24
	petite.radial_segments = 6
	petite.rings = 3
	mm.mesh = petite
	mm.instance_count = 260
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in mm.instance_count:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.25, 1), rng.randf_range(-1, 0.2)).normalized()
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.5, 1.6)), dir * 70))
	etoiles.multimesh = mm
	etoiles.material_override = Bouille.materiau(Color.WHITE, 0.0, Color(1, 1, 0.9))
	add_child(etoiles)


func _sol() -> void:
	var sol := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(80, 80)
	sol.mesh = plan
	sol.material_override = Bouille.materiau(Color(0.22, 0.42, 0.3), 0.0)
	add_child(sol)
	var place := MeshInstance3D.new()
	var disque := CylinderMesh.new()
	disque.top_radius = 7.5
	disque.bottom_radius = 7.5
	disque.height = 0.04
	place.mesh = disque
	place.material_override = Bouille.materiau(Color(0.55, 0.5, 0.55), 0.0)
	place.position = Vector3(0, 0.02, -3.2)
	add_child(place)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 70:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 7.0
		var pave := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(rng.randf_range(0.3, 0.55), 0.05, rng.randf_range(0.3, 0.5))
		pave.mesh = b
		pave.material_override = Bouille.materiau(Color(0.62, 0.58, 0.62).darkened(rng.randf() * 0.2), 0.0)
		pave.position = Vector3(cos(a) * d, 0.045, sin(a) * d - 3.2)
		pave.rotation.y = rng.randf() * PI
		add_child(pave)


func _puits(p: Vector3) -> void:
	var n := Node3D.new()
	n.position = p
	add_child(n)
	var mur := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.9
	c.bottom_radius = 1.0
	c.height = 0.8
	mur.mesh = c
	mur.material_override = Bouille.materiau(Color(0.6, 0.6, 0.68), 0.02)
	mur.position.y = 0.4
	n.add_child(mur)
	var eau := MeshInstance3D.new()
	var e := CylinderMesh.new()
	e.top_radius = 0.75
	e.bottom_radius = 0.75
	e.height = 0.02
	eau.mesh = e
	eau.material_override = Bouille.materiau(Color(0.2, 0.35, 0.8), 0.0, Color(0.1, 0.2, 0.6))
	eau.position.y = 0.75
	n.add_child(eau)
	for cote: int in [-1, 1]:
		var poteau := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.14, 1.5, 0.14)
		poteau.mesh = b
		poteau.material_override = Bouille.materiau(Color(0.5, 0.32, 0.2), 0.012)
		poteau.position = Vector3(0.85 * cote, 1.3, 0)
		n.add_child(poteau)
	var toit := MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = Vector3(2.3, 0.6, 1.3)
	toit.mesh = pr
	toit.material_override = Bouille.materiau(Color(0.75, 0.3, 0.3), 0.02)
	toit.position.y = 2.3
	n.add_child(toit)
	_obstacle(n, cylindre(1.0, 2.0), Vector3(0, 1.0, 0))


func _maison(p: Vector3, rot: float, c: Color) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = rot
	add_child(n)
	var murs := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(3.2, 2.4, 2.8)
	murs.mesh = b
	murs.material_override = Bouille.materiau(c, 0.03)
	murs.position.y = 1.2
	n.add_child(murs)
	_obstacle(n, boite(Vector3(3.2, 2.4, 2.8)), Vector3(0, 1.2, 0))
	var toit := MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = Vector3(3.8, 1.6, 3.2)
	toit.mesh = pr
	toit.material_override = Bouille.materiau(Color(0.45, 0.25, 0.4), 0.03)
	toit.position.y = 3.2
	n.add_child(toit)
	var porte := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(0.75, 1.3, 0.06)
	porte.mesh = pb
	porte.material_override = Bouille.materiau(Color(0.45, 0.28, 0.18), 0.01)
	porte.position = Vector3(0, 0.65, 1.41)
	n.add_child(porte)
	for cote: int in [-1, 1]:
		var f := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.6, 0.6, 0.06)
		f.mesh = fb
		var mat := Bouille.materiau(Color(1, 0.85, 0.4), 0.01, Color(1, 0.7, 0.25))
		_fenetres.append(mat)
		f.material_override = mat
		f.position = Vector3(0.95 * cote, 1.5, 1.41)
		n.add_child(f)


func _arbre(p: Vector3, taille: float) -> void:
	var n := Node3D.new()
	n.position = p
	n.scale = Vector3.ONE * taille
	add_child(n)
	var tronc := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.15
	c.bottom_radius = 0.22
	c.height = 1.0
	tronc.mesh = c
	tronc.material_override = Bouille.materiau(Color(0.4, 0.26, 0.18), 0.015)
	tronc.position.y = 0.5
	n.add_child(tronc)
	_obstacle(n, cylindre(0.5, 2.0), Vector3(0, 1.0, 0))
	for i in 3:
		var cone := MeshInstance3D.new()
		var k := CylinderMesh.new()
		k.top_radius = 0.0
		k.bottom_radius = 1.2 - i * 0.3
		k.height = 1.3
		cone.mesh = k
		cone.material_override = Bouille.materiau(Color(0.15, 0.4, 0.3).lightened(i * 0.06), 0.02)
		cone.position.y = 1.3 + i * 0.7
		n.add_child(cone)


func _lanterne(p: Vector3) -> void:
	var poteau := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.1, 2.2, 0.1)
	poteau.mesh = b
	poteau.material_override = Bouille.materiau(Color(0.2, 0.18, 0.22), 0.01)
	poteau.position = p + Vector3(0, 1.1, 0)
	add_child(poteau)
	_obstacle(self, boite(Vector3(0.3, 2.2, 0.3)), p + Vector3(0, 1.1, 0))
	var globe := Bouille.sphere(0.2, Bouille.materiau(Color(1, 0.85, 0.5), 0.0, Color(1, 0.7, 0.3)))
	globe.position = p + Vector3(0, 2.3, 0)
	add_child(globe)
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.75, 0.45)
	l.light_energy = 1.6
	l.omni_range = 6.0
	l.position = p + Vector3(0, 2.3, 0)
	add_child(l)
	_lanternes.append(l)


## Obstacle invisible pour qu'on ne traverse pas les murs.
func _obstacle(parent: Node3D, forme: Shape3D, pos: Vector3) -> void:
	var corps := StaticBody3D.new()
	var c := CollisionShape3D.new()
	c.shape = forme
	corps.add_child(c)
	corps.position = pos
	parent.add_child(corps)


static func boite(taille: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = taille
	return b


static func cylindre(rayon: float, hauteur: float) -> CylinderShape3D:
	var c := CylinderShape3D.new()
	c.radius = rayon
	c.height = hauteur
	return c


## 0 = soirée chaleureuse, 1 = nuit profonde (lanternes et fenêtres éteintes).
func regler_nuit(n: float) -> void:
	for l in _lanternes:
		l.light_energy = lerpf(1.6, 0.0, n)
	for m in _fenetres:
		m.emission_energy_multiplier = lerpf(1.5, 0.05, n)
	lumiere_lune.light_energy = lerpf(0.9, 0.35, n)
	environnement.ambient_light_energy = lerpf(0.55, 0.18, n)
