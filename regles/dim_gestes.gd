class_name DimGestes
extends RefCounted
## Le dimensionnement des cinq mini-jeux à vrais gestes (Radeau, Puits, Moulin, Cloches, Incendie) :
## tout ce qui fait qu'une équipe qui joue BIEN met au moins `Quetes.duree_min(niveau)` (Edwin, 01/11 :
## « jeux plus longs d'office », une seule partie, pas d'attente ajoutée). Aucune scène ici : des
## fonctions pures, testées sans moteur (tests/test_dim_gestes.gd). Les jeux n'ont qu'à les appeler.
##
## Principe commun : `cible(niveau)` est la durée d'une partie parfaite ; elle tombe entre le minimum
## et le maximum du niveau (le maximum étant le temps limite du jeu). Chaque jeu dimensionne son
## contenu (tronçons de rivière, sacs de grain, mouvements de mélodie, seaux à hisser, foyers à
## éteindre) pour que le contenu LUI-MÊME dure cette cible, sans qu'on puisse l'expédier plus vite.

## Durée d'une partie parfaite (s). Facile 2-8 min, moyen 2-5, dur 1-4, extrême 45 s-1 min 30.
const CIBLE := {"simple": 170.0, "normal": 160.0, "dur": 90.0, "extreme": 60.0}


static func cible(niveau: String) -> float:
	return float(CIBLE.get(niveau, CIBLE["simple"]))


# ================================================================ le Radeau

## Vitesse maximale (m/s) d'un tronçon : on ne va jamais plus vite, même en ramant à tout rompre.
const R_VMAX := {"calme": 3.0, "gorge": 3.4, "rapides": 4.2}
## Part de cette vitesse que le courant donne tout seul, sans une rame.
const R_COURANT := {"calme": 0.30, "gorge": 0.40, "rapides": 0.55}
## La rivière, par niveau : [type, part du temps parfait, difficulté 0..3]. Les rapides sont de plus
## en plus durs ; les gorges resserrent le lit.
const R_PARCOURS := {
	"simple": [["calme", 0.14, 0], ["gorge", 0.20, 1], ["calme", 0.08, 0], ["rapides", 0.24, 1], ["gorge", 0.12, 1], ["rapides", 0.22, 2]],
	"normal": [["calme", 0.10, 0], ["gorge", 0.16, 1], ["rapides", 0.20, 1], ["calme", 0.06, 0], ["gorge", 0.14, 2], ["rapides", 0.34, 2]],
	"dur": [["calme", 0.08, 0], ["rapides", 0.20, 1], ["gorge", 0.18, 2], ["rapides", 0.24, 2], ["gorge", 0.10, 2], ["rapides", 0.20, 3]],
	"extreme": [["calme", 0.06, 0], ["rapides", 0.22, 2], ["gorge", 0.20, 2], ["rapides", 0.52, 3]],
}
## Écart entre deux rangées de rochers (secondes parfaites), par type de tronçon.
const R_ECART := {"calme": 11.0, "gorge": 8.5, "rapides": 6.5}
const R_ECART_NIVEAU := {"simple": 1.15, "normal": 1.0, "dur": 1.0, "extreme": 1.0}
const R_ECART_MIN := 4.4
## Rien dans les 10 premières secondes (on apprend à ramer) ni dans les 6 dernières (on accoste).
const R_DEBUT_LIBRE := 10.0
const R_FIN_LIBRE := 6.0
## Les trois couloirs de la rivière : -1 gauche, 0 milieu, 1 droite.
const R_COULOIRS := [-1, 0, 1]


static func radeau_coque(niveau: String) -> int:
	return {"simple": 6, "normal": 5, "dur": 3, "extreme": 2}.get(niveau, 5)


## Les coups de rame qu'un joueur doit avoir donnés pour que sa part compte (anti-resquilleur) : une
## fraction de ce qu'un rameur régulier (0,55 coup/s) donne sur la durée parfaite.
static func radeau_coups_requis(niveau: String) -> int:
	var frac: float = {"simple": 0.30, "normal": 0.38, "dur": 0.46, "extreme": 0.55}.get(niveau, 0.3)
	return int(ceil(cible(niveau) * 0.55 * frac))


## Les remous (accélération latérale max, par difficulté de tronçon), plus durs aux hauts niveaux.
static func radeau_remous(difficulte: int, niveau: String) -> float:
	var base: float = [0.0, 0.35, 0.75, 1.15][clampi(difficulte, 0, 3)]
	return base * {"simple": 0.8, "normal": 1.0, "dur": 1.15, "extreme": 1.3}.get(niveau, 1.0)


## Le plan complet d'une rivière : {"troncons": [{type, d, debut, long, vmax, vcur}], "roches": [{s, lane}],
## "longueur": m, "t_ideal": s}. `t_ideal` (le temps d'une descente parfaite, au plus vite partout) vaut
## `cible(niveau)` : le radeau ne peut pas aller plus vite que `vmax`, donc une équipe ne finit jamais
## plus tôt.
static func radeau_plan(niveau: String, rng: RandomNumberGenerator) -> Dictionary:
	var modele: Array = R_PARCOURS.get(niveau, R_PARCOURS["simple"])
	var total := 0.0
	for m: Array in modele:
		total += float(m[1])
	var troncons: Array = []
	var s := 0.0
	for m: Array in modele:
		var t: String = m[0]
		var vmax: float = R_VMAX[t]
		var long: float = float(m[1]) / total * cible(niveau) * vmax
		troncons.append({"type": t, "d": int(m[2]), "debut": s, "long": long, "vmax": vmax, "vcur": vmax * float(R_COURANT[t])})
		s += long
	var longueur := s
	# Les rochers : des rangées, séparées d'au moins R_ECART_MIN secondes parfaites. On suit le couloir
	# « sûr » de l'équipe pour ne jamais exiger de traverser deux couloirs en quelques secondes.
	var roches: Array = []
	var sur := 0                                   # le couloir où l'équipe est supposée être
	var t_parf := 0.0                              # temps parfait écoulé au début du tronçon
	for tr: Dictionary in troncons:
		var vmax: float = tr["vmax"]
		var ecart_s: float = float(R_ECART[tr["type"]]) * float(R_ECART_NIVEAU.get(niveau, 1.0)) * (1.0 - 0.06 * int(tr["d"]))
		var tt := t_parf + maxf(R_DEBUT_LIBRE - t_parf, 0.0) + (ecart_s * 0.4 if t_parf < R_DEBUT_LIBRE else ecart_s * 0.6)
		var fin_t := t_parf + float(tr["long"]) / vmax
		while tt < fin_t - 1.0 and tt < cible(niveau) - R_FIN_LIBRE:
			var d: int = tr["d"]
			var deux := 0.0
			if tr["type"] == "rapides":
				deux = clampf(0.12 + 0.2 * d, 0.0, 0.65)
			elif tr["type"] == "gorge" and d >= 2:
				deux = 0.2
			var distance_s: float = s_de(troncons, tt)
			if rng.randf() < deux:
				# Deux rochers : un seul couloir libre, à un couloir au plus du couloir sûr.
				var libres: Array = R_COULOIRS.filter(func(c): return absi(int(c) - sur) <= 1)
				var libre: int = libres[rng.randi_range(0, libres.size() - 1)]
				for c: int in R_COULOIRS:
					if c != libre:
						roches.append({"s": distance_s, "lane": c})
				sur = libre
			else:
				var c: int = _couloir_pondere(rng)
				roches.append({"s": distance_s, "lane": c})
				# Le couloir sûr devient le libre le plus proche de l'ancien.
				if c == sur:
					var cand: Array = R_COULOIRS.filter(func(x): return x != c)
					var meilleur: int = cand[0]
					for x: int in cand:
						if absi(x - sur) < absi(meilleur - sur) or (absi(x - sur) == absi(meilleur - sur) and rng.randf() < 0.5):
							meilleur = x
					sur = meilleur
			tt += maxf(ecart_s * rng.randf_range(0.8, 1.25), R_ECART_MIN)
		t_parf = fin_t
	return {"troncons": troncons, "roches": roches, "longueur": longueur, "t_ideal": cible(niveau)}


static func _couloir_pondere(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	return 0 if r < 0.4 else (-1 if r < 0.7 else 1)


## La distance (m) où l'on est après `t` secondes d'une descente parfaite.
static func s_de(troncons: Array, t: float) -> float:
	var reste := t
	var s := 0.0
	for tr: Dictionary in troncons:
		var dur: float = float(tr["long"]) / float(tr["vmax"])
		if reste <= dur:
			return s + reste * float(tr["vmax"])
		reste -= dur
		s += float(tr["long"])
	return s


## Le tronçon où l'on est à la distance s (le dernier au-delà de la fin).
static func troncon_a(troncons: Array, s: float) -> int:
	for k in troncons.size():
		var tr: Dictionary = troncons[k]
		if s < float(tr["debut"]) + float(tr["long"]):
			return k
	return troncons.size() - 1


# ================================================================ le Moulin

## Battement de base (s) par niveau ; chaque sac a son propre rythme (facteurs multiplicateurs : le
## rythme change d'un sac à l'autre).
const M_PERIODE := {"simple": 1.2, "normal": 1.0, "dur": 0.93, "extreme": 0.85}
const M_FACTEURS := {
	"simple": [1.0, 0.85, 1.2, 0.8],
	"normal": [1.0, 0.82, 1.18, 0.76],
	"dur": [1.0, 0.85, 1.15, 0.8],
	"extreme": [1.0, 0.82, 1.15],
}
## Entre deux sacs : le temps de verser le suivant dans la trémie (la manivelle reprend ensuite sur 2 battements d'échauffement, non comptés).
const M_PAUSE := {"simple": 4.0, "normal": 3.5, "dur": 3.0, "extreme": 2.0}
const M_ECHAUFFEMENT := 2


## Les sacs d'une partie : [{periode, total (battements, échauffement compris), echauffement, debut}] ; `debut`
## est l'instant (s de jeu) du premier battement. La partie entière dure `cible(niveau)` à un battement près.
static func moulin_sacs(niveau: String, rng: RandomNumberGenerator) -> Array:
	var f: Array = M_FACTEURS.get(niveau, M_FACTEURS["simple"])
	var k := f.size()
	var pause: float = M_PAUSE.get(niveau, 4.0)
	var part := (cible(niveau) - k * pause) / k
	var sacs: Array = []
	var t := pause
	for i in k:
		var periode: float = float(M_PERIODE[niveau]) * float(f[i]) * rng.randf_range(0.96, 1.04)
		var total := maxi(int(round(part / periode)), M_ECHAUFFEMENT + 6)
		sacs.append({"periode": periode, "total": total, "echauffement": M_ECHAUFFEMENT, "debut": t})
		t += total * periode + pause
	return sacs


## La fin du dernier sac (s).
static func segments_fin(sacs: Array) -> float:
	var d: Dictionary = sacs[sacs.size() - 1]
	return float(d["debut"]) + int(d["total"]) * float(d["periode"])


## Où en est-on à l'instant t, dans une suite de segments (sacs du moulin, mouvements des cloches : chacun
## {periode, total, echauffement, debut}) ? {"sac": i (le dernier commencé ou le prochain), "n": numéro de battement
## dans le sac (< 0 : avant le sac), "pause": vrai tant qu'on verse le sac suivant}.
static func segment_a(sacs: Array, t: float) -> Dictionary:
	var i := 0
	for k in sacs.size():
		if t >= float(sacs[k]["debut"]) - 1e-6 or k == 0:
			i = k
	var s: Dictionary = sacs[i]
	var n := int(floor((t - float(s["debut"])) / float(s["periode"])))
	var fini: bool = n >= int(s["total"])
	# Entre la fin d'un sac et le début du suivant : pause, le prochain sac est annoncé.
	if fini and i + 1 < sacs.size():
		return {"sac": i + 1, "n": -1, "pause": true}
	if n < 0:
		return {"sac": i, "n": -1, "pause": true}
	return {"sac": i, "n": mini(n, int(s["total"]) - 1), "pause": false, "fini": fini}


# ================================================================ le Puits

const P_SEAUX := {"simple": 3, "normal": 4, "dur": 3, "extreme": 3}
const P_PAUSE := {"simple": 4.0, "normal": 3.5, "dur": 3.0, "extreme": 2.0}
## Un seau parfait (toujours dans la zone) prend `P_PARFAIT` de la cible ; le reste, c'est l'imperfection.
const P_PARFAIT := 0.85


## Les seaux à hisser : {"seaux": K, "pause": s, "effort": [s dans la zone pour hisser chaque seau],
## "montee": [...], "descente": [...], "zone_reduite": [...]}. Plus le seau est profond, plus il est LOURD :
## il monte plus lentement et retombe plus vite quand on lâche (donc plus dur à garder dans la zone).
## Hisser tous les seaux en restant toujours dans la zone dure `cible * P_PARFAIT` : c'est le minimum.
static func puits_plan(niveau: String) -> Dictionary:
	var k: int = P_SEAUX.get(niveau, 3)
	var pause: float = P_PAUSE.get(niveau, 4.0)
	var utile := cible(niveau) * P_PARFAIT - k * pause
	var poids: Array = []
	var somme := 0.0
	for i in k:
		var w := 1.0 + 0.3 * i
		poids.append(w)
		somme += w
	var plan := {"seaux": k, "pause": pause, "effort": [], "montee": [], "descente": [], "zone_reduite": []}
	for i in k:
		(plan["effort"] as Array).append(utile * float(poids[i]) / somme)
		(plan["montee"] as Array).append(0.30 / (1.0 + 0.15 * i))
		(plan["descente"] as Array).append(0.22 * (1.0 + 0.2 * i))
		(plan["zone_reduite"] as Array).append(0.012 * i)
	return plan


## La durée d'un tour de corde : assez court pour que chacun ait au moins un vrai tour dans la partie.
static func puits_tour(niveau: String, n: int, aleas: float) -> float:
	var base: float = 9.0 * {"simple": 1.0, "normal": 0.9, "dur": 0.8, "extreme": 0.7}.get(niveau, 1.0) * aleas
	return clampf(minf(base, cible(niveau) * 0.9 / maxf(float(n), 1.0)), 3.2, 12.0)


# ================================================================ les Cloches

const C_PERIODE := {"simple": 0.85, "normal": 0.75, "dur": 0.68, "extreme": 0.62}
## Les mouvements de la mélodie : [motif, facteur de tempo, densité de notes]. « ronde » : chacun son tour
## dans l'ordre des places ; « libre » : les notes s'éparpillent ; « double » : certaines notes viennent par
## deux coups de suite. Le tempo accélère de mouvement en mouvement.
const C_MOUVEMENTS := {
	"simple": [["ronde", 1.0, 0.5], ["libre", 0.9, 0.55], ["double", 0.8, 0.6]],
	"normal": [["ronde", 1.0, 0.55], ["libre", 0.88, 0.6], ["double", 0.76, 0.65]],
	"dur": [["libre", 1.0, 0.6], ["double", 0.88, 0.65], ["double", 0.78, 0.7]],
	"extreme": [["libre", 1.0, 0.65], ["double", 0.86, 0.7]],
}
const C_PAUSE := {"simple": 3.5, "normal": 3.0, "dur": 2.5, "extreme": 2.0}
## Battements silencieux au début de chaque mouvement (le temps de caler le tempo) : rien n'y compte.
const C_INTRO := 3
const C_NOMS := {"ronde": "La ronde", "libre": "Les notes s'éparpillent", "double": "Le grand carillon"}


## La partition d'un mouvement : battement -> rang du sonneur (-1 : silence). Chaque rang a ses notes
## (à une près), jamais deux sonneurs sur le même battement.
static func cloches_partition(motif: String, n: int, total: int, densite: float, rng: RandomNumberGenerator) -> Array[int]:
	var part: Array[int] = []
	part.resize(total)
	part.fill(-1)
	var pool: Array = []
	var idx := 0
	var pas := maxi(int(round(1.0 / maxf(densite, 0.1))), 1)
	var b := C_INTRO
	while b < total:
		if motif == "ronde":
			part[b] = idx % n
			idx += 1
			b += pas
			continue
		if rng.randf() < densite:
			if pool.is_empty():
				pool = range(n)
				for i in range(pool.size() - 1, 0, -1):
					var j := rng.randi_range(0, i)
					var x = pool[i]
					pool[i] = pool[j]
					pool[j] = x
			var r: int = pool.pop_back()
			part[b] = r
			if motif == "double" and rng.randf() < 0.3 and b + 1 < total:
				part[b + 1] = r
				b += 1
		b += 1
	return part


## Les mouvements d'une partie : [{motif, periode, total, echauffement, debut, partition}] ; la partie entière
## dure `cible(niveau)` à un battement près (avec les pauses entre mouvements).
static func cloches_plan(niveau: String, n: int, rng: RandomNumberGenerator) -> Array:
	var modele: Array = C_MOUVEMENTS.get(niveau, C_MOUVEMENTS["simple"])
	var k := modele.size()
	var pause: float = C_PAUSE.get(niveau, 3.0)
	var part_t := (cible(niveau) - k * pause) / k
	var mvs: Array = []
	var t := pause
	for m: Array in modele:
		var periode: float = float(C_PERIODE[niveau]) * float(m[1]) * rng.randf_range(0.97, 1.03)
		var total := maxi(int(round(part_t / periode)), C_INTRO + 6)
		mvs.append({"motif": m[0], "periode": periode, "total": total, "echauffement": C_INTRO, "debut": t,
			"partition": cloches_partition(m[0], n, total, float(m[2]), rng)})
		t += total * periode + pause
	return mvs


## Les notes que doit sonner le rang r dans toute la partie.
static func cloches_notes(mvs: Array, r: int) -> int:
	var c := 0
	for m: Dictionary in mvs:
		for x: int in m["partition"]:
			if x == r:
				c += 1
	return c


## Ce qu'il faut pour réussir sa part : [notes justes requises, fausses notes tolérées], pour un sonneur qui
## a `notes` notes dans la partie.
static func cloches_seuils(niveau: String, notes: int) -> Array:
	var frac: float = {"simple": 0.6, "normal": 0.7, "dur": 0.75, "extreme": 0.8}.get(niveau, 0.6)
	var fx: float = {"simple": 0.15, "normal": 0.10, "dur": 0.08, "extreme": 0.05}.get(niveau, 0.15)
	return [int(ceil(notes * frac)), maxi(int(ceil(notes * fx)), 1)]

# ================================================================ l'Incendie

## Les bâtiments qui peuvent brûler, avec leurs voisins (le feu se propage de proche en proche).
const I_FOYERS := [
	{"nom": "la grange", "voisins": [1, 2, 4]},
	{"nom": "la meule de foin", "voisins": [0, 3]},
	{"nom": "l'étable", "voisins": [0]},
	{"nom": "l'atelier", "voisins": [1]},
	{"nom": "le fenil", "voisins": [0]},
]
## Par niveau : combien de foyers existent, lesquels brûlent au départ (et avec quelle intensité), le temps
## entre deux seaux, le délai pour passer un seau, la croissance d'un foyer (par seconde), le recul par seau,
## le temps de chauffe avant qu'un voisin s'embrase, le nombre de bâtiments perdus qui fait échouer.
const I_PLAN := {
	"simple": {"foyers": 4, "depart": [[0, 0.75], [1, 0.75], [2, 0.75]], "intervalle": 4.0, "delai": 3.5, "croissance": 0.0004, "reduction": 0.06, "chauffe": 32.0, "ruines": 2},
	"normal": {"foyers": 5, "depart": [[0, 0.7], [1, 0.7], [2, 0.7]], "intervalle": 3.8, "delai": 2.8, "croissance": 0.0007, "reduction": 0.06, "chauffe": 28.0, "ruines": 2},
	"dur": {"foyers": 5, "depart": [[0, 0.75], [1, 0.75]], "intervalle": 3.2, "delai": 2.5, "croissance": 0.001, "reduction": 0.06, "chauffe": 22.0, "ruines": 1},
	"extreme": {"foyers": 5, "depart": [[0, 0.5], [2, 0.5]], "intervalle": 3.0, "delai": 2.2, "croissance": 0.0015, "reduction": 0.06, "chauffe": 16.0, "ruines": 1},
}


static func incendie_plan(niveau: String) -> Dictionary:
	return I_PLAN.get(niveau, I_PLAN["simple"])


## Le nombre minimal de seaux qu'il faut jeter pour venir à bout des foyers de départ (la croissance ne peut
## qu'en ajouter), et donc le temps MINIMAL d'une partie : les seaux n'arrivent qu'un toutes les `intervalle`.
static func incendie_seaux_min(niveau: String) -> float:
	var p := incendie_plan(niveau)
	var somme := 0.0
	for d: Array in p["depart"]:
		somme += float(d[1])
	return somme / float(p["reduction"])


static func incendie_temps_min(niveau: String) -> float:
	return (incendie_seaux_min(niveau) - 1.0) * float(incendie_plan(niveau)["intervalle"])
