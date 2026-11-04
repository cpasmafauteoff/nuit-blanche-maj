extends Node
## Lance le capteur de visage et reçoit ses mesures.
##
## Depuis le 28/10, le capteur tourne dans le NAVIGATEUR (capteur_web/, ouvert par Edge ou Chrome,
## sans fenêtre depuis le 01/11) : un programme signé, que le Contrôle intelligent des applications
## de Windows laisse passer, contrairement à notre ancien tracker.exe non signé.
## Il n'envoie que des nombres (expressions, regard brut, orientation de la tête, taille de
## l'iris), en local. Aucune image n'arrive jusqu'ici. L'ancien tracker reste lançable
## avec l'argument --tracker (développement).

signal etat_change(etat: String)

const PORT := 4242
const DIAMETRE_IRIS_MM := 11.7  # quasi identique chez tous les adultes
const CHAMP_WEBCAM_DEG := 65.0  # champ horizontal typique, corrigé par le joueur

var etat := "demarrage"
var bs := {}
var gx := 0.5
var gy := 0.5
var tx := 0.0
var ty := 0.0
var roulis := 0.0
var iris_px := 0.0
var img_w := 1280
var images_par_s := 0.0
## Bras, jambes, buste vus par la webcam (36 nombres, cf. Bouille.corps_suivi) ; vide si personne.
var corps := PackedFloat32Array()
## Mains et doigts (44 nombres, cf. Bouille.mains_suivi) ; vide si aucune main vue.
var mains := PackedFloat32Array()
## Essai à deux sans webcam : bras et doigts qui bougent tout seuls (--bras-factices).
var _factices := "--bras-factices" in OS.get_cmdline_user_args()
## Vrai quand le jeu se passe de webcam : joueur sans caméra, case « Utiliser ma webcam » décochée,
## caméra perdue ou visage pas revu depuis DELAI_SANS_CAMERA secondes (le retour du visage le coupe
## tout seul). Alors la souris vise, Espace ferme les yeux, et les yeux de l'avatar vivent seuls
## (RegardVivant) : les autres joueurs ne voient AUCUNE différence, rien de particulier ne part sur le réseau.
var mode_souris := false
## La case de Réglages › Caméra.
var utilise_webcam := true
## Écart du regard (rad) et balancement de tête fournis par RegardVivant ; nuls avec une vraie webcam.
var saccade := Vector2.ZERO
## 0..1 : le Conseil, une frayeur… font cligner plus vite (réglé par principal.gd).
var stress := 0.0
## Espace ferme-t-il les yeux de l'avatar (couché, assis) ? Debout, c'est la touche de saut.
var espace_ferme_yeux := true
const DELAI_SANS_CAMERA := 5.0

var _force_souris := false
var _vivant := RegardVivant.new()
var _sans_visage_s := 0.0
var _lance := false

var _udp := PacketPeerUDP.new()
var _serveur: ServeurCapteur
var _pid := -1
var _derniere := -100.0
var _compte := 0
var _chrono := 0.0
var _clignement_souris := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # la pause d'un entraînement ne doit pas le laisser sans écouter
	_udp.bind(PORT, "127.0.0.1")
	_serveur = ServeurCapteur.new()
	add_child(_serveur)
	_serveur.message.connect(_sur_message)
	_serveur.connecte.connect(func(oui: bool):
		if oui:
			_serveur.envoyer({"cmd": "config", "corps": corps_actif})
		elif etat == "ok" or etat == "pas_de_visage":
			_changer("perdu"))
	if "--souris" in OS.get_cmdline_user_args():
		return  # essai sans caméra : on n'allume pas la webcam
	# Mise à jour en vue : le jeu va se relancer, le capteur démarrera à ce moment-là.
	var maj := get_node_or_null("/root/MiseAJour")
	if maj and maj.en_attente:
		await maj.fini
	if maj and maj.redemarre:
		return
	# Les réglages (autoload suivant) disent si la webcam est voulue : ils sont lus dans cette image.
	await get_tree().process_frame
	_lance = true
	if utilise_webcam:
		_lancer()
	else:
		_changer("desactivee")


## La case « Utiliser ma webcam » : décochée, le capteur s'arrête et le jeu passe sans caméra ;
## recochée, elle se rouvre.
func regler_webcam(oui: bool) -> void:
	if oui == utilise_webcam:
		return
	utilise_webcam = oui
	if not _lance or _force_souris:
		return
	if oui:
		_sans_visage_s = 0.0
		_changer("recherche_camera")
		rouvrir()
	else:
		arreter()
		_changer("desactivee")


var camera_index := -1
## Suivi du corps (bras, jambes) : coûteux, coupé sur les petites machines.
var corps_actif := true


## Rallume le capteur avec ou sans suivi du corps.
func regler_corps(oui: bool) -> void:
	if oui == corps_actif:
		return
	corps_actif = oui
	corps = PackedFloat32Array()
	if _par_tracker():
		if _pid > 0:
			arreter()
			_lancer(camera_index)
	else:
		_serveur.envoyer({"cmd": "config", "corps": corps_actif})


func _par_tracker() -> bool:
	return "--tracker" in OS.get_cmdline_user_args()


func _lancer(camera := -1) -> void:
	if not _par_tracker():
		_lancer_navigateur()
		return
	_lancer_tracker(camera)


## Edge (présent sur tout Windows 11) ou Chrome, sans fenêtre (--headless) et avec son propre profil :
## rien ne s'ouvre par-dessus le jeu, la caméra est accordée d'office à cette seule page locale, et
## les réglages ci-dessous l'empêchent de ralentir. --capteur-visible la montre (dépannage).
const NAVIGATEURS := [
	"C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
	"C:/Program Files/Microsoft/Edge/Application/msedge.exe",
	"C:/Program Files/Google/Chrome/Application/chrome.exe",
	"C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
]


## L'adresse de la page du capteur, avec la langue du jeu (la page est traduite par capteur.js).
func _adresse_page() -> String:
	return _serveur.adresse() + ("?lang=en" if Langue.en_anglais() else "")


func _lancer_navigateur() -> void:
	if not _serveur.demarrer():
		_changer("capteur_absent")
		return
	if _serveur.est_connecte():
		_changer("recherche_camera")
		return
	var exe := ""
	for chemin in NAVIGATEURS + [OS.get_environment("LOCALAPPDATA").path_join("Google/Chrome/Application/chrome.exe")]:
		if FileAccess.file_exists(chemin):
			exe = chemin
			break
	if exe == "":
		OS.shell_open(_adresse_page())   # navigateur par défaut, sans les réglages
		_changer("navigateur")
		return
	var profil := ProjectSettings.globalize_path("user://navigateur_capteur")
	var montre := "--capteur-visible" in OS.get_cmdline_user_args()
	_pid = OS.create_process(exe, [
		"--app=" + _adresse_page(), "--user-data-dir=" + profil,
	] + (["--window-size=460,560", "--window-position=30,30"] if montre else ["--headless=new", "--use-fake-ui-for-media-stream"]) + [
		"--no-first-run", "--no-default-browser-check",
		"--disable-backgrounding-occluded-windows", "--disable-renderer-backgrounding",
		"--disable-background-timer-throttling",
	] + (["--use-fake-device-for-media-stream", "--use-fake-ui-for-media-stream"] if "--camera-factice" in OS.get_cmdline_user_args() else []))
	_changer("navigateur" if _pid > 0 else "capteur_absent")


## Le capteur relancé s'il ne répond plus.
func rouvrir() -> void:
	if not _par_tracker() and not _serveur.est_connecte():
		_pid = -1
		_lancer_navigateur()


func _lancer_tracker(camera := -1) -> void:
	var racine := ProjectSettings.globalize_path("res://").path_join("../tracker").simplify_path()
	# Version empaquetée (envoyée aux testeurs) d'abord, puis la version de développement.
	var exe := ""
	var args: Array[String] = []
	for chemin in [racine.path_join("tracker.exe"), racine.path_join("dist/tracker/tracker.exe")]:
		if FileAccess.file_exists(chemin):
			exe = chemin
			break
	if exe == "":
		exe = racine.path_join(".venv/Scripts/pythonw.exe")
		args = ["-I", racine.path_join("tracker.py")]
	if not FileAccess.file_exists(exe):
		_changer("capteur_absent")
		return
	args += ["--port", str(PORT), "--parent", str(OS.get_process_id())]
	if camera >= 0:
		args += ["--camera", str(camera)]
	if not corps_actif:
		args += ["--corps", "0"]
	_pid = OS.create_process(exe, args)
	_changer("recherche_camera" if _pid > 0 else "capteur_absent")


## Passe à la caméra suivante (un PC peut en avoir plusieurs : virtuelle, téléphone…).
func changer_camera() -> void:
	if not _par_tracker():
		if _serveur.est_connecte():
			_serveur.envoyer({"cmd": "camera_suivante"})
		else:
			rouvrir()
		return
	arreter()
	camera_index = (camera_index + 1) % 5
	bs = {}
	_lancer(camera_index)


func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_WM_CLOSE_REQUEST or quoi == NOTIFICATION_PREDELETE:
		arreter()


func arreter() -> void:
	if _pid > 0:
		# pythonw du venv relance le vrai Python : on arrête tout l'arbre.
		OS.execute("taskkill", ["/PID", str(_pid), "/T", "/F"])
		_pid = -1


func _changer(nouvel: String) -> void:
	if nouvel != etat:
		etat = nouvel
		if "--trace-capteur" in OS.get_cmdline_user_args():
			print("[capteur] ", etat)
		etat_change.emit(etat)


func _process(delta: float) -> void:
	var maintenant := Time.get_ticks_msec() / 1000.0
	if _factices:
		_bras_factices(maintenant)
	var dernier_msg = null
	while _udp.get_available_packet_count() > 0:
		var brut := _udp.get_packet().get_string_from_utf8()
		var msg = JSON.parse_string(brut)
		if typeof(msg) == TYPE_DICTIONARY:
			dernier_msg = msg
			_compte += 1
	if dernier_msg != null:
		_derniere = maintenant
		_lire(dernier_msg)
	if _msg_web != null:
		_derniere = maintenant
		_lire(_msg_web)
		_msg_web = null

	_chrono += delta
	if _chrono >= 1.0:
		images_par_s = _compte / _chrono
		if "--trace-capteur" in OS.get_cmdline_user_args() and etat != "souris":
			print("[capteur] %s, %.0f images/s, corps : %d nombres" % [etat, images_par_s, corps.size()])
		_compte = 0
		_chrono = 0.0

	if etat == "ok":
		_sans_visage_s = 0.0
	else:
		_sans_visage_s += delta
	var sans := _force_souris or not utilise_webcam or _sans_visage_s > DELAI_SANS_CAMERA
	if sans != mode_souris:
		if "--trace-capteur" in OS.get_cmdline_user_args():
			print("[capteur] sans caméra : ", sans, " (état ", etat, ")")
		mode_souris = sans
		if not sans:
			saccade = Vector2.ZERO
	# Aucune caméra du tout : inutile de garder le capteur allumé à se plaindre.
	if etat == "pas_de_camera" and _sans_visage_s > 2.0 * DELAI_SANS_CAMERA and _pid > 0:
		arreter()
	if mode_souris:
		_simuler_souris(delta)
	elif etat == "ok" and maintenant - _derniere > 2.0:
		_changer("perdu")


var _msg_web = null


## « Ma tête » : le capteur prend une photo de face (cf. capteur.js prendrePhoto).
signal photo_recue(octets: PackedByteArray, reperes: Dictionary)
signal photo_ratee(texte: String)


func prendre_photo() -> void:
	if _serveur and _serveur.est_connecte():
		_serveur.envoyer({"cmd": "photo"})
	else:
		photo_ratee.emit("Le capteur n'est pas lancé : coche « Utiliser ma webcam » dans les réglages.")


func _sur_message(msg: Dictionary) -> void:
	if msg.has("photo"):
		var octets := Marshalls.base64_to_raw(str(msg["photo"]))
		var r = msg.get("reperes")
		if r is Dictionary and not octets.is_empty():
			photo_recue.emit(octets, r)
		return
	if msg.has("photo_ratee"):
		photo_ratee.emit(str(msg["photo_ratee"]))
		return
	_msg_web = msg
	_compte += 1


## Le bras droit fait de grands cercles, la main droite s'ouvre et se ferme.
func _bras_factices(t: float) -> void:
	var a := t * 1.5
	var haut := Vector3(cos(a) * 0.9, sin(a) * 0.9, 0.3).normalized()
	corps = PackedFloat32Array()
	for d: Vector3 in [haut, haut, Vector3.DOWN, Vector3.DOWN]:
		corps.append_array([d.x, d.y, d.z, 1.0])
	for k in 5:
		corps.append_array([0.0, -1.0 if k < 4 else 1.0, 0.0, 0.0 if k < 4 else 1.0])
	mains = PackedFloat32Array()
	mains.resize(44)
	mains[0] = 1.0
	mains[1] = haut.x
	mains[2] = haut.y
	mains[3] = haut.z
	mains[6] = 1.0
	var pli := (sin(t * 2.0) * 0.5 + 0.5) * 1.4
	for i in 15:
		mains[7 + i] = pli


func _lire(msg: Dictionary) -> void:
	if _force_souris or not utilise_webcam:
		return
	var e: String = msg.get("etat", "")
	var c = msg.get("corps")
	corps = PackedFloat32Array(c) if c is Array else PackedFloat32Array()
	var m = msg.get("mains")
	mains = PackedFloat32Array(m) if m is Array else PackedFloat32Array()
	if e != "ok":
		_changer(e)
		return
	bs = msg["bs"]
	gx = msg["gx"]
	gy = msg["gy"]
	tx = msg["tx"]
	ty = msg["ty"]
	roulis = msg["roulis"]
	iris_px = msg["iris_px"]
	img_w = msg["img_w"]
	camera_index = int(msg.get("camera", camera_index))
	if mode_souris:
		# Le visage est revenu : la vraie webcam reprend la main tout de suite.
		mode_souris = false
		saccade = Vector2.ZERO
	_sans_visage_s = 0.0
	_changer("ok")


## Force le mode sans caméra (essais : --souris). Les joueurs passent par la case de Réglages › Caméra.
func activer_souris(oui: bool) -> void:
	_force_souris = oui
	mode_souris = oui
	if oui:
		_changer("souris")
	else:
		_changer("recherche_camera" if utilise_webcam else "desactivee")


func _simuler_souris(delta: float) -> void:
	_vivant.stress = stress
	_vivant.avancer(delta)
	saccade = _vivant.saccade
	var cible := 1.0 if Input.is_key_pressed(KEY_SPACE) else 0.0
	# On ferme vite, on rouvre doucement : un appui bref laisse entrouvrir les yeux (la Guetteuse épie).
	_clignement_souris = move_toward(_clignement_souris, cible, delta * (8.0 if cible > _clignement_souris else 2.5))
	var voulu := _clignement_souris if espace_ferme_yeux or _force_souris else 0.0
	var clin := maxf(voulu, _vivant.fermeture())
	var sourire := 0.8 if _force_souris and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else 0.0
	bs = {
		"eyeBlinkLeft": clin, "eyeBlinkRight": clin,
		"mouthSmileLeft": sourire, "mouthSmileRight": sourire,
	}
	# La tête reste droite, avec un léger balancement de vivant.
	var regard := get_node_or_null("/root/Regard") if is_inside_tree() else null
	tx = (regard.neutre_tx if regard else 0.0) + _vivant.balancement.x
	ty = (regard.neutre_ty if regard else 0.0) + _vivant.balancement.y
	roulis = 0.0
	if not _factices:
		corps = PackedFloat32Array()
		mains = PackedFloat32Array()
	iris_px = 0.0


func expression(nom: String) -> float:
	return float(bs.get(nom, 0.0))


## 1 = yeux grands ouverts, 0 = fermés.
func ouverture_yeux() -> float:
	if mode_souris:
		# Sans caméra, seuls les yeux fermés EXPRÈS comptent (Espace) : les clignements tout seuls
		# de l'avatar ne doivent rien changer aux règles (Guetteuse, quêtes).
		return clampf(1.0 - _clignement_souris, 0.0, 1.0)
	var clin := (expression("eyeBlinkLeft") + expression("eyeBlinkRight")) * 0.5
	return clampf(1.0 - clin, 0.0, 1.0)


func visage_vu() -> bool:
	return mode_souris or etat == "ok"


## Distance œil-caméra estimée par la taille de l'iris (cm). -1 si inconnue.
func distance_cm(correction: float = 1.0) -> float:
	if iris_px <= 1.0:
		return -1.0
	var focale := img_w / (2.0 * tan(deg_to_rad(CHAMP_WEBCAM_DEG / 2.0)))
	return focale * DIAMETRE_IRIS_MM / iris_px / 10.0 * correction
