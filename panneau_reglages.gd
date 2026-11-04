class_name PanneauReglages
extends HBoxContainer
## Les réglages (Son, Tchat vocal, Touches, Graphismes, Caméra), utilisés au menu et dans la
## pause. Un rail de sections à gauche, des cartes à droite. Tout passe par l'autoload Options.

signal petite_machine(oui: bool)
signal reglage_regard

const GRIS := Color(1, 1, 1, 0.55)
const OR := Color(1.0, 0.82, 0.5)
const BRAISE := Color(0.85, 0.16, 0.08)
const FOND_CARTE := Color(0.09, 0.06, 0.06, 0.85)
const FOND_SURVOL := Color(0.15, 0.09, 0.08, 0.95)

## id, symbole, titre, sous-titre
const SECTIONS := [
	["langue", "◐", "Langue / Language", "Le jeu en français ou en anglais."],
	["son", "♪", "Son", "Le volume de chaque famille de bruits."],
	["vocal", "◉", "Tchat vocal", "Ton micro, et comment on t'entend."],
	["touches", "≡", "Touches", "Clique une touche, puis appuie sur la nouvelle."],
	["manette", "✚", "Manette", "Branche une manette : elle marche partout, menus compris."],
	["graphisme", "◈", "Graphismes", "Plus beau, ou plus fluide."],
	["camera", "◎", "Caméra", "La webcam qui fait bouger ton villageois."],
	["streamer", "▶", "Mode streamer", "Pour jouer en direct : code caché, et le chat Twitch qui vote."],
]

var _pages := {}               # id -> Control
var _rail := {}                # id -> Button
var _titre: Label
var _sous_titre: Label
var _jauge: ProgressBar
var _alerte_micro: Label
var _attente_action := ""
var _boutons_touches := {}     # action -> Button
var _case_petite: CheckButton


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	custom_minimum_size = Vector2(920, 570)

	var rail := VBoxContainer.new()
	rail.custom_minimum_size.x = 230
	rail.add_theme_constant_override("separation", 6)
	var fond_rail := PanelContainer.new()
	fond_rail.add_theme_stylebox_override("panel", _boite(Color(0.03, 0.02, 0.025, 0.9), 14, 0, Color.TRANSPARENT, [14, 0, 0, 14]))
	var mr := _marges(14)
	mr.add_child(rail)
	fond_rail.add_child(mr)
	add_child(fond_rail)
	for s: Array in SECTIONS:
		var b := Button.new()
		b.text = "  %s   %s" % [s[1], s[2]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.custom_minimum_size.y = 52
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", OR)
		b.add_theme_color_override("font_hover_pressed_color", OR)
		b.add_theme_stylebox_override("normal", _boite(Color.TRANSPARENT, 10))
		b.add_theme_stylebox_override("hover", _boite(Color(1, 1, 1, 0.05), 10))
		b.add_theme_stylebox_override("pressed", _boite(Color(0.55, 0.08, 0.04, 0.35), 10, 4, BRAISE, [10, 10, 10, 10], true))
		b.add_theme_stylebox_override("hover_pressed", _boite(Color(0.6, 0.1, 0.05, 0.42), 10, 4, BRAISE, [10, 10, 10, 10], true))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var id: String = s[0]
		b.pressed.connect(func(): _montrer(id))
		rail.add_child(b)
		_rail[id] = b

	var droite := PanelContainer.new()
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	droite.add_theme_stylebox_override("panel", _boite(Color(0.06, 0.04, 0.045, 0.75), 14, 0, Color.TRANSPARENT, [0, 14, 14, 0]))
	add_child(droite)
	var md := _marges(26)
	droite.add_child(md)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 4)
	md.add_child(colonne)
	_titre = _texte("", 34, OR)
	colonne.add_child(_titre)
	_sous_titre = _texte("", 17, GRIS)
	colonne.add_child(_sous_titre)
	var souligne := ColorRect.new()
	souligne.color = Color(BRAISE, 0.6)
	souligne.custom_minimum_size = Vector2(80, 3)
	souligne.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	colonne.add_child(souligne)
	var espace := Control.new()
	espace.custom_minimum_size.y = 12
	colonne.add_child(espace)
	var pile := Control.new()
	pile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(pile)
	for s: Array in SECTIONS:
		var defile := ScrollContainer.new()
		defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		defile.set_anchors_preset(Control.PRESET_FULL_RECT)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 8)
		defile.add_child(v)
		pile.add_child(defile)
		_pages[s[0]] = defile
	_langue(_page("langue"))
	_son(_page("son"))
	_vocal(_page("vocal"))
	_touches(_page("touches"))
	_manette(_page("manette"))
	_graphisme(_page("graphisme"))
	_camera(_page("camera"))
	_streamer(_page("streamer"))
	_montrer("son")


func regler_petite(oui: bool) -> void:
	if _case_petite:
		_case_petite.set_pressed_no_signal(oui)


func _process(_delta: float) -> void:
	var voix := get_node_or_null("/root/Voix")
	if _jauge == null or voix == null:
		return
	# Le micro écoute tant que la page « Tchat vocal » est ouverte, même au menu.
	var ouverte := is_visible_in_tree() and (_pages["vocal"] as Control).visible
	voix.ecouter_essai(ouverte)
	if ouverte:
		# Échelle en décibels (-60 dB à -10 dB) : un micro faible fait quand même bouger la barre.
		var n := float(voix.mon_niveau)
		_jauge.value = clampf((linear_to_db(maxf(n, 0.00001)) + 60.0) * 2.0, 0, 100)
		_alerte_micro.visible = voix.micro_muet()


func _exit_tree() -> void:
	var voix := get_node_or_null("/root/Voix")
	if voix:
		voix.ecouter_essai(false)


func _montrer(id: String) -> void:
	for s: Array in SECTIONS:
		(_pages[s[0]] as Control).visible = s[0] == id
		(_rail[s[0]] as Button).set_pressed_no_signal(s[0] == id)
		if s[0] == id:
			_titre.text = s[2]
			_sous_titre.text = s[3]


func _page(id: String) -> VBoxContainer:
	return (_pages[id] as ScrollContainer).get_child(0) as VBoxContainer


# ---------------------------------------------------------------- sections

func _langue(p: VBoxContainer) -> void:
	var codes: Array = []
	var noms: Array = []
	for x: Array in Langue.CHOIX:
		codes.append(x[0])
		noms.append(x[1])
	var choix := _choix(noms)
	choix.selected = maxi(codes.find(str(Options.valeur("langue/choix"))), 0)
	choix.item_selected.connect(func(i):
		Options.regler("langue/choix", codes[i])
		_maj_touches())
	_carte(p, "Langue / Language", "Français ou English. « Automatique » suit la langue de ton système. Chacun joue dans sa langue, même en partie à plusieurs.", choix)


func _son(p: VBoxContainer) -> void:
	_glissiere(p, "Volume général", "Tout le jeu.", "son/general", 0, 100, 1, "%")
	_glissiere(p, "Ambiance", "Grillons, battements, nappes de la nuit.", "son/ambiance", 0, 100, 1, "%")
	_glissiere(p, "Musique", "La nappe sourde qui comble les silences pendant la partie.", "son/musique", 0, 100, 1, "%")
	_glissiere(p, "Effets", "Portes, cloche, pas, corbeaux.", "son/effets", 0, 100, 1, "%")
	_glissiere(p, "Voix des autres joueurs", "Au-delà de 100 % : on les entend plus fort que nature.", "son/voix", 0, 300, 5, "%")
	_glissiere(p, "Frayeurs", "Le cri des apparitions : l'épouvantail, le visage à la vitre, le monstre d'un fantôme.", "son/frayeurs", 0, 100, 1, "%")
	_case(p, "Cri des frayeurs", "Éteint : les apparitions restent, mais en silence.", "frayeurs/cri")
	var sorties := AudioServer.get_output_device_list()
	var noms := []
	for nom in sorties:
		noms.append("Sortie par défaut de Windows" if nom == "Default" else nom)
	var sortie := _choix(noms)
	sortie.selected = maxi(sorties.find(str(Options.valeur("son/sortie"))), 0)
	sortie.item_selected.connect(func(i): Options.regler("son/sortie", sorties[i]))
	_carte(p, "Sortie audio", "Casque, enceintes… Si tu n'entends rien, choisis ici où le son doit sortir.", sortie)


func _vocal(p: VBoxContainer) -> void:
	_case(p, "Micro allumé", "Éteint, personne ne t'entend.", "vocal/micro")
	var mode := _choix(["Micro ouvert", "Appuyer pour parler"])
	mode.selected = 1 if str(Options.valeur("vocal/mode")) == "appuyer" else 0
	mode.item_selected.connect(func(i): Options.regler("vocal/mode", "appuyer" if i == 1 else "ouvert"))
	_carte(p, "Mode", "Ouvert : on t'entend dès que tu parles. Sinon, tiens la touche « Parler ».", mode)
	# La touche se règle ici, à côté du mode (Edwin, 30/10) — pas seulement au fond de la page Touches.
	var parler := _bouton_touche()
	parler.pressed.connect(func(): _attendre("parler"))
	_boutons_touches["parler@vocal"] = parler
	_carte(p, "Touche pour parler", "Tiens-la pour qu'on t'entende.", parler, true)
	var carte_parler := p.get_child(p.get_child_count() - 1) as Control
	carte_parler.visible = mode.selected == 1
	mode.item_selected.connect(func(i): carte_parler.visible = i == 1)
	_maj_touches()
	var liste := Voix.micros_lisibles()
	var noms := []
	for nom in liste:
		noms.append("Micro par défaut de Windows" if nom == "Default" else nom)
	var peri := _choix(noms)
	peri.selected = maxi(liste.find(str(Options.valeur("vocal/peripherique"))), 0)
	peri.item_selected.connect(func(i): Options.regler("vocal/peripherique", liste[i]))
	_carte(p, "Micro utilisé", "", peri)
	# Les voix sur une autre sortie que le jeu (GoXLR : « Chat » d'un côté, « Game » de l'autre).
	var sorties: Array = [""] + Voix.sorties_tchat()
	if sorties.size() > 1:
		var noms_s := []
		for nom in sorties:
			noms_s.append("Comme le son du jeu" if nom == "" else nom)
		var sv := _choix(noms_s)
		sv.selected = maxi(sorties.find(str(Options.valeur("vocal/sortie"))), 0)
		sv.item_selected.connect(func(i): Options.regler("vocal/sortie", sorties[i]))
		_carte(p, "Sortie du tchat vocal", "Où tu entends les autres joueurs. La sortie du jeu se règle dans Son.", sv)
	_glissiere(p, "Sensibilité", "Plus bas = capte les voix faibles (et les bruits).", "vocal/seuil", 0.004, 0.08, 0.002, "")
	_jauge = ProgressBar.new()
	_jauge.custom_minimum_size = Vector2(280, 14)
	_jauge.show_percentage = false
	_jauge.add_theme_stylebox_override("background", _boite(Color(1, 1, 1, 0.08), 7))
	_jauge.add_theme_stylebox_override("fill", _boite(Color(0.35, 0.85, 0.45), 7))
	_jauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_carte(p, "Ton micro en ce moment", "Parle : la barre doit bouger. Sinon, essaie un autre « Micro utilisé ».", _jauge)
	_alerte_micro = _texte("Aucun son ne vient de ce micro. Essaie un autre micro dans la liste, et vérifie que Windows autorise le micro : Paramètres > Confidentialité et sécurité > Microphone > « Autoriser les applications de bureau à accéder au microphone ».", 15, OR)
	_alerte_micro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_alerte_micro.visible = false
	p.add_child(_alerte_micro)
	_note(p, "Le volume de chaque joueur se règle en partie : icône ◉ en haut à droite, ou dans la pause.")


func _touches(p: VBoxContainer) -> void:
	for a: Array in Reglages.ACTIONS:
		var b := _bouton_touche()
		var action: String = a[0]
		b.pressed.connect(func(): _attendre(action))
		_boutons_touches[action] = b
		_carte(p, a[1], "", b, true)
	_note(p, "Flèches et Espace : combinaisons du loup (fixes).")
	var r := _bouton("Remettre les touches par défaut")
	r.pressed.connect(func():
		Options.touches_par_defaut()
		_maj_touches())
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_child(r)
	_maj_touches()


func _manette(p: VBoxContainer) -> void:
	var etat := _texte("", 17)
	var maj := func(_oui := false) -> void:
		etat.text = "● Manette branchée" if Pad.connectee() else "○ Aucune manette détectée"
		etat.add_theme_color_override("font_color", OR if Pad.connectee() else GRIS)
	maj.call()
	Pad.branchee.connect(maj)
	tree_exiting.connect(func() -> void:
		if Pad.branchee.is_connected(maj):
			Pad.branchee.disconnect(maj))
	p.add_child(etat)
	_case(p, "Manette activée", "Éteinte, la manette ne fait plus rien.", "manette/active")
	_glissiere(p, "Vitesse du regard", "Le stick droit tourne la tête plus ou moins vite.", "manette/sensibilite", 0.3, 2.5, 0.1, "")
	for ligne: Array in Manette.AIDE:
		var b := _texte(ligne[1], 17, Color(1, 1, 1, 0.85))
		_carte(p, ligne[0], "", b, true)
	_note(p, "Les boutons appuient sur tes touches : change une touche dans « Touches », la manette suit.")


func _graphisme(p: VBoxContainer) -> void:
	_case(p, "Plein écran", "", "graphisme/plein_ecran")
	_case(p, "Synchronisation verticale", "Évite les déchirures de l'image.", "graphisme/vsync")
	_case(p, "Ombres", "Les éteindre fait gagner beaucoup d'images par seconde.", "graphisme/ombres")
	_glissiere(p, "Résolution 3D", "Plus bas = plus fluide, un peu plus flou.", "graphisme/echelle", 50, 100, 5, "%")
	_glissiere(p, "Champ de vision", "", "graphisme/champ", 60, 100, 1, "°")
	var choix := [0, 30, 60, 120, 144]
	var noms := []
	for c in choix:
		noms.append("Sans limite" if c == 0 else "%d images/s" % c)
	var fps := _choix(noms)
	fps.selected = maxi(choix.find(int(Options.valeur("graphisme/fps_max"))), 0)
	fps.item_selected.connect(func(i): Options.regler("graphisme/fps_max", choix[i]))
	_carte(p, "Images par seconde maximum", "", fps)
	_case_petite = _interrupteur()
	_case_petite.toggled.connect(func(oui): petite_machine.emit(oui))
	_carte(p, "Petite machine", "Moins de brume ; bras et doigts des autres non suivis.", _case_petite)


func _camera(p: VBoxContainer) -> void:
	_case(p, "Utiliser ma webcam", "Décochée, ou sans caméra : tes yeux clignent tout seuls et suivent ce que tu vises. Personne ne voit la différence.", "camera/utiliser")
	var b := _bouton("Refaire le réglage")
	b.pressed.connect(func(): reglage_regard.emit())
	_carte(p, "Réglage du regard", "Fait une seule fois, puis gardé. Le refaire si tu as déplacé ta webcam.", b)
	var c := _bouton("Caméra suivante")
	c.pressed.connect(func(): Capteur.changer_camera())
	_carte(p, "Changer de webcam", "Si tu en as plusieurs.", c)


func _streamer(p: VBoxContainer) -> void:
	_case(p, "Mode streamer", "Cache le code du lobby à l'écran (un bouton « Copier le code » le remplace).", "streamer/actif")
	var champ := LineEdit.new()
	champ.custom_minimum_size = Vector2(280, 38)
	champ.placeholder_text = "ex. : ma_chaine"
	champ.max_length = 60
	champ.text = str(Options.valeur("streamer/chaine"))
	var etat := _texte("", 16, GRIS)
	var maj := func() -> void:
		var c := TwitchVotes.chaine_valide(champ.text)
		if champ.text.strip_edges() == "":
			etat.text = ""
		elif c == "":
			etat.text = "Ce n'est pas un nom de chaîne Twitch."
		else:
			etat.text = {"hors_ligne": "Chaîne : %s" % c, "connexion": "Connexion au chat de %s…" % c,
				"en_ligne": "Connecté au chat de %s (%d messages lus)" % [c, Streamer.messages_lus],
				"erreur": "Connexion impossible pour l'instant."}.get(Streamer.etat, "")
	var valider := func(_t := "") -> void:
		Options.regler("streamer/chaine", champ.text.strip_edges())
		maj.call()
	champ.text_submitted.connect(valider)
	champ.focus_exited.connect(func() -> void: valider.call())
	champ.text_changed.connect(func(_t: String) -> void: maj.call())
	_carte(p, "Chaîne Twitch", "Le nom de ta chaîne. Le jeu lit son chat sans compte ni mot de passe, et n'y écrit jamais.", champ)
	p.add_child(etat)
	maj.call()
	var tic := Timer.new()
	tic.wait_time = 1.0
	tic.autostart = true
	tic.timeout.connect(maj)
	p.add_child(tic)
	_note(p, "Pendant le vote du village, tes spectateurs tapent « !vote rouge » (ou « !vote red » : les couleurs des bandeaux, en français ou en anglais). Un vote par personne, le dernier compte.")
	_note(p, "Tu vois ce que pense ton chat seulement après la fin du vote du village, dans un petit panneau en bas à droite. Rien n'est envoyé aux autres joueurs.")


# ---------------------------------------------------------------- touches à changer

func _attendre(action: String) -> void:
	_attente_action = action
	_maj_touches()


func _input(ev: InputEvent) -> void:
	if _attente_action == "" or not ev is InputEventKey or not ev.pressed or ev.echo:
		return
	get_viewport().set_input_as_handled()
	if ev.keycode != KEY_ESCAPE:
		Options.lier(_attente_action, ev.keycode)
	_attente_action = ""
	_maj_touches()


func _maj_touches() -> void:
	for cle: String in _boutons_touches:
		var b: Button = _boutons_touches[cle]
		var action := cle.get_slice("@", 0)
		b.text = "Appuie sur une touche…" if action == _attente_action else Options.texte_touches(action)
		b.add_theme_color_override("font_color", BRAISE if action == _attente_action else OR)


# ---------------------------------------------------------------- briques

## Une carte : titre (et aide) à gauche, le réglage à droite. Plus claire au survol.
func _carte(p: VBoxContainer, titre: String, aide: String, controle: Control, serre := false) -> void:
	var carte := PanelContainer.new()
	var normal := _boite(FOND_CARTE, 10, 0, Color.TRANSPARENT, [10, 10, 10, 10])
	var survol := _boite(FOND_SURVOL, 10, 0, Color.TRANSPARENT, [10, 10, 10, 10])
	carte.add_theme_stylebox_override("panel", normal)
	carte.mouse_filter = Control.MOUSE_FILTER_PASS
	carte.mouse_entered.connect(func(): carte.add_theme_stylebox_override("panel", survol))
	carte.mouse_exited.connect(func(): carte.add_theme_stylebox_override("panel", normal))
	var m := _marges(10 if serre else 14)
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 18)
	carte.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	m.add_child(h)
	var textes := VBoxContainer.new()
	textes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textes.add_theme_constant_override("separation", 2)
	textes.alignment = BoxContainer.ALIGNMENT_CENTER
	textes.add_child(_texte(titre, 19))
	if aide != "":
		var a := _texte(aide, 14, GRIS)
		a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		textes.add_child(a)
	h.add_child(textes)
	controle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(controle)
	p.add_child(carte)


func _note(p: VBoxContainer, t: String) -> void:
	var l := _texte(t, 15, GRIS)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)


func _texte(t: String, taille := 18, couleur := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	return l


func _marges(n: int) -> MarginContainer:
	var m := MarginContainer.new()
	for c in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + c, n)
	return m


func _boite(c: Color, rayon := 8, bord_gauche := 0, couleur_bord := Color.TRANSPARENT, coins := [], marge := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	if coins.size() == 4:
		s.corner_radius_top_left = coins[0]
		s.corner_radius_top_right = coins[1]
		s.corner_radius_bottom_right = coins[2]
		s.corner_radius_bottom_left = coins[3]
	else:
		s.set_corner_radius_all(rayon)
	if bord_gauche > 0:
		s.border_width_left = bord_gauche
		s.border_color = couleur_bord
	if marge:
		s.content_margin_left = 12
	return s


func _bouton(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", OR)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	for etat in ["normal", "hover", "pressed"]:
		var s := _boite(Color(0.5, 0.08, 0.04, 0.45) if etat == "normal" else (Color(0.7, 0.12, 0.05, 0.7) if etat == "hover" else Color(0.4, 0.05, 0.03, 0.8)), 8)
		s.border_width_bottom = 2
		s.border_color = Color(BRAISE, 0.8)
		s.content_margin_left = 16
		s.content_margin_right = 16
		b.add_theme_stylebox_override(etat, s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _bouton_touche() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(230, 36)
	b.add_theme_font_size_override("font_size", 17)
	var s := _boite(Color(0, 0, 0, 0.45), 6)
	s.border_width_bottom = 3
	s.border_width_top = 1
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_color = Color(1, 1, 1, 0.18)
	b.add_theme_stylebox_override("normal", s)
	var sh := s.duplicate() as StyleBoxFlat
	sh.border_color = Color(OR, 0.7)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _choix(noms: Array) -> OptionButton:
	var o := OptionButton.new()
	for n in noms:
		o.add_item(str(n))
	o.custom_minimum_size = Vector2(280, 38)
	o.fit_to_longest_item = false
	o.add_theme_font_size_override("font_size", 16)
	var s := _boite(Color(0, 0, 0, 0.45), 8)
	s.content_margin_left = 12
	s.border_width_bottom = 2
	s.border_color = Color(1, 1, 1, 0.15)
	o.add_theme_stylebox_override("normal", s)
	var sh := s.duplicate() as StyleBoxFlat
	sh.border_color = Color(OR, 0.6)
	o.add_theme_stylebox_override("hover", sh)
	o.add_theme_stylebox_override("pressed", sh)
	o.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return o


func _interrupteur() -> CheckButton:
	var c := CheckButton.new()
	c.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return c


func _case(p: VBoxContainer, titre: String, aide: String, cle: String) -> void:
	var c := _interrupteur()
	c.button_pressed = bool(Options.valeur(cle))
	c.toggled.connect(func(oui): Options.regler(cle, oui))
	_carte(p, titre, aide, c)


func _glissiere(p: VBoxContainer, titre: String, aide: String, cle: String, mini: float, maxi: float, pas: float, unite: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var s := HSlider.new()
	s.min_value = mini
	s.max_value = maxi
	s.step = pas
	s.value = float(Options.valeur(cle))
	s.custom_minimum_size = Vector2(260, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var piste := _boite(Color(1, 1, 1, 0.1), 4)
	piste.content_margin_top = 3
	piste.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", piste)
	var plein := _boite(BRAISE, 4)
	plein.content_margin_top = 3
	plein.content_margin_bottom = 3
	s.add_theme_stylebox_override("grabber_area", plein)
	var plein_survol := _boite(Color(0.95, 0.3, 0.12), 4)
	plein_survol.content_margin_top = 3
	plein_survol.content_margin_bottom = 3
	s.add_theme_stylebox_override("grabber_area_highlight", plein_survol)
	s.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var v := _texte("", 17, OR)
	v.custom_minimum_size.x = 64
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var montrer := func(x: float):
		v.text = ("%d%s" % [int(x), unite]) if unite != "" else ("%.3f" % x)
		v.add_theme_color_override("font_color", BRAISE.lightened(0.3) if unite == "%" and x > 100.0 else OR)
	montrer.call(s.value)
	s.value_changed.connect(func(x):
		montrer.call(x)
		Options.regler(cle, x))
	h.add_child(s)
	h.add_child(v)
	_carte(p, titre, aide, h)
