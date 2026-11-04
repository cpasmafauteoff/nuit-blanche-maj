class_name Progression
extends RefCounted
## Le niveau de villageois (décision d'Edwin, 31/10) : chaque partie rapporte de l'expérience, le
## niveau monte, et quelques cosmétiques gratuits se débloquent en route. Sans rien d'affiché.
##
## Visé : niveau 10 vers 14 parties, niveau 30 vers 100 parties (une partie moyenne rapporte ~100).

const XP_PARTICIPER := 40       # aller au bout de la partie
const XP_PAR_NUIT := 4          # par nuit vécue…
const NUITS_MAX := 8            # …jusqu'à huit
const XP_SURVIVRE := 10         # être encore en vie à la fin
const XP_GAGNER := 25           # être du camp gagnant
const XP_PAR_QUETE := 10        # par quête réussie…
const QUETES_MAX := 5           # …jusqu'à cinq
const XP_ROLE_GAGNE := 10       # avoir gagné un rôle à une quête
const XP_ELU_MAIRE := 5         # avoir été élu maire
const NIVEAU_MAX := 60
## Expérience cumulée pour ATTEINDRE le niveau n : A·(n-1)² + B·(n-1).
const A := 9
const B := 64


## L'expérience d'une partie d'après les faits du joueur (cf. Succes.faits_partie) :
## {total, detail: [[libellé, xp]…]}. Rien n'est compté pour une fiche vide.
static func xp_partie(faits: Dictionary) -> Dictionary:
	var d := []
	if faits.is_empty():
		return {"total": 0, "detail": d}
	d.append(["Partie jouée", XP_PARTICIPER])
	var nuits := mini(int(faits.get("nuits", 0)), NUITS_MAX)
	if nuits > 0:
		d.append([("%d nuits vécues" if nuits > 1 else "%d nuit vécue") % nuits, nuits * XP_PAR_NUIT])
	if faits.get("vivant", false):
		d.append(["Encore en vie", XP_SURVIVRE])
	if faits.get("gagne", false):
		d.append(["Victoire", XP_GAGNER])
	var q := mini(int(faits.get("quetes", 0)), QUETES_MAX)
	if q > 0:
		d.append([("%d quêtes réussies" if q > 1 else "%d quête réussie") % q, q * XP_PAR_QUETE])
	if faits.get("role_gagne", false):
		d.append(["Rôle gagné à une quête", XP_ROLE_GAGNE])
	if faits.get("maire", false):
		d.append(["Élu maire", XP_ELU_MAIRE])
	var total := 0
	for l: Array in d:
		total += int(l[1])
	return {"total": total, "detail": d}


## L'expérience qu'il faut avoir pour atteindre ce niveau (niveau 1 : 0).
static func seuil(niveau: int) -> int:
	var n := clampi(niveau, 1, NIVEAU_MAX) - 1
	return A * n * n + B * n


static func niveau(xp: int) -> int:
	var n := 1
	while n < NIVEAU_MAX and xp >= seuil(n + 1):
		n += 1
	return n


## Où en est la barre : {niveau, dans (xp gagnée dans ce niveau), pour (xp qu'il faut dans ce niveau), ratio}.
static func barre(xp: int) -> Dictionary:
	var n := niveau(xp)
	if n >= NIVEAU_MAX:
		return {"niveau": n, "dans": 0, "pour": 0, "ratio": 1.0}
	var dans := xp - seuil(n)
	var pour := seuil(n + 1) - seuil(n)
	return {"niveau": n, "dans": dans, "pour": pour, "ratio": float(dans) / pour}


## Les articles gratuits qu'on gagne en passant de `avant` à `apres` (ids du catalogue).
static func articles_gagnes(avant: int, apres: int) -> Array:
	var l := []
	for a: Dictionary in Cosmetiques.ARTICLES:
		var n := int(a.get("niveau", 0))
		if n > avant and n <= apres:
			l.append(a["id"])
	return l


## Le prochain article gratuit à gagner depuis ce niveau, ou "" s'il n'y en a plus.
static func prochain_article(niveau_actuel: int) -> String:
	var meilleur := ""
	var n_min := 9999
	for a: Dictionary in Cosmetiques.ARTICLES:
		var n := int(a.get("niveau", 0))
		if n > niveau_actuel and n < n_min:
			n_min = n
			meilleur = a["id"]
	return meilleur
