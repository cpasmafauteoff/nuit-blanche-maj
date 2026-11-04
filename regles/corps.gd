class_name Corps
extends RefCounted
## Les règles du corps du joueur, sans rien de la scène : la pause d'un entraînement, les collisions entre
## joueurs, l'accroupi, la marche guidée. Testées dans tests/test_corps.gd.

## Couche de collision des autres joueurs (couche 5). Les portes occupent les couches 3 et 4 (cf. Ronde).
const COUCHE_JOUEURS := 1 << 4
const MASQUE_MONDE := 1
const COUCHE_PORTE_AVANT := 1 << 3
const COUCHE_PORTE_ARRIERE := 1 << 2

## Les rayons (viser, voir à travers, poser) passent à travers les joueurs : leurs capsules ne servent qu'à
## me barrer la route.
const SANS_JOUEURS := 0xFFFFFFFF & ~COUCHE_JOUEURS

## Les modes où l'on marche de son propre chef : seuls ceux-là butent sur les autres joueurs.
const MODES_LIBRES := ["libre", "chambre"]
## Les modes où l'on peut s'accroupir : debout, en liberté ou à son poste de quête.
const MODES_ACCROUPI := ["libre", "chambre", "poste"]

const FACTEUR_VITESSE_ACCROUPI := 0.5
const BAISSE_YEUX_ACCROUPI := 0.55


## Seul, à s'entraîner, le menu pause fige la partie. En ligne, il n'arrête rien : les autres jouent.
static func pause_fige(en_ligne: bool, etape: String) -> bool:
	return etape == "pause" and not en_ligne


## Ce que mon corps heurte. Enchaîné : rien. Fantôme : le monde (autel, rondins, arbres, sol…) comme un vivant ;
## il ne traverse que les maisons : leurs murs (cf. Ronde.murs_maisons, écartés un par un) et leurs portes (pas
## de couche de porte dans son masque) ; Edwin, 03/11. Marche guidée : le monde seulement (pas de porte, pas
## de joueur : on ne reste pas coincé derrière quelqu'un). Sinon le monde et les portes ; et les autres
## joueurs seulement si je suis vivant, debout et libre de mes mouvements (ni assis au bord d'un lit, ni en
## cinématique).
static func masque(mode: String, vivant: bool, assis_libre: bool, cinematique: bool) -> int:
	if mode == "attache":
		return 0
	if mode == "fantome":
		return MASQUE_MONDE
	if mode == "guide":
		return MASQUE_MONDE
	var m := MASQUE_MONDE | COUCHE_PORTE_AVANT | COUCHE_PORTE_ARRIERE
	if mode in MODES_LIBRES and vivant and not assis_libre and not cinematique:
		m |= COUCHE_JOUEURS
	return m


## Le corps d'un autre joueur est-il solide pour moi ? Visible, vivant (un mort n'est qu'un fantôme).
static func solide(visible: bool, vivant: bool) -> bool:
	return visible and vivant


## Peut-on s'accroupir ? Pas assis, pas en fantôme, pas enchaîné ni guidé.
static func peut_s_accroupir(mode: String, vivant: bool, assis_libre: bool) -> bool:
	return vivant and not assis_libre and mode in MODES_ACCROUPI


## Faut-il être accroupi cette image ? `verrou` : une animation nous a relevés, on reste debout jusqu'à ce
## que la touche soit relâchée.
static func accroupi(touche: bool, peut: bool, verrou: bool) -> bool:
	return touche and peut and not verrou


## Le verrou après cette image : posé par une animation en cours (si la touche est tenue), levé au relâchement.
static func verrou(avant: bool, touche: bool, animation_en_cours: bool) -> bool:
	return touche and (avant or animation_en_cours)


static func vitesse_accroupi(accroupi_: bool) -> float:
	return FACTEUR_VITESSE_ACCROUPI if accroupi_ else 1.0


## La marche guidée attend d'avoir les pieds au sol : sauter juste avant qu'elle démarre ne fait pas courir en l'air.
static func guide_attend_le_sol(mode: String, en_l_air: bool) -> bool:
	return mode == "guide" and en_l_air


## Les pieds ont-ils quitté le sol ? (`y` : hauteur du sol sous le joueur ; `sur_sol` : le moteur le dit)
static func en_l_air(y: float, hauteur_sol: float, sur_sol: bool) -> bool:
	return not sur_sol and y - hauteur_sol > 0.05


## Marche guidée (le corps marche tout seul vers sa maison) : le joueur doit pouvoir REGARDER où il veut
## (Edwin, 01/11 : « on ne peut pas bouger la tête »). Le corps tourne de `d_corps` radians vers le chemin ; la
## tête (tournée par la souris, relative au corps) est contre-tournée de la même quantité tant que la souris a
## bougé il y a peu : la vue reste là où le joueur l'a mise. Sans souris depuis `DELAI_REGARD_LIBRE`, la tête
## revient doucement face au corps (vers 0), comme avant. Renvoie le nouveau lacet de la tête.
const DELAI_REGARD_LIBRE := 3.0
const LACET_MAX_GUIDE := 1.5
const RETOUR_REGARD := 1.5         # par seconde


static func guide_lacet_tete(lacet: float, d_corps: float, depuis_souris: float, delta: float) -> float:
	if depuis_souris < DELAI_REGARD_LIBRE:
		return clampf(lacet - d_corps, -LACET_MAX_GUIDE, LACET_MAX_GUIDE)
	return lerpf(lacet, 0.0, clampf(delta * RETOUR_REGARD, 0.0, 1.0))


## Quand la marche guidée s'arrête, la tête ne doit pas rester tournée de travers (Edwin, 01/11 : « mon personnage
## regarde de travers »). On reporte son lacet sur le corps : la vue ne bouge pas, la tête redevient droite.
## Renvoie [nouveau lacet du corps, nouveau lacet de la tête].
static func fin_de_marche(lacet_corps: float, lacet_tete: float) -> Array:
	return [lacet_corps + lacet_tete, 0.0]
