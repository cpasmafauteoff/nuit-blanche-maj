class_name Boutique
extends Control
## L'onglet « Cosmétique » du menu : la roulotte du colporteur (Edwin, 30/10). À gauche, le village
## et la roulotte en 3D, ton personnage devant le miroir qui essaie ce que tu regardes ; à droite,
## les malles, les articles et la caisse. Les achats passent par Steam (cf. GardeRobe).

signal essai(apparence: int, article: String)     # ce qu'on regarde, sur le personnage
signal portee(apparence: int)                     # ce qu'on garde sur soi
signal retour_demande

const OR := Color(0.92, 0.74, 0.38)
const ENCRE := Color(0.93, 0.86, 0.74)

var apparence := 0
var _famille := "tenue"
var _choisi := ""
var _onglets := {}
var _liste: VBoxContainer
var _titre_article: Label
var _rarete: Label
var _texte: Label
var _contenu: Label
var _prix: Label
var _bouton_acheter: Button
var _bouton_porter: Button
var _message: Label
var _parole: Label
var _carte: DosDeCarte
var _lignes := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.028, 0.032, 0.93)
	st.border_color = Color(0.72, 0.55, 0.3, 0.75)
	st.set_border_width_all(1)
	st.border_width_left = 3
	st.shadow_color = Color(0, 0, 0, 0.75)
	st.shadow_size = 40
	st.content_margin_left = 34
	st.content_margin_right = 30
	st.content_margin_top = 26
	st.content_margin_bottom = 22
	p.add_theme_stylebox_override("panel", st)
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.anchor_top = 0.0
	p.anchor_bottom = 1.0
	p.offset_left = -820
	p.offset_right = -24
	p.offset_top = 24
	p.offset_bottom = -24
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)

	var t := _l("La roulotte du colporteur", 46, OR, "titre")
	t.add_theme_color_override("font_shadow_color", Color(1.0, 0.55, 0.15, 0.35))
	t.add_theme_constant_override("shadow_outline_size", 14)
	v.add_child(t)
	_parole = _l("", 19, Color(ENCRE, 0.8), "italique")
	_parole.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_parole)
	if GardeRobe.mode_essai():
		var bandeau := _l("Mode essai : tout est débloqué pour l'essayer. La vente ouvrira avec la sortie sur Steam.", 15, Color(0.55, 0.85, 1.0))
		bandeau.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(bandeau)

	# Les malles : une par famille.
	var malles := HFlowContainer.new()
	malles.add_theme_constant_override("h_separation", 6)
	malles.add_theme_constant_override("v_separation", 6)
	for f: Array in Cosmetiques.FAMILLES:
		var cle: String = f[0]
		var b := Button.new()
		b.text = f[1]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", Style.police("titre"))
		b.add_theme_font_size_override("font_size", 20)
		_habiller_onglet(b)
		b.pressed.connect(func(): choisir_famille(cle))
		malles.add_child(b)
		_onglets[cle] = b
	v.add_child(malles)
	var filet := ColorRect.new()
	filet.color = Color(0.85, 0.15, 0.08, 0.6)
	filet.custom_minimum_size = Vector2(0, 1)
	v.add_child(filet)

	var corps := HBoxContainer.new()
	corps.add_theme_constant_override("separation", 22)
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(corps)
	var defile := ScrollContainer.new()
	defile.custom_minimum_size.x = 320
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corps.add_child(defile)
	_liste = VBoxContainer.new()
	_liste.add_theme_constant_override("separation", 6)
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defile.add_child(_liste)

	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 10)
	corps.add_child(detail)
	_rarete = _l("", 16, OR, "titre")
	detail.add_child(_rarete)
	_titre_article = _l("", 34, ENCRE, "titre")
	_titre_article.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_titre_article)
	_texte = _l("", 19, Color(ENCRE, 0.85), "italique")
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_texte)
	_contenu = _l("", 17, Color(ENCRE, 0.75))
	_contenu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_contenu)
	_carte = DosDeCarte.new()
	_carte.custom_minimum_size = Vector2(150, 220)
	_carte.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_carte.visible = false
	detail.add_child(_carte)
	var vide := Control.new()
	vide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(vide)
	_prix = _l("", 40, OR, "titre")
	detail.add_child(_prix)
	var boutons := HBoxContainer.new()
	boutons.add_theme_constant_override("separation", 10)
	_bouton_acheter = _gros("Acheter", Color(0.75, 0.16, 0.08))
	_bouton_acheter.pressed.connect(_acheter)
	boutons.add_child(_bouton_acheter)
	_bouton_porter = _gros("Porter", Color(0.28, 0.22, 0.14))
	_bouton_porter.pressed.connect(_porter)
	boutons.add_child(_bouton_porter)
	detail.add_child(boutons)
	_message = _l("", 16, Color(0.6, 0.9, 0.6))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_message)

	var bas := HBoxContainer.new()
	var ret := _gros("◀  Retour", Color(0.18, 0.13, 0.1))
	ret.pressed.connect(func(): retour_demande.emit())
	bas.add_child(ret)
	v.add_child(bas)


## À l'ouverture : on retire ce qui n'est plus à soi, et on ouvre la malle des tenues.
func ouvrir(app: int) -> void:
	apparence = GardeRobe.nettoyer(app)
	if apparence != app:
		portee.emit(apparence)
	choisir_famille(_famille)


func choisir_famille(f: String) -> void:
	_famille = f
	for k in _onglets:
		(_onglets[k] as Button).button_pressed = k == f
	for f2: Array in Cosmetiques.FAMILLES:
		if f2[0] == f:
			_parole.text = "« %s »" % f2[2]
	for e in _liste.get_children():
		e.queue_free()
	_lignes.clear()
	var articles := Cosmetiques.de_la_famille(f).filter(func(a: Dictionary) -> bool: return not a.get("seul", false) or GardeRobe.possede(a["id"]))
	for a: Dictionary in articles:
		var ligne := _ligne(a)
		_liste.add_child(ligne)
		_lignes[a["id"]] = ligne
	if articles.size() > 0:
		choisir(articles[0]["id"])


func choisir(id: String) -> void:
	_choisi = id
	var a := Cosmetiques.article(id)
	for k in _lignes:
		(_lignes[k] as Button).button_pressed = k == id
	var rar: String = a.get("rarete", "commun")
	_rarete.text = (Cosmetiques.NOMS_RARETES[rar] as String).to_upper()
	_rarete.add_theme_color_override("font_color", Cosmetiques.COULEURS_RARETES[rar])
	_titre_article.text = a["nom"]
	_texte.text = a["texte"]
	_contenu.text = ""
	if a["famille"] == "pack" and a.get("tout", false):
		var n := Cosmetiques.contenu(id).size()
		_contenu.text = "Les %d articles payants de la roulotte, et tous ceux qu'on y ajoutera plus tard.\n\nNon compris : les articles exclusifs des packs Fondateur (marqués « exclusif »). Les articles gratuits par niveau s'obtiennent en jouant.\n\nAu détail : %s" % [n, Cosmetiques.prix_affiche(Cosmetiques.valeur_detail(id))]
	elif a["famille"] == "pack":
		var noms := []
		for x: String in a["contient"]:
			var xa := Cosmetiques.article(x)
			noms.append("•  %s%s" % [Langue.t(xa["nom"]), ("   " + Langue.t("(exclusif)")) if xa.get("seul", false) else ""])
		_contenu.text = "\n".join(noms) + "\n\n" + Langue.t("Au détail : %s") % Cosmetiques.prix_affiche(Cosmetiques.valeur_detail(id))
	elif int(a.get("niveau", 0)) > 0:
		_contenu.text = "Offert, sans rien payer : il se débloque au niveau %d de villageois." % int(a["niveau"])
	elif a["famille"] in ["maison", "tombe"]:
		_contenu.text = "Les autres le voient pendant toute la partie."
	elif a["famille"] == "carte":
		_contenu.text = "Ne se voit que sur ton écran, quand on te tend ta carte."
	elif a["famille"] == "mort":
		_contenu.text = "Tous les vivants la voient, là où tu tombes."
	_carte.visible = a["famille"] == "carte"
	_carte.sorte = str(a.get("valeur", ""))
	_carte.queue_redraw()
	_message.text = ""
	_maj_boutons()
	# Le personnage essaie l'article (un coffret : tout ce qu'il contient).
	var essai_app := apparence
	if a["famille"] == "pack":
		if not a.get("tout", false):
			for x: String in a["contient"]:
				essai_app = GardeRobe.porter(essai_app, x)
	else:
		essai_app = GardeRobe.porter(essai_app, id)
	essai.emit(essai_app, id)


func _maj_boutons() -> void:
	var a := Cosmetiques.article(_choisi)
	var a_soi := GardeRobe.possede(_choisi)
	var porte := GardeRobe.porte(apparence, _choisi)
	var niveau := int(a.get("niveau", 0))
	_prix.text = "Possédé" if a_soi else ("Niveau %d" % niveau if niveau > 0 else Cosmetiques.prix_affiche(int(a["prix"])))
	_prix.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6) if a_soi else OR)
	_bouton_acheter.visible = not a_soi and niveau == 0
	_bouton_acheter.text = "Acheter  %s" % Cosmetiques.prix_affiche(int(a["prix"]))
	var portable: bool = a["famille"] not in ["pack", "emote"]
	_bouton_porter.visible = a_soi and portable
	_bouton_porter.text = "Retirer" if porte else "Porter"
	for k in _lignes:
		_etat_ligne(_lignes[k], k)


func _acheter() -> void:
	var r := GardeRobe.acheter(_choisi)
	if r == "":
		_message.text = "Le colporteur te tend l'article avec un sourire de travers."
		var a := Cosmetiques.article(_choisi)
		if a["famille"] not in ["pack", "emote"]:
			_porter()
	else:
		_message.text = r
	_maj_boutons()


func _porter() -> void:
	var a := Cosmetiques.article(_choisi)
	if a["famille"] == "carte":
		GardeRobe.choisir_carte("" if GardeRobe.carte() == a["valeur"] else str(a["valeur"]))
	else:
		apparence = GardeRobe.porter(apparence, _choisi, GardeRobe.porte(apparence, _choisi))
		portee.emit(apparence)
	_maj_boutons()
	essai.emit(apparence, _choisi)


# ---------------------------------------------------------------- formes

func _l(texte: String, taille: int, couleur: Color, sorte := "texte") -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_override("font", Style.police(sorte))
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	return l


func _boite(fond: Color, bord: Color, gauche := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.border_color = bord
	s.set_border_width_all(1)
	s.border_width_left = gauche
	s.set_corner_radius_all(4)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _habiller_onglet(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _boite(Color(0.08, 0.06, 0.05, 0.9), Color(0.5, 0.38, 0.22, 0.5)))
	b.add_theme_stylebox_override("hover", _boite(Color(0.2, 0.08, 0.05, 0.95), Color(0.85, 0.3, 0.12)))
	b.add_theme_stylebox_override("pressed", _boite(Color(0.42, 0.1, 0.05, 0.95), OR, 3))
	b.add_theme_color_override("font_color", Color(ENCRE, 0.75))
	b.add_theme_color_override("font_pressed_color", OR)
	b.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.75))


func _gros(texte: String, fond: Color) -> Button:
	var b := Button.new()
	b.text = texte
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Style.police("titre"))
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("normal", _boite(fond, Color(OR, 0.6), 3))
	b.add_theme_stylebox_override("hover", _boite(fond.lightened(0.25), OR, 3))
	b.add_theme_stylebox_override("pressed", _boite(fond.darkened(0.2), OR, 3))
	b.add_theme_color_override("font_color", ENCRE)
	b.mouse_entered.connect(func(): create_tween().tween_property(b, "scale", Vector2.ONE * 1.04, 0.1))
	b.mouse_exited.connect(func(): create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	return b


## Une ligne d'article : un trait de la couleur de sa rareté, le nom, le prix ou son état.
func _ligne(a: Dictionary) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(300, 58)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var rar: Color = Cosmetiques.COULEURS_RARETES[a.get("rarete", "commun")]
	b.add_theme_stylebox_override("normal", _boite(Color(0.07, 0.05, 0.045, 0.92), Color(rar, 0.55), 4))
	b.add_theme_stylebox_override("hover", _boite(Color(0.15, 0.08, 0.06, 0.95), rar, 4))
	b.add_theme_stylebox_override("pressed", _boite(Color(0.3, 0.09, 0.05, 0.95), rar, 6))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 16
	h.offset_right = -12
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var nom := _l(a["nom"], 20, ENCRE, "titre")
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nom.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nom.clip_text = true
	nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(nom)
	var etat := _l("", 17, OR)
	etat.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etat.name = "Etat"
	etat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(etat)
	var id: String = a["id"]
	b.pressed.connect(func(): choisir(id))
	return b


func _etat_ligne(b: Button, id: String) -> void:
	var etat := b.find_child("Etat", true, false) as Label
	var a := Cosmetiques.article(id)
	if GardeRobe.porte(apparence, id) and a["famille"] != "emote":
		etat.text = "Porté"
		etat.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	elif GardeRobe.possede(id):
		etat.text = "À toi"
		etat.add_theme_color_override("font_color", Color(ENCRE, 0.6))
	elif int(a.get("niveau", 0)) > 0:
		etat.text = "Niveau %d" % int(a["niveau"])
		etat.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	else:
		etat.text = Cosmetiques.prix_affiche(int(a["prix"]))
		etat.add_theme_color_override("font_color", OR)
