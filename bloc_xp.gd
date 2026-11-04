class_name BlocXp
extends PanelContainer
## Le petit bloc de l'écran de fin : « +130 XP · niveau 7 », la barre, les succès et les cosmétiques
## gagnés. C'est un bloc À PART, posé en bas à gauche de l'écran (l'écran de fin ne le connaît pas) :
## il n'est visible que tant que l'écran de fin l'est.

const OR := Color(0.92, 0.74, 0.38)
const ENCRE := Color(0.93, 0.86, 0.74)
const VERT := Color(0.6, 0.9, 0.6)


## Pose le bloc sur `ecran` (le Control plein écran du jeu) à partir du compte rendu de
## Progres.enregistrer_partie. Remplace celui de la partie d'avant.
static func poser(ecran: Control, rapport: Dictionary) -> BlocXp:
	var ancien := ecran.get_node_or_null("BlocXp")
	if ancien:
		ancien.queue_free()
	var b := BlocXp.new()
	b.name = "BlocXp"
	ecran.add_child(b)
	b.construire(rapport)
	return b


func construire(r: Dictionary) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.028, 0.032, 0.93)
	s.border_color = Color(0.72, 0.55, 0.3, 0.8)
	s.set_border_width_all(1)
	s.border_width_left = 4
	s.set_corner_radius_all(4)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 14
	add_theme_stylebox_override("panel", s)
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = 24
	offset_bottom = -24
	custom_minimum_size.x = 330
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	var monte: bool = int(r["niveau_apres"]) > int(r["niveau_avant"])
	v.add_child(_l("+%d XP" % int(r["xp_gagnee"]), 30, OR, "titre"))
	v.add_child(_l(("Niveau %d  ·  tu montes !" if monte else "Niveau %d") % int(r["niveau_apres"]), 20, VERT if monte else ENCRE, "titre"))
	var barre := ProgressBar.new()
	var b: Dictionary = r["barre"]
	barre.show_percentage = false
	barre.min_value = 0.0
	barre.max_value = 1.0
	barre.value = float(b["ratio"])
	barre.custom_minimum_size = Vector2(0, 10)
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(1, 1, 1, 0.1)
	fond.set_corner_radius_all(5)
	var plein := StyleBoxFlat.new()
	plein.bg_color = OR
	plein.set_corner_radius_all(5)
	barre.add_theme_stylebox_override("background", fond)
	barre.add_theme_stylebox_override("fill", plein)
	v.add_child(barre)
	if int(b["pour"]) > 0:
		v.add_child(_l("%d / %d vers le niveau %d" % [int(b["dans"]), int(b["pour"]), int(b["niveau"]) + 1], 15, Color(ENCRE, 0.7)))
	for ligne: Array in r["detail"]:
		v.add_child(_l("%s   +%d" % [Langue.t(str(ligne[0])), int(ligne[1])], 15, Color(ENCRE, 0.8)))
	for id: String in r["succes"]:
		v.add_child(_l("Succès : %s" % Succes.nom(id), 17, OR, "titre"))
	for id: String in r["articles"]:
		v.add_child(_l("Offert : %s" % Cosmetiques.article(id).get("nom", id), 17, VERT, "titre"))


func _process(_delta: float) -> void:
	var p := get_parent()
	if p and p.has_method("fin_visible"):
		visible = p.fin_visible()


func _l(texte: String, taille: int, couleur: Color, sorte := "texte") -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_override("font", Style.police(sorte))
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
