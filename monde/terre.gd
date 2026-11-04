class_name Terre
extends RefCounted
## La terre autour du village (demande d'Edwin, 29/10 : « elle est trop mal faite »).
##  · le relief : plat partout où l'on marche, des buttes boisées au-delà qui ferment l'horizon ;
##  · le tapis du sous-bois : herbes, fougères, feuilles, pierres moussues, branches mortes ;
##  · la forêt lointaine sur les buttes (MultiMesh, sans collision : on n'y va jamais) ;
##  · les sentiers de terre battue qui mènent de la place à chaque clairière de quête.

## Où commencent les buttes (au-delà, personne ne marche : le mur des quêtes est à 52 m).
static var R_BUTTES := 54.0
## Autour d'une clairière, le sol reste plat sur ce rayon (les décors des quêtes vont jusqu'à 21 m).
const R_CLAIRIERE_PLATE := 23.0
const LARGEUR_SENTIER := 1.7


## La hauteur du sol en (x, z) : 0 là où l'on marche, des buttes au-delà.
static func hauteur(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var k := smoothstep(R_BUTTES, R_BUTTES + 24.0, r)
	if k <= 0.0:
		return 0.0
	for z_k in Quetes.ANGLES_ZONES.size():
		var c := Quetes.zone(z_k)
		k *= smoothstep(R_CLAIRIERE_PLATE, R_CLAIRIERE_PLATE + 10.0, Vector2(x - c.x, z - c.z).length())
	var a := atan2(x, z)
	var buttes := 0.5 + 0.5 * sin(a * 5.0 + 1.3) * cos(a * 3.0 - 0.4)
	var bosses := 0.5 + 0.5 * sin(x * 0.11 + 2.0) * cos(z * 0.13 - 1.0)
	return k * (5.0 + 9.0 * buttes + 4.0 * bosses)


## Le milieu du sentier k à la distance r du centre (il serpente un peu).
static func sentier(k: int, r: float) -> Vector3:
	var m := Quetes.passage(k, r)
	var axe := (Quetes.passage(k, r + 0.2) - m).normalized()
	var travers := axe.cross(Vector3.UP)
	var serpente := 0.55 * sin(r * 0.33 + 2.1) * smoothstep(Ronde.R_PLACE + 1.0, Ronde.R_PLACE + 5.0, r) * (1.0 - smoothstep(Ronde.R_LISIERE - 2.6, Ronde.R_LISIERE - 0.1, r))
	return m + travers * serpente


## La marche guidée vers le poste d'un joueur dans la clairière k : sur le milieu du sentier dessiné,
## de la trouée de la lisière jusqu'au bord de la clairière, puis droit au poste. Couper au plus court
## depuis la fourche (Edwin, 31/10) passait dans les sapins et sous les lanternes.
static func marche_vers_clairiere(k: int, poste: Vector3) -> Array[Vector3]:
	var r: Array[Vector3] = []
	var s := Ronde.R_LISIERE - 4.0
	var fin := Quetes.R_ZONE - Quetes.RAYON_ZONE - 1.0
	while s < fin:
		r.append(sentier(k, s))
		s += 1.5 if s < Quetes.R_FOURCHE + 2.0 else 3.0
	r.append(sentier(k, fin))
	r.append(poste)
	return r


## Ce point est-il sur un sentier (à `marge` m de son milieu) ?
static func sur_sentier(p: Vector3, marge: float) -> bool:
	var r := Vector2(p.x, p.z).length()
	if r < Ronde.R_PLACE - 1.0:
		return false
	for k in Quetes.ANGLES_ZONES.size():
		var s := Ronde.R_PLACE - 1.0 if k == 0 else Quetes.R_FOURCHE
		while s < Quetes.R_ZONE - 3.0:
			var m := sentier(k, s)
			if Vector2(p.x - m.x, p.z - m.z).length() < marge:
				return true
			s += 0.5
	return false


## Les maillages d'un modèle glTF, avec leur transformation dans la scène : [[Mesh, Transform3D]…].
static func maillages(nom: String) -> Array:
	var s: Node3D = (load("res://modeles/nature/%s/%s.gltf" % [nom, nom]) as PackedScene).instantiate()
	var r := []
	for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != s:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var b := mi.mesh.get_aabb()
		# Certains packs (coast_rocks_01) embarquent leur dalle de sol scannée, 59 m × 42 m : semée
		# comme un rocher, elle traversait le village et les maisons (Edwin, 30/10). On la laisse.
		var monde := t * b
		if maxf(monde.size.x, monde.size.z) > 12.0:
			continue
		# On pose le bas du morceau au sol, centré.
		r.append([mi.mesh, t * Transform3D(Basis.IDENTITY, Vector3(-b.get_center().x, -b.position.y, -b.get_center().z))])
	s.free()
	return r


# ================================================================ construction (appelée par Ronde)

## Le sol : un disque de 150 m de rayon, plat au centre, les buttes au bord.
static func maillage_sol() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rayons: Array[float] = []
	var r := 0.0
	while r < 150.0:
		rayons.append(r)
		r += 3.0 if r < R_BUTTES - 2.0 else 1.8
	rayons.append(150.0)
	var nb_a := 200
	for i in rayons.size():
		for j in nb_a:
			var a := j * TAU / nb_a
			var x := sin(a) * rayons[i]
			var z := cos(a) * rayons[i]
			st.set_uv(Vector2(x, z) * 0.25)
			st.add_vertex(Vector3(x, hauteur(x, z), z))
	for i in rayons.size() - 1:
		for j in nb_a:
			var j2 := (j + 1) % nb_a
			var a0 := i * nb_a + j
			var a1 := i * nb_a + j2
			var b0 := (i + 1) * nb_a + j
			var b1 := (i + 1) * nb_a + j2
			for v in [a0, b1, b0, a0, a1, b1]:
				st.add_index(v)
	st.generate_normals()
	st.generate_tangents()      # le shader du sol a des cartes de relief : sans tangentes, il blanchit
	return st.commit()


## Un semis de morceaux d'un modèle (un MultiMesh par morceau) aux points donnés.
## `points` : [[position, échelle, angle]…].
static func semer(parent: Node3D, nom: String, points: Array, teinte := Color.WHITE) -> void:
	var ms := maillages(nom)
	if ms.is_empty():
		return
	var paquets := []
	for m in ms:
		paquets.append([])
	for k in points.size():
		paquets[k % ms.size()].append(points[k])
	for i in ms.size():
		var liste: Array = paquets[i]
		if liste.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = ms[i][0]
		mm.instance_count = liste.size()
		for k in liste.size():
			var p: Array = liste[k]
			var t := Transform3D(Basis(Vector3.UP, float(p[2])).scaled(Vector3.ONE * float(p[1])), p[0]) * (ms[i][1] as Transform3D)
			mm.set_instance_transform(k, t)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if teinte != Color.WHITE:
			var surf := (ms[i][0] as Mesh).surface_get_material(0)
			if surf is BaseMaterial3D:
				var mat := (surf as BaseMaterial3D).duplicate() as BaseMaterial3D
				mat.albedo_color = mat.albedo_color * teinte
				mmi.material_override = mat
		parent.add_child(mmi)


## Le sentier k : un ruban de terre battue, bords ronges, de la place jusqu'à la clairière.
static func ruban_sentier(k: int, mat: Material, depuis := -1.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r0 := Ronde.R_PLACE - 0.6 if depuis < 0.0 else depuis
	var r1 := Quetes.R_ZONE - 4.2
	var pas := 0.5
	var avant: Array = []
	var r := r0
	var longueur := 0.0
	while r <= r1 + 0.01:
		var m := sentier(k, r)
		var suite := sentier(k, r + 0.1)
		var t := (suite - m).normalized().cross(Vector3.UP)
		var l := LARGEUR_SENTIER * (0.85 + 0.15 * sin(r * 0.9 + k))
		var g := m - t * l * 0.5 + Vector3(0, 0.032, 0)
		var d := m + t * l * 0.5 + Vector3(0, 0.032, 0)
		if not avant.is_empty():
			var g0: Vector3 = avant[0]
			var d0: Vector3 = avant[1]
			var v0: float = avant[2]
			for q: Array in [[g0, 0.0, v0], [d0, 1.0, v0], [d, 1.0, longueur], [g0, 0.0, v0], [d, 1.0, longueur], [g, 0.0, longueur]]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(q[1], float(q[2]) / (r1 - r0)))
				st.add_vertex(q[0])
		avant = [g, d, longueur]
		longueur += pas
		r += pas
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## La terre battue du sentier : la texture de piste caillouteuse, plus sombre et humide au milieu,
## des bords ronges (bruit) qui se fondent dans le sol.
static func mat_sentier() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D piste_a : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D piste_n : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D piste_r : repeat_enable, filter_linear_mipmap_anisotropic;
varying vec3 mp;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { mp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float bord = abs(UV.x - 0.5) * 2.0;
	float ronge = bruit(mp.xz * 2.3) * 0.35 + bruit(mp.xz * 7.0) * 0.15;
	// Il s'effile et se perd dans la terre à ses deux bouts.
	float bouts = min(1.0, min(UV.y * 10.0, (1.0 - UV.y) * 7.0));
	if (bord > (0.62 + ronge) * bouts) { discard; }
	vec2 u = mp.xz * 0.45;
	vec3 a = texture(piste_a, u).rgb * vec3(0.95, 0.84, 0.7);
	float milieu = 1.0 - smoothstep(0.0, 0.7, bord);
	a *= mix(1.0, 0.72, milieu * bruit(mp.xz * 0.6));   // l'ornière, humide
	ALBEDO = a;
	NORMAL_MAP = texture(piste_n, u).rgb;
	ROUGHNESS = mix(texture(piste_r, u).r, 0.55, milieu * 0.4);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("piste_a", load("res://textures/rocky_trail_diff.jpg"))
	m.set_shader_parameter("piste_n", load("res://textures/rocky_trail_nor.jpg"))
	m.set_shader_parameter("piste_r", load("res://textures/rocky_trail_rough.jpg"))
	m.render_priority = 1
	return m
