class_name TchatLobby
extends RefCounted
## Le tchat écrit du lobby (seulement là, jamais en partie). Logique pure, côté hôte : nettoyer le
## texte, borner sa longueur et freiner le spam avant de le relayer à tous.

const LONGUEUR_MAX := 200
## Deux messages d'un même joueur : au moins ce délai entre les deux (secondes)…
const INTERVALLE_MIN := 0.6
## …et jamais plus de RAFALE messages dans la FENETRE.
const RAFALE := 5
const FENETRE := 8.0
## Le même texte répété coup sur coup est refusé pendant ce délai.
const REPETITION := 5.0

var _envois := {}      # id -> Array[float] (instants des derniers messages acceptés)
var _dernier := {}     # id -> [texte, instant]


## Retire les retours à la ligne et caractères de contrôle, rogne les bords, coupe à la longueur max.
static func nettoyer(texte: String) -> String:
	var sortie := ""
	for i in texte.length():
		var c := texte.unicode_at(i)
		if c < 32 or c == 127:
			sortie += " "
		else:
			sortie += texte[i]
	sortie = sortie.strip_edges()
	if sortie.length() > LONGUEUR_MAX:
		sortie = sortie.substr(0, LONGUEUR_MAX).strip_edges()
	return sortie


## Le texte à relayer, ou "" s'il est vide / trop rapproché du précédent / répété.
func accepter(id: int, texte: String, maintenant: float) -> String:
	var t := nettoyer(texte)
	if t == "":
		return ""
	var recents: Array = _envois.get(id, [])
	recents = recents.filter(func(x): return maintenant - float(x) < FENETRE)
	if not recents.is_empty() and maintenant - float(recents.back()) < INTERVALLE_MIN:
		_envois[id] = recents
		return ""
	if recents.size() >= RAFALE:
		_envois[id] = recents
		return ""
	var d: Array = _dernier.get(id, ["", -999.0])
	if d[0] == t and maintenant - float(d[1]) < REPETITION:
		return ""
	recents.append(maintenant)
	_envois[id] = recents
	_dernier[id] = [t, maintenant]
	return t


func oublier(id: int) -> void:
	_envois.erase(id)
	_dernier.erase(id)


## Un texte sûr pour un RichTextLabel en BBCode : les crochets ne s'interprètent jamais.
static func echapper(texte: String) -> String:
	return texte.replace("[", "[lb]")
