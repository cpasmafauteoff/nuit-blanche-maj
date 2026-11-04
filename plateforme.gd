extends Node
## Steam, quand il est ouvert sur ce PC (autoload `Plateforme`, module GodotSteam).
## Il porte la connexion des parties (cf. Reseau : plus de port à ouvrir sur la box), le bouton
## « Rejoindre la partie » de la liste d'amis Steam, les invitations, et dit quels DLC on possède.
## Sans Steam (fermé, absent, essais sans écran, --sans-steam), tout reste comme avant :
## connexion directe par les adresses de l'hôte.

signal rejoindre_demande(adresse: String)

## Le numéro du jeu sur Steamworks. 480 = Spacewar, le jeu d'essai que Valve prête à tous les
## développeurs : il sert tant que Nuit Blanche n'a pas le sien (inscription d'Edwin en cours).
const APP_ID := 480
const APP_ESSAI := 480
const PREFIXE := "steam:"
const MOT_CONNEXION := "+nuitblanche"   # ce que Steam passe au jeu quand on rejoint un ami

var actif := false
var mon_id := 0
var steam: Object


func _ready() -> void:
	if DisplayServer.get_name() == "headless" or "--sans-steam" in OS.get_cmdline_user_args():
		return
	if not get_node("/root/Options").valeur("reseau/steam") or not Engine.has_singleton("Steam"):
		return
	steam = Engine.get_singleton("Steam")
	var r: Dictionary = steam.steamInitEx(APP_ID, true)
	if int(r.get("status", -1)) != 0:
		print("[steam] pas de Steam : ", r.get("verbal", ""))
		steam = null
		return
	actif = true
	mon_id = steam.getSteamID()
	print("[steam] connecté : ", steam.getPersonaName())
	steam.join_game_requested.connect(func(_ami: int, texte: String): _demande(texte))
	# Lancé par Steam depuis « Rejoindre la partie » : la demande arrive en arguments.
	_demande.call_deferred(" ".join(OS.get_cmdline_args()))
	Progres.pousser_vers_steam.call_deferred()


## « steam:7656… » : l'adresse d'un hôte Steam, à mettre avec les autres dans l'annuaire.
static func adresse(id: int) -> String:
	return PREFIXE + str(id)


static func est_adresse(a: String) -> bool:
	return a.begins_with(PREFIXE) and a.substr(PREFIXE.length()).is_valid_int()


static func id_de(a: String) -> int:
	return a.substr(PREFIXE.length()).to_int() if est_adresse(a) else 0


## Ce que Steam renvoie quand un ami clique « Rejoindre » : « +nuitblanche 7656… ».
static func lire_connexion(texte: String) -> String:
	var mots := texte.split(" ", false)
	var i := mots.find(MOT_CONNEXION)
	if i < 0 or i + 1 >= mots.size() or not mots[i + 1].is_valid_int():
		return ""
	return adresse(mots[i + 1].to_int())


func _demande(texte: String) -> void:
	var a := lire_connexion(texte)
	if a != "" and id_de(a) != mon_id:
		rejoindre_demande.emit(a)


## L'hôte ouvre (ou ferme) sa partie à ses amis Steam : bouton « Rejoindre » et invitations.
func annoncer(ouverte: bool) -> void:
	if not actif:
		return
	steam.setRichPresence("connect", "%s %d" % [MOT_CONNEXION, mon_id] if ouverte else "")
	steam.setRichPresence("status", Langue.t("Au village de Nuit Blanche") if ouverte else "")


## L'invitation passe par la fenêtre Steam par-dessus le jeu (Maj+Tab) : elle n'existe que si le
## jeu a été lancé depuis Steam, pas depuis le zip des testeurs.
func peut_inviter() -> bool:
	return actif and steam.has_method("isOverlayEnabled") and steam.isOverlayEnabled()


func inviter() -> bool:
	if not peut_inviter():
		return false
	steam.activateGameOverlayInviteDialogConnectString("%s %d" % [MOT_CONNEXION, mon_id])
	return true


## La vraie boutique ne s'ouvre qu'avec le vrai numéro du jeu : sous Spacewar, rien à acheter.
func boutique_ouverte() -> bool:
	return actif and APP_ID != APP_ESSAI


## Les succès Steam, eux aussi, n'existent qu'avec le vrai numéro du jeu.
func succes_ouverts() -> bool:
	return actif and APP_ID != APP_ESSAI


func debloquer_succes(id: String) -> void:
	if not succes_ouverts():
		return
	if steam.has_method("getAchievement") and bool(steam.getAchievement(id).get("achieved", false)):
		return
	steam.setAchievement(id)
	steam.storeStats()


func possede_dlc(dlc: int) -> bool:
	return boutique_ouverte() and dlc > 0 and steam.isDLCInstalled(dlc)


func ouvrir_page_dlc(dlc: int) -> void:
	if boutique_ouverte():
		steam.activateGameOverlayToStore(dlc, 0)
