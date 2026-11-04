extends MiniJeu
## Le Radeau des rapides : une VRAIE descente. Le radeau avance dans la rivière en fonction des coups
## de rame de l'équipe, et dérive de côté quand un bord rame plus que l'autre : ramer du bord DROIT
## pousse le radeau vers la gauche (et inversement). Des rochers arrivent dans trois couloirs
## (gauche, milieu, droite) ; seul le joueur de l'AVANT (il change toutes les 30 secondes) les voit
## de loin : il doit les crier, et le bon bord doit ramer AU BON MOMENT (le courant ramène le radeau
## au milieu, ramer trop tôt ne sert à rien). La rivière a des gorges (les parois raclent la coque)
## et des rapides de plus en plus durs (des remous). Chaque rocher touché ou paroi raclée use la
## coque ; coque brisée : personne ne réussit.
## Réussite individuelle : le radeau accoste ET tu as donné assez de coups de rame (anti-resquilleur).
## Sabotage : ramer du mauvais bord au mauvais moment ; le radeau « tangue » sans dire d'où ça vient.
## L'avant peut aussi crier le mauvais bord. Règle du jour « Brouillard » : l'avant ne voit que 5 s.
## La durée vient de DimGestes.radeau_plan : la vitesse est plafonnée, une descente parfaite dure
## `DimGestes.cible(niveau)` (au-dessus du minimum du niveau), le temps limite est le maximum.

const FRONT := 2.0           # le rocher touche le radeau quand il arrive à cette distance du centre
const LAT_COULOIR := 0.9     # écart latéral (unités de lat) entre deux couloirs
const TOUCHE := 0.6          # un rocher est touché si le radeau est plus près que ça de son couloir
const LAT_AMORT := 2.2
const LAT_RAPPEL := 0.5      # le courant ramène le radeau au milieu
const IMPULSION := 1.1       # poussée latérale d'un coup de TOUT un bord (partagée entre ses rameurs)
const SOUFFLE_MAX := 4.0
const SOUFFLE_REGEN := 0.75
const TAU_PUISSANCE := 1.8   # la poussée avant retombe en ce temps
const TAU_VITESSE := 1.2
const LAT_OUVERT := 1.35
const LAT_GORGE := 1.0
const PAROI := 0.95          # au-delà, en gorge, la paroi racle la coque
const RELEVE_S := 30.0       # l'avant change toutes les 30 s de descente parfaite
const VUE_AVANT := 12.0      # secondes de descente que voit l'avant (5 dans le brouillard)
const VUE_AUTRES_M := 9.0    # ce que voient les autres : 9 m, trop peu pour réagir seuls

var plan := {}
var s := 0.0                 # distance parcourue (m)
var v := 0.0                 # vitesse (m/s)
var lat := 0.0               # position latérale (-1.35 gauche… +1.35 droite)
var vl := 0.0
var puissance := 0.0         # poussée avant récente des rameurs (0..1+)
var coque := 6
var coque_depart := 6
var cote := {}               # id -> 0 (bord gauche) / 1 (bord droit)
var bord_n := [0, 0]         # rameurs par bord
var coups := {}              # id -> coups de rame donnés
var souffle := {}
var annonce := ""
var _annonce_t := 0.0
var troncon := 0
var arrive := false
var racle := 0.0             # temps passé à frotter la paroi
var _remous_phase: Array[float] = [0.0, 0.0]
var _bot_t := {}
var _bot_row := {}           # id -> {"k": rangée, "ignore": bool, "fourbe": bool}
var _crie := {}              # s de la rangée -> couloirs criés par un avant bot (les bots le croient)
var _bot_avant_dit := -1.0
var _bots := {}
var _signalee := -1          # tronçon dont l'entrée a été annoncée
var _rangs := {}             # s de la rangée -> {"vu": quand l'avant l'a vue, "dit": quand il la crie, "su": quand les autres le savent}
var _coque_vue := -1         # la coque telle que les bots l'ont vue (un choc les fige un instant)


func demarrer() -> void:
	plan = DimGestes.radeau_plan(niveau, rng)
	coque = DimGestes.radeau_coque(niveau)
	coque_depart = coque
	duree = Quetes.duree_max(niveau)
	if niveau != "simple" and rng.randf() < 0.35:
		variante = "Brouillard"
	_remous_phase = [rng.randf() * TAU, rng.randf() * TAU]
	v = float(plan["troncons"][0]["vcur"])
	for i in ids.size():
		var id: int = ids[i]
		# Les rameurs de rang pair sont debout à droite du radeau (cf. DecorQuete.poste).
		cote[id] = 1 - (i % 2)
		bord_n[int(cote[id])] += 1
		coups[id] = 0
		souffle[id] = 3.0
		_bot_t[id] = rng.randf_range(0.2, 1.2)


func _dire(m: String) -> void:
	annonce = m
	_annonce_t = 2.8


func _tr() -> Dictionary:
	return plan["troncons"][troncon]


## L'avant : celui qui voit venir les rochers ; il change à chaque tranche de 30 s de descente parfaite.
func _avant() -> int:
	var nb := maxi(int(ceil(DimGestes.cible(niveau) / RELEVE_S)), 1)
	var k := clampi(int(s / maxf(float(plan["longueur"]), 1.0) * nb), 0, nb - 1)
	return ids[k % ids.size()]


func action(id: int, d: Dictionary) -> void:
	if fini or not ids.has(id) or not d.has("rame"):
		return
	if float(souffle[id]) < 1.0:
		return
	souffle[id] -= 1.0
	coups[id] += 1
	var c: int = int(cote[id])
	# Ramer du bord droit pousse le radeau à gauche (-), du bord gauche à droite (+).
	var sens := -1.0 if c == 1 else 1.0
	vl += sens * IMPULSION / float(maxi(bord_n[c], 1))
	puissance += 1.0 / float(ids.size())
	# Un coup qui jette le radeau vers un rocher proche : il tangue (sans dire qui).
	for r: Dictionary in plan["roches"]:
		var rel: float = float(r["s"]) - s
		if rel > 0.0 and rel < 8.0 and not r.get("fait", false):
			if signf(float(r["lane"]) * LAT_COULOIR - lat) == sens and absf(float(r["lane"]) * LAT_COULOIR - lat) < 0.8:
				_dire("Le radeau tangue !")
				break


## Un fantôme arrache la rame des mains de ce rameur : son souffle est vidé.
func _hanter(id: int) -> String:
	souffle[id] = 0.0
	return "La rame de %s lui échappe des mains." % nom(id)


func _frapper_roche(r: Dictionary) -> void:
	r["touche"] = true
	coque = vies_apres(coque)
	v *= 0.45
	puissance *= 0.4
	vl += -signf(float(r["lane"]) * LAT_COULOIR - lat) * 0.9 if absf(float(r["lane"]) * LAT_COULOIR - lat) > 0.05 else 0.0
	_dire("Le radeau racle un rocher !")
	if coque <= 0:
		_dire("Le radeau se brise !")
		terminer()


func avancer(delta: float) -> void:
	if fini:
		return
	for id in ids:
		souffle[id] = minf(float(souffle[id]) + SOUFFLE_REGEN * delta, SOUFFLE_MAX)
	puissance = maxf(puissance - puissance / TAU_PUISSANCE * delta, 0.0)
	troncon = DimGestes.troncon_a(plan["troncons"], s)
	var tr := _tr()
	if troncon != _signalee:
		_signalee = troncon
		if troncon > 0:
			_dire({"calme": "Le courant s'apaise.", "gorge": "Les gorges se resserrent !", "rapides": "Les rapides !"}[str(tr["type"])])
	var cible_v: float = float(tr["vcur"]) + (float(tr["vmax"]) - float(tr["vcur"])) * clampf(puissance, 0.0, 1.0)
	v += (cible_v - v) * minf(delta / TAU_VITESSE, 1.0)
	s += v * delta
	# Latéral : le courant ramène au milieu, l'eau freine, les remous bousculent.
	var remous := DimGestes.radeau_remous(int(tr["d"]), niveau)
	var tourbillon := remous * (sin(temps * 0.9 + _remous_phase[0]) + 0.6 * sin(temps * 2.3 + _remous_phase[1])) / 1.6
	vl += (-LAT_RAPPEL * lat - LAT_AMORT * vl + tourbillon) * delta
	lat += vl * delta
	var lim := LAT_GORGE if tr["type"] == "gorge" else LAT_OUVERT
	if absf(lat) >= lim:
		lat = signf(lat) * lim
		if signf(vl) == signf(lat):
			vl = 0.0
	if tr["type"] == "gorge" and absf(lat) > PAROI:
		racle += delta
		if racle > 1.1:
			racle = 0.0
			coque = vies_apres(coque)
			v *= 0.6
			vl = -signf(lat) * 0.5
			_dire("La paroi racle la coque !")
			if coque <= 0:
				_dire("Le radeau se brise !")
				terminer()
				return
	else:
		racle = maxf(racle - delta, 0.0)
	# Les rochers qui arrivent à la proue.
	for r: Dictionary in plan["roches"]:
		if r.get("fait", false):
			continue
		if float(r["s"]) - s <= FRONT:
			r["fait"] = true
			if absf(float(r["lane"]) * LAT_COULOIR - lat) < TOUCHE:
				_frapper_roche(r)
				if fini:
					return
	if s >= float(plan["longueur"]):
		arrive = true
		_dire("Vous accostez !")
		for id in ids:
			_reussis[id] = int(coups[id]) >= DimGestes.radeau_coups_requis(niveau)
		terminer()
		return
	_annonce_t -= delta
	if _annonce_t <= 0.0:
		annonce = ""
	super.avancer(delta)


func equipe_reussit() -> bool:
	return arrive and super.equipe_reussit()


func _roches_visibles(id: int) -> Array:
	var avant: bool = id == _avant()
	var horizon: float = 5.0 * 3.6 if variante == "Brouillard" else VUE_AVANT * 3.6
	var portee: float = horizon if avant else VUE_AUTRES_M
	var l := []
	for r: Dictionary in plan["roches"]:
		var rel: float = float(r["s"]) - s
		if rel > -8.0 and rel < portee:
			l.append([snappedf(rel, 0.05), int(r["lane"]), bool(r.get("touche", false))])
			if l.size() >= 10:
				break
	return l


func vue_pour(id: int) -> Dictionary:
	var blocs := []
	blocs.append({"t": "rame", "l": "Rame : clic tenu et tire la souris vers toi (poing fermé qui descend, devant la webcam)"})
	blocs.append(MiniJeu.texte("Tu rames du bord %s." % ("DROIT" if int(cote.get(id, 0)) == 1 else "GAUCHE"), 20, "or"))
	if id == _avant():
		blocs.append(MiniJeu.texte("Tu es à l'AVANT : tu vois les rochers de loin (le brouillard ne les montre qu'au dernier moment). Crie-les !" if variante == "Brouillard" else "Tu es à l'AVANT : tu vois les rochers de loin. Crie-les !", 18, "or"))
	blocs.append(MiniJeu.jauge(float(coque) / maxf(coque_depart, 1), "Coque du radeau", [], "vert"))
	blocs.append(MiniJeu.jauge(float(souffle.get(id, 0.0)) / SOUFFLE_MAX, "Souffle"))
	blocs.append(MiniJeu.jauge(s / maxf(float(plan["longueur"]), 1.0), "La rivière", [], "or"))
	if annonce != "":
		blocs.append(MiniJeu.texte(annonce, 24, "rouge"))
	blocs.append(MiniJeu.texte("Tes coups de rame : %d / %d" % [coups.get(id, 0), DimGestes.radeau_coups_requis(niveau)], 16, "vert" if int(coups.get(id, 0)) >= DimGestes.radeau_coups_requis(niveau) else "gris"))
	var consigne := "Descendez la rivière : ramez de votre bord pour avancer. Un rocher à droite : les rameurs de DROITE ramez pour l'écarter (ramer d'un bord pousse le radeau vers l'autre), au bon moment."
	if variante == "Brouillard":
		consigne = "Règle du jour : BROUILLARD. L'avant ne voit les rochers qu'au dernier moment : criez vite. Un rocher à droite : les rameurs de DROITE ramez pour l'écarter (ramer d'un bord pousse le radeau vers l'autre), au bon moment."
	var tr := _tr()
	var troncons := []
	for t: Dictionary in plan["troncons"]:
		troncons.append([snappedf(float(t["debut"]), 0.1), snappedf(float(t["long"]), 0.1), str(t["type"]), int(t["d"])])
	return {"consigne": consigne, "blocs": blocs, "vies": coque, "vies_max": coque_depart,
		"radeau": {"s": snappedf(s, 0.01), "v": snappedf(v, 0.01), "lat": snappedf(lat, 0.005), "vl": snappedf(vl, 0.01), "type": str(tr["type"]),
			"d": int(tr["d"]), "L": snappedf(float(plan["longueur"]), 0.1), "troncons": troncons, "roches": _roches_visibles(id),
			"coups": ids.map(func(x): return int(coups[x])), "bord": int(cote.get(id, 0)), "racle": racle > 0.2}}


# ---------------------------------------------------------------- les bots

## Les couloirs occupés de la rangée de rochers la plus proche devant, et sa distance (rel). {} s'il n'y en a pas
## dans les `portee` m (20 par défaut).
func _rangee_devant(portee := 20.0) -> Dictionary:
	var rel0 := 1e9
	var lanes: Array = []
	var s0 := 0.0
	for r: Dictionary in plan["roches"]:
		if r.get("fait", false):
			continue
		var rel: float = float(r["s"]) - s
		if lanes.is_empty():
			rel0 = rel
			s0 = float(r["s"])
			lanes.append(int(r["lane"]))
		elif absf(float(r["s"]) - s0) < 0.5:
			lanes.append(int(r["lane"]))
		else:
			break
	if lanes.is_empty() or rel0 > portee:
		return {}
	return {"s": s0, "rel": rel0, "lanes": lanes}


## Ce que l'avant met à voir, à dire et à être compris (rythme humain) : un coup d'oeil pour repérer les couloirs,
## puis la phrase. Un avant bot la dit à `dit` ; les autres bots la savent à `su` (premiers mots entendus +
## compréhension) ; si l'avant est une PERSONNE, ils lui laissent le temps de la phrase entière.
static func delais_avant(rng: RandomNumberGenerator, avant_bot: bool) -> Dictionary:
	var coup_d_oeil := rng.randf_range(0.5, 1.2)
	var comprendre := rng.randf_range(0.3, 0.7)
	var phrase := 0.8 if avant_bot else RythmeHumain.parole(4)
	return {"dit": coup_d_oeil, "su": coup_d_oeil + phrase + comprendre}


## Le rang (vu/dit/su) de la rangée visible la plus proche, créé quand l'avant la voit pour la première fois.
func _rang_de(avant: int) -> Dictionary:
	var horizon: float = (5.0 if variante == "Brouillard" else VUE_AVANT) * 3.6
	var ran := _rangee_devant(horizon)
	if ran.is_empty():
		return {}
	var k: float = float(ran["s"])
	if not _rangs.has(k):
		var d := delais_avant(rng, _bots.has(avant))
		_rangs[k] = {"vu": temps, "dit": temps + float(d["dit"]), "su": temps + float(d["su"]), "dit_fait": false}
	var rg: Dictionary = _rangs[k]
	rg["s"] = k
	rg["lanes"] = ran["lanes"]
	rg["rel"] = ran["rel"]
	return rg


func bot(id: int, delta: float) -> void:
	if fini:
		return
	_bots[id] = true
	var avant: int = _avant()
	var rg := _rang_de(avant)
	# L'avant bot crie la rangée une fois qu'il l'a repérée (un saboteur ment parfois, rarement).
	if id == avant and not rg.is_empty() and not bool(_rangs[float(rg["s"])]["dit_fait"]) and temps >= float(rg["dit"]):
		_rangs[float(rg["s"])]["dit_fait"] = true
		var dits: Array = []
		var ment: bool = peut_saboter(id) and rng.randf() < 0.25
		for c: int in rg["lanes"]:
			dits.append(-c if ment else c)
		_crie[float(rg["s"])] = dits
		if dits.size() == 1:
			paroles.append([id, {-1: "Rocher à GAUCHE ! Ramez de ce bord !", 0: "Rocher au MILIEU ! Poussez d'un côté ou de l'autre !", 1: "Rocher à DROITE ! Ramez de ce bord !"}[dits[0]]])
		else:
			var libre: int = 0
			for c: int in DimGestes.R_COULOIRS:
				if not dits.has(c):
					libre = c
			paroles.append([id, {-1: "Deux rochers ! Passez à GAUCHE !", 0: "Deux rochers ! Passez au MILIEU !", 1: "Deux rochers ! Passez à DROITE !"}[libre]])
	# Un choc : tout le monde souffle un instant avant de reprendre la rame.
	if _coque_vue < 0:
		_coque_vue = coque
	if coque < _coque_vue:
		_coque_vue = coque
		for x in ids:
			_bot_t[x] = maxf(float(_bot_t[x]), RythmeHumain.reaction(rng))
	_bot_t[id] -= delta
	if _bot_t[id] > 0.0:
		return
	_bot_t[id] = rng.randf_range(0.75, 1.3)
	# Un rameur regarde sa jauge de souffle : à bout, il attend.
	if float(souffle[id]) < 1.0:
		_bot_t[id] = 0.3
		return
	var c: int = int(cote[id])
	var sens := -1.0 if c == 1 else 1.0
	var cible_lat := 0.0
	var fourbe := false
	var ran := _rangee_devant()
	if not ran.is_empty():
		var k: float = float(ran["s"])
		var memo: Dictionary = _bot_row.get(id, {})
		if float(memo.get("k", -1.0)) != k:
			var manque: float = {"simple": 0.08, "normal": 0.10, "dur": 0.11, "extreme": 0.12}[niveau]
			memo = {"k": k, "ignore": rng.randf() < manque, "fourbe": peut_saboter(id) and rng.randf() < 0.2}
			_bot_row[id] = memo
		fourbe = bool(memo["fourbe"])
		if not bool(memo["ignore"]):
			# Ce que le bot sait : ce que l'avant a crié (une fois la phrase entendue et comprise), ou ce qu'il voit
			# lui-même quand le rocher est tout près (9 m). Sinon il ne sait pas où ils sont et reste au milieu.
			var crus: Array = []
			var rgk: Dictionary = _rangs.get(k, {})
			var su: bool = not rgk.is_empty() and temps >= float(rgk["su"])
			if id == avant:
				crus = ran["lanes"]
			elif su:
				crus = _crie[k] if _bots.has(avant) and _crie.has(k) else ran["lanes"]
			elif float(ran["rel"]) < VUE_AUTRES_M:
				crus = ran["lanes"]
			var libres: Array = DimGestes.R_COULOIRS.filter(func(x): return not crus.has(x))
			if not crus.is_empty() and not libres.is_empty() and float(ran["rel"]) < 17.0:
				libres.sort_custom(func(a, b): return absf(float(a) * LAT_COULOIR - lat) < absf(float(b) * LAT_COULOIR - lat))
				cible_lat = float(libres[0]) * LAT_COULOIR
	var dl := cible_lat - lat
	var veut: float = 0.0
	if absf(dl) > 0.15:
		veut = signf(dl) if not fourbe else -signf(dl)
	var p_coup := 0.85
	if veut != 0.0:
		p_coup = 1.0 if veut == sens else 0.12
	if rng.randf() < p_coup:
		action(id, {"rame": true})
