class_name Clics
extends RefCounted
## Qui a le dernier mot sur un clic ou une touche 1-4 (décisions d'Edwin, 31/10). Règles pures,
## testées sans moteur (tests/test_clics.gd).
##
## CLIC GAUCHE, par ordre de priorité :
##   1. une carte ou un panneau ouvert : le clic est à lui (la souris n'est plus captée) ;
##   2. la phase de vote, quelqu'un de votable visé : le clic vote ;
##   3. une proposition à accepter : le clic accepte ;
##   4. un caillou en main : viser ;
##   5. un carnet ou une page en main : l'ouvrir en lecture, ou le refermer s'il est ouvert ;
##   6. quelqu'un en face : interagir.
## CLIC DROIT : caillou = lancer ; carnet ou page = poser la plume (ouvre le carnet fermé directement en
## écriture), puis la lever. Molette et flèches : tourner les pages (Edwin, 01/11).


static func clic_gauche(carte_ouverte: bool, vote_possible: bool, proposition: bool, caillou_en_main: bool,
		livre_en_main: bool, cible_geste: bool) -> String:
	if carte_ouverte:
		return "carte"
	if vote_possible:
		return "voter"
	if proposition:
		return "accepter"
	if caillou_en_main:
		return "viser"
	if livre_en_main:
		return "carnet"
	if cible_geste:
		return "interagir"
	return ""


## Clic gauche avec un carnet ou une page en main : "ouvrir" (lecture seule) ou "fermer" (le panneau est ouvert).
static func carnet_gauche(panneau_ouvert: bool) -> String:
	return "fermer" if panneau_ouvert else "ouvrir"


## Clic droit, `sorte` : la sorte de l'objet en main ("" : rien). `panneau_ouvert` : le carnet est affiché ;
## `ecriture` : la plume est posée.
static func clic_droit(sorte: String, panneau_ouvert: bool, ecriture: bool) -> String:
	match sorte:
		"caillou":
			return "lancer"
		"carnet", "page":
			if ecriture:
				return "lever"
			return "ecrire" if panneau_ouvert else "ouvrir_ecrire"
	return ""


## L'aide à l'écran : {"gauche": texte, "droite": texte} ("" : ce bouton ne fait rien ici).
static func aide(sorte: String, ouvert: bool) -> Dictionary:
	match sorte:
		"caillou":
			return {"gauche": "Viser", "droite": "Lancer"}
		"carnet", "page":
			return {"gauche": "Fermer" if ouvert else "Ouvrir", "droite": "Écrire"}
	return {"gauche": "", "droite": ""}


## Les touches 1 à 4 vont-elles à l'inventaire ? Jamais pendant le vote de quête (phase « tableau »,
## ou son panneau affiché), ni quand une carte de choix ou le panneau des gestes est ouvert.
static func chiffre_pour_inventaire(phase: String, vote_quete_visible: bool, carte_de_choix: bool, emotes_ouverts: bool) -> bool:
	return phase != "tableau" and not vote_quete_visible and not carte_de_choix and not emotes_ouverts
