class_name Manette
extends Node
## La manette (autoload `Pad`) : elle ne parle pas au jeu, elle se fait passer pour le clavier et la
## souris du joueur. Chaque bouton appuie sur la touche que CE joueur a réglée pour l'action ; le
## stick droit tourne la tête comme la souris. Tout le reste du jeu reste écrit pour le clavier.
##
## Souris capturée (en jeu) : boutons → touches, stick gauche → marche, stick droit → regard.
## Souris visible (menus, pause, panneaux) : le stick gauche promène le curseur, A clique, B = Échap.

signal branchee(oui: bool)

const ZONE_MORTE := 0.22
const SEUIL_MARCHE := 0.45       # au-delà, la touche de marche est tenue…
const SEUIL_RELACHE := 0.3       # … et relâchée en deçà (pas de clignotement autour du seuil)

## Bouton → action du jeu (les noms de Reglages.ACTIONS). Xbox : A, B, X, Y.
const BOUTONS := {
	JOY_BUTTON_A: "sauter",
	JOY_BUTTON_B: "poser",
	JOY_BUTTON_X: "agir",
	JOY_BUTTON_Y: "pouvoir",
	JOY_BUTTON_LEFT_SHOULDER: "portee",
	JOY_BUTTON_RIGHT_SHOULDER: "emotes",
	JOY_BUTTON_LEFT_STICK: "sprint",
	JOY_BUTTON_RIGHT_STICK: "mordre",
	JOY_BUTTON_BACK: "lire",
}
## La croix : les flèches (combinaisons du loup), et hors combinaison une action en plus.
const CROIX := {
	JOY_BUTTON_DPAD_UP: [KEY_UP, "pret"],
	JOY_BUTTON_DPAD_DOWN: [KEY_DOWN, "miroir"],
	JOY_BUTTON_DPAD_LEFT: [KEY_LEFT, "volumes"],
	JOY_BUTTON_DPAD_RIGHT: [KEY_RIGHT, "interagir"],
}
## Le tableau de la page Réglages > Manette (bouton, ce qu'il fait).
const AIDE := [
	["Stick gauche", "Marcher (menus : déplacer le curseur)"],
	["Stick droit", "Regarder"],
	["A", "Sauter (menus : cliquer)"],
	["B", "Lâcher ce qu'on tient (menus : retour)"],
	["X", "Agir (porte, tableau, s'asseoir)"],
	["Y", "Pouvoir de son rôle"],
	["LB", "Chuchoter / parler / crier"],
	["RB", "Animations (gestes et danses)"],
	["LT", "Parler (appuyer pour parler)"],
	["RT", "Clic (tenir la corde, viser…)"],
	["Clic stick gauche", "Sprinter"],
	["Clic stick droit", "Mordre (vampire)"],
	["Croix", "Passer au vote · miroir · volumes · interagir face à quelqu'un (flèches pendant une combinaison)"],
	["Croix, pendant un vote", "↑ 1 · → 2 · ↓ 3 · ← 4"],
	["View / Select", "Carnet"],
	["Menu / Start", "Pause"],
]

## Vrai pendant une combinaison du loup : la croix ne fait plus que les flèches.
var fleches_seules := false
## Vrai quand l'écran attend un chiffre (vote des quêtes, choix d'une quête) : la croix tape 1 à 4.
var chiffres := false
const CROIX_CHIFFRES := {JOY_BUTTON_DPAD_UP: KEY_1, JOY_BUTTON_DPAD_RIGHT: KEY_2, JOY_BUTTON_DPAD_DOWN: KEY_3, JOY_BUTTON_DPAD_LEFT: KEY_4}
## Tests : une manette fictive (les axes viennent de `axes_simules`, rien n'est lu du matériel).
var simulee := false
var axes_simules := {}       # JoyAxis -> valeur
var jeu_simule := -1         # -1 : on suit la souris ; 0/1 : menus / en jeu

var _tenues := {}          # keycode synthétique -> vrai (pour relâcher proprement)
var _gachettes := {"gauche": false, "droite": false}
var _connectee := false
## Vrai tant que la dernière main posée est sur la manette (bouton ou stick), faux dès qu'on retouche
## au clavier ou à la souris : c'est ce qui décide si les textes disent « X » ou « E » (Edwin, 01/11 :
## manette branchée mais clavier en main, le jeu proposait « X pour t'asseoir »).
var en_main := false
## Marque des faux événements fabriqués ici : ils ne comptent pas comme un geste du clavier.
const APPAREIL_FAUX := 4242


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(func(_id: int, _oui: bool) -> void: _verifier())
	_verifier()


const NOMS := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_BACK: "View", JOY_BUTTON_DPAD_UP: "Croix ↑",
	JOY_BUTTON_DPAD_DOWN: "Croix ↓", JOY_BUTTON_DPAD_LEFT: "Croix ←", JOY_BUTTON_DPAD_RIGHT: "Croix →"}


## Le bouton qui fait cette action ("" : aucun). Les textes à l'écran le montrent à la place de la touche.
static func bouton_de(action: String) -> String:
	if action == "parler":
		return "LT"
	for b in BOUTONS:
		if BOUTONS[b] == action:
			return Langue.t(NOMS[b])
	for b in CROIX:
		if CROIX[b][1] == action:
			return Langue.t(NOMS[b])
	return ""


func connectee() -> bool:
	return _connectee or simulee


## La manette est branchée, activée ET c'est elle qu'on utilise : les textes montrent ses boutons.
func utilise() -> bool:
	return connectee() and bool(Options.valeur("manette/active")) and (en_main or simulee)


## Règle pure : ce qui change la main posée. 1 : manette, 0 : clavier/souris, -1 : sans effet.
static func main_de(est_manette: bool, est_faux: bool, force := 1.0) -> int:
	if est_faux:
		return -1
	if est_manette:
		return 1 if absf(force) > 0.5 else -1
	return 0


func _verifier() -> void:
	var oui := not Input.get_connected_joypads().is_empty()
	if oui != _connectee:
		_connectee = oui
		if not oui:
			_tout_relacher()
		branchee.emit(oui)


func _active() -> bool:
	return connectee() and bool(Options.valeur("manette/active"))


func _en_jeu() -> bool:
	if jeu_simule >= 0:
		return jeu_simule == 1
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------- boutons

func _input(ev: InputEvent) -> void:
	var force := 1.0
	if ev is InputEventJoypadMotion:
		force = (ev as InputEventJoypadMotion).axis_value
	var main := main_de(ev is InputEventJoypadButton or ev is InputEventJoypadMotion,
			ev.device == APPAREIL_FAUX,
			force) if (ev is InputEventJoypadButton or ev is InputEventJoypadMotion or ev is InputEventKey
			or ev is InputEventMouseButton or (ev is InputEventMouseMotion and (ev as InputEventMouseMotion).relative.length() > 3.0)) else -1
	if main >= 0:
		en_main = main == 1
	if not _active():
		return
	if ev is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()   # les sticks sont lus à chaque image, pas par la navigation des menus
		return
	if not ev is InputEventJoypadButton:
		return
	var b := ev as InputEventJoypadButton
	get_viewport().set_input_as_handled()
	if b.button_index == JOY_BUTTON_START:
		if b.pressed:
			_taper(KEY_ESCAPE)
		return
	if chiffres and CROIX_CHIFFRES.has(b.button_index):
		if b.pressed:
			_taper(CROIX_CHIFFRES[b.button_index])
		return
	if not _en_jeu():
		# Menus : A clique là où est le curseur, B revient en arrière. Seuls les boutons qui
		# ferment un panneau gardent leur action (gestes, carnet) ; la croix ne fait que les flèches.
		match b.button_index:
			JOY_BUTTON_A:
				_clic(MOUSE_BUTTON_LEFT, b.pressed)
			JOY_BUTTON_B:
				if b.pressed:
					_taper(KEY_ESCAPE)
			JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_BACK:
				_bouton_de_jeu(b)
			_:
				if CROIX.has(b.button_index):
					_touche(CROIX[b.button_index][0], b.pressed)
		return
	_bouton_de_jeu(b)


func _bouton_de_jeu(b: InputEventJoypadButton) -> void:
	if BOUTONS.has(b.button_index):
		_action(BOUTONS[b.button_index], b.pressed)
	elif CROIX.has(b.button_index):
		var c: Array = CROIX[b.button_index]
		_touche(c[0], b.pressed)
		if not fleches_seules and _en_jeu():
			_action(c[1], b.pressed)


func _action(action: String, presse: bool) -> void:
	var k := Options.touche_principale(action)
	if k != KEY_NONE:
		_touche(k, presse)


# ---------------------------------------------------------------- sticks et gâchettes

func _process(delta: float) -> void:
	if not _active():
		if not _tenues.is_empty() or _gachettes["gauche"] or _gachettes["droite"]:
			_tout_relacher()
		return
	var g := _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	var d := _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	if _en_jeu():
		_marche("avancer", -g.y)
		_marche("reculer", g.y)
		_marche("gauche", -g.x)
		_marche("droite", g.x)
		if d != Vector2.ZERO:
			var m := InputEventMouseMotion.new()
			var force := float(Options.valeur("manette/sensibilite"))
			m.relative = d * d.length() * force * 900.0 * delta   # courbe douce : précis au centre
			m.screen_relative = m.relative
			m.device = APPAREIL_FAUX
			Input.parse_input_event(m)
	else:
		for a in ["avancer", "reculer", "gauche", "droite"]:
			_marche(a, 0.0)
		var v := g if g.length() > d.length() else d
		if v != Vector2.ZERO:
			var vp := get_viewport()
			var pos := vp.get_mouse_position() + v * v.length() * 1100.0 * delta
			var taille := vp.get_visible_rect().size
			pos = pos.clamp(Vector2.ZERO, taille - Vector2.ONE)
			vp.warp_mouse(pos)
	# Gâchettes : LT = parler, RT = clic gauche (tenir la corde, cliquer dans une quête).
	_gachette("gauche", _axe(JOY_AXIS_TRIGGER_LEFT) > 0.4)
	_gachette("droite", _axe(JOY_AXIS_TRIGGER_RIGHT) > 0.4)


func _axe(a: JoyAxis) -> float:
	if simulee:
		return float(axes_simules.get(a, 0.0))
	return Input.get_joy_axis(_pad(), a)


func _pad() -> int:
	var l := Input.get_connected_joypads()
	return l[0] if not l.is_empty() else 0


func _stick(ax: JoyAxis, ay: JoyAxis) -> Vector2:
	var v := Vector2(_axe(ax), _axe(ay))
	var n := v.length()
	if n < ZONE_MORTE:
		return Vector2.ZERO
	return v / n * minf((n - ZONE_MORTE) / (1.0 - ZONE_MORTE), 1.0)


func _marche(action: String, valeur: float) -> void:
	var k := Options.touche_principale(action)
	if k == KEY_NONE:
		return
	var tenue := _tenues.has(k)
	if not tenue and valeur > SEUIL_MARCHE:
		_touche(k, true)
	elif tenue and valeur < SEUIL_RELACHE:
		_touche(k, false)


func _gachette(cote: String, presse: bool) -> void:
	if presse == _gachettes[cote]:
		return
	_gachettes[cote] = presse
	if cote == "gauche":
		_action("parler", presse)
	else:
		_clic(MOUSE_BUTTON_LEFT, presse)


# ---------------------------------------------------------------- faux clavier, fausse souris

func _touche(k: int, presse: bool) -> void:
	if presse == _tenues.has(k):
		return
	if presse:
		_tenues[k] = true
	else:
		_tenues.erase(k)
	var e := InputEventKey.new()
	e.keycode = k as Key
	e.physical_keycode = k as Key
	e.pressed = presse
	e.device = APPAREIL_FAUX
	Input.parse_input_event(e)


func _taper(k: int) -> void:
	_touche(k, true)
	_touche(k, false)


func _clic(bouton: MouseButton, presse: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = bouton
	e.pressed = presse
	e.position = get_viewport().get_mouse_position()
	e.global_position = e.position
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if presse else 0
	e.device = APPAREIL_FAUX
	Input.parse_input_event(e)


func _tout_relacher() -> void:
	for k in _tenues.keys():
		_touche(k, false)
	if _gachettes["gauche"]:
		_gachette("gauche", false)
	if _gachettes["droite"]:
		_gachette("droite", false)
