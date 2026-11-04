class_name Cosmetiques
extends RefCounted
## La roulotte du colporteur (Edwin, 30/10) : tout ce qui se vend en euros, sans rien d'affiché.
##
## Règle d'or du jeu : on y lit les visages pour démasquer les loups. Aucun article ne couvre les
## yeux ni la bouche, aucun ne se voit plus la nuit qu'un autre, aucun ne dit quoi que ce soit du
## rôle. Payer n'achète que de l'allure.
##
## Sept emplacements se voient des autres joueurs : ils voyagent dans les bits hauts de l'apparence
## (36 à 63, 4 bits chacun, cf. Bouille.coder). Les objets en main étendent le champ « objet » de
## l'apparence ; le dos de carte et les émotes restent sur ce PC.

const EMPLACEMENTS := ["tenue", "mort", "familier", "fantome", "trace", "maison", "tombe"]
const DECALAGE := 36
## Ce qui n'est pas un cosmétique : la liste publique des lobbies passe par du JSON (53 bits sûrs).
const MASQUE_BASE := (1 << DECALAGE) - 1

## id, nom de la malle, une ligne du colporteur
const FAMILLES := [
	["tenue", "Tenues", "Des habits cousus pour le deuil, la fête ou la fosse."],
	["mort", "Morts", "On ne meurt qu'une fois. Autant que ça se voie."],
	["familier", "Familiers", "Ils te suivront partout. Même là-bas."],
	["maison", "Maisons", "Ta porte, ta lueur, ce que les voisins voient en passant."],
	["fantome", "Fantômes", "Pour hanter le village avec un peu de tenue."],
	["trace", "Traces", "Ce que tes pas laissent derrière toi."],
	["objet", "Objets", "De quoi occuper la main qui ne tient pas la lanterne."],
	["tombe", "Tombes", "La dernière chose qu'on dira de toi."],
	["carte", "Cartes", "Le dos de la carte qu'on te tend à la nuit tombée."],
	["emote", "Gestes", "Des gestes qu'on n'apprend pas au village."],
	["pack", "Packs", "Le meilleur de la roulotte, à meilleur prix."],
]

## Les valeurs 1 à 15 de chaque emplacement (0 = rien). L'ordre ne change JAMAIS : il est porté
## par le réseau et par les réglages enregistrés.
const TENUES := ["", "fossoyeur", "veuve", "peste", "inquisiteur", "saltimbanque", "pelerin"]
const MORTS := ["", "corbeaux", "cendres", "ombre", "statue"]
const FAMILIERS := ["", "corbeau", "chat", "chouette", "rat"]
const FANTOMES := ["", "lambeaux", "feu_follet", "brume", "flammes_bleues"]
const TRACES := ["", "brume", "feuilles", "lucioles", "cendres"]
const MAISONS := ["", "lierre", "lueur_bleue", "enseigne", "deuil"]
const TOMBES := ["", "gravee", "croix_fer", "mausolee"]
const VALEURS := {"tenue": TENUES, "mort": MORTS, "familier": FAMILIERS, "fantome": FANTOMES,
	"trace": TRACES, "maison": MAISONS, "tombe": TOMBES}
## Les objets payants prolongent Bouille.OBJETS (les huit premiers restent gratuits).
const OBJETS_PAYANTS := ["lanterne_bleue", "crane_lanterne", "cloche_sonneur", "grimoire", "lanterne_fondateur", "crane_fondateur", "grimoire_fondateur"]
const CARTES := ["", "gravure", "vitrail", "sang"]
const EMOTES_PAYANTES := ["reverence", "rire_dement", "signe_croix", "hurlement"]

## Le catalogue. prix en centimes ; « steam » = numéro du DLC une fois créé sur Steamworks (0 tant
## qu'il n'existe pas). « seul » = article exclusif qu'on ne trouve que dans un pack Fondateur.
## « niveau » = article GRATUIT, débloqué en montant de niveau (cf. regles/progression.gd).
const ARTICLES := [
	# --- Tenues
	{"id": "tenue_fossoyeur", "famille": "tenue", "valeur": "fossoyeur", "nom": "Le Fossoyeur", "prix": 499, "rarete": "rare",
		"texte": "Chapeau troué, gilet de cuir, pelle rouillée à l'épaule. Il connaît chacun d'entre vous par sa taille."},
	{"id": "tenue_veuve", "famille": "tenue", "valeur": "veuve", "nom": "La Veuve", "prix": 599, "rarete": "epique",
		"texte": "Voile de dentelle noire relevé sur le front, robe de deuil. Elle a déjà enterré un mari. Peut-être deux."},
	{"id": "tenue_peste", "famille": "tenue", "valeur": "peste", "nom": "Le Médecin de peste", "prix": 599, "rarete": "epique",
		"texte": "Le bec de cuir est posé sur le front, pas sur le visage : on doit pouvoir te regarder dans les yeux."},
	{"id": "tenue_inquisiteur", "famille": "tenue", "valeur": "inquisiteur", "nom": "L'Inquisiteur", "prix": 599, "rarete": "epique",
		"texte": "Chapeau large, col blanc empesé, croix d'argent. Il pose les questions. Il n'aime pas les réponses."},
	{"id": "tenue_saltimbanque", "famille": "tenue", "valeur": "saltimbanque", "nom": "Le Saltimbanque", "prix": 499, "rarete": "rare",
		"texte": "Bonnet à grelots, losanges délavés. Il fait rire le village. Personne ne sait d'où vient la troupe."},
	{"id": "tenue_pelerin", "famille": "tenue", "valeur": "pelerin", "nom": "Le Pèlerin", "prix": 399, "rarete": "rare",
		"texte": "Grand manteau de bure, coquille cousue, bâton noueux. Il ne fait que passer. Il dit ça depuis trois hivers."},
	# --- Morts
	{"id": "mort_corbeaux", "famille": "mort", "valeur": "corbeaux", "nom": "Nuée de corbeaux", "prix": 299, "rarete": "epique",
		"texte": "Le corps s'effondre et s'envole en cent corbeaux qui tournent au-dessus de la place."},
	{"id": "mort_cendres", "famille": "mort", "valeur": "cendres", "nom": "Cendres rougeoyantes", "prix": 249, "rarete": "rare",
		"texte": "La peau se craquelle de braise et le vent emporte le reste."},
	{"id": "mort_ombre", "famille": "mort", "valeur": "ombre", "nom": "Avalé par l'ombre", "prix": 249, "rarete": "rare",
		"texte": "Une flaque noire s'ouvre sous les pieds. Elle ne rend jamais rien."},
	{"id": "mort_statue", "famille": "mort", "valeur": "statue", "nom": "Statue de pierre", "prix": 0, "niveau": 26, "rarete": "commun",
		"texte": "Figé en pierre grise, puis fissuré de part en part. Les enfants n'osent plus passer devant."},
	# --- Familiers
	{"id": "familier_corbeau", "famille": "familier", "valeur": "corbeau", "nom": "Le Corbeau", "prix": 249, "rarete": "rare",
		"texte": "Perché sur ton épaule. Il s'envole quand tu cours et revient toujours."},
	{"id": "familier_chat", "famille": "familier", "valeur": "chat", "nom": "Le Chat noir", "prix": 249, "rarete": "rare",
		"texte": "Il marche dans tes pas et s'assoit quand tu t'arrêtes. Il porte malheur, mais pas à toi."},
	{"id": "familier_chouette", "famille": "familier", "valeur": "chouette", "nom": "La Chouette", "prix": 299, "rarete": "epique",
		"texte": "Elle vole en cercle au-dessus de toi et tourne la tête vers ceux qui te regardent."},
	{"id": "familier_rat", "famille": "familier", "valeur": "rat", "nom": "Le Rat", "prix": 0, "niveau": 14, "rarete": "commun",
		"texte": "Il trottine derrière toi. Personne ne l'a invité. Il est là quand même."},
	# --- Maisons
	{"id": "maison_lierre", "famille": "maison", "valeur": "lierre", "nom": "Lierre et citrouilles", "prix": 199, "rarete": "commun",
		"texte": "Le lierre mange la façade, deux citrouilles creusées veillent sur le seuil."},
	{"id": "maison_lueur_bleue", "famille": "maison", "valeur": "lueur_bleue", "nom": "Lueur des noyés", "prix": 249, "rarete": "rare",
		"texte": "Tes fenêtres brillent d'un bleu froid, comme une lampe qu'on aurait remontée du lac."},
	{"id": "maison_enseigne", "famille": "maison", "valeur": "enseigne", "nom": "Enseigne et porte sculptée", "prix": 299, "rarete": "epique",
		"texte": "Une enseigne de fer forgé grince au-dessus d'une porte sculptée de têtes de loup."},
	{"id": "maison_deuil", "famille": "maison", "valeur": "deuil", "nom": "Couronne de deuil", "prix": 0, "niveau": 8, "rarete": "commun",
		"texte": "Une couronne de fleurs noires sur la porte, des rubans qui pendent. Chez toi, on se souvient."},
	# --- Fantômes
	{"id": "fantome_lambeaux", "famille": "fantome", "valeur": "lambeaux", "nom": "Spectre en lambeaux", "prix": 199, "rarete": "rare",
		"texte": "Un suaire déchiré qui flotte derrière toi, même sans vent."},
	{"id": "fantome_feu_follet", "famille": "fantome", "valeur": "feu_follet", "nom": "Feu follet", "prix": 199, "rarete": "rare",
		"texte": "Une petite flamme verte danse au-dessus de ton épaule et éclaire le chemin des morts."},
	{"id": "fantome_brume", "famille": "fantome", "valeur": "brume", "nom": "Silhouette de brume", "prix": 0, "niveau": 22, "rarete": "commun",
		"texte": "Tu te défais en fumée blanche à chaque pas."},
	{"id": "fantome_flammes_bleues", "famille": "fantome", "valeur": "flammes_bleues", "nom": "Flammes bleues", "prix": 249, "rarete": "epique",
		"texte": "Tes mains et ta tête brûlent d'un feu bleu qui ne chauffe pas."},
	# --- Traces
	{"id": "trace_brume", "famille": "trace", "valeur": "brume", "nom": "Brume au sol", "prix": 0, "niveau": 18, "rarete": "commun",
		"texte": "Une traîne de brouillard rampe derrière tes talons."},
	{"id": "trace_feuilles", "famille": "trace", "valeur": "feuilles", "nom": "Feuilles mortes", "prix": 0, "niveau": 6, "rarete": "commun",
		"texte": "Les feuilles se soulèvent et tourbillonnent à ton passage."},
	{"id": "trace_lucioles", "famille": "trace", "valeur": "lucioles", "nom": "Lucioles", "prix": 199, "rarete": "rare",
		"texte": "Quelques lucioles te suivent et s'éparpillent quand tu t'arrêtes."},
	{"id": "trace_cendres", "famille": "trace", "valeur": "cendres", "nom": "Empreintes de cendre", "prix": 199, "rarete": "rare",
		"texte": "Chaque pas laisse une empreinte grise et fumante qui s'efface lentement."},
	# --- Objets en main
	{"id": "objet_lanterne_bleue", "famille": "objet", "valeur": "lanterne_bleue", "nom": "Lanterne à flamme bleue", "prix": 99, "rarete": "commun",
		"texte": "Une lanterne de fer dont la flamme bleue ne vacille jamais."},
	{"id": "objet_crane_lanterne", "famille": "objet", "valeur": "crane_lanterne", "nom": "Crâne-lanterne", "prix": 149, "rarete": "rare",
		"texte": "Un vieux crâne, une bougie dedans. La lumière passe par les orbites."},
	{"id": "objet_cloche_sonneur", "famille": "objet", "valeur": "cloche_sonneur", "nom": "Cloche du sonneur", "prix": 0, "niveau": 10, "rarete": "commun",
		"texte": "La grosse cloche de bronze du sonneur de glas, sur son manche."},
	{"id": "objet_grimoire", "famille": "objet", "valeur": "grimoire", "nom": "Grimoire", "prix": 149, "rarete": "rare",
		"texte": "Un livre relié de cuir sombre, fermé par une sangle. Ne l'ouvre pas devant tout le monde."},
	{"id": "objet_lanterne_fondateur", "famille": "objet", "valeur": "lanterne_fondateur", "nom": "Lanterne du Fondateur", "prix": 0, "rarete": "legende", "seul": true,
		"texte": "Laiton doré, flamme blanche éternelle. Seuls les premiers villageois l'ont reçue."},
	{"id": "objet_crane_fondateur", "famille": "objet", "valeur": "crane_fondateur", "nom": "Crâne doré du Fondateur", "prix": 0, "rarete": "legende", "seul": true,
		"texte": "Un crâne couvert de feuilles d'or, une flamme blanche dans les orbites. Réservé au Fondateur II."},
	{"id": "objet_grimoire_fondateur", "famille": "objet", "valeur": "grimoire_fondateur", "nom": "Grimoire d'or du Fondateur", "prix": 0, "rarete": "legende", "seul": true,
		"texte": "Reliure noire, fermoirs d'or, un œil blanc qui ne cligne pas. Réservé au Fondateur III."},
	# --- Tombes
	{"id": "tombe_gravee", "famille": "tombe", "valeur": "gravee", "nom": "Pierre gravée", "prix": 0, "niveau": 4, "rarete": "commun",
		"texte": "Une stèle sculptée de lierre, ton nom en lettres profondes."},
	{"id": "tombe_croix_fer", "famille": "tombe", "valeur": "croix_fer", "nom": "Croix de fer", "prix": 99, "rarete": "commun",
		"texte": "Une croix forgée, tordue par les hivers, et une lanterne qui ne s'éteint pas."},
	{"id": "tombe_mausolee", "famille": "tombe", "valeur": "mausolee", "nom": "Mausolée", "prix": 199, "rarete": "epique",
		"texte": "Un petit mausolée de pierre, deux colonnes, une grille. On t'aimait beaucoup. Ou on avait peur."},
	# --- Dos de carte (seulement sur ton écran)
	{"id": "carte_gravure", "famille": "carte", "valeur": "gravure", "nom": "Gravure ancienne", "prix": 0, "niveau": 2, "rarete": "commun",
		"texte": "Un loup gravé à l'eau-forte, cerné d'entrelacs."},
	{"id": "carte_vitrail", "famille": "carte", "valeur": "vitrail", "nom": "Vitrail", "prix": 99, "rarete": "rare",
		"texte": "Le village en vitrail, la lune au centre, le plomb qui brille."},
	{"id": "carte_sang", "famille": "carte", "valeur": "sang", "nom": "Sang séché", "prix": 99, "rarete": "rare",
		"texte": "Un parchemin taché, une empreinte de patte au milieu."},
	# --- Gestes
	{"id": "emote_reverence", "famille": "emote", "valeur": "reverence", "nom": "Révérence", "prix": 99, "rarete": "commun",
		"texte": "Une révérence de cour, le bras replié sur la poitrine."},
	{"id": "emote_rire_dement", "famille": "emote", "valeur": "rire_dement", "nom": "Rire dément", "prix": 99, "rarete": "rare",
		"texte": "Plié en deux, les épaules qui sautent. Pas drôle du tout."},
	{"id": "emote_signe_croix", "famille": "emote", "valeur": "signe_croix", "nom": "Signe de croix", "prix": 0, "niveau": 30, "rarete": "commun",
		"texte": "Front, poitrine, épaule, épaule. Ça ne coûte rien d'essayer."},
	{"id": "emote_hurlement", "famille": "emote", "valeur": "hurlement", "nom": "Hurlement", "prix": 149, "rarete": "epique",
		"texte": "La tête renversée vers la lune. Les villageois n'aiment pas ça du tout."},
	# --- Packs (chacun = un DLC Steam ; « steam » = son numéro une fois créé, 0 d'ici là)
	{"id": "pack_tout", "famille": "pack", "nom": "Tout le colporteur", "prix": 2000, "rarete": "legende", "tout": true, "steam": 0,
		"texte": "Tous les cosmétiques payants de la roulotte, y compris ceux qui arriveront plus tard. Hors articles exclusifs des packs Fondateur."},
	{"id": "pack_fondateur_1", "famille": "pack", "nom": "Fondateur I : le Deuil", "prix": 1000, "rarete": "legende", "steam": 0,
		"contient": ["objet_lanterne_fondateur", "tenue_veuve", "mort_corbeaux", "familier_corbeau", "maison_enseigne", "tombe_croix_fer"],
		"texte": "La Veuve et son Corbeau, la Nuée, l'enseigne aux têtes de loup, et la Lanterne du Fondateur qu'on ne trouve nulle part ailleurs."},
	{"id": "pack_fondateur_2", "famille": "pack", "nom": "Fondateur II : l'Au-delà", "prix": 1000, "rarete": "legende", "steam": 0,
		"contient": ["objet_crane_fondateur", "tenue_peste", "fantome_flammes_bleues", "fantome_lambeaux", "trace_lucioles", "maison_lueur_bleue", "carte_vitrail"],
		"texte": "Pour ceux qui jouent mieux morts que vivants : flammes bleues, lucioles, et le Crâne doré du Fondateur."},
	{"id": "pack_fondateur_3", "famille": "pack", "nom": "Fondateur III : le Fossoyeur", "prix": 1000, "rarete": "legende", "steam": 0,
		"contient": ["objet_grimoire_fondateur", "tenue_fossoyeur", "tenue_inquisiteur", "mort_ombre", "mort_cendres", "tombe_mausolee", "trace_cendres", "emote_hurlement"],
		"texte": "Celui qui creuse, celui qui interroge, l'ombre, les cendres, le mausolée, et le Grimoire d'or du Fondateur."},
]

const NOMS_RARETES := {"commun": "Commun", "rare": "Rare", "epique": "Épique", "legende": "Légende"}
const COULEURS_RARETES := {"commun": Color(0.72, 0.68, 0.6), "rare": Color(0.35, 0.6, 0.95),
	"epique": Color(0.72, 0.38, 0.95), "legende": Color(0.98, 0.72, 0.22)}


static func article(id: String) -> Dictionary:
	for a: Dictionary in ARTICLES:
		if a["id"] == id:
			return a
	return {}


static func de_la_famille(famille: String) -> Array:
	return ARTICLES.filter(func(a: Dictionary) -> bool: return a["famille"] == famille)


static func nom_famille(famille: String) -> String:
	for f: Array in FAMILLES:
		if f[0] == famille:
			return f[1]
	return famille


static func prix_texte(centimes: int) -> String:
	return "%d,%02d €" % [centimes / 100, centimes % 100]


## Le prix tel qu'on l'écrit dans la langue du jeu : « 5,99 € » en français, « €5.99 » en anglais.
static func prix_affiche(centimes: int) -> String:
	if Langue.code() == "en":
		return "€%d.%02d" % [centimes / 100, centimes % 100]
	return prix_texte(centimes)


## Un article qui s'achète à l'unité (ni pack, ni exclusif Fondateur, ni gratuit par niveau).
static func est_payant(a: Dictionary) -> bool:
	return a.get("famille", "") != "pack" and not a.get("seul", false) and int(a.get("niveau", 0)) == 0 and int(a.get("prix", 0)) > 0


## Les articles d'un pack. « Tout le colporteur » : tous les articles payants, ceux d'aujourd'hui
## comme ceux qu'on ajoutera ; les exclusifs Fondateur n'en font PAS partie (ils sont aux packs
## Fondateur seulement), ni les articles gratuits par niveau.
static func contenu(pack_id: String) -> Array:
	var p := article(pack_id)
	if p.get("tout", false):
		return ARTICLES.filter(func(a: Dictionary) -> bool: return est_payant(a)).map(func(a: Dictionary) -> String: return a["id"])
	return p.get("contient", [])


## Les packs qui contiennent cet article.
static func packs_de(id: String) -> Array:
	return de_la_famille("pack").filter(func(p: Dictionary) -> bool: return id in contenu(p["id"])).map(func(p: Dictionary) -> String: return p["id"])


## Le niveau de villageois qui offre cet article (0 : il ne s'offre pas).
static func niveau_requis(id: String) -> int:
	return int(article(id).get("niveau", 0))


## Ce qu'il en coûterait au détail : un pack doit toujours valoir moins que ses pièces.
static func valeur_detail(id: String) -> int:
	var a := article(id)
	if a.get("famille", "") != "pack":
		return int(a.get("prix", 0))
	var s := 0
	for x: String in contenu(id):
		s += int(article(x).get("prix", 0))
	return s


## Le numéro (1-15) d'une valeur dans son emplacement, -1 si inconnue.
static func indice(emplacement: String, valeur: String) -> int:
	if emplacement == "objet":
		var i := OBJETS_PAYANTS.find(valeur)
		return -1 if i < 0 else Bouille.NB_OBJETS_GRATUITS + i
	if emplacement == "carte":
		return CARTES.find(valeur)
	var l: Array = VALEURS.get(emplacement, [])
	var i := l.find(valeur)
	return i if i > 0 else -1


## Lit (en clair) les sept emplacements portés par une apparence.
static func lire(apparence: int) -> Dictionary:
	var d := {}
	for i in EMPLACEMENTS.size():
		var l: Array = VALEURS[EMPLACEMENTS[i]]
		var v := (apparence >> (DECALAGE + 4 * i)) & 15
		d[EMPLACEMENTS[i]] = l[v] if v < l.size() else ""
	return d


## Pose (ou retire, avec "") une valeur dans l'apparence.
static func poser(apparence: int, emplacement: String, valeur: String) -> int:
	var i := EMPLACEMENTS.find(emplacement)
	if i < 0:
		return apparence
	var v := 0 if valeur == "" else maxi(indice(emplacement, valeur), 0)
	var dec := DECALAGE + 4 * i
	return (apparence & ~(15 << dec)) | (v << dec)


## L'apparence sans aucun cosmétique (liste publique, et les vérifications).
static func sans(apparence: int) -> int:
	return apparence & MASQUE_BASE


## Les villageois joués par l'ordinateur portent parfois de quoi donner envie (un sur trois par pièce).
static func pour_bot(apparence: int, rng: RandomNumberGenerator) -> int:
	for e: String in EMPLACEMENTS:
		var l: Array = VALEURS[e]
		if rng.randf() < 0.3:
			apparence = poser(apparence, e, l[rng.randi_range(1, l.size() - 1)])
	return apparence
