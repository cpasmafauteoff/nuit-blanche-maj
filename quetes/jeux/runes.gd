extends MiniJeu
## Les Runes : une suite de signes gravés sur la stèle. Chacun n'en voit que quelques-uns
## (« la 2e, c'est Lune ») ; il faut se les dire pour que CHACUN reconstitue la suite entière sur SON autel :
## des galets gravés (de vrais objets, cf. Prise) qu'on PREND à la main et qu'on POSE dans les encoches, dans
## l'ordre ; on peut en retirer un. Quand l'autel est plein, il juge : suite juste (il s'embrase) ou fausse
## (les galets rentrent à la réserve, un essai de moins).
## La pierre du jour n'use qu'une poignée des 24 runes du jeu (Catalogue.RUNES) : ce sont les galets de
## l'autel, et la liste du parchemin.
## Règles du jour (au hasard) : la suite telle quelle ; « Miroir » (à poser à l'envers) ;
## « Rune maudite » (une rune ne se pose jamais : on la saute — et SEUL le voyant sait laquelle ;
## s'il est loup, il peut en désigner une autre).
## Sabotage : annoncer une rune fausse (à la voix — le jeu ne fait rien de plus).
##
## Dimensionnement (Edwin, 01/11 : facile 2–8 min, moyen 2–5, dur 1–4, extrême 45 s–1 min 30) : la durée d'une
## partie réussie vient de la longueur de la suite (`longueur`), des tours de parole (`PAROLE_PAR_JOUEUR`) et du
## geste de chacun (`PAS_BOT`, environ un galet toutes les 7,6 secondes). Une partie réussie dure à peu près
## 9 + 3·n + 8,8·longueur secondes (un peu moins, les bots posent pendant que les derniers parlent) (n joueurs) ; `tests/mesure_duree.gd runes` le mesure.

const SIGNES := Catalogue.RUNES
## Un bot qui joue « bien » : prendre puis poser un galet, comme un humain qui cherche et vise.
const PAS_BOT := Vector2(3.0, 4.6)
## Chaque joueur dit ses runes à son tour : 3 secondes + 2,2 par rune qu'il voit (les autres les notent).
const PAROLE_FIXE := 3.0
const PAROLE_PAR_RUNE := 2.2

var palette: Array[int] = []   # les runes de la pierre du jour (indices dans SIGNES)
var suite: Array[int] = []     # la suite gravée, telle quelle
var maudite := -1              # « Rune maudite » : le signe qu'on saute
var voyant := -1               # « Rune maudite » : le seul qui sait laquelle
var vus := {}          # id -> [positions visibles]
var essais := {}       # id -> essais restants
var echecs := {}       # id -> suites fausses posées (l'autel tremble)
var prise := Prise.new()
var ordre: Array[int] = []     # pour chaque encoche, la position d'origine dans la suite
var cases_de := {}     # id -> [case de chaque encoche]
var galets_de := {}    # id -> [objet de chaque galet]
var _bot := {}         # id -> {t, k, plan, attend}
var _bot_dit := {}     # id -> a déjà dit ses runes
var _parle_a := {}     # id -> instant où le bot parle
var _fin_paroles := 0.0
var _fin_dit := {}     # id -> l'instant où il a fini de dire ses runes
var _entendu_a := {}   # position -> l'instant où on a fini de la dire à voix haute
var _dit_val := {}     # position -> la rune dite pour elle (la vraie, sauf si un bot menteur en a cité une autre)
var _corrige := {}     # id -> a vu sa suite refusée : le groupe s'est reparlé, il sait la vérité
var _maudite_dit_a := 0.0      # « Rune maudite » : quand le voyant dit laquelle
var _maudite_entendue := 0.0   # ... quand on a fini de l'entendre
var _maudite_dite := -1        # ... ce qu'il a dit (une autre rune s'il est loup et menteur)


## Combien de runes dans la suite (et d'encoches sur l'autel), selon le niveau et l'équipe.
static func longueur(niveau: String, n: int) -> int:
	var base: int = {"simple": 14, "normal": 14, "dur": 9, "extreme": 6}.get(niveau, 10)
	if n >= 7:
		base -= 1   # plus de monde = plus de paroles : la suite raccourcit d'une rune
	return clampi(base, 4, Dispositions.MAX_ENCOCHES)


static func nb_essais(niveau: String) -> int:
	return {"simple": 3, "normal": 2, "dur": 2, "extreme": 1}.get(niveau, 2)


static func nb_runes_pierre(niveau: String) -> int:
	return {"simple": 8, "normal": 9, "dur": 9, "extreme": 10}.get(niveau, 9)


## Les galets d'un autel : un par rune de la pierre, et autant d'exemplaires qu'il en faut pour la suite à poser
## (une rune qui revient trois fois = trois galets). Rend les indices de rune, de quoi remplir au plus `max`.
static func galets_pour(attendue: Array, palette: Array, maxi_: int) -> Array[int]:
	var r: Array[int] = []
	for s in palette:
		for k in maxi(1, attendue.count(s)):
			r.append(s)
	# Trop de galets : on retire d'abord les leurres (runes de la pierre absentes de la suite).
	var i := r.size() - 1
	while r.size() > maxi_ and i >= 0:
		if not attendue.has(r[i]):
			r.remove_at(i)
		i -= 1
	return r.slice(0, maxi_)


func demarrer() -> void:
	_init_vies()
	var n := ids.size()
	var long_ := longueur(niveau, n)
	duree = Quetes.duree_max(niveau)
	palette = Catalogue.tirer(SIGNES, nb_runes_pierre(niveau), rng)
	var regles: Array = ["", "Miroir"] if niveau == "simple" else ["", "Miroir", "Rune maudite"]
	variante = regles[rng.randi_range(0, regles.size() - 1)]
	for i in long_:
		suite.append(palette[rng.randi_range(0, palette.size() - 1)])
	if variante == "Rune maudite":
		# La rune maudite est dans la suite (sinon la règle ne sert à rien), mais pas partout.
		maudite = suite[rng.randi_range(0, long_ - 1)]
		if suite.count(maudite) == long_:
			suite[0] = palette[(palette.find(maudite) + 1) % palette.size()]
		voyant = ids[rng.randi_range(0, ids.size() - 1)]
	# Chaque position est vue par au moins un joueur ; chacun voit au moins une rune.
	for k in n:
		vus[ids[k]] = []
	for p in long_:
		vus[ids[p % n]].append(p)
	# L'ordre dans lequel on pose : la suite sans la rune maudite, à l'envers au Miroir.
	for p in long_:
		if suite[p] != maudite:
			ordre.append(p)
	if variante == "Miroir":
		ordre.reverse()
	var att := attendue()
	for k in n:
		var id := ids[k]
		if (vus[id] as Array).is_empty():
			vus[id].append(rng.randi_range(0, long_ - 1))
		essais[id] = nb_essais(niveau)
		echecs[id] = 0
		cases_de[id] = []
		galets_de[id] = []
		var runes := galets_pour(att, palette, Dispositions.MAX_GALETS)
		for i in range(runes.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var x: int = runes[i]
			runes[i] = runes[j]
			runes[j] = x
		for j in att.size():
			(cases_de[id] as Array).append(prise.ajouter_cible(Dispositions.encoche(k, n, j, att.size()), id, {"own": id, "r": 0.12, "j": j}))
		for g in runes.size():
			(galets_de[id] as Array).append(prise.ajouter_objet("galet", SIGNES[runes[g]], Dispositions.galet(k, n, g, runes.size()), id,
				{"own": id, "s": runes[g], "t": 0.17, "rot": Dispositions.autel(k, n).basis.get_euler().y + rng.randf_range(-0.5, 0.5)}))
		_parle_a[id] = _fin_paroles if k > 0 else 4.0
		_fin_paroles = float(_parle_a[id]) + PAROLE_FIXE + PAROLE_PAR_RUNE * (vus[id] as Array).size()
		_fin_dit[id] = _fin_paroles
		for p: int in vus[id]:
			_dit_val[p] = suite[p]
			_entendu_a[p] = minf(float(_entendu_a.get(p, INF)), _fin_paroles)
		_bot[id] = {"t": rng.randf_range(0.5, 1.5), "k": 0, "plan": [], "attend": 0.0, "reac": RythmeHumain.reaction(rng), "fautif": -1}
	if voyant >= 0:
		# Le voyant dit sa rune maudite juste après avoir dit les siennes ; on la comprend après la phrase.
		_maudite_dit_a = float(_fin_dit[voyant]) + 0.5
		_maudite_entendue = _maudite_dit_a + RythmeHumain.parole(8)
		_maudite_dite = maudite


## Ce qu'il faut poser, selon la règle du jour.
func attendue() -> Array[int]:
	var r: Array[int] = []
	for p in ordre:
		r.append(suite[p])
	return r


func liste() -> Dictionary:
	var noms := PackedStringArray()
	for s in palette:
		noms.append(SIGNES[s])
	return {"titre": "Les runes de la pierre", "v": Array(noms)}


## Les runes posées dans l'autel de ce joueur, encoche par encoche (-1 : vide).
func posees(id: int) -> Array[int]:
	var r: Array[int] = []
	for c: int in cases_de.get(id, []):
		var o := prise.objet_sur(c)
		r.append(int(prise.objets[o]["x"]["s"]) if o >= 0 else -1)
	return r


func action(id: int, d: Dictionary) -> void:
	if fini or not ids.has(id) or _reussis.get(id, false) or essais[id] <= 0:
		return
	var r := prise.agir(id, d)
	if r["quoi"] == "pose":
		_juger(id)


## L'autel plein : juste (il s'embrase) ou faux (les galets rentrent, un essai de moins).
func _juger(id: int) -> void:
	var p := posees(id)
	if p.has(-1):
		return
	if p == attendue():
		_reussis[id] = true
		_verrouiller(id)
		if tous_reussis() and RythmeHumain.duree_plausible(temps, niveau, humain_a_agi):
			terminer()
		return
	essais[id] -= 1
	echecs[id] += 1
	for g: int in galets_de[id]:
		prise.renvoyer(g)
	if essais[id] <= 0:
		_verrouiller(id)
	var b: Dictionary = _bot[id]
	b["k"] = 0
	b["plan"] = []
	b["fautif"] = -1
	_corrige[id] = true   # la suite est refusée : on s'en parle, la vérité sort
	b["attend"] = RythmeHumain.regret(rng)   # il s'en aperçoit, souffle, reprend
	perdre_vie()          # niveau dur : une suite fausse coûte une vie à l'équipe


## Plus personne ne touche à cet autel (suite juste, ou plus d'essai).
func _verrouiller(id: int) -> void:
	for g: int in galets_de[id]:
		prise.objets[g]["dest"] = -2
	for c: int in cases_de[id]:
		prise.cibles[c]["pour"] = -2


func _consigne() -> String:
	match variante:
		"Miroir":
			return "Règle du jour : MIROIR. Dites-vous vos runes, puis chacun pose sa suite À L'ENVERS (la dernière gravée d'abord). Prends un galet de ta réserve (clic tenu, ou E), pose-le dans une encoche ; tu peux en reprendre un. Quand l'autel est plein, il juge."
		"Rune maudite":
			return "Règle du jour : RUNE MAUDITE. Une rune de la suite ne se pose jamais, et seul %s sait laquelle : qu'il vous la dise — s'il ment, tout le monde se trompe. Dites-vous vos runes, puis chacun pose le reste, dans l'ordre. Prends un galet de ta réserve (clic tenu, ou E), pose-le dans une encoche ; tu peux en reprendre un. Quand l'autel est plein, il juge." % nom(voyant)
	return "Dites-vous vos runes : il faut que chacun reconstitue la suite entière sur son autel, dans l'ordre. Prends un galet de ta réserve (clic tenu, ou E), pose-le dans une encoche ; tu peux en reprendre un. Quand l'autel est plein, il juge."


func vue_pour(id: int) -> Dictionary:
	var gravure := PackedStringArray()
	for p in suite.size():
		gravure.append(SIGNES[suite[p]] if (vus.get(id, []) as Array).has(p) else "?")
	var blocs := [MiniJeu.texte("Ce que TU vois sur la pierre :", 18, "gris"),
		MiniJeu.texte("  ".join(PackedStringArray(range(1, suite.size() + 1).map(func(i): return "%d." % i))), 16, "gris"),
		MiniJeu.texte("   ".join(gravure), 26, "or")]
	if variante == "Miroir":
		blocs.append(MiniJeu.texte("À poser à l'envers : la %de d'abord." % suite.size(), 18, "rouge"))
	elif variante == "Rune maudite":
		if id == voyant:
			blocs.append(MiniJeu.texte("Toi seul le sais : la rune maudite est %s (ne jamais la poser). Dis-le aux autres." % SIGNES[maudite], 18, "rouge"))
		else:
			blocs.append(MiniJeu.texte("Une rune est maudite : seul %s sait laquelle. Demande-lui." % nom(voyant), 18, "rouge"))
	if _reussis.get(id, false):
		blocs.append(MiniJeu.texte("Ta suite est juste. Aide les autres !", 22, "vert"))
	elif essais.get(id, 0) <= 0:
		blocs.append(MiniJeu.texte("Plus d'essai pour toi. Aide les autres de la voix.", 22, "rouge"))
	else:
		blocs.append(MiniJeu.texte("Essais restants : %d" % essais[id], 16, "gris"))
	var fait := 0
	for x in ids:
		if _reussis.get(x, false):
			fait += 1
	blocs.append(MiniJeu.texte("Suites justes : %d / %d (il en faut %d)" % [fait, ids.size(), Quetes.seuil(ids.size(), niveau)], 16, "gris"))
	# Le bloc de la prise, TOUJOURS le dernier : mes galets, mes encoches.
	var b := prise.bloc(id, func(_i: int, o: int) -> bool: return int(prise.objets[o]["x"]["own"]) == id,
		func(_i: int, c: int) -> bool: return int(prise.cibles[c]["x"]["own"]) == id)
	b["juste"] = _reussis.get(id, false)
	b["echecs"] = echecs.get(id, 0)
	b["conf"] = _confirmees(id)
	blocs.append(b)
	return {"consigne": _consigne(), "blocs": blocs}


## Les encoches où le galet posé est celui que MOI je lis sur la stèle à cette place : la pierre me le confirme
## (je le savais déjà — aucune information neuve, on ne peut pas tâtonner).
func _confirmees(id: int) -> Array:
	var r := []
	var p := posees(id)
	var att := attendue()
	for j in p.size():
		if p[j] >= 0 and p[j] == att[j] and (vus.get(id, []) as Array).has(ordre[j]):
			r.append(j)
	return r


## La chance qu'un bot pose UN mauvais galet (il en a pris un autre pour celui qu'il croyait voir), pour qu'une suite
## entière réussisse à peu près avec la probabilité `reussite_suite` du niveau. Jamais zéro : un joueur se trompe.
static func erreur_galet(niveau: String, longueur: int) -> float:
	var juste: float = {"simple": 0.85, "normal": 0.75, "dur": 0.725, "extreme": 0.7}.get(niveau, 0.75)
	return 1.0 - pow(juste, 1.0 / maxf(float(longueur), 1.0))


## Quelle rune un joueur doit poser dans l'encoche `j`, d'après ce qu'il SAIT : `connu` donne, pour une position
## de la suite (dans l'ordre où on la lit), la rune qu'il en connaît (-1 : il ne la sait pas encore). `maudite`
## : la rune qu'il croit maudite (-1 : il ne sait pas encore s'il y en a une à sauter ; -2 : aucune règle de ce genre).
## `sens` : les positions dans l'ordre de pose (la suite, ou la suite à l'envers au Miroir).
## Rend la rune, ou -1 s'il lui manque encore une information pour savoir.
static func rune_a_poser(sens: Array, connu: Array, maudite: int, j: int) -> int:
	if maudite == -1:
		return -1
	var compte := 0
	for p: int in sens:
		var v: int = connu[p]
		if v < 0:
			return -1
		if maudite >= 0 and v == maudite:
			continue
		if compte == j:
			return v
		compte += 1
	return -1


## La rune que CE bot connaît à la position p : la sienne (il la lit sur la stèle), celle qu'un autre a dite et qu'il a
## eu le temps d'entendre et de comprendre, sinon -1. Après une suite fausse le groupe se reparle : il sait tout.
func _sait(id: int, p: int) -> int:
	if _corrige.get(id, false) or (vus.get(id, []) as Array).has(p):
		return suite[p]
	if temps >= float(_entendu_a.get(p, INF)) + float(_bot[id]["reac"]):
		return int(_dit_val[p])
	return -1


## La rune maudite telle que CE bot la croit : -2 s'il n'y a pas de rune maudite aujourd'hui, -1 si on ne la lui a
## pas encore dite, sinon ce qu'il a entendu (le voyant, lui, la sait ; un voyant menteur a pu en citer une autre).
func _maudite_pour(id: int) -> int:
	if variante != "Rune maudite":
		return -2
	if id == voyant or _corrige.get(id, false):
		return maudite
	if temps >= _maudite_entendue + float(_bot[id]["reac"]):
		return _maudite_dite
	return -1


## Des bots seuls (aucun humain n'a joué) qui ont tous posé juste ne concluent pas avant le plancher du
## niveau : la quête se termine au premier instant plausible. Edwin, 01/11 : « finie en 10 secondes ».
func avancer(delta: float) -> void:
	if not fini and tous_reussis() and RythmeHumain.duree_plausible(temps, niveau, humain_a_agi):
		terminer()
		return
	super.avancer(delta)


func bot(id: int, delta: float) -> void:
	if fini or _reussis.get(id, false) or essais.get(id, 0) <= 0:
		return
	var b: Dictionary = _bot[id]
	# Il parle à son tour (les autres écoutent), puis il se met à poser ce qu'il a entendu.
	if not _bot_dit.get(id, false) and temps >= float(_parle_a[id]):
		_parler(id)
		return
	if id == voyant and not _bot_dit.has(-1) and temps >= _maudite_dit_a:
		_bot_dit[-1] = true
		var m := maudite
		if peut_saboter(id) and rng.randf() < 0.5:
			for s in suite:
				if s != maudite:
					m = s
					break
		_maudite_dite = m
		paroles.append([id, "La rune maudite, c'est %s. Ne la posez pas !" % SIGNES[m]])
		return
	b["attend"] -= delta
	b["t"] -= delta
	if float(b["attend"]) > 0.0 or float(b["t"]) > 0.0:
		return
	var att := attendue()
	var porte := prise.tenu(id)
	if porte < 0:
		var k: int = b["k"]
		# La prochaine case vide (si un humain a posé quelque chose, on s'y retrouve).
		while k < cases_de[id].size() and prise.objet_sur(cases_de[id][k]) >= 0:
			k += 1
		b["k"] = k
		if k >= cases_de[id].size():
			b["t"] = 0.3
			return
		# Quelle rune poser ici ? Seulement ce qu'il sait : sa part de la stèle, et ce qu'on lui a dit.
		var sens: Array = range(suite.size())
		if variante == "Miroir":
			sens.reverse()
		var connu: Array = []
		for p in suite.size():
			connu.append(_sait(id, p))
		var voulu := rune_a_poser(sens, connu, _maudite_pour(id), k)
		if voulu < 0:
			b["t"] = 0.4   # il attend qu'on lui dise la rune
			return
		# Un joueur se trompe parfois de galet ; un saboteur le fait exprès, une seule fois par essai.
		if b["fautif"] < 0:
			b["fautif"] = rng.randi_range(0, att.size() - 1) if peut_saboter(id) and rng.randf() < 0.5 else -2
		if k == int(b["fautif"]) or rng.randf() < erreur_galet(niveau, att.size()) * (0.0 if peut_saboter(id) else 1.0):
			voulu = palette[(palette.find(voulu) + 1) % palette.size()]
		var choix := -1
		for g: int in galets_de[id]:
			if int(prise.objets[g]["par"]) < 0 and int(prise.objets[g]["sur"]) < 0 and int(prise.objets[g]["x"]["s"]) == voulu:
				choix = g
				break
		if choix < 0:
			for g: int in galets_de[id]:
				if int(prise.objets[g]["par"]) < 0 and int(prise.objets[g]["sur"]) < 0:
					choix = g
					break
		if choix >= 0:
			b["t"] = maxf(rng.randf_range(PAS_BOT.x, PAS_BOT.y), RythmeHumain.CADENCE_MIN)
			action(id, {"prend": choix})
	else:
		b["t"] = maxf(rng.randf_range(PAS_BOT.x, PAS_BOT.y), RythmeHumain.CADENCE_MIN)
		var k2: int = b["k"]
		while k2 < cases_de[id].size() and prise.objet_sur(cases_de[id][k2]) >= 0:
			k2 += 1
		if k2 < cases_de[id].size():
			b["k"] = k2 + 1
			action(id, {"pose": cases_de[id][k2]})
		else:
			action(id, {"repose": true})


func _parler(id: int) -> void:
	# Le bot dit ses runes. Un saboteur en change UNE au plus (une fois sur deux), toujours pour une rune de la pierre.
	_bot_dit[id] = true
	var menteuse := -1
	if peut_saboter(id) and rng.randf() < 0.5:
		menteuse = (vus[id] as Array)[rng.randi_range(0, (vus[id] as Array).size() - 1)]
	var dit := PackedStringArray()
	for p in vus[id]:
		var s: int = suite[p]
		if p == menteuse:
			s = palette[(palette.find(s) + 1 + rng.randi_range(0, palette.size() - 2)) % palette.size()]
		_dit_val[p] = s
		dit.append(("la 1re, c'est %s" % SIGNES[s]) if p == 0 else ("la %de, c'est %s" % [p + 1, SIGNES[s]]))
	# Une phrase par ligne : chacune se traduit chez le joueur qui la lit.
	paroles.append([id, "Moi je vois :\n%s" % "\n".join(dit)])
