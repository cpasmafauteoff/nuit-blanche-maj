extends Node
## Le mode streamer (autoload `Streamer`) : pour qui joue en direct.
##
## 1. Le code du lobby ne s'affiche plus : « • • • • • » et un bouton « Copier le code ».
## 2. Le chat Twitch de la chaîne peut voter : connexion ANONYME en LECTURE SEULE (aucun compte,
##    aucun jeton, on n'écrit jamais). Pendant le vote du village, les spectateurs tapent
##    « !vote rouge » ; le streamer voit ce que pense son chat SEULEMENT une fois le vote du
##    village fini, dans un petit panneau en coin. Rien n'est envoyé aux autres joueurs.
## L'analyse des messages et le décompte sont dans regles/twitch_votes.gd (testés).

const PHASES_VOTE := ["vote", "vote_maire"]
const DUREE_PANNEAU := 30.0
const OR := Color(0.92, 0.74, 0.38)
const ENCRE := Color(0.93, 0.86, 0.74)

## Le code du lobby où l'on est (posé par principal.gd), pour le bouton « Copier le code ».
var code_courant := ""
## « hors_ligne » | « connexion » | « en_ligne » | « erreur » : ce que montre la page Réglages.
var etat := "hors_ligne"
var messages_lus := 0

var _ws: WebSocketPeer
var _chaine := ""
var _envoye := false
var _phase := ""
var _vote_ouvert := false
var _vote_maire := false
var _candidats: Array = []
var _votes := {}
var _fin_panneau := 0.0
var _couche: CanvasLayer
var _panneau: PanelContainer
var _titre: Label
var _corps: Label
var _aide: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Options.change.connect(func(cle: String) -> void:
		if cle.begins_with("streamer/"):
			_regler())
	_construire()


## Vrai si le joueur a coché « Mode streamer ».
func mode_actif() -> bool:
	return bool(Options.valeur("streamer/actif"))


func chaine() -> String:
	return TwitchVotes.chaine_valide(str(Options.valeur("streamer/chaine")))


## Le code tel qu'on l'écrit à l'écran : masqué en mode streamer.
func code_affichable(code: String) -> String:
	if not mode_actif():
		return "  ".join(code.split(""))
	return "  ".join("•".repeat(maxi(code.length(), 5)).split(""))


## Le bouton « Copier le code », ajouté au salon quand le code est masqué (sinon rien).
func ajouter_bouton_copier(parent: Container) -> void:
	if not mode_actif() or code_courant == "":
		return
	var b := Button.new()
	b.text = "  Copier le code  "
	b.add_theme_font_size_override("font_size", 18)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(code_courant)
		b.text = "  Code copié ✓  ")
	parent.add_child(b)


# ---------------------------------------------------------------- la partie

## Appelé à chaque état public de la partie (cf. principal.gd).
func sur_pub(pub: Dictionary) -> void:
	var p: String = pub.get("phase", "salon")
	var etait := _phase
	_phase = p
	if not mode_actif():
		_fermer_vote()
		_regler()
		return
	if p in ["salon", "fin"]:
		_vote_ouvert = false
		if p == "salon":
			_cacher()
		_fermer()
	else:
		_ouvrir()
	if p in PHASES_VOTE and etait != p:
		_commencer_vote(pub, p)
	elif etait in PHASES_VOTE and p not in PHASES_VOTE:
		_fermer_vote()


func _commencer_vote(pub: Dictionary, p: String) -> void:
	_vote_ouvert = true
	_vote_maire = p == "vote_maire"
	_votes.clear()
	_candidats.clear()
	var sieges: Dictionary = pub.get("sieges", {})
	for id in sieges:
		var k := int(sieges[id].get("bandeau", -1))
		if sieges[id].get("vivant", true) and k >= 0 and not k in _candidats:
			_candidats.append(k)
	_cacher()
	_montrer_aide("Le chat peut voter : « !vote <couleur du bandeau> »")


## Le village a fini de voter : le streamer découvre ce que pense son chat.
func _fermer_vote() -> void:
	if not _vote_ouvert:
		return
	_vote_ouvert = false
	if not mode_actif():
		return
	var d := TwitchVotes.compter(_votes)
	var noms := _noms()
	_titre.text = "Le chat voulait un maire" if _vote_maire else "Le chat a voté"
	var lignes := PackedStringArray([TwitchVotes.phrase(d, noms)])
	if int(d["total"]) > 0:
		lignes[0] = lignes[0].replace("soupçonne", "voulait élire") if _vote_maire else lignes[0]
		var n := 0
		for part: Array in d["parts"]:
			n += 1
			if n > 1 and n <= 4:
				lignes.append("Bandeau %s (%d %%)" % [noms[int(part[0])], int(part[2])])
		lignes.append(("%d spectateurs" if d["total"] > 1 else "%d spectateur") % d["total"])
	_corps.text = "\n".join(lignes)
	_aide.visible = false
	_corps.visible = true
	_panneau.visible = true
	_fin_panneau = Time.get_ticks_msec() / 1000.0 + DUREE_PANNEAU


func _noms() -> Array:
	return Bouille.BANDEAUX.map(func(b: Array) -> String: return b[1])


func _process(_delta: float) -> void:
	if _panneau and _panneau.visible and _fin_panneau > 0.0 and Time.get_ticks_msec() / 1000.0 > _fin_panneau:
		_cacher()
	if _ws == null:
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _envoye:
				_envoye = true
				etat = "en_ligne"
				# PASS / NICK / JOIN : tout ce que le jeu envoie, jamais un message.
				for l in TwitchVotes.lignes_connexion(_chaine, 70000 + randi() % 9999):
					_ws.send_text(l)
			while _ws.get_available_packet_count() > 0:
				for ligne in TwitchVotes.decouper(_ws.get_packet().get_string_from_utf8()):
					_ligne(ligne)
		WebSocketPeer.STATE_CLOSED:
			_ws = null
			etat = "erreur" if _chaine != "" else "hors_ligne"
			if mode_actif() and _phase not in ["", "salon", "fin"]:
				get_tree().create_timer(5.0).timeout.connect(_ouvrir)


func _ligne(ligne: String) -> void:
	var r := TwitchVotes.analyser(ligne)
	match r["type"]:
		"ping":
			_ws.send_text(r["reponse"])
		"message":
			messages_lus += 1
			if _vote_ouvert:
				var k := TwitchVotes.lire_vote(str(r["texte"]), _candidats, _noms())
				if k >= 0:
					_votes[r["pseudo"]] = k


# ---------------------------------------------------------------- la connexion

## Les réglages ont changé : on (re)connecte ou on coupe.
func _regler() -> void:
	if mode_actif() and _phase not in ["", "salon", "fin"]:
		_ouvrir()
	else:
		_fermer()


func _ouvrir() -> void:
	var c := chaine()
	if not mode_actif() or c == "":
		_fermer()
		return
	if _ws != null and c == _chaine:
		return
	_fermer()
	_chaine = c
	_envoye = false
	etat = "connexion"
	_ws = WebSocketPeer.new()
	if _ws.connect_to_url(TwitchVotes.ADRESSE) != OK:
		_ws = null
		etat = "erreur"


func _fermer() -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.close()
	_ws = null
	_chaine = ""
	_envoye = false
	etat = "hors_ligne"


# ---------------------------------------------------------------- le panneau en coin

func _construire() -> void:
	_couche = CanvasLayer.new()
	_couche.layer = 90
	add_child(_couche)
	_panneau = PanelContainer.new()
	_panneau.visible = false
	_panneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.028, 0.032, 0.92)
	s.border_color = Color(0.72, 0.55, 0.3, 0.8)
	s.set_border_width_all(1)
	s.border_width_left = 4
	s.set_corner_radius_all(4)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 12
	_panneau.add_theme_stylebox_override("panel", s)
	_panneau.anchor_left = 1.0
	_panneau.anchor_right = 1.0
	_panneau.anchor_top = 1.0
	_panneau.anchor_bottom = 1.0
	_panneau.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panneau.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panneau.offset_left = -20
	_panneau.offset_right = -20
	_panneau.offset_top = -24
	_panneau.offset_bottom = -24
	_couche.add_child(_panneau)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_panneau.add_child(v)
	_titre = _etiquette(20, OR)
	v.add_child(_titre)
	_corps = _etiquette(17, ENCRE)
	v.add_child(_corps)
	_aide = _etiquette(15, Color(ENCRE, 0.75))
	v.add_child(_aide)


func _etiquette(taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _montrer_aide(texte: String) -> void:
	_titre.text = "Chat Twitch" + ("" if etat == "en_ligne" else " (connexion…)")
	_aide.text = texte
	_aide.visible = true
	_corps.visible = false
	_panneau.visible = true
	_fin_panneau = Time.get_ticks_msec() / 1000.0 + 6.0


func _cacher() -> void:
	if _panneau:
		_panneau.visible = false
	_fin_panneau = 0.0
