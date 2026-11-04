class_name TamponEtats
extends RefCounted
## Les états d'un joueur distant, rangés par l'heure où IL les a envoyés.
##
## On affiche toujours ce qu'il faisait il y a DELAI secondes, en interpolant entre les deux
## états qui encadrent ce moment : le mouvement reste fluide malgré les paquets qui arrivent
## par à-coups, et rien ne peut s'accumuler — un état trop vieux est jeté, jamais rejoué.
##
## Les horloges des deux PC n'ont rien en commun : l'écart se déduit du plus petit
## (réception - envoi) des dernières secondes, c'est-à-dire du paquet le plus rapide.

const DELAI := 0.1          # marge d'interpolation
const GARDE := 1.0          # on ne garde qu'une seconde d'états
const FENETRE_ECART := 4.0  # l'écart d'horloge se réévalue sur 4 s

var _etats: Array = []      # [t_envoi, etat] du plus ancien au plus récent
var _ecarts: Array = []     # [reçu, reçu - envoi]
var ecart := INF
var dernier_recu := -INF


## Un état reçu. Faux s'il est plus vieux que le dernier (arrivé dans le désordre) : on le jette.
func ajouter(t_envoi: float, recu: float, etat: Dictionary) -> bool:
	if not _etats.is_empty() and t_envoi <= float(_etats[-1][0]):
		return false
	_etats.append([t_envoi, etat])
	dernier_recu = recu
	_ecarts.append([recu, recu - t_envoi])
	while not _ecarts.is_empty() and recu - float(_ecarts[0][0]) > FENETRE_ECART:
		_ecarts.pop_front()
	ecart = INF
	for e: Array in _ecarts:
		ecart = minf(ecart, float(e[1]))
	while _etats.size() > 2 and t_envoi - float(_etats[0][0]) > GARDE:
		_etats.pop_front()
	return true


func vide() -> bool:
	return _etats.is_empty()


## Retard du dernier état sur le plus rapide des dernières secondes (gigue), en secondes.
func gigue() -> float:
	if _ecarts.is_empty():
		return 0.0
	return float(_ecarts[-1][1]) - ecart


## Ce qu'il faut afficher maintenant (horloge locale) : position et cap interpolés.
func echantillon(maintenant: float) -> Dictionary:
	if _etats.is_empty():
		return {}
	var rendu := maintenant - ecart - DELAI
	var dernier: Array = _etats[-1]
	if rendu >= float(dernier[0]) or _etats.size() == 1:
		return dernier[1]
	if rendu <= float(_etats[0][0]):
		return _etats[0][1]
	for i in range(_etats.size() - 1, 0, -1):
		var a: Array = _etats[i - 1]
		if float(a[0]) <= rendu:
			var b: Array = _etats[i]
			var k := (rendu - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-6)
			return _melanger(a[1], b[1], k)
	return dernier[1]


static func _melanger(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var d := b.duplicate()
	if a.has("pos") and b.has("pos"):
		d["pos"] = (a["pos"] as Vector3).lerp(b["pos"], k)
	if a.has("yaw") and b.has("yaw"):
		d["yaw"] = lerp_angle(float(a["yaw"]), float(b["yaw"]), k)
	if a.has("pitch") and b.has("pitch"):
		d["pitch"] = lerpf(float(a["pitch"]), float(b["pitch"]), k)
	return d
