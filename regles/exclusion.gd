class_name Exclusion
extends RefCounted
## L'exclusion d'un joueur (décision d'Edwin, 31/10) : l'hôte exclut qui il veut ; les autres
## joueurs lancent un VOTE visible de tous les humains. Règles pures, côté HÔTE, sans nœud
## (tests/test_exclusion.gd).
##
##   - jamais contre l'hôte, jamais contre soi, jamais contre un bot (il n'y a personne à exclure) ;
##   - un seul vote à la fois ; 90 s d'attente pour celui qui vient d'en demander un ;
##   - le vote dure 30 s ; les bots ne votent pas ;
##   - exclusion si PLUS DE LA MOITIÉ des humains hors la cible votent « oui » (un silence compte
##     « non ») ; celui qui demande vote « oui » d'office.

const DUREE_VOTE := 30.0
const ATTENTE := 90.0

var cible := -1                 # -1 : aucun vote en cours
var demandeur := -1
var reste := 0.0
var electeurs: Array[int] = []  # les humains hors la cible, au moment de la demande
var votes := {}                 # id -> bool
var _derniere := {}             # demandeur -> instant de sa dernière demande (secondes)


func en_cours() -> bool:
	return cible >= 0


## « oui » nécessaires : strictement plus de la moitié des électeurs.
static func seuil(n_electeurs: int) -> int:
	return n_electeurs / 2 + 1


## Verdict avec les voix connues. "exclu" dès que le « oui » est acquis, "refuse" dès qu'il est
## devenu impossible, "" tant que tout peut encore changer. `fini` : le temps est écoulé (le
## silence compte « non »).
static func verdict_de(n_electeurs: int, oui: int, non: int, fini: bool) -> String:
	var besoin := seuil(n_electeurs)
	if oui >= besoin:
		return "exclu"
	if fini or n_electeurs - non < besoin:
		return "refuse"
	return ""


## Pourquoi on ne peut pas lancer ce vote ("" : on peut). `humains` : les ids humains présents.
func refus_demande(par: int, contre: int, hote: int, humains: Array, maintenant: float) -> String:
	if en_cours():
		return "Un vote d'exclusion est déjà en cours."
	if contre == hote:
		return "On ne peut pas exclure l'hôte."
	if par == contre:
		return "Tu ne peux pas demander ta propre exclusion."
	if not humains.has(contre) or not humains.has(par):
		return "Ce joueur n'est plus là."
	if par == hote:
		return "L'hôte n'a pas besoin de vote : il exclut directement."
	var attente := attente_restante(par, maintenant)
	if attente > 0.0:
		return "Patiente encore %d s avant de relancer un vote." % ceili(attente)
	return ""


func attente_restante(par: int, maintenant: float) -> float:
	if not _derniere.has(par):
		return 0.0
	return maxf(0.0, ATTENTE - (maintenant - float(_derniere[par])))


## Ouvre le vote. Rend "" ou la raison du refus.
func demander(par: int, contre: int, hote: int, humains: Array, maintenant: float) -> String:
	var refus := refus_demande(par, contre, hote, humains, maintenant)
	if refus != "":
		return refus
	cible = contre
	demandeur = par
	reste = DUREE_VOTE
	electeurs.clear()
	for h: int in humains:
		if h != contre:
			electeurs.append(h)
	votes = {par: true}
	_derniere[par] = maintenant
	return ""


## Un humain répond. Faux si ce n'est pas à lui de voter (cible, bot, étranger, pas de vote) ou si
## sa réponse ne change rien (rien à republier).
func voter(id: int, oui: bool) -> bool:
	if not en_cours() or not electeurs.has(id):
		return false
	if votes.has(id) and votes[id] == oui:
		return false
	votes[id] = oui
	return true


## Un joueur s'en va : s'il était la cible, le vote tombe ; sinon il ne compte plus.
func oublier(id: int) -> void:
	_derniere.erase(id)
	if not en_cours():
		return
	if id == cible:
		annuler()
		return
	electeurs.erase(id)
	votes.erase(id)


func annuler() -> void:
	cible = -1
	demandeur = -1
	reste = 0.0
	electeurs.clear()
	votes = {}


func nb_oui() -> int:
	var n := 0
	for id: int in electeurs:
		if votes.get(id, false):
			n += 1
	return n


func nb_non() -> int:
	var n := 0
	for id: int in electeurs:
		if votes.has(id) and not votes[id]:
			n += 1
	return n


## "", "exclu" ou "refuse" ; l'hôte appelle `annuler` après avoir agi.
func verdict() -> String:
	if not en_cours():
		return ""
	if electeurs.is_empty():
		return "refuse"
	return verdict_de(electeurs.size(), nb_oui(), nb_non(), reste <= 0.0)


func avancer(delta: float) -> void:
	if en_cours():
		reste -= delta


## Ce que tous voient (petite fenêtre) : la cible (par son bandeau, côté interface), le temps, les
## voix déjà données — pas qui a voté quoi : seulement le décompte.
func etat() -> Dictionary:
	if not en_cours():
		return {}
	return {"cible": cible, "demandeur": demandeur, "reste": maxf(0.0, reste), "electeurs": electeurs.duplicate(),
		"a_vote": votes.keys(), "oui": nb_oui(), "non": nb_non(), "besoin": seuil(electeurs.size())}
