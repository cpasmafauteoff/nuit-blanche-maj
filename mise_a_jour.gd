extends Node
## Mise à jour intégrée, pour les testeurs : au lancement, le jeu compare sa liste de fichiers
## (manifest.json, à côté du jeu) à celle du dépôt public, télécharge seulement les fichiers
## qui ont changé, puis se relance tout seul.
##
## Ne fait rien sans le fichier maj.cfg à côté du jeu : il n'existe que dans le paquet envoyé
## aux testeurs, jamais dans le dossier de développement. Rien non plus en headless (tests).
## L'exécutable lui-même (180 Mo) n'est jamais mis à jour : GitHub refuse les fichiers de plus
## de 100 Mo, et c'est le moteur, qui ne change pas d'une version à l'autre.

signal fini

const DEPOT := "cpasmafauteoff/nuit-blanche-maj"
const BRANCHE := "main"
const SIMULTANES := 4
const ESSAIS := 3

## true tant qu'on ne sait pas encore s'il faut se mettre à jour (Capteur attend avant de lancer
## la fenêtre de la webcam, pour ne pas l'ouvrir deux fois si le jeu se relance).
var en_attente := false
## true si une mise à jour a lieu : le jeu va se relancer.
var redemarre := false

var _dossier := ""
var _sha := ""
var _local := {}
var _distant := {}
var _a_prendre: Array[String] = []
var _suivant := 0
var _en_cours := 0
var _faits := 0
var _octets_total := 0
var _octets_faits := 0
var _echec := ""

var _couche: CanvasLayer
var _ecran: EcranDemarrage
var _debut := 0
## Le village (principal.gd) se construit sous l'écran : on ne le lève qu'une fois fini.
var _village := false
var _part := 0.0
var _apres_maj := false   # relancé par une mise à jour : l'écran le dit
var _leve := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dossier = ProjectSettings.globalize_path("res://")
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or "--sans-maj" in args:
		return
	var vrai := FileAccess.file_exists(_dossier.path_join("maj.cfg"))
	var simule := "--simule-maj" in args
	_apres_maj = "--apres-maj" in args
	# Les essais en fenêtre (captures, parties de test) n'attendent pas l'écran de démarrage.
	var pressee := false
	for a in args:
		if a.begins_with("--essai") or a == "--sans-demarrage":
			pressee = true
	if not pressee:
		_montrer()
	_capturer_demarrage(args)
	if simule:
		_simuler.call_deferred()
		return
	if not vrai:
		# Développement : pas de mise à jour, l'écran attend le village puis passe.
		_terminer.call_deferred("")
		return
	_nettoyer_anciens()
	en_attente = true
	_statut("Recherche de mises à jour…")
	_verifier.call_deferred()


func _verifier() -> void:
	_local = _lire_json(_dossier.path_join("manifest.json"))
	var rep := await _requete("https://api.github.com/repos/%s/commits/%s" % [DEPOT, BRANCHE],
			["Accept: application/vnd.github+json"])
	if rep.is_empty():
		print("[maj] dépôt injoignable")
		return _terminer("À jour")
	var commit = JSON.parse_string(rep.get_string_from_utf8())
	if not commit is Dictionary or not commit.has("sha"):
		return _terminer("À jour")
	_sha = str(commit["sha"])
	var brut := await _requete(_url("manifest.json"))
	var distant = JSON.parse_string(brut.get_string_from_utf8()) if not brut.is_empty() else null
	if not distant is Dictionary or not distant.has("fichiers"):
		print("[maj] liste distante illisible")
		return _terminer("À jour")
	_distant = distant
	if str(_distant.get("version", "")) == str(_local.get("version", "")):
		return _terminer("À jour")
	var anciens: Dictionary = _local.get("fichiers", {})
	for chemin in _distant["fichiers"]:
		var info: Array = _distant["fichiers"][chemin]
		var ancien = anciens.get(chemin)
		if ancien is Array and ancien[0] == info[0] and FileAccess.file_exists(_dossier.path_join(chemin)):
			continue
		_a_prendre.append(chemin)
		_octets_total += int(info[1])
	print("[maj] %s -> %s : %d fichiers" % [_local.get("version", "?"), _distant.get("version", "?"), _a_prendre.size()])
	redemarre = true
	_montrer()
	_rafraichir()
	get_tree().paused = true
	if _a_prendre.is_empty():
		return _appliquer()
	for i in mini(SIMULTANES, _a_prendre.size()):
		_lancer_suivant()


func _lancer_suivant() -> void:
	if _echec != "" or _suivant >= _a_prendre.size():
		return
	var chemin := _a_prendre[_suivant]
	_suivant += 1
	_en_cours += 1
	var ok := false
	for essai in ESSAIS:
		if await _telecharger(chemin):
			ok = true
			break
	_en_cours -= 1
	if not ok:
		_echec = chemin
		_afficher_echec()
		return
	_faits += 1
	_octets_faits += int(_distant["fichiers"][chemin][1])
	_rafraichir()
	if _faits == _a_prendre.size():
		_appliquer()
	else:
		_lancer_suivant()


## Un fichier va d'abord dans « nom.maj », vérifié, puis remplace l'ancien.
func _telecharger(chemin: String) -> bool:
	var cible := _dossier.path_join(chemin)
	DirAccess.make_dir_recursive_absolute(cible.get_base_dir())
	var tmp := cible + ".maj"
	var req := HTTPRequest.new()
	req.download_file = tmp
	req.timeout = 120.0
	req.use_threads = true
	add_child(req)
	if req.request(_url(chemin)) != OK:
		req.queue_free()
		return false
	var r: Array = await req.request_completed
	req.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200:
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.get_md5(tmp) != str(_distant["fichiers"][chemin][0]):
		DirAccess.remove_absolute(tmp)
		return false
	return true


## Tout est arrivé : on remplace les fichiers d'un coup, on retire ceux qui n'existent plus, puis
## on écrit la nouvelle liste en dernier (si quelque chose casse avant, on recommencera).
func _appliquer() -> void:
	for chemin in _a_prendre:
		var cible := _dossier.path_join(chemin)
		var tmp := cible + ".maj"
		if FileAccess.file_exists(cible) and DirAccess.remove_absolute(cible) != OK:
			# Fichier verrouillé (un programme en cours) : Windows permet de le renommer.
			DirAccess.rename_absolute(cible, cible + ".ancien")
		if DirAccess.rename_absolute(tmp, cible) != OK:
			_echec = chemin
			_afficher_echec()
			return
	for chemin in _local.get("fichiers", {}):
		if not _distant["fichiers"].has(chemin):
			DirAccess.remove_absolute(_dossier.path_join(chemin))
	var f := FileAccess.open(_dossier.path_join("manifest.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_distant))
		f.close()
	if _ecran:
		_ecran.statut("Le jeu redémarre…")
		_ecran.progres(100.0)
		_ecran.detail("")
	await get_tree().create_timer(1.0).timeout
	var args: Array[String] = []
	var sauter := false
	for a in OS.get_cmdline_args():
		if sauter:
			sauter = false
			continue
		if a == "--path":
			sauter = true
			continue
		args.append(a)
	# Les réglages de la ligne de commande suivent, et le jeu relancé dira « Mise à jour installée ».
	var apres: Array[String] = ["--"]
	apres.append_array(OS.get_cmdline_user_args())
	if not "--apres-maj" in apres:
		apres.append("--apres-maj")
	OS.create_process(OS.get_executable_path(), ["--path", _dossier] + args + apres)
	get_tree().quit()


## Rien à faire (ou dépôt injoignable) : on le dit, on laisse l'écran un instant, puis le menu ; si le
## village n'est pas encore construit, la barre de chargement prend la suite.
func _terminer(message := "À jour") -> void:
	en_attente = false
	fini.emit()
	if _village:
		_passer(message)
	else:
		_afficher_chargement()


## L'écran de démarrage est-il là (le village s'y construit alors par étapes, cf. principal.gd) ?
func ecran_ouvert() -> bool:
	return _ecran != null and is_instance_valid(_ecran) and not _leve


## La part du village déjà construite (0..1), envoyée par Ronde à chaque étape.
func chargement(part: float) -> void:
	_part = part
	_afficher_chargement()


func _afficher_chargement() -> void:
	if not ecran_ouvert() or en_attente or redemarre:
		return
	_ecran.statut(("Mise à jour installée  ·  " if _apres_maj else "") + "Le village se prépare…")
	_ecran.progres(100.0 * _part)
	_ecran.detail("")


## Le village est construit : l'écran se lève dès que la mise à jour a dit son mot.
func village_pret() -> void:
	if _village:
		return
	_village = true
	if ecran_ouvert() and not en_attente and not redemarre:
		_passer("")


## Dit `message` (s'il y en a un), garde l'écran au moins une seconde en tout, puis le lève.
func _passer(message: String) -> void:
	if not ecran_ouvert():
		return
	_leve = true
	if message != "":
		_ecran.statut(message)
		_ecran.progres(null)
	var ecoule := (Time.get_ticks_msec() - _debut) / 1000.0
	await get_tree().create_timer(maxf(1.0 - ecoule, 0.0) + (0.5 if message != "" else 0.0)).timeout
	if _ecran and is_instance_valid(_ecran):
		_ecran.finir()


## Les fichiers renommés « .ancien » par une mise à jour précédente.
func _nettoyer_anciens() -> void:
	for chemin in _lire_json(_dossier.path_join("manifest.json")).get("fichiers", {}):
		var vieux := _dossier.path_join(chemin) + ".ancien"
		if FileAccess.file_exists(vieux):
			DirAccess.remove_absolute(vieux)


func _url(chemin: String) -> String:
	var morceaux := PackedStringArray()
	for m in chemin.split("/"):
		morceaux.append(m.uri_encode())
	return "https://raw.githubusercontent.com/%s/%s/%s" % [DEPOT, _sha, "/".join(morceaux)]


func _requete(url: String, entetes: Array = []) -> PackedByteArray:
	var req := HTTPRequest.new()
	req.timeout = 20.0
	req.use_threads = true  # le village se construit pendant ce temps : des images très longues
	add_child(req)
	var h := PackedStringArray(["User-Agent: NuitBlanche-maj"] + entetes)
	if req.request(url, h) != OK:
		req.queue_free()
		return PackedByteArray()
	var r: Array = await req.request_completed
	req.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200:
		print("[maj] %s : résultat %d, code %d" % [url, r[0], r[1]])
		return PackedByteArray()
	return r[3]


func _lire_json(chemin: String) -> Dictionary:
	if not FileAccess.file_exists(chemin):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	return d if d is Dictionary else {}


func _montrer() -> void:
	if _ecran != null:
		return
	_debut = Time.get_ticks_msec()
	_couche = CanvasLayer.new()
	_couche.layer = 128
	add_child(_couche)
	_ecran = EcranDemarrage.new()
	_couche.add_child(_ecran)


func _statut(texte: String) -> void:
	if _ecran:
		_ecran.statut(texte)


func _rafraichir() -> void:
	if _ecran == null:
		return
	_ecran.statut("Mise à jour : %d / %d fichiers" % [_faits, _a_prendre.size()])
	_ecran.progres(100.0 * _octets_faits / maxf(1.0, _octets_total))
	_ecran.detail("%.1f / %.1f Mo  ·  Ne ferme pas le jeu, il redémarre tout seul." % [_octets_faits / 1048576.0, _octets_total / 1048576.0])


func _afficher_echec() -> void:
	if _ecran:
		_ecran.echec("La mise à jour n'a pas pu se terminer",
				"Vérifie ta connexion puis relance le jeu : il reprendra où il en était.
(%s)" % _echec)


## Essai (--simule-maj) : une fausse mise à jour pour regarder l'écran, sans réseau ni fichier touché.
func _simuler() -> void:
	en_attente = true
	_statut("Recherche de mises à jour…")
	await get_tree().create_timer(1.6).timeout
	_a_prendre.assign(["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"])
	_octets_total = 38 * 1048576
	for i in _a_prendre.size() + 1:
		_faits = i
		_octets_faits = int(_octets_total * float(i) / _a_prendre.size())
		_rafraichir()
		await get_tree().create_timer(0.45).timeout
	_ecran.statut("Le jeu redémarre…")
	_ecran.detail("")
	await get_tree().create_timer(1.4).timeout
	_terminer("")


## Essai (--capture-demarrage=<dossier>) : photographie l'écran de démarrage, puis ferme le jeu.
func _capturer_demarrage(args: PackedStringArray) -> void:
	var dossier := ""
	for a in args:
		if a.begins_with("--capture-demarrage="):
			dossier = a.substr(20)
	if dossier == "":
		return
	for k in 5:
		await get_tree().create_timer(1.0 if k == 0 else 1.6).timeout
		get_viewport().get_texture().get_image().save_png("%s/demarrage_%d.png" % [dossier, k])
	get_tree().quit()
