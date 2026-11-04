class_name PanneauCarnet
extends PanelContainer
## Lire et écrire le carnet (ou la page) qu'on tient : une couverture de cuir cousue, une feuille de
## papier crème réglée, la plume, l'encre sombre, page par page. Déchirer la page en cours la met
## dans l'autre main.

## (type, a, b) -> envoie une intention à l'hôte.
var envoyer: Callable
## (maison) -> [pseudo, bandeau] : à qui est ce carnet (ou d'où vient cette page).
var proprietaire: Callable
## () -> Array[String] : les pseudos des joueurs de la partie (pour le sélecteur de la page des bandeaux).
var joueurs: Callable
## On tape au clavier : le stylo écrit (l'hôte le montre aux autres).
signal tape
## La plume se pose (true) ou se lève (false) : principal montre ou cache le curseur de la souris.
signal ecriture_changee(oui: bool)
## On lit : vrai tant que le carnet est affiché. `ecriture` : la plume est posée, on tape au clavier.
var ecriture := false
var _bandeaux := false          # ce carnet a sa première page « Les bandeaux »

var _id := -1
var _sorte := ""
var _page := 0
var _nb_pages := 1
var _texte_envoye := ""
var _brouillon := {}            # page -> texte envoyé, en attendant l'écho de l'hôte
var _titre: Label
var _qui: HBoxContainer
var _pastille: ColorRect
var _qui_texte: Label
var _numero: Label
var _ecrit: TextEdit
var _avant: Button
var _apres: Button
var _dechirer: Button
var _stylo_2d: Stylo2D
var _lignes: Lignes
var _selecteur: HBoxContainer    # la page des bandeaux, plume posée : lignes cliquables + liste des joueurs
var _sel_lignes: VBoxContainer
var _sel_joueurs: VBoxContainer
var _sel_aide: Label
var _sel := -1                   # la ligne choisie (pour inverser, ou choisir son pseudo dans la liste)
var _riche: RichTextLabel       # la page des bandeaux, en lecture : pastilles de couleur
var _bas: HBoxContainer
var _aide: Label
var _police: Font
var _taille := 25
var _espace := 0


## La plume d'oie qui suit le curseur d'écriture et gribouille quand on tape (posée, elle attend).
class Stylo2D extends Control:
	var _t := 0.0
	var _ecrit_t := 0.0

	func ecrire() -> void:
		_ecrit_t = 0.45

	func _process(delta: float) -> void:
		_t += delta
		_ecrit_t = maxf(_ecrit_t - delta, 0.0)
		queue_redraw()

	func _draw() -> void:
		var te := get_parent() as TextEdit
		if te == null:
			return
		var pointe := te.get_caret_draw_pos() + Vector2(6, 3)
		if _ecrit_t > 0.0:
			pointe += Vector2(sin(_t * 38.0) * 3.0, cos(_t * 52.0) * 2.0)
		else:
			pointe += Vector2(0, sin(_t * 2.0) * 1.2)
		var dir := Vector2(0.5, -0.866)
		var nor := Vector2(-dir.y, dir.x)
		# L'ombre de la plume sur le papier.
		draw_line(pointe + Vector2(5, 4) + dir * 6.0, pointe + Vector2(5, 4) + dir * 100.0, Color(0.1, 0.05, 0.02, 0.18), 6.0, true)
		# Les barbes : deux ailes en ellipse, la tige au milieu.
		for cote in [-1.0, 1.0]:
			var pts := PackedVector2Array()
			for i in 21:
				var u := float(i) / 20.0
				var largeur := sin(u * PI) * (17.0 if cote < 0.0 else 14.0) * (1.0 - u * 0.25)
				pts.append(pointe + dir * (46.0 + u * 66.0) + nor * cote * largeur)
			pts.append(pointe + dir * 46.0)
			draw_colored_polygon(pts, Color(0.92, 0.88, 0.79) if cote < 0.0 else Color(0.84, 0.79, 0.69))
			draw_polyline(pts, Color(0.35, 0.28, 0.22, 0.55), 1.0, true)
			for i in range(2, 19, 2):
				var u := float(i) / 20.0
				var base := pointe + dir * (46.0 + u * 66.0)
				draw_line(base, base + nor * cote * sin(u * PI) * (16.0 if cote < 0.0 else 13.0) + dir * 5.0, Color(0.4, 0.32, 0.25, 0.25), 1.0, true)
		draw_line(pointe + dir * 14.0, pointe + dir * 114.0, Color(0.55, 0.48, 0.4), 2.0, true)
		# Le tuyau et la pointe trempée d'encre.
		draw_line(pointe + dir * 3.0, pointe + dir * 52.0, Color(0.94, 0.9, 0.8), 4.0, true)
		draw_line(pointe, pointe + dir * 11.0, Color(0.08, 0.04, 0.04), 3.0, true)
		if _ecrit_t > 0.0:
			draw_circle(pointe + Vector2(0, 1), 1.8, Color(0.08, 0.05, 0.05, 0.9))


## Le fond de la page : une pile de feuilles dont la tranche dépasse, la feuille de papier crème,
## l'ombre du pli côté reliure.
class Feuille extends MarginContainer:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		for k in range(4, 0, -1):
			draw_rect(Rect2(Vector2(k * 2.0, k * 2.0), size), Color(0.62 - k * 0.03, 0.53 - k * 0.03, 0.38 - k * 0.03))
			draw_rect(Rect2(Vector2(k * 2.0, k * 2.0), size), Color(0.1, 0.06, 0.03, 0.35), false, 1.0)
		draw_texture_rect(StyleCarnet.papier(false, 0), r, false)
		for i in 18:
			draw_rect(Rect2(i, 0, 1, size.y), Color(0.2, 0.12, 0.05, 0.2 * pow(1.0 - i / 18.0, 2.0)))
		draw_rect(r, Color(0.25, 0.15, 0.07, 0.6), false, 1.0)


## Les lignes de l'écriture : discrètes, calées sur les lignes du texte.
class Lignes extends Control:
	var pas := 34.0
	var decal := 0.0

	func _draw() -> void:
		var y := pas + decal
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.38, 0.27, 0.17, 0.3), 1.0)
			y += pas


## La couverture : points de couture, filet doré, coins de laiton, sangle et fermoir.
class Ornements extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var dore := Color(0.86, 0.66, 0.3)
		draw_rect(r.grow(-1.5), Color(0.04, 0.02, 0.01, 0.9), false, 3.0)
		draw_rect(r.grow(-13), Color(dore, 0.55), false, 1.5)
		var c := r.grow(-8)
		var pts := [c.position, Vector2(c.end.x, c.position.y), c.end, Vector2(c.position.x, c.end.y)]
		for i in 4:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % 4]
			var n := int(a.distance_to(b) / 9.0)
			for k in range(1, n):
				draw_circle(a.lerp(b, float(k) / n), 1.3, Color(0.9, 0.78, 0.55, 0.65))
		for sx in [0.0, 1.0]:
			for sy in [0.0, 1.0]:
				var o := Vector2(sx * size.x, sy * size.y)
				var ex := Vector2(1.0 if sx < 0.5 else -1.0, 1.0 if sy < 0.5 else -1.0)
				var tri := PackedVector2Array([o, o + Vector2(ex.x * 34.0, 0), o + Vector2(ex.x * 8.0, ex.y * 8.0), o + Vector2(0, ex.y * 34.0)])
				draw_colored_polygon(tri, Color(0.62, 0.45, 0.18))
				draw_polyline(PackedVector2Array([tri[1], tri[2], tri[3]]), Color(0.95, 0.8, 0.45), 1.5, true)
				draw_circle(o + ex * 10.0, 2.6, Color(0.98, 0.86, 0.52))
		var y := size.y * 0.5
		draw_rect(Rect2(size.x - 40, y - 15, 40, 30), Color(0.14, 0.07, 0.03))
		draw_rect(Rect2(size.x - 40, y - 15, 40, 30), Color(dore, 0.4), false, 1.0)
		draw_rect(Rect2(size.x - 30, y - 11, 14, 22), dore, false, 3.0)
		draw_line(Vector2(size.x - 30, y), Vector2(size.x - 10, y), dore, 2.0)


func _init() -> void:
	var style := StyleBoxTexture.new()
	style.texture = StyleCarnet.cuir()
	style.set_texture_margin_all(24)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.content_margin_left = 44
	style.content_margin_right = 58
	style.content_margin_top = 36
	style.content_margin_bottom = 40
	style.modulate_color = Color(0.78, 0.7, 0.66)
	add_theme_stylebox_override("panel", style)
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var encre := StyleCarnet.ENCRE
	var police_ecrit := Style.police("italique")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	_titre = Label.new()
	_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titre.add_theme_font_override("font", Style.police("titre"))
	_titre.add_theme_font_size_override("font_size", 28)
	_titre.add_theme_color_override("font_color", Color(0.96, 0.8, 0.46))
	_titre.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_titre.add_theme_constant_override("shadow_offset_x", 1)
	_titre.add_theme_constant_override("shadow_offset_y", 2)
	v.add_child(_titre)
	_qui = HBoxContainer.new()
	_qui.alignment = BoxContainer.ALIGNMENT_CENTER
	_qui.add_theme_constant_override("separation", 8)
	_pastille = ColorRect.new()
	_pastille.custom_minimum_size = Vector2(30, 10)
	_pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_qui.add_child(_pastille)
	_qui_texte = Label.new()
	_qui_texte.add_theme_font_override("font", Style.police("italique"))
	_qui_texte.add_theme_font_size_override("font_size", 18)
	_qui_texte.add_theme_color_override("font_color", Color(0.85, 0.74, 0.55))
	_qui.add_child(_qui_texte)
	v.add_child(_qui)
	# La feuille : papier, lignes, écriture.
	var feuille := Feuille.new()
	feuille.add_theme_constant_override("margin_left", 34)
	feuille.add_theme_constant_override("margin_right", 24)
	feuille.add_theme_constant_override("margin_top", 20)
	feuille.add_theme_constant_override("margin_bottom", 14)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 4)
	feuille.add_child(pv)
	var zone := Control.new()
	zone.custom_minimum_size = Vector2(570, 340)
	zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(zone)
	var lignes := Lignes.new()
	_lignes = lignes
	lignes.set_anchors_preset(Control.PRESET_FULL_RECT)
	lignes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(lignes)
	_ecrit = TextEdit.new()
	_ecrit.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ecrit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_ecrit.placeholder_text = Langue.t("Page vierge. Écris ce que tu veux laisser…")
	var taille := 25
	_ecrit.add_theme_font_override("font", police_ecrit)
	_ecrit.add_theme_font_size_override("font_size", taille)
	_police = police_ecrit
	_ecrit.context_menu_enabled = false   # le clic droit pose la plume, il n'ouvre pas un menu
	_mettre_taille(25)
	_ecrit.add_theme_color_override("font_color", encre)
	_ecrit.add_theme_color_override("font_placeholder_color", Color(encre, 0.42))
	_ecrit.add_theme_color_override("caret_color", Color(0.4, 0.1, 0.06))
	_ecrit.add_theme_color_override("selection_color", Color(0.75, 0.55, 0.25, 0.4))
	var fond := StyleBoxEmpty.new()
	fond.content_margin_left = 6
	fond.content_margin_right = 6
	fond.content_margin_top = 4
	_ecrit.add_theme_stylebox_override("normal", fond)
	_ecrit.add_theme_stylebox_override("focus", fond)
	_ecrit.add_theme_stylebox_override("read_only", fond)
	_stylo_2d = Stylo2D.new()
	_stylo_2d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ecrit.add_child(_stylo_2d)
	_ecrit.text_changed.connect(func():
		_stylo_2d.ecrire()
		tape.emit()
		if _ecrit.text.length() > Objets.MAX_TEXTE:
			_ecrit.text = _ecrit.text.substr(0, Objets.MAX_TEXTE)
			_ecrit.set_caret_column(_ecrit.get_line(_ecrit.get_line_count() - 1).length())
			_ecrit.set_caret_line(_ecrit.get_line_count() - 1))
	_ecrit.gui_input.connect(_souris_sur_page)
	zone.add_child(_ecrit)
	_riche = RichTextLabel.new()
	_riche.set_anchors_preset(Control.PRESET_FULL_RECT)
	_riche.bbcode_enabled = true
	_riche.scroll_active = false
	_riche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_riche.add_theme_font_override("normal_font", police_ecrit)
	_riche.add_theme_color_override("default_color", encre)
	_riche.visible = false
	zone.add_child(_riche)
	_selecteur = HBoxContainer.new()
	_selecteur.set_anchors_preset(Control.PRESET_FULL_RECT)
	_selecteur.add_theme_constant_override("separation", 14)
	_selecteur.visible = false
	zone.add_child(_selecteur)
	var col_g := VBoxContainer.new()
	col_g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_g.add_theme_constant_override("separation", 0)
	_selecteur.add_child(col_g)
	_sel_aide = Label.new()
	_sel_aide.add_theme_font_override("font", police_ecrit)
	_sel_aide.add_theme_font_size_override("font_size", 15)
	_sel_aide.add_theme_color_override("font_color", Color(encre, 0.75))
	_sel_aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col_g.add_child(_sel_aide)
	_sel_lignes = VBoxContainer.new()
	_sel_lignes.add_theme_constant_override("separation", 0)
	col_g.add_child(_sel_lignes)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 170
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_selecteur.add_child(scroll)
	_sel_joueurs = VBoxContainer.new()
	_sel_joueurs.add_theme_constant_override("separation", 0)
	_sel_joueurs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_sel_joueurs)
	# Le pied de page : ◀ page 2 / 8 ▶ à l'encre.
	var pied := HBoxContainer.new()
	pied.alignment = BoxContainer.ALIGNMENT_CENTER
	pied.add_theme_constant_override("separation", 14)
	pv.add_child(pied)
	_avant = _bouton_page("◀", func(): _tourner(-1))
	pied.add_child(_avant)
	_numero = Label.new()
	_numero.add_theme_font_override("font", police_ecrit)
	_numero.add_theme_color_override("font_color", Color(encre, 0.85))
	_numero.add_theme_font_size_override("font_size", 20)
	_numero.custom_minimum_size.x = 150
	_numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pied.add_child(_numero)
	_apres = _bouton_page("▶", func(): _tourner(1))
	pied.add_child(_apres)
	v.add_child(feuille)
	# Sous la feuille, sur le cuir : déchirer, fermer.
	var bas := HBoxContainer.new()
	_bas = bas
	bas.add_theme_constant_override("separation", 10)
	v.add_child(bas)
	_dechirer = _bouton("Déchirer cette page", _arracher)
	bas.add_child(_dechirer)
	var vide := Control.new()
	vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bas.add_child(vide)
	bas.add_child(_bouton("Poser la plume (Échap)", func(): ecrire(false)))
	_aide = Label.new()
	_aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aide.add_theme_font_override("font", Style.police("italique"))
	_aide.add_theme_font_size_override("font_size", 17)
	_aide.add_theme_color_override("font_color", Color(0.85, 0.74, 0.55, 0.9))
	_aide.custom_minimum_size.y = 30
	v.add_child(_aide)
	var orn := Ornements.new()
	orn.set_anchors_preset(Control.PRESET_FULL_RECT)
	orn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(orn)
	visible = false


## Le clic droit lève la plume ; la molette tourne les pages (le TextEdit, lui, les garderait pour lui).
func _souris_sur_page(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton) or not ev.pressed:
		return
	if ev.button_index == MOUSE_BUTTON_RIGHT and ecriture:
		ecrire(false)
		accept_event()
		_ecrit.accept_event()
	elif ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_tourner(-1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		_ecrit.accept_event()


func _gui_input(ev: InputEvent) -> void:
	_souris_sur_page(ev)


func _style_bouton(fond: Color, bord: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.border_color = bord
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s


## Un bouton sur le cuir : brun sombre, lettres dorées.
func _bouton(texte: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Color(0.95, 0.8, 0.5))
	b.add_theme_color_override("font_hover_color", Color(1, 0.92, 0.7))
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.5, 0.35, 0.5))
	b.add_theme_stylebox_override("normal", _style_bouton(Color(0.1, 0.05, 0.025, 0.85), Color(0.7, 0.52, 0.24, 0.7)))
	b.add_theme_stylebox_override("hover", _style_bouton(Color(0.2, 0.1, 0.05, 0.95), Color(0.95, 0.75, 0.38)))
	b.add_theme_stylebox_override("pressed", _style_bouton(Color(0.05, 0.025, 0.012, 1.0), Color(0.95, 0.75, 0.38)))
	b.add_theme_stylebox_override("disabled", _style_bouton(Color(0.1, 0.05, 0.025, 0.4), Color(0.5, 0.4, 0.25, 0.3)))
	b.pressed.connect(f)
	return b


## Une flèche à l'encre, sur le papier.
func _bouton_page(texte: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.3, 0.17, 0.08))
	b.add_theme_color_override("font_hover_color", Color(0.6, 0.2, 0.08))
	b.add_theme_color_override("font_disabled_color", Color(0.3, 0.17, 0.08, 0.25))
	b.pressed.connect(f)
	return b


## Taille de l'écriture : les lignes de la page restent calées sur les lignes réglées.
func _mettre_taille(taille: int, pas := 34.0) -> void:
	_taille = taille
	_espace = int(maxf(pas - _police.get_height(taille), 0.0))
	_ecrit.add_theme_font_size_override("font_size", taille)
	_ecrit.add_theme_constant_override("line_spacing", _espace)
	_lignes.pas = _police.get_height(taille) + _espace
	if _riche:
		_riche.add_theme_font_size_override("normal_font_size", taille)
		_riche.add_theme_constant_override("line_separation", _espace)


## Ouvre l'objet tenu EN LECTURE (son état tel que reçu de l'hôte) : aucun curseur, aucune frappe.
func ouvrir(o: Dictionary) -> void:
	_id = o["id"]
	_sorte = o["sorte"]
	_page = 0
	_brouillon.clear()
	ecriture = false
	_afficher(o)
	visible = true
	_ecrit.release_focus()
	_regler_mode()


## La plume se pose (on écrit) ou se lève (on lit). Lever la plume envoie le texte à l'hôte.
func ecrire(oui: bool) -> void:
	if not visible or oui == ecriture:
		return
	if not oui:
		_envoyer_texte()
	ecriture = oui
	_regler_mode()
	if oui:
		_ecrit.grab_focus()
		_ecrit.set_caret_line(_ecrit.get_line_count() - 1)
		_ecrit.set_caret_column(_ecrit.get_line(_ecrit.get_line_count() - 1).length())
	else:
		_ecrit.release_focus()
	ecriture_changee.emit(oui)


func _regler_mode() -> void:
	_ecrit.editable = ecriture and (_sorte == "page" or _nb_pages > 0)
	_stylo_2d.visible = ecriture
	_bas.visible = ecriture
	_aide.visible = not ecriture
	_aide.text = Langue.t("Molette ou ← → : tourner la page  ·  Clic droit : écrire  ·  Clic gauche : refermer") if _sorte == "carnet" 			else Langue.t("Clic droit : écrire  ·  Clic gauche : refermer")
	_montrer_page()
	_maj_boutons()


## Page des bandeaux, en lecture : pastille de couleur devant chaque ligne qui commence par un nom de couleur.
func _bbcode_bandeaux(texte: String) -> String:
	var noms: Array = []
	for k in Bouille.BANDEAUX.size():
		for n: String in [Bouille.nom_bandeau(k), Langue.t(Bouille.nom_bandeau(k))]:
			noms.append([n, k])
	noms.sort_custom(func(a, b): return (a[0] as String).length() > (b[0] as String).length())
	var r := ""
	for ligne in texte.split("\n"):
		var pastille := "     "
		for n: Array in noms:
			if (ligne as String).to_lower().begins_with((n[0] as String).to_lower()):
				var c: Color = Bouille.BANDEAUX[n[1]][0]
				pastille = "[color=#%s]■[/color]  " % c.to_html(false)
				break
		r += pastille + (ligne as String).replace("[", "[lb]") + "\n"
	return r


## Montre le texte de la page : un TextEdit pour écrire, ou (page des bandeaux en lecture) le texte coloré.
func _montrer_page() -> void:
	var bandeaux := _bandeaux and _sorte == "carnet" and _page == 0
	_mettre_taille(18 if bandeaux else 25, 24.0 if bandeaux else 34.0)
	var riche := bandeaux and not ecriture
	# Plume posée sur la page des bandeaux : pas de frappe libre, un sélecteur de pseudo.
	var selecteur := bandeaux and ecriture
	_riche.visible = riche
	_selecteur.visible = selecteur
	_ecrit.visible = not selecteur
	_ecrit.modulate.a = 0.0 if riche else 1.0
	if selecteur:
		_sel = -1
		_remplir_selecteur()
	if riche:
		_riche.text = _bbcode_bandeaux(_ecrit.text)
		_riche.add_theme_font_size_override("normal_font_size", _taille)


## Les lignes « couleur : pseudo » en boutons, et (ligne choisie) la liste des joueurs de la partie.
func _remplir_selecteur() -> void:
	for c in _sel_lignes.get_children():
		_sel_lignes.remove_child(c)
		c.queue_free()
	for c in _sel_joueurs.get_children():
		_sel_joueurs.remove_child(c)
		c.queue_free()
	var lignes := Objets.lignes_bandeaux(_ecrit.text)
	for i in lignes.size():
		var k := _bandeau_de(str(lignes[i][0]))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var pastille := ColorRect.new()
		pastille.custom_minimum_size = Vector2(16, 14)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pastille.color = Bouille.BANDEAUX[k][0] if k >= 0 else Color(0, 0, 0, 0)
		h.add_child(pastille)
		var texte: String = str(lignes[i][0]) if str(lignes[i][1]) == "" else "%s : %s" % [Langue.t(str(lignes[i][0])), lignes[i][1]]
		var b := _bouton_ligne(texte, i == _sel, func(): _clic_ligne(i))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
		_sel_lignes.add_child(h)
	if _sel >= 0 and _sel < lignes.size():
		_sel_aide.text = Langue.t("Choisis un pseudo à droite, ou clique une autre ligne pour les inverser.")
		var l_sel: Array = lignes[_sel]
		for nom: String in (joueurs.call() if joueurs.is_valid() else []):
			_sel_joueurs.add_child(_bouton_ligne(nom, nom == str(l_sel[1]), func(): _clic_joueur(nom)))
	else:
		_sel_aide.text = Langue.t("Clique une ligne pour changer son pseudo.")


func _bandeau_de(nom: String) -> int:
	for k in Bouille.BANDEAUX.size():
		if nom.to_lower() == Bouille.nom_bandeau(k).to_lower() or nom.to_lower() == Langue.t(Bouille.nom_bandeau(k)).to_lower():
			return k
	return -1


func _bouton_ligne(texte: String, choisi: bool, f: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.flat = not choisi
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Style.police("italique"))
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", StyleCarnet.ENCRE)
	b.add_theme_color_override("font_hover_color", Color(0.6, 0.2, 0.08))
	b.add_theme_stylebox_override("normal", _style_choisi() if choisi else StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", _style_choisi())
	b.add_theme_stylebox_override("pressed", _style_choisi())
	b.custom_minimum_size.y = 24
	b.pressed.connect(f)
	return b


func _style_choisi() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.75, 0.55, 0.25, 0.35)
	st.set_corner_radius_all(3)
	st.content_margin_left = 6
	st.content_margin_right = 6
	return st


## Un clic sur une ligne : on la choisit ; si une autre était déjà choisie, les deux pseudos s'inversent.
func _clic_ligne(i: int) -> void:
	if _sel >= 0 and _sel != i:
		_changer_page_bandeaux(Objets.echanger_bandeaux(_ecrit.text, _sel, i))
		_sel = -1
	else:
		_sel = -1 if _sel == i else i
	_remplir_selecteur()


## Un clic sur un joueur de la liste : il prend la ligne choisie (s'il en avait une, les deux s'inversent).
func _clic_joueur(nom: String) -> void:
	if _sel < 0:
		return
	_changer_page_bandeaux(Objets.attribuer_bandeau(_ecrit.text, _sel, nom))
	_sel = -1
	_remplir_selecteur()


func _changer_page_bandeaux(texte: String) -> void:
	if texte == _ecrit.text:
		return
	_ecrit.text = texte
	_stylo_2d.ecrire()
	tape.emit()
	_envoyer_texte()


## L'hôte a renvoyé les objets : si le nôtre a disparu de nos mains, on ferme.
func maj(o: Dictionary, moi: int) -> void:
	if not visible:
		return
	if o.is_empty() or o["porteur"] != moi or not bool(o.get("main", false)):
		fermer()
		return
	if _sorte == "carnet":
		_nb_pages = (o["pages"] as Array).size()
		_page = mini(_page, maxi(_nb_pages - 1, 0))
		_maj_boutons()


func _afficher(o: Dictionary) -> void:
	var maison := int(o.get("maison", -1))
	var h: Array = proprietaire.call(maison) if proprietaire.is_valid() and maison >= 0 else ["", -1]
	var bandeau: int = h[1]
	_qui.visible = maison >= 0
	_pastille.visible = bandeau >= 0 and bandeau < Bouille.BANDEAUX.size()
	if _pastille.visible:
		_pastille.color = Bouille.BANDEAUX[bandeau][0]
	if _pastille.visible:
		_qui_texte.text = Langue.t("Bandeau %s · maison %s") % [Langue.t(Bouille.nom_bandeau(bandeau)), Ronde.numero(maison)]
	else:
		_qui_texte.text = Langue.t("maison %s") % Ronde.numero(maison)
	_bandeaux = bool(o.get("bandeaux", false))
	if _sorte == "carnet":
		_titre.text = "Carnet de %s" % h[0] if h[0] != "" else "Carnet de la maison %s" % Ronde.numero(maison)
		var pages: Array = o["pages"]
		_nb_pages = pages.size()
		_ecrit.text = str(pages[_page]) if _page < pages.size() else ""
	else:
		_titre.text = "Une page arrachée au carnet de %s" % h[0] if h[0] != "" else "Une page déchirée"
		_nb_pages = 1
		_ecrit.text = str(o.get("texte", ""))
	_texte_envoye = _ecrit.text
	_maj_boutons()


func _maj_boutons() -> void:
	var carnet := _sorte == "carnet"
	_avant.visible = carnet and ecriture
	_apres.visible = carnet and ecriture
	_numero.visible = carnet
	_dechirer.visible = carnet and _nb_pages > 0
	_dechirer.disabled = _bandeaux and _page == 0
	if _nb_pages <= 0:
		_numero.text = Langue.t("plus de pages")
	elif _bandeaux and _page == 0:
		_numero.text = Langue.t("— Les bandeaux —")
	else:
		_numero.text = "— page %d / %d —" % [_page + 1, _nb_pages]
	_avant.disabled = _page <= 0
	_apres.disabled = _page >= _nb_pages - 1


## Enregistre la page en cours chez l'hôte si elle a changé.
func _envoyer_texte() -> void:
	if _id < 0 or _ecrit.text == _texte_envoye or not envoyer.is_valid():
		return
	_texte_envoye = _ecrit.text
	_brouillon[_page] = _ecrit.text
	envoyer.call("obj_ecrire", _id, [_page, _ecrit.text])


var _o_courant: Callable          # () -> Dictionary : l'état le plus récent de l'objet ouvert


## Molette, flèches ou boutons : une page en avant ou en arrière.
func tourner(sens: int) -> void:
	_tourner(sens)


func _tourner(sens: int) -> void:
	_envoyer_texte()
	var o: Dictionary = _o_courant.call() if _o_courant.is_valid() else {}
	_page = clampi(_page + sens, 0, maxi(_nb_pages - 1, 0))
	if not o.is_empty():
		var pages: Array = o["pages"]
		# Ce qu'on vient d'écrire n'est peut-être pas encore revenu de l'hôte : le brouillon d'abord.
		_ecrit.text = str(_brouillon.get(_page, pages[_page] if _page < pages.size() else ""))
	_texte_envoye = _ecrit.text
	_montrer_page()
	_maj_boutons()


func _arracher() -> void:
	if _bandeaux and _page == 0:
		return
	_envoyer_texte()
	if envoyer.is_valid():
		envoyer.call("obj_dechirer", _id, _page)
	fermer()


func fermer() -> void:
	_envoyer_texte()
	var etait := ecriture
	ecriture = false
	_ecrit.release_focus()
	visible = false
	if etait:
		ecriture_changee.emit(false)


func lier_etat(f: Callable) -> void:
	_o_courant = f
