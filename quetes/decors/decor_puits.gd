extends DecorQuete
## Le Puits : une margelle de pierres moussues, un toit de tuiles sur deux poteaux, un treuil à
## manivelle d'où descend la corde jusqu'au seau de bois. Au bord, la jauge du puisatier : un
## poteau, une bague verte (la bonne tension) et un anneau de fer qui monte et descend avec la
## tension. Hors de la bande, la corde vire au rouge et tremble.

var _seau: Node3D
var _corde: Node3D
var _treuil: Node3D
var _anneau: Node3D
var _bande: MeshInstance3D
var _poignee: Node3D
var _haut := 0.0
var _poignee_y0 := 0.9
var _eau_bac: MeshInstance3D         # l'abreuvoir où l'on vide les seaux : il se remplit
var _seaux_faits: Array = []         # un petit seau doré par seau hissé, sur le râtelier
var _seaux_vus := -1
var _lourd_vu := 1.0
var _gouttes: GPUParticles3D         # l'eau qui ruisselle du seau quand on le hisse
const JAUGE_BAS := 0.55
const JAUGE_HAUT := 1.75


func construire() -> void:
	# Roche verdie : la matière « mousse » sort noire sur les faces verticales (bande noire).
	var roche := matiere("roche", 0.8, Color(0.72, 0.8, 0.66))
	roche.cull_mode = BaseMaterial3D.CULL_DISABLED
	var margelle := _cylindre(0.85, 0.8, roche)
	(margelle.mesh as CylinderMesh).cap_top = false
	margelle.position.y = 0.4
	add_child(margelle)
	var dedans := _cylindre(0.7, 0.8, matiere("roche", 0.8, Color(0.3, 0.3, 0.3)))
	(dedans.mesh as CylinderMesh).cap_top = false
	(dedans.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	dedans.position.y = 0.41
	add_child(dedans)
	anneau(0.78, 0.09, matiere("roche", 1.2), self).position.y = 0.8
	eau(Vector2(1.4, 1.4), Vector3(0, 0.12, 0), 0.0, Color(0.02, 0.04, 0.05))
	# Deux poteaux, une traverse, un toit à deux pans.
	# Plantés dans le sol, à côté de la margelle : à 0,95 m du centre ils sont hors du rayon de
	# la pierre (0,85), donc partir de 0,6 les laissait pendre dans le vide.
	for x: float in [-0.95, 0.95]:
		poutre(Vector3(x, -0.1, 0), Vector3(x, 2.35, 0), 0.07, matiere("vieux_bois", 1.0))
	var tuiles := matiere("tuiles", 1.2, Color(0.75, 0.65, 0.6))
	for cote: float in [-1.0, 1.0]:
		var pan := _boite(Vector3(2.4, 0.06, 1.0), tuiles)
		pan.position = Vector3(0, 2.55, cote * 0.38)
		pan.rotation.x = cote * 0.62
		add_child(pan)
	poutre(Vector3(-1.1, 2.33, 0), Vector3(1.1, 2.33, 0), 0.06, matiere("vieux_bois", 1.0))
	# Le treuil et sa manivelle.
	_treuil = Node3D.new()
	_treuil.position = Vector3(0, 1.55, 0)
	add_child(_treuil)
	var axe := _cylindre(0.11, 1.8, matiere("vieux_bois", 1.0))
	axe.rotation.z = PI / 2
	_treuil.add_child(axe)
	for k in 5:
		var tour := anneau(0.12, 0.012, matiere("chanvre", 1.0, Color(0.5, 0.42, 0.3)), _treuil)
		tour.rotation.z = PI / 2
		tour.position.x = -0.1 + k * 0.045
	var bras := _boite(Vector3(0.04, 0.32, 0.04), matiere("metal", 2.0, Color(0.3, 0.29, 0.28)))
	bras.position = Vector3(1.0, 0.14, 0)
	_treuil.add_child(bras)
	var main := _cylindre(0.025, 0.18, matiere("vieux_bois", 2.0))
	main.rotation.z = PI / 2
	main.position = Vector3(1.08, 0.29, 0)
	_treuil.add_child(main)
	_corde = Node3D.new()
	add_child(_corde)
	_seau = modele("wooden_bucket_01", Vector3(0, 0.3, 0), 0.8)
	_seau.add_to_group("mobile")
	# La jauge du puisatier : un poteau planté au bord de la margelle, une bague verte (la bonne
	# tension) et un anneau de fer qui monte et descend autour. Elle se lit de partout.
	meuble = ""
	var j := Node3D.new()
	j.position = Vector3(0, 0, 1.25)
	add_child(j)
	poutre(Vector3(0, -0.1, 0), Vector3(0, 2.0, 0), 0.05, matiere("vieux_bois", 1.0), j)
	var vert := StandardMaterial3D.new()
	vert.albedo_color = Color(0.25, 0.6, 0.25)
	vert.emission_enabled = true
	vert.emission = Color(0.1, 0.35, 0.1)
	_bande = _cylindre(0.062, 0.2, vert)
	_bande.position = Vector3(0, 1.1, 0)
	j.add_child(_bande)
	_anneau = Node3D.new()
	j.add_child(_anneau)
	anneau(0.1, 0.022, matiere("metal", 2.0, Color(0.55, 0.5, 0.45)), _anneau)
	_anneau.position = Vector3(0, 1.0, 0)
	_anneau.add_to_group("mobile")
	# La corde qui me revient quand c'est mon tour : une boucle devant mes mains.
	_poignee = Node3D.new()
	var boucle := anneau(0.07, 0.014, matiere("chanvre", 1.0, Color(0.6, 0.5, 0.35)), _poignee)
	boucle.rotation.x = PI / 2
	_poignee.visible = false
	a_cote(_poignee, Vector3(0.22, 0.9, 0.62))
	_poignee_y0 = _poignee.position.y
	_batir_cour()
	accessoire("wooden_bucket_02", Vector3(1.3, 0, -0.9), 0.8, 0.5)
	accessoire("wooden_crate_01", Vector3(-1.4, 0, -0.7), 0.9, 1.2)


## La cour du puits : un abreuvoir de pierre où l'on vide chaque seau, un râtelier où s'alignent les seaux
## hissés, des tonneaux, du foin, un banc ; l'eau ruisselle du seau quand on le monte.
func _batir_cour() -> void:
	var roche := matiere("roche", 0.8, Color(0.62, 0.64, 0.58))
	var bac := Node3D.new()
	bac.position = Vector3(-0.3, 0, -1.9)
	add_child(bac)
	var cuve := _boite(Vector3(1.6, 0.5, 0.6), roche)
	cuve.position.y = 0.25
	bac.add_child(cuve)
	_eau_bac = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.4, 0.4)
	_eau_bac.mesh = pm
	var me := StandardMaterial3D.new()
	me.albedo_color = Color(0.1, 0.22, 0.28, 0.85)
	me.metallic = 0.3
	me.roughness = 0.1
	me.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_eau_bac.material_override = me
	_eau_bac.position = Vector3(0, 0.1, 0)
	bac.add_child(_eau_bac)
	# Le râtelier : une poutre sur deux poteaux, un crochet par seau.
	var rat := Node3D.new()
	rat.position = Vector3(2.2, 0, -1.6)
	rat.rotation.y = -0.5
	rat.add_to_group("traversable")
	add_child(rat)
	for x: float in [-0.9, 0.9]:
		poutre(Vector3(x, -0.05, 0), Vector3(x, 1.5, 0), 0.04, matiere("vieux_bois", 1.0), rat)
	poutre(Vector3(-1.0, 1.45, 0), Vector3(1.0, 1.45, 0), 0.04, matiere("vieux_bois", 1.0), rat)
	for k in 4:
		var s := modele("wooden_bucket_02", Vector3(-0.6 + k * 0.4, 1.0, 0.0), 0.5, 0.0, rat)
		s.visible = false
		_seaux_faits.append(s)
	accessoire("wine_barrel_01", Vector3(-2.2, 0, -1.2), 1.3, 0.4, 1.8)
	accessoire("tree_stump_01", Vector3(1.8, 0, 1.6), 0.7, 0.3, 1.8)
	_gouttes = _particules(16, 0.7, Vector3(0.12, 0.02, 0.12), Vector3(0, -1.2, 0), 0.05,
		_degrade([Color(0.7, 0.85, 0.95, 0.0), Color(0.75, 0.9, 1.0, 0.8), Color(0.7, 0.85, 0.95, 0.0)]), false)
	_gouttes.position = Vector3(0, 0.6, 0)
	_gouttes.emitting = false
	add_child(_gouttes)


func cible_geste() -> Node3D:
	return _poignee


func animer(vue: Dictionary, _phase: float, delta: float) -> void:
	var tension := jauge(vue, "Tension", 0.5)
	var monte := jauge(vue, "seau", 0.0)
	_haut = lerpf(_haut, monte, delta * 3.0)
	var y := lerpf(0.12, 1.0, _haut)
	_seau.position = Vector3(0, y, 0)
	# Plus le seau est profond, plus il est LOURD : plus gros, rempli à ras bord, la corde vibre davantage.
	var pu: Dictionary = vue.get("puits", {})
	var lourd := float(pu.get("lourd", 1.0))
	_lourd_vu = lerpf(_lourd_vu, lourd, delta * 2.0)
	_seau.scale = Vector3.ONE * (0.8 + 0.5 * (_lourd_vu - 1.0))
	var fait := int(pu.get("seau", 0))
	if fait != _seaux_vus and not pu.is_empty():
		_seaux_vus = fait
		for k in _seaux_faits.size():
			(_seaux_faits[k] as Node3D).visible = k < fait
	if not pu.is_empty():
		var rempli := float(fait) + (1.0 if bool(pu.get("pause", false)) else 0.0)
		var cible := clampf(rempli / maxf(float(pu.get("seaux", 3)), 1.0), 0.0, 1.0)
		_eau_bac.position.y = lerpf(_eau_bac.position.y, 0.1 + 0.34 * cible, delta * 2.0)
		_gouttes.position = Vector3(0, y + 0.1, 0)
		_gouttes.emitting = _haut > 0.05 and not bool(pu.get("pause", false))
	_treuil.rotation.x = -_haut * 12.0
	var zone: Array = []
	for b in jauges(vue):
		if str(b.get("l", "")).contains("Tension"):
			zone = b.get("zone", [])
	var dedans := zone.size() < 2 or (tension >= float(zone[0]) and tension <= float(zone[1]))
	if zone.size() >= 2:
		var z0 := lerpf(JAUGE_BAS, JAUGE_HAUT, float(zone[0]))
		var z1 := lerpf(JAUGE_BAS, JAUGE_HAUT, float(zone[1]))
		_bande.position.y = (z0 + z1) * 0.5
		_bande.scale.y = maxf((z1 - z0) / 0.2, 0.05)
	_anneau.position.y = lerpf(_anneau.position.y, lerpf(JAUGE_BAS, JAUGE_HAUT, tension), delta * 6.0)
	var tremble := 0.0 if dedans else 0.02 * sin(Time.get_ticks_msec() * 0.06)
	var couleur := Color(0.55, 0.46, 0.32) if dedans else Color(0.75, 0.2, 0.12)
	refaire_corde(_corde, Vector3(tremble, 1.43, 0), Vector3(0, y + 0.55, 0), 0.0, 0.016, matiere("chanvre", 1.0, couleur))
	var a_moi := not bloc(vue, "tenir").is_empty()
	_poignee.visible = a_moi
	if a_moi:
		_poignee.scale = Vector3.ONE * (1.2 if tenu else 1.0)
		# La boucle suit ma main : je tire pour de bon sur la corde.
		_poignee.position.y = lerpf(_poignee.position.y, _poignee_y0 - (clampf(-main.y * 0.25, -0.1, 0.3) if tenu else 0.0), delta * 14.0)
	if nouvelle_annonce(vue):
		secouer(_seau, 0.08)
