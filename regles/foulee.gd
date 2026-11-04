class_name Foulee
extends RefCounted
## Les bruits de pas (retour d'Edwin, 01/11 : « les personnages ne font pas de bruit quand ils marchent
## ou courent »). Règles pures, testées sans moteur (tests/test_foulee.gd).
##
## Ce qui compte, c'est le déplacement RÉEL du corps (position d'une image à l'autre) : marche libre,
## marche guidée, trajet automatique, bots et autres joueurs passent donc tous par la même règle.

const SEUIL_IMMOBILE := 0.3     # m/s : en dessous, on ne marche pas (poste d'un mini-jeu, balancement)
const SEUIL_COURSE := 4.0       # m/s : au-dessus, c'est une course
const SAUT_MAX := 2.0           # m en une image : téléporté (placement), pas un pas
const EN_L_AIR := 0.12          # m au-dessus du sol : en plein saut, pas de pas

## Volumes (dB) : la marche est douce, la course nette ; ses propres pas sont plus discrets que ceux
## qu'on entend des autres (ils sont à 3D, atténués par la distance).
## Les échantillons de pas sont à pleine échelle (crête ~0,8 jouée à 0 dB, mesuré au bus Master) : la marche à
## -12 dB donne une crête ~0,2, la course à -5 dB ~0,45. Les pas des autres passent par un lecteur 3D qui perd
## ~-12 dB à 1 m et ~-35 dB à 8 m même sans filtre : d'où leurs valeurs plus hautes.
const DB_SOI_MARCHE := -12.0
const DB_SOI_COURSE := -5.0
const DB_AUTRE_MARCHE := 5.0
const DB_AUTRE_COURSE := 12.0
const UNITE_3D := 3.0           # m : distance de référence du pas d'un autre (atténuation en 1/d)
const PORTEE_3D := 30.0         # m : au-delà, on n'entend plus rien
const CHUTE_MIN := 0.15         # m : en dessous, une simple marche sur une marche, pas un atterrissage


## "" (pas de pas), "marche" ou "course" pour un déplacement horizontal `d` (m) en `delta` s,
## le corps étant à `hauteur` m au-dessus du sol (0 = au sol, y compris sur la terrasse du temple).
static func allure(d: float, delta: float, hauteur: float) -> String:
	if delta <= 0.0 or d > SAUT_MAX or hauteur > EN_L_AIR:
		return ""
	var v := d / delta
	if v < SEUIL_IMMOBILE:
		return ""
	return "course" if v > SEUIL_COURSE else "marche"


## Distance (m) entre deux pas : la foulée s'allonge avec la vitesse, donc la cadence (pas par
## seconde) monte avec elle sans s'emballer : 3,2 m/s -> ~0,35 s entre deux pas ; 5 m/s -> ~0,3 s.
static func longueur(vitesse: float) -> float:
	return clampf(0.55 + 0.2 * vitesse, 0.9, 1.9)


## Le volume d'un pas (dB), avant atténuation de distance pour les autres.
static func volume_db(est_soi: bool, allure_: String) -> float:
	if allure_ == "course":
		return DB_SOI_COURSE if est_soi else DB_AUTRE_COURSE
	return DB_SOI_MARCHE if est_soi else DB_AUTRE_MARCHE


## Ce pas doit-il s'entendre ? Un fantôme (soi) ne fait pas de bruit ; la nuit, les villageois vivants
## se taisent pour les autres villageois vivants (le bruit des loups passe par les combinaisons) ;
## un autre qui est mort ne s'entend que des morts.
static func sonne(est_soi: bool, moi_vivant: bool, nuit_muette: bool, acteur_audible: bool) -> bool:
	if est_soi:
		return moi_vivant
	return not nuit_muette and acteur_audible


## Le bruit d'un atterrissage après un saut (dB) : plus fort quand la chute est haute (plafonné à 3 m).
static func volume_atterrissage(est_soi: bool, chute: float) -> float:
	var base := (DB_SOI_COURSE if est_soi else DB_AUTRE_COURSE) - 1.0
	return base + 4.0 * minf(maxf(chute, 0.0), 3.0)


## La hauteur de la note : une chute haute sonne plus grave et plus lourde.
static func pitch_atterrissage(chute: float) -> float:
	return clampf(0.95 - 0.08 * chute, 0.7, 0.95)
