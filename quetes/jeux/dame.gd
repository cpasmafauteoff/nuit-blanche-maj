extends MiniJeu
## La Dame blanche, dans un vrai cimetière (01/11) : à chaque manche, un GUIDE (qui tourne) voit la
## Dame glisser vers un lieu du cimetière et la décrit à voix haute ; tous les autres sont les FUYARDS :
## leur écran est presque noir et ils MARCHENT pour de vrai, guidés par sa voix et par les bruits de la
## Dame (sons spatialisés), pour s'éloigner d'elle. À la fin de la manche, la Dame attrape qui est là où
## elle est allée (ou qui n'a presque pas bougé) : l'hôte lit leurs pieds (`pieds`), comme au marais.
## La manche du guide compte comme survécue.
## Sabotage : le guide ment (à la voix). Les autres écrans ne disent jamais où elle est allée.
## Réussite individuelle : être attrapé assez peu de fois (Cimetiere.tolerees).
## Les lieux de chaque manche sont tirés des 20 repères du cimetière (Catalogue.LIEUX, bâtis par le décor là
## où Cimetiere.lieu_pos les met) : ils s'éclairent pendant la préparation, un guide menteur en cite un autre.
## Règle du jour « Deux dames » (normal, dur, extrême) : elles vont à DEUX lieux, il faut s'éloigner des deux.
## Durée : un nombre de manches fixe (Cimetiere.nb_manches), chacune de la même longueur : une équipe qui joue
## bien met toujours au moins le minimum du niveau ; le temps limite est le maximum du niveau.

const LIEUX := Catalogue.LIEUX

var manches := 4
var cyc := {}
var duree_manche := 20.0        # la part où les fuyards marchent dans le noir
var nb_lieux := 4
var tour := 0
var phase := "prep"             # prep | actif | bilan
var phase_t := 0.0
var ordre: Array[int] = []
var guide := 0
var lieux: Array[String] = []
var lieux_k: Array[int] = []    # leur numéro dans le catalogue (donc leur place : Cimetiere.lieu_pos)
var dame := 0                   # index (dans `lieux`) du lieu où elle va
var dame2 := -1                 # « Deux dames » : le second lieu, sinon -1
var dames_pos: Array[Vector3] = []   # où sont les Dames maintenant (l'hôte les fait glisser)
var _dames_dep: Array[Vector3] = []
var _dames_but: Array[Vector3] = []
var debut_pos := {}             # id -> où il était au début de la manche
var pris := {}                  # id -> manches où il a été attrapé
var _pris_tour := {}            # id -> "" | "dame" | "immobile"
var nb_pris_tour := 0
var _rayon_plus := {}           # id -> mètres de plus pour l'attraper cette manche (un fantôme l'a désigné)
var _annonce_bot: Array[int] = []    # ce que dit le guide bot (index dans `lieux`), vide s'il n'a rien dit
var _bot_plan := {}
var _bots_vus := {}             # les joueurs joués par des bots (vus passer dans `bot`) : un guide bot parle, un guide humain, on ne l'entend pas
var _guide_voit := 1.5          # le moment (dans la manche) où le guide a vu vers où glisse la Dame et se met à parler
var _annonce_fin := 0.0         # le moment où un guide bot a fini de parler
var _dernier_mensonge := -9     # la dernière manche où un guide loup a menti : il ne ment pas deux fois de suite
var _sim := {}                  # id -> position, quand aucun hôte ne lit de vrais pieds (essais sans moteur)


func demarrer() -> void:
	_init_vies()
	cyc = Cimetiere.cycle(niveau)
	duree_manche = float(cyc["actif"])
	manches = Cimetiere.nb_manches(niveau, ids.size())
	if niveau != "simple" and rng.randf() < {"normal": 0.35, "dur": 0.45, "extreme": 0.6}[niveau]:
		variante = "Deux dames"
	nb_lieux = {"simple": 4, "normal": rng.randi_range(4, 5), "dur": 4, "extreme": 3}[niveau]
	if variante == "Deux dames":
		nb_lieux = 5 if niveau == "normal" else 4
	# Le temps limite est le maximum du niveau : les manches se suivent jusqu'au bout sans l'atteindre.
	duree = Quetes.duree_max(niveau)
	var o: Array = ids.duplicate()
	for i in range(o.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var x: int = o[i]
		o[i] = o[j]
		o[j] = x
	# Celui qui s'est avancé dans la zone « Guide » est le premier guide.
	if o.has(elu):
		o.erase(elu)
		o.push_front(elu)
	ordre.assign(o)
	for id in ids:
		pris[id] = 0
	# Les Dames naissent au centre du cimetière, au milieu du cercle des joueurs.
	dames_pos = [Vector3.ZERO, Vector3(0.7, 0, -0.7)]
	_nouveau_tour()


func nb_dames() -> int:
	return 2 if variante == "Deux dames" else 1


func _nouveau_tour() -> void:
	guide = ordre[tour % ordre.size()]
	lieux.clear()
	lieux_k.clear()
	for k in Catalogue.tirer(LIEUX, nb_lieux, rng):
		lieux.append(LIEUX[k])
		lieux_k.append(k)
	dame = rng.randi_range(0, nb_lieux - 1)
	dame2 = -1
	if variante == "Deux dames":
		dame2 = (dame + rng.randi_range(1, nb_lieux - 1)) % nb_lieux
	# Chaque Dame part d'où elle s'est arrêtée à la manche d'avant.
	_dames_dep.clear()
	_dames_but.clear()
	for i in nb_dames():
		_dames_dep.append(dames_pos[i])
		_dames_but.append(Cimetiere.lieu_pos(lieux_k[dame if i == 0 else dame2]))
	for id in ids:
		_pris_tour[id] = ""
	_rayon_plus.clear()
	debut_pos.clear()
	nb_pris_tour = 0
	_annonce_bot.clear()
	_bot_plan.clear()
	_guide_voit = rng.randf_range(1.0, 2.0)
	phase = "prep"
	phase_t = 0.0


## Les fuyards entrent dans le noir : on note d'où chacun part, pour juger s'il a bougé.
func _commencer_manche() -> void:
	phase = "actif"
	phase_t = 0.0
	for id in ids:
		if pieds.has(id):
			debut_pos[id] = pieds[id]


func a_pied(_id: int) -> bool:
	return true


## Le cercle serré du centre, face à la Dame (cf. DecorQuete.poste).
func depart_locale(id: int) -> Vector3:
	return DecorQuete.poste("dame", maxi(ids.find(id), 0), ids.size())


func _resoudre() -> void:
	nb_pris_tour = 0
	for i in nb_dames():
		dames_pos[i] = _dames_but[i]
	for id in ids:
		if id == guide:
			continue
		var cause := ""
		# Un joueur dont on ne lit pas les pieds (parti, mort) n'est pas jugé.
		if pieds.has(id):
			var depart: Vector3 = debut_pos.get(id, pieds[id])
			cause = Cimetiere.verdict(depart, pieds[id], _dames_but, Cimetiere.rayon_attrape(niveau) + float(_rayon_plus.get(id, 0.0)))
		_pris_tour[id] = cause
		if cause != "":
			pris[id] = int(pris[id]) + 1
			nb_pris_tour += 1
	phase = "bilan"
	phase_t = 0.0
	# Niveau dur : une manche où un tiers des fuyards (au moins un) est attrapé coûte une vie à l'équipe.
	if nb_pris_tour >= maxi(1, int(ceil((ids.size() - 1) / 3.0))):
		perdre_vie()


func _tolerees() -> int:
	return Cimetiere.tolerees(niveau, manches)


func terminer() -> void:
	for id in ids:
		_reussis[id] = int(pris.get(id, 0)) <= _tolerees()
	super.terminer()


## Un fantôme désigne un fuyard à la Dame : cette manche, elle l'attrapera de plus loin.
func _hanter(id: int) -> String:
	if id == guide or phase == "bilan":
		return ""
	_rayon_plus[id] = 1.4
	return "La Dame sent %s : elle l'attrapera de plus loin cette manche." % nom(id)


func action(_id: int, _d: Dictionary) -> void:
	# Plus aucun bouton : on fuit en marchant, l'hôte lit les pieds.
	pass


func avancer(delta: float) -> void:
	super.avancer(delta)
	if fini:
		return
	phase_t += delta
	if phase == "prep":
		if phase_t >= float(cyc["prep"]):
			_commencer_manche()
	elif phase == "actif":
		var f := Cimetiere.fraction_trajet(phase_t, duree_manche)
		for i in nb_dames():
			dames_pos[i] = Cimetiere.pos_dame(_dames_dep[i], _dames_but[i], f, 1.0 if i == 0 else -1.0)
		if phase_t >= duree_manche:
			_resoudre()
	elif phase_t >= float(cyc["bilan"]):
		tour += 1
		if tour >= manches:
			terminer()
		else:
			_nouveau_tour()


func liste() -> Dictionary:
	return {"titre": "Les lieux de cette manche", "v": Array(lieux)}


func _ou_elle_va() -> String:
	if dame2 < 0:
		return lieux[dame].to_upper()
	return "%s ET %s" % [lieux[dame].to_upper(), lieux[dame2].to_upper()]


func vue_pour(id: int) -> Dictionary:
	var blocs := []
	var deux := variante == "Deux dames"
	var aveugle := id != guide
	var consigne := "Dans le noir, écoute le guide : marche loin d'où vont les DEUX dames." if deux else "Dans le noir, écoute le guide : marche loin d'où va la Dame."
	if not aveugle:
		consigne = "Tu es le GUIDE : les autres sont dans le noir. Dis-leur où vont les deux dames." if deux else "Tu es le GUIDE : les autres sont dans le noir. Dis-leur où va la Dame."
		if phase == "prep":
			blocs.append(MiniJeu.texte("Les lieux de la manche s'éclairent. La Dame va se mettre en route.", 22))
			blocs.append(MiniJeu.texte("Les lieux possibles : %s" % ", ".join(lieux), 16, "gris"))
		elif phase == "bilan":
			blocs.append(MiniJeu.texte("Manche finie. Joueurs attrapés : %d" % nb_pris_tour, 22))
		else:
			blocs.append(MiniJeu.texte("Les deux dames vont :" if deux else "La Dame blanche va :", 18, "gris"))
			blocs.append(MiniJeu.texte(_ou_elle_va(), 36 if not deux else 28, "or"))
			blocs.append(MiniJeu.texte("Décris-la à voix haute (ou mens, si tu l'oses).", 16, "gris"))
			blocs.append(MiniJeu.texte("Les lieux possibles : %s" % ", ".join(lieux), 16, "gris"))
	elif phase == "prep":
		blocs.append(MiniJeu.texte("La nuit tombe : retiens où sont les lieux éclairés.", 26, "rouge"))
		blocs.append(MiniJeu.texte("Bientôt tu marcheras dans le noir, guidé par la voix de %s et les bruits de la Dame." % nom(guide), 16, "gris"))
		blocs.append(MiniJeu.texte("Les lieux éclairés : %s" % ", ".join(lieux), 16, "gris"))
	elif phase == "actif":
		blocs.append(MiniJeu.texte("Écoute %s. Où est la Dame ? Éloigne-toi !" % nom(guide), 24))
		blocs.append(MiniJeu.texte("Si tu restes sur place, elle te trouve.", 16, "gris"))
		blocs.append(MiniJeu.jauge(1.0 - phase_t / maxf(duree_manche, 0.1), "Avant que la Dame arrive"))
	else:
		var cause: String = _pris_tour.get(id, "")
		if cause == "":
			blocs.append(MiniJeu.texte("Tu as échappé à la Dame. La lumière revient.", 22, "vert"))
		elif cause == "immobile":
			blocs.append(MiniJeu.texte("Tu n'as pas bougé : la Dame t'a trouvé.", 22, "rouge"))
		else:
			blocs.append(MiniJeu.texte("La Dame t'a attrapé.", 22, "rouge"))
		blocs.append(MiniJeu.texte("Joueurs attrapés cette manche : %d" % nb_pris_tour, 16, "gris"))
	blocs.append(MiniJeu.texte("Manche %d / %d · tu as été attrapé %d fois (au plus %d permises)" % [mini(tour + 1, manches), manches, int(pris.get(id, 0)), _tolerees()], 16, "gris"))
	# Pour le décor : où sont les Dames (les sons et le guide), et si mon écran est noir.
	var pos := []
	for i in nb_dames():
		pos.append([dames_pos[i].x, dames_pos[i].z])
	var noir := aveugle and (phase == "actif" or (phase == "prep" and phase_t > float(cyc["prep"]) - 1.2))
	var cim := {"phase": phase, "aveugle": aveugle, "noir": noir, "dames": pos, "lieux": lieux_k,
		"pris": _pris_tour.get(id, "") if phase == "bilan" else "", "t": phase_t, "actif": duree_manche,
		"rayon": Cimetiere.rayon_attrape(niveau)}
	var vue := {"consigne": consigne, "blocs": blocs, "cim": cim}
	return vue


# ---------------------------------------------------------------- les bots

func bot(id: int, delta: float) -> void:
	if fini or phase == "bilan":
		return
	_bots_vus[id] = true
	if id == guide:
		if phase == "actif" and _annonce_bot.is_empty() and phase_t > _guide_voit:
			var dit: int = dame
			var dit2: int = dame2
			# Un guide loup ment rarement : jamais deux manches de suite.
			if peut_saboter(id) and tour != _dernier_mensonge + 1 and rng.randf() < 0.3:
				_dernier_mensonge = tour
				# Il ment avec un lieu de la manche où elle ne va pas : ça sonne juste.
				dit = (dame + 1 + rng.randi_range(0, nb_lieux - 2)) % nb_lieux
				if dit == dame2:
					dit = (dit + 1) % nb_lieux
					if dit == dame:
						dit = (dit + 1) % nb_lieux
				dit2 = -1
			_annonce_bot.append(dit)
			if dit2 >= 0:
				_annonce_bot.append(dit2)
				paroles.append([id, "Elles vont %s et %s !" % [lieux[dit], lieux[dit2]]])
				_annonce_fin = phase_t + RythmeHumain.parole(6)
			else:
				paroles.append([id, "Elle va %s !" % lieux[dit]])
				_annonce_fin = phase_t + RythmeHumain.parole(4)
		return
	# Sans hôte qui lise de vrais pieds (un essai sans moteur), le bot « marche » dans cette table.
	if not _sim.has(id) and not pieds.has(id):
		_sim[id] = depart_locale(id)
		pieds[id] = _sim[id]
	var reel := not _sim.has(id)
	if _sim.has(id):
		var but: Variant = _bot_plan.get(id, {}).get("dest", null)
		if but != null:
			var d: Vector3 = (but as Vector3) - (_sim[id] as Vector3)
			d.y = 0.0
			var pas := 2.6 * delta
			_sim[id] = (but as Vector3) if d.length() <= pas else (_sim[id] as Vector3) + d.normalized() * pas
			pieds[id] = _sim[id]
	if phase != "actif":
		return
	var plan: Dictionary = _bot_plan.get(id, {})
	if plan.is_empty():
		plan = {
			"rate": rng.randf() < {"simple": 0.05, "normal": 0.1, "dur": 0.125, "extreme": 0.15}[niveau],
			"reac": RythmeHumain.reaction(rng), "alle": false}
		_bot_plan[id] = plan
	if plan["alle"]:
		return
	# Il n'agit qu'après avoir ENTENDU le guide : la phrase dite en entier, puis le temps de comprendre. Un guide bot parle quand
	# il a vu la Dame partir ; un guide humain, les bots ne l'entendent pas : ils supposent qu'il parle vers la même heure et
	# qu'il dit vrai (la règle des autres jeux, cf. Chaudron).
	var guide_bot := _bots_vus.has(guide)
	var cites: Array[int] = []
	if guide_bot:
		if _annonce_bot.is_empty():
			return
		cites = _annonce_bot.duplicate()
		if phase_t < _annonce_fin + float(plan["reac"]):
			return
	else:
		cites.append(dame)
		if dame2 >= 0:
			cites.append(dame2)
		if phase_t < _guide_voit + RythmeHumain.parole(6 if dame2 >= 0 else 4) + float(plan["reac"]):
			return
	plan["alle"] = true
	var ici: Vector3 = pieds[id]
	var dest: Vector3
	if plan["rate"]:
		# Il a mal compris : il court vers la Dame, ou ne bouge pas.
		dest = _dames_but[0] + Vector3(0.6, 0, 0.4) if rng.randf() < 0.7 else ici
	else:
		# Il s'éloigne des lieux que le guide a cités (les deux, s'il en a dit deux).
		var interdits := []
		for k: int in cites:
			interdits.append(Cimetiere.lieu_pos(lieux_k[k]))
		dest = Cimetiere.refuge(interdits, Cimetiere.rayon_attrape(niveau), ici, rng)
		if dest == Vector3.INF:
			dest = -ici.normalized() * 5.0
	plan["dest"] = dest
	if reel:
		deplacements.append([id, dest])
