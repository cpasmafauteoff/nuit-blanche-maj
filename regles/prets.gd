class_name Prets
extends RefCounted
## « Prêt, on passe au vote » : à la fin du jour (retour des quêtes) et pendant les débats de l'élection du maire,
## chacun appuie sur la touche V s'il est d'accord ; quand tous les vivants l'ont fait, on passe tout de suite
## à la suite (Edwin, 01/11). Règles pures, testées sans moteur (tests/test_prets.gd).

## Les phases où la touche « prêt » est acceptée.
const PHASES := ["pret", "election"]
## Au plus tôt après le dernier « prêt » : le temps de lire l'annonce avant que l'écran change (s).
const DELAI_FINAL := 1.5
## Un bot dit « prêt » comme une personne : pas avant, ni après, ces délais (s) depuis le début de la phase.
const BOT_MIN := 6.0
const BOT_MAX := 40.0


static func accepte(phase: String) -> bool:
	return phase in PHASES


## Combien de VIVANTS sont prêts (un mort qui aurait appuyé avant de mourir ne compte plus).
static func compte(vivants: Array, prets: Array) -> int:
	var n := 0
	for id in vivants:
		if prets.has(id):
			n += 1
	return n


## Tous les vivants sont-ils prêts ? (Personne de vivant : non, il n'y a personne pour décider.)
static func tous(vivants: Array, prets: Array) -> bool:
	return not vivants.is_empty() and compte(vivants, prets) == vivants.size()


## Le temps restant à la phase une fois qu'un joueur vient de se dire prêt.
static func reste_apres(reste: float, vivants: Array, prets: Array) -> float:
	return minf(reste, DELAI_FINAL) if tous(vivants, prets) else reste
