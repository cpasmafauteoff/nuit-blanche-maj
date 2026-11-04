class_name EffetMort
extends Node3D
## Une mort stylée (cf. Cosmetiques) : posée dans le monde, à l'endroit où le villageois tombe,
## pour que les vivants la voient même si son corps disparaît aussitôt. Elle se retire seule.
##   corbeaux : le corps s'effondre et s'envole en une nuée qui tourne au-dessus de la place
##   cendres  : une silhouette de braise qui se défait, des escarbilles, un petit tas gris
##   ombre    : une flaque noire s'ouvre, des volutes montent, elle se referme
##   statue   : figé en pierre, fissuré, puis il s'écroule en blocs

const DUREE := 7.0

var sorte := "corbeaux"
var apparence := {}
var _t := 0.0
var _corbeaux: Array[Node3D] = []
var _statue: Bouille
var _blocs: Array = []          # [noeud, vitesse, rotation]
var _flaque: MeshInstance3D
var _fissures: ShaderMaterial
var _silhouette: Bouille
var _braise: ShaderMaterial


## Lance l'effet de `sorte` à la place de `b` (le corps, lui, peut être caché aussitôt).
static func jouer(parent: Node, b: Bouille, sorte_: String) -> EffetMort:
	var e := EffetMort.new()
	e.sorte = sorte_
	e.apparence = b.apparence.duplicate()
	for emp: String in Cosmetiques.EMPLACEMENTS:
		e.apparence.erase(emp)
	parent.add_child(e)
	e.global_transform = b.global_transform
	return e


func _ready() -> void:
	match sorte:
		"corbeaux":
			_nuee()
		"cendres":
			_silhouette = _copie()
			_braise = _shader_braise()
			_peindre(_silhouette, _braise)
			_particules(90, 2.4, Color(1.0, 0.45, 0.1), 0.05, Vector3(0, 1.4, 0), Vector2(0.6, 1.8), Vector3(0.6, 0.9, 0.3), true)
			_particules(40, 3.5, Color(0.3, 0.29, 0.28, 0.5), 0.5, Vector3(0, 0.5, 0), Vector2(0.2, 0.6), Vector3(0.4, 0.8, 0.3), false)
			_tas()
		"ombre":
			_flaque_noire()
			_particules(70, 2.6, Color(0.08, 0.02, 0.12, 0.8), 0.35, Vector3(0, 1.2, 0), Vector2(0.4, 1.2), Vector3(0.5, 0.2, 0.5), false)
			_silhouette = _copie()
		"statue":
			_statue = _copie()
			_fissures = _shader_pierre()
			_peindre(_statue, _fissures)


func _copie() -> Bouille:
	var c := Bouille.new()
	c.apparence = apparence
	c.autonome = false
	add_child(c)
	return c


func _peindre(n: Node, m: Material) -> void:
	for e in n.get_children():
		if e is GeometryInstance3D and not (e is Label3D):
			(e as GeometryInstance3D).material_override = m
		_peindre(e, m)


## Libère une copie repeinte : on lui rend ses matériaux d'abord. Libérée avec la peinture de
## l'effet posée sur chaque morceau, le moteur se plaignait de matériaux nuls (4 erreurs à chaque
## statue ou cendres).
func _liberer(n: Node) -> void:
	_peindre(n, null)
	n.queue_free()


func _process(delta: float) -> void:
	_t += delta
	match sorte:
		"corbeaux":
			for i in _corbeaux.size():
				var c := _corbeaux[i]
				var k := float(i) / _corbeaux.size()
				var depart := smoothstep(0.0, 0.5, _t - k * 0.6)
				var a := k * TAU * 3.0 + _t * (1.4 + k)
				var r := 0.3 + depart * (1.0 + k * 1.8)
				c.position = Vector3(cos(a) * r, 0.3 + k * 1.5 + depart * (_t * 0.55 + k * 1.2), sin(a) * r)
				c.look_at(global_transform * (c.position + Vector3(-sin(a), 0.4, cos(a))), Vector3.UP)
				for aile in c.get_children():
					if aile.has_meta("aile"):
						(aile as Node3D).rotation.z = float(aile.get_meta("aile")) * sin(_t * 18.0 + i) * 0.9
				c.visible = _t > k * 0.6
				c.scale = Vector3.ONE * clampf((DUREE - _t) / 2.0, 0.0, 1.0)
		"cendres":
			if _braise:
				_braise.set_shader_parameter("defait", clampf(_t / 3.2, 0.0, 1.0))
		"ombre":
			if _flaque:
				var o := smoothstep(0.0, 0.6, _t) * (1.0 - smoothstep(DUREE - 2.5, DUREE - 0.5, _t))
				_flaque.scale = Vector3(o, 1, o) * 1.3
			if _silhouette:
				_silhouette.position.y = -smoothstep(0.5, 2.6, _t) * 2.0
				if _t > 2.7:
					_silhouette.queue_free()
					_silhouette = null
		"statue":
			if _fissures:
				_fissures.set_shader_parameter("fissure", clampf((_t - 0.9) / 1.4, 0.0, 1.0))
			if _statue and _t > 2.5:
				_ecrouler()
			for bl: Array in _blocs:
				var n: Node3D = bl[0]
				bl[1] += Vector3(0, -9.8, 0) * delta
				n.position += (bl[1] as Vector3) * delta
				if n.position.y < 0.08:
					n.position.y = 0.08
					bl[1] = (bl[1] as Vector3) * Vector3(0.6, -0.25, 0.6)
				n.rotation += (bl[2] as Vector3) * delta * (1.0 if n.position.y > 0.09 else 0.1)
	if _t > DUREE:
		if _silhouette:
			_liberer(_silhouette)
			_silhouette = null
		queue_free()


# ---------------------------------------------------------------- corbeaux

func _nuee() -> void:
	var plume := StandardMaterial3D.new()
	plume.albedo_color = Color(0.03, 0.03, 0.04)
	plume.roughness = 0.35
	plume.metallic = 0.2
	plume.rim_enabled = true
	plume.rim = 0.3
	var corps_m := SphereMesh.new()
	corps_m.radius = 0.07
	corps_m.height = 0.14
	corps_m.radial_segments = 10
	corps_m.rings = 5
	var aile_m := BoxMesh.new()
	aile_m.size = Vector3(0.22, 0.008, 0.09)
	for i in 70:
		var c := Node3D.new()
		add_child(c)
		var corps := MeshInstance3D.new()
		corps.mesh = corps_m
		corps.material_override = plume
		corps.scale = Vector3(0.75, 0.7, 1.5)
		c.add_child(corps)
		for cote: int in [-1, 1]:
			var pivot := Node3D.new()
			pivot.set_meta("aile", cote)
			c.add_child(pivot)
			var a := MeshInstance3D.new()
			a.mesh = aile_m
			a.material_override = plume
			a.position = Vector3(cote * 0.12, 0, -0.01)
			pivot.add_child(a)
		c.visible = false
		_corbeaux.append(c)
	# Quelques plumes qui retombent.
	_particules(40, 3.0, Color(0.05, 0.05, 0.06), 0.06, Vector3(0, 1.2, 0), Vector2(0.5, 1.5), Vector3(0.4, 0.6, 0.4), false, -0.4)


# ---------------------------------------------------------------- cendres

func _shader_braise() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform float defait = 0.0;
varying vec3 mp;
float h(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float bruit(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1,0,0)), f.x), mix(h(i + vec3(0,1,0)), h(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h(i + vec3(0,0,1)), h(i + vec3(1,0,1)), f.x), mix(h(i + vec3(0,1,1)), h(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() { mp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = bruit(mp * 9.0) * 0.6 + bruit(mp * 23.0) * 0.4;
	// Le haut part en premier, comme une bûche qui s'effondre.
	float seuil = defait * 1.6 - (2.0 - mp.y) * 0.35;
	if (n < seuil) { discard; }
	float bord = smoothstep(seuil + 0.12, seuil, n);
	float veine = smoothstep(0.08, 0.0, abs(bruit(mp * 14.0) - 0.5));
	ALBEDO = mix(vec3(0.05, 0.04, 0.035), vec3(0.15, 0.13, 0.12), n);
	EMISSION = vec3(1.0, 0.35, 0.05) * (bord * 6.0 + veine * defait * 2.5);
	ROUGHNESS = 0.95;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _tas() -> void:
	var tas := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.35
	s.height = 0.14
	tas.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.09, 0.085, 0.08)
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = Color(0.6, 0.15, 0.02)
	m.emission_energy_multiplier = 0.12
	tas.material_override = m
	tas.position.y = 0.02
	tas.scale = Vector3(1, 0.5, 1)
	add_child(tas)


# ---------------------------------------------------------------- ombre

func _flaque_noire() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9, 78.2))) * 43758.5); }
void fragment() {
	vec2 c = UV - 0.5;
	float a = atan(c.y, c.x);
	float r = length(c) * 2.0;
	float bord = 0.82 + 0.1 * sin(a * 7.0 + TIME * 2.0) + 0.06 * sin(a * 13.0 - TIME * 3.0);
	if (r > bord) { discard; }
	float coeur = smoothstep(bord, bord - 0.35, r);
	ALBEDO = mix(vec3(0.12, 0.02, 0.18), vec3(0.0), coeur);
	EMISSION = vec3(0.25, 0.05, 0.35) * smoothstep(bord - 0.12, bord, r) * 2.0;
	ALPHA = 0.97;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_flaque = MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(2.4, 2.4)
	_flaque.mesh = p
	_flaque.material_override = m
	_flaque.position.y = 0.025
	_flaque.scale = Vector3(0.01, 1, 0.01)
	add_child(_flaque)


# ---------------------------------------------------------------- statue

func _shader_pierre() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform sampler2D roche : source_color, filter_linear_mipmap, repeat_enable;
uniform float fissure = 0.0;
varying vec3 mp;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 voronoi(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float d1 = 8.0; float d2 = 8.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = vec2(h(i + g), h(i + g + 3.1));
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return vec2(d1, d2);
}
void vertex() { mp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 t = texture(roche, mp.xy * 1.3 + mp.zz * 0.7).rgb;
	float g = dot(t, vec3(0.33));
	vec2 v = voronoi(vec2(mp.x + mp.z, mp.y) * 6.0);
	float trait = smoothstep(0.06, 0.0, v.y - v.x);
	float montee = smoothstep(fissure * 2.2 - 0.2, fissure * 2.2, mp.y);
	trait *= 1.0 - montee;
	ALBEDO = vec3(g * 0.8 + 0.12) * (1.0 - trait * 0.9);
	EMISSION = vec3(1.0, 0.7, 0.4) * trait * 0.8;
	ROUGHNESS = 0.92;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("roche", load("res://textures/mossy_rock_diff.jpg"))
	return m


func _ecrouler() -> void:
	var pos := _statue.global_position
	_liberer(_statue)
	_statue = null
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/mossy_rock_diff.jpg")
	m.albedo_color = Color(0.62, 0.62, 0.62)
	m.roughness = 0.95
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(3, 3, 3)
	var rng := RandomNumberGenerator.new()
	for i in 22:
		var bl := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var t := rng.randf_range(0.08, 0.2)
		bm.size = Vector3(t, t * rng.randf_range(0.6, 1.4), t * rng.randf_range(0.6, 1.2))
		bl.mesh = bm
		bl.material_override = m
		bl.position = Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(0.2, 1.8), rng.randf_range(-0.15, 0.15))
		add_child(bl)
		_blocs.append([bl, Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(0.0, 1.5), rng.randf_range(-1.2, 1.2)),
			Vector3(rng.randf_range(-4, 4), rng.randf_range(-4, 4), rng.randf_range(-4, 4))])
	_particules(50, 2.0, Color(0.55, 0.53, 0.5, 0.5), 0.45, Vector3(0, 0.9, 0), Vector2(0.3, 1.0), Vector3(0.4, 0.8, 0.3), false, 0.1, true)
	global_position = pos


# ---------------------------------------------------------------- particules

func _particules(nb: int, vie: float, c: Color, taille: float, pos: Vector3, vitesse: Vector2, boite: Vector3,
		lueur: bool, gravite := 0.25, d_un_coup := false) -> void:
	var p := GPUParticles3D.new()
	p.amount = nb
	p.lifetime = vie
	p.one_shot = true
	p.explosiveness = 0.9 if d_un_coup else 0.35
	p.position = pos
	p.visibility_aabb = AABB(Vector3(-5, -2, -5), Vector3(10, 10, 10))
	var q := QuadMesh.new()
	q.size = Vector2.ONE * taille
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	if lueur:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tx := GradientTexture2D.new()
	tx.gradient = g
	tx.fill = GradientTexture2D.FILL_RADIAL
	tx.fill_from = Vector2(0.5, 0.5)
	tx.fill_to = Vector2(0.5, 0.0)
	m.albedo_texture = tx
	q.material = m
	p.draw_pass_1 = q
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = boite
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = vitesse.x
	pm.initial_velocity_max = vitesse.y
	pm.gravity = Vector3(0, gravite, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	var ramp := Gradient.new()
	ramp.set_color(0, c)
	ramp.set_color(1, Color(c.r, c.g, c.b, 0.0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	p.process_material = pm
	p.emitting = true
	add_child(p)
