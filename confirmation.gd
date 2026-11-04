class_name Confirmation
extends CanvasLayer
## Une boîte « Oui / Non » posée au-dessus de tout (Edwin, 01/11 : éviter la fausse manip en quittant
## le jeu ou en revenant au menu). Échap = Non ; le bouton « Non » a le focus (Entrée ne quitte pas).

static var ouverte := false

var _sur_oui: Callable
var _non: Button


## Ouvre la boîte (sans effet si une autre est déjà ouverte). `sur_oui` n'est appelé que sur « Oui ».
static func demander(parent: Node, texte: String, sur_oui: Callable) -> Confirmation:
	if ouverte:
		return null
	var c := Confirmation.new()
	c._sur_oui = sur_oui
	c.layer = 120
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(c)
	c._construire(texte)
	ouverte = true
	return c


func _construire(texte: String) -> void:
	var fond := ColorRect.new()
	fond.color = Color(0, 0, 0, 0.62)
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var cadre := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.035, 0.04, 0.96)
	st.border_color = Color(0.6, 0.12, 0.08, 0.85)
	st.set_border_width_all(2)
	st.set_corner_radius_all(6)
	for cote in ["left", "right", "top", "bottom"]:
		st.set("content_margin_" + cote, 30)
	cadre.add_theme_stylebox_override("panel", st)
	cadre.set_anchors_preset(Control.PRESET_CENTER)
	cadre.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cadre.grow_vertical = Control.GROW_DIRECTION_BOTH
	fond.add_child(cadre)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	cadre.add_child(v)
	var l := Label.new()
	l.text = Langue.t(texte)
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 520
	v.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 24)
	v.add_child(h)
	var oui := Button.new()
	oui.name = "Oui"
	oui.text = Langue.t("Oui")
	oui.custom_minimum_size = Vector2(150, 48)
	oui.add_theme_font_size_override("font_size", 24)
	oui.pressed.connect(_oui)
	h.add_child(oui)
	_non = Button.new()
	_non.name = "Non"
	_non.text = Langue.t("Non")
	_non.custom_minimum_size = Vector2(150, 48)
	_non.add_theme_font_size_override("font_size", 24)
	_non.pressed.connect(_fermer)
	h.add_child(_non)
	_non.grab_focus()


func _input(ev: InputEvent) -> void:
	# Tant que la boîte est là, plus rien d'autre ne reçoit de touche (Échap = Non, pas la pause).
	if ev is InputEventKey and ev.pressed:
		if ev.keycode == KEY_ESCAPE:
			_fermer()
			get_viewport().set_input_as_handled()
		elif not ev.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_TAB]:
			get_viewport().set_input_as_handled()


func _oui() -> void:
	var a := _sur_oui
	_fermer()
	if a.is_valid():
		a.call()


func _fermer() -> void:
	ouverte = false
	queue_free()


func _exit_tree() -> void:
	ouverte = false
