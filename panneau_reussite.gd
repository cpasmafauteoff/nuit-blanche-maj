class_name PanneauReussite
extends Control
## Une réussite à la bougie, pour passer la nuit dans sa chambre (décision d'Edwin, 29/10).
## Le « golf » : sept colonnes de cinq cartes. On prend la carte du bas d'une colonne si elle
## vaut une de plus ou une de moins que la carte du talon (l'as ne suit pas le roi). Quand rien
## ne va, on pioche. Toutes les colonnes vidées : gagné.

signal ferme

const COULEURS := ["♠", "♥", "♦", "♣"]
const VALEURS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "V", "D", "R"]

var _colonnes: Array = []     # 7 × [cartes] ; une carte = [valeur 0..12, couleur 0..3]
var _pioche: Array = []
var _talon: Array = []
var _rng := RandomNumberGenerator.new()
var _grille: HBoxContainer
var _carte_talon: Button
var _bouton_pioche: Button
var _etat: Label


func _ready() -> void:
	_rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fond := ColorRect.new()
	fond.color = Color(0, 0, 0, 0.55)
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var cadre := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.13, 0.2, 0.12)
	st.border_color = Color(0.45, 0.32, 0.18)
	st.set_border_width_all(6)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(18)
	cadre.add_theme_stylebox_override("panel", st)
	cadre.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cadre.custom_minimum_size = Vector2(760, 460)
	cadre.position -= cadre.custom_minimum_size * 0.5
	add_child(cadre)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	cadre.add_child(v)
	var titre := Label.new()
	titre.text = "Une réussite, à la bougie"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 26)
	titre.add_theme_color_override("font_color", Color(0.93, 0.86, 0.7))
	v.add_child(titre)
	var regle := Label.new()
	regle.text = "Prends la carte du bas d'une colonne si elle vaut une de plus ou une de moins que celle du talon. Sinon, pioche."
	regle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	regle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	regle.add_theme_color_override("font_color", Color(0.8, 0.76, 0.66))
	v.add_child(regle)
	_grille = HBoxContainer.new()
	_grille.alignment = BoxContainer.ALIGNMENT_CENTER
	_grille.add_theme_constant_override("separation", 10)
	_grille.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_grille)
	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	bas.add_theme_constant_override("separation", 18)
	v.add_child(bas)
	_bouton_pioche = Button.new()
	_bouton_pioche.custom_minimum_size = Vector2(110, 70)
	_bouton_pioche.pressed.connect(_piocher)
	bas.add_child(_bouton_pioche)
	_carte_talon = Button.new()
	_carte_talon.custom_minimum_size = Vector2(70, 92)
	_carte_talon.disabled = true
	bas.add_child(_carte_talon)
	_etat = Label.new()
	_etat.custom_minimum_size = Vector2(220, 0)
	_etat.add_theme_color_override("font_color", Color(0.9, 0.84, 0.68))
	bas.add_child(_etat)
	var nouvelle := Button.new()
	nouvelle.text = "Nouvelle donne"
	nouvelle.pressed.connect(_donner)
	bas.add_child(nouvelle)
	var fermer := Button.new()
	fermer.text = "Ranger les cartes (Échap)"
	fermer.pressed.connect(fermer_panneau)
	bas.add_child(fermer)
	_donner()


func _unhandled_input(ev: InputEvent) -> void:
	if visible and ev is InputEventKey and ev.pressed and (ev as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		fermer_panneau()


func fermer_panneau() -> void:
	ferme.emit()
	queue_free()


func _donner() -> void:
	var paquet := []
	for c in 4:
		for val in 13:
			paquet.append([val, c])
	for i in range(paquet.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var x = paquet[i]
		paquet[i] = paquet[j]
		paquet[j] = x
	_colonnes.clear()
	for k in 7:
		_colonnes.append(paquet.slice(k * 5, k * 5 + 5))
	_talon = [paquet[35]]
	_pioche = paquet.slice(36)
	_redessiner()


func _texte(c: Array) -> String:
	return "%s%s" % [VALEURS[c[0]], COULEURS[c[1]]]


func _peut_prendre(c: Array) -> bool:
	return absi(int(c[0]) - int(_talon.back()[0])) == 1


func _prendre(k: int) -> void:
	var col: Array = _colonnes[k]
	if col.is_empty() or not _peut_prendre(col.back()):
		return
	_talon.append(col.pop_back())
	_redessiner()


func _piocher() -> void:
	if _pioche.is_empty():
		return
	_talon.append(_pioche.pop_back())
	_redessiner()


func _redessiner() -> void:
	for e in _grille.get_children():
		e.queue_free()
	var restantes := 0
	var jouables := 0
	for k in 7:
		var col: Array = _colonnes[k]
		restantes += col.size()
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -54)
		_grille.add_child(v)
		for n in col.size():
			var c: Array = col[n]
			var b := Button.new()
			b.custom_minimum_size = Vector2(70, 92)
			b.text = _texte(c)
			b.add_theme_font_size_override("font_size", 20)
			var rouge: bool = c[1] in [1, 2]
			b.add_theme_color_override("font_color", Color(0.75, 0.08, 0.06) if rouge else Color(0.08, 0.07, 0.07))
			b.add_theme_color_override("font_disabled_color", Color(0.55, 0.2, 0.18) if rouge else Color(0.3, 0.28, 0.26))
			var st := StyleBoxFlat.new()
			st.bg_color = Color(0.94, 0.9, 0.8)
			st.set_corner_radius_all(6)
			st.border_color = Color(0.3, 0.22, 0.14)
			st.set_border_width_all(2)
			st.content_margin_top = 4
			st.content_margin_bottom = 0 if n == col.size() - 1 else 58
			b.add_theme_stylebox_override("normal", st)
			b.add_theme_stylebox_override("disabled", st)
			var st2 := st.duplicate() as StyleBoxFlat
			st2.border_color = Color(0.85, 0.6, 0.15)
			st2.set_border_width_all(4)
			b.add_theme_stylebox_override("hover", st2)
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			var dessous := n == col.size() - 1
			b.disabled = not dessous or not _peut_prendre(c)
			if dessous and _peut_prendre(c):
				jouables += 1
			var kk := k
			b.pressed.connect(func(): _prendre(kk))
			v.add_child(b)
	_carte_talon.text = _texte(_talon.back())
	_carte_talon.add_theme_font_size_override("font_size", 22)
	_bouton_pioche.text = "Piocher\n(%d)" % _pioche.size()
	_bouton_pioche.disabled = _pioche.is_empty()
	if restantes == 0:
		_etat.text = "Gagné ! Toutes les colonnes sont vides."
	elif jouables == 0 and _pioche.is_empty():
		_etat.text = "Perdu : il reste %d cartes." % restantes
	else:
		_etat.text = "Il reste %d cartes." % restantes
