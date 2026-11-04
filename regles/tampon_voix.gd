class_name TamponVoix
extends RefCounted
## Tampon anti-gigue de la voix reçue (8000 Hz). Pur calcul : voix.gd lui donne l'état du lecteur,
## il répond par les trames à pousser. Les paquets arrivent par rafales (un par 40 ms, mais groupés
## selon les images du jeu et le réseau) : sans réserve, le lecteur se vide entre deux rafales et on
## entend une radio qui hache. Une réserve adaptative absorbe la gigue ; si elle se vide quand même,
## on la grossit, et la coupure se fait en fondu (pas de claquement).

const TAUX := 8000
const MARGE_MIN := 0.07      # secondes de réserve à l'amorçage
const MARGE_MAX := 0.16
const RETARD_MAX := 0.22     # au-delà, le lecteur a trop de retard : on lâche le paquet
const FONDU := 0.004

var marge := MARGE_MIN
var _fin := 0.0              # dernier échantillon poussé (pour le fondu)
var _sans_vidage := 0.0      # secondes écoulées sans que le lecteur se vide
var _dernier_ms := -100000
## Compteurs (tests).
var vidages := 0
var laches := 0


## `en_tampon` : trames encore à jouer. `maintenant_ms` : horloge. Renvoie les trames à pousser
## (marge de silence éventuelle + paquet), ou un tableau vide si le paquet doit être lâché.
func preparer(ech: PackedFloat32Array, en_tampon: int, maintenant_ms: int) -> PackedFloat32Array:
	var ecoule := (maintenant_ms - _dernier_ms) / 1000.0
	_dernier_ms = maintenant_ms
	var sortie := PackedFloat32Array()
	if en_tampon > int(RETARD_MAX * TAUX):
		laches += 1
		return sortie
	_sans_vidage += ecoule
	if en_tampon <= 0:
		# Lecteur vide. Coupure en pleine phrase (peu de temps depuis le dernier paquet) : la réserve
		# était trop courte, on la grossit. Début de phrase : on repart de la réserve courante.
		if ecoule < 0.4:
			vidages += 1
			marge = minf(marge * 1.4, MARGE_MAX)
		_sans_vidage = 0.0
		var n_fondu := int(FONDU * TAUX)
		for i in range(n_fondu):
			sortie.append(_fin * (1.0 - float(i + 1) / n_fondu))
		var silence := maxi(int(marge * TAUX) - n_fondu, 0)
		var base := sortie.size()
		sortie.resize(base + silence)
		for i in range(silence):
			sortie[base + i] = 0.0
		# Fondu d'entrée sur le début du paquet.
		var e := ech.duplicate()
		for i in range(mini(n_fondu, e.size())):
			e[i] *= float(i + 1) / n_fondu
		sortie.append_array(e)
	else:
		sortie.append_array(ech)
		# Longtemps sans coupure : on peut réduire la réserve (moins de retard).
		if _sans_vidage > 4.0:
			marge = maxf(marge * 0.9, MARGE_MIN)
			_sans_vidage = 0.0
	if not ech.is_empty():
		_fin = ech[ech.size() - 1]
	return sortie
