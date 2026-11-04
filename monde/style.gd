class_name Style
extends RefCounted
## L'allure du village, en un seul endroit : la police à l'ancienne (IM Fell, OFL, cf.
## polices/IMFell-OFL.txt) et le parchemin vieilli (taché, bords brûlés et déchirés), fabriqué
## une fois au premier usage. Tout ce qui s'écrit dans le monde passe par ici.

const ENCRE := Color(0.17, 0.1, 0.05)
const OR := Color(0.93, 0.78, 0.45)

static var _polices := {}
static var _parchemins := {}


## "texte" (romain), "italique" ou "titre" (petites capitales).
static func police(sorte := "texte") -> Font:
	if not _polices.has(sorte):
		var fichier: String = {"texte": "IMFell-Regular", "italique": "IMFell-Italic", "titre": "IMFell-SC"}.get(sorte, "IMFell-Regular")
		var f := load("res://polices/%s.ttf" % fichier) as Font
		_polices[sorte] = f if f else ThemeDB.fallback_font
	return _polices[sorte]


## Une écriture posée dans le monde : éclairée par la scène (elle ne brille pas toute seule).
static func ecriture(texte: String, taille: int, couleur := ENCRE, sorte := "texte", px := 0.0022) -> Label3D:
	var l := Label3D.new()
	l.text = texte
	l.font = police(sorte)
	l.font_size = taille
	l.pixel_size = px
	l.modulate = couleur
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return l


## Un parchemin vieilli (variante 0..3) : texture avec transparence sur les bords déchirés.
static func parchemin(variante := 0) -> ImageTexture:
	variante = posmod(variante, 4)
	if _parchemins.has(variante):
		return _parchemins[variante]
	var w := 384
	var h := 320
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var gros := FastNoiseLite.new()
	gros.seed = 11 + variante * 7
	gros.frequency = 0.012
	var fin := FastNoiseLite.new()
	fin.seed = 31 + variante
	fin.frequency = 0.09
	var bord := FastNoiseLite.new()
	bord.seed = 53 + variante * 3
	bord.frequency = 0.035
	var clair := Color(0.88, 0.8, 0.62)
	var fonce := Color(0.7, 0.58, 0.4)
	var brule := Color(0.3, 0.18, 0.09)
	var rng := RandomNumberGenerator.new()
	rng.seed = 97 + variante
	var taches: Array = []
	for i in 4:
		taches.append([Vector2(rng.randf() * w, rng.randf() * h), rng.randf_range(14.0, 42.0)])
	for y in h:
		for x in w:
			var g := gros.get_noise_2d(x, y) * 0.5 + 0.5
			var c := clair.lerp(fonce, g * 0.75 + fin.get_noise_2d(x, y) * 0.12)
			for t: Array in taches:
				var d := (Vector2(x, y) - (t[0] as Vector2)).length() / float(t[1])
				if d < 1.0:
					c = c.lerp(fonce * 0.85, (1.0 - d) * 0.35)
			# Distance au bord, rongée par le bruit : roussi, puis brûlé, puis déchiré.
			var e := float(mini(mini(x, w - 1 - x), mini(y, h - 1 - y))) + bord.get_noise_2d(x, y) * 9.0
			var a := 1.0
			if e < 4.0:
				a = 0.0
			elif e < 9.0:
				c = brule
			elif e < 26.0:
				c = c.lerp(brule, pow(1.0 - (e - 9.0) / 17.0, 2.0) * 0.8)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_parchemins[variante] = tex
	return tex


## Le matériau d'un parchemin (bords déchirés découpés, jamais translucide).
static func materiau_parchemin(variante := 0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = parchemin(variante)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.roughness = 0.95
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
