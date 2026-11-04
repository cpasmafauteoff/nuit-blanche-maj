extends MiniJeu
## Les Cloches : une mélodie en PLUSIEURS MOUVEMENTS sur un battement partagé (la ronde, les notes qui
## s'éparpillent, le grand carillon aux notes doubles ; le tempo accélère). Chaque joueur possède UNE
## cloche et ne voit que sa propre ligne de partition (« ● · · ● ») : il doit tirer sa corde exactement
## aux temps où elle joue. Une fausse note (hors temps, ou sur le temps d'un autre) s'entend de TOUS,
## sans nom ; et elle couvre la note de celui dont c'était le temps. Entre deux mouvements, un silence ;
## au début de chacun, trois battements sans note pour caler le tempo.
## Sabotage : sonner trop tôt / sur le temps des autres (n'importe qui se trompe ; un loup le fait
## exprès).
## Réussite individuelle : assez de notes justes, peu de fausses notes (seuils proportionnels au nombre
## de notes du joueur : DimGestes.cloches_seuils).
## La durée vient de DimGestes.cloches_plan : la mélodie dure `cible(niveau)` ; le temps limite est le
## maximum du niveau.

const FENETRE := 0.16        # écart de phase toléré autour du battement (sur 1)

var mvs: Array = []          # [{motif, periode, total, echauffement, debut, partition}]
var fausses := {}            # id -> fausses notes
var _jouee := {}             # clé (mouvement*1000+battement) -> true quand le bon joueur a sonné
var _couverte := {}          # clé -> true quand une fausse note est tombée dessus
var notes := {}              # id -> nombre de notes dans toute la partie
var annonce := ""            # « Fausse note ! » : vu de tous, sans dire qui
var _annonce_t := 0.0
var _bot_n := {}
var _mv_dit := -1
var _p_sabo := 0.01
var _fausses_vues := {}      # id -> ses fausses notes déjà digérées par le bot
var _hesite := {}            # id -> vrai : il vient de se tromper, il peut sauter sa prochaine note


func demarrer() -> void:
	_init_vies()
	mvs = DimGestes.cloches_plan(niveau, ids.size(), rng)
	duree = Quetes.duree_max(niveau)
	var total_battements := 0
	for m: Dictionary in mvs:
		total_battements += int(m["total"])
	_p_sabo = 3.0 / maxf(float(total_battements), 1.0)
	for k in ids.size():
		fausses[ids[k]] = 0
		notes[ids[k]] = DimGestes.cloches_notes(mvs, k)


func _etat() -> Dictionary:
	return DimGestes.segment_a(mvs, temps)


func _h() -> float:
	var m: Dictionary = mvs[int(_etat()["sac"])]
	return (temps - float(m["debut"])) / float(m["periode"])


func _phase() -> float:
	return fposmod(_h(), 1.0)


func _cle(mv: int, b: int) -> int:
	return mv * 1000 + b


func _seuils(id: int) -> Array:
	return DimGestes.cloches_seuils(niveau, int(notes[id]))


## Notes justes de ce joueur : sonnées à leur temps, et pas couvertes par une fausse note.
func bonnes(id: int) -> int:
	var r: int = ids.find(id)
	var n := 0
	for v in mvs.size():
		var part: Array = mvs[v]["partition"]
		for b in part.size():
			var cle := _cle(v, b)
			if part[b] == r and _jouee.get(cle, false) and not _couverte.get(cle, false):
				n += 1
	return n


func _fausse(id: int) -> void:
	fausses[id] = int(fausses[id]) + 1
	annonce = "Fausse note !"
	_annonce_t = 1.5
	perdre_vie()          # niveau dur : une fausse note coûte une vie à l'équipe


## Un fantôme donne un coup à sa place, à contretemps.
func _hanter(id: int) -> String:
	action(id, {"coup": true, "phase": 0.5})
	if annonce == "":      # pendant un silence ou le calage le coup ne compte pas : la vue garde pourtant la trace
		annonce = "Une corde sonne toute seule !"
		_annonce_t = 1.5
	return "La corde de %s sonne toute seule : fausse note." % nom(id)


func action(id: int, d: Dictionary) -> void:
	if fini or not ids.has(id) or not d.has("coup"):
		return
	var etat := _etat()
	var v: int = int(etat["sac"])
	var m: Dictionary = mvs[v]
	# Le joueur dit à quelle phase il a sonné (ce qu'il voyait) : on la replace sur la ligne de
	# temps de l'hôte, ce qui absorbe le retard du réseau (moins d'un demi-battement).
	var h := _h()
	var ph := fposmod(float(d.get("phase", fposmod(h, 1.0))), 1.0)
	var delta := ph - fposmod(h, 1.0)
	if delta > 0.5:
		delta -= 1.0
	elif delta < -0.5:
		delta += 1.0
	var r: float = h + delta
	var nb: int = int(round(r))
	# Le silence entre deux mouvements et les battements de calage : on peut tirer pour s'y mettre.
	if bool(etat["pause"]) or nb < int(m["echauffement"]) or nb >= int(m["total"]):
		return
	if absf(r - nb) > FENETRE:
		_fausse(id)      # hors temps
		return
	var cle := _cle(v, nb)
	if (m["partition"] as Array)[nb] == ids.find(id):
		_jouee[cle] = true
		return
	# Sur le temps d'un autre (ou sur un silence) : fausse note qui couvre la vraie.
	_fausse(id)
	_couverte[cle] = true


func avancer(delta: float) -> void:
	if fini:
		return
	var etat := _etat()
	if int(etat["sac"]) != _mv_dit and bool(etat["pause"]):
		_mv_dit = int(etat["sac"])
		if _mv_dit > 0:
			annonce = "Mouvement suivant : %s" % DimGestes.C_NOMS[str(mvs[_mv_dit]["motif"])]
			_annonce_t = 3.0
	if temps >= DimGestes.segments_fin(mvs) + 0.4:
		terminer()
		return
	super.avancer(delta)
	_annonce_t -= delta
	if _annonce_t <= 0.0:
		annonce = ""


func terminer() -> void:
	for id in ids:
		var seuils := _seuils(id)
		_reussis[id] = bonnes(id) >= int(seuils[0]) and int(fausses[id]) <= int(seuils[1])
	super.terminer()


func vue_pour(id: int) -> Dictionary:
	var etat := _etat()
	var v: int = int(etat["sac"])
	var m: Dictionary = mvs[v]
	var part: Array = m["partition"]
	var cur: int = int(etat["n"]) if not bool(etat["pause"]) else -1
	var r: int = ids.find(id)
	var ligne := PackedStringArray()
	for b in range(cur - 1, cur + 7):
		var s := " "
		if b >= 0 and b < part.size():
			s = "●" if part[b] == r else "·"
		ligne.append("[%s]" % s if b == cur else s)
	var seuils := _seuils(id)
	var motif: String = m["motif"]
	var blocs := [
		MiniJeu.texte("Mouvement %d / %d : %s" % [v + 1, mvs.size(), DimGestes.C_NOMS[motif]], 18, ""),
		MiniJeu.texte("Ta cloche :", 16, "gris"),
		MiniJeu.texte("  ".join(ligne), 30, "or"),
		{"t": "rythme", "periode": float(m["periode"]), "phase": _phase(), "l": "Saisis ta corde et tire-la vers le bas quand le battement passe sur un ●"},
		MiniJeu.texte("Tes notes justes : %d / %d" % [bonnes(id), int(seuils[0])], 18, "vert" if bonnes(id) >= int(seuils[0]) else ""),
		MiniJeu.texte("Fausses notes : %d (au plus %d)" % [fausses.get(id, 0), int(seuils[1])], 16, "gris"),
	]
	if bool(etat["pause"]):
		blocs.append(MiniJeu.texte("Silence : le prochain mouvement commence, cale-toi sur le battement.", 16, "gris"))
	elif cur < int(m["echauffement"]):
		blocs.append(MiniJeu.texte("Calage : ces battements ne comptent pas.", 16, "gris"))
	if annonce != "":
		blocs.append(MiniJeu.texte(annonce, 24, "rouge"))
	# Qui sonne en ce moment (pour que chaque cloche se balance à son temps, sans révéler à l'avance).
	var proprio := -1
	if not bool(etat["pause"]) and cur >= 0 and cur < part.size():
		proprio = int(part[cur])
	return {"consigne": "Sonne ta cloche seulement quand ton ● passe sur le battement. Une fausse note s'entend de tous. La mélodie a plusieurs mouvements, de plus en plus vifs.", "blocs": blocs,
		"cloches": {"mv": v, "n": cur, "proprio": proprio, "rang": r, "periode": snappedf(float(m["periode"]), 0.001)}}


## La chance qu'un bot manque SA note (il ne tire pas la corde à temps) : plus le tempo est vif, plus c'est difficile.
static func taux_manque(niveau: String, periode: float) -> float:
	var base: float = {"simple": 0.03, "normal": 0.05, "dur": 0.05, "extreme": 0.06}.get(niveau, 0.05)
	return base * clampf(0.7 / maxf(periode, 0.1), 0.8, 1.6)


## L'écart (sur 1 battement) d'un coup de corde humain : en avance ou en retard, plus large quand le tempo est vif.
static func ecart_de_phase(periode: float, rng: RandomNumberGenerator) -> float:
	var sigma := 0.05 * clampf(0.75 / maxf(periode, 0.1), 0.8, 1.7)
	return rng.randfn(0.01, sigma)


func bot(id: int, _delta: float) -> void:
	if fini:
		return
	var etat := _etat()
	if bool(etat["pause"]):
		return
	var v: int = int(etat["sac"])
	var n: int = int(etat["n"])
	var m: Dictionary = mvs[v]
	if n >= int(m["total"]):
		return
	var cle := _cle(v, n)
	if int(_bot_n.get(id, -1)) == cle:
		return
	_bot_n[id] = cle
	# Une fausse note qui vient de sonner de SA corde : il perd le fil, et saute sa prochaine note une fois sur deux.
	if int(fausses[id]) != int(_fausses_vues.get(id, 0)):
		_fausses_vues[id] = int(fausses[id])
		_hesite[id] = rng.randf() < 0.5
	var part: Array = m["partition"]
	var bruit: float = ecart_de_phase(float(m["periode"]), rng)
	if part[n] == ids.find(id):
		# Sa note (il ne lit que sa propre ligne) : il la sonne presque toujours, mais pas à tous les coups.
		if bool(_hesite.get(id, false)):
			_hesite[id] = false
			return
		if rng.randf() > taux_manque(niveau, float(m["periode"])):
			action(id, {"coup": true, "phase": bruit})
	elif peut_saboter(id) and rng.randf() < _p_sabo:
		# Le saboteur tire sa corde à un moment qui n'est pas le sien (il ne connaît pas la ligne des autres).
		action(id, {"coup": true, "phase": bruit})
	elif rng.randf() < _p_sabo * 0.15:
		action(id, {"coup": true, "phase": bruit})
