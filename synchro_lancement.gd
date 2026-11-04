class_name SynchroLancement
extends RefCounted
## La synchronisation du lancement (côté hôte) : tout le monde charge le village pendant la scène
## d'attente, et personne ne démarre avant que tous soient prêts, sans jamais dépasser un délai.
## Au moins MIN_S (pour que la scène se lise), au plus MAX_S (un joueur muet ne bloque pas les autres).

const MIN_S := 8.0
const MAX_S := 45.0

var ecoule := 0.0
var attendus: Array = []       # les joueurs humains présents
var prets := {}                # id -> true


func demarrer(ids: Array) -> void:
	ecoule = 0.0
	attendus = ids.duplicate()
	prets = {}


func ajouter(id: int) -> void:
	if not attendus.has(id):
		attendus.append(id)


func retirer(id: int) -> void:
	attendus.erase(id)
	prets.erase(id)


## Un joueur dit que son village est construit. Un inconnu est ignoré.
func signaler(id: int) -> bool:
	if not attendus.has(id) or prets.has(id):
		return false
	prets[id] = true
	return true


func avancer(delta: float) -> void:
	ecoule += delta


func tous_prets() -> bool:
	for id in attendus:
		if not prets.has(id):
			return false
	return true


## Le top de départ : tous prêts et le minimum écoulé, ou le délai maximal atteint.
func pret_a_lancer() -> bool:
	return (tous_prets() and ecoule >= MIN_S) or ecoule >= MAX_S


## Ceux qu'on lance sans les avoir entendus.
func retardataires() -> Array:
	return attendus.filter(func(id): return not prets.has(id))


func etat() -> Dictionary:
	return {"prets": prets.keys(), "attendus": attendus.duplicate(), "min": MIN_S, "max": MAX_S}
