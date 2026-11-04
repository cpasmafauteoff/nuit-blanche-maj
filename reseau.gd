extends Node
## Partie à plusieurs : un joueur héberge, les autres le rejoignent par le code à 5 chiffres
## (cf. Annuaire), qui donne ses adresses : on les essaie l'une après l'autre.
## Steam ouvert chez l'hôte (cf. Plateforme) : la partie passe par Steam, rien à ouvrir sur la box,
## et son adresse est « steam:<son identifiant> ». Sinon, connexion directe : le port est ouvert
## automatiquement sur la box de l'hôte (UPnP) quand c'est possible.

signal adresse_trouvee(texte: String)
signal adresses_pretes(adresses: PackedStringArray)
signal connexion_ok
signal connexion_ratee

const PORT := 7777
## Essais sur un seul PC pendant qu'une vraie partie y tourne : --port=7790 évite de rejoindre celle-ci.
var port := PORT
const MAX_JOUEURS := 16
const DELAI_ESSAI_MS := 4000    # une adresse qui ne répond pas : on passe à la suivante
## Une fois connecté, on tolère qu'un PC se fige quelques secondes (village reconstruit au retour au
## salon, chargement, Windows qui rame) : avant, les 4 s de l'essai restaient en place et un invité
## figé 2,5 s était coupé net (« L'hôte a quitté la partie »).
const DELAI_MIN_MS := 20000
const DELAI_MAX_MS := 60000

var en_ligne := false
var par_steam := false
var steam_manquant := false     # l'hôte joue par Steam, mais Steam n'est pas ouvert ici
var adresses := PackedStringArray()
var _a_essayer: Array[String] = []
var _thread: Thread
var _upnp: UPNP
var _port_ouvert := false


func heberger() -> bool:
	quitter()
	if Plateforme.actif and _heberger_steam():
		return true
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, MAX_JOUEURS) != OK:
		return false
	multiplayer.multiplayer_peer = peer
	en_ligne = true
	if not multiplayer.peer_connected.is_connected(_patience_invite):
		multiplayer.peer_connected.connect(_patience_invite)
	_thread = Thread.new()
	_thread.start(_ouvrir_port)
	return true


func _heberger_steam() -> bool:
	var peer := SteamMultiplayerPeer.new()
	if peer.create_host(0) != OK:
		return false
	multiplayer.multiplayer_peer = peer
	en_ligne = true
	par_steam = true
	adresses = PackedStringArray([Plateforme.adresse(Plateforme.mon_id)])
	Plateforme.annoncer(true)
	call_deferred("emit_signal", "adresse_trouvee", "Par Steam : tes amis te rejoignent sans rien régler sur leur box.")
	call_deferred("emit_signal", "adresses_pretes", adresses)
	return true


## Essaie chaque adresse dans l'ordre ; connexion_ratee seulement quand aucune n'a répondu.
func rejoindre_liste(liste: PackedStringArray) -> void:
	quitter()
	steam_manquant = false
	_a_essayer.assign(Array(liste))
	_essayer_suivante()


func rejoindre(adresse: String) -> bool:
	quitter()
	_a_essayer.clear()
	return _connecter(adresse)


func _essayer_suivante() -> void:
	while not _a_essayer.is_empty():
		if _connecter(_a_essayer.pop_front()):
			return
	connexion_ratee.emit()


func _connecter(adresse: String) -> bool:
	adresse = adresse.strip_edges()
	if Plateforme.est_adresse(adresse):
		if not Plateforme.actif:
			steam_manquant = true
			return false
		var sp := SteamMultiplayerPeer.new()
		if sp.create_client(Plateforme.id_de(adresse), 0) != OK:
			return false
		multiplayer.multiplayer_peer = sp
		par_steam = true
	else:
		var peer := ENetMultiplayerPeer.new()
		if peer.create_client(adresse, port) != OK:
			return false
		peer.get_peer(1).set_timeout(0, DELAI_ESSAI_MS, DELAI_ESSAI_MS)
		multiplayer.multiplayer_peer = peer
	en_ligne = true
	if not multiplayer.connected_to_server.is_connected(_ok):
		multiplayer.connected_to_server.connect(_ok)
		multiplayer.connection_failed.connect(_rate)
	return true


## On quitte la partie (hôte ou invité) : connexion fermée, port de la box refermé.
func quitter() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	en_ligne = false
	if par_steam:
		Plateforme.annoncer(false)
	par_steam = false
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	_thread = null
	if _upnp and _port_ouvert:
		_upnp.delete_port_mapping(PORT, "UDP")
	_port_ouvert = false
	adresses = PackedStringArray()


## Ce qui reconnaît un joueur d'une connexion à l'autre (hôte seulement) : son compte Steam, sinon son
## adresse. L'identifiant réseau, lui, change à chaque connexion. "" : on ne sait pas.
func identite(id: int) -> String:
	var p := multiplayer.multiplayer_peer
	if p is ENetMultiplayerPeer:
		var pair := (p as ENetMultiplayerPeer).get_peer(id)
		if pair != null and pair.get_remote_address() != "":
			return "ip:" + pair.get_remote_address()
	elif p != null and par_steam and p.has_method("get_steam64_from_peer_id"):
		return "steam:%s" % str(p.call("get_steam64_from_peer_id", id))
	return ""


func _ok() -> void:
	_a_essayer.clear()
	_patience(1)
	connexion_ok.emit()


func _rate() -> void:
	en_ligne = false
	par_steam = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_essayer_suivante()


## Adresses de l'hôte, dans l'ordre où les invités les essaient : même maison, Internet, Tailscale.
func _ouvrir_port() -> void:
	# Les box donnent presque toujours du 192.168.x ; 172.x est souvent une
	# carte virtuelle (Docker, WSL) qui ne mène nulle part.
	var locale := ""
	var tailscale := ""
	for prefixe in ["192.168.", "10.", "172."]:
		for ip in IP.get_local_addresses():
			if locale == "" and ip.begins_with(prefixe):
				locale = ip
	for ip in IP.get_local_addresses():
		var o := ip.split(".")
		if o.size() == 4 and o[0] == "100" and int(o[1]) >= 64 and int(o[1]) < 128:
			tailscale = ip
	var liste := PackedStringArray()
	if locale != "":
		liste.append(locale)
	var texte := "Même maison : %s" % locale
	_upnp = UPNP.new()
	if _upnp.discover(2000, 2) == UPNP.UPNP_RESULT_SUCCESS and _upnp.get_gateway() and _upnp.get_gateway().is_valid_gateway():
		_port_ouvert = _upnp.add_port_mapping(PORT, PORT, "Nuit Blanche", "UDP") == UPNP.UPNP_RESULT_SUCCESS
		var publique := _upnp.query_external_address()
		if publique != "":
			liste.append(publique)
			texte += "\nPar Internet : %s  (port ouvert automatiquement)" % publique
	else:
		texte += "\nPar Internet : ta box n'a pas ouvert le port toute seule.\nOuvre le port %d (UDP) vers ce PC, ou utilisez Tailscale (gratuit)." % PORT
	if tailscale != "":
		liste.append(tailscale)
	adresses = liste
	call_deferred("emit_signal", "adresse_trouvee", texte)
	call_deferred("emit_signal", "adresses_pretes", liste)


func _exit_tree() -> void:
	quitter()


## Côté hôte : chaque invité arrivé a droit à la même patience.
func _patience_invite(id: int) -> void:
	_patience(id)


func _patience(id: int) -> void:
	var p := multiplayer.multiplayer_peer
	if p is ENetMultiplayerPeer:
		var pair := (p as ENetMultiplayerPeer).get_peer(id)
		if pair != null:
			pair.set_timeout(0, DELAI_MIN_MS, DELAI_MAX_MS)
