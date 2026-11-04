class_name PanneauTest
extends PanelContainer
## Le mode test (demande d'Edwin, 29/10) : un menu de triche, F10, hors ligne seulement.
## Figer le temps, sauter d'étape, lancer n'importe quel mini-jeu à n'importe quel niveau et
## avec n'importe quelle règle du jour, changer de rôle, mourir et revivre, se téléporter,
## déclencher une frayeur.

const FRAYEURS := ["monstre", "epouvantail", "vitre", "silhouette", "yeux_arbre", "yeux_lisiere", "pas",
	"chuchote", "comptine", "cloche", "porte", "bougie", "ombre", "corbeaux", "chien", "rats"]

var meneur: Meneur
## (texte) -> void : un message à l'écran.
var dire: Callable
## (Vector3 position, Vector3 regard) -> void : déplacer le joueur, sur-le-champ.
var aller: Callable
## (sorte) -> bool : déclencher une frayeur.
var frayeur: Callable
## (bool) -> void : les placements qui suivent se font sur-le-champ, sans marcher.
var sur_le_champ: Callable

var _jeux: OptionButton
var _niveaux: OptionButton
var _regles: OptionButton
var _taille: SpinBox
var _sabot: OptionButton
var _roles: OptionButton
var _frayeurs: OptionButton
var _fige: CheckBox
var _etat: Label


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.04, 0.93)
	style.border_color = Color(0.25, 0.55, 0.95, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)
	set_anchors_preset(Control.PRESET_LEFT_WIDE)
	offset_left = 12
	offset_top = 12
	offset_bottom = -12
	custom_minimum_size.x = 430
	var defile := ScrollContainer.new()
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(defile)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	defile.add_child(v)

	v.add_child(_titre("MODE TEST  ·  F10 pour fermer", 20))
	_etat = _texte("")
	v.add_child(_etat)

	v.add_child(_titre("Le temps"))
	_fige = CheckBox.new()
	_fige.text = "Bloquer le temps (étape et mini-jeux)"
	_fige.toggled.connect(func(oui: bool): meneur.test_fige = oui)
	v.add_child(_fige)
	var h := _ligne(v)
	h.add_child(_bouton("Passer l'étape", func(): meneur.passer_etape()))
	for x in [1.0, 3.0, 6.0]:
		var f: float = x
		h.add_child(_bouton("×%d" % int(f), func():
			Engine.time_scale = f
			Engine.physics_ticks_per_second = int(60 * f)))

	v.add_child(_titre("Aller à l'étape"))
	h = _ligne(v)
	for e in [["Nouveau jour", "jour"], ["Conseil", "conseil"], ["Vote", "vote"], ["Nuit", "nuit"]]:
		var quoi: String = e[1]
		h.add_child(_bouton(e[0], func(): _resultat(meneur.test_etape(quoi))))

	v.add_child(_titre("Les mini-jeux"))
	_jeux = OptionButton.new()
	for jeu in Quetes.JEUX:
		_jeux.add_item(Quetes.nom_jeu(jeu))
		_jeux.set_item_metadata(_jeux.item_count - 1, jeu)
	_jeux.item_selected.connect(func(_i): _maj_regles())
	v.add_child(_jeux)
	h = _ligne(v)
	h.add_child(_etiquette("Niveau"))
	_niveaux = OptionButton.new()
	for n in Quetes.NIVEAUX:
		_niveaux.add_item(Quetes.NOMS_NIVEAUX[n])
		_niveaux.set_item_metadata(_niveaux.item_count - 1, n)
	_niveaux.item_selected.connect(func(_i): _maj_regles())
	h.add_child(_niveaux)
	h.add_child(_etiquette("  Équipe"))
	_taille = SpinBox.new()
	_taille.min_value = 1
	_taille.max_value = 8
	_taille.value = 4
	_taille.value_changed.connect(func(_x): _maj_regles())
	h.add_child(_taille)
	_regles = OptionButton.new()
	v.add_child(_regles)
	_sabot = OptionButton.new()
	for s in [["Aucun saboteur", ""], ["Un bot saboteur", "bot"], ["Moi, saboteur", "moi"]]:
		_sabot.add_item(s[0])
		_sabot.set_item_metadata(_sabot.item_count - 1, s[1])
	v.add_child(_sabot)
	h = _ligne(v)
	h.add_child(_bouton("Lancer ce mini-jeu", _lancer_jeu))
	h.add_child(_bouton("Le finir", func(): _resultat(meneur.test_finir_quete())))

	v.add_child(_titre("Mon rôle"))
	_roles = OptionButton.new()
	for r in Roles.LISTE:
		_roles.add_item(Roles.nom(r))
		_roles.set_item_metadata(_roles.item_count - 1, r)
	v.add_child(_roles)
	h = _ligne(v)
	h.add_child(_bouton("Devenir ce rôle", func():
		_resultat(meneur.test_role(str(_roles.get_item_metadata(_roles.selected))))))
	h.add_child(_bouton("Mourir", func(): _resultat(meneur.test_mourir())))
	h.add_child(_bouton("Revivre", func(): _resultat(meneur.test_revivre())))

	v.add_child(_titre("Se téléporter"))
	var g := GridContainer.new()
	g.columns = 3
	v.add_child(g)
	g.add_child(_bouton("La place", func(): aller.call(Vector3(0, 0, 3.5), Vector3.ZERO)))
	g.add_child(_bouton("Le temple", func(): aller.call(Ronde.haut_marches(), Ronde.PIERRE)))
	g.add_child(_bouton("Le tableau", func():
		aller.call(Ronde.TABLEAU + (Vector3.ZERO - Ronde.TABLEAU).normalized() * 2.0, Ronde.TABLEAU)))
	g.add_child(_bouton("Ma maison", func():
		var m: int = (meneur.sieges.get(meneur.moi(), {}) as Dictionary).get("maison", 0)
		aller.call(Ronde.lit(m), Vector3.ZERO)))
	g.add_child(_bouton("Le cimetière", func():
		var c := Ronde.lieu("cimetiere")
		aller.call(c * 0.9, c)))
	for k in 3:
		var z: int = k
		g.add_child(_bouton("Clairière %d" % (z + 1), func():
			aller.call(Quetes.zone(z) + Vector3(0, 0, 4.0), Quetes.zone(z))))

	v.add_child(_titre("Les frayeurs"))
	_frayeurs = OptionButton.new()
	for f in FRAYEURS:
		_frayeurs.add_item(f.replace("_", " "))
	v.add_child(_frayeurs)
	v.add_child(_bouton("Déclencher", func():
		var sorte: String = FRAYEURS[_frayeurs.selected]
		if not frayeur.call(sorte):
			dire.call("Pas possible ici (de jour, dehors, rien d'ouvert, et assez loin des autres).")))
	v.add_child(_texte("Les frayeurs ne marchent que de jour, hors Conseil et hors mini-jeu."))
	_maj_regles()


func _process(_delta: float) -> void:
	if not visible or meneur == null:
		return
	_fige.set_pressed_no_signal(meneur.test_fige)
	var p := meneur.pub
	if meneur.test_fige:
		_etat.text = "Étape : %s · reste %d s · jour %d  ·  FIGÉ" % [p.get("phase", "?"), int(meneur.reste), meneur.jour_n]
	else:
		_etat.text = "Étape : %s · reste %d s · jour %d" % [p.get("phase", "?"), int(meneur.reste), meneur.jour_n]


func _maj_regles() -> void:
	var jeu: String = _jeux.get_item_metadata(_jeux.selected)
	var niveau: String = _niveaux.get_item_metadata(_niveaux.selected)
	_regles.clear()
	for r in meneur.test_variantes(jeu, niveau, int(_taille.value)):
		_regles.add_item("Règle de base" if r == "" else "Règle : %s" % str(r))
		_regles.set_item_metadata(_regles.item_count - 1, r)
	_regles.disabled = _regles.item_count <= 1


func _lancer_jeu() -> void:
	var jeu: String = _jeux.get_item_metadata(_jeux.selected)
	var niveau: String = _niveaux.get_item_metadata(_niveaux.selected)
	var regle: String = _regles.get_item_metadata(_regles.selected) if _regles.item_count > 0 else ""
	sur_le_champ.call(true)
	var e := meneur.test_jeu(jeu, niveau, regle, int(_taille.value), str(_sabot.get_item_metadata(_sabot.selected)))
	sur_le_champ.call(false)
	_resultat(e)
	if e == "":
		visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _resultat(e: String) -> void:
	if e != "":
		dire.call(e)


func _ligne(v: VBoxContainer) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	return h


func _bouton(texte: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.pressed.connect(action)
	return b


func _titre(texte: String, taille := 17) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
	return l


func _etiquette(texte: String) -> Label:
	var l := _texte(texte)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _texte(texte: String) -> Label:
	var l := Label.new()
	l.text = texte
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	return l
