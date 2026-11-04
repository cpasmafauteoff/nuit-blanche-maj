class_name Marcheur
extends RefCounted
## Le suivi des pas d'UN corps (soi, un bot, un autre joueur), image après image (retour d'Edwin 02/11 :
## « je n'entends toujours pas mes pas ni ceux des bots, sauf à la course automatique »).
##
## Cause mesurée : le corps se déplace dans _physics_process (60 Hz) alors que les pas se comptent à
## chaque image rendue (95 Hz et plus) : une image sur trois ne voit aucun déplacement (d = 0), et l'ancien
## code y remettait la distance parcourue à zéro. La foulée n'était JAMAIS atteinte en marche libre.
## Ici la vitesse se mesure sur une fenêtre de temps (FENETRE), jamais sur une seule image, et un arrêt
## ne se déclare que si la fenêtre entière est immobile. Règles pures, testées sans moteur.

const FENETRE := 0.15          # s : durée sur laquelle la vitesse se mesure

var pos := Vector3.ZERO
var _pret := false
var dist := 0.0                # m parcourus depuis le dernier pas
var vit := 0.0                 # m/s sur la dernière fenêtre complète
var _fen_d := 0.0
var _fen_t := 0.0
var _haut_max := 0.0
var _en_l_air := false

## Résultats de la dernière image : "" / "marche" / "course" ; hauteur de chute (m) si on vient de toucher
## le sol après un saut (0 sinon).
var pas := ""
var chute := 0.0


## À appeler une fois par image avec la position du corps, le temps écoulé et la hauteur au-dessus du sol d'ICI.
func avancer(p: Vector3, delta: float, hauteur: float) -> void:
	pas = ""
	chute = 0.0
	if not _pret:
		_pret = true
		pos = p
		return
	var d := Vector2(p.x - pos.x, p.z - pos.z).length()
	pos = p
	if delta <= 0.0:
		return
	if d > Foulee.SAUT_MAX:     # téléporté (placement) : on repart de zéro
		dist = 0.0
		vit = 0.0
		_fen_d = 0.0
		_fen_t = 0.0
		return
	if hauteur > Foulee.EN_L_AIR:
		_haut_max = maxf(_haut_max, hauteur)
		_en_l_air = true
		_fen_d = 0.0
		_fen_t = 0.0
		return
	if _en_l_air:
		_en_l_air = false
		if _haut_max >= Foulee.CHUTE_MIN:
			chute = _haut_max
		_haut_max = 0.0
		dist = 0.0
		return
	_fen_d += d
	_fen_t += delta
	if _fen_t >= FENETRE:
		vit = _fen_d / _fen_t
		_fen_d = 0.0
		_fen_t = 0.0
		if vit < Foulee.SEUIL_IMMOBILE:
			dist = 0.0
	if vit < Foulee.SEUIL_IMMOBILE:
		return
	dist += d
	if dist >= Foulee.longueur(vit):
		dist = 0.0
		pas = "course" if vit > Foulee.SEUIL_COURSE else "marche"
