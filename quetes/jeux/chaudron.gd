extends MiniJeu
## Le Chaudron : une recette en ordre, des ingrédients répartis entre les joueurs. Seul le lecteur
## du grimoire connaît l'ordre ; il le lit sur le PUPITRE (un vrai grimoire qu'il feuillette) et le
## dicte. Chacun possède quelques pots sur l'ÉTAGÈRE, du côté opposé à l'entrée : au bon moment, il
## MARCHE jusqu'à l'étagère, prend SON pot, marche jusqu'au chaudron et le VERSE (il tient son pot
## puis le bascule). Un mauvais ingrédient tourne la mixture : on recommence, une vie de moins, et
## le grimoire passe au joueur suivant.
## La réserve du jour : la recette, plus quelques ingrédients de trop (tirés des 40 du jeu,
## Catalogue.INGREDIENTS) que d'autres joueurs tiennent aussi — un lecteur menteur n'a qu'à en
## citer un, ça sonne juste. Tous les pots sont sur l'étagère, étiquetés ; on ne peut prendre que les
## siens (la liste « tes pots » est sur le parchemin).
## Règles du jour (au hasard) : un lecteur ; « Deux grimoires » (deux lecteurs, l'un a les
## étapes impaires, l'autre les paires — à partir de 4 joueurs) ; « Ingrédient double » (un
## ingrédient revient deux fois dans la recette — et celui qui tient ce pot le sait : si le
## lecteur ne le fait jamais verser deux fois, ou trois, il y a un menteur).
## Sabotage : une pincée de poudre noire (le saboteur seul a le sachet, il verse sans pot en main)
## ou mentir en lisant. Tous les autres lisent la même phrase : « Le chaudron tourne au noir ! ».
## Actions : {"prendre": ing} · {"poser": true} · {"verser": ing} · {"pincee": true}. Les pieds des
## joueurs (`pieds`, lus par l'hôte) décident de ce qui est à portée : étagère, chaudron.
## Le temps limite est `Quetes.duree_max(niveau)` ; la recette est assez longue (cf. `nb_etapes`)
## pour qu'une équipe qui joue bien mette au moins `Quetes.duree_min(niveau)`.

const INGREDIENTS := Catalogue.INGREDIENTS
## Rythme des bots (secondes) : annoncer, poser/prendre un pot, basculer le pot.
const BOT_LECTURE := 4.5
const BOT_GESTE := 1.2
const BOT_VERSE := 2.0

var recette: Array[int] = []
var reserve: Array[int] = []   # tout ce qu'on peut verser aujourd'hui (recette + ingrédients de trop)
var proprio := {}              # ingrédient -> id du joueur qui le tient
var main := {}                 # id -> l'ingrédient dont il tient le pot (-1 : rien)
var etape := 0                 # prochain ingrédient attendu
var vies := 3
var vies_depart := 3           # pour le décor : combien de pots de départ
var lecteur_i := 0
var annonce := ""
var verses := 0                # combien d'ingrédients justes depuis le début (le décor s'en sert)
var dernier := -1              # le dernier ingrédient juste
var gachis := 0                # combien de fois la mixture a tourné au noir
var _annonce_t := 0.0
var _bot_t := {}
var _bot_dit := -1
var _dit_ing := -1             # ce qu'un lecteur bot vient de dire (les bots le suivent, juste ou pas)
var _derniere_pincee := {}
var _bots := {}                # les joueurs joués par des bots (vus passer dans `bot`)
var _bot_choix := {}           # id -> le pot qu'un bot est en train d'aller verser (juste, ou une erreur)
var _bot_dest := {}            # id -> "etagere" | "chaudron" : où il a été envoyé
var _etape_depuis := 0.0       # le moment où l'étape courante est devenue la courante
var _pret_cle := -1            # (étape, vies) pour lesquelles `_pret_a` a été tiré
var _pret_a := 0.0             # le moment avant lequel aucun bot ne verse : le temps de lire, de dire et d'entendre
var _bot_fin_tour := {}        # sans pieds (essais unitaires) : le moment où un bot a fini son tour complet


# ---------------------------------------------------------------- règles pures (testées)

## Les étapes de la recette : plus il y en a, plus la partie dure. Une équipe qui joue bien met
## environ 8 secondes par étape (annoncer, aller chercher le pot, le verser) : cf. test_chaudron.
static func nb_etapes(niveau: String, _n: int) -> int:
	return {"simple": 21, "normal": 21, "dur": 13, "extreme": 9}.get(niveau, 14)


## La chance qu'un bot se trompe de pot à UNE étape : la recette est plus longue qu'avant (6 à 9 étapes),
## alors on la répartit pour qu'une tentative réussisse à peu près aussi souvent qu'avant.
static func erreur_bot(niveau: String, longueur: int) -> float:
	var avant: Array = {"simple": [0.06, 6], "normal": [0.09, 7], "dur": [0.105, 8], "extreme": [0.12, 9]}[niveau]
	return 1.0 - pow(1.0 - float(avant[0]), float(avant[1]) / maxf(float(longueur), 1.0))


static func vies_pour(niveau: String) -> int:
	return {"simple": 5, "normal": 4, "dur": 3, "extreme": 2}.get(niveau, 3)


# ---------------------------------------------------------------- mise en place

func demarrer() -> void:
	var longueur := nb_etapes(niveau, ids.size())
	vies = vies_pour(niveau)
	vies_depart = vies
	duree = Quetes.duree_max(niveau)
	var regles: Array = ["", "Ingrédient double"]
	if ids.size() >= 4 and niveau != "simple":
		regles.append("Deux grimoires")
	variante = regles[rng.randi_range(0, regles.size() - 1)]
	var de_trop: int = {"simple": 2, "normal": 3, "dur": 3, "extreme": 4}[niveau]
	var uniques: int = longueur - (1 if variante == "Ingrédient double" else 0)
	var tires := Catalogue.tirer(INGREDIENTS, uniques + de_trop, rng)
	for k in uniques:
		recette.append(tires[k])
	if variante == "Ingrédient double":
		# Le même, une seconde fois, jamais juste à la suite de lui-même.
		var x: int = recette[rng.randi_range(0, uniques - 1)]
		var ou: int = rng.randi_range(0, recette.size())
		for essai in 20:
			if (ou == 0 or recette[ou - 1] != x) and (ou >= recette.size() or recette[ou] != x):
				break
			ou = rng.randi_range(0, recette.size())
		recette.insert(ou, x)
	reserve.assign(tires)
	# La réserve est distribuée dans le désordre : chacun tient plusieurs pots, dont peut-être un de trop.
	var ordre: Array = reserve.duplicate()
	_melanger(ordre)
	var decal: int = rng.randi_range(0, ids.size() - 1)
	for k in ordre.size():
		proprio[int(ordre[k])] = ids[(k + decal) % ids.size()]
	lecteur_i = ids.find(elu) if ids.has(elu) else rng.randi_range(0, ids.size() - 1)
	for id in ids:
		_bot_t[id] = rng.randf_range(1.0, 3.0)
		main[id] = -1
		_bot_choix[id] = -1
		_bot_dest[id] = ""


func _melanger(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var x: Variant = a[i]
		a[i] = a[j]
		a[j] = x


func liste() -> Dictionary:
	var noms: Array = []
	for ing in reserve:
		noms.append(INGREDIENTS[ing])
	noms.sort()
	return {"titre": "La réserve du jour", "v": noms}


## Ici, tout le monde marche pour de vrai : l'hôte lit les pieds de chacun.
func a_pied(id: int) -> bool:
	return ids.has(id)


## Chacun part de sa place autour du chaudron.
func depart_locale(id: int) -> Vector3:
	return DecorQuete.poste("chaudron", maxi(ids.find(id), 0), ids.size())


## Les lecteurs du grimoire, et pour chacun les étapes qu'il lit.
func lecteurs() -> Array[int]:
	var l: Array[int] = [ids[lecteur_i]]
	if variante == "Deux grimoires":
		l.append(ids[(lecteur_i + 1) % ids.size()])
	return l


func lit(id: int, k: int) -> bool:
	var l := lecteurs()
	if l.size() == 1:
		return id == l[0]
	return id == l[k % 2]


func _gacher() -> void:
	vies = vies_apres(vies)
	etape = 0
	gachis += 1
	_dit_ing = -1
	_etape_depuis = temps
	lecteur_i = (lecteur_i + 1) % ids.size()
	annonce = "Le chaudron tourne au noir !"
	_annonce_t = 3.0
	# Après une erreur on s'en aperçoit, on souffle, on reprend : aucun bot ne bouge tout de suite.
	for x in ids:
		_bot_t[x] = maxf(float(_bot_t[x]), RythmeHumain.regret(rng))
		_bot_choix[x] = -1
	if vies <= 0:
		terminer()


# ---------------------------------------------------------------- les gestes (reçus de l'hôte)

## Cet id est-il à portée de l'étagère ? Sans pieds connus (tests), oui.
func _pres_etagere(id: int) -> bool:
	return not pieds.has(id) or LieuxChaudron.pres_de_l_etagere(pieds[id], clairiere, ids.size())


func _pres_chaudron(id: int) -> bool:
	return not pieds.has(id) or LieuxChaudron.pres_du_chaudron(pieds[id])


func action(id: int, d: Dictionary) -> void:
	if fini or not ids.has(id):
		return
	if d.has("prendre"):
		var ing := int(d["prendre"])
		if reserve.has(ing) and int(proprio.get(ing, -1)) == id and int(main[id]) == -1 and _pres_etagere(id):
			main[id] = ing
	elif d.has("poser"):
		if int(main[id]) != -1 and _pres_etagere(id):
			main[id] = -1
	elif d.has("verser"):
		_verser(id, int(d.get("verser", -1)))
	elif d.has("pincee") and peut_saboter(id):
		if temps - float(_derniere_pincee.get(id, -99.0)) < 25.0 or not _pres_chaudron(id):
			return
		_derniere_pincee[id] = temps
		_gacher()


func _verser(id: int, ing: int) -> void:
	if int(proprio.get(ing, -1)) != id:
		return
	# Un vrai joueur doit tenir ce pot et être au chaudron ; sans ses pieds (tests), l'intention suffit.
	if pieds.has(id) and (int(main[id]) != ing or not _pres_chaudron(id)):
		return
	if recette[etape] == ing:
		etape += 1
		verses += 1
		dernier = ing
		_dit_ing = -1
		_etape_depuis = temps
		if etape >= recette.size():
			for x in ids:
				_reussis[x] = true
			terminer()
	else:
		_gacher()


## Un froid qui glace les mains : le pot qu'on tenait retourne sur l'étagère.
func _hanter(id: int) -> String:
	if int(main.get(id, -1)) != -1:
		main[id] = -1
		return "Un froid glacé saisit %s : son pot lui échappe." % nom(id)
	return super._hanter(id)


func avancer(delta: float) -> void:
	super.avancer(delta)
	_annonce_t -= delta
	if _annonce_t <= 0.0:
		annonce = ""


func _consigne() -> String:
	match variante:
		"Deux grimoires":
			return "Règle du jour : DEUX GRIMOIRES. Un lecteur a les étapes impaires, l'autre les paires : relayez-vous. Va chercher SES pots sur l'étagère et verse-les dans le chaudron, au bon moment : une erreur et tout recommence."
		"Ingrédient double":
			return "Règle du jour : INGRÉDIENT DOUBLE. Un ingrédient revient deux fois dans la recette : le lecteur sait quand, celui qui tient le pot sait lequel. Va chercher SES pots sur l'étagère et verse-les dans le chaudron, au bon moment."
	return "Seul le lecteur connaît l'ordre de la recette : il la lit sur le grimoire. Va chercher SES pots sur l'étagère et verse-les dans le chaudron, au bon moment : une erreur et tout recommence."


func _mes_pots(id: int) -> Array:
	var r := []
	for ing in reserve:
		if int(proprio.get(ing, -1)) == id:
			r.append(int(ing))
	return r


## L'état de chaque pot pour ce joueur : 0 sur l'étagère, 1 dans MA main, 2 dans la main d'un autre.
func _pots_pour(id: int) -> Array:
	var r := []
	for ing in reserve:
		var tenu_par := -1
		for x in ids:
			if int(main[x]) == ing:
				tenu_par = x
		r.append([int(ing), INGREDIENTS[ing], 0 if tenu_par < 0 else (1 if tenu_par == id else 2)])
	return r


func vue_pour(id: int) -> Dictionary:
	var blocs := []
	var l := lecteurs()
	var grimoire := {}
	if l.has(id):
		var lignes := []
		for k in recette.size():
			if lit(id, k):
				lignes.append([k, INGREDIENTS[recette[k]], k < etape])
		grimoire = {"lignes": lignes, "etape": etape}
		blocs.append(MiniJeu.texte("Tu lis le grimoire sur le pupitre. Dicte l'ordre aux autres." if l.size() == 1
			else "Tu lis les étapes %s du grimoire ; %s lit les autres." % ["impaires" if l[0] == id else "paires", nom(l[1] if l[0] == id else l[0])], 18, "gris"))
	elif l.size() == 1:
		blocs.append(MiniJeu.texte("%s lit le grimoire. Écoute-le, puis verse ton ingrédient quand c'est son tour." % nom(l[0]), 18, "gris"))
	else:
		blocs.append(MiniJeu.texte("%s et %s lisent le grimoire, une étape chacun. Écoute-les." % [nom(l[0]), nom(l[1])], 18, "gris"))
	blocs.append(MiniJeu.jauge(float(etape) / recette.size(), "Étape %d / %d" % [mini(etape + 1, recette.size()), recette.size()]))
	var mes := _mes_pots(id)
	if mes.is_empty():
		blocs.append(MiniJeu.texte("Tu n'as aucun pot : guide les autres.", 20, "gris"))
	else:
		var noms := PackedStringArray()
		for ing: int in mes:
			noms.append(INGREDIENTS[ing])
			if recette.count(ing) > 1:
				blocs.append(MiniJeu.texte("Ton pot de %s se verse DEUX fois dans la recette. Si le lecteur ne le dit qu'une fois… méfie-toi." % INGREDIENTS[ing], 17, "or"))
		blocs.append(MiniJeu.texte("Tes pots : %s" % ", ".join(noms), 18, "or"))
	if peut_saboter(id):
		blocs.append(MiniJeu.texte("Tu as un sachet de poudre noire : au chaudron, sans pot en main, bascule la main pour glisser une pincée.", 16, "gris"))
	if annonce != "":
		blocs.append(MiniJeu.texte(annonce, 24, "rouge"))
	blocs.append(MiniJeu.texte("Tentatives restantes : %d" % vies, 16, "gris"))
	return {"consigne": _consigne(), "blocs": blocs, "vies": vies, "vies_max": vies_depart,
		"pots": _pots_pour(id), "mes": mes, "main": int(main.get(id, -1)), "grimoire": grimoire, "lecteur": l.has(id),
		"etape": etape, "total": recette.size(), "verses": verses, "dernier": dernier, "gachis": gachis,
		"sachet": peut_saboter(id)}


# ---------------------------------------------------------------- les bots (ils marchent pour de vrai)

func _envoyer(id: int, dest: String, ou: Vector3) -> void:
	if _bot_dest[id] == dest:
		return
	_bot_dest[id] = dest
	deplacements.append([id, ou])


func bot(id: int, delta: float) -> void:
	if fini:
		return
	_bots[id] = true
	_bot_t[id] -= delta
	if _bot_t[id] > 0.0:
		return
	_bot_t[id] = 0.15
	if lit(id, etape):
		var cle: int = etape + 100 * vies
		if _bot_dit != cle:
			_bot_dit = cle
			# Un lecteur saboteur cite un autre ingrédient de la réserve : un nom qui existe.
			_dit_ing = recette[etape]
			_etape_depuis = temps
			if peut_saboter(id) and rng.randf() < 0.5:
				_dit_ing = reserve[(reserve.find(_dit_ing) + 1 + rng.randi_range(0, reserve.size() - 2)) % reserve.size()]
			paroles.append([id, "Maintenant : %s." % INGREDIENTS[_dit_ing]])
			_bot_t[id] = BOT_LECTURE * rng.randf_range(0.9, 1.2)
			return
	if peut_saboter(id) and rng.randf() < 0.003 and _pres_chaudron(id) and int(main[id]) == -1 and temps > 20.0:
		action(id, {"pincee": true})
		return
	# Les bots versent ce qu'un lecteur bot a dit (même faux), et attendent qu'il l'ait dit ; un
	# lecteur humain, ils ne l'entendent pas : ils versent le bon.
	var lecteur := -1
	for x in lecteurs():
		if lit(x, etape):
			lecteur = x
	var voulu: int = recette[etape]
	if _bots.has(lecteur):
		if _dit_ing < 0:
			return
		voulu = _dit_ing
	if int(proprio.get(voulu, -1)) != id:
		_bot_choix[id] = -1
		return
	# Il faut d'abord que la ligne ait été lue, dite en entier, et entendue : ni avant, ni d'un coup.
	var cle_pret: int = etape + 100 * vies
	if _pret_cle != cle_pret:
		_pret_cle = cle_pret
		var mots: int = str(INGREDIENTS[voulu]).split(" ").size() + 1
		# Un lecteur bot a déjà « parlé » (sa lecture est dans BOT_LECTURE) : on n'attend que de comprendre.
		var attente: float = RythmeHumain.reaction(rng) if _bots.has(lecteur) else RythmeHumain.attente_dictee(mots, rng)
		_pret_a = _etape_depuis + attente + (RythmeHumain.marche(3.0) if etape == 0 else 0.0)
	if temps < _pret_a:
		return
	_jouer_bot(id, voulu)


## Un bot dont c'est le tour : il va chercher son pot, le rapporte, le verse (ou, de temps en
## temps, se trompe de pot parmi les siens).
func _jouer_bot(id: int, voulu: int) -> void:
	if not pieds.has(id):
		# Sans pieds (essais unitaires sans hôte) : il met le temps d'un tour complet (marcher, prendre, verser).
		if not _bot_fin_tour.has(id):
			_bot_fin_tour[id] = temps + RythmeHumain.tour_complet(4.0, 4.0)
		if temps < float(_bot_fin_tour[id]):
			return
		_bot_fin_tour.erase(id)
		if rng.randf() < _erreur():
			for ing in reserve:
				if int(proprio.get(ing, -1)) == id and ing != voulu:
					action(id, {"verser": ing})
					return
		action(id, {"verser": voulu})
		return
	if int(_bot_choix[id]) < 0:
		_bot_choix[id] = voulu
		if rng.randf() < _erreur():
			for ing in reserve:
				if int(proprio.get(ing, -1)) == id and ing != voulu:
					_bot_choix[id] = ing
					break
	var choix: int = _bot_choix[id]
	var tient: int = main[id]
	if tient == choix:
		if LieuxChaudron.pres_du_chaudron(pieds[id]):
			_bot_dest[id] = ""
			_bot_t[id] = BOT_VERSE
			_bot_choix[id] = -1
			action(id, {"verser": choix})
		else:
			_envoyer(id, "chaudron", LieuxChaudron.pt_verser(ids.find(id), ids.size()))
		return
	if LieuxChaudron.pres_de_l_etagere(pieds[id], clairiere, ids.size()):
		_bot_dest[id] = ""
		_bot_t[id] = BOT_GESTE
		action(id, {"poser": true} if tient != -1 else {"prendre": choix})
	else:
		_envoyer(id, "etagere", LieuxChaudron.devant_etagere(clairiere, ids.size()))


func _erreur() -> float:
	return erreur_bot(niveau, recette.size())
