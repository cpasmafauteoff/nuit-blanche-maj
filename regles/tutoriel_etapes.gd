class_name TutoEtapes
extends RefCounted
## La nuit guidée du premier lancement (décision d'Edwin, 31/10) : le déroulé de ses étapes et les
## conditions « étape réussie », sans rien d'affiché ni de lancé (cf. tutoriel.gd, qui joue le
## scénario dans le vrai village). Tout ici se teste sans fenêtre.
##
## Chaque étape : id, chap (le chapitre), texte (la voix-texte du narrateur ; les touches s'écrivent
## {action} et deviennent celles que CE joueur a réglées, cf. Options.avec_touches), auto (secondes
## de lecture au bout desquelles l'étape se termine seule ; 0 = elle attend que le joueur agisse),
## max (secondes au plus, pour qu'une étape ne bloque jamais : 0 = pas de plafond).

const CHAPITRES := ["Marcher", "Le Conseil", "La quête", "Le carnet", "Le vote", "La nuit", "La fin"]

const ETAPES := [
	{"id": "bouger", "chap": 0, "auto": 0.0, "max": 0.0,
		"texte": "Bienvenue à la Ronde. Avance avec {avancer} {gauche} {reculer} {droite} : le village est à toi."},
	{"id": "regarder", "chap": 0, "auto": 0.0, "max": 0.0,
		"texte": "Regarde autour de toi avec la souris. Ici personne n'a de nom : seulement un bandeau de couleur."},
	{"id": "courir", "chap": 0, "auto": 0.0, "max": 0.0,
		"texte": "Maintiens {sprint} en avançant pour courir. Le petit trait en bas est ton souffle : il se vide, et quelqu'un d'essoufflé s'entend de loin."},
	{"id": "accroupir", "chap": 0, "auto": 0.0, "max": 0.0,
		"texte": "Maintiens {accroupir} pour t'accroupir. On avance lentement, mais presque sans bruit."},
	{"id": "souche", "chap": 1, "auto": 0.0, "max": 0.0,
		"texte": "Rejoins ta souche, là où brille la lueur, et assieds-toi avec {agir}. C'est ta place au Conseil."},
	{"id": "portee", "chap": 1, "auto": 0.0, "max": 0.0,
		"texte": "Ici, tout se joue à l'oral. Ta voix porte plus ou moins loin : {portee} change entre chuchoter, parler et crier. Essaie."},
	{"id": "parler", "chap": 1, "auto": 0.0, "max": 25.0,
		"texte": "Maintenant, dis quelque chose à voix haute : bonjour, une accusation, ce que tu veux. (Pas de micro ? {passer} pour continuer.)"},
	{"id": "tableau", "chap": 2, "auto": 0.0, "max": 0.0,
		"texte": "Lève-toi et va au tableau des quêtes, là où brille la lueur. {agir} pour le lire."},
	{"id": "vote_quete", "chap": 2, "auto": 0.0, "max": 0.0,
		"texte": "Chaque matin, le village vote pour une quête avec les touches 1 à 4 (la 4 : rester au village). Pour apprendre, choisis la 1 : le Moulin, la plus simple."},
	{"id": "trajet", "chap": 2, "auto": 0.0, "max": 70.0,
		"texte": "Le village part en quête. Un sentier s'ouvre dans la lisière et on t'y conduit : regarde autour de toi, la forêt a ses habitants."},
	{"id": "quete", "chap": 2, "auto": 0.0, "max": 120.0,
		"texte": "Voici la clairière. Lis la consigne à l'écran, fais ta part et parle aux autres : une quête se réussit ensemble, et les loups y sabotent en douce."},
	{"id": "retour", "chap": 2, "auto": 0.0, "max": 60.0,
		"texte": "Quête terminée. Le sentier te ramène au village."},
	{"id": "carnet_prendre", "chap": 3, "auto": 0.0, "max": 0.0,
		"texte": "Chez toi, sur la table, un carnet t'attend : approche-toi de la lueur et prends-le avec {agir}."},
	{"id": "carnet_lire", "chap": 3, "auto": 0.0, "max": 0.0,
		"texte": "Ouvre-le avec {lire}. C'est ta mémoire : sans noms, on note qui a dit quoi."},
	{"id": "carnet_ecrire", "chap": 3, "auto": 0.0, "max": 0.0,
		"texte": "Écris-y une ligne : un soupçon, un bandeau. Les autres voient ta plume gratter. Puis referme-le avec Échap."},
	{"id": "pret", "chap": 3, "auto": 0.0, "max": 0.0,
		"texte": "Tout le monde est rentré. Appuie sur {pret} : quand tous sont prêts, le village se réunit."},
	{"id": "maire_intro", "chap": 4, "auto": 9.0, "max": 0.0,
		"texte": "Premier jour : le village se choisit un maire. Sa voix compte double et c'est lui qui tranche les égalités. Écoute, parle, convaincs."},
	{"id": "maire_vote", "chap": 4, "auto": 0.0, "max": 0.0,
		"texte": "Vise quelqu'un du regard et clique pour voter pour lui. Tu peux changer d'avis jusqu'au bout."},
	{"id": "maire_elu", "chap": 4, "auto": 7.0, "max": 0.0,
		"texte": "Voilà votre maire. Retiens-le : il peut sauver ou condamner d'un mot."},
	{"id": "conseil", "chap": 4, "auto": 10.0, "max": 0.0,
		"texte": "Le Conseil. Tout le monde s'assoit autour du feu et on débat à l'oral : qui est un loup ? Accuse, défends-toi, mens si tu veux."},
	{"id": "vote", "chap": 4, "auto": 0.0, "max": 0.0,
		"texte": "Le vote. Fixe quelqu'un du regard : au bout d'un instant, clique pour l'accuser. Ton vote reste secret."},
	{"id": "depouillement", "chap": 4, "auto": 8.0, "max": 0.0,
		"texte": "Les voix sont comptées et s'affichent au-dessus des têtes. Le plus accusé est attaché à la pierre pour la nuit."},
	{"id": "verdict", "chap": 4, "auto": 9.0, "max": 0.0,
		"texte": "Le Conseil a tranché. Les villageois emmènent le condamné à la pierre : cette nuit, les loups viendront."},
	{"id": "rentrer", "chap": 5, "auto": 0.0, "max": 40.0,
		"texte": "La nuit tombe. Chacun rentre chez soi, toi aussi : rejoins ta maison."},
	{"id": "yeux", "chap": 5, "auto": 0.0, "max": 40.0,
		"texte": "Le meneur dit : fermez les yeux. Ferme-les pour de vrai devant ta webcam, ou maintiens {sauter} si tu joues sans caméra. Certains rôles épient entre leurs cils."},
	{"id": "coucher", "chap": 5, "auto": 6.0, "max": 0.0,
		"texte": "Le village s'endort. Écoute la voix du meneur : dans le noir, c'est la seule chose qu'on entend."},
	{"id": "reveil", "chap": 5, "auto": 8.0, "max": 0.0,
		"texte": "Les loups se réveillent. Cette nuit, c'est toi, le loup. Les numéros des maisons sont rouges : ce sont tes proies."},
	{"id": "porte_arriere", "chap": 5, "auto": 0.0, "max": 90.0,
		"texte": "Va à ta porte, là où brille la lueur, et appuie sur {agir} : sortir sans bruit se mérite."},
	{"id": "coups", "chap": 5, "auto": 0.0, "max": 60.0,
		"texte": "Frappe ({agir}, ou clic) quand le curseur passe dans la zone claire. Trois coups réussis : aucun bruit. Raté, et tout le village entend ta porte."},
	{"id": "voter_porte", "chap": 5, "auto": 0.0, "max": 150.0,
		"texte": "Dehors, avance doucement. Va devant la porte d'une maison, là où brille la lueur, et clique pour la choisir. Les loups s'accordent ainsi."},
	{"id": "cine", "chap": 5, "auto": 0.0, "max": 40.0,
		"texte": "La porte s'ouvre. Regarde ce que fait la meute."},
	{"id": "fin", "chap": 6, "auto": 10.0, "max": 0.0,
		"texte": "Tu sais tout. Le reste se joue à l'oral : mens, accuse, trahis."},
]

## Les seuils des étapes de mouvement.
const MARCHE_M := 4.0           # mètres à pied
const TOURNE_RAD := 2.2         # radians cumulés de regard
const COURSE_S := 1.5           # secondes à courir
const ACCROUPI_S := 0.6         # secondes accroupi
const PARLE_S := 0.6            # secondes de voix captée
const YEUX_S := 1.0             # secondes les yeux fermés
const OUVERTURE_FERMES := 0.4   # sous cette ouverture (0 = fermés, 1 = grands ouverts), les yeux sont fermés
const COUPS := 3                # les trois coups de la porte

## Le suivi du joueur : ce que `cumuler` remplit au fil des images.
static func constat_vide() -> Dictionary:
	return {"marche": 0.0, "tourne": 0.0, "course": 0.0, "accroupi": 0.0, "parle": 0.0, "yeux": 0.0,
		"portee": 0, "assis": false, "t_etape": 0.0}


## Ajoute une image d'observation au constat. `obs` : {dist (m marchés depuis l'image précédente),
## dyaw (radians tournés), sprint (court), accroupi, parle (la voix est captée), ferme (les yeux sont fermés)}.
static func cumuler(c: Dictionary, delta: float, obs: Dictionary) -> void:
	c["marche"] = float(c["marche"]) + maxf(float(obs.get("dist", 0.0)), 0.0)
	c["tourne"] = float(c["tourne"]) + absf(float(obs.get("dyaw", 0.0)))
	c["t_etape"] = float(c["t_etape"]) + delta
	# Une durée se cumule tant que le geste dure ; elle repart de zéro quand on le lâche (sauf la voix,
	# qui s'additionne : on parle par bribes).
	c["course"] = float(c["course"]) + delta if bool(obs.get("sprint", false)) else 0.0
	c["accroupi"] = float(c["accroupi"]) + delta if bool(obs.get("accroupi", false)) else 0.0
	c["yeux"] = float(c["yeux"]) + delta if bool(obs.get("ferme", false)) else 0.0
	if bool(obs.get("parle", false)):
		c["parle"] = float(c["parle"]) + delta


## Nouvelle étape : les gestes à refaire repartent de zéro, ce que le joueur a déjà fait reste acquis.
static func nouvelle_etape(c: Dictionary) -> void:
	c["t_etape"] = 0.0
	c["marche"] = 0.0
	c["tourne"] = 0.0
	c["course"] = 0.0
	c["accroupi"] = 0.0
	c["parle"] = 0.0
	c["yeux"] = 0.0
	c["portee"] = 0


static func index(id: String) -> int:
	for i in ETAPES.size():
		if ETAPES[i]["id"] == id:
			return i
	return -1


static func etape(id: String) -> Dictionary:
	var i := index(id)
	return ETAPES[i] if i >= 0 else {}


## L'étape d'après, ou "" à la fin.
static func suivante(id: String) -> String:
	var i := index(id)
	return ETAPES[i + 1]["id"] if i >= 0 and i + 1 < ETAPES.size() else ""


static func premiere() -> String:
	return ETAPES[0]["id"]


## « Chapitre 2 sur 7 · Le Conseil ».
static func titre_chapitre(id: String) -> String:
	var e := etape(id)
	if e.is_empty():
		return ""
	return "Nuit guidée  ·  %d sur %d  ·  %s" % [int(e["chap"]) + 1, CHAPITRES.size(), CHAPITRES[int(e["chap"])]]


## L'étape est-elle réussie ? `c` : le constat du joueur (cumuler) plus ce que le jeu en dit :
## phase, quete (état de la quête du joueur : "" / "trajet" / "role" / "jeu" / "retour" / "finie"),
## carnet_main, carnet_ouvert, carnet_ecrit, pret, vote_cible (>= 0 : j'ai voté), dehors (hors de ma maison),
## sortie_ouverte, coups (les coups de la porte, réussis ou non), vote_loup, cine_vue, cine_finie, rentre.
static func remplie(id: String, c: Dictionary) -> bool:
	var e := etape(id)
	if e.is_empty():
		return false
	var auto := float(e["auto"])
	if auto > 0.0 and float(c.get("t_etape", 0.0)) >= auto:
		return true
	var plafond := float(e["max"])
	if plafond > 0.0 and float(c.get("t_etape", 0.0)) >= plafond:
		return true
	var phase := str(c.get("phase", ""))
	match id:
		"bouger":
			return float(c.get("marche", 0.0)) >= MARCHE_M
		"regarder":
			return float(c.get("tourne", 0.0)) >= TOURNE_RAD
		"courir":
			return float(c.get("course", 0.0)) >= COURSE_S
		"accroupir":
			return float(c.get("accroupi", 0.0)) >= ACCROUPI_S
		"souche":
			return bool(c.get("assis", false))
		"portee":
			return int(c.get("portee", 0)) >= 1
		"parler":
			return float(c.get("parle", 0.0)) >= PARLE_S
		"tableau":
			return bool(c.get("tableau_lu", false))
		"vote_quete":
			return bool(c.get("vote_quete", false))
		"trajet":
			return str(c.get("quete", "")) in ["jeu", "retour", "finie"] or phase == "pret"
		"quete":
			return str(c.get("quete", "")) in ["retour", "finie"] or phase == "pret"
		"retour":
			return phase == "pret"
		"carnet_prendre":
			return bool(c.get("carnet_main", false))
		"carnet_lire":
			return bool(c.get("carnet_ouvert", false))
		"carnet_ecrire":
			return bool(c.get("carnet_ecrit", false)) and not bool(c.get("carnet_ouvert", false))
		"pret":
			return bool(c.get("pret", false))
		"maire_vote":
			return phase == "vote_maire" and int(c.get("vote_cible", -1)) >= 0
		"vote":
			return phase == "vote" and int(c.get("vote_cible", -1)) >= 0
		"rentrer":
			return phase in ["distribution", "nuit"] and bool(c.get("rentre", false))
		"yeux":
			return float(c.get("yeux", 0.0)) >= YEUX_S
		"porte_arriere":
			return bool(c.get("sortie_ouverte", false)) or bool(c.get("dehors", false))
		"coups":
			return int(c.get("coups", 0)) >= COUPS or bool(c.get("dehors", false))
		"voter_porte":
			return bool(c.get("vote_loup", false))
		"cine":
			return bool(c.get("cine_finie", false))
	return false


## Les touches citées dans un texte : {avancer}, {agir}… (pour vérifier qu'elles existent toutes).
static func touches_citees(texte: String) -> Array:
	var re := RegEx.create_from_string("\\{(\\w+)\\}")
	var l: Array = []
	for m in re.search_all(texte):
		l.append(m.get_string(1))
	return l


# ---------------------------------------------------------------- la mémoire (réglages)

## À proposer d'office ? Seulement au tout premier lancement : l'état n'a jamais été écrit.
static func a_proposer(etat: String) -> bool:
	return etat == ""


## Ce qu'on enregistre quand le joueur répond à la proposition, ou quand la nuit guidée s'achève.
## Un « fait » ne redescend jamais : rejouer la nuit guidée n'efface pas qu'on l'a terminée.
static func etat_apres(avant: String, evenement: String) -> String:
	match evenement:
		"commence":
			return avant if avant != "" else "commence"
		"refuse":
			return avant if avant != "" else "refuse"
		"fait":
			return "fait"
	return avant
