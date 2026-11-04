extends MiniJeu
## Le Grand Coffre : un seul coffre pour tout le monde, un CADENAS À MOLETTES par joueur, accroché
## à une chaîne devant lui. Les joueurs sont répartis en groupes de 3 ou 4 (on préfère 4). Chacun a
## SON code. Il en connaît un chiffre, avec sa place ; les autres sont détenus par ses coéquipiers
## (plusieurs chiffres chacun aux niveaux faciles : la partie est plus longue). L'un d'eux donne la
## place de ses chiffres, un autre non : il reste à deviner l'ordre de deux chiffres au plus.
## Chacun peut MENTIR à l'oral sur ce qu'il détient (voulu : on finit par s'en apercevoir) ; la
## fiche désigne les autres par leur bandeau, jamais par leur nom.
##
## Le geste (31/10 → 01/11) : on VISE une molette et on la TOURNE (molette de la souris, ou clic
## tenu + glisser), chiffre après chiffre, puis on TIRE l'anse. Mauvais code : l'anse résiste, la
## serrure se bloque quelques secondes ET une vie d'ÉQUIPE s'en va ; à 0 vie, la quête échoue.
## Selon le niveau : la moitié, les trois quarts ou toutes les serrures à ouvrir.
## Actions : {"roue": k, "pas": ±1} (une molette d'un cran) · {"tirer": true} (l'anse).
## Le temps limite est `Quetes.duree_max(niveau)` ; la longueur des codes (cf. `longueur_code`) est
## calibrée pour qu'une équipe qui joue bien mette au moins `Quetes.duree_min(niveau)`.

## Vies de l'équipe selon le niveau (-1 : illimitées). Elles sont PARTAGÉES par toute l'équipe (un
## mauvais code, de n'importe qui, en coûte une à tous) comme celles des autres jeux au niveau dur.
const VIES := {"simple": -1, "normal": 10, "dur": 3, "extreme": 1}
const BLOCAGE := 5.0         # secondes de serrure bloquée après un mauvais code
const CRANS := 10            # chiffres d'une molette : 0 à 9

## Rythme des bots (secondes) : ce que ferait une équipe qui joue bien, en parlant.
## Par indice dit à voix haute dans le groupe, et le temps de recouper les indices, noter, vérifier.
const BOT_RYTHME := {"simple": [6.0, 12.0], "normal": [6.0, 12.0], "dur": [5.0, 12.0], "extreme": [4.5, 16.0]}
const BOT_VISER := 0.8       # passer d'une molette à la suivante
const BOT_CRAN := 0.42       # un cran tourné
const BOT_TIRER := 1.4       # prendre l'anse et tirer

var groupes: Array = []              # [[ids…], …]
var groupe_de := {}                  # id -> index du groupe
var codes := {}                      # id -> [chiffres]
var propre := {}                     # id -> {"pos": int, "chiffre": int} : ce qu'il sait de SON code
var detenus := {}                    # id -> [{"pour": id, "pos": int, "chiffre": int, "place": bool}]
var roues := {}                      # id -> [chiffre affiché sur chaque molette]
var essais := {}                     # id -> nombre de mauvais codes tirés (le décor s'en sert pour secouer)
var vies := -1                       # vies restantes de l'équipe (-1 : illimitées)
var requises := 0                    # serrures à ouvrir
var bloque := {}                     # id -> temps où sa serrure se débloque
var _bot_t := {}                     # id -> temps avant de se mettre à tourner
var _bot_dit := {}
var _bot_fautif := {}
var _bot_cible := {}                 # id -> [chiffres à afficher] (vide : il n'a pas commencé)
var _bot_k := {}                     # id -> molette en cours
var _bot_pause := {}
var _parle_a := {}                   # id -> l'instant où il dit ce qu'il sait à son groupe
var _fin_dit := {}                   # id -> l'instant où il a fini de le dire
var _dit_chiffre := {}               # id -> les chiffres qu'il DIT, dans l'ordre de detenus (faux si c'est un bot menteur)
var _pret_a := {}                    # id -> l'instant où il a tout entendu, compris et noté : il peut régler son cadenas
var _reac := {}                      # id -> son temps de réaction à lui
var _bot_essayes := {}               # id -> les codes qu'il a déjà tentés
var _bot_echecs := {}                # id -> combien de fois la serrure a résisté
var _bot_mute := {}                  # id -> le code qu'il règle contient une faute de lecture (à ne pas compter comme essayé)


# ---------------------------------------------------------------- règles pures (testées)

## Les tailles de groupes pour n inscrits, de 4 de préférence ; [] si c'est impossible (1, 2, 5).
static func decouper(n: int) -> Array:
	if n < 3 or n == 5:
		return []
	var tailles: Array = []
	var quatre := n / 4
	var reste := n % 4
	if reste == 1:        # 9, 13, 17… : trois groupes de 3, le reste en 4
		quatre -= 2
		reste = 0
		tailles.append_array([3, 3, 3])
	elif reste == 2:      # 6, 10, 14… : deux groupes de 3
		quatre -= 1
		tailles.append_array([3, 3])
	elif reste == 3:
		tailles.append(3)
	for i in quatre:
		tailles.push_front(4)
	return tailles


## Combien de serrures faut-il ouvrir (n serrures au total) : la moitié, les trois quarts ou toutes.
static func serrures_requises(n: int, niveau: String) -> int:
	if niveau == "simple":
		return (n + 1) / 2
	if niveau == "normal":
		return (3 * n + 3) / 4
	if niveau == "dur":
		return (7 * n + 7) / 8       # à mi-chemin entre les trois quarts et toutes
	return n


static func vies_pour(niveau: String) -> int:
	return int(VIES.get(niveau, -1))


## Combien de chiffres chaque coéquipier détient POUR UN AUTRE, selon le niveau : plus il y en a,
## plus on a de choses à se dire (et de molettes à tourner) — c'est ce qui allonge la partie. Un groupe
## de 3 n'a que deux coéquipiers : on leur en donne un de plus chacun, pour que les deux tailles de
## groupe durent à peu près autant.
static func chiffres_par_coequipier(niveau: String, taille: int) -> int:
	var par_taille: Array = {"simple": [3, 2], "normal": [3, 2], "dur": [2, 1], "extreme": [1, 1]}.get(niveau, [1, 1])
	return int(par_taille[0 if taille <= 3 else 1])


## Les molettes du cadenas d'un joueur dont le groupe compte `taille` personnes : un chiffre à lui,
## plus `chiffres_par_coequipier` par coéquipier.
static func longueur_code(niveau: String, taille: int) -> int:
	return 1 + (taille - 1) * chiffres_par_coequipier(niveau, taille)


## La molette tournée d'un cran (sens +1 ou -1), qui fait le tour.
static func tourner_cran(chiffre: int, pas: int) -> int:
	return posmod(chiffre + (1 if pas > 0 else -1), CRANS)


## Combien de crans il faut tourner, au plus court, pour aller de `de` à `vers` : (sens, nombre).
static func chemin_cran(de: int, vers: int) -> Array:
	var avant := posmod(vers - de, CRANS)
	var arriere := CRANS - avant
	if avant == 0:
		return [1, 0]
	return [1, avant] if avant <= arriere else [-1, arriere]


static func place_texte(pos: int, longueur: int) -> String:
	if pos == longueur - 1 and pos > 0:
		return "dernière"
	return "1re" if pos == 0 else "%de" % (pos + 1)


# ---------------------------------------------------------------- mise en place

func demarrer() -> void:
	duree = Quetes.duree_max(niveau)
	vies = vies_pour(niveau)
	var tailles := decouper(ids.size())
	if tailles.is_empty():
		# Effectif refusé (le meneur a normalement remplacé le jeu avant) : un seul groupe.
		tailles = [ids.size()]
	var melange: Array[int] = ids.duplicate()
	for i in range(melange.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var x := melange[i]
		melange[i] = melange[j]
		melange[j] = x
	var debut := 0
	for t: int in tailles:
		var g: Array = melange.slice(debut, debut + t)
		debut += t
		for id in g:
			groupe_de[id] = groupes.size()
		groupes.append(g)
	requises = serrures_requises(ids.size(), niveau)
	for id in ids:
		detenus[id] = []
		essais[id] = 0
		_bot_dit[id] = false
		_bot_fautif[id] = false
		_bot_cible[id] = []
		_bot_k[id] = 0
		_bot_pause[id] = 0.0
		_bot_essayes[id] = []
		_bot_echecs[id] = 0
		_bot_mute[id] = false
		_reac[id] = RythmeHumain.reaction(rng)
	for g: Array in groupes:
		_repartir(g)
	for id in ids:
		_dit_chiffre[id] = (detenus[id] as Array).map(func(e: Dictionary) -> int: return int(e["chiffre"]))
	for id in ids:
		var l: int = (codes[id] as Array).size()
		var zeros: Array[int] = []
		zeros.resize(l)
		zeros.fill(0)
		roues[id] = zeros
		_bot_t[id] = 0.0
	# Le groupe se parle à tour de rôle (chaque joueur dit son chiffre et ceux qu'il détient pour les autres) ; un joueur
	# n'a tout entendu qu'une fois le dernier de ses coéquipiers arrivé au bout, et il lui faut noter et recouper.
	for g3: Array in groupes:
		var curseur := rng.randf_range(2.5, 4.0)
		for q: int in g3:
			var nb_dits: int = 1 + (detenus[q] as Array).size()
			_parle_a[q] = curseur
			_fin_dit[q] = curseur + RythmeHumain.parole(int(MOTS_PAR_INDICE[niveau]) * nb_dits)
			curseur = float(_fin_dit[q]) + 0.6
		for q: int in g3:
			var dernier := 0.0
			var concernes := 0
			for r: int in g3:
				if r == q:
					continue
				dernier = maxf(dernier, float(_fin_dit[r]))
				for e: Dictionary in detenus[r]:
					if int(e["pour"]) == q:
						concernes += 1
			_pret_a[q] = dernier + float(_reac[q]) + RythmeHumain.lecture(int(MOTS_PAR_INDICE[niveau]) * concernes) + _bot_reflexion() * 0.8 * rng.randf_range(0.8, 1.2)


## Les codes d'un groupe, et qui sait quoi.
func _repartir(g: Array) -> void:
	var taille := g.size()
	var m := chiffres_par_coequipier(niveau, taille)
	var l := longueur_code(niveau, taille)
	for p: int in g:
		var code: Array[int] = []
		for i in l:
			code.append(rng.randi_range(0, 9))
		codes[p] = code
		var places := _melanger(range(l))
		propre[p] = {"pos": places[0], "chiffre": code[places[0]]}
		var autres := _melanger(g.filter(func(x): return x != p))
		for i in autres.size():
			# Un seul coéquipier donne la place (un chiffre ou deux) quand on n'a qu'un chiffre chacun ;
			# avec plusieurs chiffres chacun, tous donnent les places sauf le dernier (m! ordres au plus).
			var avec_place: bool = (i == 0) if m == 1 else (i < autres.size() - 1)
			for j in m:
				var pos: int = places[1 + i * m + j]
				detenus[autres[i]].append({"pour": p, "pos": pos, "chiffre": code[pos], "place": avec_place})


func _melanger(a: Array) -> Array:
	var r := a.duplicate()
	for i in range(r.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var x = r[i]
		r[i] = r[j]
		r[j] = x
	return r


# ---------------------------------------------------------------- jeu

func _libre(id: int) -> bool:
	return not fini and ids.has(id) and not _reussis.get(id, false) and temps >= float(bloque.get(id, 0.0))


func action(id: int, d: Dictionary) -> void:
	if not _libre(id):
		return
	if d.has("roue"):
		var k := int(d["roue"])
		var r: Array = roues[id]
		if k >= 0 and k < r.size():
			r[k] = tourner_cran(int(r[k]), int(d.get("pas", 1)))
		return
	if not d.get("tirer", false):
		return
	var code: Array = codes[id]
	var juste := true
	for k in code.size():
		if int(roues[id][k]) != int(code[k]):
			juste = false
	if juste:
		_reussis[id] = true
		if reussis().size() >= requises:
			terminer()
		return
	essais[id] = int(essais[id]) + 1
	bloque[id] = temps + BLOCAGE
	if vies > 0:
		vies = vies_apres(vies)   # des bots seuls ne perdent pas la dernière vie avant le plancher du niveau
		if vies == 0:
			terminer()


func equipe_reussit() -> bool:
	return reussis().size() >= requises and vies != 0


func seuil_requis() -> int:
	return requises


func vue_pour(id: int) -> Dictionary:
	var blocs := []
	var l: int = (codes[id] as Array).size() if codes.has(id) else 0
	if l == 0:
		return {"consigne": "", "blocs": blocs}
	var p: Dictionary = propre[id]
	blocs.append(MiniJeu.texte("Un de tes chiffres : le %d, en %s place." % [p["chiffre"], place_texte(int(p["pos"]), l)] if l > 1 else "Ton chiffre : le %d." % p["chiffre"], 24, "or"))
	var liste_d: Array = detenus.get(id, [])
	if not liste_d.is_empty():
		blocs.append(MiniJeu.texte("Ce que tu sais du code des autres (dis-le-leur) :", 18, "gris"))
		# Un chiffre sans place qui revient deux fois pour le même coéquipier : une seule ligne, comptée.
		var vus := {}
		for e: Dictionary in liste_d:
			if not e["place"]:
				var cle := "%d/%d" % [int(e["pour"]), int(e["chiffre"])]
				vus[cle] = int(vus.get(cle, 0)) + 1
		var dits := {}
		for e: Dictionary in liste_d:
			if e["place"]:
				blocs.append(MiniJeu.texte("Code de %s : un %d, en %s place" % [nom(int(e["pour"])), e["chiffre"], place_texte(int(e["pos"]), (codes[e["pour"]] as Array).size())], 22, "or"))
			else:
				var cle2 := "%d/%d" % [int(e["pour"]), int(e["chiffre"])]
				if dits.has(cle2):
					continue
				dits[cle2] = true
				if int(vus[cle2]) > 1:
					blocs.append(MiniJeu.texte("Code de %s : %d fois le %d" % [nom(int(e["pour"])), vus[cle2], e["chiffre"]], 22, "or"))
				else:
					blocs.append(MiniJeu.texte("Code de %s : un %d" % [nom(int(e["pour"])), e["chiffre"]], 22, "or"))
	if _reussis.get(id, false):
		blocs.append(MiniJeu.texte("Ton code ouvre ta serrure. Aide les autres !", 22, "vert"))
	else:
		var reste_b := float(bloque.get(id, 0.0)) - temps
		if reste_b > 0.0:
			blocs.append(MiniJeu.texte("Serrure bloquée : encore %d s." % int(ceil(reste_b)), 22, "rouge"))
	if vies < 0:
		blocs.append(MiniJeu.texte("Vies de l'équipe : illimitées. Un mauvais code ne fait que bloquer ta serrure quelques secondes.", 16, "gris"))
	else:
		blocs.append(MiniJeu.texte("Vies de l'équipe : %d. Chaque mauvais code en coûte une à tout le monde ; à 0, la quête échoue." % vies, 18, "rouge" if vies <= 1 else "gris"))
	blocs.append(MiniJeu.texte("Serrures ouvertes : %d / %d (il en faut %d)" % [reussis().size(), ids.size(), requises], 16, "gris"))
	var ouvertes: Array = []
	var cadenas: Array = []
	for k in ids.size():
		var q: int = ids[k]
		if _reussis.get(q, false):
			ouvertes.append(k)
		cadenas.append({"n": (codes[q] as Array).size(), "r": (roues[q] as Array).duplicate(), "o": _reussis.get(q, false),
			"b": maxf(float(bloque.get(q, 0.0)) - temps, 0.0), "e": int(essais[q])})
	return {"consigne": "Chacun a son cadenas à %d molettes sur le grand coffre. Tu connais un de ses chiffres ; tes coéquipiers détiennent les autres. Parlez-vous (on peut mentir !), puis tourne tes molettes et tire l'anse." % l,
		"blocs": blocs, "ouvertes": ouvertes, "vies": vies, "vies_max": vies_pour(niveau), "cadenas": cadenas}


func _bot_parole() -> float:
	return float((BOT_RYTHME[niveau] as Array)[0])


func _bot_reflexion() -> float:
	return float((BOT_RYTHME[niveau] as Array)[1])


## Tous les codes qu'un joueur peut croire, d'après ce qu'on lui a dit : `fixes` (position -> chiffre) ce dont il connaît la
## place, `libres` les chiffres qu'on lui a donnés SANS place, à ranger dans les positions restantes (dans tous les ordres
## possibles, sans doublon). Chaque code est un tableau de `longueur` chiffres ; [] si ça ne tombe pas juste (trop ou trop peu
## de chiffres pour les places libres) : on lui a dit n'importe quoi.
static func codes_possibles(longueur: int, fixes: Dictionary, libres: Array) -> Array:
	var places: Array[int] = []
	for p in longueur:
		if not fixes.has(p):
			places.append(p)
	if places.size() != libres.size():
		return []
	var sortie: Array = []
	var vus := {}
	for ordre_ in _permutations(libres):
		var code: Array = []
		code.resize(longueur)
		for p in fixes:
			code[int(p)] = int(fixes[p])
		for i in places.size():
			code[places[i]] = int(ordre_[i])
		var cle := ",".join(PackedStringArray(code.map(func(c): return str(c))))
		if not vus.has(cle):
			vus[cle] = true
			sortie.append(code)
	return sortie


static func _permutations(a: Array) -> Array:
	if a.size() <= 1:
		return [a.duplicate()]
	var r: Array = []
	for i in a.size():
		var reste := a.duplicate()
		reste.remove_at(i)
		for sous: Array in _permutations(reste):
			sous.push_front(a[i])
			r.append(sous)
	return r


## La chance qu'un joueur lise de travers un chiffre en réglant son cadenas (un cran de trop ou de moins sur une molette).
static func erreur_reglage(niveau: String) -> float:
	return {"simple": 0.06, "normal": 0.06, "dur": 0.04, "extreme": 0.03}.get(niveau, 0.05)


## Les mots d'un indice dit à voix haute (« Code de la personne au bandeau rouge : un 4, en 2e place ») : le temps de le dire.
## Quand le temps presse (niveaux dur et extrême) on parle court (« Rouge : 4, deuxième »).
const MOTS_PAR_INDICE := {"simple": 9, "normal": 9, "dur": 7, "extreme": 5}


## Ce que ce joueur a compris du code de CE bot, d'après ce que ses coéquipiers ont dit (et qu'il a eu le temps d'entendre).
## Rend {"fixes": {pos: chiffre}, "libres": [chiffres sans place]}.
func _compris(id: int) -> Dictionary:
	var p: Dictionary = propre[id]
	var fixes := {int(p["pos"]): int(p["chiffre"])}
	var libres: Array = []
	for q: int in groupes[groupe_de[id]]:
		if q == id:
			continue
		var liste_q: Array = detenus[q]
		for i in liste_q.size():
			var e: Dictionary = liste_q[i]
			if int(e["pour"]) != id:
				continue
			var dit_: int = int((_dit_chiffre[q] as Array)[i])
			if e["place"]:
				fixes[int(e["pos"])] = dit_
			else:
				libres.append(dit_)
	return {"fixes": fixes, "libres": libres}


func bot(id: int, delta: float) -> void:
	if not _libre(id):
		return
	if not _bot_dit[id]:
		# Il dit ce qu'il sait au groupe, à son tour (les autres écoutent), pas avant.
		if temps < float(_parle_a[id]):
			return
		_bot_dit[id] = true
		var dits := PackedStringArray()
		var p: Dictionary = propre[id]
		var l: int = (codes[id] as Array).size()
		dits.append("Mon chiffre : %d, en %s place." % [p["chiffre"], place_texte(int(p["pos"]), l)])
		# Un saboteur change UN chiffre de ce qu'il dit, une fois sur deux : pas une rafale de mensonges.
		var menteur := -1
		if peut_saboter(id) and (detenus[id] as Array).size() > 0 and rng.randf() < 0.5:
			menteur = rng.randi_range(0, (detenus[id] as Array).size() - 1)
		for i in (detenus[id] as Array).size():
			var e: Dictionary = (detenus[id] as Array)[i]
			var c: int = e["chiffre"]
			var pos: int = e["pos"]
			if i == menteur:
				c = (c + rng.randi_range(1, 9)) % 10
				(_dit_chiffre[id] as Array)[i] = c
			var lp: int = (codes[e["pour"]] as Array).size()
			if e["place"]:
				dits.append("%s : %d, en %s place." % [nom(int(e["pour"])), c, place_texte(pos, lp)])
			else:
				dits.append("%s : %d." % [nom(int(e["pour"])), c])
		paroles.append([id, "\n".join(dits)])
		return
	_bot_t[id] = float(_bot_t[id]) - delta
	if float(_bot_t[id]) > 0.0:
		return
	if (_bot_cible[id] as Array).is_empty():
		# Il attend d'avoir tout entendu, puis il recoupe et note.
		if temps < float(_pret_a[id]):
			_bot_t[id] = 0.3
			return
		var voulu: Array = _code_voulu(id)
		var cible: Array = voulu.duplicate()
		_bot_mute[id] = false
		# Un saboteur règle faux exprès, une seule fois (jamais au niveau où l'erreur coûte l'unique vie) ; les autres se
		# trompent rarement en lisant leur fiche.
		var tromper: bool = peut_saboter(id) and not _bot_fautif[id] and niveau != "extreme" and rng.randf() < 0.5
		_bot_fautif[id] = true
		if tromper or rng.randf() < erreur_reglage(niveau):
			var k_ := rng.randi_range(0, cible.size() - 1)
			cible[k_] = posmod(int(cible[k_]) + (1 if rng.randf() < 0.5 else -1), CRANS)
			_bot_mute[id] = true
		if not _bot_mute[id]:
			(_bot_essayes[id] as Array).append(voulu)
		_bot_cible[id] = cible
		_bot_k[id] = 0
		_bot_pause[id] = BOT_VISER
		return
	_bot_pause[id] = float(_bot_pause[id]) - delta
	if float(_bot_pause[id]) > 0.0:
		return
	var k: int = _bot_k[id]
	var cible2: Array = _bot_cible[id]
	if k >= cible2.size():
		# Toutes les molettes sont en place : il tire l'anse (réussi ou résisté, il recommencera).
		_bot_cible[id] = []
		_bot_t[id] = 0.0
		action(id, {"tirer": true})
		if not _reussis.get(id, false):
			# La serrure résiste : il s'en aperçoit, souffle, et reprend son raisonnement.
			_bot_t[id] = RythmeHumain.regret(rng)
			_bot_echecs[id] = int(_bot_echecs[id]) + 1
		return
	var ch := chemin_cran(int((roues[id] as Array)[k]), int(cible2[k]))
	if int(ch[1]) == 0:
		_bot_k[id] = k + 1
		_bot_pause[id] = BOT_TIRER if k + 1 >= cible2.size() else BOT_VISER
		return
	action(id, {"roue": k, "pas": int(ch[0])})
	_bot_pause[id] = BOT_CRAN


## Le code que ce bot va régler : un de ceux que ce qu'il a compris permet, qu'il n'a pas encore essayé. Quand il a tout essayé
## (ou qu'on lui a dit quelque chose d'incohérent), le groupe se reparle et la vérité sort.
func _code_voulu(id: int) -> Array:
	var c := _compris(id)
	var possibles := codes_possibles((codes[id] as Array).size(), c["fixes"], c["libres"])
	var essayes: Array = _bot_essayes[id]
	var restants: Array = []
	for cand: Array in possibles:
		if not essayes.has(cand):
			restants.append(cand)
	if restants.is_empty() or int(_bot_echecs[id]) >= 2:
		return (codes[id] as Array).duplicate()
	return (restants[rng.randi_range(0, restants.size() - 1)] as Array).duplicate()
