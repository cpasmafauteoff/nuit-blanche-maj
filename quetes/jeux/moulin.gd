extends MiniJeu
## Le Moulin : plusieurs SACS de grain à moudre, chacun à son rythme. La meule ne tourne que si tout le
## monde pousse sa manivelle EN MÊME TEMPS, au battement. Chaque coup juste fait avancer le grain ; un
## coup à contretemps fait cogner la meule et le battement suivant est perdu POUR TOUS. À chaque sac
## le rythme change (plus lent, plus vif…) : on verse le suivant dans la trémie, le repère annonce déjà
## le nouveau pas, et deux battements d'échauffement ne comptent pas (ni points, ni faute).
## Sabotage : tourner à contretemps (n'importe qui peut rater ; un loup le fait exprès).
## Réussite individuelle : assez de coups justes sur l'ensemble des sacs.
## La durée vient de DimGestes.moulin_sacs : la partie est le contenu (aucune attente ajoutée), elle
## dure `cible(niveau)` ; le temps limite est le maximum du niveau.

const FENETRE := 0.14        # écart de phase toléré autour du battement (sur 1)

var sacs: Array = []         # [{periode, total, echauffement, debut}]
var coups := {}              # id -> coups justes
var _dernier := {}           # id -> clé du dernier battement compté (un coup par battement)
var _cogne_jusqu := -1       # clé du battement perdu après un à-coup
var grain := 0.0             # 0..1, ce qui a été moulu au total
var comptes := 0             # battements qui comptent (échauffements exclus)
var annonce := ""            # « La meule cogne ! » : vu de tous, sans dire qui
var _annonce_t := 0.0
var _bot_plan := {}          # bot -> son prochain coup {sac, m (battement), h (instant voulu, en battements), sorte}
var _bot_dernier := {}       # bot -> {sac, m} du dernier coup décidé : jamais deux fois le même battement
var _bot_regret := {}        # bot -> {sac, jusqua} : il lève le pied jusqu'à ce battement après une erreur
var _biais := {}             # bot -> son décalage habituel (en battements)
var _sac_dit := -1
var _p_sabo := 0.05


func demarrer() -> void:
	_init_vies()
	sacs = DimGestes.moulin_sacs(niveau, rng)
	duree = Quetes.duree_max(niveau)
	for s: Dictionary in sacs:
		comptes += int(s["total"]) - int(s["echauffement"])
	_p_sabo = 2.5 / maxf(float(comptes), 1.0)
	for id in ids:
		coups[id] = 0
		_dernier[id] = -1


func _etat() -> Dictionary:
	return DimGestes.segment_a(sacs, temps)


## La position (en battements, avec décimales) dans le sac de l'état.
func _h() -> float:
	var s: Dictionary = sacs[int(_etat()["sac"])]
	return (temps - float(s["debut"])) / float(s["periode"])


func _phase() -> float:
	return fposmod(_h(), 1.0)


func _cle(sac: int, n: int) -> int:
	return sac * 1000 + n


## Un fantôme donne un coup à sa place, à contretemps.
func _hanter(id: int) -> String:
	action(id, {"coup": true, "phase": 0.5})
	if annonce == "":      # hors d'un battement qui compte, le coup ne change rien : la vue garde pourtant la trace
		annonce = "La manivelle tourne toute seule !"
		_annonce_t = 1.4
	return "La manivelle échappe à %s : un coup à contretemps." % nom(id)


func action(id: int, d: Dictionary) -> void:
	if fini or not ids.has(id) or not d.has("coup"):
		return
	var etat := _etat()
	var sac: int = int(etat["sac"])
	var s: Dictionary = sacs[sac]
	# Le joueur dit à quelle phase il a tourné (ce qu'il voyait) : le retard du réseau ne compte pas.
	var h := _h()
	var ph := fposmod(float(d.get("phase", fposmod(h, 1.0))), 1.0)
	var delta := ph - fposmod(h, 1.0)
	if delta > 0.5:
		delta -= 1.0
	elif delta < -0.5:
		delta += 1.0
	var r := h + delta
	var n := int(round(r))
	var ecart := absf(r - n)
	# Pause (on verse le sac) ou échauffement : on tourne pour s'y mettre, rien ne compte.
	if bool(etat["pause"]) or n < int(s["echauffement"]) or n >= int(s["total"]):
		return
	var cle := _cle(sac, n)
	if ecart <= FENETRE:
		if _dernier[id] == cle or cle == _cogne_jusqu:
			return
		_dernier[id] = cle
		coups[id] += 1
		grain = minf(grain + 1.0 / (maxf(float(comptes), 1.0) * ids.size() * 0.75), 1.0)
	elif ecart > 0.3:
		# À contretemps : la meule cogne, le prochain battement est perdu pour tous.
		_cogne_jusqu = cle + 1
		annonce = "La meule cogne !"
		_annonce_t = 1.4
		perdre_vie()      # niveau dur : un coup à contretemps coûte une vie à l'équipe


func _requis() -> int:
	return int(ceil(comptes * {"simple": 0.6, "normal": 0.7, "dur": 0.75, "extreme": 0.8}[niveau]))


func avancer(delta: float) -> void:
	if fini:
		return
	var etat := _etat()
	if int(etat["sac"]) != _sac_dit and bool(etat["pause"]):
		_sac_dit = int(etat["sac"])
		if _sac_dit > 0:
			var avant: float = float(sacs[_sac_dit - 1]["periode"])
			var apres: float = float(sacs[_sac_dit]["periode"])
			annonce = "Sac suivant : le rythme s'accélère !" if apres < avant else "Sac suivant : le rythme ralentit !"
			_annonce_t = 3.0
	if temps >= DimGestes.segments_fin(sacs) + 0.4:
		terminer()
		return
	super.avancer(delta)
	_annonce_t -= delta
	if _annonce_t <= 0:
		annonce = ""


func terminer() -> void:
	for id in ids:
		_reussis[id] = int(coups[id]) >= _requis()
	super.terminer()


func vue_pour(id: int) -> Dictionary:
	var etat := _etat()
	var sac: int = int(etat["sac"])
	var s: Dictionary = sacs[sac]
	var prog := 0.0
	if not bool(etat["pause"]):
		prog = clampf(_h() / float(s["total"]), 0.0, 1.0)
	var blocs := [
		{"t": "rythme", "periode": float(s["periode"]), "phase": _phase(), "l": "Saisis la manivelle et tourne : passe en haut quand le repère bat"},
		MiniJeu.jauge(grain, "Le grain moulu"),
		MiniJeu.texte("Sac %d / %d" % [sac + 1, sacs.size()], 20, "or"),
		MiniJeu.texte("Tes coups justes : %d / %d" % [coups.get(id, 0), _requis()], 18, "vert" if int(coups.get(id, 0)) >= _requis() else ""),
	]
	if bool(etat["pause"]):
		blocs.append(MiniJeu.texte("On verse le sac dans la trémie : reprenez le rythme du repère.", 16, "gris"))
	elif int(etat["n"]) < int(s["echauffement"]):
		blocs.append(MiniJeu.texte("Échauffement : ces battements ne comptent pas.", 16, "gris"))
	if annonce != "":
		blocs.append(MiniJeu.texte(annonce, 24, "rouge"))
	return {"consigne": "Tournez ensemble, au battement, sac après sac : le rythme change à chaque sac. Un coup à contretemps fait cogner la meule.", "blocs": blocs,
		"moulin": {"sac": sac, "sacs": sacs.size(), "periode": snappedf(float(s["periode"]), 0.001), "prog": snappedf(prog, 0.01), "pause": bool(etat["pause"]), "grain": snappedf(grain, 0.01)}}


## Un bot tourne la manivelle comme une personne : il ne frappe pas pile sur le battement mais un peu avant
## ou après (son propre décalage + du bruit, plus large juste après un changement de rythme), il lui arrive
## de manquer un battement (distraction) ou de frapper franchement à côté ; après un coup raté il lève le pied
## deux battements (regret) ; deux coups sont toujours séparés d'au moins la cadence humaine. Un saboteur
## cogne exprès, rarement.
func bot(id: int, _delta: float) -> void:
	if fini:
		return
	var etat := _etat()
	if bool(etat["pause"]):
		_bot_plan.erase(id)         # on verse le sac : il attend le repère du nouveau rythme
		return
	var sac: int = int(etat["sac"])
	var s: Dictionary = sacs[sac]
	var h := _h()
	if not _biais.has(id):
		_biais[id] = rng.randfn(0.0, 0.02)           # chacun a son décalage habituel
	if not _bot_plan.has(id) or int(_bot_plan[id]["sac"]) != sac:
		var dernier_m: int = int(_bot_dernier.get(id, {}).get("m", -1)) if int(_bot_dernier.get(id, {}).get("sac", -1)) == sac else -1
		var sigma := 0.05 * (1.5 if h < float(s["echauffement"]) + 1.0 else 1.0)
		var off: float = float(_biais[id]) + rng.randfn(0.0, sigma)
		var sorte := "juste"
		var tirage := rng.randf()
		if peut_saboter(id) and rng.randf() < _p_sabo:
			sorte = "sabo"
			off = rng.randf_range(0.34, 0.5) * (1.0 if rng.randf() < 0.5 else -1.0)
		elif tirage < 0.001:
			sorte = "rate"                     # il frappe franchement à côté et la meule cogne
			off = rng.randf_range(0.34, 0.5) * (1.0 if rng.randf() < 0.5 else -1.0)
		elif tirage < 0.001 + 0.008:
			sorte = "saute"                    # il regarde ailleurs : pas de coup à ce battement
		var m := maxi(int(ceil(h - off)), dernier_m + 1)
		if m < 0:
			m = 0
		_bot_plan[id] = {"sac": sac, "m": m, "h": float(m) + off, "sorte": sorte}
	var p: Dictionary = _bot_plan[id]
	if h < float(p["h"]):
		return
	_bot_plan.erase(id)
	_bot_dernier[id] = {"sac": sac, "m": int(p["m"])}
	if int(p["m"]) >= int(s["total"]):
		return
	if int(p["m"]) <= int(_bot_regret.get(id, {}).get("jusqua", -1)) and int(_bot_regret.get(id, {}).get("sac", -1)) == sac:
		return                                   # il lève le pied après son erreur
	if p["sorte"] == "saute":
		return
	var phase: float = fposmod(float(p["h"]), 1.0)
	if p["sorte"] == "rate":          # (un saboteur ne regrette rien : il reprend aussitôt pour ne pas se trahir)
		_bot_regret[id] = {"sac": sac, "jusqua": int(p["m"]) + 2}
	action(id, {"coup": true, "phase": phase})
