class_name EcranDemarrage
extends Control
## L'écran de démarrage de Nuit Blanche : l'image du lancement (images/splash.png, la même que celle
## montrée par Godot à l'ouverture, pour que rien ne saute : il apparaît d'un coup, sans fondu), une brume qui dérive, la lune qui
## respire, et en bas une ligne d'état avec sa barre. La mise à jour (mise_a_jour.gd) y écrit ce
## qu'elle fait ; la scène du jeu se construit dessous.

const FOND := Color(0.027, 0.035, 0.07)
const OR := Color(0.93, 0.78, 0.45)
const PARCHEMIN := Color(0.82, 0.77, 0.68)
## Position de la lune dans l'image 1920 x 1080.
const LUNE := Vector2(1580, 300)

var _image: TextureRect
var _decor: Control
var _statut: Label
var _detail: Label
var _barre: ProgressBar
var _bas: VBoxContainer
var _halo: Texture2D
var _brume: Array = []            # [x (0..1), y (0..1), taille, vitesse, alpha, phase]
var _t := 0.0
var _fini := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fond := ColorRect.new()
	fond.color = FOND
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fond)
	_image = TextureRect.new()
	_image.texture = load("res://images/splash.png") as Texture2D
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image)
	_decor = Control.new()
	_decor.set_anchors_preset(Control.PRESET_FULL_RECT)
	_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_decor.draw.connect(_dessiner)
	add_child(_decor)

	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	_halo = gt
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for i in 9:
		_brume.append([rng.randf(), 0.62 + rng.randf() * 0.34, 0.5 + rng.randf() * 0.55, (0.004 + rng.randf() * 0.01) * (1.0 if i % 2 == 0 else -1.0), 0.05 + rng.randf() * 0.07, rng.randf() * TAU])

	_bas = VBoxContainer.new()
	_bas.anchor_left = 0.5
	_bas.anchor_right = 0.5
	_bas.anchor_top = 1.0
	_bas.anchor_bottom = 1.0
	_bas.offset_left = -320
	_bas.offset_right = 320
	_bas.offset_top = -118
	_bas.offset_bottom = -38
	_bas.add_theme_constant_override("separation", 10)
	_bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bas)
	_statut = _etiquette(23, PARCHEMIN)
	_bas.add_child(_statut)
	_barre = ProgressBar.new()
	_barre.custom_minimum_size = Vector2(0, 7)
	_barre.show_percentage = false
	_barre.max_value = 100.0
	var vide := StyleBoxFlat.new()
	vide.bg_color = Color(0.04, 0.05, 0.09, 0.85)
	vide.border_color = Color(0.45, 0.34, 0.18, 0.7)
	vide.set_border_width_all(1)
	vide.set_corner_radius_all(4)
	var plein := StyleBoxFlat.new()
	plein.bg_color = Color(0.9, 0.7, 0.34)
	plein.set_corner_radius_all(4)
	_barre.add_theme_stylebox_override("background", vide)
	_barre.add_theme_stylebox_override("fill", plein)
	_barre.visible = false
	_bas.add_child(_barre)
	_detail = _etiquette(17, Color(PARCHEMIN, 0.65))
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.visible = false
	_bas.add_child(_detail)


func _etiquette(taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## La ligne d'état.
func statut(texte: String) -> void:
	_statut.text = texte


## La barre : valeur 0..100, ou null pour la cacher.
func progres(valeur: Variant) -> void:
	_barre.visible = valeur != null
	if valeur != null:
		_barre.value = float(valeur)


## Une ligne plus discrète sous la barre ("" la cache).
func detail(texte: String) -> void:
	_detail.text = texte
	_detail.visible = texte != ""


## La mise à jour a échoué : on le dit, et on propose de quitter.
func echec(titre: String, texte: String) -> void:
	statut(titre)
	progres(null)
	detail(texte)
	var bouton := Button.new()
	bouton.text = "Quitter"
	bouton.focus_mode = Control.FOCUS_NONE
	bouton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bouton.pressed.connect(func(): get_tree().quit())
	_bas.add_child(bouton)


## Le fondu de sortie, puis l'écran disparaît.
func finir() -> void:
	if _fini:
		return
	_fini = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	_decor.queue_redraw()


func _dessiner() -> void:
	var d := _decor.size
	if d.x < 1.0 or _image.texture == null:
		return
	var e := maxf(d.x / 1920.0, d.y / 1080.0)
	var decal := (d - Vector2(1920, 1080) * e) * 0.5
	# La lune respire : un halo pâle qui gonfle et se retire.
	var respire := 0.5 + 0.5 * sin(_t * 0.9)
	var lune := decal + LUNE * e
	var ra := (330.0 + respire * 50.0) * e
	_decor.draw_texture_rect(_halo, Rect2(lune - Vector2(ra, ra), Vector2(ra, ra) * 2.0), false, Color(0.55, 0.62, 0.95, 0.16 + respire * 0.1))
	# La brume : de grands voiles qui glissent lentement devant le village.
	for b: Array in _brume:
		var x: float = fposmod(b[0] + _t * b[3] + 0.2, 1.4) - 0.2
		var larg: float = 760.0 * b[2] * e
		var haut: float = 150.0 * b[2] * e
		var y: float = d.y * b[1] + sin(_t * 0.3 + b[5]) * 12.0 * e
		var a: float = b[4] * (0.75 + 0.25 * sin(_t * 0.5 + b[5]))
		_decor.draw_texture_rect(_halo, Rect2(Vector2(x * d.x - larg * 0.5, y - haut * 0.5), Vector2(larg, haut)), false, Color(0.62, 0.7, 0.9, a))
	# Quelques étoiles qui scintillent.
	for k in 26:
		var u := fposmod(sin(k * 91.7) * 43758.5, 1.0)
		var v := fposmod(sin(k * 12.9 + 4.0) * 24634.6, 1.0)
		var clair := 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * (1.0 + fposmod(k * 0.37, 1.7)) + k))
		var p := Vector2(u * 1920.0, v * 560.0)
		if Rect2(90, 310, 1090, 310).has_point(p) or p.distance_to(LUNE) < 140.0:
			continue   # ni sur le titre, ni sur la lune
		_decor.draw_circle(decal + p * e, 1.6 * e, Color(1, 0.97, 0.88, clair * 0.8))
