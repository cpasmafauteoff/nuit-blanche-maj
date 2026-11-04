extends MiniJeu
## Le Puits : une corde, un seau. La tension doit rester dans la zone pour que le seau monte :
## on la monte en tenant, on la baisse en lâchant. Chacun tient la corde à son tour ; le suivant
## doit la saisir AVANT que le précédent lâche, sinon elle file (il faut se prévenir à la voix).
## Plusieurs SEAUX à hisser, de plus en plus profonds donc de plus en plus LOURDS (ils montent plus
## lentement, retombent plus vite, la zone se resserre) ; entre deux seaux on vide, on redescend le suivant.
## Réussite individuelle : assez de temps dans la zone pendant TES tours.
## La durée vient de DimGestes.puits_plan : hisser tous les seaux sans quitter la zone dure déjà
## 85 % de la cible, donc jamais moins que le minimum du niveau ; le temps limite est le maximum.
## Sabotage : lâcher la corde au mauvais moment (n'importe qui peut le faire, un loup exprès).
## Tout le monde lit alors « La corde file ! » sans savoir pourquoi.

const ZONES := {"simple": [0.33, 0.67], "normal": [0.38, 0.64], "dur": [0.395, 0.635], "extreme": [0.41, 0.63]}
const MONTEE := 0.30            # tension gagnée par seconde quand on tient
const DESCENTE := 0.22          # tension perdue par seconde quand plus personne ne tient
## Serrer / lâcher la corde se refait plus vite qu'un geste ordinaire (RythmeHumain.CADENCE_MIN) : on ajuste sans cesse.
const CADENCE_CORDE := 0.25
const RELACHE := 1.5            # durée de la passation : le suivant peut saisir pendant ce délai

var zone: Array = [0.35, 0.65]
var zone_base: Array = [0.35, 0.65]
var tension := 0.5
var seau := 0.0                 # avancement du seau en cours (0..1)
var tour := 9.0
var plan := {}
var n_seau := 0                 # le seau en cours (0 = le plus léger)
var pause_t := 0.0              # > 0 : le seau est en haut, on le vide
var hisse := false              # tous les seaux sont remontés
var monte_r := MONTEE
var descente_r := DESCENTE
var tient := {}                 # id -> tient la corde (dernier état envoyé)
var zone_t := {}                # id -> secondes passées dans la zone pendant son tour
var tenu_t := {}                # id -> secondes passées à la corde (son tour)
var annonce := ""
var _annonce_t := 0.0
var _hors_t := 0.0
var _etait_dedans := true
var _c_prec := 0
var _bot_t := {}
var _bot_distrait := {}
var _bots := {}                 # les joueurs joués par des bots (vus passer dans `bot`)
var _prevenu := -1              # le tour où un bot a déjà prévenu son successeur humain
var _tour_vu := {}              # bot -> dernier tour dont il a réglé les manies
var _prise := {}                # bot -> à quel reste_tour il saisit la corde (suivant)
var _lache := {}                # saboteur -> à quel moment du tour il lâche (-1 : pas ce tour-ci)
var _plan := {}                 # bot -> {t, tenir} : le geste qu'il a décidé et qui part à l'instant t
var _dernier := {}              # bot -> instant de son dernier geste
var _sabo_apres := {}           # saboteur -> pas de nouveau lâcher avant cet instant


func demarrer() -> void:
	_init_vies()
	zone_base = ZONES[niveau]
	# Chaque puits a sa corde : la zone juste glisse un peu, les tours durent plus ou moins.
	var glisse := rng.randf_range(-0.08, 0.08)
	zone_base = [float(zone_base[0]) + glisse, float(zone_base[1]) + glisse]
	plan = DimGestes.puits_plan(niveau)
	tour = DimGestes.puits_tour(niveau, ids.size(), rng.randf_range(0.85, 1.15))
	duree = Quetes.duree_max(niveau)
	_regler_seau()
	tension = (float(zone[0]) + float(zone[1])) / 2.0
	for id in ids:
		tient[id] = false
		zone_t[id] = 0.0
		tenu_t[id] = 0.0
		_bot_t[id] = 0.0
		_bot_distrait[id] = 0.0


## Les réglages du seau en cours : plus profond, plus lourd.
func _regler_seau() -> void:
	var r: float = float((plan["zone_reduite"] as Array)[n_seau])
	zone = [float(zone_base[0]) + r, float(zone_base[1]) - r]
	monte_r = float((plan["montee"] as Array)[n_seau])
	descente_r = float((plan["descente"] as Array)[n_seau])


func _effort() -> float:
	return float((plan["effort"] as Array)[n_seau])


func _courant() -> int:
	return int(floor(temps / tour)) % ids.size()


func _reste_tour() -> float:
	return tour - fposmod(temps, tour)


## La part du temps passé à la corde qu'il faut avoir tenu dans la zone.
func _ratio() -> float:
	return {"simple": 0.5, "normal": 0.6, "dur": 0.65, "extreme": 0.7}[niveau]


func _part(id: int) -> float:
	return float(zone_t[id]) / maxf(float(tenu_t[id]), 0.001)


func _dire(m: String) -> void:
	annonce = m
	_annonce_t = 2.0


## « La corde file ! » (relais manqué, fantôme) : au niveau dur, le seau glisse un peu plus bas ; c'est
## la corde laissée hors de la zone trop longtemps qui coûte la vie (cf. `avancer`).
func _file() -> void:
	_dire("La corde file !")


func action(id: int, d: Dictionary) -> void:
	if fini or not ids.has(id) or not d.has("tenir"):
		return
	tient[id] = bool(d["tenir"])


## Un fantôme fait glisser la corde : celui qui la tenait doit la ressaisir.
func _hanter(id: int) -> String:
	if not tient.get(id, false):
		return super._hanter(id)
	tient[id] = false
	tension = maxf(tension - 0.12, 0.0)
	_file()
	return "La corde file entre les doigts de %s." % nom(id)


func avancer(delta: float) -> void:
	if fini:
		return
	var n: int = ids.size()
	var c: int = _courant()
	if c != _c_prec:
		# Passation : l'ancien n'a plus la corde ; si le nouveau ne l'avait pas saisie, elle file.
		tient[ids[_c_prec]] = false
		if not bool(tient[ids[c]]) and pause_t <= 0.0:
			tension = maxf(tension - 0.15, 0.0)
			_file()
		_c_prec = c
	var s: int = (c + 1) % n
	var tenu: bool = bool(tient[ids[c]]) or (_reste_tour() < RELACHE and bool(tient[ids[s]]))
	if pause_t > 0.0:
		# Le seau est en haut : on le vide, on redescend le suivant (la tension revient d'elle-même au milieu).
		pause_t -= delta
		tension = move_toward(tension, (float(zone[0]) + float(zone[1])) / 2.0, delta * 0.5)
		if pause_t <= 0.0:
			n_seau += 1
			seau = 0.0
			_regler_seau()
			_hors_t = 0.0
		_annonce_t -= delta
		if _annonce_t <= 0.0:
			annonce = ""
		super.avancer(delta)
		return
	tenu_t[ids[c]] += delta
	tension = clampf(tension + (monte_r if tenu else -descente_r) * delta, 0.0, 1.0)
	var dedans: bool = tension >= float(zone[0]) and tension <= float(zone[1])
	if dedans:
		_hors_t = 0.0
		seau = minf(seau + delta / _effort(), 1.0)
		zone_t[ids[c]] += delta
	else:
		var avant_hors := _hors_t
		_hors_t += delta
		if _hors_t > 1.5:
			seau = maxf(seau - 1.2 * delta / _effort(), 0.0)
			if avant_hors <= 1.5:
				# Niveau dur : le seau qui glisse (plus d'une seconde et demie hors de la zone) coûte une vie.
				perdre_vie()
		if _etait_dedans and tension < float(zone[0]):
			_dire("La corde file !")
	_etait_dedans = dedans
	if seau >= 1.0:
		if n_seau + 1 >= int(plan["seaux"]):
			hisse = true
			terminer()
			return
		pause_t = float(plan["pause"])
		_dire("Le seau est en haut ! On le vide…")
	_annonce_t -= delta
	if _annonce_t <= 0.0:
		annonce = ""
	super.avancer(delta)


func terminer() -> void:
	for id in ids:
		# Qui n'a presque pas tenu la corde (très grande équipe) n'est pas pénalisé.
		_reussis[id] = float(tenu_t[id]) < tour * 0.5 or _part(id) >= _ratio()
	super.terminer()


func equipe_reussit() -> bool:
	return hisse and super.equipe_reussit()


func vue_pour(id: int) -> Dictionary:
	var c: int = _courant()
	var s: int = (c + 1) % ids.size()
	var blocs := [MiniJeu.jauge(tension, "Tension de la corde", zone, "or"),
		MiniJeu.jauge(seau, "Le seau remonte", [], "vert")]
	if ids[c] == id:
		blocs.append(MiniJeu.texte("C'est ton tour : garde la tension dans la zone. Tiens pour monter, lâche pour descendre.", 20, "or"))
		blocs.append({"t": "tenir", "l": "Tiens la corde : regarde la boucle, poing fermé ou clic tenu"})
		if _reste_tour() < RELACHE + 1.0:
			blocs.append(MiniJeu.texte("%s va saisir la corde : ne lâche pas avant." % nom(ids[s]), 18, "gris"))
	elif ids[s] == id:
		blocs.append(MiniJeu.texte("Tu es le suivant : saisis la corde AVANT que %s la lâche." % nom(ids[c]), 20, "or"))
		blocs.append({"t": "tenir", "l": "Saisis la corde : regarde la boucle, poing fermé ou clic tenu"})
	else:
		blocs.append(MiniJeu.texte("La corde est à %s, puis à %s." % [nom(ids[c]), nom(ids[s])], 20, "gris"))
	var part := int(round(_part(id) * 100.0)) if float(tenu_t.get(id, 0.0)) > 0.5 else 100
	blocs.append(MiniJeu.texte("Ta part : %d %% dans la zone (il en faut %d %%)" % [part, int(_ratio() * 100.0)], 18, "vert" if part >= int(_ratio() * 100.0) else ""))
	if annonce != "":
		blocs.append(MiniJeu.texte(annonce, 24, "rouge"))
	blocs.insert(0, MiniJeu.texte("Seau %d / %d : de plus en plus profond, de plus en plus lourd." % [n_seau + 1, int(plan["seaux"])], 18, "or"))
	return {"consigne": "Hissez les seaux à tour de rôle. La tension doit rester dans la zone ; préviens ton successeur pour que la corde ne file pas. Plus le seau est profond, plus il est lourd.", "blocs": blocs,
		"puits": {"seau": n_seau, "seaux": int(plan["seaux"]), "prog": snappedf(seau, 0.005), "pause": pause_t > 0.0, "lourd": snappedf(descente_r / DESCENTE, 0.01)}}


## Un bot tient la corde comme une personne : il regarde la jauge, mais ce qu'il décide (serrer, lâcher) ne
## part qu'après un temps de réaction, jamais deux changements à moins de CADENCE_MIN, et il se laisse
## parfois distraire. Pour le relais, il connaît l'ordre (affiché à tous) et saisit la corde un peu avant la
## fin du tour du précédent (rarement trop tard : la corde file) ; et quand celui qui suit est une PERSONNE,
## il la prévient à voix haute à temps pour qu'elle l'entende et réagisse. Un saboteur lâche au plus une
## fois de temps en temps, jamais en rafale.
func bot(id: int, delta: float) -> void:
	_bots[id] = true
	if fini:
		return
	var n: int = ids.size()
	var c: int = _courant()
	var s: int = (c + 1) % n
	var courant: bool = ids[c] == id
	var suivant: bool = ids[s] == id
	var t_tour: int = int(floor(temps / tour))
	# Le courant prévient le suivant s'il est humain (il a besoin de l'entendre et de réagir).
	if courant and not _bots.has(ids[s]) and _prevenu != t_tour and _reste_tour() <= minf(4.0, tour * 0.6):
		_prevenu = t_tour
		paroles.append([id, "À toi, prends la corde !"])
	if not (courant or suivant):
		return
	if int(_tour_vu.get(id, -1)) != t_tour:
		# Nouveau tour pour ce bot : il choisit ses manies (instant de saisie, distraction, lâcher exprès).
		_tour_vu[id] = t_tour
		_prise[id] = RELACHE + rng.randf_range(-0.1, 0.5)
		if rng.randf() < {"simple": 0.015, "normal": 0.02, "dur": 0.02, "extreme": 0.025}[niveau]:
			_prise[id] = -0.5 - rng.randf_range(0.0, 0.6)         # il regardait ailleurs : la corde file
		_lache[id] = -1.0
		if courant and peut_saboter(id) and temps >= float(_sabo_apres.get(id, 0.0)) and rng.randf() < 0.2:
			_lache[id] = rng.randf_range(0.2, 0.7) * tour           # moment du tour où il « glisse »
			_sabo_apres[id] = temps + 30.0
		_dernier[id] = float(_dernier.get(id, -10.0))
	if float(_bot_distrait[id]) > 0.0:
		_bot_distrait[id] -= delta
		return
	if suivant and _reste_tour() > float(_prise[id]):
		return          # pas encore l'heure de saisir la corde
	# (le suivant, une fois la corde en main, la règle comme le courant)
	# Le courant : sabotage prévu ?
	if courant and float(_lache[id]) >= 0.0 and fposmod(temps, tour) >= float(_lache[id]):
		_lache[id] = -1.0
		_geste(id, false, true)
		_bot_distrait[id] = rng.randf_range(1.5, 3.0)
		return
	# Il agit sur ce qu'il voit, avec un retard de réaction : la décision est mûrie `lag` secondes.
	var milieu: float = (float(zone[0]) + float(zone[1])) / 2.0
	# Une personne anticipe : elle juge où sera la jauge quand sa main aura réagi, pas où elle est.
	var vitesse: float = monte_r if bool(tient[id]) else -descente_r
	var voulu: bool = tension + vitesse * 0.3 < milieu
	if _plan.has(id):
		if temps >= float(_plan[id]["t"]):
			var tenir: bool = bool(_plan[id]["tenir"])
			_plan.erase(id)
			_geste(id, tenir)
		return
	if voulu != bool(tient[id]):
		var quand := temps + rng.randf_range(0.12, 0.25)
		quand = maxf(quand, float(_dernier[id]) + CADENCE_CORDE)
		_plan[id] = {"t": quand, "tenir": voulu}
	elif rng.randf() < 0.0006:
		_bot_distrait[id] = rng.randf_range(0.6, 1.4)         # un instant d'inattention


func _geste(id: int, tenir: bool, force := false) -> void:
	if not force and float(_dernier.get(id, -10.0)) + CADENCE_CORDE > temps:
		return
	_dernier[id] = temps
	action(id, {"tenir": tenir})
