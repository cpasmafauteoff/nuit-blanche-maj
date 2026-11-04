class_name StyleCarnet
extends RefCounted
## Les matières du carnet, fabriquées une fois au premier usage : cuir de couverture usé, papier
## crème taché (avec ou sans lignes), tranche des pages. Servent au panneau 2D (panneau_carnet.gd)
## et au carnet 3D (carnet_3d.gd), pour que l'un et l'autre aient le même air.

const ENCRE := Color(0.14, 0.09, 0.07)
const OR := Color(0.9, 0.72, 0.36)
const CUIR_SOMBRE := Color(0.2, 0.105, 0.05)
const CUIR := Color(0.36, 0.2, 0.1)
## Proportions d'une page de carnet : 14 cm sur 20 cm.
const PAGE_L := 256
const PAGE_H := 366

static var _cache := {}


static func _bruit(graine: int, freq: float, type := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = type
	n.seed = graine
	n.frequency = freq
	return n


## Cuir : grain de peau, zones plus claires aux endroits où on le tient, quelques éraflures.
static func cuir() -> ImageTexture:
	if _cache.has("cuir"):
		return _cache["cuir"]
	var w := 256
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var grain := _bruit(5, 0.11, FastNoiseLite.TYPE_CELLULAR)
	grain.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var user := _bruit(9, 0.012)
	var fin := _bruit(23, 0.35)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var rayures: Array = []
	for i in 5:
		var p := Vector2(rng.randf() * w, rng.randf() * h)
		var a := rng.randf() * TAU
		rayures.append([p, Vector2(cos(a), sin(a)), rng.randf_range(14.0, 60.0)])
	for y in h:
		for x in w:
			var g := grain.get_noise_2d(x, y) * 0.5 + 0.5
			var u := user.get_noise_2d(x, y) * 0.5 + 0.5
			var c := CUIR_SOMBRE.lerp(CUIR, 0.35 + g * 0.45 + fin.get_noise_2d(x, y) * 0.08)
			c = c.lerp(Color(0.52, 0.33, 0.18), clampf((u - 0.55) * 1.6, 0.0, 0.7))
			for r: Array in rayures:
				var d: Vector2 = Vector2(x, y) - (r[0] as Vector2)
				var along: float = d.dot(r[1])
				if absf(along) < r[2] and absf(d.dot(Vector2(-r[1].y, r[1].x))) < 0.7:
					c = c.lerp(Color(0.55, 0.38, 0.22), 0.4)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache["cuir"] = tex
	return tex


## Papier crème. `lignes` : réglure discrète (une ligne tous les 1,4 cm). `cote` : -1 page de gauche,
## 1 page de droite (le pli du livre assombrit le bord côté reliure), 0 : page seule.
static func papier(lignes := false, cote := 0) -> ImageTexture:
	var cle := "papier_%s_%d" % [lignes, cote]
	if _cache.has(cle):
		return _cache[cle]
	var w := PAGE_L
	var h := PAGE_H
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var gros := _bruit(14, 0.011)
	var fibre := _bruit(41, 0.45)
	var bord := _bruit(77, 0.05)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var taches: Array = []
	for i in 5:
		taches.append([Vector2(rng.randf() * w, rng.randf() * h), rng.randf_range(12.0, 44.0), rng.randf_range(0.18, 0.4)])
	var clair := Color(0.93, 0.87, 0.72)
	var fonce := Color(0.83, 0.74, 0.57)
	var rousseur := Color(0.62, 0.45, 0.24)
	var ligne := Color(0.42, 0.32, 0.22)
	var pas := float(h) * 0.0143 / 0.2      # 1,43 cm de page
	for y in h:
		for x in w:
			var g := gros.get_noise_2d(x, y) * 0.5 + 0.5
			var c := clair.lerp(fonce, g * 0.7 + fibre.get_noise_2d(x, y) * 0.07)
			for t: Array in taches:
				var d := (Vector2(x, y) - (t[0] as Vector2)).length() / float(t[1])
				if d < 1.0:
					c = c.lerp(rousseur, (1.0 - d) * (1.0 - d) * t[2])
			# Bords un peu roussis.
			var e := float(mini(mini(x, w - 1 - x), mini(y, h - 1 - y))) + bord.get_noise_2d(x, y) * 7.0
			if e < 16.0:
				c = c.lerp(rousseur, pow(1.0 - e / 16.0, 2.0) * 0.5)
			# Le pli : le papier s'assombrit en descendant vers la reliure.
			if cote != 0:
				var dist := float(x) / w if cote > 0 else 1.0 - float(x) / w
				c = c.lerp(Color(0.35, 0.24, 0.13), pow(clampf(1.0 - dist * 3.2, 0.0, 1.0), 1.8) * 0.55)
			if lignes:
				var k := (float(y) - h * 0.1) / pas
				if k > 0.0 and k < 12.6 and absf(k - roundf(k)) * pas < 0.7:
					c = c.lerp(ligne, 0.32)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[cle] = tex
	return tex


## Tranche d'un bloc de pages : fines stries horizontales, jaunies.
static func tranche() -> ImageTexture:
	if _cache.has("tranche"):
		return _cache["tranche"]
	var w := 32
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var n := _bruit(3, 0.2)
	for y in h:
		for x in w:
			var v := 0.5 + 0.5 * sin(y * 2.4) + n.get_noise_2d(x * 4.0, y) * 0.25
			var c := Color(0.8, 0.72, 0.54).lerp(Color(0.6, 0.5, 0.34), clampf(v * 0.8, 0.0, 1.0))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache["tranche"] = tex
	return tex


static func materiau_cuir(teinte := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = cuir()
	m.albedo_color = teinte
	m.roughness = 0.62
	m.metallic_specular = 0.35
	m.uv1_scale = Vector3(0.5, 0.5, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func materiau_papier(lignes := false, cote := 0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = papier(lignes, cote)
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func materiau_tranche() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tranche()
	m.roughness = 1.0
	return m


static func materiau_laiton() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.6, 0.24)
	m.metallic = 0.85
	m.roughness = 0.38
	return m
