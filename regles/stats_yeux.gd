class_name StatsYeux
extends RefCounted
## Les titres de l'écran de fin, tirés de ce que les webcams ont vu des yeux (cf. SuiviYeux).
## L'hôte reçoit les chiffres de chacun et publie 3 à 5 titres marquants, avec les noms.
## Règle pure. Qui n'avait pas de webcam n'a pas de chiffres : rien n'est inventé pour lui, et
## s'il y a moins de trois titres vraiment marquants, on en montre moins.

const MAX_TITRES := 5
const MAX_PAR_JOUEUR := 2
const SEUIL_NERVEUX := 6          # clignements pendant son procès
const SEUIL_DETOURNE := 3.0       # secondes de regard détourné pendant le vote
const SEUIL_PIERRE_S := 15.0      # secondes de vote + procès sans baisser les yeux
const SEUIL_RYTHME_HAUT := 30.0   # clignements par minute
const SEUIL_RYTHME_BAS := 6.0
const SEUIL_DORMEUR := 30.0       # secondes d'yeux fermés la nuit
const SEUIL_FRAYEURS := 3


## `stats` : id -> dictionnaire de SuiviYeux.exporter() ; `noms` : id -> nom.
## Rend une liste de {id, cle, titre, texte}, du plus marquant au moins marquant.
static func titres(stats: Dictionary, noms: Dictionary) -> Array[Dictionary]:
	var valides := {}
	for id in stats:
		var s: Variant = stats[id]
		if s is Dictionary and float(s.get("suivi", 0.0)) >= SuiviYeux.MIN_SUIVI:
			valides[id] = s
	var meilleurs := {}   # cle -> candidat
	for id in valides:
		var s: Dictionary = valides[id]
		var nom := str(noms.get(id, "?"))
		var suivi := float(s["suivi"])
		var minutes := suivi / 60.0
		var clin := int(s.get("clin", 0))
		var cp := int(s.get("clin_proces", 0))
		if float(s.get("proces", 0.0)) >= 5.0 and cp >= SEUIL_NERVEUX:
			_proposer(meilleurs, id, "nerveux", 1.3 * minf(float(cp) / SEUIL_NERVEUX, 3.0), "Le plus nerveux",
				"%s a cligné %d fois pendant son procès." % [nom, cp])
		var detourne := float(s.get("detourne", 0.0))
		if detourne >= SEUIL_DETOURNE:
			_proposer(meilleurs, id, "detourne", 1.1 * minf(detourne / SEUIL_DETOURNE, 3.0), "Le regard fuyant",
				"%s a détourné le regard en votant." % nom)
		var attention := float(s.get("vote", 0.0)) + float(s.get("proces", 0.0))
		if detourne <= 0.0 and attention >= SEUIL_PIERRE_S:
			_proposer(meilleurs, id, "pierre", 1.0 + minf(attention / 120.0, 1.0), "Le regard de pierre",
				"%s n'a jamais baissé les yeux." % nom)
		if minutes >= 2.0:
			var rythme := clin / minutes
			if rythme >= SEUIL_RYTHME_HAUT:
				_proposer(meilleurs, id, "clin_haut", 0.8 * minf(rythme / SEUIL_RYTHME_HAUT, 3.0), "Les paupières en feu",
					"%s a cligné %d fois, %d par minute." % [nom, clin, roundi(rythme)])
			elif minutes >= 3.0 and rythme <= SEUIL_RYTHME_BAS:
				_proposer(meilleurs, id, "clin_bas", 0.8 * minf(SEUIL_RYTHME_BAS / maxf(rythme, 1.0), 3.0), "Le plus impassible",
					"%s n'a cligné que %d fois en %d minutes." % [nom, clin, roundi(minutes)])
		var nuit := float(s.get("ferme_nuit", 0.0))
		if nuit >= SEUIL_DORMEUR:
			_proposer(meilleurs, id, "dormeur", 0.7 * minf(nuit / SEUIL_DORMEUR, 3.0), "Le dormeur",
				"%s a gardé les yeux fermés %d secondes pendant les nuits." % [nom, roundi(nuit)])
		var grands := int(s.get("ecarquille", 0))
		if grands >= 1:
			_proposer(meilleurs, id, "peureux", 1.0 * minf(float(grands) / 2.0 + 0.5, 3.0), "Le plus craintif",
				("%s a écarquillé les yeux devant une frayeur." % nom) if grands == 1 else ("%s a écarquillé les yeux devant %d frayeurs." % [nom, grands]))
		var frayeurs := int(s.get("frayeurs", 0))
		if frayeurs >= SEUIL_FRAYEURS and grands == 0:
			_proposer(meilleurs, id, "sang_froid", 0.9 * minf(float(frayeurs) / SEUIL_FRAYEURS, 3.0), "Le sang-froid",
				"%s n'a pas sourcillé devant %d frayeurs." % [nom, frayeurs])
	var liste: Array = meilleurs.values()
	# Du plus marquant au moins marquant ; à égalité, le plus petit identifiant (résultat stable).
	liste.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(a["score"], b["score"]):
			return a["score"] > b["score"]
		return int(a["id"]) < int(b["id"]))
	var choisis: Array[Dictionary] = []
	var par_joueur := {}
	for c: Dictionary in liste:
		if choisis.size() >= MAX_TITRES:
			break
		if int(par_joueur.get(c["id"], 0)) >= MAX_PAR_JOUEUR:
			continue
		par_joueur[c["id"]] = int(par_joueur.get(c["id"], 0)) + 1
		choisis.append({"id": c["id"], "cle": c["cle"], "titre": c["titre"], "texte": c["texte"]})
	return choisis


static func _proposer(meilleurs: Dictionary, id: Variant, cle: String, score: float, titre: String, texte: String) -> void:
	var actuel: Variant = meilleurs.get(cle)
	if actuel == null or score > float(actuel["score"]) or (is_equal_approx(score, float(actuel["score"])) and int(id) < int(actuel["id"])):
		meilleurs[cle] = {"id": id, "cle": cle, "score": score, "titre": titre, "texte": texte}
