extends DecorQuete
## Le Pont : une gorge sans fond qui fend la clairière, bordée de rochers moussus ; un pont de planches
## numérotées, retenu par deux garde-corps de corde, la traverse d'une rive à l'autre. Le marcheur
## la traverse À PIED, planche par planche ; de part et d'autre du tablier, chacun TIENT SA CORDE, nouée au
## garde-corps : elle se raidit quand il la tient (poing fermé ou clic), pend quand il lâche.
## Les planches bougent sous le pas, le tablier ondule ; les tenants voient en rouge les planches pourries et
## la rafale qui se lève (le marcheur, non) ; une planche pourrie qui cède tombe dans la gorge.
## Tout se dimensionne avec Passerelle (la même géométrie que la règle, jeux/pont.gd, qui juge les pieds).
## Le vide de la gorge est un faux gouffre (un shader qui trace des parois et un fond de brume sous le sol
## de la clairière) : on le croit profond, depuis la rive comme depuis les planches.

const HAUT_PLANCHE := 0.04
const LARGEUR := 1.22
const HAUT_GARDE := 1.0

var _nb := 20
var _pont: Node3D
var _planches: Array = []          # un dictionnaire par planche : nœud, maillage, étiquette
var _ma_corde: Node3D
var _prise_pt := Node3D.new()      # le bout de ma corde, là où ma main la saisit
var _autres: Array = []            # les cordes des autres tenants (une par rang)
var _t := 0.0
var _gouffre_mat: ShaderMaterial
var _mat_pourri: StandardMaterial3D
var _casse_vue := {}
var _vent: AudioStreamPlayer
var _rafale_vue := 0
var _tenu_avant := false


func libre(p: Vector3) -> bool:
	return absf(p.x) > 3.4 or p.z > Passerelle.Z_DEPART + 2.8 or p.z < Passerelle.z_fin(_nb) - 2.2


func degage() -> Array[Rect2]:
	var z1 := Passerelle.z_fin(_nb) - 2.4
	return [Rect2(-5.0, z1, 10.0, Passerelle.Z_DEPART + 3.0 - z1)]


func construire() -> void:
	meuble = ""
	_nb = Passerelle.nb_planches(niveau if niveau != "" else "normal", maxi(equipe, 3))
	var z0 := Passerelle.Z_DEPART
	var z1 := Passerelle.z_fin(_nb)
	_gouffre(z0, z1)
	_rives(z0, z1)
	_tablier(z0, z1)
	_garde_corps(z0, z1)
	_lumieres(z0, z1)
	_arrivee(z1)
	_ma_corde = Node3D.new()
	add_child(_ma_corde)
	add_child(_prise_pt)
	_vent = AudioStreamPlayer.new()
	_vent.stream = Sons.vent()
	_vent.bus = "Effets"
	_vent.volume_db = -80.0
	add_child(_vent)
	_vent.play()


# ---------------------------------------------------------------- la gorge

func _gouffre(z0: float, z1: float) -> void:
	var m := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(Passerelle.GORGE_DEMI * 2.0, z0 - z1)
	m.mesh = q
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform vec3 centre = vec3(0.0);
uniform vec2 demi = vec2(1.4, 8.0);
uniform float profondeur = 11.0;
uniform sampler2D bruit : filter_linear_mipmap, repeat_enable;
varying vec3 monde;
void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 d = normalize(monde - cam);
	vec3 o = monde - centre;
	float t_sol = 1e6;
	if (d.y < -1e-4) {
		t_sol = (-profondeur - o.y) / d.y;
	}
	float t_x = 1e6;
	if (abs(d.x) > 1e-4) {
		t_x = ((d.x > 0.0 ? demi.x : -demi.x) - o.x) / d.x;
	}
	float t_z = 1e6;
	if (abs(d.z) > 1e-4) {
		t_z = ((d.z > 0.0 ? demi.y : -demi.y) - o.z) / d.z;
	}
	float t = min(t_sol, min(t_x, t_z));
	vec3 h = o + d * t;
	float prof = clamp(-h.y / profondeur, 0.0, 1.0);
	vec3 col;
	if (t == t_sol) {
		// Le fond : une brume froide, un fil d'eau qui luit à peine.
		float n = texture(bruit, h.xz * 0.12 + vec2(TIME * 0.01, 0.0)).r;
		col = mix(vec3(0.006, 0.01, 0.016), vec3(0.02, 0.032, 0.05), n);
		col += vec3(0.02, 0.035, 0.055) * smoothstep(0.55, 0.8, n);
	} else {
		// Les parois : de la roche en strates, de plus en plus noire à mesure qu'on descend.
		vec2 uv = (t == t_x) ? vec2(h.z * 0.22, h.y * 0.16) : vec2(h.x * 0.22, h.y * 0.16);
		float n = texture(bruit, uv).r;
		float strate = 0.5 + 0.5 * sin(h.y * 4.0 + n * 6.0);
		col = mix(vec3(0.02, 0.018, 0.015), vec3(0.085, 0.078, 0.068), n * 0.7 + strate * 0.3);
		col *= pow(1.0 - prof, 3.6);
		col += vec3(0.01, 0.016, 0.026) * prof;
	}
	// La brume monte du fond : tout se noie en bleu sombre vers le bas.
	col = mix(col, vec3(0.012, 0.02, 0.032), pow(prof, 1.3) * 0.7);
	ALBEDO = col;
}
"""
	_gouffre_mat = ShaderMaterial.new()
	_gouffre_mat.shader = sh
	var bruit := NoiseTexture2D.new()
	bruit.seamless = true
	bruit.width = 256
	bruit.height = 256
	var fn := FastNoiseLite.new()
	fn.frequency = 0.03
	bruit.noise = fn
	_gouffre_mat.set_shader_parameter("bruit", bruit)
	_gouffre_mat.set_shader_parameter("demi", Vector2(Passerelle.GORGE_DEMI, (z0 - z1) * 0.5))
	m.material_override = _gouffre_mat
	m.position = Vector3(0, 0.02, (z0 + z1) * 0.5)
	add_child(m)
	m.add_to_group("traversable")
	# Une brume épaisse qui stagne juste au-dessus du vide (elle cache le bord de la plaque).
	var brume := _particules(10, 9.0, Vector3(Passerelle.GORGE_DEMI, 0.1, (z0 - z1) * 0.5), Vector3(0.0, 0.02, 0.05), 1.5,
		_degrade([Color(0.5, 0.56, 0.64, 0.0), Color(0.46, 0.52, 0.6, 0.07), Color(0.44, 0.5, 0.58, 0.0)]), false)
	(brume.process_material as ParticleProcessMaterial).gravity = Vector3.ZERO
	brume.position = Vector3(0, 0.22, (z0 + z1) * 0.5)
	add_child(brume)


func _process(delta: float) -> void:
	super._process(delta)
	if _gouffre_mat != null and is_inside_tree():
		# Le shader trace le gouffre en coordonnées du monde : on lui dit où est le centre du dessus.
		_gouffre_mat.set_shader_parameter("centre", global_position + Vector3(0, 0.02, (Passerelle.Z_DEPART + Passerelle.z_fin(_nb)) * 0.5))


## Les bords de la gorge : des rochers moussus tout du long (solides : on n'y marche pas), deux rives plates
## aux bouts, des rochers hauts de part et d'autre, des fougères.
func _rives(z0: float, z1: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6161
	var z := z1 - 0.3
	var i := 0
	while z < z0 + 0.3:
		for cote: float in [-1.0, 1.0]:
			var p := Vector3(cote * (Passerelle.GORGE_DEMI + 0.18 + rng.randf_range(-0.05, 0.15)), -0.12, z + rng.randf_range(-0.2, 0.2))
			if loin_des_joueurs(p, 0.75):
				var lot := "rock_moss_set_01" if (i + int(cote)) % 2 == 0 else "rock_moss_set_02"
				morceau(lot, i + int(cote * 3.0) + 7, p, rng.randf_range(0.34, 0.5), rng.randf() * TAU)
		z += 0.95
		i += 1
	# Les rives plates : une dalle moussue au départ (sud) et à l'arrivée (nord).
	var m_roche := matiere("roche", 0.8, Color(0.7, 0.8, 0.66))
	var sud := _boite(Vector3(3.0, 0.1, 2.4), m_roche)
	sud.position = Vector3(0, -0.02, z0 + 1.2)
	add_child(sud)
	sud.add_to_group("traversable")
	var nord := _boite(Vector3(3.0, 0.1, 2.4), m_roche)
	nord.position = Vector3(0, -0.02, z1 - 1.2)
	add_child(nord)
	nord.add_to_group("traversable")
	# De hauts rochers qui ferment les flancs.
	for cote: float in [-1.0, 1.0]:
		for k in 6:
			var p2 := Vector3(cote * rng.randf_range(3.4, 5.0), 0.0, lerpf(z0 + 0.5, z1 - 1.0, float(k) / 5.0) + rng.randf_range(-0.7, 0.7))
			if loin_des_joueurs(p2, 2.5):
				morceau("rock_moss_set_02", k * 3 + 1, p2 + Vector3(0, -0.2, 0), rng.randf_range(0.9, 1.5), rng.randf() * TAU)


# ---------------------------------------------------------------- le tablier

func _tablier(z0: float, z1: float) -> void:
	_pont = Node3D.new()
	add_child(_pont)
	_pont.add_to_group("traversable")
	var bois := matiere("vieux_bois", 1.2)
	_mat_pourri = StandardMaterial3D.new()
	_mat_pourri.albedo_color = Color(0.9, 0.1, 0.06, 0.5)
	_mat_pourri.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_pourri.emission_enabled = true
	_mat_pourri.emission = Color(1.0, 0.12, 0.06)
	_mat_pourri.emission_energy_multiplier = 1.2
	var m_num := Color(0.95, 0.88, 0.7)
	for k in _nb:
		var z := Passerelle.z_planche(k)
		var porte := Node3D.new()
		porte.position = Vector3(0, HAUT_PLANCHE, z)
		porte.rotation.y = 0.04 * sin(k * 1.9)
		_pont.add_child(porte)
		var p := _boite(Vector3(LARGEUR, 0.045, Passerelle.PAS - 0.06), bois)
		porte.add_child(p)
		# Un trait de peinture toutes les cinq planches, un numéro sur chacune : « saute la 12 ».
		if (k + 1) % 5 == 0:
			var bande := _boite(Vector3(LARGEUR + 0.01, 0.047, 0.05), _mat("bande_pont", Color(0.78, 0.55, 0.2), Color(0.35, 0.2, 0.05)))
			bande.position = Vector3(0, 0.001, 0.12)
			porte.add_child(bande)
		var lab := _grave(str(k + 1), 64, Vector3(0.0, 0.03, -0.02))
		lab.modulate = m_num
		porte.add_child(lab)
		_planches.append({"n": porte, "mi": p, "lab": lab, "rouge": null})


func _garde_corps(z0: float, z1: float) -> void:
	var bois := matiere("bois", 1.0, Color(0.5, 0.4, 0.3))
	var chanvre := matiere("chanvre", 1.0, Color(0.5, 0.42, 0.3))
	var cote_x := LARGEUR * 0.5 + 0.03
	var pas_poteau := 4 * Passerelle.PAS
	var nb_poteaux := int(floor((z0 - z1) / pas_poteau)) + 1
	for cote: float in [-1.0, 1.0]:
		var precedent := Vector3.INF
		for j in nb_poteaux:
			var z := z0 - 0.1 - j * pas_poteau
			var pied := Vector3(cote * cote_x, 0.0, z)
			var po := poutre(pied, pied + Vector3(0, HAUT_GARDE + 0.1, 0), 0.045, bois)
			po.add_to_group("traversable")
			if precedent != Vector3.INF:
				for h: float in [HAUT_GARDE, HAUT_GARDE * 0.5]:
					var c := corde(Vector3(cote * cote_x, h, precedent.z), Vector3(cote * cote_x, h, z), 0.05, 0.016, null, chanvre)
					c.add_to_group("traversable")
			precedent = pied
			# Une lanterne pendue à un poteau sur deux.
			if j % 2 == 0:
				var lan := modele("wooden_lantern_01", Vector3(cote * (cote_x + 0.12), HAUT_GARDE - 0.2, z), 0.7, 0.0)
				lan.add_to_group("traversable")
				var flamme := _sphere(0.03, matiere("flamme", 1.0, Color(1, 0.8, 0.4), Color(1.0, 0.7, 0.3)))
				flamme.position = lan.position + Vector3(0, 0.12, 0)
				add_child(flamme)
				flamme.add_to_group("traversable")
	# Un garde-corps invisible mais solide, le long des deux côtés : on ne tombe pas par mégarde du tablier.
	var corps := StaticBody3D.new()
	corps.collision_layer = 1
	corps.collision_mask = 0
	add_child(corps)
	for cote: float in [-1.0, 1.0]:
		var forme := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(0.08, 1.2, z0 - z1)
		forme.shape = bx
		forme.position = Vector3(cote * (cote_x + 0.02), 0.6, (z0 + z1) * 0.5)
		corps.add_child(forme)


func _lumieres(z0: float, z1: float) -> void:
	# Un clair de lune froid sur la gorge, et quelques lanternes tièdes le long du tablier.
	var longueur := z0 - z1
	for k in maxi(2, int(longueur / 7.0) + 1):
		var z := lerpf(z0 - 1.5, z1 + 1.5, float(k) / maxf(float(maxi(2, int(longueur / 7.0) + 1) - 1), 1.0))
		add_child(_lumiere(Color(0.5, 0.65, 0.85), 0.85, 8.0, Vector3(0, 3.2, z)))
	var n := 0
	for z in range(0, _nb, 6):
		if n >= 6:
			break
		var l := _lumiere(Color(1.0, 0.68, 0.34), 0.9, 4.5, Vector3(0, 1.3, Passerelle.z_planche(z)))
		add_child(l)
		_feux.append([l, 0.9, randf() * 10.0])
		n += 1


## L'arrivée, au nord : un mât, une grande lanterne dorée qu'on voit de loin.
func _arrivee(z1: float) -> void:
	var c := Vector3(1.0, 0.0, z1 - 1.3)
	poteau_lanterne(c, Vector3(-1, 0, 0), 2.6)
	var colonne := _cylindre(0.14, 6.0, _lueur(Color(1.0, 0.8, 0.4, 0.05)))
	colonne.position = Vector3(0, 3.0, z1 - 1.0)
	add_child(colonne)
	colonne.add_to_group("traversable")
	var l := _lumiere(Color(1.0, 0.78, 0.4), 1.8, 7.0, Vector3(0, 2.2, z1 - 1.0))
	add_child(l)
	_feux.append([l, 1.8, randf() * 10.0])


func _lueur(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	return m


func cible_geste() -> Node3D:
	return _prise_pt


# ---------------------------------------------------------------- la vie du pont

func _donnees(vue: Dictionary) -> Dictionary:
	return bloc(vue, "pont")


func animer(vue: Dictionary, _phase: float, delta: float) -> void:
	_t += delta
	var d := _donnees(vue)
	var avance := int(d.get("avance", -1))
	var rafale := int(d.get("rafale", 0))
	var marche: bool = bool(d.get("marcheur", false))
	var pourries: Array = d.get("pourries", [])
	var cassees: Array = d.get("cassees", [])
	var engage: bool = bool(d.get("engage", false))
	# Le tablier ondule, plus fort sous le pas du marcheur et pendant une rafale.
	var vent := 1.0 + (5.0 if rafale == 2 else (1.5 if rafale == 1 else 0.0))
	for k in _planches.size():
		var pl: Dictionary = _planches[k]
		var porte: Node3D = pl["n"]
		if cassees.has(k):
			if not _casse_vue.has(k):
				_casse_vue[k] = true
				_casser(pl)
			continue
		var pres := clampf(1.0 - absf(float(k) - float(avance)) / 3.0, 0.0, 1.0) if avance >= 0 else 0.0
		porte.position.y = HAUT_PLANCHE - 0.012 * pres + 0.004 * vent * sin(_t * 2.2 + k * 0.55)
		porte.rotation.z = 0.012 * vent * sin(_t * 1.7 + k * 0.4)
		porte.position.x = 0.012 * vent * sin(_t * 1.3 + k * 0.3) * (1.0 if rafale == 2 else 0.4)
		# Les tenants voient les planches pourries en rouge (le marcheur, non).
		var rouge: bool = pourries.has(k) and not marche
		if rouge and pl["rouge"] == null:
			var ov := _boite(Vector3(LARGEUR + 0.02, 0.05, Passerelle.PAS - 0.04), _mat_pourri)
			(pl["n"] as Node3D).add_child(ov)
			pl["rouge"] = ov
			(pl["lab"] as Label3D).modulate = Color(1.0, 0.35, 0.25)
		elif not rouge and pl["rouge"] != null:
			(pl["rouge"] as Node3D).queue_free()
			pl["rouge"] = null
			(pl["lab"] as Label3D).modulate = Color(0.95, 0.88, 0.7)
	# Le vent : on l'entend monter avec la rafale.
	var voulu := -6.0 if rafale == 2 else (-18.0 if rafale == 1 else -80.0)
	_vent.volume_db = lerpf(_vent.volume_db, voulu, minf(delta * 3.0, 1.0))
	if rafale == 2 and _rafale_vue != 2:
		secouer(_pont, 0.1)
	_rafale_vue = rafale
	# MA corde, des garde-corps jusqu'à mes mains.
	var tenue := not bloc(vue, "tenir").is_empty() and tenu
	var ici := poste(jeu, rang, equipe)
	var cote := signf(ici.x) * (LARGEUR * 0.5 + 0.03)
	var a := Vector3(cote, HAUT_GARDE * 0.8, ici.z)
	var main := ici + Vector3(-signf(ici.x) * 0.35, 1.05, 0)
	_prise_pt.position = main
	if tenue:
		# Je tire la corde vers moi : la main recule et descend un peu.
		main += Vector3(signf(ici.x) * 0.15, -0.1, 0)
	refaire_corde(_ma_corde, a, main, 0.02 if tenue else 0.32, 0.02, matiere("chanvre", 1.0, Color(0.78, 0.66, 0.44) if tenue else Color(0.45, 0.38, 0.27)))
	_cordes_des_autres(engage, marche)
	if nouvelle_annonce(vue):
		secouer(_pont, 0.12)


## Les cordes des autres tenants : tendues quand le marcheur est engagé (tous tiennent, sinon il tombe), au
## repos sinon. On ne voit jamais lequel lâche : ça reste à l'annonce.
func _cordes_des_autres(engage: bool, _marche: bool) -> void:
	while _autres.size() < equipe:
		var n := Node3D.new()
		add_child(n)
		_autres.append(n)
	for k in equipe:
		var n: Node3D = _autres[k]
		if k == rang:
			n.visible = false
			continue
		n.visible = true
		var ici := poste(jeu, k, equipe)
		var cote := signf(ici.x) * (LARGEUR * 0.5 + 0.03)
		var a := Vector3(cote, HAUT_GARDE * 0.8, ici.z)
		var main := ici + Vector3(-signf(ici.x) * 0.35, 1.05, 0)
		if engage:
			main += Vector3(signf(ici.x) * 0.15, -0.1, 0)
		refaire_corde(n, a, main, 0.02 if engage else 0.3, 0.02, matiere("chanvre", 1.0, Color(0.78, 0.66, 0.44) if engage else Color(0.45, 0.38, 0.27)))


## Une planche pourrie cède : elle bascule et tombe dans la gorge.
func _casser(pl: Dictionary) -> void:
	var porte: Node3D = pl["n"]
	var son := AudioStreamPlayer3D.new()
	son.stream = Sons.craquement()
	son.position = porte.position + Vector3(0, 0.5, 0)
	son.unit_size = 6.0
	son.bus = "Effets"
	add_child(son)
	son.play()
	son.finished.connect(son.queue_free)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(porte, "position:y", -6.0, 1.2).set_ease(Tween.EASE_IN)
	tw.tween_property(porte, "rotation:x", 1.4, 0.6)
	tw.chain().tween_callback(func(): porte.visible = false)
