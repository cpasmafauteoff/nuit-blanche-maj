class_name Visibilite
extends RefCounted
## Chaque joueur ne reçoit que ce qu'il doit voir ou savoir (décision d'Edwin, 31/10) : l'hôte filtre PAR
## DESTINATAIRE tout ce qui part vers les clients, pour qu'un client qui lirait sa mémoire (ou ses
## paquets) n'y trouve rien de plus que son joueur. L'hôte, lui, sait tout. Règles pures, sans nœud
## (tests/test_visibilite.gd).
##
## Une « fiche » décrit un joueur à cet instant : {id, hote, vivant, loup, role, dehors, maison}.
##   - `dehors` : il se tient hors de toute maison ;
##   - `maison` : la sienne.
## Ce que les mécaniques autorisent, et que ces règles préservent :
##   - le soir et le jour, tout le monde se voit et s'entend (les morts n'entendent ni ne se font voir
##     des vivants, sauf du Médium) ;
##   - la nuit, enfermé chez soi, un vivant ne voit personne : seuls les loups se voient entre eux, la
##     Guetteuse voit ce qui est dehors, les morts (et l'hôte) voient tout ;
##   - la nuit, les loups parlent entre eux à l'appel des loups ; un villageois ne les surprend que de
##     près (l'oreille collée au mur).

## Les phases où tout le monde s'entend (cf. principal.PHASES_TOUS_ENTENDUS).
const PHASES_TOUS_ENTENDUS := ["salon", "fin", "annonce", "conseil", "vote", "depouillement", "tranche", "verdict",
	"election", "vote_maire", "elu", "trappeur", "successeur"]
const APPELS_DES_LOUPS := ["loups", "solitaire"]
## Les trois façons de parler : chuchoter, parler, crier (mètres), et la portée au Conseil (cf. principal).
const PORTEES_VOIX := [2.0, 8.0, 15.0]
const PORTEE_CONSEIL := 60.0
## Les positions que connaît l'hôte retardent un peu : on lui laisse cette marge.
const MARGE_VOIX := 3.0
## Le rôle qui voit les morts.
const ROLE_MEDIUM := "medium"


## `attache` : le condamné du Conseil, enchaîné sur la pierre en attendant les loups.
static func fiche(id: int, hote: bool, vivant: bool, loup: bool, role: String, dehors: bool, maison: int, attache := false) -> Dictionary:
	return {"id": id, "hote": hote, "vivant": vivant, "loup": loup, "role": role, "dehors": dehors, "maison": maison, "attache": attache}


## L'observateur reçoit-il la position (et les gestes liés) de ce joueur ?
static func voit_position(phase: String, obs: Dictionary, sujet: Dictionary) -> bool:
	if obs["hote"] or obs["id"] == sujet["id"]:
		return true
	# Un mort n'existe pas pour les vivants — sauf pour le Médium. Les morts, eux, se voient entre eux.
	if not sujet["vivant"]:
		return not obs["vivant"] or obs["role"] == ROLE_MEDIUM
	if not obs["vivant"]:
		return true
	if phase != "nuit":
		return true
	# La nuit, un vivant enfermé chez lui : les loups se voient (à la pierre), la Guetteuse voit
	# le dehors ; personne d'autre ne voit rien.
	if obs["loup"] and (sujet["loup"] or sujet.get("attache", false)):
		return true               # (la meute voit aussi sa proie, enchaînée à la pierre)
	if obs["role"] == "guetteuse" and sujet["dehors"]:
		return true
	return false


## Les portes de la nuit : les loups sortent par derrière. Voit-on cette porte bouger ?
static func voit_porte(phase: String, obs: Dictionary, maison_porte: int) -> bool:
	if phase != "nuit" or obs["hote"] or not obs["vivant"]:
		return true
	return obs["loup"] or obs["maison"] == maison_porte or obs["role"] == "guetteuse"


## Le rideau de la Guetteuse : les loups dehors le voient bouger, elle aussi, et les morts.
static func voit_rideau(obs: Dictionary, maison_rideau: int) -> bool:
	return obs["hote"] or not obs["vivant"] or obs["loup"] or obs["maison"] == maison_rideau


## La portée de la voix (touche C) se change-t-elle dans cette phase ? Non quand tout le monde s'entend
## (Conseil, vote, dépouillement, verdict…) : la portée est alors sans objet, ni proposée ni acceptée.
static func portee_modifiable(phase: String) -> bool:
	return phase not in PHASES_TOUS_ENTENDUS


## Entend-on la voix de ce joueur ? `distance` : mètres entre eux ; `portee` : 0 chuchote, 1 parle, 2 crie
## (cf. principal.PORTEES_VOIX). Un client n'est jamais atteint par une voix qu'il n'a pas le droit
## d'entendre : le paquet ne part pas.
static func entend_voix(phase: String, appel: String, obs: Dictionary, sujet: Dictionary, distance: float, portee := 1) -> bool:
	if obs["hote"] or obs["id"] == sujet["id"]:
		return true
	if not sujet["vivant"] and obs["vivant"]:
		return false              # les vivants n'entendent pas les morts
	if phase in PHASES_TOUS_ENTENDUS:
		return distance <= PORTEE_CONSEIL + MARGE_VOIX   # le Conseil : tout le village s'entend
	var rayon: float = PORTEES_VOIX[clampi(portee, 0, 2)] + MARGE_VOIX
	if phase == "nuit" and obs["vivant"]:
		if appel not in APPELS_DES_LOUPS:
			return false          # tout le monde dort, on ne parle pas
		if not sujet["loup"]:
			return false          # seuls les loups parlent à l'appel
		# Un loup entend ses pairs ; un villageois ne surprend un loup que de près (l'oreille au mur).
		return distance <= rayon
	return distance <= rayon


## Le bruit d'une porte, d'un pas, d'un cri dans la nuit : l'observateur en connaît-il l'endroit exact
## (sinon, il l'entend « à peu près », cf. Bruit.position_entendue) ? `oreille` : l'oreille collée au mur.
static func bruit_precis(phase: String, obs: Dictionary, oreille: bool) -> bool:
	if obs["hote"] or phase != "nuit":
		return true
	return not obs["vivant"] or obs["loup"] or obs["role"] == "oreille" or oreille


## Les silhouettes des autres loups : rien en dehors de l'appel des loups (ils ne se connaissent pas).
static func silhouettes_visibles(phase: String, appel: String) -> bool:
	return phase == "nuit" and appel in APPELS_DES_LOUPS


## L'état public d'une partie, tel qu'un destinataire a le droit de le lire. L'hôte (et lui seul) garde
## l'état des portes, que les autres reconstruisent par les messages de porte filtrés.
static func pub_pour(d: Dictionary, hote: bool) -> Dictionary:
	if hote:
		return d
	var r := d.duplicate()
	r.erase("portes")
	return r


## Les objets (carnets, pages, cailloux) que ce joueur peut connaître : ce que les autres ont en poche
## n'existe pas pour lui, ce qu'ils tiennent en main se voit sans se lire (ni pages, ni texte).
static func objets_pour(etat: Array, dest: int, hote: bool) -> Array:
	if hote:
		return etat
	var r := []
	for o: Dictionary in etat:
		var porteur := int(o.get("porteur", -1))
		if porteur < 0 or porteur == dest:
			r.append(o)
			continue
		if not o.get("main", false):
			continue
		var c := o.duplicate(true)
		if c.has("pages"):
			var vides: Array[String] = []
			vides.resize((c["pages"] as Array).size())
			vides.fill("")
			c["pages"] = vides
		if c.has("texte"):
			c["texte"] = ""
		r.append(c)
	return r


## Les ids de bots dont l'observateur reçoit la position (`sujets` : id -> fiche).
static func bots_visibles(phase: String, obs: Dictionary, sujets: Dictionary) -> Array[int]:
	var r: Array[int] = []
	for id: int in sujets:
		if voit_position(phase, obs, sujets[id]):
			r.append(id)
	return r
