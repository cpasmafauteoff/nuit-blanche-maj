extends DecorQuete
## Les Lanternes : un grand marais nocturne, noir et profond, dans la clairière. Le marcheur le traverse
## À PIED, à la première personne, de pierre en pierre, en suivant un vrai parcours en lacets (cf.
## regles/marais.gd) : de vraies pierres plates et moussues affleurent d'une eau sombre, sous une brume
## basse. Rien ne dit au marcheur lesquelles tiennent. Les guides, sur la rive sud, voient les pierres
## sûres ÉCLAIRÉES d'une lanterne ancienne (et son reflet dans l'eau), les pièges rougeâtres qui
## s'inclinent, les pierres qui s'enfoncent et remontent en cadence.
## Le marais a des ÉTAPES : des îlots balisés d'un poteau coloré (« va jusqu'au poteau bleu »), trois
## tronçons aux décors différents (le Gué, la Tourbière aux pierres mobiles, le Bois noyé) et des REPÈRES
## que les guides nomment à la voix (une barque échouée, un grand saule, un tronc couché, une cabane,
## une pierre dressée, un héron de pierre). Au nord, une poutre porte les lanternes de vie du marcheur ;
## l'arrivée est une grande lanterne dorée qu'on voit de loin.
## (cf. jeux/lanternes.gd, qui juge les pieds, et Quetes.case_marais, la géométrie commune.)

const ETANG_C := Vector3(0, 0, -6.1)
const ETANG_RX := 8.4
const ETANG_RZ := 9.05
const HAUT_PIERRE := 0.15         # le dessus d'une pierre, au-dessus du sol (l'eau est à 0,04)
const ENFONCE := 0.58             # de combien une pierre mobile s'enfonce

var _pierres: Array = []          # un dictionnaire par pierre (ou null : un trou du marais)
var _taille := 0                  # la largeur du marais, en pierres
var _haut := 0                    # sa profondeur
var _arrivee: Node3D
var _t := 0.0
var _t_est := 0.0                 # le temps de l'hôte, lissé entre deux vues
var _vues_chutes := -1
var _ov_chaud: Material
var _ov_piege: Material
var _ov_trace: Material
var _ov_but: Material
var _vies: Array = []             # les lanternes de vie, de gauche à droite
var _vies_max := -1
var _vies_etat := -2
var _m_vie_on: Material
var _m_vie_off: Material
var _etiquette_vies: Label3D
var _eau_mat: ShaderMaterial
var _nb_lampes := 0               # les vraies lumières des pierres (limitées : le reste est un halo)
var _iles: Array = []
var _balises: Array = []          # [lanterne (MeshInstance3D), lumière] par poteau, pour les allumer à l'arrivée
var _etape_vue := -1
var _m_roche: StandardMaterial3D


## L'eau et ce qui l'entoure ne sont jamais semés : la voie du jeu (et des joueurs qui y plongent).
func libre(p: Vector3) -> bool:
	return absf(p.x) > 7.0 or p.z > 3.0 or p.z < -15.6


## La clairière est à nous : l'herbe du sous-bois ne doit pas percer l'eau.
func degage() -> Array[Rect2]:
	return [Rect2(-8.8, -16.6, 17.6, 19.8)]


func construire() -> void:
	meuble = ""
	_materiaux()
	_etang()
	_brumes()
	_rives()
	_arbres_morts()
	_souches_et_racines()
	_lumieres()


func _materiaux() -> void:
	# La roche moussue des clairières (Poly Haven, CC0), mouillée : sombre, verdâtre, brillante.
	_m_roche = StandardMaterial3D.new()
	_m_roche.albedo_texture = load("res://textures/mossy_rock_diff.jpg")
	_m_roche.normal_enabled = true
	_m_roche.normal_texture = load("res://textures/mossy_rock_nor.jpg")
	_m_roche.roughness_texture = load("res://textures/mossy_rock_rough.jpg")
	_m_roche.albedo_color = Color(0.62, 0.72, 0.58)
	_m_roche.roughness = 0.75
	_m_roche.uv1_triplanar = true
	_m_roche.uv1_scale = Vector3.ONE * 1.4
	_m_vie_on = _mat("vie_on", Color(1.0, 0.8, 0.35), Color(1.0, 0.65, 0.2))
	_m_vie_off = _mat("vie_off", Color(0.16, 0.15, 0.15))
	_ov_chaud = _recouvrement(Color(1.0, 0.8, 0.5, 0.07), Color(1.0, 0.55, 0.2), 0.3)
	_ov_piege = _recouvrement(Color(0.8, 0.12, 0.08, 0.22), Color(0.55, 0.05, 0.02), 0.3)
	_ov_trace = _recouvrement(Color(0.45, 0.75, 1.0, 0.1), Color(0.25, 0.55, 1.0), 0.4)
	_ov_but = _recouvrement(Color(1.0, 0.9, 0.5, 0.14), Color(1.0, 0.75, 0.3), 0.7)


## Une teinte lumineuse posée par-dessus une pierre (sans toucher à sa matière moussue).
func _recouvrement(c: Color, e: Color, energie: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = e
	m.emission_energy_multiplier = energie
	m.roughness = 1.0
	return m


# ---------------------------------------------------------------- l'eau

func _etang() -> void:
	# Le fond : de la vase, qui ne se voit qu'aux berges où l'eau s'amincit.
	var fond := _cylindre(1.0, 0.02, matiere("boue", 0.35, Color(0.4, 0.4, 0.36)))
	fond.scale = Vector3(ETANG_RX + 0.6, 1.0, ETANG_RZ + 0.6)
	fond.position = ETANG_C + Vector3(0, 0.005, 0)
	add_child(fond)
	var m := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(ETANG_RX * 2.0 + 1.6, ETANG_RZ * 2.0 + 1.6)
	p.subdivide_width = 40
	p.subdivide_depth = 56
	m.mesh = p
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
uniform vec3 profond : source_color = vec3(0.008, 0.024, 0.03);
uniform vec3 ciel : source_color = vec3(0.30, 0.42, 0.50);
uniform vec2 rayon = vec2(8.4, 9.05);
uniform sampler2D bruit : filter_linear_mipmap, repeat_enable;
varying vec3 monde;
varying vec2 local;
void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local = VERTEX.xz;
	VERTEX.y += 0.008 * sin(monde.x * 2.3 + TIME * 0.9) * sin(monde.z * 1.9 - TIME * 0.7);
}
void fragment() {
	vec2 uv = monde.xz * 0.2 + vec2(TIME * 0.011, -TIME * 0.008);
	vec2 uv2 = monde.xz * 0.7 + vec2(-TIME * 0.02, TIME * 0.016);
	float n = texture(bruit, uv).r;
	float n2 = texture(bruit, uv2).r;
	vec3 nm = normalize(vec3((n - 0.5) * 0.55, 1.0, (n2 - 0.5) * 0.55));
	NORMAL = normalize((VIEW_MATRIX * vec4(nm, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = profond;
	EMISSION = ciel * fres * 0.7 + profond * 0.5;
	ROUGHNESS = 0.03;
	SPECULAR = 0.95;
	// L'étang : un rectangle aux coins arrondis et aux bords en dents, qui se perd dans la vase des berges.
	vec2 q = abs(local / rayon);
	float r = pow(pow(q.x, 4.0) + pow(q.y, 4.0), 0.25);
	float bord = r + (n - 0.5) * 0.2 + (n2 - 0.5) * 0.05;
	ALPHA = (1.0 - smoothstep(0.84, 1.0, bord)) * 0.97;
}
"""
	_eau_mat = ShaderMaterial.new()
	_eau_mat.shader = sh
	_eau_mat.set_shader_parameter("rayon", Vector2(ETANG_RX, ETANG_RZ))
	var bruit := NoiseTexture2D.new()
	bruit.seamless = true
	bruit.width = 256
	bruit.height = 256
	var fn := FastNoiseLite.new()
	fn.frequency = 0.018
	bruit.noise = fn
	_eau_mat.set_shader_parameter("bruit", bruit)
	m.material_override = _eau_mat
	m.position = ETANG_C + Vector3(0, 0.04, 0)
	add_child(m)


func _brumes() -> void:
	# Trois nappes : une basse qui lèche l'eau, une moyenne, et un fond de brume au nord qui avale les arbres.
	var basse := _particules(70, 15.0, Vector3(ETANG_RX, 0.08, ETANG_RZ), Vector3(0.08, 0, 0.05), 2.8,
		_degrade([Color(0.62, 0.7, 0.74, 0.0), Color(0.58, 0.67, 0.72, 0.2), Color(0.55, 0.64, 0.7, 0.0)]), false)
	(basse.process_material as ParticleProcessMaterial).gravity = Vector3.ZERO
	basse.position = ETANG_C + Vector3(0, 0.16, 0)
	add_child(basse)
	var moyenne := _particules(40, 16.0, Vector3(ETANG_RX + 1.0, 0.2, ETANG_RZ), Vector3(-0.06, 0, 0.04), 4.4,
		_degrade([Color(0.5, 0.58, 0.64, 0.0), Color(0.46, 0.55, 0.62, 0.12), Color(0.44, 0.52, 0.6, 0.0)]), false)
	(moyenne.process_material as ParticleProcessMaterial).gravity = Vector3.ZERO
	moyenne.position = ETANG_C + Vector3(0, 0.7, 0)
	add_child(moyenne)
	var fond := _particules(30, 18.0, Vector3(9.5, 1.6, 1.4), Vector3(0.05, 0, 0), 5.5,
		_degrade([Color(0.36, 0.43, 0.5, 0.0), Color(0.34, 0.41, 0.48, 0.34), Color(0.3, 0.38, 0.45, 0.0)]), false)
	(fond.process_material as ParticleProcessMaterial).gravity = Vector3.ZERO
	fond.position = Vector3(0, 1.6, -15.6)
	add_child(fond)
	# Une seconde nappe, plus haute, à mi-parcours : elle voile le fond du marais depuis la rive.
	var voile := _particules(22, 18.0, Vector3(8.0, 0.9, 1.6), Vector3(-0.04, 0, 0), 5.0,
		_degrade([Color(0.4, 0.47, 0.54, 0.0), Color(0.38, 0.45, 0.52, 0.17), Color(0.36, 0.43, 0.5, 0.0)]), false)
	(voile.process_material as ParticleProcessMaterial).gravity = Vector3.ZERO
	voile.position = Vector3(0, 1.0, -7.6)
	add_child(voile)


func _lumieres() -> void:
	# Un clair de lune froid sur le marais (sans lui, le marcheur ne verrait plus ses pieds), et des lucioles.
	add_child(_lumiere(Color(0.5, 0.68, 0.85), 0.8, 10.0, Vector3(0, 3.0, -1.5)))
	add_child(_lumiere(Color(0.45, 0.6, 0.78), 0.65, 10.0, Vector3(0, 3.0, -7.0)))
	add_child(_lumiere(Color(0.4, 0.55, 0.7), 0.55, 10.0, Vector3(0, 3.0, -12.5)))
	var vol := _particules(90, 7.0, Vector3(ETANG_RX, 0.8, ETANG_RZ), Vector3(0, 0.04, 0), 0.05,
		_degrade([Color(0.8, 1.0, 0.45, 0.0), Color(0.85, 1.0, 0.5, 1.0), Color(0.7, 0.95, 0.4, 0.0)]), true)
	var pm := vol.process_material as ParticleProcessMaterial
	pm.spread = 180.0
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	vol.position = ETANG_C + Vector3(0, 0.9, 0)
	add_child(vol)
	var feux := _particules(16, 9.0, Vector3(ETANG_RX, 0.4, ETANG_RZ), Vector3(0, 0.03, 0), 0.09,
		_degrade([Color(0.4, 0.8, 1.0, 0.0), Color(0.5, 0.88, 1.0, 0.9), Color(0.4, 0.8, 1.0, 0.0)]), true)
	var pm2 := feux.process_material as ParticleProcessMaterial
	pm2.spread = 180.0
	pm2.gravity = Vector3.ZERO
	pm2.turbulence_enabled = true
	pm2.turbulence_noise_strength = 0.35
	feux.position = ETANG_C + Vector3(0, 0.5, 0)
	add_child(feux)


# ---------------------------------------------------------------- les rives

## Un point où l'on peut poser un décor sans gêner : ni joueur, ni zone du rôle, ni couloir d'arrivée.
func _place_ok(p: Vector3, r: float) -> bool:
	if not loin_des_joueurs(p, r + 0.9):
		return false
	for z in Quetes.ANGLES_ZONES.size():
		var v := Quetes.passage(z, Quetes.R_FOURCHE) - Quetes.zone(z)
		var b := Vector2(v.x, v.z).normalized() * 12.0
		if _dist_segment(Vector2(p.x, p.z), Vector2.ZERO, b) < r + 1.2:
			return false
	return true


## Un point de la berge de l'étang (angle a, décalage d en mètres vers l'extérieur). Le contour est un
## rectangle aux coins arrondis (comme l'eau), pas une ellipse.
func _berge(a: float, d: float) -> Vector3:
	var sx := signf(sin(a)) * sqrt(absf(sin(a)))
	var sz := signf(cos(a)) * sqrt(absf(cos(a)))
	var base := Vector3(sx * ETANG_RX, 0, sz * ETANG_RZ)
	var dehors := Vector3(base.x / (ETANG_RX * ETANG_RX), 0, base.z / (ETANG_RZ * ETANG_RZ)).normalized()
	return ETANG_C + base + dehors * d


## Est-ce la rive des guides (au sud, devant leurs postes) ? Elle reste dégagée.
func _rive_des_guides(c: Vector3) -> bool:
	return c.z > 1.8 and absf(c.x) < 6.2


func _roseaux(rng: RandomNumberGenerator, centres: Array[Vector3], mini_: int, maxi_: int, haut_min: float, haut_max: float) -> void:
	var tige := CylinderMesh.new()
	tige.top_radius = 0.003
	tige.bottom_radius = 0.011
	tige.height = 1.0
	tige.radial_segments = 4
	tige.rings = 1
	var m_tige := StandardMaterial3D.new()
	m_tige.vertex_color_use_as_albedo = true
	m_tige.roughness = 1.0
	m_tige.cull_mode = BaseMaterial3D.CULL_DISABLED
	tige.material = m_tige
	var tete := CapsuleMesh.new()
	tete.radius = 0.026
	tete.height = 0.2
	tete.radial_segments = 6
	tete.rings = 2
	var m_tete := StandardMaterial3D.new()
	m_tete.albedo_color = Color(0.2, 0.11, 0.07)
	m_tete.roughness = 1.0
	tete.material = m_tete
	var tiges: Array[Transform3D] = []
	var couleurs: Array[Color] = []
	var tetes: Array[Transform3D] = []
	for c in centres:
		for j in rng.randi_range(mini_, maxi_):
			var base := c + Vector3(rng.randf_range(-0.45, 0.45), 0.0, rng.randf_range(-0.45, 0.45))
			var h := rng.randf_range(haut_min, haut_max)
			var dir := Vector3(rng.randf_range(-0.22, 0.22), 1.0, rng.randf_range(-0.22, 0.22)).normalized()
			var b := Basis(Quaternion(Vector3.UP, dir)) * Basis.from_scale(Vector3(1, h, 1))
			tiges.append(Transform3D(b, base + dir * h * 0.5 + Vector3(0, 0.02, 0)))
			var g := rng.randf()
			couleurs.append(Color(0.16 + 0.1 * g, 0.2 + 0.1 * g, 0.09 + 0.04 * g))
			if rng.randf() < 0.22:
				var bt := Basis(Quaternion(Vector3.UP, dir))
				tetes.append(Transform3D(bt, base + dir * h * 0.93 + Vector3(0, 0.02, 0)))
	_multi(tige, tiges, couleurs)
	_multi(tete, tetes, [])


func _rives() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7117
	# --- les roseaux : une multimesh de tiges minces, penchées, et des massettes aux sommets.
	var touffes: Array[Vector3] = []
	for i in 190:
		var c := _berge(rng.randf() * TAU, rng.randf_range(-0.6, 1.4))
		if _rive_des_guides(c) or not _place_ok(c, 0.7):
			continue
		touffes.append(c)
	_roseaux(rng, touffes, 8, 16, 0.9, 2.2)
	# --- des touffes d'herbe haute, des fougères, des orties sur la terre ferme.
	for i in 110:
		var a := rng.randf() * TAU
		var p := _berge(a, rng.randf_range(0.5, 2.8))
		if p.z > 3.0 and absf(p.x) < 6.8:
			continue
		if not _place_ok(p, 0.5):
			continue
		var lot := "grass_medium_01" if i % 3 != 0 else "fern_02"
		var n := morceau(lot, rng.randi() % nb_morceaux(lot), p, rng.randf_range(1.4, 2.4), rng.randf() * TAU)
		n.add_to_group("traversable")
	# --- des monticules de roche moussue qui affleurent aux bords.
	for i in 16:
		var a := rng.randf() * TAU
		var p := _berge(a, rng.randf_range(-0.1, 1.2))
		if (p.z > 2.0 and absf(p.x) < 6.6) or not _place_ok(p, 1.0):
			continue
		var lot := "rock_moss_set_01" if i % 2 == 0 else "rock_moss_set_02"
		morceau(lot, rng.randi() % nb_morceaux(lot), p + Vector3(0, -0.18, 0), rng.randf_range(0.55, 0.95), rng.randf() * TAU)


func _multi(mesh: Mesh, ts: Array[Transform3D], cols: Array) -> void:
	if ts.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	mm.mesh = mesh
	mm.instance_count = ts.size()
	for i in ts.size():
		mm.set_instance_transform(i, ts[i])
		if not cols.is_empty():
			mm.set_instance_color(i, cols[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.add_to_group("traversable")
	add_child(mi)


# ---------------------------------------------------------------- arbres morts, souches, racines

func _arbres_morts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var bois := matiere("tronc", 1.2, Color(0.5, 0.47, 0.44))
	# Au nord (les plans qui se perdent dans la brume), puis sur les flancs, du sud au nord.
	var lieux: Array[Vector3] = [
		Vector3(-3.2, 0, -16.6), Vector3(2.4, 0, -17.2), Vector3(5.6, 0, -16.0), Vector3(-6.4, 0, -15.4),
		Vector3(0.2, 0, -19.0), Vector3(-9.2, 0, -12.5), Vector3(9.4, 0, -13.5), Vector3(-9.6, 0, -6.0),
		Vector3(9.8, 0, -8.0), Vector3(-9.0, 0, 0.5), Vector3(9.2, 0, -2.5), Vector3(8.6, 0, 1.6)]
	for k in lieux.size():
		var p := lieux[k]
		if not _place_ok(p, 0.5):
			continue
		_arbre_mort(p, rng.randf_range(3.6, 6.4) * (1.3 if p.z < -14.0 else 1.0), rng, bois)


func _arbre_mort(pied: Vector3, haut: float, rng: RandomNumberGenerator, bois: Material) -> void:
	var penche := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
	var cime := pied + Vector3(0, haut, 0) + penche * haut
	var tronc := poutre(pied + Vector3(0, -0.2, 0), cime, 0.13, bois)
	(tronc.mesh as CylinderMesh).top_radius = 0.045
	(tronc.mesh as CylinderMesh).bottom_radius = 0.2
	# Un évasement de racines à la base.
	for r in 4:
		var a := r * TAU / 4.0 + rng.randf()
		var bout := pied + Vector3(sin(a), 0.0, cos(a)) * rng.randf_range(0.5, 0.8)
		var rac := poutre(pied + Vector3(0, 0.35, 0), bout + Vector3(0, -0.05, 0), 0.07, bois)
		rac.add_to_group("traversable")
	# Des branches tordues, sans feuilles, de plus en plus fines vers le haut.
	for b in rng.randi_range(5, 8):
		var t := rng.randf_range(0.35, 0.95)
		var a := rng.randf() * TAU
		var depart := pied + Vector3(0, haut * t, 0) + penche * haut * t
		var l := rng.randf_range(0.7, 1.7) * (1.2 - t * 0.5)
		var arrivee := depart + Vector3(sin(a) * l, rng.randf_range(0.2, 0.9) * l, cos(a) * l)
		var br := poutre(depart, arrivee, 0.045 * (1.2 - t * 0.6), bois)
		br.add_to_group("traversable")
		# Une brindille au bout.
		var a2 := a + rng.randf_range(-1.0, 1.0)
		var br2 := poutre(arrivee, arrivee + Vector3(sin(a2) * l * 0.45, l * 0.3, cos(a2) * l * 0.45), 0.02, bois)
		br2.add_to_group("traversable")


func _souches_et_racines() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	# Des souches moussues, à moitié dans l'eau.
	var souches: Array[Vector3] = [Vector3(-8.3, 0, -9.4), Vector3(8.0, 0, -11.0), Vector3(-7.6, 0, -13.8), Vector3(8.4, 0, -5.6),
		Vector3(-8.6, 0, -3.0), Vector3(7.8, 0, -15.0)]
	for k in souches.size():
		var p := souches[k]
		if _place_ok(p, 0.9):
			modele("tree_stump_01" if k % 2 == 0 else "tree_stump_02", p + Vector3(0, 0.1, 0), rng.randf_range(0.7, 1.0), rng.randf() * TAU)
	# Des troncs couchés, la moitié dans l'eau, et des racines qui sortent de la vase.
	var couches: Array[Array] = [[Vector3(-8.0, 0, -7.0), 1.35], [Vector3(2.6, 0, -16.4), 0.05], [Vector3(-3.4, 0, -16.8), 0.2]]
	for c in couches:
		var p: Vector3 = c[0]
		if _place_ok(p, 1.6):
			modele("dead_tree_trunk_02", p + Vector3(0, 0.12, 0), 0.7, float(c[1]))
	var racines: Array[Vector3] = [Vector3(8.9, 0, -9.0), Vector3(-8.8, 0, -11.2), Vector3(6.4, 0, -16.6)]
	for p in racines:
		if _place_ok(p, 1.6):
			modele("root_cluster_01", p + Vector3(0, 0.0, 0), rng.randf_range(0.5, 0.7), rng.randf() * TAU)
	for i in 8:
		var a := rng.randf() * TAU
		var p := _berge(a, 0.2)
		if _rive_des_guides(p) or not _place_ok(p, 0.8):
			continue
		modele("pine_roots", p + Vector3(0, 0.02, 0), rng.randf_range(0.9, 1.4), rng.randf() * TAU)


# ---------------------------------------------------------------- les pierres

func _unshaded_additif(c: Color, tex: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	if tex != null:
		m.albedo_texture = tex
	m.disable_receive_shadows = true
	m.no_depth_test = false
	return m


## Le marais fait l × h pierres : on le bâtit à la première vue (l, h et la carte y figurent).
func _batir(g: Dictionary) -> void:
	_taille = int(g.get("l", 5))
	_haut = int(g.get("h", _taille))
	var v := str(g.get("v", ""))
	_iles = g.get("iles", [])
	var niveau := str(g.get("niveau", "normal"))
	var tache := _tache()
	for k in _taille * _haut:
		if k >= v.length() or v[k] == "~":
			_pierres.append(null)
			continue
		var c := Quetes.case_marais(k, _taille, _haut)
		var porte := Node3D.new()
		porte.position = c
		add_child(porte)
		# Une vraie roche moussue de la clairière, aplatie en dalle irrégulière.
		var lot := "rock_moss_set_02" if k % 3 != 2 else "rock_moss_set_01"
		var roc := morceau(lot, (k * 5 + 1) % nb_morceaux(lot), Vector3.ZERO, 1.0, k * 1.9, porte)
		var mi: MeshInstance3D = roc.get_child(0)
		mi.material_override = _m_roche
		var b := mi.mesh.get_aabb().size
		var ile := _iles.has(k)
		var ech := (0.86 + 0.14 * sin(k * 1.37)) / maxf(b.x, b.z) * (1.3 if ile else 1.0)
		var ech_y := ech * 0.55
		roc.scale = Vector3(ech * (1.0 + 0.12 * sin(k * 2.9)), ech_y, ech * (1.0 + 0.12 * cos(k * 2.1)))
		roc.position.y = HAUT_PIERRE - b.y * ech_y * 0.92
		roc.add_to_group("traversable")
		# De la mousse vive sur le dessus.
		var mousse := _sphere(0.13, _mat("mousse_vive", Color(0.2, 0.36, 0.13)))
		mousse.scale = Vector3(1.5, 0.22, 1.2)
		mousse.position = Vector3(0.12 * sin(k * 1.7), HAUT_PIERRE - 0.01, 0.1 * cos(k * 1.3))
		porte.add_child(mousse)
		mousse.add_to_group("traversable")
		# L'anneau d'eau autour de la pierre : une onde lente, pour sentir la profondeur.
		var onde := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = Quetes.R_PIERRE + 0.1
		tm.outer_radius = Quetes.R_PIERRE + 0.125
		tm.rings = 24
		tm.ring_segments = 4
		onde.mesh = tm
		onde.scale.y = 0.05
		onde.position.y = 0.045
		onde.material_override = _unshaded_additif(Color(0.55, 0.75, 0.85, 0.12))
		porte.add_child(onde)
		onde.add_to_group("traversable")
		# L'anneau de trace du marcheur (bleu), sur le dessus.
		var tr := MeshInstance3D.new()
		var tt := TorusMesh.new()
		tt.inner_radius = 0.26
		tt.outer_radius = 0.3
		tt.rings = 24
		tt.ring_segments = 4
		tr.mesh = tt
		tr.scale.y = 0.2
		tr.position.y = HAUT_PIERRE + 0.01
		tr.material_override = _unshaded_additif(Color(0.4, 0.75, 1.0, 0.8))
		tr.visible = false
		porte.add_child(tr)
		tr.add_to_group("traversable")
		_pierres.append({"porte": porte, "mi": mi, "trace": tr, "onde": onde, "lampe": null, "reflet": null, "bulles": null,
			"k": k, "vit": 0.0})
	_batir_vies(niveau)
	_batir_balises()
	_batir_reperes()
	_batir_troncons(g, v, niveau)
	_batir_decor_vivant(v)


## La lanterne ancienne posée sur la pierre (vue des guides seulement), son reflet dans l'eau : bâtie à la
## demande, la première fois qu'un guide la voit allumée (le marcheur n'en voit jamais).
func _lampe_de(p: Dictionary) -> void:
	var k: int = p["k"]
	var porte: Node3D = p["porte"]
	var tache := _tache()
	var lan := Node3D.new()
	lan.position = Vector3(0.12 * sin(k * 3.1 + 1.0), HAUT_PIERRE, 0.12 * cos(k * 3.1 + 1.0))
	var cage := modele("wooden_lantern_01", Vector3.ZERO, 0.85, k * 0.8, lan)
	cage.add_to_group("traversable")
	var flamme := _sphere(0.035, matiere("flamme", 1.0, Color(1, 0.85, 0.5), Color(1.0, 0.7, 0.3)))
	flamme.position = Vector3(0, 0.13, 0)
	flamme.scale = Vector3(1, 1.6, 1)
	lan.add_child(flamme)
	flamme.add_to_group("traversable")
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(0.55, 0.55)
	halo.mesh = hq
	var hm := _unshaded_additif(Color(1.0, 0.7, 0.3, 0.5), tache)
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo.material_override = hm
	halo.position = Vector3(0, 0.15, 0)
	lan.add_child(halo)
	halo.add_to_group("traversable")
	if k % 3 == 0 and _nb_lampes < 14:
		_nb_lampes += 1
		var l := _lumiere(Color(1.0, 0.66, 0.32), 0.7, 2.4, Vector3(0, 0.35, 0))
		lan.add_child(l)
		_feux.append([l, 0.75, randf() * 10.0])
	porte.add_child(lan)
	var reflet := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.9)
	q.orientation = PlaneMesh.FACE_Y
	reflet.mesh = q
	reflet.material_override = _unshaded_additif(Color(1.0, 0.68, 0.32, 0.3), tache)
	reflet.position = Vector3(lan.position.x, 0.05, lan.position.z + 0.35)
	porte.add_child(reflet)
	p["lampe"] = lan
	p["reflet"] = reflet


## Des bulles de vase quand la pierre est un piège (bâties à la demande).
func _bulles_de(p: Dictionary) -> void:
	var bulles := _particules(6, 1.2, Vector3(0.2, 0.01, 0.2), Vector3(0, 0.1, 0), 0.07,
		_degrade([Color(0.5, 0.6, 0.55, 0.0), Color(0.6, 0.7, 0.65, 0.8), Color(0.5, 0.6, 0.55, 0.0)]), false)
	bulles.position = Vector3(0, 0.08, 0)
	bulles.emitting = false
	(p["porte"] as Node3D).add_child(bulles)
	p["bulles"] = bulles


# ---------------------------------------------------------------- les étapes : poteaux des îlots, repères

func _z_nord() -> float:
	return Quetes.MARAIS_SUD - (_haut - 1) * Quetes.MARAIS_PAS


func _demi_largeur() -> float:
	return (_taille - 1) * 0.5 * Quetes.MARAIS_PAS


## Un poteau d'îlot : une lanterne colorée tenue par un mât, qu'on voit de loin (« le poteau bleu »).
func _batir_balises() -> void:
	var couleurs: Array[Color] = [Color(1.0, 0.22, 0.16), Color(0.28, 0.52, 1.0), Color(0.3, 1.0, 0.42)]
	for i in _iles.size():
		var k: int = _iles[i]
		var c := Quetes.case_marais(k, _taille, _haut)
		var col := couleurs[i % couleurs.size()]
		var bois := matiere("bois", 1.0, Color(0.5, 0.4, 0.3))
		var mat := poutre(c + Vector3(0.25, HAUT_PIERRE - 0.1, 0.0), c + Vector3(0.25, 3.0, 0.0), 0.06, bois)
		mat.add_to_group("traversable")
		var bras := poutre(c + Vector3(0.25, 2.95, 0.0), c + Vector3(-0.1, 2.95, 0.0), 0.035, bois)
		bras.add_to_group("traversable")
		var cage := _sphere(0.2, _mat("balise_%d" % i, col * 0.8, col))
		cage.position = c + Vector3(-0.1, 2.65, 0.0)
		add_child(cage)
		cage.add_to_group("traversable")
		var halo := MeshInstance3D.new()
		var hq := QuadMesh.new()
		hq.size = Vector2(2.4, 2.4)
		halo.mesh = hq
		var hm := _unshaded_additif(Color(col.r, col.g, col.b, 0.5), _tache())
		hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		halo.material_override = hm
		halo.position = cage.position
		add_child(halo)
		halo.add_to_group("traversable")
		var l := _lumiere(col, 1.6, 6.5, cage.position)
		add_child(l)
		_feux.append([l, 1.6, randf() * 10.0])
		_balises.append(l)


## La poutre des lanternes de vie, au nord du marais : deux poteaux dans l'eau, une traverse, des
## lanternes qui pendent (assez grosses pour se lire depuis la rive, 17 m plus loin).
func _batir_vies(_niveau: String) -> void:
	var z := _z_nord() - 1.7
	var demi := 3.8
	var bois := matiere("bois", 1.0, Color(0.5, 0.4, 0.3))
	for cote: float in [-1.0, 1.0]:
		var p := _cylindre(0.08, 3.4, bois)
		p.position = Vector3(cote * demi, 1.5, z)
		add_child(p)
		var pied := _cylindre(0.2, 0.3, matiere("mousse", 0.8, Color(0.5, 0.65, 0.4)))
		pied.position = Vector3(cote * demi, 0.0, z)
		add_child(pied)
	var traverse := _boite(Vector3(demi * 2.0 + 0.3, 0.1, 0.1), bois)
	traverse.position = Vector3(0, 2.9, z)
	add_child(traverse)
	_etiquette_vies = _debout("Lanternes de vie du marcheur", 140, Vector3(0, 3.5, z))
	_etiquette_vies.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_etiquette_vies)


func _faire_vies(maxi_: int) -> void:
	_vies_max = maxi_
	for n in _vies:
		(n as Node3D).queue_free()
	_vies.clear()
	var z := _z_nord() - 1.7
	var pas := minf(0.72, 6.6 / maxf(maxi_, 1))
	for i in maxi_:
		var n := Node3D.new()
		n.position = Vector3((i - (maxi_ - 1) * 0.5) * pas, 2.86, z)
		var cordon := _cylindre(0.01, 0.4, _mat("poteau", Color(0.14, 0.1, 0.07)))
		cordon.position = Vector3(0, -0.2, 0)
		n.add_child(cordon)
		var cage := _sphere(0.2 if maxi_ <= 3 else 0.16, _m_vie_on)
		cage.name = "cage"
		cage.position = Vector3(0, -0.55, 0)
		n.add_child(cage)
		add_child(n)
		_vies.append(n)
	_vies_etat = -2


## Les repères nommés à la voix (cf. Marais.REPERES), posés sur les berges le long du marais.
func _batir_reperes() -> void:
	var demi := _demi_largeur() + 1.75
	for r: Dictionary in Marais.REPERES:
		var z := lerpf(Quetes.MARAIS_SUD - 0.6, _z_nord(), float(r["f"]))
		var p := Vector3(float(r["cote"]) * demi, 0.0, z)
		match str(r["nom"]):
			"la barque échouée":
				_repere_barque(p)
			"le grand saule":
				_repere_saule(p)
			"le tronc couché":
				_repere_tronc(p)
			"la cabane du pêcheur":
				_repere_cabane(p)
			"la pierre dressée":
				_repere_pierre(p)
			"le héron de pierre":
				_repere_heron(p)


func _repere_barque(p: Vector3) -> void:
	var n := Node3D.new()
	n.position = p + Vector3(0, 0.06, 0)
	n.rotation = Vector3(0.0, 0.5, 0.12)
	add_child(n)
	var bois := matiere("vieux_bois", 1.2, Color(0.55, 0.45, 0.35))
	var fond := _boite(Vector3(0.8, 0.07, 2.6), bois)
	n.add_child(fond)
	for cote: float in [-1.0, 1.0]:
		var flanc := _boite(Vector3(0.07, 0.42, 2.7), bois)
		flanc.position = Vector3(cote * 0.46, 0.2, 0.0)
		flanc.rotation.z = -cote * 0.18
		n.add_child(flanc)
		var proue := _boite(Vector3(0.07, 0.42, 0.9), bois)
		proue.position = Vector3(cote * 0.28, 0.2, -1.55)
		proue.rotation = Vector3(0.0, cote * 0.5, -cote * 0.15)
		n.add_child(proue)
	var banc := _boite(Vector3(0.9, 0.05, 0.22), bois)
	banc.position = Vector3(0, 0.3, 0.2)
	n.add_child(banc)
	# Une lanterne de proue : la barque se repère de loin.
	var mat := poutre(Vector3(0, 0.1, -1.7), Vector3(0, 1.3, -1.7), 0.035, bois, n)
	mat.add_to_group("traversable")
	var flamme := _sphere(0.09, matiere("flamme", 1.0, Color(1, 0.8, 0.45), Color(1.0, 0.65, 0.25)))
	flamme.position = Vector3(0, 1.25, -1.7)
	n.add_child(flamme)
	var l := _lumiere(Color(1.0, 0.68, 0.34), 1.2, 5.0, p + Vector3(0, 1.4, 0))
	add_child(l)
	_feux.append([l, 1.2, randf() * 10.0])
	for e in n.get_children():
		if e is MeshInstance3D:
			e.add_to_group("traversable")


func _repere_saule(p: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3131
	var bois := matiere("tronc", 1.2, Color(0.45, 0.42, 0.38))
	var cime := p + Vector3(-signf(p.x) * 0.9, 3.4, 0.0)
	var tronc := poutre(p + Vector3(0, -0.2, 0), cime, 0.3, bois)
	(tronc.mesh as CylinderMesh).top_radius = 0.18
	(tronc.mesh as CylinderMesh).bottom_radius = 0.42
	for b in 5:
		var a := b * TAU / 5.0 + 0.4
		var bout := cime + Vector3(sin(a) * 1.8, 0.4, cos(a) * 1.8)
		poutre(cime - Vector3(0, 0.3, 0), bout, 0.07, bois)
	# La frondaison : des centaines de lanieres pâles qui pendent jusqu'à l'eau.
	var laniere := CylinderMesh.new()
	laniere.top_radius = 0.012
	laniere.bottom_radius = 0.003
	laniere.height = 1.0
	laniere.radial_segments = 3
	laniere.rings = 1
	var ml := StandardMaterial3D.new()
	ml.vertex_color_use_as_albedo = true
	ml.roughness = 1.0
	ml.cull_mode = BaseMaterial3D.CULL_DISABLED
	laniere.material = ml
	var ts: Array[Transform3D] = []
	var cs: Array[Color] = []
	for i in 160:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 1.9
		var haut := rng.randf_range(1.6, 3.2)
		var base := cime + Vector3(sin(a) * r, 0.1 - rng.randf() * 0.5, cos(a) * r)
		ts.append(Transform3D(Basis.from_scale(Vector3(1, haut, 1)), base - Vector3(0, haut * 0.5, 0)))
		var g := rng.randf()
		cs.append(Color(0.2 + 0.12 * g, 0.3 + 0.14 * g, 0.16 + 0.06 * g))
	_multi(laniere, ts, cs)


func _repere_tronc(p: Vector3) -> void:
	var t := modele("dead_tree_trunk_02", p + Vector3(0, 0.14, 0), 1.15, 1.2 if p.x > 0 else 1.9)
	t.add_to_group("traversable")
	# Une mousse luisante sur le dessus pour le reconnaître de loin.
	var m := _sphere(0.3, _mat("mousse_tronc", Color(0.25, 0.5, 0.2), Color(0.1, 0.35, 0.12)))
	m.scale = Vector3(1.8, 0.35, 1.0)
	m.position = p + Vector3(0, 0.75, 0)
	add_child(m)
	m.add_to_group("traversable")


func _repere_cabane(p: Vector3) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = -signf(p.x) * 0.5 + PI * 0.5 * (1.0 if p.x < 0 else -1.0) * 0.0
	add_child(n)
	var bois := matiere("bois", 1.0, Color(0.55, 0.45, 0.35))
	for x: float in [-0.9, 0.9]:
		for z: float in [-0.7, 0.7]:
			var pilotis := poutre(Vector3(x, -0.3, z), Vector3(x, 0.9, z), 0.07, bois, n)
			pilotis.add_to_group("traversable")
	var plancher := _boite(Vector3(2.2, 0.1, 1.8), bois)
	plancher.position = Vector3(0, 0.9, 0)
	n.add_child(plancher)
	var murs := _boite(Vector3(2.0, 1.4, 1.6), matiere("bois", 1.4, Color(0.42, 0.34, 0.27)))
	murs.position = Vector3(0, 1.65, 0)
	n.add_child(murs)
	for cote: float in [-1.0, 1.0]:
		var toit := _boite(Vector3(2.5, 0.08, 1.15), matiere("tuiles", 1.0, Color(0.4, 0.35, 0.3)))
		toit.position = Vector3(0, 2.55, cote * 0.5)
		toit.rotation.x = cote * 0.5
		n.add_child(toit)
	# Une fenêtre allumée, qui se voit de toute la rive.
	var fen := _boite(Vector3(0.5, 0.4, 0.05), _mat("fenetre", Color(1.0, 0.8, 0.4), Color(1.0, 0.65, 0.2)))
	fen.position = Vector3(0, 1.75, 0.82)
	n.add_child(fen)
	var porte := _boite(Vector3(0.5, 1.0, 0.05), matiere("bois", 1.0, Color(0.3, 0.22, 0.16)))
	porte.position = Vector3(-0.6, 1.5, 0.82)
	n.add_child(porte)
	var l := _lumiere(Color(1.0, 0.7, 0.35), 1.4, 6.0, p + Vector3(0, 1.8, 0.9))
	add_child(l)
	_feux.append([l, 1.4, randf() * 10.0])
	for e in n.get_children():
		if e is MeshInstance3D:
			e.add_to_group("traversable")


func _repere_pierre(p: Vector3) -> void:
	# Un menhir moussu, haut de trois mètres, gravé de runes qui luisent.
	var bloc := _boite(Vector3(0.8, 3.1, 0.5), _m_roche)
	bloc.position = p + Vector3(0, 1.45, 0)
	bloc.rotation = Vector3(0.05, 0.4, -0.04)
	add_child(bloc)
	var base := _boite(Vector3(1.2, 0.4, 0.9), _m_roche)
	base.position = p + Vector3(0, 0.1, 0)
	base.rotation.y = 0.3
	add_child(base)
	var rune_m := _unshaded_additif(Color(0.4, 0.9, 1.0, 0.9))
	for i in 5:
		var r := _boite(Vector3(0.28 - 0.03 * (i % 3), 0.05, 0.02), rune_m)
		r.position = p + Vector3(-0.02 * i, 1.0 + 0.4 * i, 0.27).rotated(Vector3.UP, 0.4)
		r.rotation = Vector3(0.0, 0.4, 0.5 * (i % 2) - 0.25)
		add_child(r)
		r.add_to_group("traversable")
	var l := _lumiere(Color(0.4, 0.85, 1.0), 0.9, 5.0, p + Vector3(0, 2.0, 0.6))
	add_child(l)


func _repere_heron(p: Vector3) -> void:
	# Un héron de pierre, dressé sur une patte, la tête tournée vers le marais.
	var n := Node3D.new()
	n.position = p
	n.rotation.y = PI * 0.5 * signf(p.x) * -1.0
	add_child(n)
	var pierre := _m_roche
	var socle := _cylindre(0.55, 0.3, pierre, 0.45)
	socle.position = Vector3(0, 0.1, 0)
	n.add_child(socle)
	var patte := _cylindre(0.045, 1.3, pierre)
	patte.position = Vector3(0, 0.9, 0)
	n.add_child(patte)
	var corps := _sphere(0.3, pierre)
	corps.scale = Vector3(0.9, 0.9, 1.7)
	corps.position = Vector3(0, 1.65, 0)
	n.add_child(corps)
	var cou := poutre(Vector3(0, 1.8, 0.45), Vector3(0, 2.7, 0.8), 0.065, pierre, n)
	cou.add_to_group("traversable")
	var cou2 := poutre(Vector3(0, 2.7, 0.8), Vector3(0, 2.95, 0.55), 0.06, pierre, n)
	cou2.add_to_group("traversable")
	var tete := _sphere(0.1, pierre)
	tete.position = Vector3(0, 2.98, 0.52)
	n.add_child(tete)
	var bec := _cylindre(0.045, 0.55, pierre, 0.0)
	bec.position = Vector3(0, 2.93, 0.84)
	bec.rotation.x = PI * 0.5 + 0.15
	n.add_child(bec)
	var oeil := _sphere(0.03, _mat("oeil_heron", Color(1.0, 0.9, 0.4), Color(1.0, 0.8, 0.2)))
	oeil.position = Vector3(0.08, 3.0, 0.5)
	n.add_child(oeil)
	var oeil2 := _sphere(0.03, _mat("oeil_heron", Color(1.0, 0.9, 0.4), Color(1.0, 0.8, 0.2)))
	oeil2.position = Vector3(-0.08, 3.0, 0.5)
	n.add_child(oeil2)
	var aile := _boite(Vector3(0.05, 0.55, 0.9), pierre)
	aile.position = Vector3(0.28, 1.65, -0.1)
	aile.rotation = Vector3(0.2, 0.0, 0.15)
	n.add_child(aile)
	var aile2 := _boite(Vector3(0.05, 0.55, 0.9), pierre)
	aile2.position = Vector3(-0.28, 1.65, -0.1)
	aile2.rotation = Vector3(0.2, 0.0, -0.15)
	n.add_child(aile2)
	for e in n.get_children():
		if e is MeshInstance3D:
			e.add_to_group("traversable")
	var l := _lumiere(Color(1.0, 0.85, 0.4), 0.7, 4.0, p + Vector3(0, 3.0, 0.6))
	add_child(l)


## Les trois tronçons ont chacun leur ambiance : le Gué (clair, des roseaux), la Tourbière (une brume
## verdâtre, des feux follets), le Bois noyé (des troncs debout dans l'eau, des mousses qui pendent).
func _batir_troncons(g: Dictionary, v: String, niveau: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var s := Marais.nb_etapes(niveau)
	var rangees: Array = []
	for ile in _iles:
		rangees.append(int(ile) / _taille)
	var trous_par_bande := {}
	for k in _taille * _haut:
		if k < v.length() and v[k] == "~":
			var bande := Marais.etape_de_rangee(k / _taille, rangees)
			if not trous_par_bande.has(bande):
				trous_par_bande[bande] = []
			(trous_par_bande[bande] as Array).append(k)
	var bois := matiere("tronc", 1.2, Color(0.4, 0.38, 0.35))
	for bande in s:
		var nom := Marais.nom_etape(bande, s)
		var trous: Array = trous_par_bande.get(bande, [])
		# Les rangées de la bande, pour y placer ses brumes.
		var z_haut := _z_nord()
		var z_bas := Quetes.MARAIS_SUD
		if bande > 0 and bande - 1 < rangees.size():
			z_bas = Quetes.case_marais(int(rangees[bande - 1]) * _taille, _taille, _haut).z
		if bande < rangees.size():
			z_haut = Quetes.case_marais(int(rangees[bande]) * _taille, _taille, _haut).z
		var z_mid := (z_haut + z_bas) * 0.5
		var demi_z := absf(z_bas - z_haut) * 0.5 + 0.8
		match nom:
			"La Tourbière":
				var tourbe := _particules(36, 12.0, Vector3(_demi_largeur() + 1.2, 0.18, demi_z), Vector3(0.05, 0, 0.03), 2.6,
					_degrade([Color(0.45, 0.62, 0.5, 0.0), Color(0.42, 0.6, 0.48, 0.27), Color(0.4, 0.56, 0.45, 0.0)]), false)
				(tourbe.process_material as ParticleProcessMaterial).gravity = Vector3.ZERO
				tourbe.position = Vector3(0, 0.3, z_mid)
				add_child(tourbe)
				var feux := _particules(10, 7.0, Vector3(_demi_largeur() + 1.0, 0.3, demi_z), Vector3(0, 0.05, 0), 0.16,
					_degrade([Color(0.5, 1.0, 0.8, 0.0), Color(0.6, 1.0, 0.85, 0.95), Color(0.5, 1.0, 0.8, 0.0)]), true)
				var pm := feux.process_material as ParticleProcessMaterial
				pm.spread = 180.0
				pm.gravity = Vector3.ZERO
				pm.turbulence_enabled = true
				pm.turbulence_noise_strength = 0.6
				feux.position = Vector3(0, 0.7, z_mid)
				add_child(feux)
				# De sombres touffes de joncs dans les trous.
				var touffes: Array[Vector3] = []
				for k in trous:
					if rng.randf() < 0.35:
						touffes.append(Quetes.case_marais(int(k), _taille, _haut) + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)))
				_roseaux(rng, touffes, 6, 12, 0.5, 1.2)
			"Le Bois noyé":
				var brume := _particules(28, 14.0, Vector3(_demi_largeur() + 1.2, 0.5, demi_z), Vector3(-0.04, 0, 0.02), 3.4,
					_degrade([Color(0.3, 0.38, 0.46, 0.0), Color(0.28, 0.36, 0.44, 0.3), Color(0.26, 0.34, 0.42, 0.0)]), false)
				(brume.process_material as ParticleProcessMaterial).gravity = Vector3.ZERO
				brume.position = Vector3(0, 0.9, z_mid)
				add_child(brume)
				# Des troncs morts plantés dans les trous du marais, des mousses qui pendent des branches.
				var nb := 0
				trous.shuffle()
				for k in trous:
					if nb >= 11:
						break
					var c := Quetes.case_marais(int(k), _taille, _haut) + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
					if not _place_ok(c, 0.3):
						continue
					nb += 1
					_arbre_noye(c, rng.randf_range(2.6, 4.6), rng, bois)
			"La Lanterne":
				var lumiere := _particules(24, 6.0, Vector3(_demi_largeur() + 1.0, 0.8, demi_z), Vector3(0, 0.05, 0), 0.07,
					_degrade([Color(1.0, 0.85, 0.5, 0.0), Color(1.0, 0.85, 0.5, 0.9), Color(1.0, 0.8, 0.4, 0.0)]), true)
				var pm3 := lumiere.process_material as ParticleProcessMaterial
				pm3.spread = 180.0
				pm3.gravity = Vector3.ZERO
				pm3.turbulence_enabled = true
				pm3.turbulence_noise_strength = 0.4
				lumiere.position = Vector3(0, 0.9, z_mid)
				add_child(lumiere)
			_:
				# Le Gué : clair, quelques touffes de roseaux dans les trous.
				var touffes2: Array[Vector3] = []
				for k in trous:
					if rng.randf() < 0.18:
						touffes2.append(Quetes.case_marais(int(k), _taille, _haut) + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)))
				_roseaux(rng, touffes2, 5, 9, 0.7, 1.5)


## Un tronc mort planté dans l'eau, avec des lanieres de mousse qui pendent.
func _arbre_noye(pied: Vector3, haut: float, rng: RandomNumberGenerator, bois: Material) -> void:
	_arbre_mort(pied, haut, rng, bois)
	for i in 5:
		var a := rng.randf() * TAU
		var depart := pied + Vector3(sin(a) * 0.5, haut * rng.randf_range(0.5, 0.9), cos(a) * 0.5)
		var m := poutre(depart, depart - Vector3(0, rng.randf_range(0.7, 1.5), 0), 0.012, _mat("mousse_pend", Color(0.3, 0.42, 0.25)))
		m.add_to_group("traversable")


## Le marais vivant : des touffes de roseaux dans quelques trous, des nénuphars, des algues.
func _batir_decor_vivant(v: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3030
	var galette := CylinderMesh.new()
	galette.top_radius = 0.16
	galette.bottom_radius = 0.16
	galette.height = 0.006
	galette.radial_segments = 14
	galette.rings = 1
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.6
	galette.material = m
	var algue := CylinderMesh.new()
	algue.top_radius = 0.5
	algue.bottom_radius = 0.5
	algue.height = 0.004
	algue.radial_segments = 12
	algue.rings = 1
	var ma := StandardMaterial3D.new()
	ma.vertex_color_use_as_albedo = true
	ma.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ma.roughness = 1.0
	algue.material = ma
	var pads: Array[Transform3D] = []
	var cpads: Array[Color] = []
	var algues: Array[Transform3D] = []
	var calg: Array[Color] = []
	var fleurs: Array[Transform3D] = []
	for i in 360:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.95
		var p := ETANG_C + Vector3(sin(a) * ETANG_RX * r, 0.047, cos(a) * ETANG_RZ * r)
		if p.z > 2.2:
			continue
		# Pas sur une pierre.
		var sur_pierre := false
		var gx := roundi(p.x / Quetes.MARAIS_PAS + (_taille - 1) * 0.5)
		var gy := roundi((p.z - Quetes.MARAIS_SUD) / Quetes.MARAIS_PAS + (_haut - 1))
		for y in range(gy - 1, gy + 2):
			for x in range(gx - 1, gx + 2):
				if x < 0 or y < 0 or x >= _taille or y >= _haut:
					continue
				if y * _taille + x < _pierres.size() and _pierres[y * _taille + x] != null:
					var c := Quetes.case_marais(y * _taille + x, _taille, _haut)
					if Vector2(p.x - c.x, p.z - c.z).length() < Quetes.R_PIERRE + 0.18:
						sur_pierre = true
		if sur_pierre:
			continue
		if i % 4 == 0:
			var s := rng.randf_range(0.8, 2.0)
			algues.append(Transform3D(Basis.from_scale(Vector3(s, 1, s * rng.randf_range(0.6, 1.1))).rotated(Vector3.UP, rng.randf() * TAU), p - Vector3(0, 0.005, 0)))
			calg.append(Color(0.1 + 0.05 * rng.randf(), 0.22 + 0.08 * rng.randf(), 0.1, 0.5))
		else:
			var s2 := rng.randf_range(0.7, 1.5)
			pads.append(Transform3D(Basis.from_scale(Vector3(s2, 1, s2)).rotated(Vector3.UP, rng.randf() * TAU), p))
			cpads.append(Color(0.1 + 0.06 * rng.randf(), 0.25 + 0.1 * rng.randf(), 0.1 + 0.03 * rng.randf()))
			if rng.randf() < 0.12:
				fleurs.append(Transform3D(Basis.IDENTITY, p + Vector3(0, 0.03, 0)))
	_multi(galette, pads, cpads)
	_multi(algue, algues, calg)
	var fl := SphereMesh.new()
	fl.radius = 0.04
	fl.height = 0.07
	fl.radial_segments = 8
	fl.rings = 4
	fl.material = _mat("fleur", Color(0.9, 0.85, 0.9), Color(0.7, 0.6, 0.8))
	_multi(fl, fleurs, [])


# ---------------------------------------------------------------- la vie du marais

func animer(vue: Dictionary, _phase: float, delta: float) -> void:
	_t += delta
	var g := bloc(vue, "grille")
	if g.is_empty():
		return
	if _taille == 0:
		_batir(g)
	var guide: bool = not bool(g.get("marcheur", false))
	var v := str(g.get("v", ""))
	var sous: int = int(g.get("sous", -1))
	var niveau := str(g.get("niveau", "normal"))
	# Le temps de l'hôte, lissé : les pierres qui s'enfoncent battent au même rythme que son verdict.
	var t_hote := float(g.get("temps", 0.0))
	_t_est = t_hote if absf(_t_est + delta - t_hote) > 0.4 else lerpf(_t_est + delta, t_hote, 0.12)
	for k in mini(v.length(), _pierres.size()):
		var p = _pierres[k]
		if p == null:
			continue
		var porte: Node3D = p["porte"]
		var mi: MeshInstance3D = p["mi"]
		var trace: MeshInstance3D = p["trace"]
		var onde: MeshInstance3D = p["onde"]
		var y := 0.0
		var incl := Vector2.ZERO
		var piege := false
		var allumee := false
		var foulee := false
		var mobile := false
		var ov: Material = null
		match v[k]:
			"#", "t":
				# Un piège (que le guide voit, ou où le marcheur est tombé) : rougeâtre, il s'incline, il cède.
				ov = _ov_piege
				piege = true
				y = -0.05 + 0.012 * sin(_t * 2.0 + k)
				incl = Vector2(0.05 * sin(_t * 1.3 + k), 0.05 * cos(_t * 1.1 + k))
				mobile = v[k] == "t"
				if k == sous:
					y = -0.5
					incl = Vector2(0.28, -0.22)
			"o":
				ov = _ov_chaud
				allumee = true
			"m":
				ov = _ov_chaud
				allumee = true
				mobile = true
			"u":
				mobile = true
			".":
				ov = _ov_trace if not guide else _ov_chaud
				foulee = true
				allumee = guide
			"X":
				ov = _ov_but
				allumee = false
				if _arrivee == null:
					_arrivee = _batir_arrivee(k)
			"@":
				ov = _ov_trace if not guide else _ov_chaud
				foulee = true
				allumee = guide
			_:
				ov = null
		if mobile:
			var ph := Marais.phase_mobile(_t_est, k, niveau)
			var s := smoothstep(0.60, 0.70, ph) * (1.0 - smoothstep(0.95, 1.0, ph))
			y += -ENFONCE * s
			incl += Vector2(0.1 * s * sin(k * 1.9), 0.1 * s * cos(k * 1.3))
		mi.material_overlay = ov
		if allumee and p["lampe"] == null:
			_lampe_de(p)
		if piege and p["bulles"] == null:
			_bulles_de(p)
		if p["bulles"] != null:
			(p["bulles"] as GPUParticles3D).emitting = piege
		if p["lampe"] != null:
			(p["lampe"] as Node3D).visible = allumee
			(p["reflet"] as MeshInstance3D).visible = allumee
		trace.visible = foulee and not guide
		(onde.material_override as StandardMaterial3D).albedo_color.a = 0.1 + 0.07 * sin(_t * 1.6 + k * 0.9)
		var vit := 10.0 if k == sous else (7.0 if mobile else 4.0)
		porte.position.y = lerpf(porte.position.y, y, minf(delta * vit, 1.0))
		porte.rotation.x = lerpf(porte.rotation.x, incl.x, minf(delta * vit, 1.0))
		porte.rotation.z = lerpf(porte.rotation.z, incl.y, minf(delta * vit, 1.0))
	var maxi_: int = int(g.get("vies_max", 0))
	if maxi_ != _vies_max:
		_faire_vies(maxi_)
		_etiquette_vies.text = Langue.t("Lanternes de vie du marcheur : illimitées") if maxi_ <= 0 else Langue.t("Lanternes de vie du marcheur")
	var restantes: int = int(g.get("vies", 0))
	if restantes != _vies_etat:
		_vies_etat = restantes
		for i in _vies.size():
			((_vies[i] as Node3D).get_node("cage") as MeshInstance3D).material_override = _m_vie_on if i < restantes else _m_vie_off
	var chutes: int = int(g.get("chutes", 0))
	if _vues_chutes < 0:
		_vues_chutes = chutes
	elif chutes != _vues_chutes:
		_vues_chutes = chutes
		_eclabousser(Vector3(float(g.get("cx", 0.0)), 0.05, float(g.get("cz", 0.0))))


## La grande lanterne dorée de l'arrivée : un mât, une lanterne, une colonne de lumière qu'on voit de loin.
func _batir_arrivee(k: int) -> Node3D:
	var c := Quetes.case_marais(k, _taille, _haut)
	var n := poteau_lanterne(c + Vector3(0.55, 0, 0.0), Vector3(-1, 0, 0), 2.4)
	var colonne := _cylindre(0.2, 8.0, _unshaded_additif(Color(1.0, 0.8, 0.4, 0.06)))
	colonne.position = c + Vector3(0, 4.0, 0)
	add_child(colonne)
	colonne.add_to_group("traversable")
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(4.0, 4.0)
	halo.mesh = hq
	var hm := _unshaded_additif(Color(1.0, 0.8, 0.4, 0.4), _tache())
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo.material_override = hm
	halo.position = c + Vector3(0, 2.4, 0)
	add_child(halo)
	halo.add_to_group("traversable")
	var l := _lumiere(Color(1.0, 0.78, 0.4), 2.2, 8.0, c + Vector3(0, 2.2, 0))
	add_child(l)
	_feux.append([l, 2.2, randf() * 10.0])
	return n


## Quelqu'un tombe à l'eau : une gerbe, des ondes qui s'élargissent, le clapotis.
func _eclabousser(ou: Vector3) -> void:
	var gerbe := _particules(30, 0.9, Vector3(0.12, 0.02, 0.12), Vector3(0, 2.4, 0), 0.07,
		_degrade([Color(0.8, 0.92, 1.0, 0.0), Color(0.85, 0.95, 1.0, 0.9), Color(0.7, 0.85, 0.95, 0.0)]), false)
	var pm := gerbe.process_material as ParticleProcessMaterial
	pm.spread = 35.0
	pm.gravity = Vector3(0, -7.0, 0)
	gerbe.one_shot = true
	gerbe.explosiveness = 1.0
	gerbe.preprocess = 0.0
	gerbe.position = ou
	add_child(gerbe)
	gerbe.restart()
	for i in 2:
		var anneau := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.2
		tm.outer_radius = 0.26
		tm.rings = 28
		tm.ring_segments = 4
		anneau.mesh = tm
		anneau.scale = Vector3(1, 0.1, 1)
		var mat := _unshaded_additif(Color(0.7, 0.88, 1.0, 0.8))
		anneau.material_override = mat
		anneau.position = ou
		add_child(anneau)
		var tw := create_tween()
		tw.tween_interval(0.18 * i)
		tw.set_parallel(true)
		tw.tween_property(anneau, "scale", Vector3(5.0, 0.1, 5.0), 1.4)
		tw.tween_property(mat, "albedo_color:a", 0.0, 1.4)
		tw.chain().tween_callback(anneau.queue_free)
	var son := AudioStreamPlayer3D.new()
	son.stream = Sons.clapotis()
	son.position = ou
	son.unit_size = 6.0
	son.bus = "Effets"
	add_child(son)
	son.play()
	son.finished.connect(son.queue_free)
	get_tree().create_timer(2.5).timeout.connect(gerbe.queue_free)
