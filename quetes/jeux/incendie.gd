extends MiniJeu
## L'Incendie du hameau : PLUSIEURS foyers (la grange, la meule de foin, l'étable, l'atelier, le fenil) et
## un feu qui SE PROPAGE d'un bâtiment à l'autre. Une chaîne de seaux, les joueurs dans un ordre fixe :
## un seau arrive du puits entre les mains du premier, qui doit le lancer au suivant dans un court délai,
## et ainsi de suite jusqu'au dernier, qui le jette sur le foyer qu'il VISE (au regard). Trop tard : le
## seau se renverse. Chaque foyer a son intensité ; un bâtiment qui atteint le maximum est PERDU, et trop
## de bâtiments perdus font échouer la quête. Un foyer chaud (> 55 %) chauffe ses voisins, qui finissent
## par s'embraser : il faut choisir où jeter l'eau.
## Tous les foyers éteints : réussissent ceux qui ont passé la plupart de leurs seaux à temps.
## Sabotage : « Renverser » (le seau du seul saboteur) vide le seau qu'il tient ; le dernier de la chaîne
## peut aussi viser le mauvais foyer ; tout le monde lit la même phrase qu'un seau lâché trop tard.
## La durée vient de DimGestes.incendie_plan : le puits ne donne qu'un seau toutes les `intervalle`
## secondes, et il faut au moins `incendie_seaux_min` seaux pour éteindre les foyers de départ : une
## partie ne peut pas durer moins de `incendie_temps_min` (au-dessus du minimum du niveau).

const CHAUD := 0.55          # au-dessus, un foyer chauffe ses voisins

var ordre: Array[int] = []   # la chaîne, de la source au feu
var seaux: Array = []        # [{"main": position dans la chaîne, "recu": instant}]
var plan := {}
var foyers: Array = []       # [{"nom", "voisins": [..], "f": 0..1, "etat": "sain"|"feu"|"ruine", "chaleur": float}]
var perdus := 0
var delai := 3.5             # temps accordé pour passer un seau
var intervalle := 4.5        # un nouveau seau toutes les…
var passes := {}             # id -> seaux passés à temps
var ratees := {}             # id -> seaux lâchés trop tard
var deverses := 0
var jetes := 0               # seaux arrivés sur un foyer
var annonce := ""
var _annonce_t := 0.0
var _prochain := 0.0
var _eteint := false
## Temps de geste d'un bot (s) : lancer le seau au voisin ; se tourner et viser le foyer pour le dernier.
const RYTHME_LANCER := 0.3
const RYTHME_VISER := 0.4
var _dernier := {}           # bot -> instant de son dernier geste
var _regret := {}            # bot -> jusqu'à quand il est secoué par une erreur
var _sabo_apres := {}        # saboteur -> pas de nouveau sabotage avant cet instant


func demarrer() -> void:
	_init_vies()
	plan = DimGestes.incendie_plan(niveau)
	# Chaque incendie a son allure : seaux plus ou moins serrés.
	var allure := rng.randf_range(0.93, 1.07)
	delai = float(plan["delai"]) * allure
	intervalle = float(plan["intervalle"])
	duree = Quetes.duree_max(niveau)
	for k in int(plan["foyers"]):
		var m: Dictionary = DimGestes.I_FOYERS[k]
		foyers.append({"nom": m["nom"], "voisins": m["voisins"], "f": 0.0, "etat": "sain", "chaleur": 0.0})
	for d: Array in plan["depart"]:
		foyers[int(d[0])]["f"] = float(d[1])
		foyers[int(d[0])]["etat"] = "feu"
	ordre.assign(ids)
	for i in range(ordre.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var x: int = ordre[i]
		ordre[i] = ordre[j]
		ordre[j] = x
	for id in ids:
		passes[id] = 0
		ratees[id] = 0
	seaux.append({"main": 0, "recu": 0.0})
	_prochain = intervalle


func _dire(m: String) -> void:
	annonce = m
	_annonce_t = 2.8


## Le plus ancien seau tenu par la position k, ou -1.
func _seau_en_main(k: int) -> int:
	for i in seaux.size():
		if int(seaux[i]["main"]) == k:
			return i
	return -1


func _renverser(i: int) -> void:
	seaux.remove_at(i)
	deverses += 1
	_dire("Un seau s'est renversé")
	perdre_vie()          # niveau dur : un seau renversé coûte une vie à l'équipe


## Un fantôme renverse le seau qu'il porte.
func _hanter(id: int) -> String:
	var i := _seau_en_main(ordre.find(id))
	if i < 0:
		return super._hanter(id)
	_renverser(i)
	return "Le seau de %s se renverse tout seul." % nom(id)


## Le foyer en feu le plus chaud (ou -1).
func foyer_urgent() -> int:
	var meilleur := -1
	for k in foyers.size():
		if foyers[k]["etat"] == "feu" and (meilleur < 0 or float(foyers[k]["f"]) > float(foyers[meilleur]["f"])):
			meilleur = k
	return meilleur


func _jeter(cible: int) -> void:
	jetes += 1
	if cible < 0 or cible >= foyers.size() or foyers[cible]["etat"] != "feu":
		cible = foyer_urgent()
	if cible < 0:
		return          # plus rien à éteindre : le seau tombe dans la cendre
	var f: Dictionary = foyers[cible]
	f["f"] = maxf(float(f["f"]) - float(plan["reduction"]), 0.0)
	if float(f["f"]) <= 0.0:
		f["etat"] = "sain"
		f["chaleur"] = 0.0
		_dire("%s : le feu est éteint !" % str(f["nom"]).capitalize())


func action(id: int, d: Dictionary) -> void:
	if fini or not ids.has(id):
		return
	var k: int = ordre.find(id)
	var i: int = _seau_en_main(k)
	if k < 0 or i < 0:
		return
	if d.has("passer"):
		passes[id] += 1
		var s: Dictionary = seaux[i]
		if k >= ordre.size() - 1:
			seaux.remove_at(i)
			var cible: int = int(d.get("foyer", -1))
			# Un saboteur au bout de la chaîne peut viser le foyer le plus froid (sans que ça se voie).
			_jeter(cible)
		else:
			s["main"] = k + 1
			s["recu"] = temps
			s.erase("agit")
			s.erase("vise")
			s.erase("sabo")
	elif d.has("renverser") and peut_saboter(id):
		_renverser(i)


func _propager(delta: float) -> void:
	for k in foyers.size():
		var f: Dictionary = foyers[k]
		if f["etat"] == "feu":
			f["f"] = minf(float(f["f"]) + float(plan["croissance"]) * delta, 1.0)
			if float(f["f"]) >= 1.0:
				f["etat"] = "ruine"
				perdus += 1
				_dire("%s s'effondre !" % str(f["nom"]).capitalize())
				perdre_vie()
			elif float(f["f"]) > CHAUD:
				for v: int in f["voisins"]:
					var w: Dictionary = foyers[v] if v < foyers.size() else {}
					if not w.is_empty() and w["etat"] == "sain":
						w["chaleur"] = float(w["chaleur"]) + delta * float(f["f"])
						if float(w["chaleur"]) >= float(plan["chauffe"]):
							w["etat"] = "feu"
							w["f"] = 0.15
							_dire("Le feu gagne %s !" % str(w["nom"]))


func avancer(delta: float) -> void:
	if fini:
		return
	_propager(delta)
	if temps >= _prochain:
		_prochain += intervalle
		seaux.append({"main": 0, "recu": temps})
	for i in range(seaux.size() - 1, -1, -1):
		if temps - float(seaux[i]["recu"]) > delai:
			ratees[ordre[int(seaux[i]["main"])]] += 1
			_renverser(i)
	if perdus >= int(plan["ruines"]):
		terminer()
		return
	if foyer_urgent() < 0:
		_eteint = true
		var frac: float = {"simple": 0.6, "normal": 0.7, "dur": 0.75, "extreme": 0.8}[niveau]
		for id in ids:
			var recus: int = int(passes[id]) + int(ratees[id])
			_reussis[id] = recus == 0 or int(passes[id]) >= int(ceil(recus * frac))
		terminer()
		return
	_annonce_t -= delta
	if _annonce_t <= 0.0:
		annonce = ""
	super.avancer(delta)


func equipe_reussit() -> bool:
	return _eteint and perdus < int(plan["ruines"]) and super.equipe_reussit()


## Le feu d'ensemble, 0..1 : la moyenne des foyers (un bâtiment perdu compte pour 1).
func feu_total() -> float:
	var s := 0.0
	for f: Dictionary in foyers:
		s += 1.0 if f["etat"] == "ruine" else float(f["f"])
	return s / maxf(float(foyers.size()), 1.0)


func vue_pour(id: int) -> Dictionary:
	var k: int = ordre.find(id)
	var dernier: bool = k == ordre.size() - 1
	var blocs := []
	var avant: String = "Les seaux arrivent du puits jusqu'à toi." if k == 0 else "Tu reçois les seaux de %s." % nom(ordre[maxi(k - 1, 0)])
	var apres: String = "Tu les jettes sur le foyer que tu vises : choisis le plus dangereux." if dernier else "Tu les passes à %s." % nom(ordre[mini(k + 1, ordre.size() - 1)])
	blocs.append(MiniJeu.texte(avant, 18, "gris"))
	blocs.append(MiniJeu.texte(apres, 18, "gris"))
	var i: int = _seau_en_main(k)
	var action_passer := {"passer": true}
	if dernier:
		action_passer["jet"] = true
	if i >= 0:
		var rest: float = maxf(delai - (temps - float(seaux[i]["recu"])), 0.0)
		blocs.append(MiniJeu.texte("UN SEAU ! Lance-le vite : %.1f s" % rest, 26, "or"))
		blocs.append(MiniJeu.boutons([MiniJeu.bouton("Seau plein", action_passer)], 28))
	else:
		blocs.append(MiniJeu.texte("Pas de seau dans tes mains.", 22, "gris"))
		blocs.append(MiniJeu.boutons([MiniJeu.bouton("Seau plein", action_passer, true, "gris")], 28))
	if peut_saboter(id):
		blocs.append(MiniJeu.boutons([MiniJeu.bouton("Renverser", {"renverser": true}, i < 0, "gris")], 16))
	blocs.append(MiniJeu.jauge(feu_total(), "Le feu", [], "rouge"))
	var en_feu := 0
	for f: Dictionary in foyers:
		en_feu += 1 if f["etat"] == "feu" else 0
	blocs.append(MiniJeu.texte("Foyers en feu : %d · bâtiments perdus : %d / %d" % [en_feu, perdus, int(plan["ruines"])], 16, "rouge" if perdus >= int(plan["ruines"]) - 1 and perdus > 0 else "gris"))
	if annonce != "":
		blocs.append(MiniJeu.texte(annonce, 24, "rouge"))
	blocs.append(MiniJeu.texte("Seaux passés à temps : %d" % passes.get(id, 0), 16, "gris"))
	return {"consigne": "Formez la chaîne : passe chaque seau à ton voisin dès que tu le reçois. Le dernier jette l'eau sur le foyer qu'il vise : le feu se propage, éteignez d'abord le plus dangereux.", "blocs": blocs,
		"incendie": {"foyers": foyers.map(func(f): return [snappedf(float(f["f"]), 0.01), str(f["etat"])]), "dernier": dernier, "urgent": foyer_urgent()}}


## Un bot joue comme une personne (Edwin, 01/11) : il lève les yeux quand le seau arrive (temps de
## réaction), choisit son foyer d'après ce qu'il VOIT à ce moment-là, vise (un geste de plus pour celui qui
## jette), lance, et ne fait jamais deux gestes à moins de CADENCE_MIN. Une distraction laisse le seau
## tomber ; il souffle ensuite (REGRET) mais se dépêche si un autre seau arrive. Un saboteur renverse rarement.
func bot(id: int, _delta: float) -> void:
	if fini:
		return
	var k: int = ordre.find(id)
	var i: int = _seau_en_main(k)
	if k < 0 or i < 0:
		return
	var s: Dictionary = seaux[i]
	var dernier: bool = k == ordre.size() - 1
	if not s.has("agit"):
		var miss: float = {"simple": 0.01, "normal": 0.01, "dur": 0.006, "extreme": 0.008}[niveau]
		# Passer un seau au voisin est un réflexe (0,6 à 1,1 s) ; choisir et viser un foyer prend un vrai temps de réaction.
		var dec := float(s["recu"]) + (RythmeHumain.reaction(rng) + RYTHME_VISER if dernier else RythmeHumain.reaction(rng) * 0.6 + RYTHME_LANCER)
		if temps < float(_regret.get(id, 0.0)):
			# Encore secoué par son erreur : il se dépêche sans pouvoir être plus rapide qu'une personne.
			dec = minf(maxf(dec, float(_regret[id])), float(s["recu"]) + delai - 0.3)
		dec = RythmeHumain.geste_apres(float(_dernier.get(id, -10.0)), dec)
		s["agit"] = dec
		if dernier:
			s["vise"] = foyer_urgent()      # ce qu'il voit en levant les yeux
		if peut_saboter(id) and temps >= float(_sabo_apres.get(id, 0.0)) and rng.randf() < 0.04:
			s["sabo"] = true
			_sabo_apres[id] = temps + 40.0
		elif rng.randf() < miss:
			s["agit"] = float(s["recu"]) + delai + 5.0       # distrait : le seau tombe
			_regret[id] = float(s["recu"]) + delai + RythmeHumain.regret(rng)
	if temps < float(s["agit"]):
		return
	_dernier[id] = temps
	if s.has("sabo"):
		action(id, {"renverser": true})
		return
	var a := {"passer": true}
	if dernier:
		var cible: int = int(s.get("vise", -1))
		if peut_saboter(id) and temps >= float(_sabo_apres.get(id, 0.0)) and rng.randf() < 0.08:
			cible = _plus_froid()
			_sabo_apres[id] = temps + 40.0
		elif rng.randf() < 0.08:
			cible = rng.randi_range(0, foyers.size() - 1)       # il se trompe de bâtiment
		a["foyer"] = cible
	action(id, a)


func _plus_froid() -> int:
	var meilleur := -1
	for k in foyers.size():
		if foyers[k]["etat"] == "feu" and (meilleur < 0 or float(foyers[k]["f"]) < float(foyers[meilleur]["f"])):
			meilleur = k
	return meilleur
