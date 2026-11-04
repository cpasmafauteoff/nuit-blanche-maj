class_name Reglages
extends Node
## Les réglages du joueur (autoload `Options`) : son, tchat vocal, touches, graphismes.
## Enregistrés dans user://options.cfg et appliqués dès qu'ils changent.

signal change(cle: String)

const FICHIER := "user://options.cfg"
const BUS := ["Ambiance", "Effets", "Voix", "Musique"]

## Actions et leurs touches par défaut (plusieurs touches possibles : ZQSD et WASD).
const ACTIONS := [
	["avancer", "Avancer", [KEY_Z, KEY_UP]],
	["reculer", "Reculer", [KEY_S]],
	["gauche", "Aller à gauche", [KEY_Q, KEY_A]],
	["droite", "Aller à droite", [KEY_D]],
	["sprint", "Sprinter", [KEY_SHIFT]],
	["sauter", "Sauter", [KEY_SPACE]],
	["accroupir", "S'accroupir (maintenir)", [KEY_CTRL]],
	["agir", "Agir (porte, tableau, s'asseoir)", [KEY_E]],
	["pouvoir", "Pouvoir de son rôle", [KEY_F]],
	["lire", "Lire / écrire (carnet, page)", [KEY_L]],
	["poser", "Lâcher l'objet en main", [KEY_G]],
	["jeter", "Jeter l'objet en main (il retombe plus loin, ramassable)", [KEY_J]],
	["mordre", "Mordre (vampire)", [KEY_H]],
	["parler", "Parler (si « appuyer pour parler »)", [KEY_T]],
	["portee", "Chuchoter / parler / crier", [KEY_C]],
	["emotes", "Animations (gestes et danses)", [KEY_R]],
	["note", "Réduire / rouvrir la note de quête", [KEY_W]],
	["interagir", "Interagir, en plus du clic gauche (face à quelqu'un : pousser, main, chut…)", [KEY_I]],
	["pret", "Passer au vote (retour des quêtes)", [KEY_V]],
	["volumes", "Volume de chaque joueur", [KEY_B]],
	["miroir", "Montrer / cacher le miroir", [KEY_M]],
	["passer", "Passer l'étape (hôte)", [KEY_P]],
	["exclusion_oui", "Vote d'exclusion : répondre Oui", [KEY_F1]],
	["exclusion_non", "Vote d'exclusion : répondre Non", [KEY_F2]],
	["reseau", "Diagnostic réseau", [KEY_F3]],
]

const DEFAUTS := {
	"son/general": 80.0, "son/ambiance": 80.0, "son/musique": 70.0, "son/effets": 90.0, "son/voix": 100.0,
	"son/frayeurs": 100.0, "frayeurs/cri": true, "son/sortie": "Default",
	"vocal/micro": true, "vocal/sortie": "", "vocal/mode": "ouvert", "vocal/seuil": 0.02, "vocal/peripherique": "Default",
	"graphisme/plein_ecran": true, "graphisme/echelle": 100.0, "graphisme/vsync": true,
	"graphisme/ombres": true, "graphisme/fps_max": 0, "graphisme/champ": 75.0,
	"reseau/steam": true,
	"streamer/actif": false, "streamer/chaine": "",
	"manette/active": true, "manette/sensibilite": 1.0,
	"camera/utiliser": true,
	"langue/choix": "auto",
	"interface/note_reduite": false,
}

var _valeurs := {}
var _touches := {}        # action -> Array[int]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_creer_bus()
	_lire()
	# --langue=fr|en : force la langue pour cette session (essais à deux jeux), sans toucher au réglage.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--langue="):
			_valeurs["langue/choix"] = a.substr(9)
	Langue.appliquer(str(valeur("langue/choix")))
	for cle in DEFAUTS:
		_appliquer(cle)


func _fenetre_forcee() -> bool:
	for a in OS.get_cmdline_user_args():
		if a == "--fenetre" or a.begins_with("--essai") or a.begins_with("--capture"):
			return true
	return false


func _creer_bus() -> void:
	for nom in BUS:
		if AudioServer.get_bus_index(nom) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, nom)
			AudioServer.set_bus_send(i, "Master")


func valeur(cle: String) -> Variant:
	return _valeurs.get(cle, DEFAUTS.get(cle))


func regler(cle: String, v: Variant) -> void:
	_valeurs[cle] = v
	_appliquer(cle)
	_ecrire()
	change.emit(cle)


# ---------------------------------------------------------------- touches

func touches(action: String) -> Array:
	if _touches.has(action):
		return _touches[action]
	for a: Array in ACTIONS:
		if a[0] == action:
			return a[2]
	return []


func touche_principale(action: String) -> int:
	var t := touches(action)
	return int(t[0]) if not t.is_empty() else KEY_NONE


func appuye(action: String) -> bool:
	for k in touches(action):
		if Input.is_key_pressed(int(k)):
			return true
	return false


## Vrai si cet événement clavier correspond à l'action.
func est(ev: InputEventKey, action: String) -> bool:
	return int(ev.keycode) in touches(action)


func lier(action: String, keycode: int) -> void:
	# Une touche ne sert qu'à une action : on la retire des autres.
	for a: Array in ACTIONS:
		var l: Array = touches(a[0]).duplicate()
		if keycode in l and a[0] != action:
			l.erase(keycode)
			_touches[a[0]] = l
	_touches[action] = [keycode]
	_ecrire()
	change.emit("touches/" + action)


func touches_par_defaut() -> void:
	_touches.clear()
	_ecrire()
	change.emit("touches")


static func nom_touche(keycode: int) -> String:
	match keycode:
		KEY_SPACE: return Langue.t("Espace")
		KEY_SHIFT: return Langue.t("Maj")
		KEY_CTRL: return Langue.t("Ctrl")
		KEY_ALT: return Langue.t("Alt")
		KEY_TAB: return Langue.t("Tab")
		KEY_ENTER: return Langue.t("Entrée")
	return OS.get_keycode_string(keycode)


func texte_touches(action: String) -> String:
	var l := PackedStringArray()
	for k in touches(action):
		l.append(nom_touche(int(k)))
	return " / ".join(l)


## Les textes à l'écran écrivent {agir}, {pret}, {pouvoir}… au lieu d'une lettre : on y met la touche
## que CE joueur a réglée. Écrire « E » en dur affichait l'ancienne touche après un changement — et les
## messages de l'hôte, la touche de l'hôte.
func avec_touches(texte: String) -> String:
	texte = Langue.t(texte)   # d'abord la langue (le gabarit contient {agir}), puis la touche
	if not "{" in texte:
		return texte
	var pad: Node = get_node_or_null("/root/Pad") if is_inside_tree() else null
	var manette: bool = pad != null and pad.utilise()
	for a: Array in ACTIONS:
		var nom := Manette.bouton_de(a[0]) if manette else ""
		texte = texte.replace("{%s}" % a[0], nom if nom != "" else nom_touche(touche_principale(a[0])))
	return texte


## Un texte posé une fois (menu pause, info-bulle) suit ensuite les changements de touches.
func lier_texte(noeud: Node, gabarit: String, propriete := "text") -> void:
	noeud.set(propriete, avec_touches(gabarit))
	if not "{" in gabarit:
		return
	var suivre := func(cle: String) -> void:
		if cle.begins_with("touches"):
			noeud.set(propriete, avec_touches(gabarit))
	change.connect(suivre)
	noeud.tree_exiting.connect(func() -> void:
		if change.is_connected(suivre):
			change.disconnect(suivre))


# ---------------------------------------------------------------- application

func _appliquer(cle: String) -> void:
	var v: Variant = valeur(cle)
	match cle:
		"son/general":
			_volume("Master", float(v))
		"son/ambiance":
			_volume("Ambiance", float(v))
		"son/musique":
			_volume("Musique", float(v))
		"son/effets":
			_volume("Effets", float(v))
		"son/voix":
			_volume("Voix", float(v))
		"vocal/seuil":
			var voix := get_node_or_null("/root/Voix")
			if voix:
				voix.seuil_parole = float(v)
		"vocal/peripherique":
			# Un micro débranché depuis : on retombe sur celui de Windows.
			AudioServer.input_device = str(v) if str(v) in Voix.micros_lisibles() else "Default"
			var voix_micro := get_node_or_null("/root/Voix")
			if voix_micro:
				voix_micro.relancer_micro()
		"vocal/sortie":
			var voix_sortie := get_node_or_null("/root/Voix")
			if voix_sortie:
				voix_sortie.regler_sortie(str(v))
		"son/sortie":
			# Casque, enceintes, carte son : ceux qui ne sont pas sur la sortie par défaut n'entendaient rien.
			AudioServer.output_device = str(v) if str(v) in AudioServer.get_output_device_list() else "Default"
		"graphisme/plein_ecran":
			# Plein écran d'emblée (project.godot aussi, dès l'image de lancement). Les essais en fenêtre
			# (--fenetre, --essai…, captures) restent dans une fenêtre de 1600 x 900.
			if DisplayServer.get_name() != "headless":
				var plein := bool(v) and not _fenetre_forcee()
				var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if plein else DisplayServer.WINDOW_MODE_WINDOWED
				if DisplayServer.window_get_mode() != mode:
					DisplayServer.window_set_mode(mode)
					if not plein:
						var ecran := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
						var taille := Vector2i(mini(1600, ecran.size.x), mini(900, ecran.size.y))
						DisplayServer.window_set_size(taille)
						DisplayServer.window_set_position(ecran.position + (ecran.size - taille) / 2)
		"graphisme/echelle":
			get_viewport().scaling_3d_scale = clampf(float(v) / 100.0, 0.5, 1.0)
		"graphisme/vsync":
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(v) else DisplayServer.VSYNC_DISABLED)
		"graphisme/fps_max":
			Engine.max_fps = int(v)
		"langue/choix":
			Langue.appliquer(str(v))
		"camera/utiliser":
			var capteur := get_node_or_null("/root/Capteur")
			if capteur:
				capteur.regler_webcam(bool(v))


func _volume(bus: String, pourcent: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, pourcent <= 0.5)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(pourcent / 100.0, 0.001)))


## Le micro peut-il émettre maintenant ? (coupé, ouvert, ou touche tenue)
func peut_parler() -> bool:
	if not bool(valeur("vocal/micro")):
		return false
	if str(valeur("vocal/mode")) == "appuyer":
		return appuye("parler")
	return true


## Ombres : allumées ou éteintes sur toutes les lumières de la scène.
func appliquer_ombres(racine: Node) -> void:
	var oui := bool(valeur("graphisme/ombres"))
	for l in racine.find_children("*", "Light3D", true, false):
		if not l.has_meta("ombre_origine"):
			l.set_meta("ombre_origine", (l as Light3D).shadow_enabled)
		(l as Light3D).shadow_enabled = oui and bool(l.get_meta("ombre_origine"))


# ---------------------------------------------------------------- fichier

func _lire() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FICHIER) != OK:
		return
	for cle in DEFAUTS:
		var parts := (cle as String).split("/")
		if cfg.has_section_key(parts[0], parts[1]):
			_valeurs[cle] = cfg.get_value(parts[0], parts[1])
	if cfg.has_section("touches"):
		for action in cfg.get_section_keys("touches"):
			var l: Variant = cfg.get_value("touches", action)
			if l is Array:
				_touches[action] = l


func _ecrire() -> void:
	var cfg := ConfigFile.new()
	for cle in _valeurs:
		var parts := (cle as String).split("/")
		cfg.set_value(parts[0], parts[1], _valeurs[cle])
	for action in _touches:
		cfg.set_value("touches", action, _touches[action])
	cfg.save(FICHIER)


func _exit_tree() -> void:
	Langue.liberer()
