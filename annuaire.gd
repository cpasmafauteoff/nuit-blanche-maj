class_name Annuaire
extends Node
## Les lobbies sur Internet, sans serveur à nous : le service gratuit ntfy.sh garde quelques
## heures de petits messages par « sujet ». L'hôte y dépose « code 48213 → mes adresses » et,
## si son lobby est public, une fiche dans la liste commune, renouvelée chaque minute.
## Ce qui part : le nom du lobby, la langue, les pseudos et l'apparence des joueurs, les
## adresses de l'hôte. Jamais d'image de webcam.
## Limites gratuites de ntfy.sh : 250 messages par jour et par adresse, 1 requête toutes les 5 s.

signal code_reserve(code: String)
signal code_trouve(adresses: PackedStringArray)   # vide : code inconnu ou lobby fermé
signal liste_recue(lobbies: Array)
signal hors_ligne                                  # ntfy.sh injoignable

const SERVEUR := "https://ntfy.sh/"
const PREFIXE := "nuitblanche-v1-"
const SUJET_LISTE := PREFIXE + "lobbies"
const VIE_FICHE := 150.0        # une fiche plus vieille : l'hôte est parti sans prévenir
const RENOUVELLEMENT := 60.0
const ECART_MINI := 10.0        # entre deux fiches, même si le lobby change
const LANGUES := [["fr", "Français"], ["en", "English"], ["es", "Español"], ["de", "Deutsch"],
	["it", "Italiano"], ["pt", "Português"]]

var code := ""
var _fiche := {}
var _public := false
var _fiche_t := 0.0             # temps depuis la dernière fiche envoyée
var _fiche_attente := false
var _essais := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


# ---------------------------------------------------------------- règles pures (testées)

static func sujet_code(c: String) -> String:
	return PREFIXE + "code-" + c


static func code_valide(t: String) -> bool:
	return t.length() == 5 and t.is_valid_int() and not t.begins_with("-") and not t.begins_with("+")


static func langue_du_systeme() -> String:
	var l := OS.get_locale_language()
	for x in LANGUES:
		if x[0] == l:
			return l
	return "en"


static func nom_langue(l: String) -> String:
	for x in LANGUES:
		if x[0] == l:
			return x[1]
	return l


## Réponse de ntfy (une ligne JSON par message) → nos messages, avec leur heure dans « _t ».
static func lire_lignes(texte: String) -> Array:
	var sortie := []
	for ligne in texte.split("\n", false):
		var j := JSON.new()   # JSON.new().parse ne crie pas dans la console sur une ligne illisible
		if j.parse(ligne) != OK or not j.data is Dictionary or j.data.get("event", "") != "message":
			continue
		var e: Dictionary = j.data
		if j.parse(str(e.get("message", ""))) != OK:
			continue
		var m: Variant = j.data
		if m is Dictionary:
			m["_t"] = float(e.get("time", 0))
			sortie.append(m)
	return sortie


## Une fiche par code (la plus récente), sans les lobbies fermés ni ceux partis en silence.
static func lobbies_vivants(messages: Array, maintenant: float) -> Array:
	var derniers := {}
	for m: Dictionary in messages:
		var c := str(m.get("code", ""))
		if not code_valide(c):
			continue
		if not derniers.has(c) or float(m["_t"]) >= float(derniers[c]["_t"]):
			derniers[c] = m
	var sortie := []
	for c in derniers:
		var m: Dictionary = derniers[c]
		if m.get("ferme", false) or maintenant - float(m["_t"]) > VIE_FICHE:
			continue
		sortie.append(m)
	sortie.sort_custom(func(a, b): return (a.get("joueurs", []) as Array).size() > (b.get("joueurs", []) as Array).size())
	return sortie


static func filtrer(lobbies: Array, langue: String) -> Array:
	if langue == "":
		return lobbies
	return lobbies.filter(func(m): return m.get("langue", "") == langue)


## Les adresses déposées pour un code ; vide si le lobby a été fermé depuis.
static func adresses_du_code(messages: Array) -> PackedStringArray:
	var dernier: Dictionary = {}
	for m: Dictionary in messages:
		if dernier.is_empty() or float(m["_t"]) >= float(dernier["_t"]):
			dernier = m
	if dernier.is_empty() or dernier.get("ferme", false):
		return PackedStringArray()
	return PackedStringArray(dernier.get("adresses", []))


# ---------------------------------------------------------------- côté hôte

## Tire un code libre (personne ne s'en sert depuis 12 h) puis émet code_reserve.
func reserver() -> void:
	_essais = 0
	_tirer_code()


func _tirer_code() -> void:
	var c := "%05d" % _rng.randi_range(0, 99999)
	_essais += 1
	_lire(sujet_code(c), "12h", func(ok: bool, messages: Array):
		if ok and not adresses_du_code(messages).is_empty() and _essais < 5:
			_tirer_code()
			return
		code = c
		code_reserve.emit(c))


func publier_adresses(adresses: PackedStringArray) -> void:
	if code != "":
		_poster(sujet_code(code), {"code": code, "adresses": Array(adresses)})


## La fiche du lobby dans la liste publique (rien si privé). Renouvelée seule chaque minute.
func afficher(fiche: Dictionary, public: bool) -> void:
	if code == "":
		return
	fiche["code"] = code
	var changee: bool = fiche != _fiche or public != _public
	_fiche = fiche
	_public = public
	if changee and _public:
		_fiche_attente = true


func retirer_de_la_liste() -> void:
	if _public and code != "":
		_poster(SUJET_LISTE, {"code": code, "ferme": true})
	_public = false
	_fiche_attente = false


func fermer() -> void:
	if code == "":
		return
	retirer_de_la_liste()
	_poster(sujet_code(code), {"code": code, "ferme": true})
	code = ""
	_fiche = {}


func _process(delta: float) -> void:
	_fiche_t += delta
	if not _public or code == "":
		return
	if (_fiche_attente and _fiche_t >= ECART_MINI) or _fiche_t >= RENOUVELLEMENT:
		_fiche_attente = false
		_fiche_t = 0.0
		_poster(SUJET_LISTE, _fiche)


# ---------------------------------------------------------------- côté joueur

func chercher(c: String) -> void:
	_lire(sujet_code(c), "12h", func(ok: bool, messages: Array):
		if not ok:
			hors_ligne.emit()
		code_trouve.emit(adresses_du_code(messages)))


func lister() -> void:
	_lire(SUJET_LISTE, "5m", func(ok: bool, messages: Array):
		if not ok:
			hors_ligne.emit()
		liste_recue.emit(lobbies_vivants(messages, Time.get_unix_time_from_system())))


# ---------------------------------------------------------------- HTTP

func _poster(sujet: String, donnees: Dictionary) -> void:
	var h := HTTPRequest.new()
	h.timeout = 8.0
	add_child(h)
	h.request_completed.connect(func(_r, _c, _h, _b): h.queue_free())
	if h.request(SERVEUR + sujet, ["Content-Type: text/plain"], HTTPClient.METHOD_POST, JSON.stringify(donnees)) != OK:
		h.queue_free()


func _lire(sujet: String, depuis: String, rappel: Callable) -> void:
	var h := HTTPRequest.new()
	h.timeout = 8.0
	add_child(h)
	h.request_completed.connect(func(resultat: int, code_http: int, _h, corps: PackedByteArray):
		h.queue_free()
		var ok := resultat == HTTPRequest.RESULT_SUCCESS and code_http == 200
		rappel.call(ok, lire_lignes(corps.get_string_from_utf8()) if ok else []))
	if h.request("%s%s/json?poll=1&since=%s" % [SERVEUR, sujet, depuis]) != OK:
		h.queue_free()
		rappel.call(false, [])
