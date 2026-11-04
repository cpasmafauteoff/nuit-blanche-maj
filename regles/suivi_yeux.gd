class_name SuiviYeux
extends RefCounted
## Ce que MA webcam a vu de mes yeux pendant la partie, compté localement : clignements (en tout,
## et pendant MON procès), regard détourné pendant le vote, yeux fermés la nuit, yeux écarquillés
## devant une frayeur. Rien ne sort de cette machine avant la fin de la partie ; alors seuls ces
## quelques nombres partent vers l'hôte, qui en tire les titres de l'écran de fin (StatsYeux).
## Sans webcam, on n'alimente jamais ce suivi : rien n'est inventé.

const FERME_SOUS := 0.4          # ouverture en dessous de laquelle l'œil est fermé
const OUVERT_AU_DESSUS := 0.55         # (hystérésis, cf. _ferme)
const CLIN_MAX := 0.8            # plus long, ce n'est pas un clignement : c'est un œil qu'on ferme
const GRAND_AU_DESSUS := 0.45    # eyeWide : l'œil s'écarquille
const MIN_SUIVI := 30.0          # moins de secondes de visage vu : pas de statistiques

var suivi_s := 0.0               # secondes pendant lesquelles la webcam voyait mon visage
var clignements := 0
var clignements_proces := 0
var proces_s := 0.0
var vote_s := 0.0
var detourne_vote_s := 0.0
var ferme_nuit_s := 0.0
var frayeurs := 0
var frayeurs_ecarquille := 0

var _ferme := false
var _ferme_s := 0.0
var _en_frayeur := false
var _large_frayeur := false


## Une image. `ctx` : {nuit_dort, proces, vote, frayeur, detourne} (booléens, tous facultatifs).
func echantillon(dt: float, ouverture: float, large: float, ctx: Dictionary) -> void:
	suivi_s += dt
	var nuit: bool = ctx.get("nuit_dort", false)
	var proces: bool = ctx.get("proces", false)
	if proces:
		proces_s += dt
	if ctx.get("vote", false):
		vote_s += dt
		if ctx.get("detourne", false):
			detourne_vote_s += dt
	# Clignement : fermé, puis rouvert vite. La nuit, on ferme les yeux exprès : ce n'est pas compté.
	if not _ferme and ouverture < FERME_SOUS:
		_ferme = true
		_ferme_s = 0.0
	elif _ferme:
		_ferme_s += dt
		if nuit:
			ferme_nuit_s += dt
		if ouverture > OUVERT_AU_DESSUS:
			_ferme = false
			if _ferme_s <= CLIN_MAX and not nuit:
				clignements += 1
				if proces:
					clignements_proces += 1
	# Frayeur : un épisode compte une fois, écarquillé si l'œil s'est ouvert tout grand.
	var frayeur: bool = ctx.get("frayeur", false)
	if frayeur and not _en_frayeur:
		_en_frayeur = true
		_large_frayeur = false
		frayeurs += 1
	if frayeur and large > GRAND_AU_DESSUS and not _large_frayeur:
		_large_frayeur = true
		frayeurs_ecarquille += 1
	if not frayeur:
		_en_frayeur = false


func valable() -> bool:
	return suivi_s >= MIN_SUIVI


## Les nombres envoyés à l'hôte en fin de partie.
func exporter() -> Dictionary:
	return {"suivi": snappedf(suivi_s, 0.1), "clin": clignements, "clin_proces": clignements_proces,
		"proces": snappedf(proces_s, 0.1), "vote": snappedf(vote_s, 0.1), "detourne": snappedf(detourne_vote_s, 0.1),
		"ferme_nuit": snappedf(ferme_nuit_s, 0.1), "frayeurs": frayeurs, "ecarquille": frayeurs_ecarquille}
