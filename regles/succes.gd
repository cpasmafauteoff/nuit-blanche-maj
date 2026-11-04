class_name Succes
extends RefCounted
## Les succès de Nuit Blanche (Steam et dans le jeu), sans rien d'affiché.
##
## Chaque succès a un identifiant d'API en MAJUSCULES (le même sur Steamworks : cf.
## distribution/steam/succes.csv, généré depuis cette liste), un nom et une description en
## français et en anglais, et un symbole simple pour son icône.
##
## Les conditions se lisent sur deux choses :
##  - les « faits » de la partie qui vient de finir, pour CE joueur (`faits_partie` les calcule
##    à partir de la partie : l'hôte les joint au résultat de fin) ;
##  - le « cumul » du joueur sur ce PC (parties jouées, victoires, rôles joués, niveau).

## id, nom FR, description FR, nom EN, description EN, symbole de l'icône
const LISTE := [
	["PREMIERE_NUIT", "Première nuit", "Va jusqu'au bout d'une partie.",
		"First Night", "Play a game to the end.", "lune"],
	["SURVIVRE_3_NUITS", "Les yeux ouverts", "Survis jusqu'à la troisième nuit.",
		"Eyes Open", "Survive until the third night.", "oeil"],
	["SURVIVRE_5_NUITS", "Cinq nuits blanches", "Survis jusqu'à la cinquième nuit.",
		"Five White Nights", "Survive until the fifth night.", "bougie"],
	["VICTOIRE", "Le village respire", "Gagne une partie.",
		"The Village Breathes", "Win a game.", "couronne"],
	["VICTOIRE_VILLAGE", "Lumière sur les loups", "Gagne avec le village, sans être un loup.",
		"Light on the Wolves", "Win with the village.", "lanterne"],
	["VICTOIRE_LOUP", "Croc vainqueur", "Gagne en étant loup.",
		"Victorious Fang", "Win as a wolf.", "croc"],
	["LOUP_JAMAIS_ACCUSE", "Agneau parmi les loups", "Gagne en loup sans jamais avoir reçu une seule voix au Conseil.",
		"Lamb Among Wolves", "Win as a wolf without ever being voted against at the Council.", "agneau"],
	["LOUP_SOLITAIRE", "Seul contre tous", "Gagne en Loup solitaire.",
		"All Alone", "Win as the Lone Wolf.", "patte"],
	["VICTOIRE_OUTRE_TOMBE", "Victoire d'outre-tombe", "Gagne alors que tu es mort.",
		"Victory From Beyond", "Win while dead.", "crane"],
	["AMOURS_INTERDITS", "Amours interdits", "Gagne avec les amours interdits.",
		"Forbidden Love", "Win with the forbidden lovers.", "coeur"],
	["INNOCENT_ACCUSE", "Innocent, je le jure", "Reçois au moins deux voix au Conseil, survis et gagne avec le village.",
		"Innocent, I Swear", "Get at least two votes at the Council, survive and win with the village.", "balance"],
	["BON_FLAIR", "Bon flair", "Vote contre un loup que le Conseil élimine.",
		"Good Nose", "Vote against a wolf the Council eliminates.", "truffe"],
	["FLAIR_TROIS", "Chasseur de loups", "Vote trois fois contre un loup éliminé, en une seule partie.",
		"Wolf Hunter", "Vote against an eliminated wolf three times in a single game.", "arc"],
	["PREMIERE_QUETE", "Première quête", "Réussis une quête.",
		"First Quest", "Complete a quest.", "parchemin"],
	["QUETE_DURE", "À la dure", "Réussis une quête de niveau dur.",
		"The Hard Way", "Complete a hard quest.", "epee"],
	["QUETE_EXTREME", "Au bord du gouffre", "Réussis une quête extrême.",
		"Edge of the Abyss", "Complete an extreme quest.", "gouffre"],
	["TROIS_QUETES", "Bête de somme", "Réussis trois quêtes en une seule partie.",
		"Workhorse", "Complete three quests in a single game.", "pelle"],
	["ROLE_GAGNE", "Une vocation", "Gagne un rôle en réussissant une quête.",
		"A Calling", "Win a role by completing a quest.", "masque"],
	["ELU_MAIRE", "Monsieur le maire", "Sois élu maire.",
		"Mr. Mayor", "Get elected mayor.", "echarpe"],
	["HANTER_3", "Hanteur", "Hante trois personnes différentes en une seule partie.",
		"Haunter", "Haunt three different people in a single game.", "fantome"],
	["FRAYEUR", "Boo !", "Fais une apparition en monstre devant quelqu'un.",
		"Boo!", "Appear as a monster in front of someone.", "monstre"],
	["CAILLOU_FANTOME", "Tir de l'au-delà", "Touche un vivant d'un caillou lancé depuis la mort.",
		"Shot From Beyond", "Hit a living player with a stone thrown from beyond the grave.", "caillou"],
	["HERBORISTE_SAUVE", "Potion salvatrice", "Sauve quelqu'un de la meute en tant qu'Herboriste.",
		"Life-Saving Potion", "Save someone from the pack as the Herbalist.", "fiole"],
	["PARTIES_10", "Habitué du village", "Joue dix parties.",
		"Village Regular", "Play ten games.", "maison"],
	["PARTIES_50", "Âme du village", "Joue cinquante parties.",
		"Soul of the Village", "Play fifty games.", "cloche"],
	["VICTOIRES_10", "Dix victoires", "Gagne dix parties.",
		"Ten Victories", "Win ten games.", "laurier"],
	["ROLES_8", "Mille visages", "Joue huit rôles différents.",
		"A Thousand Faces", "Play eight different roles.", "masques"],
	["NIVEAU_10", "Villageois confirmé", "Atteins le niveau 10.",
		"Seasoned Villager", "Reach level 10.", "etoile"],
	["NIVEAU_30", "Doyen du village", "Atteins le niveau 30.",
		"Village Elder", "Reach level 30.", "soleil"],
]


static func ids() -> PackedStringArray:
	var l := PackedStringArray()
	for s: Array in LISTE:
		l.append(s[0])
	return l


static func fiche(id: String) -> Array:
	for s: Array in LISTE:
		if s[0] == id:
			return s
	return []


## Le nom d'un succès dans la langue demandée ("fr" ou "en"), par défaut celle du jeu.
static func nom(id: String, langue := "") -> String:
	var s := fiche(id)
	var l := langue if langue != "" else Langue.code()
	return "" if s.is_empty() else str(s[1] if l == "fr" else s[3])


static func description(id: String, langue := "") -> String:
	var s := fiche(id)
	var l := langue if langue != "" else Langue.code()
	return "" if s.is_empty() else str(s[2] if l == "fr" else s[4])


# ---------------------------------------------------------------- les faits d'une partie

## Les faits de chaque joueur à la fin de la partie : {id: faits}. `compteurs` : ce que l'hôte a
## compté en cours de route ({id: {quetes, quetes_dur, quetes_extreme, hantes: [ids], apparitions, cailloux}}).
## Tout se révèle à l'écran de fin : rien ici n'est un secret de la partie.
static func faits_partie(p: Partie, compteurs: Dictionary, gagnants: Array) -> Dictionary:
	var eliminations := {}     # (n, id) du Conseil -> vrai
	var maires := {}
	var voix := {}
	var flair := {}
	var sauvetages := 0
	for e: Dictionary in p.chronique:
		match e["type"]:
			"mort":
				if e.get("cause", "") == "vote":
					eliminations["%d/%d" % [e["n"], e["id"]]] = true
			"maire":
				if int(e["id"]) > 0 and not (e["votes"] as Dictionary).is_empty():
					maires[int(e["id"])] = true
			"sauve":
				sauvetages += 1
	for e: Dictionary in p.chronique:
		if e["type"] != "vote":
			continue
		var votes: Dictionary = e["votes"]
		for votant in votes:
			var cible: int = votes[votant]
			voix[cible] = int(voix.get(cible, 0)) + 1
			if p.est_loup(cible) and eliminations.has("%d/%d" % [e["n"], cible]):
				flair[votant] = int(flair.get(votant, 0)) + 1
	var faits := {}
	for id in p.joueurs:
		var c: Dictionary = compteurs.get(id, {})
		var r: String = p.role(id)
		faits[id] = {
			"role": r, "loup": p.est_loup(id), "camp": p.camp(id), "gagne": gagnants.has(id),
			"vivant": p.vivant(id), "nuits": p.nuit_n, "voix_recues": int(voix.get(id, 0)),
			"maire": maires.has(id), "role_gagne": bool(p.joueurs[id]["role_gagne"]),
			"flair": int(flair.get(id, 0)), "sauvetage": r == "herboriste" and sauvetages > 0,
			"quetes": int(c.get("quetes", 0)), "quetes_dur": int(c.get("quetes_dur", 0)),
			"quetes_extreme": int(c.get("quetes_extreme", 0)),
			"hantes": (c.get("hantes", []) as Array).size(), "apparitions": int(c.get("apparitions", 0)),
			"cailloux": int(c.get("cailloux", 0)),
		}
	return faits


# ---------------------------------------------------------------- les conditions

## Les succès que remplit ce joueur, d'après les faits de la partie qui vient de finir et son
## cumul APRÈS cette partie ({parties, victoires, roles: [..], niveau}).
static func remplis(faits: Dictionary, cumul: Dictionary) -> PackedStringArray:
	var l := PackedStringArray()
	for s: Array in LISTE:
		if _condition(s[0], faits, cumul):
			l.append(s[0])
	return l


static func _condition(id: String, f: Dictionary, c: Dictionary) -> bool:
	var gagne: bool = f.get("gagne", false)
	var loup: bool = f.get("loup", false)
	var camp: String = f.get("camp", "")
	var nuits: int = int(f.get("nuits", 0))
	var vivant: bool = f.get("vivant", false)
	match id:
		"PREMIERE_NUIT":
			return not f.is_empty()
		"SURVIVRE_3_NUITS":
			return vivant and nuits >= 3
		"SURVIVRE_5_NUITS":
			return vivant and nuits >= 5
		"VICTOIRE":
			return gagne
		"VICTOIRE_VILLAGE":
			return gagne and camp == Roles.VILLAGE and not loup
		"VICTOIRE_LOUP":
			return gagne and loup
		"LOUP_JAMAIS_ACCUSE":
			return gagne and loup and int(f.get("voix_recues", 0)) == 0
		"LOUP_SOLITAIRE":
			return gagne and f.get("role", "") == "solitaire"
		"VICTOIRE_OUTRE_TOMBE":
			return gagne and not vivant
		"AMOURS_INTERDITS":
			return gagne and camp == "amoureux"
		"INNOCENT_ACCUSE":
			return gagne and vivant and camp == Roles.VILLAGE and not loup and int(f.get("voix_recues", 0)) >= 2
		"BON_FLAIR":
			return int(f.get("flair", 0)) >= 1
		"FLAIR_TROIS":
			return int(f.get("flair", 0)) >= 3
		"PREMIERE_QUETE":
			return int(f.get("quetes", 0)) >= 1
		"QUETE_DURE":
			return int(f.get("quetes_dur", 0)) >= 1
		"QUETE_EXTREME":
			return int(f.get("quetes_extreme", 0)) >= 1
		"TROIS_QUETES":
			return int(f.get("quetes", 0)) >= 3
		"ROLE_GAGNE":
			return bool(f.get("role_gagne", false))
		"ELU_MAIRE":
			return bool(f.get("maire", false))
		"HANTER_3":
			return int(f.get("hantes", 0)) >= 3
		"FRAYEUR":
			return int(f.get("apparitions", 0)) >= 1
		"CAILLOU_FANTOME":
			return int(f.get("cailloux", 0)) >= 1
		"HERBORISTE_SAUVE":
			return bool(f.get("sauvetage", false))
		"PARTIES_10":
			return int(c.get("parties", 0)) >= 10
		"PARTIES_50":
			return int(c.get("parties", 0)) >= 50
		"VICTOIRES_10":
			return int(c.get("victoires", 0)) >= 10
		"ROLES_8":
			return (c.get("roles", []) as Array).size() >= 8
		"NIVEAU_10":
			return int(c.get("niveau", 1)) >= 10
		"NIVEAU_30":
			return int(c.get("niveau", 1)) >= 30
	return false


# ---------------------------------------------------------------- Steamworks

## Le fichier à fournir à Steamworks : id, noms et descriptions FR/EN, une ligne par succès.
static func csv() -> String:
	var l := PackedStringArray(["id;nom_fr;description_fr;nom_en;description_en;icone_debloquee;icone_verrouillee"])
	for s: Array in LISTE:
		l.append(";".join([s[0], _csv(s[1]), _csv(s[2]), _csv(s[3]), _csv(s[4]),
			"icones_succes/%s.png" % str(s[0]).to_lower(), "icones_succes/%s_verrouille.png" % str(s[0]).to_lower()]))
	return "\n".join(l) + "\n"


static func _csv(t: String) -> String:
	return "\"%s\"" % t.replace("\"", "\"\"")
