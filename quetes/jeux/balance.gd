extends MiniJeu
## La Balance : de grands plateaux de laiton pendus à un mât, et des poids de fonte (lingots, pierres) posés
## sur la table de chacun. On PREND un poids à la main (clic tenu, ou E) et on le POSE sur un plateau (cf. Prise) :
## le plateau s'enfonce sous la charge, penche du côté où l'on a posé, et son AIGUILLE bouge. Chacun ne peut lire
## que le cadran d'UN seul plateau (celui qu'on lui a confié : le cadran est tourné vers lui) ; il faut
## s'annoncer les lectures pour équilibrer tout le monde, et tenir quelques secondes. On peut reprendre ses
## propres poids sur un plateau. Équilibre tenu : tout le monde réussit ; temps écoulé : personne.
## Sabotage : le saboteur a, dans sa poche, un caillou (que lui seul voit sur sa table) à poser sur un plateau :
## une fois posé, il pèse pour tous et personne ne peut plus le reprendre ni savoir d'où il vient. Ou mentir sur
## la lecture de son plateau (un nombre plausible : le jeu ne dit jamais la vérité aux autres).
## Règle du jour « Poids voilés » (normal, extrême) : on ne connaît pas la valeur de ses propres poids (ils se
## ressemblent tous), seulement ce que lisent les plateaux.
##
## Dimensionnement (Edwin, 01/11) : le nombre de poids (`nb_poids`) croît avec l'équipe (plus d'équipiers = plus de
## paroles à échanger) ; la durée d'une partie réussie se mesure avec les bots (`tests/mesure_duree.gd balance`) :
## environ 4 + 3·n + nb_poids (paroles) + 3 + poids par joueur × 6,6 s (gestes) + tenue + corrections.

const NOMS_PLATEAUX := ["A", "B", "C", "D"]
## Un bot qui joue « bien » : lire, prendre, viser, poser (secondes entre deux gestes).
const PAS_BOT := Vector2(2.6, 4.2)

var total := 12              # poids prévu sur chaque plateau (tiré à chaque partie)
var nb_plateaux := 2
var tol := 2                 # écart maximal toléré entre le plateau le plus lourd et le plus léger
var tenue := 3.0
var prise := Prise.new()
var cases_plateaux: Array[int] = []   # plateau -> sa case
var valeurs: Array[int] = []          # objet -> sa valeur (1 pour un caillou)
var poids_objets: Array[int] = []     # les vrais poids (pas les cailloux)
var table_de := {}                    # id -> [objets sur sa table]
var _equilibre_t := 0.0
var _cailloux := {}          # id -> nombre posés
var _caillou_de := {}        # id -> [objets-cailloux qu'il peut encore poser]
var plan: Array[int] = []             # objet -> le plateau où il doit finir (la partition d'origine)
var _bot := {}
var _parle_a := {}
var _fin_paroles := 0.0
var _correcteur := -1        # celui qui vient de dire « je déplace un poids » : les autres le laissent faire
var _correcteur_jusqua := 0.0
var _fin_dit := {}           # id -> l'instant où il a fini de dire ses poids
var _annonce := {}           # plateau -> [le nombre lu à voix haute, l'instant où la phrase s'achève]


## Combien de vrais poids dans la partie (hors cailloux), pour n joueurs.
static func nb_poids(niveau: String, n: int) -> int:
	var base: Array = {"simple": [22, 4], "normal": [26, 3], "dur": [14, 2], "extreme": [8, 1]}.get(niveau, [20, 4])
	return mini(int(base[0]) + int(base[1]) * n, 44)


static func nb_plateaux_de(niveau: String) -> int:
	return {"simple": 2, "normal": 3, "dur": 3, "extreme": 4}.get(niveau, 2)


## Le poids total voulu sur chaque plateau : la somme de ses poids, pour que l'équilibre existe.
static func total_par_plateau(niveau: String, n: int) -> int:
	var par_plateau := ceili(float(nb_poids(niveau, n)) / nb_plateaux_de(niveau))
	return clampi(int(round(par_plateau * 2.0)), 8, 60)


func demarrer() -> void:
	_init_vies()
	var n := ids.size()
	nb_plateaux = nb_plateaux_de(niveau)
	tol = {"simple": 2, "normal": 1, "dur": 1, "extreme": 1}[niveau]
	tenue = {"simple": 3.0, "normal": 4.0, "dur": 4.5, "extreme": 5.0}[niveau]
	duree = Quetes.duree_max(niveau)
	total = total_par_plateau(niveau, n)
	if niveau != "simple" and rng.randf() < 0.3:
		variante = "Poids voilés"
	# Des poids qui SAVENT s'équilibrer : chaque plateau est la somme de `total` en morceaux (de 1 à 5).
	var nb := nb_poids(niveau, n)
	var vals: Array[int] = []
	var vers: Array[int] = []
	for p in nb_plateaux:
		var c := nb / nb_plateaux + (1 if p < nb % nb_plateaux else 0)
		var morceaux: Array[int] = []
		for k in c:
			morceaux.append(1)
		var reste := total - c
		var garde := 0
		while reste > 0 and garde < 2000:
			garde += 1
			var k := rng.randi_range(0, c - 1)
			if morceaux[k] < 5:
				morceaux[k] += 1
				reste -= 1
		vals.append_array(morceaux)
		for k in c:
			vers.append(p)
	for i in range(vals.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var x: int = vals[i]
		vals[i] = vals[j]
		vals[j] = x
		var y: int = vers[i]
		vers[i] = vers[j]
		vers[j] = y
	for id in ids:
		table_de[id] = []
		_cailloux[id] = 0
		_caillou_de[id] = []
		_bot[id] = {"t": rng.randf_range(4.0, 8.0), "cible": -1, "dit": 0.0, "reac": RythmeHumain.reaction(rng), "vu": {}, "delta": {},
			"oeil": rng.randf_range(1.0, 3.0), "dernier": {}, "attend": 0.0, "caillou_a": rng.randf_range(30.0, 70.0)}
	# Les plateaux, puis les poids sur les tables (largeur, hauteur, masse : la taille dit le poids, sauf voilés).
	for p in nb_plateaux:
		cases_plateaux.append(prise.ajouter_cible(Dispositions.plateau(p, nb_plateaux), -1,
			{"p": p, "nom": NOMS_PLATEAUX[p], "r": Dispositions.RAYON_PLAT}, Dispositions.MAX_PAR_PLATEAU))
	var decal: int = rng.randi_range(0, n - 1)
	for k in vals.size():
		var k_joueur := (k + decal) % n
		var id := ids[k_joueur]
		var place: int = (table_de[id] as Array).size()
		var o := prise.ajouter_objet("poids", "", Dispositions.place_table(k_joueur, n, place), id,
			{"own": id, "v": vals[k], "w": vals[k], "t": taille_poids(vals[k]), "cai": false, "rot": Dispositions.table(k_joueur, n).basis.get_euler().y + rng.randf_range(-0.5, 0.5), "s": rng.randi() % 3})
		valeurs.append(vals[k])
		plan.append(vers[k])
		(table_de[id] as Array).append(o)
		poids_objets.append(o)
	# Les cailloux du saboteur : deux, sur sa table, que lui seul voit.
	for k in n:
		var id := ids[k]
		if not peut_saboter(id):
			continue
		for c in 2:
			var place: int = (table_de[id] as Array).size()
			var o := prise.ajouter_objet("caillou", "", Dispositions.place_table(k, n, mini(place, Dispositions.MAX_TABLE - 1)), id,
				{"own": id, "v": 1, "w": 1, "t": 0.07, "cai": true, "rot": rng.randf_range(-3.0, 3.0), "s": c})
			valeurs.append(1)
			plan.append(-1)
			(table_de[id] as Array).append(o)
			(_caillou_de[id] as Array).append(o)
	# Les tours de parole : chacun dit ses poids à son tour (3 s + 1 s par poids).
	for k in n:
		var id := ids[k]
		_parle_a[id] = _fin_paroles if k > 0 else 4.0
		var nb_siens := 0
		for o: int in table_de[id]:
			if not prise.objets[o]["x"]["cai"]:
				nb_siens += 1
		_fin_paroles = float(_parle_a[id]) + 3.0 + float(nb_siens)
		_fin_dit[id] = _fin_paroles
	for id in ids:
		(_bot[id] as Dictionary)["dit"] = float(_fin_dit[id]) + 3.0 + rng.randf_range(3.0, 8.0)


## La taille d'un poids (mètres) : un lingot plus long à mesure qu'il pèse.
static func taille_poids(v: int) -> float:
	return 0.1 + 0.022 * v


## Le poids posé sur un plateau (cailloux compris), ce que lit son cadran.
func charge(p: int) -> int:
	var s := 0
	for o: int in prise.cibles[cases_plateaux[p]]["occupe"]:
		s += valeurs[o]
	return s


func sommes() -> Array:
	var s: Array = []
	for p in nb_plateaux:
		s.append(charge(p))
	return s


## Tous les vrais poids sont sur un plateau, et les plateaux ne diffèrent que de `tol` au plus.
func _equilibre() -> bool:
	for o in poids_objets:
		if int(prise.objets[o]["sur"]) < 0:
			return false
	var s: Array = sommes()
	return int(s.max()) - int(s.min()) <= tol


## Le joueur qui lit le plateau p.
func lecteur_de(p: int) -> int:
	return ids[p % ids.size()]


func plateau_de_lecteur(id: int) -> int:
	for p in nb_plateaux:
		if lecteur_de(p) == id:
			return p
	return -1


func action(id: int, d: Dictionary) -> void:
	if fini or not ids.has(id):
		return
	var r := prise.agir(id, d)
	if r["quoi"] == "pose" and prise.objets[int(r["o"])]["x"]["cai"]:
		# Un caillou posé ne se reprend plus, et personne ne saura qui l'a posé.
		prise.objets[int(r["o"])]["dest"] = -2
		_cailloux[id] += 1
		(_caillou_de[id] as Array).erase(int(r["o"]))


func avancer(delta: float) -> void:
	if fini:
		return
	if _equilibre():
		_equilibre_t += delta
		# Des bots seuls ne concluent pas avant le plancher du niveau (ils vérifient que ça tient).
		if _equilibre_t >= tenue and RythmeHumain.duree_plausible(temps, niveau, humain_a_agi):
			for id in ids:
				_reussis[id] = true
			terminer()
			return
	else:
		# Niveau dur : un équilibre presque tenu qui s'écroule coûte une vie à l'équipe.
		if _equilibre_t >= 1.0:
			perdre_vie()
		_equilibre_t = 0.0
	super.avancer(delta)


func _consigne() -> String:
	if variante == "Poids voilés":
		return "Règle du jour : POIDS VOILÉS. Tu ne connais pas la valeur de tes poids : pose-les et écoute les lectures. Tous les plateaux doivent s'équilibrer (à %d près), tous les poids posés, et tenir %d secondes. Prends un poids sur ta table (clic tenu, ou E), pose-le sur un plateau ; tu peux le reprendre." % [tol, int(tenue)]
	return "Chacun ne lit qu'un cadran. Annoncez vos lectures et posez vos poids : tous les plateaux doivent s'équilibrer (à %d près), tous les poids posés, et tenir %d secondes. Prends un poids sur ta table (clic tenu, ou E), pose-le sur un plateau ; tu peux le reprendre." % [tol, int(tenue)]


func vue_pour(id: int) -> Dictionary:
	var blocs := []
	var lus := PackedStringArray()
	for p in nb_plateaux:
		if lecteur_de(p) == id:
			lus.append(NOMS_PLATEAUX[p])
	if lus.size() == 1:
		blocs.append(MiniJeu.texte("Le cadran du plateau %s est tourné vers toi : toi seul le lis." % lus[0], 22, "or"))
	elif lus.size() > 1:
		blocs.append(MiniJeu.texte("Les cadrans des plateaux %s sont tournés vers toi : toi seul les lis." % " et ".join(lus), 22, "or"))
	else:
		blocs.append(MiniJeu.texte("Aucun cadran pour toi : écoute les lectures des autres.", 18, "gris"))
	var restants := 0
	for o: int in table_de[id]:
		if not prise.objets[o]["x"]["cai"] and int(prise.objets[o]["sur"]) < 0:
			restants += 1
	blocs.append(MiniJeu.texte("Poids encore sur ta table : %d" % restants, 16, "gris"))
	blocs.append(MiniJeu.jauge(_equilibre_t / tenue, "Équilibre tenu", [], "vert"))
	# Le bloc de la prise, TOUJOURS le dernier : tous les poids, tous les plateaux (le cadran n'est lisible que pour son lecteur).
	var b := prise.bloc(id, func(vu: int, o: int) -> bool:
			var x: Dictionary = prise.objets[o]["x"]
			return not x["cai"] or int(x["own"]) == vu or int(prise.objets[o]["sur"]) >= 0)
	for od: Dictionary in b["objets"]:
		var x2: Dictionary = (od["x"] as Dictionary).duplicate()
		if variante == "Poids voilés" and not x2["cai"]:
			x2["v"] = -1
			x2["t"] = taille_poids(3)
		od["x"] = x2
	for cd: Dictionary in b["cibles"]:
		var x3: Dictionary = (cd["x"] as Dictionary).duplicate()
		x3["lecture"] = charge(int(x3["p"])) if lecteur_de(int(x3["p"])) == id else -1
		x3["maximum"] = cadran_max(total)
		cd["x"] = x3
	blocs.append(b)
	return {"consigne": _consigne(), "blocs": blocs, "cible": total}


## Jusqu'où va le cadran (en unités) : un peu plus que le plus lourd plateau voulu.
static func cadran_max(tot: int) -> int:
	return maxi(24, int(ceil(tot * 1.6 / 4.0)) * 4)


## Quel plateau un joueur choisit pour un poids de valeur `v` (-1 : il ne la connaît pas, on prend `moyen`), d'après ce qu'il
## croit de la charge de chaque plateau (`estimees`) : celui à qui il manque le plus pour atteindre `total` ET où le poids tient ;
## sinon celui qui a le plus de place. `bruit` : un petit nombre au hasard par plateau (départage les égalités).
static func plateau_pour(estimees: Array, total: int, v: int, moyen: float, bruit: Array) -> int:
	var vv: float = float(v) if v >= 0 else moyen
	var meilleur := 0
	var score := -INF
	for p in estimees.size():
		var reste: float = float(total) - float(estimees[p])
		var s: float = (reste if reste >= vv else reste - 1000.0) + float(bruit[p])
		if s > score:
			score = s
			meilleur = p
	return meilleur


## Le poids à déplacer du plateau le plus lourd vers le plus léger : parmi `valeurs` (les poids que ce joueur a posés sur le plus
## lourd, -1 si la valeur lui est cachée), celui qui rapproche le plus les deux (|écart − 2v| minimal, et v < écart). Rend
## l'index dans `valeurs`, ou -1 si aucun ne rapproche. Valeur cachée : il essaie le premier au hasard (`au_hasard`).
static func poids_a_deplacer(valeurs_: Array, ecart: float, au_hasard: int) -> int:
	var meilleur := -1
	var reste := INF
	for i in valeurs_.size():
		var v: int = valeurs_[i]
		if v < 0:
			return au_hasard % valeurs_.size() if ecart >= 1.0 else -1
		if float(v) < ecart and absf(ecart - 2.0 * float(v)) < reste:
			reste = absf(ecart - 2.0 * float(v))
			meilleur = i
	return meilleur


## Tous les vrais poids sont posés sur un plateau ou dans une main : un joueur le voit sur les tables.
func _tout_est_pose() -> bool:
	for o in poids_objets:
		if int(prise.objets[o]["sur"]) < 0 and int(prise.objets[o]["par"]) < 0:
			return false
	return true


## La charge du plateau p telle que CE bot la croit : son cadran s'il le lit, sinon ce qu'un lecteur a dit (si ça colle avec
## ce qu'il voit pencher), sinon ce qu'il voit pencher (à peu près : deux unités près).
func _estime(id: int, p: int) -> float:
	if lecteur_de(p) == id:
		return float(charge(p))
	var b: Dictionary = _bot[id]
	var visuel: float = float((b["vu"] as Dictionary).get(p, 0.0)) + float((b["delta"] as Dictionary).get(p, 0.0))
	if _annonce.has(p) and temps >= float(_annonce[p][1]) + float(b["reac"]) and float(_annonce[p][1]) > float(b.get("oeil_t", -1.0)):
		if absf(float(_annonce[p][0]) - visuel) <= 3.0:
			return float(_annonce[p][0]) + float((b["delta"] as Dictionary).get(p, 0.0))
	return visuel


## Il lève les yeux sur les plateaux : ce qu'il croit voir (à une unité près, parfois), et il oublie ses propres ajouts d'avant.
func _coup_d_oeil(id: int) -> void:
	var b: Dictionary = _bot[id]
	for p in nb_plateaux:
		(b["vu"] as Dictionary)[p] = float(charge(p) + (rng.randi_range(-1, 1) if rng.randf() < 0.4 else 0))
	b["delta"] = {}
	b["oeil_t"] = temps
	b["oeil"] = rng.randf_range(2.0, 4.0)


## Il lit son cadran à voix haute quand ça a changé (un saboteur annonce parfois un nombre plausible, mais faux).
func _annoncer(id: int, b: Dictionary) -> bool:
	if temps < float(b["dit"]):
		return false
	for p in nb_plateaux:
		if lecteur_de(p) != id:
			continue
		var lu := charge(p)
		if int((b["dernier"] as Dictionary).get(p, -999)) == lu:
			continue
		(b["dernier"] as Dictionary)[p] = lu
		var dit := lu
		if peut_saboter(id) and rng.randf() < 0.25:
			dit = maxi(1, lu + rng.randi_range(2, 4) * (1 if rng.randf() < 0.5 else -1))
		_annonce[p] = [dit, temps + RythmeHumain.parole(5)]
		b["dit"] = temps + rng.randf_range(6.0, 10.0)
		b["t"] = maxf(float(b["t"]), RythmeHumain.parole(5))
		paroles.append([id, "Mon plateau %s indique %d." % [NOMS_PLATEAUX[p], dit]])
		return true
	return false


func bot(id: int, delta: float) -> void:
	if fini:
		return
	var b: Dictionary = _bot[id]
	# Il dit ses poids à son tour, puis on se met d'accord.
	if not b.has("parle") and temps >= float(_parle_a[id]):
		b["parle"] = true
		var dit := PackedStringArray()
		for o: int in table_de[id]:
			if not prise.objets[o]["x"]["cai"]:
				dit.append(str(valeurs[o]))
		if variante == "Poids voilés":
			paroles.append([id, "Je ne connais pas mes poids : je pose selon vos lectures."])
		else:
			paroles.append([id, "Mes poids : %s." % ", ".join(dit)])
		return
	# Il se met à poser dès qu'il a fini de dire ses poids (sans attendre que les autres aient fini : il connaît la cible).
	if temps < float(_fin_dit[id]) + 1.5:
		return
	b["oeil"] -= delta
	if float(b["oeil"]) <= 0.0:
		_coup_d_oeil(id)
	b["attend"] -= delta
	b["t"] -= delta
	if float(b["attend"]) > 0.0:
		return
	if _annoncer(id, b):
		return
	if b["t"] > 0.0:
		return
	b["t"] = maxf(rng.randf_range(PAS_BOT.x, PAS_BOT.y), RythmeHumain.CADENCE_MIN)
	var porte := prise.tenu(id)
	if porte >= 0:
		# Il pose ce qu'il tient sur le plateau qu'il visait.
		var cible_: int = b["cible"]
		action(id, {"pose": cases_plateaux[cible_]})
		var d: Dictionary = b["delta"]
		d[cible_] = float(d.get(cible_, 0.0)) + (float(valeurs[porte]) if variante != "Poids voilés" or prise.objets[porte]["x"]["cai"] else _poids_moyen())
		return
	# Un saboteur glisse un caillou sur un plateau, rarement (et jamais deux de suite).
	if peut_saboter(id) and (_caillou_de[id] as Array).size() > 0 and temps >= float(b["caillou_a"]):
		b["caillou_a"] = temps + rng.randf_range(30.0, 60.0)
		b["cible"] = rng.randi_range(0, nb_plateaux - 1)
		action(id, {"prend": (_caillou_de[id] as Array)[0]})
		return
	# D'abord ses poids restés sur la table : le plus gros d'abord, sur le plateau qui en a le plus besoin d'après ce qu'il croit
	# (un saboteur, ou un étourdi, se trompe parfois de plateau, et s'en aperçoit un peu plus tard).
	var gros := -1
	for o: int in table_de[id]:
		if prise.objets[o]["x"]["cai"] or int(prise.objets[o]["sur"]) >= 0 or int(prise.objets[o]["par"]) >= 0:
			continue
		if gros < 0 or (variante != "Poids voilés" and valeurs[o] > valeurs[gros]):
			gros = o
	if gros >= 0:
		_coup_d_oeil(id)   # il regarde les plateaux juste avant de choisir où poser
		var estimees: Array = []
		var bruit: Array = []
		for p in nb_plateaux:
			estimees.append(_estime(id, p))
			bruit.append(rng.randf() * 0.8)
		var cible: int = plateau_pour(estimees, total, valeurs[gros] if variante != "Poids voilés" else -1, _poids_moyen(), bruit)
		var erreur: float = 0.15 if peut_saboter(id) else {"simple": 0.03, "normal": 0.05, "dur": 0.07, "extreme": 0.08}.get(niveau, 0.05)
		if rng.randf() < erreur:
			cible = (cible + 1 + rng.randi_range(0, nb_plateaux - 2)) % nb_plateaux
			b["attend"] = RythmeHumain.regret(rng) * 0.5   # il s'en aperçoit un peu plus tard
		b["cible"] = cible
		action(id, {"prend": gros})
		return
	# Tout est posé : il corrige. Le déplacement d'un de ses poids du plateau le plus lourd au plus léger, d'après ce qu'il croit.
	if not _tout_est_pose():
		return
	_coup_d_oeil(id)
	var est: Array = []
	for p in nb_plateaux:
		est.append(_estime(id, p))
	var haut := 0
	var bas := 0
	for p in nb_plateaux:
		if float(est[p]) > float(est[haut]):
			haut = p
		if float(est[p]) < float(est[bas]):
			bas = p
	var ecart: float = float(est[haut]) - float(est[bas])
	if ecart <= float(tol):
		return
	# Un seul à la fois corrige (on se le dit à voix haute) : sinon chacun déplace d'après des chiffres périmés.
	if temps < _correcteur_jusqua and _correcteur != id:
		return
	var siens: Array[int] = []
	var vals: Array = []
	for o: int in table_de[id]:
		if prise.objets[o]["x"]["cai"] or int(prise.objets[o]["sur"]) != cases_plateaux[haut]:
			continue
		siens.append(o)
		vals.append(valeurs[o] if variante != "Poids voilés" else -1)
	if siens.is_empty():
		return
	var choix := poids_a_deplacer(vals, ecart, rng.randi())
	if choix < 0:
		return
	b["cible"] = bas
	b["attend"] = rng.randf_range(2.0, 4.0)   # il regarde l'effet avant de recommencer
	if _correcteur != id or temps >= _correcteur_jusqua:
		paroles.append([id, "Je passe un poids du plateau %s au plateau %s." % [NOMS_PLATEAUX[haut], NOMS_PLATEAUX[bas]]])
		b["attend"] = maxf(float(b["attend"]), RythmeHumain.parole(8))
	_correcteur = id
	_correcteur_jusqua = temps + 9.0
	action(id, {"prend": siens[choix]})


## La valeur moyenne d'un poids : ce qu'un joueur qui ne connaît pas ses poids imagine.
func _poids_moyen() -> float:
	return float(total * nb_plateaux) / maxf(float(poids_objets.size()), 1.0)
