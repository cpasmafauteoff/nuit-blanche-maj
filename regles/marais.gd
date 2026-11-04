class_name Marais
extends RefCounted
## Le marais des Lanternes, sans rien d'affiché : sa taille selon le niveau, son tracé (un vrai parcours
## en lacets, des embranchements qui ne mènent nulle part, des îlots balisés qui font les étapes, des
## pierres qui s'enfoncent), et le rythme de ces pierres. Le jeu (jeux/lanternes.gd) y juge les pieds du
## marcheur, le décor (decors/decor_lanternes.gd) le dessine : une seule source pour les deux.
##
## La carte : une chaîne de l × h caractères, rangée par rangée, du nord (rangée 0, l'arrivée) au sud
## (rangée h-1, le départ, face aux guides).
##   '.' pierre sûre · 'X' l'arrivée · '#' pierre piège (elle cède sous le pied) · '~' pas de pierre : de l'eau ·
##   'm' pierre sûre qui s'enfonce par moments (sûre seulement quand elle est haute) ·
##   't' pierre piège qui s'enfonce aussi (elle imite 'm' : le marcheur ne les distingue pas).

## Les noms des tronçons, du sud au nord. Le dernier est toujours celui de l'arrivée.
const TRONCONS := ["Le Gué", "La Tourbière", "Le Bois noyé", "La Lanterne"]
## La couleur du poteau planté sur chaque îlot (dit à la voix : « va jusqu'au poteau rouge »).
const BALISES := ["rouge", "bleu", "vert"]
## Les repères du décor que les guides nomment à la voix. `cote` : -1 à gauche (ouest), 1 à droite ;
## `f` : de 0 (la rive des guides) à 1 (le fond du marais).
const REPERES := [
	{"nom": "la barque échouée", "cote": 1, "f": 0.16},
	{"nom": "le grand saule", "cote": -1, "f": 0.28},
	{"nom": "le tronc couché", "cote": 1, "f": 0.46},
	{"nom": "la cabane du pêcheur", "cote": -1, "f": 0.6},
	{"nom": "la pierre dressée", "cote": 1, "f": 0.76},
	{"nom": "le héron de pierre", "cote": -1, "f": 0.9},
]


## Largeur et profondeur (en pierres) du marais.
static func dimensions(niveau: String) -> Vector2i:
	return {"simple": Vector2i(11, 15), "normal": Vector2i(11, 15), "dur": Vector2i(9, 11), "extreme": Vector2i(9, 9)}.get(niveau, Vector2i(11, 15))


## Combien de pierres sûres, au moins, sépare le départ de l'arrivée (le plus court chemin). C'est ce qui
## donne sa durée au jeu : une équipe qui guide bien pose le pied sur une pierre toutes les ~2 s.
static func longueur_cible(niveau: String) -> int:
	return {"simple": 74, "normal": 72, "dur": 37, "extreme": 29}.get(niveau, 52)


## Le nombre de tronçons (îlots + 1).
static func nb_etapes(niveau: String) -> int:
	return {"simple": 4, "normal": 4, "dur": 3, "extreme": 2}.get(niveau, 4)


## Le nom du tronçon i sur s tronçons (le dernier est l'arrivée).
static func nom_etape(i: int, s: int) -> String:
	if i >= s - 1:
		return TRONCONS[3]
	return TRONCONS[mini(i, 2)]


## Le tronçon « Tourbière » (pierres qui s'enfoncent) existe-t-il à ce niveau ?
static func a_tourbiere(niveau: String) -> bool:
	return nb_etapes(niveau) >= 3


## La période (s) d'une pierre qui s'enfonce : de plus en plus vive.
static func periode(niveau: String) -> float:
	return {"simple": 6.0, "normal": 5.2, "dur": 4.4, "extreme": 4.0}.get(niveau, 5.2)


## Une pierre qui s'enfonce est-elle HAUTE (praticable) à l'instant t ? Chacune a son décalage (k) : elles ne
## battent pas toutes ensemble. Haute 65 % du temps.
static func haute(t: float, k: int, niveau: String) -> bool:
	return phase_mobile(t, k, niveau) < 0.65


## Où en est la pierre dans son cycle (0..1).
static func phase_mobile(t: float, k: int, niveau: String) -> float:
	var p := periode(niveau)
	return fposmod(t + float(k) * 1.37, p) / p


## Reste-t-elle haute pendant encore `d` secondes ? (Un bot n'y met le pied que si oui.)
static func haute_pendant(t: float, k: int, niveau: String, d: float) -> bool:
	return haute(t, k, niveau) and haute(t + d, k, niveau) and haute(t + d * 0.5, k, niveau)


## Le centre de la pierre k, en local à la clairière (une rive sud fixe, le marais s'étend vers le nord).
static func centre(k: int, l: int, h: int) -> Vector3:
	return Quetes.case_marais(k, l, h)


## Cette case est-elle une pierre sur laquelle on peut se tenir quand elle est haute ?
static func est_sure(c: String) -> bool:
	return c == "." or c == "X" or c == "m"


## Les cases voisines (haut, bas, gauche, droite) de c dans une grille l × h.
static func voisines(c: int, l: int, h: int) -> Array[int]:
	var r: Array[int] = []
	var x := c % l
	var y := c / l
	if y > 0:
		r.append(c - l)
	if y < h - 1:
		r.append(c + l)
	if x > 0:
		r.append(c - 1)
	if x < l - 1:
		r.append(c + 1)
	return r


## Le plus court chemin de pierres sûres de `depuis` à `but` : les cases à suivre (départ exclu), vide s'il n'y en a pas.
static func chemin(carte: String, l: int, h: int, depuis: int, but: int) -> Array:
	var prec := {depuis: -1}
	var file: Array = [depuis]
	var tete := 0
	while tete < file.size():
		var c: int = file[tete]
		tete += 1
		if c == but:
			var res: Array = []
			var k := c
			while k != depuis:
				res.push_front(k)
				k = prec[k]
			return res
		for v in voisines(c, l, h):
			if not prec.has(v) and est_sure(carte[v]):
				prec[v] = c
				file.append(v)
	return []


## Tout le marais d'un coup : {l, h, carte, depart, but, iles (cases des poteaux, du sud au nord), longueur (plus court chemin)}.
## Déterministe pour une graine donnée.
static func generer(niveau: String, rng: RandomNumberGenerator) -> Dictionary:
	var d := dimensions(niveau)
	var l := d.x
	var h := d.y
	var cible := longueur_cible(niveau)
	var meilleur: Array = []
	var ecart_min := 1 << 30
	for essai in 400:
		var tr := _tracer(l, h, rng)
		var ecart := absi(tr.size() - 1 - cible)
		if tr.size() - 1 >= cible and tr.size() - 1 <= cible + maxi(6, cible / 4):
			meilleur = tr
			break
		if ecart < ecart_min:
			ecart_min = ecart
			meilleur = tr
	return _habiller(niveau, l, h, meilleur, rng)


## Un parcours en lacets : des allées horizontales reliées par des liaisons verticales. Les allées sont
## espacées d'au moins deux rangées : elles ne se touchent jamais, donc aucun raccourci. [cases, départ → arrivée]
static func _tracer(l: int, h: int, rng: RandomNumberGenerator) -> Array:
	var r := h - 1
	var c := rng.randi_range(1, l - 2)
	var sens := 1 if rng.randf() < 0.5 else -1
	var chemin_: Array = [r * l + c]
	while true:
		# L'allée horizontale.
		var longueur := rng.randi_range(maxi(3, l - 4), l - 1)
		var cible_c := clampi(c + sens * longueur, 0, l - 1)
		if cible_c == c:
			sens = -sens
			cible_c = clampi(c + sens * longueur, 0, l - 1)
		var pas := 1 if cible_c > c else -1
		while c != cible_c:
			c += pas
			chemin_.append(r * l + c)
		if r == 0:
			break
		# La liaison verticale : 2, 3 ou 4 rangées plus haut (plus on espace, plus il y a de place pour des culs-de-sac).
		var sp := 2
		var tirage := rng.randf()
		if tirage > 0.78:
			sp = 3
		if tirage > 0.95:
			sp = 4
		sp = mini(sp, r)
		if r - sp == 1:
			sp += 1      # jamais une allée juste sous la dernière rangée : elle la toucherait
		for i in sp:
			chemin_.append((r - 1 - i) * l + c)
		r -= sp
		sens = -sens
	return chemin_


static func _habiller(niveau: String, l: int, h: int, chem: Array, rng: RandomNumberGenerator) -> Dictionary:
	var carte := PackedStringArray()
	for k in l * h:
		carte.append("~")
	var depart: int = chem[0]
	var but: int = chem[chem.size() - 1]
	for k: int in chem:
		carte[k] = "."
	carte[but] = "X"
	# Les îlots : à intervalles réguliers du parcours, la case du poteau et deux voisines libres, toujours sûres.
	var s := nb_etapes(niveau)
	var iles: Array[int] = []
	var rangees_iles: Array[int] = []
	for i in range(1, s):
		var idx := roundi(float(chem.size() - 1) * float(i) / float(s))
		idx = clampi(idx, 3, chem.size() - 4)
		var ck: int = chem[idx]
		iles.append(ck)
		rangees_iles.append(ck / l)
		var ajoutees := 0
		var voisines_: Array[int] = voisines(ck, l, h)
		# Mélange : les îlots ne prennent pas toujours le même côté.
		for a in range(voisines_.size() - 1, 0, -1):
			var b := rng.randi_range(0, a)
			var tmp := voisines_[a]
			voisines_[a] = voisines_[b]
			voisines_[b] = tmp
		for v in voisines_:
			if ajoutees >= 2:
				break
			if carte[v] != "~":
				continue
			# Un îlot ne touche que son poteau : sinon il ferait un raccourci entre deux allées.
			var libre_ := true
			for w in voisines(v, l, h):
				if w != ck and carte[w] != "~":
					libre_ = false
			if libre_:
				carte[v] = "."
				ajoutees += 1
	# Les embranchements : de petites allées de pierres sûres qui ne mènent nulle part.
	var occupees := {}
	for k in l * h:
		if carte[k] != "~":
			occupees[k] = true
	var nb_branches := maxi(3, chem.size() / 7)
	for essai in nb_branches * 6:
		if nb_branches <= 0:
			break
		var depart_b: int = chem[rng.randi_range(2, chem.size() - 3)]
		var longueur := rng.randi_range(2, 4)
		var cur := depart_b
		var ajout: Array[int] = []
		for i in longueur:
			var cand: Array[int] = []
			for v in voisines(cur, l, h):
				if occupees.has(v) or ajout.has(v):
					continue
				# Une branche ne touche ni le parcours, ni une autre branche (sauf par son point de départ).
				var touche := false
				for w in voisines(v, l, h):
					if w != cur and (occupees.has(w) or ajout.has(w)):
						touche = true
				if not touche:
					cand.append(v)
			if cand.is_empty():
				break
			cur = cand[rng.randi_range(0, cand.size() - 1)]
			ajout.append(cur)
		if ajout.size() >= 2 or (ajout.size() == 1 and rng.randf() < 0.4):
			for v in ajout:
				carte[v] = "."
				occupees[v] = true
			nb_branches -= 1
	# Le reste : des pièges, qui imitent les pierres sûres ; des trous (de l'eau) ailleurs.
	var tourbiere_haut := -1     # rangées [haut, bas] de la tourbière
	var tourbiere_bas := -1
	if a_tourbiere(niveau) and rangees_iles.size() >= 2:
		tourbiere_haut = rangees_iles[1]
		tourbiere_bas = rangees_iles[0]
	elif a_tourbiere(niveau) and rangees_iles.size() == 1:
		tourbiere_haut = 0
		tourbiere_bas = rangees_iles[0]
	for k in l * h:
		if carte[k] != "~":
			continue
		var pres := false
		for v in voisines(k, l, h):
			if carte[v] != "~":
				pres = true
		var diag := false
		var x := k % l
		var y := k / l
		for dx in [-1, 1]:
			for dy in [-1, 1]:
				var xx: int = x + dx
				var yy: int = y + dy
				if xx >= 0 and yy >= 0 and xx < l and yy < h and carte[yy * l + xx] != "~":
					diag = true
		var p := 0.66 if pres else (0.4 if diag else 0.12)
		if rng.randf() < p:
			var dans_tourbiere := tourbiere_haut >= 0 and y >= tourbiere_haut and y <= tourbiere_bas
			carte[k] = "t" if dans_tourbiere and rng.randf() < 0.55 else "#"
	# Les pierres qui s'enfoncent sur le parcours de la tourbière : jamais deux de suite, jamais près d'un îlot.
	if tourbiere_haut >= 0:
		var derniere_m := -10
		for i in range(1, chem.size() - 1):
			var k: int = chem[i]
			var y := k / l
			if y < tourbiere_haut or y > tourbiere_bas:
				continue
			if carte[k] != ".":
				continue
			var pres_ile := false
			for ile in iles:
				if absi(ile % l - k % l) + absi(ile / l - k / l) <= 2:
					pres_ile = true
			if pres_ile or i - derniere_m < 3:
				continue
			if rng.randf() < 0.4:
				carte[k] = "m"
				derniere_m = i
	var chaine := "".join(carte)
	return {"l": l, "h": h, "carte": chaine, "depart": depart, "but": but, "iles": iles,
		"longueur": chemin(chaine, l, h, depart, but).size()}


## Le tronçon où se trouve la rangée y (0 = le plus au sud), connaissant les rangées des îlots (du sud au nord).
static func etape_de_rangee(y: int, rangees_iles: Array) -> int:
	var e := 0
	for r: int in rangees_iles:
		if y <= r:
			e += 1
	return e
