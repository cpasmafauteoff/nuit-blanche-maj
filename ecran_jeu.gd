class_name EcranJeu
extends Control
## Tout ce qui s'affiche par-dessus le jeu : phase et horloge, rôle, messages, invite d'action,
## carnet d'indices, combo du loup, carte de rôle, panneau de pouvoir, salon, fin de partie.

signal panneau_ferme
## Un message écrit au tchat du lobby, à envoyer à l'hôte.
signal tchat_envoye(texte: String)

const OR := Color(1.0, 0.82, 0.5)
const ROUGE := Color(0.85, 0.12, 0.08)

var _phase: Label
var _horloge: Label
var _role: Label
var _message: Label
var _message_t := 0.0
## Le coin en haut à gauche : ce qu'il faut savoir (consigne de la phase, puis les messages), jamais
## au milieu, qui ne garde que les actions possibles (Edwin, 31/10). Une consigne reste 4 s.
var _consigne: Label
var _consigne_texte := ""
var _consigne_t := 0.0
const DUREE_CONSIGNE := 4.0
## À droite, au milieu : « {pret} : je suis prêt » et l'attente des autres.
var _droite: Label
var _invite: Label
## En bas au milieu, tout petit : la seule touche d'une action possible (ramasser, porte, quête…), sans phrase.
var _touche_basse: PanelContainer
var _touche_basse_texte: Label
## La note de quête (le vote du matin) peut se réduire à un « W » presque invisible, en bas à gauche.
var _vote_mini: Label
var _carnet: Label
var _carnet_lignes: Array[String] = []
var _combo: Control
var _combo_obj: Combo = null
var _carte: PanelContainer
var _carte_t := 0.0
var _panneau: PanelContainer
var _style_sombre: StyleBox
var _style_carnet: StyleBoxFlat
var _panneau_boite: VBoxContainer
var _fin: PanelContainer
var _salon: PanelContainer
var _salon_boite: VBoxContainer
## Le lobby et la scène de synchronisation vivent sur leur propre calque, au-dessus de tout le HUD du
## jeu (la phase, l'horloge, le rôle… ne doivent pas transparaître) mais sous le menu pause.
var _calque_lobby: CanvasLayer
var _fond_lobby: ColorRect
var _tchat: TchatUI
var _synchro: EcranSynchro
var _progression: ProgressBar
var _viseur: Control
var _souffle: ColorRect        # trait discret en bas : ce qu'il reste de souffle pour courir
var _souffle_fond: ColorRect
var _vote: PanelContainer      # le vote de la quête du matin, à gauche
var _vote_lignes: VBoxContainer
var _vote_aide: Label
var _vote_ranger: Label
var _vote_titre: Label
var _t := 0.0
## Fournie par la partie : l'hôte exclut ce joueur (id) depuis les cartes du salon.
var sur_exclure: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme_ := Theme.new()
	theme_.default_font_size = 22
	theme = theme_

	_phase = _label("", 30, OR)
	_phase.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)   # toute la largeur, texte centré
	_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase.offset_top = 14
	add_child(_phase)
	_horloge = _label("", 46, Color(0.95, 0.9, 0.85))
	_horloge.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)   # toute la largeur, texte centré
	_horloge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_horloge.offset_top = 48
	add_child(_horloge)
	_role = _label("", 24, OR)
	_role.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_role.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_role.position = Vector2(-24, 18)
	add_child(_role)
	_consigne = _label("", 22, Color(1, 0.95, 0.85))
	_consigne.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_consigne.position = Vector2(24, 20)
	_consigne.size = Vector2(600, 0)
	add_child(_consigne)
	_message = _label("", 22, Color(1, 0.95, 0.85))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)
	_droite = _label("", 24, Color(1, 1, 1, 0.92))
	_droite.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_droite.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_droite.grow_vertical = Control.GROW_DIRECTION_BOTH
	_droite.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_droite.position = Vector2(-24, 0)
	add_child(_droite)
	_invite = _label("", 24, Color(1, 1, 1, 0.92))
	_invite.set_anchors_preset(Control.PRESET_CENTER)
	_invite.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_invite.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_invite.position.y = 60
	add_child(_invite)
	_touche_basse = PanelContainer.new()
	var st_t := StyleBoxFlat.new()
	st_t.bg_color = Color(0, 0, 0, 0.38)
	st_t.border_color = Color(1, 1, 1, 0.28)
	st_t.set_border_width_all(1)
	st_t.set_corner_radius_all(5)
	st_t.content_margin_left = 11
	st_t.content_margin_right = 11
	st_t.content_margin_top = 2
	st_t.content_margin_bottom = 2
	_touche_basse.add_theme_stylebox_override("panel", st_t)
	_touche_basse.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_touche_basse.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_touche_basse.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_touche_basse.position.y = -74
	_touche_basse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touche_basse.visible = false
	_touche_basse_texte = _label("", 17, Color(1, 1, 1, 0.72), true)
	_touche_basse.add_child(_touche_basse_texte)
	add_child(_touche_basse)
	_carnet = _label("", 18, Color(0.95, 0.9, 0.8, 0.9))
	_carnet.position = Vector2(24, 120)
	_carnet.custom_minimum_size.x = 520
	_carnet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_carnet)
	_progression = ProgressBar.new()
	_progression.set_anchors_preset(Control.PRESET_CENTER)
	_progression.custom_minimum_size = Vector2(320, 14)
	_progression.position = Vector2(-160, 100)
	_progression.show_percentage = false
	_progression.visible = false
	add_child(_progression)
	_souffle_fond = ColorRect.new()
	_souffle_fond.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_souffle_fond.custom_minimum_size = Vector2(220, 4)
	_souffle_fond.position = Vector2(-110, -46)
	_souffle_fond.color = Color(0, 0, 0, 0.35)
	_souffle_fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_souffle_fond.visible = false
	add_child(_souffle_fond)
	_souffle = ColorRect.new()
	_souffle.size = Vector2(220, 4)
	_souffle.color = Color(0.9, 0.88, 0.8, 0.6)
	_souffle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_souffle_fond.add_child(_souffle)
	_viseur = Viseur.new()
	_viseur.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viseur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viseur)
	_combo = DessinCombo.new()
	_combo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_combo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_combo)

	_carte = _cadre()
	_carte.visible = false
	_panneau = _cadre()
	_style_sombre = _panneau.get_theme_stylebox("panel")
	_style_carnet = StyleBoxFlat.new()
	_style_carnet.bg_color = Color(0.74, 0.66, 0.5)
	_style_carnet.border_color = Color(0.3, 0.2, 0.12)
	_style_carnet.set_border_width_all(3)
	_style_carnet.border_width_left = 14
	_style_carnet.set_corner_radius_all(3)
	_style_carnet.shadow_color = Color(0, 0, 0, 0.7)
	_style_carnet.shadow_size = 24
	for cote in ["left", "right", "top", "bottom"]:
		_style_carnet.set("content_margin_" + cote, 40)
	_panneau.visible = false
	_panneau_boite = _panneau.get_child(0)
	_fin = _cadre()
	_fin.visible = false
	_calque_lobby = CanvasLayer.new()
	_calque_lobby.layer = 2
	add_child(_calque_lobby)
	var racine_lobby := Control.new()
	racine_lobby.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	racine_lobby.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine_lobby.theme = theme
	_calque_lobby.add_child(racine_lobby)
	_fond_lobby = ColorRect.new()
	_fond_lobby.color = Color(0.02, 0.012, 0.025, 0.62)
	_fond_lobby.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fond_lobby.visible = false
	racine_lobby.add_child(_fond_lobby)
	_salon = _cadre()
	remove_child(_salon)
	racine_lobby.add_child(_salon)
	_salon.visible = false
	_salon_boite = _salon.get_child(0)
	_tchat = TchatUI.new()
	_tchat.envoye.connect(func(t): tchat_envoye.emit(t))
	_synchro = EcranSynchro.new()
	racine_lobby.add_child(_synchro)
	visibility_changed.connect(func(): _calque_lobby.visible = is_visible_in_tree())
	_construire_vote()


func _process(delta: float) -> void:
	_t += delta
	if _message_t > 0:
		_message_t -= delta
		_message.modulate.a = clampf(_message_t, 0, 1)
	if _consigne_t > 0:
		_consigne_t -= delta
		_consigne.modulate.a = clampf(_consigne_t, 0, 1)
	if _carte_t > 0:
		_carte_t -= delta
		if _carte_t <= 0:
			_carte.visible = false
	_placer_message()
	(_combo as DessinCombo).combo = _combo_obj
	_combo.queue_redraw()


# ---------------------------------------------------------------- affichages simples

func regler_phase(texte: String, secondes: float) -> void:
	# Au salon et pendant la synchronisation, rien du HUD de partie ne doit transparaître.
	if _salon.visible or _synchro.ouverte():
		texte = ""
		secondes = -1.0
	_phase.text = texte
	_horloge.text = "" if secondes < 0 else "%d:%02d" % [int(secondes) / 60, int(secondes) % 60]
	_horloge.add_theme_color_override("font_color", ROUGE if secondes >= 0 and secondes < 15 else Color(0.95, 0.9, 0.85))


func regler_role(texte: String) -> void:
	_role.text = Options.avec_touches(texte)


func message(texte: String, duree := 4.0) -> void:
	_message.text = Options.avec_touches(texte)
	_message_t = duree
	_message.modulate.a = 1.0


## Le message se range sous la consigne, en haut à gauche.
func _placer_message() -> void:
	_consigne.size = Vector2(minf(600.0, size.x * 0.4), 0)
	var y := 20.0
	if _consigne_t > 0.0 and _consigne.text != "":
		y = _consigne.position.y + _consigne.get_minimum_size().y + 10.0
	_message.size = Vector2(minf(600.0, size.x * 0.4), 0)
	_message.position = Vector2(24, y)
	# La carte du vote descend sous le texte du coin quand il est long, sans jamais le couvrir.
	if _vote and _vote.visible and not note_reduite():
		if _vote_y < -9000.0:
			_vote_y = _vote.position.y
		var bas := 0.0
		if _message_t > 0.0 and _message.text != "":
			bas = _message.position.y + _message.get_minimum_size().y
		elif _consigne_t > 0.0 and _consigne.text != "":
			bas = _consigne.position.y + _consigne.get_minimum_size().y
		_vote.position.y = maxf(_vote_y, bas + 14.0)


var _vote_y := -9999.0


## La consigne de la phase (coin en haut à gauche) : elle s'affiche 4 s quand elle change ;
## `persistant` la garde tant qu'on la redonne (un compte à rebours, une situation qui dure).
func consigne(texte: String, persistant := false) -> void:
	if texte != _consigne_texte:
		_consigne_texte = texte
		_consigne.text = Options.avec_touches(texte)
		_consigne_t = DUREE_CONSIGNE if texte != "" else minf(_consigne_t, 0.5)
	if persistant and texte != "":
		_consigne_t = maxf(_consigne_t, 1.0)


func droite(texte: String) -> void:
	_droite.text = Options.avec_touches(texte)


func invite(texte: String) -> void:
	_invite.text = Options.avec_touches(texte)


## Une action est possible : on n'affiche que sa touche, discrète, en bas au milieu (Edwin, 01/11 :
## « on met juste la touche en bas de son écran au milieu sans message »). "" : on la cache.
## `action` est le nom d'une action des réglages (agir, pouvoir…) ; elle suit les touches du joueur.
func touche_seule(action: String, mot := "") -> void:
	_touche_basse.visible = action != ""
	if action != "":
		_touche_basse_texte.text = Options.avec_touches("{%s}" % action) + ("  " + Langue.t(mot) if mot != "" else "")


func progression(valeur: float) -> void:
	_progression.visible = valeur > 0.0
	_progression.value = valeur * 100.0


## Souffle de course (0..1) ; négatif = plein, rien à afficher.
func souffle(valeur: float, essouffle: bool) -> void:
	_souffle_fond.visible = valeur >= 0.0
	if valeur >= 0.0:
		_souffle.size = Vector2(220.0 * valeur, 4)
		_souffle.color = Color(0.85, 0.25, 0.18, 0.75) if essouffle else Color(0.9, 0.88, 0.8, 0.6)


func viseur(visible_ : bool, couleur := Color(1, 1, 1, 0.6)) -> void:
	_viseur.visible = visible_
	(_viseur as Viseur).couleur = couleur
	_viseur.queue_redraw()


func noter(texte: String) -> void:
	_carnet_lignes.erase(texte)        # un indice déjà noté remonte en bas, sans doublon
	_carnet_lignes.append(texte)
	while _carnet_lignes.size() > 7:
		_carnet_lignes.pop_front()
	var lignes_en_langue := PackedStringArray()
	for l: String in _carnet_lignes:
		lignes_en_langue.append(Langue.t(l))
	_carnet.text = Langue.t("Ton carnet") + "\n• " + "\n• ".join(lignes_en_langue)


func vider_carnet() -> void:
	_carnet_lignes.clear()
	_carnet.text = ""


func montrer_carnet(oui: bool) -> void:
	_carnet.visible = oui and not _carnet_lignes.is_empty()


func combo(c: Combo) -> void:
	_combo_obj = c


func carte_role(nom: String, description: String, loup: bool, duree := 9.0) -> void:
	var v0: VBoxContainer = _carte.get_child(0)
	for e in v0.get_children():
		e.queue_free()
	# Le dos de la carte qu'on vient de retourner (celui acheté à la roulotte, ou celui d'origine).
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 28)
	v0.add_child(h)
	var dos := DosDeCarte.new()
	dos.sorte = GardeRobe.carte()
	dos.custom_minimum_size = Vector2(120, 176)
	dos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dos)
	var v := VBoxContainer.new()
	h.add_child(v)
	v.add_child(_label("Tu es", 24, Color(1, 1, 1, 0.7)))
	v.add_child(_label(nom, 52, ROUGE if loup else OR))
	var d := _label(description, 22)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 600
	v.add_child(d)
	# La carte ne mange pas la souris : on regarde autour de soi pendant qu'elle est là (Edwin, 01/11).
	_sans_souris(_carte)
	_carte.visible = true
	_carte_t = duree


## Ce panneau et tout ce qu'il contient laissent passer la souris.
func _sans_souris(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for e in n.get_children():
		_sans_souris(e)


# ---------------------------------------------------------------- panneau de pouvoir

func panneau_ouvert() -> bool:
	return _panneau.visible


## boutons : [[texte, Callable], …] ; un Callable vide = simple ligne de texte.
## carnet : le panneau prend l'allure d'un carnet de papier jauni, écrit à l'encre (choisir un nom).
func panneau(titre: String, explication: String, boutons: Array, carnet := false) -> void:
	for e in _panneau_boite.get_children():
		e.queue_free()
	_panneau.add_theme_stylebox_override("panel", _style_carnet if carnet else _style_sombre)
	var encre := Color(0.16, 0.09, 0.06)
	_panneau_boite.add_child(_label(titre, 32, encre if carnet else OR, carnet))
	if explication != "":
		var l := _label(explication, 20, Color(0.25, 0.16, 0.1) if carnet else Color(1, 1, 1, 0.8), carnet)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 560
		_panneau_boite.add_child(l)
	var grille := GridContainer.new()
	grille.columns = 2 if boutons.size() > 5 else 1
	grille.add_theme_constant_override("h_separation", 12)
	grille.add_theme_constant_override("v_separation", 8)
	for b in boutons:
		if b[1] is Callable and (b[1] as Callable).is_valid():
			var bouton := Button.new()
			bouton.text = "  %s  " % b[0]
			var action: Callable = b[1]
			bouton.pressed.connect(func():
				fermer_panneau()
				action.call())
			grille.add_child(bouton)
		else:
			grille.add_child(_label(b[0], 20, encre if carnet else Color(1, 1, 1, 0.75), carnet))
	if carnet:
		for bouton in grille.get_children():
			if bouton is Button:
				bouton.flat = true
				bouton.add_theme_color_override("font_color", encre)
				bouton.add_theme_color_override("font_hover_color", Color(0.55, 0.05, 0.02))
				bouton.add_theme_font_size_override("font_size", 24)
	_panneau_boite.add_child(grille)
	var fermer := Button.new()
	fermer.text = "Fermer (Échap)"
	fermer.flat = true
	fermer.pressed.connect(fermer_panneau)
	_panneau_boite.add_child(fermer)
	_panneau.visible = true


func fermer_panneau() -> void:
	if _panneau.visible:
		_panneau.visible = false
		panneau_ferme.emit()


# ---------------------------------------------------------------- salon

## humains : {id: {nom}} ; hote : peut régler et lancer. Rangé par catégories (Edwin, 29/10 :
## « trop simpliste et mal rangé ») : Lobby, Joueurs, Loups, Rôles du village, Rythme.
const LARGEUR_CARTE_SALON := 84.0


func salon(humains: Dictionary, places: int, nb_loups: int, hote: bool, adresse: String,
		sur_places: Callable, sur_loups: Callable, sur_lancer: Callable,
		durees: Dictionary = {}, sur_duree: Callable = Callable(),
		bots := false, sur_bots: Callable = Callable(), max_places := 12,
		sans: Array = [], sur_role: Callable = Callable(), prive := false, nom_lobby := "",
		sur_retour: Callable = Callable(), min_joueurs := Meneur.MIN_JOUEURS, personnalisee := false) -> void:
	# Le tchat survit au rafraîchissement : on le détache avant de défaire l'ancien salon.
	var tchat_actif := _tchat.a_le_focus()
	var saisie := _tchat.texte_saisi()
	if _tchat.get_parent() != null:
		_tchat.get_parent().remove_child(_tchat)
	for e in _salon_boite.get_children():
		e.queue_free()
	var gris := Color(1, 1, 1, 0.62)
	var titre := _label(nom_lobby if nom_lobby != "" else "Le village se rassemble", 34, OR)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Une simple flèche pour quitter le lobby (comme Échap puis « Quitter »), sans passer par la pause.
	var tete := HBoxContainer.new()
	var fleche := Button.new()
	fleche.text = "←"
	fleche.flat = true
	fleche.focus_mode = Control.FOCUS_NONE
	fleche.tooltip_text = "Quitter le lobby"
	fleche.custom_minimum_size = Vector2(56, 56)
	fleche.add_theme_font_size_override("font_size", 40)
	fleche.add_theme_color_override("font_color", Color(0.93, 0.82, 0.62, 0.6))
	fleche.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.82))
	fleche.add_theme_color_override("font_pressed_color", OR)
	fleche.visible = sur_retour.is_valid()
	if sur_retour.is_valid():
		fleche.pressed.connect(sur_retour)
	tete.add_child(fleche)
	tete.add_child(titre)
	# Un vide de la largeur de la flèche, pour que le titre reste centré.
	var contre := Control.new()
	contre.custom_minimum_size = Vector2(56, 0)
	contre.visible = fleche.visible
	tete.add_child(contre)
	_salon_boite.add_child(tete)
	var colonnes := HBoxContainer.new()
	colonnes.add_theme_constant_override("separation", 18)
	_salon_boite.add_child(colonnes)
	var gauche := VBoxContainer.new()
	gauche.add_theme_constant_override("separation", 14)
	gauche.custom_minimum_size.x = 470
	colonnes.add_child(gauche)
	var droite := VBoxContainer.new()
	droite.add_theme_constant_override("separation", 14)
	droite.custom_minimum_size.x = 560
	colonnes.add_child(droite)
	var tchat_col := VBoxContainer.new()
	tchat_col.add_theme_constant_override("separation", 14)
	tchat_col.custom_minimum_size.x = 330
	colonnes.add_child(tchat_col)

	# --- Lobby : le code, la visibilité, qui est déjà là.
	var lobby := _section(gauche, "Lobby")
	if adresse != "":
		lobby.add_child(_label(adresse, 32, OR))
		lobby.add_child(_label("À donner à tes amis : Jouer → Rejoindre avec un code.", 16, gris))
		Streamer.ajouter_bouton_copier(lobby)
	if hote and Reseau.par_steam and Plateforme.peut_inviter():
		var inviter := Button.new()
		inviter.text = "  Inviter des amis Steam  "
		inviter.add_theme_font_size_override("font_size", 18)
		inviter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		inviter.pressed.connect(func(): Plateforme.inviter())
		lobby.add_child(inviter)
		lobby.add_child(_label("Tes amis Steam peuvent aussi cliquer « Rejoindre la partie » sur ton nom.", 16, gris))
	elif hote and Reseau.par_steam:
		lobby.add_child(_label("Connexion par Steam : rien à régler sur les box.", 16, gris))
	elif hote and Reseau.en_ligne:
		lobby.add_child(_label("Connexion directe (Steam n'est pas ouvert sur ce PC).", 16, gris))
	lobby.add_child(_label(("Privé : seuls ceux qui ont le code entrent (jusqu'à %d joueurs)." if prive
		else "Public : il apparaît dans la liste des lobbies (jusqu'à %d joueurs).") % max_places, 16, gris))
	lobby.add_child(_label("Partie personnalisée : on lance dès 1 joueur ; sous 3, personne ne gagne d'office." if personnalisee
		else "Partie classique : 6 joueurs au moins (ou les bots).", 16, gris))
	var village := HFlowContainer.new()
	village.add_theme_constant_override("h_separation", 10)
	for id in humains:
		# Toutes les cartes à la même largeur (Edwin, 30/10 : un long pseudo grossissait la sienne).
		# Trop long, il se coupe en « … » ; le survol le donne en entier.
		var nom_j := str(humains[id]["nom"])
		var qui := VBoxContainer.new()
		qui.custom_minimum_size.x = LARGEUR_CARTE_SALON
		qui.tooltip_text = nom_j
		qui.mouse_filter = Control.MOUSE_FILTER_PASS
		var icone: Control = Visages.icone(int(humains[id].get("apparence", 0)), 40)
		icone.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		qui.add_child(icone)
		var n := _label(nom_j, 14 if nom_j.length() <= 10 else 12)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.custom_minimum_size.x = LARGEUR_CARTE_SALON
		n.clip_text = true
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		n.mouse_filter = Control.MOUSE_FILTER_PASS
		qui.add_child(n)
		# L'état de chacun : l'hôte, ou simplement là.
		var etat := _label("hôte" if int(id) == 1 else "en ligne", 12, OR if int(id) == 1 else Color(0.62, 0.85, 0.6, 0.8), true)
		etat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		etat.mouse_filter = Control.MOUSE_FILTER_PASS
		qui.add_child(etat)
		# L'hôte peut exclure depuis le salon (un second clic confirme, le premier s'efface au bout de 4 s).
		if hote and sur_exclure.is_valid() and int(id) != multiplayer.get_unique_id():
			var x := Button.new()
			x.text = "Exclure"
			x.add_theme_font_size_override("font_size", 12)
			x.focus_mode = Control.FOCUS_NONE
			var arme := [false]
			x.pressed.connect(func():
				if arme[0]:
					sur_exclure.call(int(id))
					return
				arme[0] = true
				x.text = "Confirmer ?"
				get_tree().create_timer(4.0).timeout.connect(func():
					if is_instance_valid(x):
						arme[0] = false
						x.text = "Exclure"))
			qui.add_child(x)
		village.add_child(qui)
	lobby.add_child(village)

	# --- Joueurs : les places, les bots.
	var joueurs := _section(gauche, "Joueurs")
	var nb_places := places if bots else clampi(humains.size(), min_joueurs, max_places)
	var l1 := HBoxContainer.new()
	l1.add_child(_label("Places au village  ", 20))
	if bots and hote:
		var s := SpinBox.new()
		s.min_value = maxi(6, humains.size())
		s.max_value = max_places
		s.value = places
		s.value_changed.connect(func(v): sur_places.call(int(v)))
		l1.add_child(s)
	else:
		l1.add_child(_label(str(nb_places), 22, OR))
	joueurs.add_child(l1)
	joueurs.add_child(_label("Une maison par joueur : le village grandit avec la partie.", 16, gris))
	if hote and sur_bots.is_valid():
		var cb := CheckBox.new()
		cb.text = "Bots : des villageois de passage prennent les places vides"
		cb.button_pressed = bots
		cb.toggled.connect(func(oui): sur_bots.call(oui))
		joueurs.add_child(cb)
	elif bots:
		joueurs.add_child(_label("Les places vides sont prises par des villageois de passage (bots).", 16, gris))
	if not bots:
		var manque := min_joueurs - humains.size()
		if manque > 0:
			joueurs.add_child(_label(("Encore %d joueurs pour pouvoir commencer." if manque > 1 else "Encore %d joueur pour pouvoir commencer.") % manque, 16, ROUGE.lightened(0.3)))

	# --- Loups : combien, et lesquels.
	var loups := _section(gauche, "Loups")
	var l2 := HBoxContainer.new()
	l2.add_child(_label("Nombre de loups  ", 20))
	var max_loups := Partie.loups_max(nb_places)
	if hote and sur_loups.is_valid():
		var sl := SpinBox.new()
		sl.min_value = 1
		sl.max_value = max_loups
		sl.value = clampi(nb_loups, 1, max_loups)
		sl.value_changed.connect(func(v): sur_loups.call(int(v)))
		l2.add_child(sl)
	else:
		l2.add_child(_label(str(clampi(nb_loups, 1, max_loups)), 22, ROUGE))
	loups.add_child(l2)
	loups.add_child(_label("Tirés la première nuit, parmi ceux qui n'ont rien gagné aux quêtes.", 16, gris))
	var gl := GridContainer.new()
	gl.columns = 2
	gl.add_theme_constant_override("h_separation", 22)
	var loup := _label("✔  Loup  (toujours là)", 18, OR)
	loup.tooltip_text = Options.avec_touches(Roles.LISTE["loup"][3])
	loup.mouse_filter = Control.MOUSE_FILTER_PASS
	gl.add_child(loup)
	gl.add_child(Control.new())
	for r: String in ["vampire", "souffleur", "solitaire", "traitre"]:
		gl.add_child(_case_role(r, sans, hote, sur_role))
	loups.add_child(gl)
	loups.add_child(_label("Traître dès %d joueurs, Loup solitaire dès %d (il remplace un loup)." % [Quetes.SEUIL_TRAITRE, Quetes.SEUIL_SOLITAIRE], 15, gris))

	# --- Rôles du village : chacun se gagne aux quêtes ; l'hôte peut en retirer.
	var village_r := _section(droite, "Rôles du village")
	village_r.add_child(_label("Chacun se gagne aux quêtes, une seule fois. Décoche ceux que tu ne veux pas.", 16, gris))
	var gr := GridContainer.new()
	gr.columns = 2
	gr.add_theme_constant_override("h_separation", 22)
	gr.add_theme_constant_override("v_separation", 4)
	for r: String in Quetes.ROLES_RETIRABLES:
		if not Roles.est_loup(r) and Roles.camp_depart(r) == Roles.VILLAGE:
			gr.add_child(_case_role(r, sans, hote, sur_role))
	village_r.add_child(gr)
	village_r.add_child(_label("Sans rôle à gagner, une quête réussie donne un simple titre (Meunier, Berger…).", 15, gris))

	# --- Rythme : la durée de chaque étape.
	var rythme := _section(droite, "Rythme")
	var gd := GridContainer.new()
	gd.columns = 4
	gd.add_theme_constant_override("h_separation", 14)
	for r: Array in Meneur.REGLAGES_DUREES:
		gd.add_child(_label(r[1], 17))
		var v := float(durees.get(r[0], r[2]))
		if hote and sur_duree.is_valid():
			var sp := SpinBox.new()
			sp.min_value = r[2]
			sp.max_value = r[3]
			sp.step = 5.0
			sp.value = v
			sp.suffix = "s"
			var cle: String = r[0]
			sp.value_changed.connect(func(x): sur_duree.call(cle, x))
			gd.add_child(sp)
		else:
			gd.add_child(_label(_minutes(v), 17, OR))
	rythme.add_child(gd)
	if hote:
		rythme.add_child(_label("En partie, l'hôte peut passer l'étape en cours avec la touche {passer}.", 15, gris))

	var zone_tchat := _section(tchat_col, "Tchat")
	zone_tchat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	zone_tchat.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tchat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	zone_tchat.add_child(_tchat)
	if tchat_actif:
		_tchat.call_deferred("rendre_focus", saisie)
	if hote:
		var b := Button.new()
		b.text = "   Commencer la partie   "
		b.add_theme_font_size_override("font_size", 26)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(sur_lancer)
		_salon_boite.add_child(b)
	else:
		var att := _label("L'hôte prépare la partie…", 22, Color(1, 1, 1, 0.75))
		att.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_salon_boite.add_child(att)
	_salon.visible = true
	_fond_lobby.visible = true


## Une catégorie du salon : un encart sombre, son titre doré, son contenu.
func _section(parent: Control, titre: String) -> VBoxContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.035)
	style.border_color = Color(0.6, 0.12, 0.08, 0.35)
	style.border_width_left = 3
	style.set_corner_radius_all(4)
	for cote in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + cote, 14)
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(_label(titre.to_upper(), 19, OR))
	return v


## Une case pour mettre un rôle dans la partie (l'hôte) ; aux autres, ce qui est en jeu.
func _case_role(r: String, sans: Array, hote: bool, sur_role: Callable) -> Control:
	var dedans := not sans.has(r)
	if hote and sur_role.is_valid():
		var c := CheckBox.new()
		c.text = Roles.nom(r)
		c.button_pressed = dedans
		c.tooltip_text = Options.avec_touches(Roles.LISTE[r][3])
		c.toggled.connect(func(oui): sur_role.call(r, oui))
		return c
	var l := _label(("✔  " if dedans else "✖  ") + Langue.t(Roles.nom(r)), 17, Color(1, 1, 1, 0.9) if dedans else Color(1, 1, 1, 0.35))
	l.tooltip_text = Options.avec_touches(Roles.LISTE[r][3])
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


func _minutes(s: float) -> String:
	var m := int(s) / 60
	var r := int(s) % 60
	return "%d min %02d" % [m, r] if m > 0 else "%d s" % r


func cacher_salon() -> void:
	_salon.visible = false
	_fond_lobby.visible = false


## Le salon est affiché, ou la scène de synchronisation qui le suit : le joueur ne se déplace pas.
func salon_visible() -> bool:
	return _salon.visible or _synchro.ouverte()


func tchat_recevoir(nom: String, texte: String) -> void:
	_tchat.ajouter(nom, texte)


func synchro_ouvrir() -> void:
	cacher_salon()
	_synchro.ouvrir()


func synchro_maj(pub: Dictionary) -> void:
	_synchro.maj(pub)


func synchro_fermer() -> void:
	_synchro.fermer()


func synchro_ouverte() -> bool:
	return _synchro.ouverte()


func synchro_temps() -> float:
	return _synchro.temps


# ---------------------------------------------------------------- fin

func fin(res: Dictionary, moi: int, hote: bool, sur_rejouer: Callable) -> void:
	var v: VBoxContainer = _fin.get_child(0)
	for e in v.get_children():
		e.queue_free()
	var gagne: bool = (res["gagnants"] as Array).has(moi)
	v.add_child(_label("Victoire !" if gagne else "Défaite", 52, OR if gagne else ROUGE))
	v.add_child(_label(res["texte"], 24))
	var bilan := VBoxContainer.new()   # la page « Bilan » (cf. _fin_pages)
	bilan.add_theme_constant_override("separation", 12)
	var grille := GridContainer.new()
	grille.add_theme_constant_override("h_separation", 26)
	var sieges: Dictionary = res["sieges"]
	grille.columns = 3 if sieges.size() <= 9 else 6   # au-delà de 9 joueurs, deux colonnes de joueurs (tout tient à l'écran)
	for id in sieges:
		var r: String = res["roles"][id]
		var bd := Bouille.nom_bandeau(int(sieges[id].get("bandeau", -1)))
		grille.add_child(_label(sieges[id]["nom"] + ("  " + Langue.t("(toi)") if id == moi else "") + ("  · " + Langue.t("bandeau %s") % Langue.t(bd) if bd != "" else ""), 20, OR if id == moi else Color.WHITE))
		grille.add_child(_label(Roles.nom(r), 20, ROUGE if Roles.est_loup(r) else Color(0.85, 0.85, 0.85)))
		grille.add_child(_label("gagne" if (res["gagnants"] as Array).has(id) else ("mort" if not sieges[id]["vivant"] else "vivant"), 18, Color(1, 1, 1, 0.6)))
	bilan.add_child(grille)
	var chronique: PackedStringArray = res.get("chronique", PackedStringArray())
	if not chronique.is_empty():
		bilan.add_child(_label("Ce qui s'est vraiment passé", 22, OR))
		var defile := ScrollContainer.new()
		defile.custom_minimum_size = Vector2(760, mini(chronique.size() * 26, 220))
		defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var t := _label("
".join(chronique), 16, Color(1, 1, 1, 0.85))
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size.x = 740
		defile.add_child(t)
		bilan.add_child(defile)
	_fin_pages(v, bilan, res)
	if hote:
		var b := Button.new()
		b.text = "   Rejouer   "
		b.pressed.connect(sur_rejouer)
		v.add_child(b)
	else:
		v.add_child(_label("L'hôte peut relancer une partie.", 18, Color(1, 1, 1, 0.7)))
	_fin.visible = true


# ---- les pages de l'écran de fin : le bilan (avec les titres des yeux à droite), la nuit des loups

var _fin_titres: VBoxContainer       # la carte des titres, à droite du bilan
var _fin_page_nuit: Control
var _fin_page_bilan: Control
var _fin_vue_loups: VueNuitLoups
var _fin_onglets_nuit: HBoxContainer


func _fin_pages(v: VBoxContainer, bilan: VBoxContainer, res: Dictionary) -> void:
	_fin_titres = null
	_fin_page_nuit = null
	var nuits: Array = res.get("nuits_loups", [])
	var avec_nuit := false
	for n: Dictionary in nuits:
		if not (n["loups"] as Dictionary).is_empty():
			avec_nuit = true
	# Le bilan, et à sa droite la carte des titres (elle se remplit quand l'hôte les publie).
	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", 26)
	haut.alignment = BoxContainer.ALIGNMENT_CENTER
	haut.add_child(bilan)
	_fin_titres = VBoxContainer.new()
	_fin_titres.add_theme_constant_override("separation", 10)
	_fin_titres.custom_minimum_size.x = 380
	_fin_titres.visible = false
	haut.add_child(_fin_titres)
	_fin_page_bilan = haut
	if not avec_nuit:
		v.add_child(haut)
		return
	var onglets := HBoxContainer.new()
	onglets.alignment = BoxContainer.ALIGNMENT_CENTER
	onglets.add_theme_constant_override("separation", 14)
	var b1 := Button.new()
	b1.text = "  Le bilan  "
	var b2 := Button.new()
	b2.text = "  La nuit vue des loups  "
	onglets.add_child(b1)
	onglets.add_child(b2)
	v.add_child(onglets)
	v.add_child(haut)
	# La nuit : un onglet par nuit, la carte en dessous.
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	_fin_onglets_nuit = HBoxContainer.new()
	_fin_onglets_nuit.add_theme_constant_override("separation", 8)
	_fin_onglets_nuit.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(_fin_onglets_nuit)
	_fin_vue_loups = VueNuitLoups.new()
	var utiles: Array = nuits.filter(func(n): return not (n["loups"] as Dictionary).is_empty())
	_fin_vue_loups.donnees(utiles, res["sieges"], res["roles"])
	for k in utiles.size():
		var bn := Button.new()
		bn.text = " Nuit %d " % _fin_vue_loups.numero_nuit(k)
		bn.toggle_mode = true
		bn.button_pressed = k == 0
		bn.pressed.connect(func():
			_fin_vue_loups.choisir_nuit(k)
			for autre in _fin_onglets_nuit.get_children():
				(autre as Button).button_pressed = autre == bn)
		_fin_onglets_nuit.add_child(bn)
	page.add_child(_fin_vue_loups)
	page.visible = false
	_fin_page_nuit = page
	v.add_child(page)
	b1.pressed.connect(func():
		haut.visible = true
		page.visible = false)
	b2.pressed.connect(func():
		haut.visible = false
		page.visible = true
		_fin_vue_loups.choisir_nuit(0))


## Pour les captures d'essai : ouvre la nuit vue des loups, figée à une fraction du rejeu.
func fin_montrer_nuit(k: int, fraction: float) -> void:
	if _fin_page_nuit == null or _fin_vue_loups == null:
		return
	_fin_page_bilan.visible = false
	_fin_page_nuit.visible = true
	_fin_vue_loups.choisir_nuit(k)
	for i in _fin_onglets_nuit.get_child_count():
		(_fin_onglets_nuit.get_child(i) as Button).button_pressed = i == k
	_fin_vue_loups.figer_a(fraction)


## Les titres des yeux, publiés par l'hôte quelques secondes après la fin (un parchemin, à droite du bilan).
func titres_yeux(titres: Array) -> void:
	if _fin_titres == null or not is_instance_valid(_fin_titres) or titres.is_empty():
		return
	for e in _fin_titres.get_children():
		e.queue_free()
	var carte := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.74, 0.66, 0.5)
	st.border_color = Color(0.3, 0.2, 0.12)
	st.set_border_width_all(2)
	st.border_width_left = 10
	st.set_corner_radius_all(3)
	st.shadow_color = Color(0, 0, 0, 0.6)
	st.shadow_size = 14
	for cote in ["left", "right", "top", "bottom"]:
		st.set("content_margin_" + cote, 20)
	carte.add_theme_stylebox_override("panel", st)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	carte.add_child(col)
	var tete := _label("Les yeux de la partie", 26, Style.ENCRE, true)
	tete.add_theme_font_override("font", Style.police("titre"))
	col.add_child(tete)
	for t: Dictionary in titres:
		var bloc := VBoxContainer.new()
		bloc.add_theme_constant_override("separation", 0)
		var nom := _label(str(t["titre"]), 21, Color(0.45, 0.07, 0.05), true)
		nom.add_theme_font_override("font", Style.police("titre"))
		bloc.add_child(nom)
		var texte := _label(str(t["texte"]), 18, Style.ENCRE, true)
		texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texte.custom_minimum_size.x = 330
		bloc.add_child(texte)
		col.add_child(bloc)
	_fin_titres.add_child(carte)
	_fin_titres.visible = true


func cacher_fin() -> void:
	_fin.visible = false


func fin_visible() -> bool:
	return _fin.visible


# ---------------------------------------------------------------- le vote de la quête du matin

## Une petite fenêtre à gauche (Edwin, 30/10) : les trois quêtes du jour, leur nom seul, puis
## « Rester ». On répond au chiffre ; elle n'arrête ni la marche ni la tête.
func _construire_vote() -> void:
	_vote = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.035, 0.035, 0.86)
	st.border_color = Color(OR, 0.6)
	st.set_border_width_all(1)
	st.border_width_left = 4
	st.set_corner_radius_all(8)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 12
	for cote in ["left", "right", "top", "bottom"]:
		st.set("content_margin_" + cote, 18)
	_vote.add_theme_stylebox_override("panel", st)
	_vote.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_vote.grow_vertical = Control.GROW_DIRECTION_BOTH
	_vote.position = Vector2(24, -150)
	_vote.custom_minimum_size.x = 340
	_vote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vote.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vote.add_child(v)
	var t := _label("La quête du jour", 26, OR)
	t.add_theme_font_override("font", Style.police("titre"))
	v.add_child(t)
	_vote_titre = t
	_vote_lignes = VBoxContainer.new()
	_vote_lignes.add_theme_constant_override("separation", 6)
	_vote_lignes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_vote_lignes)
	var aide := _label("Touche 1 à 4 · détail au tableau", 16, Color(1, 1, 1, 0.55))
	aide.add_theme_font_override("font", Style.police("italique"))
	v.add_child(aide)
	_vote_aide = aide
	# La touche qui range la note (Edwin, 01/11 : elle n'était écrite nulle part).
	_vote_ranger = _label("", 16, Color(1, 1, 1, 0.55))
	_vote_ranger.add_theme_font_override("font", Style.police("italique"))
	_vote_ranger.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # déjà traduit, touche comprise
	v.add_child(_vote_ranger)
	add_child(_vote)
	_vote_mini = _label("W", 18, Color(1, 1, 1, 0.38), true)
	_vote_mini.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_vote_mini.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_vote_mini.position = Vector2(18, -22)
	_vote_mini.visible = false
	add_child(_vote_mini)
	Options.change.connect(func(cle: String): if cle == "interface/note_reduite" or cle.begins_with("touches"): _montrer_note())


## La note est-elle réduite ? (mémorisé dans les réglages)
func note_reduite() -> bool:
	return bool(Options.valeur("interface/note_reduite"))


## La touche « note » : réduit la note de quête en un « W » à peine visible, ou la rouvre.
func basculer_note() -> void:
	Options.regler("interface/note_reduite", not note_reduite())


## Pose l'état réduit / ouvert. La note reste « visible » pour le jeu (les touches 1 à 4 votent toujours) :
## réduite, elle est seulement rendue transparente.
func _montrer_note() -> void:
	var reduite := note_reduite() and _vote.visible
	_vote.modulate.a = 0.0 if reduite else 1.0
	_vote_mini.visible = reduite
	_vote_mini.text = Options.texte_touches("note")


## `noms` : les quêtes (3), `compte` : les voix des 4 choix, `mon` : mon choix (-1 : aucun).
func vote_quete(noms: Array, compte: Array, mon: int, maire := false) -> void:
	_vote.visible = true
	_montrer_note()
	_vote_titre.text = "Tu choisis la quête du jour" if maire else "La quête du jour"
	var pad := get_node_or_null("/root/Pad")
	_vote_aide.text = "Croix ↑ 1 · → 2 · ↓ 3 · ← 4 · détail au tableau" if pad and pad.utilise() else "Touche 1 à 4 · détail au tableau"
	_vote_ranger.text = Options.avec_touches("{note} : ranger la note")
	for e in _vote_lignes.get_children():
		e.queue_free()
	var choix := noms.duplicate()
	choix.append("Rester au village")
	var total := 0
	for c in compte:
		total += int(c)
	for k in choix.size():
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 10)
		ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var moi := k == mon
		var touche := _label(str(k + 1), 24, Color(0.08, 0.05, 0.04) if moi else OR, true)
		touche.add_theme_font_override("font", Style.police("titre"))
		touche.custom_minimum_size = Vector2(34, 34)
		touche.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		touche.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var fond := StyleBoxFlat.new()
		fond.bg_color = OR if moi else Color(0, 0, 0, 0.4)
		fond.border_color = Color(OR, 0.7)
		fond.set_border_width_all(1)
		fond.set_corner_radius_all(5)
		touche.add_theme_stylebox_override("normal", fond)
		ligne.add_child(touche)
		var nom := _label(str(choix[k]), 22, Color(1.0, 0.95, 0.85) if moi else Color(0.92, 0.88, 0.8))
		nom.add_theme_font_override("font", Style.police("texte"))
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ligne.add_child(nom)
		var n := int(compte[k]) if k < compte.size() else 0
		var voix := _label("%d" % n if n > 0 else "", 20, Color(1, 0.8, 0.5))
		ligne.add_child(voix)
		_vote_lignes.add_child(ligne)
		# Une barre fine : la part des voix.
		var barre := ColorRect.new()
		barre.color = Color(ROUGE, 0.85) if k < 3 else Color(0.5, 0.6, 0.75, 0.85)
		barre.custom_minimum_size = Vector2(300.0 * (float(n) / maxf(total, 1)), 3)
		barre.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vote_lignes.add_child(barre)


## Quand il y a un maire, les autres n'ont que deux choix (Edwin, 31/10) : participer ou non.
## `mon` : 0 participer, 1 ne pas participer (par défaut, on participe) ; `refus` : ceux qui restent.
func vote_participation(mon: int, refus: int) -> void:
	_vote.visible = true
	_montrer_note()
	_vote_titre.text = "La quête du jour"
	var pad := get_node_or_null("/root/Pad")
	_vote_aide.text = "Croix ↑ 1 · → 2" if pad and pad.utilise() else "Touche 1 ou 2 · détail au tableau"
	for e in _vote_lignes.get_children():
		e.queue_free()
	var choix := ["Participer", "Ne pas participer"]
	for k in choix.size():
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 10)
		ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var moi := k == mon
		var touche := _label(str(k + 1), 24, Color(0.08, 0.05, 0.04) if moi else OR, true)
		touche.add_theme_font_override("font", Style.police("titre"))
		touche.custom_minimum_size = Vector2(34, 34)
		touche.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		touche.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var fond := StyleBoxFlat.new()
		fond.bg_color = OR if moi else Color(0, 0, 0, 0.4)
		fond.border_color = Color(OR, 0.7)
		fond.set_border_width_all(1)
		fond.set_corner_radius_all(5)
		touche.add_theme_stylebox_override("normal", fond)
		ligne.add_child(touche)
		var nom := _label(choix[k], 22, Color(1.0, 0.95, 0.85) if moi else Color(0.92, 0.88, 0.8))
		nom.add_theme_font_override("font", Style.police("texte"))
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ligne.add_child(nom)
		var n := refus if k == 1 else 0
		ligne.add_child(_label("%d" % n if n > 0 else "", 20, Color(1, 0.8, 0.5)))
		_vote_lignes.add_child(ligne)


func cacher_vote_quete() -> void:
	_vote.visible = false
	_montrer_note()


func vote_quete_visible() -> bool:
	return _vote.visible


# ---------------------------------------------------------------- outils

func _label(texte: String, taille := 22, couleur := Color.WHITE, sans_contour := false) -> Label:
	var l := Label.new()
	l.text = Options.avec_touches(texte)
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 0 if sans_contour else 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _cadre() -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.035, 0.04, 0.93)
	style.border_color = Color(0.6, 0.12, 0.08, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 18
	for cote in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + cote, 34)
	p.add_theme_stylebox_override("panel", style)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	add_child(p)
	return p


class Viseur extends Control:
	var couleur := Color(1, 1, 1, 0.6)

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 3.0, couleur)
		draw_arc(c, 11.0, 0, TAU, 24, Color(couleur, couleur.a * 0.5), 1.5, true)


class DessinCombo extends Control:
	var combo: Combo = null
	const SYMBOLES := {KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→"}

	func _draw() -> void:
		if combo == null:
			return
		var f := get_theme_default_font()
		var bas := Vector2(size.x * 0.5, size.y - 150)
		if combo.mode == "suite":
			var n := combo.attendu.size()
			var largeur := n * 70.0
			for k in n:
				var p := bas + Vector2(-largeur * 0.5 + k * 70.0 + 35.0, 0)
				var fait := k < combo.index
				var fond := Color(0.15, 0.6, 0.25, 0.85) if fait else Color(0.08, 0.06, 0.06, 0.85)
				draw_rect(Rect2(p - Vector2(28, 28), Vector2(56, 56)), fond)
				draw_rect(Rect2(p - Vector2(28, 28), Vector2(56, 56)), Color(0.85, 0.15, 0.1, 0.9), false, 2.0)
				draw_string(f, p + Vector2(-14, 14), SYMBOLES[combo.attendu[k]], HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
			var r := combo.temps_restant() / (Combo.TEMPS_PAR_FLECHE * n)
			draw_rect(Rect2(bas + Vector2(-largeur * 0.5, 40), Vector2(largeur * r, 6)), Color(0.9, 0.2, 0.1))
			draw_string(f, bas + Vector2(-200, -50), Langue.t("Pas sur les graviers et les planches : flèches, vite !"), HORIZONTAL_ALIGNMENT_CENTER, 400, 20, Color(1, 1, 1, 0.8))
		else:
			var ph := combo.phase_battement()
			draw_arc(bas, 46.0, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0, true)
			draw_arc(bas, 46.0 + (1.0 - ph) * 60.0, 0, TAU, 48, Color(0.9, 0.2, 0.1, 0.4 + ph * 0.6), 4.0, true)
			for k in combo.battements:
				var c := Color(0.15, 0.8, 0.3) if k < combo.index else Color(0.3, 0.3, 0.3)
				draw_circle(bas + Vector2((k - combo.battements * 0.5 + 0.5) * 26.0, 80), 8.0, c)
			draw_string(f, bas + Vector2(-200, -70), Langue.t("Flaques et feuilles : ESPACE quand le cercle se referme"), HORIZONTAL_ALIGNMENT_CENTER, 400, 20, Color(1, 1, 1, 0.8))
