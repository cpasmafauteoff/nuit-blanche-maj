class_name TutosSynchro
extends RefCounted
## Les astuces qui défilent pendant la synchronisation. Chaque carte : une icône, un titre, un texte
## court. Les touches s'écrivent {action} (cf. Options.avec_touches) et suivent les réglages du joueur.
##
## ICÔNES : pour remplacer le dessin par défaut, déposer une image dans res://images/tutos/ nommée
## comme la clé "icone" de la carte (ex. images/tutos/voix.png). .png, .webp et .jpg sont acceptés ;
## sans image, l'icône est dessinée en code (cf. EcranSynchro.IconeTuto).

const DOSSIER := "res://images/tutos/"
const EXTENSIONS := ["png", "webp", "jpg"]

const CARTES := [
	{"icone": "deplacer", "titre": "Se déplacer",
		"texte": "{avancer} {gauche} {reculer} {droite} pour marcher, {sprint} pour courir, {sauter} pour sauter. Courir use ton souffle."},
	{"icone": "agir", "titre": "Agir",
		"texte": "{agir} ouvre une porte, lit le tableau des quêtes ou te fait asseoir. {pouvoir} lance le pouvoir de ton rôle."},
	{"icone": "voix", "titre": "Voix de proximité",
		"texte": "Tu n'entends que ceux qui sont près de toi. {portee} change ta portée : chuchoter, parler ou crier."},
	{"icone": "carnet", "titre": "Le carnet",
		"texte": "Tes indices s'y gardent. {lire} pour le lire ou y écrire, {poser} pour lâcher ce que tu tiens."},
	{"icone": "gestes", "titre": "Gestes et danses",
		"texte": "{emotes} ouvre les animations. Face à quelqu'un, {interagir} permet de pousser, tendre la main, faire chut…"},
	{"icone": "quetes", "titre": "Les quêtes du jour",
		"texte": "Le matin, le village vote la quête. Chaque rôle se gagne aux quêtes, une seule fois."},
	{"icone": "nuit", "titre": "La nuit",
		"texte": "À la nuit tombée, les loups chassent. Le jour, le Conseil vote pour condamner un suspect."},
	{"icone": "pret", "titre": "Être prêt",
		"texte": "Ta quête finie, {pret} dit que tu veux passer au vote. La journée avance quand tout le monde l'est."},
	{"icone": "volumes", "titre": "Les voix et le miroir",
		"texte": "{volumes} règle le volume de chaque joueur. {miroir} montre ou cache le miroir."},
	{"icone": "fantome", "titre": "Mort, pas fini",
		"texte": "Un fantôme hante et lance des cailloux, au prix de son énergie. Les morts gênent tout le monde."},
]


## L'image de l'icône si elle existe, sinon null (le dessin par défaut prend le relais).
static func image(cle: String) -> Texture2D:
	for ext: String in EXTENSIONS:
		var chemin := "%s%s.%s" % [DOSSIER, cle, ext]
		if ResourceLoader.exists(chemin):
			var t = load(chemin)
			if t is Texture2D:
				return t
	return null
