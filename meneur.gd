class_name Meneur
extends Node
## Le meneur de partie. Sur l'hôte, il fait tourner les règles (Partie), les minuteries et les
## bots, et décide de tout. Sur chaque joueur (hôte compris), il reçoit l'état et le signale à
## l'affichage. Les joueurs ne lui envoient que des intentions (`intention`), qu'il vérifie.
##
## Phases : salon → tableau (vote de la quête du jour) → quete → pret → (jour 1 : election → vote_maire → elu
## → distribution ; ensuite : conseil → vote → verdict) → nuit → aube → annonce → [trappeur]
## → [successeur] → jour suivant … → fin. Le jour, ce sont les QUÊTES (cf. regles/quetes.gd).
## La nuit est une suite d'APPELS (`_appel`) : le meneur réveille les rôles un par un, les autres
## dorment. Coucher → [Entremetteuse, Enfant : 1re nuit] → Veilleur → Liseuse → Loups (pierre du
## sacrifice, vote d'une maison) → [Solitaire] → Herboriste → cinématique du sacrifice.

signal etat_public(pub: Dictionary)
signal etat_prive(priv: Dictionary)
signal annonce(texte: String, son: String, duree: float)
## `deja_entendu` : la position est déjà celle que CE joueur croit entendre (brouillée par l'hôte).
signal bruit(pos: Vector3, sorte: String, deja_entendu: bool)
signal porte(i: int, quelle: String, ouverte: bool)
signal placement(pos: Vector3, regard: Vector3, mode: String)
signal bots_maj(ids: PackedInt32Array, positions: PackedVector3Array, caps: PackedFloat32Array, regards: PackedVector3Array)
signal trace(pos: Vector3)
signal tombe(nom: String, maison: int)
signal marque(poste: String, oui: bool)
signal noir(oui: bool)
signal fin(resultat: Dictionary)
signal titres_yeux(titres: Array)
signal parole(id: int, texte: String)
## La scène du loup qui mange `victime`, chez elle (maison `maison`). La victime la vit en vrai, les autres la regardent.
signal cinematique(maison: int, victime: int, loups: Array)
signal pierre(tachee: bool)
## Les loups ont trouvé le condamné attaché à la pierre.
signal devore(id: int)
## La vue de SA quête (participants seulement), ~10 fois par seconde ; et sa fin.
signal quete_vue(vue: Dictionary)
signal quete_fin(texte: String, reussie: bool)
signal chute(pos: Vector3, regard: Vector3)   # le marcheur des Lanternes tombe à l'eau : replacé sur sa dernière pierre sûre
signal morsure(vampire: int, cible: int)
signal objets_maj(etat: Array)
## Un caillou lancé par un fantôme : d'où, jusqu'où, et qui il touche (-1 : personne).
signal caillou(de: Vector3, a: Vector3, touche: int)
signal apparition(temoins: Array, pos: Vector3)
## Un caillou lancé par un joueur vivant : d'où, vitesse de départ, durée du vol, point d'arrivée,
## qui il touche (-1 : personne) et où ("tete" | "corps" | "").
## `objet` : l'id de ce qui vole (un caillou, mais aussi un carnet ou une page jetés).
signal caillou_lance(de: Vector3, v0: Vector3, duree: float, fin: Vector3, touche: int, zone: String, objet: int)
## Un geste face à quelqu'un (cf. gestes.gd) : de, cible, type ("propose", "refus", "yeux", ou le geste lui-même) et ses détails.
signal geste(de: int, cible: int, type: String, extra: Dictionary)
## Un message du tchat du lobby, relayé à tous par l'hôte.
signal tchat(nom: String, texte: String)
## Le vote d'exclusion en cours ({} : aucun), tel que tous les humains le voient (cf. regles/exclusion.gd).
signal exclusion_maj(etat: Dictionary)
## Je viens d'être exclu : retour au menu avec ce message.
signal exclu(texte: String)
## Une demande d'exclusion refusée (raison), pour celui qui l'a faite.
signal exclusion_refus(texte: String)

## Réglées pour qu'une partie typique à 8 joueurs dure 20 à 30 minutes (décision d'Edwin, 31/10).
## Un jour ordinaire : vote de la quête 45 + quête ~145 (trajet, rôle, jeu, retour ; 240 au plus) + retour au
## village ~30 (60 au plus) + Conseil 75 + vote 20 + dépouillement 7 + verdict 14 (+ égalité ~7) + nuit ~95
## (distribution 9, coucher 6, loups 45, deux ou trois rôles à 12, cinématique 8) + aube et annonce 12 = ~450 s,
## soit 7,5 min. Le jour 1 remplace Conseil et vote par l'élection du maire (77 s) : ~7 min. Une partie dure
## 3 jours (~21 min) à 4 jours (~29 min), 3 à 4 jours étant ce que mesurent les parties de bots.
## L'hôte peut tout changer au salon.
const DUREES := {"distribution": 9.0, "nuit": 90.0, "aube": 4.0, "annonce": 8.0, "trappeur": 12.0,
	"conseil": 75.0, "vote": 20.0, "depouillement": 7.0, "tranche": 20.0, "verdict": 14.0, "choix_maire": 25.0, "tableau": 15.0, "quete": 240.0,
	"pret": 60.0, "election": 60.0, "vote_maire": 10.0, "elu": 7.0, "successeur": 15.0}
## Durées que l'hôte règle au salon : [clé, libellé, mini, maxi] (secondes).
const REGLAGES_DUREES := [["inscription", "Vote de la quête du jour", 30.0, 120.0],
	["conseil", "Conseil", 20.0, 300.0], ["vote", "Vote", 10.0, 120.0],
	["loups", "Tour des loups", 20.0, 180.0], ["roles", "Tour de chaque rôle (nuit)", 10.0, 60.0]]
const NOMS_BOTS := ["Basile", "Rosalie", "Gaspard", "Mahaut", "Anselme", "Isaure", "Clotaire",
	"Berthe", "Gauvain", "Ysabeau", "Thibaud", "Aldegonde", "Enguerrand", "Mélisende", "Bertrand", "Ermengarde"]
## Les phases du jour (quêtes) : le Vampire y mord, les portes d'entrée s'ouvrent.
const PHASES_JOUR := ["choix_maire", "tableau", "quete", "pret"]
const PORTEE_TABLEAU := 6.0
const ID_BOT := 1000
## Les bots ont les identifiants ID_BOT, ID_BOT + 1… (16 au plus). Les vrais joueurs reçoivent
## du réseau un grand nombre tiré au hasard (ENet comme Steam), presque toujours au-dessus de 1000 :
## « id >= ID_BOT » les prenait tous pour des bots — personne ne voyait bouger personne, et leurs voix
## n'étaient attachées à aucun corps. Seul l'hôte (id 1) passait.
static func est_bot(id: int) -> bool:
	return id >= ID_BOT and id < ID_BOT + 64
const PORTEE_PORTE := 3.0
const PORTEE_PIERRE := 4.5
const PORTEE_PORTE_PROIE := 4.0
## Le vote : on ne change pas de voix (chuchoter / parler / crier) tant qu'il dure.
const PHASES_VOTE := ["vote", "vote_maire", "depouillement", "tranche"]
const PORTEE_MORSURE := 1.6
const APPELS := {"coucher": 6.0, "entremetteuse": 20.0, "enfant": 15.0, "veilleur": 15.0, "liseuse": 20.0,
	"loups": NuitLoups.CHOIX, "solitaire": 30.0, "herboriste": 20.0, "cinematique": 8.5}
## Ce que dit la voix du meneur à chaque appel.
const VOIX_APPEL := {
	"coucher": "La nuit tombe sur la Ronde. Tout le monde va se coucher… fermez les yeux.",
	"entremetteuse": "L'Entremetteuse se réveille. Elle ouvre son carnet et lie deux âmes.",
	"enfant": "L'Enfant sauvage se réveille et choisit son modèle.",
	"veilleur": "Le Veilleur de nuit se réveille. Quelle porte gardera-t-il ?",
	"liseuse": "La Liseuse d'âmes se réveille. Elle ouvre son carnet…",
	"loups": "Les loups se réveillent. Sortez sans bruit… la pierre vous attend.",
	"solitaire": "Le Loup solitaire se réveille. Cette nuit, il chasse seul.",
	"herboriste": "L'Herboriste se réveille. Une porte s'est-elle ouverte cette nuit ?",
	"cinematique": "",
}
const ROLE_APPEL := {"entremetteuse": "entremetteuse", "enfant": "enfant", "veilleur": "veilleur",
	"liseuse": "liseuse", "solitaire": "solitaire", "herboriste": "herboriste"}

## Fournie par l'affichage (hôte) : position actuelle d'un joueur humain.
var position_humain: Callable
## Les gestes face à quelqu'un : anti-spam, propositions à accepter, poussées (côté hôte uniquement).
var gestes := Gestes.new()
## Les carnets des maisons et les pages déchirées (côté hôte ; cf. regles/objets.gd).
var objets: Objets
var _vols: Array = []              # cailloux en l'air : {id, t (reste), fin, touche, zone}
var _cailloux_t := 0.0
const CAILLOUX_REPOUSSE := 6.0     # un caillou repousse toutes les 6 s s'il en manque

# --- état reçu (tous les pairs)
var pub := {}
var priv := {}

# --- état de l'hôte
var partie: Partie
var humains := {}          # id -> {nom, apparence}
var nb_places := 8
## 12 joueurs dans un lobby public, 16 dans un lobby privé (décision d'Edwin, 29/10).
var max_places := 16
## Bots pour compléter les places vides : coupé par défaut, l'hôte les coche pour ses essais.
var avec_bots := false
## Partie classique : 6 vrais joueurs au moins (ou les bots cochés).
const MIN_JOUEURS := 6
## Partie personnalisée (case cochée à la création du lobby, Edwin 03/11) : on lance dès 1 joueur,
## seul pour visiter le village, à deux pour l'essayer, sans bots imposés. En dessous de
## Partie.SEUIL_VICTOIRE, la partie ne se termine pas d'elle-même (cf. Partie.victoire).
const MIN_JOUEURS_PERSO := 1
var personnalisee := false


## Le minimum de vrais joueurs pour lancer sans bots, selon le type de partie.
func min_joueurs() -> int:
	return MIN_JOUEURS_PERSO if personnalisee else MIN_JOUEURS
## Les fantômes : une énergie (0..1) qui remonte en 25 s ; hanter un joueur de quête en coûte
## beaucoup, un caillou peu. Tous les morts gênent tout le monde, quel que soit leur camp.
const RECHARGE_FANTOME := 1.0 / 25.0
const COUT_HANTER := 0.6
const COUT_CAILLOU := 0.15
const PORTEE_HANTER := 5.0
const PORTEE_CAILLOU := 20.0
## Se matérialiser une seconde en monstre : devant UN vivant (pas cher), ou devant tous ceux
## qui sont autour (cher). Décision d'Edwin du 29/10 : « les 2 ».
const COUT_APPARITION := 0.35
const COUT_GRANDE_APPARITION := 0.9
const PORTEE_APPARITION := 4.0
const PORTEE_GRANDE_APPARITION := 7.0
var composition: Array = []
## Le vote d'exclusion (hôte) et les joueurs exclus de ce lobby : leur identité réseau (adresse ou
## compte Steam) ne rentre plus tant que le lobby existe.
var exclusion := Exclusion.new()
var _identites_exclues: Array[String] = []
## Les traces de pas des loups, gardées par l'hôte jusqu'à l'aube (un client n'a pas à les connaître avant).
var _traces_nuit: Array[Vector3] = []
## Qui a l'oreille collée au mur cette nuit (l'intention « oreille ») : il entend les bruits à leur vraie place.
var _oreille_de := {}
var _refuses: Array[int] = []
var sieges := {}           # id -> fiche publique
var phase := "salon"
## La synchronisation du lancement en cours (hôte), sinon null.
var synchro: SynchroLancement = null
var _tchat_logique := TchatLobby.new()
## Durées choisies par l'hôte (voir REGLAGES_DUREES).
## Le vote de la quête dure 45 s (Edwin, 30/10 : à 10 s, « même pas le temps de parler un peu »).
var durees := {"inscription": 45.0, "conseil": DUREES["conseil"], "vote": DUREES["vote"],
	"loups": APPELS["loups"], "roles": 12.0}
## Loups tirés la première nuit (réglé par l'hôte au salon).
var nb_loups := 2
var loups_regles := false       # l'hôte a choisi lui-même : on ne suit plus la taille du village
## Les rôles que l'hôte a retirés de la partie (cf. Quetes.ROLES_RETIRABLES).
var roles_retires: Array = []
var jour_n := 0
var reste := 0.0
## Mode test (le menu de triche, F10) : le minuteur de l'étape et celui des mini-jeux ne bougent plus.
var test_fige := false
var _rng := RandomNumberGenerator.new()
var _bots := {}            # id -> état du bot (voir _nouveau_bot)
var _energie := {}         # fantôme -> énergie (0..1)
var _apparus := {}         # « fantôme:vivant » -> jour de sa dernière frayeur (cf. Apparitions : une par cycle)
var _portee_voix := {}     # joueur -> 0 chuchoter, 1 parler, 2 crier (décision d'Edwin, 29/10)
var _envoi_bots := 0.0
var _envoi_pub := 0.0
var _appel := ""
## Les loups déjà changés en bêtes cette nuit (depuis l'appel de la meute) : les fantômes les voient.
var _loups_transformes: Array[int] = []
var _file_appels: Array[String] = []
var _votes_loups := {}     # loup -> maison votée (appel des loups ou du solitaire)
var _vote_loups_fait := false
var tour_libre := false               # le tutoriel : pas d'étapes chronométrées, le joueur prend son temps
var _tour_total := 0.0                 # durée totale du tour de la meute en cours
var _sortie_forcee_faite := false
var _attaque_jouee := false            # la porte choisie s'est ouverte : la cinématique a été lancée
var _retour_t := -1.0                  # compte à rebours avant de ramener les loups humains dans leur chambre
var _loups_ramenes: Array[int] = []    # ceux déjà ramenés (fondu) pendant ce tour
signal retour_chambre(pos: Vector3, regard: Vector3)
var _resoudre_t := -1.0
var _victimes_nuit := 0    # formes sous le drap, pour la cinématique
var _maisons_ouvertes: Array[int] = []
var _a_prevenir: Array[int] = []   # mordus qui l'apprendront à l'appel des loups
var _apres_trappeur := "jour"
## Les quêtes du jour : {jeu, niveau, recompense, inscrits, etat, zone, mj, t, reussie}.
## etat : inscription → annulee | trajet → jeu → retour → finie.
var _quetes: Array[Dictionary] = []
var _propositions: Array[Dictionary] = []   # (ancien choix du maire : plus utilisé)
## Le vote du matin (décision d'Edwin, 30/10) : joueur -> 0..2 (une quête) ou Quetes.RESTER.
var _votes_quete := {}
## Ce que chacun a accompli, compté par l'hôte pour les succès (cf. Succes.faits_partie) :
## id -> {quetes, quetes_dur, quetes_extreme, hantes: [ids], apparitions, cailloux}.
var _compteurs := {}
## Le village a voté « Rester » (ou personne n'est parti) : un temps libre avant le Conseil.
var _jour_libre := false
var _indices: Array[String] = []            # le panneau à côté du tableau, pour tout le village
var _recents: Array = []                    # les jeux d'hier
var _prets := {}
var _auto_humains := {}    # humains en pilote auto (agent testeur) : joués comme des bots aux quêtes
var _envoi_quetes := 0.0
var _messages := {}        # id -> [textes à annoncer en privé]
var _annonces: Array[String] = []
var _garde := -1
## Le vote du Conseil (décisions d'Edwin, 29/10) : on dépouille devant tout le monde, le maire
## tranche une égalité, et le condamné est attaché à la pierre, où les loups le dévorent la nuit.
var _resultat := {}            # {compte: {id: voix}, en_tete: [id]}
var _condamne := -1
var _tranche_par := -1         # le maire qui tranche (-1 : le sort)
var _tranche_candidats: Array = []
var _attache := -1             # le condamné, mort pour les règles, encore à la pierre
var _attache_lie := false      # couché sur la dalle, enchaîné
var _supplice_n := 0
var _savoir_bots := {}     # id bot -> {suspect: id, innocents: []}


func _ready() -> void:
	_rng.randomize()


func est_hote() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


func moi() -> int:
	return multiplayer.get_unique_id()


# ================================================================ salon (hôte)

func joueur_arrive(id: int, nom: String, apparence: int) -> void:
	humains[id] = {"nom": nom, "apparence": apparence}
	if synchro != null:
		synchro.ajouter(id)
	if phase == "salon":
		# Jamais moins de places que de gens présents : sinon les derniers arrivés restaient
		# sans siège au lancement, et tout ce qu'ils faisaient était ignoré.
		if humains.size() > nb_places:
			nb_places = mini(humains.size(), max_places)
			_suivre_taille()
		_pub_salon()


func joueur_parti(id: int) -> void:
	humains.erase(id)
	gestes.oublier(id)
	_oublier_pour_exclusion(id)
	_tchat_logique.oublier(id)
	if synchro != null:
		synchro.retirer(id)
	if phase == "salon":
		_pub_salon()
	elif sieges.has(id):
		# Il quitte en pleine partie : plus de bot à sa place (Edwin, 30/10). Il sort du village comme
		# un mort, sans révéler son rôle ; la partie continue sans lui, ou s'arrête si un camp a gagné.
		sieges[id]["parti"] = true
		# « bot » coupe tout envoi vers lui (messages, vues de quête, placements) et toute attente de
		# sa réponse ; mais rien ne le pilote : il n'entre pas dans `_bots`.
		sieges[id]["bot"] = true
		if phase == "fin" or not partie.vivant(id):
			_envoyer_pub(_etat_pub())
			return
		var trappeur_attendu := phase == "trappeur" and partie.trappeur_attendu() == id
		partie.quitter(id)
		_vider_evenements()
		if not _annonces.is_empty():
			_annoncer_a_tous(char(10).join(_annonces), "glas", 4.0)
			_annonces.clear()
		if trappeur_attendu:
			partie.trappeur_renonce()
		var v := partie.victoire()
		if v != "":
			_terminer(v)
			return
		# Le maire s'en va : le sort désigne son successeur (il n'est plus là pour le choisir).
		if partie.maire_a_remplacer > 0:
			partie.designer_successeur(partie.maire_a_remplacer, -1)
			_vider_evenements()
			_annoncer_a_tous("Le maire n'est plus. Le sort désigne %s pour porter l'écharpe." % qui(partie.maire), "glas", 4.0)
			if phase == "successeur":
				_apres_annonce()
				return
		if trappeur_attendu:
			_apres_annonce()
			return
		_envoyer_pub(_etat_pub())


func regler_salon(places: int, compo: Array) -> void:
	nb_places = clampi(maxi(places, humains.size()), 6, max_places)
	_suivre_taille()
	composition = compo.duplicate() if compo.size() == nb_places else Roles.composition(nb_places)
	_pub_salon()


## Le nombre de loups suit la taille du village tant que l'hôte n'y a pas touché, et ne dépasse
## jamais ce qu'il supporte.
func _suivre_taille() -> void:
	# Sans bots, le village a la taille des gens présents (cf. lancer_partie et le salon).
	var taille := nb_places if _bots_actifs() else clampi(humains.size(), min_joueurs(), max_places)
	nb_loups = clampi(nb_loups, 1, Partie.loups_max(taille)) if loups_regles else Partie.loups_conseilles(taille)


func regler_duree(cle: String, valeur: float) -> void:
	durees[cle] = valeur
	_pub_salon()


func regler_loups(n: int) -> void:
	nb_loups = clampi(n, 1, 4)
	loups_regles = true
	_pub_salon()


## L'hôte met un rôle dans la partie, ou l'en retire. Le loup ne se retire pas.
func regler_role(role: String, oui: bool) -> void:
	if not Quetes.ROLES_RETIRABLES.has(role):
		return
	roles_retires.erase(role)
	if not oui:
		roles_retires.append(role)
	_pub_salon()


## Toutes les durées réglables, telles que l'hôte les a choisies.
func durees_reglees() -> Dictionary:
	return durees.duplicate()


## L'hôte passe à l'étape suivante sans attendre la fin du minuteur.
func passer_etape() -> void:
	if not est_hote() or partie == null or phase in ["salon", "fin"]:
		return
	reste = 0.0


func _pub_salon() -> void:
	_suivre_taille()
	if composition.size() != nb_places:
		composition = Roles.composition(nb_places)
	var liste := {}
	for id in humains:
		liste[id] = humains[id].duplicate()
	var d := {"phase": "salon", "humains": liste, "places": nb_places, "max_places": max_places, "composition": composition,
		"durees": durees_reglees(), "bots": avec_bots, "perso": personnalisee, "min": min_joueurs(), "nb_loups": nb_loups, "sans": roles_retires.duplicate()}
	if synchro != null:
		# Le village se construit chez tout le monde pendant la scène d'attente (cf. SynchroLancement).
		d["synchro"] = synchro.etat()
		d["nb_maisons"] = nb_places
	_envoyer_pub(d)


func regler_bots(oui: bool) -> void:
	avec_bots = oui
	_pub_salon()


## Sans bots, il faut assez de vrais joueurs pour une partie. Hors ligne (essai seul), toujours des bots.
func peut_lancer() -> bool:
	return _bots_actifs() or humains.size() >= min_joueurs()


func _bots_actifs() -> bool:
	var r := get_node_or_null("/root/Reseau")
	return avec_bots or r == null or not r.en_ligne


## Le bouton « Commencer » : ne lance pas tout de suite, ouvre la scène de synchronisation. Chacun y
## charge le village ; la partie démarre quand tous sont prêts (au moins 8 s, au plus 45 s).
func lancer_partie() -> void:
	if not est_hote() or (partie != null and phase != "salon") or synchro != null:
		return
	if not peut_lancer():
		_annoncer_a_tous("Il faut au moins %d joueurs pour commencer (ou cocher « Bots »)." % MIN_JOUEURS, "", 4.0)
		return
	if not _bots_actifs():
		nb_places = clampi(humains.size(), min_joueurs(), max_places)
	else:
		nb_places = clampi(maxi(nb_places, humains.size()), min_joueurs(), max_places)
	_suivre_taille()
	synchro = SynchroLancement.new()
	synchro.demarrer(humains.keys())
	_pub_salon()


## Le top de départ, donné par l'hôte au même instant pour tous.
func _tick_synchro(delta: float) -> void:
	synchro.avancer(delta)
	if not synchro.pret_a_lancer():
		return
	var tardifs := synchro.retardataires()
	if not tardifs.is_empty():
		print("[synchro] départ sans réponse de ", tardifs)
	synchro = null
	if peut_lancer():
		_lancer_maintenant()
	else:
		_pub_salon()
		_annoncer_a_tous("Il faut au moins %d joueurs pour commencer (ou cocher « Bots »)." % MIN_JOUEURS, "", 4.0)


func _lancer_maintenant() -> void:
	if not _bots_actifs():
		nb_places = clampi(humains.size(), min_joueurs(), max_places)
	else:
		nb_places = clampi(maxi(nb_places, humains.size()), min_joueurs(), max_places)
	_suivre_taille()
	if composition.size() != nb_places:
		composition = Roles.composition(nb_places)
	_remettre_a_zero()
	var liste := []
	var ids := humains.keys()
	ids.sort()
	for id in ids.slice(0, nb_places):
		liste.append({"id": id, "nom": humains[id]["nom"]})
	var noms := NOMS_BOTS.duplicate()
	noms.shuffle()
	var k := 0
	while liste.size() < nb_places:
		# Plus de places que de prénoms (ou un humain qui porte le même) : on numérote plutôt que
		# de tourner sans fin — c'est ce qui figeait la partie à 16 au salon.
		var nom: String = noms[k % noms.size()] + ("" if k < noms.size() else " " + Ronde.CHIFFRES[mini(k / noms.size(), 15)])
		k += 1
		var pris := false
		for l in liste:
			if l["nom"] == nom:
				pris = true
		if pris:
			continue
		liste.append({"id": ID_BOT + k, "nom": nom})
	# Le village prend la taille de la partie : une maison par joueur, plus le temple.
	Ronde.configurer(liste.size())
	partie = Partie.new()
	_nuits_loups.clear()
	_stats_yeux.clear()
	_stats_t = -1.0
	partie.roles_retires = roles_retires.duplicate()
	partie.configurer_quetes(liste, _rng.randi())
	var bandeaux := range(liste.size())
	for k2 in range(bandeaux.size() - 1, 0, -1):
		var j := _rng.randi_range(0, k2)
		var tmp: int = bandeaux[k2]
		bandeaux[k2] = bandeaux[j]
		bandeaux[j] = tmp
	for n_l in liste.size():
		var l: Dictionary = liste[n_l]
		var id: int = l["id"]
		var bot := not humains.has(id)
		sieges[id] = {"nom": l["nom"], "maison": partie.joueurs[id]["maison"], "vivant": true, "bot": bot, "role": "",
			"apparence": humains[id]["apparence"] if not bot else Cosmetiques.pour_bot(Bouille.au_hasard(_rng), _rng), "bandeau": bandeaux[n_l]}
		if bot:
			_bots[id] = _nouveau_bot(id)
			_bots[id]["pos"] = Ronde.depart(int(sieges[id]["maison"]))   # devant sa maison, comme les joueurs
			_savoir_bots[id] = {"suspect": -1, "innocents": []}
	objets = Objets.new()
	var tables: Array = []
	for i in Ronde.NB_MAISONS:
		tables.append(Ronde.table_carnet(i))
	objets.poser_carnets(tables)
	var par_bandeau: Array = sieges.keys()
	par_bandeau.sort_custom(func(a, b): return int(sieges[a]["bandeau"]) < int(sieges[b]["bandeau"]))
	var paires: Array = []
	for sid in par_bandeau:
		paires.append([Bouille.nom_bandeau(int(sieges[sid]["bandeau"])), str(sieges[sid]["nom"])])
	objets.ajouter_page_bandeaux(Objets.page_bandeaux(paires))
	objets.semer_cailloux(Cailloux.tirer(_rng, Objets.CAILLOUX_DEPART * 4))
	_vols.clear()
	_cailloux_t = CAILLOUX_REPOUSSE
	_envoyer_objets()
	_portes_toutes_fermees()
	_nouveau_jour()


# ================================================================ exclusion (hôte)

## Le nom d'un joueur dans un vote : le bandeau en partie, le pseudo au salon.
func _libelle_joueur(id: int) -> String:
	if partie != null and sieges.has(id):
		return qui(id)
	return str(humains.get(id, {}).get("nom", "un joueur"))


func _maintenant() -> float:
	return Time.get_ticks_msec() / 1000.0


## Ce qu'on a le droit de faire : l'hôte exclut directement, les autres demandent un vote.
func _intention_exclusion(id: int, type: String, a: Variant) -> void:
	var refus := ""
	match type:
		"exclure":
			refus = exclure(int(a)) if id == 1 else "Seul l'hôte peut exclure directement."
		"exclusion_demande":
			refus = demander_exclusion(id, int(a))
		"exclusion_vote":
			if exclusion.voter(id, bool(a)):
				_publier_exclusion()
				_verifier_exclusion()
	if refus != "" and humains.has(id):
		_exclusion_refus_rpc.rpc_id(id, refus)


func demander_exclusion(par: int, contre: int) -> String:
	var r := exclusion.demander(par, contre, 1, humains.keys(), _maintenant())
	if r == "":
		_annoncer_a_tous("Un vote d'exclusion est ouvert contre %s." % _libelle_joueur(contre), "", 4.0)
		_publier_exclusion()
	return r


## L'hôte exclut sans vote.
func exclure(contre: int) -> String:
	if contre == 1:
		return "On ne peut pas exclure l'hôte."
	if not humains.has(contre):
		return "Ce joueur n'est plus là."
	_expulser(contre)
	return ""


func _publier_exclusion() -> void:
	_exclusion_rpc.rpc(exclusion.etat())


func _verifier_exclusion() -> void:
	var v := exclusion.verdict()
	if v == "":
		return
	var cible := exclusion.cible
	var nom := _libelle_joueur(cible)
	exclusion.annuler()
	_publier_exclusion()
	if v == "exclu" and humains.has(cible):
		_annoncer_a_tous("Le vote est acquis : %s est exclu de la partie." % nom, "", 4.0)
		_expulser(cible)
	else:
		_annoncer_a_tous("Le vote d'exclusion contre %s n'a pas abouti." % nom, "", 4.0)


## Il est exclu : il le sait, il repart au menu, son identité ne revient plus. Dans la partie, c'est un
## départ comme un autre (cf. joueur_parti).
func _expulser(id: int) -> void:
	var cle := _identite(id)
	if "--auto" in OS.get_cmdline_user_args():
		print("[exclusion] identité de l'exclu : '%s'" % cle)
	if cle != "" and not _identites_exclues.has(cle):
		_identites_exclues.append(cle)
	_refuses.append(id)
	_exclu_rpc.rpc_id(id, "Tu as été exclu de la partie.")
	joueur_parti(id)
	_couper_plus_tard(id)


## Un exclu qui retente de se connecter : on le renvoie aussitôt.
func refuser_exclu(id: int) -> void:
	if "--auto" in OS.get_cmdline_user_args():
		print("[exclusion] connexion refusée à ", id)
	_refuses.append(id)
	_exclu_rpc.rpc_id(id, "Tu as été exclu de cette partie : tu ne peux pas y revenir.")
	_couper_plus_tard(id)


func est_refuse(id: int) -> bool:
	return _refuses.has(id)


func identite_exclue(cle: String) -> bool:
	return cle != "" and _identites_exclues.has(cle)


func _identite(id: int) -> String:
	var r := get_node_or_null("/root/Reseau")
	return r.identite(id) if r != null else ""


## Le temps que son message lui parvienne, puis la connexion est coupée.
func _couper_plus_tard(id: int) -> void:
	get_tree().create_timer(0.8, false).timeout.connect(func():
		_refuses.erase(id)
		var p := multiplayer.multiplayer_peer
		# (Souvent déjà parti de lui-même en lisant son message.)
		if "--trace-pubs" in OS.get_cmdline_user_args(): print("[coupe] ", id)
		if p != null and not p is OfflineMultiplayerPeer and p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED 				and multiplayer.get_peers().has(id):
			p.disconnect_peer(id))


## Un joueur s'en va : le vote qui le visait tombe, et celui où il était électeur se recompte.
func _oublier_pour_exclusion(id: int) -> void:
	var etait := exclusion.en_cours()
	exclusion.oublier(id)
	if etait and est_hote():
		_publier_exclusion()
		_verifier_exclusion()


@rpc("authority", "call_local", "reliable")
func _exclusion_rpc(etat: Dictionary) -> void:
	exclusion_maj.emit(etat)


@rpc("authority", "call_remote", "reliable")
func _exclu_rpc(texte: String) -> void:
	exclu.emit(texte)


@rpc("authority", "call_local", "reliable")
func _exclusion_refus_rpc(texte: String) -> void:
	exclusion_refus.emit(texte)



# ================================================================ boucle de l'hôte

func _process(delta: float) -> void:
	if synchro != null and est_hote():
		_tick_synchro(delta)
	if _stats_t > 0.0 and est_hote():
		_stats_t -= delta
		if _stats_t <= 0.0:
			_publier_titres()
	if exclusion.en_cours() and est_hote():
		exclusion.avancer(delta)
		_verifier_exclusion()
	if not est_hote() or partie == null or phase in ["salon", "fin"]:
		return
	if phase == "nuit" and _appel in ["loups", "solitaire"]:
		_enregistrer_loups(delta)
	if not test_fige:
		reste -= delta
	# Essai : --vite-la-nuit saute le jour (chaque phase de jour dure une seconde) pour atteindre la nuit.
	if "--vite-la-nuit" in OS.get_cmdline_user_args() and phase in ["tableau", "quete", "pret", "election", "vote_maire", "elu", "choix_maire"]:
		reste = minf(reste, 1.0)
	_bots_avancer(delta)
	_cailloux_tick(delta)
	for id in sieges:
		if not partie.vivant(id):
			_energie[id] = minf(1.0, float(_energie.get(id, 1.0)) + delta * RECHARGE_FANTOME)
	if phase not in ["nuit", "distribution"]:
		_apparitions_bots(delta)
	else:
		_rentrer_tick(delta)
	match phase:
		"nuit":
			if _resoudre_t >= 0.0:
				_resoudre_t -= delta
				if _resoudre_t < 0.0:
					_resoudre_vote_loups()
			if _appel == "loups" and not tour_libre and not _vote_loups_fait and NuitLoups.sortie_forcee(_ecoule_tour(), _sortie_forcee_faite):
				_sortie_forcee_faite = true
				_transformer_les_retardataires()
			if _retour_t >= 0.0:
				_retour_t -= delta
				if _retour_t < 0.0:
					_ramener_loups_humains()
			if _appel == "loups" and _attache > 0:
				for l in _chasseurs_appel():
					if _position(l).distance_to(Ronde.PIERRE) < 2.6:
						_devorer()
						break
			_bots_nuit_tick(delta)
		"choix_maire", "tableau", "pret":
			_bots_journee_tick(delta)
		"quete":
			_bots_journee_tick(delta)
			_quetes_tick(delta)
		"vote", "vote_maire":
			_bots_vote_tick(delta)
	_envoi_bots += delta
	if _envoi_bots > 0.1:
		_envoi_bots = 0.0
		_envoyer_bots()
	_envoi_pub += delta
	if _envoi_pub > 1.0:
		_envoi_pub = 0.0
		_envoyer_pub(_etat_pub())
	if reste <= 0.0:
		_suivante()


func _entrer(p: String) -> void:
	phase = p
	for i in Ronde.NB_MAISONS:
		if maison_close(i):
			_clore_maison(i, false)
	reste = durees["inscription"] if p == "tableau" else durees.get(p, DUREES.get(p, 5.0))
	match p:
		"choix_maire":
			_annoncer_a_tous("Le maire, %s, choisit les trois quêtes du jour." % qui(partie.maire), "", 4.0)
			if sieges[partie.maire]["bot"]:
				var m := partie.maire
				get_tree().create_timer(_rng.randf_range(3.0, 7.0), false).timeout.connect(func():
					if phase == "choix_maire" and partie.maire == m:
						var k := range(_propositions.size())
						k.shuffle()
						traiter(m, "choisir_quetes", k.slice(0, Quetes.NB_DU_JOUR)))
		"tableau":
			var texte := "Votez pour la quête du jour (touches 1 à 4) : la plus votée part, tout le village avec elle, sauf ceux qui votent « Rester ». Le détail de chaque quête est au tableau."
			if _maire_actif():
				texte = "%s, le maire, choisit la quête du jour parmi les trois du tableau. Les autres répondent : 1 Participer, 2 Ne pas participer." % qui(partie.maire, true)
			if jour_n == 1:
				texte = "Premier jour. Personne n'a de rôle : il se gagne aux quêtes. %s" % texte
			_annoncer_a_tous(texte, "cloche", 6.0)
			_bots_votes_quete()
			# Essai du mode fantôme : l'hôte meurt au premier tableau (--mourir).
			if "--mourir" in OS.get_cmdline_user_args() and partie.vivant(moi()):
				partie._mourir(moi(), "chagrin")
				_vider_evenements()
		"quete":
			_annoncer_a_tous("Les équipes partent : un chemin s'ouvre dans la lisière. Les autres attendent au village.", "", 5.0)
		"pret":
			_prets.clear()
			if _jour_libre:
				_annoncer_a_tous("Le village reste aujourd'hui : temps libre. Appuie sur {pret} quand tu es prêt à passer au Conseil.", "cloche", 5.0)
			else:
				_annoncer_a_tous("Tout le monde est rentré. Appuie sur {pret} quand tu es prêt à passer au Conseil.", "cloche", 5.0)
			for id in _bots:
				if partie.vivant(id):
					get_tree().create_timer(_rng.randf_range(2.0, 14.0), false).timeout.connect(func():
						if phase == "pret":
							traiter(id, "pret"))
		"election":
			_tous_au_conseil("assis")
			_prets.clear()
			_annoncer_a_tous("Le village se choisit un maire. Sa voix comptera double, au Conseil comme au vote des quêtes, et il désignera son successeur. Débattez, puis appuyez tous sur {pret} quand vous êtes d'accord pour passer au vote.", "cloche", 7.0)
			# Les bots disent « prêt » au bout d'un délai humain, pendant le débat.
			for id in _bots:
				if partie.vivant(id):
					get_tree().create_timer(_rng.randf_range(Prets.BOT_MIN, Prets.BOT_MAX), false).timeout.connect(func():
						if phase == "election":
							traiter(id, "pret"))
		"vote_maire":
			partie.commencer_conseil()
			for b in _bots:
				_bots[b]["vote_t"] = _rng.randf_range(1.0, maxf(2.0, DUREES["vote_maire"] - 2.0))
			_annoncer_a_tous("Votez pour votre maire : fixez-le, puis cliquez.", "coeur", 3.0)
		"elu":
			var m := partie.elire_maire()
			_vider_evenements()
			_annoncer_a_tous("%s est élue maire de la Ronde." % qui(m, true), "cloche", reste)
		"successeur":
			var ancien := partie.maire_a_remplacer
			_annoncer_a_tous("%s était le maire : elle désigne son successeur." % qui(ancien, true), "glas", 4.0)
			if sieges[ancien]["bot"]:
				get_tree().create_timer(_rng.randf_range(2.0, 6.0), false).timeout.connect(func():
					if phase == "successeur":
						traiter(ancien, "successeur", -1))
		"distribution":
			if not partie.loups_tires:
				# Essais : --loup=invite (un invité est loup) ou --loup=hote.
				for arg in OS.get_cmdline_user_args():
					if arg == "--loup=hote":
						partie.loups_preferes = [1]
					elif arg == "--loup=invite1":
						var invites: Array = humains.keys().filter(func(h): return h != 1)
						invites.sort()
						partie.loups_preferes.assign(invites.slice(0, 1))
					elif arg == "--loup=invite":
						partie.loups_preferes.assign(humains.keys().filter(func(h): return h != 1))
				partie.tirer_loups(nb_loups)
				_vider_evenements()
				_envoyer_prives()   # chacun apprend s'il est loup
			for id in sieges:
				if id != _attache:
					_placer(id, Ronde.lit(sieges[id]["maison"]), _fenetre(id), "chambre")
		"nuit":
			_traces_nuit.clear()
			_oreille_de.clear()
			partie.commencer_nuit()
			_vider_evenements()
			_garde = -1
			_victimes_nuit = 0
			_maisons_ouvertes.clear()
			_pierre_rpc.rpc(false)
			_portes_fermees_sauf_dehors()
			for id in sieges:
				if partie.vivant(id):
					_placer(id, Ronde.lit(sieges[id]["maison"]), _fenetre(id), "chambre")
			_file_appels.assign(["coucher"])
			# Elles se gagnent aux quêtes : appelées la première nuit où elles ont un choix à faire.
			for r in ["entremetteuse", "enfant"]:
				if partie.doit_choisir(r):
					_file_appels.append(r)
			for r in ["veilleur", "liseuse"]:
				if _role_en_jeu(r):
					_file_appels.append(r)
			_file_appels.append("loups")
			if _role_en_jeu("solitaire") and partie.solitaire_peut_tuer():
				_file_appels.append("solitaire")
			if _role_en_jeu("herboriste"):
				_file_appels.append("herboriste")
			# Dernier acte : la scène de la ou des victimes, puis le jour se lève tout de suite (Edwin, 03/11).
			_file_appels.append("cinematique")
			_scene_file.clear()
			_scene_initiale = false
			_scene_victime = -1
			_scenes_jouees = 0
			_appel = ""
			_appel_suivant()
			return
		"aube":
			_appel = ""
			_loups_transformes.clear()
			_devorer()
			_achever_scene()
			var mange: bool = _scenes_jouees > 0
			partie.fin_nuit()
			if mange:
				# La scène vient de se jouer : le mort devient fantôme TOUT DE SUITE (Edwin, 03/11 : « j'étais encore
				# humain 10 secondes »), et le village se réveille sans autre attente. L'annonce suivra.
				partie.resoudre_aube()
			_vider_evenements()
			_portes_toutes_fermees()
			_pierre_rpc.rpc(_victimes_nuit > 0)
			_annoncer_a_tous("Le jour se lève sur la Ronde…", "", 1.5 if mange else 3.5)
		"annonce":
			for t in _traces_nuit:
				_trace_rpc.rpc(t)
			_traces_nuit.clear()
			partie.resoudre_aube()
			_vider_evenements()
			_portes_toutes_fermees()
			_tous_au_conseil("fige")
			var texte := "\n".join(_annonces) if not _annonces.is_empty() else "Le jour se lève. Personne n'est mort cette nuit."
			_annonces.clear()
			_annoncer_a_tous(texte, "glas", reste)
			_apres_trappeur = "jour"
		"trappeur":
			var t := partie.trappeur_attendu()
			_annoncer_a_tous("%s était le Trappeur : elle a 10 secondes pour emporter quelqu'un avec elle." % qui(t, true), "coeur", 4.0)
			if sieges[t]["bot"]:
				_bots_trappeur(t)
		"conseil":
			_tous_au_conseil("assis")
			_annoncer_a_tous("La cloche appelle au Conseil. Débattez : qui sont les loups ?", "cloche", 4.0)
			_bots_debattent()
		"vote":
			partie.commencer_conseil()
			_condamne = -1
			_resultat = {}
			for b in _bots:
				_bots[b]["vote_t"] = _rng.randf_range(3.0, 22.0)
			_annoncer_a_tous("Votez : fixez celui que vous accusez, puis cliquez. Ton vote reste secret, et tu peux en changer jusqu'à la fin.", "coeur", 4.0)
		"depouillement":
			_resultat = partie.depouiller()
			_annoncer_a_tous("Les voix sont comptées.", "cloche", 3.0)
		"tranche":
			var en_tete: Array = _resultat.get("en_tete", [])
			_tranche_candidats = en_tete.duplicate() if not en_tete.is_empty() else Array(partie.vivants())
			_tranche_par = partie.maire if partie.maire > 0 and partie.vivant(partie.maire) else -1
			if _tranche_par < 0:
				_condamne = _tranche_candidats[_rng.randi_range(0, _tranche_candidats.size() - 1)]
				_annoncer_a_tous("Pas de maire pour trancher : le sort désigne qui sera attaché.", "", 3.0)
				reste = 2.5
			else:
				var pourquoi := "Égalité." if not en_tete.is_empty() else "Personne n'a voté."
				_annoncer_a_tous("%s Le maire désigne qui sera attaché à la pierre." % pourquoi, "glas", 5.0)
				if sieges[_tranche_par]["bot"]:
					var m := _tranche_par
					get_tree().create_timer(_rng.randf_range(3.0, 6.0), false).timeout.connect(func():
						if phase == "tranche" and _condamne < 0:
							traiter(m, "trancher", _tranche_candidats[_rng.randi_range(0, _tranche_candidats.size() - 1)]))
		"verdict":
			var r := partie.resoudre_vote(_condamne)
			if r["elimine"] > 0:
				_attache = r["elimine"]
				_attache_lie = false
			_vider_evenements()
			var texte := ""
			if r["elimine"] > 0:
				texte = "Le Conseil a tranché : %s sera attachée à la pierre. Cette nuit, les loups viendront." % qui(r["elimine"])
				_supplice(r["elimine"])
			elif r["gracie"] > 0:
				texte = "%s était le Simplet : on la gracie au dernier moment. Elle ne votera plus." % qui(r["gracie"], true)
				reste = 7.0
			else:
				texte = "Le Conseil n'a pas su trancher. Personne n'est éliminé."
				reste = 7.0
			_annonces.clear()
			_annoncer_a_tous(texte, "glas" if r["elimine"] > 0 else "", 6.0)
			_apres_trappeur = "nuit"
	_envoyer_pub(_etat_pub())
	_envoyer_prives()


func _suivante() -> void:
	match phase:
		"choix_maire":
			if _quetes.is_empty():
				_poser_quetes(_propositions.slice(0, Quetes.NB_DU_JOUR))
			_entrer("tableau")
		"tableau":
			_resoudre_vote_quete()
		"quete":
			# Un jeu en cours n'est jamais coupé avant son propre temps limite (Edwin, 01/11).
			var restes := []
			for q in _quetes:
				if q["etat"] == "jeu" and not (q["mj"] as MiniJeu).fini:
					restes.append((q["mj"] as MiniJeu).reste())
			var encore := Quetes.prolongation(restes)
			if encore > 0.0:
				reste = encore
				return
			_forcer_fin_quetes()
			_entrer("pret")
		"pret":
			_entrer("election" if jour_n == 1 else "conseil")
		"election":
			_entrer("vote_maire")
		"vote_maire":
			_entrer("elu")
		"elu":
			_annoncer_a_tous("Le soleil se couche. Rentrez chez vous… cette nuit, les loups se réveillent.", "glas", 4.0)
			_entrer("distribution")
		"successeur":
			if partie.maire_a_remplacer > 0:
				partie.designer_successeur(partie.maire_a_remplacer, -1)
			_vider_evenements()
			_apres_annonce()
		"distribution":
			_entrer("nuit")
		"nuit":
			_appel_suivant()
		"aube":
			_entrer("annonce")
		"annonce":
			_apres_annonce()
		"trappeur":
			if partie.trappeur_attendu() > 0:
				partie.trappeur_renonce()
			_vider_evenements()
			_apres_annonce()
		"conseil":
			_entrer("vote")
		"vote":
			_entrer("depouillement")
		"depouillement":
			var en_tete: Array = _resultat.get("en_tete", [])
			if en_tete.size() == 1:
				_condamne = en_tete[0]
				_entrer("verdict")
			else:
				_entrer("tranche")
		"tranche":
			if _condamne < 0 and not _tranche_candidats.is_empty():
				_condamne = _tranche_candidats[_rng.randi_range(0, _tranche_candidats.size() - 1)]
			_entrer("verdict")
		"verdict":
			_apres_annonce()


## Le supplice (décision d'Edwin, 29/10) : le maire va chercher le condamné sur son rondin et
## l'attache sur la pierre ; si c'est le maire le condamné (ou qu'il n'y a pas de maire), deux
## villageois tirés au sort s'en chargent. Tout se joue tout seul ; chacun garde la tête libre.
func _supplice(id: int) -> void:
	_supplice_n += 1
	var n := _supplice_n
	var porteurs: Array = []
	if partie.maire > 0 and partie.vivant(partie.maire) and partie.maire != id:
		porteurs = [partie.maire]
	else:
		var v := Array(partie.vivants())
		v.shuffle()
		porteurs = v.slice(0, 2)
	var m: int = sieges[id]["maison"]
	var souche := Ronde.souche(m)
	var travers := Vector3(souche.z, 0, -souche.x).normalized()
	var etapes := [
		[0.3, func():
			for k in porteurs.size():
				_placer(porteurs[k], souche + travers * (0.85 if k == 0 else -0.85), souche + Vector3(0, 0.9, 0), "fige")],
		[5.0, func():
			# Sur la terrasse du temple, devant l'autel (côté place).
			_placer(id, Ronde.PIERRE + Vector3(0, 0, -1.3), Ronde.PIERRE, "traine")
			for k in porteurs.size():
				_placer(porteurs[k], Ronde.PIERRE + Vector3(-0.75 if k == 0 else 0.75, 0, -1.75), Ronde.PIERRE, "fige")],
		[10.0, func():
			_attache_lie = true
			_placer(id, Ronde.PIERRE + Vector3(0.75, Ronde.PIERRE_HAUT, 0), Ronde.PIERRE + Vector3(0.75, 3.0, 0), "attache")
			if _bots.has(id):
				_bots[id]["mode"] = "attache"
				_bots[id]["chemin"] = []
			_jouer_chaines_rpc.rpc()
			for p in porteurs:
				if partie.vivant(p):
					_placer(p, Ronde.souche(sieges[p]["maison"]), Vector3(0, 0.9, 0), "assis")
			_envoyer_pub(_etat_pub())],
	]
	for e: Array in etapes:
		get_tree().create_timer(e[0], false).timeout.connect(func():
			if _supplice_n == n and _attache == id and phase == "verdict":
				(e[1] as Callable).call())


@rpc("authority", "call_local", "reliable")
func _jouer_chaines_rpc() -> void:
	annonce.emit("", "chaines", 0.0)


## Les loups trouvent le condamné sur la pierre : il meurt pour de bon, et devient un fantôme.
func _devorer() -> void:
	if _attache <= 0 or partie == null:
		return
	var id := _attache
	_attache = -1
	_attache_lie = false
	_devore_rpc.rpc(id)
	_victimes_nuit += 1
	_annonces.append("%s a été dévorée sur la pierre." % qui(id, true))
	_tombe_rpc.rpc(etiquette(id), sieges[id]["maison"])
	_placer(id, Ronde.souche(sieges[id]["maison"]), Vector3.ZERO, "fantome")
	if _bots.has(id):
		_bots[id]["mode"] = "fantome"
		_bots[id]["pos"] = Ronde.souche(sieges[id]["maison"])
		_bots[id]["chemin"] = []
	_envoyer_pub(_etat_pub())


## Après une annonce de morts : le Trappeur, puis la victoire, puis la suite.
func _apres_annonce() -> void:
	if partie.trappeur_attendu() > 0:
		_entrer("trappeur")
		return
	var v := partie.victoire()
	if v != "":
		_terminer(v)
		return
	if partie.maire_a_remplacer > 0 and phase != "successeur":
		_entrer("successeur")
		return
	if _apres_trappeur == "jour":
		_nouveau_jour()
	else:
		_entrer(_apres_trappeur)


func _terminer(camp: String) -> void:
	phase = "fin"
	var roles := {}
	for id in sieges:
		roles[id] = partie.role(id)
		sieges[id]["role"] = partie.role(id)
	var textes := {"village": "Le village a gagné : tous les loups sont morts.",
		"meute": "La meute a gagné : le village est tombé.",
		"solitaire": "Le Loup solitaire a gagné : il est le dernier vivant.",
		"amoureux": "Les amours interdits ont gagné : ils sont les deux derniers.",
		"personne": "Personne n'a survécu à Nuit Blanche."}
	var res := {"camp": camp, "texte": textes.get(camp, camp), "roles": roles, "gagnants": partie.gagnants(camp),
		"sieges": sieges.duplicate(true), "chronique": texte_chronique(partie),
		"faits": Succes.faits_partie(partie, _compteurs, partie.gagnants(camp))}
	# La nuit vue des loups : envoyée une fois la partie finie seulement (rien n'en sort avant : anti-triche).
	res["nuits_loups"] = _nuits_loups.duplicate(true)
	_stats_yeux.clear()
	_stats_t = DELAI_STATS_YEUX
	for i in Ronde.NB_MAISONS:
		_porte_rpc(i, "avant", true)
	_envoyer_pub(_etat_pub())
	_fin_rpc.rpc(res)


## Le récit de la partie, révélé à la fin : qui est mort, comment, et les votes du Conseil.
static func texte_chronique(p: Partie) -> PackedStringArray:
	var l := PackedStringArray()
	var causes := {"loups": "dévoré par la meute", "solitaire": "tué par le loup solitaire", "potion": "empoisonné par l'Herboriste",
		"vote": "éliminé par le Conseil", "chagrin": "mort de chagrin", "trappeur": "emporté par le Trappeur", "parti": "parti en pleine partie"}
	var qui := func(id: int) -> String:
		return "%s (%s)" % [p.nom(id), Roles.nom(p.role(id))] if p.joueurs.has(id) else "?"
	for e: Dictionary in p.chronique:
		var au_conseil: bool = e["type"] == "vote" or (e["type"] == "mort" and e.get("cause", "") in ["vote", "trappeur"])
		var quand := ("Conseil %d" if au_conseil else "Nuit %d") % e["n"]
		match e["type"]:
			"mort":
				l.append("%s — %s : %s" % [quand, qui.call(e["id"]), causes.get(e["cause"], e["cause"])])
			"sauve":
				l.append("%s — %s attaqué, sauvé par l'Herboriste" % [quand, qui.call(e["id"])])
			"devient_loup":
				l.append("%s — %s rejoint la meute en secret" % [quand, qui.call(e["id"])])
			"maire":
				l.append("Jour — %s devient maire" % qui.call(e["id"]))
			"role_gagne":
				var nom_r: String = e["titre"] if e["titre"] != "" else Roles.nom(e["role"])
				if e.get("quete", "") != "":
					l.append("Jour %d — %s gagne à la quête (%s) : %s" % [e["n"] + 1, p.nom(e["id"]), e["quete"], nom_r])
				else:
					l.append("Jour %d — %s gagne à la quête : %s" % [e["n"] + 1, p.nom(e["id"]), nom_r])
			"vote":
				var votes: Dictionary = e["votes"]
				if votes.is_empty():
					l.append("%s — personne n'a voté" % quand)
				else:
					var parts := PackedStringArray()
					for v in votes:
						parts.append("%s → %s" % [p.nom(v), p.nom(votes[v])])
					l.append("%s — %s" % [quand, ", ".join(parts)])
	return l


# ---------------------------------------------------------------- la nuit vue des loups, et les yeux

const CADENCE_LOUPS := 0.5          # une position toutes les 0,5 s
const MAX_ECHANTILLONS_LOUPS := 600
const DELAI_STATS_YEUX := 6.0       # on n'attend pas plus longtemps les chiffres des webcams

var _nuits_loups: Array = []        # {n, loups: {id: PackedVector2Array (x, z)}, attaques: [{maison, victime, reussi, t}]}
var _loups_t := 0.0
var _stats_yeux := {}               # id -> chiffres envoyés par chaque jeu à la fin
var _stats_t := -1.0


func _nuit_loups_courante() -> Dictionary:
	if _nuits_loups.is_empty() or int(_nuits_loups.back()["n"]) != partie.nuit_n:
		_nuits_loups.append({"n": partie.nuit_n, "loups": {}, "attaques": []})
		_loups_t = CADENCE_LOUPS
	return _nuits_loups.back()


## Pendant l'appel des loups, l'hôte note où ils sont, deux fois par seconde.
func _enregistrer_loups(delta: float) -> void:
	_loups_t += delta
	if _loups_t < CADENCE_LOUPS:
		return
	_loups_t = 0.0
	var nuit := _nuit_loups_courante()
	var loups: Dictionary = nuit["loups"]
	for id in partie.chasseurs():
		if not loups.has(id):
			# Un loup qui n'était pas encore dehors : on remplit le début avec sa première position.
			var debut := PackedVector2Array()
			var deja := 0
			for autre in loups:
				deja = (loups[autre] as PackedVector2Array).size()
				break
			var p0 := _position(id)
			for k in deja:
				debut.append(Vector2(p0.x, p0.z))
			loups[id] = debut
		var tab: PackedVector2Array = loups[id]
		if tab.size() >= MAX_ECHANTILLONS_LOUPS:
			continue
		var p := _position(id)
		tab.append(Vector2(p.x, p.z))
		loups[id] = tab


func _noter_attaque(maison: int, victime: int, reussi: bool) -> void:
	var nuit := _nuit_loups_courante()
	var t := 0
	for id in nuit["loups"]:
		t = maxi(t, (nuit["loups"][id] as PackedVector2Array).size() - 1)
	(nuit["attaques"] as Array).append({"maison": maison, "victime": victime, "reussi": reussi, "t": t})


## Chaque jeu envoie ses chiffres à l'hôte quand la partie est finie (un dictionnaire vide : pas de webcam).
func envoyer_stats_yeux(d: Dictionary) -> void:
	if est_hote():
		_recevoir_stats_yeux(moi(), d)
	else:
		_stats_yeux_rpc.rpc_id(1, d)


@rpc("any_peer", "call_remote", "reliable")
func _stats_yeux_rpc(d: Dictionary) -> void:
	if est_hote():
		_recevoir_stats_yeux(multiplayer.get_remote_sender_id(), d)


func _recevoir_stats_yeux(id: int, d: Dictionary) -> void:
	if phase != "fin" or not sieges.has(id) or _stats_yeux.has(id):
		return
	var propre := {}
	for cle in ["suivi", "clin", "clin_proces", "proces", "vote", "detourne", "ferme_nuit", "frayeurs", "ecarquille"]:
		if d.has(cle) and (d[cle] is float or d[cle] is int):
			propre[cle] = clampf(float(d[cle]), 0.0, 100000.0)
	_stats_yeux[id] = propre
	for autre in sieges:
		if not est_bot(autre) and not _stats_yeux.has(autre):
			return
	_publier_titres()


func _publier_titres() -> void:
	_stats_t = -1.0
	if phase != "fin":
		return
	var noms := {}
	for id in sieges:
		noms[id] = sieges[id]["nom"]
	var stats := _stats_yeux.duplicate()
	if "--stats-factices" in OS.get_cmdline_user_args():
		_stats_factices(stats)
	_titres_rpc.rpc(StatsYeux.titres(stats, noms))


## Essais (--stats-factices) : des chiffres inventés pour les bots, pour voir l'écran de fin.
func _stats_factices(stats: Dictionary) -> void:
	var k := 0
	for id in sieges:
		if not est_bot(id):
			continue
		k += 1
		stats[id] = {"suivi": 900.0, "clin": 110 + k * 37, "clin_proces": 38 if k == 1 else k, "proces": 40.0, "vote": 30.0,
			"detourne": 9.0 if k == 2 else (0.0 if k == 3 else 1.0), "ferme_nuit": 55.0 if k == 4 else 5.0, "frayeurs": 4,
			"ecarquille": 3 if k == 5 else 0}


@rpc("authority", "call_local", "reliable")
func _titres_rpc(titres: Array) -> void:
	titres_yeux.emit(titres)


## Après le récit de fin, l'hôte ramène tout le monde au MÊME salon, connexions gardées : chacun
## garde son apparence, et la partie est remise à zéro (cf. `_remettre_a_zero`).
func rejouer() -> void:
	if not est_hote() or phase != "fin":
		return
	_stats_t = -1.0
	_remettre_a_zero()
	phase = "salon"
	_envoyer_objets()
	_portes_toutes_fermees()
	for i in Ronde.NB_MAISONS:
		_porte_rpc(i, "avant", true)
	_pub_salon()
	for id in humains:
		_placer(id, Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(5, 8)), Vector3.ZERO, "libre")


## Tout ce qu'une partie laisse derrière elle côté hôte : rôles, morts, quêtes, objets, fantômes, votes,
## minuteurs. Les réglages du salon (places, durées, loups, rôles retirés, bots) et les humains
## présents restent. Appelé au retour au salon et avant chaque lancement.
func _remettre_a_zero() -> void:
	synchro = null
	partie = null
	objets = null
	sieges.clear()
	_bots.clear()
	_savoir_bots.clear()
	_energie.clear()
	_apparus.clear()
	_portee_voix.clear()
	_loups_transformes.clear()
	tour_libre = false
	_file_appels.clear()
	_votes_loups.clear()
	_vote_loups_fait = false
	_resoudre_t = -1.0
	_victimes_nuit = 0
	_maisons_ouvertes.clear()
	_a_prevenir.clear()
	_apres_trappeur = "jour"
	_appel = ""
	_quetes.clear()
	_propositions.clear()
	_votes_quete.clear()
	_jour_libre = false
	_indices.clear()
	_recents.clear()
	_prets.clear()
	_auto_humains.clear()
	_messages.clear()
	_annonces.clear()
	_garde = -1
	_resultat = {}
	_condamne = -1
	_tranche_par = -1
	_tranche_candidats.clear()
	_attache = -1
	_attache_lie = false
	_supplice_n = 0
	_vols.clear()
	_traces_nuit.clear()
	_oreille_de.clear()
	_cailloux_t = CAILLOUX_REPOUSSE
	_rentre_t = 0.0
	_envoi_bots = 0.0
	_envoi_pub = 0.0
	_envoi_quetes = 0.0
	gestes = Gestes.new()
	jour_n = 0
	reste = 0.0
	test_fige = false
	priv = {}
	_compteurs.clear()
	_nuits_loups.clear()
	_loups_t = 0.0
	_stats_yeux.clear()


# ================================================================ tchat du lobby

## Un message écrit au lobby : l'hôte le nettoie, freine le spam, puis le relaie à tous avec le pseudo.
@rpc("any_peer", "call_local", "reliable")
func tchat_envoyer(texte: String) -> void:
	if not est_hote() or phase != "salon":
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = moi()
	if not humains.has(id):
		return
	var t := _tchat_logique.accepter(id, texte, Time.get_ticks_msec() / 1000.0)
	if t != "":
		_tchat_rpc.rpc(str(humains[id]["nom"]), t)


@rpc("authority", "call_local", "reliable")
func _tchat_rpc(nom: String, texte: String) -> void:
	tchat.emit(nom.substr(0, 24), TchatLobby.nettoyer(texte))


# ================================================================ intentions des joueurs

@rpc("any_peer", "call_local", "reliable")
func intention(type: String, a: Variant = null, b: Variant = null) -> void:
	if not est_hote():
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = moi()
	traiter(id, type, a, b)


## Aussi appelé directement pour les bots.
func traiter(id: int, type: String, a: Variant = null, b: Variant = null) -> void:
	if type == "rejouer" and id == 1:
		rejouer()
		return
	if type == "passer" and id == 1:
		passer_etape()
		return
	if type in ["exclure", "exclusion_demande", "exclusion_vote"]:
		_intention_exclusion(id, type, a)
		return
	if type == "synchro_pret":
		if synchro != null and synchro.signaler(id):
			_pub_salon()
		return
	if type in ["geste", "geste_accord", "choc"]:
		_intention_gestes(id, type, a, b)
		return
	if partie == null or not partie.joueurs.has(id):
		return
	var refus := ""
	match type:
		"porte":
			refus = _intention_porte(id, int(a), str(b))
		"vote_loup":
			refus = _intention_vote_loup(id, int(a))
		"mordre":
			refus = _intention_morsure(id, int(a))
		"bruit":
			if phase == "nuit" and _appel in ["loups", "solitaire"] and partie.est_loup(id) and partie.vivant(id):
				_envoyer_bruit_a_tous(a, str(b))
				_noter_trace(a)
		"repere":
			# La Guetteuse a trop ouvert les yeux au passage d'un loup : la meute sait qui elle est.
			if phase == "nuit" and _appel == "loups" and partie.role(id) == "guetteuse" and partie.vivant(id):
				for l in partie.chasseurs():
					_message(l, "Des yeux ouverts derrière la fenêtre de la maison %s : quelqu'un épie la nuit." % Ronde.numero(sieges[id]["maison"]), true)
		"faux_bruit":
			refus = partie.action(id, "faux_bruit")
			if refus == "":
				var sortes := ["craquement", "clapotis", "froissement", "gravier"]
				_envoyer_bruit_a_tous(a, sortes[_rng.randi_range(0, 3)])
				_noter_trace(a)
				_message(id, "Faux bruit lâché. Il t'en reste %d." % partie.souffles_restants())
		"garder":
			refus = partie.action(id, "garder", int(a)) if _appel == "veilleur" else "Attends qu'on t'appelle."
			if refus == "":
				_garde = int(a)
				_message(id, "Tu gardes la porte de %s, lanterne à la main." % qui(_garde))
		"voter_quete":
			refus = _intention_voter_quete(id, int(a))
		"choisir_quetes":
			refus = _intention_choisir(id, a)
		"jeu":
			var q := _quete_de(id)
			if q.is_empty() or q["etat"] != "jeu" or not a is Dictionary:
				refus = ""
			else:
				(q["mj"] as MiniJeu).humain_a_agi = true
				(q["mj"] as MiniJeu).action(id, a)
		"jeu_auto":
			_auto_humains[id] = true
		"pret":
			if Prets.accepte(phase) and partie.vivant(id):
				_prets[id] = true
				reste = Prets.reste_apres(reste, partie.vivants(), _prets.keys())
				_envoyer_pub(_etat_pub())
		"successeur":
			if phase != "successeur":
				refus = "Ce n'est pas le moment."
			else:
				refus = partie.designer_successeur(id, int(a))
				if refus == "":
					_vider_evenements()
					_annoncer_a_tous("%s est le nouveau maire." % qui(partie.maire, true), "cloche", 4.0)
					reste = minf(reste, 3.0)
		"trappe":
			if phase == "trappeur":
				refus = partie.action(id, "trappe", int(a))
				if refus == "":
					_vider_evenements()
					var texte := "\n".join(_annonces)
					_annonces.clear()
					_annoncer_a_tous(texte, "cri", 4.0)
					reste = minf(reste, 4.0)
			else:
				refus = "Ce n'est pas le moment."
		"voter":
			refus = partie.voter(id, int(a)) if phase in ["vote", "vote_maire"] else "Le vote n'est pas ouvert."
		"sortir":
			refus = _intention_sortir(id, int(a))
		"oreille":
			# L'oreille collée au mur : à l'intérieur d'une maison, la nuit, vivant.
			_oreille_de[id] = phase == "nuit" and bool(a) and partie.vivant(id) and Ronde.maison_de(_position(id)) >= 0
		"rideau":
			if Roles.peut_ecarter_rideau(partie.role(id), phase, partie.vivant(id)):
				_envoyer_rideau(int(sieges[id]["maison"]), int(a), clampf(float(b), 0.0, 1.0))
		"portee":
			if not Visibilite.portee_modifiable(phase):
				pass              # tout le monde s'entend : la portée envoyée est ignorée, sans message
			else:
				_portee_voix[id] = clampi(int(a), 0, 2)
				_envoyer_pub(_etat_pub())
		"trancher":
			if phase != "tranche" or _condamne > 0:
				refus = "Ce n'est pas le moment."
			elif id != _tranche_par:
				refus = "C'est au maire de trancher."
			elif not _tranche_candidats.has(int(a)):
				refus = "Choisis parmi ceux qui sont à égalité."
			else:
				_condamne = int(a)
				reste = minf(reste, 0.5)
		"examiner":
			if _position(id).distance_to(Ronde.lieu("cimetiere")) > 8.0:
				refus = "Va au cimetière pour examiner les morts."
			else:
				refus = partie.action(id, "examiner", int(a))
		"sauver_maison":
			refus = "Attends qu'on t'appelle." if _appel != "herboriste" else partie.action(id, "sauver", _habitant(int(a)))
			if refus == "":
				_message(id, "Tu verses la potion de vie derrière la porte %s." % Ronde.numero(int(a)))
		"lire", "poison", "lier", "modele":
			var appel_requis: String = {"lire": "liseuse", "poison": "herboriste", "lier": "entremetteuse", "modele": "enfant"}[type]
			if _appel != appel_requis:
				refus = "Attends qu'on t'appelle."
			else:
				refus = partie.action(id, type, int(a), int(b) if b != null else -1)
			if refus == "" and type == "poison":
				_message(id, "Tu as versé la potion de mort chez %s." % qui(int(a)))
			if refus == "" and type == "modele":
				_message(id, "%s est ton modèle. Si elle meurt, tu deviens loup." % qui(int(a), true))
		"obj_prendre", "obj_poser", "obj_donner", "obj_ecrire", "obj_dechirer", "obj_choisir", "obj_ouvrir", "obj_plume", "obj_lancer":
			refus = _intention_objet(id, type, a, b)
		"hanter", "caillou", "apparition", "grande_apparition" when id == _attache:
			refus = "Tu es enchaîné à la pierre : tu ne peux plus rien, qu'attendre la nuit."
		"hanter":
			refus = _intention_hanter(id, int(a))
		"caillou":
			refus = _intention_caillou(id, a, b)
		"apparition":
			refus = _intention_apparition(id, int(a) if a != null else -1, false)
		"grande_apparition":
			refus = _intention_apparition(id, -1, true)
	if refus != "" and not sieges[id]["bot"]:
		_message(id, refus)
	_vider_evenements()
	_envoyer_prives()


# ================================================================ gestes face à quelqu'un

func _intention_gestes(id: int, type: String, a: Variant = null, b: Variant = null) -> void:
	var maintenant := Time.get_ticks_msec() / 1000.0
	if not Gestes.phase_permise(phase) or (partie != null and partie.joueurs.has(id) and not partie.vivant(id)):
		_geste_vers(id, id, id, "refus", {"texte": "Pas maintenant."})
		return
	match type:
		"geste":
			var t := str(a)
			var cible := int(b) if b != null else -1
			var connu: bool = _bots.has(cible) or humains.has(cible) or (sieges.has(cible) and not sieges[cible]["bot"])
			if not connu or (partie != null and partie.joueurs.has(cible) and not partie.vivant(cible)):
				_geste_vers(id, id, cible, "refus", {"texte": "Personne ici."})
				return
			var r := gestes.tenter(id, cible, t, _position(id), _position(cible), maintenant)
			if not bool(r["ok"]):
				_geste_vers(id, id, cible, "refus", {"texte": str(r["refus"])})
			elif r["etat"] == "propose":
				if Meneur.est_bot(cible):
					gestes.accepter(cible, maintenant)
					if _rng.randf() < 0.7:
						_jouer_geste(id, cible, t, r["dir"])
					else:
						_geste_vers(id, id, cible, "refus", {"texte": "Il ne répond pas."})
				else:
					_geste_vers(id, id, cible, "envoye", {"type": t})
					_geste_vers(cible, id, cible, "propose", {"type": t})
			else:
				_jouer_geste(id, cible, t, r["dir"])
		"geste_accord":
			var r := gestes.accepter(id, maintenant)
			if bool(r["ok"]):
				_jouer_geste(int(r["de"]), id, str(r["type"]), Vector3.ZERO)
		"choc":
			if gestes.choc(id, maintenant):
				_geste_rpc.rpc(id, id, "yeux", {"duree": Gestes.DUREE_YEUX, "pos": _position(id)})


## Le geste est accepté (ou n'a pas besoin de l'être) : tout le monde le voit.
func _jouer_geste(de: int, cible: int, type: String, dir: Vector3) -> void:
	var extra := {"pos": _position(de), "dir": dir}
	if type == "accolade" and _rng.randf() < 0.5:
		type = "check"      # une accolade ou un check du poing, au hasard
	if type == "pousser" and _bots.has(cible):
		var b: Dictionary = _bots[cible]
		b["pos"] = (b["pos"] as Vector3) + dir * Gestes.POUSSEE
	_geste_rpc.rpc(de, cible, type, extra)


## Un message pour un seul joueur (refus, proposition) : jamais pour un bot.
func _geste_vers(dest: int, de: int, cible: int, type: String, extra: Dictionary) -> void:
	if Meneur.est_bot(dest):
		return
	if dest == moi():
		geste.emit(de, cible, type, extra)
	else:
		_geste_rpc.rpc_id(dest, de, cible, type, extra)


@rpc("authority", "call_local", "reliable")
func _geste_rpc(de: int, cible: int, type: String, extra: Dictionary) -> void:
	geste.emit(de, cible, type, extra)


## Un fantôme hante un joueur en pleine quête, à portée : le jeu décide de ce qui lui arrive.
func _intention_hanter(id: int, cible: int) -> String:
	if partie.vivant(id):
		return "Seuls les morts hantent."
	if not partie.vivant(cible):
		return ""
	var q := _quete_de(cible)
	if q.is_empty() or q["etat"] != "jeu":
		return "Il n'est pas en pleine quête."
	if _position(id).distance_to(_position(cible)) > PORTEE_HANTER:
		return "Approche-toi de lui."
	if float(_energie.get(id, 1.0)) < COUT_HANTER:
		return "Pas assez d'énergie : attends qu'elle remonte."
	var effet := (q["mj"] as MiniJeu).hanter(cible)
	if effet == "":
		return "Rien à faire tomber."
	_energie[id] = float(_energie.get(id, 1.0)) - COUT_HANTER
	_noter_hantise(id, cible)
	_message(id, effet)
	return ""


## Les compteurs des succès (côté hôte seulement : les clients reçoivent le bilan à la fin).
func _compter(id: int, cle: String) -> void:
	if not _compteurs.has(id):
		_compteurs[id] = {}
	_compteurs[id][cle] = int(_compteurs[id].get(cle, 0)) + 1


func _noter_hantise(id: int, cible: int) -> void:
	if not _compteurs.has(id):
		_compteurs[id] = {}
	var l: Array = _compteurs[id].get("hantes", [])
	if not cible in l:
		l.append(cible)
	_compteurs[id]["hantes"] = l


## Un fantôme lance un caillou : il ne se voit qu'en vol. On cherche le premier vivant sur sa route.
func _intention_caillou(id: int, de: Variant, dir: Variant) -> String:
	if partie.vivant(id) or not de is Vector3 or not dir is Vector3:
		return ""
	if phase == "nuit":
		return "La nuit, les fantômes laissent dormir le village."
	if not sieges[id]["bot"] and _position(id).distance_to(de) > 3.0:
		return ""
	if float(_energie.get(id, 1.0)) < COUT_CAILLOU:
		return "Pas assez d'énergie pour lancer."
	_energie[id] = float(_energie.get(id, 1.0)) - COUT_CAILLOU
	var vol := Meneur.vol_caillou(de, dir, partie.vivants().map(func(x): return [x, _position(x)]))
	_caillou_rpc.rpc(de, vol[0], vol[1])
	if int(vol[1]) >= 0:
		_compter(id, "cailloux")
	return ""


## Un fantôme se matérialise une seconde en monstre. `grande` : devant tous les vivants autour de
## lui ; sinon devant `cible` seul (les autres le voient sursauter, sans rien voir).
func _intention_apparition(id: int, cible: int, grande: bool) -> String:
	if partie.vivant(id):
		return ""
	if phase in ["nuit", "distribution", "salon", "fin"]:
		return "La nuit, les fantômes laissent dormir le village."
	var cout := COUT_GRANDE_APPARITION if grande else COUT_APPARITION
	if float(_energie.get(id, 1.0)) < cout:
		return "Pas assez d'énergie : attends qu'elle remonte."
	var temoins := Meneur.temoins_apparition(_position(id), cible, grande,
		partie.vivants().map(func(x): return [x, _position(x)]))
	if temoins.is_empty():
		return "Personne à effrayer ici." if grande else "Approche-toi de lui."
	# Une seule frayeur par vivant et par cycle jour + nuit, pour chaque fantôme.
	var neufs := Apparitions.restants(_apparus, id, temoins, jour_n)
	if neufs.is_empty():
		if not grande and cible >= 0:
			return "Tu as déjà effrayé cette personne aujourd'hui : elle se méfie. Reviens demain."
		return "Tu les as déjà tous effrayés aujourd'hui. Reviens demain."
	temoins = neufs
	Apparitions.noter(_apparus, id, temoins, jour_n)
	_energie[id] = float(_energie.get(id, 1.0)) - cout
	_apparition_rpc.rpc(temoins, _position(id))
	_compter(id, "apparitions")
	return ""


## Qui voit l'apparition : la cible seule (à portée), ou tous les vivants dans le rayon.
static func temoins_apparition(ici: Vector3, cible: int, grande: bool, vivants: Array) -> Array:
	var r: Array = []
	for v: Array in vivants:
		var d := Vector2(ici.x, ici.z).distance_to(Vector2((v[1] as Vector3).x, (v[1] as Vector3).z))
		if grande and d <= PORTEE_GRANDE_APPARITION:
			r.append(int(v[0]))
		elif not grande and int(v[0]) == cible and d <= PORTEE_APPARITION:
			r.append(int(v[0]))
	return r


## Où s'arrête un caillou lancé de `de` vers `dir` : [point d'arrivée, id touché ou -1].
## `cibles` : [[id, position au sol]…] ; on vise le buste (1,2 m), 45 cm de tolérance.
static func vol_caillou(de: Vector3, dir: Vector3, cibles: Array) -> Array:
	var d := dir.normalized()
	var loin := PORTEE_CAILLOU
	if d.y < -0.01:
		loin = minf(loin, -de.y / d.y)
	var touche := -1
	for c: Array in cibles:
		var p: Vector3 = (c[1] as Vector3) + Vector3(0, 1.2, 0)
		var t := (p - de).dot(d)
		if t > 0.3 and t < loin and (de + d * t).distance_to(p) < 0.45:
			loin = t
			touche = int(c[0])
	return [de + d * loin, touche]


## Les fantômes bots hantent aussi : énergie pleine, ils vont jusqu'à un joueur de la quête et,
## arrivés à portée, le hantent (sinon une partie de bots ne les montre jamais).
func _fantomes_bots(q: Dictionary, delta: float) -> void:
	var mj: MiniJeu = q["mj"]
	for id in _bots:
		var b: Dictionary = _bots[id]
		if partie.vivant(id) or float(_energie.get(id, 1.0)) < 1.0:
			continue
		var cible: int = b.get("hante", -1)
		if cible < 0 or not mj.ids.has(cible) or not partie.vivant(cible):
			if _rng.randf() > delta / 15.0:
				continue
			var cibles: Array = mj.ids.filter(func(x): return partie.vivant(x))
			if cibles.is_empty():
				continue
			cible = cibles[_rng.randi_range(0, cibles.size() - 1)]
			b["hante"] = cible
		var ici := _position(cible)
		if (b["pos"] as Vector3).distance_to(ici) < PORTEE_HANTER - 1.0:
			_intention_hanter(id, cible)
			b["hante"] = -1
		elif (b["chemin"] as Array).is_empty():
			# Un fantôme traverse tout : en ligne droite jusqu'à un pas de lui.
			b["chemin"] = [ici + (b["pos"] - ici).normalized() * 1.5]


## De temps en temps, un fantôme bot errant surgit devant un humain vivant tout proche.
func _apparitions_bots(delta: float) -> void:
	for id in _bots:
		if partie.vivant(id) or id == _attache or float(_energie.get(id, 1.0)) < 1.0 or _rng.randf() > delta / 40.0:
			continue
		var ici: Vector3 = _bots[id]["pos"]
		for h in humains:
			if partie.joueurs.has(h) and partie.vivant(h) and Vector2(ici.x, ici.z).distance_to(Vector2(_position(h).x, _position(h).z)) <= PORTEE_APPARITION:
				_intention_apparition(id, h, false)
				break


## Pendant la partie, personne n'a de nom : on désigne chacun par son bandeau, et le jeu ne dit
## jamais quel bandeau est à qui (décision d'Edwin, 29/10). Les noms reviennent à l'écran de fin.
func qui(id: int, majuscule := false) -> String:
	var k: int = sieges[id].get("bandeau", -1) if sieges.has(id) else -1
	var t := "la personne au bandeau %s" % Bouille.nom_bandeau(k) if k >= 0 else "quelqu'un"
	return t[0].to_upper() + t.substr(1) if majuscule else t


## Le même, en étiquette (boutons, tombe, mini-jeux) : « Bandeau rouge ».
func etiquette(id: int) -> String:
	var k: int = sieges[id].get("bandeau", -1) if sieges.has(id) else -1
	return "Bandeau %s" % Bouille.nom_bandeau(k) if k >= 0 else "Quelqu'un"


## La maison d'un mort reste close (décision d'Edwin, 29/10) : portes fermées, et son carnet
## posé sur le seuil, dehors, où tout le monde peut le lire.
func _clore_maison(m: int, carnet := true, mort_ici := Vector3.INF) -> void:
	if m < 0:
		return
	if pub.get("portes", {}).get("%d:avant" % m, false):
		_porte_rpc(m, "avant", false)
	if not carnet or objets == null:
		return
	for oid in objets.liste:
		var o: Dictionary = objets.liste[oid]
		if o["sorte"] == "carnet" and int(o["maison"]) == m and int(o["porteur"]) < 0 \
				and (Ronde.maison_de(o["pos"]) == m or (o["pos"] as Vector3).distance_to(mort_ici) < 2.0):
			o["pos"] = Meneur.seuil(m)
			o["angle"] = Ronde.angle_maison(m)
	_envoyer_objets()


## Le carnet d'un mort, posé dehors au pied de sa porte d'entrée.
static func seuil(m: int) -> Vector3:
	var devant := Ronde.devant_porte(m, "avant")
	var c := Ronde.centre_maison(m)
	var dehors := Vector3(devant.x - c.x, 0, devant.z - c.z).normalized()
	return Vector3(devant.x, 0.03, devant.z) + dehors * 0.15 + dehors.cross(Vector3.UP) * 0.7


func maison_close(i: int) -> bool:
	var h := _habitant(i)
	return h >= 0 and partie != null and not partie.vivant(h)


## Ce joueur est-il au poste d'un mini-jeu (inventaire fermé) ? Cf. Objets.inventaire_bloque.
func _au_poste(id: int) -> bool:
	for q in _quetes:
		if (q["inscrits"] as Array).has(id) and Objets.inventaire_bloque(str(q["etat"])):
			return true
	return false


## Carnets et pages : les mains de chacun, tenues par l'hôte. Un mort ne touche plus à rien.
func _intention_objet(id: int, type: String, a: Variant, b: Variant) -> String:
	if objets == null:
		return ""
	if not partie.vivant(id):
		return "Les morts ne prennent rien."
	if Objets.intention_bloquee_au_poste(type, a) and _au_poste(id):
		return ""      # au poste d'un mini-jeu l'inventaire est fermé : on ignore, rien ne se perd
	var ici := _position(id)
	var refus := ""
	match type:
		"obj_prendre":
			refus = objets.prendre(id, int(a), ici + Vector3(0, 0.8, 0))
		"obj_poser":
			# Un point farfelu (loin, sous le sol) devient un point à ses pieds : l'objet ne disparaît jamais.
			var ou: Vector3 = Depose.corriger_hote(a if a is Vector3 else ici, ici, _sol_de)
			refus = objets.poser(id, ou, float(b) if b != null else 0.0)
		"obj_donner":
			var autre := int(a)
			if not partie.joueurs.has(autre) or not partie.vivant(autre):
				refus = "Personne à qui le donner."
			else:
				refus = objets.donner(id, autre, ici, _position(autre))
				if refus == "" and not sieges[autre]["bot"]:
					var quoi: String = "une page" if objets.liste[objets.en_main(autre)]["sorte"] == "page" else "un carnet"
					_message(autre, "%s te glisse %s dans la main. (L pour lire)" % [qui(id, true), quoi])
		"obj_ecrire":
			var d: Array = b if b is Array else [0, ""]
			refus = objets.ecrire(id, int(a), int(d[0]), str(d[1]))
		"obj_dechirer":
			refus = objets.dechirer(id, int(a), int(b))[0]
		"obj_choisir":
			refus = objets.choisir(id, int(a))
		"obj_ouvrir":
			refus = objets.ouvrir(id, bool(a))
		"obj_plume":
			refus = objets.plume(id, bool(a))
		"obj_lancer":
			refus = _lancer_objet(id, a, b)
	if refus == "":
		_envoyer_objets()
	return refus


## Le caillou en main part : l'hôte calcule le vol (murs, sol, qui est touché et où) et le dit à tous.
## `de` : d'où il part (devant les yeux) ; `b` : [direction du regard, force 0..1].
func _sol_de(x: float, z: float) -> float:
	return Ronde.hauteur_sol(Vector3(x, 0.0, z))


func _lancer_objet(id: int, de: Variant, b: Variant) -> String:
	var d: Array = b if b is Array else []
	if not de is Vector3 or d.size() < 2 or not d[0] is Vector3 or (d[0] as Vector3).length() < 0.01:
		return ""
	var en_quete: bool = (pub.get("en_quete", {}) as Dictionary).has(id)
	if not Lancer.peut_lancer(phase, partie.vivant(id), en_quete):
		return "On ne jette rien maintenant."
	if not sieges[id]["bot"] and _position(id).distance_to(de) > 3.5:
		return ""
	var r := objets.lancer(id)
	if r[0] != "":
		return r[0]
	var v := Lancer.v0(d[0], clampf(float(d[1]), 0.0, 1.0))
	var cibles: Array = []
	for x in partie.vivants():
		if x != id:
			cibles.append([x, _position(x)])
	var res := Lancer.simuler(de, v, cibles, func(x: float, z: float): return Ronde.hauteur_sol(Vector3(x, 0, z)), _mur_entre)
	_vols.append({"de": de, "id": r[1], "t": float(res["duree"]), "fin": res["fin"], "touche": int(res["touche"]), "zone": str(res["zone"])})
	_caillou_lance_rpc.rpc(de, v, float(res["duree"]), res["fin"], int(res["touche"]), str(res["zone"]), int(r[1]))
	return ""


## Le dessus du meuble (lit, table, coffre…) sous le point où retombe un objet jeté : null si rien, sinon
## sa hauteur. On cherche d'un peu au-dessus : le vol s'arrête parfois juste dans le meuble.
func _plateau_sous(p: Vector3) -> Variant:
	var w := get_viewport().world_3d if get_viewport() else null
	if w == null:
		return null
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.7, 0), Vector3(p.x, Ronde.hauteur_sol(p) - 0.05, p.z), 1)
	var corps: Variant = get_parent().get("corps_joueur") if get_parent() else null
	if corps is CollisionObject3D:
		q.exclude = [(corps as CollisionObject3D).get_rid()]
	var t := w.direct_space_state.intersect_ray(q)
	if t.is_empty() or (t["normal"] as Vector3).y < 0.6:
		return null
	return float((t["position"] as Vector3).y)


## Le premier mur entre a et b (null : rien). Ni le corps de l'hôte, ni l'eau : le décor plein.
func _mur_entre(a: Vector3, b: Vector3) -> Variant:
	var w := get_viewport().world_3d if get_viewport() else null
	if w == null:
		return null
	var q := PhysicsRayQueryParameters3D.create(a, b, 1 | Ronde.COUCHE_PORTE_AVANT)
	var p := get_parent()
	var corps: Variant = p.get("corps_joueur") if p else null
	if corps is CollisionObject3D:
		q.exclude = [(corps as CollisionObject3D).get_rid()]
	var t := w.direct_space_state.intersect_ray(q)
	return t["position"] if not t.is_empty() else null


## Où retombe un objet en vol : sur le meuble sous lui ; s'il a tapé un mur au-dessus d'un lit, il glisse
## dessus (côté lanceur, 30 cm au plus) au lieu de se coincer entre le lit et le mur (Edwin, 01/11).
func _atterrissage_vol(fin: Vector3, de: Variant) -> Vector3:
	var sol := Ronde.hauteur_sol(fin)
	var dessus: Variant = _plateau_sous(fin)
	if de is Vector3 and (dessus == null or float(dessus) < sol + 0.05):
		var recul := (de as Vector3) - fin
		recul.y = 0.0
		if recul.length() > 0.05:
			for d in [0.12, 0.22, 0.32]:
				var p := fin + recul.normalized() * minf(d, recul.length())
				var h: Variant = _plateau_sous(p)
				if h != null and float(h) >= sol + 0.05:
					return Depose.atterrissage(p, _sol_de, h)
	return Depose.atterrissage(fin, _sol_de, dessus)


## Les cailloux en vol atterrissent (et font leur effet) ; il en repousse quand il en manque.
func _cailloux_tick(delta: float) -> void:
	if objets == null:
		return
	var change := false
	for v: Dictionary in _vols.duplicate():
		v["t"] = float(v["t"]) - delta
		if float(v["t"]) > 0.0:
			continue
		_vols.erase(v)
		var fin: Vector3 = v["fin"]
		objets.atterrir(int(v["id"]), _atterrissage_vol(fin, v.get("de")))
		change = true
		var touche := int(v["touche"])
		if touche >= 0 and v["zone"] == "tete" and partie.vivant(touche):
			_geste_rpc.rpc(touche, touche, "yeux", {"duree": Gestes.DUREE_YEUX, "pos": _position(touche)})
	_cailloux_t -= delta
	if _cailloux_t <= 0.0:
		_cailloux_t = CAILLOUX_REPOUSSE
		if objets.reapprovisionner(Cailloux.tirer(_rng, 6)) >= 0:
			change = true
	if change:
		_envoyer_objets()


func _envoyer_objets() -> void:
	var etat: Array = objets.etat() if objets else []
	if humains.is_empty():
		_objets_rpc.rpc(etat)
		return
	# Chacun voit les objets, mais ne lit que ce qu'il tient ou ce qui est posé ; la poche des autres lui est inconnue.
	for id: int in humains.keys():
		_objets_rpc.rpc_id(id, Visibilite.objets_pour(etat, id, id == 1))


@rpc("authority", "call_local", "reliable")
func _objets_rpc(etat: Array) -> void:
	objets_maj.emit(etat)


func _intention_porte(id: int, i: int, quelle: String) -> String:
	# Un mort ne pousse plus les portes : le fantôme a ses propres façons de hanter.
	if partie != null and phase != "salon" and partie.joueurs.has(id) and not partie.vivant(id):
		return "Tu n'es plus de ce monde : les portes ne t'obéissent plus."
	if _position(id).distance_to(Ronde.devant_porte(i, quelle).lerp(Ronde.centre_maison(i), 0.35)) > PORTEE_PORTE + 1.5:
		return "Approche-toi de la porte."
	# On sort d'une maison close (on y était quand son habitant est mort), on n'y entre plus.
	if maison_close(i) and Ronde.maison_de(_position(id)) != i:
		return "Cette maison est close. Celui qui y vivait n'est plus."
	var ouverte: bool = pub.get("portes", {}).get("%d:%s" % [i, quelle], false)
	if phase == "nuit":
		if quelle != "avant" or not partie.est_loup(id) or i != sieges[id]["maison"]:
			return "La nuit, les portes restent closes."
		_porte_rpc(i, quelle, not ouverte)
		_envoyer_bruit_a_tous(Ronde.devant_porte(i), "poignee")
		return ""
	if phase in PHASES_JOUR or phase == "salon":
		if quelle != "avant":
			return "Le jour, on passe par la porte d'entrée."
		_porte_rpc(i, quelle, not ouverte)
		return ""
	return "Pas maintenant."


## Un loup, à la pierre, fixe une maison et clique : sa voix pour la porte à ouvrir.
func _intention_vote_loup(id: int, maison: int) -> String:
	if phase != "nuit" or not partie.est_loup(id) or not partie.vivant(id):
		return "Seuls les loups votent à la pierre."
	if _appel == "solitaire":
		if partie.role(id) != "solitaire":
			return "Cette nuit, le solitaire chasse seul."
	elif _appel != "loups":
		return "Attends qu'on appelle les loups."
	if _vote_loups_fait:
		return "La meute a déjà choisi."
	if not _vote_ouvert():
		return "Pas encore : la meute se prépare."
	var devant := false
	if maison >= 0 and maison < Ronde.NB_MAISONS:
		if _position(id).distance_to(Ronde.devant_porte(maison)) < PORTEE_PORTE_PROIE:
			devant = true
	if not Ronde.a_l_autel(_position(id), PORTEE_PIERRE) and not devant:
		return "Va devant la porte de ta proie pour la choisir."
	if maison < 0 or maison >= Ronde.NB_MAISONS or _habitant(maison) < 0 or not partie.vivant(_habitant(maison)):
		return "Personne ne dort plus dans cette maison."
	if maison == sieges[id]["maison"]:
		return "C'est ta propre maison."
	if not NuitLoups.cible_permise(partie.est_loup(_habitant(maison))):
		return "C'est la maison d'un des tiens."
	_votes_loups[id] = maison
	if _votes_loups.size() >= _chasseurs_appel().size():
		_resoudre_t = 3.0
	_envoyer_prives()
	return ""


## Un loup sort de chez lui. Les trois coups de la porte : 3 réussis, aucun bruit ; 2, un léger
## grincement ; 1, une porte qu'on entend ; 0, un vacarme (décision d'Edwin, 29/10).
func _intention_sortir(id: int, reussis: int) -> String:
	if phase != "nuit" or not (_appel in ["loups", "solitaire"]) or not _chasseurs_appel().has(id):
		return "Ce n'est pas l'heure de la chasse."
	if Ronde.maison_de(_position(id)) != sieges[id]["maison"]:
		return "Tu es déjà dehors."
	_sortie_loup(id, clampi(reussis, 0, 3))
	return ""


func _sortie_loup(id: int, reussis: int) -> void:
	var m: int = sieges[id]["maison"]
	_porte_rpc(m, "avant", true)
	var sorte: String = ["porte_fort", "porte", "porte_leger", ""][reussis]
	if sorte != "":
		_envoyer_bruit_a_tous(Ronde.devant_porte(m), sorte)


## Les loups humains rentrent dans leur chambre : fondu au noir chez eux, replacés dans leur chambre, le
## fondu se lève. Pas de marche : la nuit continue pour les autres rôles, le jour trouvera chacun chez soi.
## Secondes écoulées dans le tour de la meute.
func _ecoule_tour() -> float:
	return maxf(_tour_total - reste, 0.0)


## Le vote à la pierre est-il ouvert ? (Après la transformation et la préparation ; jamais fermé pour le solitaire
## ni pendant le tutoriel.)
func _vote_ouvert() -> bool:
	return tour_libre or _appel != "loups" or NuitLoups.vote_ouvert(_ecoule_tour())


## Dix secondes sans sortir : le loup se transforme seul et sort de chez lui (les bots sont déjà dehors).
func _transformer_les_retardataires() -> void:
	for l in _chasseurs_appel():
		if _bots.has(l) or sieges[l]["bot"] or not partie.vivant(l):
			continue
		var m: int = sieges[l]["maison"]
		if Ronde.maison_de(_position(l)) != m:
			continue
		if "--trace-pubs" in OS.get_cmdline_user_args():
			print("[loups] transformation d'office après %.1f s" % _ecoule_tour())
		_sortie_loup(l, _rng.randi_range(1, 3))
		_message(l, "Le loup en toi a pris le dessus : tu es sorti malgré toi. Rejoins la pierre.", true)
		_placer(l, Ronde.devant_porte(m), Ronde.PIERRE, "libre")


func _ramener_loups_humains() -> int:
	var n := 0
	for l in _chasseurs_appel():
		var chez_soi := sieges.has(l) and Meneur.est_rentre(_position(l), sieges[l]["maison"])
		if not NuitLoups.a_ramener(not _bots.has(l) and not sieges[l]["bot"], partie.vivant(l), _loups_ramenes.has(l), chez_soi):
			continue
		_loups_ramenes.append(l)
		n += 1
		_retour_chambre_rpc.rpc_id(l, Ronde.lit(sieges[l]["maison"]), _fenetre(l))
	return n


## Ceux qui votent à cet appel : la meute (solitaire compris), ou le solitaire seul.
func _chasseurs_appel() -> Array[int]:
	if _appel == "solitaire":
		var s: Array[int] = []
		for l in partie.chasseurs():
			if partie.role(l) == "solitaire":
				s.append(l)
		return s
	return partie.chasseurs()


func _dire_aux(ids: Array[int], texte: String) -> void:
	for l in ids:
		_message(l, texte, true)


func _resoudre_vote_loups() -> void:
	if _vote_loups_fait or not (_appel in ["loups", "solitaire"]):
		return
	_vote_loups_fait = true
	_resoudre_t = -1.0
	_attaque_jouee = false
	var compte := {}
	for l in _votes_loups:
		if partie.vivant(l):
			compte[_votes_loups[l]] = compte.get(_votes_loups[l], 0) + 1
	var meilleure := -1
	var max_v := 0
	var egalite := false
	for m in compte:
		if compte[m] > max_v:
			max_v = compte[m]
			meilleure = m
			egalite = false
		elif compte[m] == max_v:
			egalite = true
	var chasseurs := _chasseurs_appel()
	# (essai) la meute choisit l'hôte, ou un invité : on voit la scène vécue de l'intérieur.
	for arg in OS.get_cmdline_user_args():
		if arg in ["--mange=hote", "--mange=invite"] and not chasseurs.is_empty():
			for h: int in humains.keys():
				if (h == 1) == (arg == "--mange=hote") and partie.vivant(h) and not partie.est_loup(h):
					meilleure = int(sieges[h]["maison"])
					egalite = false
	if meilleure < 0:
		_dire_aux(chasseurs, "Personne n'a voté : la pierre restera froide.")
	elif egalite:
		_dire_aux(chasseurs, "La meute ne s'est pas mise d'accord : aucune porte ne s'ouvre.")
	elif not chasseurs.is_empty():
		var cible := _habitant(meilleure)
		var type := "tuer_seul" if _appel == "solitaire" else "tuer"
		var r := partie.action(chasseurs[0], type, cible)
		_noter_attaque(meilleure, cible, r == "")
		if OS.get_cmdline_user_args().has("--trace-reseau"):
			print("[nuit] la meute vise la maison %d (joueur %d) : %s" % [meilleure, cible, "porte ouverte" if r == "" else r])
		if r == "":
			_maisons_ouvertes.append(meilleure)
			_victimes_nuit += 1
			# La scène elle-même ne se joue qu'à la FIN de la nuit (Edwin, 03/11) : d'abord l'Herboriste peut encore
			# sauver cette porte, puis l'attaque se joue pour tout le monde, et la nuit s'achève aussitôt.
			_attaque_jouee = true
			_dire_aux(chasseurs, "La porte %s s'ouvre. C'est fait. Rentrez chez vous : l'aube ne tardera pas." % Ronde.numero(meilleure))
		elif partie.est_loup(cible):
			_dire_aux(chasseurs, "Derrière la porte %s, une odeur de loup. La meute recule." % Ronde.numero(meilleure))
		elif cible == _garde:
			_dire_aux(chasseurs, "Une lanterne brille derrière la porte %s : le Veilleur veille. Elle ne s'ouvre pas." % Ronde.numero(meilleure))
		else:
			_dire_aux(chasseurs, r)
	# Les loups humains sont ramenés dans leur chambre (la scène ne se joue qu'en fin de nuit) ; la nuit reprend
	# alors pour les autres rôles, puis la scène de la victime clôt la nuit.
	reste = NuitLoups.reste_apres_choix(reste, false, Cinematique.DUREE)
	_retour_t = NuitLoups.delai_retour(false, Cinematique.DUREE)
	for id in _bots:
		if partie.vivant(id) and partie.est_loup(id):
			_bots[id]["but"] = "retour"
			_aller(id, Ronde.lit(sieges[id]["maison"]), true)
	_envoyer_prives()


## Le Vampire, le jour, tout contre sa victime.
func _intention_morsure(id: int, cible: int) -> String:
	if not phase in PHASES_JOUR:
		return "On ne mord que le jour."
	if not partie.joueurs.has(cible) or _position(id).distance_to(_position(cible)) > PORTEE_MORSURE:
		return "Approche-toi davantage."
	var r := partie.action(id, "mordre", cible)
	if r != "":
		return r
	_morsure_rpc.rpc(id, cible)
	for b in _bots:
		if b != id and b != cible and partie.vivant(b) and not partie.est_loup(b) and _position(b).distance_to(_position(id)) < 8.0 and _rng.randf() < 0.4:
			_savoir_bots[b]["suspect"] = id
	if partie.vivant(id):
		_message(id, "Ta morsure est faite. Le venin agira à la nuit tombée.", true)
	_vider_evenements()
	if not _annonces.is_empty():
		_annoncer_a_tous(char(10).join(_annonces), "cri", 5.0)
		_annonces.clear()
		var v := partie.victoire()
		if v != "":
			_terminer(v)
			return ""
	# Le maire est mort en plein jour (surdose du vampire) : le village ne reste pas sans maire
	# jusqu'à la nuit — plus de voix double au vote, égalité du Conseil tirée au sort. Le sort
	# désigne son successeur tout de suite, sans arrêter la journée.
	if partie.maire_a_remplacer > 0 and phase != "fin":
		partie.designer_successeur(partie.maire_a_remplacer, -1)
		_vider_evenements()
		_annoncer_a_tous("Le maire n'est plus. Le sort désigne %s pour porter l'écharpe." % qui(partie.maire), "glas", 4.0)
	return ""


func _role_en_jeu(r: String) -> bool:
	for id in partie.joueurs:
		if partie.role(id) == r:
			return true
	return false


## Appelle le rôle suivant de la nuit. Un rôle mort est appelé quand même (plus court), pour ne
## rien révéler à ceux qui écoutent.
func _appel_suivant() -> void:
	# Le temps du tour est écoulé avant que la meute ait fini de voter : on tranche, et si une porte
	# s'ouvre on reste dans le tour le temps de l'attaque et du retour (sinon la cinématique serait
	# coupée par le rôle suivant et le loup resterait dehors).
	if _appel in ["loups", "solitaire"] and not _vote_loups_fait:
		_resoudre_vote_loups()
	# Un loup humain encore dehors (personne n'a voté, ou la porte est restée fermée) : on le ramène avec le
	# fondu, et la nuit n'avance qu'une fois qu'il est chez lui.
	if _appel in ["loups", "solitaire"] and _ramener_loups_humains() > 0:
		_retour_t = -1.0
		reste = NuitLoups.FONDU + 0.6
		_envoyer_pub(_etat_pub())
		return
	if _appel != "":
		_finir_appel(_appel)
	if _file_appels.is_empty():
		_entrer("aube")
		return
	_appel = _file_appels.pop_front()
	reste = APPELS[_appel]
	if _appel in ["loups", "solitaire"]:
		for l in _chasseurs_appel():
			if not _loups_transformes.has(l):
				_loups_transformes.append(l)
	if _appel == "loups":
		reste = durees["loups"] if tour_libre else NuitLoups.duree_tour(durees["loups"])
		_tour_total = reste
		_sortie_forcee_faite = false
	elif ROLE_APPEL.has(_appel):
		reste = durees["roles"]
	if ROLE_APPEL.has(_appel):
		var titulaire_vivant := false
		for id in partie.vivants():
			if partie.role(id) == ROLE_APPEL[_appel]:
				titulaire_vivant = true
		if not titulaire_vivant:
			reste = _rng.randf_range(6.0, 9.0)
	_votes_loups.clear()
	_vote_loups_fait = false
	_attaque_jouee = false
	_retour_t = -1.0
	_loups_ramenes.clear()
	_resoudre_t = -1.0
	match _appel:
		"loups", "solitaire":
			for l in _chasseurs_appel():
				if _bots.has(l):
					_sortie_loup(l, _rng.randi_range(1, 3))
				else:
					_message(l, "Tu te transformes. Sors par ta porte ({agir}) : réussis les trois coups pour l'ouvrir sans bruit.")
			if _appel == "loups":
				for m in _a_prevenir:
					if partie.vivant(m):
						_message(m, "Le venin a fait son œuvre. Tu es des leurs : sors, la meute t'attend à la pierre.", true)
				_a_prevenir.clear()
		"cinematique":
			_lancer_scene()
	if VOIX_APPEL[_appel] != "":
		_annoncer_a_tous(VOIX_APPEL[_appel], "" if _appel == "loups" else "cloche", 4.0)
	_bots_appel(_appel)
	_envoyer_pub(_etat_pub())
	_envoyer_prives()


## La scène de la nuit. Au premier passage on dresse la liste de ceux que le loup mange vraiment (ni gardés,
## ni sauvés par l'Herboriste, ni Doyen encore indemne) ; chaque victime a sa scène, l'une après l'autre
## (la même entrée `cinematique` est remise en tête de file tant qu'il en reste). Personne à manger : on passe.
var _scene_file: Array[int] = []
var _scene_initiale := false


## La victime de la scène en cours : elle devient fantôme dès que SA scène est finie (avant la suivante).
var _scene_victime := -1
var _scenes_jouees := 0


func _achever_scene() -> void:
	if _scene_victime <= 0:
		return
	var v := _scene_victime
	_scene_victime = -1
	if partie.manger_maintenant(v):
		_vider_evenements()
		_envoyer_pub(_etat_pub())
		_envoyer_prives()


func _lancer_scene() -> void:
	_achever_scene()
	if not _scene_initiale:
		_scene_initiale = true
		_scene_file.assign(partie.victimes_a_manger())
	if _scene_file.is_empty():
		_scene_initiale = false
		reste = 0.2
		return
	var v: int = _scene_file.pop_front()
	var maison: int = sieges[v]["maison"]
	reste = Cinematique.DUREE + 0.3
	_scene_victime = v
	_scenes_jouees += 1
	_cinematique_rpc.rpc(maison, v, partie.agresseurs(v))
	if _scene_file.is_empty():
		_scene_initiale = false
	else:
		_file_appels.push_front("cinematique")


func _finir_appel(a: String) -> void:
	if a in ["loups", "solitaire"]:
		if not _vote_loups_fait:
			_resoudre_vote_loups()
		# Qui n'est pas rentré à temps est ramené dans son lit… mais laisse des traces dehors.
		_retour_t = -1.0
		for l in _chasseurs_appel():
			var ou := _position(l)
			if Ronde.maison_de(ou) != sieges[l]["maison"]:
				_noter_trace(ou)
		_ramener_loups_humains()
		for l in _chasseurs_appel():
			if _bots.has(l):
				_placer(l, Ronde.lit(sieges[l]["maison"]), _fenetre(l), "chambre")
		for i in Ronde.NB_MAISONS:
			if not _maisons_ouvertes.has(i):
				_porte_rpc(i, "avant", false)


# ================================================================ qui reçoit quoi (cf. regles/visibilite.gd)

## La fiche d'un joueur pour les règles de visibilité : vivant (le condamné encore à la pierre compte pour
## vivant), loup, rôle, dehors ou non, sa maison. Hors partie, tout est permis.
func fiche_vis(id: int, avec_dehors := true) -> Dictionary:
	if partie == null or not partie.joueurs.has(id):
		return Visibilite.fiche(id, id == 1, true, false, "", false, -1)
	var dehors := avec_dehors and Ronde.maison_de(_position(id)) < 0   # (seul le sujet d'une position a besoin de le savoir)
	return Visibilite.fiche(id, id == 1, partie.vivant(id) or id == _attache, partie.est_loup(id), partie.role(id), dehors,
		int(sieges[id]["maison"]) if sieges.has(id) else -1, id == _attache)


## Les humains qui doivent recevoir la position (et les gestes) de `origine`.
func destinataires_position(origine: int) -> Array[int]:
	var r: Array[int] = []
	var sujet := fiche_vis(origine)
	for dest: int in humains.keys():
		if dest != origine and Visibilite.voit_position(phase, fiche_vis(dest, false), sujet):
			r.append(dest)
	return r


## Les humains qui doivent entendre la voix de `origine`.
func destinataires_voix(origine: int) -> Array[int]:
	var r: Array[int] = []
	var sujet := fiche_vis(origine)
	var ici := _position(origine)
	for dest: int in humains.keys():
		if dest != origine and Visibilite.entend_voix(phase, _appel if phase == "nuit" else "", fiche_vis(dest, false), sujet, ici.distance_to(_position(dest)), int(_portee_voix.get(origine, 1))):
			r.append(dest)
	return r


## Ma voix part vers l'hôte, qui la distribue aux seuls joueurs qui ont le droit de l'entendre.
func voix_envoyer(donnees: PackedByteArray, niveau: float) -> void:
	if est_hote():
		_distribuer_voix(moi(), donnees, niveau)
	else:
		_voix_vers_hote.rpc_id(1, donnees, niveau)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)   # le canal de la voix (cf. Voix.CANAL)
func _voix_vers_hote(donnees: PackedByteArray, niveau: float) -> void:
	if est_hote():
		_distribuer_voix(multiplayer.get_remote_sender_id(), donnees, niveau)


func _distribuer_voix(origine: int, donnees: PackedByteArray, niveau: float) -> void:
	if donnees.size() > 400 or not humains.has(origine):
		return
	# L'hôte entend tout le monde ; chacun des autres seulement ceux qu'il a le droit d'entendre.
	if origine != moi():
		var voix := get_node_or_null("/root/Voix")
		if voix:
			voix.recevoir_de(origine, donnees, niveau)
	for dest in destinataires_voix(origine):
		if dest != moi():
			_voix_relai.rpc_id(dest, origine, donnees, niveau)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _voix_relai(origine: int, donnees: PackedByteArray, niveau: float) -> void:
	var voix := get_node_or_null("/root/Voix")
	if voix:
		voix.recevoir_de(origine, donnees, niveau)


func _noter_trace(pos: Vector3) -> void:
	_traces_nuit.append(pos)


func _envoyer_rideau(maison: int, cote: int, ouverture: float) -> void:
	if humains.is_empty():
		_rideau_rpc.rpc(maison, cote, ouverture)
		return
	for dest: int in humains.keys():
		if Visibilite.voit_rideau(fiche_vis(dest, false), maison):
			_rideau_rpc.rpc_id(dest, maison, cote, ouverture)



# ================================================================ envois

func _etat_pub() -> Dictionary:
	var s := {}
	for id in sieges:
		var f: Dictionary = sieges[id].duplicate()
		f["vivant"] = partie.vivant(id) if partie else true
		f["portee"] = int(_portee_voix.get(id, 1))
		s[id] = f
	var d := {"phase": phase, "reste": reste, "tour_libre": tour_libre, "duree_loups": durees["loups"], "nb_loups": nb_loups, "sieges": s, "nuit_n": partie.nuit_n if partie else 0,
		"nb_maisons": Ronde.NB_MAISONS,
		"portes": pub.get("portes", {}), "appel": _appel if phase == "nuit" else "", "durees": durees_reglees()}
	# Les votes sont secrets (décision d'Edwin, 29/10) : on ne publie que le dépouillement.
	if phase in ["depouillement", "tranche", "verdict"] and not _resultat.is_empty():
		d["resultat"] = _resultat
	if phase == "tranche":
		d["tranche"] = {"par": _tranche_par, "candidats": _tranche_candidats.duplicate()}
	if _attache > 0:
		d["attache"] = _attache
		d["attache_lie"] = _attache_lie
	if phase == "trappeur":
		d["trappeur"] = partie.trappeur_attendu()
	if partie:
		d["jour_n"] = jour_n
		d["maire"] = partie.maire
		d["indices"] = _indices.duplicate()
		d["quetes"] = _quetes_pub()
		var en := {}
		for q in _quetes:
			if q["etat"] in ["trajet", "role", "jeu", "retour"]:
				for id in q["inscrits"]:
					en[id] = q["zone"]
		d["en_quete"] = en
		var poste: Array = []
		for q in _quetes:
			if Objets.inventaire_bloque(str(q["etat"])):
				poste.append_array(q["inscrits"])
		d["au_poste"] = poste
		if phase == "choix_maire":
			d["propositions"] = _propositions.map(func(q): return {"jeu": q["jeu"], "nom": Quetes.nom_jeu(q["jeu"]),
				"niveau": q["niveau"], "recompense": q["recompense"], "titre_seul": _titre_seul(q)})
		if phase == "tableau":
			var compte := [0, 0, 0, 0]
			for v in _votes_quete:
				compte[int(_votes_quete[v])] += 1
			d["votes_quete"] = compte
			# Avec un maire : son choix (-1 : pas encore) et ceux qui ne partent pas.
			d["maire_quete"] = _maire_actif()
			d["quete_du_maire"] = int(_votes_quete.get(partie.maire, -1)) if _maire_actif() else -1
			d["refus_quete"] = compte[Quetes.RESTER] if _maire_actif() else 0
		if Prets.accepte(phase):
			d["prets"] = _prets.keys()
		if phase == "successeur":
			d["successeur"] = partie.maire_a_remplacer
	return d


## La quête à rôle ne donnerait-elle qu'un titre ? Le tableau le dit (et ne change plus d'avis une fois
## la quête finie : le verdict est gardé au moment de la remise du rôle).
func _titre_seul(q: Dictionary) -> bool:
	if q.has("titre_seul"):
		return q["titre_seul"]
	return q["recompense"] == "role" and Quetes.titre_seul(q["niveau"], jour_n, partie.roles_pris() + partie.roles_retires)


func _quetes_pub() -> Array:
	var l := []
	for q in _quetes:
		var e := {"jeu": q["jeu"], "nom": Quetes.nom_jeu(q["jeu"]), "niveau": q["niveau"], "recompense": q["recompense"],
			"inscrits": (q["inscrits"] as Array).duplicate(), "etat": q["etat"], "zone": q["zone"], "reussie": q["reussie"],
			"requis": Quetes.joueurs_requis(q["jeu"]), "remplace": q.get("remplace", ""), "titre_seul": _titre_seul(q)}
		if q["etat"] == "role":
			# La zone du rôle : où elle est, son nom, le temps qui reste et, une fois pris, qui l'a.
			var ch: ChoixRole = q["choix"]
			e["role"] = {"nom": Quetes.role_unique(q["jeu"]), "pos": q["zone_role"], "reste": ch.reste,
				"elu": ch.elu, "hasard": ch.par_hasard, "elu_nom": etiquette(ch.elu) if ch.elu >= 0 else ""}
		l.append(e)
	return l


func _prive(id: int) -> Dictionary:
	var f: Dictionary = partie.joueurs[id]
	var desc := Roles.description(f["role"])
	if f["titre"] != "":
		desc = "Ton titre au village, gagné à une quête. Il ne donne aucun pouvoir : observe, écoute et démasque les loups."
	elif f["role"] == "villageois" and not partie.loups_tires:
		desc = "Pas encore de rôle : il se gagne aux quêtes. La première nuit, les loups seront tirés parmi ceux qui n'en ont pas."
	var d := {"id": id, "role": f["role"], "nom_role": partie.nom_role(id), "desc": desc,
		"loup": partie.est_loup(id), "vivant": f["vivant"], "camp": partie.camp(id),
		"sans_role": f["role"] == "villageois" and f["titre"] == "" and not partie.loups_tires,
		"amoureux": f["amoureux"], "modele": f["modele"], "peut_voter": f["peut_voter"],
		"messages": _messages.get(id, [])}
	if not f["vivant"] and phase == "nuit":
		d["loups_vus"] = _loups_transformes.filter(func(l): return partie.vivant(l))
	if partie.est_loup(id):
		# Les loups ne se connaissent pas : ils ne se voient qu'à l'appel des loups, à la pierre.
		d["silhouettes"] = partie.silhouettes(id) if Visibilite.silhouettes_visibles(phase, _appel) else []
		d["faim"] = partie.faim
		if _appel in ["loups", "solitaire"]:
			d["votes_loups"] = _votes_loups.duplicate()
			d["chasse_finie"] = _vote_loups_fait
	match f["role"]:
		"vampire":
			d["peut_mordre"] = partie.peut_mordre()
		"herboriste":
			d["potions"] = partie.potions()
			if _appel == "herboriste":
				d["maisons_attaquees"] = _maisons_ouvertes.duplicate()
		"souffleur":
			d["souffles"] = partie.souffles_restants()
	if not f["vivant"]:
		d["energie"] = float(_energie.get(id, 1.0))
	if phase in ["vote", "vote_maire"]:
		var contre := 0
		var votes := partie.votes()
		for v in votes:
			if votes[v] == id:
				contre += 1
		d["contre_moi"] = contre
	return d


func _envoyer_prives() -> void:
	if partie == null:
		return
	if "--trace-priv" in OS.get_cmdline_user_args(): print("[priv] envoi ", sieges.keys().filter(func(i): return not sieges[i]["bot"]), " pairs=", multiplayer.get_peers())
	for id in sieges:
		if not sieges[id]["bot"]:
			_priv_rpc.rpc_id(id, _prive(id))
	_messages.clear()


func _envoyer_pub(d: Dictionary) -> void:
	if "--trace-reseau" in OS.get_cmdline_user_args(): print("[pub] %d octets" % var_to_bytes(d).size())
	if humains.is_empty():
		_pub_rpc.rpc(d)
		return
	# Chacun sa copie : l'état des portes (reconstruit par les messages de porte filtrés) ne part que vers l'hôte.
	var autres := Visibilite.pub_pour(d, false)
	if "--trace-pubs" in OS.get_cmdline_user_args(): print("[pub envoyé] phase=%s à %s" % [d.get("phase", "?"), humains.keys()])
	for id: int in humains.keys():
		_pub_rpc.rpc_id(id, d if id == 1 else autres)


func _envoyer_bots() -> void:
	var ids := PackedInt32Array()
	var pos := PackedVector3Array()
	var caps := PackedFloat32Array()
	var regards := PackedVector3Array()
	for id in _bots:
		var b: Dictionary = _bots[id]
		ids.append(id)
		pos.append(b["pos"])
		caps.append(b["cap"])
		regards.append(b["regard"])
	if phase != "nuit" or partie == null or humains.is_empty():
		_bots_rpc.rpc(ids, pos, caps, regards)
		return
	# La nuit, chacun ne reçoit que les bots qu'il a le droit de voir (cf. Visibilite).
	var sujets := {}
	for id in _bots:
		sujets[id] = fiche_vis(id)
	for dest: int in humains.keys():
		var permis := Visibilite.bots_visibles(phase, fiche_vis(dest, false), sujets)
		if permis.is_empty():
			continue
		var i2 := PackedInt32Array()
		var p2 := PackedVector3Array()
		var c2 := PackedFloat32Array()
		var r2 := PackedVector3Array()
		for k in ids.size():
			if permis.has(ids[k]):
				i2.append(ids[k])
				p2.append(pos[k])
				c2.append(caps[k])
				r2.append(regards[k])
		_bots_rpc.rpc_id(dest, i2, p2, c2, r2)


## Un message privé, joint au prochain état privé. `garder` : à noter dans le carnet.
func _message(id: int, texte: String, garder := false) -> void:
	if not sieges.has(id) or sieges[id]["bot"]:
		return
	var l: Array = _messages.get(id, [])
	l.append({"texte": texte, "carnet": garder})
	_messages[id] = l


func _annoncer_a_tous(texte: String, son: String, duree: float) -> void:
	_annonce_rpc.rpc(texte, son, duree)


func _envoyer_bruit_a_tous(pos: Vector3, sorte: String) -> void:
	if phase != "nuit" or partie == null or humains.is_empty():
		_bruit_rpc.rpc(pos, sorte, false)
		return
	# La nuit, on entend « à peu près » : l'endroit exact (donc la maison, donc le loup) ne part que vers ceux
	# qui le connaissent (loups, morts, Oreille fine, oreille collée au mur) ; les autres reçoivent la position
	# déjà brouillée pour eux (cf. Bruit.position_entendue).
	for dest: int in humains.keys():
		if Visibilite.bruit_precis(phase, fiche_vis(dest, false), bool(_oreille_de.get(dest, false))):
			_bruit_rpc.rpc_id(dest, pos, sorte, false)
		else:
			_bruit_rpc.rpc_id(dest, Bruit.position_entendue(pos, _position(dest), _rng, false), sorte, true)


func _placer(id: int, pos: Vector3, regard: Vector3, mode: String) -> void:
	if _bots.has(id):
		var b: Dictionary = _bots[id]
		# Comme les joueurs : on marche jusqu'à sa place, on n'y apparaît pas (immersion).
		var loin: bool = Vector2(pos.x - b["pos"].x, pos.z - b["pos"].z).length() > 1.5
		b["court"] = phase == "distribution" and mode == "chambre"   # au soir, on COURT jusqu'à sa maison
		if loin and mode != "fantome" and phase not in ["salon", "fin"] and partie and (partie.vivant(id) or mode == "traine"):
			# Dans la forêt des quêtes (de clairière à clairière, du rôle au poste), TOUT DROIT : le
			# plan du village les faisait repartir vers la place avant de revenir (31/10).
			var ch: Array[Vector3] = []
			if Ronde.hors_village(b["pos"]) and Ronde.hors_village(pos):
				ch.append(pos)
			else:
				ch = _chemin_bot(b, pos, phase == "nuit")
				ch.append(pos)
			b["chemin"] = ch
		else:
			b["pos"] = pos
			b["chemin"] = []
		b["mode"] = mode
		b["but"] = ""
		if regard != Vector3.ZERO:
			b["cap"] = atan2(regard.x - pos.x, regard.z - pos.z)
		return
	if sieges.has(id) and sieges[id]["bot"]:
		return
	# Un mort est un fantôme libre (Edwin, 03/11) : aucun placement d'étape ne le ramène près du feu, de son
	# lit ou de sa quête. Seuls passent le fantôme lui-même et le condamné, mort pour les règles mais encore
	# conduit à la pierre.
	if mode != "fantome" and id != _attache and partie != null and partie.joueurs.has(id) and not partie.vivant(id) 			and phase not in ["salon", "fin"]:
		return
	_placer_rpc.rpc_id(id, pos, regard, mode)


func _porte_rpc(i: int, quelle: String, ouverte: bool) -> void:
	# La nuit, une porte qui s'ouvre (les loups sortent par leur porte) ne se voit pas de partout.
	if not ouverte or phase != "nuit" or partie == null or humains.is_empty():
		_porte_etat.rpc(i, quelle, ouverte)
		return
	for dest: int in humains.keys():
		if Visibilite.voit_porte(phase, fiche_vis(dest, false), i):
			_porte_etat.rpc_id(dest, i, quelle, ouverte)


## Le battant ouvert mesure 1,36 m et se referme en balayant le sol derrière lui : on n'est « rentré » (et
## la porte ne se referme) qu'une fois le corps hors de ce balayage (Edwin, 01/11 : « mon personnage se prend
## la porte en la refermant »).
const PROFONDEUR_RENTRE := 2.0

## Debout assez loin derrière sa porte d'entrée (2 m) : on est rentré chez soi.
static func est_rentre(pos: Vector3, maison: int) -> bool:
	if maison < 0 or Ronde.maison_de(pos) != maison:
		return false
	return Ronde._vers_local(maison, pos).z < Ronde.PROFONDEUR * 0.5 - PROFONDEUR_RENTRE


var _rentre_t := 0.0


## Au soir : dès qu'un habitant est rentré, SA porte d'entrée se ferme (sans attendre les autres).
func _rentrer_tick(delta: float) -> void:
	_rentre_t -= delta
	if _rentre_t > 0.0:
		return
	_rentre_t = 0.2
	for id in sieges:
		if not partie.vivant(id):
			continue
		var m: int = sieges[id]["maison"]
		if pub.get("portes", {}).get("%d:avant" % m, false) and Meneur.est_rentre(_position(id), m):
			_porte_rpc(m, "avant", false)


## La nuit tombe : les portes se ferment, sauf celle d'un habitant encore dehors (il la ferme en rentrant).
func _portes_fermees_sauf_dehors() -> void:
	var dehors := {}
	for id in sieges:
		if partie.vivant(id) and not Meneur.est_rentre(_position(id), sieges[id]["maison"]):
			dehors[int(sieges[id]["maison"])] = true
	for i in Ronde.NB_MAISONS:
		if pub.get("portes", {}).get("%d:avant" % i, false) and not dehors.has(i):
			_porte_rpc(i, "avant", false)


func _portes_toutes_fermees() -> void:
	for i in Ronde.NB_MAISONS:
		if pub.get("portes", {}).get("%d:avant" % i, false):
			_porte_rpc(i, "avant", false)


## Debout à côté de son rondin (juste derrière) : un joueur placé au centre serait dans le bois.
static func pres_souche(i: int) -> Vector3:
	return Ronde.souche(i) * (1.0 + 0.9 / Ronde.R_SOUCHES)


func _tous_au_conseil(mode: String) -> void:
	for id in sieges:
		if partie.vivant(id):
			var siege: Vector3 = Ronde.souche(sieges[id]["maison"])
			_placer(id, siege, Vector3(0, 0.9, 0), mode)
			# Assis (Edwin, 31/10) : tout le monde est sur son rondin d'un coup, tourné vers le feu,
			# bots compris. Les bots n'y marchent pas : ils y sont, sans délai.
			if mode == "assis" and _bots.has(id):
				var b: Dictionary = _bots[id]
				b["chemin"] = []
				b["court"] = false
				b["pos"] = Vector3(siege.x, Ronde.hauteur_sol(siege), siege.z)
				b["cap"] = atan2(-siege.x, -siege.z)
				b["mode"] = mode


func _vider_evenements() -> void:
	for e in partie.evenements:
		var id: int = e.get("id", -1)
		match e["type"]:
			"mort":
				# On ne révèle plus le rôle : seul le Fossoyeur saura (révision du 27/10).
				sieges[id]["vivant"] = false
				if objets and not objets.portes_par(id).is_empty():
					objets.lacher_tout(id, _position(id) + Vector3(0, 0.05, 0))
					_envoyer_objets()
				var causes := {"loups": "%s n'a pas survécu à la nuit.", "solitaire": "%s n'a pas survécu à la nuit.",
					"potion": "%s n'a pas survécu à la nuit.", "vote": "%s a été éliminée par le Conseil.",
					"chagrin": "%s est morte de chagrin.", "trappeur": "%s a été abattue par le Trappeur.",
					"surdose": "%s s'effondre d'un coup, les lèvres noircies. Morte.", "parti": "%s a quitté le village."}
				if e["cause"] != "vote":
					_annonces.append(str(causes.get(e["cause"], "%s est morte.")) % qui(id, true))
				if id == _attache:
					# Le condamné du Conseil : il reste avec les vivants jusqu'à ce que les loups viennent.
					_clore_maison(int(sieges[id]["maison"]), true)
					continue
				_tombe_rpc.rpc(etiquette(id), sieges[id]["maison"])
				_clore_maison(int(sieges[id]["maison"]), true, _position(id))
				_placer(id, Ronde.souche(sieges[id]["maison"]) + Vector3(0, 0, 0), Vector3.ZERO, "fantome")
				if _bots.has(id):
					# Un bot mort devient un fantôme qui erre (vu des morts et du Médium), pas un corps enterré.
					_bots[id]["mode"] = "fantome"
					_bots[id]["pos"] = Ronde.souche(sieges[id]["maison"])
					_bots[id]["chemin"] = []
			"doyen":
				_message(id, "Les loups t'ont attaqué cette nuit. Tu as survécu. Ce ne sera pas toujours le cas.", true)
			"sauve":
				_message(id, "Cette nuit, on a voulu ta mort. Une main inconnue t'a sauvé.", true)
			"role_gagne":
				var qui_: int = e["pour"]
				if not sieges[qui_]["bot"]:
					var nom_r: String = e["titre"] if e["titre"] != "" else Roles.nom(e["role"])
					_message(qui_, "La quête t'a donné un rôle : %s. Il est écrit en haut à droite. Garde-le pour toi… ou pas." % nom_r, true)
			"maire":
				pass
			"devient_loup":
				if e.get("cause", "") == "tirage":
					if partie.role(id) == "solitaire":
						_message(id, "La nuit tombe… et quelque chose s'éveille en toi. Tu es %s. Quand on appellera les loups, rejoins la pierre. Mais tu gagnes seul : sois le dernier vivant. Une nuit sur deux, tu chasses sans eux." % Roles.nom(partie.role(id)), true)
					else:
						_message(id, "La nuit tombe… et quelque chose s'éveille en toi. Tu es %s. Quand on appellera les loups, rejoins la pierre." % Roles.nom(partie.role(id)), true)
					if _bots.has(id):
						_savoir_bots[id] = {"suspect": -1, "innocents": []}
					continue
				if e.get("cause", "") == "morsure":
					if not _a_prevenir.has(id):
						_a_prevenir.append(id)
				else:
					_message(id, "Tu deviens loup. Quand on appellera les loups, rejoins la pierre.", true)
				if _bots.has(id):
					_savoir_bots[id] = {"suspect": -1, "innocents": []}
			"devient_traitre":
				_message(e["pour"], "La nuit tombe… et ton cœur se retourne. Tu es le Traître : tu restes villageois aux yeux de tous, mais tu gagnes avec les loups. Tu ne sais pas qui ils sont.", true)
			"lecture":
				if sieges[e["pour"]]["bot"]:
					_bot_apprend(e["pour"], {"sorte": "lecture", "cible": e["cible"], "loup": Roles.est_loup(e["role"])})
				else:
					_message(e["pour"], "%s est : %s." % [qui(e["cible"], true), Roles.nom(e["role"])], true)
			"examen":
				_message(e["pour"], ("%s était un loup." if e["loup"] else "%s n'était pas un loup.") % qui(e["cible"], true), true)
			"amoureux":
				_message(e["pour"], "Tu es lié à %s. Si l'un de vous meurt, l'autre meurt aussi." % qui(e["cible"]), true)
			"modele":
				_message(e["pour"], "Le destin t'a donné %s pour modèle." % qui(e["cible"]), true)
	partie.evenements.clear()


func _herboriste_peut_sauver() -> bool:
	for id in partie.vivants():
		if partie.role(id) == "herboriste" and partie.potions()["vie"]:
			return true
	return false


func _habitant(maison: int) -> int:
	for id in sieges:
		if sieges[id]["maison"] == maison:
			return id
	return -1


func _fenetre(id: int) -> Vector3:
	return Ronde.centre_maison(sieges[id]["maison"]) * 0.2


func _position(id: int) -> Vector3:
	if _bots.has(id):
		return _bots[id]["pos"]
	if position_humain.is_valid():
		return position_humain.call(id)
	return Vector3.ZERO


func _ronde() -> Ronde:
	var p := get_parent()
	return p.get("ronde") if p else null


# ================================================================ réception (tous les pairs)

@rpc("authority", "call_local", "reliable")
func _pub_rpc(d: Dictionary) -> void:
	var portes: Dictionary = pub.get("portes", {})
	pub = d
	pub["portes"] = portes
	etat_public.emit(pub)


@rpc("authority", "call_local", "reliable")
func _priv_rpc(d: Dictionary) -> void:
	if "--trace-priv" in OS.get_cmdline_user_args(): print("[priv] recu role=", d.get("role"))
	priv = d
	etat_prive.emit(priv)


@rpc("authority", "call_local", "reliable")
func _annonce_rpc(texte: String, son: String, duree: float) -> void:
	annonce.emit(texte, son, duree)


@rpc("authority", "call_local", "reliable")
func _bruit_rpc(pos: Vector3, sorte: String, deja_entendu: bool) -> void:
	bruit.emit(pos, sorte, deja_entendu)


@rpc("authority", "call_local", "reliable")
func _porte_etat(i: int, quelle: String, ouverte: bool) -> void:
	var portes: Dictionary = pub.get("portes", {})
	portes["%d:%s" % [i, quelle]] = ouverte
	pub["portes"] = portes
	porte.emit(i, quelle, ouverte)


@rpc("authority", "call_local", "reliable")
func _apparition_rpc(temoins: Array, pos: Vector3) -> void:
	apparition.emit(temoins, pos)


@rpc("authority", "call_local", "reliable")
func _caillou_lance_rpc(de: Vector3, v0: Vector3, duree: float, fin: Vector3, touche: int, zone: String, objet: int) -> void:
	caillou_lance.emit(de, v0, duree, fin, touche, zone, objet)


@rpc("authority", "call_local", "reliable")
func _caillou_rpc(de: Vector3, a: Vector3, touche: int) -> void:
	caillou.emit(de, a, touche)


@rpc("authority", "call_local", "reliable")
func _placer_rpc(pos: Vector3, regard: Vector3, mode: String) -> void:
	placement.emit(pos, regard, mode)


@rpc("authority", "call_local", "unreliable_ordered")
func _bots_rpc(ids: PackedInt32Array, positions: PackedVector3Array, caps: PackedFloat32Array, regards: PackedVector3Array) -> void:
	bots_maj.emit(ids, positions, caps, regards)


@rpc("authority", "call_local", "reliable")
func _trace_rpc(pos: Vector3) -> void:
	trace.emit(pos)


@rpc("authority", "call_local", "reliable")
func _tombe_rpc(nom: String, maison: int) -> void:
	tombe.emit(nom, maison)


@rpc("authority", "call_local", "reliable")
func _marque_rpc(poste: String, oui: bool) -> void:
	marque.emit(poste, oui)


@rpc("authority", "call_local", "reliable")
func _noir_rpc(oui: bool) -> void:
	noir.emit(oui)


@rpc("authority", "call_local", "reliable")
func _fin_rpc(res: Dictionary) -> void:
	fin.emit(res)


@rpc("authority", "call_local", "reliable")
func _parole_rpc(id: int, texte: String) -> void:
	parole.emit(id, texte)


@rpc("authority", "call_local", "reliable")
func _retour_chambre_rpc(pos: Vector3, regard: Vector3) -> void:
	retour_chambre.emit(pos, regard)


@rpc("authority", "call_local", "reliable")
func _cinematique_rpc(maison: int, victime: int, loups: Array) -> void:
	cinematique.emit(maison, victime, loups)


@rpc("authority", "call_local", "reliable")
func _pierre_rpc(tachee: bool) -> void:
	pierre.emit(tachee)


signal rideau(maison: int, cote: int, ouverture: float)


@rpc("authority", "call_local", "reliable")
func _rideau_rpc(maison: int, cote: int, ouverture: float) -> void:
	rideau.emit(maison, cote, ouverture)


@rpc("authority", "call_local", "reliable")
func _devore_rpc(id: int) -> void:
	devore.emit(id)


@rpc("authority", "call_local", "reliable")
func _morsure_rpc(vampire: int, cible: int) -> void:
	morsure.emit(vampire, cible)


# ================================================================ bots

func _nouveau_bot(id: int) -> Dictionary:
	return {"id": id, "pos": Vector3.ZERO, "cap": 0.0, "regard": Vector3(0, 0.9, 0), "chemin": [],
		"vitesse": 2.6, "mode": "fige", "but": "", "attente": 0.0, "vote_t": -1.0, "pas": 0.0}


## Vers une quête et au retour, un bot court (un humain y est guidé à 4,8 m/s).
const VITESSE_COURSE_BOT := 5.6


func _aller(id: int, vers: Vector3, nuit: bool) -> void:
	var b: Dictionary = _bots[id]
	b["court"] = false
	b["chemin"] = _chemin_bot(b, vers, nuit)
	b["mode"] = "libre"


## Le trajet d'un bot, et les portes qu'il y franchira : qui part de l'intérieur d'une maison en sort par
## une porte (qu'il ouvre si elle est close, cf. _bot_porte), jamais à travers un mur.
func _chemin_bot(b: Dictionary, vers: Vector3, nuit: bool) -> Array[Vector3]:
	var ouvertes: Dictionary = pub.get("portes", {})
	b["portes"] = Trajets.portes_a_franchir(b["pos"], vers, nuit, ouvertes)
	return Trajets.chemin(b["pos"], vers, nuit, ouvertes)


## Un bot devant une porte close sur son trajet l'ouvre comme un joueur (même ouverture, mêmes sons),
## attend qu'elle ait tourné, puis passe. Renvoie vrai tant qu'il attend. La nuit, les portes restent
## closes (sauf, derrière sa maison, pour un loup) : il passe alors comme avant.
func _bot_porte(id: int, b: Dictionary, delta: float) -> bool:
	var portes: Array = b.get("portes", [])
	if portes.is_empty():
		return false
	var chemin: Array = b["chemin"]
	var p: Dictionary = portes[0]
	var m: int = p["maison"]
	var q: String = p["porte"]
	var l := Ronde._vers_local(m, b["pos"])
	var s := 1.0 if q == "avant" else -1.0
	var dehors := l.z * s > Ronde.PROFONDEUR * 0.5 + 0.45
	var dedans := l.z * s < Ronde.PROFONDEUR * 0.5 - 0.9 and absf(l.x) < Ronde.LARGEUR * 0.5
	var coherent: bool = (not chemin.is_empty()) and (dehors or Ronde.maison_de(b["pos"]) == m or Ronde.maison_de(chemin[-1]) == m)
	if not coherent or (p["sortie"] and dehors) or (not p["sortie"] and dedans):
		portes.pop_front()
		b["attente_porte"] = 0.0
		return false
	var ouverte: bool = pub.get("portes", {}).get("%d:%s" % [m, q], false)
	var loin := Vector2(b["pos"].x, b["pos"].z).distance_to(Vector2(centre_porte_xz(m, q).x, centre_porte_xz(m, q).y))
	# La porte s'ouvre AVANT qu'on arrive (dès 3,2 m) : le bot ne s'arrête que si le battant tourne encore.
	if loin > 3.2:
		return false
	if ouverte:
		var reste: float = float(b.get("attente_porte", 0.0)) - delta
		b["attente_porte"] = reste
		return reste > 0.0 and loin <= 1.3
	var permis := phase != "nuit" or (partie != null and partie.est_loup(id))
	if not permis:
		return false
	_porte_rpc(m, q, true)
	if phase == "nuit":
		_envoyer_bruit_a_tous(Ronde.devant_porte(m, q), "poignee")
	b["attente_porte"] = 0.8     # le temps que le battant tourne (0,7 s)
	return loin <= 1.3


func centre_porte_xz(m: int, q: String) -> Vector2:
	var c := Trajets.centre_porte(m, q)
	return Vector2(c.x, c.z)


func _bots_avancer(delta: float) -> void:
	for id in _bots:
		var b: Dictionary = _bots[id]
		if b["mode"] == "mort":
			continue
		var chemin: Array = b["chemin"]
		if chemin.is_empty():
			continue
		if _bot_porte(id, b, delta):
			continue
		var cible: Vector3 = chemin[0]
		var d: Vector3 = cible - b["pos"]
		d.y = 0
		var pas: float = (VITESSE_COURSE_BOT if b.get("court", false) else float(b["vitesse"])) * delta
		if d.length() <= pas:
			b["pos"] = cible
			chemin.pop_front()
			if chemin.is_empty():
				b["court"] = false
		else:
			b["pos"] = b["pos"] + d.normalized() * pas
			b["cap"] = lerp_angle(b["cap"], atan2(d.x, d.z), clampf(delta * 8.0, 0, 1))
		# Sans moteur physique : on suit le sol (les marches et la terrasse du temple).
		var p: Vector3 = b["pos"]
		p.y = Ronde.hauteur_sol(p)
		b["pos"] = p
		# La nuit, un loup bot peut rater son combo sur un sol bruyant.
		if phase == "nuit" and partie.est_loup(id):
			var sol := Ronde.sol_a(b["pos"])
			if Combo.mode_du_sol(sol) != "":
				b["pas"] += pas
				if b["pas"] > 2.6:
					b["pas"] = 0.0
					var risque := 0.15 + 0.05 * partie.faim
					if _rng.randf() < risque:
						var sortes := {"graviers": "gravier", "planches": "craquement", "flaques": "clapotis", "feuilles": "froissement"}
						_envoyer_bruit_a_tous(b["pos"], sortes[sol])
						_noter_trace(b["pos"])


## Ce que font les bots quand le meneur appelle leur rôle (après un temps de réflexion).
func _bots_appel(a: String) -> void:
	for id in _bots:
		if not partie.vivant(id):
			continue
		var r := partie.role(id)
		var b: Dictionary = _bots[id]
		var choix := _autres_vivants(id)
		if choix.is_empty():
			continue
		var delai := _rng.randf_range(3.0, 8.0)
		match a:
			"liseuse":
				if r == "liseuse":
					var deja: Array = _savoir_bots[id].get("lus", [])
					var neufs := choix.filter(func(x): return not deja.has(x))
					if not neufs.is_empty():
						var c: int = neufs[_rng.randi_range(0, neufs.size() - 1)]
						deja.append(c)
						_savoir_bots[id]["lus"] = deja
						_plus_tard(delai, a, func(): traiter(id, "lire", c))
			"entremetteuse":
				if r == "entremetteuse":
					var tous := partie.vivants()
					tous.shuffle()
					if tous.size() >= 2:
						_plus_tard(delai, a, func(): traiter(id, "lier", tous[0], tous[1]))
			"enfant":
				if r == "enfant":
					var c2: int = choix[_rng.randi_range(0, choix.size() - 1)]
					_plus_tard(delai, a, func(): traiter(id, "modele", c2))
			"veilleur":
				if r == "veilleur":
					var c3: int = choix[_rng.randi_range(0, choix.size() - 1)]
					_plus_tard(delai, a, func():
						traiter(id, "garder", c3)
						if _garde != c3 and choix.size() > 1:
							traiter(id, "garder", choix[(choix.find(c3) + 1) % choix.size()]))
			"herboriste":
				if r == "herboriste" and not _maisons_ouvertes.is_empty() and partie.potions()["vie"] and _rng.randf() < 0.5:
					var m: int = _maisons_ouvertes[0]
					_plus_tard(delai, a, func(): traiter(id, "sauver_maison", m))
			"loups", "solitaire":
				if _chasseurs_appel().has(id):
					# Sortir par sa porte, rejoindre la pierre.
					var ang := _rng.randf() * TAU
					b["but"] = "pierre"
					b["attente"] = 0.0
					_aller(id, Ronde.autour_autel(ang), true)


func _plus_tard(delai: float, appel: String, quoi: Callable) -> void:
	get_tree().create_timer(delai, false).timeout.connect(func():
		if phase == "nuit" and _appel == appel:
			quoi.call())


func _bots_nuit_tick(_delta: float) -> void:
	if not (_appel in ["loups", "solitaire"]) or _vote_loups_fait or not _vote_ouvert():
		return
	for id in _bots:
		if not partie.vivant(id) or not _chasseurs_appel().has(id) or _votes_loups.has(id):
			continue
		var b: Dictionary = _bots[id]
		if b["but"] != "pierre" or not (b["chemin"] as Array).is_empty():
			continue
		# Arrivé à la pierre : suivre la maison la plus votée, sinon en choisir une (le bot ne sait pas
		# plus que les autres qui est loup : il peut se tromper de porte).
		var compte := {}
		for l in _votes_loups:
			compte[_votes_loups[l]] = compte.get(_votes_loups[l], 0) + 1
		var maison := -1
		for m in compte:
			if maison < 0 or compte[m] > compte[maison]:
				maison = m
		if maison < 0 or _rng.randf() < 0.2:
			var proies := NuitLoups.proies(_autres_vivants(id), partie.chasseurs()).filter(func(x): return x != _garde or _rng.randf() < 0.5)
			if "--condamne-moi" in OS.get_cmdline_user_args():
				proies = proies.filter(func(x): return x != moi())   # essai : l'hôte doit vivre jusqu'au Conseil
			if proies.is_empty():
				continue
			maison = sieges[proies[_rng.randi_range(0, proies.size() - 1)]]["maison"]
		b["regard"] = Ronde.centre_maison(maison) + Vector3(0, 1.5, 0)
		traiter(id, "vote_loup", maison)
		if partie.role(id) == "souffleur" and partie.souffles_restants() > 0 and _rng.randf() < 0.5:
			var a := _rng.randf() * TAU
			traiter(id, "faux_bruit", Vector3(sin(a), 0, cos(a)) * 21.0)


func _bots_debut_jour() -> void:
	for id in _bots:
		if not partie.vivant(id):
			continue
		_bots[id]["attente"] = _rng.randf_range(1.0, 8.0)
		_bots[id]["but"] = "flane"


func _bots_vote_tick(delta: float) -> void:
	var votes := partie.votes()
	for id in _bots:
		if not partie.vivant(id) or not partie.joueurs[id]["peut_voter"]:
			continue
		var b: Dictionary = _bots[id]
		if b["vote_t"] < 0:
			continue
		b["vote_t"] -= delta
		if b["vote_t"] > 0:
			continue
		b["vote_t"] = -1.0
		var c := _choix_vote(id, votes)
		if c > 0:
			traiter(id, "voter", c)
			b["regard"] = _position(c) + Vector3(0, 0.9, 0)


func _choix_vote(id: int, votes: Dictionary) -> int:
	var candidats := _autres_vivants(id)
	if candidats.is_empty():
		return -1
	# Essai (--condamne-moi) : au Conseil, tous les bots votent contre l'hôte, pour voir le supplice.
	if phase == "vote" and "--condamne-moi" in OS.get_cmdline_user_args() and candidats.has(moi()):
		return moi()
	var loup := partie.camp(id) == Roles.MEUTE or partie.camp(id) == Roles.SOLITAIRE
	if loup:
		candidats = candidats.filter(func(x): return not partie.est_loup(x))
	else:
		var s: Dictionary = _savoir_bots.get(id, {})
		var suspect: int = s.get("suspect", -1)
		if suspect > 0 and suspect != id and partie.vivant(suspect):
			return suspect
		var innocents: Array = s.get("innocents", [])
		var reste_c := candidats.filter(func(x): return not innocents.has(x))
		if not reste_c.is_empty():
			candidats = reste_c
	# Suivre le plus accusé, souvent ; sinon au hasard.
	var compte := {}
	for v in votes:
		compte[votes[v]] = compte.get(votes[v], 0) + 1
	var meilleur := -1
	for c in compte:
		if candidats.has(c) and (meilleur < 0 or compte[c] > compte[meilleur]):
			meilleur = c
	if meilleur > 0 and _rng.randf() < 0.6:
		return meilleur
	return candidats[_rng.randi_range(0, candidats.size() - 1)] if not candidats.is_empty() else -1


## Les bots ne parlent pas : ils disent au Conseil ce qu'ils savent (ou ce qu'ils inventent).
## Les autres bots les croient à moitié ; les joueurs lisent la bulle et doivent trier.
func _bots_debattent() -> void:
	var orateurs := []
	for id in _bots:
		if partie.vivant(id):
			orateurs.append(id)
	orateurs.shuffle()
	var t := 6.0
	for id in orateurs:
		var phrase := _phrase_de_bot(id)
		if phrase.is_empty():
			continue
		var quand := t
		t += _rng.randf_range(7.0, 13.0)
		if t > durees["conseil"] - 10.0:
			break
		get_tree().create_timer(quand, false).timeout.connect(func():
			if phase != "conseil" or not partie.vivant(id):
				return
			_parole_rpc.rpc(id, phrase[0])
			var accuse: int = phrase[1]
			if accuse > 0:
				for autre in _bots:
					if autre != id and partie.vivant(autre) and not partie.est_loup(autre) and _rng.randf() < 0.5:
						var s: Dictionary = _savoir_bots.get(autre, {"suspect": -1, "innocents": []})
						if s["suspect"] < 0 or _rng.randf() < 0.3:
							s["suspect"] = accuse
						_savoir_bots[autre] = s)


## [texte, id accusé ou -1] ; [] si le bot se tait.
func _phrase_de_bot(id: int) -> Array:
	var cibles := _autres_vivants(id)
	if cibles.is_empty():
		return []
	var role := partie.role(id)
	if partie.est_loup(id) or role == "traitre":
		var proies := cibles.filter(func(x): return not partie.est_loup(x))
		if proies.is_empty() or _rng.randf() < 0.35:
			return ["Moi je n'ai rien vu… et c'est bien ça qui m'inquiète.", -1]
		var c: int = proies[_rng.randi_range(0, proies.size() - 1)]
		var mensonges := ["J'ai lu l'âme de %s cette nuit. C'est un loup, je vous le jure.",
			"%s rôdait près du cimetière hier soir. Je l'ai vue.",
			"%s était dans la quête ratée d'hier, comme par hasard.",
			"%s ne regarde personne dans les yeux. Ça ne trompe pas."]
		var phrase: String = mensonges[_rng.randi_range(0, mensonges.size() - 1)]
		return [phrase % qui(c, phrase.begins_with("%")), c]
	var s: Dictionary = _savoir_bots.get(id, {})
	var suspect: int = s.get("suspect", -1)
	if suspect > 0 and partie.vivant(suspect):
		if role == "liseuse":
			return ["J'ai lu l'âme de %s. C'est un loup." % qui(suspect), suspect]
		return ["Les indices du tableau désignent %s. Je vote contre elle." % qui(suspect), suspect]
	var innocents: Array = s.get("innocents", [])
	for i in innocents:
		if partie.vivant(i) and _rng.randf() < 0.5:
			return ["Je me porte garant de %s : ce n'est pas un loup." % qui(i), -1]
	if _rng.randf() < 0.5:
		var c2: int = cibles[_rng.randi_range(0, cibles.size() - 1)]
		return ["Je ne sais pas… %s me paraît bizarre depuis ce matin." % qui(c2), -1]
	return []


func _bots_trappeur(t: int) -> void:
	var s: Dictionary = _savoir_bots.get(t, {})
	var c: int = s.get("suspect", -1)
	if c < 0 or not partie.vivant(c):
		var v := _autres_vivants(t)
		c = v[_rng.randi_range(0, v.size() - 1)] if not v.is_empty() else -1
	if c > 0:
		get_tree().create_timer(_rng.randf_range(2.0, 6.0), false).timeout.connect(func():
			if phase == "trappeur" and partie.trappeur_attendu() == t:
				traiter(t, "trappe", c))


func _bot_apprend(id: int, ind: Dictionary) -> void:
	var s: Dictionary = _savoir_bots.get(id, {"suspect": -1, "innocents": []})
	match ind["sorte"]:
		"lecture":
			if ind["loup"]:
				s["suspect"] = ind["cible"]
			else:
				(s["innocents"] as Array).append(ind["cible"])
		"innocent":
			(s["innocents"] as Array).append(ind["cible"])
		"trois":
			if s["suspect"] < 0:
				var ids: Array = ind["ids"]
				s["suspect"] = ids[_rng.randi_range(0, ids.size() - 1)]
	_savoir_bots[id] = s


func _autres_vivants(id: int) -> Array:
	return partie.vivants().filter(func(x): return x != id)


func _plus_proche(id: int) -> int:
	var meilleur := -1
	var d := 9.0
	for autre in sieges:
		if autre == id or not partie.vivant(autre):
			continue
		var e := _position(autre).distance_to(_position(id))
		if e < d:
			d = e
			meilleur = autre
	return meilleur


# ================================================================ les quêtes du jour (hôte)

## Un nouveau jour : trois quêtes tirées, et le vote du matin s'ouvre dès qu'on sort de chez soi.
func _nouveau_jour() -> void:
	jour_n += 1
	_quetes.clear()
	_propositions.clear()
	_prets.clear()
	for id in sieges:
		if partie.vivant(id):
			# À l'aube on sort juste devant sa porte et on s'arrête là (pas jusqu'au rondin, Edwin 01/11).
			_placer(id, Ronde.devant_porte(sieges[id]["maison"]), Vector3.ZERO, "libre")
	for i in Ronde.NB_MAISONS:
		_porte_rpc(i, "avant", true)
	_bots_debut_jour()
	_envoyer_prives()   # le premier matin, chacun reçoit sa fiche (villageois, sans rôle)
	_votes_quete.clear()
	_jour_libre = false
	_poser_quetes(Quetes.tableau(jour_n, _rng, _recents))
	_entrer("tableau")


func _poser_quetes(t: Array) -> void:
	t = Quetes.un_seul_role(t)
	# Drapeau d'essai : --quete=<jeu> impose ce jeu à la première quête du tableau (si le jeu existe).
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--quete=") and Quetes.JEUX.has(a.substr(8)) and not t.is_empty():
			(t[0] as Dictionary)["jeu"] = a.substr(8)
	_quetes.clear()
	_recents.clear()
	for k in t.size():
		var q: Dictionary = t[k]
		_recents.append(q["jeu"])
		_quetes.append({"jeu": q["jeu"], "niveau": q["niveau"], "recompense": q["recompense"], "inscrits": [],
			"etat": "inscription", "zone": k, "mj": null, "t": 0.0, "reussie": false})


## Un vote du matin : k = 0..2 (une quête) ou Quetes.RESTER. On peut changer d'avis tant que
## le vote dure. Pas besoin d'aller au tableau : il ne sert plus qu'à lire le détail.
func _intention_voter_quete(id: int, k: int) -> String:
	if phase != "tableau":
		return "Le vote de la quête est clos."
	if not partie.vivant(id):
		return "Les morts ne votent plus."
	if k < 0 or k > Quetes.RESTER or (k != Quetes.RESTER and k >= _quetes.size()):
		return "Choix inconnu."
	# Avec un maire, lui seul choisit la quête ; les autres ne disent que « participer » (0) ou non.
	if _maire_actif() and id != partie.maire:
		k = Quetes.participation(k)
	_votes_quete[id] = k
	_envoyer_pub(_etat_pub())
	return ""


## Y a-t-il un maire vivant pour choisir la quête du jour ? (Pas au premier jour : on vote 1 à 4.)
func _maire_actif() -> bool:
	return partie != null and partie.maire > 0 and partie.vivant(partie.maire) and sieges.has(partie.maire)


## Fin du vote : la quête la plus votée part, avec tous les vivants sauf ceux qui ont voté
## « Rester » ; si « Rester » l'emporte, temps libre au village. La voix du maire compte double,
## puis le hasard départage (décisions d'Edwin, 30/10).
func _resoudre_vote_quete() -> void:
	var vivants := sieges.keys().filter(func(x): return partie.vivant(x))
	var votes := {}
	for id in _votes_quete:
		if partie.vivant(id):
			votes[id] = _votes_quete[id]
	var gagnant: int
	if _maire_actif():
		gagnant = Quetes.choix_du_maire(int(votes.get(partie.maire, -1)), _quetes.size(), _rng)
	else:
		gagnant = Quetes.depouiller(votes, partie.maire, _quetes.size(), _rng)
	# Drapeau d'essai : --quete=<jeu> fait gagner la première quête (celle qu'il impose).
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--quete=") and Quetes.JEUX.has(a.substr(8)):
			gagnant = 0
	for k in _quetes.size():
		if k != gagnant:
			_quetes[k]["etat"] = "ecartee"
	if gagnant == Quetes.RESTER:
		_jour_libre = true
		_annoncer_a_tous("Le village a voté : on reste aujourd'hui. Pas de quête, pas de rôle à gagner.", "", 5.0)
		_envoyer_pub(_etat_pub())
		_entrer("pret")
		return
	var q: Dictionary = _quetes[gagnant]
	q["inscrits"] = vivants.filter(func(x): return int(votes.get(x, -1)) != Quetes.RESTER)
	_annoncer_a_tous("Le village a choisi : %s. En route, sauf ceux qui restent." % Quetes.nom_jeu(q["jeu"]), "cloche", 4.0)
	_lancer_quetes()


func _intention_choisir(id: int, choix: Variant) -> String:
	if phase != "choix_maire" or id != partie.maire:
		return "Seul le maire choisit les quêtes, le matin."
	if not choix is Array or (choix as Array).size() != Quetes.NB_DU_JOUR:
		return "Choisis trois quêtes."
	var pris := []
	for c in choix:
		var k := int(c)
		if k < 0 or k >= _propositions.size() or pris.has(k):
			return "Choisis trois quêtes différentes."
		pris.append(k)
	_poser_quetes(pris.map(func(k): return _propositions[k]))
	reste = minf(reste, 1.0)
	return ""


## La quête où est inscrit ce joueur, ou {}.
func _quete_de(id: int) -> Dictionary:
	for q in _quetes:
		if (q["inscrits"] as Array).has(id):
			return q
	return {}


## Fin des inscriptions : les quêtes assez remplies partent, les autres sont annulées.
func _lancer_quetes() -> void:
	var parties := 0
	var annulees := PackedStringArray()
	var remplaces := PackedStringArray()
	for q in _quetes:
		if q["etat"] != "inscription":
			continue
		var vivants_inscrits: Array = (q["inscrits"] as Array).filter(func(x): return partie.vivant(x))
		q["inscrits"] = vivants_inscrits
		if vivants_inscrits.size() < Quetes.MIN_INSCRITS:
			q["etat"] = "annulee"
			annulees.append(Quetes.nom_jeu(q["jeu"]))
			q["inscrits"] = []
			continue
		# Le nombre d'inscrits ne convient pas à ce jeu : un autre, compatible, se joue à sa place.
		if not Quetes.effectif_valide(q["jeu"], vivants_inscrits.size()):
			var ancien: String = q["jeu"]
			var autre := Quetes.remplacant(ancien, vivants_inscrits.size(), _rng, _quetes.map(func(x): return x["jeu"]))
			if autre != "":
				q["jeu"] = autre
				q["remplace"] = "Pas le bon nombre : %s devient %s" % [Quetes.nom_jeu(ancien).to_lower(), Quetes.nom_jeu(autre)]
				remplaces.append(q["remplace"])
		q["etat"] = "trajet"
		q["t"] = 0.0
		_trace_q("départ vers %s : %s" % [q["jeu"], str(vivants_inscrits)])
		parties += 1
		var n := vivants_inscrits.size()
		for k in n:
			var id: int = vivants_inscrits[k]
			# On arrive juste derrière sa place, hors du décor (jamais dans le puits ni sur la table) :
			# il ne reste qu'un pas pour s'y mettre.
			var arrivee := Quetes.zone(q["zone"]) + DecorQuete.arrivee(q["jeu"], k, n)
			if _bots.has(id):
				_aller_zone(id, q["zone"], arrivee)
			else:
				# Pas d'écran de transition : le jeu l'y amène, tout seul (la tête reste libre), et
				# il attend sur place que l'équipe soit là (Edwin, 30/10 : on ne s'en va pas).
				_placer(id, arrivee, Quetes.zone(q["zone"]), "poste")
	if not annulees.is_empty():
		if annulees.size() == 1:
			_annoncer_a_tous("Trop peu de monde pour partir (%d minimum) : %s n'aura pas lieu. Temps libre au village." % [Quetes.MIN_INSCRITS, annulees[0]], "", 5.0)
		else:
			# Une phrase complète par quête (jamais de noms recollés, qui ne se traduiraient pas).
			var lignes := PackedStringArray()
			for nom_a in annulees:
				lignes.append("Trop peu de monde pour partir (%d minimum) : %s n'aura pas lieu." % [Quetes.MIN_INSCRITS, nom_a])
			lignes.append("Temps libre au village.")
			_annoncer_a_tous("\n".join(lignes), "", 5.0)
	if not remplaces.is_empty():
		_annoncer_a_tous("\n".join(PackedStringArray(Array(remplaces).map(func(r: String) -> String: return r + "."))), "", 5.0)
	if parties == 0:
		_jour_libre = true
		_entrer("pret")
	else:
		_entrer("quete")


func _trace_q(texte: String) -> void:
	if "--trace-quetes" in OS.get_cmdline_user_args():
		print("[quete] %.1f s · " % (Time.get_ticks_msec() / 1000.0), texte)


func _aller_zone(id: int, k: int, arrivee: Vector3) -> void:
	var b: Dictionary = _bots[id]
	var dedans := Quetes.passage(k, Ronde.R_LISIERE - 4.0)
	var chemin: Array[Vector3] = _chemin_bot(b, dedans, false)
	chemin.append(Quetes.passage(k, Ronde.R_LISIERE + 2.5))
	chemin.append(arrivee)
	b["chemin"] = chemin
	b["mode"] = "libre"
	b["but"] = "quete"
	b["court"] = true   # Edwin, 30/10 : les bots étaient trop lents pour aller à la quête


## À moins de ce rayon (m) du portail de retour, on est « rentré ».
const RAYON_PORTAIL := 2.6


func _rentrer(id: int, k: int) -> void:
	var b: Dictionary = _bots[id]
	# Jusqu'au portail qui sépare le sentier du village, et pas plus loin : on y reste, libre de ses pas.
	var chemin: Array[Vector3] = [Quetes.passage(k, Ronde.R_LISIERE + 2.5), Quetes.portail_retour()]
	b["chemin"] = chemin
	b["mode"] = "libre"
	b["but"] = "retour"
	b["court"] = true


func _quetes_tick(delta: float) -> void:
	for q in _quetes:
		match q["etat"]:
			"trajet":
				q["t"] += delta
				var arrives := true
				var humains_la := true
				var centre_q := Quetes.zone(q["zone"])
				var nb_q: int = (q["inscrits"] as Array).size()
				for k_q in nb_q:
					var id: int = q["inscrits"][k_q]
					if not partie.vivant(id):
						continue
					var ici := _position(id)
					# Arrivé = dans la clairière, ou posé à SON point d'arrivée (celui des Lanternes est à plus de
					# 6 m du centre : on attendait alors les 50 s du délai, 31/10).
					var arr := centre_q + DecorQuete.arrivee(q["jeu"], k_q, nb_q)
					if ici.distance_to(centre_q) > Quetes.RAYON_ZONE and Vector2(ici.x - arr.x, ici.z - arr.z).length() > 2.0:
						arrives = false
						if not _bots.has(id):
							humains_la = false
				if Quetes.depart_pret(q["t"], arrives, humains_la):
					_ouvrir_role(q)
			"role":
				_tick_role(q, delta)
			"jeu":
				var mj: MiniJeu = q["mj"]
				_pieds_du_jeu(q, mj)
				for id in mj.ids:
					if (_bots.has(id) or _auto_humains.has(id)) and partie.vivant(id):
						mj.bot(id, delta)
				_fantomes_bots(q, delta)
				if test_fige:
					mj.duree += delta   # le jeu tourne, son compte à rebours ne bouge plus
				mj.avancer(delta)
				_suites_des_pieds(q, mj, delta)
				for pa in mj.paroles:
					_parole_rpc.rpc(pa[0], pa[1])
				mj.paroles.clear()
				if mj.fini:
					_finir_quete(q)
			"retour":
				q["t"] += delta
				var tous := true
				var portail := Quetes.portail_retour()
				for id in q["inscrits"]:
					var pos := _position(id)
					if partie.vivant(id) and Vector2(pos.x - portail.x, pos.z - portail.z).length() > RAYON_PORTAIL:
						tous = false
				if tous or q["t"] > 45.0:
					# Les retardataires sont amenés au portail, pas jusqu'à leur rondin.
					for id in q["inscrits"]:
						var pos := _position(id)
						if partie.vivant(id) and Vector2(pos.x - portail.x, pos.z - portail.z).length() > RAYON_PORTAIL:
							_placer(id, portail, Vector3.ZERO, "libre")
					q["etat"] = "finie"
					_envoyer_pub(_etat_pub())
	_envoi_quetes += delta
	if _envoi_quetes >= 0.1:
		_envoi_quetes = 0.0
		for q in _quetes:
			if q["etat"] == "jeu":
				_envoyer_vues(q)
	var reste_a_faire := false
	for q in _quetes:
		if q["etat"] in ["trajet", "role", "jeu", "retour"]:
			reste_a_faire = true
	if not reste_a_faire and phase == "quete":
		_entrer("pret")


## Les jeux où l'on marche pour de vrai : l'hôte donne au jeu la position (locale à la clairière) de
## ceux qui marchent, avant chaque image.
func _pieds_du_jeu(q: Dictionary, mj: MiniJeu) -> void:
	var centre := Quetes.zone(q["zone"])
	for id in mj.ids:
		if mj.a_pied(id) and partie.vivant(id):
			mj.pieds[id] = _position(id) - centre


## Ce que le jeu demande en retour : faire marcher un bot jusqu'à une pierre, replacer un tombé.
func _suites_des_pieds(q: Dictionary, mj: MiniJeu, delta := 0.0) -> void:
	var centre := Quetes.zone(q["zone"])
	_placements_du_jeu(q, mj, centre, delta)
	for d in mj.deplacements:
		var id: int = d[0]
		var ou: Vector3 = centre + (d[1] as Vector3)
		if _bots.has(id):
			var b: Dictionary = _bots[id]
			var ch: Array[Vector3] = [ou]
			b["chemin"] = ch
			b["mode"] = "libre"
			b["but"] = "quete"
			b["court"] = false
		elif partie.vivant(id) and not sieges[id]["bot"]:
			_placer(id, ou, Vector3.ZERO, "libre")   # un pilote auto : le jeu l'y amène
	mj.deplacements.clear()
	for r in mj.rappels:
		var id2: int = r[0]
		var ou2: Vector3 = centre + (r[1] as Vector3)
		var vers: Vector3 = centre + (r[2] as Vector3)
		if _bots.has(id2):
			var b2: Dictionary = _bots[id2]
			b2["pos"] = ou2
			b2["chemin"] = [] as Array[Vector3]
			b2["cap"] = atan2(vers.x - ou2.x, vers.z - ou2.z)
		elif not sieges[id2]["bot"]:
			_chute_rpc.rpc_id(id2, ou2, vers)
	mj.rappels.clear()


## Le jeu change des joueurs de place et de mode (cf. MiniJeu.placements), au bout du délai demandé. Un bot
## y est posé d'un coup (il ne traverse pas la clairière à pied pendant que le jeu attend).
func _placements_du_jeu(q: Dictionary, mj: MiniJeu, centre: Vector3, delta: float) -> void:
	for pl in mj.placements:
		(q.get_or_add("placements", []) as Array).append([float(pl[4]), pl[0], pl[1], pl[2], pl[3]])
	mj.placements.clear()
	if not q.has("placements"):
		return
	var reste: Array = []
	for e in q["placements"]:
		e[0] = float(e[0]) - delta
		if float(e[0]) > 0.0:
			reste.append(e)
			continue
		var id: int = e[1]
		var ou: Vector3 = centre + (e[2] as Vector3)
		var vers: Vector3 = centre + (e[3] as Vector3)
		var mode: String = e[4]
		if _bots.has(id):
			var b: Dictionary = _bots[id]
			b["pos"] = ou
			b["chemin"] = [] as Array[Vector3]
			b["mode"] = mode
			b["court"] = false
			b["cap"] = atan2(vers.x - ou.x, vers.z - ou.z)
			if mode == "libre":
				b["but"] = "quete"
		elif partie.vivant(id) and not sieges[id]["bot"]:
			_placer(id, ou, vers, mode)
	q["placements"] = reste


@rpc("authority", "call_local", "reliable")
func _chute_rpc(pos: Vector3, regard: Vector3) -> void:
	chute.emit(pos, regard)


func _envoyer_vues(q: Dictionary) -> void:
	var mj: MiniJeu = q["mj"]
	for id in mj.ids:
		if sieges[id]["bot"]:
			continue
		var v := mj.vue_pour(id)
		v["titre"] = Quetes.nom_jeu(q["jeu"])
		v["niveau"] = Quetes.NOMS_NIVEAUX[q["niveau"]]
		v["reste"] = mj.reste()
		v["equipe"] = mj.ids.size()
		v["seuil"] = mj.seuil_requis()
		v["jeu"] = q["jeu"]
		v["zone"] = q["zone"]
		v["rang"] = mj.ids.find(id)
		v["variante"] = mj.variante
		v["liste"] = mj.liste()
		v["hante"] = mj.vient_d_etre_hante(id)
		mj.ajouter_vies(v)
		Prise.compacter(v, id)   # le bloc « prise » (objets à prendre/poser) ne part que pour ce qui bouge
		_quete_rpc.rpc_id(id, v)


## Les quêtes à rôle unique ouvrent d'abord le CHOIX du rôle : une zone lumineuse au sol, à gauche,
## au nom du rôle. Le premier qui s'y met le prend ; sans volontaire en 15 s, le hasard tranche.
## Les autres jeux démarrent tout de suite.
func _ouvrir_role(q: Dictionary) -> void:
	var inscrits: Array = (q["inscrits"] as Array).filter(func(x): return partie.vivant(x))
	if Quetes.role_unique(q["jeu"]) == "" or inscrits.is_empty():
		_demarrer_quete(q)
		return
	var centre := Quetes.zone(q["zone"])
	q["etat"] = "role"
	q["t"] = 0.0
	q["elu"] = -1
	q["pause"] = 0.0
	q["choix"] = ChoixRole.new(inscrits, Quetes.DELAI_ROLE, _rng)
	q["zone_role"] = DecorQuete.zone_role(q["jeu"], q["zone"], inscrits.size())
	var ou: Vector3 = centre + (q["zone_role"] as Vector3)
	_trace_q("choix du rôle « %s » dans %s" % [Quetes.role_unique(q["jeu"]), q["jeu"]])
	# Un bot sur deux environ se met de lui-même dans la zone, au bout de quelques secondes.
	q["aspirant"] = -1
	q["aspirant_t"] = _rng.randf_range(2.0, 9.0)
	var bots_la: Array = inscrits.filter(func(x): return _bots.has(x))
	if not bots_la.is_empty() and _rng.randf() < 0.5:
		q["aspirant"] = bots_la[_rng.randi_range(0, bots_la.size() - 1)]
	# Personne d'humain pour s'avancer : inutile de faire attendre quinze secondes pour rien.
	if bots_la.size() == inscrits.size() and not bots_la.is_empty():
		q["aspirant"] = bots_la[_rng.randi_range(0, bots_la.size() - 1)]
		q["aspirant_t"] = _rng.randf_range(0.5, 1.5)
	# Les humains peuvent maintenant marcher dans la clairière (jusque-là, chacun attendait à l'arrivée).
	for id in inscrits:
		if not _bots.has(id):
			_placer(id, _position(id), ou, "libre")
	_envoyer_pub(_etat_pub())


func _tick_role(q: Dictionary, delta: float) -> void:
	var ch: ChoixRole = q["choix"]
	var centre := Quetes.zone(q["zone"])
	var ou: Vector3 = centre + (q["zone_role"] as Vector3)
	if ch.elu < 0:
		var asp: int = q["aspirant"]
		if asp >= 0:
			q["aspirant_t"] -= delta
			if q["aspirant_t"] <= 0.0 and _bots.has(asp):
				var b: Dictionary = _bots[asp]
				b["chemin"] = [ou] as Array[Vector3]
				b["mode"] = "libre"
				b["but"] = "quete"
				b["court"] = true
				q["aspirant"] = -1
		var dedans := []
		for id in ch.ids:
			if partie.vivant(id) and Vector2(_position(id).x - ou.x, _position(id).z - ou.z).length() < Quetes.RAYON_ROLE:
				dedans.append(id)
		ch.avancer(delta, dedans)
		if ch.elu >= 0:
			q["elu"] = ch.elu
			_trace_q("rôle %s pris par %d (%s) après %.1f s" % [Quetes.role_unique(q["jeu"]), ch.elu, "hasard" if ch.par_hasard else "zone", Quetes.DELAI_ROLE - ch.reste])
			var role: String = Quetes.role_unique(q["jeu"])
			var qui := etiquette(ch.elu)
			var texte: String = ("Le hasard désigne %s : il sera %s." if ch.par_hasard else "%s s'est avancé : il sera %s.") % [qui, role.to_lower()]
			for id in ch.ids:
				if not sieges[id]["bot"]:
					_annonce_rpc.rpc_id(id, texte, "cloche", 3.0)
			_envoyer_pub(_etat_pub())
	else:
		q["pause"] += delta
		if q["pause"] >= Quetes.PAUSE_ROLE:
			_demarrer_quete(q)


func _demarrer_quete(q: Dictionary) -> void:
	_trace_q("début du jeu %s après %.1f s de trajet" % [q["jeu"], q["t"]])
	var mj := _fabriquer_mj(q, _rng.randi())
	# Mode test : une règle du jour imposée. Elle se tire dans `demarrer`, alors on cherche la
	# graine qui la donne (sans toucher aux douze jeux).
	if q.has("variante"):
		for g in 400:
			var essai := _fabriquer_mj(q, g)
			if essai.variante == q["variante"]:
				mj = essai
				break
	q["mj"] = mj
	q["etat"] = "jeu"
	q["t"] = 0.0
	# Chacun à son poste dans le décor (la rive du pont, sa place autour du puits…), libre d'y bouger.
	var centre := Quetes.zone(q["zone"])
	var n := mj.ids.size()
	for k in n:
		if mj.a_pied(mj.ids[k]):
			# Le marcheur des Lanternes part de la rive, libre de marcher (pas cloué à un poste).
			var rg_dep: Vector3 = mj.regard_depart(mj.ids[k])
			_placer(mj.ids[k], centre + mj.depart_locale(mj.ids[k]), centre + (rg_dep if rg_dep != Vector3.ZERO else DecorQuete.regard(q["jeu"], k, n)), "libre")
			if _bots.has(mj.ids[k]):
				_bots[mj.ids[k]]["but"] = "quete"   # sans quoi il partirait flâner au village
		else:
			_placer(mj.ids[k], centre + DecorQuete.poste(q["jeu"], k, n), centre + DecorQuete.regard(q["jeu"], k, n), "poste")
	# Les bots courent à leur poste (à 1 m/s ils mettaient une éternité à y arriver).
	for id in mj.ids:
		if _bots.has(id) and not (_bots[id]["chemin"] as Array).is_empty():
			_bots[id]["court"] = true
	_envoyer_pub(_etat_pub())
	_envoyer_vues(q)


func _finir_quete(q: Dictionary) -> void:
	var mj: MiniJeu = q["mj"]
	_trace_q("fin du jeu %s après %.1f s (durée prévue %.0f s)" % [q["jeu"], mj.temps, mj.duree])
	var nom_q := Quetes.nom_jeu(q["jeu"])
	var ok := mj.equipe_reussit()
	q["reussie"] = ok
	var texte := ""
	q["titre_seul"] = _titre_seul(q)
	if ok and q["recompense"] == "role" and not mj.ids.is_empty():
		# Un loup ne reçoit jamais de rôle (il redevenait villageois sans le savoir), et un rôle
		# gagné ne s'écrase pas : on tire d'abord parmi ceux qui n'en ont pas encore. Équipe de
		# loups seulement : personne ne reçoit rien, mais l'annonce reste la même (couverture).
		var pas_loups: Array = mj.ids.filter(func(x): return not partie.est_loup(x) and partie.role(x) != "traitre")
		var sans: Array = pas_loups.filter(func(x): return not partie.joueurs[x]["role_gagne"])
		var tirage: Array = sans if not sans.is_empty() else pas_loups
		if not tirage.is_empty():
			var gagnant: int = tirage[_rng.randi_range(0, tirage.size() - 1)]
			var r := Quetes.role_gagne(q["niveau"], jour_n, partie.roles_pris() + partie.roles_retires, _rng)
			partie.donner_role(gagnant, r["role"], r["titre"], nom_q)
		# Le village sait qu'un rôle a été gagné, jamais lequel ni par qui (cadrage du 31/10).
		_indices.append("%s : réussie. %s." % [nom_q, Quetes.texte_recompense("role", q["titre_seul"], true)])
		texte = "Quête réussie ! L'un de vous vient de recevoir %s, en secret." % ("un titre" if q["titre_seul"] else "un rôle")
	elif ok:
		var ind := partie.indice_quete(q["niveau"], mj.ids)
		_indices.append("%s : %s" % [nom_q, ind["texte"]])
		texte = "Quête réussie ! Un indice est affiché au tableau : %s" % str(ind["texte"])
		for id in mj.ids:
			if sieges[id]["bot"]:
				_bot_apprend(id, ind)
	else:
		_indices.append("%s : échouée." % nom_q)
		texte = "Quête ratée (%d sur %d ont réussi, il en fallait %d). Rien gagné." % [mj.reussis().size(),
			mj.ids.size(), mj.seuil_requis()]
	_vider_evenements()
	if ok:
		for id in mj.ids:
			_compter(id, "quetes")
			if q["niveau"] in ["dur", "extreme"]:
				_compter(id, "quetes_" + str(q["niveau"]))
	for id in mj.ids:
		if not sieges[id]["bot"]:
			_quete_fin_rpc.rpc_id(id, texte, ok)
	q["etat"] = "retour"
	q["t"] = 0.0
	for id in mj.ids:
		if _bots.has(id):
			_rentrer(id, q["zone"])
		elif partie.vivant(id):
			# Et on rentre de la même façon : jusqu'au portail du sentier, où l'on reste libre.
			_placer(id, Quetes.portail_retour(), Vector3.ZERO, "libre")
	_annoncer_a_tous("%s : %s." % [nom_q, "réussie" if ok else "échouée"], "cloche" if ok else "", 3.0)
	_envoyer_pub(_etat_pub())
	_envoyer_prives()


func _fabriquer_mj(q: Dictionary, graine: int) -> MiniJeu:
	var script: GDScript = load(Quetes.JEUX[q["jeu"]][2])
	if script == null or not script.can_instantiate():
		script = load(Quetes.JEUX["runes"][2])
	var mj: MiniJeu = script.new()
	# Le joueur qui a pris le rôle unique (zone) passe en tête : c'est le rang 0 du décor.
	var elu: int = q.get("elu", -1)
	if elu >= 0 and (q["inscrits"] as Array).has(elu) and partie.vivant(elu):
		mj.ids.append(elu)
		mj.noms[elu] = etiquette(elu)
		mj.elu = elu
	for id in q["inscrits"]:
		if partie.vivant(id) and id != mj.elu:
			mj.ids.append(id)
			mj.noms[id] = etiquette(id)
			# Pas de sabotage le premier jour : il n'y a pas encore de loups.
			if jour_n > 1 and partie.est_loup(id):
				mj.saboteurs.append(id)
	for id in q.get("saboteurs", []):
		if mj.ids.has(id) and not mj.saboteurs.has(id):
			mj.saboteurs.append(id)
	mj.niveau = q["niveau"]
	mj.clairiere = int(q.get("zone", 0))
	mj.rng.seed = graine
	mj.demarrer()
	return mj


## L'hôte passe l'étape pendant les quêtes : tout s'arrête et tout le monde rentre.
func _forcer_fin_quetes() -> void:
	for q in _quetes:
		if q["etat"] in ["trajet", "role"]:
			_demarrer_quete(q)
		if q["etat"] == "jeu":
			(q["mj"] as MiniJeu).terminer()
			_finir_quete(q)
		if q["etat"] == "retour":
			for id in q["inscrits"]:
				if partie.vivant(id):
					_placer(id, Quetes.portail_retour(), Vector3.ZERO, "libre")
			q["etat"] = "finie"


@rpc("authority", "call_local", "unreliable_ordered")
func _quete_rpc(vue: Dictionary) -> void:
	quete_vue.emit(vue)


@rpc("authority", "call_local", "reliable")
func _quete_fin_rpc(texte: String, reussie: bool) -> void:
	quete_fin.emit(texte, reussie)


# ---------------------------------------------------------------- les bots, le jour

## Les bots votent pour la quête du jour : le premier jour toujours pour une quête (chacun veut
## un rôle), ensuite un sur six préfère rester. Ils penchent pour la quête à rôle. Certains vont
## lire le tableau avant.
func _bots_votes_quete() -> void:
	for id in _bots:
		if not partie.vivant(id):
			continue
		var b: Dictionary = _bots[id]
		if _rng.randf() < 0.5:
			b["but"] = "tableau"
			var a := _rng.randf() * TAU
			_aller(id, Ronde.TABLEAU + Vector3(sin(a), 0, cos(a)) * 2.0 - Ronde.TABLEAU.normalized() * 1.5, false)
		var delai := _rng.randf_range(2.0, maxf(3.0, durees["inscription"] - 2.0))
		get_tree().create_timer(delai, false).timeout.connect(func():
			if phase != "tableau" or not partie.vivant(id):
				return
			var k := _rng.randi_range(0, _quetes.size() - 1)
			for i in _quetes.size():
				if _quetes[i]["recompense"] == "role" and _rng.randf() < 0.5:
					k = i
			if jour_n > 1 and _rng.randf() < 0.17:
				k = Quetes.RESTER
			if _maire_actif() and id != partie.maire:
				k = Quetes.participation(k)
			if _bots.has(id):
				_bots[id]["but"] = "flane"
			traiter(id, "voter_quete", k))


## Le jour : regarder le plus proche, flâner sur la place, et pour le Vampire, mordre parfois.
func _bots_journee_tick(delta: float) -> void:
	for id in _bots:
		if not partie.vivant(id):
			continue
		var b: Dictionary = _bots[id]
		var proche := _plus_proche(id)
		if proche >= 0:
			b["regard"] = _position(proche) + Vector3(0, 1.6, 0)
			if partie.role(id) == "vampire" and partie.peut_mordre() and partie.nuit_n >= 1 and phase in ["tableau", "pret"] \
					and _position(proche).distance_to(b["pos"]) < PORTEE_MORSURE and _rng.randf() < 0.01:
				traiter(id, "mordre", proche)
		if b["mode"] != "libre" or not (b["chemin"] as Array).is_empty() or b["but"] in ["quete", "tableau"]:
			continue
		if not _quete_de(id).is_empty() and _quete_de(id)["etat"] in ["trajet", "role", "jeu", "retour"]:
			continue
		b["attente"] -= delta
		if b["attente"] > 0:
			continue
		b["but"] = "flane"
		var a := _rng.randf() * TAU
		if _rng.randf() < 0.5 and proche >= 0:
			_aller(id, _position(proche) + Vector3(sin(a), 0, cos(a)) * 1.6, false)
		else:
			_aller(id, Vector3(sin(a), 0, cos(a)) * _rng.randf_range(5.5, 9.5), false)
		b["attente"] = _rng.randf_range(4.0, 12.0)


# ================================================================ mode test (menu de triche, F10)
# Hors ligne seulement : l'hôte est seul avec des bots. Chaque commande rend "" ou la raison du refus.

## Les règles du jour qu'un jeu peut tirer, à ce niveau et pour cette équipe ("" = la règle de base).
func test_variantes(jeu: String, niveau: String, taille: int) -> Array:
	var faux := {"jeu": jeu, "niveau": niveau, "inscrits": []}
	var vues := {}
	var script: GDScript = load(Quetes.JEUX[jeu][2])
	for g in 80:
		var mj: MiniJeu = script.new()
		for k in taille:
			mj.ids.append(1000 + k)
			mj.noms[1000 + k] = "Essai %d" % k
		mj.niveau = faux["niveau"]
		mj.rng.seed = g
		mj.demarrer()
		vues[mj.variante] = true
	var l := vues.keys()
	l.sort()
	return l


## Lance tout de suite un mini-jeu, avec moi (si je suis vivant) et des bots, dans la première
## clairière. saboteur : "" personne, "bot" un bot, "moi" moi.
func test_jeu(jeu: String, niveau: String, variante: String, taille: int, saboteur: String) -> String:
	if partie == null or phase in ["salon", "fin"]:
		return "Lance d'abord la partie."
	for q in _quetes:
		if q["etat"] == "jeu":
			(q["mj"] as MiniJeu).fini = true
	_quetes.clear()
	_file_appels.clear()
	_appel = ""
	var ids: Array = []
	if partie.vivant(moi()):
		ids.append(moi())
	for id in _bots:
		if ids.size() >= taille:
			break
		if partie.vivant(id):
			ids.append(id)
	if ids.is_empty():
		return "Plus personne de vivant pour jouer."
	var sab: Array = []
	if saboteur == "moi" and ids.has(moi()):
		sab.append(moi())
	elif saboteur == "bot" and ids.size() > 1:
		sab.append(ids[ids.size() - 1])
	var q := {"jeu": jeu, "niveau": niveau, "recompense": "indice", "inscrits": ids, "etat": "trajet",
		"zone": 0, "mj": null, "t": 0.0, "reussie": false, "variante": variante, "saboteurs": sab}
	_quetes.append(q)
	_entrer("quete")
	# Tout le monde y est déjà : pas de marche jusqu'à la clairière.
	var centre := Quetes.zone(0)
	for k in ids.size():
		if _bots.has(ids[k]):
			_bots[ids[k]]["pos"] = centre + DecorQuete.poste(jeu, k, ids.size())
			_bots[ids[k]]["chemin"] = []
	_demarrer_quete(q)
	if not partie.vivant(moi()):
		_placer(moi(), centre + Vector3(0, 0, 3.0), centre, "fantome")
	return ""


## La quête en cours se termine maintenant (le résultat dépend de ce qui a été réussi).
func test_finir_quete() -> String:
	for q in _quetes:
		if q["etat"] == "jeu":
			(q["mj"] as MiniJeu).terminer()
			return ""
	return "Aucune quête en cours."


## Saute à une étape : "jour" (nouveau jour, tableau), "conseil", "vote", "nuit".
func test_etape(quoi: String) -> String:
	if partie == null or phase in ["salon", "fin"]:
		return "Lance d'abord la partie."
	if phase == "quete":
		_forcer_fin_quetes()
	_file_appels.clear()
	_appel = ""
	match quoi:
		"jour":
			_nouveau_jour()
		"conseil", "vote":
			_entrer(quoi)
		"nuit":
			_entrer("distribution")
	return ""


func test_role(r: String) -> String:
	if partie == null or phase in ["salon", "fin"]:
		return "Lance d'abord la partie."
	if not partie.vivant(moi()):
		return "Tu es mort : reviens d'abord à la vie."
	partie.donner_role(moi(), r, "", "mode test")
	_vider_evenements()
	_envoyer_pub(_etat_pub())
	_envoyer_prives()
	return ""


func test_mourir() -> String:
	if partie == null or phase in ["salon", "fin"]:
		return "Lance d'abord la partie."
	if not partie.vivant(moi()):
		return "Tu es déjà mort."
	partie._mourir(moi(), "chagrin")
	_vider_evenements()
	return ""


func test_revivre() -> String:
	if partie == null or phase in ["salon", "fin"]:
		return "Lance d'abord la partie."
	if partie.vivant(moi()):
		return "Tu es déjà vivant."
	partie.joueurs[moi()]["vivant"] = true
	_envoyer_pub(_etat_pub())
	_envoyer_prives()
	_placer(moi(), pres_souche(sieges[moi()]["maison"]), Vector3.ZERO, "libre")
	return ""
