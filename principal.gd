extends Node3D
## Nuit Blanche, vu par un joueur : première personne dans la Ronde. Tu vois les bouilles des
## autres, dont les yeux suivent ce que regarde vraiment la personne derrière sa webcam.
## Le meneur (enfant « Meneur ») décide de tout ; ici on affiche, on écoute, on obéit.
##
## Touches : ZQSD se déplacer · Maj courir (loup, la nuit) · souris regarder · E agir ·
##           F pouvoir · flèches/Espace combo du loup · clic voter · M miroir · Échap menu.

const EXPR := [
	"eyeBlinkLeft", "eyeBlinkRight", "eyeSquintLeft", "eyeSquintRight",
	"eyeWideLeft", "eyeWideRight", "jawOpen", "mouthSmileLeft", "mouthSmileRight",
	"mouthFrownLeft", "mouthFrownRight", "mouthPucker", "cheekPuff",
	"browDownLeft", "browDownRight", "browInnerUp", "browOuterUpLeft", "browOuterUpRight",
	"mouthFunnel", "tongueOut", "mouthLeft", "mouthRight", "noseSneerLeft", "noseSneerRight",
]
const HAUTEUR_YEUX := 1.6
const BAISSE_ASSIS := 0.5   # les yeux descendent quand on s'assoit sur le rondin
const VITESSE := 3.2
## Sprint (Maj) : on court ~5 s, puis on s'essouffle et on halète (les autres l'entendent).
const SPRINT := 1.55
const SOUFFLE_PERTE := 0.2
const SOUFFLE_REPRISE := 0.12
const SAUT := 4.6
const SENSIBILITE := 0.0025
const ENVOIS_PAR_S := 20.0
const SEUIL_VOIX_FORTE := 0.12
## Trois façons de parler (décision d'Edwin, 29/10) : on n'est entendu qu'à cette distance.
const PORTEES_VOIX := [2.0, 8.0, 15.0]
const NOMS_PORTEE := ["Chuchoter", "Parler", "Crier"]
## Ce qu'affiche le voyant en jeu (Edwin, 30/10 : « chuchote », « parle », « crie » plutôt que « Voix »).
const VOYANT_PORTEE := ["Chuchote", "Parle", "Crie"]
const VERT_VOIX := Color(0.35, 0.95, 0.45)
const GRIS_VOIX := Color(1, 1, 1, 0.28)
## Au Conseil, tout le monde s'entend (la voix reste placée, pour savoir qui parle).
const PHASES_TOUS_ENTENDUS := ["salon", "fin", "annonce", "conseil", "vote", "depouillement", "tranche", "verdict", "election", "vote_maire", "elu", "trappeur", "successeur"]
const PORTEE_CONSEIL := 60.0
const NOMS_APPELS := {"coucher": "Tout le monde se couche", "entremetteuse": "L'Entremetteuse", "enfant": "L'Enfant sauvage",
	"veilleur": "Le Veilleur", "liseuse": "La Liseuse d'âmes", "loups": "Les loups", "solitaire": "Le Loup solitaire",
	"herboriste": "L'Herboriste", "cinematique": "La pierre"}
const DUREE_CINE := Cinematique.DUREE
const NOMS_PHASES := {"salon": "Le salon", "distribution": "La nuit tombe", "nuit": "La nuit", "aube": "L'aube",
	"annonce": "L'aube", "trappeur": "Le Trappeur", "conseil": "Le Conseil",
	"vote": "Le vote", "depouillement": "Le dépouillement", "tranche": "Le maire tranche", "verdict": "Le verdict", "fin": "Fin de la partie", "choix_maire": "Le vote de la quête",
	"tableau": "Le vote de la quête", "quete": "Les quêtes", "pret": "Le retour au village",
	"election": "L'élection du maire", "vote_maire": "Le vote du maire", "elu": "Le maire", "successeur": "Le successeur"}
const PHASES_CONSEIL := ["annonce", "conseil", "vote", "depouillement", "tranche", "election", "vote_maire", "elu"]
const PHASES_VOTE := ["vote", "vote_maire"]
const SONS_BRUITS := {"gravier": "gravier", "craquement": "craquement", "clapotis": "clapotis",
	"froissement": "froissement", "poignee": "poignee", "cloche": "cloche",
	"porte_leger": "porte_coup", "porte": "porte_coup", "porte_fort": "porte_coup"}
## Les bruits métalliques ou secs ont leur aigu : en 3D on coupe le filtre à 5 kHz que Godot met par défaut
## (il étouffait de 12 dB un loquet, des chaînes, un caillou).
const SONS_NETS := ["poignee", "chaines", "caillou", "gravier", "porte", "porte_ferme", "porte_coup"]
## Le volume d'une porte de loup selon ses trois coups (2, 1 ou 0 réussis).
const VOLUME_PORTE := {"porte_leger": -14.0, "porte": -3.0, "porte_fort": 7.0}
const SORTE_DU_SOL := {"graviers": "gravier", "planches": "craquement", "flaques": "clapotis", "feuilles": "froissement"}

var ronde: Ronde
var _ronde_n := 12            # le nombre de maisons du village construit
var meneur: Meneur
var ecran: EcranJeu
var corps_joueur: CharacterBody3D
var tete: Node3D
var camera: Camera3D
var moi: Bouille
var bouilles := {}      # id -> Bouille (tous les autres : humains et bots)
var _etats := {}        # id humain distant -> TamponEtats (cf. tampon_etats.gd)
## « Ma tête » : ma photo [octets, repères], affichée ou non ; celles des autres, reçues
## seulement dans un lobby privé (cf. MaTete).
var _ma_tete: Array = []
var _tete_on := false
var _prive := false
var _tetes := {}        # id -> [octets, repères]
var _recus := {}        # id -> états reçus depuis la dernière mesure (diagnostic F3)
var _diag: Label
var _diag_t := 0.0
var _recus_t := 0
var _panneau_emotes: PanelContainer
var _panneau_volumes: PanelContainer
var _liste_volumes: VBoxContainer
var _voyants := {}            # id -> Label (s'allume quand ce joueur parle)
var _icone_voix: Button
var _dedans := 0.0            # 0 dehors, 1 dans une maison porte fermée (le son s'étouffe)
var _filtre_dedans: AudioEffectLowPassFilter
var _gain_dedans: AudioEffectAmplify
var _assis_libre := false     # assis de soi-même, sur une souche ou au bord du lit
var _yeux := Vector3.ZERO     # décalage lissé de la caméra vers la tête du corps
var _yaw_siege := 0.0         # assis : le regard reste vers la scène (souche) ou le corps ne tourne pas (lit)
var _sur_lit := false
var _alt_souris := false      # Alt tenu : la souris apparaît pour cliquer (volumes des voix…)
var _marcheurs := {}          # id -> Marcheur (suivi des pas ; 0 = moi)
var _pas_n := 0
var _panneau_role: PanelContainer
var _texte_role: Label
var _pause_joueurs: VBoxContainer
var _panneau_excl: PanneauExclusion      # la fenêtre du vote d'exclusion
var _excl_etat := {}                     # le vote en cours, tel que l'hôte l'a publié
var _excl_confirmer := -1                # le joueur dont j'ai cliqué « Exclure » : on attend ma confirmation
var _sig_liste := ""                     # ce que la liste des joueurs affiche : on ne la refait que si ça change
var _humains := {}      # id -> {nom, apparence} (présentations reçues)

# Profil
var mon_nom := "Joueur"
var mon_apparence := 0
var _emotes_dispo: Array = []   # les gestes de la liste G : ceux d'origine et ceux qu'on a achetés
var _vivants_vus := {}      # id -> vivant à la dernière image (pour jouer la mort achetée une fois)

# Interface hors jeu (accueil, réglage, luciole)
var _ui: CanvasLayer
var _ui_nuit: CanvasLayer
var _voile: ColorRect
var _voile_mat: ShaderMaterial
var _texte_nuit: Label
var _miroir: SubViewportContainer
var _cam_miroir: Camera3D
var _menu: Menu
var _cam_menu: Camera3D
var _boutique := false          # l'onglet Cosmétique est ouvert : la caméra est à la roulotte
var _essai: Bouille             # le personnage devant le miroir, qui essaie
var _essai_article := ""
var _essai_t := 0.0
var _essai_extra: Node3D        # une tombe posée à côté, pour l'essayer
var _maison_essai := -1
var _menu_angle := 0.0
var _lobby := {}                  # le lobby que j'héberge : nom, langue, public
var _code := ""                   # le code du lobby où je suis (hôte ou invité)
var _code_cherche := ""           # code demandé, en attente de réponse
var _reglage_origine := "entree"  # d'où on arrive au réglage du regard : entree, menu, pause
static var message_retour := ""
var _trace_reseau := "--trace-reseau" in OS.get_cmdline_user_args()   # mesure du retard (même PC)
var _trace_ages: Array[float] = []
var _trace_t := 0.0   # affiché au menu après être sorti d'une partie
var _panneau_reglage: PanelContainer
var _etat_camera_reglage: Label
var _spin_pouces: SpinBox
var _note_pouces: Label
var _spin_distance: SpinBox
var _mesure_distance: Label
var _bouton_luciole: Button
var _bouton_garder: Button
var _luciole: Luciole
var _panneau_resultat: PanelContainer
var _texte_resultat: Label
var _panneau_pause: PanelContainer
var _panneau_options_jeu: PanelContainer
var _reglages_jeu: PanneauReglages

# État local
var etape := "accueil"   # accueil, reglage, luciole, verif, resultat, jeu, pause
var mode := "libre"      # libre, fige, assis, poste, fantome, guide (marche automatique)
## Marche guidée vers la place d'une étape : chemin restant, [pos, regard, mode] à l'arrivée.
var _guide: Array[Vector3] = []
var _guide_fin: Array = []
var _guide_t := 0.0
var _souris_guide_t := -100.0         # quand la souris a bougé pour la dernière fois pendant la marche guidée
var _guide_bloque := 0.0
var _guide_mieux := INF        # la plus courte distance atteinte au prochain point
var _guide_recalcule := false
var _guide_ecarts := 0         # pas de côté déjà tentés
var _guide_portes: Array[Dictionary] = []   # les portes que la marche franchit (cf. Trajets.portes_a_franchir)
var _guide_porte_attente := 0.0             # depuis combien de temps on attend devant une porte
var _guide_porte_demande := -1.0            # la dernière fois qu'on a poussé la porte (temps de marche)
const GUIDE_MIN := 1.5          # plus près que ça, on pose sans marcher
const GUIDE_VITESSE := 1.5      # × VITESSE : un pas pressé, pas une course
const GUIDE_COURSE := 2.0       # × VITESSE : au soir, on court jusqu'à sa maison
const GUIDE_MAX := 25.0         # au-delà (coincé quelque part), on pose quand même
var _guide_max := GUIDE_MAX
var _guide_traverse := false   # marche guidée d'une quête : on ne bute sur rien
var _souffle := 1.0      # sprint : 1 = plein, 0 = à bout
var _essouffle := false
var _accroupi := false              # Ctrl tenu : je suis accroupi
var _acc_verrou := false            # une animation m'a relevé : debout jusqu'à ce que Ctrl soit relâché
var _acc_k := 0.0                   # 0 debout, 1 accroupi (la caméra descend en douceur)
var _espace_avant := false
var _ancre := Vector3.ZERO
var nuit := 0.0
var _noir := false
var _t := 0.0
var _envoi_t := 0.0
var _regard_monde := Vector3.ZERO
## Le point que les yeux de l'avatar regardent : _regard_monde, plus les petites saccades de celui
## qui n'a pas de webcam (nulles avec une webcam). C'est lui qui part sur le réseau.
var _regard_vu := Vector3.ZERO
var _vise_bouille := -1
## Carnets et pages : ce qu'on voit, et la feuille qu'on lit (L).
var _vue_objets: VueObjets
var _carnet: PanneauCarnet
var _indic_carnet: Label           # « Clic gauche : ouvrir · Clic droit : écrire », quand on tient un carnet ou une page
var _slot_vide_sel := -1                        # dernière case choisie : sert quand la main est vide, -1 : aucune
var _inventaire: InventaireUI                 # les 4 emplacements, l'aide souris, la visée et les coups reçus
var _vise_caillou_t := -1.0                   # depuis quand je maintiens le clic gauche pour viser (-1 : non)
var _courbe_visee: MeshInstance3D             # la courbe du caillou pendant que je vise
var _plume_t := 0.0                           # reste de temps où mon stylo écrit
var _plume_envoyee := false
var _vise_t := 0.0
var _vote_cible := -1
var _combo: Combo = null
var _pas_combo := 0.0
var _rng := RandomNumberGenerator.new()
var _lecture_t := 0.0
var _lecture_maison := -1
var _risque := 0.0
var _repere := false
var _tache_t := 0.0
var _tache_poste := ""
var _tache_sabotage := false
var _traces_nuit: Array[Vector3] = []
var _traces: Array[Node3D] = []
var _marques := {}
var _vue_quete: VueQuete
## La quête jouée dans le décor de la clairière (VueQuete ne sert plus qu'aux touches).
var _monde_quete: MondeQuete
var _choix_maire: Array = []     # (ancien choix du maire : plus utilisé)
var _mon_vote_quete := -1        # mon choix au vote du matin (0..2, Quetes.RESTER), -1 : aucun
var _vote_participation := false # il y a un maire et ce n'est pas moi : « Participer / Ne pas participer »
var _auto_jeu := false
var _fils := {}         # votant -> MeshInstance3D
## Le vote est secret (décision d'Edwin, 29/10) : une petite tête de mort (ou une couronne, pour
## le maire) flotte au-dessus de celui que J'ACCUSE, visible de moi seul.
var _marque_vote: Node3D = null
var _marque_couronne: Node3D = null   # élection : la flèche VERTE de mon vote posé
var _fleche_grise: Node3D = null      # élection : la flèche GRISE sur celui que je vise
var _voix_affichees := {}  # id -> Label3D du dépouillement
var _lanterne: OmniLight3D
var _brouillage := {}   # id -> [décalage, temps]
var _capture := ""
var _capture_t := -1.0
var _auto := false
## Mode test (F10) : le menu de triche, hors ligne seulement (menu « Mode test », ou --test).
var _mode_test := false
var _tuto: Tutoriel = null   # la nuit guidée du premier lancement, tant qu'elle se joue
var _panneau_test: PanneauTest
var _sur_le_champ := false
var _derniere_phase := ""
var _rapide_en_partie := 0.0   # essais : accélération appliquée tant qu'on n'est pas au salon (--rapide-en-partie=N)
var _rejouer_restant := 0      # essais : combien de fois l'hôte relance après la fin (--rejouer=N)
var _finir_apres := -1.0       # essais (--finir-apres=S) : l'hôte arrête chaque partie S s après son lancement
var _partie_t := 0.0
var _trace_pas := "--trace-pas" in OS.get_cmdline_user_args()
var _stat_pas_d := {}
func _stat_pas(cle: String) -> void:
	_stat_pas_d[cle] = int(_stat_pas_d.get(cle, 0)) + 1
var _trace_fantome := "--trace-fantome" in OS.get_cmdline_user_args()
var _trace_pubs := "--trace-pubs" in OS.get_cmdline_user_args()
var _dernier_appel := ""
var _voix_meneur := ""        # la dernière phrase du meneur, affichée aux dormeurs
var _vote_maison := -1        # la maison que je vise à la pierre
## La nuit dans sa chambre (décisions d'Edwin, 29/10).
var _oreille := false         # l'oreille collée au mur : on entend mieux dehors
var _rideau_o := 0.0          # la Petite fille écarte son rideau (0 → 1)
var _rideau_cote := 1
var _rideau_envoye := 0.0
var _sortie: Control = null   # les trois coups pour sortir sans bruit (loups)
var _sortie_t := 0.0
var _sortie_coups: Array[bool] = []
var _reussite: PanneauReussite = null
var _aide_portee: Label = null   # « C : changer de mode », cachée quand la portée ne se change pas
var _ma_portee := 1           # 0 chuchoter, 1 parler, 2 crier
var _fils_loups := {}         # loup -> fil rouge vers sa maison votée
var _morsure_t := 0.0
var _cine_t := -1.0
var _cine: Cinematique
var _cine_victimes := 0

# Sons
var _vent: AudioStreamPlayer
var _grillons: AudioStreamPlayer
var _coeur_t := 0.0


func _ready() -> void:
	# Le menu pause d'un entraînement fige le jeu (get_tree().paused) : la scène principale, elle, doit
	# continuer de recevoir Échap et de faire vivre ses menus ; le monde et le meneur, eux, se figent.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	mon_nom = _lire_reglage("nom", mon_nom)
	mon_apparence = _lire_reglage("apparence", mon_apparence)
	if mon_apparence == 0:
		mon_apparence = Bouille.au_hasard(_rng)
		_ecrire_reglage("apparence", mon_apparence)
	ronde = Ronde.new()
	# Au lancement, l'écran de démarrage est là : le village s'y construit par étapes, la barre avance.
	# Le reste de la scène attend qu'il soit fini (ni image, ni physique, ni touche entre-temps).
	ronde.par_etapes = MiseAJour.ecran_ouvert()
	add_child(ronde)
	if not ronde.construite:
		set_process(false)
		set_physics_process(false)
		set_process_unhandled_input(false)
		ronde.avance.connect(MiseAJour.chargement)
		await ronde.construit
		set_process(true)
		set_physics_process(true)
		set_process_unhandled_input(true)
	MiseAJour.village_pret()
	meneur = Meneur.new()
	meneur.name = "Meneur"
	add_child(meneur)
	meneur.position_humain = _position_humain
	_creer_joueur()
	_construire_ui()
	_creer_sons()
	_brancher_meneur()
	_creer_frissons()
	multiplayer.peer_connected.connect(_pair_arrive)
	multiplayer.peer_disconnected.connect(_pair_parti)
	multiplayer.server_disconnected.connect(_hote_parti)
	Reseau.adresses_pretes.connect(_sur_adresses)
	Reseau.connexion_ratee.connect(_sur_connexion_ratee)
	Reseau.connexion_ok.connect(_sur_connexion_ok)
	Plateforme.rejoindre_demande.connect(_rejoindre_ami_steam)
	Lobbies.code_reserve.connect(_sur_code_reserve)
	Lobbies.code_trouve.connect(_sur_code_trouve)
	Capteur.etat_change.connect(func(_e): _maj_etat())
	_maj_etat()
	_aller("accueil")
	if message_retour != "":
		_menu.info(message_retour)
		message_retour = ""
	_lire_arguments()
	# Tout premier lancement : on propose la nuit guidée (jamais pendant un essai en ligne de commande).
	if TutoEtapes.a_proposer(str(_lire_reglage("tutoriel", ""))) and OS.get_cmdline_user_args().is_empty():
		_proposer_nuit_guidee()


static var _arguments_lus := false   # la scène est rechargée au retour au menu : une seule lecture


func _lire_arguments() -> void:
	if _arguments_lus:
		return
	_arguments_lus = true
	var sauter := false
	var lancer := false
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--port="):
			Reseau.port = a.substr(7).to_int()
	for a in OS.get_cmdline_user_args():
		if a == "--souris":
			Capteur.activer_souris(true)
		elif a.begins_with("--nom="):
			mon_nom = a.substr(6)
		elif a == "--bots":
			meneur.avec_bots = true
		elif a == "--heberger":
			Reseau.heberger()
		elif a.begins_with("--rejoindre="):
			Reseau.rejoindre(a.substr(12))
		elif a == "--jeu":
			sauter = true
		elif a == "--test":
			_mode_test = true
		elif a == "--tutoriel":
			_lancer_tutoriel.call_deferred()   # essais : directement la nuit guidée
		elif a == "--lancer":
			lancer = true
		elif a == "--auto":
			_auto = true
			_frissons.journal = true
		elif a.begins_with("--places="):
			# Essais : le nombre de joueurs (bots compris), 6 à 16.
			meneur.max_places = 16
			meneur.nb_places = clampi(a.substr(9).to_int(), 6, 16)
			meneur.nb_loups = clampi(meneur.nb_places / 4, 1, 4)
		elif a.begins_with("--rapide="):
			Engine.time_scale = a.substr(9).to_float()
			Engine.physics_ticks_per_second = int(60 * Engine.time_scale)
		elif a.begins_with("--rapide-en-partie="):
			# Essais à deux jeux : le temps ne s'accélère qu'une fois la partie lancée (la synchro du
			# lancement, elle, se compte en secondes de jeu et laisserait trop peu de temps à l'invité).
			_rapide_en_partie = a.substr(19).to_float()
		elif a.begins_with("--decouverte=") or a.begins_with("--inscription="):
			meneur.durees["inscription"] = a.get_slice("=", 1).to_float()
		elif a.begins_with("--essai-transfo="):
			_essai_transfo = a.substr(16)
		elif a.begins_with("--apparence="):
			mon_apparence = a.substr(12).to_int()
		elif a.begins_with("--capture="):
			_capture = a.substr(10)
			_capture_t = maxf(_capture_t, 2.5)
		elif a.begins_with("--fin-essai="):
			_essai_fin_lancer.call_deferred(a.substr(12))
		elif a.begins_with("--menu="):
			_menu.ecran(a.substr(7).get_slice("/", 0))   # --menu=options/vocal : une page des réglages
			if a.begins_with("--menu=regles/"):
				_menu._afficher_regle(a.get_slice("/", 1).to_int())   # --menu=regles/5 : une page de « Comment jouer »
			elif "/" in a:
				_menu.page_reglages(a.get_slice("/", 1))
		elif a.begins_with("--creer="):
			_creer_lobby(a.substr(8), "fr", true, "--bots" in args, "--perso" in args)
		elif a.begins_with("--code="):
			_rejoindre_code(a.substr(7))
		elif a.begins_with("--lancer-apres="):
			get_tree().create_timer(a.substr(15).to_float()).timeout.connect(func(): meneur.lancer_partie())
		elif a.begins_with("--tchat="):
			# Essais : écrit ce message au tchat du lobby 3 s après le lancement (a=texte ; | sépare plusieurs messages).
			var morceaux := a.substr(8).split("|")
			for k in morceaux.size():
				get_tree().create_timer(3.0 + k * 1.0).timeout.connect(func(): meneur.tchat_envoyer.rpc_id(1, morceaux[k]))
		elif a == "--voix-factice":
			# Essais : sans micro, parle toutes les 0,2 s (un son pur) et écrit qui il entend à quel niveau.
			var minuterie := Timer.new()
			minuterie.wait_time = 0.25
			minuterie.autostart = true
			add_child(minuterie)
			minuterie.timeout.connect(func():
				if etape != "jeu" or _phase() == "salon" or not Voix.en_partie():
					return
				var echantillons := PackedFloat32Array()
				for k in 320:
					echantillons.append(0.4 * sin(k * 0.3))
				meneur.voix_envoyer(CodecVoix.encoder(echantillons), 0.4)
				var entendus := []
				for hid in _humains:
					if hid != _moi_id() and Voix.niveau(hid) > 0.0:
						entendus.append(hid)
				if _auto and int(_t) % 20 == 0:
					print("[voix] phase=%s je suis %s, j'entends %s" % [_phase(), "vivant" if _vivant() else "mort", entendus]))
		elif a.begins_with("--vote-factice="):
			# Essais (captures) : affiche la fenêtre du vote d'exclusion, contre le premier autre joueur du village.
			get_tree().create_timer(a.substr(15).to_float()).timeout.connect(func():
				var ids: Array = (meneur.pub.get("sieges", {}) as Dictionary).keys().filter(func(i): return i != _moi_id())
				if ids.size() >= 2:
					_sur_exclusion({"cible": ids[0], "demandeur": ids[1], "reste": 24.0, "electeurs": [_moi_id(), ids[1], ids[2]],
						"a_vote": [ids[1]], "oui": 1, "non": 0, "besoin": 2}))
		elif a.begins_with("--exclure-apres="):
			# Essais (hôte) : exclut le premier invité après ce délai (secondes).
			get_tree().create_timer(a.substr(16).to_float()).timeout.connect(func():
				for hid: int in meneur.humains:
					if hid != 1:
						print("[exclusion] l'hôte exclut ", hid)
						_envoyer_intention("exclure", hid)
						break)
		elif a.begins_with("--demander-exclusion="):
			# Essais (invité) : demande un vote contre le premier autre invité après ce délai.
			get_tree().create_timer(a.substr(21).to_float()).timeout.connect(func():
				var autres := _humains.keys().filter(func(hid): return hid != _moi_id() and hid != 1)
				autres.sort()
				if not autres.is_empty():
					print("[exclusion] je demande l'exclusion de ", autres[0])
					_envoyer_intention("exclusion_demande", autres[0]))
		elif a.begins_with("--mourir-apres="):
			# Essais (hôte) : on se tue après ce délai, dès que la partie est lancée (pour éprouver le fantôme).
			var delai_mort := a.substr(15).to_float()
			get_tree().create_timer(delai_mort).timeout.connect(func():
				while meneur.partie == null or _phase() in ["salon", "fin"]:
					await get_tree().create_timer(1.0).timeout
				print("[mort-essai] ", meneur.test_mourir()))
		elif a.begins_with("--tuer-invite-apres="):
			# Essais (hôte) : tue le premier invité après ce délai, dès que la partie est lancée.
			get_tree().create_timer(a.substr(20).to_float()).timeout.connect(func():
				while meneur.partie == null or _phase() in ["salon", "fin"]:
					await get_tree().create_timer(1.0).timeout
				for hid: int in meneur.humains:
					if hid != 1 and meneur.partie.vivant(hid):
						meneur.partie._mourir(hid, "chagrin")
						meneur._vider_evenements()
						print("[mort-essai] invité ", hid, " tué")
						break)
		elif a.begins_with("--rejouer="):
			_rejouer_restant = a.substr(10).to_int()
		elif a.begins_with("--finir-apres="):
			_finir_apres = a.substr(14).to_float()
		elif a.begins_with("--retour-menu="):
			get_tree().create_timer(a.substr(14).to_float()).timeout.connect(_quitter_partie)
		elif a.begins_with("--delai="):
			_capture_t = a.substr(8).to_float()
	if sauter and _code_cherche == "":
		_appliquer_profil()
		_aller("jeu")
		if lancer and meneur.est_hote():
			meneur.lancer_partie()


# ================================================================ joueur et présence

func _creer_joueur() -> void:
	corps_joueur = CharacterBody3D.new()
	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	forme.shape = capsule
	forme.position.y = 0.875
	corps_joueur.add_child(forme)
	corps_joueur.position = Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(5, 8))
	add_child(corps_joueur)
	# Sans les couches des portes, le masque par défaut (1) laissait traverser toute porte fermée tant
	# qu'aucun placement n'avait reposé le masque — au salon, et pour qui n'était jamais placé (30/10).
	corps_joueur.collision_mask = _masque_corps()
	tete = Node3D.new()
	tete.position = Vector3(0, HAUTEUR_YEUX, -0.1)   # au niveau des yeux, un peu devant le cou : on voit son buste en baissant la tête
	corps_joueur.add_child(tete)
	camera = Camera3D.new()
	camera.fov = float(Options.valeur("graphisme/champ"))
	camera.near = 0.05
	camera.far = 160
	camera.cull_mask = 0xFFFFF & ~(1 << 1)  # sans la couche 2 : ta propre tête (le reste de ton corps se voit)
	tete.add_child(camera)
	moi = Bouille.new()
	moi.rotation.y = PI
	corps_joueur.add_child(moi)
	moi.vue_interieure(2)
	_lanterne = OmniLight3D.new()
	_lanterne.light_color = Color(1.0, 0.7, 0.35)
	_lanterne.omni_range = 7.0
	_lanterne.light_energy = 1.4
	_lanterne.shadow_enabled = true
	_lanterne.position = Vector3(0.4, 1.0, -0.3)
	_lanterne.visible = false
	corps_joueur.add_child(_lanterne)

	_miroir = SubViewportContainer.new()
	_miroir.stretch = true
	_miroir.custom_minimum_size = Vector2(260, 260)
	_miroir.visible = false
	var vue := SubViewport.new()
	vue.size = Vector2i(260, 260)
	_miroir.add_child(vue)
	_cam_miroir = Camera3D.new()
	_cam_miroir.fov = 40
	vue.add_child(_cam_miroir)


func _appliquer_profil() -> void:
	moi.queue_free()
	moi = Bouille.new()
	moi.apparence = Bouille.decoder(mon_apparence)
	moi.rotation.y = PI
	corps_joueur.add_child(moi)
	moi.vue_interieure(2)
	var id := multiplayer.get_unique_id()
	_humains[id] = {"nom": mon_nom, "apparence": mon_apparence}
	if meneur.est_hote():
		meneur.joueur_arrive(id, mon_nom, mon_apparence)
	if _tete_on and _ma_tete.size() == 2:
		moi.poser_photo(_ma_tete[0], _ma_tete[1])
	if Reseau.en_ligne and _connecte():
		_presenter.rpc(mon_nom, mon_apparence)
		_envoyer_ma_tete(0)


func _connecte() -> bool:
	return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _moi_id() -> int:
	return multiplayer.get_unique_id()


func _position_humain(id: int) -> Vector3:
	if id == _moi_id():
		return corps_joueur.global_position
	if _etats.has(id) and not (_etats[id] as TamponEtats).vide():
		return (_etats[id] as TamponEtats).echantillon(_horloge()).get("pos", Vector3.ZERO)
	return Vector3.ZERO


## Horloge locale des états (secondes, monotone) : seule la différence entre deux PC compte.
func _horloge() -> float:
	return Time.get_ticks_usec() / 1000000.0


func _hote_parti() -> void:
	for id in bouilles.keys():
		_retirer_bouille(id)
	_etats.clear()
	_retour_menu("L'hôte a quitté la partie.")


func _pair_arrive(id: int) -> void:
	if meneur.est_hote() and meneur.identite_exclue(Reseau.identite(id)):
		meneur.refuser_exclu(id)   # exclu de ce lobby : il ne revient pas
		return
	if meneur.est_hote():
		_lobby_prive.rpc_id(id, _prive)
	if etape == "jeu" or etape == "pause":
		_presenter.rpc_id(id, mon_nom, mon_apparence)
		_envoyer_ma_tete(id)


## L'hôte dit aux arrivants si le lobby est privé : c'est la seule condition pour échanger les photos.
@rpc("authority", "call_remote", "reliable")
func _lobby_prive(oui: bool) -> void:
	_prive = oui
	if oui:
		_envoyer_ma_tete(0)


## Ma photo aux autres (id 0 : à tous) — seulement dans un lobby privé, et si je l'ai activée.
func _envoyer_ma_tete(id: int) -> void:
	if not (Reseau.en_ligne and _connecte() and _prive):
		return
	var octets := PackedByteArray()
	var reperes := {}
	if _tete_on and _ma_tete.size() == 2:
		octets = _ma_tete[0]
		reperes = _ma_tete[1]
	if id == 0:
		_ma_tete_rpc.rpc(octets, reperes)
	else:
		_ma_tete_rpc.rpc_id(id, octets, reperes)


@rpc("any_peer", "call_remote", "reliable")
func _ma_tete_rpc(octets: PackedByteArray, reperes: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not _prive or octets.size() > MaTete.TAILLE_MAX:
		return
	if octets.is_empty():
		_tetes.erase(id)
		if bouilles.has(id):
			(bouilles[id] as Bouille).retirer_photo()
		return
	_tetes[id] = [octets, reperes]
	if bouilles.has(id):
		(bouilles[id] as Bouille).poser_photo(octets, reperes)


func _sur_photo(octets: PackedByteArray, reperes: Dictionary) -> void:
	if not MaTete.reperes_valides(reperes) or MaTete.image(octets) == null:
		_menu.regler_tete(_ma_tete, _tete_on, "Photo ratée : recommence, bien en face de la caméra.")
		return
	MaTete.enregistrer(octets, reperes)
	_ma_tete = [octets, reperes]
	_regler_tete(true)
	_menu.regler_tete(_ma_tete, true, "Photo prise ✓  Elle reste sur ton PC.")


func _regler_tete(oui: bool) -> void:
	_tete_on = oui and _ma_tete.size() == 2
	_ecrire_reglage("ma_tete", _tete_on)
	if is_instance_valid(moi):
		if _tete_on:
			moi.poser_photo(_ma_tete[0], _ma_tete[1])
		else:
			moi.retirer_photo()
	_envoyer_ma_tete(0)


func _pair_parti(id: int) -> void:
	if "--trace-pubs" in OS.get_cmdline_user_args():
		print("[pair parti] ", id, " t=", _t)
	_etats.erase(id)
	_recus.erase(id)
	_tetes.erase(id)
	_humains.erase(id)
	Voix.oublier(id)
	if meneur.est_hote():
		meneur.joueur_parti(id)
	if bouilles.has(id) and not _est_siege(id):
		_retirer_bouille(id)


@rpc("any_peer", "call_remote", "reliable")
func _presenter(nom: String, apparence: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if meneur.est_hote() and meneur.est_refuse(id):
		return
	# Lobby complet (12 en public, 16 en privé) : on le dit au nouveau venu, qui repart au menu.
	if meneur.est_hote() and meneur.phase == "salon" and meneur.humains.size() >= meneur.max_places:
		_lobby_complet.rpc_id(id, meneur.max_places)
		return
	_humains[id] = {"nom": nom, "apparence": apparence}
	if meneur.est_hote():
		meneur.joueur_arrive(id, nom, apparence)
	_assurer_bouille(id, nom, apparence)


@rpc("authority", "call_remote", "reliable")
func _lobby_complet(n: int) -> void:
	_retour_menu("Ce lobby est complet (%d joueurs)." % n)


## Mon état part à tous le jour ; la nuit, ou si je suis mort, il passe par l'hôte, qui ne le donne qu'à ceux
## qui ont le droit de me voir (cf. Visibilite) : un client ne reçoit jamais la position de qui il ne voit pas.
func _par_l_hote() -> bool:
	return _phase() == "nuit" or not _vivant()


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)   # canal à part (cf. Voix.CANAL)
func _etat(pos: Vector3, yaw: float, pitch: float, expr: PackedFloat32Array, tete_v: Vector3, regard: Vector3, corps_v: PackedFloat32Array,
		mains_v: PackedFloat32Array, t_envoi: float) -> void:
	# Un état « pour tous » qui arrive pendant la nuit est en retard sur le changement de phase : on le jette.
	if _phase() == "nuit":
		return
	_recevoir_etat(multiplayer.get_remote_sender_id(), pos, yaw, pitch, expr, tete_v, regard, corps_v, mains_v, t_envoi)


## Hôte : un état envoyé par un joueur de la nuit (ou un mort), à relayer aux seuls destinataires permis.
@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _etat_vers_hote(pos: Vector3, yaw: float, pitch: float, expr: PackedFloat32Array, tete_v: Vector3, regard: Vector3, corps_v: PackedFloat32Array,
		mains_v: PackedFloat32Array, t_envoi: float) -> void:
	if not meneur.est_hote():
		return
	_relayer_etat(multiplayer.get_remote_sender_id(), pos, yaw, pitch, expr, tete_v, regard, corps_v, mains_v, t_envoi)


func _relayer_etat(origine: int, pos: Vector3, yaw: float, pitch: float, expr: PackedFloat32Array, tete_v: Vector3, regard: Vector3,
		corps_v: PackedFloat32Array, mains_v: PackedFloat32Array, t_envoi: float) -> void:
	# L'hôte sait tout : il garde toujours l'état.
	if origine != _moi_id():
		_recevoir_etat(origine, pos, yaw, pitch, expr, tete_v, regard, corps_v, mains_v, t_envoi)
	for dest in meneur.destinataires_position(origine):
		if dest != _moi_id():
			_etat_relai.rpc_id(dest, origine, pos, yaw, pitch, expr, tete_v, regard, corps_v, mains_v, t_envoi)


## L'état d'un autre joueur, relayé par l'hôte : l'hôte seul peut en être l'émetteur.
@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _etat_relai(origine: int, pos: Vector3, yaw: float, pitch: float, expr: PackedFloat32Array, tete_v: Vector3, regard: Vector3,
		corps_v: PackedFloat32Array, mains_v: PackedFloat32Array, t_envoi: float) -> void:
	_recevoir_etat(origine, pos, yaw, pitch, expr, tete_v, regard, corps_v, mains_v, t_envoi)


func _recevoir_etat(id: int, pos: Vector3, yaw: float, pitch: float, expr: PackedFloat32Array, tete_v: Vector3, regard: Vector3,
		corps_v: PackedFloat32Array, mains_v: PackedFloat32Array, t_envoi: float) -> void:
	if not _etats.has(id):
		_etats[id] = TamponEtats.new()
	var tampon: TamponEtats = _etats[id]
	var maintenant := _horloge()
	if not tampon.ajouter(t_envoi, maintenant, {"pos": pos, "yaw": yaw, "pitch": pitch, "expr": expr, "tete": tete_v,
			"regard": regard, "corps": corps_v, "mains": mains_v}):
		return
	_recus[id] = int(_recus.get(id, 0)) + 1
	if _trace_reseau:
		_trace_ages.append(tampon.gigue())


func _envoyer() -> void:
	if not Reseau.en_ligne or not _connecte():
		return
	var expr := PackedFloat32Array()
	for n in EXPR:
		expr.append(Capteur.expression(n))
	var tv := Vector3(Capteur.tx - Regard.neutre_tx, (Capteur.ty - Regard.neutre_ty) * 2.5, Capteur.roulis)
	if _par_l_hote():
		if meneur.est_hote():
			_relayer_etat(_moi_id(), corps_joueur.global_position, corps_joueur.rotation.y, tete.rotation.x, expr, tv, _regard_vu,
				Capteur.corps, Capteur.mains, _horloge())
		else:
			_etat_vers_hote.rpc_id(1, corps_joueur.global_position, corps_joueur.rotation.y, tete.rotation.x, expr, tv, _regard_vu,
				Capteur.corps, Capteur.mains, _horloge())
		return
	_etat.rpc(corps_joueur.global_position, corps_joueur.rotation.y, tete.rotation.x, expr, tv, _regard_vu, Capteur.corps,
		Capteur.mains, _horloge())


## F3 : ce que voit le réseau (ping, pertes, régularité des paquets, images par seconde).
func _maj_diag(delta: float) -> void:
	_diag_t += delta
	if _diag == null or not _diag.visible or _diag_t < 0.5:
		return
	_diag.text = _texte_diag()
	_diag_t = 0.0


func _texte_diag() -> String:
	var l := PackedStringArray()
	l.append(Langue.t("%d images/s") % Engine.get_frames_per_second())
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null or not Reseau.en_ligne:
		l.append(Langue.t("hors ligne"))
		return "\n".join(l)
	var duree := maxf((Time.get_ticks_msec() - _recus_t) / 1000.0, 0.1)
	_recus_t = Time.get_ticks_msec()
	for id in _humains:
		if id == _moi_id():
			continue
		var p: ENetPacketPeer = peer.get_peer(id) if meneur.est_hote() else peer.get_peer(1)
		var ping := p.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) if p else -1.0
		var pertes := p.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / float(ENetPacketPeer.PACKET_LOSS_SCALE) * 100.0 if p else 0.0
		var t: TamponEtats = _etats.get(id)
		var gigue := t.gigue() * 1000.0 if t else 0.0
		var muet := (_horloge() - t.dernier_recu) if t and not t.vide() else -1.0
		l.append(Langue.t("%s : ping %d ms, pertes %.0f %%, gigue %d ms, %.0f états/s") % [_humains[id].get("nom", "?"), ping, pertes,
			gigue, int(_recus.get(id, 0)) / duree] + (Langue.t("  (muet depuis %.1f s)") % muet if muet > 1.0 else ""))
		_recus[id] = 0
	return "\n".join(l)


func _est_siege(id: int) -> bool:
	return meneur.pub.get("sieges", {}).has(id)


func _assurer_bouille(id: int, nom: String, apparence: int) -> Bouille:
	if id == _moi_id():
		return null
	if bouilles.has(id):
		var b0: Bouille = bouilles[id]
		if b0.nom_affiche == nom:
			return b0
		_retirer_bouille(id)
	var b := Bouille.new()
	b.nom_affiche = nom
	b.apparence = Bouille.decoder(apparence)
	add_child(b)
	bouilles[id] = b
	_corps_solide(b)
	if not Meneur.est_bot(id):
		b.autonome = false
		Voix.attacher(id, b)
		if _tetes.has(id):
			b.poser_photo(_tetes[id][0], _tetes[id][1])
	return b


## Chaque autre joueur a un corps solide (une capsule sur la couche des joueurs) que le mien ne traverse pas.
## Il ne l'est que vivant et visible : un mort n'est qu'un fantôme (cf. `Corps.solide`).
func _corps_solide(b: Bouille) -> void:
	var sb := StaticBody3D.new()
	sb.name = "CorpsSolide"
	sb.collision_layer = Corps.COUCHE_JOUEURS
	sb.collision_mask = 0
	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	forme.shape = capsule
	forme.position.y = 0.875
	sb.add_child(forme)
	b.add_child(sb)


func _rendre_solide(b: Bouille, oui: bool) -> void:
	var sb := b.get_node_or_null("CorpsSolide") as StaticBody3D
	if sb:
		sb.collision_layer = Corps.COUCHE_JOUEURS if oui else 0


## Ce que mon corps heurte : voir `Corps.masque`. Rappelé à chaque image (le mode change sans crier gare).
## Collé à un mur ou à une porte fermée, la caméra (plus en avant pour un loup, penchée, accroupie) ne doit
## jamais passer de l'autre côté : un rayon part de l'axe du corps vers l'œil, prolongé d'une marge qui couvre
## le plan proche ; au moindre obstacle, l'œil recule (Edwin, 01/11 : « un loup collé à une porte voit à travers »).
const MARGE_CAMERA := 0.2


func _reculer_camera_du_mur() -> void:
	if _masque_corps() == 0 or camera == null or not camera.is_inside_tree():
		return
	var cam_g: Vector3 = tete.global_transform * camera.position
	var axe := Vector3(corps_joueur.global_position.x, cam_g.y, corps_joueur.global_position.z)
	var dir := cam_g - axe
	if dir.length() < 0.001:
		return
	dir = dir.normalized()
	var q := PhysicsRayQueryParameters3D.create(axe, cam_g + dir * MARGE_CAMERA, _masque_corps())
	q.exclude = [corps_joueur.get_rid()]
	for m in _murs_ecartes:
		if is_instance_valid(m):
			q.exclude.append(m.get_rid())   # le fantôme voit à travers les murs qu'il traverse
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return
	var voulu: Vector3 = (r["position"] as Vector3) - dir * MARGE_CAMERA
	var corr := voulu - cam_g
	corr.y = 0.0
	if (voulu - axe).dot(dir) < 0.0:
		corr = axe - cam_g
		corr.y = 0.0
	tete.position += corps_joueur.global_transform.basis.inverse() * corr


## Le fantôme traverse les murs des maisons (et seulement eux) : on les écarte un par un de ses collisions,
## on les lui rend dès qu'il n'est plus fantôme. Le village peut être rebâti (nouvelle liste de murs).
var _murs_ecartes: Array[StaticBody3D] = []


func _regler_traversee_maisons() -> void:
	var voulus: Array[StaticBody3D] = []
	if mode == "fantome" and is_instance_valid(ronde):
		voulus = ronde.murs_maisons
	if voulus.size() == _murs_ecartes.size() and (voulus.is_empty() or voulus[0] == _murs_ecartes[0]):
		return
	for m in _murs_ecartes:
		if is_instance_valid(m):
			corps_joueur.remove_collision_exception_with(m)
	_murs_ecartes = []
	for m in voulus:
		if is_instance_valid(m):
			corps_joueur.add_collision_exception_with(m)
			_murs_ecartes.append(m)


func _masque_corps() -> int:
	return Corps.masque(mode, _vivant(), _assis_libre, _cine_t >= 0.0)


func _retirer_bouille(id: int) -> void:
	if bouilles.has(id):
		bouilles[id].queue_free()
		bouilles.erase(id)


func _animer_autres(delta: float) -> void:
	# L'état est déjà interpolé (TamponEtats) : un lissage court suffit pour gommer les sauts.
	var k := clampf(delta * 25.0, 0, 1)
	var maintenant := _horloge()
	for id in bouilles:
		var b: Bouille = bouilles[id]
		if Meneur.est_bot(id):
			continue
		if not _etats.has(id) or (_etats[id] as TamponEtats).vide():
			continue
		var e: Dictionary = (_etats[id] as TamponEtats).echantillon(maintenant)
		var avant := b.global_position
		if b.global_position.distance_to(e["pos"]) > 4.0:
			b.global_position = e["pos"]     # téléporté (placement) : on ne le fait pas glisser
		else:
			b.global_position = b.global_position.lerp(e["pos"], k)
		b.rotation.y = lerp_angle(b.rotation.y, e["yaw"] + PI, k)
		b.marcher(clampf((b.global_position - avant).length() / maxf(delta, 0.001) / 2.5, 0, 2))
		var bs := {}
		var expr: PackedFloat32Array = e["expr"]
		for i in mini(expr.size(), EXPR.size()):
			bs[EXPR[i]] = expr[i]
		var tv: Vector3 = e["tete"]
		b.appliquer(bs, tv.x, tv.y - float(e["pitch"]) * 0.6, tv.z, e["regard"])
		b.corps_suivi = e["corps"]
		b.mains_suivi = e.get("mains", PackedFloat32Array())


func _bots_recus(ids: PackedInt32Array, positions: PackedVector3Array, caps: PackedFloat32Array, regards: PackedVector3Array) -> void:
	var sieges: Dictionary = meneur.pub.get("sieges", {})
	for k in ids.size():
		var id := ids[k]
		if not sieges.has(id):
			continue
		var b := _assurer_bouille(id, sieges[id]["nom"], sieges[id]["apparence"])
		if b == null:
			continue
		if not b.has_meta("but"):
			b.global_position = positions[k]
		var avant: Vector3 = b.get_meta("but", positions[k])
		b.set_meta("but", positions[k])
		b.set_meta("cap", caps[k])
		b.set_meta("vitesse", (positions[k] - avant).length() / 0.1)
		b.regarder(regards[k])


func _animer_bots(delta: float) -> void:
	for id in bouilles:
		if not Meneur.est_bot(id):
			continue
		var b: Bouille = bouilles[id]
		if not b.has_meta("but"):
			continue
		b.global_position = b.global_position.lerp(b.get_meta("but"), clampf(delta * 10.0, 0, 1))
		b.rotation.y = lerp_angle(b.rotation.y, b.get_meta("cap"), clampf(delta * 8.0, 0, 1))
		b.marcher(clampf(float(b.get_meta("vitesse")) / 2.6, 0, 2))


# ================================================================ le meneur parle

## La partie commence : le village prend sa taille (une maison par joueur, plus le temple).
## On le rebâtit, et on se pose près du feu, hors des murs du nouveau cercle.
func _reconstruire_ronde(n: int) -> void:
	_ronde_n = n
	Ronde.configurer(n)
	var ancienne := ronde
	ronde = Ronde.new()
	add_child(ronde)
	if is_instance_valid(ancienne):
		ancienne.queue_free()
	ronde.regler_brume(Ronde.brume_volumetrique)
	if _frissons:
		_frissons.ronde = ronde
	if _cine:
		_cine.ronde = ronde
	var portes: Dictionary = meneur.pub.get("portes", {})
	for cle: String in portes:
		var bouts := cle.split(":")
		ronde.regler_porte(int(bouts[0]), bouts[1], bool(portes[cle]))
	var m := _ma_maison()
	if m >= 0:
		ronde.marquer_ma_maison(m)
	var a := _rng.randf() * TAU
	corps_joueur.global_position = Vector3(sin(a), 0.05, cos(a)) * (Ronde.R_SOUCHES + 1.6)


## La partie commence : on apparaît devant sa maison, tourné vers la place.
func _partir_de_ma_maison() -> void:
	var m := _ma_maison()
	if m < 0:
		return
	var p := Ronde.depart(m)
	_appliquer_placement(Vector3(p.x, 0.05, p.z), Vector3(0, 0.05, 0), "libre")


func _brancher_meneur() -> void:
	meneur.etat_public.connect(_sur_pub)
	meneur.etat_prive.connect(_sur_priv)
	meneur.annonce.connect(_sur_annonce)
	meneur.tchat.connect(func(nom, t):
		ecran.tchat_recevoir(nom, t)
		if _auto:
			print("[tchat] %s : %s" % [nom, t]))
	meneur.bruit.connect(_sur_bruit)
	Voix.envoyer = func(donnees: PackedByteArray, niveau: float): meneur.voix_envoyer(donnees, niveau)
	meneur.porte.connect(_sur_porte)
	meneur.placement.connect(_sur_placement)
	meneur.bots_maj.connect(_bots_recus)
	meneur.trace.connect(func(p): _traces_nuit.append(p))
	meneur.tombe.connect(func(nom, maison):
		ronde.enterrer(nom, _cosm_de_maison(maison, "tombe"))
		ronde.barricader(maison))
	meneur.marque.connect(_sur_marque)
	meneur.noir.connect(_sur_noir)
	meneur.fin.connect(_sur_fin)
	meneur.titres_yeux.connect(func(t: Array):
		if _auto:
			print("[titres] ", t.map(func(x): return x["texte"]))
		ecran.titres_yeux(t))
	meneur.parole.connect(_sur_parole)
	meneur.cinematique.connect(_sur_cinematique)
	meneur.retour_chambre.connect(_sur_retour_chambre)
	meneur.pierre.connect(func(t): ronde.tacher(t))
	meneur.devore.connect(_sur_devore)
	meneur.rideau.connect(func(m, c, o):
		if m != _ma_maison():
			ronde.entrouvrir_rideau(m, c, o))
	meneur.morsure.connect(_sur_morsure)
	meneur.quete_vue.connect(_sur_quete_vue)
	meneur.quete_fin.connect(_sur_quete_fin)
	meneur.chute.connect(_sur_chute)
	meneur.objets_maj.connect(_sur_objets)
	meneur.caillou.connect(_sur_caillou)
	meneur.caillou_lance.connect(_sur_caillou_lance)
	meneur.apparition.connect(_sur_apparition)
	meneur.geste.connect(_sur_geste)
	meneur.exclusion_maj.connect(_sur_exclusion)
	meneur.exclu.connect(func(texte: String):
		if _auto:
			print("[exclu] ", texte)
		_retour_menu(texte))
	meneur.exclusion_refus.connect(func(texte: String): ecran.message(texte, 4.0))


# ================================================================ frissons, bandeaux, musique

var _frissons: Frissons
var _bourdon: AudioStreamPlayer
var _musique_jour: AudioStreamPlayer     # nappes de fond en partie (outils/musique/ambiance_jeu.py), bus « Musique »
var _musique_nuit: AudioStreamPlayer
var _musique_duck_t := 0.0               # > 0 : un son important vient de retentir, la musique s'efface un instant
var _musique_menu: AudioStreamPlayer   # ambiance calme et sombre des menus (outils/musique/ambiance_menu.py)
var _clic: AudioStreamPlayer


func _creer_frissons() -> void:
	_frissons = Frissons.new()
	_frissons.camera = camera
	_frissons.corps = corps_joueur
	_frissons.ronde = ronde
	_frissons.permis = _frissons_permis
	_frissons.maison_vide = func(i: int) -> bool:
		var s: Dictionary = meneur.pub.get("sieges", {})
		for id in s:
			if int(s[id].get("maison", -1)) == i:
				return not s[id].get("vivant", true)
		return false
	_frissons.seul = func() -> bool:
		for id in bouilles:
			var b: Bouille = bouilles[id]
			if b.visible and b.global_position.distance_to(corps_joueur.global_position) < 8.0:
				return false
		return true
	_frissons.sol_pas = _sol_pas
	_frissons.secouer = _secouer_tete
	_frissons.journal = _auto
	add_child(_frissons)


## Les frayeurs : vivant, de jour, sans panneau ni mini-jeu sous les yeux.
func _frissons_permis() -> bool:
	return etape == "jeu" and _vivant() and _phase() not in ["salon", "fin", "nuit", "distribution", "aube", "pret", "successeur"] \
		and _phase() not in PHASES_CONSEIL and _phase() != "verdict" \
		and _monde_quete == null and _cine_t < 0.0 and not ecran.panneau_ouvert() and not _carnet.visible


## Une porte s'ouvre ou se ferme, chez tout le monde : on l'entend d'autant moins qu'on est loin
## (la nuit, les portes des loups passent par les bruits de l'hôte).
func _sur_porte(i: int, q: String, o: bool) -> void:
	var change: bool = ronde.porte_ouverte(i, q) != o
	ronde.regler_porte(i, q, o)
	if change and etape == "jeu" and _phase() != "nuit":
		_jouer3d("porte" if o else "porte_ferme", Ronde.devant_porte(i, q), -6.0, false)


## Un fantôme s'est matérialisé : si j'en suis témoin, son visage hurle devant mes yeux.
func _sur_apparition(temoins: Array, pos: Vector3) -> void:
	if etape != "jeu" or not _vivant() or _cine_t >= 0.0:
		return
	if temoins.has(_moi_id()):
		_frissons.monstre()
	else:
		# Je ne le vois pas, mais son hurlement porte : plus on est loin, moins on l'entend.
		_jouer3d("hurlement", pos + Vector3(0, 1.5, 0), -2.0, false)


## Traduit un texte de plusieurs lignes ligne par ligne (un gabarit « …%s » ne doit pas avaler les lignes suivantes).
func _tl(texte: String) -> String:
	var sortie := PackedStringArray()
	for ligne: String in texte.split("
"):
		sortie.append(Langue.t(ligne))
	return "
".join(sortie)


## Comment le jeu désigne quelqu'un pendant la partie : jamais par son nom, par son bandeau.
func _designer(id: int) -> String:
	if id == _moi_id():
		return "toi"
	var s: Dictionary = meneur.pub.get("sieges", {})
	var k: int = s[id].get("bandeau", -1) if s.has(id) else -1
	return "la personne au bandeau %s" % Bouille.nom_bandeau(k) if k >= 0 else "cette personne"


## Les bandeaux de chacun (et le mien, pour le miroir), et le numéro de ma maison en vert.
func _maj_bandeaux(sieges: Dictionary) -> void:
	if _vue_objets:
		_vue_objets.rafraichir()   # ne refait que les carnets dont l'habitant ou le bandeau a changé
	for id in sieges:
		var k: int = sieges[id].get("bandeau", -1)
		if id == _moi_id():
			if moi:
				moi.porter_bandeau(k)
		elif bouilles.has(id):
			(bouilles[id] as Bouille).porter_bandeau(k)
	var m := _ma_maison()
	if m >= 0:
		ronde.marquer_ma_maison(m)
		_frissons.ma_maison = m


## La musique : il n'en reste rien. Le bourdon (« on dirait des vagues ») puis les notes isolées
## (« des carillons, il faut les enlever ») sont retirés à la demande d'Edwin (31/10).
func _musique(delta: float, p: String, _tension: float) -> void:
	if _musique_jour == null:
		return
	# Une nappe très basse pendant la partie, jour ou nuit ; rien au salon, à l'écran de fin, en pause, ni dans
	# les clairières des quêtes (elles ont déjà leur ambiance).
	var en_jeu: bool = etape == "jeu" and p not in ["salon", "fin"] and not Ronde.hors_village(corps_joueur.global_position)
	var nuit: bool = p in ["distribution", "nuit", "aube"]
	var duck := 0.0
	if en_jeu:
		var parle: bool = Voix.mon_niveau > 0.02
		for id in bouilles:
			if Voix.niveau(id) > 0.02:
				parle = true
		if parle:
			duck = -7.0
		if _musique_duck_t > 0.0:
			_musique_duck_t -= delta
			duck = minf(duck, -9.0)
	var haut_jour := (-6.0 + duck) if en_jeu and not nuit else -80.0
	var haut_nuit := (-6.0 + duck) if en_jeu and nuit else -80.0
	# Entrée en fondu lent (6 s), sortie un peu plus vive ; le ducking, lui, est rapide.
	var vitesse := 14.0 if duck < 0.0 else 7.0
	_musique_jour.volume_db = move_toward(_musique_jour.volume_db, haut_jour, delta * vitesse)
	_musique_nuit.volume_db = move_toward(_musique_nuit.volume_db, haut_nuit, delta * vitesse)


## Au Conseil, celui qui est sur son rondin s'y assoit (joueurs, bots et soi-même).
func _asseoir() -> void:
	var conseil: bool = _phase() in PHASES_CONSEIL
	var tous: Array = bouilles.values()
	if moi:
		tous.append(moi)
	for b: Bouille in tous:
		var oui := false
		if conseil and not b.mort:
			var p := Vector2(b.global_position.x, b.global_position.z)
			oui = absf(p.length() - Ronde.R_SOUCHES) < 0.35
		elif not b.mort and b.global_position.y < 0.1:
			# Personne ne tient debout au milieu d'une souche ou d'un lit : s'il y est, il est assis.
			oui = not Ronde.siege_proche(b.global_position, 0.25, true).is_empty()
		if b == moi and oui and not b.assis and Ronde.maison_de(corps_joueur.global_position) < 0:
			_face_au_feu()
		b.assis = oui
	if moi and _assis_libre:
		moi.assis = true


func _phase() -> String:
	return meneur.pub.get("phase", "salon")


func _priv(cle: String, defaut: Variant = null) -> Variant:
	return meneur.priv.get(cle, defaut)


func _suis_loup() -> bool:
	return _priv("loup", false) and _vivant()


func _vivant() -> bool:
	if _phase() == "salon":
		return true
	return _priv("vivant", true)


func _sur_pub(pub: Dictionary) -> void:
	if _trace_pubs:
		print("[pub reçu] phase=%s synchro=%s t=%.1f" % [pub.get("phase", "?"), pub.has("synchro"), _t])
		var t0 := Time.get_ticks_msec()
		_sur_pub_vrai(pub)
		print("[pub traité] en %d ms" % (Time.get_ticks_msec() - t0))
		return
	_sur_pub_vrai(pub)


func _sur_pub_vrai(pub: Dictionary) -> void:
	if pub.has("nb_maisons") and int(pub["nb_maisons"]) != _ronde_n:
		_reconstruire_ronde(int(pub["nb_maisons"]))
	var p: String = pub.get("phase", "salon")
	if p == "salon" and _derniere_phase != "" and _derniere_phase != "salon":
		_revenir_au_salon(pub)
	if p == "salon" and pub.has("synchro"):
		ecran.cacher_fin()
		_synchro_sur_pub(pub)
	elif p == "salon":
		ecran.cacher_fin()
		_synchro_fermer()
		_rafraichir_salon()
	else:
		ecran.cacher_salon()
		_synchro_fermer()
	var sieges: Dictionary = pub.get("sieges", {})
	for id in sieges:
		if id != _moi_id():
			_assurer_bouille(id, sieges[id]["nom"], sieges[id]["apparence"])
	_maj_bandeaux(sieges)
	if p != _derniere_phase:
		if _derniere_phase == "salon" and p != "fin":
			_partir_de_ma_maison()
		_changement_de_phase(_derniere_phase, p)
		_derniere_phase = p
	_maj_quetes(pub)
	var appel: String = pub.get("appel", "")
	if appel != _dernier_appel:
		_dernier_appel = appel
		_changement_d_appel(appel)
	_dessiner_fils({})
	_rafraichir_liste_joueurs()
	_maj_depouillement(pub)
	Streamer.sur_pub(pub)
	ronde.attacher(pub.get("attache_lie", false) and pub.get("attache", -1) > 0)
	Voix.masquer(p == "nuit")
	if Reseau.en_ligne:
		Voix.partie(p != "salon")   # pas de chat vocal tant que la partie n'est pas lancée


## Fin de partie, l'hôte nous ramène au salon : le village est reconstruit à neuf (tombes, barricades,
## rideaux, taches…), les bouilles de la partie disparaissent, et ce que la partie avait laissé chez
## moi (traces, marques, quête, rôle, carnet d'indices) avec. Les connexions, elles, restent.
func _revenir_au_salon(pub: Dictionary) -> void:
	if _auto:
		print("[retour] de %s au salon" % _derniere_phase)
	for t in _traces:
		if is_instance_valid(t):
			t.queue_free()
	_traces.clear()
	_traces_nuit.clear()
	for k in _marques:
		if is_instance_valid(_marques[k]):
			_marques[k].queue_free()
	_marques.clear()
	_cacher_vue_quete()
	_dessiner_fils({})
	_dessiner_fils_loups({})
	for m: Node3D in [_marque_vote, _marque_couronne, _fleche_grise]:
		if m != null:
			m.visible = false
	_voix_affichees.clear()
	_brouillage.clear()
	_vivants_vus.clear()
	_marcheurs.clear()
	for id in bouilles.keys():
		_retirer_bouille(id)
	meneur.priv = {}
	ecran.vider_carnet()
	ecran.fermer_panneau()
	_carnet.visible = false
	if is_instance_valid(moi):
		moi.porter_bandeau(-1)
		moi.visible = true
	_noir = false
	_retour_t = -1.0
	_cine_t = -1.0
	_vote_cible = -1
	_vote_maison = -1
	_oreille = false
	_rideau_o = 0.0
	_guide.clear()
	mode = "libre"
	var t0 := Time.get_ticks_msec()
	_reconstruire_ronde(_ronde_n)
	if _trace_pubs: print("[retour] village reconstruit en %d ms" % (Time.get_ticks_msec() - t0))
	Voix.masquer(false)
	# Les autres humains reprennent leur place au salon, chacun avec son apparence.
	for id in pub.get("humains", {}):
		if id != _moi_id():
			var h: Dictionary = pub["humains"][id]
			_assurer_bouille(id, str(h.get("nom", "?")), int(h.get("apparence", 0)))


## La nuit, l'hôte ne me donne plus la position de qui je n'ai pas le droit de voir : leurs corps sont
## chez eux, dans leur lit, et y restent jusqu'à l'aube (ou jusqu'à ce que je reçoive à nouveau leur état).
func _cacher_les_autres_au_lit() -> void:
	var s: Dictionary = meneur.pub.get("sieges", {})
	var proie := int(meneur.pub.get("attache", -1))
	for id in bouilles.keys():
		if id == proie and (_suis_loup() or not _vivant()):
			continue   # le condamné reste enchaîné à la pierre pour la meute et pour les morts
		_etats.erase(id)
		if s.has(id) and is_instance_valid(bouilles[id]):
			(bouilles[id] as Bouille).global_position = Ronde.lit(int(s[id]["maison"]))


func _changement_de_phase(avant: String, p: String) -> void:
	if _rapide_en_partie > 0.0:
		var x := 1.0 if p == "salon" else _rapide_en_partie
		Engine.time_scale = x
		Engine.physics_ticks_per_second = int(60 * x)
	if avant == "salon" and p != "salon":
		_frissons.remettre()
	ronde.regler_nuit_close(p in ["distribution", "nuit"])
	_fermer_sortie()
	_oreille = false
	_rideau_o = 0.0
	if _auto:
		print("[phase] %s -> %s  (t=%.0f s, role=%s, vivant=%s)" % [avant, p, _t, _priv("role", "?"), _vivant()])
	ecran.fermer_panneau()
	# --photo-phases=<dossier> : des photos du Conseil et du supplice (agent testeur, essais).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--photo-phases=") and p in ["vote", "depouillement", "tranche", "verdict", "nuit", "annonce"]:
			var dossier := arg.substr(15)
			for k in 4:
				get_tree().create_timer(1.0 + k * 3.5).timeout.connect(func():
					if _phase() == p:
						get_viewport().get_texture().get_image().save_png("%s/j%d_%s_%d.png" % [dossier, int(meneur.pub.get("jour_n", 0)), p, k]))
	_vote_cible = -1
	_combo = null
	ecran.combo(null)
	_lecture_t = 0.0
	_risque = 0.0
	_repere = false
	match p:
		"distribution":
			ecran.vider_carnet()
			for t in _traces:
				t.queue_free()
			_traces.clear()
		"nuit":
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--essai-cine="):
					# Essai : la cinématique du loup tout de suite, une photo toutes les 0,4 s (dossier).
					var dossier := arg.substr(13)
					var ess_maison := -1
					var ess_victime := -1
					var ess_loups := []
					for a2 in OS.get_cmdline_user_args():
						if a2 == "--essai-cine-pov":
							ess_maison = _ma_maison()
							ess_victime = _moi_id()
						elif a2 == "--essai-cine-loup":
							ess_loups = [_moi_id()]
						elif a2.begins_with("--essai-cine-maison="):
							ess_maison = int(a2.substr(20))
					_sur_cinematique(ess_maison, ess_victime, ess_loups)
					for k in 22:
						get_tree().create_timer(0.4 * k / Engine.time_scale, true, false, true).timeout.connect(func():
							get_viewport().get_texture().get_image().save_png("%s/c_%02d.png" % [dossier, k]))
			_cacher_les_autres_au_lit()
			for t in _traces:
				t.queue_free()
			_traces.clear()
			_traces_nuit.clear()
			ronde.lune_rouge(_suis_loup())
		"annonce":
			for pos in _traces_nuit:
				_poser_trace(pos)
			_traces_nuit.clear()
	if avant == "salon" and p != "salon":
		ecran.cacher_salon()
		camera.current = true
	if avant == "quete" or p not in ["quete"]:
		_cacher_vue_quete()
	if p == "tableau":
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--essai-dos="):
				# Essai : une photo de l'arrière puis de la façade d'une maison, vues de l'extérieur.
				var dossier := arg.substr(12)
				var dz := Ronde.PROFONDEUR * 0.5
				for k in 2:
					get_tree().create_timer((0.8 + 1.2 * k) / Engine.time_scale, true, false, true).timeout.connect(func():
						var sens := -1.0 if k == 0 else 1.0
						var pos := Ronde._vers_monde(1, Vector3(0, 0, sens * (dz + 5.0)))
						_guide.clear()
						_appliquer_placement(pos, Ronde.centre_maison(1) + Vector3(0, 1.3, 0), "libre")
						get_tree().create_timer(0.5 / Engine.time_scale, true, false, true).timeout.connect(func():
							get_viewport().get_texture().get_image().save_png("%s/maison_%s.png" % [dossier, "dos" if k == 0 else "facade"])))
	match p:
		"choix_maire":
			_choix_maire.clear()
			if meneur.pub.get("maire", -1) == _moi_id() and _vivant():
				if _auto:
					_envoyer_intention("choisir_quetes", [0, 1, 2])
				else:
					_panneau_choix_maire()
		"successeur":
			if meneur.pub.get("successeur", -1) == _moi_id():
				if _auto:
					_envoyer_intention("successeur", -1)
				else:
					_panneau_successeur()
		"depouillement":
			_annoncer_depouillement(meneur.pub.get("resultat", {}))
		"tranche":
			var t: Dictionary = meneur.pub.get("tranche", {})
			if t.get("par", -1) == _moi_id() and _vivant():
				if _auto:
					var c: Array = t.get("candidats", [])
					if not c.is_empty():
						_envoyer_intention("trancher", c[_rng.randi_range(0, c.size() - 1)])
				else:
					_panneau_tranche()
		"tableau":
			# (Le joueur automatique vote à son prochain tour : voter ici, en plein changement de
			# phase, renvoyait l'état et relançait ce même changement, sans fin.)
			_mon_vote_quete = -1


func _sur_priv(priv: Dictionary) -> void:
	_energie_t = Time.get_ticks_msec() / 1000.0
	if priv.get("vivant", true) and _caillou_main:
		_caillou_main.queue_free()
		_caillou_main = null
	for m in priv.get("messages", []):
		ecran.message(m["texte"], 5.0)
		if m["carnet"]:
			ecran.noter(Langue.t(m["texte"]))
	if _phase() == "distribution" and not ecran.has_meta("carte_vue"):
		ecran.set_meta("carte_vue", true)
		ecran.carte_role(priv["nom_role"], priv["desc"], priv["loup"])
	if _phase() != "distribution":
		ecran.remove_meta("carte_vue")
	_dessiner_fils_loups(priv.get("votes_loups", {}))
	_maj_chiffres_loups()


func _sur_annonce(texte: String, son: String, duree: float) -> void:
	var texte_fr := texte   # l'hôte écrit en français : on le teste avant de le traduire
	texte = Options.avec_touches(texte)
	if _auto and texte != "":
		print("[annonce] ", texte.replace(char(10), " | "))
	if texte_fr.begins_with("Votez") and _phase() not in ["salon", "fin"] and not _vivant():
		texte = Langue.t("Les vivants votent. Toi, tu ne peux que regarder.")
	if texte != "":
		ecran.message(texte, duree)
		if _phase() == "nuit":
			_voix_meneur = texte
	if son != "":
		_jouer2d(son, -4.0)


## Immersion (décision d'Edwin, 28/10) : jamais de téléportation quand une étape change.
## Si le joueur est loin de sa place, son personnage y MARCHE tout seul (mode « guide ») ; il ne
## bouge que la tête. Mort, dans le salon ou déjà sur place : on pose directement.
func _sur_placement(pos: Vector3, regard: Vector3, m: String) -> void:
	# Un fantôme apparaît là où il est mort et n'est plus jamais déplacé : l'hôte l'envoyait sur sa
	# souche du Conseil, au feu de camp (« il revient toujours au feu après 1 seconde », Edwin 03/11).
	if etape == "jeu" and m == "fantome" and _phase() not in ["salon", "fin"]:
		if mode != "fantome":
			_guide.clear()
			_appliquer_placement(corps_joueur.global_position + Vector3(0, 0.3, 0), Vector3.ZERO, "fantome")
		return
	# Un mort reste un fantôme libre : on ne le replace plus, il suit qui il veut. Même s'il n'a pas encore
	# basculé en mode fantôme (placement reçu juste après sa mort) ; seul le condamné, mort pour les règles
	# mais encore mené à la pierre, obéit aux placements.
	if etape == "jeu" and m != "fantome" and not _vivant() and _phase() not in ["salon", "fin"] 			and (mode == "fantome" or (meneur.pub.get("attache", -1) != _moi_id() and _phase() not in ["verdict", "tranche", "depouillement"])):
		return
	# Déjà rentré chez soi au soir : on ne retourne pas au lit, on garde ses commandes dans sa chambre.
	if etape == "jeu" and m == "chambre" and _vivant() and _phase() in ["distribution", "nuit"] and Meneur.est_rentre(corps_joueur.global_position, _ma_maison()):
		_guide.clear()
		_entrer_chez_soi()
		return
	# Au Conseil, tout le monde est assis à sa place d'un coup, tourné vers le feu (Edwin, 31/10).
	if _sur_le_champ or (m == "assis" and _phase() not in ["verdict", "tranche", "depouillement"]):
		_guide.clear()
		_appliquer_placement(pos, regard, m)
		return
	var ecart := Vector2(pos.x - corps_joueur.global_position.x, pos.z - corps_joueur.global_position.z).length()
	if etape == "jeu" and m != "fantome" and (_vivant() or m == "traine") and ecart > GUIDE_MIN and _phase() not in ["salon", "fin"]:
		_guide = _chemin_guide(corps_joueur.global_position, pos)
		_guide_fin = [pos, regard, m]
		_guide_t = 0.0
		# Le temps d'y aller à pas pressé, et de la marge : au-delà, on est coincé, on pose.
		var long := 0.0
		var de := corps_joueur.global_position
		for p in _guide:
			long += de.distance_to(p)
			de = p
		_guide_max = maxf(GUIDE_MAX, long / (VITESSE * GUIDE_VITESSE) * 1.8)
		_guide_bloque = 0.0
		_guide_mieux = INF
		_guide_recalcule = false
		_guide_ecarts = 0
		# Vers une clairière ou au retour : le jeu nous y amène quoi qu'il arrive, rien ne l'arrête.
		_guide_traverse = Ronde.hors_village(pos) or Ronde.hors_village(corps_joueur.global_position)
		mode = "guide"
		_assis_libre = false
		_sur_lit = false
		_auto_chemin.clear()
		corps_joueur.collision_mask = _masque_corps()
		return
	_guide.clear()
	_appliquer_placement(pos, regard, m)


## Rentré chez soi : la marche guidée s'arrête, les commandes reviennent (mode chambre), sur place.
func _entrer_chez_soi() -> void:
	_tete_droite()
	mode = "chambre"
	_assis_libre = false
	_sur_lit = false
	_auto_chemin.clear()
	corps_joueur.collision_mask = 1 | Ronde.COUCHE_PORTE_AVANT | Ronde.COUCHE_PORTE_ARRIERE
	moi.visible = true


## La tête redevient droite sans que la vue saute : son lacet passe au corps (sinon on regardait de travers
## jusqu'au prochain placement : Edwin, 01/11).
func _tete_droite() -> void:
	var r := Corps.fin_de_marche(corps_joueur.rotation.y, tete.rotation.y)
	corps_joueur.rotation.y = r[0]
	tete.rotation.y = r[1]


func _appliquer_placement(pos: Vector3, regard: Vector3, m: String) -> void:
	if _trace_fantome and mode == "fantome":
		print("[fantome] replacé en ", m, " à ", pos, " phase=", _phase())
		print_stack()
	mode = m
	_assis_libre = false
	_sur_lit = false
	tete.rotation.y = 0.0
	_auto_chemin.clear()
	_ancre = pos
	corps_joueur.global_position = pos
	corps_joueur.velocity = Vector3.ZERO
	if regard != Vector3.ZERO:
		var d := regard - pos
		corps_joueur.rotation.y = atan2(-d.x, -d.z)
		_yaw_siege = corps_joueur.rotation.y
		tete.rotation.x = -0.05
	corps_joueur.collision_mask = _masque_corps()
	moi.visible = m != "attache"
	if m == "attache":
		tete.rotation.x = 1.15   # couché sur le dos : on regarde le ciel, la tête reste libre
		ecran.message("On t'enchaîne sur la pierre. Tu ne peux plus parler. Cette nuit, les loups viendront.", 7.0)
	_lanterne.visible = m == "poste" and _monde_quete == null and not (meneur.pub.get("en_quete", {}) as Dictionary).has(_moi_id())
	if m == "fantome":
		ecran.message("Tu es mort. Les vivants ne te voient pas et ne t'entendent pas ; les autres morts, si. Approche-toi d'un joueur en quête pour le hanter ({agir}), ou ramasse des cailloux à lui lancer. Devant un vivant, {agir} te fait apparaître en monstre ; %s, devant tous ceux autour (une frayeur par vivant et par jour). Ton énergie remonte avec le temps." % Options.texte_touches("pouvoir"), 11.0)


func _sur_parole(id: int, texte: String) -> void:
	# Comme une voix : on n'entend (et ne note) que ce qui se dit à portée.
	if bouilles.has(id) and (bouilles[id] as Bouille).global_position.distance_to(corps_joueur.global_position) > 22.0:
		return
	if bouilles.has(id):
		(bouilles[id] as Bouille).dire(Langue.t(texte), 6.0)
	ecran.noter("%s : « %s »" % [Langue.t("Toi" if id == _moi_id() else _etiquette(id)), Langue.t(texte)])
	if _auto:
		print("[parole] %s : %s" % [_nom(id), texte])


func _sur_noir(oui: bool) -> void:
	_noir = oui
	if oui:
		_jouer2d("cri", 0.0)


func _sur_marque(poste: String, oui: bool) -> void:
	if oui and not _marques.has(poste):
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.9, 0.06, 0.25)
		m.mesh = b
		m.material_override = Bouille.materiau(Color(0.35, 0.28, 0.22), 0.01)
		m.position = ronde.postes[poste] + Vector3(0.6, 0.35, 0.4)
		m.rotation = Vector3(0.5, 0.8, 0.9)
		add_child(m)
		_marques[poste] = m
	elif not oui and _marques.has(poste):
		_marques[poste].queue_free()
		_marques.erase(poste)


func _sur_fin(res: Dictionary) -> void:
	if _auto:
		print("[fin] ", res.get("texte", ""))
		var nl: Array = res.get("nuits_loups", [])
		print("[fin] nuits des loups reçues : %d (échantillons : %s)" % [nl.size(), nl.map(func(n): return (n["loups"] as Dictionary).values().map(func(t): return t.size()))])
		for ligne in res.get("chronique", []):
			print("[fin]   ", ligne)
	if _auto and "--quitter-a-la-fin" in OS.get_cmdline_user_args() and not meneur.est_hote():
		# Essais : un invité qui s'en va pendant l'écran de fin ne doit rien casser.
		get_tree().create_timer(2.0).timeout.connect(func():
			print("[retour] l'invité quitte pendant l'écran de fin")
			_quitter_partie())
	if _auto and meneur.est_hote() and _rejouer_restant > 0:
		# Essais (--rejouer=N) : l'hôte relance N fois, comme s'il cliquait « Rejouer » puis « Commencer ».
		_rejouer_restant -= 1
		get_tree().create_timer(6.0).timeout.connect(func():
			print("[retour] l'hôte clique Rejouer")
			meneur.intention.rpc_id(1, "rejouer")
			get_tree().create_timer(8.0).timeout.connect(func():
				print("[retour] l'hôte clique Commencer")
				meneur.lancer_partie()))
	_noir = false
	mode = "libre"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sauver-fin="):
			# Essais : le résultat de la partie, pour le rejouer à l'écran (tests/cap_fin.gd).
			var f := FileAccess.open(a.substr(13), FileAccess.WRITE)
			if f:
				f.store_string(var_to_str(res))
	ecran.fin(res, _moi_id(), meneur.est_hote(), func(): meneur.intention.rpc_id(1, "rejouer"))
	# Progression : expérience, niveau, succès (bloc à part, cf. bloc_xp.gd). Pas en mode test.
	var faits: Dictionary = res.get("faits", {}).get(_moi_id(), {})
	if not _mode_test and not faits.is_empty():
		var rapport := Progres.enregistrer_partie(faits)
		BlocXp.poser(ecran, rapport)
		if _auto:
			print("[progression] +%d XP, niveau %d, succès %s" % [rapport["xp_gagnee"], rapport["niveau_apres"], rapport["succes"]])
	# Mes chiffres partent vers l'hôte maintenant (jamais avant) ; vides si je n'avais pas de webcam.
	if not _suivi_yeux_envoye:
		_suivi_yeux_envoye = true
		var chiffres := _suivi_yeux.exporter() if _suivi_yeux.valable() else {}
		if "--stats-factices" in OS.get_cmdline_user_args():
			chiffres = {"suivi": 900.0, "clin": 150, "clin_proces": 6, "proces": 30.0, "vote": 30.0, "detourne": 0.0}
		meneur.envoyer_stats_yeux(chiffres)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Essai (--fin-essai=<res.txt> --photo-fin=<dossier>) : rejoue l'écran de fin d'une partie enregistrée
## par --sauver-fin, avec des chiffres de webcam inventés, et le photographie (bilan, nuit des loups).
func _essai_fin_lancer(chemin: String) -> void:
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return
	var res: Dictionary = str_to_var(f.get_as_text())
	_aller("jeu")
	meneur.pub = {"phase": "fin", "sieges": res["sieges"]}   # sans cela, le salon se rouvre par-dessus
	ecran.cacher_salon()
	_sur_fin(res)
	var noms := {}
	var stats := {}
	var k := 0
	for id in res["sieges"]:
		noms[id] = res["sieges"][id]["nom"]
		k += 1
		stats[id] = {"suivi": 900.0, "clin": 110 + k * 37, "clin_proces": 38 if k == 1 else k, "proces": 40.0, "vote": 30.0,
			"detourne": 9.0 if k == 2 else (0.0 if k == 3 else 1.0), "ferme_nuit": 55.0 if k == 4 else 5.0, "frayeurs": 4,
			"ecarquille": 3 if k == 5 else 0}
	ecran.titres_yeux(StatsYeux.titres(stats, noms))
	var dossier := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--photo-fin="):
			dossier = a.substr(12)
	if dossier == "":
		return
	var photo := func(nom: String):
		await get_tree().create_timer(2.0, true, false, true).timeout
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dossier, nom])
	await get_tree().create_timer(3.0, true, false, true).timeout   # le tout premier rendu reste noir
	await photo.call("fin_bilan")
	ecran.fin_montrer_nuit(0, 0.45)
	await photo.call("fin_nuit1_milieu")
	ecran.fin_montrer_nuit(0, 1.0)
	await photo.call("fin_nuit1_fin")
	if (res.get("nuits_loups", []) as Array).size() > 1:
		ecran.fin_montrer_nuit(1, 1.0)
		await photo.call("fin_nuit2_fin")
	get_tree().quit()


func _poser_trace(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = _rng.randf() * TAU
	for k in 3:
		var e := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.14, 0.01, 0.22)
		e.mesh = b
		e.material_override = Bouille.materiau(Color(0.12, 0.08, 0.06), 0.0)
		e.position = Vector3((k % 2) * 0.22 - 0.11, 0.06, k * 0.45 - 0.45)
		n.add_child(e)
	add_child(n)
	_traces.append(n)


## Pendant la partie : « Bandeau rouge », jamais le nom (décision d'Edwin, 29/10).
func _etiquette(id: int) -> String:
	var s: Dictionary = meneur.pub.get("sieges", {})
	var k: int = s[id].get("bandeau", -1) if s.has(id) else -1
	return "Bandeau %s" % Bouille.nom_bandeau(k) if k >= 0 else "Quelqu'un"


func _nom(id: int) -> String:
	var s: Dictionary = meneur.pub.get("sieges", {})
	return s[id]["nom"] if s.has(id) else "?"


func _vivants_autres() -> Array:
	var v := []
	var s: Dictionary = meneur.pub.get("sieges", {})
	for id in s:
		if s[id]["vivant"] and id != _moi_id():
			v.append(id)
	return v


func _envoyer_intention(type: String, a: Variant = null, b: Variant = null) -> void:
	meneur.intention.rpc_id(1, type, a, b)


# ================================================================ salon

func _rafraichir_salon() -> void:
	if _phase() != "salon" or etape != "jeu":
		return
	var pub := meneur.pub
	var hote := meneur.est_hote()
	ecran.salon(pub.get("humains", {}), pub.get("places", 8), int(pub.get("nb_loups", 2)), hote,
		_texte_code(),
		func(n): meneur.regler_salon(n, []),
		func(n): meneur.regler_loups(n),
		func(): meneur.lancer_partie(),
		pub.get("durees", {}), func(cle, v): meneur.regler_duree(cle, v),
		bool(pub.get("bots", false)), func(oui): meneur.regler_bots(oui), int(pub.get("max_places", 12)),
		pub.get("sans", []), func(r, oui): meneur.regler_role(r, oui), _prive, _lobby.get("nom", ""),
		func(): _quitter_partie(), int(pub.get("min", Meneur.MIN_JOUEURS)), bool(pub.get("perso", false)))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Le lobby se tient dans le menu : le village vu de loin, la nuit, derrière la fiche du salon.
	_cam_menu.current = true
	_maj_fiche()


# ================================================================ synchronisation du lancement

var _synchro_envoye := false
var _synchro_charge := 0.0


## L'hôte a cliqué « Commencer » : la scène d'attente s'ouvre chez tous. Le village se construit
## (cf. nb_maisons dans le pub) ; quand il est prêt on le dit à l'hôte, qui donne le top.
func _synchro_sur_pub(pub: Dictionary) -> void:
	if etape != "jeu":
		return
	if not ecran.synchro_ouverte():
		_synchro_envoye = false
		_synchro_charge = 0.0
		ecran.synchro_ouvrir()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_cam_menu.current = true
		if _auto:
			print("[synchro] scène ouverte")
	ecran.synchro_maj(pub)


func _synchro_fermer() -> void:
	if ecran.synchro_ouverte():
		ecran.synchro_fermer()
		camera.current = true


func _synchro_tick(delta: float) -> void:
	if not ecran.synchro_ouverte():
		return
	_cam_menu.current = true
	_cam_menu.global_transform = SynchroVues.vue(ecran.synchro_temps())
	if _synchro_envoye:
		return
	_synchro_charge += delta
	var voulu := int(meneur.pub.get("nb_maisons", _ronde_n))
	if _ronde_n == voulu and is_instance_valid(ronde) and ronde.is_inside_tree() and _synchro_charge > 0.5:
		_synchro_envoye = true
		if _auto:
			print("[synchro] prêt (%d maisons)" % _ronde_n)
		_envoyer_intention("synchro_pret")


# ================================================================ pouvoirs (F)

func _ouvrir_pouvoir() -> void:
	if not _vivant():
		if _phase() == "trappeur" and meneur.pub.get("trappeur", -1) == _moi_id():
			_panneau_trappeur()
		return
	var role: String = _priv("role", "")
	var p := "jour" if _de_jour() else _phase()
	var noms := func(filtre: Callable, action: Callable) -> Array:
		var l := []
		for id in _vivants_autres():
			if filtre.call(id):
				l.append([_etiquette(id), action.bind(id)])
		return l
	var tous := func(_id): return true
	var appel: String = meneur.pub.get("appel", "")
	if p == "nuit" and (appel == role or (appel in ["loups", "solitaire"] and _suis_loup())):
		if _panneau_appel(appel):
			return
	match [role, p]:
		["souffleur", "nuit"]:
			if appel == "loups" and _priv("souffles", 0) > 0:
				ecran.panneau("Faux bruit", "Il t'en reste %d. Le bruit part là où tu regardes." % _priv("souffles", 0),
					[["Faire un faux bruit là-bas", _faux_bruit]])
				return
		["vampire", "jour"]:
			ecran.panneau("Loup vampire", "Approche-toi de quelqu'un à le toucher et maintiens {mordre} trois secondes. Une seule morsure de toute la partie. S'il est loup, tu meurs." if _priv("peut_mordre", false) else "Tu as déjà mordu.", [])
			return
		["fossoyeur", "jour"]:
			var morts := []
			var s: Dictionary = meneur.pub.get("sieges", {})
			for id in s:
				if not s[id]["vivant"]:
					morts.append([s[id]["nom"], func(): _envoyer_intention("examiner", id)])
			ecran.panneau("Examiner un mort", "Au cimetière, tu apprends s'il était loup. Un par jour.", morts if not morts.is_empty() else [["Personne n'est encore mort.", Callable()]])
			return
	# Rien à faire avec son pouvoir maintenant : plus de fiche de rôle qui s'ouvre (Edwin, 31/10 :
	# le rôle est déjà écrit en haut à droite).


func _panneau_lier(premier: int) -> void:
	var l := []
	for id in _vivants_autres() + [_moi_id()]:
		if id == premier:
			continue
		var nom := "Toi" if id == _moi_id() else _etiquette(id)
		if premier < 0:
			l.append([nom, _panneau_lier.bind(id)])
		else:
			l.append([nom, func(): _envoyer_intention("lier", premier, id)])
	ecran.panneau("Lier deux âmes", "Choisis le premier." if premier < 0 else "Lié à %s… et à qui ?" % _designer(premier), l, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Le carnet de celui qu'on vient d'appeler. Renvoie true si un panneau s'est ouvert.
func _panneau_appel(appel: String) -> bool:
	if not _vivant():
		return false
	var nuit_n: int = meneur.pub.get("nuit_n", 0)
	var carnet := func(action: Callable) -> Array:
		var l := []
		for id in _vivants_autres():
			l.append([_etiquette(id), action.bind(id)])
		return l
	match appel:
		"entremetteuse":
			if nuit_n == 1:
				_panneau_lier(-1)
				return true
		"enfant":
			if _priv("modele", -1) < 0:
				ecran.panneau("Ton modèle", "Choisis-le dans ton carnet. S'il meurt, tu deviens loup.", carnet.call(func(id): _envoyer_intention("modele", id)), true)
				return true
		"veilleur":
			ecran.panneau("Garder une porte", "Quelle porte garderas-tu cette nuit, lanterne à la main ? (Jamais deux nuits de suite la même.)", carnet.call(func(id): _envoyer_intention("garder", id)), true)
			return true
		"liseuse":
			ecran.panneau("Ton carnet", "Les noms des vivants, à l'encre. Touche-en un : tu sauras s'il est loup.", carnet.call(func(id): _envoyer_intention("lire", id)), true)
			return true
		"herboriste":
			var maisons: Array = _priv("maisons_attaquees", [])
			var potions: Dictionary = _priv("potions", {})
			var l := []
			var texte := "Aucune porte ne s'est ouverte cette nuit."
			if not maisons.is_empty():
				texte = "Cette nuit, la porte de la maison %s s'est ouverte." % ", ".join(maisons.map(func(m): return Ronde.numero(m)))
				if potions.get("vie", false):
					for m in maisons:
						l.append(["Potion de vie derrière la porte %s" % Ronde.numero(m), func(): _envoyer_intention("sauver_maison", m)])
			if potions.get("mort", false):
				var poison := func():
					ecran.panneau("Potion de mort", "Chez qui la verser ? Il ne se réveillera pas.", carnet.call(func(id): _envoyer_intention("poison", id)), true)
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				l.append(["Potion de mort…", poison])
			if l.is_empty():
				texte += "\nTes fioles sont vides."
			ecran.panneau("Tes fioles", texte, l, true)
			return true
	return false


## Le tableau, de près : le détail des quêtes du jour (on vote au chiffre, pas ici).
func _panneau_tableau() -> void:
	var quetes: Array = meneur.pub.get("quetes", [])
	var lignes := PackedStringArray()
	for k in quetes.size():
		var q: Dictionary = quetes[k]
		var jeu: Array = Quetes.JEUX.get(q["jeu"], ["", ""])
		lignes.append("%d · %s — %s, %s\n      %s" % [k + 1, Langue.t(q["nom"]), Langue.t(Quetes.NOMS_NIVEAUX.get(q["niveau"], "")),
			Langue.t(Quetes.texte_recompense(q["recompense"], q.get("titre_seul", false), q.get("etat", "") == "finie" and q.get("reussie", false))), Langue.t(jeu[1])])
		if str(q.get("remplace", "")) != "":
			lignes[lignes.size() - 1] += "\n      " + Langue.t(str(q["remplace"]))
		elif str(q.get("requis", "")) != "":
			lignes[lignes.size() - 1] += "\n      " + Langue.t("Joueurs requis : %s") % Langue.t(str(q["requis"]))
	lignes.append(Langue.t("4 · Rester au village — pas de quête aujourd'hui."))
	var regle := "Le maire choisit seul la quête ; les autres participent ou non." if meneur.pub.get("maire_quete", false) else "La quête la plus votée part avec tout le village, sauf ceux qui restent."
	ecran.panneau("Le tableau des quêtes", "\n\n".join(lignes) + "\n\n" + Langue.t(regle) + " " + Langue.t("Réussie, une quête à rôle donne un rôle à l'un de ses joueurs, tiré au sort ; une quête à indice affiche un indice ici, pour tout le village."), [], true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Mon vote du matin (touches 1 à 4).
func _voter_quete(k: int) -> void:
	_mon_vote_quete = k
	_envoyer_intention("voter_quete", k)
	_maj_vote_quete(meneur.pub)


func _maj_vote_quete(pub: Dictionary) -> void:
	if pub.get("phase", "") != "tableau" or not _vivant() or etape != "jeu":
		ecran.cacher_vote_quete()
		return
	var noms := (pub.get("quetes", []) as Array).map(func(q): return q["nom"])
	var maire: int = pub.get("maire", -1)
	_vote_participation = pub.get("maire_quete", false) and maire != _moi_id()
	if _vote_participation:
		# Il y a un maire : lui seul choisit la quête, les autres participent ou non (défaut : oui).
		ecran.vote_participation(1 if _mon_vote_quete == Quetes.RESTER else 0, int(pub.get("refus_quete", 0)))
	else:
		ecran.vote_quete(noms, pub.get("votes_quete", [0, 0, 0, 0]), _mon_vote_quete, pub.get("maire_quete", false))


## Le chiffre d'une touche (1..9), quelle que soit la disposition du clavier ; 0 sinon.
func _chiffre(ev: InputEventKey) -> int:
	for code in [ev.physical_keycode, ev.keycode]:
		if code >= KEY_1 and code <= KEY_9:
			return int(code - KEY_1) + 1
		if code >= KEY_KP_1 and code <= KEY_KP_9:
			return int(code - KEY_KP_1) + 1
	return 0


## Le maire, le matin : trois quêtes parmi les propositions.
func _panneau_choix_maire() -> void:
	var props: Array = meneur.pub.get("propositions", [])
	var l := []
	for k in props.size():
		var q: Dictionary = props[k]
		var coche := _choix_maire.has(k)
		l.append([("✓ " if coche else "") + "%s — %s, %s" % [Langue.t(q["nom"]), Langue.t(Quetes.NOMS_NIVEAUX.get(q["niveau"], "")),
			Langue.t(("un titre" if q.get("titre_seul", false) else "un rôle") if q["recompense"] == "role" else "un indice")], _cocher_quete.bind(k)])
	ecran.panneau("Tu es le maire", "Choisis les trois quêtes du jour (%d / %d). Un rôle de plus pour le village, ou un indice ?" % [_choix_maire.size(), Quetes.NB_DU_JOUR], l, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _cocher_quete(k: int) -> void:
	if _choix_maire.has(k):
		_choix_maire.erase(k)
	elif _choix_maire.size() < Quetes.NB_DU_JOUR:
		_choix_maire.append(k)
	if _choix_maire.size() == Quetes.NB_DU_JOUR:
		_envoyer_intention("choisir_quetes", _choix_maire.duplicate())
		ecran.message("Les quêtes du jour sont affichées au tableau.", 3.0)
	else:
		_panneau_choix_maire.call_deferred()


func _panneau_tranche() -> void:
	var t: Dictionary = meneur.pub.get("tranche", {})
	var l := []
	for id in t.get("candidats", []):
		l.append([_designer(id).capitalize() if id == _moi_id() else _etiquette(id), func(): _envoyer_intention("trancher", id)])
	ecran.panneau("Le maire tranche", "Il faut toujours un éliminé. Qui sera attaché à la pierre cette nuit ?", l, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Le dépouillement, à l'écran de tout le monde : chaque bandeau et ses voix, du plus accusé au moins.
func _annoncer_depouillement(res: Dictionary) -> void:
	var compte: Dictionary = res.get("compte", {})
	var en_tete: Array = res.get("en_tete", [])
	if compte.is_empty():
		ecran.message("Le dépouillement : personne n'a voté.", 8.0)
		return
	var ids := compte.keys()
	ids.sort_custom(func(a, b): return int(compte[a]) > int(compte[b]))
	var lignes := [Langue.t("Le dépouillement :")]
	for id in ids:
		var n := int(compte[id])
		var moi: bool = id == _moi_id()
		var qui := Langue.t(_etiquette(id))
		var ligne: String
		if n == 1:
			ligne = Langue.t("%s (toi) — 1 voix" if moi else "%s — 1 voix") % qui
		else:
			ligne = Langue.t("%s (toi) — %d voix" if moi else "%s — %d voix") % [qui, n]
		lignes.append(ligne + ("   ◀" if en_tete.has(id) and en_tete.size() == 1 else ""))
	if en_tete.size() > 1:
		lignes.append(Langue.t("Égalité : le maire va trancher."))
	ecran.message("\n".join(lignes), 8.0)


## Au-dessus de chaque tête accusée, son nombre de voix ; en rouge, le plus accusé.
func _maj_depouillement(pub: Dictionary) -> void:
	var res: Dictionary = pub.get("resultat", {})
	var compte: Dictionary = res.get("compte", {})
	var en_tete: Array = res.get("en_tete", [])
	for id in _voix_affichees.keys():
		if not compte.has(id) or not bouilles.has(id):
			if is_instance_valid(_voix_affichees[id]):
				_voix_affichees[id].queue_free()
			_voix_affichees.erase(id)
	for id in compte:
		if not bouilles.has(id):
			continue
		if not _voix_affichees.has(id):
			var l := Label3D.new()
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.font_size = 128
			l.pixel_size = 0.0055
			l.outline_size = 18
			l.outline_modulate = Color(0, 0, 0, 0.9)
			l.position = Vector3(0, 2.35, 0)
			bouilles[id].add_child(l)
			_voix_affichees[id] = l
		var lab: Label3D = _voix_affichees[id]
		lab.text = str(int(compte[id]))
		lab.modulate = Color(1.0, 0.12, 0.08) if en_tete.has(id) else Color(0.95, 0.92, 0.85)


## La tête de mort (vote) ou la couronne (élection) au-dessus de mon accusé, pour moi seul.
func _placer_marque_vote() -> void:
	if _marque_vote == null:
		_marque_vote = _fabriquer_crane()
		add_child(_marque_vote)
		_marque_couronne = _fabriquer_fleche(Color(0.2, 0.9, 0.3), Color(0.05, 0.5, 0.12))
		add_child(_marque_couronne)
		_fleche_grise = _fabriquer_fleche(Color(0.62, 0.62, 0.64), Color(0.2, 0.2, 0.22))
		add_child(_fleche_grise)
	var p := _phase()
	var voir: bool = p in PHASES_VOTE and _vote_cible >= 0 and bouilles.has(_vote_cible) and _vivant()
	_marque_vote.visible = voir and p == "vote"
	# Élection du maire : la flèche VERTE sur mon vote posé, une flèche GRISE sur celui que je vise
	# (on peut changer d'avis jusqu'à la fin du temps ; le dernier clic compte).
	_marque_couronne.visible = voir and p == "vote_maire"
	var vise_gris: bool = p == "vote_maire" and _vivant() and _vise_bouille >= 0 and _vise_bouille != _vote_cible \
			and _vise_bouille != _moi_id() and bouilles.has(_vise_bouille) and _est_vivant(_vise_bouille)
	_fleche_grise.visible = vise_gris
	if voir:
		var b: Bouille = bouilles[_vote_cible]
		var ou := b.global_position + Vector3(0, 2.15 + sin(_t * 2.2) * 0.04, 0)
		for m: Node3D in [_marque_vote, _marque_couronne]:
			m.global_position = ou
			m.rotation.y = _t * 1.4
	if vise_gris:
		_fleche_grise.global_position = (bouilles[_vise_bouille] as Bouille).global_position + Vector3(0, 2.15 + sin(_t * 2.2) * 0.04, 0)
		_fleche_grise.rotation.y = _t * 1.4


func _fabriquer_crane() -> Node3D:
	var n := Node3D.new()
	var os_ := Bouille.materiau(Color(0.92, 0.89, 0.8), 0.0, Color(0.35, 0.33, 0.28))
	var noir := Bouille.materiau(Color(0.02, 0.02, 0.02), 0.0)
	var crane := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.11
	s.height = 0.2
	crane.mesh = s
	crane.material_override = os_
	n.add_child(crane)
	var machoire := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.06, 0.1)
	machoire.mesh = bm
	machoire.material_override = os_
	machoire.position = Vector3(0, -0.1, 0.02)
	n.add_child(machoire)
	for x: float in [-0.042, 0.042]:
		var oeil := MeshInstance3D.new()
		var so := SphereMesh.new()
		so.radius = 0.032
		so.height = 0.05
		oeil.mesh = so
		oeil.material_override = noir
		oeil.position = Vector3(x, -0.005, 0.088)
		n.add_child(oeil)
	var nez := MeshInstance3D.new()
	var sn := SphereMesh.new()
	sn.radius = 0.014
	sn.height = 0.03
	nez.mesh = sn
	nez.material_override = noir
	nez.position = Vector3(0, -0.05, 0.1)
	n.add_child(nez)
	for x: float in [-0.03, -0.01, 0.01, 0.03]:
		var dent := MeshInstance3D.new()
		var bd := BoxMesh.new()
		bd.size = Vector3(0.006, 0.03, 0.004)
		dent.mesh = bd
		dent.material_override = noir
		dent.position = Vector3(x, -0.095, 0.072)
		n.add_child(dent)
	for m: MeshInstance3D in n.get_children():
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


## Une flèche qui pointe vers le bas, au-dessus d'une tête : grise (je vise), verte (mon vote).
func _fabriquer_fleche(couleur: Color, lueur: Color) -> Node3D:
	var n := Node3D.new()
	var mat := Bouille.materiau(couleur, 0.0, lueur)
	var pointe := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.13
	c.bottom_radius = 0.0
	c.height = 0.22
	pointe.mesh = c
	pointe.material_override = mat
	pointe.position = Vector3(0, 0.0, 0)
	n.add_child(pointe)
	var hampe := MeshInstance3D.new()
	var h := CylinderMesh.new()
	h.top_radius = 0.045
	h.bottom_radius = 0.045
	h.height = 0.2
	hampe.mesh = h
	hampe.material_override = mat
	hampe.position = Vector3(0, 0.21, 0)
	n.add_child(hampe)
	for m: MeshInstance3D in n.get_children():
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


## Les loups ont trouvé le condamné : un cri dans la nuit, la pierre se tache, les chaînes tombent.
func _sur_devore(id: int) -> void:
	ronde.attacher(false)
	ronde.tacher(true)
	_jouer2d("cri", -3.0)
	if bouilles.has(id):
		(bouilles[id] as Bouille).couche = false


## Le condamné, couché sur la dalle, les pieds vers l'ouest : on pose son corps à chaque image
## (par-dessus la position reçue du réseau), pour tous ceux qui le voient.
func _poser_attache() -> void:
	var a: int = meneur.pub.get("attache", -1)
	var lie: bool = meneur.pub.get("attache_lie", false)
	for id in bouilles:
		var b: Bouille = bouilles[id]
		var oui: bool = id == a and lie
		if oui:
			b.assis = false
			b.couche = true
			b.global_transform = Transform3D(Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)), Ronde.PIERRE + Vector3(-0.95, Ronde.PIERRE_HAUT + 0.12, 0))
		elif b.couche:
			b.couche = false
			b.global_basis = Basis.IDENTITY


func _panneau_successeur() -> void:
	var l := []
	for id in _vivants_autres():
		l.append([_etiquette(id), func(): _envoyer_intention("successeur", id)])
	ecran.panneau("Ton successeur", "Tu meurs, maire. Qui portera l'écharpe après toi ?", l, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _de_jour() -> bool:
	return _phase() in Meneur.PHASES_JOUR


## Ma quête du jour, ou {} : {jeu, nom, niveau, inscrits, etat, zone…}.
func _ma_quete() -> Dictionary:
	for q in meneur.pub.get("quetes", []):
		if (q["inscrits"] as Array).has(_moi_id()):
			return q
	return {}


## Le tableau, les panneaux des clairières et les portails suivent l'état des quêtes.
func _maj_quetes(pub: Dictionary) -> void:
	var p: String = pub.get("phase", "salon")
	var quetes: Array = pub.get("quetes", []) if p != "choix_maire" else pub.get("propositions", [])
	ronde.regler_tableau(quetes if p not in ["salon"] else [], pub.get("indices", []), p == "choix_maire")
	_maj_portails(pub)
	_maj_vote_quete(pub)
	if _au_poste() and _carnet.visible:
		_carnet_fermer()
	if _inventaire != null and _vue_objets != null:
		_maj_inventaire()
	_preparer_decor(pub)
	if _monde_quete != null:
		# Le choix du rôle (zone lumineuse au sol) vit tant que la quête est à l'état « role ».
		var mq := _ma_quete()
		_monde_quete.regler_role(mq.get("role", {}) if mq.get("etat", "") == "role" else {}, int(mq.get("zone", 0)))


## Le décor de ma quête se pose dès le départ : en arrivant, tout est déjà là (avant, il
## n'apparaissait qu'au début du jeu, et la clairière restait vide le temps d'attendre l'équipe).
func _preparer_decor(pub: Dictionary) -> void:
	var q0 := _ma_quete()
	if _monde_quete != null and not _vue_quete.visible and q0.get("etat", "") not in ["trajet", "role", "jeu"]:
		_cacher_vue_quete()   # quête annulée en route : on retire le décor posé d'avance
	if _monde_quete != null or not _vivant():
		return
	for q in pub.get("quetes", []):
		var inscrits: Array = q["inscrits"]
		if q["etat"] in ["trajet", "role"] and inscrits.has(_moi_id()):
			_monde_quete = MondeQuete.new()
			_monde_quete.camera = camera
			_monde_quete.geste.connect(func(d): _envoyer_intention("jeu", d))
			add_child(_monde_quete)
			_monde_quete.preparer(str(q["jeu"]), int(q["zone"]), inscrits.find(_moi_id()), inscrits.size(), str(q.get("niveau", "")))


## Les portails des clairières : ouverts pendant l'aller et le retour, fermés pendant le jeu. Une
## fois entré dans la clairière, on n'en ressort plus avant la fin de sa quête (Edwin, 29/10).
func _maj_portails(pub: Dictionary) -> void:
	var p: String = pub.get("phase", "salon")
	var ma: int = (pub.get("en_quete", {}) as Dictionary).get(_moi_id(), -1)
	var dedans := _dans_la_clairiere()
	for k in Quetes.ANGLES_ZONES.size():
		var etat := ""
		if p == "quete":
			for q in pub.get("quetes", []):
				if q["zone"] == k and q["etat"] in ["trajet", "role", "jeu", "retour"]:
					etat = q["etat"]
		var passe := ma == k and (etat == "retour" or (etat == "trajet" and not dedans))
		ronde.regler_portail(k, etat in ["trajet", "retour"], passe)


## La consigne du choix du rôle (« Marcheur »…) : se mettre dans la zone lumineuse, sinon le hasard.
func _invite_role() -> String:
	var info: Dictionary = _ma_quete().get("role", {})
	var nom := str(info.get("nom", "rôle")).to_lower()
	if int(info.get("elu", -1)) >= 0:
		return Langue.t("%s : %s. Rejoins ton poste…") % [Langue.t(nom.capitalize()), Langue.t(str(info.get("elu_nom", "?")))]
	var reste := int(ceil(_monde_quete.reste_role())) if _monde_quete != null else int(ceil(float(info.get("reste", 0.0))))
	return Langue.t("Qui sera le %s ? Entre dans la zone lumineuse, à gauche, pour l'être. Sinon le hasard décide dans %d s.") % [Langue.t(nom.capitalize()).to_lower(), reste]


## En quête (aller compris) dans un jeu qui ne se joue pas à pied : on ne bouge pas de son poste.
func _quete_sur_place() -> bool:
	var q := _ma_quete()
	return not q.is_empty() and q.get("etat", "") in ["trajet", "jeu"] and not Quetes.JEUX_A_PIED.has(str(q.get("jeu", "")))


func _dans_la_clairiere() -> bool:
	if corps_joueur == null:
		return false
	# Passé le portail de sa branche (à R_FOURCHE + 3,2), pas dès la lisière : avant, le portail de
	# sa propre quête se refermait DEVANT l'équipe, qui butait sur un mur invisible.
	var ici := corps_joueur.global_position
	var k := Quetes.zone_proche(ici)
	return Vector2(ici.x, ici.z).length() > Quetes.R_FOURCHE and ici.distance_to(Quetes.zone(k)) < Quetes.LONGUEUR_BRANCHE - 4.7


func _sur_quete_vue(vue: Dictionary) -> void:
	if etape not in ["jeu", "pause"]:
		return
	var neuf := not _vue_quete.visible
	_vue_quete.discret = true
	_vue_quete.afficher(vue)
	if _monde_quete == null:
		_monde_quete = MondeQuete.new()
		_monde_quete.camera = camera
		_monde_quete.geste.connect(func(d): _envoyer_intention("jeu", d))
		add_child(_monde_quete)
	_monde_quete.afficher(vue)
	# Un fantôme vient de me hanter : un souffle glacé, la tête qui vacille.
	var hante: bool = vue.get("hante", false)
	if hante and not _hante_avant:
		_secouer_tete(0.06)
		ecran.message("Un souffle glacé te passe sur les mains…", 2.5)
	_hante_avant = hante
	if neuf:
		ecran.fermer_panneau()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if _auto and not _auto_jeu:
			_auto_jeu = true
			_envoyer_intention("jeu_auto")


func _sur_quete_fin(texte: String, reussie: bool) -> void:
	_cacher_vue_quete()
	ecran.message(texte, 6.0)
	ecran.noter(Langue.t(texte))
	_jouer2d("cloche" if reussie else "glas", -6.0)


## Le marcheur des Lanternes a posé le pied dans l'eau : éclaboussure, bref fondu au noir, et il
## reparaît sur la dernière pierre sûre (l'hôte a déjà retiré la lanterne de vie).
var _fondu_chute: ColorRect


func _sur_chute(pos: Vector3, regard: Vector3) -> void:
	if etape != "jeu" or corps_joueur == null:
		return
	_jouer2d("clapotis", 4.0)
	if _fondu_chute == null:
		_fondu_chute = ColorRect.new()
		_fondu_chute.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fondu_chute.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fondu_chute.color = Color(0.01, 0.03, 0.04, 0.0)
		_vue_quete.get_parent().add_child(_fondu_chute)
		_vue_quete.get_parent().move_child(_fondu_chute, 0)
	_fondu_chute.color.a = 0.0
	var tw := create_tween()
	tw.tween_property(_fondu_chute, "color:a", 1.0, 0.16)
	tw.tween_callback(func():
		_guide.clear()
		_appliquer_placement(pos, regard, "libre"))
	tw.tween_interval(0.25)
	tw.tween_property(_fondu_chute, "color:a", 0.0, 0.55)


func _cacher_vue_quete() -> void:
	if _monde_quete:
		_monde_quete.cacher()
		_monde_quete = null
	if _vue_quete and _vue_quete.visible:
		_vue_quete.cacher()
		if etape == "jeu" and not ecran.panneau_ouvert():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _panneau_trappeur() -> void:
	var l := []
	for id in _vivants_autres():
		l.append([_etiquette(id), func(): _envoyer_intention("trappe", id)])
	ecran.panneau("Ton dernier tir", "Tu meurs. Qui emportes-tu avec toi ?", l)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _faux_bruit() -> void:
	var centre := get_viewport().get_visible_rect().size * 0.5
	var o := camera.project_ray_origin(centre)
	var d := camera.project_ray_normal(centre)
	var q := PhysicsRayQueryParameters3D.create(o, o + d * 30.0, Corps.SANS_JOUEURS)
	q.exclude = [corps_joueur.get_rid()]
	var t := get_world_3d().direct_space_state.intersect_ray(q)
	_envoyer_intention("faux_bruit", t["position"] if t else o + d * 12.0)


# ================================================================ interactions (E)

## L'habitant d'une maison : [pseudo, bandeau]. Son carnet porte les deux (Edwin, 30/10).
func _nom_habitant(maison: int) -> Array:
	var s: Dictionary = meneur.pub.get("sieges", {})
	for id in s:
		if int(s[id].get("maison", -1)) == maison:
			return [str(s[id].get("nom", "")), int(s[id].get("bandeau", -1))]
	return ["", -1]


## Les pseudos de tous les joueurs de la partie, dans l'ordre des bandeaux (pour le sélecteur du carnet).
func _pseudos_de_la_partie() -> Array:
	var s: Dictionary = meneur.pub.get("sieges", {})
	var ids: Array = s.keys()
	ids.sort_custom(func(a, b): return int(s[a].get("bandeau", 0)) < int(s[b].get("bandeau", 0)))
	var r: Array = []
	for id in ids:
		r.append(str(s[id].get("nom", "")))
	return r


func _sur_objets(etat: Array) -> void:
	if _vue_objets == null:
		_vue_objets = VueObjets.new()
		_vue_objets.bouille_de = func(id): return bouilles.get(id, null)
		_vue_objets.proprietaire = _nom_habitant
		var mains := Node3D.new()
		camera.add_child(mains)
		_vue_objets.mes_mains = mains
		_bras_objet_creer(mains)
		add_child(_vue_objets)
		_vue_objets.depose.connect(_sur_depose)
	_vue_objets.moi = _moi_id()
	_vue_objets.maj(etat)
	var etait_ouvert := _carnet.visible
	if _carnet.visible:
		_carnet.maj(_vue_objets.objet(_carnet._id), _moi_id())
		if not _carnet.visible and etait_ouvert and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_maj_inventaire()


## Les quatre emplacements et l'aide de la souris (selon ce que je tiens), pour le HUD.
func _maj_inventaire() -> void:
	if _inventaire == null:
		return
	var slots: Array = [{}, {}, {}, {}]
	var aide := {"gauche": "", "droite": ""}
	if _vue_objets != null and etape == "jeu" and _vivant() and _phase() != "salon" and not _au_poste():
		var ids := _vue_objets.mes_slots()
		for k in Objets.SLOTS:
			if ids[k] >= 0:
				var o := _vue_objets.objet(ids[k])
				slots[k] = {"sorte": o["sorte"], "ouvert": bool(o.get("ouvert", false)), "main": bool(o.get("main", false))}
		var d := _vue_objets.main_decrite()
		aide = Clics.aide(str(d.get("sorte", "")), _carnet != null and _carnet.visible)
	_inventaire.maj(slots, aide, _phase() == "tableau", _slot_courant())


## Suis-je au poste d'un mini-jeu ? L'inventaire est alors masqué et inutilisable (rien à perdre ni à sortir).
func _au_poste() -> bool:
	return (meneur.pub.get("au_poste", []) as Array).has(_moi_id())


## La case choisie : celle de l'objet en main, sinon la case vide qu'on a choisie (mains vides), sinon -1.
func _slot_courant() -> int:
	if _vue_objets != null:
		var id := _vue_objets.en_main()
		if id >= 0:
			_slot_vide_sel = int(_vue_objets.objet(id).get("slot", -1))
	return _slot_vide_sel


## Molette en jeu : la case suivante ou précédente de l'inventaire, en boucle (cases vides comprises).
func _molette_inventaire(sens: int) -> void:
	var cur := _slot_courant()
	_choisir_slot((0 if sens > 0 else Objets.SLOTS - 1) if cur < 0 else Objets.slot_voisin(cur, sens))


## L'inventaire répond-il (touches 1 à 4, molette) ? Mêmes conditions que les chiffres.
func _inventaire_ouvert_au_jeu() -> bool:
	return etape == "jeu" and _vivant() and _phase() not in ["salon", "fin"] and not _au_poste() 			and not _carnet.visible and not ecran.panneau_ouvert() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED 			and _cine_t < 0.0 and Clics.chiffre_pour_inventaire(_phase(), ecran.vote_quete_visible(), _vue_quete != null and _vue_quete.a_des_choix(), _panneau_emotes.visible)


## Touches 1 à 4 : prendre en main l'objet de l'emplacement (la même touche le range).
func _choisir_slot(k: int) -> void:
	if _vue_objets == null:
		return
	if _au_poste():
		return
	_slot_vide_sel = k
	_vise_caillou_t = -1.0
	_envoyer_intention("obj_choisir", k)


## Le stylo écrit tant qu'on tape ; l'hôte le montre aux autres.
func _stylo_ecrit() -> void:
	_plume_t = 0.7
	if not _plume_envoyee:
		_plume_envoyee = true
		_envoyer_intention("obj_plume", true)


func _plume_avancer(delta: float) -> void:
	if not _plume_envoyee:
		return
	_plume_t -= delta
	if _plume_t <= 0.0 or not _carnet.ecriture:
		_plume_envoyee = false
		_envoyer_intention("obj_plume", false)


## Le clic gauche, quand ni une carte, ni le vote n'ont pris la main (cf. regles/clics.gd) :
## accepter une proposition > viser au caillou > fermer le livre ouvert > interagir avec qui on regarde.
func _clic_gauche_objets() -> bool:
	var d := _vue_objets.main_decrite() if _vue_objets else {}
	var sorte := str(d.get("sorte", ""))
	var proposition: bool = _gestes_ui != null and _gestes_ui.proposition_active()
	var cible: bool = _peut_geste() and _cible_geste() >= 0
	var livre: bool = sorte in ["carnet", "page"] and not _au_poste() and _vivant() and _phase() != "salon" and _cine_t < 0.0 and not ecran.panneau_ouvert()
	match Clics.clic_gauche(false, false, proposition, sorte == "caillou" and _peut_viser(), livre, cible):
		"accepter", "interagir":
			_toucher_interagir()
		"viser":
			_vise_caillou_t = Time.get_ticks_msec() / 1000.0
		"carnet":
			if Clics.carnet_gauche(_carnet.visible) == "fermer":
				_carnet_fermer()
			else:
				_carnet_ouvrir(false)
		_:
			return false
	return true


## Le clic droit : lancer le caillou ; avec un carnet ou une page, poser la plume (le carnet fermé
## s'ouvre directement en écriture), un second clic droit la lève.
func _clic_droit_objets() -> void:
	if _vue_objets == null or not _vivant() or _au_poste() or _phase() == "salon" or ecran.panneau_ouvert() or ecran.salon_visible() 			or ecran.fin_visible() or _cine_t >= 0.0:
		return
	var d := _vue_objets.main_decrite()
	match Clics.clic_droit(str(d.get("sorte", "")), _carnet.visible, _carnet.ecriture):
		"lancer":
			_lancer_en_main()
		"ouvrir_ecrire":
			_carnet_ouvrir(true)
		"ecrire":
			_carnet.ecrire(true)
		"lever":
			_carnet.ecrire(false)


## Peut-on viser et lancer ? Vivant, hors nuit et salon, et pas en quête dans une clairière
## (le Conseil et les votes, eux, oui).
func _peut_viser() -> bool:
	if etape != "jeu" or not _vivant() or _cine_t >= 0.0 or _sortie != null or _reussite != null or _carnet.visible:
		return false
	if mode not in ["libre", "assis"] or ecran.panneau_ouvert():
		return false
	return Lancer.peut_lancer(_phase(), true, (meneur.pub.get("en_quete", {}) as Dictionary).has(_moi_id()))


## Clic droit, caillou en main : il part. La force vient du temps passé à viser (clic gauche tenu),
## moyenne si je n'ai pas visé.
func _lancer_en_main() -> void:
	if _au_poste():
		return
	if not _peut_viser():
		ecran.message("Pas maintenant : on ne jette rien ici.", 2.0)
		return
	if _lanc_t >= 0.0:
		return
	var force := Lancer.FORCE_SANS_VISEE
	if _vise_caillou_t >= 0.0:
		force = Lancer.charge(Time.get_ticks_msec() / 1000.0 - _vise_caillou_t)
	_vise_caillou_t = -1.0
	# Le geste d'abord (bras armé en arrière) ; le caillou part au milieu (cf. _lancer_avancer).
	_lanc_force = force
	_lanc_t = 0.0
	_lanc_envoye = false
	moi.jouer_emote("lancer")
	if Reseau.en_ligne and _connecte():
		_emote_rpc.rpc("lancer")


## Essai (--essai-objets=<dossier>) : ramasser des cailloux, remplir l'inventaire, ouvrir et écrire dans
## le livre, viser, lancer, recevoir un coup au corps puis à la tête, et voir un villageois qui tient
## tout ça ; une photo à chaque geste (pour regarder, pas un test).
var _essai_objets := ""
var _essai_vise := false


func _essai_pierre_proche(de: Vector3) -> int:
	var meilleur := -1
	var d_min := 1e9
	for id in _vue_objets._etat:
		var o: Dictionary = _vue_objets._etat[id]
		if o["sorte"] == "caillou" and o["porteur"] == -1:
			var d := (o["pos"] as Vector3).distance_to(de)
			if d < d_min:
				d_min = d
				meilleur = id
	return meilleur


## Essai (--essai-coup=<dossier>) : des cailloux dans le village (vus de près et de loin), un caillou en main (la
## prise de la main), puis un caillou lancé dans la tête d'un villageois (il bascule, des étoiles, « toc »).
var _essai_coup := ""


func _essai_coup_lancer() -> void:
	if _essai_coup == "":
		_essai_coup = "-"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--essai-coup="):
				_essai_coup = a.substr(13)
	if _essai_coup == "-" or etape != "jeu" or _phase() != "tableau" or mode != "libre" or _vue_objets == null:
		return
	var dossier := _essai_coup
	_essai_coup = "-"
	var photo := func(n: String):
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png("%s/coup_%s.png" % [dossier, n])
	var attendre := func(t: float):
		await get_tree().create_timer(t).timeout
	await attendre.call(1.0)
	var sol: Array[int] = meneur.objets.cailloux_au_sol()
	print("[coup] cailloux au sol : ", sol.size())
	# 1. Le village vu comme un joueur qui marche : trois coups d'œil, debout, vers le sol devant soi.
	for k in 3:
		var o: Dictionary = _vue_objets.objet(sol[k * 5])
		var pos: Vector3 = o["pos"]
		var vers := Vector3(-pos.x, 0, -pos.z).normalized()
		_appliquer_placement(pos + vers * 3.2 - Vector3(0, pos.y, 0), pos - Vector3(0, pos.y, 0), "libre")
		tete.rotation.x = -0.28
		await attendre.call(0.6)
		await photo.call("1_village_%d" % k)
	# 2. Un caillou en main, vu en jeu (la prise de la main).
	var pierre := sol[0]
	meneur.objets.prendre(_moi_id(), pierre, meneur.objets.liste[pierre]["pos"])
	meneur._envoyer_objets()
	await attendre.call(0.5)
	if _vue_objets.en_main() < 0:
		_choisir_slot(0)
	_appliquer_placement(Vector3(0, 0, 6.0), Vector3(0, 0, -20), "libre")
	tete.rotation.x = -0.15
	await attendre.call(0.8)
	print("[coup] en main : ", _vue_objets.en_main())
	await photo.call("2_caillou_en_main")
	# 3. Un villageois visé à la tête.
	var cible := -1
	for id in bouilles:
		if id != _moi_id():
			cible = id
			break
	if cible >= 0:
		var devant := -corps_joueur.global_basis.z
		devant.y = 0
		meneur._bots[cible]["pos"] = corps_joueur.global_position + devant.normalized() * 3.0
		meneur._bots[cible]["chemin"] = []
		meneur._bots[cible]["mode"] = "fige"
		await attendre.call(0.4)
		var vers_t: Vector3 = (bouilles[cible] as Bouille).global_position + Vector3(0, Lancer.TETE_Y, 0) - camera.global_position
		tete.rotation.x = asin(vers_t.normalized().y)
		print("[coup] avant le jet, en main : ", _vue_objets.en_main())
		_lancer_en_main()
		for k in 6:
			await attendre.call(0.18)
			get_viewport().get_texture().get_image().save_png("%s/coup_3_tete_%d.png" % [dossier, k])
	print("[coup] fini")
	get_tree().quit()


func _essai_objets_lancer() -> void:
	if _essai_objets == "":
		_essai_objets = "-"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--essai-objets="):
				_essai_objets = a.substr(15)
	if _essai_objets == "-" or etape != "jeu" or _phase() != "tableau" or mode != "libre" or _vue_objets == null:
		return
	var dossier := _essai_objets
	_essai_objets = "-"
	var photo := func(n: String):
		await get_tree().create_timer(0.35).timeout
		get_viewport().get_texture().get_image().save_png("%s/objets_%s.png" % [dossier, n])
	var attendre := func(t: float):
		await get_tree().create_timer(t).timeout
	await attendre.call(1.0)
	print("[objets] cailloux au sol (hôte) : ", meneur.objets.cailloux_au_sol().size())
	# 1. Trois cailloux ramassés, un à un.
	for k in 3:
		var id := _essai_pierre_proche(corps_joueur.global_position)
		var pos: Vector3 = _vue_objets.objet(id)["pos"]
		_appliquer_placement(pos + Vector3(0.9, 0, 0.3) - Vector3(0, pos.y, 0), pos - Vector3(0, pos.y, 0), "libre")
		tete.rotation.x = -0.5
		await attendre.call(0.5)
		var act := _action_possible()
		print("[objets] invite : ", act[0] if not act.is_empty() else "(rien)")
		if not act.is_empty() and (act[1] as Callable).is_valid():
			(act[1] as Callable).call()
		await attendre.call(0.5)
	tete.rotation.x = 0.0
	await photo.call("01_trois_cailloux")
	# 2. Le carnet de ma maison : quatrième emplacement.
	var m := _ma_maison()
	var table := Ronde.table_carnet(m)
	var ici := Ronde.siege_lit(m).lerp(table, 0.35)
	ici.y = 0
	_appliquer_placement(ici, table, "libre")
	tete.rotation.x = -0.55
	await attendre.call(0.5)
	(_action_objet()[1] as Callable).call()
	await attendre.call(0.6)
	tete.rotation.x = 0.0
	await photo.call("02_inventaire_plein_livre_ferme")
	# Un 4e caillou ne se ramasse plus.
	var autre := _essai_pierre_proche(corps_joueur.global_position)
	var pa: Vector3 = _vue_objets.objet(autre)["pos"]
	_appliquer_placement(pa + Vector3(0.9, -pa.y, 0.3), pa - Vector3(0, pa.y, 0), "libre")
	tete.rotation.x = -0.5
	await attendre.call(0.5)
	print("[objets] inventaire plein, invite : ", _action_possible()[0])
	await photo.call("03_plein")
	# 3. Le livre : ouvrir (clic droit), écrire (clic droit), fermer (clic gauche).
	_appliquer_placement(ici, table, "libre")
	tete.rotation.x = 0.0
	await attendre.call(0.4)
	_clic_droit_objets()
	await attendre.call(0.6)
	await photo.call("04_livre_ouvert")
	_clic_droit_objets()
	await attendre.call(0.3)
	_carnet._ecrit.text = "Rosalie ment. Je l'ai vue près du puits avant la nuit."
	_stylo_ecrit()
	_carnet._stylo_2d.ecrire()
	await photo.call("05_j_ecris")
	await attendre.call(0.4)
	_carnet._stylo_2d.ecrire()
	_stylo_ecrit()
	await photo.call("06_j_ecris_encore")
	_lire_objet()
	await attendre.call(0.6)
	_clic_gauche_objets()
	await attendre.call(0.6)
	await photo.call("07_livre_ferme_de_nouveau")
	# 4. Viser puis lancer un caillou (emplacement 1).
	_choisir_slot(0)
	await attendre.call(0.5)
	_appliquer_placement(Vector3(0, 0, 6.0), Vector3(0, 0, -20), "libre")
	tete.rotation.x = 0.1
	_essai_vise = true
	_vise_caillou_t = Time.get_ticks_msec() / 1000.0 - 0.7
	await attendre.call(0.3)
	await photo.call("08_vise")
	_essai_vise = false
	_lancer_en_main()
	await photo.call("09_en_vol")
	await attendre.call(2.0)
	await photo.call("10_retombe")
	# 4 bis. Un jet court vers le sol : le geste (armé, jeté), puis la poussière à l'arrivée.
	_choisir_slot(1)
	await attendre.call(0.4)
	tete.rotation.x = -0.45
	_lancer_en_main()
	await attendre.call(0.1)
	get_viewport().get_texture().get_image().save_png("%s/objets_10a_arme.png" % dossier)
	await attendre.call(0.2)
	get_viewport().get_texture().get_image().save_png("%s/objets_10b_jete.png" % dossier)
	await attendre.call(0.3)
	get_viewport().get_texture().get_image().save_png("%s/objets_10c_vol.png" % dossier)
	await attendre.call(0.25)
	get_viewport().get_texture().get_image().save_png("%s/objets_10d_impact.png" % dossier)
	await attendre.call(0.2)
	get_viewport().get_texture().get_image().save_png("%s/objets_10e_impact_suite.png" % dossier)
	tete.rotation.x = 0.1
	# 5. Un villageois visé : touché au corps, il sursaute.
	var cible := -1
	for id in bouilles:
		if id != _moi_id():
			cible = id
			break
	if cible >= 0:
		var devant := -corps_joueur.global_basis.z
		devant.y = 0
		meneur._bots[cible]["pos"] = corps_joueur.global_position + devant.normalized() * 3.0
		meneur._bots[cible]["chemin"] = []
		meneur._bots[cible]["mode"] = "fige"
		await attendre.call(0.3)
		var vers: Vector3 = (bouilles[cible] as Bouille).global_position + Vector3(0, 1.0, 0) - camera.global_position
		tete.rotation.x = asin(vers.normalized().y)
		_choisir_slot(1)
		await attendre.call(0.4)
		_lancer_en_main()
		await attendre.call(0.2)
		await photo.call("11_bot_touche")
		print("[objets] cailloux au sol (hôte) : ", meneur.objets.cailloux_au_sol().size())
		# 5 bis. Le même villageois visé à la TÊTE : il bascule en arrière, des étoiles tournent, « toc ».
		await attendre.call(1.5)
		var vers_t: Vector3 = (bouilles[cible] as Bouille).global_position + Vector3(0, Lancer.TETE_Y, 0) - camera.global_position
		tete.rotation.x = asin(vers_t.normalized().y)
		_choisir_slot(2)
		await attendre.call(0.4)
		_lancer_en_main()
		await attendre.call(0.37)
		await photo.call("11a_bot_tete_1")
		await attendre.call(0.12)
		await photo.call("11b_bot_tete_2")
		await attendre.call(0.2)
		await photo.call("11c_bot_tete_3")
		await attendre.call(1.0)
	# 6. Coups reçus : au corps (hitmarker), puis à la tête (étoiles + écran noir).
	var src := corps_joueur.global_position + Vector3(2.5, 1.2, -2.5)
	_caillou_arrive(src, corps_joueur.global_position, _moi_id(), "corps")
	await photo.call("12_coup_recu_corps")
	await attendre.call(1.0)
	_caillou_arrive(corps_joueur.global_position + Vector3(-3, 1.2, 0), corps_joueur.global_position, _moi_id(), "tete")
	_sur_geste(_moi_id(), _moi_id(), "yeux", {"duree": Gestes.DUREE_YEUX, "pos": corps_joueur.global_position})
	await photo.call("13_coup_tete")
	await attendre.call(0.4)
	await photo.call("14_coup_tete_noir")
	await attendre.call(1.5)
	# 7. Ce que voient les autres : un villageois qui tient un caillou, puis le livre ouvert qui écrit.
	if cible >= 0:
		var b: Bouille = bouilles[cible]
		var o := meneur.objets
		var pierre := o.cailloux_au_sol()[0]
		o.prendre(cible, pierre, o.liste[pierre]["pos"])
		meneur._envoyer_objets()
		var bp: Vector3 = b.global_position
		var avant: Vector3 = b.global_transform.basis.z
		avant.y = 0
		_appliquer_placement(bp + avant.normalized() * 1.7, bp + Vector3(0, 0, 0), "libre")
		tete.rotation.x = -0.12
		await attendre.call(0.6)
		await photo.call("15_bot_tient_un_caillou")
		var livre := -1
		for id in o.liste:
			if o.liste[id]["sorte"] == "carnet" and o.liste[id]["porteur"] == -1:
				livre = id
				break
		o.liste[livre]["pos"] = o.liste[pierre]["pos"]
		o.prendre(cible, livre, o.liste[livre]["pos"])
		o.ouvrir(cible, true)
		meneur._envoyer_objets()
		await attendre.call(0.6)
		await photo.call("16_bot_livre_ouvert")
		o.plume(cible, true)
		meneur._envoyer_objets()
		await attendre.call(0.5)
		await photo.call("17_bot_ecrit")
		await attendre.call(0.12)
		await photo.call("18_bot_ecrit_suite")
	print("[objets] fini")
	get_tree().quit()


## Essai (--essai-ui=<dossier> avec --essai-jeu=runes) : pendant une quête, parchemin en main, ouvre la pause
## puis F10 : le menu doit passer DEVANT le parchemin et rester cliquable (photos + calques imprimés).
var _essai_ui := ""


func _essai_ui_lancer() -> void:
	if _essai_ui == "":
		_essai_ui = "-"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--essai-ui="):
				_essai_ui = a.substr(11)
	if _essai_ui == "-" or etape != "jeu" or _monde_quete == null or _monde_quete._parchemin == null:
		return
	var dossier := _essai_ui
	_essai_ui = "-"
	var photo := func(n: String):
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png("%s/ui_%s.png" % [dossier, n])
	await get_tree().create_timer(5.0).timeout
	await photo.call("1_parchemin")
	_aller("pause")
	await photo.call("2_pause")
	var bouton: Control = null
	for c in _panneau_pause.find_children("*", "Button", true, false):
		bouton = c as Control
		break
	var centre := bouton.get_global_rect().get_center() if bouton else Vector2.ZERO
	print("[ui] parchemin layer=%d ; pause layer=%d ; bouton de pause au centre %s ; sous la souris : %s" % [
		_monde_quete._parchemin.layer, _ui.layer, centre, bouton != null and bouton.is_visible_in_tree()])
	_aller("jeu")
	await get_tree().create_timer(0.4).timeout
	_basculer_panneau_test()
	await photo.call("3_f10")
	var calque: CanvasLayer = _panneau_test.get_parent() as CanvasLayer
	print("[ui] F10 layer=%d (parchemin %d)" % [calque.layer if calque else -1, _monde_quete._parchemin.layer])
	print("[ui] fini")
	get_tree().quit()


## Essai à deux jeux (--essai-reseau-objets=<dossier>) : l'hôte prend son carnet et le pose dehors ;
## l'invité le voit au sol (photo), s'approche et le ramasse ; l'hôte constate qu'il a été repris.
var _essai_rz := ""


func _essai_reseau_objets_lancer() -> void:
	if _essai_rz == "":
		_essai_rz = "-"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--essai-reseau-objets="):
				_essai_rz = a.substr(22)
	if _essai_rz == "-" or etape != "jeu" or _phase() != "tableau" or mode != "libre" or _vue_objets == null:
		return
	var dossier := _essai_rz
	_essai_rz = "-"
	var attendre := func(t: float):
		await get_tree().create_timer(t).timeout
	var au_sol := func() -> int:
		for i in _vue_objets._etat:
			var o: Dictionary = _vue_objets._etat[i]
			if o["porteur"] == -1 and o["sorte"] == "carnet" and (o["pos"] as Vector3).y < 0.3:
				return i
		return -1
	if meneur.est_hote():
		await attendre.call(1.0)
		var m := _ma_maison()
		var table := Ronde.table_carnet(m)
		var ici := Ronde.siege_lit(m).lerp(table, 0.35)
		ici.y = 0
		_appliquer_placement(ici, table, "libre")
		tete.rotation.x = -0.55
		await attendre.call(0.6)
		(_action_objet()[1] as Callable).call()
		await attendre.call(0.6)
		var dehors := Ronde.devant_porte(m, "avant")
		dehors.y = 0
		_appliquer_placement(dehors, Ronde.centre_maison(m), "libre")
		tete.rotation.x = -0.6
		await attendre.call(0.8)
		_poser_objet()
		await attendre.call(1.0)
		var id: int = au_sol.call()
		print("[reseau] hôte : carnet posé id=%d pos=%s" % [id, _vue_objets.objet(id).get("pos", "?")])
		for k in 40:
			await attendre.call(0.5)
			if id >= 0 and int(meneur.objets.liste[id]["porteur"]) != -1:
				print("[reseau] hôte : le carnet a été ramassé par %d (invité=%s)" % [int(meneur.objets.liste[id]["porteur"]), int(meneur.objets.liste[id]["porteur"]) != 1])
				break
		get_tree().create_timer(3.0).timeout.connect(func(): get_tree().quit())
	else:
		var id := -1
		for k in 80:
			await attendre.call(0.5)
			id = au_sol.call()
			if id >= 0:
				break
		if id < 0:
			print("[reseau] invité : aucun carnet au sol vu")
			get_tree().quit()
			return
		var pos: Vector3 = _vue_objets.objet(id)["pos"]
		print("[reseau] invité : voit le carnet au sol id=%d pos=%s" % [id, pos])
		_appliquer_placement(pos + Vector3(0.7, -pos.y, 0.4), pos, "libre")
		tete.rotation.x = -0.7
		await attendre.call(0.8)
		get_viewport().get_texture().get_image().save_png("%s/reseau_invite_voit.png" % dossier)
		var act := _action_possible()
		print("[reseau] invité : invite = ", act[0] if not act.is_empty() else "(rien)")
		if not act.is_empty() and (act[1] as Callable).is_valid():
			(act[1] as Callable).call()
		await attendre.call(1.0)
		print("[reseau] invité : en main = %d (attendu %d)" % [_vue_objets.en_main(), id])
		get_viewport().get_texture().get_image().save_png("%s/reseau_invite_repris.png" % dossier)
		await attendre.call(4.0)
		get_tree().quit()


## Essai à deux jeux (--essai-reseau-carnet=<dossier>) : l'hôte prend son carnet, écrit (une page libre et
## une correction sur la page des bandeaux, plume levée = envoi), le pose dehors ; l'invité le ramasse,
## l'ouvre en lecture et lit les mêmes pages.
var _essai_rc := ""


func _essai_reseau_carnet_lancer() -> void:
	if _essai_rc == "":
		_essai_rc = "-"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--essai-reseau-carnet="):
				_essai_rc = a.substr(22)
	if _essai_rc == "-" or etape != "jeu" or _phase() != "tableau" or mode != "libre" or _vue_objets == null:
		return
	var dossier := _essai_rc
	_essai_rc = "-"
	var attendre := func(t: float):
		await get_tree().create_timer(t).timeout
	var au_sol := func() -> int:
		for i in _vue_objets._etat:
			var o: Dictionary = _vue_objets._etat[i]
			if o["porteur"] == -1 and o["sorte"] == "carnet" and (o["pos"] as Vector3).y < 0.3:
				return i
		return -1
	if meneur.est_hote():
		await attendre.call(1.0)
		var m := _ma_maison()
		var table := Ronde.table_carnet(m)
		var ici := Ronde.siege_lit(m).lerp(table, 0.35)
		ici.y = 0
		_appliquer_placement(ici, table, "libre")
		tete.rotation.x = -0.55
		await attendre.call(0.6)
		(_action_objet()[1] as Callable).call()
		await attendre.call(0.6)
		_clic_droit_objets()          # carnet fermé : s'ouvre en écriture
		await attendre.call(0.4)
		print("[rc] hôte : visible=%s ecriture=%s page=%d/%d" % [_carnet.visible, _carnet.ecriture, _carnet._page + 1, _carnet._nb_pages])
		_carnet._ecrit.text = _carnet._ecrit.text.replace("rouge", "ROUGE (corrigé)")
		_carnet.tourner(1)
		_carnet._ecrit.text = "Rosalie ment. Je l'ai vue près du puits."
		_carnet.ecrire(false)          # plume levée : envoi à l'hôte
		await attendre.call(0.5)
		_clic_gauche_objets()          # referme
		await attendre.call(0.5)
		var dehors := Ronde.devant_porte(m, "avant")
		dehors.y = 0
		_appliquer_placement(dehors, Ronde.centre_maison(m), "libre")
		tete.rotation.x = -0.6
		await attendre.call(0.8)
		_poser_objet()
		await attendre.call(1.0)
		var id: int = au_sol.call()
		var pg: Array = meneur.objets.liste[id]["pages"] if id >= 0 else []
		print("[rc] hôte : carnet posé id=%d, page1=%s | page2=%s" % [id, str(pg[0]).split("\n")[0] if pg.size() > 0 else "?", pg[1] if pg.size() > 1 else "?"])
		for k in 40:
			await attendre.call(0.5)
			if id >= 0 and int(meneur.objets.liste[id]["porteur"]) != -1:
				break
		await attendre.call(4.0)
		get_tree().quit()
	else:
		var id := -1
		for k in 80:
			await attendre.call(0.5)
			id = au_sol.call()
			if id >= 0 and str((_vue_objets.objet(id)["pages"] as Array)[1]) != "":
				break
		if id < 0:
			print("[rc] invité : aucun carnet au sol vu")
			get_tree().quit()
			return
		var pos: Vector3 = _vue_objets.objet(id)["pos"]
		_appliquer_placement(pos + Vector3(0.7, -pos.y, 0.4), pos, "libre")
		tete.rotation.x = -0.7
		await attendre.call(0.8)
		var act := _action_possible()
		if not act.is_empty() and (act[1] as Callable).is_valid():
			(act[1] as Callable).call()
		await attendre.call(1.0)
		_clic_gauche_objets()
		await attendre.call(0.6)
		print("[rc] invité : lecture visible=%s ecriture=%s" % [_carnet.visible, _carnet.ecriture])
		print("[rc] invité : page 1 = %s" % _carnet._ecrit.text.split("\n")[0])
		get_viewport().get_texture().get_image().save_png("%s/rc_invite_page1.png" % dossier)
		_carnet.tourner(1)
		await attendre.call(0.4)
		print("[rc] invité : page 2 = %s" % _carnet._ecrit.text)
		get_viewport().get_texture().get_image().save_png("%s/rc_invite_page2.png" % dossier)
		await attendre.call(3.0)
		get_tree().quit()


## Essai (--essai-bras=<dossier>) : combien de bras voit-on quand on tient quelque chose ? Le carnet puis un caillou,
## de mes yeux (immobile, en marchant, en courant), puis un villageois qui tient les deux, vu de dehors.
var _essai_bras := ""


func _essai_bras_lancer() -> void:
	if _essai_bras == "":
		_essai_bras = "-"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--essai-bras="):
				_essai_bras = a.substr(13)
	if _essai_bras == "-" or etape != "jeu" or _phase() != "tableau" or mode != "libre" or _vue_objets == null:
		return
	var dossier := _essai_bras
	_essai_bras = "-"
	_auto = false      # le pilote automatique a mené jusqu'ici ; la suite, c'est l'essai qui la conduit
	var photo := func(n: String, t := 0.0):
		await get_tree().create_timer(t).timeout
		get_viewport().get_texture().get_image().save_png("%s/bras_%s.png" % [dossier, n])
	var attendre := func(t: float):
		await get_tree().create_timer(t).timeout
	var touche := func(code: int, oui: bool):
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = oui
		Input.parse_input_event(ev)
	await attendre.call(1.0)
	print("[bras] cailloux : ", meneur.objets.cailloux_au_sol().size(), " ; moi ", corps_joueur.global_position)
	var id := _essai_pierre_proche(corps_joueur.global_position)
	var pos: Vector3 = _vue_objets.objet(id)["pos"]
	_appliquer_placement(pos + Vector3(0.9, 0, 0.3) - Vector3(0, pos.y, 0), pos - Vector3(0, pos.y, 0), "libre")
	tete.rotation.x = -1.0
	await attendre.call(0.5)
	print("[bras] caillou ", id, " en ", pos, " ; action : ", _action_possible())
	if not _action_possible().is_empty() and (_action_possible()[1] as Callable).is_valid():
		(_action_possible()[1] as Callable).call()
	await attendre.call(0.5)
	var m := _ma_maison()
	var table := Ronde.table_carnet(m)
	var ici := Ronde.siege_lit(m).lerp(table, 0.35)
	ici.y = 0
	_appliquer_placement(ici, table, "libre")
	tete.rotation.x = -0.55
	await attendre.call(0.5)
	(_action_objet()[1] as Callable).call()
	await attendre.call(0.6)
	var dehors := Ronde.devant_porte(m, "avant")
	dehors.y = 0
	_appliquer_placement(dehors, dehors + (dehors - Ronde.centre_maison(m)).normalized() * 20.0, "libre")
	for sorte: Array in [["carnet", 1], ["caillou", 0]]:
		if str(_vue_objets.main_decrite().get("sorte", "")) != str(sorte[0]):
			_choisir_slot(int(sorte[1]))
		await attendre.call(0.6)
		print("[bras] en main : ", _vue_objets.main_decrite(), " bras visible=", _bras_objet.visible)
		for inc: float in [0.0, -1.1]:
			tete.rotation.x = inc
			await photo.call("%s_%s_immobile" % [sorte[0], "droit" if inc == 0.0 else "bas"], 0.3)
		tete.rotation.x = -1.0
		await touche.call(KEY_Z, true)
		await attendre.call(1.2)
		for k in 3:
			await photo.call("%s_marche_%d" % [sorte[0], k], 0.17)
		await touche.call(KEY_SHIFT, true)
		await attendre.call(1.0)
		for k in 3:
			await photo.call("%s_course_%d" % [sorte[0], k], 0.15)
		await touche.call(KEY_SHIFT, false)
		await touche.call(KEY_Z, false)
		await attendre.call(0.3)
	# Vu de dehors : un villageois tient le carnet puis le caillou.
	var bot := -1
	for b in bouilles:
		bot = int(b)
		break
	if bot >= 0:
		for sorte: String in ["carnet", "caillou"]:
			for oid in _vue_objets._etat:
				var o: Dictionary = _vue_objets._etat[oid]
				if o["sorte"] == sorte and o["porteur"] == _moi_id():
					o["porteur"] = bot
					o["main"] = true
					_vue_objets._ranger(oid)
					_vue_objets._maj_porteurs()
			var bb: Bouille = bouilles[bot]
			for v: Array in [["face", Vector3(0, 0, 1.8)], ["cote", Vector3(1.8, 0, 0.2)]]:
				var devant := bb.global_position + bb.global_basis * (v[1] as Vector3)
				devant.y = bb.global_position.y
				_appliquer_placement(devant, bb.global_position, "libre")
				tete.rotation.x = 0.05
				await photo.call("dehors_%s_%s" % [sorte, v[0]], 0.4)
	print("[bras] fini")
	get_tree().quit()


## Essai (--essai-poser=<dossier>) : prendre le carnet, le poser dehors (trois photos du geste), le voir au sol,
## le reprendre, le jeter (il vole, retombe, se voit), puis la même chose dans la maison, et une page.
var _essai_poser := ""
var _essai_pas := ""
var _essai_pas_obj: EssaiPas = null


func _essai_poser_lancer() -> void:
	if _essai_poser == "":
		_essai_poser = "-"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--essai-poser="):
				_essai_poser = a.substr(14)
	if _essai_poser == "-" or etape != "jeu" or _phase() != "tableau" or mode != "libre" or _vue_objets == null:
		return
	var dossier := _essai_poser
	_essai_poser = "-"
	var photo := func(n: String, t := 0.0):
		await get_tree().create_timer(t).timeout
		get_viewport().get_texture().get_image().save_png("%s/poser_%s.png" % [dossier, n])
	var attendre := func(t: float):
		await get_tree().create_timer(t).timeout
	var etat := func(quoi: String):
		var id: int = _vue_objets.en_main()
		var tout := []
		for i in _vue_objets._etat:
			var o: Dictionary = _vue_objets._etat[i]
			if o["porteur"] == -1 and (o["pos"] as Vector3).y < 1.0 and (o["pos"] as Vector3).distance_to(corps_joueur.global_position) < 6.0:
				var n: Node3D = _vue_objets._noeuds[i]
				tout.append("%s#%d pos=%s nœud=%s visible=%s" % [o["sorte"], i, o["pos"], n.global_position if n.is_inside_tree() else "hors arbre", n.is_visible_in_tree()])
		print("[poser] %s : en main=%d ; posés : %s" % [quoi, id, tout.slice(0, 3)])
	# On regarde le carnet posé le plus proche (la touche n'apparaît qu'en le visant, Edwin 01/11).
	var viser_carnet := func():
		for i in _vue_objets._etat:
			var pp: Vector3 = _vue_objets._etat[i]["pos"]
			if _vue_objets._etat[i]["porteur"] == -1 and _vue_objets._etat[i]["sorte"] == "carnet" and pp.distance_to(corps_joueur.global_position) < 3.0:
				_appliquer_placement(corps_joueur.global_position, pp, "libre")
				var v := pp - camera.global_position
				tete.rotation.x = -atan2(-v.y, Vector2(v.x, v.z).length())
		await get_tree().create_timer(0.2).timeout
	await attendre.call(1.0)
	var m := _ma_maison()
	var table := Ronde.table_carnet(m)
	var ici := Ronde.siege_lit(m).lerp(table, 0.35)
	ici.y = 0
	_appliquer_placement(ici, table, "libre")
	tete.rotation.x = -0.55
	await attendre.call(0.6)
	(_action_objet()[1] as Callable).call()
	await attendre.call(0.6)
	# Dehors : à 3 m de la porte, face à la maison.
	var dehors := Ronde.devant_porte(m, "avant")
	dehors.y = 0
	_appliquer_placement(dehors, Ronde.centre_maison(m), "libre")
	tete.rotation.x = -0.6
	await attendre.call(0.8)
	_poser_objet()
	await photo.call("1a_geste", 0.1)
	await photo.call("1b_geste", 0.2)
	await photo.call("1c_geste", 0.2)
	await photo.call("1d_au_sol", 1.0)
	etat.call("dehors, posé")
	tete.rotation.x = -0.75
	await attendre.call(0.4)
	await viser_carnet.call()
	var act := _action_possible()
	print("[poser] invite : ", act[0] if not act.is_empty() else "(rien)")
	if not act.is_empty() and (act[1] as Callable).is_valid():
		(act[1] as Callable).call()
	await attendre.call(0.5)
	etat.call("dehors, repris")
	await photo.call("2_repris", 0.2)
	# Jeter : le carnet vole, retombe, reste visible.
	var loin := dehors + (dehors - Ronde.centre_maison(m)).normalized() * 6.0
	_appliquer_placement(dehors, loin, "libre")
	tete.rotation.x = 0.1
	await attendre.call(0.4)
	_lancer_en_main()
	await photo.call("3a_jet", 0.3)
	await photo.call("3b_vol", 0.2)
	await photo.call("3c_retombe", 1.8)
	etat.call("jeté")
	# Le retrouver : on avance vers lui.
	var cible := Vector3.ZERO
	for i in _vue_objets._etat:
		if _vue_objets._etat[i]["porteur"] == -1 and _vue_objets._etat[i]["sorte"] == "carnet" and (_vue_objets._etat[i]["pos"] as Vector3).y < 0.3:
			cible = _vue_objets._etat[i]["pos"]
	_appliquer_placement(cible + Vector3(0.7, -cible.y, 0.4), cible, "libre")
	await attendre.call(0.4)
	await viser_carnet.call()
	act = _action_possible()
	print("[poser] invite après jet : ", act[0] if not act.is_empty() else "(rien)")
	await photo.call("4_jete_vu_de_pres", 0.2)
	if not act.is_empty() and (act[1] as Callable).is_valid():
		(act[1] as Callable).call()
	await attendre.call(0.5)
	etat.call("jeté puis repris")
	# Dans la maison : sur le sol.
	_appliquer_placement(ici, Ronde.siege_lit(m), "libre")
	tete.rotation.x = -0.9
	await attendre.call(0.6)
	_poser_objet()
	await photo.call("5a_maison_geste", 0.25)
	await photo.call("5b_maison_sol", 1.0)
	etat.call("maison, posé")
	# Jeté sur le lit : il reste dessus (Edwin, 01/11 : il traversait le lit).
	await viser_carnet.call()
	act = _action_objet()
	if not act.is_empty() and (act[1] as Callable).is_valid():
		(act[1] as Callable).call()
	await attendre.call(0.6)
	_appliquer_placement(ici, Ronde.siege_lit(m), "libre")
	tete.rotation.x = -0.25
	_lanc_force = 0.12
	await attendre.call(0.4)
	print("[poser] avant le jet : moi ", corps_joueur.global_position, " lit ", Ronde._vers_monde(m, Vector3(1.4, 0.25, -0.6)), " en main ", _vue_objets.en_main())
	_lancer_en_main()
	await attendre.call(1.6)
	tete.rotation.x = -0.75
	await photo.call("6_sur_le_lit", 0.6)
	etat.call("jeté sur le lit")
	print("[poser] fini")
	get_tree().quit()


## À chaque image : le stylo, la visée (jauge, courbe, main qui se recule).
## Ma main et mon avant-bras, vus de mes yeux, qui tiennent l'objet en main : debout, assis, au vote, partout
## (sinon l'objet flotte quand le corps ne montre pas ses bras). Même style que les mains de la transformation.
var _bras_objet: Node3D
var _bras_peau: StandardMaterial3D
var _bras_pos := Vector3(0.2, -0.25, -0.5)
var _pose_t := -1.0                   # depuis quand je pose l'objet (le bras descend au sol), -1 : non
var _lanc_t := -1.0                   # depuis quand je lance (-1 : non) : armer, puis le caillou part à 0,2 s
var _lanc_force := 0.5
var _lanc_envoye := false


func _bras_objet_creer(mains: Node3D) -> void:
	var peau_c: Color = Bouille.PEAUX[int(moi.apparence.get("peau", 0))] if is_instance_valid(moi) else Bouille.PEAUX[0]
	var teinte: Color = Bouille.TEINTES[int(moi.apparence.get("teinte", 0))] if is_instance_valid(moi) else Color(0.17, 0.13, 0.1)
	var manche: Color = teinte.lerp(Color(0.62, 0.58, 0.52), 0.55)
	if is_instance_valid(moi):
		manche = moi.couleur_manche()      # la manche du corps, lue sur la tenue : les deux bras restent assortis
	_bras_objet = MainTenue.creer(peau_c, manche)
	_bras_objet.visible = false
	mains.add_child(_bras_objet)


## Pose le bras sous l'objet en main (ou le cache s'il n'y en a pas) ; appelé à chaque image.
func _bras_objet_avancer() -> void:
	if _bras_objet == null or _vue_objets == null:
		return
	# Un fantôme qui tient un caillou : même bras, même prise que celui d'un vivant.
	if is_instance_valid(_caillou_main) and etape == "jeu":
		_bras_objet.visible = true
		if is_instance_valid(moi):
			moi.bras_droit_cache = _vue_objets.mes_mains.visible
			moi.tient_objet = true
		MainTenue.generique(_bras_objet, CAILLOU_MAIN_POS)
		return
	var n := _vue_objets.noeud_en_main()
	var tient := n != null and n.visible and n.get_parent() == _vue_objets.mes_mains
	if tient:
		_bras_pos = n.position + Vector3(0.0, -0.045, 0.02)
	# Le jet parti, le caillou n est plus en main : le bras du corps (visible lui aussi) finit le geste.
	var oui := tient and etape == "jeu"
	_bras_objet.visible = oui
	if is_instance_valid(moi):
		# Le bras du corps du même côté s'efface quand celui-ci tient (jamais trois bras), et se lève pour les autres.
		moi.bras_droit_cache = oui and _vue_objets.mes_mains.visible
		moi.tient_objet = tient
	if not oui:
		return
	var decrit: Dictionary = _vue_objets.main_decrite()
	if str(decrit.get("sorte", "")) in ["carnet", "page"]:
		MainTenue.livre(_bras_objet, n, bool(decrit.get("ouvert", false)), Carnet3D.EPAIS)
	else:
		MainTenue.generique(_bras_objet, n.position)


## Le jet en deux temps : le bras s'arme (0,2 s, les autres le voient aussi), puis le caillou part.
func _lancer_avancer(delta: float) -> void:
	if _pose_t >= 0.0:
		_pose_t += delta
		if _pose_t > 0.9:
			_pose_t = -1.0
	if _lanc_t < 0.0:
		return
	_lanc_t += delta
	if not _lanc_envoye and _lanc_t >= 0.2:
		_lanc_envoye = true
		if _lanc_fantome:
			_lacher_caillou_fantome()
		else:
			var dir := -camera.global_basis.z
			_envoyer_intention("obj_lancer", camera.global_position + dir.normalized() * 0.4, [dir, _lanc_force])
	if _lanc_t > 0.7:
		_lanc_t = -1.0
		_lanc_fantome = false


func _objets_avancer(delta: float) -> void:
	_plume_avancer(delta)
	_lancer_avancer(delta)
	_bras_objet_avancer()
	var d := _vue_objets.main_decrite() if _vue_objets else {}
	var caillou: bool = str(d.get("sorte", "")) == "caillou"
	if _vise_caillou_t >= 0.0 and not _essai_vise and (not caillou or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not _peut_viser()):
		_vise_caillou_t = -1.0
	var f := -1.0
	if _vise_caillou_t >= 0.0:
		f = Lancer.charge(Time.get_ticks_msec() / 1000.0 - _vise_caillou_t)
	if _inventaire != null:
		_inventaire.charge(f)
	if _vue_objets != null and _vue_objets.mes_mains != null:
		_vue_objets.mes_mains.visible = not _au_poste()    # au poste d'un mini-jeu, rien en main à l'écran
		var tire := Vector3.ZERO if f < 0.0 else Vector3(0.0, 0.04 * f, 0.12 * f)
		var incline := 0.0
		if _lanc_t >= 0.0:
			var armer := smoothstep(0.0, 0.2, _lanc_t)
			var jeter := smoothstep(0.2, 0.32, _lanc_t)
			var rendre := smoothstep(0.4, 0.6, _lanc_t)
			var k := (armer - jeter) * (1.0 - rendre)
			tire += Vector3(0.05, 0.1, 0.2) * k + Vector3(-0.08, 0.0, -0.38) * jeter * (1.0 - rendre)
			incline = 0.55 * k - 0.6 * jeter * (1.0 - rendre)
		if _pose_t >= 0.0:
			var g := Depose.geste(_pose_t)
			tire += Vector3(0.0, -0.22, -0.18) * g
			incline += 0.7 * g
		_vue_objets.mes_mains.position = _vue_objets.mes_mains.position.lerp(tire, 0.3)
		_vue_objets.mes_mains.rotation.x = lerpf(_vue_objets.mes_mains.rotation.x, incline, 0.35)
	if f < 0.0:
		if _courbe_visee != null:
			_courbe_visee.visible = false
		return
	if _courbe_visee == null:
		_courbe_visee = MeshInstance3D.new()
		_courbe_visee.mesh = ImmediateMesh.new()
		_courbe_visee.top_level = true
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.86, 0.5, 0.8)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_courbe_visee.material_override = m
		_courbe_visee.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_courbe_visee)
	_courbe_visee.visible = true
	var dir := -camera.global_basis.z
	var de := camera.global_position + dir.normalized() * 0.4
	var pts := Lancer.courbe(de, Lancer.v0(dir, f), 0.0, 0.1)
	var im := _courbe_visee.mesh as ImmediateMesh
	im.clear_surfaces()
	if pts.size() >= 2:
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		for k in range(0, pts.size() - 1, 2):
			im.surface_add_vertex(pts[k])
			im.surface_add_vertex(pts[k + 1])
		# Un anneau là où il va retomber.
		var fin := pts[pts.size() - 1]
		for k in 16:
			var a0 := k * TAU / 16.0
			var a1 := (k + 1) * TAU / 16.0
			im.surface_add_vertex(fin + Vector3(cos(a0), 0.03, sin(a0)) * 0.35)
			im.surface_add_vertex(fin + Vector3(cos(a1), 0.03, sin(a1)) * 0.35)
		im.surface_end()


## Un caillou lancé par un joueur vole, chez tout le monde ; à l'arrivée il touche (ou non).
func _sur_caillou_lance(de: Vector3, v0: Vector3, duree: float, fin: Vector3, touche: int, zone: String, objet := -1) -> void:
	# Qui lance ? Celui dont le corps est tout près du départ du caillou (un bot lance sans prévenir : on joue
	# son geste ici ; un humain l'a déjà armé en cliquant).
	var lanceur := _bouille_de_pres(de)
	if lanceur != null and lanceur.emote != "lancer":
		lanceur.jouer_emote("lancer")
	# Un caillou vole comme une pierre ; un carnet ou une page jetés volent tels qu'on les voit au sol.
	var c: Node3D = _vue_objets.apercu(objet) if _vue_objets != null and objet >= 0 else null
	if c == null or c.get_child_count() == 0 or (_vue_objets.objet(objet).get("sorte", "") == "caillou"):
		c = _caillou_mesh(0.07)
		(c.material_override as StandardMaterial3D).emission_enabled = true
		(c.material_override as StandardMaterial3D).emission = Color(0.35, 0.33, 0.3)
	add_child(c)
	c.global_position = de
	var spin := Vector3(_rng.randf_range(10.0, 16.0), _rng.randf_range(-8.0, 8.0), _rng.randf_range(-6.0, 6.0))
	var tw := create_tween()
	tw.tween_method(func(t: float):
		c.global_position = Lancer.point(de, v0, t)
		c.rotation = spin * t, 0.0, maxf(duree, 0.05), maxf(duree, 0.05))
	tw.tween_callback(func():
		c.queue_free()
		_caillou_arrive(de, fin, touche, zone))


## La bouille (la mienne comprise) dont les pieds sont à moins de 1,3 m (à l'horizontale) de ce point, ou null.
func _bouille_de_pres(p: Vector3) -> Bouille:
	var meilleure: Bouille = null
	var dmin := 1.3
	var candidats: Array = bouilles.values()
	candidats.append(moi)
	for b: Bouille in candidats:
		if not is_instance_valid(b):
			continue
		var d := Vector2(b.global_position.x - p.x, b.global_position.z - p.z).length()
		if d < dmin:
			dmin = d
			meilleure = b
	return meilleure


## Poussière, gravillons et éclats à l'endroit où un caillou arrive : `sorte` = "sol", "mur" ou "corps".
func _impact_caillou(pos: Vector3, sorte: String) -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 14 if sorte == "sol" else 10
	p.lifetime = 0.7
	p.direction = Vector3.UP if sorte == "sol" else Vector3(0, 0.4, 0)
	p.spread = 70.0 if sorte == "sol" else 180.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 2.2 if sorte == "sol" else 1.6
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var m := SphereMesh.new()
	m.radius = 0.045 if sorte == "sol" else 0.03
	m.height = m.radius * 2.0
	m.radial_segments = 5
	m.rings = 3
	p.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.45, 0.38) if sorte != "corps" else Color(0.75, 0.7, 0.62)
	mat.roughness = 1.0
	m.material = mat
	add_child(p)
	p.global_position = pos
	p.restart()
	# La petite bouffée de poussière : un halo qui monte et s'efface.
	var nuage := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.12
	s.height = 0.24
	s.radial_segments = 8
	s.rings = 4
	nuage.mesh = s
	var nm := StandardMaterial3D.new()
	nm.albedo_color = Color(0.6, 0.55, 0.47, 0.6)
	nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nuage.material_override = nm
	nuage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(nuage)
	nuage.global_position = pos
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(nuage, "scale", Vector3.ONE * (3.0 if sorte == "sol" else 2.0), 0.6)
	tw.tween_property(nm, "albedo_color:a", 0.0, 0.6)
	tw.tween_property(nuage, "global_position:y", pos.y + 0.25, 0.6)
	tw.chain().tween_callback(func():
		nuage.queue_free()
		p.queue_free())


func _caillou_arrive(de: Vector3, fin: Vector3, touche: int, zone: String) -> void:
	if touche < 0:
		# Au sol : poussière et gravier ; sur un mur (au-dessus du sol) : un choc sec. Le caillou reste ensuite
		# par terre, ramassable (l'hôte le repose).
		var haut: bool = fin.y - Ronde.hauteur_sol(fin) > 0.3
		_impact_caillou(fin, "mur" if haut else "sol")
		_jouer3d("choc" if haut else "caillou", fin, -8.0, false)
		return
	_impact_caillou(fin, "corps")
	var rea := Lancer.reaction(zone)
	_jouer3d(str(rea.get("son", "choc")), fin, -2.0 if zone == "tete" else -8.0, false)
	var b := _bouille_de(touche)
	if b != null:
		if bool(rea.get("etoiles", false)):
			b.coup_tete()                  # la tête part en arrière, des étoiles tournent : tout le monde le voit
		else:
			b.jouer_emote("bouscule")      # le lanceur voit aussi un bot sursauter
	var lanceur := _bouille_de_pres(de)
	if lanceur == moi and touche != _moi_id() and str(rea.get("message_lanceur", "")) != "":
		ecran.message(Langue.t(str(rea["message_lanceur"])), 1.8)
	if touche == _moi_id():
		_secouer_tete(float(rea.get("secousse", 0.07)))
		if float(rea.get("bascule", 0.0)) > 0.0:
			_coup_de_tete_vue(float(rea["bascule"]))
			_jouer2d("toc", -2.0)
			ecran.message(Langue.t(str(rea["message_touche"])), 2.5)
		if _inventaire != null:
			_inventaire.coup(Lancer.angle_depuis(de, corps_joueur.global_position, corps_joueur.rotation.y), zone == "tete")
		# Dans la tête : l'hôte envoie en même temps le geste « yeux », le même que le choc contre un mur
		# (étoiles + une seconde d'écran noir).


## Ma vue est jetée en arrière par le coup, puis revient (sur la caméra : la souris n'y touche pas).
func _coup_de_tete_vue(force: float) -> void:
	var tw := create_tween()
	tw.tween_property(camera, "rotation:x", force * 0.6, 0.07)
	tw.tween_property(camera, "rotation:x", -force * 0.15, 0.25)
	tw.tween_property(camera, "rotation:x", 0.0, 0.25)


## L : ouvrir en lecture ce qu'on tient (le dernier pris), ou le refermer.
func _lire_objet() -> void:
	if _carnet.visible:
		_carnet_fermer()
		return
	_carnet_ouvrir(false)


## Ouvre le carnet (ou la page) tenu : en lecture (aucun curseur, le jeu garde le clavier) ou, avec
## `ecrire`, la plume posée tout de suite.
func _carnet_ouvrir(ecrire: bool) -> void:
	var id := _vue_objets.en_main() if _vue_objets else -1
	if id < 0:
		ecran.message("Tu ne tiens rien à lire. Les carnets sont sur la table de chaque maison.", 3.0)
		return
	var o := _vue_objets.objet(id)
	if o["sorte"] == "caillou":
		ecran.message("Un caillou : clic gauche pour viser, clic droit pour lancer.", 2.5)
		return
	if o["sorte"] == "carnet" and not bool(o.get("ouvert", false)):
		_envoyer_intention("obj_ouvrir", true)
	_carnet.ouvrir(o)
	if ecrire:
		_carnet.ecrire(true)


## Referme le carnet (ou la page) : le texte part chez l'hôte, le livre se ferme dans la main.
func _carnet_fermer() -> void:
	var etait_carnet: bool = _carnet._sorte == "carnet"
	_carnet.fermer()
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and etape == "jeu" and not ecran.panneau_ouvert() and not ecran.salon_visible() 			and not ecran.fin_visible() and not _panneau_volumes.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if etait_carnet and _vue_objets and _vue_objets.en_main() >= 0 and bool(_vue_objets.objet(_vue_objets.en_main()).get("ouvert", false)):
		_envoyer_intention("obj_ouvrir", false)


## La plume se pose : le curseur apparaît, le clavier est au texte. Elle se lève : la souris redevient le regard.
func _sur_ecriture_carnet(oui: bool) -> void:
	if etape != "jeu":
		return
	if oui:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not ecran.panneau_ouvert() and not ecran.salon_visible() and not ecran.fin_visible() and not _panneau_volumes.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## G : lâcher ce qu'on tient là où l'on regarde (une table, le sol), à portée de main.
func _poser_objet() -> void:
	if _vue_objets == null or _vue_objets.en_main() < 0 or not _vivant() or _au_poste():
		return
	var o := camera.global_position
	var d := -camera.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(o, o + d * 2.2, Corps.SANS_JOUEURS)
	q.exclude = [corps_joueur.get_rid()]
	var t := get_world_3d().direct_space_state.intersect_ray(q)
	var ou: Vector3
	if t and (t["normal"] as Vector3).y > 0.6:
		ou = t["position"] + Vector3(0, 0.005, 0)
	else:
		var devant := -corps_joueur.global_basis.z
		devant.y = 0
		ou = corps_joueur.global_position + devant.normalized() * 0.6 + Vector3(0, 0.02, 0)
	_envoyer_intention("obj_poser", ou, corps_joueur.rotation.y)


## Quelqu'un (moi compris) vient de poser ce qu'il tenait : son corps se penche et pose l'objet devant lui.
## (L'objet, lui, tombe de sa main au sol : cf. VueObjets._faire_tomber.)
func _sur_depose(_id: int, porteur: int) -> void:
	var b := _bouille_de(porteur)
	if b != null and is_instance_valid(b) and not b.mort and b.emote != "lancer":
		b.jouer_emote("poser")
	if porteur == _moi_id():
		_pose_t = 0.0


## Ce qu'on peut faire avec les carnets ici : [texte, Callable] ou [].
func _action_objet() -> Array:
	if _vue_objets == null:
		return []
	var tenu := _vue_objets.en_main()
	if tenu >= 0 and _vise_bouille >= 0 and bouilles.has(_vise_bouille) 			and (bouilles[_vise_bouille] as Bouille).global_position.distance_to(corps_joueur.global_position) < 2.6:
		var qui := _vise_bouille
		return ["{agir} : donner %s à %s" % [_vue_objets.nom(tenu), _designer(qui)], func(): _envoyer_intention("obj_donner", qui)]
	# Mesuré à hauteur de table, pas des yeux (Edwin, 31/10 : debout devant la table, rien ne
	# s'affichait) : 1,7 m à l'horizontale suffit, d'où qu'on arrive.
	var yeux := camera.global_position
	# Et seulement si on le REGARDE (Edwin, 01/11) : être à côté ne suffit plus.
	var proche := _vue_objets.proche(Vector3(yeux.x, yeux.y - 0.8, yeux.z), 1.7,
		func(p: Vector3) -> bool: return _vise_gros(p, 2.8, 0.2) and _vu_des_yeux(p))
	if proche >= 0 and _vue_objets.mes_objets().size() < Objets.SLOTS:
		var sorte: String = _vue_objets.objet(proche)["sorte"]
		return [("{agir} : ramasser %s" if sorte == "caillou" else "{agir} : prendre %s") % _vue_objets.nom(proche), func():
			_envoyer_intention("obj_prendre", proche)]
	if proche >= 0:
		return ["Inventaire plein (%d/%d) : lâche ou lance quelque chose pour ramasser %s" % [Objets.SLOTS, Objets.SLOTS, _vue_objets.nom(proche)], Callable()]
	return []


## Rien entre mes yeux et ce point : on ne prend pas un carnet à travers un mur (Edwin, 31/10).
func _vu_des_yeux(cible: Vector3) -> bool:
	var yeux := camera.global_position
	var q := PhysicsRayQueryParameters3D.create(yeux, cible + (yeux - cible).normalized() * 0.08, Corps.SANS_JOUEURS)
	q.exclude = [corps_joueur.get_rid()]
	return corps_joueur.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

# ================================================================ les fantômes

var _caillou_main: Node3D          # le caillou que je tiens (mort), dans ma main ; les autres morts le voient dans la main de mon corps
const CAILLOU_MAIN_POS := Vector3(0.2, -0.2, -0.5)   # comme celui d'un vivant (cf. VueObjets)
var _lanc_fantome := false          # le jet en cours est celui d'un fantôme
var _energie_t := 0.0              # quand l'énergie reçue de l'hôte a été mesurée
var _hante_avant := false


## Mon énergie de fantôme, prolongée depuis le dernier état reçu (elle remonte seule).
func _energie() -> float:
	return minf(1.0, float(_priv("energie", 1.0)) + (Time.get_ticks_msec() / 1000.0 - _energie_t) * Meneur.RECHARGE_FANTOME)


func _action_fantome() -> Array:
	var p := _phase()
	if p in ["salon", "fin"]:
		return []
	var e := _energie()
	var jauge := " · " + Langue.t("énergie %d %%") % int(e * 100)
	if p not in ["nuit", "distribution"] and e >= Meneur.COUT_GRANDE_APPARITION:
		jauge += "   ·   " + Langue.t("%s : apparaître à tous ceux autour") % Options.texte_touches("pouvoir")
	# Un vivant en pleine quête, que je regarde, tout près : je peux le hanter.
	if p == "quete" and _vise_bouille >= 0 and _est_vivant(_vise_bouille) and bouilles.has(_vise_bouille) 			and (bouilles[_vise_bouille] as Bouille).global_position.distance_to(corps_joueur.global_position) < Meneur.PORTEE_HANTER 			and (meneur.pub.get("en_quete", {}) as Dictionary).has(_vise_bouille):
		var qui := _vise_bouille
		if e < Meneur.COUT_HANTER:
			return [Langue.t("Trop faible pour hanter %s") % Langue.t(_designer(qui)) + jauge, Callable()]
		return [Langue.t("{agir} : hanter %s") % Langue.t(_designer(qui)) + jauge, func(): _envoyer_intention("hanter", qui)]
	# Un vivant que je regarde, tout près : lui apparaître une seconde en monstre.
	if p not in ["nuit", "distribution"] and _vise_bouille >= 0 and _est_vivant(_vise_bouille) and bouilles.has(_vise_bouille) \
			and (bouilles[_vise_bouille] as Bouille).global_position.distance_to(corps_joueur.global_position) < Meneur.PORTEE_APPARITION:
		var qui2 := _vise_bouille
		if e < Meneur.COUT_APPARITION:
			return [Langue.t("Trop faible pour apparaître à %s") % Langue.t(_designer(qui2)) + jauge, Callable()]
		return [Langue.t("{agir} : apparaître en monstre devant %s") % Langue.t(_designer(qui2)) + jauge, func(): _envoyer_intention("apparition", qui2)]
	if _caillou_main:
		return [Langue.t("E ou clic : lancer le caillou") + jauge, _lancer_caillou]
	if p != "nuit" and Ronde.maison_de(corps_joueur.global_position) < 0:
		return [Langue.t("{agir} : ramasser un caillou") + jauge, _ramasser_caillou]
	return []


func _caillou_mesh(taille: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = taille
	s.height = taille * 1.5
	s.radial_segments = 7
	s.rings = 4
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.43, 0.4)
	mat.roughness = 1.0
	m.material_override = mat
	return m


func _ramasser_caillou() -> void:
	if _caillou_main:
		return
	_caillou_main = _caillou_mesh(0.035)
	# Dans MA main (celle des vivants, avec son bras et son geste de jet), pas collé à la caméra.
	(_vue_objets.mes_mains if _vue_objets != null and _vue_objets.mes_mains != null else camera).add_child(_caillou_main)
	_caillou_main.position = CAILLOU_MAIN_POS + Vector3(0.0, 0.03, 0.0)
	_jouer2d("caillou", -18.0)
	if Reseau.en_ligne and _connecte():
		_caillou_fantome_rpc.rpc(true)   # les autres morts me voient le tenir


func _lancer_caillou() -> void:
	if _caillou_main == null:
		return
	if _energie() < Meneur.COUT_CAILLOU:
		ecran.message("Trop faible pour lancer : attends que ton énergie remonte.", 2.5)
		return
	if _lanc_t >= 0.0:
		return
	# Le geste d'abord (le bras s'arme, les autres morts le voient) ; le caillou part à 0,2 s (cf. _lancer_avancer).
	_lanc_fantome = true
	_lanc_force = Lancer.FORCE_SANS_VISEE
	_lanc_t = 0.0
	_lanc_envoye = false
	moi.jouer_emote("lancer")
	if Reseau.en_ligne and _connecte():
		_emote_rpc.rpc("lancer")


## Le caillou quitte la main du fantôme : chez lui, et chez les autres morts qui le voyaient dans sa main.
func _lacher_caillou_fantome() -> void:
	if _caillou_main != null:
		_caillou_main.queue_free()
		_caillou_main = null
	if Reseau.en_ligne and _connecte():
		_caillou_fantome_rpc.rpc(false)
	var dir := -camera.global_basis.z + Vector3(0, 0.06, 0)
	_envoyer_intention("caillou", camera.global_position + dir.normalized() * 0.4, dir)


## Un autre fantôme tient (ou lâche) un caillou : les morts le voient dans sa main droite.
@rpc("any_peer", "call_remote", "reliable")
func _caillou_fantome_rpc(oui: bool) -> void:
	var qui := multiplayer.get_remote_sender_id()
	if not bouilles.has(qui):
		return
	var b: Bouille = bouilles[qui]
	if b.has_meta("caillou_main"):
		var ancien: Variant = b.get_meta("caillou_main")
		if ancien is Node and is_instance_valid(ancien):
			(ancien as Node).queue_free()
		b.remove_meta("caillou_main")
	b.tient_objet = oui
	if oui:
		var c := _caillou_mesh(0.045)
		b.main_droite().add_child(c)
		b.set_meta("caillou_main", c)


## Un caillou vole, chez tout le monde : on ne le voit qu'en vol, pas dans la main du fantôme.
func _sur_caillou(de: Vector3, a: Vector3, touche: int) -> void:
	var c := _caillou_mesh(0.045)
	add_child(c)
	c.global_position = de
	var duree := maxf(de.distance_to(a) / 16.0, 0.08)
	var milieu := (de + a) * 0.5 + Vector3(0, de.distance_to(a) * 0.06, 0)
	var tw := create_tween()
	tw.tween_method(func(t: float): c.global_position = de.lerp(milieu, t).lerp(milieu.lerp(a, t), t), 0.0, 1.0, duree)
	tw.tween_callback(func():
		c.queue_free()
		if touche == _moi_id():
			_jouer2d("caillou", -4.0)
			_secouer_tete(0.09)
			ecran.message("Aïe ! Un caillou… venu de nulle part.", 2.5)
		else:
			_jouer3d("caillou", a, -8.0, false))


## Un choc (caillou, souffle glacé) : la tête vacille un instant.
func _secouer_tete(force: float) -> void:
	var tw := create_tween()
	tw.tween_property(camera, "rotation:z", force, 0.06)
	tw.tween_property(camera, "rotation:z", -force * 0.6, 0.1)
	tw.tween_property(camera, "rotation:z", 0.0, 0.18)


## Ce qu'on peut faire ici ; renvoie [texte, Callable] ou [].
func _action_possible() -> Array:
	var p := _phase()
	var pos := corps_joueur.global_position
	if not _vivant() and etape == "jeu":
		return _action_fantome()
	if not _vivant() or mode in ["fige", "assis", "fantome", "guide"]:
		return []
	if _monde_quete and _monde_quete.viser() >= 0:
		return [_monde_quete.invite(), func(): _monde_quete.toucher()]
	if p != "salon" and (p != "nuit" or mode == "chambre"):
		var obj := _action_objet()
		if not obj.is_empty():
			return obj
	var porte_ := ronde.porte_proche(pos, 2.2)
	if mode == "libre" and not _assis_libre:
		var siege := Ronde.siege_proche(pos, 1.2, _de_jour() or p == "salon")
		if not siege.is_empty() and _vise_gros((siege[0] as Vector3) + Vector3(0, 0.35, 0), 2.6, 0.6):
			var sur_lit: bool = Ronde.maison_de(pos) >= 0
			return ["{agir} : t'asseoir sur le lit" if sur_lit else "{agir} : t'asseoir", func(): _s_asseoir(siege[0], siege[1])]
	if p == "nuit":
		return _action_nuit(pos)
	if p in ["tableau", "quete", "pret"] and pos.distance_to(Ronde.TABLEAU) < Meneur.PORTEE_TABLEAU 			and (_invite_geste() != "" or _vise_gros(Ronde.TABLEAU + Vector3(0, 1.3, 0), 7.0, 1.4)):
		# Quelqu'un devant moi : interagir avec lui passe avant le tableau (Edwin, 31/10).
		var geste := _invite_geste()
		if geste != "":
			return [geste, Callable()]
		return ["{agir} : lire le tableau des quêtes", _panneau_tableau]
	if _de_jour() or p == "salon":
		if not porte_.is_empty() and porte_[1] == "avant" and _vise_porte(porte_[0]):
			var ouverte: bool = ronde.porte_ouverte(porte_[0], "avant")
			return ["{agir} : fermer la porte" if ouverte else "{agir} : ouvrir la porte", func(): _envoyer_intention("porte", porte_[0], "avant")]
		if _priv("role") == "fossoyeur" and pos.distance_to(Ronde.lieu("cimetiere")) < 8.0:
			return ["{pouvoir} : examiner un mort", Callable()]
	return []


## On vient de s'asseoir sur son rondin : on se tourne vers le feu (Edwin, 30/10), la tête droite.
func _face_au_feu() -> void:
	var d := -corps_joueur.global_position
	if Vector2(d.x, d.z).length() < 0.5:
		return
	corps_joueur.rotation.y = atan2(-d.x, -d.z)
	_yaw_siege = corps_joueur.rotation.y
	tete.rotation.y = 0.0


func _s_asseoir(siege: Vector3, regard: Vector3) -> void:
	_assis_libre = true
	_ancre = siege
	corps_joueur.global_position = siege
	corps_joueur.velocity = Vector3.ZERO
	var d := regard - siege
	corps_joueur.rotation.y = atan2(-d.x, -d.z)
	_yaw_siege = corps_joueur.rotation.y
	_sur_lit = Ronde.maison_de(siege) >= 0
	tete.rotation.y = 0.0
	ecran.message("Tu t'assois. Bouge pour te lever.", 2.0)


## Debout : un pas en avant, hors de la souche (ou du lit), sinon on resterait coincé dedans.
func _se_lever() -> void:
	_assis_libre = false
	if _sur_lit:
		corps_joueur.rotate_y(tete.rotation.y)    # on se lève face à là où l'on regardait
	_sur_lit = false
	tete.rotation.y = 0.0
	var devant := -corps_joueur.global_transform.basis.z
	devant.y = 0
	corps_joueur.global_position = _ancre + devant.normalized() * 0.75


func _habitant(maison: int) -> int:
	var s: Dictionary = meneur.pub.get("sieges", {})
	for id in s:
		if s[id]["maison"] == maison:
			return id
	return -1


func _est_vivant(id: int) -> bool:
	var s: Dictionary = meneur.pub.get("sieges", {})
	return s.has(id) and s[id]["vivant"]






func _construire_ui() -> void:
	_ui_nuit = CanvasLayer.new()
	_ui_nuit.layer = 1
	add_child(_ui_nuit)
	_voile = ColorRect.new()
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile_mat = ShaderMaterial.new()
	_voile_mat.shader = load("res://nuit.gdshader")
	_voile.material = _voile_mat
	_ui_nuit.add_child(_voile)
	_texte_nuit = _label("", 28, Color(0.9, 0.85, 0.85))
	_texte_nuit.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_texte_nuit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texte_nuit.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_texte_nuit.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_texte_nuit.position.y -= 70
	_ui_nuit.add_child(_texte_nuit)

	var calque_jeu := CanvasLayer.new()
	calque_jeu.layer = 2
	add_child(calque_jeu)
	ecran = EcranJeu.new()
	calque_jeu.add_child(ecran)
	ecran.tchat_envoye.connect(func(t): meneur.tchat_envoyer.rpc_id(1, t))
	_construire_gestes(calque_jeu)
	_inventaire = InventaireUI.new()
	calque_jeu.add_child(_inventaire)
	_vue_quete = VueQuete.new()
	calque_jeu.add_child(_vue_quete)
	_vue_quete.geste.connect(func(d): _envoyer_intention("jeu", d))
	ecran.panneau_ferme.connect(func():
		if etape == "jeu" and not ecran.salon_visible() and not ecran.fin_visible():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)

	_ui = CanvasLayer.new()
	_ui.layer = 3
	add_child(_ui)
	var racine := Control.new()
	var th := Theme.new()
	th.default_font_size = 22
	racine.theme = th
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(racine)

	racine.add_child(_miroir)
	_miroir.anchor_left = 1.0
	_miroir.anchor_right = 1.0
	_miroir.anchor_top = 1.0
	_miroir.anchor_bottom = 1.0
	_miroir.offset_left = -284
	_miroir.offset_right = -24
	_miroir.offset_top = -300
	_miroir.offset_bottom = -40

	_luciole = Luciole.new()
	_luciole.set_anchors_preset(Control.PRESET_FULL_RECT)
	_luciole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(_luciole)

	_menu = Menu.new()
	_menu.nom = mon_nom
	_menu.apparence = mon_apparence
	racine.add_child(_menu)
	_menu.regler_petite(_lire_reglage("petite_machine", false))
	_petite_machine(_lire_reglage("petite_machine", false))
	_menu.creer.connect(_creer_lobby)
	_menu.rejoindre.connect(_rejoindre_code)
	_menu.essai_bots.connect(_essai_bots)
	_menu.nuit_guidee.connect(func(): _lancer_tutoriel())
	_menu.nuit_guidee_refusee.connect(func(): _memoriser_tutoriel("refuse"))
	_menu.mode_test.connect(func():
		_mode_test = true
		_essai_bots())
	_menu.reglage_regard.connect(func():
		_reglage_origine = "menu"
		_aller("reglage"))
	_menu.quitter_jeu.connect(func(): _confirmer("Quitter le jeu ?", _quitter))
	_menu.boutique.connect(_sur_boutique)
	_menu.essai_cosmetique.connect(_essayer_cosmetique)
	_menu.profil_change.connect(func(n: String, a: int):
		mon_nom = n
		mon_apparence = a
		_ecrire_reglage("nom", n)
		_ecrire_reglage("apparence", a))
	_menu.petite_machine.connect(_petite_machine)
	_ma_tete = MaTete.charger()
	_tete_on = bool(_lire_reglage("ma_tete", false)) and _ma_tete.size() == 2
	_menu.regler_tete(_ma_tete, _tete_on)
	_menu.prendre_tete.connect(func(): Capteur.prendre_photo())
	_menu.tete_active.connect(_regler_tete)
	_menu.effacer_tete.connect(func():
		MaTete.effacer()
		_ma_tete = []
		_regler_tete(false)
		_menu.regler_tete([], false, "Photo effacée."))
	Capteur.photo_recue.connect(_sur_photo)
	Capteur.photo_ratee.connect(func(t: String): _menu.regler_tete(_ma_tete, _tete_on, t))
	_cam_menu = Camera3D.new()
	_cam_menu.fov = 50
	_cam_menu.far = 300
	add_child(_cam_menu)
	_construire_reglage(racine)

	_panneau_resultat = _panneau(racine)
	var r := _panneau_resultat.get_child(0) as VBoxContainer
	_texte_resultat = _label("", 26)
	r.add_child(_texte_resultat)
	var rb := HBoxContainer.new()
	rb.add_theme_constant_override("separation", 16)
	rb.add_child(_bouton("  C'est réglé  ", _apres_reglage))
	rb.add_child(_bouton("Recommencer", _commencer_luciole))
	r.add_child(rb)

	_panneau_pause = _panneau(racine)
	var p := _panneau_pause.get_child(0) as VBoxContainer
	p.add_child(_label("Pause", 34, EcranJeu.OR))
	p.add_child(_label("{emotes} : animations · {accroupir} : s'accroupir · Clic gauche : interagir face à quelqu'un, voter · 1 à 4 : tes objets · {reseau} : réseau
Les touches se changent dans Réglages → Touches.", 18, Color(1, 1, 1, 0.75)))
	p.add_child(_bouton("Reprendre", func(): _aller("jeu")))
	p.add_child(_bouton("Réglages (son, micro, touches, graphismes)", func(): _montrer_options_jeu(true)))
	p.add_child(_bouton("Réglage du regard", func():
		_reglage_origine = "pause"
		_aller("reglage")))
	p.add_child(_bouton("Quitter la partie (retour au menu)", func(): _confirmer("Quitter la partie et revenir au menu ?", _quitter_partie)))
	p.add_child(_bouton("Quitter le jeu", func(): _confirmer("Quitter le jeu ?", _quitter)))

	_panneau_options_jeu = _panneau(racine)
	var po := _panneau_options_jeu.get_child(0) as VBoxContainer
	po.add_child(_label("Réglages", 34, EcranJeu.OR))
	_reglages_jeu = PanneauReglages.new()
	_reglages_jeu.petite_machine.connect(func(oui):
		_menu.regler_petite(oui)
		_petite_machine(oui))
	_reglages_jeu.reglage_regard.connect(func():
		_montrer_options_jeu(false)
		_reglage_origine = "pause"
		_aller("reglage"))
	po.add_child(_reglages_jeu)
	po.add_child(_bouton("◀  Retour", func(): _montrer_options_jeu(false)))
	_panneau_options_jeu.visible = false
	Options.change.connect(_option_changee)

	_diag = _label("", 16, Color(0.8, 1.0, 0.8))
	_diag.position = Vector2(12, 12)
	_diag.visible = false
	racine.add_child(_diag)

	# Gestes et danses (G) : une liste, un clic ou un chiffre.
	_panneau_emotes = _panneau(racine)
	var pe := _panneau_emotes.get_child(0) as VBoxContainer
	pe.add_child(_label("Gestes et danses", 28, EcranJeu.OR))
	var ge := GridContainer.new()
	ge.columns = 2
	_emotes_dispo = Emotes.LISTE.filter(func(e: Array) -> bool:
		return not Emotes.PAYANTES.has(e[0]) or GardeRobe.possede(Emotes.PAYANTES[e[0]]))
	for k in _emotes_dispo.size():
		var e: Array = _emotes_dispo[k]
		var raccourci := str(k + 1) if k < 9 else ""
		var id: String = e[0]
		ge.add_child(_bouton(("%s  %s" % [raccourci, e[1]]).strip_edges(), func(): _faire_emote(id)))
	pe.add_child(ge)
	pe.add_child(_label("1 à 9 · {emotes} pour fermer · bouger arrête la danse", 15, Color(1, 1, 1, 0.6)))
	_panneau_emotes.visible = false

	# Ma fiche de rôle (Tab).
	_panneau_role = _panneau(racine)
	var pr := _panneau_role.get_child(0) as VBoxContainer
	_texte_role = _label("", 19)
	_texte_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texte_role.custom_minimum_size.x = 640
	pr.add_child(_texte_role)
	_panneau_role.visible = false

	# Le volume de chaque joueur, en pleine partie : l'icône en haut à droite, ou la touche B.
	_carnet = PanneauCarnet.new()
	_carnet.envoyer = func(t, a, b): _envoyer_intention(t, a, b)
	_carnet.proprietaire = _nom_habitant
	_carnet.joueurs = _pseudos_de_la_partie
	_carnet.tape.connect(_stylo_ecrit)
	_carnet.ecriture_changee.connect(_sur_ecriture_carnet)
	_carnet.lier_etat(func(): return _vue_objets.objet(_carnet._id) if _vue_objets else {})
	racine.add_child(_carnet)
	_indic_carnet = Label.new()
	_indic_carnet.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_indic_carnet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_indic_carnet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_indic_carnet.position.y = -64
	_indic_carnet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indic_carnet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indic_carnet.add_theme_font_override("font", Style.police("italique"))
	_indic_carnet.add_theme_font_size_override("font_size", 17)
	_indic_carnet.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82, 0.78))
	_indic_carnet.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_indic_carnet.add_theme_constant_override("shadow_offset_x", 1)
	_indic_carnet.add_theme_constant_override("shadow_offset_y", 1)
	_indic_carnet.text = Langue.t("Clic gauche : ouvrir  ·  Clic droit : écrire")
	_indic_carnet.visible = false
	racine.add_child(_indic_carnet)

	_panneau_volumes = _panneau(racine)
	var pv := _panneau_volumes.get_child(0) as VBoxContainer
	_liste_volumes = VBoxContainer.new()
	_liste_volumes.add_theme_constant_override("separation", 8)
	_liste_volumes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.add_child(_defilant(_liste_volumes))
	pv.add_child(_label("Jusqu'à 300 % pour qui parle trop bas · {volumes} ou Échap pour fermer", 15, Color(1, 1, 1, 0.6)))
	_panneau_volumes.visible = false
	_icone_voix = Button.new()
	_icone_voix.text = VOYANT_PORTEE[_ma_portee]
	_icone_voix.icon = _rond(18)
	_icone_voix.add_theme_constant_override("h_separation", 10)
	Options.lier_texte(_icone_voix, "Vert : le micro te capte. {portee} change la portée. Clic ou {volumes} : le volume de chaque joueur.", "tooltip_text")
	_icone_voix.add_theme_font_size_override("font_size", 18)
	_icone_voix.add_theme_color_override("font_color", EcranJeu.OR)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.03, 0.03, 0.7)
	st.set_corner_radius_all(18)
	st.border_width_bottom = 2
	st.border_color = Color(0.85, 0.16, 0.08, 0.8)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	_icone_voix.add_theme_stylebox_override("normal", st)
	var sth := st.duplicate() as StyleBoxFlat
	sth.bg_color = Color(0.3, 0.06, 0.03, 0.85)
	_icone_voix.add_theme_stylebox_override("hover", sth)
	_icone_voix.add_theme_stylebox_override("pressed", sth)
	_icone_voix.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_icone_voix.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Ancré au bord droit, il s'élargit vers la gauche (« Micro coupé » est plus long que « Crie »).
	_icone_voix.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_icone_voix.offset_left = -24
	_icone_voix.offset_right = -24
	_icone_voix.offset_top = 64
	_icone_voix.pressed.connect(_basculer_volumes)
	_icone_voix.visible = false
	racine.add_child(_icone_voix)
	# En petit dessous : la touche qui change la portée (Edwin, 31/10).
	var aide_portee := Label.new()
	_aide_portee = aide_portee
	Options.lier_texte(aide_portee, "{portee} : changer de mode")
	aide_portee.add_theme_font_size_override("font_size", 14)
	aide_portee.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	aide_portee.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aide_portee.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	aide_portee.offset_top = 4
	aide_portee.offset_bottom = 24
	aide_portee.grow_horizontal = Control.GROW_DIRECTION_BOTH
	aide_portee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icone_voix.add_child(aide_portee)

	# Le volume de chaque joueur, dans la pause.
	_pause_joueurs = VBoxContainer.new()
	_pause_joueurs.add_theme_constant_override("separation", 6)
	_pause_joueurs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(_panneau_pause.get_child(0) as VBoxContainer).add_child(_defilant(_pause_joueurs))
	# Le vote d'exclusion : une petite fenêtre en haut à droite, au-dessus du menu pause.
	_panneau_excl = PanneauExclusion.new()
	_panneau_excl.repond.connect(func(oui: bool): _envoyer_intention("exclusion_vote", oui))
	racine.add_child(_panneau_excl)
	ecran.sur_exclure = func(id: int): _envoyer_intention("exclure", id)


## Le parchemin de quête s'efface sous la pause et F10 (ils passent devant et restent cliquables).
func _parchemin_selon_menus() -> void:
	if _monde_quete != null:
		_monde_quete.montrer_parchemin(etape != "pause" and not (_panneau_test != null and _panneau_test.visible))


## Le mode test : le panneau s'ouvre (souris libre) ou se ferme. Fabriqué à la première ouverture.
func _basculer_panneau_test() -> void:
	if _panneau_test == null:
		_panneau_test = PanneauTest.new()
		_panneau_test.meneur = meneur
		_panneau_test.dire = func(t: String): ecran.message(t, 3.5)
		_panneau_test.aller = func(p: Vector3, r: Vector3):
			_guide.clear()
			_appliquer_placement(p, r, "fantome" if mode == "fantome" else "libre")
		_panneau_test.frayeur = func(sorte: String) -> bool: return _frissons.forcer(sorte)
		_panneau_test.sur_le_champ = func(oui: bool):
			_sur_le_champ = oui
			if oui:
				_cacher_vue_quete()   # le décor du jeu d'avant s'en va
		_panneau_test.visible = false
		# Son propre calque, AU-DESSUS de tout (parchemin, bandeau, menus) : F10 reste cliquable.
		var calque_test := CanvasLayer.new()
		calque_test.layer = 50
		add_child(calque_test)
		calque_test.add_child(_panneau_test)
	_panneau_test.visible = not _panneau_test.visible
	_parchemin_selon_menus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _panneau_test.visible else Input.MOUSE_MODE_CAPTURED


## Alt tenu en partie : la souris apparaît (pour cliquer sur l'icône des voix) ; lâché, elle repart.
func _alt(tenu: bool) -> void:
	if etape != "jeu":
		_alt_souris = false
		return
	if tenu and not _alt_souris and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_alt_souris = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not tenu and _alt_souris:
		_alt_souris = false
		if not _panneau_volumes.visible and not _panneau_emotes.visible and not ecran.panneau_ouvert():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Le sol sous un pied, pour le bruit du pas.
func _sol_pas(p: Vector3) -> String:
	if Ronde.maison_de(p) >= 0:
		return "planches"
	if Ronde.hauteur_sol(p) > 0.0 or Vector2(p.x, p.z).length() < Ronde.R_PLACE + 1.0:
		return "pave"
	match Ronde.sol_a(p):
		"graviers": return "graviers"
		"planches": return "planches"
		"flaques": return "flaques"
	return "terre"


## Les pas : doux en marchant, nets en courant, cadence calée sur la vitesse réelle (règle : Foulee).
## Ils viennent du déplacement RÉEL du corps, donc marche libre, marche guidée, trajets automatiques,
## bots et autres joueurs sonnent pareil. La nuit, ceux des autres se taisent (le bruit des loups passe
## par les combinaisons), sauf pour les loups et les morts.
func _pas(delta: float) -> void:
	if etape not in ["jeu", "pause"] or delta <= 0.0:
		return
	var nuit_muette: bool = _phase() == "nuit" and _vivant() and not _suis_loup()
	var qui := {0: corps_joueur.global_position}
	for id in bouilles:
		qui[id] = (bouilles[id] as Bouille).global_position
	for id in qui:
		var p: Vector3 = qui[id]
		if not _marcheurs.has(id):
			_marcheurs[id] = Marcheur.new()
		var m: Marcheur = _marcheurs[id]
		# La hauteur se mesure au-dessus du sol d'ICI : sur la terrasse du temple, on marche.
		m.avancer(p, delta, p.y - Ronde.hauteur_sol(p))
		if m.pas == "" and m.chute <= 0.0:
			continue
		var est_soi: bool = id == 0
		var sol := _sol_pas(p)
		var sonne: bool = Foulee.sonne(est_soi, _vivant(), nuit_muette, _est_vivant_ou_bot(id) if not est_soi else true)
		var atterrit: bool = m.chute > 0.0
		var allure: String = "atterrit" if atterrit else m.pas
		if _trace_pas:
			_stat_pas("%s|%s|%s|%s|%s" % ["moi/" + mode if est_soi else ("bot" if Meneur.est_bot(id) else "autre"), _phase(), sol, allure, "joue" if sonne else "muet"])
		if not sonne:
			continue
		_pas_n += 1
		var court: bool = m.pas == "course"
		var db: float = Foulee.volume_atterrissage(est_soi, m.chute) if atterrit else Foulee.volume_db(est_soi, m.pas)
		var pitch: float = Foulee.pitch_atterrissage(m.chute) if atterrit else randf_range(0.92, 1.08) * (1.06 if court else 1.0)
		_jouer_pas(Sons.pas(sol, _pas_n % 4), p, est_soi, db, pitch)


## Un pas (ou un atterrissage) : en 2D pour soi, en 3D à la place du corps pour les autres.
func _jouer_pas(son: AudioStream, p: Vector3, est_soi: bool, db: float, pitch: float) -> void:
	if est_soi:
		var a := AudioStreamPlayer.new()
		a.stream = son
		a.bus = "Effets"
		a.volume_db = db
		a.pitch_scale = pitch
		add_child(a)
		a.play()
		a.finished.connect(a.queue_free)
		return
	var a3 := AudioStreamPlayer3D.new()
	a3.stream = son
	a3.bus = "Effets"
	# Atténuation douce (en 1/d, pas en carré inverse comme les autres bruits) : un pas se perçoit nettement à
	# 8 m et encore à 15 m. Mesuré : l'ancien réglage (carré inverse) laissait -21 dB entre 3 et 8 m.
	a3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	a3.unit_size = Foulee.UNITE_3D
	a3.max_distance = Foulee.PORTEE_3D
	a3.attenuation_filter_cutoff_hz = 20500.0   # filtre coupé : par défaut (5 kHz, -24 dB) il avale tout le pas
	a3.max_db = 24.0   # sinon le plafond par défaut (+3 dB) écrase les pas proches
	a3.volume_db = db + _sourdine_mort()
	a3.pitch_scale = pitch
	var ma := Ronde.maison_de(corps_joueur.global_position)
	if ma >= 0 and Ronde.maison_de(p) != ma:
		a3.volume_db -= 18.0 * _dedans
		a3.attenuation_filter_cutoff_hz = lerpf(20000.0, 500.0, _dedans)
	add_child(a3)
	a3.global_position = p
	a3.play()
	a3.finished.connect(a3.queue_free)


## Un fantôme ne fait pas de bruit en marchant.
func _est_vivant_ou_bot(id: int) -> bool:
	var s: Dictionary = meneur.pub.get("sieges", {})
	return not s.has(id) or s[id]["vivant"] or not _vivant()


func _basculer_volumes() -> void:
	_panneau_volumes.visible = not _panneau_volumes.visible
	if _panneau_volumes.visible:
		_remplir_pause_joueurs(_liste_volumes)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _panneau_volumes.visible else Input.MOUSE_MODE_CAPTURED


## Un rond plein (le voyant de voix), teinté ensuite par la couleur d'icône du bouton.
static func _rond(cote: int) -> ImageTexture:
	var img := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
	var c := (cote - 1) * 0.5
	for y in cote:
		for x in cote:
			var d := Vector2(x - c, y - c).length()
			img.set_pixel(x, y, Color(1, 1, 1, clampf(c - d + 0.5, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## L'icône et les voyants « il parle » (appelé chaque image).
func _maj_volumes() -> void:
	_icone_voix.visible = etape == "jeu" and _phase() != "salon"
	var micro := bool(Options.valeur("vocal/micro"))
	# La portée en mètres à côté du mot (Edwin, 31/10) : « Parle · 8 m ».
	var portee_libre := Visibilite.portee_modifiable(_phase())
	if not micro:
		_icone_voix.text = "Micro coupé"
	elif portee_libre:
		_icone_voix.text = "%s · %d m" % [VOYANT_PORTEE[_ma_portee], int(PORTEES_VOIX[_ma_portee])]
	else:
		_icone_voix.text = "Tout le monde t'entend"
	if is_instance_valid(_aide_portee):
		_aide_portee.visible = portee_libre
	var teinte := VERT_VOIX if micro and Voix.detecte() else GRIS_VOIX
	for etat in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		_icone_voix.add_theme_color_override(etat, teinte)
	if not _panneau_volumes.visible and etape != "pause":
		return
	for id in _voyants:
		if not is_instance_valid(_voyants[id]):
			continue
		var parle: bool = (Voix.mon_niveau if id == _moi_id() else Voix.niveau(id)) > 0.02
		(_voyants[id] as Label).add_theme_color_override("font_color", Color(0.4, 0.95, 0.5) if parle else Color(1, 1, 1, 0.2))


## Dans une maison, l'ambiance du dehors s'étouffe : filtre sur le bus Ambiance.
func _insonoriser() -> void:
	var i := AudioServer.get_bus_index("Ambiance")
	if i < 0:
		return
	if _filtre_dedans == null:
		_filtre_dedans = AudioEffectLowPassFilter.new()
		_gain_dedans = AudioEffectAmplify.new()
		AudioServer.add_bus_effect(i, _filtre_dedans)
		AudioServer.add_bus_effect(i, _gain_dedans)
	var cible := 0.0
	var m := Ronde.maison_de(corps_joueur.global_position) if etape in ["jeu", "pause"] else -1
	if m >= 0:
		cible = 0.45 if ronde.porte_ouverte(m, "avant") else 1.0
	_dedans = move_toward(_dedans, cible, 0.04)
	_filtre_dedans.cutoff_hz = 20000.0 * pow(450.0 / 20000.0, _dedans)
	_gain_dedans.volume_db = -16.0 * _dedans


## Accroupi chez les autres : un état qui change rarement, envoyé quand il change (comme une émote).
@rpc("any_peer", "call_remote", "reliable")
func _accroupi_rpc(oui: bool) -> void:
	var qui := multiplayer.get_remote_sender_id()
	if bouilles.has(qui) and _phase() != "nuit":
		(bouilles[qui] as Bouille).accroupi = oui


func _faire_emote(id: String) -> void:
	_panneau_emotes.visible = false
	if etape == "jeu":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Mort, on garde ses gestes : un fantôme fait coucou, pointe, danse… seuls les autres morts le voient,
	# puisque les vivants ne voient pas les fantômes (Edwin, 04/11).
	if not is_instance_valid(moi):
		return
	# Pointer du doigt : vers le joueur visé à cet instant, s'il y en a un.
	var vers := _vise_bouille if Emotes.pointe(id) and _vise_bouille >= 0 and _est_vivant(_vise_bouille) else -1
	moi.jouer_emote(id, _bouille_de(vers) if vers >= 0 else null)
	# Plus de « retour » sur soi : la caméra reste à la première personne.
	if Reseau.en_ligne and _connecte() and not _par_l_hote():
		_emote_rpc.rpc(id)
		if vers >= 0:
			_emote_vers_rpc.rpc(id, vers)


## Les villageois de passage (bots) font eux aussi des gestes et dansent, le jour, quand ils sont à l'arrêt.
var _emote_bots_t := 6.0


func _emotes_bots(delta: float) -> void:
	if not meneur.est_hote() or not _de_jour():
		return
	_emote_bots_t -= delta
	if _emote_bots_t > 0.0:
		return
	_emote_bots_t = _rng.randf_range(5.0, 12.0)
	var choix := []
	for id in bouilles:
		if Meneur.est_bot(id) and _est_vivant(id) and (bouilles[id] as Bouille).emote == "":
			choix.append(id)
	if choix.is_empty():
		return
	var qui: int = choix[_rng.randi_range(0, choix.size() - 1)]
	var e: String = Emotes.LISTE[_rng.randi_range(0, Emotes.LISTE.size() - 1)][0]
	_emote_bot_rpc(qui, e)
	if Reseau.en_ligne and _connecte():
		_emote_bot_rpc.rpc(qui, e)


@rpc("authority", "call_remote", "reliable")
func _emote_bot_rpc(qui: int, id: String) -> void:
	if bouilles.has(qui) and Emotes.existe(id):
		(bouilles[qui] as Bouille).jouer_emote(id)


## Le même geste, avec la personne qu'il montre (envoyé juste après `_emote_rpc`, qui l'a déjà lancé).
@rpc("any_peer", "call_remote", "reliable")
func _emote_vers_rpc(id: String, vers: int) -> void:
	var qui := multiplayer.get_remote_sender_id()
	if bouilles.has(qui) and Emotes.existe(id):
		(bouilles[qui] as Bouille).jouer_emote(id, _bouille_de(vers))


@rpc("any_peer", "call_remote", "reliable")
func _emote_rpc(id: String) -> void:
	var qui := multiplayer.get_remote_sender_id()
	if bouilles.has(qui) and Emotes.existe(id):
		(bouilles[qui] as Bouille).jouer_emote(id)


func _montrer_role() -> void:
	var role: String = _priv("role", "")
	var t := ""
	if role == "":
		t = "Tu es villageois, sans rôle pour l'instant."
	else:
		t = "Tu es : %s\n%s" % [_priv("nom_role", Roles.nom(role)), _priv("desc", Roles.description(role))]
	t += "\n\nLes rôles se gagnent aux quêtes du jour : quand une équipe réussit, l'un d'elle reçoit un rôle en secret."
	t += "\nLes loups (%d) sont tirés la première nuit, parmi ceux qui n'ont encore rien gagné." % int(meneur.pub.get("nb_loups", 2))
	_texte_role.text = Options.avec_touches(_tl(t))
	_panneau_role.visible = true


## Une liste qui défile (la pause et le panneau des voix ne grandissent pas avec le village).
func _defilant(contenu: Control) -> ScrollContainer:
	var d := ScrollContainer.new()
	d.custom_minimum_size = Vector2(900, 270)
	d.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	d.add_child(contenu)
	return d


## Tous les joueurs de la partie, vivants et morts : {id, nom, couleur, vivant, humain}. En partie, un
## bandeau et jamais de nom ; au salon, les pseudos (il n'y a pas encore de bandeaux).
func _lignes_joueurs() -> Array:
	var r := []
	var sieges: Dictionary = meneur.pub.get("sieges", {})
	if _phase() == "salon" or sieges.is_empty():
		for id in _humains:
			r.append({"id": id, "nom": str(_humains[id].get("nom", "?")), "couleur": EcranJeu.OR, "vivant": true, "humain": true})
		r.sort_custom(func(x, y): return int(x["id"]) < int(y["id"]))
		return r
	for id in sieges:
		var f: Dictionary = sieges[id]
		if f.get("parti", false):
			continue
		var k: int = f.get("bandeau", -1)
		r.append({"id": id, "nom": _etiquette(id), "bandeau": k, "vivant": bool(f.get("vivant", true)),
			"couleur": Bouille.BANDEAUX[k][0] if k >= 0 and k < Bouille.BANDEAUX.size() else Color.WHITE,
			"humain": not bool(f.get("bot", false)) and _humains.has(id) or id == _moi_id()})
	r.sort_custom(func(x, y): return int(x.get("bandeau", 0)) < int(y.get("bandeau", 0)))
	return r


func _signature_liste() -> String:
	var t := PackedStringArray()
	for l: Dictionary in _lignes_joueurs():
		t.append("%s/%s/%s/%s" % [l["id"], l["nom"], l["vivant"], l["humain"]])
	return "|".join(t) + "#%s#%s#%s" % [meneur.est_hote(), not _excl_etat.is_empty(), _excl_confirmer]


## La liste ouverte (pause ou panneau des voix) suit les arrivées, les morts et les départs ; elle
## ne se refait que si quelque chose a changé, pour ne pas lâcher un curseur qu'on tient.
func _rafraichir_liste_joueurs() -> void:
	if etape == "pause":
		if _signature_liste() != _sig_liste:
			_remplir_pause_joueurs()
	elif _panneau_volumes.visible and _signature_liste() != _sig_liste:
		_remplir_pause_joueurs(_liste_volumes)


func _remplir_pause_joueurs(liste: VBoxContainer = null) -> void:
	if liste == null:
		liste = _pause_joueurs
	for e in liste.get_children():
		liste.remove_child(e)
		e.queue_free()
	_voyants.clear()
	_sig_liste = _signature_liste()
	liste.add_child(_label("Les joueurs", 20, EcranJeu.OR))
	var moi_id := _moi_id()
	var hote := meneur.est_hote()
	for l: Dictionary in _lignes_joueurs():
		var id: int = l["id"]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var pastille := ColorRect.new()
		pastille.color = l["couleur"]
		pastille.custom_minimum_size = Vector2(18, 18)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(pastille)
		var n := _label("", 18, Color.WHITE if l["vivant"] else Color(1, 1, 1, 0.45))
		# Un pseudo ne se traduit jamais ; un bandeau (« Bandeau rouge ») si.
		if l.has("bandeau"):
			n.text = Langue.t(str(l["nom"]))
		else:
			n.text = str(l["nom"])
			n.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		if id == moi_id:
			n.text += "  " + Langue.t("(toi)")
		n.custom_minimum_size.x = 190
		h.add_child(n)
		var etat := _label("" if l["vivant"] else "mort", 16, Color(1, 1, 1, 0.5))
		etat.custom_minimum_size.x = 44
		h.add_child(etat)
		if not l["humain"]:
			liste.add_child(h)
			continue
		var voyant := _label("●", 18, Color(1, 1, 1, 0.2))
		h.add_child(voyant)
		_voyants[id] = voyant
		if id != moi_id:
			var s := HSlider.new()
			s.min_value = 0
			s.max_value = 300
			s.step = 5
			s.value = float(Voix.volumes.get(id, 100.0))
			s.custom_minimum_size.x = 170
			s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var chiffre := _label("%d %%" % int(s.value), 17, EcranJeu.OR)
			chiffre.custom_minimum_size.x = 58
			s.value_changed.connect(func(v):
				Voix.volumes[id] = v
				chiffre.text = "%d %%" % int(v))
			h.add_child(s)
			h.add_child(chiffre)
			h.add_child(_bouton("Muet", func(): s.value = 0))
			h.add_child(_bouton("100 %", func(): s.value = 100))
			# L'hôte exclut ; les autres demandent un vote (jamais contre l'hôte : pas de bouton).
			if hote:
				h.add_child(_bouton_exclusion(id, "Exclure", "Confirmer l'exclusion"))
			elif id != 1:
				var b := _bouton_exclusion(id, "Demander l'exclusion", "Confirmer la demande")
				b.disabled = not _excl_etat.is_empty()
				h.add_child(b)
		liste.add_child(h)


## « Exclure » demande d'abord une confirmation (un second clic), puis envoie l'ordre.
func _bouton_exclusion(id: int, texte: String, texte_confirmer: String) -> Button:
	var b := Button.new()
	if _excl_confirmer == id:
		b.text = texte_confirmer
		b.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
		b.pressed.connect(func():
			_excl_confirmer = -1
			_envoyer_intention("exclure" if meneur.est_hote() else "exclusion_demande", id)
			_rafraichir_liste_joueurs())
	else:
		b.text = texte
		b.pressed.connect(func():
			_excl_confirmer = id
			_rafraichir_liste_joueurs())
	return b


## L'hôte publie l'état du vote d'exclusion (ou {} quand il est fini).
func _sur_exclusion(etat: Dictionary) -> void:
	var nouveau := _excl_etat.is_empty() and not etat.is_empty()
	_excl_etat = etat
	_excl_confirmer = -1
	if _auto and not etat.is_empty():
		print("[exclusion] vote contre %d demandé par %d (électeurs %s)" % [etat["cible"], etat["demandeur"], etat["electeurs"]])
		if (etat["electeurs"] as Array).has(_moi_id()) and int(etat["demandeur"]) != _moi_id():
			_envoyer_intention("exclusion_vote", true)   # le joueur automatique vote oui
	_panneau_excl.maj(etat, _moi_id(), func(id: int) -> String:
		return Langue.t("toi") if id == _moi_id() else (str(_humains.get(id, {}).get("nom", "?")) if _phase() == "salon" else Langue.t(_etiquette(id))))
	if nouveau and (etat["electeurs"] as Array).has(_moi_id()) and int(etat["demandeur"]) != _moi_id():
		_jouer2d("cloche", -10.0)
		ecran.message(Options.avec_touches("Vote d'exclusion : {exclusion_oui} pour Oui, {exclusion_non} pour Non."), 6.0)
	_rafraichir_liste_joueurs()


func _montrer_options_jeu(oui: bool) -> void:
	_panneau_options_jeu.visible = oui
	_panneau_pause.visible = not oui and etape == "pause"
	if oui:
		_reglages_jeu.regler_petite(bool(_lire_reglage("petite_machine", false)))


func _option_changee(cle: String) -> void:
	if cle == "graphisme/champ":
		camera.fov = float(Options.valeur("graphisme/champ"))
	elif cle == "graphisme/ombres":
		Options.appliquer_ombres(self)


func _petite_machine(oui: bool) -> void:
	_ecrire_reglage("petite_machine", oui)
	Ronde.brume_volumetrique = not oui
	if ronde:
		ronde.regler_brume(not oui)
	Capteur.regler_corps(not oui)


const FICHIER_REGLAGES := "user://reglages.cfg"


func _lire_reglage(cle: String, defaut: Variant) -> Variant:
	var f := ConfigFile.new()
	if f.load(FICHIER_REGLAGES) != OK:
		return defaut
	return f.get_value("jeu", cle, defaut)


func _ecrire_reglage(cle: String, valeur: Variant) -> void:
	var f := ConfigFile.new()
	f.load(FICHIER_REGLAGES)
	f.set_value("jeu", cle, valeur)
	f.save(FICHIER_REGLAGES)


func _construire_reglage(racine: Control) -> void:
	_panneau_reglage = _panneau(racine)
	var v := _panneau_reglage.get_child(0) as VBoxContainer
	v.add_child(_label("Réglage du regard", 36, EcranJeu.OR))
	v.add_child(_label("Installe-toi comme quand tu joues. La caméra ne garde aucune image :\nseuls des nombres (yeux, tête, expressions) arrivent au jeu.", 19, Color(1, 1, 1, 0.75)))
	var l0 := HBoxContainer.new()
	l0.add_theme_constant_override("separation", 16)
	_etat_camera_reglage = _label("", 22)
	l0.add_child(_etat_camera_reglage)
	l0.add_child(_bouton("Changer de caméra", Capteur.changer_camera))
	v.add_child(l0)
	var l1 := HBoxContainer.new()
	l1.add_child(_label("Taille de ton écran (pouces)", 22))
	_spin_pouces = _spin(10, 100, 0.1, Regard.ecran_pouces)
	l1.add_child(_spin_pouces)
	_note_pouces = _label("", 18, Color(0.6, 1, 0.7))
	l1.add_child(_note_pouces)
	v.add_child(l1)
	var l2 := HBoxContainer.new()
	l2.add_child(_label("Distance entre tes yeux et l'écran (cm)", 22))
	_spin_distance = _spin(25, 150, 1, Regard.distance_ref_cm)
	l2.add_child(_spin_distance)
	v.add_child(l2)
	var l3 := HBoxContainer.new()
	_mesure_distance = _label("", 18, Color(0.6, 0.85, 1))
	l3.add_child(_mesure_distance)
	l3.add_child(_bouton("Prendre la mesure de la caméra", func():
		var d := Capteur.distance_cm(Regard.correction_focale)
		if d > 0: _spin_distance.value = round(d)))
	v.add_child(l3)
	var boutons := HBoxContainer.new()
	boutons.add_theme_constant_override("separation", 16)
	_bouton_luciole = _bouton("  Suivre la luciole des yeux (15 s)  ", _commencer_luciole)
	boutons.add_child(_bouton_luciole)
	_bouton_garder = _bouton("Garder mon dernier réglage", _apres_reglage)
	boutons.add_child(_bouton_garder)
	var souris := _bouton("Jouer sans webcam", func():
		Options.regler("camera/utiliser", false)
		_apres_reglage())
	souris.flat = true
	boutons.add_child(souris)
	v.add_child(boutons)
	var retour := _bouton("  ◀  Retour  ", _reglage_retour)
	retour.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(retour)


func _bouton(texte: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.pressed.connect(action)
	return b


func _label(texte: String, taille := 22, couleur := Color.WHITE) -> Label:
	var l := Label.new()
	Options.lier_texte(l, texte)
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _spin(mini: float, maxi: float, pas: float, val: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = mini
	s.max_value = maxi
	s.step = pas
	s.value = val
	s.custom_minimum_size.x = 130
	return s


func _panneau(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.035, 0.04, 0.94)
	style.border_color = Color(0.6, 0.12, 0.08, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	p.add_theme_stylebox_override("panel", style)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	parent.add_child(p)
	return p


## Seul, à s'entraîner, la pause fige vraiment la partie (bots, minuteurs de l'hôte, quêtes) : règle dans
## `Corps.pause_fige`. À plusieurs, elle n'arrête rien.
func _figer_entrainement(pause: bool) -> void:
	var oui := Corps.pause_fige(Reseau.en_ligne, "pause" if pause else "")
	if oui:
		for c in get_children():
			if c is Node3D or c == meneur:
				c.process_mode = Node.PROCESS_MODE_PAUSABLE
	if get_tree().paused != oui:
		get_tree().paused = oui


func _aller(e: String) -> void:
	etape = e
	_parchemin_selon_menus()
	_menu.visible = e == "accueil"
	_cam_menu.current = e == "accueil"
	if e != "accueil":
		camera.current = true
	_panneau_reglage.visible = e == "reglage"
	_panneau_resultat.visible = e == "resultat"
	_panneau_pause.visible = e == "pause"
	_panneau_options_jeu.visible = false
	_panneau_emotes.visible = false
	_panneau_role.visible = false
	_figer_entrainement(e == "pause")
	if e == "pause":
		_remplir_pause_joueurs()
	_luciole.visible = e == "luciole" or e == "verif"
	var en_jeu: bool = e == "jeu"
	ecran.visible = en_jeu or e == "pause"
	_ui_nuit.visible = en_jeu or e == "pause"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if en_jeu else Input.MOUSE_MODE_VISIBLE
	if en_jeu:
		Options.appliquer_ombres(self)
		if meneur.est_hote() and meneur.phase == "salon":
			meneur.regler_salon(meneur.nb_places, meneur.composition)
		if _phase() == "salon":
			_rafraichir_salon()
	if e == "reglage":
		_spin_pouces.value = Regard.ecran_pouces
		_bouton_garder.visible = Regard.calibre


func _maj_etat() -> void:
	var textes := {
		"demarrage": "Démarrage du capteur…",
		"recherche_camera": "Je cherche ta caméra…",
		"pas_de_camera": "Aucune caméra ici : clique sur « Changer de caméra ».",
		"camera_muette": "La caméra ne donne plus d'image.",
		"pas_de_visage": "Je ne vois pas ton visage : place-toi face à la caméra, bien éclairé.",
		"perdu": "Le capteur ne répond plus : « Changer de caméra » le relance.",
		"capteur_absent": "Le capteur n'a pas pu démarrer (ports 4243-4244 déjà pris ?).",
		"navigateur": "Le capteur démarre…",
		"ok": "Visage détecté ✓",
		"souris": "Mode souris (essai sans caméra)",
		"desactivee": "Webcam désactivée : tes yeux clignent tout seuls.",
	}
	_etat_camera_reglage.text = Langue.t("Caméra : %s") % Langue.t(str(textes.get(Capteur.etat, Capteur.etat)))


func _quitter() -> void:
	var fermait := Lobbies.code != ""
	Lobbies.fermer()
	Capteur.arreter()
	if fermait:
		# le temps que ntfy.sh apprenne que le lobby est fermé
		await get_tree().create_timer(0.8).timeout
	get_tree().quit()


# ================================================================ menu, lobbies, retour au menu

func _creer_lobby(nom_lobby: String, langue: String, public: bool, bots := false, perso := false) -> void:
	_mode_test = false
	if not Reseau.heberger():
		_menu.info("Impossible d'héberger : le port %d est déjà pris (une autre partie ouverte ?)." % Reseau.PORT)
		return
	meneur.avec_bots = bots
	meneur.personnalisee = perso
	_lobby = {"nom": nom_lobby, "langue": langue, "public": public}
	_prive = not public
	meneur.max_places = 16 if _prive else 12
	_code = ""
	Lobbies.reserver()
	_appliquer_profil()
	_entrer()


func _sur_code_reserve(c: String) -> void:
	if not meneur.est_hote() or not Reseau.en_ligne:
		return
	_code = c
	print("[lobby] code ", c)
	if not Reseau.adresses.is_empty():
		Lobbies.publier_adresses(Reseau.adresses)
	_maj_fiche()
	_rafraichir_salon()


func _sur_adresses(liste: PackedStringArray) -> void:
	if Lobbies.code != "":
		Lobbies.publier_adresses(liste)


## La fiche du lobby dans la liste publique : tant qu'on est au salon, et seulement si public.
func _maj_fiche() -> void:
	if not meneur.est_hote() or Lobbies.code == "" or _lobby.is_empty():
		return
	if _phase() != "salon":
		Lobbies.retirer_de_la_liste()
		return
	var joueurs := []
	var humains: Dictionary = meneur.pub.get("humains", {})
	for id in humains:
		joueurs.append({"n": humains[id]["nom"], "a": Cosmetiques.sans(int(humains[id].get("apparence", 0)))})
	Lobbies.afficher({"nom": _lobby["nom"], "langue": _lobby["langue"], "places": meneur.pub.get("places", 8),
		"joueurs": joueurs, "perso": meneur.personnalisee, "v": 1}, _lobby["public"])


func _texte_code() -> String:
	Streamer.code_courant = _code
	if _code == "":
		return "Code du lobby : préparation…" if meneur.est_hote() and Reseau.en_ligne else ""
	return "Code du lobby :   %s" % Streamer.code_affichable(_code)


func _rejoindre_code(c: String) -> void:
	_mode_test = false
	_code_cherche = c
	_menu.info("Je cherche le lobby %s…" % ("•••••" if Streamer.mode_actif() else c))
	Lobbies.chercher(c)


func _sur_code_trouve(adresses: PackedStringArray) -> void:
	if _code_cherche == "" or etape != "accueil":
		return
	if adresses.is_empty():
		_menu.info("Aucun lobby ouvert avec le code %s. Vérifie les 5 chiffres." % ("•••••" if Streamer.mode_actif() else _code_cherche))
		_code_cherche = ""
		return
	_menu.info("Lobby trouvé, connexion à l'hôte…")
	Reseau.rejoindre_liste(adresses)


func _sur_connexion_ok() -> void:
	if etape != "accueil":
		return
	print("[lobby] connecté au lobby ", _code_cherche)
	_code = _code_cherche
	_code_cherche = ""
	_appliquer_profil()
	_entrer()


## Un ami a cliqué « Rejoindre la partie » dans Steam (ou accepté une invitation).
func _rejoindre_ami_steam(adresse: String) -> void:
	if etape != "accueil":
		_menu.info("Quitte d'abord ta partie pour rejoindre ton ami.")
		return
	_mode_test = false
	_code_cherche = ""
	_menu.info("Connexion à ton ami par Steam…")
	Reseau.rejoindre_liste(PackedStringArray([adresse]))


func _sur_connexion_ratee() -> void:
	_code_cherche = ""
	if etape == "accueil" and Reseau.steam_manquant:
		_menu.info("Cet hôte joue par Steam : ouvre Steam sur ce PC, puis réessaie.")
	elif etape == "accueil":
		_menu.info("Le lobby existe mais l'hôte ne répond pas : sa box bloque peut-être le port %d.\nEssayez avec Tailscale (gratuit), ou que l'hôte ouvre ce port." % Reseau.PORT)


func _essai_bots() -> void:
	Reseau.quitter()
	_lobby = {}
	_code = ""
	_appliquer_profil()
	_entrer()


## La nuit guidée (cf. tutoriel.gd) : une partie hors ligne, six villageois dont cinq bots, menée pas à pas.
## `sans_memoire` : les essais automatiques n'écrivent rien dans les réglages du joueur.
## La proposition attend que l'écran de démarrage (mise à jour, capteur) ait fini de s'effacer.
func _proposer_nuit_guidee() -> void:
	while MiseAJour._ecran != null and is_instance_valid(MiseAJour._ecran):
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(0.8).timeout
	if etape == "accueil":
		_menu.proposer_nuit_guidee()


func _lancer_tutoriel(sans_memoire := false) -> void:
	_mode_test = false
	if not sans_memoire:
		_memoriser_tutoriel("commence")
	if _tuto != null:
		_tuto.queue_free()
	_tuto = Tutoriel.new()
	_tuto.p = self
	_tuto.sans_memoire = sans_memoire
	add_child(_tuto)
	_essai_bots()


## Ce que le joueur a fait de la nuit guidée, dans user://reglages.cfg : "" (jamais proposée), "refuse",
## "commence" ou "fait" (cf. TutoEtapes.etat_apres).
func _memoriser_tutoriel(evenement: String) -> void:
	var avant := str(_lire_reglage("tutoriel", ""))
	var apres := TutoEtapes.etat_apres(avant, evenement)
	if apres != avant:
		_ecrire_reglage("tutoriel", apres)


## En entrant dans une partie : le réglage du regard n'est demandé qu'une fois. Déjà fait, on
## le garde (il se refait depuis Réglages › Caméra, ou la pause).
func _entrer() -> void:
	_reglage_origine = "entree"
	# Le réglage du regard n'est proposé qu'à qui a une webcam qui voit son visage : sans caméra, ou case
	# décochée, rien ne s'impose et aucun écran ne bloque (il se fait plus tard depuis Réglages › Caméra).
	if Regard.calibre or Capteur.mode_souris or Capteur.etat != "ok" or "--jeu" in OS.get_cmdline_user_args():
		_apres_reglage()
	else:
		_aller("reglage")


## Après le réglage du regard : on revient d'où on venait (le menu, ou la partie).
func _apres_reglage() -> void:
	if _reglage_origine == "menu":
		_aller("accueil")
		_menu.ecran("options")
	else:
		_aller("jeu")


## « Retour » depuis le réglage : au menu ou à la pause d'où l'on venait ; en entrant dans
## un lobby, Retour veut dire « finalement non » : on le quitte.
func _reglage_retour() -> void:
	match _reglage_origine:
		"menu":
			_apres_reglage()
		"pause":
			_aller("pause")
		_:
			_quitter_partie()


## Au menu : le village vu de loin, la nuit, la caméra tourne lentement autour.
func _tourner_cam_menu(delta: float) -> void:
	if _boutique:
		_cam_roulotte(delta)
		return
	_menu_angle += delta * 0.025
	# Au-dessus des toits, EN DEÇÀ de la lisière : à 46 m la caméra était dans le mur de ténèbres
	# et le menu ne montrait qu'un voile noir (Edwin, 30/10).
	# Au-dessus de la place, regard vers l'autre bord du village : dehors, la caméra traversait les
	# sapins et le village disparaissait derrière un tronc, ou derrière le toit le plus proche
	# (Edwin, 30/10). Rien ne pousse ni ne se bâtit sur la place : le champ reste toujours libre.
	var r := Ronde.R_PLACE * 0.6
	var dir := Vector3(sin(_menu_angle), 0, cos(_menu_angle))
	# Assez bas pour laisser le ciel étoilé au-dessus des buttes (Edwin, 30/10).
	_cam_menu.position = dir * r + Vector3(0, 7.5, 0)
	_cam_menu.look_at(-dir * (Ronde.R_MAISON + 4.0) + Vector3(0, 3.0, 0))


func _quitter_partie() -> void:
	_retour_menu("")


## Une boîte Oui / Non avant un geste qu'on regretterait (quitter, revenir au menu) : Échap = Non.
func _confirmer(texte: String, sur_oui: Callable) -> void:
	Confirmation.demander(self, texte, sur_oui)


# ================================================================ la roulotte du colporteur

## L'onglet Cosmétique s'ouvre ou se ferme : la caméra glisse vers la roulotte, ton personnage
## se poste devant le miroir ; au retour, tout reprend sa place.
func _sur_boutique(oui: bool) -> void:
	_boutique = oui
	if oui:
		_essayer_cosmetique(mon_apparence, "")
	else:
		_retirer_essai()


func _retirer_essai() -> void:
	if _essai:
		_essai.queue_free()
		_essai = null
	if _essai_extra:
		_essai_extra.queue_free()
		_essai_extra = null
	if _maison_essai >= 0:
		ronde.parer_maison(_maison_essai, "")
		_maison_essai = -1


func _essayer_cosmetique(apparence: int, article: String) -> void:
	if not _boutique:
		return
	_retirer_essai()
	_essai_article = article
	_essai_t = 0.0
	var a := Cosmetiques.article(article)
	var famille: String = a.get("famille", "")
	var t := Ronde.repere_roulotte()
	_essai = Bouille.new()
	_essai.apparence = Bouille.decoder(apparence)
	_essai.autonome = true
	_essai.nom_affiche = ""
	ronde.add_child(_essai)
	_essai.global_transform = Transform3D(t.basis.rotated(Vector3.UP, 0.35), t * Roulotte.place_essai())
	if _tete_on and _ma_tete.size() == 2:
		_essai.poser_photo(_ma_tete[0], _ma_tete[1])
	var c := Cosmetiques.lire(apparence)
	match famille:
		"fantome":
			_essai.fantome.call_deferred(true)
		"mort":
			# On la joue tout de suite, puis le personnage revient.
			EffetMort.jouer(ronde, _essai, str(a["valeur"]))
			_essai.visible = false
		"emote":
			_essai.jouer_emote.call_deferred(str(a["valeur"]))
		"maison":
			_maison_essai = Ronde.maison_de_la_roulotte()
			ronde.parer_maison(_maison_essai, str(a["valeur"]))
		"tombe":
			_essai_extra = Parures.tombe(str(a["valeur"]))
			ronde.add_child(_essai_extra)
			_essai_extra.global_transform = Transform3D(t.basis.rotated(Vector3.UP, -0.5), t * (Roulotte.place_essai() + Vector3(-1.7, 0, 0.4)))
	if famille == "pack" or famille == "":
		if str(c["maison"]) != "":
			_maison_essai = Ronde.maison_de_la_roulotte()
			ronde.parer_maison(_maison_essai, str(c["maison"]))


## La caméra de la roulotte : l'étal à gauche de l'écran (le panneau est à droite), le personnage
## au premier plan. Une mort, une tombe ou une maison s'essaient avec un plan un peu plus large.
func _cam_roulotte(delta: float) -> void:
	var t := Ronde.repere_roulotte()
	var a := Cosmetiques.article(_essai_article)
	var large: bool = a.get("famille", "") in ["maison", "tombe", "mort", "familier", "trace"]
	var pos := t * (Vector3(0.4, 2.6, 11.0) if large else Vector3(0.3, 2.2, 8.6))
	var vise := t * (Vector3(4.0, 1.4, 2.4) if large else Vector3(3.3, 1.25, 1.8))
	var voulu := Transform3D(Basis.looking_at(vise - pos, Vector3.UP), pos)
	_cam_menu.global_transform = _cam_menu.global_transform.interpolate_with(voulu, clampf(delta * 2.5, 0, 1))
	if _essai == null:
		return
	_essai_t += delta
	var fam: String = a.get("famille", "")
	if fam == "mort" and _essai_t > 5.0 and not _essai.visible:
		_essai.visible = true
	# Une trace ou un familier se voient mieux en marchant : un petit tour sur le tapis.
	if fam in ["trace", "familier"]:
		var base := t * Roulotte.place_essai()
		var ang := _essai_t * 0.9
		var rayon := 1.1
		var p := base + t.basis * Vector3(cos(ang) * rayon, 0, sin(ang) * rayon)
		var avant := _essai.global_position
		_essai.global_position = p
		if (p - avant).length() > 0.001:
			_essai.look_at(p + (p - avant), Vector3.UP)
			_essai.rotate_object_local(Vector3.UP, PI)
		_essai.marcher(1.0)
	_essai.regarder(_cam_menu.global_position)


## On quitte le lobby ou la partie : connexion fermée, lobby retiré, et le jeu repart
## propre depuis le menu (la scène est rechargée ; caméra et réglages restent).
func _retour_menu(message: String) -> void:
	if _trace_pubs:
		print("[retour menu] ", message)
		print_stack()
	Lobbies.fermer()
	Voix.partie(false)
	Voix.arreter()
	Reseau.quitter()
	message_retour = message
	get_tree().reload_current_scene()


# ================================================================ luciole (calibrage du regard)

const T_VOL := 0.7
const T_POSE := 0.35
const T_MESURE := 0.85
var _cibles: Array[Vector2] = []
var _i_cible := 0
var _phase_t := 0.0
var _depart := Vector2.ZERO
var _erreurs: Array[float] = []
var _predits: Array[Vector2] = []


func _commencer_luciole() -> void:
	if Capteur.mode_souris:
		Capteur.activer_souris(false)
		Options.regler("camera/utiliser", true)
	Regard.ecran_pouces = _spin_pouces.value
	Regard.annoncer_distance(_spin_distance.value)
	Regard.vider_calibrage()
	var vue := get_viewport().get_visible_rect().size
	var m := vue * 0.08
	var xs := [m.x, vue.x * 0.5, vue.x - m.x]
	var ys := [m.y, vue.y * 0.5, vue.y - m.y]
	_cibles = [Vector2(xs[1], ys[1])]
	for j in 3:
		for i in 3:
			var ii := i if j % 2 == 0 else 2 - i
			var p := Vector2(xs[ii], ys[j])
			if p != _cibles[0]:
				_cibles.append(p)
	_cibles.append(Vector2(xs[1], ys[1]))
	_i_cible = 0
	_phase_t = 0.0
	_depart = vue * 0.5
	_luciole.pos = _depart
	_aller("luciole")


func _commencer_verif() -> void:
	var vue := get_viewport().get_visible_rect().size
	_cibles = [vue * Vector2(0.3, 0.3), vue * Vector2(0.72, 0.35), vue * Vector2(0.65, 0.72), vue * Vector2(0.28, 0.68)]
	_i_cible = 0
	_phase_t = 0.0
	_depart = _luciole.pos
	_erreurs.clear()
	_predits.clear()
	_aller("verif")


func _luciole_avance(delta: float) -> void:
	_phase_t += delta
	var cible: Vector2 = _cibles[_i_cible]
	var k := clampf(_phase_t / T_VOL, 0, 1)
	k = k * k * (3 - 2 * k)
	_luciole.pos = _depart.lerp(cible, k) + Vector2(sin(_t * 9), cos(_t * 7)) * 3.0 * (1.0 - k)
	_luciole.mesure = _phase_t > T_VOL + T_POSE
	if etape == "luciole" and _i_cible == 0 and _phase_t > T_VOL + T_POSE * 0.8 and _phase_t - delta <= T_VOL + T_POSE * 0.8:
		Regard.noter_neutre()
	if _luciole.mesure and Capteur.visage_vu() and Capteur.ouverture_yeux() > 0.5:
		if etape == "luciole":
			Regard.ajouter(cible)
		else:
			_predits.append(Regard.point_brut())
	if _phase_t >= T_VOL + T_POSE + T_MESURE:
		if etape == "verif" and _predits.size() > 3:
			var moy := Vector2.ZERO
			for p in _predits:
				moy += p
			moy /= _predits.size()
			_erreurs.append(moy.distance_to(cible))
		_predits.clear()
		_i_cible += 1
		_phase_t = 0.0
		_depart = cible
		if _i_cible >= _cibles.size():
			if etape == "luciole":
				if Regard.ajuster():
					_commencer_verif()
				else:
					_texte_resultat.text = "Je n'ai pas assez vu tes yeux.\nPlace-toi face à la caméra, bien éclairé, et recommence."
					_aller("resultat")
			else:
				_fin_verif()


func _fin_verif() -> void:
	var px := 0.0
	for e in _erreurs:
		px += e
	px /= maxf(_erreurs.size(), 1)
	var cm := px / Regard.pixels_par_cm()
	Regard.precision_cm = cm
	Regard.sauver()
	var avis := "Excellent : tu sauras qui tu regardes, même au Conseil à 12."
	if cm > 4.5:
		avis = "Faible : rapproche-toi d'une lumière (face à toi, pas derrière) et recommence."
	elif cm > 2.5:
		avis = "Bon : largement assez pour savoir quel joueur tu regardes."
	_texte_resultat.text = Langue.t("Précision du regard : %.1f cm sur ton écran") % cm + "\n" + Langue.t(avis)
	_aller("resultat")


# ================================================================ boucle

## Essais : --photo=<fichier.png> enregistre l'écran au bout de --photo-t secondes (6 par
## défaut) puis quitte ; --ouvrir=reglages|volumes ouvre ce panneau juste avant.
var _photo := ""
var _photo_t := 6.0
var _photo_n := 0


func _photo_essai(delta: float) -> void:
	if _photo == "":
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--photo="):
				_photo = a.substr(8)
			elif a.begins_with("--photo-t="):
				_photo_t = float(a.substr(10))
		if _photo == "":
			_photo = "-"
	if _photo == "-":
		return
	var avant := _photo_t
	_photo_t -= delta
	if avant > 1.0 and _photo_t <= 1.0:
		for a in OS.get_cmdline_user_args():
			if a == "--ouvrir=reglages":
				if etape == "jeu" or etape == "pause":
					_aller("pause")
					_montrer_options_jeu(true)
				else:
					_menu.ecran("options")
			elif a == "--ouvrir=volumes" and etape == "jeu":
				_basculer_volumes()
			elif a == "--ouvrir=pause" and etape == "jeu":
				_aller("pause")
	if _photo_t <= 0.0:
		# --photo-tous=N : une photo toutes les N secondes (photo_1.png, photo_2.png…) jusqu'à la fin.
		var tous := 0.0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--photo-tous="):
				tous = float(a.substr(13))
		if tous > 0.0:
			_photo_n += 1
			get_viewport().get_texture().get_image().save_png(_photo.get_basename() + "_%02d.png" % _photo_n)
			print("[photo %02d] phase=%s mode=%s pos=%s guide=%d bloque=%.1f auto=%d" % [_photo_n, _phase(), mode, corps_joueur.global_position.snapped(Vector3.ONE * 0.1), _guide.size(), _guide_bloque, _auto_chemin.size()])
			_photo_t = tous
			return
		get_viewport().get_texture().get_image().save_png(_photo)
		get_tree().quit()


## Essai des carnets (--essai-carnet=<dossier>) : au premier jour, on entre chez soi, on prend
## le carnet, on écrit, on déchire, on pose la page sur la table ; une photo à chaque geste.
var _essai_carnet := ""


func _essai_carnet_lancer() -> void:
	var dossier := _essai_carnet
	_essai_carnet = "-"
	var m := _ma_maison()
	var photo := func(n: String):
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png("%s/carnet_%s.png" % [dossier, n])
	var table := Ronde.table_carnet(m)
	var ici := Ronde.siege_lit(m).lerp(table, 0.35)
	ici.y = 0
	_appliquer_placement(ici, table, "libre")
	tete.rotation.x = -0.55
	# D'abord dehors, de l'autre côté du mur : le carnet ne doit pas se prendre à travers.
	for k in 16:
		var dehors := table + Vector3(cos(k * TAU / 16), 0, sin(k * TAU / 16)) * 1.15
		dehors.y = 0
		if Ronde.maison_de(dehors) < 0:
			_appliquer_placement(dehors, table, "libre")
			tete.rotation.x = -0.4
			await photo.call("0_dehors")
			print("[carnet] dehors : ", _action_possible()[0] if not _action_possible().is_empty() else "(rien)")
			break
	_appliquer_placement(ici, table, "libre")
	tete.rotation.x = -0.55
	await photo.call("1_table")
	print("[carnet] action : ", _action_possible()[0] if not _action_possible().is_empty() else "(rien)")
	(_action_objet()[1] as Callable).call()
	await photo.call("2_en_main")
	var clic := func(bouton: int):
		var ev := InputEventMouseButton.new()
		ev.button_index = bouton
		ev.pressed = true
		# Au centre, comme une vraie souris captée : c'est là que le carnet ouvert avalait les clics.
		ev.position = get_viewport().get_visible_rect().size * 0.5
		ev.global_position = ev.position
		Input.parse_input_event(ev)
		await get_tree().create_timer(0.4).timeout
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Clic gauche : ouvert en lecture, la souris reste captée.
	await clic.call(MOUSE_BUTTON_LEFT)
	print("[carnet] clic gauche : visible=%s ecriture=%s souris_captee=%s" % [_carnet.visible, _carnet.ecriture, Input.mouse_mode == Input.MOUSE_MODE_CAPTURED])
	await photo.call("3_lecture_bandeaux")
	await clic.call(MOUSE_BUTTON_WHEEL_DOWN)
	print("[carnet] molette : page %d" % (_carnet._page + 1))
	await photo.call("4_lecture_page2")
	await clic.call(MOUSE_BUTTON_WHEEL_UP)
	print("[carnet] molette arrière : page %d" % (_carnet._page + 1))
	# Clic droit : la plume se pose.
	await clic.call(MOUSE_BUTTON_WHEEL_DOWN)
	await clic.call(MOUSE_BUTTON_RIGHT)
	print("[carnet] clic droit : ecriture=%s souris_visible=%s" % [_carnet.ecriture, Input.mouse_mode == Input.MOUSE_MODE_VISIBLE])
	_carnet._ecrit.text = "Rosalie ment. Je l'ai vue près du puits avant la nuit."
	_stylo_ecrit()
	_carnet._stylo_2d.ecrire()
	await photo.call("5_ecriture")
	_carnet._ecrit.gui_input.emit(_evenement_clic(MOUSE_BUTTON_RIGHT))
	await get_tree().create_timer(0.3).timeout
	print("[carnet] clic droit encore : ecriture=%s souris_captee=%s" % [_carnet.ecriture, Input.mouse_mode == Input.MOUSE_MODE_CAPTURED])
	await clic.call(MOUSE_BUTTON_RIGHT)
	_carnet.tourner(-1)
	await get_tree().create_timer(0.2).timeout
	await photo.call("6_bandeaux_ecriture")
	# Le sélecteur : clic sur une ligne, puis sur une autre = inversion ; clic sur un joueur de la liste.
	print("[carnet] page bandeaux avant : ", _carnet._ecrit.text.replace("\n", " / "))
	_carnet._clic_ligne(0)
	await photo.call("6b_bandeaux_ligne_choisie")
	_carnet._clic_ligne(2)
	print("[carnet] après inversion 0<->2 : ", _carnet._ecrit.text.replace("\n", " / "))
	await photo.call("6c_bandeaux_inverses")
	_carnet._clic_ligne(1)
	var liste_j: Array = _pseudos_de_la_partie()
	_carnet._clic_joueur(liste_j[liste_j.size() - 1])
	print("[carnet] après choix dans la liste : ", _carnet._ecrit.text.replace("\n", " / "))
	_carnet.ecrire(false)
	await get_tree().create_timer(0.6).timeout
	var hote_page: String = str(_vue_objets.objet(_carnet._id)["pages"][0])
	print("[carnet] page 0 chez l'hôte : ", hote_page.replace("\n", " / "))
	_carnet.ecrire(true)
	await photo.call("6d_bandeaux_apres_liste")
	_carnet.ecrire(false)
	await clic.call(MOUSE_BUTTON_WHEEL_DOWN)
	await photo.call("7_page_ecrite_lecture")
	await clic.call(MOUSE_BUTTON_LEFT)
	print("[carnet] clic gauche : ferme visible=%s" % _carnet.visible)
	# Carnet fermé en main : clic droit l'ouvre directement en écriture.
	await clic.call(MOUSE_BUTTON_RIGHT)
	print("[carnet] clic droit carnet fermé : visible=%s ecriture=%s" % [_carnet.visible, _carnet.ecriture])
	_carnet.ecrire(false)
	await clic.call(MOUSE_BUTTON_LEFT)
	_lire_objet()
	_carnet._page = 1
	_carnet.ecrire(true)
	_carnet._arracher()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await photo.call("8_dechiree")
	_poser_objet()
	await photo.call("5_posee")
	for o: Dictionary in _vue_objets._etat.values():
		if o["porteur"] != -1 or o["sorte"] == "page" or int(o["maison"]) == m:
			print("[carnet] %s maison=%d porteur=%d texte=%s pages=%s" % [o["sorte"], o["maison"], o["porteur"], o.get("texte", ""), str((o["pages"] as Array).size())])
	# Inventaire : molette = case suivante, en boucle ; une case vide = mains vides.
	if _carnet.visible:
		_carnet_fermer()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var attente := 0
	while not _inventaire_ouvert_au_jeu() and attente < 240:
		await get_tree().create_timer(0.5).timeout
		attente += 1
	print("[inv] phase=%s au_poste=%s utilisable=%s" % [_phase(), _au_poste(), _inventaire_ouvert_au_jeu()])
	print("[inv] départ : case=%d en_main=%d slots=%s" % [_slot_courant(), _vue_objets.en_main(), str(_vue_objets.mes_slots())])
	for k in 5:
		await clic.call(MOUSE_BUTTON_WHEEL_DOWN)
		await get_tree().create_timer(0.3).timeout
		print("[inv] molette bas : case=%d en_main=%d" % [_slot_courant(), _vue_objets.en_main()])
		if k == 1:
			await photo.call("9_molette_case_vide")
	await clic.call(MOUSE_BUTTON_WHEEL_UP)
	await get_tree().create_timer(0.3).timeout
	print("[inv] molette haut : case=%d en_main=%d" % [_slot_courant(), _vue_objets.en_main()])
	# Au poste d'un mini-jeu : rien ne bouge, l'inventaire est masqué.
	_choisir_slot(0)
	await get_tree().create_timer(0.4).timeout
	print("[inv] carnet en main avant le poste : en_main=%d" % _vue_objets.en_main())
	attente = 0
	while not _au_poste() and attente < 400:
		await get_tree().create_timer(0.5).timeout
		attente += 1
	print("[inv] au_poste=%s phase=%s mode=%s" % [_au_poste(), _phase(), mode])
	if _au_poste():
		var avant := _vue_objets.mes_slots()
		var main_avant := _vue_objets.en_main()
		_choisir_slot(2)
		_poser_objet()
		_envoyer_intention("obj_choisir", 2)       # même en forçant l'intention : l'hôte l'ignore
		_envoyer_intention("obj_poser", Vector3.ZERO, 0.0)
		await clic.call(MOUSE_BUTTON_WHEEL_DOWN)
		await get_tree().create_timer(0.5).timeout
		print("[inv] au poste : slots identiques=%s main identique=%s inventaire_visible_slots=%s" % [avant == _vue_objets.mes_slots(), main_avant == _vue_objets.en_main(), str(_inventaire._slots)])
		await photo.call("10_au_poste")
	get_tree().quit()


func _evenement_clic(bouton: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = bouton
	ev.pressed = true
	return ev


## Essai du moulin (--essai-moulin=<dossier>) : un HUMAIN (moi) qui joue la quête comme on le fait à la souris :
## viser la manivelle, tenir le clic gauche, tracer des cercles. Dit si l'hôte compte des coups.
var _essai_moulin := ""


func _essai_moulin_lancer() -> void:
	var dossier := _essai_moulin
	_essai_moulin = "-"
	var photo := func(n: String):
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png("%s/moulin_%s.png" % [dossier, n])
	await get_tree().create_timer(2.0).timeout
	var mj: MiniJeu = null
	for q in meneur._quetes:
		if q["etat"] == "jeu":
			mj = q["mj"]
	print("[moulin] état : phase=%s mode=%s souris=%s inventaire_bloque=%s" % [_phase(), mode, Input.mouse_mode, _au_poste()])
	var cible: Node3D = _monde_quete.decor.cible_geste()
	var d := cible.global_position - camera.global_position
	corps_joueur.rotation.y = atan2(-d.x, -d.z)
	tete.rotation.x = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.2, 1.2)
	await get_tree().create_timer(0.3).timeout
	print("[moulin] je regarde la manivelle : %s (geste attendu %s)" % [_monde_quete.regarde(cible), _monde_quete._geste_attendu()])
	await photo.call("1_vise")
	var presse := InputEventMouseButton.new()
	presse.button_index = MOUSE_BUTTON_LEFT
	presse.pressed = true
	presse.position = get_viewport().get_visible_rect().size * 0.5
	Input.parse_input_event(presse)
	await get_tree().create_timer(0.3).timeout
	print("[moulin] après le clic : prise=%s" % _monde_quete._prise)
	var t := 0.0
	var angle := 0.0
	while t < 20.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		var avant := angle
		angle += get_process_delta_time() * TAU * 0.9
		var mv := InputEventMouseMotion.new()
		mv.relative = (Vector2(sin(angle), -cos(angle)) - Vector2(sin(avant), -cos(avant))) * 90.0
		Input.parse_input_event(mv)
	await photo.call("2_tourne")
	print("[moulin] coups comptés par l'hôte pour moi : %s (jeu=%s, temps=%.1f, prise=%s)" % [str(mj.get("coups").get(_moi_id(), "?")) if mj != null else "-", str(mj != null), mj.temps if mj != null else -1.0, _monde_quete._prise])
	get_tree().quit()


## Essai du livre (--essai-livre=<dossier>) : le sélecteur de pseudos avec de VRAIS clics et la vraie touche Échap,
## puis fermer le livre, puis le jeter (ouvert ou fermé) et le revoir au sol.
var _essai_livre := ""


func _essai_souris(pos: Vector2, bouton: int = MOUSE_BUTTON_LEFT) -> void:
	for oui: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = bouton
		ev.pressed = oui
		ev.position = pos
		ev.global_position = pos
		Input.parse_input_event(ev)
		await get_tree().create_timer(0.08).timeout


func _essai_touche_echap() -> void:
	for oui: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.physical_keycode = KEY_ESCAPE
		ev.pressed = oui
		Input.parse_input_event(ev)
		await get_tree().create_timer(0.08).timeout


func _essai_livre_boutons(n: Node, r: Array) -> void:
	if n is Button and (n as Button).is_visible_in_tree():
		r.append(n)
	for c in n.get_children():
		_essai_livre_boutons(c, r)


func _essai_livre_lancer() -> void:
	var dossier := _essai_livre
	_essai_livre = "-"
	var m := _ma_maison()
	var photo := func(n: String):
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png("%s/livre_%s.png" % [dossier, n])
	var table := Ronde.table_carnet(m)
	var ici := Ronde.siege_lit(m).lerp(table, 0.35)
	ici.y = 0
	_appliquer_placement(ici, table, "libre")
	tete.rotation.x = -0.55
	await get_tree().create_timer(0.8).timeout
	(_action_objet()[1] as Callable).call()
	await get_tree().create_timer(0.5).timeout
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var centre := get_viewport().get_visible_rect().size * 0.5
	var etat := func(t: String):
		var o := _vue_objets.objet(_carnet._id) if _carnet._id >= 0 else {}
		print("[livre] %s : visible=%s ecriture=%s souris=%s main=%d ouvert=%s" % [t, _carnet.visible, _carnet.ecriture, Input.mouse_mode, _vue_objets.en_main(), o.get("ouvert", "?")])
	# Plusieurs façons de modifier un pseudo puis de fermer : chacune doit finir livre fermé.
	for variante: String in ["echap_puis_clic", "clic_droit_puis_clic", "bouton_plume_puis_clic", "liste_puis_echap_echap", "touche_L"]:
		await _essai_souris(centre)
		await etat.call(variante + " ouvert")
		await _essai_souris(centre, MOUSE_BUTTON_RIGHT)
		var bs: Array = []
		_essai_livre_boutons(_carnet._sel_lignes, bs)
		await _essai_souris((bs[0] as Button).get_global_rect().get_center())
		if variante.begins_with("liste"):
			var bj: Array = []
			_essai_livre_boutons(_carnet._sel_joueurs, bj)
			await _essai_souris((bj[2] as Button).get_global_rect().get_center())
		else:
			bs = []
			_essai_livre_boutons(_carnet._sel_lignes, bs)
			await _essai_souris((bs[2] as Button).get_global_rect().get_center())
		await etat.call(variante + " après modification")
		match variante:
			"echap_puis_clic", "liste_puis_echap_echap":
				await _essai_touche_echap()
			"clic_droit_puis_clic":
				await _essai_souris(centre, MOUSE_BUTTON_RIGHT)
			"bouton_plume_puis_clic":
				var bb: Array = []
				_essai_livre_boutons(_carnet._bas, bb)
				await _essai_souris((bb[bb.size() - 1] as Button).get_global_rect().get_center())
		await etat.call(variante + " plume levée")
		if variante == "touche_L":
			var ev := InputEventKey.new()
			ev.keycode = KEY_L
			ev.physical_keycode = KEY_L
			ev.pressed = true
			Input.parse_input_event(ev)
			await get_tree().create_timer(0.3).timeout
		elif variante == "liste_puis_echap_echap":
			await _essai_touche_echap()
			await get_tree().create_timer(0.3).timeout
			print("[livre] etape=%s" % etape)
			if etape == "pause":
				await _essai_touche_echap()
				print("[livre] après reprise : etape=%s visible=%s souris=%s" % [etape, _carnet.visible, Input.mouse_mode])
				await _essai_souris(centre)
		else:
			await _essai_souris(centre)
		await etat.call(variante + " FIN")
		if _carnet.visible:
			print("[livre] !!! NE SE FERME PAS : %s" % variante)
			await photo.call("bloque_" + variante)
			_carnet_fermer()
	# Jeter le livre : fermé sur la table, puis dehors (regard à l'horizontale), puis « ouvert » en main sans panneau.
	await _essai_livre_jet("fermé, à la table")
	await photo.call("jet_table")
	_prendre_livre_au_sol()
	await get_tree().create_timer(0.8).timeout
	var table2 := Ronde.table_carnet(m)
	for k in 16:
		var dehors := table2 + Vector3(cos(k * TAU / 16), 0, sin(k * TAU / 16)) * 3.2
		dehors.y = 0
		if Ronde.maison_de(dehors) < 0:
			_appliquer_placement(dehors, dehors + Vector3(0, 0, 5), "libre")
			tete.rotation.x = -0.15
			break
	await get_tree().create_timer(0.5).timeout
	await _essai_livre_jet("fermé, dehors")
	await photo.call("jet_dehors")
	for id in _vue_objets._etat:
		var o: Dictionary = _vue_objets._etat[id]
		if o["sorte"] == "carnet" and o["porteur"] == -1 and int(o["maison"]) == m:
			var l: Vector3 = o["pos"]
			print("[livre] au sol en %s, joueur en %s" % [str(l), str(corps_joueur.global_position)])
			var d := (corps_joueur.global_position - l)
			d.y = 0
			var vu := l + d.normalized() * 1.0
			_appliquer_placement(vu, l, "libre")
			tete.rotation.x = -0.5
			await get_tree().create_timer(0.8).timeout
			await photo.call("jet_dehors_regarde")
	_prendre_livre_au_sol()
	get_tree().quit()


func _prendre_livre_au_sol() -> void:
	for id in _vue_objets._etat:
		var o: Dictionary = _vue_objets._etat[id]
		if o["sorte"] == "carnet" and int(o["maison"]) == _ma_maison() and o["porteur"] == -1:
			_appliquer_placement(Ronde.table_carnet(_ma_maison()) + Vector3(0.8, -0.8, 0.8), Ronde.table_carnet(_ma_maison()), "libre")
			_envoyer_intention("obj_prendre", id)
			print("[livre] reprise du livre %d" % id)
			return
	print("[livre] !!! plus de livre au sol")


func _essai_livre_jet(t: String) -> void:
	var avant_id := _vue_objets.en_main()
	print("[livre] jet %s : en main=%d" % [t, avant_id])
	_lancer_en_main()
	for k in 14:
		await get_tree().create_timer(0.25).timeout
		if avant_id >= 0:
			var o := _vue_objets.objet(avant_id)
			var n: Node3D = _vue_objets._noeuds.get(avant_id)
			print("[livre]  t=%.2f porteur=%s pos=%s noeud_visible=%s" % [(k + 1) * 0.25, str(o.get("porteur")), str(o.get("pos")), str(n.is_visible_in_tree()) if n else "aucun"])


## Essai de l'intérieur (--essai-interieur=<dossier>) : cinq coups d'œil dans sa maison, une photo chacun.
var _essai_interieur := ""


func _essai_interieur_lancer() -> void:
	var dossier := _essai_interieur
	_essai_interieur = "-"
	var m := _ma_maison()
	# [où je me tiens, ce que je regarde, inclinaison de la tête], dans le repère de la maison.
	var vues := [
		["a_lit_et_table", Vector3(1.5, 0, 1.3), Vector3(-1.2, 1.0, -1.2), 0.0],
		["b_atre", Vector3(1.5, 0, 0.9), Vector3(-2.0, 0.9, 0.9), 0.0],
		["c_lit", Vector3(-1.2, 0, 0.9), Vector3(1.6, 0.6, -0.5), -0.1],
		["d_plafond", Vector3(1.4, 0, 1.2), Vector3(-0.5, 2.8, -0.2), 0.7],
		["e_fond", Vector3(1.5, 0, 1.4), Vector3(0.5, 1.5, -1.8), 0.0],
		["f_sol", Vector3(0.4, 0, 1.0), Vector3(-0.4, 0, 0.4), -0.6],
	]
	# Une maison qui a un âtre (selon ses fenêtres) : on s'y rend pour le regarder.
	var j := -1
	for k in ronde._maisons.size():
		if (ronde._maisons[k] as Node).find_child("Atre", true, false) != null:
			j = k
			break
	if j >= 0:
		vues.append(["g_atre_maison%d" % j, Vector3(0.3, 0, -0.5), Vector3(-2.0, 0.8, 0.95), -0.05, j])
		vues.append(["h_atre_loin", Vector3(1.0, 0, -0.9), Vector3(-2.0, 0.9, 1.0), 0.0, j])
	await get_tree().create_timer(1.0).timeout
	for v: Array in vues:
		if v.size() > 4:
			m = v[4]
		var ici: Vector3 = Ronde._vers_monde(m, v[1])
		var cible: Vector3 = Ronde._vers_monde(m, v[2])
		ici.y = 0
		_appliquer_placement(ici, cible, "libre")
		tete.rotation.x = v[3]
		await get_tree().create_timer(0.9).timeout
		get_viewport().get_texture().get_image().save_png("%s/interieur_%s.png" % [dossier, v[0]])
	get_tree().quit()


## Essai monde (--essai-monde=<dossier>[:nuit]) : vues de dessus du village, marche autour du chemin de ronde
## (test_move, collisions sur la sortie), maisons et objets au sol, familier. Photos dans le dossier.
var _essai_monde := ""
var _ambiance_forcee := ""


func _essai_monde_scan(n: Node) -> void:
	# Liste tout ce qui contient le point (18,1.5,10.5) : maillages et instances de multimesh.
	var pt := Vector3(18.0, 1.5, 10.5)
	for c in n.get_children():
		if c is MultiMeshInstance3D:
			var mm: MultiMesh = (c as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null:
				continue
			var bb := mm.mesh.get_aabb()
			for i in mm.instance_count:
				var tb: AABB = ((c as Node3D).global_transform * mm.get_instance_transform(i)) * bb
				if tb.grow(0.5).has_point(pt):
					print("[scan] mm %s #%d taille=%s pos=%s parent=%s" % [mm.mesh.resource_path, i, tb.size.snapped(Vector3.ONE * 0.1), tb.get_center().snapped(Vector3.ONE * 0.1), c.get_parent().name])
		elif c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var tb2: AABB = (c as Node3D).global_transform * (c as MeshInstance3D).mesh.get_aabb()
			if tb2.grow(0.5).has_point(pt):
				print("[scan] mi %s %s taille=%s pos=%s parent=%s" % [c.name, (c as MeshInstance3D).mesh.resource_path, tb2.size.snapped(Vector3.ONE * 0.1), tb2.get_center().snapped(Vector3.ONE * 0.1), c.get_parent().name])
		if c.get_child_count() > 0 and not (c is MultiMeshInstance3D):
			_essai_monde_scan(c)


## Mesure des pics de luminosité : on tourne sur place, une image sur deux est mesurée (luminance moyenne,
## part de pixels quasi blancs) ; les sauts d'une mesure à la suivante sont écrits sur la sortie.
func _essai_monde_flash(options: String) -> void:
	ecran.visible = false
	var spots := [Vector3(0, 0, 8.0), Vector3(9.0, 0, 18.0), Vector3(-6.0, 0, -9.0)]
	var prec_l := -1.0
	var pires := []
	for sp: Vector3 in spots:
		corps_joueur.global_position = sp
		corps_joueur.velocity = Vector3.ZERO
		for k in 180:
			corps_joueur.rotation.y += deg_to_rad(2.5)
			tete.rotation.x = 0.1 * sin(k * 0.13)
			await get_tree().process_frame
			if k % 2 == 0:
				var im := get_viewport().get_texture().get_image()
				im.resize(160, 90)
				var somme := 0.0
				var blancs := 0
				for y in 90:
					for x in 160:
						var c := im.get_pixel(x, y)
						var l := c.get_luminance()
						somme += l
						if l > 0.93:
							blancs += 1
				var lm := somme / 14400.0
				if prec_l >= 0.0:
					pires.append([absf(lm - prec_l), lm, blancs, sp, k])
				prec_l = lm
	pires.sort_custom(func(a, b): return a[0] > b[0])
	for k in mini(8, pires.size()):
		print("[flash] saut=%.3f lum=%.3f blancs=%d spot=%s k=%d" % pires[k])
	var maxb := 0
	for p: Array in pires:
		maxb = maxi(maxb, int(p[2]))
	print("[flash] max pixels quasi blancs (sur 14400) : ", maxb)


## Collé à une porte fermée puis à un mur, en villageois et en loup : la caméra ne doit pas passer derrière.
func _essai_monde_mur(dossier: String) -> void:
	ecran.visible = false
	var m := _ma_maison()
	meneur._porte_rpc(m, "avant", false)
	var cas := [
		["porte", Vector3(0, 0, Ronde.PROFONDEUR * 0.5 + 0.9), Vector3(0, 1.5, 0)],
		["mur", Vector3(Ronde.LARGEUR * 0.5 + 0.9, 0, 0.0), Vector3(0, 1.5, 0)],
	]
	for loup: bool in [false, true]:
		moi.devenir_loup(loup)
		for c: Array in cas:
			var ici: Vector3 = Ronde._vers_monde(m, c[1])
			var cible: Vector3 = Ronde._vers_monde(m, c[2])
			_appliquer_placement(ici, cible, "libre")
			# On pousse vers le mur pendant une seconde.
			var d := (cible - ici)
			d.y = 0.0
			d = d.normalized()
			for k in 50:
				corps_joueur.velocity = d * 3.0
				await get_tree().physics_frame
			for incl: float in [0.0, 0.5, -0.5]:
				tete.rotation.x = incl
				await get_tree().create_timer(0.2).timeout
				get_viewport().get_texture().get_image().save_png("%s/mur_%s_%s_%d.png" % [dossier, c[0], "loup" if loup else "villageois", int(incl * 10)])
			print("[mur] ", c[0], " loup=", loup, " camera a ", (camera.global_position - ici).length())
	moi.devenir_loup(false)


## Une photo face à l'âtre de chaque maison qui en a un : le conduit doit monter droit, rien ne le traverse.
func _essai_monde_atres(dossier: String) -> void:
	ecran.visible = false
	await get_tree().create_timer(1.0).timeout
	camera.top_level = true
	camera.far = 100.0
	for j in ronde._maisons.size():
		var at := (ronde._maisons[j] as Node).find_child("Atre", true, false) as Node3D
		if at == null:
			continue
		var p := at.global_position
		var vers := ((ronde._maisons[j] as Node3D).global_position - p)
		vers.y = 0.0
		var b := Basis(Vector3.UP, atan2(vers.x, vers.z))
		for v: Array in [["face", 2.6, 1.5, 1.6], ["haut", 1.7, 1.0, 2.2]]:
			camera.global_position = p + b.z * float(v[1]) + Vector3(0, float(v[2]), 0)
			camera.look_at(p + b.z * 0.2 + Vector3(0, float(v[3]), 0), Vector3.UP)
			await get_tree().create_timer(0.35).timeout
			get_viewport().get_texture().get_image().save_png("%s/atre_%02d_%s.png" % [dossier, j, v[0]])
		print("[atres] maison ", j)


func _essai_monde_hibou(dossier: String) -> void:
	ecran.visible = false
	ronde._env.fog_enabled = false
	var f := Familier.new()
	f.sorte = "chouette"
	f.maitre = moi
	moi.get_parent().add_child(f)
	moi.visible = true
	corps_joueur.global_position = Vector3(0, 0, 6.0)
	await get_tree().create_timer(2.5).timeout
	camera.top_level = true
	var fwd := moi.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var dr := fwd.cross(Vector3.UP).normalized()
	var vues := {
		"arriere": moi.global_position - fwd * 3.2 + Vector3(0, 2.3, 0),
		"cote": moi.global_position + dr * 3.0 + Vector3(0, 2.2, 0),
		"avant": moi.global_position + fwd * 3.0 + Vector3(0, 2.4, 0),
		"dessus": moi.global_position + Vector3(0, 6.0, 0.3) + fwd * 0.3,
		"proche": f.global_position + dr * 1.0 + fwd * 0.2 + Vector3(0, 0.15, 0),
	}
	for nom: String in vues:
		camera.global_position = vues[nom]
		camera.look_at(f.global_position, Vector3.UP if nom != "dessus" else fwd)
		await get_tree().create_timer(0.25).timeout
		get_viewport().get_texture().get_image().save_png("%s/hibou_%s.png" % [dossier, nom])
	# Marche : le hibou doit suivre derrière sans tourner.
	camera.top_level = false
	var pos0 := f.global_position
	for k in 6:
		await get_tree().create_timer(0.5).timeout
		print("[hibou] t=%d pos=%s rot=%.2f" % [k, (f.global_position - moi.global_position).snapped(Vector3.ONE * 0.01), f.rotation.y])


func _essai_monde_lancer() -> void:
	var arg := _essai_monde
	_essai_monde = "-"
	var dossier := arg.get_slice("|", 0)
	var options := arg.get_slice("|", 1) if arg.contains("|") else ""
	if "nuit" in options:
		_ambiance_forcee = "nuit"
	await get_tree().create_timer(2.0).timeout
	if "avant" in options:
		for l: OmniLight3D in ronde._bougies:
			if l.has_meta("base"):
				l.omni_range = 0.01
	if "scan" in options:
		_essai_monde_scan(ronde)
	ronde.regler_brume(false)
	if "brume" not in options:
		ronde._env.fog_enabled = false
	ecran.visible = false
	if "atres" in options:
		await _essai_monde_atres(dossier)
		get_tree().quit()
		return
	if "mur" in options:
		await _essai_monde_mur(dossier)
		get_tree().quit()
		return
	if "hibou" in options:
		await _essai_monde_hibou(dossier)
		get_tree().quit()
		return
	if "flash" in options:
		await _essai_monde_flash(options)
		get_tree().quit()
		return
	var cam_avant := camera.top_level
	camera.top_level = true
	var vues := [
		["haut_village", Vector3(0, 60, 0.1), Vector3.ZERO],
		["sol_a", Vector3(16.0, 1.7, 8.0), Vector3(21.5, 1.0, 11.8)],
		["sol_b", Vector3(24.0, 1.7, 17.0), Vector3(21.5, 1.0, 11.8)],
		["sol_c", Vector3(27.0, 3.0, 8.0), Vector3(21.5, 1.0, 11.8)],
		["haut_ronde_nord", Vector3(0, 30, 21.0), Vector3(0, 0, 21.0)],
		["haut_ronde_est", Vector3(21.0, 30, 0), Vector3(21.0, 0, 0)],
		["haut_ronde_sud", Vector3(0, 30, -21.0), Vector3(0, 0, -21.0)],
		["haut_ronde_ouest", Vector3(-21.0, 30, 0), Vector3(-21.0, 0, 0)],
	]
	if "marche" in options:
		vues = []
	if "tour" in options:
		vues = []
		for k in 12:
			var a := k * TAU / 12.0
			var r := (Ronde.R_CHEMIN_MIN + Ronde.R_CHEMIN_MAX) * 0.5
			var ici := Vector3(sin(a) * r, 1.7, cos(a) * r)
			var tang := Vector3(cos(a), 0, -sin(a))
			vues.append(["tour_%02d" % k, ici, ici + tang * 8.0 + Vector3(0, -0.6, 0)])
	if "facades" in options:
		vues = []
		for k in [0, 3, 6, 9]:
			var a: float = (k + 1) * TAU / float(Ronde.PLACES)
			var ici := Vector3(sin(a), 0, cos(a)) * (Ronde.R_MAISON + 7.0) + Vector3(0, 1.7, 0)
			vues.append(["facade_%02d" % k, ici, Vector3(sin(a), 0, cos(a)) * Ronde.R_MAISON + Vector3(0, 1.3, 0)])
	for v: Array in vues:
		camera.global_position = v[1]
		camera.look_at(v[2] + Vector3(0, 0, 0.01), Vector3.FORWARD if "tour" not in options else Vector3.UP)
		camera.far = 400.0
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dossier, v[0]])
		if v[0] == "haut_village":
			var vs := get_viewport().get_visible_rect().size
			for px: Vector2 in [Vector2(1010, 565), Vector2(1330, 520), Vector2(1400, 680), Vector2(470, 800)]:
				var pxs := px * vs / Vector2(1600, 900)
				var org := camera.project_ray_origin(pxs)
				var dr := camera.project_ray_normal(pxs)
				print("[essai-monde] pixel ", px, " -> sol ", Plane(Vector3.UP, 0).intersects_ray(org, dr))
	camera.top_level = cam_avant
	# Marche autour du village : test_move le long de trois cercles, 0,4 m par pas.
	var gens := 0
	for r: float in [Ronde.R_CHEMIN_MIN - 2.0, Ronde.R_CHEMIN_MIN - 1.0, Ronde.R_CHEMIN_MIN, Ronde.R_CHEMIN_MIN + 0.8, (Ronde.R_CHEMIN_MIN + Ronde.R_CHEMIN_MAX) * 0.5, Ronde.R_CHEMIN_MAX - 0.8, Ronde.R_CHEMIN_MAX, Ronde.R_CHEMIN_MAX + 1.0, Ronde.R_CHEMIN_MAX + 2.0, Ronde.R_CHEMIN_MAX + 3.0]:
		var pas := int(TAU * r / 0.4)
		var prec := Vector3(0, 0, r)
		prec.y = 0.1
		for k in range(1, pas + 1):
			var a := k * TAU / pas
			var p := Vector3(sin(a) * r, 0.1, cos(a) * r)
			corps_joueur.global_position = prec
			var col := KinematicCollision3D.new()
			if corps_joueur.test_move(corps_joueur.global_transform, p - prec, col):
				gens += 1
				print("[essai-monde] BLOCAGE r=%.1f angle=%.0f pos=(%.1f, %.1f) contre %s en %s parent=%s" % [r, rad_to_deg(a), p.x, p.z, col.get_collider(), (col.get_collider() as Node3D).global_position, (col.get_collider() as Node).get_parent().name])
			prec = p
	print("[essai-monde] marche autour du village : %d blocages" % gens)
	if "tour" in options:
		get_tree().quit()
		return
	get_tree().quit()



## Essai de la marche guidée depuis l'intérieur (--essai-marche-maison=<dossier>[:nuit]) : on se place dans sa
## maison, porte close, puis on la quitte en marche guidée vers sa souche ; une photo toutes les 0,4 s, et le
## suivi (position dans le repère de la maison, état de la porte) sur la sortie.
var _essai_marche := ""


func _essai_marche_lancer() -> void:
	var dossier := _essai_marche
	_essai_marche = "-"
	var m := _ma_maison()
	var lit := Ronde._vers_monde(m, Vector3(-1.2, 0, -0.9))
	meneur._porte_rpc(m, "avant", false)
	await get_tree().create_timer(0.8).timeout
	_appliquer_placement(lit, Ronde._vers_monde(m, Vector3(0, 0.9, 3.0)), "libre")
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("%s/marche_00.png" % dossier)
	_sur_placement(Ronde.souche(m), Vector3(0, 0.9, 0), "libre")
	print("[essai-marche] guide : ", _guide.size(), " points, portes ", _guide_portes)
	var k := 1
	var fini := false
	for t in 60:
		await get_tree().create_timer(0.2).timeout
		var l := Ronde._vers_local(m, corps_joueur.global_position)
		print("[essai-marche] t=%.1f local=(%.2f, %.2f) porte avant=%s mode=%s guide=%d" % [t * 0.2, l.x, l.z, ronde.porte_ouverte(m, "avant"), mode, _guide.size()])
		if t < 12 or t % 4 == 1:
			get_viewport().get_texture().get_image().save_png("%s/marche_%02d.png" % [dossier, k])
			k += 1
		if _guide.is_empty() and t > 5:
			fini = true
			break
	print("[essai-marche] fini=", fini, " position=", corps_joueur.global_position, " dehors=", Ronde.maison_de(corps_joueur.global_position) != m)
	get_tree().quit()


## Essai (dev) : --essai-jeu=<jeu>:<niveau>:<taille> lance tout de suite ce mini-jeu avec des bots.
## Essai visuel (--essai-interface=<dossier>) : la note de quête ouverte puis réduite, la touche seule en
## bas, le message de vote en haut à gauche, la boîte de confirmation. Photos en fenêtre (--fenetre).
var _essai_if := ""
var _essai_if_fait := {}
var _essai_touche := ""      # force la touche du bas pour la photo


func _essai_interface_lancer(delta: float) -> void:
	if _essai_if == "":
		_essai_if = "-"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--essai-interface="):
				_essai_if = a.substr(18)
	if _essai_if == "-" or etape != "jeu":
		return
	var dossier := _essai_if
	if ecran.vote_quete_visible() and not _essai_if_fait.has("note"):
		_essai_if_fait["note"] = true
		_essai_interface_photos(dossier)
	elif _phase() in PHASES_VOTE and _vivant() and not _essai_if_fait.has("vote") and _vise_bouille >= 0:
		_essai_if_fait["vote"] = true
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png("%s/if_vote.png" % dossier)
		print("[interface] photo du vote")


func _essai_interface_photos(dossier: String) -> void:
	var photo := func(n: String):
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png("%s/if_%s.png" % [dossier, n])
		print("[interface] photo ", n)
	await photo.call("1_note_ouverte")
	ecran.basculer_note()
	await photo.call("2_note_reduite")
	ecran.basculer_note()
	_essai_touche = "agir"
	await photo.call("3_touche_seule")
	_essai_touche = ""
	_confirmer("Quitter la partie et revenir au menu ?", _quitter_partie)
	await photo.call("4_confirmation")
	print("[interface] confirmation ouverte : ", Confirmation.ouverte)
	var c: Node = null
	for n in get_children():
		if n is Confirmation:
			c = n
	if c != null:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().create_timer(0.5).timeout
		print("[interface] après Échap : ouverte = ", Confirmation.ouverte, " ; étape = ", etape)


var _essai_jeu := ""
var _essai_jeu_t := 0.0


func _essai_jeu_lancer(delta: float) -> void:
	if _essai_jeu == "":
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--essai-jeu="):
				_essai_jeu = a.substr(12)
		if _essai_jeu == "":
			_essai_jeu = "-"
	if _essai_jeu == "-" or etape != "jeu" or _phase() in ["salon", "fin"] or not meneur.est_hote():
		return
	_essai_jeu_t += delta
	if _essai_jeu_t < 3.0:
		return
	var p := _essai_jeu.split(":")
	meneur.test_jeu(p[0], p[1] if p.size() > 1 else "normal", "", int(p[2]) if p.size() > 2 else 6, "")
	_essai_jeu = "-"


## Essai (dev) : --essai-photos=<dossier>:<intervalle en s> enregistre une capture de la fenêtre à intervalle
## régulier tant qu'une partie tourne (pour regarder un mini-jeu joué par des bots, avec --essai-jeu).
var _photos := ""
var _photos_t := 0.0
var _photos_n := 0


func _essai_photos(delta: float) -> void:
	if _photos == "":
		_photos = "-"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--essai-photos="):
				_photos = a.substr(15)
	if _photos == "-" or etape != "jeu" or _phase() in ["salon", "fin"]:
		return
	var p := _photos.rsplit(":", true, 1)
	_photos_t += delta
	if _photos_t < (float(p[1]) if p.size() > 1 else 5.0):
		return
	_photos_t = 0.0
	_photos_n += 1
	get_viewport().get_texture().get_image().save_png("%s/photo_%03d.png" % [p[0], _photos_n])


## Diagnostic (--mesure-images) : chaque image lente (> 22 ms) est signalée, avec l'étape.
var _mesure_images := "--mesure-images" in OS.get_cmdline_user_args()


func _process(delta: float) -> void:
	if _trace_pubs and int(_t / 3.0) != int((_t + delta) / 3.0):
		print("[battement] t=%.1f phase=%s mode=%s" % [_t, _phase(), mode])
	_t += delta
	if _finir_apres > 0.0 and meneur.est_hote():
		var ph := _phase()
		_partie_t = 0.0 if ph in ["salon", "fin"] else _partie_t + delta
		if _partie_t > _finir_apres:
			_partie_t = 0.0
			print("[essai] fin forcée de la partie")
			meneur._terminer("village")
	if _mesure_images and delta > 0.022 and _t > 3.0:
		print("[image] %.0f ms à t=%.1f (%s)" % [delta * 1000.0, _t, etape])
		var vp := get_viewport().get_viewport_rid()
		print("        rendu cpu %.1f ms, gpu %.1f ms" % [RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(), RenderingServer.viewport_get_measured_render_time_gpu(vp)])
	if _mesure_images and _t < 1.0:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	if _mesure_images and _t > 40.0:
		get_tree().quit()
	Pad.fleches_seules = _combo != null or (_gestes_ui != null and _gestes_ui.roue_ouverte())   # pendant une combinaison, la croix ne fait que les flèches
	Pad.chiffres = etape == "jeu" and not _panneau_emotes.visible and (ecran.vote_quete_visible() or (_vue_quete != null and _vue_quete.a_des_choix()))
	_photo_essai(delta)
	if get_tree().paused:
		return
	_prechauffer_sons()
	_objets_avancer(delta)
	if _essai_carnet == "":
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--essai-carnet="):
				_essai_carnet = a.substr(15)
		if _essai_carnet == "":
			_essai_carnet = "-"
	if _essai_carnet != "-" and etape == "jeu" and _phase() == "tableau" and _vue_objets and mode == "libre":
		_essai_carnet_lancer()
	if _essai_moulin == "":
		_essai_moulin = "-"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--essai-moulin="):
				_essai_moulin = a.substr(15)
	if _essai_moulin != "-" and etape == "jeu" and _monde_quete != null and _ma_quete().get("etat", "") == "jeu":
		_essai_moulin_lancer()
	if _essai_livre == "":
		_essai_livre = "-"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--essai-livre="):
				_essai_livre = a.substr(14)
	if _essai_livre != "-" and etape == "jeu" and _phase() == "tableau" and _vue_objets and mode == "libre":
		_essai_livre_lancer()
	if _essai_interieur == "":
		_essai_interieur = "-"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--essai-interieur="):
				_essai_interieur = a.substr(18)
	if _essai_interieur != "-" and etape == "jeu" and _phase() == "tableau" and _vue_objets and mode == "libre":
		_essai_interieur_lancer()
	if _essai_monde == "":
		_essai_monde = "-"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--essai-monde="):
				_essai_monde = a.substr(14)
	if _essai_monde != "-" and etape == "jeu" and _phase() == "tableau" and _vue_objets and mode == "libre":
		_essai_monde_lancer()
	if _essai_marche == "":
		_essai_marche = "-"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--essai-marche-maison="):
				_essai_marche = a.substr(22)
	if _essai_marche != "-" and etape == "jeu" and _phase() == "tableau" and _vue_objets and mode == "libre":
		_essai_marche_lancer()
	_essai_jeu_lancer(delta)
	_essai_photos(delta)
	_essai_interface_lancer(delta)
	_essai_pousser_lancer()
	_essai_objets_lancer()
	_essai_coup_lancer()
	_essai_poser_lancer()
	if _essai_pas == "":
		_essai_pas = "-"
		for a2 in OS.get_cmdline_user_args():
			if a2.begins_with("--essai-pas="):
				_essai_pas = a2.substr(12)
	if _essai_pas != "-" and etape == "jeu" and _phase() == "tableau" and mode == "libre":
		var dos := _essai_pas
		_essai_pas = "-"
		_essai_pas_obj = EssaiPas.new(self, dos)
		_essai_pas_obj.lancer()
	_essai_bras_lancer()
	_essai_ui_lancer()
	_essai_reseau_objets_lancer()
	_essai_reseau_carnet_lancer()
	if etape == "accueil":
		_tourner_cam_menu(delta)
	elif etape == "jeu" and ecran.salon_visible():
		if ecran.synchro_ouverte():
			_synchro_tick(delta)
		else:
			_tourner_cam_menu(delta)
	if etape == "luciole" or etape == "verif":
		_luciole_avance(delta)
	if etape == "reglage":
		var d := Capteur.distance_cm(Regard.correction_focale)
		_mesure_distance.text = (Langue.t("La caméra te mesure à %d cm") % round(d) if d > 0 else Langue.t("La caméra ne mesure pas encore ta distance")) + "  "
		_note_pouces.text = "  " + Langue.t("lu sur Windows ✓") if Regard.ecran_auto else ""
		if Regard.ecran_auto and not _spin_pouces.has_focus() and absf(_spin_pouces.value - Regard.ecran_pouces) > 0.05:
			_spin_pouces.value = Regard.ecran_pouces
		_bouton_luciole.disabled = Capteur.etat != "ok"

	var point := _point_regard()
	var vise := _viser(point)
	_regard_monde = vise[0]
	_vise_bouille = vise[1]
	_regard_vu = _regard_avec_saccades(_regard_monde)
	_regler_capteur_sans_camera()
	_suivre_mes_yeux(delta)
	# Mort, on est un fantôme, quel que soit l'endroit où la mort nous a pris (assis, dans sa
	# chambre…) : il traverse les portes et les murs (Edwin, 31/10).
	# Sauf le condamné du Conseil : mort pour les règles, il reste avec les vivants jusqu'à ce que
	# les loups viennent (les porteurs l'emmènent à la pierre ; sans ça, il ne voyait personne venir).
	if etape == "jeu" and not _vivant() and meneur.pub.get("attache", -1) != _moi_id() and mode in ["libre", "chambre", "assis", "poste"] and _phase() not in ["salon", "fin", "verdict", "tranche", "depouillement"]:
		_guide.clear()
		_appliquer_placement(corps_joueur.global_position + Vector3(0, 0.3, 0), Vector3.ZERO, "fantome")
	_avancer_transformation(delta)
	_animer_moi()
	_suivre_gestes(delta)
	_animer_autres(delta)
	_emotes_bots(delta)
	_animer_bots(delta)
	_asseoir()
	_poser_attache()
	_placer_marque_vote()
	_guetter(delta)
	_regard_porteurs(delta)
	_avancer_sortie(delta)
	var oreille_avant := _oreille
	_oreille = _contre_un_mur() and Options.appuye("agir") and _phase() == "nuit" and _ecoute_possible()
	if _oreille != oreille_avant:
		_envoyer_intention("oreille", _oreille)   # l'hôte n'enverra les bruits à leur vraie place qu'à qui écoute
	_animer_chambre(delta)
	_maj_volumes()
	_alt(Input.is_key_pressed(KEY_ALT))
	_pas(delta)
	if _trace_pas and int(_t / 30.0) != int((_t + delta) / 30.0):
		print("[pas] t=%d %s" % [int(_t), JSON.stringify(_stat_pas_d)])
	_visibilite_bouilles()
	_ambiance(delta)
	_musique_des_menus(delta)
	_animer_nuit(delta)
	_voix()
	_placer_fils()
	_placer_fils_loups()
	_cadrer_miroir()
	if etape == "jeu":
		_jeu(delta)

	if _trace_reseau:
		_trace_t += delta
		if _trace_t >= 2.0 and not _trace_ages.is_empty():
			_trace_t = 0.0
			print("[reseau] %d états reçus, gigue max %.0f ms, dernière %.0f ms, %.0f images/s, %s" % [_trace_ages.size(),
				_trace_ages.max() * 1000.0, _trace_ages[-1] * 1000.0, Engine.get_frames_per_second(), _texte_diag().replace("\n", " | ")])
			_trace_ages.clear()
			for id in bouilles:
				if not Meneur.est_bot(id):
					var bb: Bouille = bouilles[id]
					print("[reseau] %d est en %s (mon corps en %s) phase %s voix %s" % [id, bb.global_position.snapped(Vector3.ONE * 0.1), corps_joueur.global_position.snapped(Vector3.ONE * 0.1), _phase(), Voix.en_partie()])
					print("[reseau] bras de %d : poids %.2f, direction %s, main %.2f" % [id, bb._poids_suivi[0], bb._dir_suivi[0], bb._poids_main[0]])
	_maj_diag(delta)
	_envoi_t += delta
	if _envoi_t >= 1.0 / ENVOIS_PAR_S:
		_envoi_t = 0.0
		_envoyer()

	if _capture_t > 0:
		_capture_t -= delta
		if _capture_t <= 0:
			get_viewport().get_texture().get_image().save_png(_capture)
			_quitter()


## Le point de l'écran que regarde le joueur : ses yeux s'ils sont réglés, sinon le centre.
func _point_regard() -> Vector2:
	var centre := get_viewport().get_visible_rect().size * 0.5
	if Capteur.mode_souris or not Regard.calibre or not Capteur.visage_vu():
		return centre
	return Regard.point_ecran(get_process_delta_time())


func _jeu(delta: float) -> void:
	var pub := meneur.pub
	var p := _phase()
	var reste: float = pub.get("reste", -1.0)
	if p != "salon" and p != "fin":
		pub["reste"] = reste - delta
	var appel: String = pub.get("appel", "")
	var titre: String = Langue.t(NOMS_PHASES.get(p, p))
	if p == "nuit":
		titre = Langue.t("Nuit %d  ·  %s") % [pub.get("nuit_n", 0), Langue.t(NOMS_APPELS.get(appel, ""))] if appel != "" else Langue.t("Nuit %d  ·") % pub.get("nuit_n", 0)
	var maire: int = pub.get("maire", -1)
	if maire > 0 and p not in ["salon", "fin"]:
		titre += "   ·   " + Langue.t("Maire : %s") % Langue.t("toi" if maire == _moi_id() else _etiquette(maire).to_lower())
	if p == "tableau" and pub.get("maire_quete", false):
		titre = _titre_quete_du_maire(pub)
	# En quête, seul le temps de la quête compte : le chrono du village se cache (choix d'Edwin).
	var en_quete: bool = (meneur.pub.get("en_quete", {}) as Dictionary).has(_moi_id())
	ecran.regler_phase(titre, pub.get("reste", -1.0) if p not in ["salon", "fin"] and not en_quete and _tuto == null else -1.0)
	var role_texte := ""
	if p != "salon":
		role_texte = Langue.t(str(_priv("nom_role", "")))
		# Avant le tirage de la première nuit, personne n'a encore de rôle (Edwin, 31/10).
		if _priv("sans_role", false):
			role_texte = Langue.t("Tu obtiens ton rôle après la première nuit")
		# Le texte est assemblé morceau par morceau : chaque morceau est traduit ici (jamais de morceaux collés en français).
		if not _vivant():
			role_texte += " · " + Langue.t("mort")
			# L'énergie du fantôme, toujours sous les yeux (hanter en coûte 60 %).
			role_texte += " · " + Langue.t("énergie %d %%") % int(_energie() * 100)
		elif _priv("loup", false) and not Roles.est_loup(_priv("role", "villageois")):
			role_texte += " · " + Langue.t("loup")
		var mon_bandeau: int = (pub.get("sieges", {}) as Dictionary).get(_moi_id(), {}).get("bandeau", -1)
		if mon_bandeau >= 0 and p != "fin":
			role_texte += " · " + Langue.t("bandeau %s" % Bouille.nom_bandeau(mon_bandeau))
		if _priv("amoureux", -1) > 0:
			role_texte += "\n♥ " + Langue.t(_etiquette(_priv("amoureux")).to_lower())
	ecran.regler_role(role_texte)
	# Plus aucune note à l'écran (décision d'Edwin, 29/10) : tout se joue à l'oral, et ce qu'on veut
	# garder s'écrit à la main dans le carnet de sa maison (pages qu'on déchire, mots qu'on laisse).
	ecran.montrer_carnet(false)

	# Invite d'action
	var act := _action_possible()
	var invite: String = act[0] if not act.is_empty() else ""
	# Au milieu, seulement ce qu'on peut faire (prendre, ouvrir, voter…) ; ce qu'il faut savoir va en
	# haut à gauche, 4 s (Edwin, 31/10 : « vote pour la quête » restait écrit tout le temps).
	var consigne := ""
	var consigne_dure := false
	var a_droite := ""
	if p in PHASES_VOTE and _vivant() and _priv("peut_voter", true):
		# Le message du vote va en haut à gauche, jamais au milieu (Edwin, 01/11).
		invite = ""
		consigne = _invite_vote(delta)
		consigne_dure = true
	elif Prets.accepte(p) and _vivant():
		var prets: Array = pub.get("prets", [])
		a_droite = Langue.t("{pret} : passer au vote  %d / %d") % [Prets.compte(_vivants_ids(), prets), _nb_vivants()] if not prets.has(_moi_id()) else Langue.t("Tu veux passer au vote.") + "\n" + Langue.t("On attend les autres  %d / %d…") % [Prets.compte(_vivants_ids(), prets), _nb_vivants()]
		if p == "election":
			# Deux minutes sans consigne, c'était un écran figé : on dit quoi faire et ce qui vient.
			consigne = "Tout le monde peut être maire. Dis qui tu veux (ou propose-toi) — le vote suivra : tu fixeras ton choix, puis clic."
	elif p == "successeur" and pub.get("successeur", -1) == _moi_id():
		invite = "{pouvoir} : désigner ton successeur"
		consigne = "{pouvoir} : désigner ton successeur"
	elif p == "tranche" and (pub.get("tranche", {}) as Dictionary).get("par", -1) == _moi_id():
		invite = "{pouvoir} : désigner qui sera attaché à la pierre"
		consigne = "{pouvoir} : désigner qui sera attaché à la pierre"
	elif mode == "attache":
		consigne = "Tu es enchaîné à la pierre. Tu ne peux plus parler. Cette nuit, les loups viendront."
		consigne_dure = true
	elif p == "quete" and not _ma_quete().is_empty() and _ma_quete()["etat"] == "trajet":
		consigne = "Tu es dans la clairière : le portail ne s'ouvrira qu'à la fin de la quête." if _dans_la_clairiere() else "Ton équipe part vers la clairière de la quête… suis le sentier."
	elif p == "quete" and not _ma_quete().is_empty() and _ma_quete()["etat"] == "role":
		consigne = _invite_role()
		consigne_dure = true
	elif p == "quete" and not _ma_quete().is_empty() and _ma_quete()["etat"] == "retour":
		consigne = "C'est fini : tu rentres au village."
	elif p == "tableau" and _vivant():
		if _vote_participation:
			consigne = "Touche 1 : participer · touche 2 : ne pas participer"
		else:
			consigne = "Vote pour la quête du jour : touches 1 à 4" if _mon_vote_quete < 0 else "Ton vote : %d · tu peux encore changer d'avis" % (_mon_vote_quete + 1)
	elif p == "nuit" and appel in ["loups", "solitaire"] and _suis_loup():
		invite = _invite_pierre()
	elif p == "nuit" and _eveille() and appel == _priv("role", ""):
		invite = "{pouvoir} : rouvrir ton carnet"
	elif _de_jour() and _priv("role") == "vampire" and _priv("peut_mordre", false) and _vivant():
		invite = _morsure(delta)
	elif p == "trappeur" and pub.get("trappeur", -1) == _moi_id():
		invite = "{pouvoir} : choisir qui tu emportes"
		consigne = "{pouvoir} : choisir qui tu emportes"
	var texte_geste := _invite_geste()
	if invite == "":
		invite = texte_geste
	if _gestes_ui != null and _gestes_ui.roue_ouverte():
		invite = ""
	var icone_invite: bool = invite != "" and invite == texte_geste
	# (Plus de « G : lâcher » en bas à droite, ni de rappel de touches pour l'objet en main : Edwin, 01/11.)
	if p == "nuit" and mode == "chambre" and _vivant() and _oreille:
		consigne = "Écoute… tu as l'oreille collée au mur."
	# Une action possible ne s'écrit plus en phrase : seule sa touche, discrète, en bas au milieu.
	# Tout autre message permanent du milieu (vote, pierre, morsure…) passe en haut à gauche.
	var touche_seule := ""
	var mot_touche := ""
	if invite != "" and not icone_invite:
		touche_seule = _touche_de_invite(invite)
		mot_touche = Invites.mot(invite)
		if touche_seule == "":
			consigne = invite if consigne == "" else consigne + "\n" + invite
			consigne_dure = true
		invite = ""
	ecran.touche_seule(_essai_touche if _essai_touche != "" else touche_seule if _cine_t < 0 and not (_gestes_ui != null and _gestes_ui.roue_ouverte()) else "", mot_touche)
	ecran.invite(invite if _cine_t < 0 else "")
	_indic_carnet.visible = _cine_t < 0.0 and _vivant() and p != "salon" and etape == "jeu" and not _carnet.visible and not _au_poste() and not ecran.panneau_ouvert() 			and _vue_objets != null and str(_vue_objets.main_decrite().get("sorte", "")) in ["carnet", "page"]
	if _inventaire != null:
		_inventaire.souris_invite(ecran._invite.get_global_rect() if icone_invite and _cine_t < 0 else Rect2())
	# Nuit guidée : le narrateur parle seul, la consigne du coin se tait.
	ecran.consigne(consigne if _cine_t < 0 and _tuto == null else "", consigne_dure)
	ecran.droite(a_droite if _cine_t < 0 else "")
	var a_la_pierre: bool = p == "nuit" and appel in ["loups", "solitaire"] and _suis_loup() and Ronde.a_l_autel(corps_joueur.global_position, Meneur.PORTEE_PIERRE)
	ecran.viseur((p in PHASES_VOTE or a_la_pierre) and _cine_t < 0, Color(0.9, 0.15, 0.1, 0.8) if p != "vote_maire" else Color(0.95, 0.78, 0.45, 0.8))

	# Combo du loup
	if _combo:
		_combo.avancer(delta)
		if _combo.etat == "rate":
			var sol := Ronde.sol_a(corps_joueur.global_position)
			_envoyer_intention("bruit", corps_joueur.global_position, SORTE_DU_SOL.get(sol, "craquement"))
			ecran.message("Raté ! Tu as fait du bruit…", 1.5)
			_combo = null
		elif _combo.etat == "reussi":
			_combo = null
		ecran.combo(_combo)

	# Cœur qui bat : accusé au vote, ou loup tout près de chez soi la nuit.
	var battre: bool = false
	if p in PHASES_VOTE:
		battre = int(_priv("contre_moi", 0)) >= 2
	elif p == "nuit" and appel == "loups" and not _suis_loup() and _vivant():
		for id in bouilles:
			var b: Bouille = bouilles[id]
			if Ronde.maison_de(b.global_position) < 0 and b.global_position.distance_to(corps_joueur.global_position) < 7.0:
				battre = true
	_coeur_t -= delta
	if battre and _coeur_t <= 0:
		_coeur_t = 0.62
		_jouer2d("coeur", -2.0)

	if _cine_t >= 0.0:
		_jouer_cinematique(delta)
	_jouer_retour_chambre(delta)
	if _auto:
		_pilote_auto(delta)


## Le titre du matin quand un maire choisit la quête (à la place de « Le vote de la quête · Maire… »).
func _titre_quete_du_maire(pub: Dictionary) -> String:
	var k: int = pub.get("quete_du_maire", -1)
	var quetes: Array = pub.get("quetes", [])
	if k == Quetes.RESTER:
		return "Le maire a décidé de rester au village"
	if k >= 0 and k < quetes.size():
		return "Le maire a choisi la quête « %s »" % quetes[k]["nom"]
	return "Tu choisis la quête du jour" if pub.get("maire", -1) == _moi_id() else "Le maire choisit la quête du jour…"


## Une invite qui commence par « {touche} : … » (ou « Maintiens {touche} : … ») n'est qu'une touche à
## montrer : renvoie le nom de l'action (agir, pouvoir…), "" si c'est un vrai message.
func _touche_de_invite(texte: String) -> String:
	var re := RegEx.new()
	re.compile("^(?:Maintiens )?\\{(\\w+)\\}\\s*:")
	var m := re.search(texte)
	return m.get_string(1) if m else ""


func _invite_vote(delta: float) -> String:
	if _phase() == "vote_maire":
		# Pas de délai : on change d'avis autant qu'on veut, le dernier clic compte à la fin du temps.
		if _vise_bouille >= 0 and _vise_bouille != _moi_id() and _est_vivant(_vise_bouille) and _vise_bouille != _vote_cible:
			return "Clic : voter pour %s" % _designer(_vise_bouille)
		return "Vise quelqu'un et clique pour voter pour lui comme maire." if _vote_cible < 0 \
				else "Tu votes pour %s. Clique sur quelqu'un d'autre pour changer, jusqu'à la fin du temps." % _designer(_vote_cible)
	if _vise_bouille >= 0 and _est_vivant(_vise_bouille):
		if _vise_bouille != _vote_cible:
			_vise_t += delta
			if _vise_t > 1.2:
				return "Clic : accuser %s" % _designer(_vise_bouille)
			return "Tu fixes %s…" % _designer(_vise_bouille)
		return "Tu accuses %s. Fixe quelqu'un d'autre pour changer." % _designer(_vote_cible)
	_vise_t = 0.0
	return "Fixe celui que tu accuses." if _vote_cible < 0 else "Tu accuses %s." % _designer(_vote_cible)


## La nuit : sa chambre, sa porte (loups), le rideau qu'on écarte.
func _action_nuit(pos: Vector3) -> Array:
	var m := _ma_maison()
	if m < 0:
		return []
	var dz := Ronde.PROFONDEUR * 0.5
	var appel: String = meneur.pub.get("appel", "")
	if mode == "chambre":
		if _eveille() and appel in ["loups", "solitaire"] and pos.distance_to(Ronde._vers_monde(m, Vector3(0, 0, dz - 0.7))) < 1.4 				and _vise_gros(Ronde._vers_monde(m, Vector3(0, 1.0, dz)), 3.0, 0.9):
			return ["{agir} : sortir sans bruit (trois coups)", _ouvrir_sortie]
		if Roles.peut_ecarter_rideau(str(_priv("role", "")), "nuit", _vivant()) and _fenetre_visee() != 0:
			return ["Maintiens {agir} : écarter le rideau, doucement", Callable()]
		return _action_chambre()
	elif mode == "libre" and _suis_loup():
		var porte_ := ronde.porte_proche(pos, 2.2)
		if not porte_.is_empty() and porte_[0] == m and porte_[1] == "avant" and _vise_porte(m):
			return ["{agir} : fermer ta porte" if ronde.porte_ouverte(m, "avant") else "{agir} : ouvrir ta porte", func(): _envoyer_intention("porte", m, "avant")]
	return []


## Devant laquelle de ses deux fenêtres de façade on se tient (-1, 1), ou 0.
func _fenetre_proche(pos: Vector3) -> int:
	var m := _ma_maison()
	for cote: int in [-1, 1]:
		var f: Array = Ronde.fenetre(m, cote)
		var dedans: Vector3 = (f[0] as Vector3) - (f[1] as Vector3) * 0.75
		if Vector2(pos.x - dedans.x, pos.z - dedans.z).length() < 1.1:
			return cote
	return 0


## La fenêtre de façade que je REGARDE, de près (-1, 1), ou 0.
func _fenetre_visee() -> int:
	var cote := _fenetre_proche(corps_joueur.global_position)
	if cote == 0:
		return 0
	var f: Array = Ronde.fenetre(_ma_maison(), cote)
	return cote if _vise_gros((f[0] as Vector3) + Vector3(0, 0.1, 0), 3.2, 0.8) else 0


## La nuit dans sa chambre, tout passe par la touche d'action (Edwin, 01/11 : « trop d'interactions et
## de touches différentes ») et ne s'affiche que face à l'objet : la bougie (la souffler / la rallumer),
## le mur (maintenir pour écouter dehors). Plus de jeu de cartes sur le lit (Edwin, 01/11).
func _action_chambre() -> Array:
	var m := _ma_maison()
	if m < 0 or _cine_t >= 0.0 or ecran.panneau_ouvert():
		return []
	if _vise_point(Ronde._vers_monde(m, Vector3(-1.4, 0.9, -1.2)), 2.4, 14.0):
		return ["{agir} : la bougie", _basculer_bougie_main]
	if _contre_un_mur() and Visee.vers_le_mur(-camera.global_basis.z, _axe_mur_monde()):
		return ["{agir} : écouter dehors (maintenir)", Callable()]
	return []


## Le joueur écoute-t-il quelque chose en maintenant la touche ? (rien d'autre n'est visé)
func _ecoute_possible() -> bool:
	var act := _action_chambre() if mode == "chambre" and _vivant() else []
	return not act.is_empty() and not (act[1] as Callable).is_valid()


## Le point est-il à portée et dans le champ du regard ?
func _vise_point(pt: Vector3, portee: float, cone_deg: float) -> bool:
	return Visee.vise(camera.global_position, -camera.global_basis.z, pt, portee, 0.0, cone_deg)


## Le centre de l'écran vise-t-il cet objet (de taille `rayon`) ? La règle est dans regles/visee.gd.
func _vise_gros(pt: Vector3, portee: float, rayon: float) -> bool:
	return Visee.vise(camera.global_position, -camera.global_basis.z, pt, portee, rayon)


## Le milieu de la porte de la maison m est-il visé ?
func _vise_porte(m: int) -> bool:
	return _vise_gros(Ronde._vers_monde(m, Vector3(0, 1.0, Ronde.PROFONDEUR * 0.5)), 3.6, 1.0)


func _basculer_bougie_main() -> void:
	var allumee := ronde.basculer_bougie(_ma_maison())
	ecran.message("Tu rallumes ta bougie." if allumee else "Tu souffles ta bougie. Il fait noir.", 2.0)
	_geste_bougie = 0.0001


const DUREE_GESTE_BOUGIE := 1.1
var _geste_bougie := -1.0        # >= 0 : la main va à la bougie (secondes écoulées)
var _pench := 0.0                # 0..1 : l'oreille contre le mur (la tête se penche)


## Le corps parle : l'oreille contre le mur (la tête se penche vers lui), la main vers la bougie
## (la tête se baisse vers la table de chevet).
func _animer_chambre(delta: float) -> void:
	_pench = move_toward(_pench, 1.0 if _oreille else 0.0, delta * 3.5)
	var bas := 0.0
	if _geste_bougie >= 0.0:
		_geste_bougie += delta
		bas = sin(PI * clampf(_geste_bougie / DUREE_GESTE_BOUGIE, 0.0, 1.0))
		if _geste_bougie >= DUREE_GESTE_BOUGIE:
			_geste_bougie = -1.0
	var m := _ma_maison()
	var vers_mur := Vector3.ZERO
	if _pench > 0.0 and m >= 0:
		var loc := Ronde._vers_local(m, corps_joueur.global_position)
		var axe := Vector3(signf(loc.x), 0, 0) if absf(loc.x) / (Ronde.LARGEUR * 0.5) > absf(loc.z) / (Ronde.PROFONDEUR * 0.5) else Vector3(0, 0, signf(loc.z))
		var mondial := Ronde._vers_monde(m, axe) - Ronde._vers_monde(m, Vector3.ZERO)
		vers_mur = corps_joueur.global_basis.inverse() * mondial
		_vers_mur_dernier = vers_mur
	elif _pench > 0.0:
		vers_mur = _vers_mur_dernier
	var actif: bool = _pench > 0.0 or bas > 0.0
	if not actif and not _chambre_anime:
		return
	_chambre_anime = actif
	camera.position = Vector3(vers_mur.x * 0.22, -0.1 * _pench - 0.16 * bas, vers_mur.z * 0.22 - 0.1 * bas)
	tete.rotation.z = -vers_mur.x * 0.38 * _pench
	camera.rotation.x = -0.32 * bas


var _vers_mur_dernier := Vector3.ZERO
var _chambre_anime := false

## Vers quel mur de ma chambre je suis collé (direction monde, à plat).
func _axe_mur_monde() -> Vector3:
	var m := _ma_maison()
	if m < 0:
		return Vector3.ZERO
	var loc := Ronde._vers_local(m, corps_joueur.global_position)
	var axe := Vector3(signf(loc.x), 0, 0) if absf(loc.x) / (Ronde.LARGEUR * 0.5) > absf(loc.z) / (Ronde.PROFONDEUR * 0.5) else Vector3(0, 0, signf(loc.z))
	return Ronde._vers_monde(m, axe) - Ronde._vers_monde(m, Vector3.ZERO)


## Contre un mur de sa chambre ?
func _contre_un_mur() -> bool:
	var m := _ma_maison()
	if m < 0 or mode != "chambre":
		return false
	var loc := Ronde._vers_local(m, corps_joueur.global_position)
	return absf(loc.x) > Ronde.LARGEUR * 0.5 - 0.95 or absf(loc.z) > Ronde.PROFONDEUR * 0.5 - 0.95


## La Petite fille écarte son rideau, doucement (E maintenu devant la fenêtre). Les autres voient
## le pan bouger ; un loup tout proche qui le voit la repère.
func _guetter(delta: float) -> void:
	var m := _ma_maison()
	var actif: bool = Roles.peut_ecarter_rideau(str(_priv("role", "")), _phase(), _vivant()) and mode == "chambre" and m >= 0
	var pres := _fenetre_proche(corps_joueur.global_position) if actif else 0
	if pres != 0:
		_rideau_cote = pres
	# Le pan ne s'écarte que si on REGARDE la fenêtre, pas si on passe devant.
	var tire: bool = pres != 0 and _fenetre_visee() != 0 and Options.appuye("agir") and not ecran.panneau_ouvert()
	var avant := _rideau_o
	_rideau_o = move_toward(_rideau_o, 1.0 if tire else 0.0, delta * (0.3 if tire else 1.2))
	if not actif and avant <= 0.0:
		return
	ronde.entrouvrir_rideau(m, _rideau_cote, _rideau_o)
	if absf(_rideau_o - _rideau_envoye) > 0.08 or (_rideau_o == 0.0 and _rideau_envoye > 0.0):
		_rideau_envoye = _rideau_o
		_envoyer_intention("rideau", _rideau_cote, _rideau_o)
	if meneur.pub.get("appel", "") == "loups" and _rideau_o > 0.05:
		var loup_proche := false
		for id in bouilles:
			var b: Bouille = bouilles[id]
			if b.visible and Ronde.maison_de(b.global_position) < 0 and b.global_position.distance_to(corps_joueur.global_position) < 10.0:
				loup_proche = true
		_risque += delta * (0.05 + 0.6 * _rideau_o) * (1.0 if loup_proche else 0.12)
	_risque = maxf(_risque - delta * 0.03, 0.0)
	if _risque >= 1.0 and not _repere:
		_repere = true
		_envoyer_intention("repere")
		ecran.message("Un loup a vu ton rideau bouger. Il sait qui tu es.", 4.0)


## La nuit, un loup voit les numéros des maisons en couleur : rouges les villageois, bleus ses
## alliés, verte la sienne (décision d'Edwin, 29/10).
func _maj_chiffres_loups() -> void:
	var c := {}
	if _phase() == "nuit" and _suis_loup() and _vivant() and meneur.pub.get("appel", "") in ["loups", "solitaire"]:
		var allies: Array = _priv("silhouettes", [])
		var s: Dictionary = meneur.pub.get("sieges", {})
		for id in s:
			var m: int = s[id]["maison"]
			if id == _moi_id():
				c[m] = Color(0.42, 0.95, 0.4)
			elif allies.has(id):
				c[m] = Color(0.35, 0.55, 1.0)
			elif s[id]["vivant"]:
				c[m] = Color(1.0, 0.18, 0.12)
	ronde.colorer_chiffres(c)


## Les trois coups pour ouvrir sa porte sans bruit : un curseur va et vient, on frappe (E,
## Espace ou clic) quand il passe dans la zone claire. 3 réussis : aucun bruit ; 0 : un vacarme.
func _ouvrir_sortie() -> void:
	if _sortie:
		return
	_sortie_coups.clear()
	_sortie_t = 0.0
	_sortie = Control.new()
	_sortie.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_sortie.position += Vector2(-260, -230)
	_sortie.custom_minimum_size = Vector2(520, 90)
	var fond := ColorRect.new()
	fond.color = Color(0.05, 0.03, 0.03, 0.85)
	fond.size = Vector2(520, 90)
	_sortie.add_child(fond)
	var barre := ColorRect.new()
	barre.color = Color(0.25, 0.18, 0.14)
	barre.position = Vector2(20, 40)
	barre.size = Vector2(480, 22)
	_sortie.add_child(barre)
	var zone := ColorRect.new()
	zone.name = "zone"
	zone.color = Color(0.85, 0.75, 0.45, 0.85)
	zone.size = Vector2(70, 22)
	zone.position = Vector2(20 + _rng.randf_range(80, 330), 40)
	_sortie.add_child(zone)
	var curseur := ColorRect.new()
	curseur.name = "curseur"
	curseur.color = Color(1, 1, 1)
	curseur.size = Vector2(6, 34)
	curseur.position = Vector2(20, 34)
	_sortie.add_child(curseur)
	var texte := Label.new()
	texte.name = "texte"
	texte.position = Vector2(20, 8)
	texte.text = Options.avec_touches("La porte : frappe quand le curseur passe dans la zone ({agir}).")
	_sortie.add_child(texte)
	ecran.add_child(_sortie)


func _fermer_sortie() -> void:
	if _sortie:
		_sortie.queue_free()
		_sortie = null


func _avancer_sortie(delta: float) -> void:
	if _sortie == null:
		return
	_sortie_t += delta * (1.25 + _sortie_coups.size() * 0.4)
	var x := 20.0 + (0.5 - 0.5 * cos(_sortie_t * PI)) * 474.0
	(_sortie.get_node("curseur") as ColorRect).position.x = x


func _coup_de_sortie() -> void:
	var curseur := _sortie.get_node("curseur") as ColorRect
	var zone := _sortie.get_node("zone") as ColorRect
	var c := curseur.position.x + 3.0
	var ok: bool = c >= zone.position.x and c <= zone.position.x + zone.size.x
	_sortie_coups.append(ok)
	_jouer2d("poignee" if not ok else "craquement", -16.0 if ok else -8.0)
	var marques := ""
	for r in _sortie_coups:
		marques += "✔ " if r else "✘ "
	(_sortie.get_node("texte") as Label).text = Langue.t("Coups : %s") % marques
	zone.position.x = 20 + _rng.randf_range(60, 350)
	zone.size.x = maxf(40.0, 70.0 - _sortie_coups.size() * 12.0)
	if _sortie_coups.size() >= 3:
		var reussis := _sortie_coups.count(true)
		_envoyer_intention("sortir", reussis)
		mode = "libre"
		ecran.message(["La porte claque contre le mur : tout le village a dû l'entendre !",
			"La porte grince : on a pu l'entendre.", "Un léger grincement…", "La porte s'ouvre sans un bruit."][reussis], 3.5)
		_fermer_sortie()


## Suis-je réveillé par l'appel en cours ? (Le reste du village dort.)
func _eveille() -> bool:
	if not _vivant():
		return false
	if _retour_cle != "" and _retour_cle == _cle_tour():
		return false   # rentré dans sa chambre : le tour des loups est fini pour lui, il se rendort
	var appel: String = meneur.pub.get("appel", "")
	if appel in ["loups", "solitaire"]:
		return _suis_loup() and (appel == "loups" or _priv("role") == "solitaire")
	return appel != "" and appel == _priv("role", "")


## À la pierre, un loup fixe une maison et clique pour voter.
func _invite_pierre() -> String:
	_vote_maison = -1
	if _retour_cle != "" and _retour_cle == _cle_tour():
		return "Tu es rentré chez toi. Rendors-toi : la nuit continue."
	var votes: Dictionary = _priv("votes_loups", {})
	var ici := corps_joueur.global_position
	if _sortie:
		return "Frappe quand le curseur passe dans la zone claire ({agir}, Espace ou clic)."
	if mode == "chambre":
		var act := _action_nuit(ici)
		return act[0] if not act.is_empty() else "Tu te transformes… Va à ta porte pour sortir."
	if _priv("chasse_finie", false):
		return "C'est fait. Rentre chez toi avant l'aube."
	if _etape_loups() == "preparation":
		return "Prépare-toi : le choix de la porte s'ouvre dans %d s. Rejoins la pierre." % ceili(_reste_etape_loups())
	# Devant la porte d'une maison : on la choisit (décision d'Edwin, 29/10).
	for i in Ronde.NB_MAISONS:
		if i == _ma_maison():
			continue
		if ici.distance_to(Ronde.devant_porte(i)) < Meneur.PORTEE_PORTE_PROIE - 0.5:
			if _maison_de_la_meute(i):
				return "Cette porte (bleue) est celle d'un des tiens : choisis un villageois."
			_vote_maison = i
			if votes.get(_moi_id(), -1) == i:
				return "Tu as choisi la porte %s. La meute doit s'accorder." % Ronde.numero(i)
			return "Clic : choisir la porte %s" % Ronde.numero(i)
	if not Ronde.a_l_autel(ici, Meneur.PORTEE_PIERRE):
		if votes.has(_moi_id()):
			return "Tu as choisi la porte %s. La meute doit s'accorder." % Ronde.numero(votes[_moi_id()])
		return "Va devant la porte de ta proie (numéro rouge) et clique. Sans bruit."
	var m := Ronde.maison_proche(_regard_monde)
	if _regard_monde.distance_to(Ronde.centre_maison(m)) < 5.5 and m != _ma_maison():
		if _maison_de_la_meute(m):
			return "Cette porte (bleue) est celle d'un des tiens : choisis un villageois."
		_vote_maison = m
		return "Clic : voter pour la porte %s" % Ronde.numero(m)
	if votes.has(_moi_id()):
		return "Tu as voté pour la porte %s. Fixe une autre maison pour changer." % Ronde.numero(votes[_moi_id()])
	return "Fixe la maison de ta proie, puis clique."


## La maison d'un autre loup de la meute (affichée en bleu) : on ne la vise pas.
func _maison_de_la_meute(maison: int) -> bool:
	var allies: Array = _priv("silhouettes", [])
	var s: Dictionary = meneur.pub.get("sieges", {})
	for id in allies:
		if s.has(id) and int(s[id]["maison"]) == maison:
			return true
	return false


## Où en est le tour de la meute (étapes chronométrées : transformation, préparation, choix) ; "" hors tour.
func _etape_loups() -> String:
	if _phase() != "nuit" or meneur.pub.get("appel", "") != "loups" or bool(meneur.pub.get("tour_libre", false)) or not _vivant() or not _suis_loup():
		return ""
	return NuitLoups.etape(_ecoule_loups())


func _ecoule_loups() -> float:
	return maxf(NuitLoups.duree_tour(float(meneur.pub.get("duree_loups", NuitLoups.CHOIX))) - _cpt_reste, 0.0)


func _reste_etape_loups() -> float:
	return NuitLoups.reste_etape(_ecoule_loups(), float(meneur.pub.get("duree_loups", NuitLoups.CHOIX)))


var _cpt_reste := 0.0
var _compte_loups: Label = null


## Le temps restant, discret, en haut à gauche (jamais au milieu de l'écran).
func _maj_compte_loups(delta: float) -> void:
	var pub_reste: float = meneur.pub.get("reste", 0.0)
	_cpt_reste -= delta
	if absf(_cpt_reste - pub_reste) > 1.2:
		_cpt_reste = pub_reste
	var e := _etape_loups()
	if e == "" or _priv("chasse_finie", false) or _retour_t >= 0.0 or _cine_t >= 0.0 or etape != "jeu":
		if _compte_loups:
			_compte_loups.visible = false
		return
	if _compte_loups == null:
		_compte_loups = Label.new()
		_compte_loups.position = Vector2(24, 112)
		_compte_loups.add_theme_font_size_override("font_size", 20)
		_compte_loups.add_theme_color_override("font_color", Color(0.86, 0.8, 0.7, 0.85))
		_compte_loups.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_compte_loups.add_theme_constant_override("outline_size", 5)
		_compte_loups.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ecran.add_child(_compte_loups)
	var noms := {"transformation": "Transformation", "preparation": "Préparation", "choix": "Choix de la porte"}
	_compte_loups.text = "%s : %d s" % [noms[e], ceili(_reste_etape_loups())]
	_compte_loups.visible = true


func _ma_maison() -> int:
	var s: Dictionary = meneur.pub.get("sieges", {})
	return s[_moi_id()]["maison"] if s.has(_moi_id()) else -1


## Le Vampire maintient V, tout contre quelqu'un, trois secondes.
func _morsure(delta: float) -> String:
	var proche := -1
	var d := Meneur.PORTEE_MORSURE
	for id in bouilles:
		var b: Bouille = bouilles[id]
		if b.visible and _est_vivant(id) and b.global_position.distance_to(corps_joueur.global_position) < d:
			d = b.global_position.distance_to(corps_joueur.global_position)
			proche = id
	if proche < 0:
		_morsure_t = 0.0
		ecran.progression(0.0)
		return ""
	if Options.appuye("mordre"):
		_morsure_t += delta
		ecran.progression(_morsure_t / 3.0)
		if _morsure_t >= 3.0:
			_morsure_t = -999.0
			ecran.progression(0.0)
			_envoyer_intention("mordre", proche)
		return "Tu mords %s… ne te fais pas voir." % _designer(proche)
	_morsure_t = 0.0
	ecran.progression(0.0)
	return "Maintiens {mordre} : mordre %s" % _designer(proche)


## Quelqu'un vient d'être mordu : qui regardait le Vampire à ce moment-là l'a vu.
func _sur_morsure(vampire: int, cible: int) -> void:
	if vampire == _moi_id() or cible == _moi_id() or not _vivant() or not bouilles.has(vampire):
		return
	var b: Bouille = bouilles[vampire]
	if not b.visible:
		return
	var vers := b.global_position + Vector3(0, 0.9, 0) - camera.global_position
	var regarde: bool = _vise_bouille == vampire or _vise_bouille == cible or (vers.length() < 10.0 and (-camera.global_basis.z).angle_to(vers) < deg_to_rad(30))
	if regarde:
		var t := "Tu as vu %s se pencher sur le cou de %s… longtemps." % [_designer(vampire), _designer(cible) if bouilles.has(cible) or cible == _moi_id() else "quelqu'un"]
		ecran.message(t, 5.0)
		ecran.noter(Langue.t(t))


func _changement_d_appel(appel: String) -> void:
	ecran.fermer_panneau()
	_vote_maison = -1
	_maj_chiffres_loups()
	_fermer_sortie()
	_dessiner_fils_loups({})
	if appel == "":
		return
	if _auto:
		print("[appel] %s (moi : %s%s)" % [appel, _priv("role", "?"), ", réveillé" if _eveille() else ""])
	if _eveille() and appel != "coucher" and appel != "cinematique":
		_jouer2d("cloche", -10.0)
		if _auto:
			_auto_appel(appel)
		elif _panneau_appel(appel):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _dessiner_fils_loups(votes: Dictionary) -> void:
	for l in _fils_loups.keys():
		if not votes.has(l):
			_fils_loups[l].queue_free()
			_fils_loups.erase(l)
	for l in votes:
		if not _fils_loups.has(l):
			var m := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.02
			c.bottom_radius = 0.02
			c.height = 1.0
			m.mesh = c
			m.material_override = Bouille.materiau(Color(0.7, 0.03, 0.02), 0.0, Color(1.0, 0.05, 0.03))
			add_child(m)
			_fils_loups[l] = m
		_fils_loups[l].set_meta("maison", votes[l])


func _placer_fils_loups() -> void:
	for l in _fils_loups:
		var a := _tete_de(l)
		var m: MeshInstance3D = _fils_loups[l]
		var b := Ronde.devant_porte(int(m.get_meta("maison")), "avant").lerp(Ronde.centre_maison(int(m.get_meta("maison"))), 0.4) + Vector3(0, 2.0, 0)
		m.visible = a != Vector3.ZERO
		if not m.visible:
			continue
		_orienter_fil(m, a, b)


func _orienter_fil(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var long := a.distance_to(b)
	m.global_position = (a + b) * 0.5
	var dir := (b - a).normalized()
	var axe := Vector3.UP.cross(dir)
	if axe.length() > 0.001:
		m.global_basis = Basis(axe.normalized(), Vector3.UP.angle_to(dir)).scaled(Vector3(1, long, 1))
	else:
		m.global_basis = Basis().scaled(Vector3(1, long, 1))


# ---------------------------------------------------------------- la cinématique du sacrifice

## Le loup entre chez `victime` (maison `maison`) et la mange. Elle, la vit EN VRAI (ses yeux, sa chambre) ;
## tous les autres, vivants ou morts, la regardent en cinématique, tout de suite, où qu'ils soient (cf. Cinematique).
## `maison` < 0 : une chambre au hasard (essais).
func _sur_cinematique(maison: int = -1, victime: int = -1, loups: Array = []) -> void:
	_cine_victimes = 1
	_cine_t = 0.0
	ecran.fermer_panneau()
	_degager_pour_cine(true)
	if _cine:
		_cine.queue_free()
	_cine = Cinematique.new()
	_cine.victimes = 1
	_cine.ma_maison = _ma_maison()
	_cine.maison_cible = maison
	_cine.pov = victime > 0 and victime == _moi_id() and _vivant()
	# Un loup humain de la meute vit lui aussi la scène en vrai, avec les yeux du loup (Edwin, 04/11).
	_cine.loup_pov = not _cine.pov and _suis_loup() and loups.has(_moi_id())
	if _auto:
		print("[cine] maison %d, victime %d, moi %d : %s (je suis en %s, mode %s)" % [maison, victime, _moi_id(), "EN VRAI (victime)" if _cine.pov else ("EN VRAI (loup)" if _cine.loup_pov else "cinématique"), corps_joueur.global_position, mode])
	_cine.camera = camera
	_cine.ronde = ronde
	_cine.jouer_son = _jouer2d
	add_child(_cine)
	camera.top_level = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--photo-phases="):
			var dossier := arg.substr(15)
			_cine.photos = "%s/cine_%s_n%d" % [dossier, "pov" if _cine.pov else ("loup" if _cine.loup_pov else "autres"), int(meneur.pub.get("nuit_n", 0))]


# ---------------------------------------------------------------- le loup rentre dans sa chambre

var _retour_t := -1.0                       # >= 0 : fondu du retour en cours (secondes écoulées)
var _retour_dest: Array = []                # [position, regard]
var _retour_fait := false                   # le replacement a eu lieu (au plus noir)
var _retour_cle := ""                       # le tour (nuit + appel) pendant lequel le loup est rentré


func _cle_tour() -> String:
	return "%d:%s" % [int(meneur.pub.get("nuit_n", 0)), str(meneur.pub.get("appel", ""))]


## Après l'attaque (ou si la meute n'a rien ouvert), l'hôte ramène le loup dans sa chambre : fondu au noir,
## replacé dans sa chambre, le noir se lève. Aucune marche, aucune téléportation visible.
func _sur_retour_chambre(pos: Vector3, regard: Vector3) -> void:
	if etape != "jeu" or not _vivant():
		return
	_retour_dest = [pos, regard]
	_retour_cle = _cle_tour()
	_retour_t = 0.0
	_retour_fait = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--photo-phases="):
			var dossier := arg.substr(15)
			# (essai) le fondu, puis la chambre une fois le noir levé, puis un peu plus tard
			for k in 3:
				var quand: float = [NuitLoups.FONDU * 0.25, NuitLoups.FONDU + 0.4, NuitLoups.FONDU + 3.0][k]
				get_tree().create_timer(quand / Engine.time_scale, true, false, true).timeout.connect(func():
					get_viewport().get_texture().get_image().save_png("%s/retour_%d.png" % [dossier, k]))
	_fermer_sortie()
	ecran.fermer_panneau()


## Le noir (0 à 1) du retour : monte, plein au moment du replacement, redescend.
func _noir_retour() -> float:
	if _retour_t < 0.0:
		return 0.0
	var f := NuitLoups.FONDU
	if _retour_t < f * 0.35:
		return _retour_t / (f * 0.35)
	if _retour_t < f * 0.55:
		return 1.0
	return clampf(1.0 - (_retour_t - f * 0.55) / (f * 0.45), 0.0, 1.0)


func _jouer_retour_chambre(delta: float) -> void:
	if _retour_t < 0.0 or _cine_t >= 0.0:
		return   # la cinématique se joue d'abord, en entier
	_retour_t += delta
	if not _retour_fait and _retour_t >= NuitLoups.FONDU * 0.4:
		_retour_fait = true
		_guide.clear()
		_appliquer_placement(_retour_dest[0], _retour_dest[1], "chambre")
		_entrer_chez_soi()
		if _auto:
			print("[retour] le loup est ramené dans sa chambre (", _retour_dest[0], ")")
		ecran.message("Tu es de retour dans ta chambre. La nuit continue…", 5.0)
	if _retour_t >= NuitLoups.FONDU:
		_retour_t = -1.0


## Condamné au vote : les villageois viennent le chercher. Sa tête se tourne vers eux pour qu'il les
## voie arriver, le prendre et l'emmener (sans cela il regardait le feu : « aucune animation »).
var _porteurs_dits := false


func _regard_porteurs(delta: float) -> void:
	var pub: Dictionary = meneur.pub
	var condamne: bool = etape == "jeu" and _phase() == "verdict" and int(pub.get("attache", -1)) == _moi_id() and not bool(pub.get("attache_lie", false))
	if not condamne:
		_porteurs_dits = false
		return
	if not _porteurs_dits:
		_porteurs_dits = true
		ecran.message("Les villageois viennent te chercher.", 5.0)
	var proche: Bouille = null
	var d_min := 9.0
	for id in bouilles:
		var bo: Bouille = bouilles[id]
		var d := bo.global_position.distance_to(corps_joueur.global_position)
		if bo.visible and d < d_min and d > 0.3 and Ronde.maison_de(bo.global_position) < 0:
			d_min = d
			proche = bo
	if proche == null:
		return
	var v := proche.global_position - corps_joueur.global_position
	var cap := atan2(-v.x, -v.z)
	if mode == "assis":
		var ecart := clampf(wrapf(cap - _yaw_siege, -PI, PI), -PI * 0.5, PI * 0.5)
		corps_joueur.rotation.y = lerp_angle(corps_joueur.rotation.y, _yaw_siege + ecart, minf(delta * 2.5, 1.0))
	elif mode == "guide":
		var rel := clampf(wrapf(cap - corps_joueur.rotation.y, -PI, PI), -1.3, 1.3)
		tete.rotation.y = lerpf(tete.rotation.y, rel, minf(delta * 2.5, 1.0))


## Pendant une cinématique, plus rien ne gêne la vue : carnet refermé, objet de la main rangé, corps,
## inventaire, roue des gestes, panneaux et aides souris cachés (Edwin : « j'avais le carnet en main,
## je n'ai rien vu »). `oui` faux : tout revient.
func _degager_pour_cine(oui: bool) -> void:
	if oui:
		if _carnet.visible:
			_carnet.fermer()
		for p: Control in [_panneau_emotes, _panneau_role, _panneau_volumes]:
			p.visible = false
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and etape == "jeu":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_pench = 0.0
		_geste_bougie = -1.0
	if is_instance_valid(moi):
		moi.visible = (not oui) and mode != "attache"
	if _inventaire != null:
		_inventaire.visible = not oui
	if _gestes_ui != null:
		_gestes_ui.visible = not oui
	if _caillou_main != null:
		_caillou_main.visible = not oui
	if _vue_objets != null:
		_vue_objets.visible = not oui


func _jouer_cinematique(delta: float) -> void:
	_cine_t += delta
	if _cine:
		var phrase := _cine.avancer(delta)
		_voix_meneur = phrase if phrase != "" else "…"
	# L'hôte a passé l'étape (P) : la cinématique s'arrête avec elle, chez tout le monde.
	var passee: bool = _cine_t > 0.5 and _phase() != "nuit"
	if _cine_t >= DUREE_CINE or passee:
		_cine_t = -1.0
		camera.top_level = false
		camera.transform = Transform3D.IDENTITY
		_degager_pour_cine(false)
		if _cine:
			_cine.queue_free()
			_cine = null


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	var dir := Vector3.ZERO
	var peut: bool = etape == "jeu" and mode in ["libre", "poste", "fantome", "chambre"] and _sortie == null and _reussite == null and not ecran.panneau_ouvert() and not ecran.salon_visible() and not _noir and _cine_t < 0 and not _carnet.ecriture
	if peut:
		if Options.appuye("avancer"): dir.z -= 1
		if Options.appuye("reculer"): dir.z += 1
		if Options.appuye("gauche"): dir.x -= 1
		if Options.appuye("droite"): dir.x += 1
	if _auto and peut:
		dir = _auto_dir
	if mode == "poste" and _quete_sur_place():
		dir = Vector3.ZERO   # en quête, on reste à son poste : seule la tête bouge
	if _auto and Engine.get_physics_frames() % 120 == 0 and "--trace-auto" in OS.get_cmdline_user_args():
		print("[auto] etape=%s mode=%s peut=%s panneau=%s salon=%s noir=%s cine=%.1f chemin=%d dir=%s" % [etape, mode, peut, ecran.panneau_ouvert(), ecran.salon_visible(), _noir, _cine_t, _auto_chemin.size(), _auto_dir])
	dir = corps_joueur.global_basis * dir.normalized()
	dir.y = 0
	corps_joueur.collision_mask = _masque_corps()
	# Sauter juste avant le départ de la marche guidée : on attend de toucher le sol avant de courir (plus de
	# course dans les airs).
	var en_l_air := Corps.en_l_air(corps_joueur.global_position.y, Ronde.hauteur_sol(corps_joueur.global_position), corps_joueur.is_on_floor())
	if mode == "guide":
		var yaw_avant := corps_joueur.rotation.y
		dir = Vector3.ZERO if Corps.guide_attend_le_sol(mode, en_l_air) else _guider(delta)
		# On regarde où l'on veut pendant la marche : la tête compense le corps qui tourne vers sa maison.
		if mode == "guide":
			tete.rotation.y = Corps.guide_lacet_tete(tete.rotation.y, wrapf(corps_joueur.rotation.y - yaw_avant, -PI, PI),
				Time.get_ticks_msec() / 1000.0 - _souris_guide_t, delta)
	# Accroupi (Ctrl tenu) : plus bas, plus lent ; une animation nous relève, et on le reste jusqu'au relâchement.
	var touche_acc := Options.appuye("accroupir") and peut
	_acc_verrou = Corps.verrou(_acc_verrou, touche_acc, moi.emote != "")
	var accroupi := Corps.accroupi(touche_acc, Corps.peut_s_accroupir(mode, _vivant(), _assis_libre), _acc_verrou)
	if accroupi != _accroupi:
		_accroupi = accroupi
		moi.accroupi = accroupi
		if Reseau.en_ligne and _connecte() and not _par_l_hote():
			_accroupi_rpc.rpc(accroupi)
	var p := _phase()
	var loup_nuit: bool = p == "nuit" and _suis_loup()
	var maj: bool = peut and Options.appuye("sprint") and dir.length() > 0.1 and not accroupi
	var course: bool = loup_nuit and maj
	var sprint: bool = maj and not loup_nuit and not _essouffle and mode != "fantome"
	if sprint:
		_souffle = maxf(_souffle - SOUFFLE_PERTE * delta, 0.0)
		if _souffle <= 0.0:
			_essouffle = true
	else:
		_souffle = minf(_souffle + SOUFFLE_REPRISE * delta, 1.0)
		if _essouffle and _souffle >= 0.4:
			_essouffle = false
	ecran.souffle(_souffle if _souffle < 0.999 else -1.0, _essouffle)
	var vitesse := VITESSE * (1.45 if loup_nuit else 1.0) * (1.4 if course else 1.0) * (SPRINT if sprint else 1.0)
	if mode == "guide":
		vitesse = VITESSE * (GUIDE_COURSE if _phase() == "distribution" else GUIDE_VITESSE)
	if mode == "fantome":
		vitesse = 6.0
	if _combo:
		vitesse *= 0.45
	vitesse *= Corps.vitesse_accroupi(accroupi)
	corps_joueur.velocity.x = dir.x * vitesse + _pousse_v.x
	corps_joueur.velocity.z = dir.z * vitesse + _pousse_v.z
	var espace: bool = peut and Options.appuye("sauter") and not _combo and not (_vue_quete.visible and not _vue_quete.discret)
	if corps_joueur.is_on_floor():
		corps_joueur.velocity.y = SAUT if espace and not _espace_avant else 0.0
	else:
		corps_joueur.velocity.y -= 14.0 * delta
	_espace_avant = espace
	var avant := corps_joueur.global_position
	_regler_traversee_maisons()
	if _assis_libre and (dir != Vector3.ZERO or espace or not _vivant() or mode != "libre"):
		_se_lever()
	if mode in ["assis", "fige", "attache"] or _assis_libre:
		# Assis sur son rondin : on ne bouge pas, et le rondin ne nous repousse pas.
		corps_joueur.global_position = _ancre
		corps_joueur.velocity = Vector3.ZERO
	elif mode == "guide" and _guide_traverse:
		# Hors collisions : la gravité compte quand même (retombée d'un saut avant le départ).
		corps_joueur.global_position += Vector3(corps_joueur.velocity.x, corps_joueur.velocity.y if en_l_air else 0.0, corps_joueur.velocity.z) * delta
	else:
		corps_joueur.move_and_slide()
		_fin_de_poussee(delta)
	corps_joueur.position.y = maxf(corps_joueur.position.y, 0.0)
	if mode == "chambre" and _ma_maison() >= 0:
		var m := _ma_maison()
		var loc := Ronde._vers_local(m, corps_joueur.global_position)
		var bx := Ronde.LARGEUR * 0.5 - 0.55
		var bz := Ronde.PROFONDEUR * 0.5 - 0.55
		if absf(loc.x) > bx or absf(loc.z) > bz:
			loc.x = clampf(loc.x, -bx, bx)
			loc.z = clampf(loc.z, -bz, bz)
			var w := Ronde._vers_monde(m, loc)
			corps_joueur.global_position.x = w.x
			corps_joueur.global_position.z = w.z
	elif mode == "libre" and p == "nuit" and _suis_loup() and not _priv("chasse_finie", false) \
			and Ronde.maison_de(corps_joueur.global_position) >= 0 and Ronde.maison_de(avant) < 0:
		corps_joueur.global_position = avant
		ecran.message("Pas avant d'avoir choisi ta proie : la meute t'attend.", 1.5)
	if mode == "poste":
		var ecart := corps_joueur.global_position - _ancre
		ecart.y = 0
		var rayon := 0.0 if _quete_sur_place() else 3.0
		if ecart.length() > rayon:
			corps_joueur.global_position = _ancre + (ecart.normalized() * rayon if rayon > 0.0 else Vector3.ZERO)
	var r := Vector2(corps_joueur.position.x, corps_joueur.position.z)
	var limite := Ronde.R_LIMITE_QUETE if (meneur.pub.get("en_quete", {}) as Dictionary).has(_moi_id()) or (mode == "guide" and _guide_traverse) 			or (mode == "fantome" and _phase() == "quete") else Ronde.r_limite(atan2(corps_joueur.position.x, corps_joueur.position.z))
	if etape == "jeu" and _phase() == "quete":
		_maj_portails(meneur.pub)
	if r.length() > limite:
		r = r.normalized() * limite
		corps_joueur.position.x = r.x
		corps_joueur.position.z = r.y
	if _trace_fantome and Engine.get_physics_frames() % 60 == 0 and not _vivant():
		print("[fantome] mode=", mode, " pos=", corps_joueur.global_position, " phase=", _phase(), " guide=", _guide.size(), " cine=", _cine_t)
	var parcouru := (corps_joueur.global_position - avant).length()
	moi.marcher(clampf(dir.length() * vitesse / 2.5, 0, 2))
	_acc_k = move_toward(_acc_k, 1.0 if accroupi else 0.0, delta * 5.0)
	tete.position.y = (0.3 if mode == "attache" else HAUTEUR_YEUX - BAISSE_ASSIS if mode in ["assis", "fige"] or _assis_libre else HAUTEUR_YEUX - Corps.BAISSE_YEUX_ACCROUPI * _acc_k) + absf(sin(_t * 9.0)) * 0.04 * dir.length()
	# Les yeux suivent la tête du corps (sprint penché, assis avancé), un peu devant le cou.
	var t_loc := corps_joueur.to_local(moi.position_tete())
	_yeux = _yeux.lerp(Vector3(t_loc.x, 0, t_loc.z - 0.1), minf(delta * 12.0, 1.0))
	tete.position.x = _yeux.x
	tete.position.z = _yeux.z
	_reculer_camera_du_mur()
	# Combo : tous les 2,6 m sur un sol bruyant, à l'aller vers la pierre comme au retour.
	if loup_nuit and mode == "libre" and _combo == null and parcouru > 0.0:
		var sol := Ronde.sol_a(corps_joueur.global_position)
		var m := Combo.mode_du_sol(sol)
		if m != "":
			_pas_combo += parcouru
			if _pas_combo > 2.6:
				_pas_combo = 0.0
				_combo = Combo.new(m, Combo.longueur(sol, course, _priv("faim", 0), false), _rng)


## Renvoie [point 3D regardé, id de la bouille regardée ou -1].
func _viser(p: Vector2) -> Array:
	if etape != "jeu":
		return [camera.global_position - camera.global_basis.z * 5.0, -1]
	var origine := camera.project_ray_origin(p)
	var dir := camera.project_ray_normal(p)
	var meilleure := -1
	var dmin := INF
	for id in bouilles:
		var b: Bouille = bouilles[id]
		if not b.visible:
			continue
		var centre := b.global_position + Vector3(0, 0.85, 0)
		var oc := centre - origine
		var proj := oc.dot(dir)
		if proj <= 0:
			continue
		var ecart := (oc - dir * proj).length()
		if ecart < 0.75 and proj < dmin:
			dmin = proj
			meilleure = id
	if meilleure >= 0:
		return [bouilles[meilleure].global_position + Vector3(0, HAUTEUR_YEUX, 0), meilleure]
	var requete := PhysicsRayQueryParameters3D.create(origine, origine + dir * 60.0, Corps.SANS_JOUEURS)
	requete.exclude = [corps_joueur.get_rid()]
	var touche := get_world_3d().direct_space_state.intersect_ray(requete)
	if touche:
		return [touche["position"], -1]
	return [origine + dir * 10.0, -1]


## La transformation, dans sa chambre, quand la meute est appelée (Edwin, 31/10) : le cœur
## cogne, la vue rougit et tremble, on baisse les yeux sur ses mains qui deviennent des pattes,
## les os craquent. Avant l'appel, le loup a encore figure humaine.
const DUREE_TRANSFO := 2.8
var _transforme := false
var _transfo_t := -1.0
var _transfo_sons := 0
var _voile_transfo: ColorRect


func _avancer_transformation(delta: float) -> void:
	if _essai_transfo != "" and _essai_transfo != "-":
		_essai_transfo_avancer()
	elif not (_suis_loup() and _phase() == "nuit" and _vivant()):
		_transforme = false
		_transfo_t = -1.0
		if _voile_transfo:
			_voile_transfo.visible = false
		return
	if not _transforme and _transfo_t < 0.0 and (_eveille() or _essai_transfo_go):
		_transfo_t = 0.0
		_transfo_sons = 0
		if _voile_transfo == null:
			_voile_transfo = ColorRect.new()
			_voile_transfo.set_anchors_preset(Control.PRESET_FULL_RECT)
			_voile_transfo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ecran.add_child(_voile_transfo)
		_voile_transfo.visible = true
		_mains_transfo_creer()
		_jouer2d("coeur", -4.0)
		if mode == "chambre":
			create_tween().tween_property(tete, "rotation:x", -0.3, 0.6).set_trans(Tween.TRANS_SINE)
	if _transfo_t < 0.0:
		return
	_transfo_t += delta
	var k := clampf(_transfo_t / DUREE_TRANSFO, 0.0, 1.0)
	var battement := 0.5 + 0.5 * sin(_transfo_t * TAU * 1.6)
	_voile_transfo.color = Color(0.45, 0.02, 0.02, sin(PI * k) * (0.28 + 0.22 * battement))
	tete.rotation.z = sin(_transfo_t * 53.0) * 0.025 * sin(PI * k)
	_mains_transfo_avancer()
	# Les os qui craquent, puis le souffle de la bête.
	for i in 3:
		if _transfo_sons == i and _transfo_t >= 0.6 + i * 0.55:
			_transfo_sons += 1
			_jouer2d("craquement", -6.0 + i * 2.0)
	if not _transforme and _transfo_t >= 1.3:
		_transforme = true
	if _transfo_t >= DUREE_TRANSFO:
		_transfo_t = -1.0
		tete.rotation.z = 0.0
		_voile_transfo.visible = false
		if _mains_transfo:
			_mains_transfo.visible = false


## Mes deux mains levées devant les yeux pendant la transformation : peau, puis fourrure et griffes.
var _mains_transfo: Node3D
var _doigts_transfo: Array[MeshInstance3D] = []
var _griffes_transfo: Array[MeshInstance3D] = []
var _paumes_transfo: Array[MeshInstance3D] = []
var _peau_transfo: StandardMaterial3D
var _poil_transfo: StandardMaterial3D


func _mains_transfo_creer() -> void:
	if _mains_transfo == null:
		_mains_transfo = Node3D.new()
		camera.add_child(_mains_transfo)
		_poil_transfo = Bouille.materiau(Color(0.26, 0.21, 0.17), 0.0)
		var manche := Bouille.materiau(Color(0.12, 0.1, 0.09), 0.0)
		var griffe := Bouille.materiau(Color(0.85, 0.8, 0.7), 0.0)
		for c: float in [-1.0, 1.0]:
			var bras := Node3D.new()
			bras.name = "bras"
			bras.position = Vector3(c * 0.17, 0, 0)
			bras.rotation = Vector3(0.25, -c * 0.35, c * 0.2)
			_mains_transfo.add_child(bras)
			var avant_bras := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.045
			cy.bottom_radius = 0.055
			cy.height = 0.4
			avant_bras.mesh = cy
			avant_bras.material_override = manche
			avant_bras.position = Vector3(0, -0.24, 0.05)
			avant_bras.rotation.x = -0.3
			bras.add_child(avant_bras)
			var paume := Bouille.sphere(0.06, _poil_transfo, Vector3(1.0, 1.25, 0.45))
			bras.add_child(paume)
			_paumes_transfo.append(paume)
			for d in 4:
				var doigt := Bouille.sphere(0.017, _poil_transfo, Vector3(1, 2.6, 1))
				doigt.position = Vector3((d - 1.5) * 0.026, 0.08, 0.0)
				bras.add_child(doigt)
				_doigts_transfo.append(doigt)
				var g := MeshInstance3D.new()
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 0.008
				cone.height = 0.035
				g.mesh = cone
				g.material_override = griffe
				g.rotation.x = -0.35
				bras.add_child(g)
				_griffes_transfo.append(g)
	var peau_c: Color = Bouille.PEAUX[int(moi.apparence.get("peau", 0))] if is_instance_valid(moi) else Bouille.PEAUX[0]
	_peau_transfo = Bouille.materiau(peau_c, 0.0)
	_mains_transfo.visible = true
	_mains_transfo_avancer()


func _mains_transfo_avancer() -> void:
	if _mains_transfo == null or not _mains_transfo.visible:
		return
	var t := maxf(_transfo_t, 0.0)
	# Elles montent, tremblent, puis redescendent.
	var monte := smoothstep(0.0, 0.5, t) * (1.0 - smoothstep(DUREE_TRANSFO - 0.5, DUREE_TRANSFO, t))
	var tremble := sin(t * 61.0) * 0.006 * sin(PI * clampf(t / DUREE_TRANSFO, 0, 1))
	_mains_transfo.position = Vector3(tremble, lerpf(-0.55, -0.12, monte), -0.42)
	# La métamorphose : les doigts s'allongent, la peau se couvre, les griffes sortent.
	var bete := smoothstep(0.9, 1.6, t)
	var mat := _poil_transfo if bete > 0.5 else _peau_transfo
	for m in _paumes_transfo:
		m.material_override = mat
		m.scale = Vector3(1.0, 1.25, 0.45) * lerpf(1.0, 1.35, bete)
	for m in _doigts_transfo:
		m.material_override = mat
		m.scale = Vector3(1, lerpf(2.6, 3.6, bete), 1) * lerpf(1.0, 1.3, bete)
	for i in _griffes_transfo.size():
		var g := _griffes_transfo[i]
		var doigt := _doigts_transfo[i]
		# Au bout du doigt, quelle que soit sa longueur.
		g.position = doigt.position + Vector3(0, 0.017 * doigt.scale.y + 0.012 * bete, -0.006)
		g.visible = bete > 0.05
		g.scale = Vector3.ONE * bete


## Essai (--essai-transfo=<dossier>) : dans sa chambre au premier jour, la transformation se
## joue comme si la meute était appelée ; photos pendant (pour regarder, pas un test).
var _essai_transfo := ""
var _essai_transfo_go := false
var _essai_transfo_t := 0.0


func _essai_transfo_avancer() -> void:
	if etape != "jeu" or _phase() in ["salon", "fin"] or _ma_maison() < 0:
		return
	_essai_transfo_t += get_process_delta_time()
	if not _essai_transfo_go and _essai_transfo_t > 3.0:
		var m := _ma_maison()
		_appliquer_placement(Ronde.siege_lit(m), Ronde.table_carnet(m), "chambre")
		_essai_transfo_go = true
		var dossier := _essai_transfo
		for k in 5:
			get_tree().create_timer(0.3 + k * 0.55).timeout.connect(func():
				get_viewport().get_texture().get_image().save_png("%s/transfo_%d.png" % [dossier, k]))
		get_tree().create_timer(4.5).timeout.connect(get_tree().quit)


## Les saccades de celui qui n'a pas de webcam, en angle autour du point visé.
func _regard_avec_saccades(p: Vector3) -> Vector3:
	if Capteur.saccade == Vector2.ZERO or camera == null:
		return p
	var l := (p - camera.global_position).length()
	var b := camera.global_basis
	return p + (b.x * Capteur.saccade.x + b.y * Capteur.saccade.y) * l


## Ce que le capteur doit savoir du jeu pour animer des yeux sans caméra : le stress (Conseil,
## procès, frayeur) fait cligner plus vite ; Espace ne ferme les yeux que couché ou assis.
func _regler_capteur_sans_camera() -> void:
	var p := _phase()
	var stress := 0.0
	if p in ["conseil", "vote", "depouillement", "tranche", "verdict", "vote_maire"]:
		stress = 0.6
	if _en_proces():
		stress = 1.0
	if _frissons != null and _frissons.frayeur_en_cours():
		stress = maxf(stress, 0.8)
	Capteur.stress = stress
	Capteur.espace_ferme_yeux = mode in ["fige", "assis", "attache", "guide"]


## Suis-je accusé ou condamné devant le village (dépouillement, choix du maire, verdict) ?
func _en_proces() -> bool:
	var pub := meneur.pub
	var moi_id := _moi_id()
	if pub.get("attache", -1) == moi_id:
		return true
	match _phase():
		"depouillement":
			return (pub.get("resultat", {}).get("en_tete", []) as Array).has(moi_id)
		"tranche":
			return (pub.get("tranche", {}).get("candidats", []) as Array).has(moi_id)
		"verdict":
			return (pub.get("resultat", {}).get("en_tete", []) as Array).has(moi_id)
	return false


# ---------------------------------------------------------------- mes yeux, pour l'écran de fin

## Ce que MA webcam voit de mes yeux : compté ici, envoyé à l'hôte seulement à la fin de la partie
## (cf. StatsYeux). Sans webcam on ne compte rien : on n'invente aucune statistique.
var _suivi_yeux := SuiviYeux.new()
var _suivi_yeux_envoye := false


func _suivre_mes_yeux(delta: float) -> void:
	var p := _phase()
	if p == "salon":
		if _suivi_yeux_envoye or _suivi_yeux.suivi_s > 0.0:
			_suivi_yeux = SuiviYeux.new()
			_suivi_yeux_envoye = false
		return
	if etape != "jeu" or p == "fin" or Capteur.mode_souris or Capteur.etat != "ok" or (not _vivant() and not _en_proces()):
		return
	var large := (Capteur.expression("eyeWideLeft") + Capteur.expression("eyeWideRight")) * 0.5
	var ctx := {
		"nuit_dort": p in ["nuit", "distribution"] and mode == "fige",
		"proces": _en_proces(),
		"vote": p in ["vote", "vote_maire"],
		"frayeur": _frissons != null and _frissons.frayeur_en_cours(),
		"detourne": _regard_detourne(),
	}
	_suivi_yeux.echantillon(delta, Capteur.ouverture_yeux(), large, ctx)


## Le regard est-il parti ailleurs que vers l'écran : tête tournée, ou yeux hors de la fenêtre ?
func _regard_detourne() -> bool:
	if absf(Capteur.tx - Regard.neutre_tx) > 0.12:
		return true
	if Regard.calibre:
		var vue := get_viewport().get_visible_rect().size
		var brut := Regard.point_brut()
		return brut.x < -vue.x * 0.08 or brut.x > vue.x * 1.08 or brut.y < -vue.y * 0.08 or brut.y > vue.y * 1.08
	return false


func _animer_moi() -> void:
	if Capteur.visage_vu():
		var tv := Vector3(Capteur.tx - Regard.neutre_tx, (Capteur.ty - Regard.neutre_ty) * 2.5, Capteur.roulis)
		moi.appliquer(Capteur.bs, tv.x, tv.y - tete.rotation.x * 0.6, tv.z, _regard_vu)
		moi.corps_suivi = Capteur.corps
		moi.mains_suivi = Capteur.mains
	moi.devenir_loup((_suis_loup() and _phase() == "nuit" or _essai_transfo_go) and _transforme)


## Un cosmétique porté par celui qui dort dans cette maison ("" s'il n'y en a pas).
func _cosm_de_maison(maison: int, emplacement: String) -> String:
	var s: Dictionary = meneur.pub.get("sieges", {})
	for id in s:
		if int(s[id]["maison"]) == maison:
			return str(Cosmetiques.lire(int(s[id]["apparence"])).get(emplacement, ""))
	return ""


## Chaque maison prend la parure de son habitant ; une mort achetée se joue à l'endroit où l'on tombe.
func _cosmetiques_partie(s: Dictionary) -> void:
	for id in s:
		var c := Cosmetiques.lire(int(s[id]["apparence"]))
		ronde.parer_maison(int(s[id]["maison"]), str(c["maison"]))
		var vivant: bool = s[id]["vivant"] or id == meneur.pub.get("attache", -1)
		var avant: bool = _vivants_vus.get(id, true)
		_vivants_vus[id] = vivant
		if avant and not vivant and str(c["mort"]) != "" and bouilles.has(id) and _phase() != "salon":
			EffetMort.jouer(ronde, bouilles[id], str(c["mort"]))


## Qui voit qui : les morts sont invisibles aux vivants ; la nuit, les loups ont leur vraie tête.
func _visibilite_bouilles() -> void:
	var s: Dictionary = meneur.pub.get("sieges", {})
	_cosmetiques_partie(s)
	var je_vis: bool = _vivant()
	var nuit_: bool = _phase() == "nuit"
	var silhouettes: Array = _priv("silhouettes", [])
	var appel: String = meneur.pub.get("appel", "")
	for id in bouilles:
		var b: Bouille = bouilles[id]
		var vivant: bool = true
		if s.has(id):
			vivant = s[id]["vivant"] or id == meneur.pub.get("attache", -1)
		elif _phase() != "salon":
			vivant = false
		# Les morts : invisibles aux vivants, sauf au Médium ; translucides pour qui les voit.
		b.visible = vivant or not je_vis or _priv("role") == "medium"
		_rendre_solide(b, Corps.solide(b.visible, vivant))
		b.fantome(not vivant and _phase() != "salon")
		# Un loup voit les autres loups en silhouettes sans nom, quand on les appelle.
		var loup_vu: bool = nuit_ and appel in ["loups", "solitaire"] and silhouettes.has(id)
		# Un fantôme voit les loups changés en bêtes, et la métamorphose s'il la regarde (Edwin, 31/10).
		var vu_du_fantome: bool = nuit_ and not je_vis and (_priv("loups_vus", []) as Array).has(id)
		b.devenir_loup(loup_vu or vu_du_fantome, vu_du_fantome)
		b.anonyme(nuit_ or _phase() not in ["salon", "fin"])
		b.dort = nuit_ and Ronde.maison_de(b.global_position) >= 0
		if not b.has_meta("lanterne"):
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.7, 0.35)
			l.omni_range = 7.0
			l.light_energy = 1.4
			l.position = Vector3(0.4, 1.0, 0.3)
			b.add_child(l)
			b.set_meta("lanterne", l)
		(b.get_meta("lanterne") as OmniLight3D).visible = false


func _cadrer_miroir() -> void:
	if not _miroir.visible:
		return
	var devant := -corps_joueur.global_basis.z
	_cam_miroir.global_position = corps_joueur.global_position + Vector3(0, 1.66, 0) + devant * 1.1
	_cam_miroir.look_at(corps_joueur.global_position + Vector3(0, 1.62, 0))


# ================================================================ ambiance, nuit, sons, voix

## Chez un mort, plus personne n'allume (Edwin, 30/10). Au salon et à la fin, tout le monde rallume.
func _maisons_des_morts(p: String) -> Dictionary:
	var r := {}
	if p in ["salon", "fin"]:
		return r
	var s: Dictionary = meneur.pub.get("sieges", {})
	for id in s:
		if not s[id].get("vivant", true):
			r[int(s[id].get("maison", -1))] = true
	return r

func _ambiance(_delta: float) -> void:
	if etape == "accueil":
		ronde.maisons_eteintes = {}
		ronde.regler_ambiance("menu", 0.0)
		return
	var p := _phase() if _ambiance_forcee == "" else _ambiance_forcee
	var reste: float = meneur.pub.get("reste", 0.0)
	ronde.maisons_eteintes = _maisons_des_morts(p)
	match p:
		"salon", "fin":
			ronde.regler_ambiance("jour", 0.2)
		"distribution", "nuit":
			# Le loup transformé, dehors, voit assez bien la nuit (les villageois, non).
			var vision := 1.0 if p == "nuit" and _eveille() and _suis_loup() and Ronde.maison_de(corps_joueur.global_position) < 0 else 0.0
			ronde.regler_ambiance("nuit", vision)
		"aube", "annonce", "trappeur":
			ronde.regler_ambiance("aube", 0.0)
		"choix_maire", "tableau":
			ronde.regler_ambiance("jour", 0.1)
		"quete":
			ronde.regler_ambiance("jour", 0.35)
		"pret":
			ronde.regler_ambiance("jour", 0.6 + 0.3 * (1.0 - clampf(reste / Meneur.DUREES["pret"], 0, 1)))
		"election", "vote_maire", "elu":
			ronde.regler_ambiance("election", 0.0)   # maisons plus claires pour bien voir les candidats
		_:
			ronde.regler_ambiance("conseil", 0.0)
	var jour: bool = _de_jour() or p in ["conseil", "vote", "depouillement", "tranche", "verdict", "salon", "election", "vote_maire", "elu"]
	var fin_jour: bool = p == "pret" and reste < 60.0
	_insonoriser()
	var tension := 1.0 if p == "vote" or fin_jour else (0.6 if p == "pret" or p == "conseil" else 0.0)
	_musique(_delta, p, tension)
	_grillons.volume_db = lerpf(_grillons.volume_db, -22.0 if p == "nuit" else -80.0, 0.02)


func _animer_nuit(delta: float) -> void:
	var p := _phase()
	_maj_compte_loups(delta)
	# Les yeux ne se ferment qu'une fois couché : pendant la marche jusqu'au lit, on voit le crépuscule.
	var voulu := 1.0 if p in ["nuit", "distribution"] and mode == "fige" else 0.0
	nuit = move_toward(nuit, voulu, delta / 1.5)
	var ouverture := Capteur.ouverture_yeux() if Capteur.visage_vu() else 1.0
	var vue := 0.0
	var flou := 0.0
	var plein := 0.0
	var texte := ""
	var role: String = _priv("role", "villageois")
	var appel: String = meneur.pub.get("appel", "")
	var n := nuit
	if not _vivant() or etape != "jeu" or p == "salon" or _cine_t >= 0.0:
		n = 0.0 if _cine_t < 0.0 or _cine_victimes > 0 else 0.4
		if _cine_t >= 0.0:
			texte = _voix_meneur
	elif p == "nuit" or p == "distribution":
		if p == "distribution":
			vue = 0.5
		elif _eveille() and appel in ["loups", "solitaire"]:
			plein = 1.0
			vue = 1.0
			texte = "Sors par ta porte. Rejoins la pierre. Choisis une porte avec la meute."
		elif _eveille():
			vue = 0.75
			texte = _voix_meneur
		else:
			match role if appel == "loups" else "":
				"guetteuse_yeux":
					vue = clampf((ouverture - 0.18) / 0.6, 0.0, 1.0)
					flou = (1.0 - vue) * 3.0
					var loup_proche: bool = false
					for id in bouilles:
						var b: Bouille = bouilles[id]
						if b.visible and Ronde.maison_de(b.global_position) < 0 and b.global_position.distance_to(corps_joueur.global_position) < 9.0:
							loup_proche = true
					if _repere:
						texte = "Un loup t'a vue. Il sait qui tu es."
						vue = maxf(vue, 0.35)
					elif vue <= 0.0:
						texte = "Guetteuse : entrouvre les yeux pour épier, doucement."
					elif vue < 0.7:
						_risque += delta * (0.12 if loup_proche else 0.03)
						texte = "Tu épies à travers tes cils."
					else:
						_risque += delta * (0.6 if loup_proche else 0.15)
						texte = "Yeux grands ouverts : s'ils passent, ils vont te voir !"
					_risque = maxf(_risque - delta * 0.03, 0.0)
					if _risque >= 1.0 and not _repere:
						_repere = true
						_envoyer_intention("repere")
				_:
					if ouverture > 0.45:
						texte = _voix_meneur + "\n\nTu ouvres les yeux… mais il fait noir comme dans un four. Écoute."
					else:
						texte = _voix_meneur
	if _noir:
		n = 1.0
		vue = 0.0
		plein = 0.0
		texte = "…"
	var f_retour := _noir_retour()
	if f_retour > 0.0:
		n = maxf(n, f_retour)
		vue = vue * (1.0 - f_retour)
		plein = plein * (1.0 - f_retour)
		if f_retour > 0.8:
			texte = "…"
	var mort_v := 1.0 if (etape == "jeu" and not _vivant() and _phase() not in ["salon", "fin"]) else 0.0
	_voile.visible = n > 0.001 or mort_v > 0.0
	_voile_mat.set_shader_parameter("mort", mort_v)
	_voile_mat.set_shader_parameter("nuit", n)
	_voile_mat.set_shader_parameter("vue", vue)
	_voile_mat.set_shader_parameter("flou", flou)
	_voile_mat.set_shader_parameter("alerte", clampf(_risque, 0, 1) if role == "guetteuse" else 0.0)
	_voile_mat.set_shader_parameter("temps", _t)
	_voile_mat.set_shader_parameter("plein", plein)
	_texte_nuit.text = texte
	_texte_nuit.modulate.a = maxf(n, 1.0 if _cine_t >= 0.0 else 0.0)


## Les sons sont fabriqués par calcul, et le premier appel de chacun bloquait l'image jusqu'à
## 60 ms en pleine partie (une note de musique toutes les 15 à 30 s : les à-coups, Edwin 31/10).
## Au menu, on les prépare un par image, avant qu'on en ait besoin.
var _a_prechauffer: Array[Callable] = []


func _prechauffer_sons() -> void:
	if _a_prechauffer.is_empty() or (etape == "jeu" and _phase() != "salon"):
		return
	_a_prechauffer.pop_back().call()


func _creer_sons() -> void:
	for v in 4:
		_a_prechauffer.append(Sons.murmure.bind(v))
	for f: Callable in [Sons.cloche, Sons.glas, Sons.coeur, Sons.craquement, Sons.clapotis,
			Sons.cri, Sons.comptine, Sons.hurlement, Sons.coup_vitre]:
		_a_prechauffer.append(f)
	_grillons = _boucle(Sons.grillon())
	var ogg := AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path("res://sons/menu_ambiance.ogg"))
	if ogg:
		ogg.loop = true
		_musique_menu = _boucle(ogg)
	for qui: String in ["jour", "nuit"]:
		var fond := AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path("res://sons/jeu_%s.ogg" % qui))
		if fond:
			fond.loop = true
			var lecteur := _boucle(fond)
			lecteur.bus = "Musique"
			if qui == "jour":
				_musique_jour = lecteur
			else:
				_musique_nuit = lecteur
	# Un léger clic sur tous les boutons du jeu : ceux qui existent déjà, et ceux qui viendront.
	_clic = AudioStreamPlayer.new()
	_clic.stream = Sons.clic()
	_clic.bus = "Effets"
	_clic.volume_db = -15.0
	_clic.max_polyphony = 4
	add_child(_clic)
	for b in get_tree().root.find_children("*", "BaseButton", true, false):
		_brancher_clic(b)
	get_tree().node_added.connect(_brancher_clic)


func _brancher_clic(n: Node) -> void:
	if n is BaseButton and not (n as BaseButton).pressed.is_connected(_jouer_clic):
		(n as BaseButton).pressed.connect(_jouer_clic)


func _jouer_clic() -> void:
	if is_instance_valid(_clic):
		_clic.pitch_scale = _rng.randf_range(0.94, 1.06)
		_clic.play()


## La musique des menus : elle monte à l'accueil et dans les écrans d'avant-partie, et s'efface
## dès qu'on entre dans le village.
func _musique_des_menus(delta: float) -> void:
	if _musique_menu == null:
		return
	var au_menu := etape not in ["jeu", "pause"]
	_musique_menu.volume_db = move_toward(_musique_menu.volume_db, -17.0 if au_menu else -80.0, delta * (30.0 if au_menu else 25.0))


func _boucle(flux: AudioStream) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new()
	a.stream = flux
	a.bus = "Ambiance"
	a.volume_db = -80.0
	add_child(a)
	a.play()
	return a


func _flux(nom: String) -> AudioStream:
	match nom:
		"cloche": return Sons.cloche()
		"glas": return Sons.glas()
		"coeur": return Sons.coeur()
		"craquement": return Sons.craquement()
		"clapotis": return Sons.clapotis()
		"froissement": return Sons.pas("feuilles", randi() % 5)   # un vrai pas sur les feuilles, plus le crépitement de balai
		"caillou": return Sons.caillou()
		"gravier": return Sons.gravier()
		"toc": return Sons.toc()
		"poignee": return Sons.poignee()
		"cri": return Sons.cri()
		"hurlement": return Sons.hurlement()
		"porte": return Sons.porte()
		"porte_ferme": return Sons.porte_ferme()
		"porte_coup": return Sons.porte_coup()
		"chaines": return Sons.chaines()
		"choc": return Sons.choc()
	return null


func _jouer2d(nom: String, volume_db: float) -> void:
	var f := _flux(nom)
	if f == null:
		return
	var a := AudioStreamPlayer.new()
	a.stream = f
	a.bus = "Effets"
	a.volume_db = volume_db + _sourdine_mort()
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)
	if nom in ["cloche", "glas", "cri", "hurlement"]:
		_musique_duck_t = 3.0    # la musique s'efface sous les sons importants


## Un mort entend le monde en sourdine (Edwin, 31/10 : « les bruits quand on est mort sont trop forts »).
func _sourdine_mort() -> float:
	return -12.0 if etape == "jeu" and not _vivant() and _phase() not in ["salon", "fin"] else 0.0


func _jouer3d(nom: String, pos: Vector3, volume_db: float, etouffe: bool) -> void:
	var f := _flux(nom)
	if f == null:
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = f
	a.bus = "Effets"
	# Proximité : on n'entend que ce qui se passe autour de soi (la cloche, elle, porte partout).
	if nom == "cloche":
		a.unit_size = 3.0
		a.max_distance = 60.0
	else:
		Bruit.regler_3d(a)
		if nom in SONS_NETS:
			a.attenuation_filter_cutoff_hz = 20500.0
	a.volume_db = volume_db - (10.0 if etouffe else 0.0) + _sourdine_mort()
	if etouffe:
		a.attenuation_filter_cutoff_hz = 900.0
	# Dans une maison, ce qui se passe dehors n'arrive presque plus.
	var ma := Ronde.maison_de(corps_joueur.global_position) if is_instance_valid(corps_joueur) else -1
	if ma >= 0 and Ronde.maison_de(pos) != ma:
		a.volume_db -= 18.0 * _dedans
		a.attenuation_filter_cutoff_hz = minf(a.attenuation_filter_cutoff_hz, lerpf(20000.0, 500.0, _dedans))
	add_child(a)
	a.global_position = pos
	a.play()
	a.finished.connect(a.queue_free)


## Un bruit dans la nuit : brouillé et étouffé pour qui est enfermé, précis pour l'Oreille fine.
func _sur_bruit(pos: Vector3, sorte: String, deja_entendu := false) -> void:
	var nom: String = SONS_BRUITS.get(sorte, "craquement")
	var ecoute := corps_joueur.global_position
	if sorte == "cloche":
		_jouer3d(nom, pos, 4.0, false)
		return
	var dedans: bool = Ronde.maison_de(ecoute) >= 0
	var source_dedans: bool = Ronde.maison_de(pos) >= 0
	var precise: bool = _priv("role") == "oreille" or not _vivant() or _suis_loup() or _oreille
	# L'hôte a déjà brouillé la position pour qui n'a pas le droit de la connaître exactement.
	var entendu := pos if deja_entendu else Bruit.position_entendue(pos, ecoute, _rng, precise)
	var mur: bool = dedans != source_dedans and not _oreille
	if not Bruit.audible(ecoute.distance_to(pos) * (0.6 if _oreille else 1.0), mur):
		return
	_jouer3d(nom, entendu, VOLUME_PORTE.get(sorte, 0.0) + (5.0 if _oreille else 0.0), mur)
	if _priv("role") == "oreille" and _vivant() and _phase() == "nuit":
		var m := Ronde.maison_proche(pos)
		var h := _habitant(m)
		ecran.message("Un bruit, près de la maison %s%s." % [Ronde.CHIFFRES[m], " (la tienne)" if h == _moi_id() else ""], 3.0)


## Qui entend qui, à chaque image.
func _voix() -> void:
	if not Reseau.en_ligne:
		return
	var p := _phase()
	var je_vis: bool = _vivant()
	var je_suis_loup: bool = _suis_loup()
	var silhouettes: Array = _priv("silhouettes", [])
	var appel: String = meneur.pub.get("appel", "")
	var s: Dictionary = meneur.pub.get("sieges", {})
	var ici := corps_joueur.global_position
	var ma_maison := Ronde.maison_de(ici)
	var tous: bool = p in PHASES_TOUS_ENTENDUS
	for id in bouilles:
		if Meneur.est_bot(id):
			continue
		var b: Bouille = bouilles[id]
		var lui_vit: bool = s[id]["vivant"] if s.has(id) else true
		var audible := true
		var etouffe := false
		var decalage := Vector3.ZERO
		var isolation := 0.0
		var portee: float = PORTEE_CONSEIL if tous else PORTEES_VOIX[clampi(int(s.get(id, {}).get("portee", 1)), 0, 2)]
		var dist := b.global_position.distance_to(ici)
		if not lui_vit and je_vis:
			audible = false
		elif tous:
			pass                  # le Conseil : tout le monde s'entend, chacun à sa place
		elif p == "nuit" and je_vis:
			var lui_loup: bool = silhouettes.has(id) or (not je_suis_loup and appel in ["loups", "solitaire"] and Ronde.maison_de(b.global_position) < 0)
			if appel not in ["loups", "solitaire"]:
				audible = false   # tout le monde dort, on ne parle pas
			elif not lui_loup and not je_suis_loup:
				audible = false   # le village dort
			elif lui_loup and not je_suis_loup:
				# Les maisons sont insonorisées ; l'oreille collée au mur, on surprend un loup qui
				# parle fort, étouffé, d'une direction faussée.
				audible = _oreille and dist <= portee
				etouffe = true
				decalage = _decalage_brouille(id, b.global_position, ici)
			elif not lui_loup and je_suis_loup:
				audible = false
			else:
				var r := _a_travers_murs(b.global_position, ma_maison)
				audible = dist <= portee and r[0]
				etouffe = r[1]
				isolation = r[2]
		else:
			var r := _a_travers_murs(b.global_position, ma_maison)
			audible = dist <= portee and r[0]
			etouffe = r[1]
			isolation = r[2]
		Voix.regler(id, audible, etouffe, decalage, isolation, portee)
		# La bouche suit la voix, mais seulement si je l'entends : sinon elle trahirait qui parle.
		b.parole = Voix.niveau(id) if audible else 0.0
	moi.parole = Voix.mon_niveau



## Entre deux pièces : porte fermée, rien ne passe, même un cri ; porte ouverte, une voix
## étouffée. Renvoie [audible, étouffé, isolation].
func _a_travers_murs(source: Vector3, ma_maison: int) -> Array:
	var sa_maison := Ronde.maison_de(source)
	if sa_maison == ma_maison:
		return [true, false, 0.0]
	for m in [ma_maison, sa_maison]:
		if m >= 0 and not (ronde.porte_ouverte(m, "avant")):
			return [false, true, 1.0]
	return [true, true, 0.4]


## La touche C : chuchoter → parler → crier. Un anneau bleu montre un instant jusqu'où on porte.
func _changer_portee() -> void:
	if not Visibilite.portee_modifiable(_phase()):
		return                # tout le monde s'entend : la touche ne fait rien
	_ma_portee = (_ma_portee + 1) % 3
	if Reseau.en_ligne:
		_envoyer_intention("portee", _ma_portee)
	var r: float = PORTEES_VOIX[_ma_portee]
	if _phase() in PHASES_TOUS_ENTENDUS:
		ecran.message("%s (%d m) — au Conseil, tout le monde t'entend." % [NOMS_PORTEE[_ma_portee], int(r)], 2.5)
	else:
		ecran.message("%s : on t'entend à %d m." % [NOMS_PORTEE[_ma_portee], int(r)], 2.0)
	_anneau_portee(r)


var _anneau: Node3D = null

func _anneau_portee(r: float) -> void:
	if is_instance_valid(_anneau):
		_anneau.queue_free()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.35, 0.7, 1.0, 0.9)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fond := mat.duplicate() as StandardMaterial3D
	fond.albedo_color = Color(0.3, 0.6, 1.0, 0.12)
	var n := Node3D.new()
	var bord := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = r - 0.06
	t.outer_radius = r + 0.06
	t.rings = 96
	bord.mesh = t
	bord.material_override = mat
	bord.scale.y = 0.6
	bord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(bord)
	var disque := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 0.01
	c.radial_segments = 64
	disque.mesh = c
	disque.material_override = fond
	disque.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(disque)
	add_child(n)
	n.global_position = Vector3(corps_joueur.global_position.x, 0.06, corps_joueur.global_position.z)
	_anneau = n
	# Il s'étend depuis les pieds, puis s'efface : il ne reste pas.
	n.scale = Vector3(0.6, 1, 0.6)
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.0).set_delay(0.9)
	tw.parallel().tween_property(fond, "albedo_color:a", 0.0, 1.0).set_delay(0.9)
	tw.tween_callback(n.queue_free)


func _decalage_brouille(id: int, source: Vector3, ecoute: Vector3) -> Vector3:
	var e: Array = _brouillage.get(id, [Vector3.ZERO, -1.0])
	if _t > e[1]:
		var faux := Bruit.position_entendue(source, ecoute, _rng)
		e = [faux - source, _t + 3.0]
		_brouillage[id] = e
	return e[0]


func _dessiner_fils(votes: Dictionary) -> void:
	for v in _fils.keys():
		if not votes.has(v):
			_fils[v].queue_free()
			_fils.erase(v)
	for v in votes:
		if not _fils.has(v):
			var m := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.025
			c.bottom_radius = 0.025
			c.height = 1.0
			m.mesh = c
			m.material_override = Bouille.materiau(Color(0.8, 0.05, 0.03), 0.0, Color(1.0, 0.08, 0.04))
			add_child(m)
			_fils[v] = m
		_fils[v].set_meta("cible", votes[v])
	_placer_fils()


func _placer_fils() -> void:
	for v in _fils:
		var a := _tete_de(v)
		var b := _tete_de(int(_fils[v].get_meta("cible")))
		var m: MeshInstance3D = _fils[v]
		if a == Vector3.ZERO or b == Vector3.ZERO:
			m.visible = false
			continue
		m.visible = true
		_orienter_fil(m, a, b)


func _tete_de(id: int) -> Vector3:
	if id == _moi_id():
		return corps_joueur.global_position + Vector3(0, 1.55, 0)
	if bouilles.has(id):
		return bouilles[id].global_position + Vector3(0, 1.55, 0)
	return Vector3.ZERO


# ================================================================ entrées

## Le carnet ouvert en lecture est au milieu de l'écran, là où la souris captée « clique » : sans ce
## détour, il avalait les clics et la molette (Edwin, 01/11 : il ne se fermait plus, on ne pouvait
## pas écrire). On les prend donc avant l'interface tant que la plume n'est pas posée.
func _input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed) or etape != "jeu" or _carnet == null or not _carnet.visible:
		return
	# Plume posée : un clic droit n'importe où la lève (sur la page, le carnet s'en charge déjà).
	if _carnet.ecriture:
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			_carnet.ecrire(false)
			get_viewport().set_input_as_handled()
		return
	# Souris libre (un panneau vient de se fermer, la plume vient de se lever) : le clic gauche referme quand même,
	# sinon le livre restait ouvert sans qu'aucune touche ne le ferme (Edwin, 01/11).
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if ev.button_index == MOUSE_BUTTON_LEFT and not ecran.panneau_ouvert():
			_carnet_fermer()
			get_viewport().set_input_as_handled()
		return
	match ev.button_index:
		MOUSE_BUTTON_LEFT:
			_carnet_fermer()
		MOUSE_BUTTON_RIGHT:
			_clic_droit_objets()
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			_carnet.tourner(-1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		_:
			return
	get_viewport().set_input_as_handled()


func _unhandled_input(ev: InputEvent) -> void:
	if _entree_roue(ev):
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventMouseMotion and etape == "jeu" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# La main serre quelque chose dans une quête : la souris la déplace, la tête ne bouge plus.
		if _monde_quete and _monde_quete.absorber_souris(ev.relative):
			return
		if mode == "guide":
			# Le corps marche tout seul : seule la tête tourne.
			_souris_guide_t = Time.get_ticks_msec() / 1000.0
			tete.rotation.y = clampf(tete.rotation.y - ev.relative.x * SENSIBILITE, -1.5, 1.5)
		elif _assis_libre and _sur_lit:
			# Au bord du lit, le corps ne bouge pas : seule la tête tourne.
			tete.rotation.y = clampf(tete.rotation.y - ev.relative.x * SENSIBILITE, -1.3, 1.3)
		elif _assis_libre or mode == "assis":
			# Sur la souche : un demi-tour au plus, toujours face à la scène du débat.
			var ecart := wrapf(corps_joueur.rotation.y - ev.relative.x * SENSIBILITE - _yaw_siege, -PI, PI)
			corps_joueur.rotation.y = _yaw_siege + clampf(ecart, -PI * 0.5, PI * 0.5)
		else:
			corps_joueur.rotate_y(-ev.relative.x * SENSIBILITE)
		tete.rotation.x = clampf(tete.rotation.x - ev.relative.y * SENSIBILITE, -1.2, 1.2)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_F10 and _mode_test and etape == "jeu" and meneur.est_hote() and not Reseau.en_ligne:
			_basculer_panneau_test()
			return
		if _combo and ev.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE]:
			_combo.appuyer(ev.keycode)
			return
		if ev.keycode == KEY_ESCAPE and _panneau_options_jeu.visible:
			_montrer_options_jeu(false)
			return
		if ev.keycode == KEY_ESCAPE and (_panneau_emotes.visible or _panneau_role.visible or _panneau_volumes.visible):
			_panneau_emotes.visible = false
			_panneau_role.visible = false
			_panneau_volumes.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		var action := ""
		for a: Array in Reglages.ACTIONS:
			if Options.est(ev, a[0]):
				action = a[0]
				break
		if action == "reseau":
			_diag.visible = not _diag.visible
			_diag_t = 1.0
			return
		if (action == "exclusion_oui" or action == "exclusion_non") and etape in ["jeu", "pause"] and _panneau_excl.touche(action == "exclusion_oui"):
			return
		if etape == "jeu" and not _panneau_emotes.visible and ecran.vote_quete_visible():
			var k := _chiffre(ev)
			if _vote_participation:
				if k == 1 or k == 2:
					_voter_quete(0 if k == 1 else Quetes.RESTER)
					return
			elif k >= 1 and k <= Quetes.RESTER + 1:
				_voter_quete(k - 1)
				return
		if etape == "jeu" and _panneau_emotes.visible and ev.keycode >= KEY_1 and ev.keycode <= KEY_9:
			var k := int(ev.keycode - KEY_1)
			if k < _emotes_dispo.size():
				_faire_emote(_emotes_dispo[k][0])
			return
		# 1 à 4 : l'objet de l'emplacement en main. Jamais pendant le vote de quête, ni quand une carte
		# de choix, le panneau des gestes ou le carnet sont ouverts : eux d'abord.
		var chiffre := _chiffre(ev)
		if chiffre >= 1 and chiffre <= Objets.SLOTS and etape == "jeu" and _vivant() and _phase() not in ["salon", "fin"] and not _au_poste() \
				and not _carnet.ecriture and not ecran.panneau_ouvert() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
				and Clics.chiffre_pour_inventaire(_phase(), ecran.vote_quete_visible(), _vue_quete != null and _vue_quete.a_des_choix(), _panneau_emotes.visible):
			_choisir_slot(chiffre - 1)
			return
		if ev.keycode == KEY_ESCAPE and _carnet.ecriture:
			_carnet.ecrire(false)      # la plume se lève ; le carnet reste ouvert en lecture
			return
		if ev.keycode == KEY_ESCAPE and _carnet.visible and etape == "jeu":
			_carnet_fermer()           # un second Échap referme le livre (et n'ouvre pas la pause par-dessus)
			return
		if _carnet.visible and etape == "jeu" and not _carnet.ecriture and (ev.keycode == KEY_LEFT or ev.keycode == KEY_RIGHT):
			_carnet.tourner(-1 if ev.keycode == KEY_LEFT else 1)
			return
		if action == "note" and etape == "jeu" and _phase() != "salon":
			ecran.basculer_note()
			return
		if action == "lire" and etape == "jeu" and _phase() != "salon" and _vivant() and not _au_poste():
			_lire_objet()
			return
		if action == "poser" and etape == "jeu" and _phase() != "salon" and not _carnet.ecriture and not _au_poste():
			_poser_objet()
			return
		if action == "jeter" and etape == "jeu" and _phase() != "salon" and not _carnet.ecriture and _vivant() and not _au_poste() 				and _vue_objets != null and _vue_objets.en_main() >= 0 and not ecran.panneau_ouvert():
			_lancer_en_main()
			return
		if action == "volumes" and etape == "jeu" and _phase() != "salon":
			_basculer_volumes()
			return
		if action == "interagir" and etape == "jeu":
			_toucher_interagir()
			return
		if action == "emotes" and etape == "jeu" and _phase() != "salon":
			_panneau_emotes.visible = not _panneau_emotes.visible
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _panneau_emotes.visible else Input.MOUSE_MODE_CAPTURED
			return
		if action == "role" and etape == "jeu" and _phase() != "salon":
			if _panneau_role.visible:
				_panneau_role.visible = false
			else:
				_montrer_role()
			return
		match "echap" if ev.keycode == KEY_ESCAPE else action:
			"echap":
				if etape == "accueil":
					_menu.retour()
				elif etape == "reglage":
					_reglage_retour()
				elif ecran.panneau_ouvert():
					ecran.fermer_panneau()
				elif etape == "jeu":
					_aller("pause")
				elif etape == "pause":
					_aller("jeu")
			"agir":
				if etape == "jeu" and _sortie:
					_coup_de_sortie()
				elif etape == "jeu":
					var act := _action_possible()
					if not act.is_empty() and (act[1] as Callable).is_valid():
						(act[1] as Callable).call()
			"pret":
				if etape == "jeu" and Prets.accepte(_phase()) and _vivant():
					_envoyer_intention("pret")
					_jouer2d("cloche", -14.0)
			"pouvoir":
				if etape == "jeu" and _phase() == "successeur" and meneur.pub.get("successeur", -1) == _moi_id():
					_panneau_successeur()
				elif etape == "jeu" and _phase() == "tranche" and (meneur.pub.get("tranche", {}) as Dictionary).get("par", -1) == _moi_id():
					_panneau_tranche()
				elif etape == "jeu" and mode == "attache":
					ecran.message("Tu es enchaîné : tu ne peux plus rien, qu'attendre la nuit.", 2.5)
				elif etape == "jeu" and not _vivant() and _phase() not in ["salon", "fin"]:
					if _energie() < Meneur.COUT_GRANDE_APPARITION:
						ecran.message("Trop faible pour apparaître à tous : attends que ton énergie remonte.", 2.5)
					else:
						_envoyer_intention("grande_apparition")
				elif etape == "jeu" and _phase() == "successeur" and meneur.pub.get("successeur", -1) == _moi_id():
					_panneau_successeur()
				elif etape == "jeu" and _phase() != "salon":
					_ouvrir_pouvoir()
					if ecran.panneau_ouvert():
						Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			"portee":
				if etape == "jeu":
					_changer_portee()
			"miroir":
				_miroir.visible = not _miroir.visible
			"passer":
				# Nuit guidée : la touche passe l'étape du tutoriel, pas celle de la partie.
				if _tuto != null:
					if etape == "jeu":
						_tuto.passer()
				# L'hôte accélère : l'étape en cours se termine tout de suite.
				elif etape == "jeu" and meneur.est_hote() and _phase() not in ["salon", "fin"]:
					_envoyer_intention("passer")
	elif ev is InputEventMouseButton and ev.pressed and etape == "jeu" and _monde_quete != null and not _carnet.visible \
			and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN) \
			and _monde_quete.molette(1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else -1):
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.pressed and etape == "jeu" and _carnet.visible \
			and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_carnet.tourner(-1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
	elif ev is InputEventMouseButton and ev.pressed and _inventaire_ouvert_au_jeu() \
			and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_molette_inventaire(-1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT and etape == "jeu" and not _sortie \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_clic_droit_objets()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and etape == "jeu" and _sortie:
		_coup_de_sortie()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and etape == "jeu":
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if not ecran.panneau_ouvert() and not ecran.salon_visible() and not ecran.fin_visible() and not _panneau_volumes.visible and not (_vue_quete.visible and not _vue_quete.discret) and not _carnet.visible:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		var centre := get_viewport().get_visible_rect().size * 0.5
		if mode == "fantome" and _caillou_main:
			_lancer_caillou()
		elif _monde_quete and _monde_quete.viser() >= 0:
			_monde_quete.toucher()
		elif _phase() == "nuit" and _vote_maison >= 0 and _suis_loup():
			_envoyer_intention("vote_loup", _vote_maison)
			_jouer2d("coeur", -8.0)
		elif _phase() in PHASES_VOTE and _vise_bouille >= 0 and (_vise_t > 1.2 or _phase() == "vote_maire") and _vise_bouille != _moi_id() and _est_vivant(_vise_bouille) and _vivant():
			_vote_cible = _vise_bouille
			_vise_t = 0.0
			_envoyer_intention("voter", _vote_cible)
			_jouer2d("coeur", -6.0)
		elif _clic_gauche_objets():
			pass
		elif _vise_bouille >= 0:
			# Clic sur quelqu'un = on le regarde vraiment : recalage discret du regard.
			Regard.recaler_sur(_point_regard() if Regard.calibre else centre)


# ================================================================ pilote automatique (agent testeur)

var _auto_dir := Vector3.ZERO
var _auto_t := 0.0
var _auto_chemin: Array[Vector3] = []


## Un pas de la marche guidée : renvoie la direction (monde) et tourne le corps vers elle.
## À l'arrivée (ou coincé trop longtemps), on applique la place finale.
func _guider(delta: float) -> Vector3:
	_guide_t += delta
	var ici := corps_joueur.global_position
	while not _guide.is_empty() and Vector2(_guide[0].x - ici.x, _guide[0].z - ici.z).length() < 0.35:
		_guide.pop_front()
		_guide_mieux = INF
	# Dès qu'on est rentré chez soi au soir : SA porte se ferme (l'hôte la voit), on reprend les commandes.
	if _guide_fin.size() >= 3 and _guide_fin[2] == "chambre" and _phase() in ["distribution", "nuit"] 			and Meneur.est_rentre(ici, _ma_maison()):
		_guide.clear()
		_entrer_chez_soi()
		return Vector3.ZERO
	if _guide.is_empty() or _guide_t > _guide_max or (_guide_bloque > 1.5 and _guide_ecarts >= 4):
		var f := _guide_fin
		_guide.clear()
		_guide_portes.clear()
		_appliquer_placement(f[0], f[1], f[2])
		return Vector3.ZERO
	# Devant une porte close sur le trajet : on la pousse (ouverture normale, vue et entendue de tous),
	# on attend qu'elle ait tourné, puis on passe. Jamais à travers un mur.
	var devant := _guider_porte(ici, delta)
	if devant != Vector3.ZERO:
		var cap_p := atan2(-devant.x, -devant.z)
		corps_joueur.rotation.y = lerp_angle(corps_joueur.rotation.y, cap_p, minf(delta * 6.0, 1.0))
		_guide_mieux = INF
		_guide_bloque = 0.0
		return Vector3.ZERO
	var d := _guide[0] - ici
	d.y = 0
	var vitesse_reelle := Vector2(corps_joueur.velocity.x, corps_joueur.velocity.z).length()
	# Coincé = on n'approche plus du prochain point (frotter un mur en glissant garde de la
	# vitesse : la vitesse seule ne le voit pas). D'abord on recalcule le chemin d'ici ; ensuite
	# on fait un pas de côté, à gauche puis à droite, de plus en plus large ; en dernier recours
	# seulement, on pose.
	var reste := Vector2(d.x, d.z).length()
	if reste < _guide_mieux - 0.15:
		_guide_mieux = reste
		_guide_bloque = 0.0
	elif _guide_t > 0.5:
		_guide_bloque += delta * (2.0 if vitesse_reelle < 0.3 else 1.0)
	if _guide_bloque > 1.5 and not _guide_recalcule:
		_guide_recalcule = true
		_guide = _chemin_guide(ici, _guide_fin[0])
		_guide_mieux = INF
		_guide_bloque = 0.0
	elif _guide_bloque > 1.5 and _guide_ecarts < 4:
		var cote := Vector3(-d.z, 0, d.x).normalized() * (1.0 if _guide_ecarts % 2 == 0 else -1.0)
		var recul := -d.normalized() * 0.4
		_guide.push_front(ici + cote * (1.0 + 0.6 * (_guide_ecarts / 2)) + recul)
		_guide_ecarts += 1
		_guide_mieux = INF
		_guide_bloque = 0.0
		d = _guide[0] - ici
		d.y = 0
	var cap := atan2(-d.x, -d.z)
	corps_joueur.rotation.y = lerp_angle(corps_joueur.rotation.y, cap, minf(delta * 6.0, 1.0))
	return d.normalized()


## La porte que la marche guidée doit franchir : renvoie la direction de la porte tant qu'il faut
## attendre devant (porte à pousser, ou battant en train de tourner), sinon ZERO. Au-delà de 3 s sans que
## la porte cède (la nuit elle reste close), on cesse d'attendre : la marche reprend son cours.
func _guider_porte(ici: Vector3, delta: float) -> Vector3:
	if _guide_portes.is_empty():
		return Vector3.ZERO
	var p: Dictionary = _guide_portes[0]
	var m: int = p["maison"]
	var q: String = p["porte"]
	var l := Ronde._vers_local(m, ici)
	var s := 1.0 if q == "avant" else -1.0
	var dehors := l.z * s > Ronde.PROFONDEUR * 0.5 + 0.45
	var dedans := l.z * s < Ronde.PROFONDEUR * 0.5 - 0.9 and absf(l.x) < Ronde.LARGEUR * 0.5
	if (p["sortie"] and dehors) or (not p["sortie"] and dedans):
		_guide_portes.pop_front()
		_guide_porte_attente = 0.0
		_guide_porte_demande = -1.0
		return Vector3.ZERO
	var c := Trajets.centre_porte(m, q)
	var d := c - ici
	d.y = 0
	if _guide_porte_attente > 3.0:
		return Vector3.ZERO
	# La porte s'ouvre AVANT qu'on arrive (dès 3,2 m), sans qu'on s'arrête : on ne patiente que si le
	# battant tourne encore quand on est tout contre (Edwin, 01/11 : plus fluide).
	if d.length() > 3.2:
		return Vector3.ZERO
	var tourne: bool = _guide_porte_demande >= 0.0 and _guide_t - _guide_porte_demande < 0.8
	if ronde.porte_ouverte(m, q):
		if d.length() <= 1.4 and tourne:
			_guide_porte_attente += delta
			return d.normalized()
		return Vector3.ZERO
	if _guide_porte_demande < 0.0 or _guide_t - _guide_porte_demande > 1.0:
		_guide_porte_demande = _guide_t
		_envoyer_intention("porte", m, q)
	if d.length() <= 1.4:
		_guide_porte_attente += delta
		return d.normalized()
	return Vector3.ZERO


## Le chemin de la marche guidée. Une clairière de quête est hors du village : on passe par la
## trouée de la lisière (comme les bots, cf. meneur._aller_zone / _rentrer).
func _chemin_guide(de: Vector3, vers: Vector3) -> Array[Vector3]:
	var nuit_ := _phase() == "nuit"
	var ouvertes: Dictionary = meneur.pub.get("portes", {})
	var dehors_de := Ronde.hors_village(de)
	var dehors_vers := Ronde.hors_village(vers)
	var r: Array[Vector3] = []
	_guide_portes.clear()
	_guide_porte_attente = 0.0
	_guide_porte_demande = -1.0
	if dehors_vers and not dehors_de:
		var k := Quetes.zone_proche(vers)
		var marche := Terre.marche_vers_clairiere(k, vers)
		r = Trajets.chemin(de, marche[0], nuit_, ouvertes)
		_guide_portes.assign(Trajets.portes_a_franchir(de, marche[0], nuit_, ouvertes))
		r.append_array(marche)
		return r
	elif dehors_de and not dehors_vers:
		var k := Quetes.zone_proche(de)
		var marche := Terre.marche_vers_clairiere(k, de)
		marche.reverse()
		marche.remove_at(0)   # on y est déjà
		r = marche
		r.append_array(Trajets.chemin(marche[marche.size() - 1], vers, nuit_, ouvertes))
		_guide_portes.assign(Trajets.portes_a_franchir(marche[marche.size() - 1], vers, nuit_, ouvertes))
	elif not dehors_de:
		r = Trajets.chemin(de, vers, nuit_, ouvertes)
		_guide_portes.assign(Trajets.portes_a_franchir(de, vers, nuit_, ouvertes))
	r.append(vers)
	return r


func _auto_aller(vers: Vector3, nuit_: bool) -> void:
	_auto_chemin = Trajets.chemin(corps_joueur.global_position, vers, nuit_)


## Vers le tableau en faisant le tour de la place (en ligne droite, on bute sur les souches).
func _auto_vers_tableau() -> void:
	var ici := corps_joueur.global_position
	var a0 := atan2(ici.x, ici.z)
	var a1 := atan2(Ronde.TABLEAU.x, Ronde.TABLEAU.z)
	var ecart := wrapf(a1 - a0, -PI, PI)
	_auto_chemin.clear()
	var n := maxi(1, int(absf(ecart) / 0.4))
	for i in range(0, n + 1):
		var a := a0 + ecart * i / n
		_auto_chemin.append(Vector3(sin(a), 0, cos(a)) * 7.0)
	_auto_chemin.append(Ronde.TABLEAU - Ronde.TABLEAU.normalized() * 3.5)


## Le pilote répond à l'appel de son rôle comme le ferait un joueur pressé.
func _auto_appel(appel: String) -> void:
	var v := _vivants_autres()
	if v.is_empty():
		return
	var c: int = v[_rng.randi_range(0, v.size() - 1)]
	match appel:
		"liseuse":
			_envoyer_intention("lire", c)
		"veilleur":
			_envoyer_intention("garder", c)
			_envoyer_intention("garder", v[(v.find(c) + 1) % v.size()])
		"entremetteuse":
			_envoyer_intention("lier", c, _moi_id())
		"enfant":
			_envoyer_intention("modele", c)
		"loups", "solitaire":
			if "--loup-passif" in OS.get_cmdline_user_args():
				return   # essai : le loup ne fait rien, la transformation d'office doit le faire sortir
			_envoyer_intention("sortir", _rng.randi_range(0, 3))
			mode = "libre"
			var a := _rng.randf() * TAU
			_auto_aller(Ronde.autour_autel(a), true)
	if appel == "herboriste":
		get_tree().create_timer(1.5).timeout.connect(func():
			var maisons: Array = _priv("maisons_attaquees", [])
			if not maisons.is_empty() and _rng.randf() < 0.6:
				_envoyer_intention("sauver_maison", maisons[0]))


## Joue tout seul pour l'agent testeur : tâches le jour, pierre et vote la nuit s'il est loup.
func _pilote_auto(delta: float) -> void:
	_auto_t -= delta
	var p := _phase()
	var ici := corps_joueur.global_position
	if ecran.salon_visible() and meneur.est_hote() and p == "salon":
		# Avec --lancer-apres, on attend les autres joueurs : c'est le minuteur qui lance.
		if not Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--lancer-apres=")):
			meneur.lancer_partie()
		return
	if ecran.fin_visible():
		return
	var appel: String = meneur.pub.get("appel", "")
	if _auto_t <= 0:
		_auto_t = 3.0
		match p:
			"tableau":
				if _mon_vote_quete < 0 and _vivant():
					_voter_quete(_rng.randi_range(0, Quetes.RESTER - 1))
			"quete":
				var q := _ma_quete()
				if not q.is_empty() and _auto_chemin.is_empty() and mode == "libre":
					var k: int = q["zone"]
					if q["etat"] == "trajet":
						# Le tour de la place jusqu'à l'angle du passage, puis tout droit entre deux maisons.
						var a0 := atan2(ici.x, ici.z)
						var ecart := wrapf(deg_to_rad(Quetes.ANGLES_ZONES[k]) - a0, -PI, PI)
						var n := maxi(1, int(absf(ecart) / 0.4))
						_auto_chemin.clear()
						for i in range(0, n + 1):
							var a := a0 + ecart * i / n
							_auto_chemin.append(Vector3(sin(a), 0, cos(a)) * 5.0)   # à l'intérieur du tableau, autour de la pierre
						for r in [8.0, 12.0, 18.0, 26.0, Ronde.R_LISIERE - 3.0, Ronde.R_LISIERE + 2.5]:
							_auto_chemin.append(Quetes.passage(k, r))
						_auto_chemin.append(Quetes.zone(k))
					elif q["etat"] == "retour" and Vector2(ici.x - Quetes.portail_retour().x, ici.z - Quetes.portail_retour().z).length() > 1.5:
						# Jusqu'au portail du sentier, et on y reste.
						_auto_chemin.assign([Quetes.passage(k, Ronde.R_LISIERE + 2.5), Quetes.portail_retour()])
			"pret", "election":
				if not (meneur.pub.get("prets", []) as Array).has(_moi_id()):
					_envoyer_intention("pret")
			"nuit":
				if _eveille() and appel in ["loups", "solitaire"]:
					var votes: Dictionary = _priv("votes_loups", {})
					if Ronde.a_l_autel(ici, Meneur.PORTEE_PIERRE) and not votes.has(_moi_id()):
						var cibles := []
						for id in _vivants_autres():
							if not (_priv("silhouettes", []) as Array).has(id):
								cibles.append(id)
						if not cibles.is_empty():
							var c: int = cibles[_rng.randi_range(0, cibles.size() - 1)]
							_envoyer_intention("vote_loup", meneur.pub["sieges"][c]["maison"])
					elif votes.has(_moi_id()) and _auto_chemin.is_empty() and Ronde.maison_de(ici) != _ma_maison():
						_auto_aller(Ronde.lit(_ma_maison()), true)
			"vote", "vote_maire":
				var v := _vivants_autres()
				if not v.is_empty() and _vote_cible < 0 and _vivant():
					_vote_cible = v[_rng.randi_range(0, v.size() - 1)]
					_envoyer_intention("voter", _vote_cible)
			"trappeur":
				if meneur.pub.get("trappeur", -1) == _moi_id():
					var v := _vivants_autres()
					if not v.is_empty():
						_envoyer_intention("trappe", v[0])
	if _combo:
		if _combo.mode == "suite" and _combo.index < _combo.attendu.size() and _rng.randf() < 0.3:
			_combo.appuyer(_combo.attendu[_combo.index] if _rng.randf() < 0.85 else KEY_UP)
		elif _combo.mode == "rythme" and _combo.phase_battement() > 0.97:
			_combo.appuyer(KEY_SPACE)
	_auto_dir = Vector3.ZERO
	if mode in ["libre", "poste"] and not _auto_chemin.is_empty():
		var d := _auto_chemin[0] - ici
		d.y = 0
		if d.length() < 0.5:
			_auto_chemin.pop_front()
		else:
			corps_joueur.rotation.y = lerp_angle(corps_joueur.rotation.y, atan2(-d.x, -d.z), clampf(delta * 8.0, 0, 1))
			_auto_dir = Vector3(0, 0, -1)
	if mode == "fantome" and "--fantome-marche" in OS.get_cmdline_user_args():
		# Essai : le fantôme se promène tout seul (tout droit, en tournant doucement).
		corps_joueur.rotation.y += delta * 0.25
		_auto_dir = Vector3(0, 0, -1)
		if Engine.get_physics_frames() % 90 == 0 and _phase() not in ["nuit", "salon", "fin"]:
			if _caillou_main == null:
				_ramasser_caillou()
			else:
				_lancer_caillou()
	if not _de_jour() and p != "nuit":
		_auto_chemin.clear()


# ================================================================ dessins 2D

class Luciole extends Control:
	var pos := Vector2.ZERO
	var mesure := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.05, 0.85))
		var pulse := 1.0 + sin(_t * 8.0) * 0.15
		for i in range(6, 0, -1):
			draw_circle(pos, i * 9.0 * pulse, Color(1.0, 0.9, 0.35, 0.05))
		draw_circle(pos, 9.0, Color(1.0, 0.97, 0.7))
		draw_circle(pos, 4.0, Color.WHITE)
		var aile := sin(_t * 40.0) * 4.0
		draw_circle(pos + Vector2(-9, -6 - aile), 6, Color(0.8, 0.9, 1.0, 0.5))
		draw_circle(pos + Vector2(9, -6 - aile), 6, Color(0.8, 0.9, 1.0, 0.5))
		var f := get_theme_default_font()
		var texte := Langue.t("Suis la luciole des yeux, sans bouger la tête") if not mesure else Langue.t("Fixe-la…")
		draw_string(f, Vector2(size.x * 0.5 - 260, size.y - 40), texte, HORIZONTAL_ALIGNMENT_CENTER, 520, 24, Color(1, 1, 1, 0.8))


## Les ids des joueurs vivants, tels que l'hôte les a publiés.
func _vivants_ids() -> Array:
	var r: Array = []
	var s: Dictionary = meneur.pub.get("sieges", {})
	for id in s:
		if s[id]["vivant"]:
			r.append(id)
	return r


func _nb_vivants() -> int:
	var n := 0
	var s: Dictionary = meneur.pub.get("sieges", {})
	for id in s:
		if s[id]["vivant"]:
			n += 1
	return n


# ================================================================ gestes face à quelqu'un (cf. gestes.gd)

var _gestes_ui: GestesUI
var _roue_cible := -1            # qui la roue vise (figé à l'ouverture)
var _roue_tenue := false         # la touche est tenue depuis l'ouverture : la relâcher valide
var _pousse_v := Vector3.ZERO    # ma vitesse de poussée, qui décroît seule (1 m en tout)
var _chuchote_t := 0.0           # ma voix est un chuchotement jusque-là
var _portee_avant := 1


func _construire_gestes(calque: CanvasLayer) -> void:
	_gestes_ui = GestesUI.new()
	_gestes_ui.camera = camera
	calque.add_child(_gestes_ui)
	_gestes_ui.choisi.connect(_geste_choisi)
	_gestes_ui.annule.connect(func(): _roue_fermee())


## Peut-on faire un geste maintenant ? Debout dans le village, vivant, hors vote, nuit et panneaux.
func _peut_geste() -> bool:
	if etape != "jeu" or not _vivant() or mode != "libre" or _assis_libre or _cine_t >= 0.0:
		return false
	if not Gestes.phase_permise(_phase()) or ecran.panneau_ouvert() or _panneau_emotes.visible or _carnet.visible:
		return false
	return _combo == null and _sortie == null and _reussite == null


## Le joueur que je regarde de près (~2 m), ou -1.
func _cible_geste() -> int:
	if _vise_bouille >= 0 and bouilles.has(_vise_bouille) and _est_vivant(_vise_bouille):
		var b: Bouille = bouilles[_vise_bouille]
		if b.visible and b.global_position.distance_to(corps_joueur.global_position) <= Gestes.PORTEE_INVITE:
			return _vise_bouille
	# Le regard suivi par la webcam bouge : à défaut, la personne la plus proche droit devant
	# (Edwin, 31/10 : impossible de viser un bot).
	var devant := -camera.global_basis.z
	devant.y = 0
	devant = devant.normalized()
	var meilleure := -1
	var d_min := Gestes.PORTEE_INVITE
	for id in bouilles:
		var b: Bouille = bouilles[id]
		if id == _moi_id() or not b.visible or not _est_vivant(id):
			continue
		var vers := b.global_position - corps_joueur.global_position
		vers.y = 0
		var d := vers.length()
		if d < d_min and d > 0.01 and devant.angle_to(vers / d) < deg_to_rad(40.0):
			d_min = d
			meilleure = id
	return meilleure


func _invite_geste() -> String:
	if _gestes_ui == null or _gestes_ui.roue_ouverte() or not _peut_geste():
		return ""
	var c := _cible_geste()
	if c < 0:
		return ""
	return "Interagir"


## La touche « interagir » : accepter ce qu'on me propose, sinon ouvrir la roue sur celui que je regarde.
func _toucher_interagir() -> void:
	if _gestes_ui == null:
		return
	if _gestes_ui.proposition_active():
		_gestes_ui.effacer_proposition()
		_envoyer_intention("geste_accord")
		return
	if _gestes_ui.roue_ouverte():
		_gestes_ui.valider()
		return
	if not _peut_geste():
		return
	var c := _cible_geste()
	if c < 0:
		return
	_roue_cible = c
	_roue_tenue = true
	_gestes_ui.ouvrir(Langue.t("Avec %s") % Langue.t(_designer(c)))


func _roue_fermee() -> void:
	_roue_cible = -1
	_roue_tenue = false


## La roue lit la souris (ou le stick), les flèches, le clic, Échap. Rend vrai si elle a mangé l'événement.
func _entree_roue(ev: InputEvent) -> bool:
	if _gestes_ui == null or not _gestes_ui.roue_ouverte():
		return false
	if ev is InputEventMouseMotion:
		_gestes_ui.bouger((ev as InputEventMouseMotion).relative)
		return true
	if ev is InputEventMouseButton:
		if ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_gestes_ui.valider()
		return true
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_ESCAPE:
				_gestes_ui.annuler()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_gestes_ui.valider()
			KEY_RIGHT, KEY_DOWN:
				_gestes_ui.tourner(1)
			KEY_LEFT, KEY_UP:
				_gestes_ui.tourner(-1)
			_:
				if Options.touches("interagir").has(ev.keycode):
					return false     # la touche elle-même (action) : traitée plus loin
		return true
	return false


func _suivre_gestes(delta: float) -> void:
	if _gestes_ui == null:
		return
	if _gestes_ui.roue_ouverte():
		# On a changé d'avis ailleurs (mort, phase, plus personne en face) : on ferme.
		if not _peut_geste() or _roue_cible < 0 or not _est_vivant(_roue_cible):
			_gestes_ui.annuler()
		# Tenir la touche puis la relâcher sur un secteur le valide ; relâchée sans rien, la roue reste (clic).
		elif _roue_tenue and not Options.appuye("interagir") and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_roue_tenue = false
			if _gestes_ui.age_roue() > 0.3:
				_gestes_ui.valider()
	if _chuchote_t > 0.0:
		_chuchote_t -= delta
		if _chuchote_t <= 0.0:
			_ma_portee = _portee_avant
			_icone_voix.text = VOYANT_PORTEE[_ma_portee]
			if Reseau.en_ligne:
				_envoyer_intention("portee", _ma_portee)


func _geste_choisi(type: String) -> void:
	var cible := _roue_cible
	_roue_fermee()
	if not _peut_geste():
		return
	if type == "chut":
		moi.jouer_emote("chut")
		if Reseau.en_ligne and _connecte():
			_emote_rpc.rpc("chut")
		return
	if cible < 0 or not _est_vivant(cible):
		return
	_envoyer_intention("geste", type, cible)


## L'hôte a décidé : ce que je dois voir, entendre ou subir.
func _sur_geste(de: int, cible: int, type: String, extra: Dictionary) -> void:
	var moi_id := _moi_id()
	match type:
		"refus":
			ecran.message(str(extra.get("texte", "")), 2.0)
		"envoye":
			ecran.message(Langue.t("Tu proposes : %s") % Langue.t(Gestes.nom(str(extra.get("type", "")))).to_lower(), 2.5)
		"propose":
			var t := str(extra.get("type", ""))
			var verbe: String = {"main": "une poignée de main", "chuchoter": "de chuchoter à ton oreille", "accolade": "une accolade"}.get(t, Langue.t(Gestes.nom(t)).to_lower())
			_gestes_ui.proposer(Langue.t("%s te propose %s : clic gauche pour accepter") % [Langue.t(_designer(de)), Langue.t(verbe)], Gestes.DELAI_ACCORD)
		"yeux":
			var b := _bouille_de(de)
			if b:
				b.fermer_les_yeux(float(extra.get("duree", Gestes.DUREE_YEUX)))
			_jouer3d("choc", extra.get("pos", Vector3.ZERO), -4.0, false)
			if de == moi_id:
				_gestes_ui.etourdir()
		_:
			_geste_joue(de, cible, type, extra)


func _bouille_de(id: int) -> Bouille:
	if id == _moi_id():
		return moi
	return bouilles.get(id) as Bouille


func _geste_joue(de: int, cible: int, type: String, extra: Dictionary) -> void:
	var emote: String = Gestes.EMOTE_DE.get(type, "")
	var b_de := _bouille_de(de)
	var b_ci := _bouille_de(cible)
	var moi_id := _moi_id()
	if emote != "":
		if b_de:
			b_de.jouer_emote(emote, b_ci if Emotes.pointe(emote) else null)
		# Les gestes à deux se jouent des deux côtés ; les autres, par celui qui les fait.
		if b_ci and type in ["main", "accolade", "check"]:
			b_ci.jouer_emote(emote)
	match type:
		"chuchoter":
			if de == moi_id:
				_chuchoter_pendant(Emotes.duree("chuchoter"))
		"pointer":
			if cible == moi_id:
				ecran.message("%s te montre du doigt." % _designer(de), 3.0)
		"epaule":
			if cible == moi_id:
				var c := Gestes.cote(extra.get("pos", corps_joueur.global_position), corps_joueur.global_position, corps_joueur.rotation.y)
				_gestes_ui.marquer(c)
		"pousser":
			# Tout le monde voit celui qu'on pousse partir en arrière, et l'entend racler le sol.
			if b_ci:
				b_ci.jouer_emote("bouscule")
				_jouer3d("choc", b_ci.global_position, -14.0, false)
			if cible == moi_id:
				_subir_poussee(extra.get("dir", Vector3.ZERO))
				_gestes_ui.bousculer()
			if de == moi_id:
				# Mes propres bras poussent déjà, vus de mes yeux : pas de seconde paire (Edwin, 31/10).
				_gestes_ui.elancer()


func _chuchoter_pendant(secondes: float) -> void:
	if _chuchote_t <= 0.0:
		_portee_avant = _ma_portee
	_chuchote_t = secondes
	_ma_portee = 0
	_icone_voix.text = VOYANT_PORTEE[0]
	if Reseau.en_ligne:
		_envoyer_intention("portee", 0)


## Essai (--essai-pousser=<dossier>) : au tableau, je pousse un villageois puis il me pousse ;
## photos de ma vue à chaque fois (pour regarder, pas un test).
var _essai_pousser := ""


func _essai_pousser_lancer() -> void:
	if _essai_pousser == "":
		_essai_pousser = "-"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--essai-pousser="):
				_essai_pousser = a.substr(16)
	if _essai_pousser == "-" or etape != "jeu" or _phase() != "tableau" or mode != "libre":
		return
	var dossier := _essai_pousser
	_essai_pousser = "-"
	var autre := -1
	for id in bouilles:
		if id != _moi_id():
			autre = id
			break
	if autre < 0:
		return
	var b: Bouille = bouilles[autre]
	var ici := corps_joueur.global_position
	b.global_position = ici + (-corps_joueur.global_transform.basis.z).normalized() * 1.2
	await get_tree().create_timer(0.3).timeout
	var photo := func(n: String):
		get_viewport().get_texture().get_image().save_png("%s/pousser_%s.png" % [dossier, n])
	_geste_joue(_moi_id(), autre, "pousser", {})
	await get_tree().create_timer(0.14).timeout
	photo.call("1_je_pousse")
	await get_tree().create_timer(1.5).timeout
	_geste_joue(autre, _moi_id(), "pousser", {"dir": corps_joueur.global_transform.basis.z})
	await get_tree().create_timer(0.12).timeout
	photo.call("2_on_me_pousse")
	await get_tree().create_timer(1.2).timeout
	photo.call("3_apres")
	print("[pousser] fini, recul : %.2f m" % corps_joueur.global_position.distance_to(ici))


func _subir_poussee(dir: Vector3) -> void:
	if mode not in ["libre", "chambre", "poste"] or _assis_libre:
		return
	dir.y = 0
	if dir.length() < 0.01:
		return
	_pousse_v = dir.normalized() * Gestes.VITESSE_POUSSEE


## Après le déplacement : la poussée s'éteint (1 m en tout) ; si elle a cogné un mur, l'hôte le saura.
func _fin_de_poussee(delta: float) -> void:
	if _pousse_v == Vector3.ZERO:
		return
	if Gestes.choc_mur(corps_joueur, _pousse_v):
		_pousse_v = Vector3.ZERO
		_envoyer_intention("choc")
		return
	_pousse_v *= exp(-Gestes.FRAIN_POUSSEE * delta)
	if _pousse_v.length() < 0.3:
		_pousse_v = Vector3.ZERO
