class_name Atours
extends Node3D
## Ce qu'on achète à la roulotte du colporteur et qu'on porte sur soi (cf. regles/cosmetiques.gd) :
## la tenue, le familier, les traces de pas, l'allure de fantôme et les objets payants.
## Construit par Bouille à sa construction ; tout est en code, comme le villageois lui-même.
##
## Rien ici ne couvre les yeux ni la bouche : c'est le visage qu'on lit pour trouver les loups.

## habit (0 paysan, 1 rôdeur), étoffe (0 ordinaire, 1 du dimanche), teinte du tissu
const REGLAGE_TENUE := {
	"fossoyeur": [0, 0, Color(0.22, 0.16, 0.1)],
	"veuve": [0, 1, Color(0.05, 0.045, 0.055)],
	"peste": [1, 0, Color(0.1, 0.085, 0.07)],
	"inquisiteur": [1, 1, Color(0.34, 0.03, 0.05)],
	"saltimbanque": [0, 1, Color(0.36, 0.1, 0.32)],
	"pelerin": [1, 0, Color(0.34, 0.27, 0.18)],
}
const CHAPEAUX := ["fossoyeur", "peste", "inquisiteur", "saltimbanque", "pelerin", "veuve"]

const PELLE := preload("res://modeles/nature/rusted_spade_01/rusted_spade_01.gltf")

var b: Bouille
var cosm := {}
var _familier: Node3D
var _traces: Array[GPUParticles3D] = []
var _style_fantome: Node3D
var _cache := false
var _t := 0.0


static func a_un_chapeau(tenue: String) -> bool:
	return tenue in CHAPEAUX


func habiller(bouille: Bouille, apparence: Dictionary) -> void:
	b = bouille
	cosm = apparence
	var tenue := str(cosm.get("tenue", ""))
	if tenue != "":
		_tenue(tenue)
	var objet_i := int(cosm.get("objet", 0))
	if objet_i >= Bouille.NB_OBJETS_GRATUITS and objet_i < Bouille.OBJETS.size():
		_objet(Bouille.OBJETS[objet_i])
	var fam := str(cosm.get("familier", ""))
	if fam != "":
		_familier = Familier.new()
		_familier.sorte = fam
		_familier.maitre = b
		add_child(_familier)
	var trace := str(cosm.get("trace", ""))
	if trace != "":
		_poser_traces(trace)


## La bête n'a ni chat ni traces (on la reconnaîtrait) ; le loup démasqué non plus.
func cacher(oui: bool) -> void:
	if oui == _cache:
		return
	_cache = oui
	if _familier:
		_familier.visible = not oui
	for t in _traces:
		t.visible = not oui


func _process(delta: float) -> void:
	_t += delta
	var marche := b._marche if b else 0.0
	for t in _traces:
		t.emitting = marche > 0.12 and not _cache and b.visible


# ================================================================ formes

func _m(c: Color, rugueux := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugueux
	m.metallic = metal
	return m


func _lueur(c: Color, force := 3.0) -> StandardMaterial3D:
	var m := _m(c, 0.4)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = force
	return m


func _cyl(p: Node3D, r_haut: float, r_bas: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO, seg := 24) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_haut
	c.bottom_radius = r_bas
	c.height = h
	c.radial_segments = seg
	c.rings = 2
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


func _sphere(p: Node3D, r: float, mat: Material, pos: Vector3, ech := Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 20
	s.rings = 10
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = mat
	mi.position = pos
	mi.scale = ech
	p.add_child(mi)
	return mi


func _bloc(p: Node3D, t: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = t
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


func _tore(p: Node3D, r_int: float, r_ext: float, mat: Material, pos: Vector3, rot := Vector3.ZERO, ech := Vector3.ONE) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r_int
	t.outer_radius = r_ext
	t.rings = 32
	t.ring_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = ech
	p.add_child(mi)
	return mi


## Un bord de chapeau qui ondule (feutre mou, jamais une galette parfaite).
func _bord(p: Node3D, r_int: float, r_ext: float, mat: Material, pos: Vector3, ondule: float, tombe := 0.0, releve_avant := 0.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 48
	for face in 2:
		var dy := 0.0 if face == 0 else -0.006
		for i in n:
			var a0 := i * TAU / n
			var a1 := (i + 1) * TAU / n
			var pts := []
			for a in [a0, a1]:
				var o: float = sin(a * 3.0) * ondule + sin(a * 7.0 + 1.3) * ondule * 0.4
				var avant: float = maxf(cos(a), 0.0)
				var h_ext: float = o - tombe + releve_avant * pow(avant, 3.0)
				pts.append(Vector3(sin(a) * r_int, dy, cos(a) * r_int))
				pts.append(Vector3(sin(a) * r_ext, h_ext + dy, cos(a) * r_ext))
			var tri := [pts[0], pts[1], pts[3], pts[0], pts[3], pts[2]] if face == 0 else [pts[0], pts[3], pts[1], pts[0], pts[2], pts[3]]
			for v: Vector3 in tri:
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	p.add_child(mi)
	return mi


## Feutre, cuir ou laine : le tissu des villageois (tissu.gdshader), pas un aplat.
func _etoffe(c: Color, matiere: String, echelle := 30.0) -> ShaderMaterial:
	return b._tissu(c, matiere, echelle)


# ================================================================ tenues

func _tenue(t: String) -> void:
	var v: Node3D = b._visage
	var torse: Node3D = b.corps
	match t:
		"fossoyeur":
			# Chapeau mou cabossé, le bord qui tombe, un trou par où passe la pluie.
			var feutre := _etoffe(Color(0.16, 0.12, 0.09), "laine", 22.0)
			_bord(v, 0.09, 0.2, feutre, Vector3(0, 0.125, -0.01), 0.012, 0.035)
			var calotte := _cyl(v, 0.075, 0.094, 0.1, feutre, Vector3(0, 0.175, -0.01), Vector3(0.12, 0, -0.08))
			calotte.scale = Vector3(1.0, 1.0, 1.1)
			_sphere(v, 0.076, feutre, Vector3(0.005, 0.222, -0.012), Vector3(1, 0.35, 1.1))
			_sphere(v, 0.012, _m(Color(0.02, 0.02, 0.02), 1.0), Vector3(0.04, 0.226, 0.02), Vector3(1, 0.3, 1))
			_cyl(v, 0.095, 0.095, 0.018, _etoffe(Color(0.08, 0.06, 0.05), "cuir", 30.0), Vector3(0, 0.138, -0.01))
			# Gilet de cuir patiné par-dessus la chemise.
			var cuir := _etoffe(Color(0.2, 0.12, 0.07), "cuir", 18.0)
			for c: int in [-1, 1]:
				_bloc(torse, Vector3(0.1, 0.26, 0.014), cuir, Vector3(c * 0.07, 0.16, 0.115), Vector3(-0.12, c * 0.25, 0))
				for k in 3:
					_sphere(torse, 0.007, _m(Color(0.45, 0.38, 0.22), 0.3, 0.8), Vector3(c * 0.024, 0.24 - k * 0.07, 0.125))
			# La pelle rouillée en travers du dos.
			var pelle := PELLE.instantiate() as Node3D
			pelle.scale = Vector3.ONE * 0.9
			pelle.position = Vector3(0.05, 0.05, -0.17)
			pelle.rotation = Vector3(0.1, 0.0, 0.5)
			torse.add_child(pelle)
		"veuve":
			# Petit chapeau de deuil et son voile de dentelle relevé sur le front, qui tombe dans le dos.
			var noir := _etoffe(Color(0.03, 0.03, 0.035), "velours", 40.0)
			_cyl(v, 0.068, 0.075, 0.05, noir, Vector3(0, 0.145, -0.02), Vector3(-0.25, 0, 0))
			_bord(v, 0.07, 0.1, noir, Vector3(0, 0.124, -0.02), 0.004)
			var dentelle := _dentelle()
			var voile := _sphere(v, 0.135, dentelle, Vector3(0, 0.06, -0.035), Vector3(1.0, 1.3, 1.05))
			voile.rotation.x = -0.35
			# Le voile s'arrête au front : la moitié avant de la sphère est coupée par le shader.
			_bloc(v, Vector3(0.22, 0.26, 0.004), dentelle, Vector3(0, -0.12, -0.13), Vector3(0.2, 0, 0))
			# Haut col de dentelle et camée d'ivoire.
			_tore(b._cou, 0.045, 0.07, dentelle, b._tete.position + Vector3(0, -0.12, -0.01), Vector3.ZERO, Vector3(1, 2.2, 1))
			var camee := _sphere(torse, 0.022, _m(Color(0.88, 0.82, 0.72), 0.35), Vector3(0, 0.39, 0.15), Vector3(0.8, 1.0, 0.35))
			_tore(camee, 0.02, 0.026, _m(Color(0.55, 0.42, 0.18), 0.25, 0.9), Vector3.ZERO, Vector3(PI / 2, 0, 0))
			for k in 9:
				var a := (k - 4) * 0.22
				_sphere(torse, 0.009, _m(Color(0.92, 0.9, 0.86), 0.15), Vector3(sin(a) * 0.1, 0.42 - cos(a) * 0.04, 0.12 + cos(a) * 0.02))
		"peste":
			# Le grand chapeau noir, et le masque à bec relevé dessus : on voit le visage, pas le bec.
			var cuir := _etoffe(Color(0.06, 0.05, 0.045), "cuir", 26.0)
			_bord(v, 0.085, 0.23, cuir, Vector3(0, 0.13, -0.01), 0.006, 0.01)
			_cyl(v, 0.085, 0.092, 0.11, cuir, Vector3(0, 0.19, -0.01))
			_cyl(v, 0.093, 0.093, 0.022, _etoffe(Color(0.28, 0.2, 0.12), "cuir", 30.0), Vector3(0, 0.145, -0.01))
			var masque := Node3D.new()
			masque.position = Vector3(0, 0.235, 0.075)
			masque.rotation.x = -0.45
			v.add_child(masque)
			var peau_masque := _etoffe(Color(0.52, 0.4, 0.26), "cuir", 30.0)
			_sphere(masque, 0.07, peau_masque, Vector3(0, 0, 0), Vector3(1, 0.8, 0.7))
			_cyl(masque, 0.004, 0.04, 0.17, peau_masque, Vector3(0, -0.02, 0.1), Vector3(PI / 2 + 0.25, 0, 0))
			for c: int in [-1, 1]:
				var verre := _m(Color(0.25, 0.08, 0.05, 0.9), 0.05, 0.3)
				verre.emission_enabled = true
				verre.emission = Color(0.6, 0.15, 0.05)
				verre.emission_energy_multiplier = 0.6
				_cyl(masque, 0.022, 0.022, 0.01, verre, Vector3(c * 0.032, 0.025, 0.05), Vector3(PI / 2, 0, 0))
				_tore(masque, 0.02, 0.027, _m(Color(0.6, 0.45, 0.2), 0.25, 0.9), Vector3(c * 0.032, 0.025, 0.055), Vector3(PI / 2, 0, 0))
			# Pèlerine de cuir sur les épaules.
			var pelerine := _cyl(torse, 0.13, 0.26, 0.2, cuir, Vector3(0, 0.38, -0.005), Vector3.ZERO, 32)
			pelerine.scale = Vector3(1.05, 1, 0.72)
		"inquisiteur":
			# Chapeau rouge à larges bords plats, cordons à glands ; fraise blanche ; croix d'argent.
			var rouge := _etoffe(Color(0.4, 0.03, 0.05), "velours", 34.0)
			_bord(v, 0.08, 0.25, rouge, Vector3(0, 0.128, -0.01), 0.003, 0.0)
			_cyl(v, 0.075, 0.088, 0.045, rouge, Vector3(0, 0.155, -0.01))
			_sphere(v, 0.075, rouge, Vector3(0, 0.178, -0.01), Vector3(1, 0.3, 1))
			var or_m := _m(Color(0.75, 0.55, 0.18), 0.3, 0.9)
			for c: int in [-1, 1]:
				_cyl(v, 0.003, 0.003, 0.22, rouge, Vector3(c * 0.13, 0.02, 0.0), Vector3(0, 0, c * 0.08))
				_cyl(v, 0.006, 0.016, 0.04, or_m, Vector3(c * 0.14, -0.1, 0.0))
			var linge := _m(Color(0.93, 0.92, 0.88), 0.85)
			for k in 3:
				var f := _tore(b._cou, 0.05 + k * 0.004, 0.105 + k * 0.006, linge, b._tete.position + Vector3(0, -0.165 - k * 0.012, -0.03), Vector3.ZERO, Vector3(1, 1.3, 1))
				f.rotation.y = k * 0.3
			var argent := _m(Color(0.78, 0.8, 0.84), 0.2, 1.0)
			_bloc(torse, Vector3(0.012, 0.08, 0.008), argent, Vector3(0, 0.28, 0.165))
			_bloc(torse, Vector3(0.05, 0.012, 0.008), argent, Vector3(0, 0.3, 0.165))
			for k in 10:
				var a := (k - 4.5) * 0.17
				_sphere(torse, 0.005, argent, Vector3(sin(a) * 0.09, 0.4 - cos(a) * 0.08, 0.13 + cos(a) * 0.03))
		"saltimbanque":
			# Bonnet à trois pointes molles et grelots ; collerette à pointes ; losanges sur l'habit.
			var violet := _etoffe(Color(0.4, 0.08, 0.35), "velours", 30.0)
			var safran := _etoffe(Color(0.75, 0.52, 0.12), "velours", 30.0)
			_cyl(v, 0.1, 0.1, 0.03, safran, Vector3(0, 0.12, -0.01))
			var grelot := _m(Color(0.85, 0.66, 0.25), 0.2, 0.95)
			for k in 3:
				var a := (k - 1) * 1.15
				var p := Vector3(sin(a) * 0.05, 0.14, -0.01)
				var dir := Vector3(sin(a) * 1.0, 0.85, -0.2).normalized()
				var r := 0.045
				for seg in 9:
					_sphere(v, r, violet if k != 1 else safran, p)
					p += dir * r * 1.1
					dir = (dir + Vector3(sin(a) * 0.08, -0.2, -0.16 if k == 1 else 0.0)).normalized()
					r *= 0.88
				_sphere(v, 0.016, grelot, p)
			for k in 12:
				var a := k * TAU / 12.0
				var pointe := _cyl(b._cou, 0.0, 0.028, 0.07, violet if k % 2 == 0 else safran,
					b._tete.position + Vector3(sin(a) * 0.08, -0.14, cos(a) * 0.08 - 0.02), Vector3(0, 0, 0))
				pointe.look_at_from_position(pointe.position, pointe.position + Vector3(sin(a), -0.6, cos(a)), Vector3.UP)
				pointe.rotate_object_local(Vector3.RIGHT, -PI / 2)
				_sphere(b._cou, 0.006, grelot, b._tete.position + Vector3(sin(a) * 0.12, -0.165, cos(a) * 0.12 - 0.02))
			_losanges()
		"pelerin":
			# Chapeau de pèlerin au bord relevé devant, coquille cousue ; mantelet ; gourde à la hanche.
			var bure := _etoffe(Color(0.22, 0.17, 0.11), "laine", 22.0)
			_bord(v, 0.085, 0.22, bure, Vector3(0, 0.13, -0.01), 0.005, 0.01, 0.1)
			_cyl(v, 0.07, 0.09, 0.09, bure, Vector3(0, 0.18, -0.01))
			_sphere(v, 0.07, bure, Vector3(0, 0.222, -0.01), Vector3(1, 0.4, 1))
			var nacre := _m(Color(0.9, 0.85, 0.75), 0.4)
			var coquille := Node3D.new()
			coquille.position = Vector3(0, 0.205, 0.17)
			coquille.rotation.x = -0.6
			v.add_child(coquille)
			for k in 7:
				var a := (k - 3) * 0.26
				_bloc(coquille, Vector3(0.01, 0.05, 0.006), nacre, Vector3(sin(a) * 0.022, cos(a) * 0.022, 0), Vector3(0, 0, -a))
			var mantelet := _cyl(torse, 0.12, 0.27, 0.22, bure, Vector3(0, 0.36, -0.005), Vector3.ZERO, 32)
			mantelet.scale = Vector3(1.05, 1, 0.74)
			var gourde := _sphere(b._bassin, 0.055, _etoffe(Color(0.45, 0.3, 0.15), "cuir", 20.0), Vector3(-0.19, 0.86, 0.05), Vector3(0.8, 1.0, 0.5))
			_cyl(b._bassin, 0.012, 0.015, 0.03, _m(Color(0.3, 0.2, 0.1)), gourde.position + Vector3(0, 0.065, 0))


## La dentelle noire du voile : un motif de fleurs ajourées, coupé au front (rien sur le visage).
func _dentelle() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
varying vec3 lp;
void vertex() { lp = VERTEX; }
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	// Rien devant le front : le visage doit rester lisible.
	if (lp.z > 0.02 && lp.y < 0.1) { discard; }
	vec2 uv = UV * vec2(48.0, 26.0);
	vec2 c = fract(uv) - 0.5;
	float fleur = abs(length(c) - 0.28 - 0.06 * cos(atan(c.y, c.x) * 6.0));
	float maille = min(abs(c.x), abs(c.y));
	float fil = min(smoothstep(0.05, 0.0, fleur), 1.0) + smoothstep(0.035, 0.0, maille) * 0.8;
	if (fil < 0.35) { discard; }
	ALBEDO = vec3(0.025, 0.022, 0.028);
	ROUGHNESS = 0.6;
	SPECULAR = 0.3;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## Des losanges délavés posés par-dessus l'étoffe du saltimbanque (un calque, pas une texture).
func _losanges() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never;
void fragment() {
	vec2 q = UV * vec2(9.0, 14.0);
	vec2 r = vec2(q.x + q.y, q.x - q.y);
	vec2 id = floor(r);
	float pair = mod(id.x + id.y, 2.0);
	vec3 a = vec3(0.55, 0.36, 0.08);
	vec3 bc = vec3(0.12, 0.03, 0.12);
	ALBEDO = mix(a, bc, pair);
	vec2 f = fract(r) - 0.5;
	float bord = smoothstep(0.47, 0.5, max(abs(f.x), abs(f.y)));
	ALPHA = mix(0.55, 0.8, bord);
	ROUGHNESS = 0.9;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var peaux := {}
	for pk: Array in b._peaux:
		peaux["%s/%d" % [(pk[0] as Node).get_instance_id(), pk[1]]] = true
	for mi: MeshInstance3D in b._humain.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible:
			continue
		for k in mi.mesh.get_surface_count():
			var o := mi.get_surface_override_material(k)
			if o and not peaux.has("%s/%d" % [mi.get_instance_id(), k]):
				o.next_pass = m


# ================================================================ objets payants

func _objet(sorte: String) -> void:
	var main: Node3D = b._main
	var poignet := Vector3(0.0, -0.03, 0.0)
	match sorte:
		"lanterne_bleue", "lanterne_fondateur":
			var fondateur := sorte == "lanterne_fondateur"
			var fer := _m(Color(0.62, 0.46, 0.18) if fondateur else Color(0.08, 0.08, 0.09), 0.3, 0.9 if fondateur else 0.6)
			var flamme_c := Color(1.0, 0.97, 0.88) if fondateur else Color(0.3, 0.6, 1.0)
			var c := poignet + Vector3(0, -0.2, 0.01)
			_tore(main, 0.012, 0.018, fer, poignet + Vector3(0, -0.035, 0), Vector3(0, 0, PI / 2))
			_cyl(main, 0.0035, 0.0035, 0.1, fer, poignet + Vector3(0, -0.1, 0))
			_cyl(main, 0.012, 0.064, 0.06, fer, c + Vector3(0, 0.088, 0), Vector3.ZERO, 6)
			_cyl(main, 0.064, 0.064, 0.014, fer, c + Vector3(0, -0.066, 0), Vector3.ZERO, 6)
			var vitre := _m(Color(flamme_c.r, flamme_c.g, flamme_c.b, 0.28), 0.05)
			vitre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_cyl(main, 0.055, 0.055, 0.11, vitre, c, Vector3.ZERO, 6)
			for k in 6:
				var a := k * TAU / 6.0
				_cyl(main, 0.004, 0.004, 0.12, fer, c + Vector3(cos(a) * 0.058, 0, sin(a) * 0.058))
			var flamme := _sphere(main, 0.016, _lueur(flamme_c, 6.0), c + Vector3(0, -0.01, 0), Vector3(0.8, 1.8, 0.8))
			flamme.set_meta("vacille", true)
			var l := OmniLight3D.new()
			l.light_color = flamme_c
			l.light_energy = 1.2
			l.omni_range = 3.5
			l.position = c
			main.add_child(l)
			if fondateur:
				for k in 6:
					var a := k * TAU / 6.0
					_sphere(main, 0.009, _lueur(Color(1, 0.8, 0.4), 2.0), c + Vector3(cos(a) * 0.064, 0.074, sin(a) * 0.064))
		"crane_lanterne", "crane_fondateur":
			var dore := sorte == "crane_fondateur"
			var os_m := _m(Color(0.86, 0.66, 0.24), 0.3, 0.9) if dore else _m(Color(0.86, 0.8, 0.66), 0.7)
			var c := poignet + Vector3(0, -0.14, 0.02)
			_cyl(main, 0.004, 0.004, 0.07, _m(Color(0.1, 0.09, 0.08), 0.5, 0.6), poignet + Vector3(0, -0.07, 0.02))
			_sphere(main, 0.06, os_m, c, Vector3(0.9, 0.95, 1.05))
			_sphere(main, 0.04, os_m, c + Vector3(0, -0.045, 0.025), Vector3(1.0, 0.7, 0.9))
			var feu := _lueur(Color(1.0, 0.97, 0.88) if dore else Color(1.0, 0.55, 0.15), 5.0)
			for cote: int in [-1, 1]:
				_sphere(main, 0.016, feu, c + Vector3(cote * 0.022, 0.005, 0.05), Vector3(1, 0.8, 0.4))
			_sphere(main, 0.008, feu, c + Vector3(0, -0.02, 0.058), Vector3(1, 1.4, 0.4))
			for k in 5:
				_bloc(main, Vector3(0.008, 0.012, 0.006), os_m, c + Vector3((k - 2) * 0.011, -0.065, 0.055))
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.95, 0.85) if dore else Color(1.0, 0.55, 0.2)
			l.light_energy = 0.9
			l.omni_range = 2.5
			l.position = c + Vector3(0, 0, 0.1)
			main.add_child(l)
		"cloche_sonneur":
			var bronze := _m(Color(0.42, 0.28, 0.12), 0.28, 0.9)
			var bois := _etoffe(Color(0.25, 0.15, 0.08), "cuir", 20.0)
			var c := poignet + Vector3(0, -0.16, 0.02)
			_cyl(main, 0.011, 0.012, 0.12, bois, poignet + Vector3(0, -0.05, 0.02))
			_sphere(main, 0.045, bronze, c + Vector3(0, 0.02, 0), Vector3(1, 0.7, 1))
			_cyl(main, 0.045, 0.085, 0.09, bronze, c + Vector3(0, -0.03, 0), Vector3.ZERO, 32)
			_tore(main, 0.078, 0.092, bronze, c + Vector3(0, -0.075, 0))
			_sphere(main, 0.016, _m(Color(0.1, 0.09, 0.08), 0.5, 0.7), c + Vector3(0, -0.085, 0))
		"grimoire", "grimoire_fondateur":
			var dore := sorte == "grimoire_fondateur"
			var cuir := _etoffe(Color(0.05, 0.05, 0.06) if dore else Color(0.16, 0.06, 0.05), "cuir", 14.0)
			var c := poignet + Vector3(0.0, -0.05, 0.06)
			var livre := Node3D.new()
			livre.position = c
			livre.rotation = Vector3(0, 0, 0.15)
			main.add_child(livre)
			_bloc(livre, Vector3(0.05, 0.2, 0.15), cuir, Vector3.ZERO)
			_bloc(livre, Vector3(0.042, 0.19, 0.142), _m(Color(0.82, 0.76, 0.6), 0.9), Vector3(0.004, 0, 0.004))
			var laiton := _m(Color(0.92, 0.72, 0.28), 0.25, 0.95) if dore else _m(Color(0.6, 0.45, 0.2), 0.3, 0.9)
			for y in [-0.08, 0.08]:
				_bloc(livre, Vector3(0.054, 0.025, 0.025), laiton, Vector3(0, y, 0.065))
			_bloc(livre, Vector3(0.056, 0.012, 0.156), _etoffe(Color(0.1, 0.06, 0.04), "cuir", 20.0), Vector3(0, 0, 0))
			var oeil := _sphere(livre, 0.014, _lueur(Color(1.0, 0.97, 0.88) if dore else Color(0.9, 0.2, 0.1), 2.0), Vector3(0.027, 0.03, 0.0), Vector3(0.3, 1, 1))
			oeil.set_meta("vacille", true)


# ================================================================ traces

func _point_doux() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


func _quad(taille: float, couleur: Color, lueur := 0.0, texture: Texture2D = null) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE * taille
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = couleur
	m.albedo_texture = texture if texture else _point_doux()
	if lueur > 0.0:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.4
	q.material = m
	return q


func _emetteur(nb: int, vie: float, mesh: Mesh) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = nb
	p.lifetime = vie
	p.local_coords = false
	p.draw_pass_1 = mesh
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 6, 12))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	_traces.append(p)
	return p


func _proc(dir: Vector3, vitesse: Vector2, gravite: Vector3, echelle: Vector2, couleur: Gradient) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = 40.0
	pm.initial_velocity_min = vitesse.x
	pm.initial_velocity_max = vitesse.y
	pm.gravity = gravite
	pm.scale_min = echelle.x
	pm.scale_max = echelle.y
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25
	var ct := GradientTexture1D.new()
	ct.gradient = couleur
	pm.color_ramp = ct
	return pm


func _rampe(couleurs: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(range(couleurs.size()).map(func(i): return float(i) / (couleurs.size() - 1)))
	g.colors = PackedColorArray(couleurs)
	return g


func _poser_traces(sorte: String) -> void:
	match sorte:
		"brume":
			var p := _emetteur(40, 2.6, _quad(1.1, Color(0.8, 0.84, 0.9, 0.22)))
			p.process_material = _proc(Vector3(0, 0.2, 0), Vector2(0.05, 0.2), Vector3(0, 0.02, 0), Vector2(0.6, 1.4),
				_rampe([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)]))
			p.position = Vector3(0, 0.15, 0)
		"feuilles":
			var feuille := _quad(0.09, Color(1, 1, 1, 1), 0.0, _texture_feuille())
			(feuille.material as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
			(feuille.material as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
			(feuille.material as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			var p := _emetteur(26, 2.2, feuille)
			var pm := _proc(Vector3(0, 1, 0), Vector2(0.6, 1.4), Vector3(0, -1.6, 0), Vector2(0.7, 1.3),
				_rampe([Color(0.75, 0.38, 0.1, 1), Color(0.55, 0.22, 0.06, 1), Color(0.35, 0.18, 0.06, 0)]))
			pm.angular_velocity_min = -280.0
			pm.angular_velocity_max = 280.0
			pm.particle_flag_rotate_y = true
			pm.orbit_velocity_min = 0.3
			pm.orbit_velocity_max = 0.6
			p.process_material = pm
			p.position = Vector3(0, 0.1, 0)
		"lucioles":
			var p := _emetteur(18, 3.2, _quad(0.05, Color(0.85, 1.0, 0.45, 1.0), 1.0))
			var pm := _proc(Vector3(0, 1, 0), Vector2(0.1, 0.35), Vector3(0, 0.05, 0), Vector2(0.6, 1.2),
				_rampe([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)]))
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 2.0
			pm.turbulence_noise_scale = 2.5
			pm.emission_sphere_radius = 0.6
			p.process_material = pm
			p.position = Vector3(0, 0.9, 0)
		"cendres":
			var empreinte := _quad(0.16, Color(0.08, 0.07, 0.06, 0.85), 0.0, _texture_empreinte())
			var me := empreinte.material as StandardMaterial3D
			me.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
			me.proximity_fade_enabled = false
			var p := _emetteur(16, 4.5, empreinte)
			var pm := _proc(Vector3.UP, Vector2.ZERO, Vector3.ZERO, Vector2(0.9, 1.1),
				_rampe([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)]))
			pm.emission_sphere_radius = 0.05
			pm.particle_flag_align_y = false
			pm.angle_min = 0.0
			pm.angle_max = 0.0
			p.process_material = pm
			p.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0, 0.03, 0))
			p.fixed_fps = 0
			var fumee := _emetteur(30, 1.6, _quad(0.25, Color(0.35, 0.33, 0.3, 0.35)))
			fumee.process_material = _proc(Vector3.UP, Vector2(0.2, 0.5), Vector3(0, 0.3, 0), Vector2(0.5, 1.2),
				_rampe([Color(1, 0.55, 0.2, 0.0), Color(1, 0.5, 0.2, 0.6), Color(0.4, 0.4, 0.4, 0.4), Color(0.3, 0.3, 0.3, 0)]))
			fumee.position = Vector3(0, 0.1, 0)


func _texture_feuille() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var u := (x - 15.5) / 15.5
			var v := (y - 15.5) / 15.5
			var dans := absf(u) < (1.0 - v * v) * 0.6 + 0.05 * sin(v * 18.0)
			var nervure := absf(u) < 0.06 or absf(absf(u) - absf(v + 0.2) * 0.4) < 0.04
			img.set_pixel(x, y, Color(1, 1, 1, 1) * (0.7 if nervure else 1.0) if dans else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func _texture_empreinte() -> ImageTexture:
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	for y in 48:
		for x in 32:
			var u := (x - 15.5) / 9.0
			var semelle := Vector2(u, (y - 30.0) / 15.0).length() < 1.0
			var talon := Vector2(u * 1.1, (y - 10.0) / 7.0).length() < 1.0
			img.set_pixel(x, y, Color(1, 1, 1, 1) if semelle or talon else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


# ================================================================ fantôme

func en_fantome(oui: bool) -> void:
	if _style_fantome:
		_style_fantome.queue_free()
		_style_fantome = null
	var sorte := str(cosm.get("fantome", ""))
	if not oui or sorte == "":
		return
	_style_fantome = Node3D.new()
	add_child(_style_fantome)
	match sorte:
		"lambeaux":
			var sh := Shader.new()
			sh.code = """
shader_type spatial;
render_mode cull_disabled, unshaded, depth_draw_never, blend_mix;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9, 78.2))) * 43758.5); }
void vertex() {
	float bas = 1.0 - UV.y;
	VERTEX.z += sin(TIME * 2.2 + UV.x * 7.0 + VERTEX.y * 3.0) * 0.08 * (1.0 - bas) - 0.12 * (1.0 - bas);
	VERTEX.x += sin(TIME * 1.7 + UV.y * 5.0) * 0.04 * (1.0 - bas);
}
void fragment() {
	float dechire = h(vec2(floor(UV.x * 18.0), 0.0));
	if (UV.y > 0.55 + dechire * 0.45) { discard; }
	float trou = h(floor(UV * vec2(9.0, 12.0)));
	if (trou > 0.95 && UV.y > 0.3) { discard; }
	ALBEDO = vec3(0.85, 0.88, 0.92);
	float bords = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	ALPHA = 0.28 * (1.0 - UV.y * 0.7) * bords;
}
"""
			var m := ShaderMaterial.new()
			m.shader = sh
			var suaire := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(0.55, 1.6)
			pm.subdivide_width = 10
			pm.subdivide_depth = 20
			pm.orientation = PlaneMesh.FACE_Z
			suaire.mesh = pm
			suaire.material_override = m
			suaire.position = Vector3(0, 0.75, -0.28)
			_style_fantome.add_child(suaire)
		"feu_follet":
			var f := Node3D.new()
			f.set_meta("orbite", true)
			_style_fantome.add_child(f)
			_sphere(f, 0.05, _lueur(Color(0.45, 1.0, 0.55), 5.0), Vector3.ZERO)
			var halo := _lueur(Color(0.3, 1.0, 0.4, 0.25), 1.5)
			halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_sphere(f, 0.1, halo, Vector3.ZERO)
			var l := OmniLight3D.new()
			l.light_color = Color(0.45, 1.0, 0.55)
			l.light_energy = 1.5
			l.omni_range = 4.0
			f.add_child(l)
		"brume":
			var p := GPUParticles3D.new()
			p.amount = 50
			p.lifetime = 2.2
			p.local_coords = false
			p.draw_pass_1 = _quad(0.55, Color(0.9, 0.93, 1.0, 0.25))
			p.process_material = _proc(Vector3(0, 1, 0), Vector2(0.1, 0.35), Vector3(0, 0.25, 0), Vector2(0.5, 1.3),
				_rampe([Color(1, 1, 1, 0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)]))
			(p.process_material as ParticleProcessMaterial).emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			(p.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(0.22, 0.8, 0.15)
			p.position = Vector3(0, 0.9, 0)
			p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 6, 8))
			_style_fantome.add_child(p)
		"flammes_bleues":
			for cible: Node3D in [b._tete, b._main, b._poing]:
				var p := GPUParticles3D.new()
				p.amount = 40 if cible == b._tete else 18
				p.lifetime = 0.8
				p.local_coords = false
				p.draw_pass_1 = _quad(0.12 if cible == b._tete else 0.07, Color(0.35, 0.6, 1.0, 1.0), 1.0)
				p.process_material = _proc(Vector3(0, 1, 0), Vector2(0.3, 0.7), Vector3(0, 0.9, 0), Vector2(0.6, 1.3),
					_rampe([Color(0.6, 0.85, 1, 0), Color(0.4, 0.7, 1, 1), Color(0.2, 0.3, 1, 0.6), Color(0.1, 0.1, 0.6, 0)]))
				(p.process_material as ParticleProcessMaterial).emission_sphere_radius = 0.09 if cible == b._tete else 0.04
				p.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 6, 6))
				p.top_level = true
				p.set_meta("colle", cible)
				_style_fantome.add_child(p)
			var l := OmniLight3D.new()
			l.light_color = Color(0.35, 0.55, 1.0)
			l.light_energy = 1.0
			l.omni_range = 3.0
			l.position = Vector3(0, 1.6, 0)
			_style_fantome.add_child(l)


func _physics_process(_delta: float) -> void:
	if _style_fantome == null:
		return
	for e in _style_fantome.get_children():
		if e.has_meta("orbite"):
			var a := _t * 1.6
			(e as Node3D).position = Vector3(cos(a) * 0.45, 1.75 + sin(_t * 2.3) * 0.12, sin(a) * 0.45)
		elif e.has_meta("colle"):
			var c: Node3D = e.get_meta("colle")
			(e as Node3D).global_position = c.global_position + (Vector3(0, 0.08, 0) if c == b._tete else Vector3.ZERO)
