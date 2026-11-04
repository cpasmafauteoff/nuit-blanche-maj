class_name SuccesUi
extends VBoxContainer
## L'écran « Succès » du menu : la liste des succès, ceux déjà gagnés en couleur, les autres grisés.
## Tout vient de Succes (liste) et Progres (ce qui est gagné) ; les icônes sont dans images/succes/.

const OR := Color(0.92, 0.74, 0.38)
const ENCRE := Color(0.93, 0.86, 0.74)

var _compte: Label
var _grille: GridContainer


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_compte = Label.new()
	_compte.add_theme_font_override("font", Style.police("italique"))
	_compte.add_theme_font_size_override("font_size", 22)
	_compte.add_theme_color_override("font_color", OR)
	add_child(_compte)
	var defile := ScrollContainer.new()
	defile.custom_minimum_size = Vector2(1180, 520)
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(defile)
	_grille = GridContainer.new()
	_grille.columns = 2
	_grille.add_theme_constant_override("h_separation", 16)
	_grille.add_theme_constant_override("v_separation", 10)
	defile.add_child(_grille)


func rafraichir() -> void:
	for e in _grille.get_children():
		e.queue_free()
	var gagnes := Progres.succes_gagnes()
	_compte.text = "%d succès sur %d" % [gagnes.size(), Succes.LISTE.size()]
	# Les gagnés d'abord (les plus récents en tête), puis les autres dans l'ordre de la liste.
	var ids: Array = Array(Succes.ids())
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ga := gagnes.has(a)
		var gb := gagnes.has(b)
		if ga != gb:
			return ga
		return ga and int(gagnes[a]) > int(gagnes[b]))
	for id: String in ids:
		_grille.add_child(_ligne(id, gagnes.has(id)))


func _ligne(id: String, gagne: bool) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(580, 84)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.06, 0.05, 0.9) if gagne else Color(0.06, 0.05, 0.05, 0.85)
	s.border_color = Color(OR, 0.7) if gagne else Color(1, 1, 1, 0.12)
	s.set_border_width_all(1)
	s.border_width_left = 4
	s.set_corner_radius_all(4)
	s.content_margin_left = 10
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", s)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var chemin := "res://images/succes/%s%s.png" % [id.to_lower(), "" if gagne else "_verrouille"]
	if ResourceLoader.exists(chemin):
		var t := TextureRect.new()
		t.texture = load(chemin)
		t.custom_minimum_size = Vector2(64, 64)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(t)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	v.add_child(_l(Succes.nom(id), 22, ENCRE if gagne else Color(ENCRE, 0.5), "titre"))
	var d := _l(Succes.description(id), 16, Color(ENCRE, 0.8 if gagne else 0.45))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	return p


func _l(texte: String, taille: int, couleur: Color, sorte := "texte") -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_override("font", Style.police(sorte))
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	return l
