class_name RythmeHumain
extends RefCounted
## Le rythme d'un joueur HUMAIN, que les bots de tous les mini-jeux doivent respecter (Edwin, 01/11 :
## « les bots doivent agir comme des joueurs, avoir le même comportement »). Un bot ne fait jamais une
## action instantanée ni plus vite qu'une personne : il marche (temps de trajet), prend et pose (temps de
## geste), lit et écoute (temps de lecture, de parole, de réaction), à une cadence humaine, et il lui arrive
## de se tromper. Et il attend l'humain dès que le jeu a besoin de lui (une information qu'il détient, un
## geste qu'il doit faire) : un bot ne finit JAMAIS la quête à la place de l'humain.
## Rien ici n'a de nœud : tout se teste sans moteur (tests/test_rythme_humain.gd).

## Vitesse de marche d'un bot dans une clairière (m/s) : celle de `meneur.gd` (b["vitesse"]).
const MARCHE := 2.6
## Les gestes (secondes) : tendre la main et saisir, reposer, basculer un pot / tourner une manivelle.
const PRISE := 1.2
const POSE := 1.0
const VERSEMENT := 2.0
## Lire à voix haute : un mot par ~0,4 s (2,5 mots/s), plus un temps pour se lancer.
const PAROLE_PAR_MOT := 0.4
const PAROLE_LANCER := 0.8
## Lire en silence (chercher la ligne, la comprendre) : 0,3 s par mot, plus le temps de lever les yeux.
const LECTURE_PAR_MOT := 0.3
const LECTURE_LANCER := 1.0
## Comprendre ce qu'on vient d'entendre et décider (le « temps de réaction » d'un joueur, pas d'un réflexe).
const REACTION_MIN := 0.9
const REACTION_MAX := 1.8
## Deux gestes du même joueur sont toujours séparés d'au moins ceci.
const CADENCE_MIN := 0.45
## Après une erreur on s'en aperçoit, on souffle, on reprend : jamais de geste dans cet intervalle.
const REGRET_MIN := 2.5
const REGRET_MAX := 4.0


## Le temps pour marcher `distance` mètres.
static func marche(distance: float) -> float:
	return maxf(distance, 0.0) / MARCHE


## Le temps pour dire `nb_mots` mots à voix haute.
static func parole(nb_mots: int) -> float:
	return PAROLE_LANCER + PAROLE_PAR_MOT * float(maxi(nb_mots, 0))


## Le temps pour lire `nb_mots` mots en silence.
static func lecture(nb_mots: int) -> float:
	return LECTURE_LANCER + LECTURE_PAR_MOT * float(maxi(nb_mots, 0))


## Un temps de réaction tiré au hasard (jamais sous REACTION_MIN).
static func reaction(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(REACTION_MIN, REACTION_MAX)


## Le délai après une erreur.
static func regret(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(REGRET_MIN, REGRET_MAX)


## Le moment (temps de jeu) où un bot peut AGIR après qu'une information lui est parvenue : il faut qu'elle
## ait été dite en entier, puis qu'il la comprenne. `dit_a` : le moment où l'on a commencé à parler.
static func agir_apres(dit_a: float, nb_mots: int, reaction_: float) -> float:
	return dit_a + parole(nb_mots) + maxf(reaction_, REACTION_MIN)


## Le moment où un geste enchaîné peut démarrer : jamais avant la cadence minimale du joueur.
static func geste_apres(dernier_geste: float, voulu: float) -> float:
	return maxf(voulu, dernier_geste + CADENCE_MIN)


## Le temps minimal d'un tour complet « aller chercher un objet, le rapporter, le déposer » pour un
## trajet de `aller` mètres chacun : un bot n'en fait jamais plus vite.
static func tour_complet(aller: float, retour: float) -> float:
	return marche(aller) + PRISE + marche(retour) + VERSEMENT


## Peut-on perdre la DERNIÈRE vie de l'équipe maintenant ? Si les bots seuls jouent (l'humain n'a rien
## fait), la quête ne peut pas être perdue avant `Quetes.duree_min` : Edwin, 01/11, « finie en 10 secondes ».
## Une personne qui joue vraiment peut, elle, perdre aussi vite qu'elle le mérite.
static func derniere_vie_permise(temps_de_jeu: float, niveau: String, humain_a_agi: bool) -> bool:
	return humain_a_agi or temps_de_jeu >= Quetes.duree_min(niveau)


## Les vies restantes après une faute : jamais 0 si la dernière vie n'a pas le droit de tomber.
static func vies_apres_faute(restantes: int, temps_de_jeu: float, niveau: String, humain_a_agi: bool) -> int:
	var n := restantes - 1
	if n <= 0 and not derniere_vie_permise(temps_de_jeu, niveau, humain_a_agi):
		return maxi(restantes, 1)
	return maxi(n, 0)


## Quand un lecteur HUMAIN dicte la recette, un bot ne verse qu'après avoir lu la ligne (`mots` mots) et
## entendu le lecteur la dire. Rend le délai (secondes) depuis que l'étape est devenue la courante.
static func attente_dictee(mots: int, rng: RandomNumberGenerator) -> float:
	return lecture(mots) + parole(mots) + reaction(rng)


## Un jeu qui dure moins que son plancher (Quetes.duree_min du niveau) alors que l'humain n'a rien fait de
## décisif est trop expéditif : vrai si ce temps de jeu est plausible.
static func duree_plausible(temps_de_jeu: float, niveau: String, humain_a_joue: bool) -> bool:
	return humain_a_joue or temps_de_jeu >= Quetes.duree_min(niveau)
