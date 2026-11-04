class_name VueQuete
extends PanelContainer
## L'écran d'un mini-jeu de quête, chez le joueur : il dessine la vue envoyée par l'hôte
## (cf. MiniJeu pour le format des blocs) et renvoie les gestes du joueur par `geste`.
## La vue arrive ~10 fois par seconde : on ne reconstruit les contrôles que si la forme change
## (sinon un bouton disparaîtrait entre l'appui et le relâché), on met à jour le reste en place.

signal geste(d: Dictionary)

const OR := Color(0.95, 0.78, 0.45)
const TONS := {"": Color(1, 1, 1, 0.92), "or": OR, "gris": Color(1, 1, 1, 0.55),
	"rouge": Color(1.0, 0.42, 0.35), "vert": Color(0.55, 0.95, 0.55)}

var _boite: VBoxContainer
var _titre: Label
var _sous_titre: Label
var _consigne: Label
var _blocs: VBoxContainer
var _forme := ""
var _vue := {}
var _noeuds: Array = []      # un nœud (ou une liste de boutons) par bloc
var _tenir := false
var _yeux := false
var _recu_t := 0.0           # temps depuis la dernière vue (pour faire tourner le battement)


func _ready() -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.05, 0.05, 0.9)
	st.border_color = Color(OR, 0.5)
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	st.content_margin_left = 22
	st.content_margin_right = 22
	st.content_margin_top = 18
	st.content_margin_bottom = 18
	add_theme_stylebox_override("panel", st)
	# Collé au bord droit, centré en hauteur ; il grandit vers la gauche et des deux côtés.
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -570.0
	offset_right = -30.0
	offset_top = -200.0
	offset_bottom = 200.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	_boite = VBoxContainer.new()
	_boite.add_theme_constant_override("separation", 10)
	add_child(_boite)
	_titre = _label("", 30, OR)
	_boite.add_child(_titre)
	_sous_titre = _label("", 16, TONS["gris"])
	_boite.add_child(_sous_titre)
	_consigne = _label("", 18, TONS[""])
	_boite.add_child(_consigne)
	_boite.add_child(HSeparator.new())
	_blocs = VBoxContainer.new()
	_blocs.add_theme_constant_override("separation", 12)
	_boite.add_child(_blocs)
	visible = false


func _label(t: String, taille: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 490
	return l


## Discret : la quête se joue dans le décor (MondeQuete) ; ce panneau reste actif pour lire
## les touches (Espace tenu, battement, yeux, 1 à 9) mais ne montre plus rien.
var discret := false


func afficher(vue: Dictionary) -> void:
	_vue = vue
	_recu_t = 0.0
	visible = true
	modulate.a = 0.0 if discret else 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE if discret else Control.MOUSE_FILTER_STOP
	_titre.text = str(vue.get("titre", "Quête"))
	var gabarit_sous := "%s  ·  %d s  ·  il faut %d réussites sur %d" if int(vue.get("seuil", 0)) > 1 else "%s  ·  %d s  ·  il faut %d réussite sur %d"
	_sous_titre.text = gabarit_sous % [vue.get("niveau", ""), int(ceil(float(vue.get("reste", 0.0)))),
		int(vue.get("seuil", 0)), int(vue.get("equipe", 0))]
	_consigne.text = str(vue.get("consigne", ""))
	var blocs: Array = vue.get("blocs", [])
	var forme := _forme_de(blocs)
	if forme != _forme:
		_forme = forme
		_construire(blocs)
	else:
		_mettre_a_jour(blocs)


func cacher() -> void:
	visible = false
	_forme = ""
	if _tenir:
		_tenir = false
	_yeux = false


## Ce qui oblige à reconstruire : le type des blocs et le libellé / l'état des boutons.
func _forme_de(blocs: Array) -> String:
	var f := PackedStringArray()
	for b: Dictionary in blocs:
		var t: String = b.get("t", "")
		f.append(t)
		if t == "boutons":
			for x in b.get("v", []):
				f.append("%s|%s|%s" % [x.get("l", ""), x.get("off", false), x.get("ton", "")])
		elif t == "grille":
			f.append("%dx%d" % [b.get("l", 0), b.get("h", 0)])
	return "/".join(f)


func _construire(blocs: Array) -> void:
	for e in _blocs.get_children():
		e.queue_free()
	_noeuds.clear()
	for i in blocs.size():
		var b: Dictionary = blocs[i]
		match b.get("t", ""):
			"texte":
				var l := _label(MiniJeu.tr_vue(str(b.get("v", ""))), int(b.get("taille", 20)), TONS.get(b.get("ton", ""), TONS[""]))
				_blocs.add_child(l)
				_noeuds.append(l)
			"boutons":
				var rang := HFlowContainer.new()
				rang.add_theme_constant_override("h_separation", 8)
				rang.add_theme_constant_override("v_separation", 8)
				var liste := []
				var v: Array = b.get("v", [])
				for k in v.size():
					var x: Dictionary = v[k]
					var bt := Button.new()
					bt.text = ("%d · " % (_compter_boutons_avant(blocs, i) + k + 1) if _compter_boutons_avant(blocs, i) + k < 9 else "") + str(x.get("l", ""))
					bt.add_theme_font_size_override("font_size", int(b.get("taille", 22)))
					bt.disabled = bool(x.get("off", false))
					bt.focus_mode = Control.FOCUS_NONE
					if x.get("ton", "") != "":
						bt.add_theme_color_override("font_color", TONS.get(x["ton"], TONS[""]))
					var a: Dictionary = x.get("a", {})
					bt.pressed.connect(func(): geste.emit(a.duplicate()))
					rang.add_child(bt)
					liste.append(bt)
				_blocs.add_child(rang)
				_noeuds.append(liste)
			"jauge":
				var j := Jauge.new()
				j.custom_minimum_size = Vector2(490, 46)
				_blocs.add_child(j)
				_noeuds.append(j)
			"rythme":
				var r := Battement.new()
				r.custom_minimum_size = Vector2(490, 150)
				_blocs.add_child(r)
				_noeuds.append(r)
			"tenir", "yeux":
				var l2 := _label("", 22, OR)
				_blocs.add_child(l2)
				_noeuds.append(l2)
			"grille":
				var g := Grille.new()
				g.custom_minimum_size = Vector2(490, 360)
				g.clic.connect(func(c): if bool(_bloc(i).get("clic", false)): geste.emit({"case": c}))
				_blocs.add_child(g)
				_noeuds.append(g)
			_:
				_noeuds.append(null)
	_mettre_a_jour(blocs)


func _bloc(i: int) -> Dictionary:
	var blocs: Array = _vue.get("blocs", [])
	return blocs[i] if i < blocs.size() else {}


func _compter_boutons_avant(blocs: Array, i: int) -> int:
	var n := 0
	for k in i:
		if blocs[k].get("t", "") == "boutons":
			n += (blocs[k].get("v", []) as Array).size()
	return n


func _mettre_a_jour(blocs: Array) -> void:
	for i in mini(blocs.size(), _noeuds.size()):
		var b: Dictionary = blocs[i]
		var n = _noeuds[i]
		match b.get("t", ""):
			"texte":
				(n as Label).text = MiniJeu.tr_vue(str(b.get("v", "")))
				(n as Label).add_theme_color_override("font_color", TONS.get(b.get("ton", ""), TONS[""]))
			"jauge":
				var j: Jauge = n
				j.valeur = float(b.get("v", 0.0))
				j.libelle = str(b.get("l", ""))
				j.zone = b.get("zone", [])
				j.couleur = TONS.get(b.get("ton", ""), OR) if b.get("ton", "") != "" else OR
				j.queue_redraw()
			"rythme":
				var r: Battement = n
				r.periode = maxf(float(b.get("periode", 1.0)), 0.1)
				r.phase_recue = float(b.get("phase", 0.0))
				r.libelle = str(b.get("l", ""))
			"tenir":
				(n as Label).text = "%s\n%s" % [b.get("l", ""), "→ tu tiens (Espace)" if _tenir else "→ Espace : tenir"]
			"yeux":
				(n as Label).text = "%s\n%s" % [b.get("l", ""), "→ yeux fermés" if _yeux else ("→ YEUX OUVERTS" if not Capteur.mode_souris else "→ maintiens Espace : yeux fermés")]
				(n as Label).add_theme_color_override("font_color", TONS["vert"] if _yeux else TONS["rouge"])
			"grille":
				var g: Grille = n
				g.l = int(b.get("l", 1))
				g.h = int(b.get("h", 1))
				g.cases = str(b.get("v", ""))
				g.queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_recu_t += delta
	var a_tenir := false
	var a_yeux := false
	for b: Dictionary in _vue.get("blocs", []):
		a_tenir = a_tenir or b.get("t", "") == "tenir"
		a_yeux = a_yeux or b.get("t", "") == "yeux"
	var espace := Input.is_key_pressed(KEY_SPACE)
	# Tenir et battre la mesure se font à la main, dans le décor (MondeQuete) : seul le panneau
	# visible (essais, ancien affichage) garde Espace.
	if a_tenir and not discret and espace != _tenir:
		_tenir = espace
		geste.emit({"tenir": _tenir})
	if a_yeux:
		var fermes := espace
		if not Capteur.mode_souris and Capteur.visage_vu():
			fermes = fermes or Capteur.ouverture_yeux() < 0.3
		if fermes != _yeux:
			_yeux = fermes
			geste.emit({"yeux": _yeux})
	for n in _noeuds:
		if n is Battement:
			(n as Battement).avancer(_recu_t)


## Des boutons numérotés attendent un choix (la manette les tape à la croix).
func a_des_choix() -> bool:
	if not visible:
		return false
	for n in _noeuds:
		if n is Array and not (n as Array).is_empty():
			return true
	return false


func _unhandled_input(ev: InputEvent) -> void:
	if not visible or not ev is InputEventKey or not ev.pressed or ev.echo:
		return
	var k: Key = ev.keycode
	if k == KEY_SPACE and not discret:
		for n in _noeuds:
			if n is Battement:
				geste.emit({"coup": true, "phase": (n as Battement).phase_vue()})
				(n as Battement).eclair()
	elif k >= KEY_1 and k <= KEY_9:
		var rang := int(k - KEY_1)
		for n in _noeuds:
			if n is Array:
				for bt: Button in n:
					if rang == 0 and not bt.disabled:
						bt.pressed.emit()
						get_viewport().set_input_as_handled()
						return
					rang -= 1


# ---------------------------------------------------------------- petits dessins

class Jauge extends Control:
	var valeur := 0.0
	var libelle := ""
	var zone: Array = []
	var couleur := Color(0.95, 0.78, 0.45)

	func _draw() -> void:
		var h := 20.0
		var y := size.y - h
		draw_rect(Rect2(0, y, size.x, h), Color(1, 1, 1, 0.08))
		if zone.size() == 2:
			draw_rect(Rect2(size.x * float(zone[0]), y, size.x * (float(zone[1]) - float(zone[0])), h), Color(0.5, 0.95, 0.5, 0.25))
		draw_rect(Rect2(0, y, size.x * clampf(valeur, 0, 1), h), couleur)
		draw_string(get_theme_default_font(), Vector2(0, y - 6), Langue.t(libelle), HORIZONTAL_ALIGNMENT_LEFT, size.x, 17, Color(1, 1, 1, 0.8))


## Le battement : une aiguille qui tourne ; elle passe en haut au moment du coup.
class Battement extends Control:
	var periode := 1.0
	var phase_recue := 0.0
	var libelle := ""
	var _phase := 0.0
	var _eclair := 0.0

	func avancer(depuis: float) -> void:
		_phase = fposmod(phase_recue + depuis / periode, 1.0)
		_eclair = maxf(_eclair - get_process_delta_time() * 3.0, 0.0)
		queue_redraw()

	func phase_vue() -> float:
		return _phase

	func eclair() -> void:
		_eclair = 1.0

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 70)
		var r := 56.0
		draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.25), 3.0)
		draw_circle(c + Vector2(0, -r), 9.0, Color(0.55, 0.95, 0.55, 0.9))
		var a := _phase * TAU - PI * 0.5
		draw_line(c, c + Vector2(cos(a), sin(a)) * r, Color(0.95, 0.78, 0.45), 5.0)
		draw_circle(c, 8.0 + _eclair * 10.0, Color(1, 0.9, 0.6, 0.4 + _eclair * 0.6))
		draw_string(get_theme_default_font(), Vector2(0, size.y - 6), Langue.t(libelle), HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, Color(1, 1, 1, 0.8))


## La grille des Lanternes : des cases de couleur, cliquables.
class Grille extends Control:
	signal clic(c: int)
	var l := 1
	var h := 1
	var cases := ""
	const COULEURS := {".": Color(0.32, 0.36, 0.28), "#": Color(0.16, 0.1, 0.06), "o": Color(1.0, 0.8, 0.3),
		"@": Color(0.4, 0.8, 1.0), "*": Color(0.75, 0.6, 1.0), "?": Color(0.12, 0.12, 0.14), "X": Color(0.95, 0.3, 0.25),
		"~": Color(0.2, 0.35, 0.55), "^": Color(0.5, 0.5, 0.52)}

	func _cote() -> float:
		return minf(size.x / maxf(l, 1), size.y / maxf(h, 1))

	func _draw() -> void:
		var c := _cote()
		for i in mini(cases.length(), l * h):
			var x := i % l
			var y := i / l
			var ch := cases[i]
			draw_rect(Rect2(x * c + 1, y * c + 1, c - 2, c - 2), COULEURS.get(ch, Color(0.3, 0.3, 0.3)))
			if ch in ["@", "*", "X", "o"]:
				draw_string(get_theme_default_font(), Vector2(x * c, y * c + c * 0.68), {"@": Langue.t("toi"), "*": "", "X": Langue.t("fin"), "o": ""}[ch],
					HORIZONTAL_ALIGNMENT_CENTER, c, int(c * 0.3), Color(0, 0, 0, 0.8))

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var c := _cote()
			var x := int(ev.position.x / c)
			var y := int(ev.position.y / c)
			if x >= 0 and x < l and y >= 0 and y < h:
				clic.emit(y * l + x)
