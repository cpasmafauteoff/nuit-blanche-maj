class_name TwitchVotes
extends RefCounted
## Le chat Twitch qui vote avec le streamer (mode streamer), sans rien d'affiché.
##
## Lecture seule et anonyme : on se connecte au chat comme un spectateur sans compte
## (NICK justinfan<nombre>, PASS quelconque), on lit les messages, on n'écrit JAMAIS. Ici, que de
## l'analyse de texte et du décompte : la connexion vit dans streamer.gd.
##
## Un spectateur tape « !vote rouge » (ou « !vote red », « !vote bandeau bleu ciel »…) : les
## noms des couleurs de bandeau marchent en français et en anglais, sans tenir compte des
## majuscules ni des accents. Un vote par spectateur : le dernier compte.

const ADRESSE := "wss://irc-ws.chat.twitch.tv:443"
const MOT_DE_PASSE := "SCHMOOPIIE"
const COMMANDE := "!vote"

## Les noms de couleur en anglais, rang pour rang avec Bouille.BANDEAUX (plusieurs noms possibles).
const NOMS_EN := [["red"], ["blue"], ["yellow"], ["green"], ["white"], ["orange"], ["purple", "violet"],
	["pink"], ["turquoise", "teal", "cyan"], ["gold", "golden"], ["brown"], ["gray", "grey"],
	["sky blue", "skyblue", "light blue", "lightblue"], ["apple green", "lime", "lime green"],
	["burgundy", "maroon", "wine"], ["mauve", "lilac", "lavender"]]
## Ces mots devant la couleur ne comptent pas (« !vote bandeau rouge », « !vote the red one »).
const MOTS_VIDES := ["le", "la", "the", "bandeau", "headband", "bandana", "band"]


## Minuscules, sans accents, espaces simples.
static func normaliser(texte: String) -> String:
	var t := texte.strip_edges().to_lower()
	var de := "àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ"
	var vers := "aaaaaaceeeeiiiinooooouuuuyyoa"
	var sortie := ""
	for c in t:
		var i := de.find(c)
		sortie += vers[i] if i >= 0 else c
	var mots := sortie.split(" ", false)
	return " ".join(mots)


## Le nom de chaîne saisi (« #Chaine », « twitch.tv/chaine », « https://www.twitch.tv/Chaine/ ») en
## nom Twitch valide (a-z, 0-9, _ ; 4 à 25 signes). "" si ce n'en est pas un.
static func chaine_valide(saisie: String) -> String:
	var t := saisie.strip_edges().to_lower()
	if t.contains("twitch.tv/"):
		t = t.substr(t.find("twitch.tv/") + 10)
	t = t.get_slice("/", 0).get_slice("?", 0).lstrip("#@")
	if t.length() < 3 or t.length() > 25:
		return ""
	for c in t:
		if not (c >= "a" and c <= "z") and not (c >= "0" and c <= "9") and c != "_":
			return ""
	return t


## Les lignes à envoyer pour entrer anonymement dans le chat d'une chaîne.
static func lignes_connexion(chaine: String, nombre: int) -> PackedStringArray:
	return PackedStringArray(["PASS " + MOT_DE_PASSE, "NICK justinfan%d" % nombre, "JOIN #" + chaine])


## Un bloc reçu de la socket (plusieurs lignes séparées par \r\n) en lignes.
static func decouper(bloc: String) -> PackedStringArray:
	var l := PackedStringArray()
	for x in bloc.replace("\r", "").split("\n", false):
		if x.strip_edges() != "":
			l.append(x)
	return l


## Une ligne IRC : {type: "message", pseudo, texte} | {type: "ping", reponse} | {type: "autre"}.
static func analyser(ligne: String) -> Dictionary:
	var l := ligne
	if l.begins_with("@"):                 # les étiquettes (badges, couleur…) : on les saute
		var e := l.find(" ")
		if e < 0:
			return {"type": "autre"}
		l = l.substr(e + 1)
	if l.begins_with("PING"):
		return {"type": "ping", "reponse": "PONG" + l.substr(4)}
	if not l.begins_with(":"):
		return {"type": "autre"}
	var mots := l.split(" ", true, 3)       # [prefixe, commande, canal, :texte]
	if mots.size() < 4 or mots[1] != "PRIVMSG":
		return {"type": "autre", "commande": mots[1] if mots.size() > 1 else ""}
	var pseudo := mots[0].substr(1).get_slice("!", 0).to_lower()
	var texte := mots[3]
	if texte.begins_with(":"):
		texte = texte.substr(1)
	return {"type": "message", "pseudo": pseudo, "texte": texte}


## Le rang de bandeau désigné par ce texte, parmi `candidats` (rangs encore en lice), ou -1.
## `noms_fr` : les noms français des bandeaux, dans l'ordre (Bouille.BANDEAUX[k][1]).
static func lire_vote(texte: String, candidats: Array, noms_fr: Array) -> int:
	var t := normaliser(texte)
	if t != COMMANDE and not t.begins_with(COMMANDE + " ") and not t.begins_with(COMMANDE + ":"):
		return -1
	var reste := t.substr(COMMANDE.length()).strip_edges().lstrip(":").strip_edges()
	var mots := Array(reste.split(" ", false))
	while not mots.is_empty() and mots[0] in MOTS_VIDES:
		mots.pop_front()
	while not mots.is_empty() and mots[mots.size() - 1] in ["one", "color", "couleur"]:
		mots.pop_back()
	var voulu := " ".join(mots)
	if voulu == "":
		return -1
	for k in candidats:
		if voulu in noms_de(int(k), noms_fr):
			return int(k)
	return -1


## Tous les noms acceptés pour un bandeau, normalisés.
static func noms_de(k: int, noms_fr: Array) -> Array:
	var l := []
	if k >= 0 and k < noms_fr.size():
		l.append(normaliser(str(noms_fr[k])))
	if k >= 0 and k < NOMS_EN.size():
		for n: String in NOMS_EN[k]:
			l.append(normaliser(n))
	return l


## Le décompte : `votes` = {pseudo: rang}. Renvoie {total, parts: [[rang, voix, pourcentage]…]},
## du plus soupçonné au moins soupçonné (à égalité, le plus petit rang d'abord).
static func compter(votes: Dictionary) -> Dictionary:
	var c := {}
	for p in votes:
		c[int(votes[p])] = int(c.get(int(votes[p]), 0)) + 1
	var parts := []
	var total := votes.size()
	for k in c:
		parts.append([k, c[k], int(round(100.0 * c[k] / total))])
	parts.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1] or (a[1] == b[1] and a[0] < b[0]))
	return {"total": total, "parts": parts}


## « Le chat soupçonne : Bandeau rouge (42 %) », ou une phrase honnête s'il n'a rien dit.
static func phrase(decompte: Dictionary, noms_fr: Array) -> String:
	if int(decompte["total"]) == 0 or (decompte["parts"] as Array).is_empty():
		return "Le chat n'a pas voté."
	var tete: Array = decompte["parts"][0]
	return "Le chat soupçonne : Bandeau %s (%d %%)" % [noms_fr[int(tete[0])], int(tete[2])]
