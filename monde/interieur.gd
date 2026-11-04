class_name Interieur
extends RefCounted
## L'intérieur d'une maison : plancher de lattes, lambris et torchis sur les murs, poutres et solives,
## tapis usé, âtre avec son feu, étagères chargées de pots, quelques objets sur la table. Les meubles qui ont un volume
## portent une collision en boîte (cf. `_solide`), comme le lit et la table de Ronde._maison. Les tirages au hasard viennent d'un générateur à part, jamais de celui du
## village, pour ne rien décaler ailleurs.
##
## Repère : celui de la maison (origine au centre du sol, +Z vers la façade, +Y en haut). Les faces
## intérieures des murs sont à x = ±2,04 et z = ±1,80.

const X_MUR := 2.04
const Z_MUR := 1.8
const H_MUR := 2.98
const H_LAMBRIS := 0.85
const EPAIS := 0.026

static var _cache := {}


# ---------------------------------------------------------------- matières

static func _bruit(graine: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = graine
	n.frequency = freq
	return n


## Lattes de bois : chacune sa teinte, son fil, des jours sombres entre elles, des clous aux bouts.
## `sens` : les lattes courent selon X (plancher) ou selon Y (lambris).
static func tex_lattes(clair: Color, fonce: Color, graine: int) -> ImageTexture:
	var cle := "lattes_%s_%s_%d" % [clair.to_html(), fonce.to_html(), graine]
	if _cache.has(cle):
		return _cache[cle]
	var w := 512
	var h := 512
	var n_lattes := 10
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var fil := _bruit(graine, 0.012)
	var fin := _bruit(graine + 5, 0.06)
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var tons: Array[float] = []
	var decal: Array[float] = []
	for k in n_lattes:
		tons.append(rng.randf())
		decal.append(rng.randf() * 400.0)
	var larg := float(h) / n_lattes
	for y in h:
		var k := int(y / larg)
		var dy := fmod(float(y), larg)
		for x in w:
			var f := fil.get_noise_2d(x * 0.18 + decal[k], y * 1.7) * 0.5 + 0.5
			var c := clair.lerp(fonce, clampf(tons[k] * 0.55 + f * 0.5 + fin.get_noise_2d(x * 0.5, y * 2.0) * 0.12, 0.0, 1.0))
			# Un jour sombre entre deux lattes, un liseré clair au-dessus.
			if dy < 1.5 or dy > larg - 1.5:
				c = c.lerp(Color(0.04, 0.025, 0.015), 0.85)
			elif dy < 3.0:
				c = c.lerp(Color(1, 0.9, 0.7), 0.06)
			# Les joints en bout de latte, décalés d'une latte à l'autre.
			var jx := fmod(float(x) + decal[k], 300.0)
			if jx < 1.5:
				c = c.lerp(Color(0.04, 0.025, 0.015), 0.8)
			elif jx > 6.0 and jx < 8.5 and absf(dy - larg * 0.5) < 1.2:
				c = Color(0.12, 0.09, 0.07)     # un clou
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[cle] = t
	return t


## Torchis : chaux jaunie, taches d'humidité, fissures fines.
static func tex_torchis() -> ImageTexture:
	if _cache.has("torchis"):
		return _cache["torchis"]
	var w := 256
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var gros := _bruit(61, 0.014)
	var moy := _bruit(62, 0.045)
	var fin := _bruit(63, 0.4)
	var fis := FastNoiseLite.new()
	fis.noise_type = FastNoiseLite.TYPE_CELLULAR
	fis.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	fis.frequency = 0.035
	fis.seed = 64
	for y in h:
		for x in w:
			var g := gros.get_noise_2d(x, y) * 0.5 + 0.5
			var c := Color(0.8, 0.7, 0.54).lerp(Color(0.6, 0.48, 0.34), g * 0.8 + moy.get_noise_2d(x, y) * 0.2)
			c = c.lerp(Color(0.4, 0.3, 0.2), clampf(fin.get_noise_2d(x, y) * 0.5 + 0.1, 0.0, 0.2))
			var f := fis.get_noise_2d(x, y)
			if f > 0.93:
				c = c.lerp(Color(0.22, 0.16, 0.1), 0.55)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache["torchis"] = t
	return t


## Tapis de laine usé : bordure ocre, losanges, usure.
static func tex_tapis() -> ImageTexture:
	if _cache.has("tapis"):
		return _cache["tapis"]
	var w := 256
	var h := 176
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var usure := _bruit(71, 0.03)
	var fil := _bruit(72, 0.5)
	var rouge := Color(0.42, 0.11, 0.08)
	var ocre := Color(0.7, 0.5, 0.2)
	var bleu := Color(0.12, 0.15, 0.24)
	var creme := Color(0.72, 0.62, 0.45)
	for y in h:
		for x in w:
			var e := mini(mini(x, w - 1 - x), mini(y, h - 1 - y))
			var c := rouge
			if e < 8:
				c = bleu
			elif e < 12:
				c = ocre
			elif e < 26:
				c = bleu if (x / 8 + y / 8) % 2 == 0 else rouge
			elif e < 29:
				c = ocre
			else:
				# Un grand losange au centre, des petits tout autour.
				var dx := absf(float(x) - w * 0.5)
				var dy := absf(float(y) - h * 0.5)
				if dx / 70.0 + dy / 38.0 < 1.0:
					c = ocre if dx / 70.0 + dy / 38.0 > 0.78 else bleu
					if dx / 70.0 + dy / 38.0 < 0.3:
						c = creme
				elif (int(x) % 32 < 3) or (int(y) % 32 < 3):
					c = rouge.lightened(0.1)
			var u := usure.get_noise_2d(x, y) * 0.5 + 0.5
			c = c.lerp(Color(0.38, 0.3, 0.22), clampf((u - 0.5) * 1.5, 0.0, 0.55))
			c = c.darkened(clampf(fil.get_noise_2d(x, y) * 0.12, 0.0, 0.2))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache["tapis"] = t
	return t


static func _mat(tex: Texture2D, echelle: float, rugosite := 0.9, teinte := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = teinte
	m.roughness = rugosite
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * echelle
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func _mat_unie(c: Color, rugosite := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugosite
	return m


static func mat_plancher() -> StandardMaterial3D:
	if not _cache.has("m_plancher"):
		_cache["m_plancher"] = _mat(tex_lattes(Color(0.46, 0.31, 0.18), Color(0.25, 0.15, 0.08), 7), 0.5)
	return _cache["m_plancher"]


static func mat_lambris() -> StandardMaterial3D:
	if not _cache.has("m_lambris"):
		_cache["m_lambris"] = _mat(tex_lattes(Color(0.4, 0.26, 0.15), Color(0.2, 0.12, 0.07), 19), 0.85)
	return _cache["m_lambris"]


static func mat_poutre() -> StandardMaterial3D:
	if not _cache.has("m_poutre"):
		_cache["m_poutre"] = _mat(tex_lattes(Color(0.26, 0.17, 0.1), Color(0.12, 0.075, 0.04), 33), 1.4, 0.8)
	return _cache["m_poutre"]


static func mat_torchis() -> StandardMaterial3D:
	if not _cache.has("m_torchis"):
		_cache["m_torchis"] = _mat(tex_torchis(), 0.55, 1.0)
	return _cache["m_torchis"]


static func mat_pierre() -> StandardMaterial3D:
	if not _cache.has("m_pierre"):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://textures/cobblestone_floor_08_diff.jpg")
		m.albedo_color = Color(0.62, 0.58, 0.55)
		m.normal_enabled = true
		m.normal_texture = load("res://textures/cobblestone_floor_08_nor.jpg")
		m.roughness = 0.95
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 1.4
		_cache["m_pierre"] = m
	return _cache["m_pierre"]


static func mat_tapis() -> StandardMaterial3D:
	if not _cache.has("m_tapis"):
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex_tapis()
		m.roughness = 1.0
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_cache["m_tapis"] = m
	return _cache["m_tapis"]


static func mat_laine() -> StandardMaterial3D:
	return _mat_unie(Color(0.36, 0.18, 0.13), 1.0)


static func mat_emissif(c: Color, force: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = force
	m.roughness = 1.0
	return m


# ---------------------------------------------------------------- briques de construction

static func _boite(parent: Node3D, taille: Vector3, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Un volume plein, invisible, en boîte (couche 1 comme les murs) : ce qu'on ne traverse pas, et sur quoi
## un objet jeté se pose. Le repère est celui du `parent`. Marqué (méta « solide ») pour le test des meubles.
static func _solide(parent: Node3D, taille: Vector3, pos: Vector3, rot_y := 0.0) -> StaticBody3D:
	var corps := StaticBody3D.new()
	corps.set_meta("solide", true)
	var c := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = taille
	c.shape = b
	corps.add_child(c)
	corps.position = pos
	corps.rotation.y = rot_y
	parent.add_child(corps)
	return corps


static func _cyl(parent: Node3D, r_haut: float, r_bas: float, h: float, m: Material, pos: Vector3, rot := Vector3.ZERO, seg := 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_haut
	c.bottom_radius = r_bas
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _objet(parent: Node3D, nom: String, pos: Vector3, rot_y := 0.0, echelle := 1.0) -> Node3D:
	var ps := load("res://modeles/nature/%s/%s.gltf" % [nom, nom]) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	n.position = pos
	n.rotation.y = rot_y
	n.scale = Vector3.ONE * echelle
	parent.add_child(n)
	return n


## Un panneau collé contre la face intérieure d'un mur. `mur` : "gauche", "droite", "fond", "façade".
## [a, b] : l'étendue le long du mur ; [y0, y1] : la hauteur.
static func _panneau(parent: Node3D, mur: String, a: float, b: float, y0: float, y1: float, m: Material) -> void:
	var lon := b - a
	var h := y1 - y0
	var c := (a + b) * 0.5
	var y := (y0 + y1) * 0.5
	match mur:
		"gauche":
			_boite(parent, Vector3(EPAIS, h, lon), m, Vector3(-X_MUR + EPAIS * 0.5, y, c))
		"droite":
			_boite(parent, Vector3(EPAIS, h, lon), m, Vector3(X_MUR - EPAIS * 0.5, y, c))
		"fond":
			_boite(parent, Vector3(lon, h, EPAIS), m, Vector3(c, y, -Z_MUR + EPAIS * 0.5))
		_:
			_boite(parent, Vector3(lon, h, EPAIS), m, Vector3(c, y, Z_MUR - EPAIS * 0.5))


## Une fenêtre tombe-t-elle dans [a, b] sur ce mur ? `fens` : [position locale, direction, largeur].
static func _fenetre_dans(fens: Array, mur: String, a: float, b: float) -> bool:
	for f: Array in fens:
		var p: Vector3 = f[0]
		var le_long := p.z if mur in ["gauche", "droite"] else p.x
		var sur_le_mur := false
		match mur:
			"gauche":
				sur_le_mur = p.x < -2.0
			"droite":
				sur_le_mur = p.x > 2.0
			"fond":
				sur_le_mur = p.z < -2.0
			_:
				sur_le_mur = p.z > 2.0
		if sur_le_mur and le_long > a - 0.2 and le_long < b + 0.2:
			return true
	return false


# ---------------------------------------------------------------- la pièce

## Meuble et habille la maison. Renvoie les lumières de l'âtre (à faire vaciller comme les bougies).
static func meubler(maison: Node3D, i: int, fens: Array) -> Array[OmniLight3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210 + i * 131
	var feux: Array[OmniLight3D] = []
	var poutre := mat_poutre()
	var lambris := mat_lambris()
	var torchis := mat_torchis()

	# Plancher : de vraies lattes, posées sur les dalles du pack.
	_boite(maison, Vector3(X_MUR * 2.0, 0.012, Z_MUR * 2.0), mat_plancher(), Vector3(0, 0.07, 0))

	# Murs : lambris de bois sur le bas, torchis au-dessus (là où il n'y a pas de fenêtre).
	var troncons := [
		["gauche", -Z_MUR, 0.0], ["gauche", 0.0, Z_MUR],
		["droite", -Z_MUR, 0.0], ["droite", 0.0, Z_MUR],
		["fond", -X_MUR, -1.0], ["fond", 1.0, X_MUR],
		["façade", -X_MUR, -1.0], ["façade", 1.0, X_MUR],
	]
	var libres: Array = []         # les troncons sans fenêtre : pour l'âtre et les étagères
	for t: Array in troncons:
		var mur: String = t[0]
		var a: float = t[1]
		var b: float = t[2]
		_panneau(maison, mur, a, b, 0.07, H_LAMBRIS, lambris)
		if mur == "façade" or _fenetre_dans(fens, mur, a, b):
			continue
		_panneau(maison, mur, a, b, H_LAMBRIS, H_MUR, torchis)
		libres.append(t)
	# Le pan du fond, entre -1 et 1 : c'était la porte de derrière (supprimée le 01/11, un mur plein la remplace).
	# Sans lui, ce pan restait nu, d'une autre couleur que les murs de la pièce (Edwin, 01/11). Habillé comme le
	# reste du fond ; hors de `libres`, pour ne rien déplacer des étagères.
	_panneau(maison, "fond", -1.0, 1.0, 0.07, H_LAMBRIS, lambris)
	_panneau(maison, "fond", -1.0, 1.0, H_LAMBRIS, H_MUR, torchis)
	# Le chambranle : une moulure sur le dessus du lambris, sur tout le tour sauf aux portes.
	for t: Array in troncons:
		var mur: String = t[0]
		var a: float = t[1]
		var b: float = t[2]
		var lon := b - a
		var c := (a + b) * 0.5
		match mur:
			"gauche":
				_boite(maison, Vector3(0.05, 0.045, lon), poutre, Vector3(-X_MUR + 0.025, H_LAMBRIS + 0.02, c))
			"droite":
				_boite(maison, Vector3(0.05, 0.045, lon), poutre, Vector3(X_MUR - 0.025, H_LAMBRIS + 0.02, c))
			"fond":
				_boite(maison, Vector3(lon, 0.045, 0.05), poutre, Vector3(c, H_LAMBRIS + 0.02, -Z_MUR + 0.025))
			_:
				_boite(maison, Vector3(lon, 0.045, 0.05), poutre, Vector3(c, H_LAMBRIS + 0.02, Z_MUR - 0.025))

	_boite(maison, Vector3(2.0, 0.045, 0.05), poutre, Vector3(0, H_LAMBRIS + 0.02, -Z_MUR + 0.025))   # la moulure du pan du fond

	# Charpente : poteaux d'angle, entraits et solives sous le plafond.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_boite(maison, Vector3(0.16, H_MUR, 0.16), poutre, Vector3(sx * (X_MUR - 0.08), H_MUR * 0.5, sz * (Z_MUR - 0.08)))
	for z: float in [-1.2, 0.0, 1.2]:
		_boite(maison, Vector3(X_MUR * 2.0, 0.2, 0.17), poutre, Vector3(0, H_MUR - 0.1, z))
	for k in 9:
		_boite(maison, Vector3(0.07, 0.09, Z_MUR * 2.0), poutre, Vector3(-X_MUR + 0.3 + k * (X_MUR * 2.0 - 0.6) / 8.0, H_MUR - 0.045 - 0.14, 0))
	# Aisselliers : une jambe de force sous l'entrait central, de chaque côté.
	for sx: float in [-1.0, 1.0]:
		_boite(maison, Vector3(0.09, 0.7, 0.12), poutre, Vector3(sx * (X_MUR - 0.45), H_MUR - 0.55, 0.0), Vector3(0, 0, -sx * 0.7))

	# Tapis usé, entre la table et le lit, sur le passage (sans épaisseur : on marche dessus).
	var tapis := _boite(maison, Vector3(1.75, 0.008, 1.2), mat_tapis(), Vector3(-0.2, 0.08, 0.55 + rng.randf_range(-0.1, 0.1)), Vector3(0, rng.randf_range(-0.12, 0.12), 0))
	tapis.name = "Tapis"

	# L'âtre : sur un mur libre, à gauche côté fenêtre sinon rien (la fenêtre est plus belle).
	var atre_pose := false
	for t: Array in libres:
		if t[0] == "gauche" and t[1] == 0.0:
			feux = _atre(maison, "gauche", (float(t[1]) + float(t[2])) * 0.5 + 0.05)
			atre_pose = true
			break

	# Des étagères sur les murs libres qui restent : fond, puis droite.
	var nb_etageres := 0
	for t: Array in libres:
		var mur: String = t[0]
		if nb_etageres >= 2 or (mur == "gauche" and atre_pose):
			continue
		if mur == "gauche" and float(t[2]) <= 0.0:
			continue
		var a: float = t[1]
		var b: float = t[2]
		# Sur un mur latéral, on laisse l'angle du fond à l'étagère du mur du fond (0,7 m : sa
		# profondeur avec ses pots) : sinon les deux se traversent dans le coin.
		if mur != "fond":
			a = maxf(a, -Z_MUR + 0.7)
		_etagere(maison, mur, (a + b) * 0.5, minf(b - a, 1.5) - 0.2, rng, nb_etageres)
		nb_etageres += 1

	# La table : un pichet et une écuelle (du côté opposé au carnet et à la bougie).
	_objet(maison, "jug_01", Vector3(-1.72, 0.78, -1.42), rng.randf() * TAU, 0.9)
	_objet(maison, "wooden_bowl_01", Vector3(-1.5, 0.78, -0.97), rng.randf() * TAU, 0.9)

	# Le lit : un traversin, une couverture de laine, un coffre à son pied (le lit ne bouge pas).
	var laine := mat_tapis()
	var le_lit: Node3D = maison.get_node_or_null("Lit") if maison.has_node("Lit") else maison
	_boite(le_lit, Vector3(0.62, 0.11, 0.3), _mat_unie(Color(0.72, 0.65, 0.5), 1.0), Vector3(1.4, 0.6, -1.32), Vector3(0.05, 0, 0))
	_boite(le_lit, Vector3(0.97, 0.03, 1.05), laine, Vector3(1.4, 0.575, -0.22))
	# Des herbes qui sèchent, accrochées à l'entrait.
	for k in 4:
		var x := -1.4 + k * 0.85 + rng.randf_range(-0.1, 0.1)
		var z: float = [-1.2, 0.0, 1.2][rng.randi() % 3]
		_cyl(maison, 0.003, 0.003, 0.25, _mat_unie(Color(0.3, 0.22, 0.12)), Vector3(x, H_MUR - 0.32, z + 0.1), Vector3.ZERO, 4)
		var botte := _cyl(maison, 0.1, 0.012, 0.36, _mat_unie(Color(0.34, 0.38, 0.17) if k % 2 == 0 else Color(0.42, 0.3, 0.16), 1.0), Vector3(x, H_MUR - 0.56, z + 0.1), Vector3(PI, 0, 0), 7)
		botte.scale = Vector3(1.0, 1.0, 0.8)
	# Un tableau de mur : le cadre du pack.
	if not libres.is_empty():
		var t: Array = libres[rng.randi() % libres.size()]
		if t[0] in ["fond", "droite"] and nb_etageres == 0:
			var c := (float(t[1]) + float(t[2])) * 0.5
			var cadre := _objet(maison, "hanging_picture_frame_02", Vector3(-1.5 if t[0] == "fond" else X_MUR - 0.03, 1.7, -Z_MUR + 0.03 if t[0] == "fond" else c), 0.0 if t[0] == "fond" else -PI * 0.5, 0.9)
			if cadre:
				cadre.name = "Cadre"
				cadre.set_meta("meuble", "Cadre")
	return feux


## Une étagère : deux planches sur des consoles, des pots, une bougie.
static func _etagere(maison: Node3D, mur: String, centre: float, largeur: float, rng: RandomNumberGenerator, rang: int) -> void:
	var poutre := mat_poutre()
	var y := 1.55 + rang * 0.0
	var hauteurs := [1.5, 1.95]
	var objets := ["ceramic_pot", "jug_01", "ceramic_vase_01", "wooden_bowl_01", "brass_candleholders", "wicker_basket_02"]
	var monter := Node3D.new()
	monter.name = "Etagere"
	monter.set_meta("meuble", "Etagere")
	maison.add_child(monter)
	# Repère de l'étagère : le dos contre le mur, le devant vers la pièce (+Z local).
	match mur:
		"gauche":
			monter.position = Vector3(-X_MUR + EPAIS, 0, centre)
			monter.rotation.y = PI * 0.5
		"droite":
			monter.position = Vector3(X_MUR - EPAIS, 0, centre)
			monter.rotation.y = -PI * 0.5
		_:
			monter.position = Vector3(centre, 0, -Z_MUR + EPAIS)
	for h: float in hauteurs:
		y = h
		_boite(monter, Vector3(largeur, 0.045, 0.26), poutre, Vector3(0, y, 0.13))
		_solide(monter, Vector3(largeur, 0.06, 0.26), Vector3(0, y, 0.13))
		for sx: float in [-1.0, 1.0]:
			_boite(monter, Vector3(0.04, 0.2, 0.04), poutre, Vector3(sx * (largeur * 0.5 - 0.1), y - 0.12, 0.05), Vector3(0.5, 0, 0))
		var x := -largeur * 0.5 + 0.18
		while x < largeur * 0.5 - 0.1:
			var nom: String = objets[rng.randi() % objets.size()]
			var o := _objet(monter, nom, Vector3(x, y + 0.0225, 0.12), rng.randf() * TAU, {"brass_candleholders": 0.3, "wicker_basket_02": 0.6, "ceramic_vase_01": 0.55}.get(nom, 0.85))
			if o == null:
				break
			x += rng.randf_range(0.28, 0.4)


## L'âtre : une hotte de pierre contre le mur, une pierre de foyer, des bûches et des flammes.
## Renvoie ses deux lumières (rangées avec les bougies : elles ne brûlent que la nuit).
static func _atre(maison: Node3D, mur: String, centre: float) -> Array[OmniLight3D]:
	var pierre := mat_pierre()
	var noir := _mat_unie(Color(0.03, 0.025, 0.02), 1.0)
	var n := Node3D.new()
	n.name = "Atre"
	n.set_meta("meuble", "Atre")
	maison.add_child(n)
	# Repère : dos au mur en z = 0, le devant vers la pièce (+Z local).
	n.position = Vector3(-X_MUR + EPAIS, 0, centre)
	n.rotation.y = PI * 0.5
	for sx: float in [-1.0, 1.0]:
		_boite(n, Vector3(0.36, 0.98, 0.44), pierre, Vector3(sx * 0.56, 0.49 + 0.07, 0.22))
	_boite(n, Vector3(1.48, 0.32, 0.44), pierre, Vector3(0, 0.82 + 0.07, 0.22))
	_boite(n, Vector3(0.8, 0.6, 0.06), noir, Vector3(0, 0.37 + 0.07, 0.03))
	_boite(n, Vector3(0.8, 0.06, 0.44), pierre, Vector3(0, 0.1, 0.22))
	_boite(n, Vector3(1.8, 0.07, 0.74), pierre, Vector3(0, 0.1, 0.37))   # la pierre du foyer, qui déborde
	# Collisions : le massif (jambages, foyer et manteau d'un bloc, le feu ne se traverse pas), le conduit, les planches.
	_solide(n, Vector3(1.48, 0.98, 0.44), Vector3(0, 0.56, 0.22))
	_solide(n, Vector3(0.72, H_MUR - 1.05, 0.34), Vector3(0, 1.05 + (H_MUR - 1.05) * 0.5, 0.17))
	for sx: float in [-1.0, 1.0]:
		_solide(n, Vector3(0.44, 0.08, 0.3), Vector3(sx * 0.63, 1.19, 0.26))
	# La hotte, qui monte en s'amincissant jusqu'au plafond.
	# Un conduit droit, collé au mur, centré sur le foyer, du manteau au plafond (Edwin, 01/11 : la hotte
	# en tronc de cône était mal posée, décalée du mur, et traversait les étagères voisines).
	var h_conduit := H_MUR - 1.05
	_boite(n, Vector3(0.72, h_conduit, 0.34), pierre, Vector3(0, 1.05 + h_conduit * 0.5, 0.17))
	# Manteau de bois : deux planches de part et d'autre du conduit, qui s'arrêtent à 5 cm de la pierre
	# (Edwin, 01/11 : la planche traversait le bloc), avec un pot et une bougie.
	for sx: float in [-1.0, 1.0]:
		_boite(n, Vector3(0.44, 0.06, 0.3), mat_poutre(), Vector3(sx * 0.63, 1.12 + 0.07, 0.26))
	_objet(n, "ceramic_pot", Vector3(-0.5, 1.15 + 0.07, 0.26), 0.0, 0.8)
	_objet(n, "wooden_candlestick", Vector3(0.5, 1.15 + 0.07, 0.26), 0.0, 0.9)
	# Les bûches, les braises, les flammes.
	var bois := _mat_unie(Color(0.2, 0.12, 0.07), 1.0)
	_cyl(n, 0.06, 0.06, 0.62, bois, Vector3(0, 0.2, 0.2), Vector3(0, 0.3, PI * 0.5), 8)
	_cyl(n, 0.055, 0.055, 0.58, bois, Vector3(0.02, 0.2, 0.3), Vector3(0, -0.4, PI * 0.5), 8)
	_cyl(n, 0.05, 0.05, 0.5, bois, Vector3(0.0, 0.3, 0.25), Vector3(0.15, 0.1, PI * 0.5 + 0.35), 8)
	_boite(n, Vector3(0.62, 0.03, 0.26), mat_emissif(Color(0.9, 0.25, 0.06), 2.2), Vector3(0, 0.15, 0.26))
	var flamme := Node3D.new()
	n.add_child(flamme)
	var f1 := mat_emissif(Color(1.0, 0.55, 0.12), 3.0)
	var f2 := mat_emissif(Color(1.0, 0.82, 0.35), 3.5)
	_cyl(flamme, 0.0, 0.1, 0.46, f1, Vector3(0, 0.45, 0.25), Vector3.ZERO, 8)
	_cyl(flamme, 0.0, 0.07, 0.34, f2, Vector3(0.1, 0.4, 0.27), Vector3(0, 0, -0.15), 8)
	_cyl(flamme, 0.0, 0.07, 0.3, f1, Vector3(-0.12, 0.38, 0.22), Vector3(0, 0, 0.18), 8)
	_cyl(flamme, 0.0, 0.05, 0.22, f2, Vector3(0.0, 0.34, 0.3), Vector3.ZERO, 8)
	var feux: Array[OmniLight3D] = []
	for k in 2:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.5, 0.18)
		l.omni_range = 4.6 if k == 0 else 2.6
		l.omni_attenuation = 1.2
		l.position = Vector3(0, 0.6, 0.65 if k == 0 else 0.4)
		l.set_meta("flamme", flamme)
		n.add_child(l)
		feux.append(l)
	return feux
