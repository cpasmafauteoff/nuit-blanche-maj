extends DecorQuete
## Le Radeau : on est debout sur un radeau de troncs liés qui DESCEND une vraie rivière. Le radeau
## ne bouge pas (c'est le repère des joueurs) : c'est le monde qui défile — l'eau, les berges, les
## arbres, les parois des gorges, les rochers qui arrivent. Chacun tient SA rame, de son bord ; les
## coups de rame des équipiers se voient aussi. Éclaboussures, écume des rapides, brume, lanterne
## au mât, bruit de l'eau. Le rythme et la position viennent de l'hôte (vue["radeau"]).
##
## Repères : on regarde vers +z (l'aval). La droite des rameurs est donc vers -x ; `lat` > 0 = le radeau
## est allé à droite = tout le décor glisse vers +x.

const LARGE_EAU := 34.0
const X_LAT := 2.4                 # mètres par unité de latéral
const COULOIR := 0.9               # écart de latéral entre deux couloirs (cf. Radeau.LAT_COULOIR)
const SPAN := 54.0                 # longueur du ruban de berges qui boucle
const Z_ARRIERE := -16.0
const NB_BERGES := 15              # emplacements par rive
const NB_POOL := 12                # rochers visibles en même temps

var _radeau: Node3D
var _fleuve: Node3D                # tout ce qui glisse de côté avec le latéral
var _eau: MeshInstance3D
var _eau_mat: ShaderMaterial
var _mat_troncs: StandardMaterial3D
var _s := 0.0
var _vue_s := -1.0
var _s_h := 0.0
var _v_h := 3.0
var _lat := 0.0
var _lat_h := 0.0
var _vl_h := 0.0
var _age := 0.0
var _t := 0.0
var _type := "calme"
var _ecume := 0.0
var _gorge := 0.0
var _remous := 0.0
var _troncons: Array = []
var _berges: Array = []
var _roches := {}                  # clé -> {n, ecume, touche}
var _rames: Array = []             # un par rameur : {pivot, sens, vu, t, bras}
var _jets: Array = []              # éclaboussures à usage unique
var _jet_k := 0
var _proue: GPUParticles3D
var _brume_av: GPUParticles3D
var _fond: AudioStreamPlayer       # le clapotis rare, joué toutes les 6 à 10 s
var _clapot_t := 2.0
var _ecorce: StandardMaterial3D
var _aiguilles: StandardMaterial3D
var _mat_ecume: StandardMaterial3D
var _dernier_son := 0.0
var _coups_vus: Array = []
var _annonce_vue := ""
var _avant_pos := 2.0


func degage() -> Array[Rect2]:
	return [Rect2(-LARGE_EAU * 0.5, -17.0, LARGE_EAU, 62.0)]


func libre(p: Vector3) -> bool:
	return absf(p.x) > 6.5


func construire() -> void:
	meuble = ""
	_ecorce = matiere("ecorce", 0.7, Color(0.42, 0.38, 0.35))
	_aiguilles = StandardMaterial3D.new()
	_aiguilles.albedo_color = Color(0.06, 0.1, 0.075)
	_aiguilles.vertex_color_use_as_albedo = true
	_aiguilles.roughness = 1.0
	_aiguilles.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_ecume = StandardMaterial3D.new()
	_mat_ecume.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_ecume.albedo_color = Color(0.85, 0.92, 0.95, 0.5)
	_mat_ecume.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_ecume.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_ecume.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fleuve = Node3D.new()
	_fleuve.add_to_group("mobile")
	add_child(_fleuve)
	_batir_eau()
	_batir_berges()
	_batir_pool()
	_batir_radeau()
	_batir_rames()
	_batir_jets()
	# Le banc de brume (règle « Brouillard »), éteint les autres jours.
	_brume_av = _particules(70, 7.0, Vector3(9.0, 0.5, 4.5), Vector3(0, 0.03, -0.25), 2.6,
		_degrade([Color(0.7, 0.74, 0.76, 0.0), Color(0.72, 0.76, 0.78, 0.42), Color(0.7, 0.74, 0.76, 0.0)]), false)
	_brume_av.position = Vector3(0, 0.7, 12.0)
	_brume_av.visible = false
	add_child(_brume_av)
	# Un clapotis très doux, rare (plus de grondement continu : retour d'Edwin, 01/11).
	_fond = AudioStreamPlayer.new()
	_fond.stream = Sons.clapotis_radeau()
	_fond.volume_db = -24.0
	_fond.bus = "Effets" if AudioServer.get_bus_index("Effets") >= 0 else "Master"
	add_child(_fond)


func _enter_tree() -> void:
	_clapot_t = 2.0


# ---------------------------------------------------------------- l'eau

func _batir_eau() -> void:
	var m := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(LARGE_EAU, 78.0)
	p.subdivide_width = 40
	p.subdivide_depth = 60
	m.mesh = p
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 teinte : source_color = vec3(0.03, 0.07, 0.08);
uniform float defil = 0.0;
uniform float ecume = 0.0;
uniform float houle = 0.025;
uniform sampler2D bruit : filter_linear_mipmap, repeat_enable;
varying vec2 loc;
void vertex() {
	loc = VERTEX.xz;
	VERTEX.y += houle * sin(loc.x * 1.7 + TIME * 1.6) * sin((loc.y + defil) * 1.3 - TIME * 0.4);
}
void fragment() {
	vec2 uv = vec2(loc.x, loc.y + defil) * 0.18;
	vec2 uv2 = vec2(loc.x, loc.y + defil * 1.3) * 0.41 + vec2(TIME * 0.02, 0.0);
	float n = texture(bruit, uv).r * 0.6 + texture(bruit, uv2).r * 0.4;
	vec3 nm = normalize(vec3((n - 0.5) * (0.9 + ecume), 1.0, (texture(bruit, uv2 + 0.13).r - 0.5) * (0.9 + ecume)));
	NORMAL = normalize((VIEW_MATRIX * vec4(nm, 0.0)).xyz);
	float seuil = 0.82 - ecume * 0.28;
	float mousse = smoothstep(seuil, seuil + 0.14, n);
	ALBEDO = mix(teinte, vec3(0.62, 0.68, 0.7), mousse * (0.25 + ecume * 0.6));
	ROUGHNESS = 0.08 + mousse * 0.5;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	float bord = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	ALPHA = smoothstep(0.0, 0.07, bord - (n - 0.5) * 0.05);
}
"""
	_eau_mat = ShaderMaterial.new()
	_eau_mat.shader = sh
	_eau_mat.set_shader_parameter("teinte", Color(0.03, 0.07, 0.08))
	var bruit := NoiseTexture2D.new()
	bruit.seamless = true
	bruit.width = 256
	bruit.height = 256
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	bruit.noise = fn
	_eau_mat.set_shader_parameter("bruit", bruit)
	m.material_override = _eau_mat
	m.position = Vector3(0, 0.05, 11.0)
	_fleuve.add_child(m)
	_eau = m


# ---------------------------------------------------------------- les berges qui défilent

func _batir_berges() -> void:
	for cote: float in [-1.0, 1.0]:
		for k in NB_BERGES:
			var b := Node3D.new()
			_fleuve.add_child(b)
			var arbre := Node3D.new()
			b.add_child(arbre)
			var d := Arbres.variante(k * 3 + (1 if cote > 0 else 0))
			var tronc := MeshInstance3D.new()
			tronc.mesh = d["tronc"]
			tronc.material_override = _ecorce
			arbre.add_child(tronc)
			if d["aiguilles"]:
				var ai := MeshInstance3D.new()
				ai.mesh = d["aiguilles"]
				ai.material_override = _aiguilles
				arbre.add_child(ai)
			var roc := morceau("rock_moss_set_01" if k % 2 == 0 else "rock_moss_set_02", k, Vector3.ZERO, 1.0, 0.0, b)
			var fal := morceau("namaqualand_cliff_01", k, Vector3.ZERO, 1.0, 0.0, b)
			var herbe := morceau("grass_medium_01", k * 5, Vector3.ZERO, 1.2, 0.0, b)
			var tr := modele("dead_tree_trunk_02", Vector3.ZERO, 1.0, 0.0, b)
			b.set_meta("parts", {"arbre": arbre, "rocher": roc, "falaise": fal, "herbe": herbe, "tronc": tr})
			var item := {"n": b, "cote": cote, "z0": Z_ARRIERE + SPAN * (float(k) + (0.35 if cote > 0 else 0.0)) / NB_BERGES, "z_prec": -1e9, "graine": k * 7 + (3 if cote > 0 else 0)}
			_berges.append(item)
			_styler(item, 0.0, item["z0"])


## Habille l'emplacement selon le tronçon où il se trouve (D = distance dans la rivière).
func _styler(item: Dictionary, s: float, z: float) -> void:
	var d := s + z
	var type := "calme"
	var dif := 0
	for t: Array in _troncons:
		if d >= float(t[0]) and d < float(t[0]) + float(t[1]):
			type = str(t[2])
			dif = int(t[3])
	var b: Node3D = item["n"]
	var parts: Dictionary = b.get_meta("parts")
	var rs := RandomNumberGenerator.new()
	rs.seed = int(item["graine"]) * 7919 + int(d / SPAN)
	for p: Node3D in parts.values():
		p.visible = false
	var cote: float = item["cote"]
	var x := 0.0
	b.rotation.y = rs.randf() * TAU
	b.scale = Vector3.ONE
	match type:
		"gorge":
			# Une paroi haute et sombre de chaque côté, qui serre le lit.
			var f: Node3D = parts["falaise"]
			f.visible = true
			var ech := rs.randf_range(1.15, 1.45)
			b.rotation.y = PI * 0.5 + rs.randf_range(-0.08, 0.08)
			b.scale = Vector3.ONE * ech
			# Le mur fait 4,4 m d'épaisseur : sa face, à 3,6 m du milieu (là où racle la coque).
			x = 3.7 / ech + 2.2 + 0.2
			if rs.randf() < 0.3:
				var r: Node3D = parts["rocher"]
				r.visible = true
				r.position = Vector3(-cote * 0.0, 0, 0)
		"rapides":
			x = 6.0 + rs.randf_range(0.0, 3.0)
			var r: Node3D = parts["rocher"]
			r.visible = true
			b.scale = Vector3.ONE * rs.randf_range(0.45, 0.9)
			if rs.randf() < 0.35:
				var a: Node3D = parts["arbre"]
				a.visible = true
				a.scale = Vector3.ONE * rs.randf_range(1.2, 1.8)
		_:
			x = 8.5 + rs.randf_range(0.0, 7.0)
			var a: Node3D = parts["arbre"]
			if rs.randf() < 0.8:
				a.visible = true
				a.scale = Vector3.ONE * rs.randf_range(1.3, 2.2)
			elif rs.randf() < 0.5:
				var tr: Node3D = parts["tronc"]
				tr.visible = true
			else:
				var r: Node3D = parts["rocher"]
				r.visible = true
			if rs.randf() < 0.6:
				var h: Node3D = parts["herbe"]
				h.visible = true
				h.position = Vector3(-cote * 1.2, 0, 0.5)
	b.position.x = cote * x * (b.scale.x if type == "gorge" else 1.0)
	item["x"] = b.position.x


# ---------------------------------------------------------------- les rochers du lit

func _batir_pool() -> void:
	for k in NB_POOL:
		var n := Node3D.new()
		n.visible = false
		_fleuve.add_child(n)
		modele("boulder_01", Vector3(0, -0.25, 0), 1.35, k * 1.9, n)
		var anneau_e := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.75
		tm.outer_radius = 1.0
		tm.rings = 24
		tm.ring_segments = 4
		anneau_e.mesh = tm
		anneau_e.scale = Vector3(1.3, 0.06, 1.3)
		anneau_e.material_override = _mat_ecume
		anneau_e.position.y = 0.08
		n.add_child(anneau_e)
		var ecume := _particules(20, 1.0, Vector3(0.8, 0.02, 0.4), Vector3(0, 0.5, -0.3), 0.35,
			_degrade([Color(0.8, 0.85, 0.85, 0.0), Color(0.85, 0.9, 0.9, 0.6), Color(0.8, 0.85, 0.85, 0.0)]), false)
		ecume.position = Vector3(0, 0.15, -0.5)
		n.add_child(ecume)
		_roches[-k - 1] = {"n": n, "libre": true, "cle": 0, "touche": false, "anneau": anneau_e}


# ---------------------------------------------------------------- le radeau

func _batir_radeau() -> void:
	_radeau = Node3D.new()
	add_child(_radeau)
	_mat_troncs = matiere("tronc", 1.0).duplicate() as StandardMaterial3D
	var rangs := (equipe + 1) / 2
	var arriere := -0.3 - rangs * 0.5 * RANG_RADEAU - 0.7
	var avant := -0.3 + rangs * 0.5 * RANG_RADEAU + 0.6
	_avant_pos = avant
	var long := avant - arriere
	var milieu := (avant + arriere) * 0.5
	for k in 8:
		var x := -1.05 + k * 0.3
		var c := _cylindre(0.15, long + 0.1 * sin(k * 2.3), _mat_troncs)
		c.rotation.x = PI / 2
		c.position = Vector3(x, 0.2, milieu)
		_radeau.add_child(c)
	var traverses: Array[float] = [arriere + 0.25, avant - 0.25]
	for r in range(1, rangs):
		traverses.append(-0.3 + (r - rangs * 0.5) * RANG_RADEAU)
	for z: float in traverses:
		poutre(Vector3(-1.25, 0.37, z), Vector3(1.25, 0.37, z), 0.06, matiere("vieux_bois", 1.0), _radeau)
		for x: float in [-1.05, 1.05]:
			var lien := anneau(0.17, 0.015, matiere("chanvre", 1.0, Color(0.5, 0.42, 0.3)), _radeau)
			lien.rotation.z = PI / 2
			lien.position = Vector3(x, 0.25, z)
	modele("wooden_crate_01", Vector3(-0.55, 0.35, arriere + 0.5), 0.7, 0.2, _radeau)
	modele("wooden_bucket_02", Vector3(0.6, 0.35, arriere + 0.5), 0.55, 0.0, _radeau)
	modele("wicker_basket_01", Vector3(0.1, 0.35, arriere + 0.45), 0.7, 0.9, _radeau)
	# Le mât de proue et sa lanterne ; une seconde lanterne à la poupe.
	var mat := Node3D.new()
	mat.position = Vector3(0.0, 0.35, avant - 0.3)
	_radeau.add_child(mat)
	poutre(Vector3(0, 0, 0), Vector3(0, 2.0, 0), 0.05, null, mat)
	poutre(Vector3(0, 1.9, 0), Vector3(0, 1.9, 0.5), 0.03, null, mat)
	corde(Vector3(0, 1.9, 0.5), Vector3(0, 1.6, 0.5), 0.0, 0.008, mat)
	var lan := modele("wooden_lantern_01", Vector3(0, 1.05, 0.5), 1.0, 0.0, mat)
	var l := _lumiere(Color(1.0, 0.68, 0.35), 2.4, 12.0, Vector3(0, 0.3, 0))
	lan.add_child(l)
	_feux.append([l, 2.4, 2.0])
	var mat2 := Node3D.new()
	mat2.position = Vector3(0.9, 0.35, arriere + 0.3)
	_radeau.add_child(mat2)
	poutre(Vector3(0, 0, 0), Vector3(0, 1.5, 0), 0.04, null, mat2)
	var lan2 := modele("vintage_oil_lamp", Vector3(0, 1.45, 0), 0.9, 0.0, mat2)
	var l2 := _lumiere(Color(1.0, 0.7, 0.4), 1.2, 6.0, Vector3(0, 0.2, 0))
	lan2.add_child(l2)
	_feux.append([l2, 1.2, 5.0])
	# L'écume que fend la proue.
	_proue = _particules(40, 0.9, Vector3(1.0, 0.05, 0.15), Vector3(0, 0.9, 0.7), 0.08,
		_degrade([Color(0.85, 0.9, 0.92, 0.0), Color(0.9, 0.94, 0.95, 0.4), Color(0.85, 0.9, 0.92, 0.0)]), false)
	_proue.position = Vector3(0, 0.15, avant + 0.15)
	_radeau.add_child(_proue)


## Une rame par rameur, à son bord : manche dans les mains, pale dans l'eau. Les coups des équipiers se
## voient (leur compte arrive dans la vue) ; ma rame suit ma main.
func _batir_rames() -> void:
	var bois := matiere("vieux_bois", 2.0)
	for k in equipe:
		var p := poste(jeu, k, equipe)
		var sens := 1.0 if p.x > 0.0 else -1.0      # vers où pointe la pale
		var pivot := Node3D.new()
		pivot.position = Vector3(p.x + sens * 0.5, 0.95, p.z)
		pivot.add_to_group("mobile")
		add_child(pivot)
		var arbre := _cylindre(0.025, 2.4, bois)
		arbre.rotation.z = PI / 2
		arbre.position.x = 0.55
		pivot.add_child(arbre)
		var pale := _boite(Vector3(0.55, 0.025, 0.2), bois)
		pale.position.x = 1.55
		pivot.add_child(pale)
		var poignee := _cylindre(0.035, 0.16, bois)
		poignee.position.x = -0.6
		pivot.add_child(poignee)
		var tolet := _cylindre(0.03, 0.2, bois)
		tolet.position = Vector3(0, -0.12, 0)
		pivot.add_child(tolet)
		_rames.append({"pivot": pivot, "sens": sens, "vu": 0, "t": -1.0, "k": k})
		_pose_rame(_rames[k], -0.3, -0.28)
		_coups_vus.append(0)


func _pose_rame(r: Dictionary, balayage: float, inclinaison: float) -> void:
	var sens: float = r["sens"]
	var base := 0.0 if sens > 0.0 else PI
	var piv: Node3D = r["pivot"]
	piv.basis = Basis(Vector3.UP, base + balayage * sens) * Basis(Vector3.BACK, inclinaison)


func _batir_jets() -> void:
	for k in 6:
		var j := _particules(30, 0.9, Vector3(0.25, 0.05, 0.25), Vector3(0, 2.6, 0), 0.08,
			_degrade([Color(0.9, 0.95, 0.97, 0.0), Color(0.95, 0.98, 1.0, 0.8), Color(0.85, 0.9, 0.92, 0.0)]), false)
		j.one_shot = true
		j.explosiveness = 0.85
		j.emitting = false
		j.preprocess = 0.0
		add_child(j)
		_jets.append(j)


## Une gerbe d'eau en ce point (repère du décor).
func _gerbe(pos: Vector3, fort := 1.0) -> void:
	var j: GPUParticles3D = _jets[_jet_k % _jets.size()]
	_jet_k += 1
	j.position = pos
	j.amount_ratio = clampf(fort, 0.3, 1.0)
	j.restart()
	j.emitting = true


func _bruit_eau(pos: Vector3, db := -4.0) -> void:
	if _t - _dernier_son < 0.12 or not is_inside_tree():
		return
	_dernier_son = _t
	var son := AudioStreamPlayer3D.new()
	son.stream = Sons.rame()
	son.position = pos
	son.unit_size = 5.0
	son.volume_db = db
	son.pitch_scale = randf_range(0.9, 1.1)
	son.bus = "Effets" if AudioServer.get_bus_index("Effets") >= 0 else "Master"
	add_child(son)
	son.play()
	son.finished.connect(son.queue_free)


# ---------------------------------------------------------------- les gestes

func cible_geste() -> Node3D:
	return _rames[rang]["pivot"] if rang >= 0 and rang < _rames.size() else null


## Mon coup de rame est parti : la gerbe à la pale et le bruit de l'eau.
func frappe() -> void:
	if rang < 0 or rang >= _rames.size():
		return
	var pivot: Node3D = _rames[rang]["pivot"]
	var bout := pivot.position + pivot.basis.x * 1.6 + Vector3(0, -0.5, -0.2)
	_gerbe(Vector3(bout.x, 0.1, bout.z), 0.6)
	_bruit_eau(bout, -3.0)


func touche(_n: Node3D) -> void:
	pass


# ---------------------------------------------------------------- l'animation

func animer(vue: Dictionary, _phase: float, delta: float) -> void:
	_t += delta
	var r: Dictionary = vue.get("radeau", {})
	if r.is_empty():
		return
	if _troncons.is_empty():
		_troncons = r.get("troncons", [])
		for it in _berges:
			_styler(it, _s, _z_de(it))
	# Une nouvelle photo de l'hôte : on repart de ses chiffres, on les prolonge entre deux.
	var sh := float(r.get("s", 0.0))
	if sh != _vue_s:
		if _vue_s < 0.0:
			_s = sh
			_lat = float(r.get("lat", 0.0))
		_vue_s = sh
		_s_h = sh
		_v_h = float(r.get("v", 3.0))
		_lat_h = float(r.get("lat", 0.0))
		_vl_h = float(r.get("vl", 0.0))
		_age = 0.0
		_poser_rochers(r)
		_coups(r)
	_age += delta
	var lisse := clampf(delta * 7.0, 0.0, 1.0)
	_s = lerpf(_s, _s_h + _v_h * _age, lisse)
	_lat = lerpf(_lat, _lat_h + _vl_h * minf(_age, 0.5), lisse)
	_type = str(r.get("type", "calme"))
	var dif := float(r.get("d", 0))
	_fleuve.position.x = _lat * X_LAT
	var vit := _v_h
	# L'eau : défilement, écume, houle.
	var cible_ecume := 0.0 if _type == "calme" else (0.35 + dif * 0.2)
	_ecume = lerpf(_ecume, cible_ecume, delta * 1.2)
	_remous = lerpf(_remous, dif, delta * 1.2)
	_eau_mat.set_shader_parameter("defil", _s * 0.9)
	_eau_mat.set_shader_parameter("ecume", _ecume)
	_eau_mat.set_shader_parameter("houle", 0.025 + 0.03 * _remous)
	# Les berges : le ruban boucle ; à chaque tour, l'emplacement prend le décor du tronçon qu'il atteint.
	for it in _berges:
		var z := fposmod(float(it["z0"]) - _s, SPAN) + Z_ARRIERE
		if z > float(it["z_prec"]) + SPAN * 0.5 and float(it["z_prec"]) > -1e8:
			_styler(it, _s, z)
		it["z_prec"] = z
		(it["n"] as Node3D).position.z = z
	# Le radeau tangue, plus fort dans les remous ; il gîte quand il dérive.
	_radeau.rotation.z = 0.025 * sin(_t * 1.1) + (0.012 + 0.014 * _remous) * sin(_t * 2.3) - _vl_h * 0.05
	_radeau.rotation.x = 0.012 * sin(_t * 0.7) + 0.01 * _remous * sin(_t * 3.1)
	_radeau.position.y = 0.02 * sin(_t * 1.7) + 0.02 * _remous * sin(_t * 2.9)
	var coque := jauge(vue, "Coque", 1.0)
	_mat_troncs.albedo_color = Color.WHITE.lerp(Color(0.3, 0.27, 0.25), 1.0 - coque)
	_proue.amount_ratio = clampf((vit - 1.0) / 4.0, 0.1, 1.0)
	_brume_av.visible = str(vue.get("variante", "")) == "Brouillard"
	_clapot_t -= delta
	if _clapot_t <= 0.0:
		_clapot_t = randf_range(6.0, 10.0)
		if is_inside_tree() and not _fond.playing:
			_fond.pitch_scale = randf_range(0.9, 1.1)
			_fond.play()
	_animer_rames(delta)
	_animer_rochers(delta)
	if nouvelle_annonce(vue):
		secouer(_radeau, 0.1)


func _z_de(it: Dictionary) -> float:
	return fposmod(float(it["z0"]) - _s, SPAN) + Z_ARRIERE


## Les rochers vus par ce joueur : [distance au centre, couloir, touché]. Un rocher a une identité (sa
## distance absolue) : il garde son nœud d'une photo à l'autre.
func _poser_rochers(r: Dictionary) -> void:
	var vus := {}
	for x: Array in r.get("roches", []):
		var cle := int(round((float(x[0]) + _s_h) * 10.0)) * 8 + int(x[1]) + 1
		vus[cle] = x
		var trouve := false
		for k in _roches:
			if _roches[k]["cle"] == cle:
				trouve = true
				_roches[k]["rel"] = float(x[0])
				_roches[k]["lane"] = int(x[1])
				if bool(x[2]) and not _roches[k]["touche"]:
					_roches[k]["touche"] = true
					_choc(_roches[k])
				break
		if not trouve:
			for k in _roches:
				if _roches[k]["libre"]:
					var e: Dictionary = _roches[k]
					e["libre"] = false
					e["cle"] = cle
					e["rel"] = float(x[0])
					e["lane"] = int(x[1])
					e["touche"] = bool(x[2])
					e["n"].rotation.y = float(cle % 17)
					e["n"].scale = Vector3.ONE * (0.9 + 0.1 * float(cle % 5))
					(e["n"] as Node3D).visible = true
					break
	for k in _roches:
		if not _roches[k]["libre"] and not vus.has(_roches[k]["cle"]):
			_roches[k]["libre"] = true
			(_roches[k]["n"] as Node3D).visible = false


func _animer_rochers(delta: float) -> void:
	for k in _roches:
		var e: Dictionary = _roches[k]
		if e["libre"]:
			continue
		var n: Node3D = e["n"]
		var z := float(e["rel"]) - (_s - _s_h)
		n.position = Vector3(-float(e["lane"]) * COULOIR * X_LAT, 0.0, z)
		(e["anneau"] as MeshInstance3D).scale = Vector3(1.0 + 0.08 * sin(_t * 3.0 + z), 0.06, 1.0 + 0.08 * sin(_t * 3.0 + z))


func _choc(e: Dictionary) -> void:
	var n: Node3D = e["n"]
	_gerbe(Vector3(_fleuve.position.x + n.position.x, 0.2, 2.2), 1.0)
	_bruit_eau(Vector3(_fleuve.position.x + n.position.x, 0.2, 2.2), 2.0)
	secouer(_radeau, 0.16)


## Les coups de mes équipiers : leur rame fait un mouvement quand leur compte monte.
func _coups(r: Dictionary) -> void:
	var c: Array = r.get("coups", [])
	for k in mini(c.size(), _rames.size()):
		var n := int(c[k])
		if k != rang and n > int(_rames[k]["vu"]):
			_rames[k]["vu"] = n
			_rames[k]["t"] = 0.0
		elif k == rang:
			_rames[k]["vu"] = n


func _animer_rames(delta: float) -> void:
	for r in _rames:
		var k: int = r["k"]
		var piv: Node3D = r["pivot"]
		if k == rang:
			if tenu:
				_pose_rame(r, clampf(-main.y / 0.7, -0.3, 1.0), -0.3)
			else:
				_pose_rame(r, lerpf(-0.3, 0.2, 0.5 + 0.5 * sin(_t * 1.2)), -0.18)
			continue
		var t: float = r["t"]
		if t < 0.0:
			_pose_rame(r, -0.3 + 0.05 * sin(_t * 1.3 + k), -0.2)
			continue
		t += delta
		r["t"] = t
		const DUREE := 0.85
		if t >= DUREE:
			r["t"] = -1.0
			continue
		var u := t / DUREE
		var balayage := 0.0
		var incl := -0.3
		if u < 0.5:
			balayage = lerpf(-0.3, 0.9, u * 2.0)
		else:
			balayage = lerpf(0.9, -0.3, (u - 0.5) * 2.0)
			incl = -0.05
		_pose_rame(r, balayage, incl)
		if u > 0.3 and u - delta / DUREE <= 0.3:
			var bout := piv.position + piv.basis.x * 1.6 + Vector3(0, -0.5, 0)
			_gerbe(Vector3(bout.x, 0.1, bout.z), 0.5)
			_bruit_eau(bout, -9.0)
