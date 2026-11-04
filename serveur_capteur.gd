class_name ServeurCapteur
extends Node
## Le capteur tourne dans le navigateur (cf. capteur_web/). Ce nœud lui sert la page
## (http://127.0.0.1:4243) et reçoit ses mesures par WebSocket (port 4244), uniquement
## en local : rien n'écoute au-delà de ce PC.

signal message(msg: Dictionary)
signal connecte(oui: bool)

const PORT_PAGE := 4243
const PORT_FLUX := 4244
const DOSSIER := "res://capteur_web/"
const TYPES := {"html": "text/html; charset=utf-8", "js": "text/javascript", "mjs": "text/javascript",
	"wasm": "application/wasm", "task": "application/octet-stream", "css": "text/css"}
const DELAI_REQUETE := 5.0

var _page := TCPServer.new()
var _flux := TCPServer.new()
var _requetes: Array = []           # [StreamPeerTCP, texte reçu, âge]
var _poignees: Array[WebSocketPeer] = []
var _ws: WebSocketPeer = null


func demarrer() -> bool:
	if _page.is_listening():
		return true
	var ok := _page.listen(PORT_PAGE, "127.0.0.1") == OK
	ok = _flux.listen(PORT_FLUX, "127.0.0.1") == OK and ok
	return ok


func adresse() -> String:
	return "http://127.0.0.1:%d/" % PORT_PAGE


func est_connecte() -> bool:
	return _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func envoyer(d: Dictionary) -> void:
	if est_connecte():
		_ws.send_text(JSON.stringify(d))


func _process(delta: float) -> void:
	_servir_page(delta)
	_suivre_flux()


# ---------------------------------------------------------------- la page

func _servir_page(delta: float) -> void:
	while _page.is_listening() and _page.is_connection_available():
		_requetes.append([_page.take_connection(), "", 0.0])
	for r: Array in _requetes.duplicate():
		var c: StreamPeerTCP = r[0]
		c.poll()
		r[2] += delta
		if c.get_status() != StreamPeerTCP.STATUS_CONNECTED or r[2] > DELAI_REQUETE:
			c.disconnect_from_host()
			_requetes.erase(r)
			continue
		var n := c.get_available_bytes()
		if n > 0:
			r[1] += c.get_utf8_string(n)
		if (r[1] as String).contains("\r\n\r\n"):
			_repondre(c, r[1])
			c.disconnect_from_host()
			_requetes.erase(r)


## Le fichier demandé, pris dans capteur_web/ et nulle part ailleurs.
static func chemin_demande(requete: String) -> String:
	var premiere := requete.get_slice("\r\n", 0).split(" ")
	if premiere.size() < 2 or premiere[0] != "GET":
		return ""
	var chemin := premiere[1].get_slice("?", 0).uri_decode().trim_prefix("/")
	if chemin == "":
		chemin = "index.html"
	if chemin.contains("..") or chemin.contains("\\") or chemin.contains(":"):
		return ""
	return chemin


func _repondre(c: StreamPeerTCP, requete: String) -> void:
	var chemin := chemin_demande(requete)
	var fichier := DOSSIER + chemin
	if chemin == "" or not FileAccess.file_exists(fichier):
		c.put_data("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".to_utf8_buffer())
		return
	var octets := FileAccess.get_file_as_bytes(fichier)
	var entete := "HTTP/1.1 200 OK\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-cache\r\nConnection: close\r\n\r\n" \
		% [TYPES.get(chemin.get_extension(), "application/octet-stream"), octets.size()]
	c.put_data(entete.to_utf8_buffer())
	c.put_data(octets)


# ---------------------------------------------------------------- les mesures

func _suivre_flux() -> void:
	while _flux.is_listening() and _flux.is_connection_available():
		var w := WebSocketPeer.new()
		w.inbound_buffer_size = 1 << 20
		if w.accept_stream(_flux.take_connection()) == OK:
			_poignees.append(w)
	for w: WebSocketPeer in _poignees.duplicate():
		w.poll()
		match w.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				_poignees.erase(w)
				if _ws:
					_ws.close()
				_ws = w
				connecte.emit(true)
			WebSocketPeer.STATE_CLOSED:
				_poignees.erase(w)
	if _ws == null:
		return
	_ws.poll()
	if _ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_ws = null
		connecte.emit(false)
		return
	var j := JSON.new()
	while _ws.get_available_packet_count() > 0:
		if j.parse(_ws.get_packet().get_string_from_utf8()) == OK and j.data is Dictionary:
			message.emit(j.data)
