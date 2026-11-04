class_name EcranSynchro
extends Control
## La scène de synchronisation, entre « Commencer » et la première phase : au milieu « La partie va
## commencer », derrière le village en plans lents (cf. SynchroVues, la caméra est pilotée par
## principal.gd), de chaque côté une astuce qui change toutes les 4,5 s, en bas qui est prêt.

const OR := Color(1.0, 0.82, 0.5)
const ROUGE := Color(0.85, 0.12, 0.08)
const CHANGER_S := 4.5
const FONDU_CARTE := 0.45

## Le temps écoulé depuis l'ouverture (secondes) : la caméra et les fondus en dépendent.
var temps := 0.0

var _fondu: ColorRect
var _titre: Label
var _sous_titre: Label
var _compte: Label
var _barre: ProgressBar
var _puces: HBoxContainer
var _cartes: Array = []        # [PanelContainer, IconeTuto, Label titre, Label texte]
var _decale := 0
var _signature := ""
var _ouverte := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_fondu = ColorRect.new()
	_fondu.color = Color.BLACK
	_fondu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fondu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fondu)
	# Un voile en haut et en bas : le texte reste lisible quel que soit le plan.
	for haut: bool in [true, false]:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(0, 0, 0, 0.7), Color(0, 0, 0, 0.0)])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill_from = Vector2(0.5, 0.0 if haut else 1.0)
		tex.fill_to = Vector2(0.5, 1.0 if haut else 0.0)
		tex.width = 4
		tex.height = 256
		var v := TextureRect.new()
		v.texture = tex
		v.stretch_mode = TextureRect.STRETCH_SCALE
		v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		v.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if haut else Control.PRESET_BOTTOM_WIDE)
		v.offset_top = 0.0 if haut else -260.0
		v.offset_bottom = 260.0 if haut else 0.0
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)

	var milieu := VBoxContainer.new()
	milieu.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	milieu.offset_top = 70
	milieu.alignment = BoxContainer.ALIGNMENT_CENTER
	milieu.add_theme_constant_override("separation", 6)
	milieu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(milieu)
	_titre = _label("LA PARTIE VA COMMENCER", 62, OR)
	_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	milieu.add_child(_titre)
	_sous_titre = _label("préparez-vous", 36, Color(1, 0.95, 0.85))
	_sous_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	milieu.add_child(_sous_titre)

	var bas := VBoxContainer.new()
	bas.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bas.offset_top = -190
	bas.offset_bottom = -26
	bas.alignment = BoxContainer.ALIGNMENT_END
	bas.add_theme_constant_override("separation", 10)
	bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bas)
	_compte = _label("", 26, Color(1, 1, 1, 0.92))
	_compte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bas.add_child(_compte)
	_barre = ProgressBar.new()
	_barre.custom_minimum_size = Vector2(420, 8)
	_barre.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_barre.show_percentage = false
	_barre.max_value = 1.0
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(1, 1, 1, 0.12)
	var plein := StyleBoxFlat.new()
	plein.bg_color = Color(0.85, 0.12, 0.08)
	_barre.add_theme_stylebox_override("background", fond)
	_barre.add_theme_stylebox_override("fill", plein)
	bas.add_child(_barre)
	_puces = HBoxContainer.new()
	_puces.alignment = BoxContainer.ALIGNMENT_CENTER
	_puces.add_theme_constant_override("separation", 10)
	_puces.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bas.add_child(_puces)

	for gauche: bool in [true, false]:
		_cartes.append(_construire_carte(gauche))


func _construire_carte(gauche: bool) -> Array:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.035, 0.04, 0.9)
	style.border_color = Color(0.6, 0.12, 0.08, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 16
	for cote in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + cote, 26)
	p.add_theme_stylebox_override("panel", style)
	p.custom_minimum_size = Vector2(360, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if gauche:
		p.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		p.grow_horizontal = Control.GROW_DIRECTION_END
		p.offset_left = 44
	else:
		p.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		p.offset_right = -44
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var icone := IconeTuto.new()
	icone.custom_minimum_size = Vector2(104, 104)
	icone.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(icone)
	var titre := _label("", 28, OR)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titre)
	var texte := _label("", 21, Color(1, 1, 1, 0.9))
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texte.custom_minimum_size.x = 306
	v.add_child(texte)
	return [p, icone, titre, texte]


func ouvrir() -> void:
	if _ouverte:
		return
	_ouverte = true
	temps = 0.0
	_decale = randi() % TutosSynchro.CARTES.size()
	_signature = ""
	_afficher_cartes(true)
	visible = true


func fermer() -> void:
	_ouverte = false
	visible = false


func ouverte() -> bool:
	return _ouverte


func _process(delta: float) -> void:
	if not _ouverte:
		return
	temps += delta
	_fondu.color.a = SynchroVues.fondu(temps)
	_afficher_cartes(false)


## Les deux cartes changent ensemble toutes les CHANGER_S ; un fondu les enrobe.
func _afficher_cartes(force: bool) -> void:
	var n: int = TutosSynchro.CARTES.size()
	var rang := int(temps / CHANGER_S)
	var local := fposmod(temps, CHANGER_S)
	var alpha := clampf(minf(local, CHANGER_S - local) / FONDU_CARTE, 0.0, 1.0)
	for k in _cartes.size():
		var c: Array = _cartes[k]
		(c[0] as Control).modulate.a = alpha
		var cle := "%d/%d" % [rang, k]
		if force or c[0].get_meta("cle", "") != cle:
			c[0].set_meta("cle", cle)
			var carte: Dictionary = TutosSynchro.CARTES[(_decale + rang * 2 + k * 5) % n]
			(c[1] as IconeTuto).regler(carte["icone"])
			(c[2] as Label).text = carte["titre"]
			(c[3] as Label).text = Options.avec_touches(carte["texte"])


## Qui est prêt : un compteur, une barre du minimum de 8 s, une puce par joueur.
func maj(pub: Dictionary) -> void:
	var s: Dictionary = pub.get("synchro", {})
	var attendus: Array = s.get("attendus", [])
	var prets: Array = s.get("prets", [])
	var humains: Dictionary = pub.get("humains", {})
	var sig := "%s|%s" % [str(attendus), str(prets)]
	if sig == _signature:
		return
	_signature = sig
	_compte.text = "Joueurs prêts  %d / %d" % [prets.size(), attendus.size()]
	for e in _puces.get_children():
		e.queue_free()
	for id in attendus:
		var pret := prets.has(id)
		var nom := str(humains.get(id, {}).get("nom", "?"))
		var puce := _label(("✔ " if pret else "… ") + nom, 19,
			Color(0.75, 0.95, 0.7) if pret else Color(1, 1, 1, 0.55))
		_puces.add_child(puce)


func _label(texte: String, taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## La barre avance avec le minimum de 8 s ; une fois plein, elle ne bouge plus (on attend les autres).
func _physics_process(_d: float) -> void:
	if _ouverte:
		_barre.value = clampf(temps / SynchroLancement.MIN_S, 0.0, 1.0)


## L'icône d'une carte : l'image de images/tutos/<id>.* si elle existe, sinon un dessin sobre en code.
class IconeTuto extends Control:
	var cle := ""
	var _image: Texture2D = null

	func regler(c: String) -> void:
		cle = c
		_image = TutosSynchro.image(c)
		queue_redraw()

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		var c := size * 0.5
		if _image != null:
			draw_texture_rect(_image, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
			return
		var or_ := Color(1.0, 0.82, 0.5)
		draw_circle(c, r, Color(0.12, 0.04, 0.04, 0.95))
		draw_arc(c, r - 2.0, 0, TAU, 48, Color(0.6, 0.12, 0.08), 3.0, true)
		var u := r / 50.0      # une unité de dessin = 1/50 du rayon
		match cle:
			"deplacer":
				for d: Array in [[0, -1, "Z"], [-1, 0, "Q"], [0, 0, "S"], [1, 0, "D"]]:
					var o := c + Vector2(d[0] * 26, d[1] * 26 + 12) * u * 0.9
					var rect := Rect2(o - Vector2(11, 11) * u, Vector2(22, 22) * u)
					draw_rect(rect, Color(1, 1, 1, 0.12))
					draw_rect(rect, or_, false, 2.0)
					draw_string(ThemeDB.fallback_font, o + Vector2(-5.5, 6.0) * u, d[2], HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * u), or_)
			"agir":
				draw_rect(Rect2(c + Vector2(-16, -28) * u, Vector2(32, 56) * u), or_, false, 3.0)
				draw_circle(c + Vector2(8, 2) * u, 3.0 * u, or_)
			"voix":
				draw_rect(Rect2(c + Vector2(-26, -8) * u, Vector2(12, 16) * u), or_)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-14, -8) * u, c + Vector2(0, -22) * u, c + Vector2(0, 22) * u, c + Vector2(-14, 8) * u]), or_)
				for k in 3:
					draw_arc(c + Vector2(2, 0) * u, (12 + k * 9) * u, -0.9, 0.9, 12, or_, 2.5, true)
			"carnet":
				draw_rect(Rect2(c + Vector2(-22, -28) * u, Vector2(44, 56) * u), or_, false, 3.0)
				for k in 4:
					draw_line(c + Vector2(-12, -14 + k * 11) * u, c + Vector2(12, -14 + k * 11) * u, or_, 2.0)
			"gestes":
				draw_circle(c + Vector2(0, -22) * u, 7 * u, or_)
				draw_line(c + Vector2(0, -14) * u, c + Vector2(0, 10) * u, or_, 3.0)
				draw_line(c + Vector2(0, -8) * u, c + Vector2(-20, -24) * u, or_, 3.0)
				draw_line(c + Vector2(0, -8) * u, c + Vector2(20, -24) * u, or_, 3.0)
				draw_line(c + Vector2(0, 10) * u, c + Vector2(-12, 30) * u, or_, 3.0)
				draw_line(c + Vector2(0, 10) * u, c + Vector2(12, 30) * u, or_, 3.0)
			"quetes":
				draw_rect(Rect2(c + Vector2(-26, -22) * u, Vector2(52, 44) * u), or_, false, 3.0)
				for k in 3:
					draw_line(c + Vector2(-16, -10 + k * 11) * u, c + Vector2(16, -10 + k * 11) * u, or_, 2.0)
				draw_circle(c + Vector2(20, 20) * u, 8 * u, Color(0.85, 0.12, 0.08))
			"nuit":
				draw_circle(c, 26 * u, or_)
				draw_circle(c + Vector2(11, -6) * u, 23 * u, Color(0.12, 0.04, 0.04))
				draw_circle(c + Vector2(26, -26) * u, 2.5 * u, or_)
				draw_circle(c + Vector2(30, 12) * u, 2.0 * u, or_)
			"pret":
				draw_polyline(PackedVector2Array([c + Vector2(-22, 2) * u, c + Vector2(-6, 18) * u, c + Vector2(24, -18) * u]), or_, 6.0, true)
			"volumes":
				for k in 3:
					var x := (-20 + k * 20) * u
					draw_line(c + Vector2(x, -26 * u), c + Vector2(x, 26 * u), Color(1, 1, 1, 0.3), 3.0)
					draw_circle(c + Vector2(x, (-10 + k * 12) * u), 6 * u, or_)
			"fantome":
				draw_circle(c + Vector2(0, -6) * u, 20 * u, Color(0.9, 0.9, 0.95))
				draw_rect(Rect2(c + Vector2(-20, -6) * u, Vector2(40, 26) * u), Color(0.9, 0.9, 0.95))
				for k in 3:
					draw_circle(c + Vector2(-13 + k * 13, 20) * u, 6.5 * u, Color(0.9, 0.9, 0.95))
				draw_circle(c + Vector2(-7, -8) * u, 3.5 * u, Color(0.1, 0.05, 0.05))
				draw_circle(c + Vector2(7, -8) * u, 3.5 * u, Color(0.1, 0.05, 0.05))
			_:
				draw_string(ThemeDB.fallback_font, c + Vector2(-9, 14) * u, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(44 * u), or_)
