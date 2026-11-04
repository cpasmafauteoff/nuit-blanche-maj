extends MiniJeu
## Les Lanternes du marais : UN joueur est le MARCHEUR (celui qui a pris la zone « Marcheur », sinon
## le hasard). Il traverse le marais dans le brouillard SANS voir quelles pierres sont sûres. Tous
## les autres, sur la rive, voient le bon chemin (les pierres sûres sont éclairées) et le guident
## à la voix. Une pierre piège : il tombe à l'eau, perd une lanterne de vie et repart de la
## dernière pierre sûre. Les lanternes de vie suivent le niveau (cf. Quetes.vies_marais : facile
## illimitées, normal 10, difficile 3, extrême 1) ; le temps raccourcit lui aussi.
## Le marcheur MARCHE POUR DE VRAI, à la première personne, de pierre en pierre (31/10) : l'hôte
## lit ses pieds (`pieds`). Une pierre piège s'enfonce sous lui, et poser le pied dans l'eau le fait
## tomber : il est replacé sur la dernière pierre sûre (`rappels`) et perd une lanterne de vie.
## Sabotage : un guide loup envoie le marcheur à l'eau (à la voix).
## Le marais est GRAND (cf. regles/marais.gd) : un parcours en lacets, des embranchements, des îlots à poteaux
## colorés (les étapes), des pierres qui s'enfoncent en cadence (la tourbière). Durée : temps limite =
## Quetes.duree_max, parcours dimensionné pour durer au moins Quetes.duree_min.
## Réussite : le marcheur atteint l'arrivée, toute l'équipe réussit ; sinon personne.

const DIRS := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
const FLECHES := ["↑", "↓", "←", "→"]
const MOTS := ["en haut", "en bas", "à gauche", "à droite"]

var taille := 5              # la LARGEUR du marais, en pierres
var haut := 5                # sa PROFONDEUR, en pierres
var carte := ""              # taille × haut caractères (cf. Marais) : '.' sûre, '#' piège, 'X' arrivée, '~' eau, 'm'/'t' pierres qui s'enfoncent
var depart := 0
var but := 0
var iles: Array[int] = []    # les cases des poteaux (un par étape franchie), du sud au nord
var etape := 0               # combien d'îlots le marcheur a atteints
var vies_max := 0            # 0 : lanternes illimitées, seul le temps compte
var vies := 0
var marcheur := 0
var pos := 0
var vus := {}                # case -> true (ce que le marcheur a découvert : pierres foulées, pièges tombés)
var annonce := ""
var _annonce_t := 0.0
var _bot_t := 0.0
var _conseil := -1
var _conseil_pos := -1
var _guide_dit_pos := -1
var _parleur := -1           # le bot qui guide à voix haute (s'il y en a un)
var chutes := 0              # combien de fois le marcheur est tombé (les décors s'en servent pour l'éclaboussure)
var chute_pos := Vector3.ZERO   # où il est tombé (local à la clairière)
var _arme := false           # les pieds ne comptent qu'une fois le marcheur arrivé sur la rive
var _t_eau := 0.0            # depuis combien de temps il a le pied dans l'eau
var _grace := 0.0            # juste après une chute, on ne juge plus rien le temps d'être replacé
var piege_sous := -1         # la pierre piège sous ses pieds (elle s'enfonce), sinon -1
var _t_piege := 0.0          # depuis combien de temps il est sur une pierre piège
var _bot_parti := false      # le bot marcheur est arrivé sur sa pierre de départ
var _bot_vers := -1          # la pierre où un bot marcheur se rend
var _bot_vers_t := 0.0
var _bots := {}              # les joueurs joués par des bots (vus passer dans `bot`)
var _pos_depuis := 0.0       # le moment où le marcheur s'est posé sur sa pierre (ou y a été remis)
var _guide_prevu_pos := -1   # la pierre pour laquelle le guide bot a déjà lu sa carte
var _guide_parle_a := 0.0    # le moment où il dira la direction
var _conseil_t := 0.0        # le moment où il l'a dite
var _conseil_vrai := true
var _conseil_attend := false # a-t-il dit d'attendre que la pierre remonte ?
var _dernier_mensonge := -99.0
var _agit_pos := -1          # la pierre pour laquelle le bot marcheur a calculé quand il agit
var _agit_a := 0.0           # le moment où il peut bouger (il a entendu, compris)
var _chutes_vues := 0        # combien de chutes il a déjà digérées

const DELAI_EAU := 0.3       # le temps de traverser un interstice sans tomber, pas de rester
const DELAI_PIEGE := 0.4     # la pierre piège cède sous lui


func demarrer() -> void:
	vies_max = Quetes.vies_marais(niveau)
	vies = vies_max
	duree = Quetes.duree_max(niveau)
	_generer()
	marcheur = elu if ids.has(elu) else ids[rng.randi_range(0, ids.size() - 1)]
	pos = depart
	vus = {depart: true}
	_bot_t = 1.5


func a_pied(id: int) -> bool:
	return id == marcheur


func depart_locale(_id: int) -> Vector3:
	return centre_de(depart)


## La rive sud (côté guides) : tout ce qui est au sud de cette ligne est solide.
func z_rive() -> float:
	return Quetes.MARAIS_SUD + Quetes.R_PIERRE + 0.3


## La pierre sous ce point (local à la clairière), ou -1 si c'est de l'eau (ou un trou du marais).
func pierre_sous(p: Vector3) -> int:
	# Les pierres sont décalées de moins d'une demi-case : on teste la case ronde et ses voisines.
	var gx := roundi(p.x / Quetes.MARAIS_PAS + (taille - 1) * 0.5)
	var gy := roundi((p.z - Quetes.MARAIS_SUD) / Quetes.MARAIS_PAS + (haut - 1))
	var meilleure := -1
	var dmin: float = Quetes.R_PIERRE + 0.04
	for y in range(gy - 1, gy + 2):
		for x in range(gx - 1, gx + 2):
			if x < 0 or y < 0 or x >= taille or y >= haut:
				continue
			if carte[y * taille + x] == "~":
				continue
			var c := Quetes.case_marais(y * taille + x, taille, haut)
			var d := Vector2(p.x - c.x, p.z - c.z).length()
			if d < dmin:
				dmin = d
				meilleure = y * taille + x
	return meilleure


func _generer() -> void:
	var g := Marais.generer(niveau, rng)
	taille = g["l"]
	haut = g["h"]
	carte = g["carte"]
	depart = g["depart"]
	but = g["but"]
	iles.assign(g["iles"])


## Le centre de la pierre k.
func centre_de(k: int) -> Vector3:
	return Quetes.case_marais(k, taille, haut)


## Le plus court chemin de pierres sûres de `depuis` à l'arrivée : les cases à suivre (départ
## exclu). Vide s'il n'y en a pas.
func chemin(depuis: int) -> Array:
	return Marais.chemin(carte, taille, haut, depuis, but)


func _voisins(c: int) -> Array:
	var r: Array = []
	for k in 4:
		var v: int = _vers(c, k)
		if v >= 0:
			r.append(v)
	return r


## La case voisine de `c` dans la direction k, ou -1 hors de la carte.
func _vers(c: int, k: int) -> int:
	var dv: Vector2i = DIRS[k]
	var x: int = c % taille + dv.x
	var y: int = c / taille + dv.y
	if x < 0 or y < 0 or x >= taille or y >= haut:
		return -1
	return y * taille + x


func _dir_vers(a: int, b: int) -> int:
	for k in 4:
		if _vers(a, k) == b:
			return k
	return 0


## Un fantôme souffle la brume sur le marais : le marcheur oublie ce qu'il avait découvert.
func _hanter(id: int) -> String:
	if id != marcheur:
		return super._hanter(id)
	vus = {pos: true}
	annonce = "La brume recouvre les pierres de %s." % nom(id)
	_annonce_t = 3.0
	return "La brume efface les pierres que %s avait trouvées." % nom(id)


func action(id: int, d: Dictionary) -> void:
	if fini or id != marcheur or not d.has("dir"):
		return
	# Dès que l'hôte lit les pieds du marcheur, il marche pour de vrai : les flèches n'existent plus.
	if pieds.has(id):
		return
	var k: int = int(d["dir"])
	if k < 0 or k > 3:
		return
	var nv: int = _vers(pos, k)
	if nv < 0 or carte[nv] == "~":
		return
	_poser_pied(nv)


## Cette pierre cède-t-elle sous le pied du marcheur à cet instant ? ('#' et 't' toujours ; 'm' quand elle est basse.)
func cede(k: int) -> bool:
	if k < 0:
		return false
	var c := carte[k]
	if c == "#" or c == "t":
		return true
	return c == "m" and not Marais.haute(temps, k, niveau)


## Le marcheur pose le pied sur la pierre nv (un pas discret, ou ses vrais pieds qui y arrivent).
func _poser_pied(nv: int) -> void:
	vus[nv] = true
	_conseil_pos = -1       # le conseil d'avant ne vaut plus : le guide en redonnera un
	_guide_dit_pos = -1
	_guide_prevu_pos = -1
	_pos_depuis = temps
	if cede(nv):
		_tomber(nv)
		return
	pos = nv
	_voir_ile(nv)
	if nv == but:
		for x in ids:
			_reussis[x] = true
		annonce = "%s a traversé le marais !" % nom(marcheur)
		_annonce_t = 3.0
		terminer()


## Le marcheur est-il sur un îlot qu'il n'avait pas encore atteint ? C'est une étape de plus.
func _voir_ile(nv: int) -> void:
	for i in iles.size():
		var c: int = iles[i]
		if absi(nv % taille - c % taille) + absi(nv / taille - c / taille) <= 1 and carte[nv] == ".":
			if i + 1 > etape:
				etape = i + 1
				annonce = "Poteau %s atteint : devant toi, %s." % [Marais.BALISES[i % Marais.BALISES.size()], Marais.nom_etape(etape, Marais.nb_etapes(niveau))]
				_annonce_t = 4.0
			return


## À l'eau ! (pierre piège nv, ou -1 : le pied dans l'eau.) Il reste sur la dernière pierre sûre.
func _tomber(nv: int) -> void:
	if nv >= 0:
		vus[nv] = true
	if vies_max > 0:
		# Des bots seuls ne perdent pas la dernière lanterne avant la durée minimale (cf. RythmeHumain).
		vies = vies_apres(vies)
	chutes += 1
	chute_pos = pieds[marcheur] if pieds.has(marcheur) else centre_de(nv if nv >= 0 else pos)
	_grace = 1.2
	piege_sous = -1
	_t_eau = 0.0
	_t_piege = 0.0
	_bot_vers = -1
	_conseil_pos = -1
	_guide_dit_pos = -1
	_guide_prevu_pos = -1
	_pos_depuis = temps
	if vies_max > 0 and vies <= 0:
		annonce = "Plus aucune lanterne : %s est englouti par le marais." % nom(marcheur)
		_annonce_t = 3.0
		terminer()
		return
	annonce = "%s tombe à l'eau ! Il revient sur la dernière pierre sûre." % nom(marcheur)
	_annonce_t = 2.5
	var ici := centre_de(pos)
	rappels.append([marcheur, ici, ici + Vector3(0, 0, -6.0)])


## Les pieds du marcheur (réels) : sur une pierre sûre il avance, sur une pierre piège (ou une pierre qui
## s'est enfoncée) elle cède, dans l'eau il tombe. Pas de verdict en l'air (il saute), ni juste après une chute.
func _suivre_les_pieds(delta: float) -> void:
	var p: Vector3 = pieds[marcheur]
	if _grace > 0.0:
		_grace -= delta
		return
	if p.y > 0.2:
		return
	var k := pierre_sous(p)
	piege_sous = k if k >= 0 and (carte[k] == "#" or carte[k] == "t") else -1
	var sur_rive := p.z > z_rive()
	if not _arme:
		# Le marcheur marche d'abord jusqu'à son départ : rien ne compte avant qu'il y soit.
		# (Pas la rive : il traverse peut-être le marais pour y arriver, escorté par le jeu.)
		if k == depart:
			_arme = true
		return
	if k >= 0:
		_t_eau = 0.0
		if cede(k):
			vus[k] = true
			_t_piege += delta
			if _t_piege >= DELAI_PIEGE:
				_tomber(k)
		else:
			_t_piege = 0.0
			if k != pos:
				_poser_pied(k)
	elif sur_rive:
		_t_eau = 0.0
		_t_piege = 0.0
	else:
		_t_piege = 0.0
		_t_eau += delta
		if _t_eau >= DELAI_EAU:
			_tomber(-1)


func avancer(delta: float) -> void:
	super.avancer(delta)
	if fini:
		return
	if pieds.has(marcheur):
		_suivre_les_pieds(delta)
		if fini:
			return
	_annonce_t -= delta
	if _annonce_t <= 0.0:
		annonce = ""


## Ce que voit `id` : '@' le marcheur, 'X' l'arrivée, '~' l'eau (un trou, tout le monde le voit) ; le marcheur
## ne connaît que ce qu'il a foulé ('.' pierre sûre, '#' piège où il est tombé, '?' le reste, 'u' le reste
## quand la pierre s'enfonce et remonte : il ne sait pas si elle est sûre) ; un guide voit tout ('o' pierre
## sûre éclairée, '.' déjà foulée, '#' piège, 'm' pierre sûre qui s'enfonce, 't' piège qui s'enfonce).
func _grille(id: int) -> String:
	var s := PackedStringArray()
	for k in taille * haut:
		var c := carte[k]
		if k == pos:
			s.append("@")
		elif c == "~":
			s.append("~")
		elif k == but:
			s.append("X")
		elif id == marcheur:
			if c == "m" or c == "t":
				s.append("u")
			elif vus.has(k):
				s.append(c)
			else:
				s.append("?")
		elif c == "#" or c == "t":
			s.append(c)
		elif c == "m":
			s.append("m")
		else:
			s.append("." if vus.has(k) else "o")
	return "".join(s)


func texte_vies() -> String:
	if vies_max <= 0:
		return "Lanternes de vie : illimitées. Seul le temps compte."
	return "Lanternes de vie : %d / %d. Chaque chute à l'eau en éteint une." % [vies, vies_max]


func vue_pour(id: int) -> Dictionary:
	var blocs := []
	var consigne := ""
	var grille := {"t": "grille", "l": taille, "h": haut, "v": _grille(id), "clic": false,
		"vies": vies, "vies_max": vies_max, "marcheur": id == marcheur,
		"chutes": chutes, "cx": chute_pos.x, "cz": chute_pos.z, "sous": piege_sous,
		"temps": temps, "niveau": niveau, "etape": etape, "iles": iles}
	if id == marcheur:
		consigne = "Traverse le marais de pierre en pierre : écoute tes guides"
		blocs.append(MiniJeu.texte("Tu es le MARCHEUR : c'est toi qui avances", 20, "or"))
		blocs.append(grille)
		blocs.append(MiniJeu.texte("Tu ne vois pas quelles pierres tiennent. Marche (ou saute) de l'une à l'autre : l'eau t'engloutit, une pierre piège cède, une pierre qui s'enfonce ne tient que quand elle est haute.", 16, "gris"))
	else:
		consigne = "Guide le marcheur à la voix : les pierres éclairées sont sûres"
		blocs.append(MiniJeu.texte("GUIDE de %s — %s" % [nom(marcheur), consigne], 20, "or"))
		blocs.append(grille)
		blocs.append(MiniJeu.texte(texte_reperes(), 14, "gris"))
		blocs.append(MiniJeu.texte(texte_poteaux(), 14, "gris"))
	blocs.append(MiniJeu.texte(texte_etape(), 16, "or"))
	blocs.append(MiniJeu.texte(texte_vies(), 18, "or"))
	if annonce != "":
		blocs.append(MiniJeu.texte(annonce, 22, "rouge"))
	blocs.append(MiniJeu.jauge(1.0 - temps / duree, "Temps de la traversée"))
	return {"consigne": consigne, "blocs": blocs}


## « Étape 2 / 4 : La Tourbière » : où en est le marcheur.
func texte_etape() -> String:
	var s := Marais.nb_etapes(niveau)
	return "Étape %d / %d : %s" % [etape + 1, s, Marais.nom_etape(etape, s)]


## Les repères du décor que les guides peuvent nommer à la voix.
func texte_reperes() -> String:
	var noms := PackedStringArray()
	for r: Dictionary in Marais.REPERES:
		noms.append(str(r["nom"]))
	return "Repères : %s" % ", ".join(noms)


## Les couleurs des poteaux des îlots (un par étape franchie).
func texte_poteaux() -> String:
	var poteaux := PackedStringArray(Marais.BALISES.slice(0, maxi(Marais.nb_etapes(niveau) - 1, 0)))
	return "Poteaux des îlots : %s" % ", ".join(poteaux)


## Le temps qu'un guide met à repérer, sur sa carte, où mène la pierre où le marcheur vient de se poser.
static func coup_d_oeil(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(0.4, 0.8)


## Le temps que met un marcheur à entendre le premier mot du guide (« Va… ») et à décider de bouger.
static func ecoute(rng: RandomNumberGenerator) -> float:
	return 0.8 + rng.randf_range(0.3, 0.7)


## Un guide saboteur ment rarement, et jamais deux fois à la suite de près (un loup qui se fait prendre ne
## ment pas à chaque pierre) : il faut au moins `MENSONGE_ECART` secondes depuis son dernier mensonge.
const MENSONGE_P := 0.12
const MENSONGE_ECART := 12.0


static func peut_mentir(depuis_dernier: float, tirage: float) -> bool:
	return depuis_dernier >= MENSONGE_ECART and tirage < MENSONGE_P


func bot(id: int, delta: float) -> void:
	if fini:
		return
	_bots[id] = true
	if id != marcheur:
		_bot_guide(id)
		return
	_bot_marcheur(id, delta)


## Un bot guide (le premier venu) lit sa carte, puis dit la direction à chaque nouvelle pierre : un coup d'oeil,
## puis la phrase. Un saboteur ment, mais pas souvent.
func _bot_guide(id: int) -> void:
	if _parleur < 0:
		_parleur = id
	if id != _parleur or pos == but or temps <= 1.0 or pos == _guide_dit_pos:
		return
	if _guide_prevu_pos != pos:
		_guide_prevu_pos = pos
		_guide_parle_a = maxf(_pos_depuis, 0.0) + coup_d_oeil(rng)
	if temps < _guide_parle_a:
		return
	_guide_dit_pos = pos
	var ch := chemin(pos)
	if ch.is_empty():
		return
	var k: int = _dir_vers(pos, int(ch[0]))
	var ment := false
	if peut_saboter(id) and peut_mentir(temps - _dernier_mensonge, rng.randf()):
		ment = true
		_dernier_mensonge = temps
		var piege := -1
		for q in 4:
			var v: int = _vers(pos, q)
			if v >= 0 and (carte[v] == "#" or carte[v] == "t"):
				piege = q
		k = piege if piege >= 0 else (k + 1 + rng.randi_range(0, 2)) % 4
	_conseil = k
	_conseil_pos = pos
	_conseil_t = temps
	_conseil_vrai = not ment
	# Une pierre qui s'enfonce : l'honnête le dit (« attends qu'elle remonte »), le saboteur se tait.
	_conseil_attend = carte[int(ch[0])] == "m" and not peut_saboter(id)
	if _conseil_attend:
		paroles.append([id, "Attends qu'elle remonte, puis va %s !" % MOTS[k]])
	else:
		paroles.append([id, "Va %s !" % MOTS[k]])


## Le marcheur bot n'a que ce qu'un marcheur a : la voix de ses guides. Un guide bot parle : il l'écoute (il
## attend qu'il ait dit sa phrase). Si tous les guides sont des personnes, il ne les entend pas : il leur laisse
## le temps de lire la carte, de dire la direction et d'être compris, puis il va où elles l'auraient envoyé.
## Il marche pour de vrai de pierre en pierre, se trompe parfois, souffle après une chute.
func _bot_marcheur(id: int, delta: float) -> void:
	if chutes != _chutes_vues:
		_chutes_vues = chutes
		_bot_t = RythmeHumain.regret(rng)
		_agit_pos = -1
	_bot_t -= delta
	if pieds.has(id):
		# L'hôte lit ses pieds : le bot marche pour de vrai jusqu'à la pierre choisie, avant de choisir la suivante.
		if _bot_vers >= 0:
			_bot_vers_t += delta
			var c := centre_de(_bot_vers)
			var p: Vector3 = pieds[id]
			if Vector2(p.x - c.x, p.z - c.z).length() < 0.15 or _bot_vers_t > 4.0:
				_bot_vers = -1
			return
		# Il ne choisit sa première pierre qu'une fois arrivé sur la pierre de départ (il y marche d'abord).
		if not _bot_parti:
			var dep_c := centre_de(depart)
			var pp: Vector3 = pieds[id]
			if Vector2(pp.x - dep_c.x, pp.z - dep_c.z).length() > 0.45:
				return
			_bot_parti = true
			_pos_depuis = temps
			_bot_t = rng.randf_range(0.4, 0.9)
			return
	if _bot_t > 0.0:
		return
	var dir := -1
	var attend := false
	if _parleur >= 0:
		# Un guide bot parle : il l'écoute, mais attend qu'il ait parlé pour cette pierre.
		if _conseil_pos != pos:
			return
		if _agit_pos != pos:
			_agit_pos = pos
			_agit_a = _conseil_t + ecoute(rng)
		dir = _conseil
		attend = _conseil_attend
	else:
		# Des personnes guident : le temps de lire la carte, de dire, de comprendre, puis il va où elles l'auraient envoyé.
		if _agit_pos != pos:
			_agit_pos = pos
			_agit_a = _pos_depuis + coup_d_oeil(rng) + rng.randf_range(0.2, 0.5) + ecoute(rng)
		var ch2 := chemin(pos)
		if not ch2.is_empty():
			dir = _dir_vers(pos, int(ch2[0]))
			attend = carte[int(ch2[0])] == "m"
	if temps < _agit_a:
		return
	var err: float = {"simple": 0.05, "normal": 0.07, "dur": 0.06, "extreme": 0.05}.get(niveau, 0.06)
	var voulu := dir
	if dir < 0 or rng.randf() < err:
		dir = rng.randi_range(0, 3)
	var nv: int = _vers(pos, dir)
	# Une pierre qui s'enfonce : s'il en a été prévenu il attend qu'elle soit haute pour un bon moment.
	if attend and dir == voulu and nv >= 0 and carte[nv] == "m" and not Marais.haute_pendant(temps, nv, niveau, 1.6):
		_bot_t = 0.25
		return
	_bot_t = rng.randf_range(0.5, 0.9)
	if pieds.has(id):
		if nv >= 0 and carte[nv] != "~":
			_bot_vers = nv
			_bot_vers_t = 0.0
			deplacements.append([id, centre_de(nv)])
		else:
			# Il tâte l'eau du bout du pied et se rend compte : un temps perdu.
			_bot_t = RythmeHumain.reaction(rng)
		return
	action(id, {"dir": dir})
