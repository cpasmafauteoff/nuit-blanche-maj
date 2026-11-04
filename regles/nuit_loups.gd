class_name NuitLoups
extends RefCounted
## Le tour des loups, après le choix de la porte : combien de temps la nuit leur laisse, et qui
## est ramené dans sa chambre. Règle pure (testée sans fenêtre).
## Déroulé voulu (Edwin, 01/11) : la meute choisit → l'attaque se joue (cinématique) → chaque loup
## humain est ramené dans sa chambre (fondu au noir) → la nuit continue pour les autres rôles →
## le jour se lève avec tout le monde chez soi.

const FONDU := 1.6          # fondu au noir, replacement, retour de la lumière (secondes)
const MARGE_CINE := 0.4     # après la fin de la cinématique, avant le fondu
const ATTENTE_SANS_PORTE := 2.0   # personne n'a été attaqué : un court silence avant de rentrer


## Quand (après le choix) faut-il lancer le retour des loups humains ?
## Attaque réussie : la cinématique se joue d'abord, et tout le monde la voit en entier.
static func delai_retour(attaque: bool, duree_cine: float) -> float:
	return duree_cine + MARGE_CINE if attaque else ATTENTE_SANS_PORTE


## Combien de temps reste-t-il au tour des loups une fois la porte choisie ? Jamais plus long que
## ce qui restait ; assez long pour la cinématique PUIS le fondu du retour.
static func reste_apres_choix(reste: float, attaque: bool, duree_cine: float) -> float:
	return minf(reste, delai_retour(attaque, duree_cine) + FONDU + 1.0)


## Faut-il ramener ce loup dans sa chambre ? Un vivant, humain, pas encore ramené, pas déjà au lit.
## (Les bots, eux, marchent jusqu'à leur lit.)
static func a_ramener(humain: bool, vivant: bool, deja_ramene: bool, deja_chez_lui: bool) -> bool:
	return humain and vivant and not deja_ramene and not deja_chez_lui


## Le tour s'achève-t-il tout de suite, ou faut-il laisser jouer l'attaque d'un choix tardif (le
## temps était écoulé avant que la meute ait fini de voter) ? Vrai : on reste dans le tour.
static func prolonger_apres_temps_ecoule(choix_deja_fait: bool, attaque: bool) -> bool:
	return (not choix_deja_fait) and attaque


# ---------------------------------------------------------------- le déroulé du tour des loups (Edwin, 01/11)
# « Quand la nuit commence, les loups ont 10 secondes pour se transformer ; s'ils ne le font pas, ils se
# transforment seuls et sortent de chez eux ; uniquement après, 10 secondes de préparation ; puis un loup a
# 30 secondes pour choisir sa porte. »

const TRANSFORMATION := 10.0
const PREPARATION := 10.0
const CHOIX := 30.0


## Durée totale du tour de la meute (le choix peut être réglé au salon).
static func duree_tour(choix: float = CHOIX) -> float:
	return TRANSFORMATION + PREPARATION + choix


## Où en est le tour, après `ecoule` secondes : "transformation", "preparation", "choix".
static func etape(ecoule: float) -> String:
	if ecoule < TRANSFORMATION:
		return "transformation"
	if ecoule < TRANSFORMATION + PREPARATION:
		return "preparation"
	return "choix"


## Secondes restantes dans l'étape en cours (`choix` : la durée du choix, pour la dernière étape).
static func reste_etape(ecoule: float, choix: float = CHOIX) -> float:
	match etape(ecoule):
		"transformation":
			return TRANSFORMATION - ecoule
		"preparation":
			return TRANSFORMATION + PREPARATION - ecoule
	return maxf(duree_tour(choix) - ecoule, 0.0)


## Le vote à la pierre n'ouvre qu'après la transformation et la préparation.
static func vote_ouvert(ecoule: float) -> bool:
	return ecoule >= TRANSFORMATION + PREPARATION


## Les dix secondes sont passées : ceux qui ne se sont pas transformés le font seuls, et sortent.
static func sortie_forcee(ecoule: float, deja_faite: bool) -> bool:
	return ecoule >= TRANSFORMATION and not deja_faite


## Une meute ne vise jamais une maison de loup : seuls les côtés villageois se ciblent.
static func cible_permise(habitant_est_loup: bool) -> bool:
	return not habitant_est_loup


## Les proies possibles d'un bot : tout sauf les loups.
static func proies(candidats: Array, loups: Array) -> Array:
	return candidats.filter(func(x): return not loups.has(x))
