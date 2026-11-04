extends Node
## Voix de proximité : capture le micro, l'envoie en paquets ADPCM (non fiables),
## et fait parler chaque joueur depuis sa bouille (lecteur 3D).
## Le jeu décide QUI entend QUI : il appelle regler() à chaque image.
## Autoload attendu : Voix = "*res://voix.gd" (chemin /root/Voix identique sur tous les pairs).

const BUS_MICRO := "Micro"
## La nuit, toutes les voix passent par ce bus : même timbre grave et rauque pour tout le monde.
## On comprend ce qui est dit, on ne reconnaît pas qui parle.
const BUS_MASQUE := "VoixNuit"
## Les voix des autres (le volume « Voix des autres joueurs » des réglages).
const BUS_VOIX := "Voix"
const PAQUET_SECONDES := 0.04
const TAILLE_MAX_PAQUET := 400  # un paquet légitime fait ~163 octets
const SILENCE_APRES := 0.3
## La voix a son canal à elle. Sur le canal commun, un paquet « ordonné » plus vieux que le dernier
## reçu est jeté — et les positions des joueurs (17 par seconde et par joueur) en doublaient sans
## cesse : des bouts de phrase disparaissaient.
const CANAL := 1

## Fournie par la partie : envoie mon paquet de voix (données, niveau) — à l'hôte, qui le distribue.
var envoyer: Callable

## Niveau RMS (8000 Hz) au-dessus duquel on parle : en dessous, rien n'est envoyé.
var seuil_parole := 0.02
## Niveau lissé de mon micro (0..1), pour afficher « tu parles trop fort ».
var mon_niveau := 0.0

var _capture: AudioEffectCapture
var _micro: AudioStreamPlayer
var _actif := false
## Micro allumé seulement pour la barre des réglages (hors partie) : on le rend en fermant le panneau.
var _essai := false
## Depuis combien de secondes le micro ne donne que du silence parfait (aucune image, ou que des zéros).
var _muet := 0.0
var _partie := false   # le chat vocal n'existe que partie lancée (décision d'Edwin, 30/10)
var _porte := PorteVoix.new()
var _avant := PackedFloat32Array()  # le bloc juste avant le début de parole
var _tampon := PackedFloat32Array()  # mono, au taux du serveur audio
var _locuteurs: Dictionary = {}  # id -> Dictionary d'état
var _masque := false
## Volume choisi pour chaque joueur (en %, 0 = muet), réglé dans la pause.
var volumes := {}

## Une autre sortie pour les voix que pour le jeu (Edwin, 30/10 : une GoXLR a un canal « Chat » et
## un canal « Game »). Godot n'ouvre qu'une sortie : le bus Voix est alors détourné vers
## BUS_DEHORS (muet ici), capturé, et joué par bin/sortie-voix.exe sur le périphérique choisi.
const BUS_DEHORS := "VoixDehors"
const PROGRAMME_SORTIE := "res://bin/sortie-voix.exe"
var _sortie_pipe: FileAccess
var _sortie_pid := -1
var _sortie_appareil := ""
var _capture_dehors: AudioEffectCapture
static var _sorties_connues: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_creer_bus()


func _creer_bus() -> void:
	if AudioServer.get_bus_index(BUS_VOIX) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS_VOIX)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	if AudioServer.get_bus_index(BUS_MASQUE) < 0:
		AudioServer.add_bus()
		var m := AudioServer.bus_count - 1
		AudioServer.set_bus_name(m, BUS_MASQUE)
		AudioServer.set_bus_send(m, BUS_VOIX)
		var grave := AudioEffectPitchShift.new()
		grave.pitch_scale = 0.74
		AudioServer.add_bus_effect(m, grave)
		var double := AudioEffectChorus.new()
		double.voice_count = 2
		double.wet = 0.55
		AudioServer.add_bus_effect(m, double)
		var rauque := AudioEffectDistortion.new()
		rauque.mode = AudioEffectDistortion.MODE_OVERDRIVE
		rauque.drive = 0.35
		rauque.post_gain = -4.0
		AudioServer.add_bus_effect(m, rauque)
		var etroit := AudioEffectBandPassFilter.new()
		etroit.cutoff_hz = 1300.0
		etroit.resonance = 0.35
		AudioServer.add_bus_effect(m, etroit)
	var idx := AudioServer.get_bus_index(BUS_MICRO)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS_MICRO)
		AudioServer.set_bus_volume_db(idx, -80.0)
		AudioServer.set_bus_mute(idx, true)
		AudioServer.add_bus_effect(idx, AudioEffectCapture.new())
	_capture = AudioServer.get_bus_effect(idx, 0) as AudioEffectCapture
	_capture.buffer_length = 0.5


func demarrer() -> void:
	_essai = false          # la partie prend la main : fermer les réglages ne coupera plus le micro
	if _actif:
		return
	if not bool(ProjectSettings.get_setting("audio/driver/enable_input", false)):
		push_warning("Voix : audio/driver/enable_input est faux, le micro est inactif.")
		return
	if _micro == null:
		_micro = AudioStreamPlayer.new()
		_micro.stream = AudioStreamMicrophone.new()
		_micro.bus = BUS_MICRO
		add_child(_micro)
	_micro.play()
	_capture.clear_buffer()
	_tampon.clear()
	_muet = 0.0
	_actif = true


## La barre « Ton micro en ce moment » doit bouger aussi au menu : avant, le micro n'était allumé
## qu'une fois dans un lobby en ligne, et la barre restait immobile chez tout le monde.
## Hors ligne, rien n'est envoyé (_connecte est faux).
func ecouter_essai(oui: bool) -> void:
	if oui and not _actif:
		demarrer()
		_essai = true
	elif not oui and _essai:
		_essai = false
		arreter()


## Après un changement de micro : on rouvre la prise de son sur le nouveau périphérique.
## Godot rouvre lui-même la prise de son quand `AudioServer.input_device` change : l'arrêter et la
## relancer en plus faisait démarrer le micro deux fois en même temps, et le pilote audio plantait
## le jeu entier (Edwin, 31/10). On ne fait que vider ce qui restait de l'ancien micro.
func relancer_micro() -> void:
	if _actif and _micro != null:
		_capture.clear_buffer()
		_tampon.clear()
		_muet = 0.0


## Vrai si le micro est allumé mais ne rend que du silence parfait depuis plus de 2,5 s :
## Windows bloque l'accès, ou le périphérique choisi n'envoie rien.
func micro_muet() -> bool:
	return _actif and _muet > 2.5


## La partie est lancée (ou finie) : on allume / coupe le chat vocal. Au salon, personne ne
## s'entend et rien ne part — sauf l'essai du micro dans les réglages, qui reste local.
func partie(oui: bool) -> void:
	if oui == _partie:
		return
	_partie = oui
	if oui:
		demarrer()
	elif not _essai:
		arreter()


func en_partie() -> bool:
	return _partie


func arreter() -> void:
	if not _actif:
		return
	_actif = false
	if _micro != null:
		_micro.stop()
	_tampon.clear()
	mon_niveau = 0.0


func _process(delta: float) -> void:
	if _actif:
		_lire_micro(delta)
	_rafraichir_niveaux()
	_pousser_dehors()


# ---------------------------------------------------------------- sortie du tchat vocal

## Les sorties audio du PC, vues par le programme de sortie (ses noms font foi). Vide : pas de programme.
static func sorties_tchat() -> Array:
	if _sorties_connues.is_empty() and OS.get_name() == "Windows":
		var exe := ProjectSettings.globalize_path(PROGRAMME_SORTIE)
		if FileAccess.file_exists(exe):
			var sortie := []
			OS.execute(exe, ["--lister"], sortie)
			if not sortie.is_empty():
				for ligne in str(sortie[0]).split("\n", false):
					if ligne.strip_edges() != "":
						_sorties_connues.append(ligne.strip_edges())
	return _sorties_connues


static var _canaux_micros := {}


## Les micros que Godot sait lire : mono ou stéréo. Un périphérique à 8 ou 16 canaux (câble virtuel,
## table de mixage) bloquait tout le pilote audio, le jeu ne répondait plus (Edwin, 31/10).
static func micros_lisibles() -> PackedStringArray:
	if _canaux_micros.is_empty() and OS.get_name() == "Windows":
		var exe := ProjectSettings.globalize_path(PROGRAMME_SORTIE)
		if FileAccess.file_exists(exe):
			var sortie := []
			OS.execute(exe, ["--lister-entrees"], sortie)
			if not sortie.is_empty():
				for ligne in str(sortie[0]).split("\n", false):
					var parts := ligne.strip_edges().split("\t")
					if parts.size() == 2:
						_canaux_micros[parts[0]] = parts[1].to_int()
	var r := PackedStringArray()
	for nom in AudioServer.get_input_device_list():
		if int(_canaux_micros.get(nom, 2)) <= 2:
			r.append(nom)
	return r


## "" : les voix sortent avec le jeu. Sinon, sur ce périphérique.
func regler_sortie(appareil: String) -> void:
	if appareil == _sortie_appareil and (appareil == "" or OS.is_process_running(_sortie_pid)):
		return
	_fermer_dehors()
	_sortie_appareil = appareil
	var voix := AudioServer.get_bus_index(BUS_VOIX)
	var exe := ProjectSettings.globalize_path(PROGRAMME_SORTIE)
	if appareil == "" or voix < 0 or not FileAccess.file_exists(exe):
		if voix >= 0:
			AudioServer.set_bus_send(voix, "Master")
		return
	var dehors := AudioServer.get_bus_index(BUS_DEHORS)
	if dehors < 0:
		AudioServer.add_bus()
		dehors = AudioServer.bus_count - 1
		AudioServer.set_bus_name(dehors, BUS_DEHORS)
		AudioServer.set_bus_send(dehors, "Master")
		AudioServer.set_bus_volume_db(dehors, -80.0)   # la capture prend le son AVANT ce volume
		var cap := AudioEffectCapture.new()
		cap.buffer_length = 0.3
		AudioServer.add_bus_effect(dehors, cap)
		# Un bus n'envoie qu'à un bus placé AVANT lui : sinon Godot ignore l'envoi, sans rien dire.
		AudioServer.move_bus(dehors, voix)
		dehors = AudioServer.get_bus_index(BUS_DEHORS)
		voix = AudioServer.get_bus_index(BUS_VOIX)
	_capture_dehors = AudioServer.get_bus_effect(dehors, 0) as AudioEffectCapture
	_capture_dehors.clear_buffer()
	var r := OS.execute_with_pipe(exe, ["--appareil", appareil, "--taux", str(int(AudioServer.get_mix_rate()))])
	if r.is_empty():
		AudioServer.set_bus_send(voix, "Master")
		return
	_sortie_pipe = r["stdio"]
	_sortie_pid = int(r["pid"])
	AudioServer.set_bus_send(voix, BUS_DEHORS)


func sortie_separee() -> bool:
	return _sortie_pipe != null


func _pousser_dehors() -> void:
	if _sortie_pipe == null:
		return
	if not OS.is_process_running(_sortie_pid):
		# Le programme s'est arrêté (périphérique débranché…) : les voix reviennent avec le jeu.
		var a := _sortie_appareil
		_fermer_dehors()
		_sortie_appareil = a
		AudioServer.set_bus_send(AudioServer.get_bus_index(BUS_VOIX), "Master")
		return
	var n := _capture_dehors.get_frames_available()
	if n > 0:
		_sortie_pipe.store_buffer(_capture_dehors.get_buffer(n).to_byte_array())   # f32 stéréo entrelacé


func _fermer_dehors() -> void:
	if _sortie_pipe:
		_sortie_pipe.close()
		_sortie_pipe = null
	if _sortie_pid > 0 and OS.is_process_running(_sortie_pid):
		OS.kill(_sortie_pid)
	_sortie_pid = -1
	_sortie_appareil = ""


func _exit_tree() -> void:
	_fermer_dehors()


func _lire_micro(delta: float) -> void:
	var dispo := _capture.get_frames_available()
	var crete := 0.0
	if dispo > 0:
		var trames := _capture.get_buffer(dispo)
		var plus := PackedFloat32Array()
		plus.resize(trames.size())
		for i in range(trames.size()):
			plus[i] = (trames[i].x + trames[i].y) * 0.5
			crete = maxf(crete, absf(plus[i]))
		_tampon.append_array(plus)
	# Un vrai micro a toujours un souffle : du zéro parfait veut dire qu'aucun son n'arrive.
	_muet = _muet + delta if crete == 0.0 else 0.0
	var taux := int(AudioServer.get_mix_rate())
	var par_paquet := maxi(int(taux * PAQUET_SECONDES), 1)
	# Garde-fou : si le jeu a figé, on jette le retard plutôt que d'envoyer du vieux son.
	if _tampon.size() > par_paquet * 12:
		_tampon = _tampon.slice(_tampon.size() - par_paquet * 2)
	var lisse := 0.0
	var compte := 0
	while _tampon.size() >= par_paquet:
		var bloc := _tampon.slice(0, par_paquet)
		_tampon = _tampon.slice(par_paquet)
		var mono8k := CodecVoix.reechantillonner(bloc, taux, CodecVoix.TAUX)
		var n := CodecVoix.niveau(mono8k)
		lisse += n
		compte += 1
		# Un paquet sous le seuil (creux entre deux syllabes, fin de mot) n'était pas envoyé : la voix
		# était hachée comme une radio. On garde l'émission ouverte un moment après la parole, et on
		# envoie le bloc qui précède le début (les consonnes douces).
		var ouvert := _porte.ouvert(n, seuil_parole, PAQUET_SECONDES)
		if _partie and _connecte() and _peut_parler() and envoyer.is_valid():
			if ouvert:
				if not _avant.is_empty():
					envoyer.call(CodecVoix.encoder(_avant), n)
					_avant.clear()
				envoyer.call(CodecVoix.encoder(mono8k), n)
			else:
				_avant = mono8k
		else:
			_avant.clear()
	if compte > 0:
		var moyen := lisse / compte
		# Attaque rapide, relâchement lent.
		mon_niveau = moyen if moyen > mon_niveau else lerpf(mon_niveau, moyen, 0.3)


## Le micro me capte en ce moment, et ma voix part vraiment (le voyant vert du jeu).
func detecte() -> bool:
	return _actif and mon_niveau > seuil_parole and _peut_parler()


## Micro coupé, ou « appuyer pour parler » sans la touche : rien ne part.
func _peut_parler() -> bool:
	var o := get_node_or_null("/root/Options")
	return o == null or o.peut_parler()


func _connecte() -> bool:
	var r := get_node_or_null("/root/Reseau")
	if r == null or not r.en_ligne:
		return false
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## Un paquet de voix venu de `id`, relayé par l'hôte (qui ne le donne qu'à ceux qui ont le droit de
## l'entendre : cf. Meneur.voix_envoyer et regles/visibilite.gd).
func recevoir_de(id: int, donnees: PackedByteArray, niveau_recu: float) -> void:
	if id <= 0 or not _partie or donnees.size() > TAILLE_MAX_PAQUET:
		return
	var l := _locuteur(id)
	var ech := CodecVoix.decoder(donnees)
	if ech.is_empty():
		return
	var pb: AudioStreamGeneratorPlayback = l["lecture"]
	var capacite := int(0.3 * CodecVoix.TAUX)
	var en_tampon: int = capacite - pb.get_frames_available()
	# Tampon anti-gigue : réserve adaptative, coupure en fondu (cf. regles/tampon_voix.gd).
	var mono: PackedFloat32Array = (l["tampon"] as TamponVoix).preparer(ech, en_tampon, Time.get_ticks_msec())
	var trames := PackedVector2Array()
	trames.resize(mono.size())
	for i in range(mono.size()):
		trames[i] = Vector2(mono[i], mono[i])
	if not trames.is_empty() and pb.can_push_buffer(trames.size()):
		pb.push_buffer(trames)  # sinon : trop de retard, on lâche le paquet
	var n := clampf(niveau_recu, 0.0, 1.0)
	l["niveau"] = n if n > l["niveau"] else lerpf(l["niveau"], n, 0.5)
	l["dernier"] = Time.get_ticks_msec()


func _locuteur(id: int) -> Dictionary:
	if _locuteurs.has(id):
		return _locuteurs[id]
	var lecteur := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = CodecVoix.TAUX
	gen.buffer_length = 0.3
	lecteur.stream = gen
	lecteur.unit_size = 4.0
	lecteur.max_distance = 22.0     # chat de proximité : au-delà, on ne s'entend plus
	lecteur.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	lecteur.attenuation_filter_cutoff_hz = 20500.0
	lecteur.volume_db = -80.0  # muet tant que le jeu n'a pas dit « audible »
	lecteur.position = Vector3(0, 1.6, 0)
	lecteur.bus = BUS_MASQUE if _masque else BUS_VOIX
	add_child(lecteur)
	lecteur.play()
	var l := {
		"lecteur": lecteur,
		"lecture": lecteur.get_stream_playback(),
		"niveau": 0.0,
		"dernier": 0,
		"audible": false,
		"etouffe": false,
		"decalage": Vector3.ZERO,
		"id": id,
		"tampon": TamponVoix.new(),
	}
	_locuteurs[id] = l
	return l


## Nuit : toutes les voix masquées ; jour : voix naturelles.
func masquer(oui: bool) -> void:
	if oui == _masque:
		return
	_masque = oui
	for id in _locuteurs:
		(_locuteurs[id]["lecteur"] as AudioStreamPlayer3D).bus = BUS_MASQUE if oui else BUS_VOIX


func est_masque() -> bool:
	return _masque


## (Re)parente le lecteur 3D de ce joueur sous sa tête (position locale 0, 0.9, 0).
func attacher(id: int, parent: Node3D) -> void:
	var l := _locuteur(id)
	var lecteur: AudioStreamPlayer3D = l["lecteur"]
	if lecteur.get_parent() != parent:
		lecteur.get_parent().remove_child(lecteur)
		parent.add_child(lecteur)
	lecteur.position = Vector3(0, 1.6, 0) + (l["decalage"] as Vector3)
	_appliquer(l)


## À appeler chaque image par le jeu : qui entend ce locuteur, et comment.
## `isolation` (0 à 1) : des murs entre nous, porte fermée = 1. La voix arrive, mais trop
## basse et trop sourde pour qu'on comprenne les mots.
## `portee` : jusqu'où porte sa voix (chuchoter 2 m, parler 8 m, crier 15 m ; plus au Conseil).
func regler(id: int, audible: bool, etouffe: bool, decalage: Vector3 = Vector3.ZERO, isolation := 0.0, portee := 22.0) -> void:
	var l := _locuteur(id)
	var lect: AudioStreamPlayer3D = l["lecteur"]
	lect.max_distance = portee + 0.5
	lect.unit_size = clampf(portee * 0.38, 0.8, 24.0)
	l["audible"] = audible
	l["etouffe"] = etouffe
	l["isolation"] = isolation
	l["decalage"] = decalage
	(l["lecteur"] as AudioStreamPlayer3D).position = Vector3(0, 0.9, 0) + decalage
	_appliquer(l)


func _appliquer(l: Dictionary) -> void:
	var lecteur: AudioStreamPlayer3D = l["lecteur"]
	# Un lecteur resté sous l'autoload (non 3D) n'a pas de position réelle : on le tait.
	var rattache := lecteur.get_parent() is Node3D
	if not l["audible"] or not rattache:
		lecteur.volume_db = -80.0
	else:
		lecteur.volume_db = (-9.0 if l["etouffe"] else 0.0) - 15.0 * float(l.get("isolation", 0.0))
		var v := float(volumes.get(l.get("id", -1), 100.0))
		lecteur.volume_db = -80.0 if v <= 0.5 else lecteur.volume_db + linear_to_db(v / 100.0)
	lecteur.attenuation_filter_cutoff_hz = lerpf(700.0, 320.0, float(l.get("isolation", 0.0))) if l["etouffe"] else 20500.0


## Dernier niveau reçu de ce locuteur (lissé) ; 0 s'il se tait depuis 0,3 s.
func niveau(id: int) -> float:
	if not _locuteurs.has(id):
		return 0.0
	var l: Dictionary = _locuteurs[id]
	if Time.get_ticks_msec() - int(l["dernier"]) > int(SILENCE_APRES * 1000.0):
		return 0.0
	return l["niveau"]


func _rafraichir_niveaux() -> void:
	var maintenant := Time.get_ticks_msec()
	for id: int in _locuteurs:
		var l: Dictionary = _locuteurs[id]
		if maintenant - int(l["dernier"]) > int(SILENCE_APRES * 1000.0):
			l["niveau"] = 0.0


## Libère le lecteur d'un joueur parti.
func oublier(id: int) -> void:
	if not _locuteurs.has(id):
		return
	var lecteur: AudioStreamPlayer3D = _locuteurs[id]["lecteur"]
	_locuteurs.erase(id)
	if is_instance_valid(lecteur):
		lecteur.queue_free()
