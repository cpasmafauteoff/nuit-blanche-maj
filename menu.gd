class_name Menu
extends Control
## Le menu d'accueil, posé sur le village vu de loin, la nuit.
## Titre → Jouer → (Créer un lobby · Rejoindre avec un code · Lobbies ouverts) ;
## Titre → Mon personnage ; Titre → Réglages. « Retour » ou Échap remonte d'un cran.

signal creer(nom_lobby: String, langue: String, public: bool, bots: bool, perso: bool)
signal rejoindre(code: String)
signal essai_bots
## La nuit guidée du premier lancement (tutoriel jouable) : lancée, ou repoussée au premier lancement.
signal nuit_guidee
signal nuit_guidee_refusee
signal mode_test
signal reglage_regard
signal quitter_jeu
signal profil_change(nom: String, apparence: int)
signal petite_machine(oui: bool)
signal prendre_tete
signal tete_active(oui: bool)
signal effacer_tete
## La roulotte du colporteur (onglet Cosmétique) : ouverte ou non, et ce que le personnage essaie.
signal boutique(oui: bool)
signal essai_cosmetique(apparence: int, article: String)

const PARENTS := {"jouer": "titre", "creer": "jouer", "code": "jouer", "liste": "jouer",
	"villageois": "titre", "succes": "villageois", "options": "titre", "regles": "titre", "cosmetique": "titre"}
const ACTUALISER_LISTE := 15.0
const TEINTES := ["Mousse", "Sang séché", "Tabac", "Nuit", "Lin sale", "Prune", "Suie", "Cendre"]

var nom := "Joueur"
var apparence := 0
var petite := false

var _ecrans := {}
var _actuel := "titre"
var _info: Label
var _salut: HBoxContainer
var _champ_nom: LineEdit
var _champ_lobby: LineEdit
var _choix_langue: OptionButton
var _case_public: CheckBox
var _reglages: PanneauReglages
var _tete: Array = []          # [octets, repères] de ma photo, ou vide
var _tete_on := false
var _case_tete: CheckBox
var _info_tete: Label
var _case_bots: CheckBox
var _case_perso: CheckBox
var _champ_code: LineEdit
var _filtre: OptionButton
var _liste_boite: VBoxContainer
var _lobbies: Array = []
var _liste_t := 0.0
var _apercu: Bouille
var _apercu_vue: SubViewport
var _choix_labels := {}
var _rng := RandomNumberGenerator.new()
var _ecrans_voile: TextureRect
var _boutique: Boutique
var _succes_ui: SuccesUi
var _niveau_titre: Label
var _niveau_barre: ProgressBar
var _niveau_suite: Label
var _fleche_boutique: Button
var _regle_i := 0
## Carte ouverte d'emblée (essai : --regle=<n>) ; 0 en jeu normal.
var _regle_depart := 0
var _regle_illu: Illustration
var _regle_titre: Label
var _regle_texte: VBoxContainer
var _regle_prec: Button
var _regle_suiv: Button
var _regle_points: HBoxContainer
var _proposition: Control     # la proposition de la nuit guidée, tant qu'elle est à l'écran


func _ready() -> void:
	_rng.randomize()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--regle="):
			_regle_depart = a.get_slice("=", 1).to_int()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if apparence == 0:
		apparence = Bouille.au_hasard(_rng)
	_construire_voile()
	_construire_titre()
	_construire_jouer()
	_construire_creer()
	_construire_regles()
	_construire_code()
	_construire_liste()
	_construire_villageois()
	_construire_succes()
	_construire_options()
	_construire_boutique()
	_info = _label("", 20, Color(1, 0.8, 0.7))
	_info.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info.position.y -= 40
	add_child(_info)
	Lobbies.liste_recue.connect(_sur_liste)
	Lobbies.hors_ligne.connect(func(): info("Impossible de joindre le service des lobbies (ntfy.sh) : vérifie ta connexion Internet."))
	ecran("titre")


# ---------------------------------------------------------------- navigation

func ecran(e: String) -> void:
	var etait_boutique := _actuel == "cosmetique"
	_actuel = e
	for k in _ecrans:
		(_ecrans[k] as Control).visible = k == e
	if _ecrans_voile:
		_ecrans_voile.visible = e != "cosmetique"
	info("")
	if etait_boutique != (e == "cosmetique"):
		boutique.emit(e == "cosmetique")
	match e:
		"titre":
			_maj_salut()
		"creer":
			if _champ_lobby.text.strip_edges() == "":
				_champ_lobby.text = Langue.t("Le village de %s") % nom
		"code":
			_champ_code.text = ""
			_champ_code.secret = Streamer.mode_actif()   # mode streamer : le code saisi ne s'affiche pas
			_champ_code.grab_focus.call_deferred()
		"liste":
			_actualiser_liste()
		"villageois":
			_champ_nom.text = nom
			_rafraichir_apercu()
			_rafraichir_niveau()
		"succes":
			_succes_ui.rafraichir()
		"cosmetique":
			_boutique.ouvrir(apparence)
		"regles":
			_afficher_regle(_regle_depart)


## Échap : un cran en arrière. Faux si on est déjà au titre.
func retour() -> bool:
	if not PARENTS.has(_actuel):
		return false
	_quitter_ecran()
	ecran(PARENTS[_actuel])
	return true


func info(texte: String) -> void:
	if _info:
		_info.text = texte


func _quitter_ecran() -> void:
	if _actuel == "villageois":
		_valider_nom()


func _process(delta: float) -> void:
	if not visible:
		return
	if _apercu and _actuel == "villageois":
		_apercu.rotation.y += delta * 0.4
	if _actuel == "liste":
		_liste_t += delta
		if _liste_t >= ACTUALISER_LISTE:
			_actualiser_liste()


# ---------------------------------------------------------------- la nuit guidée

## Au tout premier lancement : « Première fois ? Une nuit guidée de 5 minutes ». Commencer, ou plus tard
## (elle reste dans Jouer › Nuit guidée et dans Comment jouer).
func proposer_nuit_guidee() -> void:
	if _proposition != null or not visible:
		return
	_proposition = Control.new()
	_proposition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_proposition.mouse_filter = Control.MOUSE_FILTER_STOP
	var fond := ColorRect.new()
	fond.color = Color(0.01, 0.005, 0.015, 0.7)
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_proposition.add_child(fond)
	var cadre := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.03, 0.035, 0.96)
	style.border_color = Color(0.72, 0.55, 0.3, 0.8)
	style.set_border_width_all(1)
	style.border_width_top = 3
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size = 30
	style.content_margin_left = 54
	style.content_margin_right = 54
	style.content_margin_top = 38
	style.content_margin_bottom = 34
	cadre.add_theme_stylebox_override("panel", style)
	cadre.set_anchors_preset(Control.PRESET_CENTER)
	cadre.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cadre.grow_vertical = Control.GROW_DIRECTION_BOTH
	_proposition.add_child(cadre)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	cadre.add_child(v)
	v.add_child(_label("Première fois ?", 54, EcranJeu.OR, "titre"))
	var texte := _label("Une nuit guidée de 5 minutes : tu marches, tu parles, tu votes, tu fais une quête, puis tu vis une nuit en loup. Seul, avec des bots, dans le vrai village. Rien ne compte, personne ne te regarde.", 25, Color(0.95, 0.92, 0.88), "italique")
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte.custom_minimum_size.x = 640
	v.add_child(texte)
	var boutons := HBoxContainer.new()
	boutons.add_theme_constant_override("separation", 40)
	boutons.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(boutons)
	var commencer := _grand_bouton("Commencer", func():
		_fermer_proposition()
		nuit_guidee.emit(), 38, true)
	boutons.add_child(commencer)
	boutons.add_child(_grand_bouton("Plus tard", func():
		_fermer_proposition()
		nuit_guidee_refusee.emit(), 38))
	add_child(_proposition)
	commencer.grab_focus.call_deferred()


func _fermer_proposition() -> void:
	if _proposition != null:
		_proposition.queue_free()
		_proposition = null


# ---------------------------------------------------------------- titre

func _construire_titre() -> void:
	var c := MarginContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_theme_constant_override("margin_left", 90)
	c.add_theme_constant_override("margin_top", 70)
	c.add_theme_constant_override("margin_bottom", 70)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	var titre := _label("Nuit Blanche", 96, EcranJeu.ROUGE, "titre")
	titre.add_theme_color_override("font_shadow_color", Color(0.9, 0.1, 0.05, 0.45))
	titre.add_theme_constant_override("shadow_outline_size", 22)
	titre.add_theme_constant_override("shadow_offset_x", 0)
	titre.add_theme_constant_override("shadow_offset_y", 0)
	v.add_child(titre)
	v.add_child(_label("Personne ne dort vraiment dans ce village.", 24, Color(0.93, 0.82, 0.62, 0.75), "italique"))
	var vide := Control.new()
	vide.custom_minimum_size.y = 40
	v.add_child(vide)
	v.add_child(_grand_bouton("Jouer", func(): ecran("jouer"), 46, true))
	v.add_child(_grand_bouton("Mon personnage", func(): ecran("villageois")))
	v.add_child(_grand_bouton("Cosmétique", func(): ecran("cosmetique")))
	v.add_child(_grand_bouton("Comment jouer", func(): ecran("regles")))
	v.add_child(_grand_bouton("Réglages", func(): ecran("options")))
	v.add_child(_grand_bouton("Quitter", func(): quitter_jeu.emit()))
	var bas := Control.new()
	bas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bas)
	_salut = HBoxContainer.new()
	_salut.add_theme_constant_override("separation", 12)
	v.add_child(_salut)
	_ecrans["titre"] = c


func _maj_salut() -> void:
	for e in _salut.get_children():
		e.queue_free()
	_salut.add_child(Visages.icone(apparence, 48))
	_salut.add_child(_label("Tu joues : %s" % nom, 24, Color(0.93, 0.82, 0.62, 0.9), "italique"))


# ---------------------------------------------------------------- jouer

func _construire_jouer() -> void:
	# Plus une liste : des cartes qu'on survole (demande d'Edwin, 30/10 : « plus ludique et sympa »).
	var v := _panneau("jouer", "Jouer")
	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", 22)
	haut.add_child(_carte("lanterne", "Créer un lobby", "Ouvre ton village\net invite tes amis.", func(): ecran("creer"), Color(1.0, 0.42, 0.25)))
	haut.add_child(_carte("cle", "Rejoindre", "Entre le code\nqu'on t'a donné.", func(): ecran("code"), EcranJeu.OR))
	haut.add_child(_carte("feu", "Lobbies ouverts", "Les villages qui\ncherchent du monde.", func(): ecran("liste"), Color(0.55, 0.75, 0.95)))
	v.add_child(haut)
	var bas := HBoxContainer.new()
	bas.add_theme_constant_override("separation", 22)
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	bas.add_child(_carte("lanterne", "Nuit guidée", "Apprendre en 5 minutes.", func(): nuit_guidee.emit(), Color(0.95, 0.78, 0.45), true))
	bas.add_child(_carte("loup", "S'entraîner", "Seul, avec des bots.", func(): essai_bots.emit(), Color(0.6, 0.85, 0.55), true))
	bas.add_child(_carte("rouage", "Mode test", "Tout essayer.\nF10 en partie.", func(): mode_test.emit(), Color(0.75, 0.65, 0.9), true))
	v.add_child(bas)


func _construire_creer() -> void:
	var v := _panneau("creer", "Créer un lobby")
	# Rangé par catégories (Edwin, 29/10) ; les places, les loups, les rôles et le rythme se
	# règlent ensuite, dans le salon, tant que la partie n'a pas commencé.
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 12)
	g.add_child(_label("Nom du lobby", 22))
	_champ_lobby = LineEdit.new()
	_champ_lobby.max_length = 32
	_champ_lobby.custom_minimum_size.x = 380
	g.add_child(_champ_lobby)
	g.add_child(_label("Langue parlée", 22))
	_choix_langue = OptionButton.new()
	for l in Annuaire.LANGUES:
		_choix_langue.add_item(l[1])
		_choix_langue.set_item_metadata(_choix_langue.item_count - 1, l[0])
	_choisir(_choix_langue, Annuaire.langue_du_systeme())
	g.add_child(_choix_langue)
	_categorie(v, "Le lobby").add_child(g)
	var acces := _categorie(v, "Qui peut entrer")
	_case_public = CheckBox.new()
	_case_public.text = "Public : il apparaît dans la liste des lobbies ouverts (12 joueurs au plus)"
	_case_public.button_pressed = true
	acces.add_child(_case_public)
	var prive_l := _label("Décoché, le lobby est privé : on n'y entre qu'avec le code, jusqu'à 16 joueurs.", 17, Color(1, 1, 1, 0.6))
	acces.add_child(prive_l)
	acces.add_child(_label("Dans les deux cas, tu reçois un code à 5 chiffres à donner à tes amis, même à l'oral.", 17, Color(1, 1, 1, 0.6)))
	var essai := _categorie(v, "Essai")
	_case_bots = CheckBox.new()
	_case_bots.text = "Bots : des villageois de passage prennent les places vides"
	_case_bots.button_pressed = false
	essai.add_child(_case_bots)
	_case_perso = CheckBox.new()
	_case_perso.text = "Partie personnalisée : on peut lancer dès 1 joueur (visiter le village, essayer à deux)"
	_case_perso.button_pressed = false
	essai.add_child(_case_perso)
	essai.add_child(_label("Décochée, c'est une partie classique : 6 joueurs au moins. La liste des lobbies affiche le type.", 17, Color(1, 1, 1, 0.6)))
	v.add_child(_label("Places, loups, rôles et rythme se règlent ensuite, dans le salon.", 17, Color(1, 1, 1, 0.6)))
	v.add_child(_grand_bouton("Créer le lobby", func():
		var n := _champ_lobby.text.strip_edges()
		# Le nom par défaut voyage en français (chacun le lit dans sa langue, via la liste des lobbies).
		if n == "" or n == Langue.t("Le village de %s") % nom or n == Langue.en_de("Le village de %s") % nom:
			n = "Le village de %s" % nom
		creer.emit(n, str(_choix_langue.get_selected_metadata()), _case_public.button_pressed, _case_bots.button_pressed, _case_perso.button_pressed), 30))


## Une catégorie d'un écran du menu : son titre doré, un trait, son contenu.
func _categorie(parent: VBoxContainer, titre: String) -> VBoxContainer:
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
	v.add_child(_label(titre.to_upper(), 19, EcranJeu.OR))
	return v


func _construire_regles() -> void:
	var v := _panneau("regles", "Comment jouer")
	_regle_illu = Illustration.new()
	_regle_illu.custom_minimum_size = Vector2(460, 345)
	_regle_illu.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_regle_titre = _label("", 38, EcranJeu.OR, "titre")
	_regle_texte = VBoxContainer.new()
	_regle_texte.add_theme_constant_override("separation", 14)
	_regle_texte.custom_minimum_size = Vector2(430, 0)
	var corps := HBoxContainer.new()
	corps.add_theme_constant_override("separation", 30)
	corps.add_child(_regle_illu)
	var droite := VBoxContainer.new()
	droite.add_theme_constant_override("separation", 14)
	droite.add_child(_regle_titre)
	droite.add_child(_regle_texte)
	droite.custom_minimum_size.y = 300
	corps.add_child(droite)
	v.add_child(corps)
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 24)
	_regle_prec = _fleche_page("‹", -1)
	_regle_suiv = _fleche_page("›", 1)
	_regle_points = HBoxContainer.new()
	_regle_points.add_theme_constant_override("separation", 10)
	_regle_points.alignment = BoxContainer.ALIGNMENT_CENTER
	_regle_points.custom_minimum_size.x = 200
	for i in REGLES.size():
		var p := Control.new()
		p.custom_minimum_size = Vector2(14, 14)
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		p.set_meta("i", i)
		p.draw.connect(func():
			var actif: bool = i == _regle_i
			p.draw_circle(Vector2(7, 7), 6.0 if actif else 4.0, EcranJeu.OR if actif else Color(1, 1, 1, 0.3)))
		_regle_points.add_child(p)
	nav.add_child(_regle_prec)
	nav.add_child(_regle_points)
	nav.add_child(_regle_suiv)
	v.add_child(nav)
	var guidee := _grand_bouton("Faire la nuit guidée", func(): nuit_guidee.emit(), 28)
	guidee.alignment = HORIZONTAL_ALIGNMENT_CENTER
	guidee.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(guidee)
	_afficher_regle(0)


## Un bouton de page (‹ ou ›), nu comme la flèche de retour.
func _fleche_page(glyphe: String, sens: int) -> Button:
	var b := _fleche(func(): _afficher_regle(_regle_i + sens))
	b.text = glyphe
	b.tooltip_text = ""
	b.add_theme_font_size_override("font_size", 64)
	b.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82, 0.9))
	return b


## Montre la carte `i` (bornée) : illustration, titre, texte avec les touches du joueur.
func _afficher_regle(i: int) -> void:
	_regle_i = clampi(i, 0, REGLES.size() - 1)
	var carte: Array = REGLES[_regle_i]
	_regle_illu.sorte = carte[0]
	_regle_titre.text = carte[1]
	for e in _regle_texte.get_children():
		e.queue_free()
	# Les touches du joueur ressortent en or : {agir} devient [color]E[/color] (ou sa touche réglée).
	var gabarit: String = Langue.t(carte[2])   # la langue d'abord : la clé contient {agir}, pas le BBCode
	var re := RegEx.create_from_string("\\{(\\w+)\\}")
	gabarit = re.sub(gabarit, "[color=#ffd180]{$1}[/color]", true)
	for para: String in Options.avec_touches(gabarit).split("\n\n"):
		# Un RichTextLabel : sa hauteur suit le texte (un Label à retour à la ligne gardait une hauteur gonflée).
		var l := RichTextLabel.new()
		l.bbcode_enabled = true
		l.fit_content = true
		l.scroll_active = false
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_override("normal_font", Style.police("texte"))
		l.add_theme_font_size_override("normal_font_size", 23)
		l.add_theme_color_override("default_color", Color(0.95, 0.92, 0.88))
		l.text = para
		l.custom_minimum_size.x = 430
		_regle_texte.add_child(l)
	_regle_prec.disabled = _regle_i == 0
	_regle_suiv.disabled = _regle_i == REGLES.size() - 1
	_regle_prec.modulate.a = 0.25 if _regle_prec.disabled else 1.0
	_regle_suiv.modulate.a = 0.25 if _regle_suiv.disabled else 1.0
	for p in _regle_points.get_children():
		p.queue_redraw()


## [dessin, titre, texte]. Les touches s'écrivent {action} : elles suivent les réglages du joueur
## (et deviennent le bouton de la manette quand on en tient une).
const REGLES := [
	["but", "Le but",
		"Des loups se cachent parmi vous.

Le village gagne quand tous les loups sont morts.
La meute gagne quand le village est tombé."],
	["jour", "Le jour : les quêtes",
		"Au début, personne n'a de rôle : on le gagne aux quêtes.

Chaque matin, le village vote pour une quête (touches 1 à 4, ou « Rester »). On part ensemble, on réussit ensemble.

Méfie-toi : les loups sabotent en douce."],
	["conseil", "Le Conseil",
		"La cloche sonne : tout le monde s'assoit autour du feu.

Débattez, puis votez : fixe du regard celui que tu accuses et clique."],
	["nuit", "La nuit",
		"Chacun rentre chez soi. Les loups se retrouvent masqués à la pierre et désignent une victime.

Les autres rôles agissent en secret.

Au matin, on découvre qui est tombé (son rôle reste caché)."],
	["roles", "Les rôles",
		"17 rôles : liseuse d'âmes, herboriste, trappeur, veilleur… et des loups.

Ton rôle reste écrit en haut à droite de l'écran."],
	["touches_bouger", "Les touches : bouger",
		"{avancer} avancer · {gauche} à gauche · {reculer} reculer · {droite} à droite

Maintiens {sprint} pour courir, appuie sur {sauter} pour sauter, maintiens {accroupir} pour t'accroupir (on marche plus lentement ; une animation te relève).

La souris te sert à regarder autour de toi. Une manette ? Branche-la, elle marche aussi (Réglages > Manette)."],
	["touches_agir", "Les touches : agir",
		"{agir}  agir (porte, tableau, s'asseoir)
{pouvoir}  le pouvoir de ton rôle
{lire}  lire / écrire (carnet, page)
{poser}  lâcher l'objet que tu tiens (livre, carnet…)
{jeter}  jeter l'objet que tu tiens (il vole, retombe, se ramasse)
{mordre}  mordre (vampire)
{emotes}  animations (gestes et danses)
Clic gauche  face à quelqu'un : interagir (pousser, chut, poignée de main…) · {interagir} marche aussi
1 à 4  prendre en main l'objet de l'emplacement (la même touche le range)
Clic droit  caillou : lancer · livre : l'ouvrir, puis écrire — clic gauche tenu : viser, clic gauche : fermer le livre
{pret}  passer au vote, au retour des quêtes
{passer}  passer l'étape (l'hôte)"],
	["touches_voix", "Les touches : parler",
		"{parler}  parler (si « appuyer pour parler »)
{portee}  chuchoter, parler ou crier
{volumes}  le volume de chaque joueur
{miroir}  montrer / cacher le miroir
[color=#ffd180]Échap[/color]  la pause · {reseau}  le diagnostic réseau

On t'entend de près seulement : chuchote, éloigne-toi… ou tends l'oreille.

Tu peux changer chaque touche dans les Réglages."],
]


func _construire_code() -> void:
	var v := _panneau("code", "Rejoindre avec un code")
	v.add_child(_label("Le code à 5 chiffres que l'hôte t'a donné :", 22))
	_champ_code = LineEdit.new()
	_champ_code.max_length = 5
	_champ_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_champ_code.placeholder_text = "_ _ _ _ _"
	_champ_code.add_theme_font_size_override("font_size", 64)
	_champ_code.custom_minimum_size = Vector2(340, 96)
	_champ_code.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_champ_code.text_changed.connect(func(t: String):
		var chiffres := ""
		for ch in t:
			if ch >= "0" and ch <= "9":
				chiffres += ch
		if chiffres != t:
			_champ_code.text = chiffres
			_champ_code.caret_column = chiffres.length())
	_champ_code.text_submitted.connect(func(_t): _valider_code())
	v.add_child(_champ_code)
	v.add_child(_grand_bouton("Rejoindre", _valider_code, 30))


func _valider_code() -> void:
	var c := _champ_code.text.strip_edges()
	if not Annuaire.code_valide(c):
		info("Il faut les 5 chiffres du code.")
		return
	rejoindre.emit(c)


# ---------------------------------------------------------------- lobbies ouverts

func _construire_liste() -> void:
	var v := _panneau("liste", "Lobbies ouverts")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.add_child(_label("Langue", 22))
	_filtre = OptionButton.new()
	_filtre.add_item("Toutes les langues")
	_filtre.set_item_metadata(0, "")
	for l in Annuaire.LANGUES:
		_filtre.add_item(l[1])
		_filtre.set_item_metadata(_filtre.item_count - 1, l[0])
	_choisir(_filtre, Annuaire.langue_du_systeme())
	_filtre.item_selected.connect(func(_i): _afficher_liste())
	h.add_child(_filtre)
	h.add_child(_bouton("Actualiser", _actualiser_liste))
	v.add_child(h)
	var defile := ScrollContainer.new()
	defile.custom_minimum_size = Vector2(820, 380)
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_liste_boite = VBoxContainer.new()
	_liste_boite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liste_boite.add_theme_constant_override("separation", 8)
	defile.add_child(_liste_boite)
	v.add_child(defile)


func _actualiser_liste() -> void:
	_liste_t = 0.0
	Lobbies.lister()


func _sur_liste(lobbies: Array) -> void:
	_lobbies = lobbies
	_afficher_liste()


func _afficher_liste() -> void:
	for e in _liste_boite.get_children():
		e.queue_free()
	var langue := str(_filtre.get_selected_metadata())
	var montres := Annuaire.filtrer(_lobbies, langue)
	if montres.is_empty():
		var texte := "Aucun lobby ouvert pour l'instant." if langue == "" else \
			"Aucun lobby ouvert en %s pour l'instant." % Annuaire.nom_langue(langue)
		_liste_boite.add_child(_label(texte + "\nCrée le tien, ou regarde les autres langues.", 20, Color(1, 1, 1, 0.65)))
		return
	for m: Dictionary in montres:
		_liste_boite.add_child(_ligne_lobby(m))


func _ligne_lobby(m: Dictionary) -> Control:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.07, 0.07, 0.9)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", style)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var gauche := VBoxContainer.new()
	gauche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var titre := _label(str(m.get("nom", "Lobby")), 22)
	titre.clip_text = true
	titre.custom_minimum_size.x = 220
	gauche.add_child(titre)
	var joueurs: Array = m.get("joueurs", [])
	var infos := HBoxContainer.new()
	infos.add_theme_constant_override("separation", 10)
	var perso := bool(m.get("perso", false))
	infos.add_child(_label("Personnalisée" if perso else "Classique", 16,
		Color(0.55, 0.75, 0.95) if perso else EcranJeu.OR))
	infos.add_child(_label("%s  ·  %d / %d joueurs" % [Annuaire.nom_langue(str(m.get("langue", ""))), joueurs.size(), int(m.get("places", 8))],
		16, Color(1, 1, 1, 0.6)))
	gauche.add_child(infos)
	h.add_child(gauche)
	var icones := HBoxContainer.new()
	icones.add_theme_constant_override("separation", 4)
	for j: Dictionary in joueurs.slice(0, 8):
		var ic := Visages.icone(int(j.get("a", 0)), 40)
		ic.tooltip_text = str(j.get("n", ""))
		ic.mouse_filter = Control.MOUSE_FILTER_STOP
		icones.add_child(ic)
	if joueurs.size() > 8:
		icones.add_child(_label("+%d" % (joueurs.size() - 8), 18))
	h.add_child(icones)
	var code := str(m.get("code", ""))
	var b := _bouton("  Rejoindre  ", func(): rejoindre.emit(code))
	b.disabled = joueurs.size() >= int(m.get("places", 12))
	h.add_child(b)
	return p


# ---------------------------------------------------------------- mon villageois

func _construire_villageois() -> void:
	var v := _panneau("villageois", "Mon personnage")
	var l1 := HBoxContainer.new()
	l1.add_child(_label("Ton nom  ", 22))
	_champ_nom = LineEdit.new()
	_champ_nom.custom_minimum_size.x = 260
	_champ_nom.max_length = 16
	_champ_nom.text_submitted.connect(func(_t): _valider_nom())
	_champ_nom.focus_exited.connect(_valider_nom)
	l1.add_child(_champ_nom)
	v.add_child(l1)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	var cadre := SubViewportContainer.new()
	cadre.stretch = true
	cadre.custom_minimum_size = Vector2(230, 300)
	_apercu_vue = SubViewport.new()
	_apercu_vue.own_world_3d = true
	cadre.add_child(_apercu_vue)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.04, 0.04)
	env.environment.ambient_light_color = Color(0.3, 0.3, 0.35)
	env.environment.ambient_light_energy = 0.4
	_apercu_vue.add_child(env)
	var lampe := OmniLight3D.new()
	lampe.light_color = Color(1.0, 0.65, 0.35)
	lampe.omni_range = 5.0
	lampe.light_energy = 2.2
	lampe.position = Vector3(0.7, 1.8, 1.2)
	_apercu_vue.add_child(lampe)
	var cam := Camera3D.new()
	cam.fov = 32
	_apercu_vue.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.3, 3.4), Vector3(0, 1.05, 0))
	h.add_child(cadre)
	var grille := GridContainer.new()
	grille.columns = 4
	grille.add_theme_constant_override("h_separation", 8)
	var traits := [["tete", "Tête", Bouille.NOMS_TETES], ["visage", "Visage", Bouille.NOMS_VISAGES],
		["habit", "Habit", Bouille.NOMS_HABITS], ["teinte", "Teinte", TEINTES],
		["matiere", "Étoffe", Bouille.NOMS_MATIERES], ["objet", "Objet", Bouille.NOMS_OBJETS],
		["peau", "Peau", ["Craie", "Rosée", "Cire", "Terre"]], ["yeux", "Yeux", Bouille.NOMS_YEUX], ["corps", "Corps", Bouille.NOMS_CORPS]]
	for t in traits:
		var champ: String = t[0]
		var noms: Array = t[2]
		grille.add_child(_label(t[1] + "  ", 20, Color(1, 1, 1, 0.7)))
		grille.add_child(_bouton(" ◀ ", func(): _changer_trait(champ, -1, noms)))
		var l := _label("", 20)
		l.custom_minimum_size.x = 200
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_choix_labels[champ] = [l, noms]
		grille.add_child(l)
		grille.add_child(_bouton(" ▶ ", func(): _changer_trait(champ, 1, noms)))
	var col := VBoxContainer.new()
	col.add_child(grille)
	col.add_child(_bouton("  Au hasard  ", func():
		apparence = Bouille.au_hasard(_rng)
		_rafraichir_apercu()
		profil_change.emit(nom, apparence)))
	# « Ma tête » : une photo de face sur le visage du villageois.
	col.add_child(_label("Ma tête", 22, EcranJeu.OR))
	var lt := HBoxContainer.new()
	lt.add_child(_bouton("  Prendre ma tête (photo de face)  ", func():
		_info_tete.text = "Regarde la caméra…"
		prendre_tete.emit()))
	lt.add_child(_bouton("  Effacer ma photo  ", func(): effacer_tete.emit()))
	col.add_child(lt)
	_case_tete = CheckBox.new()
	_case_tete.text = "Afficher ma tête sur mon personnage"
	_case_tete.toggled.connect(func(oui):
		_tete_on = oui
		_rafraichir_apercu()
		tete_active.emit(oui))
	col.add_child(_case_tete)
	_info_tete = _label("Seulement dans les lobbies privés (avec ceux qui ont ton code).
La photo ne part sur aucun site.", 15, Color(1, 1, 1, 0.6))
	col.add_child(_info_tete)
	h.add_child(col)
	v.add_child(h)
	# Niveau de villageois et succès (cf. regles/progression.gd).
	var niv := HBoxContainer.new()
	niv.add_theme_constant_override("separation", 18)
	_niveau_titre = _label("", 24, EcranJeu.OR, "titre")
	niv.add_child(_niveau_titre)
	_niveau_barre = ProgressBar.new()
	_niveau_barre.show_percentage = false
	_niveau_barre.max_value = 1.0
	_niveau_barre.custom_minimum_size = Vector2(300, 14)
	_niveau_barre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(1, 1, 1, 0.1)
	fond.set_corner_radius_all(7)
	var plein := StyleBoxFlat.new()
	plein.bg_color = EcranJeu.OR
	plein.set_corner_radius_all(7)
	_niveau_barre.add_theme_stylebox_override("background", fond)
	_niveau_barre.add_theme_stylebox_override("fill", plein)
	niv.add_child(_niveau_barre)
	niv.add_child(_bouton("  Succès  ", func(): ecran("succes")))
	v.add_child(niv)
	_niveau_suite = _label("", 16, Color(1, 1, 1, 0.6))
	v.add_child(_niveau_suite)
	_ajouter_retour(v, "C'est moi")


func _rafraichir_niveau() -> void:
	var b := Progression.barre(Progres.xp())
	_niveau_titre.text = "Niveau %d" % int(b["niveau"])
	_niveau_barre.value = float(b["ratio"])
	var suivant := Progression.prochain_article(int(b["niveau"]))
	# Deux phrases entières, chacune traduite (jamais de morceaux collés).
	var texte := Langue.t("%d / %d d'expérience vers le niveau %d.") % [int(b["dans"]), int(b["pour"]), int(b["niveau"]) + 1] if int(b["pour"]) > 0 else Langue.t("Niveau maximum.")
	if suivant != "":
		texte += "  " + Langue.t("Prochain cosmétique offert : %s (niveau %d).") % [Langue.t(str(Cosmetiques.article(suivant)["nom"])), Cosmetiques.niveau_requis(suivant)]
	_niveau_suite.text = texte


func _construire_succes() -> void:
	var v := _panneau("succes", "Succès")
	_succes_ui = SuccesUi.new()
	v.add_child(_succes_ui)
	_ajouter_retour(v, "◀  Retour")


func _valider_nom() -> void:
	var n := _champ_nom.text.strip_edges()
	if n != "" and n != nom:
		nom = n
		profil_change.emit(nom, apparence)


func _changer_trait(champ: String, sens: int, noms: Array) -> void:
	var a := Bouille.decoder(apparence)
	a[champ] = posmod(int(a[champ]) + sens, noms.size())
	apparence = Bouille.coder(a)
	_rafraichir_apercu()
	profil_change.emit(nom, apparence)


## Ma photo (ou rien) et la case cochée ou non, lues au démarrage puis après chaque photo.
func regler_tete(tete: Array, active: bool, info := "") -> void:
	_tete = tete
	_tete_on = active and not tete.is_empty()
	_case_tete.set_pressed_no_signal(_tete_on)
	_case_tete.disabled = tete.is_empty()
	if info != "":
		_info_tete.text = info
	_rafraichir_apercu()


func _rafraichir_apercu() -> void:
	var a := Bouille.decoder(apparence)
	for champ in _choix_labels:
		var l: Label = _choix_labels[champ][0]
		var noms: Array = _choix_labels[champ][1]
		l.text = noms[int(a[champ]) % noms.size()]
	var angle := 0.0
	if _apercu:
		angle = _apercu.rotation.y
		_apercu.queue_free()
	_apercu = Bouille.new()
	_apercu.apparence = a
	_apercu.rotation.y = angle
	_apercu_vue.add_child(_apercu)
	_apercu.regarder(Vector3(0, 1.6, 3.4))
	if _tete_on and _tete.size() == 2:
		_apercu.poser_photo(_tete[0], _tete[1])


# ---------------------------------------------------------------- cosmétique

func _construire_boutique() -> void:
	_boutique = Boutique.new()
	add_child(_boutique)
	_ecrans["cosmetique"] = _boutique
	# Le bouton du bas est à la boutique ; la flèche du haut est la même que partout ailleurs.
	_fleche_boutique = _fleche()
	_fleche_boutique.position = Vector2(24, 18)
	_boutique.add_child(_fleche_boutique)
	_boutique.retour_demande.connect(func(): retour())
	_boutique.essai.connect(func(a: int, article: String): essai_cosmetique.emit(a, article))
	_boutique.portee.connect(func(a: int):
		apparence = a
		profil_change.emit(nom, apparence))


# ---------------------------------------------------------------- réglages

func page_reglages(id: String) -> void:
	_reglages._montrer(id)


func _construire_options() -> void:
	var v := _panneau("options", "Réglages")
	_reglages = PanneauReglages.new()
	_reglages.petite_machine.connect(func(oui): petite = oui; petite_machine.emit(oui))
	_reglages.reglage_regard.connect(func(): reglage_regard.emit())
	v.add_child(_reglages)


## La case « petite machine » suit le réglage enregistré (lu après la construction).
func regler_petite(oui: bool) -> void:
	petite = oui
	_reglages.regler_petite(oui)


# ---------------------------------------------------------------- briques

func _panneau(cle: String, titre: String) -> VBoxContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.03, 0.035, 0.9)
	style.border_color = Color(0.72, 0.55, 0.3, 0.7)
	style.set_border_width_all(1)
	style.border_width_top = 3
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size = 30
	style.content_margin_left = 44
	style.content_margin_right = 44
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	p.add_theme_stylebox_override("panel", style)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	p.add_child(v)
	var t := _label(titre, 52, EcranJeu.OR, "titre")
	t.add_theme_color_override("font_shadow_color", Color(1.0, 0.6, 0.2, 0.3))
	t.add_theme_constant_override("shadow_outline_size", 14)
	t.add_theme_constant_override("shadow_offset_x", 0)
	t.add_theme_constant_override("shadow_offset_y", 0)
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 18)
	tete.add_child(_fleche())
	tete.add_child(t)
	v.add_child(tete)
	var filet := ColorRect.new()
	filet.color = Color(0.85, 0.15, 0.08, 0.7)
	filet.custom_minimum_size = Vector2(120, 2)
	filet.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(filet)
	add_child(p)
	_ecrans[cle] = p
	return v


## La flèche « ← » des sous-écrans : même effet qu'Échap (un cran en arrière), rien d'autre.
func _fleche(action := Callable()) -> Button:
	var b := Button.new()
	b.text = "←"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Retour (Échap)"
	b.custom_minimum_size = Vector2(56, 56)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 40)
	b.add_theme_color_override("font_color", Color(0.93, 0.82, 0.62, 0.8))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.82))
	b.add_theme_color_override("font_pressed_color", EcranJeu.OR)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 6)
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(func(): _animer(b, 1.15))
	b.mouse_exited.connect(func(): _animer(b, 1.0))
	b.pressed.connect(action if action.is_valid() else func(): retour())
	return b


func _ajouter_retour(v: VBoxContainer, texte := "◀  Retour") -> void:
	v.add_child(_grand_bouton(texte, func(): retour(), 26))


## Une plaque (décision du 30/10, Edwin : « écriture simple blanche sans style ») : en petites
## capitales, un trait doré à gauche au repos ; au survol elle s'allume de rouge et grandit.
func _grand_bouton(texte: String, action: Callable, taille := 40, premier := false) -> Button:
	var b := Button.new()
	b.text = texte
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", Style.police("titre"))
	b.add_theme_font_size_override("font_size", taille)
	var repos := EcranJeu.OR.lerp(Color.WHITE, 0.25) if premier else Color(0.9, 0.84, 0.74)
	b.add_theme_color_override("font_color", repos)
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.82))
	b.add_theme_color_override("font_pressed_color", EcranJeu.OR)
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.94, 0.82))
	b.add_theme_color_override("font_hover_pressed_color", EcranJeu.OR)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 8)
	var calme := StyleBoxFlat.new()
	calme.bg_color = Color(0, 0, 0, 0)
	calme.border_color = Color(0.72, 0.55, 0.3, 0.6 if premier else 0.3)
	calme.border_width_left = 3
	calme.content_margin_left = 18
	calme.content_margin_right = 26
	calme.content_margin_top = 2
	calme.content_margin_bottom = 6
	var vif := calme.duplicate() as StyleBoxFlat
	vif.bg_color = Color(0.5, 0.05, 0.03, 0.6)
	vif.border_color = Color(1.0, 0.38, 0.15)
	vif.border_width_left = 6
	# Mêmes marges qu'au repos : un Button ne mesure sa largeur que sur « normal » ; 12 px de plus
	# au survol poussaient la dernière lettre hors du bouton, où elle était rognée.
	vif.content_margin_left = calme.content_margin_left
	vif.corner_radius_top_right = 6
	vif.corner_radius_bottom_right = 6
	vif.shadow_color = Color(0.9, 0.15, 0.05, 0.35)
	vif.shadow_size = 16
	for etat in ["normal", "disabled"]:
		b.add_theme_stylebox_override(etat, calme)
	for etat in ["hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(etat, vif)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.resized.connect(func(): b.pivot_offset = Vector2(0, b.size.y * 0.5))
	b.mouse_entered.connect(func(): _animer(b, 1.05))
	b.mouse_exited.connect(func(): _animer(b, 1.0))
	b.pressed.connect(action)
	return b


## Survol : grandir (ou revenir) en douceur, avec un léger rebond.
func _animer(c: Control, echelle: float) -> void:
	if c.has_meta("anim"):
		var ancien: Tween = c.get_meta("anim")
		if ancien and ancien.is_valid():
			ancien.kill()
	var t := c.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2.ONE * echelle, 0.18)
	c.set_meta("anim", t)


## Une carte de l'écran « Jouer » : un dessin animé, un titre, deux lignes ; au survol elle
## grandit et s'éclaire de sa couleur.
func _carte(dessin: String, titre: String, texte: String, action: Callable, teinte: Color, petite := false) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(260, 180) if petite else Vector2(260, 270)
	var calme := StyleBoxFlat.new()
	calme.bg_color = Color(0.09, 0.06, 0.06, 0.92)
	calme.border_color = Color(teinte, 0.35)
	calme.set_border_width_all(2)
	calme.set_corner_radius_all(14)
	calme.shadow_color = Color(0, 0, 0, 0.6)
	calme.shadow_size = 12
	var vif := calme.duplicate() as StyleBoxFlat
	vif.bg_color = Color(teinte.darkened(0.8), 0.96)
	vif.border_color = teinte
	vif.set_border_width_all(3)
	vif.shadow_color = Color(teinte, 0.45)
	vif.shadow_size = 24
	for etat in ["normal", "disabled"]:
		b.add_theme_stylebox_override(etat, calme)
	for etat in ["hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(etat, vif)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var icone := Icone.new()
	icone.sorte = dessin
	icone.teinte = teinte
	icone.custom_minimum_size = Vector2(0, 58 if petite else 96)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icone)
	var t := _label(titre, 30 if petite else 34, Color(1.0, 0.94, 0.84), "titre")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := _label(texte, 19, Color(0.9, 0.84, 0.74, 0.8), "italique")
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(func():
		icone.allume = true
		_animer(b, 1.06))
	b.mouse_exited.connect(func():
		icone.allume = false
		_animer(b, 1.0))
	b.pressed.connect(action)
	return b


## Le fond du menu reste le village ; seul le bord gauche s'assombrit pour qu'on lise.
func _construire_voile() -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0.8), Color(0, 0, 0, 0.4), Color(0, 0, 0, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	r.offset_right = 860
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	_ecrans_voile = r

func _bouton(texte: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.pressed.connect(action)
	return b


func _label(texte: String, taille := 22, couleur := Color.WHITE, sorte := "texte") -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_override("font", Style.police(sorte))
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _choisir(o: OptionButton, valeur: String) -> void:
	for i in o.item_count:
		if str(o.get_item_metadata(i)) == valeur:
			o.select(i)


## Les petits dessins des cartes, tracés par le code : lanterne, clé, feu de camp, loup, rouage.
class Icone extends Control:
	var sorte := "lanterne"
	var teinte := Color.WHITE
	var allume := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta * (2.5 if allume else 1.0)
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		var e := size.y / 96.0
		var trait_ := Color(teinte, 0.95 if allume else 0.75)
		var lueur := Color(teinte, (0.26 if allume else 0.1) + 0.05 * sin(_t * 3.0))
		draw_circle(c, 42.0 * e, lueur)
		draw_circle(c, 30.0 * e, Color(teinte, lueur.a * 0.8))
		var w := 3.0 * e
		match sorte:
			"lanterne":
				draw_rect(Rect2(c + Vector2(-13, -14) * e, Vector2(26, 32) * e), trait_, false, w)
				draw_line(c + Vector2(-16, -14) * e, c + Vector2(16, -14) * e, trait_, w)
				draw_line(c + Vector2(0, -14) * e, c + Vector2(0, -24) * e, trait_, w)
				draw_arc(c + Vector2(0, -28) * e, 5.0 * e, 0, TAU, 12, trait_, w * 0.7)
				var f := 1.0 + 0.18 * sin(_t * 9.0)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, 2 - 12 * f) * e, c + Vector2(6, 10) * e, c + Vector2(-6, 10) * e]), Color(1.0, 0.75, 0.3))
			"cle":
				draw_arc(c + Vector2(-14, 0) * e, 11.0 * e, 0, TAU, 20, trait_, w)
				draw_line(c + Vector2(-3, 0) * e, c + Vector2(26, 0) * e, trait_, w)
				draw_line(c + Vector2(17, 0) * e, c + Vector2(17, 10) * e, trait_, w)
				draw_line(c + Vector2(24, 0) * e, c + Vector2(24, 8) * e, trait_, w)
			"feu":
				for k in 3:
					var x := (k - 1) * 10.0
					var hf := 22.0 + 6.0 * sin(_t * 7.0 + k * 2.0)
					draw_colored_polygon(PackedVector2Array([c + Vector2(x - 7, 12) * e, c + Vector2(x, 12 - hf) * e, c + Vector2(x + 7, 12) * e]), Color(1.0, 0.4 + 0.18 * k, 0.15, 0.9))
				draw_line(c + Vector2(-20, 17) * e, c + Vector2(20, 11) * e, trait_, w * 1.3)
				draw_line(c + Vector2(-20, 11) * e, c + Vector2(20, 17) * e, trait_, w * 1.3)
			"loup":
				var tete := PackedVector2Array([c + Vector2(-20, -18) * e, c + Vector2(-9, -6) * e, c + Vector2(9, -6) * e,
					c + Vector2(20, -18) * e, c + Vector2(17, 5) * e, c + Vector2(0, 22) * e, c + Vector2(-17, 5) * e, c + Vector2(-20, -18) * e])
				draw_polyline(tete, trait_, w)
				var oeil := Color(1.0, 0.85, 0.3) if allume else trait_
				draw_circle(c + Vector2(-7, 2) * e, 2.8 * e, oeil)
				draw_circle(c + Vector2(7, 2) * e, 2.8 * e, oeil)
			"rouage":
				var a0 := _t * 0.6
				for k in 8:
					var a := a0 + k * TAU / 8.0
					draw_line(c + Vector2(cos(a), sin(a)) * 14.0 * e, c + Vector2(cos(a), sin(a)) * 22.0 * e, trait_, w * 1.6)
				draw_arc(c, 15.0 * e, 0, TAU, 24, trait_, w)
				draw_arc(c, 6.0 * e, 0, TAU, 16, trait_, w)


## Les illustrations de « Comment jouer » : de vraies vues du village (images/regles/*.jpg, prises
## dans la scène du jeu), encadrées comme des gravures, avec un peu de vie par-dessus (feu, braises,
## yeux de loup) ; les pages « rôles » et « touches » sont dessinées sur un parchemin sombre.
class Illustration extends Control:
	const OR := Color(1.0, 0.82, 0.5)
	const OR_VIF := Color(1.0, 0.9, 0.62)
	const SANG := Color(0.85, 0.12, 0.08)
	const ENCRE := Color(0.05, 0.03, 0.03)
	const PAPIER := Color(0.92, 0.86, 0.72)
	## Légende de la plaque + pistes d'illustration (clichés) par sorte.
	const LEGENDES := {
		"but": "LE VILLAGE DE NUIT", "jour": "AU TABLEAU DES QUÊTES", "conseil": "AUTOUR DU FEU",
		"nuit": "ILS RÔDENT…", "roles": "17 RÔLES, 17 SECRETS", "touches_bouger": "SE DÉPLACER",
		"touches_agir": "AGIR", "touches_voix": "PARLER ET LE RESTE"}
	## Les touches dessinées : [action ou "=texte", libellé, x, y, largeur] par page.
	const CLAVIERS := {
		"touches_bouger": [
			["avancer", "Avancer", 202, 22, 56], ["gauche", "Gauche", 126, 108, 56],
			["reculer", "Reculer", 202, 108, 56], ["droite", "Droite", 278, 108, 56],
			["sprint", "Sprinter", 40, 194, 120], ["sauter", "Sauter", 196, 194, 224]],
		"touches_agir": [
			["agir", "Agir", 60, 22, 56], ["pouvoir", "Pouvoir", 202, 22, 56], ["lire", "Lire / écrire", 344, 22, 56],
			["poser", "Lâcher", 60, 110, 56], ["mordre", "Mordre", 202, 110, 56], ["emotes", "Animations", 344, 110, 56],
			["role", "Fiche de rôle", 60, 198, 56], ["pret", "Passer au vote", 202, 198, 56], ["passer", "Passer (hôte)", 344, 198, 56]],
		"touches_voix": [
			["parler", "Parler", 60, 52, 56], ["portee", "Chuchoter / crier", 202, 52, 56], ["volumes", "Volumes", 344, 52, 56],
			["miroir", "Miroir", 60, 156, 56], ["=Échap", "Pause", 202, 156, 56], ["reseau", "Réseau", 344, 156, 56]],
	}
	static var _images := {}
	var sorte := "but":
		set(v):
			sorte = v
			queue_redraw()
	var _t := 0.0
	var _cap_haut := StyleBoxFlat.new()
	var _cap_pied := StyleBoxFlat.new()

	func _init() -> void:
		for sb: StyleBoxFlat in [_cap_haut, _cap_pied]:
			sb.set_corner_radius_all(10)
			sb.anti_aliasing = true
		_cap_haut.set_border_width_all(2)
		_cap_haut.shadow_size = 0
		_cap_pied.bg_color = Color(0.03, 0.02, 0.02)
		_cap_pied.set_border_width_all(2)
		_cap_pied.border_color = Color(0.45, 0.32, 0.16)

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_t += delta
			queue_redraw()

	# ------------------------------------------------------------ petits outils

	func _police(sorte_police: String) -> Font:
		return Style.police(sorte_police)

	func _texte(p: Vector2, t: String, taille: int, c: Color, largeur := -1.0, police := "texte", ombre := true) -> void:
		var f := _police(police)
		if ombre:
			draw_string(f, p + Vector2(1.5, 1.5), t, HORIZONTAL_ALIGNMENT_CENTER if largeur > 0.0 else HORIZONTAL_ALIGNMENT_LEFT, largeur, taille, Color(0, 0, 0, 0.8))
		draw_string(f, p, t, HORIZONTAL_ALIGNMENT_CENTER if largeur > 0.0 else HORIZONTAL_ALIGNMENT_LEFT, largeur, taille, c)

	## Un fondu entre deux couleurs sur un rectangle (haut → bas, ou gauche → droite).
	func _fondu(r: Rect2, c0: Color, c1: Color, vertical := true) -> void:
		var pts := PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)])
		var cols := PackedColorArray([c0, c0 if vertical else c1, c1, c1 if vertical else c0])
		draw_polygon(pts, cols)

	## Une lueur douce : cercles concentriques de plus en plus pâles.
	func _lueur(c: Vector2, rayon: float, couleur: Color, force := 1.0) -> void:
		for k in 18:
			var f := 1.0 - k / 18.0
			draw_circle(c, rayon * (0.15 + 0.85 * f * f), Color(couleur, couleur.a * force * 0.07 * (1.0 - f * 0.6)))

	func _vignette(r: Rect2, force := 0.7) -> void:
		var e := minf(r.size.x, r.size.y) * 0.34
		var n := Color(0.01, 0.005, 0.01, force)
		var z := Color(n, 0.0)
		_fondu(Rect2(r.position, Vector2(r.size.x, e)), n, z)
		_fondu(Rect2(r.position + Vector2(0, r.size.y - e), Vector2(r.size.x, e)), z, n)
		_fondu(Rect2(r.position, Vector2(e, r.size.y)), n, z, false)
		_fondu(Rect2(r.position + Vector2(r.size.x - e, 0), Vector2(e, r.size.y)), z, n, false)

	## Parchemin sombre taché (déterministe : pas de scintillement d'une image à l'autre).
	func _parchemin(r: Rect2) -> void:
		_fondu(r, Color(0.2, 0.14, 0.09), Color(0.1, 0.065, 0.05))
		var rng := RandomNumberGenerator.new()
		rng.seed = 424242
		for k in 46:
			var c := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
			var rayon := 12.0 + rng.randf() * 44.0
			draw_circle(c, rayon, Color(0.34, 0.22, 0.1, 0.035 + rng.randf() * 0.03))
		for k in 26:
			var y := r.position.y + rng.randf() * r.size.y
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y + rng.randf_range(-3.0, 3.0)), Color(0.0, 0.0, 0.0, 0.05), 1.0)
		_lueur(r.get_center() + Vector2(0, -10), r.size.x * 0.62, Color(1.0, 0.62, 0.25, 0.1), 1.0)
		_vignette(r, 0.55)

	## Le cadre : bois sombre, filet d'or encré, équerres aux coins, plaque légendée en bas.
	func _cadre(photo: bool) -> void:
		var s := size
		# L'extérieur : le bois du cadre (la photo ou le parchemin est dessiné avant, on fait la bordure par-dessus).
		var bois := Color(0.1, 0.06, 0.04)
		draw_rect(Rect2(0, 0, s.x, 8), bois)
		draw_rect(Rect2(0, s.y - 8, s.x, 8), bois)
		draw_rect(Rect2(0, 0, 8, s.y), bois)
		draw_rect(Rect2(s.x - 8, 0, 8, s.y), bois)
		draw_rect(Rect2(Vector2.ZERO, s), Color(OR, 0.9), false, 2.0)
		draw_rect(Rect2(Vector2(8, 8), s - Vector2(16, 16)), Color(ENCRE, 0.9), false, 2.0)
		draw_rect(Rect2(Vector2(12, 12), s - Vector2(24, 24)), Color(OR, 0.55), false, 1.2)
		# Les équerres (un petit losange et deux branches) aux quatre coins.
		for cx in [0, 1]:
			for cy in [0, 1]:
				var c := Vector2(12.0 if cx == 0 else s.x - 12.0, 12.0 if cy == 0 else s.y - 12.0)
				var dx := 1.0 if cx == 0 else -1.0
				var dy := 1.0 if cy == 0 else -1.0
				draw_line(c, c + Vector2(26 * dx, 0), OR, 2.0)
				draw_line(c, c + Vector2(0, 26 * dy), OR, 2.0)
				var d := c + Vector2(7 * dx, 7 * dy)
				draw_colored_polygon(PackedVector2Array([d + Vector2(0, -5), d + Vector2(5, 0), d + Vector2(0, 5), d + Vector2(-5, 0)]), OR)
		# La plaque légendée.
		var legende: String = Langue.t(LEGENDES.get(sorte, ""))
		if legende != "":
			var f := _police("titre")
			var w := f.get_string_size(legende, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 44.0
			var p := Rect2((s.x - w) * 0.5, s.y - 40, w, 26)
			draw_rect(Rect2(p.position + Vector2(0, 3), p.size), Color(0, 0, 0, 0.55))
			draw_rect(p, Color(0.2, 0.04, 0.05, 0.96))
			draw_rect(p, Color(OR, 0.9), false, 1.6)
			draw_rect(p.grow(-3), Color(OR, 0.35), false, 1.0)
			draw_colored_polygon(PackedVector2Array([p.position + Vector2(-9, 13), p.position + Vector2(0, 5), p.position + Vector2(0, 21)]), OR)
			draw_colored_polygon(PackedVector2Array([p.end + Vector2(9, -13), p.end + Vector2(0, -5), p.end + Vector2(0, -21)]), OR)
			draw_string(f, p.position + Vector2(0, 19), legende, HORIZONTAL_ALIGNMENT_CENTER, w, 15, OR_VIF)

	func _photo(nom: String) -> void:
		if not _images.has(nom):
			_images[nom] = load("res://images/regles/%s.jpg" % nom) if ResourceLoader.exists("res://images/regles/%s.jpg" % nom) else null
		var tex: Texture2D = _images[nom]
		if tex:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
		else:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.03, 0.06))
		_vignette(Rect2(Vector2.ZERO, size), 0.62)

	func _scintille(f: float, vitesse: float, decalage: float) -> float:
		return f * (0.8 + 0.2 * sin(_t * vitesse + decalage) * sin(_t * vitesse * 0.63 + decalage * 2.0))

	func _yeux(c: Vector2, e: float, decalage: float) -> void:
		var ouvert := 1.0 if fmod(_t + decalage, 4.3) < 4.0 else 0.15
		var l := 0.7 + 0.3 * sin(_t * 2.2 + decalage)
		for dx in [-1.0, 1.0]:
			var p: Vector2 = c + Vector2(dx * 9.0 * e, 0)
			_lueur(p, 20.0 * e, Color(SANG.r, 0.1, 0.05, 0.6), l)
			var r := PackedVector2Array([p + Vector2(-5 * e, 1.5 * e * ouvert), p + Vector2(0, -3.0 * e * ouvert), p + Vector2(5 * e, 0), p + Vector2(0, 3.0 * e * ouvert)])
			draw_colored_polygon(r, Color(1.0, 0.3 + 0.2 * l, 0.1))
			draw_circle(p + Vector2(0.5 * e, 0), 0.9 * e, Color(1.0, 0.9, 0.5))

	# ------------------------------------------------------------ les touches

	func _nom(action: String) -> String:
		if action.begins_with("="):
			return Langue.t(action.substr(1))
		var k: int = Options.touche_principale(action)
		return "—" if k == KEY_NONE else Options.nom_touche(k)

	func _touche(r: Rect2, texte: String, etiquette: String, appui: float) -> void:
		etiquette = Langue.t(etiquette)
		var creux := 5.0 * appui
		var haut := r
		haut.position.y += creux
		haut.size.y -= 0.0
		# Le pied de la touche (l'épaisseur), puis son dessus qui s'enfonce quand on appuie.
		var pied := Rect2(r.position + Vector2(0, 6), r.size)
		draw_style_box(_cap_pied, pied)
		_cap_haut.bg_color = Color(0.2, 0.14, 0.11).lerp(Color(0.5, 0.33, 0.12), appui)
		_cap_haut.border_color = Color(OR, 0.55 + 0.45 * appui)
		_cap_haut.shadow_color = Color(1.0, 0.7, 0.25, 0.55 * appui)
		_cap_haut.shadow_size = int(14 * appui)
		draw_style_box(_cap_haut, haut)
		# Un reflet sur le haut du capuchon.
		draw_line(haut.position + Vector2(10, 5), haut.position + Vector2(haut.size.x - 10, 5), Color(1, 1, 1, 0.12 + 0.1 * appui), 2.0)
		var f := _police("titre")
		var taille := 30
		while taille > 13 and f.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x > haut.size.x - 12.0:
			taille -= 2
		var w := f.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille)
		var c := OR_VIF if appui > 0.3 else Color(0.96, 0.9, 0.78)
		draw_string(f, haut.position + Vector2((haut.size.x - w.x) * 0.5, haut.size.y * 0.5 + taille * 0.36), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, c)
		# Le nom de l'action, sous la touche : c'est lui qu'on cherche.
		var cx := r.position.x + r.size.x * 0.5
		var tex := _police("texte")
		var lt := 17
		while lt > 11 and tex.get_string_size(etiquette, HORIZONTAL_ALIGNMENT_LEFT, -1, lt).x > 136.0:
			lt -= 1
		_texte(Vector2(cx - 70, r.end.y + 24), etiquette, lt, PAPIER, 140.0)

	func _clavier(nom: String) -> void:
		_parchemin(Rect2(Vector2.ZERO, size))
		var liste: Array = CLAVIERS[nom]
		var n := liste.size()
		var actif := int(_t * 1.1) % n
		var fr := fmod(_t * 1.1, 1.0)
		for i in n:
			var a: Array = liste[i]
			var appui := clampf(sin(fr * PI) * 2.2, 0.0, 1.0) if i == actif else 0.0
			_touche(Rect2(float(a[2]), float(a[3]), float(a[4]), 56.0), _nom(a[0]), a[1], appui)

	# ------------------------------------------------------------ les cartes de rôle

	func _carte(centre: Vector2, angle: float, col: Color, sorte_carte: String, vie: float) -> void:
		draw_set_transform(centre, angle, Vector2.ONE)
		var r := Rect2(-56, -96, 112, 192)
		draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.5))
		_fondu(r, Color(0.16, 0.1, 0.1), Color(0.07, 0.04, 0.05))
		_lueur(Vector2(0, -6), 70, Color(col, 0.35), vie)
		draw_rect(r, Color(col, 0.95), false, 3.0)
		draw_rect(r.grow(-7), Color(OR, 0.55), false, 1.2)
		for sy in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(0, 80 * sy - 6), Vector2(6, 80 * sy), Vector2(0, 80 * sy + 6), Vector2(-6, 80 * sy)]), Color(OR, 0.9))
		match sorte_carte:
			"oeil":
				var amande := PackedVector2Array()
				for k in 17:
					var u := -1.0 + k * 0.125
					amande.append(Vector2(u * 36, -sqrt(maxf(0.0, 1.0 - u * u)) * 20 - 8))
				for k in 17:
					var u := 1.0 - k * 0.125
					amande.append(Vector2(u * 36, sqrt(maxf(0.0, 1.0 - u * u)) * 20 - 8))
				draw_colored_polygon(amande, Color(0.04, 0.05, 0.1))
				draw_polyline(amande + PackedVector2Array([amande[0]]), col, 2.5)
				draw_circle(Vector2(0, -8), 12, Color(col, 0.55))
				draw_circle(Vector2(0, -8), 5, Color(0.02, 0.02, 0.05))
				draw_circle(Vector2(-3, -11), 2, Color(1, 1, 1, 0.9))
				for k in 7:
					var a := PI + 0.35 + k * (PI - 0.7) / 6.0
					draw_line(Vector2(cos(a) * 24, sin(a) * 14 - 8), Vector2(cos(a) * 34, sin(a) * 24 - 8), Color(col, 0.8), 2.0)
				draw_arc(Vector2(0, 44), 14, 0.0, TAU, 20, Color(col, 0.5), 1.5)
				draw_circle(Vector2(0, 44), 3, Color(col, 0.9))
			"fiole":
				var corps := PackedVector2Array([Vector2(-8, -48), Vector2(8, -48), Vector2(8, -28), Vector2(27, 10), Vector2(27, 30), Vector2(14, 42), Vector2(-14, 42), Vector2(-27, 30), Vector2(-27, 10), Vector2(-8, -28)])
				draw_colored_polygon(corps, Color(0.05, 0.08, 0.06))
				draw_colored_polygon(PackedVector2Array([Vector2(-26, 14), Vector2(26, 14), Vector2(26, 30), Vector2(14, 41), Vector2(-14, 41), Vector2(-26, 30)]), Color(col, 0.65))
				draw_polyline(corps + PackedVector2Array([corps[0]]), col, 2.5)
				draw_rect(Rect2(-10, -58, 20, 12), Color(0.5, 0.33, 0.18))
				for k in 4:
					var bt := fmod(_t * 0.7 + k * 0.27, 1.0)
					draw_circle(Vector2(sin(k * 2.3) * 12, 28 - bt * 36), 2.0 + k % 2, Color(0.8, 1.0, 0.75, 0.7 * (1.0 - bt)))
				draw_line(Vector2(-18, 8), Vector2(-10, 28), Color(1, 1, 1, 0.3), 2.0)
				for k in 3:
					var a := k * TAU / 3.0 + 0.4
					draw_circle(Vector2(0, 62) + Vector2(cos(a), sin(a)) * 9, 2.5, Color(col, 0.8))
			"loup":
				var tete := PackedVector2Array([Vector2(-34, -52), Vector2(-14, -28), Vector2(14, -28), Vector2(34, -52), Vector2(34, -8), Vector2(18, 18), Vector2(8, 44), Vector2(0, 50), Vector2(-8, 44), Vector2(-18, 18), Vector2(-34, -8)])
				draw_colored_polygon(tete, Color(0.05, 0.02, 0.03))
				draw_polyline(tete + PackedVector2Array([tete[0]]), col, 2.5)
				draw_colored_polygon(PackedVector2Array([Vector2(-26, -44), Vector2(-17, -30), Vector2(-27, -22)]), Color(col, 0.4))
				draw_colored_polygon(PackedVector2Array([Vector2(26, -44), Vector2(17, -30), Vector2(27, -22)]), Color(col, 0.4))
				for dx in [-1.0, 1.0]:
					var p := Vector2(dx * 14, -8)
					_lueur(p, 18, Color(1.0, 0.35, 0.1, 0.6), vie)
					draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 3), p + Vector2(0, -4), p + Vector2(8, -2), p + Vector2(0, 4)]), Color(1.0, 0.8, 0.25))
				draw_colored_polygon(PackedVector2Array([Vector2(-5, 28), Vector2(5, 28), Vector2(0, 40)]), Color(0.9, 0.85, 0.8))
				draw_line(Vector2(-12, 14), Vector2(12, 14), Color(col, 0.7), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _roles() -> void:
		_parchemin(Rect2(Vector2.ZERO, size))
		for k in 22:
			var p := Vector2(fmod(k * 97.3, size.x - 40) + 20, fmod(k * 53.7, size.y * 0.5) + 20)
			draw_circle(p, 1.2, Color(1, 0.95, 0.8, 0.25 + 0.3 * sin(_t * 2.0 + k)))
		var m := size.x * 0.5
		var vie := 0.8 + 0.2 * sin(_t * 2.0)
		_carte(Vector2(m - 118, 160 + 8), -0.2, Color(0.55, 0.75, 0.95), "oeil", vie)
		_carte(Vector2(m + 118, 160 + 8), 0.2, SANG.lightened(0.15), "loup", vie)
		_carte(Vector2(m, 152 + sin(_t * 1.4) * 3.0), 0.0, Color(0.6, 0.85, 0.55), "fiole", vie)

	# ------------------------------------------------------------ le dessin

	func _draw() -> void:
		var s := size
		match sorte:
			"but":
				_photo("but")
				# Les lanternes du temple et les fenêtres vivent un peu.
				for p: Vector2 in [Vector2(0.46, 0.44), Vector2(0.54, 0.44)]:
					_lueur(p * s, 20.0, Color(1.0, 0.35, 0.15, 0.5), _scintille(1.0, 7.0, p.x * 9.0))
				for p: Vector2 in [Vector2(0.44, 0.48), Vector2(0.56, 0.48)]:
					_lueur(p * s, 26.0, Color(1.0, 0.55, 0.2, 0.4), _scintille(1.0, 9.0, p.x * 5.0))
				for p: Vector2 in [Vector2(0.17, 0.53), Vector2(0.33, 0.54)]:
					_lueur(p * s, 28.0, Color(1.0, 0.7, 0.3, 0.35), _scintille(1.0, 3.0, p.x * 7.0))
			"jour":
				_photo("jour")
				for p: Vector2 in [Vector2(0.22, 0.61), Vector2(0.62, 0.61)]:
					_lueur(p * s, 22.0, Color(1.0, 0.75, 0.3, 0.45), _scintille(1.0, 8.0, p.x * 4.0))
				# Les sceaux de cire numérotés : c'est le chiffre qu'on tape au vote du matin.
				for k in 3:
					var c := Vector2((0.305 + k * 0.14) * s.x, 0.5 * s.y)
					draw_circle(c + Vector2(1.5, 2.5), 17, Color(0, 0, 0, 0.5))
					draw_circle(c, 17, Color(0.7, 0.08, 0.06))
					draw_arc(c, 13, 0.0, TAU, 20, Color(1.0, 0.5, 0.4, 0.5), 1.4)
					draw_circle(c + Vector2(-5, -6), 4, Color(1, 1, 1, 0.13))
					draw_string(_police("titre"), c + Vector2(-17, 8), str(k + 1), HORIZONTAL_ALIGNMENT_CENTER, 34, 24, Color(1.0, 0.9, 0.7))
			"conseil":
				_photo("conseil")
				var feu := Vector2(0.46, 0.56) * s
				_lueur(feu, 120.0, Color(1.0, 0.5, 0.15, 0.55), _scintille(1.0, 6.0, 0.0))
				for k in 12:
					var u := fmod(_t * 0.28 + k * 0.083, 1.0)
					var p := feu + Vector2(sin(k * 3.1 + _t * 1.3) * (10.0 + 30.0 * u), -u * 150.0 - 14.0)
					draw_circle(p, 2.0 - u, Color(1.0, 0.65 + 0.2 * (1.0 - u), 0.25, 0.9 * (1.0 - u)))
			"nuit":
				_photo("nuit")
				# Une lumière chaude à une fenêtre, et des yeux qui s'ouvrent dans l'ombre entre les maisons.
				_yeux(Vector2(0.575, 0.585) * s, 0.9, 0.0)
				_yeux(Vector2(0.075, 0.52) * s, 0.7, 1.7)
			"roles":
				_roles()
			"touches_bouger", "touches_agir", "touches_voix":
				_clavier(sorte)
		_cadre(true)
