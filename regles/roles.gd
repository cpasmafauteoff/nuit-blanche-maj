class_name Roles
extends RefCounted
## Les 17 rôles de Nuit Blanche et la composition suggérée selon le nombre de joueurs.
## Mécaniques classiques des jeux de loups-garous, noms à nous.

const VILLAGE := "village"
const MEUTE := "meute"
const SOLITAIRE := "solitaire"

## id -> [nom, camp de départ, est un loup, ce qu'il fait]
const LISTE := {
	"villageois": ["Villageois", VILLAGE, false,
		"Tu n'as pas de pouvoir. Observe, écoute, fais les quêtes et démasque les loups."],
	"liseuse": ["Liseuse d'âmes", VILLAGE, false,
		"Chaque nuit, fixe une maison par ta fenêtre pendant 5 secondes : tu découvres le rôle de son habitant."],
	"herboriste": ["Herboriste", VILLAGE, false,
		"Une potion de vie pour sauver la victime à l'aube, une potion de mort à verser la nuit. Une fois chacune."],
	"trappeur": ["Trappeur", VILLAGE, false,
		"Si tu meurs, tu as 10 secondes pour viser quelqu'un et l'emporter avec toi."],
	"entremetteuse": ["Entremetteuse", VILLAGE, false,
		"La première nuit, lie deux joueurs. Si l'un meurt, l'autre meurt de chagrin."],
	"doyen": ["Doyen", VILLAGE, false,
		"Tu survis à la première attaque des loups."],
	"simplet": ["Simplet", VILLAGE, false,
		"Si le Conseil t'élimine, tu es gracié au dernier moment, mais tu perds ton droit de vote."],
	"enfant": ["Enfant sauvage", VILLAGE, false,
		"La première nuit, choisis un modèle. S'il meurt, tu deviens loup."],
	"oreille": ["Oreille fine", VILLAGE, false,
		"Tu entends les bruits de la nuit sans brouillage : tu sais de quelle maison ils viennent."],
	"veilleur": ["Veilleur de nuit", VILLAGE, false,
		"Chaque nuit, sors avec ta lanterne et garde une porte. Un loup qui s'en approche doit réussir un combo deux fois plus long."],
	"fossoyeur": ["Fossoyeur", VILLAGE, false,
		"Chaque jour, au cimetière, examine un mort : tu apprends s'il était loup."],
	"guetteuse": ["Petite fille", VILLAGE, false,
		"La nuit, toi seule peux écarter le rideau de ta chambre pour épier dehors : maintiens {agir} devant la fenêtre, doucement. Si un loup voit le rideau bouger, il te repère."],
	"medium": ["Médium", VILLAGE, false,
		"Tu vois les fantômes des morts errer parmi vous, et les cailloux qu'ils lancent. Tu ne les entends pas : à toi de deviner ce qu'ils manigancent."],
	"traitre": ["Traître", MEUTE, false,
		"Tu joues comme un villageois, mais tu gagnes avec les loups. Tu ne sais pas qui ils sont."],
	"loup": ["Loup", MEUTE, true,
		"Quand on t'appelle la nuit, rejoins la pierre du sacrifice sans bruit et vote pour une maison avec la meute. Tu ne sais pas qui sont les autres loups."],
	"vampire": ["Loup vampire", MEUTE, true,
		"Tu chasses la nuit avec la meute. Une seule fois de toute la partie, le jour, approche-toi de quelqu'un et mords-le en cachette : il deviendra loup la nuit suivante. Mais tu ne sais pas qui sont les loups : mordre un loup, c'est mourir de surdose."],
	"souffleur": ["Loup souffleur", MEUTE, true,
		"Deux fois par partie, fais un faux bruit sur le chemin de ronde pour faire accuser un innocent."],
	"solitaire": ["Loup solitaire", SOLITAIRE, true,
		"Tu chasses avec la meute, mais tu gagnes seul : sois le dernier vivant. Une nuit sur deux, tu peux tuer seul."],
}

const LOUPS := ["loup", "vampire", "souffleur", "solitaire"]

## Ce que le jeu propose ; l'hôte peut tout changer.
const SUGGESTIONS := {
	6: ["loup", "vampire", "liseuse", "herboriste", "villageois", "villageois"],
	7: ["loup", "vampire", "liseuse", "herboriste", "trappeur", "villageois", "villageois"],
	8: ["loup", "vampire", "liseuse", "herboriste", "trappeur", "oreille", "villageois", "villageois"],
	9: ["loup", "vampire", "liseuse", "herboriste", "trappeur", "oreille", "veilleur", "villageois", "villageois"],
	10: ["loup", "vampire", "souffleur", "liseuse", "herboriste", "trappeur", "entremetteuse", "veilleur", "guetteuse", "villageois"],
	11: ["loup", "vampire", "souffleur", "liseuse", "herboriste", "trappeur", "entremetteuse", "veilleur", "guetteuse", "fossoyeur", "villageois"],
	12: ["loup", "vampire", "souffleur", "liseuse", "herboriste", "trappeur", "entremetteuse", "veilleur", "guetteuse", "fossoyeur", "oreille", "traitre"],
}


static func nom(role: String) -> String:
	return LISTE[role][0] if LISTE.has(role) else role


static func camp_depart(role: String) -> String:
	return LISTE[role][1]


static func est_loup(role: String) -> bool:
	return LISTE[role][2]


static func description(role: String) -> String:
	return LISTE[role][3]


static func composition(n: int) -> Array[String]:
	var c: Array[String] = []
	c.assign(SUGGESTIONS[clampi(n, 6, 12)])
	if n < 6:                # petit village (3 à 5, sans bots) : les premiers rôles de la liste à 6
		c.resize(maxi(n, 1))
	while c.size() < n:      # au-delà de 12 (lobby privé, jusqu'à 16) : des villageois de plus
		c.append("villageois")
	return c


## Écarter son rideau, la nuit, pour épier dehors : seule la Petite fille (« guetteuse »), vivante.
## Un villageois ne se le voit pas proposer, et l'hôte refuse l'intention (Edwin, 01/11 :
## « je n'étais que villageois et pourtant j'ai pu ouvrir le volet »).
static func peut_ecarter_rideau(role: String, phase: String, vivant: bool) -> bool:
	return vivant and phase == "nuit" and role == "guetteuse"
