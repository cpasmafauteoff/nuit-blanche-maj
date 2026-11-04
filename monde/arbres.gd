class_name Arbres
extends RefCounted
## Les arbres du bois, faits par le code (décision d'Edwin, 29/10 : « plus réalistes, plus
## flippants ») : un tronc tordu qui s'évase en racines, une écorce creusée de sillons, des branches
## nues qui griffent le ciel ; ou un sapin noir aux branches qui pendent. Huit variantes, bâties
## une fois au premier usage et partagées par tous les arbres (un maillage par variante).

const NB := 8          # 0..4 : arbres morts, 5..7 : sapins
const FACES := 9       # côtés d'un tronc (6 pour une branche)

static var _cache := {}


static func est_sapin(k: int) -> bool:
	return posmod(k, NB) >= 5


## {tronc: ArrayMesh, aiguilles: ArrayMesh ou null, axe: PackedVector3Array, rayons: PackedFloat32Array, haut: float}
static func variante(k: int) -> Dictionary:
	k = posmod(k, NB)
	if _cache.has(k):
		return _cache[k]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + k * 97
	var bruit := FastNoiseLite.new()
	bruit.seed = 17 + k
	bruit.frequency = 0.9
	var sapin := est_sapin(k)
	var haut := rng.randf_range(3.8, 4.6) if sapin else rng.randf_range(3.2, 4.2)
	var r0 := rng.randf_range(0.2, 0.24) if sapin else rng.randf_range(0.26, 0.34)
	# L'axe du tronc : il part un peu sous terre, se tord, penche.
	var axe := PackedVector3Array()
	var rayons := PackedFloat32Array()
	var n := 14
	var phase := rng.randf() * TAU
	var tord := 0.03 if sapin else rng.randf_range(0.08, 0.16)
	for i in n + 1:
		var u := float(i) / n
		var h := -0.15 + u * (haut + 0.15)
		axe.append(Vector3(sin(h * 0.9 + phase) * tord * u * 2.0, h, cos(h * 0.7 + phase * 1.3) * tord * u * 1.6))
		rayons.append(lerpf(r0, r0 * (0.12 if sapin else 0.22), pow(u, 0.8)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var contreforts := rng.randi_range(4, 6)
	var phi := rng.randf() * TAU
	_tube(st, axe, rayons, FACES, func(th: float, h: float, r: float) -> float:
		# L'écorce : des sillons verticaux, des bosses ; au pied, l'évasement et les racines.
		var sillon := 0.07 * bruit.get_noise_3d(cos(th) * 2.0, sin(th) * 2.0, h * 1.5)
		var bosse := 0.05 * bruit.get_noise_3d(cos(th) * 0.7 + 9.0, sin(th) * 0.7, h * 0.4)
		var pied := 0.9 * exp(-maxf(h, 0.0) / 0.22)
		var racine := 0.7 * pow(maxf(0.0, cos(contreforts * th + phi)), 3.0) * exp(-maxf(h, 0.0) / 0.35)
		return r * (1.0 + sillon + bosse + pied + racine), 0.55)
	if not sapin:
		_branches(st, rng, axe, rayons, haut)
	st.index()
	st.generate_normals()
	var d := {"tronc": st.commit(), "aiguilles": null, "axe": axe, "rayons": rayons, "haut": haut}
	if sapin:
		d["aiguilles"] = _aiguilles(rng, haut)
	_cache[k] = d
	return d


## Le point de l'axe et le rayon du tronc à la hauteur h (pour y sculpter un visage).
static func axe_a(d: Dictionary, h: float) -> Array:
	var axe: PackedVector3Array = d["axe"]
	var rayons: PackedFloat32Array = d["rayons"]
	for i in axe.size() - 1:
		if axe[i + 1].y >= h:
			var u := inverse_lerp(axe[i].y, axe[i + 1].y, h)
			return [axe[i].lerp(axe[i + 1], u), lerpf(rayons[i], rayons[i + 1], u)]
	return [axe[axe.size() - 1], rayons[rayons.size() - 1]]


## Un tube le long de `axe`, de rayons `rayons`, `cotes` côtés ; `relief(th, h, r)` déforme chaque
## sommet. Le bout est refermé en pointe. UV : u autour (2 tours de texture), v le long.
static func _tube(st: SurfaceTool, axe: PackedVector3Array, rayons: PackedFloat32Array, cotes: int, relief: Callable, v_echelle: float) -> void:
	var anneaux: Array = []
	var v := 0.0
	for i in axe.size():
		var t := (axe[mini(i + 1, axe.size() - 1)] - axe[maxi(i - 1, 0)]).normalized()
		var ref := Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT
		var nn := (ref - t * ref.dot(t)).normalized()
		var bb := t.cross(nn)
		if i > 0:
			v += axe[i].distance_to(axe[i - 1]) * v_echelle
		var anneau := []
		for c in cotes + 1:
			var th := TAU * c / cotes
			var r: float = relief.call(th, axe[i].y, rayons[i]) if relief.is_valid() else rayons[i]
			anneau.append([axe[i] + (nn * cos(th) + bb * sin(th)) * r, Vector2(2.0 * c / cotes, v)])
		anneaux.append(anneau)
	for i in anneaux.size() - 1:
		for c in cotes:
			var a: Array = anneaux[i][c]
			var b: Array = anneaux[i][c + 1]
			var cc: Array = anneaux[i + 1][c + 1]
			var dd: Array = anneaux[i + 1][c]
			for s: Array in [a, dd, cc, a, cc, b]:
				st.set_uv(s[1])
				st.add_vertex(s[0])
	var bout := axe[axe.size() - 1] + (axe[axe.size() - 1] - axe[axe.size() - 2]).normalized() * rayons[rayons.size() - 1] * 2.0
	var der: Array = anneaux[anneaux.size() - 1]
	for c in cotes:
		for s: Array in [der[c], [bout, Vector2(2.0 * c / cotes, v + 0.1)], der[c + 1]]:
			st.set_uv(s[1])
			st.add_vertex(s[0])


## Les branches nues d'un arbre mort : des bras qui montent puis se recourbent en griffe, et
## leurs rameaux.
static func _branches(st: SurfaceTool, rng: RandomNumberGenerator, axe: PackedVector3Array, rayons: PackedFloat32Array, haut: float) -> void:
	var d := {"axe": axe, "rayons": rayons}
	var nb := rng.randi_range(6, 9)
	for b in nb:
		var h := lerpf(haut * 0.42, haut * 0.95, float(b) / (nb - 1)) + rng.randf_range(-0.15, 0.15)
		var base: Array = axe_a(d, h)
		var az := b * 2.4 + rng.randf_range(-0.5, 0.5)
		var monte := rng.randf_range(0.35, 1.0)
		var dir := Vector3(cos(az), monte, sin(az)).normalized()
		var longueur := rng.randf_range(0.9, 1.9) * (1.15 - h / haut * 0.4)
		var r_base: float = (base[1] as float) * rng.randf_range(0.32, 0.45)
		var spine := _spine(rng, base[0], dir, longueur, 6, rng.randf_range(-0.35, 0.2))
		var rr := PackedFloat32Array()
		for i in spine.size():
			rr.append(lerpf(r_base, 0.012, float(i) / (spine.size() - 1)))
		_tube(st, spine, rr, 6, Callable(), 0.9)
		for k in rng.randi_range(2, 3):
			var i0 := rng.randi_range(2, spine.size() - 2)
			var d2 := (spine[i0] - spine[i0 - 1]).normalized().rotated(Vector3.UP, rng.randf_range(-1.2, 1.2))
			d2 = (d2 + Vector3(0, rng.randf_range(0.1, 0.6), 0)).normalized()
			var s2 := _spine(rng, spine[i0], d2, rng.randf_range(0.35, 0.8), 4, rng.randf_range(-0.5, 0.3))
			var r2 := PackedFloat32Array()
			for i in s2.size():
				r2.append(lerpf(rr[i0] * 0.6, 0.008, float(i) / (s2.size() - 1)))
			_tube(st, s2, r2, 5, Callable(), 0.9)


## Un axe de branche : il part dans `dir`, se tord au hasard ; `courbe` < 0 le fait retomber.
static func _spine(rng: RandomNumberGenerator, depart: Vector3, dir: Vector3, longueur: float, n: int, courbe: float) -> PackedVector3Array:
	var p := PackedVector3Array([depart])
	var d := dir
	for i in n:
		d = (d + Vector3(rng.randf_range(-0.25, 0.25), courbe * 0.25, rng.randf_range(-0.25, 0.25))).normalized()
		p.append(p[p.size() - 1] + d * longueur / n)
	return p


## Les branches d'un sapin noir : des jupes étagées aux pointes qui pendent, découpées en dents.
static func _aiguilles(rng: RandomNumberGenerator, haut: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var etages := 10
	for e in etages:
		var u := float(e) / etages
		var h := lerpf(0.9, haut - 0.15, u)
		var r := lerpf(1.55, 0.3, pow(u, 0.85)) * rng.randf_range(0.88, 1.12)
		var dents := 19
		var cime := Vector3(0, h + 0.55 + (1.0 - u) * 0.2, 0)
		var dessous := Vector3(0, h - 0.12, 0)
		var milieu: Array[Vector3] = []
		var bord: Array[Vector3] = []
		var d0 := rng.randf() * TAU
		for k in dents:
			var a := d0 + TAU * k / dents
			var rk := r * (1.15 if k % 2 == 0 else 0.68) * rng.randf_range(0.8, 1.2)
			var pend := rng.randf_range(0.3, 0.65) * (1.0 if k % 2 == 0 else 0.55)
			milieu.append(Vector3(cos(a) * rk * 0.5, h + 0.12, sin(a) * rk * 0.5))
			bord.append(Vector3(cos(a) * rk, h - pend, sin(a) * rk))
		for k in dents:
			var k2 := (k + 1) % dents
			var clair := Color(0.75, 0.85, 0.75) if k % 2 == 0 else Color(0.55, 0.62, 0.55)
			for s: Array in [[cime, Color(0.45, 0.5, 0.45)], [milieu[k], clair], [milieu[k2], clair],
					[milieu[k], clair], [bord[k], Color(1, 1, 1)], [bord[k2], Color(0.9, 0.95, 0.9)],
					[milieu[k], clair], [bord[k2], Color(0.9, 0.95, 0.9)], [milieu[k2], clair],
					[dessous, Color(0.2, 0.22, 0.2)], [bord[k2], Color(0.4, 0.45, 0.4)], [bord[k], Color(0.4, 0.45, 0.4)]]:
				st.set_color(s[1])
				st.add_vertex(s[0])
	st.generate_normals()
	return st.commit()


static var _mat_aiguilles: ShaderMaterial = null


## La matière des aiguilles (demande d'Edwin, 30/10 : « les arbres ne sont pas bien faits ») : plus
## d'aplat noir, des aiguilles en stries qui accrochent la lumière, des pointes plus claires, et des
## bords effilochés (les jupes ne finissent plus en arête nette). Partagée par tous les sapins.
static func materiau_aiguilles() -> ShaderMaterial:
	if _mat_aiguilles:
		return _mat_aiguilles
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
varying vec3 lp;
float h3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float bruit(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() {
	lp = VERTEX;
}
void fragment() {
	// Des stries qui partent du tronc vers la pointe : la direction de l'aiguille.
	float ang = atan(lp.z, lp.x);
	float rad = length(lp.xz);
	float stries = bruit(vec3(ang * 22.0, rad * 3.0, lp.y * 9.0));
	float fin = bruit(lp * 34.0);
	float touffes = bruit(lp * 3.5);
	float bord = smoothstep(0.88, 1.0, COLOR.r);
	// Les bords des jupes s'effilochent.
	if (bord > 0.0 && fin < bord * 0.55) {
		discard;
	}
	vec3 vert = mix(vec3(0.035, 0.06, 0.04), vec3(0.1, 0.15, 0.085), stries * 0.7 + touffes * 0.3);
	vert = mix(vert, vec3(0.14, 0.18, 0.1), bord * 0.6 * fin);
	ALBEDO = vert * (0.45 + 0.75 * COLOR.r);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4((stries - 0.5) * 0.9, 0.0, (fin - 0.5) * 0.9, 0.0)).xyz);
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
	BACKLIGHT = vec3(0.025, 0.04, 0.02);
}
"""
	_mat_aiguilles = ShaderMaterial.new()
	_mat_aiguilles.shader = sh
	return _mat_aiguilles
