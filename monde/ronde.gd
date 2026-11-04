class_name Ronde
extends Node3D
## La Ronde : 12 maisons en cercle autour du Conseil, le chemin de ronde derrière,
## quatre lieux à la lisière (moulin, forge, chapelle, cimetière), la forêt qui se penche.
## Un village à l'abandon : rien n'y est accueillant, ni le jour ni la nuit.
##
## Repères : centre (0, 0, 0). Une maison i est à l'angle i·30°, rayon R_MAISON, porte
## d'entrée tournée vers le centre, porte de derrière vers le chemin de ronde.

## Le village grandit avec la partie (décision d'Edwin, 29/10) : autant de maisons que de
## joueurs (6 à 16), plus le temple de l'autel, sur un cercle dont le rayon suit. Tout ce qui est
## au-delà des maisons (chemin de ronde, lieux, lisière, clairières) recule d'autant : `ECART`.
## `configurer(n)` règle tout ; par défaut, 12 maisons.
const MAX_MAISONS := 16
static var NB_MAISONS := 12
static var R_MAISON := 15.0
static var R_SOUCHES := 4.6
static var R_PLACE := 11.0
static var R_CHEMIN_MIN := 18.6
static var R_CHEMIN_MAX := 23.4
static var R_LIEUX := 31.0
static var R_LIMITE := 37.0
static var ECART := 0.0
const LARGEUR := 5.0       # façade : une porte (2 m) entre deux fenêtres (1,5 m chacune)
const PROFONDEUR := 4.4    # deux modules de mur de 2 m, plus l'épaisseur des murs de façade
const HAUTEUR := 3.12      # hauteur d'un module de mur du pack
const EPAIS := 0.4         # épaisseur d'un mur (le module : de -0,31 à +0,09)
const FAITAGE := 6.5       # sommet du toit (les corbeaux s'y perchent)
static var POS_CHARRETTE := Vector3(26.5, 0, -4.0)
const VILLAGE := "res://modeles/village/"   # pack Quaternius « Medieval Village MegaKit » (CC0)
## Angle d'ouverture d'une porte (vers l'intérieur de la maison, des deux côtés).
const PORTE_OUVERTE_DEG := 95.0
## La pierre du sacrifice : sur le temple de l'autel (place 0 du cercle), à hauteur de sa terrasse.
## Au centre de la place, il n'y a plus qu'un petit feu de camp (décision d'Edwin, 29/10).
static var PIERRE := Vector3(0, 1.5, 15.0)
const PIERRE_HAUT := 0.78
## Le temple : une terrasse de pierre de la taille d'une maison, 1,5 m de haut, huit marches.
const TEMPLE_LARGE := 5.0
const TEMPLE_PROFOND := 4.8
const TEMPLE_HAUT := 1.5
const MARCHES := 8
const MARCHES_LARGE := 3.0
const MARCHES_LONG := 2.4
## Places sur le cercle : les maisons, le temple (place 0) et le tableau des quêtes (la dernière).
static var PLACES := 14
const CHIFFRES := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI"]
const COUCHE_PORTE_AVANT := 1 << 3   # couche de collision 4
const COUCHE_PORTE_ARRIERE := 1 << 2 # couche de collision 3 (les loups la traversent la nuit… porte ouverte)

## Le sol du chemin de ronde, secteur par secteur (24 secteurs de 15°).
const SOLS := ["graviers", "terre", "planches", "planches", "flaques", "terre",
	"feuilles", "feuilles", "terre", "graviers", "graviers", "flaques",
	"terre", "planches", "feuilles", "terre", "flaques", "flaques",
	"graviers", "terre", "feuilles", "planches", "terre", "graviers"]

## Lieux de la lisière : angle (degrés) et nom.
## Dans le village, il ne reste que ce qu'on a bâti, et le cimetière (décision d'Edwin, 29/10) :
## moulin, chapelle, forge, calvaire, bûcheron, tas de bois et enclos sont partis.
const LIEUX := {"cimetiere": 180.0}
const PETITS_LIEUX := {}
static var R_LISIERE := 38.6
## Le tableau des quêtes, à côté du temple, sur sa propre place du cercle, un peu en avant des
## façades ; le panneau des indices à côté. Le sentier des quêtes part de l'autre côté du temple.
static var TABLEAU := Vector3(-2.9, 0, -8.0)
## Au-delà de la lisière (pour les équipes en quête) : un second mur, plus loin.
static var R_LIMITE_QUETE := 51.0
const NOMS_LIEUX := {"cimetiere": "le cimetière"}

## Couleurs passées : ocres sales, verts malades, gris. Le rouge est réservé (braises, sang, vote).
const MURS := [Color(0.55, 0.5, 0.42), Color(0.48, 0.5, 0.45), Color(0.52, 0.46, 0.44),
	Color(0.45, 0.47, 0.5), Color(0.56, 0.52, 0.4), Color(0.47, 0.44, 0.48)]

var postes := {}            # nom de tâche -> Vector3 (où se tenir pour la faire)
var _env: Environment
var _soleil: DirectionalLight3D
var _lune: DirectionalLight3D
var _astre_lune: MeshInstance3D
var _mat_lune: StandardMaterial3D
var _ciel: ProceduralSkyMaterial
var _feu: OmniLight3D
var _tache: MeshInstance3D
var _braises: StandardMaterial3D
var _bougies: Array[OmniLight3D] = []
var _fenetres: Array[StandardMaterial3D] = []
var _verre: StandardMaterial3D       # la vitre de la maison en cours de construction
var _mats_pat := {}                   # matériaux du pack, patinés (assombris), partagés
var _mats_tex := {}                   # matériaux texturés (Poly Haven), partagés
var _mat_cernes: StandardMaterial3D   # bout coupé d'un rondin
var _portes := {}           # "i:avant" / "i:arriere" -> {pivot, corps, ouverte}
var _maisons: Array[Node3D] = []
var roulotte: Roulotte      # la roulotte du colporteur, seulement au menu (onglet Cosmétique)
var _parures := {}          # maison -> [sorte, nœud] (cf. Parures)
var _barricades := {}
var _corbeaux: Array[Node3D] = []
var _cordes: Array[Node3D] = []
var _tombes := 0
var _ailes_moulin: Node3D
var _nuages: MeshInstance3D
var _mat_nuages: ShaderMaterial
var _etoiles: MeshInstance3D
var _mat_etoiles: ShaderMaterial
var _jour_nuageux := 0.0      # 1 le jour : les nuages passent devant le soleil
var _torches: Array[OmniLight3D] = []
var _portail_tronc := {}
var _fiches_quetes: Array[Dictionary] = []   # les trois parchemins du tableau (cf. _fiche)
var _texte_indices: Label3D
var _panneaux_zones: Array[Label3D] = []
## Les murs des maisons (pas les portes) : seuls solides que le fantôme traverse (Edwin, 03/11).
var murs_maisons: Array[StaticBody3D] = []
var _portails: Array[Dictionary] = []     # zone -> {corps: CollisionShape3D, battants: [Node3D], ouvert: float}
var _t := 0.0
var _chaines: Array = []        # [articulation haute, articulation basse, phase]
var _maillon: TorusMesh
var _chiffres := {}         # maison -> [Label3D] (les deux numéros gravés)
## La nuit (décisions d'Edwin, 29/10) : rideaux tirés, chambres allumées.
var _rideaux := {}          # maison -> [[panneau gauche, panneau droit]…] ; [0] et [1] : la façade
var _lampes: Array[OmniLight3D] = []
var _bougie_chambre := {}   # maison -> OmniLight3D (la bougie de la table)
var _flamme_chambre := {}   # maison -> la flamme visible
## Les maisons des morts : plus une lumière la nuit, fenêtres comprises (Edwin, 30/10). Tenu par principal.
var maisons_eteintes := {}
var _maison_lumiere := {}   # lumière -> maison
var _nuit_close := false
var _ma_maison := -1
## Les visages d'écorce : {pos (monde), dir (vers où il regarde), yeux: StandardMaterial3D}.
var visages: Array[Dictionary] = []
var _mat_arbre: StandardMaterial3D
var _mat_aiguilles: Material
var _mur_tenebres: MeshInstance3D   # le mur de ténèbres (cf. _mur_de_tenebres)
var _mat_creux: StandardMaterial3D
var _mat_bois_mort: StandardMaterial3D   # l'écorce pâle d'un visage : le bois mort y blanchit
## La brume en volume (halos autour des lumières) : coûteuse, on peut la couper.
static var brume_volumetrique := true
var _phase := "jour"
var _feu_force := 0.8
var _rng := RandomNumberGenerator.new()


## Construit par petites étapes (cf. _construire_par_etapes) : posé par principal.gd au lancement, pour que
## l'écran de chargement reste vivant pendant les ~8 s que prend le village.
var par_etapes := false
var construite := false
## La part du village déjà construite (0..1), à chaque étape.
signal avance(part: float)
signal construit


func _ready() -> void:
	if par_etapes:
		_construire_par_etapes()
		return
	for etape: Callable in _etapes():
		etape.call()
	construite = true


## Les étapes du village, dans l'ordre (le tirage au hasard en dépend).
func _etapes() -> Array[Callable]:
	var e: Array[Callable] = [_commencer, _ciel_et_lumieres, _sol, _place]
	for i in NB_MAISONS:
		e.append(_maison.bind(i))
	e.append_array([_chemin_de_ronde, _cimetiere, _foret, _lisiere, _mur_de_tenebres, _tableau_des_quetes,
			_clairieres_de_quete, _foret_lointaine, _plaine, _poser_roulotte, _sentiers, _sous_bois,
			_tas_de_feuilles, _corbeaux_sur_les_toits, _glauque, _achever])
	return e


## Une image entre deux étapes dès qu'un vingtième de seconde est passé : la barre avance, la brume
## dérive. Une mise à jour trouvée arrête tout (le jeu va redémarrer) et laisse le réseau tranquille.
func _construire_par_etapes() -> void:
	var etapes := _etapes()
	var depuis := Time.get_ticks_msec()
	for i in etapes.size():
		etapes[i].call()
		avance.emit(float(i + 1) / etapes.size())
		if Time.get_ticks_msec() - depuis > 50:
			await get_tree().process_frame
			depuis = Time.get_ticks_msec()
		var maj := get_node_or_null("/root/MiseAJour")
		if maj and maj.redemarre:
			return
	construite = true
	construit.emit()


func _commencer() -> void:
	_rng.seed = 13
	_sur = self
	_verre = _verre_neuf()


func _poser_roulotte() -> void:
	roulotte = Roulotte.new()
	roulotte.transform = repere_roulotte()
	roulotte.visible = false
	add_child(roulotte)


func _achever() -> void:
	alleger(self)
	regler_ambiance("jour", 0.0)


## Les petites choses (cailloux, clous, bougies, fruits…) ne projettent plus d'ombre, et les
## détails s'effacent au loin. ~4 000 objets, tous redessinés par chaque palier d'ombre, faisaient
## 9 000 à 12 000 ordres de dessin par image au village (Edwin, 30/10 : « on dirait 10 fps »).
static func alleger(racine: Node) -> void:
	for g: GeometryInstance3D in racine.find_children("*", "GeometryInstance3D", true, false):
		if g is MultiMeshInstance3D or not g.is_inside_tree():
			continue
		var b := (g as VisualInstance3D).get_aabb()
		var taille := maxf(b.size.x, maxf(b.size.y, b.size.z)) * g.global_basis.get_scale().abs().x
		if taille < 0.6:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if taille < 1.2 and g.visibility_range_end == 0.0:
			g.visibility_range_end = 40.0
			g.visibility_range_end_margin = 4.0
			g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


# ---------------------------------------------------------------- repères (purs)

static func _static_init() -> void:
	configurer(12)


## Le village pour `n` joueurs : n maisons et le temple, sur un cercle assez grand pour que les
## ruelles entre deux maisons gardent la largeur d'avant (1,6 m au ras des façades).
static func configurer(n: int) -> void:
	NB_MAISONS = clampi(n, 1, MAX_MAISONS)
	var places := NB_MAISONS + 2
	PLACES = places
	R_MAISON = maxf(15.0, PROFONDEUR * 0.5 + 6.63 / (2.0 * sin(PI / places)))
	ECART = R_MAISON - 15.0
	# Les souches du Conseil : 2,4 m au moins de l'une à l'autre.
	R_SOUCHES = maxf(4.6, NB_MAISONS * 2.4 / TAU)
	R_PLACE = 11.0 + ECART
	R_CHEMIN_MIN = 18.6 + ECART
	R_CHEMIN_MAX = 23.4 + ECART
	# La forêt est tout près (Edwin, 29/10) : la lisière juste derrière le chemin de ronde ; elle ne
	# recule que pour laisser la place au cimetière (cf. r_lisiere).
	R_LISIERE = R_CHEMIN_MAX + 4.6
	R_LIMITE = R_LISIERE - 1.6
	R_LIEUX = R_CHEMIN_MAX + 6.8
	POS_CHARRETTE = Vector3(R_CHEMIN_MAX + 2.6, 0, -4.0)
	Trajets.configurer(ECART, places)
	Quetes.configurer(ECART, places)
	R_LIMITE_QUETE = Quetes.R_ZONE + 9.0
	PIERRE = centre_temple() + Vector3(0, TEMPLE_HAUT, 0)
	# Rentré dans le vide entre le mur de la dernière maison et celui du temple, au rang des maisons
	# (Edwin, 31/10 : il dépassait sur la place). Mesuré (tests/mesure_tableau.gd) : 1,5 m de passage
	# au moins de chaque côté, de 6 à 14 joueurs, et le chemin de ronde libre derrière.
	var a_tab := -TAU / places - 0.15 / R_MAISON
	TABLEAU = Vector3(sin(a_tab), 0, cos(a_tab)) * R_MAISON
	Terre.R_BUTTES = R_LIMITE_QUETE + 3.0
	_tas.clear()


## Le cercle a deux places de plus que de maisons : la place 0 (vers +z) est celle du temple, la
## dernière celle du tableau des quêtes.
static func angle_maison(i: int) -> float:
	return (i + 1) * TAU / PLACES


static func angle_temple() -> float:
	return 0.0


static func centre_temple() -> Vector3:
	return Vector3(sin(angle_temple()), 0, cos(angle_temple())) * R_MAISON


## Un point vu depuis le temple : x le long de sa façade, z vers le fond (z < 0 : côté place).
## Le temple est à l'angle 0 : son repère est celui du monde, simplement décalé.
static func _au_temple(p: Vector3) -> Vector3:
	return p - centre_temple()


## Sur la terrasse du temple.
static func sur_temple(p: Vector3) -> bool:
	var l := _au_temple(p)
	return absf(l.x) < TEMPLE_LARGE * 0.5 and absf(l.z) < TEMPLE_PROFOND * 0.5


## La hauteur du sol sous ce point : la terrasse du temple, ses marches, sinon la terre battue.
## (Pour les bots, qui marchent sans moteur physique.)
static func hauteur_sol(p: Vector3) -> float:
	var l := _au_temple(p)
	if absf(l.x) < TEMPLE_LARGE * 0.5 and absf(l.z) <= TEMPLE_PROFOND * 0.5:
		return TEMPLE_HAUT
	var bord := -TEMPLE_PROFOND * 0.5
	if absf(l.x) < MARCHES_LARGE * 0.5 and l.z < bord and l.z > bord - MARCHES_LONG:
		return TEMPLE_HAUT * (l.z - (bord - MARCHES_LONG)) / MARCHES_LONG
	return 0.0


## Au pied des marches du temple, sur la place.
static func pied_marches() -> Vector3:
	return centre_temple() + Vector3(0, 0, -TEMPLE_PROFOND * 0.5 - MARCHES_LONG - 0.5)


## En haut des marches, sur la terrasse.
static func haut_marches() -> Vector3:
	return centre_temple() + Vector3(0, TEMPLE_HAUT, -TEMPLE_PROFOND * 0.5 + 0.5)


## À l'autel : sur la terrasse du temple (ou en haut des marches), à `portee` m de la pierre.
## Un loup resté en bas ne vote pas « à la pierre ».
static func a_l_autel(p: Vector3, portee: float) -> bool:
	return hauteur_sol(p) > TEMPLE_HAUT * 0.6 and Vector2(p.x - PIERRE.x, p.z - PIERRE.z).length() < portee


## Une place autour de l'autel, sur la terrasse (là où la meute se retrouve la nuit).
static func autour_autel(a: float) -> Vector3:
	return PIERRE + Vector3(sin(a) * 1.9, 0, cos(a) * 1.35)


## La lisière à cet angle : tout près, sauf là où elle s'écarte pour le cimetière.
static func r_lisiere(a: float) -> float:
	var ecart_cim := absf(wrapf(a - deg_to_rad(LIEUX["cimetiere"]), -PI, PI))
	return R_LISIERE + 9.5 * (1.0 - smoothstep(0.2, 0.42, ecart_cim))


## Le mur invisible du village, à cet angle.
static func r_limite(a: float) -> float:
	return r_lisiere(a) - 1.6


## Ce point est-il hors du village (dans la forêt, vers les quêtes) ?
static func hors_village(p: Vector3, marge := 0.0) -> bool:
	return Vector2(p.x, p.z).length() > r_limite(atan2(p.x, p.z)) - marge


static func centre_maison(i: int) -> Vector3:
	var a := angle_maison(i)
	return Vector3(sin(a), 0, cos(a)) * R_MAISON


## Le sol sous ces pieds : graviers, planches, flaques, feuilles, terre, ou "" (place, maisons).
static func sol_a(pos: Vector3) -> String:
	for t in tas_de_feuilles():
		if Vector2(pos.x - t.x, pos.z - t.z).length() < RAYON_TAS:
			return "feuilles"
	var r := Vector2(pos.x, pos.z).length()
	if r < R_CHEMIN_MIN or r > R_CHEMIN_MAX:
		return ""
	var a := fposmod(atan2(pos.x, pos.z), TAU)
	return SOLS[int(a / (TAU / 24.0)) % 24]


const RAYON_TAS := 1.15
static var _tas: Array[Vector3] = []

## Des tas de feuilles mortes et de brindilles autour de chaque maison : un loup qui marche
## dessus fait du bruit, que les maisons voisines entendent (décision d'Edwin, 29/10).
static func tas_de_feuilles() -> Array[Vector3]:
	if _tas.is_empty():
		var dz := PROFONDEUR * 0.5
		for i in NB_MAISONS:
			var s := 1.0 if i % 2 == 0 else -1.0
			_tas.append(_vers_monde(i, Vector3(s * 1.7, 0, dz + 1.5)))
			_tas.append(_vers_monde(i, Vector3(-s * 1.5, 0, -dz - 1.4)))
			_tas.append(_vers_monde(i, Vector3(s * 1.2, 0, -dz - 2.6)))
	return _tas


## Maison dans laquelle se trouve ce point, ou -1.
static func maison_de(pos: Vector3) -> int:
	for i in NB_MAISONS:
		var local := _vers_local(i, pos)
		if absf(local.x) < LARGEUR * 0.5 - EPAIS * 0.5 and absf(local.z) < PROFONDEUR * 0.5 - EPAIS * 0.5:
			return i
	return -1


## Maison la plus proche de ce point (pour l'Oreille fine).
static func maison_proche(pos: Vector3) -> int:
	var meilleure := 0
	var d := INF
	for i in NB_MAISONS:
		var e := Vector2(pos.x, pos.z).distance_to(Vector2(centre_maison(i).x, centre_maison(i).z))
		if e < d:
			d = e
			meilleure = i
	return meilleure


static func _vers_local(i: int, pos: Vector3) -> Vector3:
	var a := angle_maison(i)
	# Repère de la maison : +z vers le centre du village.
	var base := Basis(Vector3.UP, a + PI)
	return base.inverse() * (pos - centre_maison(i))


static func _vers_monde(i: int, local: Vector3) -> Vector3:
	return centre_maison(i) + Basis(Vector3.UP, angle_maison(i) + PI) * local


## Où repose le carnet de la maison : sur la table, à côté de la bougie.
static func table_carnet(i: int) -> Vector3:
	return _vers_monde(i, Vector3(-1.12, 0.8, -1.0))


## Où dort l'habitant (regard vers sa fenêtre).
static func lit(i: int) -> Vector3:
	return _vers_monde(i, Vector3(-1.2, 0, -0.45))   # (z = -0,9 tombait DANS la table, devenue pleine : tests/test_meubles.gd)


## Assis au bord du lit, tourné vers la pièce (et le regard qui va avec).
static func siege_lit(i: int) -> Vector3:
	return _vers_monde(i, Vector3(1.05, 0, -0.45))


static func regard_lit(i: int) -> Vector3:
	return _vers_monde(i, Vector3(-1.0, 0.9, -0.45))


## Le siège (souche, ou bord du lit le jour) le plus proche, ou [] : [position, regard].
static func siege_proche(pos: Vector3, portee: float, lit_aussi: bool) -> Array:
	var proche := -1
	var d_min := portee
	for i in NB_MAISONS:
		var d := Vector2(pos.x - souche(i).x, pos.z - souche(i).z).length()
		if d < d_min:
			d_min = d
			proche = i
	if proche >= 0:
		return [souche(proche), Vector3(0, 0.9, 0)]
	if lit_aussi:
		var m := maison_de(pos)
		if m >= 0 and Vector2(pos.x - siege_lit(m).x, pos.z - siege_lit(m).z).length() < portee + (0.3 if portee >= 1.0 else 0.0):
			return [siege_lit(m), regard_lit(m)]
	return []


## Où l'on apparaît quand la partie commence : devant sa porte d'entrée, un pas plus loin que le
## perron (Edwin, 31/10 : « chaque joueur spawn devant sa maison »).
static func depart(i: int) -> Vector3:
	return _vers_monde(i, Vector3(0, 0, PROFONDEUR * 0.5 + 2.7))


static func devant_porte(i: int, _quelle := "avant") -> Vector3:
	# Une seule porte par maison (celle de devant) : l'ancien « arriere » désigne la même.
	return _vers_monde(i, Vector3(0, 0, PROFONDEUR * 0.5 + 0.9))


static func souche(i: int) -> Vector3:
	var a := angle_maison(i)
	return Vector3(sin(a), 0, cos(a)) * R_SOUCHES


static func lieu(nom: String) -> Vector3:
	var a := deg_to_rad(LIEUX[nom])
	return Vector3(sin(a), 0, cos(a)) * R_LIEUX


static func petit_lieu(nom: String) -> Vector3:
	var a := deg_to_rad(PETITS_LIEUX[nom])
	return Vector3(sin(a), 0, cos(a)) * R_LIEUX


static func tombe(n: int) -> Vector3:
	var c := lieu("cimetiere")
	var vers_centre := -c.normalized()
	var cote := vers_centre.cross(Vector3.UP)
	return c + cote * (float(n % 4) - 1.5) * 1.6 + vers_centre * (1.0 + float(n / 4) * 1.6)


# ---------------------------------------------------------------- ambiance

## jour (progression 0 → 1 : la lumière baisse), conseil, nuit, aube, salon.
func regler_ambiance(phase: String, progression: float) -> void:
	_phase = phase
	# Au menu, la vraie forêt derrière le village, pas le mur peint (Edwin, 30/10 : « l'image doit
	# être belle ») ; en partie, il cache le dehors.
	if _mur_tenebres:
		_mur_tenebres.visible = phase != "menu"
	if phase == "menu":
		regler_nuit_close(true)
	if roulotte:
		roulotte.visible = phase == "menu"
	var avant := _etat_ambiance()
	if _mat_etoiles:
		_mat_etoiles.set_shader_parameter("force", {"menu": 1.0, "nuit": 0.75}.get(phase, 0.0))
	var p := clampf(progression, 0.0, 1.0)
	match phase:
		"jour", "salon":
			# Même le jour, rien n'est clair : ciel bas et gris-vert, lumière de cave, brume au sol.
			# Quand la nuit approche (q → 1), le ciel tourne au sang séché et la brume monte.
			var q := p if phase == "jour" else 0.15
			var crepuscule := clampf((q - 0.55) / 0.45, 0.0, 1.0)
			_soleil.visible = true
			_soleil_base = lerpf(0.5, 0.18, q)
			_soleil.light_energy = _soleil_base * _facteur_nuages
			_soleil.light_color = Color(0.78, 0.74, 0.62).lerp(Color(0.85, 0.3, 0.18), q)
			_soleil.rotation_degrees = Vector3(lerpf(-30, -6, q), -30, 0)
			_soleil.shadow_blur = 2.5
			_lune.light_energy = 0.0
			_ciel.sky_top_color = Color(0.16, 0.18, 0.19).lerp(Color(0.12, 0.05, 0.08), q)
			_ciel.sky_horizon_color = Color(0.36, 0.37, 0.34).lerp(Color(0.36, 0.1, 0.07), q)
			_ciel.ground_horizon_color = Color(0.2, 0.21, 0.19).lerp(Color(0.12, 0.05, 0.04), q)
			_env.ambient_light_color = Color(0.55, 0.6, 0.55).lerp(Color(0.5, 0.3, 0.3), q)
			_env.ambient_light_energy = lerpf(0.36, 0.16, q)
			_jour_nuageux = 1.0 - crepuscule * 0.6
			_env.fog_density = lerpf(0.022, 0.034, q)
			_env.fog_light_color = Color(0.42, 0.45, 0.41).lerp(Color(0.2, 0.08, 0.07), q)
			_env.fog_height = lerpf(0.4, 1.4, q)
			_env.fog_height_density = lerpf(0.2, 0.35, q)
			_env.adjustment_saturation = lerpf(0.55, 0.45, q)
			_env.adjustment_contrast = lerpf(1.08, 1.2, q)
			_env.volumetric_fog_density = lerpf(0.0, 0.012, crepuscule)
			_env.volumetric_fog_albedo = Color(0.6, 0.6, 0.58).lerp(Color(0.55, 0.25, 0.2), crepuscule)
			_feu_force = lerpf(0.6, 1.6, q)
		"conseil", "election":
			_soleil.visible = true
			_soleil.light_energy = 0.25
			_soleil.light_color = Color(0.9, 0.38, 0.25)
			_soleil.rotation_degrees = Vector3(-6, -30, 0)
			_lune.light_energy = 0.0
			_ciel.sky_top_color = Color(0.14, 0.08, 0.16)
			_ciel.sky_horizon_color = Color(0.5, 0.2, 0.15)
			_env.ambient_light_color = Color(0.5, 0.3, 0.3)
			# Élection du maire : les maisons éclairent un peu plus, pour bien voir les visages (Edwin, 31/10).
			_env.ambient_light_energy = 0.2 if phase == "election" else 0.12
			_env.fog_density = 0.032
			_env.fog_light_color = Color(0.22, 0.1, 0.08)
			_env.fog_height = 1.0
			_env.fog_height_density = 0.3
			_env.adjustment_saturation = 0.45
			_env.adjustment_contrast = 1.2
			_env.volumetric_fog_density = 0.012
			_env.volumetric_fog_albedo = Color(0.55, 0.28, 0.22)
			_feu_force = 2.4
		"nuit":
			_soleil.visible = false
			# La nuit : presque rien. Une lune froide, une brume qui avale tout au-delà de quelques mètres,
			# et les lumières (fenêtres, bougies, braises) qui dessinent des halos dans la brume.
			# `progression` = la vision du loup (0 : villageois, 1 : loup transformé, dehors) : la nuit reste nuit,
			# mais il distingue nettement le village (Edwin, 01/11 : « un loup-garou voit assez bien dehors »).
			_lune.light_energy = lerpf(0.3, 1.0, p)
			_ciel.sky_top_color = Color(0.005, 0.005, 0.012).lerp(Color(0.02, 0.025, 0.06), p)
			_ciel.sky_horizon_color = Color(0.025, 0.025, 0.045).lerp(Color(0.08, 0.08, 0.14), p)
			_ciel.ground_horizon_color = Color(0.01, 0.01, 0.015)
			_env.ambient_light_color = Color(0.4, 0.45, 0.6).lerp(Color(0.45, 0.5, 0.75), p)
			_env.ambient_light_energy = lerpf(0.07, 0.55, p)
			_env.fog_density = lerpf(0.04, 0.012, p)
			_env.fog_light_color = Color(0.03, 0.035, 0.06).lerp(Color(0.08, 0.09, 0.15), p)
			_env.fog_height = 1.0
			_env.fog_height_density = 0.4
			_env.adjustment_saturation = lerpf(0.5, 0.7, p)
			_env.adjustment_contrast = lerpf(1.25, 1.1, p)
			_env.volumetric_fog_density = lerpf(0.015, 0.006, p)
			_env.volumetric_fog_albedo = Color(0.5, 0.55, 0.7)
			_feu_force = 0.25
		"menu":
			# Le village vu de loin pour le menu : la nuit, mais une brume assez légère pour
			# laisser voir les toits sous la lune et les fenêtres allumées.
			# Une carte postale (Edwin, 30/10 : « l'image doit être belle ») : lune franche et bleue,
			# chambres allumées derrière les rideaux, horizon qui se détache du ciel.
			_soleil.visible = false
			_lune.light_energy = 1.25
			_lune.light_color = Color(0.7, 0.78, 1.0)
			_ciel.sky_top_color = Color(0.02, 0.025, 0.06)
			_ciel.sky_horizon_color = Color(0.13, 0.14, 0.22)
			_ciel.ground_horizon_color = Color(0.03, 0.03, 0.045)
			_env.ambient_light_color = Color(0.45, 0.5, 0.7)
			_env.ambient_light_energy = 0.32
			_env.fog_density = 0.009
			_env.fog_light_color = Color(0.06, 0.07, 0.11)
			_env.fog_height = 1.0
			_env.fog_height_density = 0.25
			_env.adjustment_saturation = 0.55
			_env.adjustment_contrast = 1.2
			_env.volumetric_fog_density = 0.006
			_env.volumetric_fog_albedo = Color(0.5, 0.55, 0.7)
			_feu_force = 0.4
		"aube":
			_soleil.visible = true
			_soleil.light_energy = 0.4
			_soleil.light_color = Color(0.75, 0.8, 0.9)
			_soleil.rotation_degrees = Vector3(-10, 150, 0)
			_lune.light_energy = 0.0
			_ciel.sky_top_color = Color(0.45, 0.48, 0.55)
			_ciel.sky_horizon_color = Color(0.82, 0.8, 0.8)
			_env.ambient_light_color = Color(0.55, 0.58, 0.62)
			_env.ambient_light_energy = 0.28
			_env.fog_density = 0.035
			_env.fog_light_color = Color(0.5, 0.52, 0.56)
			_env.fog_height = 0.6
			_env.fog_height_density = 0.3
			_env.adjustment_saturation = 0.45
			_env.adjustment_contrast = 1.1
			_env.volumetric_fog_density = 0.004
			_env.volumetric_fog_albedo = Color(0.8, 0.82, 0.86)
			_feu_force = 0.15
	# Le temps tourne doucement (Edwin, 31/10 : « la météo change net ») : on glisse vers la cible,
	# ~95 % du chemin en 30 s. Seuls le menu et la première image d'un village neuf sautent.
	var cible := _etat_ambiance()
	var maintenant := Time.get_ticks_msec() / 1000.0
	var dernier := _amb_t if _amb_t >= 0.0 else maintenant
	if _amb_t >= 0.0 and phase != "menu" and _amb_phase != "menu":
		var k := 1.0 - exp(-clampf(maintenant - _amb_t, 0.0, 0.5) / FONDU_AMBIANCE)
		for n in cible.size():
			cible[n] = lerp(avant[n], cible[n], k)
	_amb_t = maintenant
	_amb_phase = phase
	_poser_ambiance(cible)
	if phase not in ["jour", "salon"]:
		_jour_nuageux = 0.35 if phase in ["conseil", "election", "aube"] else 0.0
	var nuit := phase == "nuit"
	# La lueur des maisons suit la phase en douceur : plus forte au Conseil d'ÉLECTION, inchangée
	# (faible) au Conseil d'élimination.
	_lueur_maisons = move_toward(_lueur_maisons, 1.0 if phase == "election" else 0.0, clampf(maintenant - dernier, 0.0, 0.5) / 4.0)
	for i in _fenetres.size():
		_fenetres[i].emission_energy_multiplier = 0.0 if maisons_eteintes.has(i) else (1.4 if nuit else (0.35 + 1.6 * _lueur_maisons if phase in ["conseil", "election"] else 0.0))
	if not _nuit_close:
		for l in _lampes:
			l.light_energy = 1.3 * _lueur_maisons
	var allumees := nuit or phase == "aube"
	for b in _bougies:
		var morte := maisons_eteintes.has(_maison_de_lumiere(b))
		b.visible = allumees and not morte and not b.has_meta("soufflee") and not b.has_meta("eteinte_main")
		if b.has_meta("flamme"):
			(b.get_meta("flamme") as Node3D).visible = not morte and not b.has_meta("soufflee")
	for i in _flamme_chambre:
		(_flamme_chambre[i] as Node3D).visible = not maisons_eteintes.has(i) and not (_bougie_chambre[i] as Node).has_meta("eteinte_main")
	_astre_lune.visible = nuit
	# Une lumière éteinte (énergie 0) calcule quand même ses ombres : la lune du jour redessinait
	# tout le village pour rien.
	_lune.visible = _lune.light_energy > 0.01
	_soleil.visible = _soleil.light_energy > 0.01


const FONDU_AMBIANCE := 10.0   # constante de temps du fondu d'ambiance (s)
var _amb_t := -1.0
var _lueur_maisons := 0.0   # 0 : lueur faible (Conseil d'élimination), 1 : maisons plus claires (élection)
var _amb_phase := ""


## Tout ce que l'ambiance règle, dans un ordre fixe (cf. _poser_ambiance). Un astre caché vaut 0.
func _etat_ambiance() -> Array:
	return [_soleil.light_energy if _soleil.visible else 0.0, _soleil.light_color, _soleil.rotation_degrees,
		_lune.light_energy if _lune.visible or _lune.light_energy > 0.0 else 0.0,
		_ciel.sky_top_color, _ciel.sky_horizon_color, _ciel.ground_horizon_color,
		_env.ambient_light_color, _env.ambient_light_energy, _env.fog_density, _env.fog_light_color,
		_env.fog_height, _env.fog_height_density, _env.adjustment_saturation, _env.adjustment_contrast,
		_env.volumetric_fog_density, _env.volumetric_fog_albedo, _feu_force,
		_force_etoiles()]


func _force_etoiles() -> float:
	var f: Variant = _mat_etoiles.get_shader_parameter("force") if _mat_etoiles else null
	return float(f) if f != null else 0.0


func _poser_ambiance(v: Array) -> void:
	_soleil.light_energy = v[0]
	_soleil.visible = v[0] > 0.01
	_soleil.light_color = v[1]
	_soleil.rotation_degrees = v[2]
	_lune.light_energy = v[3]
	_ciel.sky_top_color = v[4]
	_ciel.sky_horizon_color = v[5]
	_ciel.ground_horizon_color = v[6]
	_env.ambient_light_color = v[7]
	_env.ambient_light_energy = v[8]
	_env.fog_density = v[9]
	_env.fog_light_color = v[10]
	_env.fog_height = v[11]
	_env.fog_height_density = v[12]
	_env.adjustment_saturation = v[13]
	_env.adjustment_contrast = v[14]
	_env.volumetric_fog_density = v[15]
	_env.volumetric_fog_albedo = v[16]
	_feu_force = v[17]
	if _mat_etoiles:
		_mat_etoiles.set_shader_parameter("force", v[18])
		_etoiles.visible = v[18] > 0.01


## Les loups voient la lune rouge.
func regler_brume(oui: bool) -> void:
	brume_volumetrique = oui
	if _env:
		_env.volumetric_fog_enabled = oui


func lune_rouge(oui: bool) -> void:
	_mat_lune.albedo_color = Color(0.85, 0.12, 0.08) if oui else Color(0.9, 0.9, 0.82)
	_mat_lune.emission = Color(0.9, 0.08, 0.05) if oui else Color(0.85, 0.85, 0.75)
	_lune.light_color = Color(0.9, 0.35, 0.3) if oui else Color(0.55, 0.62, 0.85)


## La pierre des statues : la roche moussue de Poly Haven, posée en triplanaire.
func _pierre_moussue() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/mossy_rock_diff.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://textures/mossy_rock_nor.jpg")
	m.roughness_texture = load("res://textures/mossy_rock_rough.jpg")
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 1.6
	m.albedo_color = Color(0.62, 0.6, 0.58)
	return m


func _forme(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, echelle := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = echelle
	parent.add_child(mi)
	return mi


func _ovoide(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 10
	return s


func _tronc_cone(r_haut: float, r_bas: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_haut
	c.bottom_radius = r_bas
	c.height = h
	c.radial_segments = 10
	return c


## Un loup de pierre couché, le dos à hauteur du dessous de la dalle, la tête levée vers le ciel.
## `cap` : où regarde sa gueule.
func _loup_de_pierre(pos: Vector3, cap: float, mat: Material) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = cap
	_sur.add_child(n)
	# Le corps couché, massif (le socle se confond avec lui).
	_forme(n, _ovoide(0.3), mat, Vector3(0, 0.3, -0.1), Vector3.ZERO, Vector3(0.82, 0.95, 1.2))
	_forme(n, _tronc_cone(0.24, 0.3, 0.12), mat, Vector3(0, 0.06, -0.1))
	# Le poitrail et le cou, dressés.
	_forme(n, _ovoide(0.17), mat, Vector3(0, 0.46, 0.2), Vector3(-0.5, 0, 0), Vector3(1.0, 1.35, 1.0))
	# La tête, tournée vers le haut : crâne, museau, mâchoire ouverte, oreilles.
	var tete := Node3D.new()
	tete.position = Vector3(0, 0.66, 0.34)
	tete.rotation.x = -0.75
	n.add_child(tete)
	_forme(tete, _ovoide(0.12), mat, Vector3.ZERO, Vector3.ZERO, Vector3(0.95, 0.9, 1.1))
	_forme(tete, _tronc_cone(0.04, 0.075, 0.24), mat, Vector3(0, -0.01, 0.19), Vector3(PI * 0.5, 0, 0))
	_forme(tete, _tronc_cone(0.035, 0.06, 0.17), mat, Vector3(0, -0.06, 0.14), Vector3(PI * 0.5 + 0.28, 0, 0))
	for c: int in [-1, 1]:
		_forme(tete, _tronc_cone(0.0, 0.065, 0.17), mat, Vector3(c * 0.07, 0.13, -0.03), Vector3(-0.25, 0, -c * 0.28))
		# Deux yeux creusés : une ombre noire au fond.
		_forme(tete, _ovoide(0.018), Bouille.materiau(Color(0.02, 0.02, 0.02), 0.0), Vector3(c * 0.05, 0.035, 0.09))
		# Les pattes avant, allongées devant lui.
		_forme(n, _tronc_cone(0.055, 0.065, 0.42), mat, Vector3(c * 0.12, 0.07, 0.3), Vector3(PI * 0.5, 0, 0))
		_forme(n, _ovoide(0.07), mat, Vector3(c * 0.12, 0.05, 0.52), Vector3.ZERO, Vector3(1, 0.6, 1.3))
	# La queue, enroulée sur le flanc.
	_forme(n, _tronc_cone(0.03, 0.06, 0.45), mat, Vector3(0.22, 0.1, -0.42), Vector3(PI * 0.5, 0.9, 0))
	_obstacle(_sur, Ronde.boite(Vector3(0.5, 0.6, 0.7)), pos + Vector3(0, 0.3, 0))


## Un cercle de runes gravées dans les pavés, autour de l'autel : un sillon noir, et seize signes.
func _cercle_de_runes() -> void:
	var noir := Bouille.materiau(Color(0.05, 0.03, 0.03), 0.0)
	var sang := Bouille.materiau(Color(0.2, 0.02, 0.02), 0.0)
	var anneau := TorusMesh.new()
	anneau.inner_radius = 1.48
	anneau.outer_radius = 1.53
	anneau.rings = 64
	_forme(_sur, anneau, noir, Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1, 0.05, 1))
	var anneau2 := TorusMesh.new()
	anneau2.inner_radius = 1.2
	anneau2.outer_radius = 1.24
	anneau2.rings = 64
	_forme(_sur, anneau2, noir, Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1, 0.05, 1))
	# Chaque rune : un jambage et deux ou trois traits obliques, comme taillés au ciseau.
	var traits := [[[0.0, 0.0, 0.0], [0.06, 0.03, 0.8], [0.06, -0.03, -0.8]],
		[[0.0, 0.0, 0.0], [-0.05, 0.04, 0.7], [0.05, 0.04, -0.7]],
		[[0.0, 0.0, 0.0], [0.05, 0.0, 1.57], [0.07, -0.05, 0.7]],
		[[0.0, 0.0, 0.0], [0.04, 0.05, -0.9], [0.04, -0.01, -0.9], [0.04, -0.07, -0.9]]]
	var barre := BoxMesh.new()
	barre.size = Vector3(0.025, 0.012, 0.18)
	for k in 16:
		var a := k * TAU / 16.0
		var c := Vector3(sin(a), 0, cos(a)) * 1.365
		var rune := Node3D.new()
		rune.position = c + Vector3(0, 0.004, 0)
		rune.rotation.y = a
		_sur.add_child(rune)
		for t: Array in traits[k % traits.size()]:
			_forme(rune, barre, sang if k % 4 == 0 else noir, Vector3(t[0], 0, t[1]), Vector3(0, t[2], 0))


## Des crânes de loup et des os, posés sur les pierres du cercle et dans l'herbe.
func _ossements() -> void:
	var os_ := Bouille.materiau(Color(0.78, 0.74, 0.62), 0.0)
	var creux := Bouille.materiau(Color(0.04, 0.03, 0.03), 0.0)
	for k in 5:
		var a := k * TAU / 5.0 + 0.4 + _rng.randf_range(-0.15, 0.15)
		var crane := Node3D.new()
		crane.position = Vector3(sin(a), 0, cos(a)) * _rng.randf_range(1.75, 2.0) + Vector3(0, 0.05, 0)
		crane.rotation.y = a + PI + _rng.randf_range(-0.5, 0.5)
		add_child(crane)
		_forme(crane, _ovoide(0.07), os_, Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(0.9, 0.75, 1.15))
		_forme(crane, _tronc_cone(0.025, 0.045, 0.14), os_, Vector3(0, 0.035, 0.11), Vector3(PI * 0.5, 0, 0))
		_forme(crane, _tronc_cone(0.018, 0.032, 0.12), os_, Vector3(0, 0.0, 0.1), Vector3(PI * 0.5 + 0.12, 0, 0))
		for c: int in [-1, 1]:
			_forme(crane, _ovoide(0.02), creux, Vector3(c * 0.035, 0.07, 0.05))
			_forme(crane, _tronc_cone(0.0, 0.008, 0.05), os_, Vector3(c * 0.025, 0.0, 0.15), Vector3(PI, 0, 0))
	var long_os := _tronc_cone(0.012, 0.012, 0.28)
	var bout := _ovoide(0.022)
	for k in 12:
		var a := _rng.randf() * TAU
		var o := Node3D.new()
		o.position = Vector3(sin(a), 0.02, cos(a)) * _rng.randf_range(1.3, 2.3) + Vector3(0, 0.015, 0)
		o.rotation = Vector3(PI * 0.5, _rng.randf() * TAU, 0)
		add_child(o)
		_forme(o, long_os, os_, Vector3.ZERO)
		_forme(o, bout, os_, Vector3(0, 0.14, 0))
		_forme(o, bout, os_, Vector3(0, -0.14, 0))


## Une chaîne qui pend d'un anneau : maillons ovales, chacun tourné d'un quart de tour sur le
## précédent ; deux articulations (haut, milieu) pour qu'elle ondule au vent.
func _chaine(attache: Vector3, mat: Material) -> void:
	if _maillon == null:
		_maillon = TorusMesh.new()
		_maillon.inner_radius = 0.014
		_maillon.outer_radius = 0.026
		_maillon.rings = 10
		_maillon.ring_segments = 6
	var haut := Node3D.new()
	haut.position = attache
	_sur.add_child(haut)
	var bas := Node3D.new()
	haut.add_child(bas)
	var pas := 0.052
	for m in 12:
		var maillon := MeshInstance3D.new()
		maillon.mesh = _maillon
		maillon.material_override = mat
		var b := Basis(Vector3.UP, (m % 2) * PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1, 1, 1.55))
		var y := -0.03 - m * pas
		if m < 6:
			maillon.transform = Transform3D(b, Vector3(0, y, 0))
			haut.add_child(maillon)
		else:
			maillon.transform = Transform3D(b, Vector3(0, y + 6 * pas + 0.03, 0))
			bas.add_child(maillon)
	bas.position.y = -0.03 - 6 * pas
	_chaines.append([haut, bas, _rng.randf() * TAU])


func _animer_chaines() -> void:
	for c: Array in _chaines:
		var ph: float = c[2]
		# Un vent irrégulier : une houle lente et des rafales courtes.
		var vent := sin(_t * 0.9 + ph) * 0.07 + sin(_t * 2.6 + ph * 1.7) * 0.025 * maxf(0.0, sin(_t * 0.31 + ph))
		(c[0] as Node3D).rotation = Vector3(vent * 0.6, 0, vent)
		(c[1] as Node3D).rotation = Vector3(sin(_t * 0.9 + ph - 0.8) * 0.04, 0, sin(_t * 0.9 + ph - 0.7) * 0.08)


func _process(delta: float) -> void:
	_animer_portails(delta)
	_animer_chaines()
	_t += delta
	var vacille := 0.85 + 0.15 * sin(_t * 13.0) * sin(_t * 7.3 + 1.0)
	_feu.light_energy = _feu_force * vacille
	_braises.emission_energy_multiplier = 1.5 + _feu_force * vacille
	for k in _torches.size():
		_torches[k].light_energy = (0.5 + _feu_force * 0.5) * (0.8 + 0.2 * sin(_t * 17.0 + k * 2.1) * sin(_t * 5.3 + k))
	_maj_nuages(delta)
	for i in _bougies.size():
		_bougies[i].light_energy = float(_bougies[i].get_meta("base", 0.55)) * (0.8 + 0.2 * sin(_t * 11.0 + i * 1.7))
	if _ailes_moulin:
		_ailes_moulin.rotate_z(delta * 0.12)
	for c in _cordes:
		c.rotation.z = sin(_t * 0.7 + float(c.get_meta("decalage"))) * 0.06
	for c in _corbeaux:
		if c.has_meta("vol"):
			continue
		var k := sin(_t * 1.3 + c.get_meta("decalage"))
		c.rotation.y = c.get_meta("cap") + k * 0.6
		c.position.y = c.get_meta("y") + maxf(0.0, sin(_t * 2.1 + c.get_meta("decalage") * 3.0)) * 0.12


# ---------------------------------------------------------------- portes

func porte_ouverte(i: int, quelle: String) -> bool:
	return _portes.get("%d:%s" % [i, quelle], {}).get("ouverte", false)


## Une porte d'une maison que cette Ronde n'a pas encore (l'hôte règle les portes du village à 16
## juste avant qu'on ne le rebâtisse) : ignorée, la reconstruction reprend l'état des portes.
func regler_porte(i: int, quelle: String, ouverte: bool) -> void:
	var cle := "%d:%s" % [i, quelle]
	if not _portes.has(cle):
		return
	var p: Dictionary = _portes[cle]
	p["ouverte"] = ouverte
	var tw := create_tween()
	tw.tween_property(p["pivot"], "rotation:y", deg_to_rad(PORTE_OUVERTE_DEG) if ouverte else 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	# Ouverte, la porte reste un obstacle (Edwin, 31/10 : on la traversait) : sa forme tourne avec le
	# gond et se range le long du mur intérieur.


func fermer_tout() -> void:
	for i in NB_MAISONS:
		if porte_ouverte(i, "avant"):
			regler_porte(i, "avant", false)


## La porte (et laquelle) devant laquelle se tient ce point, à moins de `portee` mètres.
func porte_proche(pos: Vector3, portee := 1.8) -> Array:
	for i in NB_MAISONS:
		var seuil := _vers_monde(i, Vector3(0, 0, PROFONDEUR * 0.5))
		if Vector2(pos.x, pos.z).distance_to(Vector2(seuil.x, seuil.z)) < portee:
			return [i, "avant"]
	return []


## Planches clouées sur les fenêtres d'un mort.
## La pierre garde la trace du sacrifice jusqu'à la nuit suivante.
func tacher(oui: bool) -> void:
	_tache.visible = oui


var _liens: Node3D = null
## Où se bâtit l'autel : le temple (cf. _temple) ; ailleurs, la Ronde elle-même.
var _sur: Node3D = null
var _autel: Node3D = null


## Une chaîne de part en part de la dalle, bombée par-dessus le corps (u : 0 → 1, de z- à z+).
static func _lien_point(x: float, u: float) -> Vector3:
	return Vector3(x, PIERRE_HAUT - 0.14 + sin(u * PI) * 0.4 * smoothstep(0.0, 0.25, u) * smoothstep(1.0, 0.75, u) + 0.0, lerpf(-0.6, 0.6, u))

## Le condamné du Conseil est enchaîné sur la dalle : trois chaînes passent par-dessus son corps
## (poitrine, hanches, chevilles) et retombent de chaque côté de la pierre.
func attacher(oui: bool) -> void:
	if _liens == null:
		if not oui:
			return
		_liens = Node3D.new()
		_autel.add_child(_liens)
		var rouille := StandardMaterial3D.new()
		rouille.albedo_color = Color(0.3, 0.2, 0.15)
		rouille.metallic = 0.75
		rouille.roughness = 0.6
		if _maillon == null:
			_chaine(Vector3(0, -50, 0), rouille)   # crée le maillon partagé (chaîne cachée sous terre)
		for x: float in [-0.68, -0.18, 0.3]:
			var n := 44
			for m in n:
				var u := float(m) / float(n - 1)          # d'un bord de la dalle à l'autre
				var ou := _lien_point(x, u)
				var t := (_lien_point(x, minf(u + 0.01, 1.0)) - _lien_point(x, maxf(u - 0.01, 0.0))).normalized()
				# Chaque maillon dans l'axe de la chaîne, tourné d'un quart de tour sur le précédent.
				var axe := Vector3.RIGHT if m % 2 == 0 else Vector3(0, -t.z, t.y)
				var b := Basis(axe.cross(t), axe, t) * Basis.from_scale(Vector3(1, 1, 1.55))
				var maillon := MeshInstance3D.new()
				maillon.mesh = _maillon
				maillon.material_override = rouille
				maillon.transform = Transform3D(b, ou)
				_liens.add_child(maillon)
	_liens.visible = oui


## Deux pans d'étoffe devant chaque fenêtre, à l'intérieur. Fermés la nuit, ouverts le jour.
func _poser_rideaux(i: int, penche: Node3D, fens: Array) -> void:
	var l: Array = []
	var toile := StandardMaterial3D.new()
	toile.albedo_color = [Color(0.42, 0.12, 0.1), Color(0.35, 0.3, 0.18), Color(0.2, 0.22, 0.3)][i % 3]
	toile.roughness = 1.0
	toile.emission_enabled = true
	toile.emission = Color(1.0, 0.6, 0.3)
	toile.emission_energy_multiplier = 0.0
	toile.cull_mode = BaseMaterial3D.CULL_DISABLED
	for f: Array in fens:
		var dedans: Vector3 = f[1]
		var larg: float = f[2]
		var support := Node3D.new()
		support.position = (f[0] as Vector3) + dedans * (0.42 if larg < 1.2 else 0.52) + Vector3(0, 1.62, 0)
		support.rotation.y = atan2(dedans.x, dedans.z)
		penche.add_child(support)
		var pans := []
		for c: int in [-1, 1]:
			var pan := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(larg * 0.5 + 0.05, 1.45, 0.025)
			pan.mesh = b
			pan.material_override = toile
			pan.set_meta("ferme_x", c * larg * 0.25)
			# Ouvert, le pan reste dans la pièce : il entrait dans l'épaisseur du mur latéral et sa tranche
			# rouge se voyait de dehors, en fine fente (Edwin, 01/11).
			var ox := larg * 0.5 + 0.02
			var moitie := (larg * 0.5 + 0.05) * 0.3 * 0.5
			var bas := Basis(Vector3.UP, support.rotation.y)
			var bout := support.position + bas.x * c * (ox + moitie)
			ox -= maxf(maxf(absf(bout.x) - 1.97, absf(bout.z) - 1.74), 0.0)
			pan.set_meta("ouvert_x", c * ox)
			pan.position.x = pan.get_meta("ouvert_x")
			pan.scale.x = 0.3
			support.add_child(pan)
			pans.append(pan)
		support.set_meta("toile", toile)
		l.append(pans)
	_rideaux[i] = l


## La nuit : tous les rideaux tirés, toutes les chambres allumées ; le jour, l'inverse.
func regler_nuit_close(oui: bool) -> void:
	_nuit_close = oui
	for i in _rideaux:
		for pans: Array in _rideaux[i]:
			for pan: MeshInstance3D in pans:
				pan.position.x = pan.get_meta("ferme_x") if oui else pan.get_meta("ouvert_x")
				pan.scale.x = 1.0 if oui else 0.3
				(pan.material_override as StandardMaterial3D).emission_energy_multiplier = 0.35 if oui else 0.0
	for l in _lampes:
		l.light_energy = 0.9 if oui else 0.0


## La Guetteuse écarte un pan du rideau de sa façade (cote -1 ou 1), doucement (0 → 1).
func entrouvrir_rideau(i: int, cote: int, ouverture: float) -> void:
	if not _rideaux.has(i) or not _nuit_close:
		return
	var pans: Array = _rideaux[i][0 if cote < 0 else 1]
	var pan: MeshInstance3D = pans[1]
	var f: float = pan.get_meta("ferme_x")
	pan.position.x = lerpf(f, f + 0.42, ouverture)
	pan.scale.x = lerpf(1.0, 0.45, ouverture)


## Souffler ou rallumer la bougie de sa chambre (seulement chez soi).
func basculer_bougie(i: int) -> bool:
	if not _bougie_chambre.has(i):
		return false
	# Une marque, pas `visible` : regler_ambiance repasse sur toutes les bougies à chaque image.
	var l: OmniLight3D = _bougie_chambre[i]
	if l.has_meta("eteinte_main"):
		l.remove_meta("eteinte_main")
	else:
		l.set_meta("eteinte_main", true)
	return not l.has_meta("eteinte_main")


## La maison qui porte cette lumière (-1 : dehors). Calculé une fois par lumière.
func _maison_de_lumiere(l: Node) -> int:
	if _maison_lumiere.has(l):
		return _maison_lumiere[l]
	var r := -1
	for i in _maisons.size():
		if _maisons[i].is_ancestor_of(l):
			r = i
			break
	_maison_lumiere[l] = r
	return r


## La nuit, un loup voit les numéros autrement : rouges les villageois, bleus ses alliés, verte
## la sienne. `couleurs` vide : on revient aux numéros de tout le monde.
func colorer_chiffres(couleurs: Dictionary) -> void:
	for m in _chiffres:
		var c: Color = couleurs.get(m, Color(0.42, 0.95, 0.4) if m == _ma_maison else Color(0.78, 0.7, 0.58))
		for l: Label3D in _chiffres[m]:
			l.modulate = c
			l.outline_modulate = c.darkened(0.88)


## Les tas de feuilles : un lit de feuilles mortes et quelques branches sèches, bien visibles.
func _tas_de_feuilles() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.12)
	q.orientation = PlaneMesh.FACE_Y
	mm.mesh = q
	var tas := Ronde.tas_de_feuilles()
	var par := 70
	mm.instance_count = tas.size() * par
	var branches := []
	var k := 0
	for t in tas:
		for n in par:
			var a := _rng.randf() * TAU
			var d := sqrt(_rng.randf()) * RAYON_TAS
			var p := t + Vector3(sin(a) * d, 0.03 + _rng.randf() * 0.04, cos(a) * d)
			var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.4, 0.4))
			mm.set_instance_transform(k, Transform3D(b.scaled(Vector3.ONE * _rng.randf_range(0.8, 1.5)), p))
			mm.set_instance_color(k, Color(0.55, 0.3, 0.1).lerp(Color(0.32, 0.2, 0.1), _rng.randf()).lerp(Color(0.6, 0.45, 0.15), _rng.randf() * 0.4))
			k += 1
		for n in 3:
			var a := _rng.randf() * TAU
			branches.append([t + Vector3(sin(a), 0, cos(a)) * _rng.randf() * 0.7, _rng.randf_range(0.5, 0.8), _rng.randf() * TAU])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	Terre.semer(self, "dry_branches_medium_01", branches)


## Un brasero : un chaudron de fer sur trois pieds, des bûches, et un vrai feu de particules.
func _brasero(base: Vector3, fer: Material) -> void:
	var n := Node3D.new()
	n.position = base
	add_child(n)
	for k in 3:
		var a := k * TAU / 3.0 + 0.3
		var pied := MeshInstance3D.new()
		var cp := CylinderMesh.new()
		cp.top_radius = 0.025
		cp.bottom_radius = 0.03
		cp.height = 0.95
		pied.mesh = cp
		pied.material_override = fer
		pied.position = Vector3(sin(a) * 0.24, 0.44, cos(a) * 0.24)
		pied.rotation = Vector3(cos(a) * 0.22, 0, -sin(a) * 0.22)
		n.add_child(pied)
	var bol := MeshInstance3D.new()
	var cb := CylinderMesh.new()
	cb.top_radius = 0.42
	cb.bottom_radius = 0.2
	cb.height = 0.3
	cb.cap_top = false
	bol.mesh = cb
	bol.material_override = fer
	bol.position.y = 0.98
	n.add_child(bol)
	var rebord := MeshInstance3D.new()
	var tr := TorusMesh.new()
	tr.inner_radius = 0.39
	tr.outer_radius = 0.45
	rebord.mesh = tr
	rebord.material_override = fer
	rebord.position.y = 1.13
	n.add_child(rebord)
	var ecorce := _mat_ecorce()
	for k in 4:
		var buche := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.05
		cy.bottom_radius = 0.06
		cy.height = 0.46
		buche.mesh = cy
		buche.material_override = ecorce
		buche.position = Vector3(0, 1.12, 0)
		buche.rotation = Vector3(PI * 0.5 - 0.5, k * PI * 0.5 + 0.4, 0)
		n.add_child(buche)
	var braise := Bouille.sphere(0.3, _braises, Vector3(1, 0.25, 1))
	braise.position.y = 1.08
	n.add_child(braise)
	# Le feu : un cœur de flammes hautes, des braises qui montent, une fumée lente.
	var flammes := DecorQuete._particules(40, 0.75, Vector3(0.18, 0.04, 0.18), Vector3(0, 1.0, 0), 0.34,
		DecorQuete._degrade([Color(0.9, 0.5, 0.15, 0.0), Color(0.95, 0.55, 0.15, 0.55), Color(0.85, 0.25, 0.05, 0.4), Color(0.4, 0.05, 0.02, 0.0)]), true)
	flammes.position.y = 1.15
	n.add_child(flammes)
	var etincelles := DecorQuete._particules(28, 2.2, Vector3(0.25, 0.1, 0.25), Vector3(0.1, 1.9, 0.05), 0.05,
		DecorQuete._degrade([Color(1.0, 0.7, 0.3, 0.0), Color(1.0, 0.6, 0.2, 1.0), Color(0.9, 0.25, 0.05, 0.0)]), true)
	etincelles.position.y = 1.3
	n.add_child(etincelles)
	var fumee := DecorQuete._particules(22, 4.0, Vector3(0.2, 0.05, 0.2), Vector3(0.15, 0.8, 0), 1.1,
		DecorQuete._degrade([Color(0.15, 0.14, 0.14, 0.0), Color(0.12, 0.12, 0.13, 0.35), Color(0.2, 0.2, 0.21, 0.0)]), false)
	fumee.position.y = 2.1
	n.add_child(fumee)
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(1.0, 0.5, 0.2)
	lueur.omni_range = 7.0
	lueur.position = Vector3(0, 1.6, 0)
	n.add_child(lueur)
	_torches.append(lueur)
	_obstacle(self, Ronde.cylindre(0.45, 1.2), base + Vector3(0, 0.6, 0))


## Du sang sur les pavés, jamais deux fois le même : flaques, éclaboussures, traînées (décalques au sol).
func _sang_et_mots() -> void:
	var formes: Array[ImageTexture] = []
	for k in 6:
		formes.append(_tache_de_sang(k))
	var couleurs := [Color(0.62, 0.03, 0.02), Color(0.48, 0.04, 0.03), Color(0.34, 0.05, 0.03), Color(0.24, 0.06, 0.04)]
	var poses := 0
	var essais := 0
	while poses < 46 and essais < 400:
		essais += 1
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(2.4, R_CHEMIN_MIN - 1.0)
		var p := Vector3(sin(a) * d, 0, cos(a) * d)
		if maison_de(p) >= 0 or absf(d - R_SOUCHES) < 0.6:
			continue
		var k := _rng.randi_range(0, formes.size() - 1)
		var long := k >= 4                  # les traînées : allongées
		var t := _rng.randf_range(0.8, 1.9)
		_decalque(p, formes[k], Vector2(t * (0.55 if long else 1.0), t * (2.2 if long else 1.0)), _rng.randf() * TAU,
			couleurs[_rng.randi_range(0, couleurs.size() - 1)])
		poses += 1
	# Au pied de l'autel, ce qui a coulé de la dalle.
	for k in 4:
		var a := _rng.randf() * TAU
		_decalque(Vector3(sin(a) * 1.15, 0, cos(a) * 0.75), formes[_rng.randi_range(0, 3)], Vector2.ONE * _rng.randf_range(0.5, 0.9),
			_rng.randf() * TAU, couleurs[_rng.randi_range(0, 1)])
	# Plus aucun mot écrit dans le sang (Edwin, 31/10) : ils couvraient les numéros des maisons et
	# barraient les passages.


func _decalque(p: Vector3, tex: Texture2D, taille: Vector2, angle: float, c: Color) -> void:
	var dc := Decal.new()
	dc.texture_albedo = tex
	dc.size = Vector3(taille.x, 0.3, taille.y)
	dc.modulate = c
	dc.albedo_mix = 0.92
	dc.position = p
	dc.rotation.y = angle
	dc.upper_fade = 0.1
	dc.lower_fade = 0.1
	dc.cull_mask = 1
	add_child(dc)


func _decalque_mur(p: Vector3, dehors: Vector3, tex: Texture2D, c: Color) -> void:
	var dc := Decal.new()
	dc.texture_albedo = tex
	dc.size = Vector3(0.45, 0.4, 1.3)
	dc.modulate = c
	dc.albedo_mix = 0.9
	add_child(dc)
	# Un décalque projette le long de son -Y : on le couche face au mur, la traînée qui coule.
	var y := dehors
	var z := Vector3.UP
	dc.global_transform = Transform3D(Basis(y.cross(z).normalized(), y, z), p)


## Une tache de sang dessinée à la main : `k` 0-1 flaque, 2-3 éclaboussure, 4-5 traînée.
func _tache_de_sang(k: int) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var bruit := FastNoiseLite.new()
	bruit.seed = 91 + k * 13
	bruit.frequency = 0.045
	var fin := FastNoiseLite.new()
	fin.seed = 7 + k
	fin.frequency = 0.16
	for y in n:
		for x in n:
			var u := (x - n * 0.5) / (n * 0.5)
			var v := (y - n * 0.5) / (n * 0.5)
			var r: float
			if k >= 4:
				r = Vector2(u * 1.8, v * 0.55 + (0.25 if v > 0 else 0.0) * v).length()   # traînée
			else:
				r = Vector2(u, v).length()
			var seuil := (0.5 if k < 2 else 0.32) + bruit.get_noise_2d(x, y) * 0.32 + fin.get_noise_2d(x, y) * 0.06
			var a := clampf((seuil - r) * 14.0, 0.0, 1.0)
			# Le bord sèche plus sombre, le cœur reste plus épais.
			var coeur := clampf((seuil - r) * 3.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.75 + 0.25 * coeur, 0.75 + 0.25 * coeur, 0.75 + 0.25 * coeur, a))
	# Les gouttes : autour d'une éclaboussure, le long d'une traînée.
	var gouttes := 26 if k in [2, 3] else (14 if k >= 4 else 6)
	var rr := RandomNumberGenerator.new()
	rr.seed = 300 + k
	for g in gouttes:
		var ang := rr.randf() * TAU
		var dist := rr.randf_range(0.35, 0.92) * n * 0.5
		var cx := n * 0.5 + sin(ang) * dist * (0.4 if k >= 4 else 1.0)
		var cy := n * 0.5 + cos(ang) * dist
		var rad := rr.randf_range(1.2, 4.5) * (1.0 - dist / n)
		for y in range(maxi(0, int(cy - rad - 1)), mini(n, int(cy + rad + 2))):
			for x in range(maxi(0, int(cx - rad - 1)), mini(n, int(cx + rad + 2))):
				var a := clampf(rad - Vector2(x - cx, y - cy).length(), 0.0, 1.0)
				if a > img.get_pixel(x, y).a:
					img.set_pixel(x, y, Color(0.85, 0.85, 0.85, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Le numéro de MA maison s'écrit en vert (décision d'Edwin, 29/10) ; les autres restent gravés.
func marquer_ma_maison(i: int) -> void:
	if i == _ma_maison:
		return
	_ma_maison = i
	for m in _chiffres:
		for l: Label3D in _chiffres[m]:
			l.modulate = Color(0.42, 0.95, 0.4) if m == i else Color(0.78, 0.7, 0.58)
			l.outline_modulate = Color(0.02, 0.12, 0.03) if m == i else Color(0.08, 0.05, 0.04)


## Une fenêtre de façade (cote -1 : gauche, 1 : droite), vue de dehors : [centre de la vitre, normale].
static func fenetre(i: int, cote: int) -> Array:
	var c := _vers_monde(i, Vector3(cote * 1.75, 1.62, PROFONDEUR * 0.5))
	var dehors := _vers_monde(i, Vector3(cote * 1.75, 1.62, PROFONDEUR * 0.5 + 1.0)) - c
	return [c, dehors.normalized()]


## Une porte fermée s'entrouvre seule, grince… et se referme d'un coup. Rien ne bouge pour les
## autres : la collision ne change pas (frisson local, cf. Frissons).
func entrouvrir(i: int, quelle: String) -> bool:
	var cle := "%d:%s" % [i, quelle]
	if not _portes.has(cle) or _portes[cle]["ouverte"]:
		return false
	var pivot: Node3D = _portes[cle]["pivot"]
	var tw := create_tween()
	tw.tween_property(pivot, "rotation:y", deg_to_rad(24.0), 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(1.8)
	tw.tween_callback(func():
		if not _portes[cle]["ouverte"]:
			var t2 := create_tween()
			t2.tween_property(pivot, "rotation:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN))
	return true


## La bougie la plus proche s'éteint quelques secondes. Renvoie sa position, ou Vector3.INF.
func souffler_bougie(pos: Vector3, portee: float) -> Vector3:
	for l in _bougies:
		if l.has_meta("base") or l.has_meta("soufflee") or l.global_position.distance_to(pos) > portee:
			continue
		l.set_meta("soufflee", true)
		l.visible = false
		var flamme: Node3D = l.get_meta("flamme") if l.has_meta("flamme") else null
		if flamme:
			flamme.visible = false
		get_tree().create_timer(5.5).timeout.connect(func():
			l.visible = true
			if flamme:
				flamme.visible = true
			l.remove_meta("soufflee"))
		return l.global_position
	return Vector3.INF


## Un corbeau perché tout près s'envole d'un coup, et ne revient qu'une minute et demie plus tard.
func envoler_corbeau(pos: Vector3, portee: float) -> Vector3:
	for c in _corbeaux:
		if c.has_meta("vol") or c.global_position.distance_to(pos) > portee:
			continue
		c.set_meta("vol", true)
		var depart := c.position
		var fuite := Vector3(c.position.x, 0, c.position.z).normalized() * 14.0 + Vector3(0, 9.0, 0)
		var tw := create_tween()
		tw.tween_property(c, "position", depart + fuite, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): c.visible = false)
		tw.tween_interval(90.0)
		tw.tween_callback(func():
			c.position = depart
			c.visible = true
			c.remove_meta("vol"))
		return c.global_position
	return Vector3.INF


static func numero(i: int) -> String:
	return CHIFFRES[i] if i >= 0 and i < CHIFFRES.size() else "?"


func barricader(i: int) -> void:
	if _barricades.has(i):
		return
	_barricades[i] = true
	var m := _maisons[i]
	for k in 3:
		var planche := _boite(Vector3(1.2, 0.14, 0.06), Color(0.32, 0.25, 0.2))
		planche.position = Vector3(-1.75, 1.3 + k * 0.32, PROFONDEUR * 0.5 + 0.46)   # devant la fenêtre de gauche, au-delà de l'appui
		planche.rotation.z = (k - 1) * 0.35
		m.add_child(planche)
	var croix := _boite(Vector3(1.1, 0.12, 0.06), Color(0.55, 0.06, 0.05))
	croix.position = Vector3(0, 1.5, PROFONDEUR * 0.5 + 0.05)
	croix.rotation.z = 0.7
	m.add_child(croix)
	accrocher_a_la_porte(i, "avant", croix)


## Où se gare la roulotte : sur la place, entre la 2e et la 3e maison, l'étal tourné vers le feu.
static func repere_roulotte() -> Transform3D:
	var a := (angle_maison(1) + angle_maison(2)) * 0.5
	var dir := Vector3(sin(a), 0, cos(a))
	return Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.z)), dir * (R_MAISON - 5.6))


## La maison la plus proche de la roulotte : c'est elle qu'on pare pour essayer une parure.
static func maison_de_la_roulotte() -> int:
	return maison_proche(repere_roulotte().origin)


## La parure de maison choisie à la roulotte par celui qui y dort ("" la retire).
func parer_maison(i: int, sorte: String) -> void:
	if i < 0 or i >= _maisons.size():
		return
	if _parures.has(i):
		if _parures[i][0] == sorte:
			return
		(_parures[i][1] as Node).queue_free()
		if _parures[i][2] != null and is_instance_valid(_parures[i][2]):
			(_parures[i][2] as Node).queue_free()
		_parures.erase(i)
		if i < _fenetres.size():
			_fenetres[i].emission = _verre_neuf().emission
			_fenetres[i].albedo_color = _verre_neuf().albedo_color
	if sorte == "":
		return
	var verre: StandardMaterial3D = _fenetres[i] if i < _fenetres.size() else null
	var racine := Parures.maison(self, _maisons[i], verre, sorte)
	var sur_porte := racine.get_node_or_null("SurPorte") as Node3D
	if sur_porte:
		accrocher_a_la_porte(i, "avant", sur_porte)
	_parures[i] = [sorte, racine, sur_porte]


## Ce qui est cloué sur un battant passe sous son gond et tourne avec lui (Edwin, 31/10 : couronne,
## têtes sculptées et croix flottaient dans le vide, porte ouverte). Placé comme sur la porte fermée.
func accrocher_a_la_porte(i: int, quelle: String, noeud: Node3D) -> void:
	var cle := "%d:%s" % [i, quelle]
	if not _portes.has(cle):
		return
	var pivot: Node3D = _portes[cle]["pivot"]
	var angle := pivot.rotation.y
	pivot.rotation.y = 0.0
	var dans := _relatif(pivot).affine_inverse() * _relatif(noeud)
	noeud.get_parent().remove_child(noeud)
	pivot.add_child(noeud)
	noeud.transform = dans
	pivot.rotation.y = angle


## La transformation d'un nœud dans le repère de la Ronde.
func _relatif(n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != self:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


## Une tombe de plus au cimetière, avec le nom gravé. Renvoie sa position.
func enterrer(nom: String, style := "") -> Vector3:
	var p := tombe(_tombes)
	_tombes += 1
	if style != "":
		# Une tombe achetée à la roulotte (cf. Parures) : elle remplace la pierre nue.
		var t := Parures.tombe(style)
		add_child(t)
		t.look_at_from_position(p, Vector3(0, 0, 0))
		t.rotate_object_local(Vector3.UP, PI)
	else:
		var pierre := _boite(Vector3(0.7, 0.9, 0.18), Color(0.4, 0.4, 0.42))
		pierre.position = p + Vector3(0, 0.45, 0)
		pierre.look_at_from_position(pierre.position, Vector3(0, 0.45, 0))
		add_child(pierre)
	var terre := _boite(Vector3(0.8, 0.12, 1.5), Color(0.25, 0.18, 0.13))
	terre.position = p + Vector3(0, 0.06, 0) + (-p.normalized()) * 0.85
	terre.look_at_from_position(terre.position, Vector3(0, 0.06, 0))
	add_child(terre)
	var l := Label3D.new()
	l.font = Style.police("titre")
	l.text = nom
	l.font_size = 40
	l.modulate = Color(0.85, 0.82, 0.75)
	l.outline_size = 6
	l.position = p + Vector3(0, 1.15, 0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(l)
	return p


# ---------------------------------------------------------------- construction

## Le plafond de nuages (cf. nuages.gdshader) suit la caméra ; quand une masse passe devant
## le soleil, la lumière du village baisse pendant de longues secondes.
func _maj_nuages(delta: float) -> void:
	if _nuages == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		_nuages.global_position = cam.global_position
		if _etoiles:
			_etoiles.global_position = cam.global_position
	var o := float(_mat_nuages.get_shader_parameter("opacite"))
	o = move_toward(o, _jour_nuageux, delta * 0.035)   # au rythme du fondu d'ambiance (~30 s)
	_mat_nuages.set_shader_parameter("opacite", o)
	_nuages.visible = o > 0.01
	_mat_nuages.set_shader_parameter("soleil", _soleil.global_transform.basis.z)
	if _soleil.visible and _phase in ["jour", "salon"]:
		# Deux périodes lentes qui ne se recoupent jamais : jamais deux fois le même ciel.
		var ombre := 0.5 + 0.5 * sin(_t * 0.09) * sin(_t * 0.047 + 1.3)
		_soleil.shadow_opacity = lerpf(1.0, 0.35, ombre * o)
		_facteur_nuages = lerpf(1.0, 0.45, ombre * o)
	else:
		_soleil.shadow_opacity = 1.0
		_facteur_nuages = 1.0


var _soleil_base := 0.5
var _facteur_nuages := 1.0


func _ciel_et_lumieres() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	var ciel := Sky.new()
	_ciel = ProceduralSkyMaterial.new()
	_ciel.ground_bottom_color = Color(0.05, 0.05, 0.05)
	_ciel.ground_horizon_color = Color(0.25, 0.24, 0.22)
	ciel.sky_material = _ciel
	_env.background_mode = Environment.BG_SKY
	_env.sky = ciel
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.6, 0.62, 0.7)
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 0.72
	_env.adjustment_contrast = 1.1
	_env.glow_enabled = true
	# Les petits flashs qui font mal aux yeux (Edwin, 01/11) : un reflet ou une flamme à émission forte
	# (jusqu'à 6) passait en bloom brutal quand on tournait la tête. Seuil relevé, pic plafonné.
	_env.glow_intensity = 0.55
	_env.glow_bloom = 0.04
	_env.glow_hdr_threshold = 1.4
	_env.glow_hdr_luminance_cap = 3.0
	_env.fog_enabled = true
	_env.volumetric_fog_enabled = brume_volumetrique
	_env.volumetric_fog_length = 40.0
	_env.volumetric_fog_anisotropy = 0.6
	_env.volumetric_fog_ambient_inject = 0.0
	we.environment = _env
	add_child(we)

	_soleil = DirectionalLight3D.new()
	_soleil.shadow_enabled = true
	# Les paliers d'ombre se fondent l'un dans l'autre : sans ça, le sol des clairières se coupait en
	# bandes claires et sombres à bords nets.
	_soleil.directional_shadow_blend_splits = true
	_soleil.directional_shadow_max_distance = 45.0
	_soleil.directional_shadow_fade_start = 0.7
	_soleil.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(_soleil)
	_lune = DirectionalLight3D.new()
	_lune.shadow_enabled = true
	_lune.directional_shadow_blend_splits = true
	_lune.directional_shadow_max_distance = 45.0
	_lune.directional_shadow_fade_start = 0.7
	_lune.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_lune.rotation_degrees = Vector3(-35, 40, 0)
	add_child(_lune)
	_mat_lune = Bouille.materiau(Color(0.9, 0.9, 0.82), 0.0, Color(0.85, 0.85, 0.75))
	_astre_lune = Bouille.sphere(4.0, _mat_lune)
	_astre_lune.position = Vector3(-30, 34, -70)
	add_child(_astre_lune)
	lune_rouge(false)
	# Le soleil reste un disque terne derrière le voile, pas un astre éclatant.
	_ciel.sun_angle_max = 8.0
	_ciel.sun_curve = 0.6
	_ciel.sky_energy_multiplier = 0.85
	_nuages = MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 140.0
	dome.height = 280.0
	dome.radial_segments = 32
	dome.rings = 16
	_nuages.mesh = dome
	_mat_nuages = ShaderMaterial.new()
	_mat_nuages.shader = preload("res://monde/nuages.gdshader")
	_mat_nuages.set_shader_parameter("opacite", 0.0)
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.generate_mipmaps = true
	var bruit := FastNoiseLite.new()
	bruit.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	bruit.frequency = 0.008
	bruit.fractal_octaves = 5
	bruit.seed = 7
	tex.noise = bruit
	_mat_nuages.set_shader_parameter("bruit_tex", tex)
	_nuages.material_override = _mat_nuages
	_nuages.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_nuages.visible = false
	add_child(_nuages)
	# Les étoiles, juste derrière les nuages (cf. etoiles.gdshader) : au menu et la nuit.
	_etoiles = MeshInstance3D.new()
	var dome_e := SphereMesh.new()
	dome_e.radius = 145.0
	dome_e.height = 290.0
	dome_e.radial_segments = 48
	dome_e.rings = 24
	_etoiles.mesh = dome_e
	_mat_etoiles = ShaderMaterial.new()
	_mat_etoiles.shader = preload("res://monde/etoiles.gdshader")
	_mat_etoiles.render_priority = -1
	_etoiles.material_override = _mat_etoiles
	_etoiles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_etoiles.visible = false
	add_child(_etoiles)


func _sol() -> void:
	var sol := MeshInstance3D.new()
	sol.mesh = Terre.maillage_sol()     # plat où l'on marche, des buttes au-delà (cf. Terre)
	sol.material_override = _mat_sol()
	add_child(sol)
	var corps := StaticBody3D.new()
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(120, 1, 120)
	f.shape = b
	f.position.y = -0.5
	corps.add_child(f)
	add_child(corps)
	# Herbe sèche et touffes, pour casser l'uniforme.
	var brin := CylinderMesh.new()
	brin.top_radius = 0.0
	brin.bottom_radius = 0.03
	brin.height = 0.32
	brin.radial_segments = 3
	brin.rings = 1
	var mm := _semis(brin, 1500, Color(0.24, 0.27, 0.14))
	for k in mm.multimesh.instance_count:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(R_CHEMIN_MIN - 0.8, 30.0 + ECART)
		var pos := Vector3(sin(a) * d, 0.13, cos(a) * d)
		if maison_de(pos) >= 0:
			pos.y = -1.0      # pas de brins d'herbe dans une maison
		var t := Transform3D(Basis(Vector3.UP, _rng.randf() * PI).rotated(Vector3.FORWARD, _rng.randf_range(-0.4, 0.4)), pos)
		mm.multimesh.set_instance_transform(k, t)


func _place() -> void:
	# (La place est pavée par le shader du sol : pavés usés qui se perdent dans la boue.)

	# Au centre, le Conseil du jour se tient autour d'un petit feu de camp (Edwin, 29/10) ; l'autel
	# est monté sur le temple (cf. _temple).
	# Le cercle de pierres autour du feu : de vraies pierres moussues (Poly Haven, CC0), à
	# moitié enfoncées, toutes différentes (Edwin, 29/10 : « juste des ronds gris »).
	var cercle := []
	var plats := []
	for k in 11:
		var a := k * TAU / 11.0 + _rng.randf_range(-0.12, 0.12)
		var d := _rng.randf_range(1.6, 1.8)
		if k % 2 == 0:
			cercle.append([Vector3(sin(a) * d, -0.08, cos(a) * d), _rng.randf_range(0.38, 0.5), _rng.randf() * TAU])
		else:
			plats.append([Vector3(sin(a) * d, -0.04, cos(a) * d), _rng.randf_range(0.2, 0.28), _rng.randf() * TAU])
	Terre.semer(self, "boulder_01", cercle)
	Terre.semer(self, "rock_moss_set_02", plats)
	var gravats := []
	for k in 18:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(1.2, 2.2)
		gravats.append([Vector3(sin(a) * d, -0.02, cos(a) * d), _rng.randf_range(0.04, 0.08), _rng.randf() * TAU])
	Terre.semer(self, "rock_moss_set_01", gravats)
	# Les pieds de l'autel : quatre loups de pierre couchés aux angles, qui portent la dalle sur
	# leur dos et tendent la gueule vers le dehors (décision d'Edwin, 29/10 : « emblématique »).
	_braises = Bouille.materiau(Color(1.0, 0.45, 0.1), 0.0, Color(1.0, 0.42, 0.08))
	_ossements()
	_feu_de_camp()
	_temple()

	# Les 12 sièges du Conseil : des souches debout, à l'écorce et aux cernes réels.
	for i in NB_MAISONS:
		_souche_siege(i)

	# (Plus de puits sur la place : décision d'Edwin, 29/10.)
	_sang_et_mots()

	# Une charrette abandonnée, loin des ruelles par où passent les bots.
	var chariot := _modele("Prop_Wagon", self, POS_CHARRETTE, 1.2, Vector3.ONE, Color(0.5, 0.46, 0.43))
	chariot.rotation.z = 0.04
	_obstacle(chariot, Ronde.boite(Vector3(1.9, 1.5, 3.9)), Vector3(0, 0.75, -1.1))



## L'autel, pièce maîtresse du village (Edwin, 31/10 : « limite emblématique ») : un bloc de basalte
## taillé sur un socle à deux degrés, une bordure qui retient ce qui coule, des runes qui couvent
## en rouge sur sa face. Derrière, la Lune du loup : un grand disque de pierre pâle cerclé d'or où
## hurle un loup de fer, éclairé par-derrière ; de part et d'autre, deux stèles gravées.
## Le repère est celui de la terrasse : y = 0 au dallage, la place vers -z.
func _contenu_autel() -> void:
	var basalte := _mat_tex("rocky_trail", 0.35, Color(0.30, 0.28, 0.30), false)
	var socle := _mat_tex("rocky_trail", 0.5, Color(0.46, 0.44, 0.45), false)
	var bordure := _pierre_moussue()
	var fer := Bouille.materiau(Color(0.10, 0.10, 0.11), 0.01)
	fer.metallic = 0.75
	fer.roughness = 0.45
	var rouille := StandardMaterial3D.new()
	rouille.albedo_color = Color(0.2, 0.13, 0.09)
	rouille.metallic = 0.55
	rouille.roughness = 0.78
	var or_ := StandardMaterial3D.new()
	or_.albedo_color = Color(0.82, 0.6, 0.26)
	or_.metallic = 0.9
	or_.roughness = 0.32
	var braise := StandardMaterial3D.new()
	braise.albedo_color = Color(0.25, 0.02, 0.01)
	braise.emission_enabled = true
	braise.emission = Color(1.0, 0.12, 0.04)
	braise.emission_energy_multiplier = 2.2
	_runes_braise = braise
	# Le socle à deux degrés, puis le corps, puis la table — chacun un peu en retrait, comme taillé.
	_bloc(_sur, Vector3(2.9, 0.12, 1.7), socle, Vector3(0, 0.06, 0))
	_bloc(_sur, Vector3(2.65, 0.12, 1.45), socle, Vector3(0, 0.18, 0))
	var corps_h := PIERRE_HAUT - 0.24 - 0.2
	_bloc(_sur, Vector3(2.15, corps_h, 1.0), basalte, Vector3(0, 0.24 + corps_h * 0.5, 0))
	# Deux bandeaux en saillie autour du corps : la pierre a l'air taillée, pas posée.
	_bloc(_sur, Vector3(2.22, 0.05, 1.07), bordure, Vector3(0, 0.27, 0))
	_bloc(_sur, Vector3(2.22, 0.05, 1.07), bordure, Vector3(0, 0.24 + corps_h - 0.03, 0))
	# La table, qui déborde, et sa bordure qui retient ce qui coule.
	_bloc(_sur, Vector3(2.45, 0.2, 1.25), basalte, Vector3(0, PIERRE_HAUT - 0.1, 0))
	for z: float in [-0.6, 0.6]:
		_bloc(_sur, Vector3(2.45, 0.035, 0.06), bordure, Vector3(0, PIERRE_HAUT + 0.017, z))
	for x: float in [-1.2, 1.2]:
		_bloc(_sur, Vector3(0.06, 0.035, 1.25), bordure, Vector3(x, PIERRE_HAUT + 0.017, 0))
	_tache = _boite(Vector3(1.3, 0.015, 0.7), Color(0.32, 0.02, 0.02))
	_tache.position.y = PIERRE_HAUT + 0.01
	_tache.visible = false
	_sur.add_child(_tache)
	# Sur la face qui regarde la place : sept runes qui couvent comme des braises.
	_runes_verticales(_sur, Vector3(0, 0.24 + corps_h * 0.5, -0.505), 7, 0.27, braise)
	# Les anneaux de fer et les chaînes, sur les deux côtés.
	for cote: int in [-1, 1]:
		for z: float in [-0.35, 0.35]:
			var anneau := MeshInstance3D.new()
			var tore := TorusMesh.new()
			tore.inner_radius = 0.05
			tore.outer_radius = 0.075
			anneau.mesh = tore
			anneau.material_override = fer
			anneau.position = Vector3(cote * 1.24, PIERRE_HAUT - 0.06, z)
			anneau.rotation.z = PI * 0.5
			_sur.add_child(anneau)
			_chaine(Vector3(cote * 1.3, PIERRE_HAUT - 0.11, z), rouille)
	# Deux bouquets de bougies allumées, sur les coins arrière de la table.
	for cote: int in [-1, 1]:
		_bougies_allumees(Vector3(cote * 0.98, PIERRE_HAUT, 0.42))
	# Une coupe d'offrande, au milieu derrière : du bronze, et quelque chose de sombre dedans.
	var coupe := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.13
	cc.bottom_radius = 0.05
	cc.height = 0.1
	coupe.mesh = cc
	coupe.material_override = or_
	coupe.position = Vector3(0, PIERRE_HAUT + 0.05, 0.47)
	_sur.add_child(coupe)
	var pied := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 0.03
	pc.bottom_radius = 0.08
	pc.height = 0.04
	pied.mesh = pc
	pied.material_override = or_
	pied.position = Vector3(0, PIERRE_HAUT + 0.0, 0.47)
	_sur.add_child(pied)
	var vin := _boite(Vector3(0.2, 0.005, 0.2), Color(0.18, 0.01, 0.01))
	vin.position = Vector3(0, PIERRE_HAUT + 0.092, 0.47)
	_sur.add_child(vin)
	# Les vieilles taches, posées dans la pierre (décalques), au lieu de rectangles unis.
	var formes: Array[ImageTexture] = []
	for k in 4:
		formes.append(_tache_de_sang(k))
	var ici := (_sur as Node3D).global_position
	for k in 4:
		var p := ici + Vector3(_rng.randf_range(-0.75, 0.75), PIERRE_HAUT + 0.05, _rng.randf_range(-0.38, 0.3))
		_decalque(p, formes[k], Vector2.ONE * _rng.randf_range(0.3, 0.55), _rng.randf() * TAU, Color(0.3, 0.03, 0.02))
	for k in 3:
		# Ce qui a coulé par-dessus la bordure, sur la face avant.
		var coulure := _boite(Vector3(0.05, _rng.randf_range(0.12, 0.3), 0.008), Color(0.22, 0.02, 0.02))
		coulure.position = Vector3(_rng.randf_range(-0.9, 0.9), PIERRE_HAUT - 0.12, -0.627)
		_sur.add_child(coulure)
	_obstacle(_sur, Ronde.boite(Vector3(2.45, 0.8, 1.25)), Vector3(0, 0.4, 0))
	_lune_du_loup(Vector3(0, 1.9, TEMPLE_PROFOND * 0.5 - 0.42), or_, fer)
	# Les deux stèles, en retrait de part et d'autre.
	for cote: int in [-1, 1]:
		var s := Node3D.new()
		s.position = Vector3(cote * 1.72, 0, 1.2)
		s.rotation.y = -cote * 0.35
		_sur.add_child(s)
		_bloc(s, Vector3(0.62, 0.14, 0.42), socle, Vector3(0, 0.07, 0))
		_bloc(s, Vector3(0.46, 1.9, 0.24), basalte, Vector3(0, 0.14 + 0.95, 0))
		var tete := MeshInstance3D.new()
		var pr := PrismMesh.new()
		pr.size = Vector3(0.46, 0.28, 0.24)
		tete.mesh = pr
		tete.material_override = basalte
		tete.position = Vector3(0, 0.14 + 1.9 + 0.14, 0)
		s.add_child(tete)
		_runes_verticales(s, Vector3(0, 1.15, -0.125), 4, 0.3, braise, true)
		_obstacle(s, Ronde.boite(Vector3(0.5, 2.0, 0.3)), Vector3(0, 1.0, 0))


var _runes_braise: StandardMaterial3D


## Des runes taillées dans une face verticale (le plan xy local), en ligne (ou en colonne).
func _runes_verticales(parent: Node3D, centre: Vector3, n: int, pas: float, mat: Material, colonne := false) -> void:
	var traits := [[[0.0, 0.0, 0.0], [0.045, 0.03, 0.8], [0.045, -0.03, -0.8]],
		[[0.0, 0.0, 0.0], [-0.04, 0.04, 0.7], [0.04, 0.04, -0.7]],
		[[0.0, 0.0, 0.0], [0.04, 0.0, 1.57], [0.055, -0.04, 0.7]],
		[[0.0, 0.0, 0.0], [0.035, 0.045, -0.9], [0.035, -0.005, -0.9], [0.035, -0.055, -0.9]]]
	var barre := BoxMesh.new()
	barre.size = Vector3(0.022, 0.15, 0.012)
	for k in n:
		var decal := (k - (n - 1) * 0.5) * pas
		var r := Node3D.new()
		r.position = centre + (Vector3(0, -decal, 0) if colonne else Vector3(decal, 0, 0))
		parent.add_child(r)
		for t: Array in traits[(k * 3 + 1) % traits.size()]:
			_forme(r, barre, mat, Vector3(t[0], t[1], 0), Vector3(0, 0, t[2]))


## Trois ou quatre bougies serrées, de hauteurs différentes, avec leur flamme et une lueur.
func _bougies_allumees(base: Vector3) -> void:
	var cire := Bouille.materiau(Color(0.84, 0.8, 0.68), 0.0)
	var flamme := StandardMaterial3D.new()
	flamme.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flamme.albedo_color = Color(1.0, 0.72, 0.32)
	var hauts := [0.22, 0.15, 0.3, 0.11]
	var places := [Vector3(0, 0, 0), Vector3(0.07, 0, -0.05), Vector3(-0.06, 0, 0.04), Vector3(0.05, 0, 0.07)]
	for k in hauts.size():
		var h: float = hauts[k]
		var b := MeshInstance3D.new()
		var cb := CylinderMesh.new()
		cb.top_radius = 0.022
		cb.bottom_radius = 0.028
		cb.height = h
		b.mesh = cb
		b.material_override = cire
		b.position = base + places[k] + Vector3(0, h * 0.5, 0)
		_sur.add_child(b)
		var f := Bouille.sphere(0.02, flamme, Vector3(1, 2.2, 1))
		f.position = base + places[k] + Vector3(0, h + 0.03, 0)
		_sur.add_child(f)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.28)
	l.light_energy = 0.9
	l.omni_range = 2.6
	l.position = base + Vector3(0, 0.45, 0)
	_sur.add_child(l)
	_bougies.append(l)


## La tête de loup du fond du temple, face à la place : un médaillon de basalte noir, cerclé d'or,
## dans lequel une tête de loup est sculptée en relief (cf. TeteLoup), gueule ouverte, œil de braise.
func _lune_du_loup(centre: Vector3, or_: Material, fer: Material) -> void:
	var n := Node3D.new()
	n.position = centre
	_sur.add_child(n)
	var r := 0.82
	var lune := _mat_tex("rocky_trail", 0.6, Color(0.10, 0.09, 0.10), false)
	var pierre := _mat_tex("rocky_trail", 0.45, Color(0.66, 0.62, 0.59), false)
	var os := StandardMaterial3D.new()
	os.albedo_color = Color(0.86, 0.82, 0.7)
	os.roughness = 0.7
	var disque := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = r
	dm.bottom_radius = r
	dm.height = 0.05
	dm.radial_segments = 64
	disque.mesh = dm
	disque.material_override = lune
	disque.rotation.x = PI * 0.5
	n.add_child(disque)
	var cercle := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.01
	tm.outer_radius = r + 0.07
	tm.rings = 64
	cercle.mesh = tm
	cercle.material_override = or_
	cercle.rotation.x = PI * 0.5
	n.add_child(cercle)
	# Douze clous d'or sur le cercle, comme les heures de la nuit.
	for k in 12:
		var a := k * TAU / 12.0
		var clou := Bouille.sphere(0.03, or_)
		clou.position = Vector3(cos(a), sin(a), 0) * (r + 0.03) + Vector3(0, 0, -0.05)
		n.add_child(clou)
	# La tête de loup, sculptée en relief dans la pierre (vers la place, donc vers -z).
	var tete := TeteLoup.construire(pierre, lune, _runes_braise, os)
	tete.position = Vector3(0, -0.02, -0.025)
	tete.scale = Vector3(0.92, 0.92, 1.0)
	n.add_child(tete)
	# Deux chaînes d'or qui la tiennent à la poutre.
	for c: int in [-1, 1]:
		_bloc(n, Vector3(0.025, 0.9, 0.025), or_, Vector3(c * 0.5, r + 0.35, 0.02))
	# La lueur derrière : un halo rouge sur le paravent, qui détache la lune du fond.
	var halo := OmniLight3D.new()
	halo.light_color = Color(1.0, 0.22, 0.1)
	halo.light_energy = 2.2
	halo.omni_range = 2.4
	halo.position = Vector3(0, 0, 0.22)
	n.add_child(halo)
	var face := OmniLight3D.new()
	face.light_color = Color(0.85, 0.85, 1.0)
	face.light_energy = 0.5
	face.omni_range = 2.2
	face.position = Vector3(0, 0.3, -1.0)
	n.add_child(face)


## Au centre de la place, un petit feu de camp, bas (Edwin, 29/10 : « pas trop haut ») : il
## éclaire le cercle des souches pour qu'on voie chaque visage au Conseil.
func _feu_de_camp() -> void:
	var n := Node3D.new()
	add_child(n)
	var cendre := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.55
	cc.bottom_radius = 0.6
	cc.height = 0.03
	cendre.mesh = cc
	cendre.material_override = Bouille.materiau(Color(0.07, 0.06, 0.06), 0.0)
	cendre.position.y = 0.015
	n.add_child(cendre)
	# Les pierres du foyer.
	var foyer := []
	for k in 10:
		var a := k * TAU / 10.0 + _rng.randf_range(-0.1, 0.1)
		foyer.append([Vector3(sin(a) * 0.66, -0.04, cos(a) * 0.66), _rng.randf_range(0.13, 0.17), _rng.randf() * TAU])
	Terre.semer(self, "boulder_01", foyer)
	# Les bûches dressées en tipi, deux couchées en travers.
	var ecorce := _mat_ecorce()
	for k in 6:
		var a := k * TAU / 6.0 + 0.3
		var b := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.04
		cy.bottom_radius = 0.06
		cy.height = 0.72
		b.mesh = cy
		b.material_override = ecorce
		b.position = Vector3(sin(a) * 0.17, 0.3, cos(a) * 0.17)
		b.rotation = Vector3(cos(a) * -0.55, 0, sin(a) * 0.55)
		n.add_child(b)
	for k in 2:
		var b := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.06
		cy.bottom_radius = 0.07
		cy.height = 0.9
		b.mesh = cy
		b.material_override = ecorce
		b.position = Vector3(0, 0.07, -0.2 + k * 0.4)
		b.rotation = Vector3(0, 0.5 + k * 1.3, PI * 0.5)
		n.add_child(b)
	var braise := Bouille.sphere(0.36, _braises, Vector3(1.0, 0.18, 1.0))
	braise.position.y = 0.05
	n.add_child(braise)
	var flammes := DecorQuete._particules(56, 0.8, Vector3(0.2, 0.04, 0.2), Vector3(0, 1.1, 0), 0.4,
		DecorQuete._degrade([Color(0.9, 0.5, 0.15, 0.0), Color(0.95, 0.55, 0.15, 0.55), Color(0.85, 0.25, 0.05, 0.4), Color(0.4, 0.05, 0.02, 0.0)]), true)
	flammes.position.y = 0.18
	n.add_child(flammes)
	var etincelles := DecorQuete._particules(30, 2.4, Vector3(0.3, 0.1, 0.3), Vector3(0.1, 2.0, 0.05), 0.05,
		DecorQuete._degrade([Color(1.0, 0.7, 0.3, 0.0), Color(1.0, 0.6, 0.2, 1.0), Color(0.9, 0.25, 0.05, 0.0)]), true)
	etincelles.position.y = 0.4
	n.add_child(etincelles)
	var fumee := DecorQuete._particules(20, 4.5, Vector3(0.25, 0.05, 0.25), Vector3(0.15, 0.9, 0), 1.2,
		DecorQuete._degrade([Color(0.15, 0.14, 0.14, 0.0), Color(0.12, 0.12, 0.13, 0.3), Color(0.2, 0.2, 0.21, 0.0)]), false)
	fumee.position.y = 1.1
	n.add_child(fumee)
	_feu = OmniLight3D.new()
	_feu.light_color = Color(1.0, 0.45, 0.18)
	_feu.omni_range = R_SOUCHES + 8.0
	_feu.omni_attenuation = 1.4
	_feu.shadow_enabled = true
	_feu.position.y = 0.9
	n.add_child(_feu)
	_obstacle(n, Ronde.boite(Vector3(1.4, 0.6, 1.4)), Vector3(0, 0.3, 0))


## Le temple de l'autel (Edwin, 29/10) : un petit temple de prière ouvert, à la chinoise, de la
## taille d'une maison, à la place 0 du cercle, face à la place. Une terrasse de pierre à 1,5 m,
## huit marches, six colonnes laquées de rouge, une balustrade, un toit aux coins relevés, deux
## lanternes. L'autel est dessus ; deux braseros au pied des marches.
func _temple() -> void:
	var t := Node3D.new()
	t.position = centre_temple()
	add_child(t)
	var L := TEMPLE_LARGE
	var P := TEMPLE_PROFOND
	var H := TEMPLE_HAUT
	var pierre := _pierre_moussue()
	# Plus aucun aplat (Edwin, 30/10) : dalles de pierre, bois laqué veiné, dorure patinée.
	var dalle := _mat_tex("rocky_trail", 0.5, Color(0.55, 0.53, 0.55))
	var laque := _bois_teint("laque", Color(0.95, 0.16, 0.12), 0.45)
	var bois := _bois_teint("sombre", Color(0.45, 0.32, 0.25), 1.0)
	var tuile := _mat_tuiles_temple()
	var dore := _bois_teint("dore", Color(1.0, 0.78, 0.36), 0.4)
	dore.metallic = 0.65
	# La terrasse : un socle de pierre, une corniche, un dallage sombre.
	_bloc(t, Vector3(L, H, P), pierre, Vector3(0, H * 0.5, 0))
	_bloc(t, Vector3(L + 0.16, 0.12, P + 0.16), pierre, Vector3(0, H - 0.06, 0))
	_bloc(t, Vector3(L - 0.1, 0.02, P - 0.1), dalle, Vector3(0, H + 0.01, 0))
	_obstacle(t, Ronde.boite(Vector3(L, H, P)), Vector3(0, H * 0.5, 0))
	# Huit marches vers la place, entre deux limons de pierre ; dessous, une rampe invisible
	# (le moteur ne monte pas une marche de 19 cm, il gravit une pente de 32°).
	var h := H / MARCHES
	var d := MARCHES_LONG / MARCHES
	for k in MARCHES:
		_bloc(t, Vector3(MARCHES_LARGE, (k + 1) * h, d), pierre,
			Vector3(0, (k + 1) * h * 0.5, -P * 0.5 - MARCHES_LONG + (k + 0.5) * d))
	var pente := atan2(H, MARCHES_LONG)
	var long_ := sqrt(H * H + MARCHES_LONG * MARCHES_LONG)
	for c: int in [-1, 1]:
		var limon := _bloc(t, Vector3(0.3, 0.42, long_ + 0.2), pierre,
			Vector3(c * (MARCHES_LARGE * 0.5 + 0.15), H * 0.5 + 0.21, -P * 0.5 - MARCHES_LONG * 0.5))
		limon.rotation.x = -pente
		_obstacle(t, Ronde.boite(Vector3(0.3, 1.2, MARCHES_LONG)), Vector3(c * (MARCHES_LARGE * 0.5 + 0.15), 0.6, -P * 0.5 - MARCHES_LONG * 0.5))
	var rampe := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	forme.shape = Ronde.boite(Vector3(MARCHES_LARGE, 0.2, long_))
	rampe.add_child(forme)
	rampe.rotation.x = -pente
	rampe.position = Vector3(0, H * 0.5, -P * 0.5 - MARCHES_LONG * 0.5) - Vector3(0, cos(pente), -sin(pente)) * 0.1
	t.add_child(rampe)
	# Six colonnes laquées sur socle de pierre : les quatre coins, et deux qui encadrent l'escalier.
	var colonnes := [Vector3(-L * 0.5 + 0.3, 0, -P * 0.5 + 0.3), Vector3(L * 0.5 - 0.3, 0, -P * 0.5 + 0.3),
		Vector3(-L * 0.5 + 0.3, 0, P * 0.5 - 0.3), Vector3(L * 0.5 - 0.3, 0, P * 0.5 - 0.3),
		Vector3(-MARCHES_LARGE * 0.5 + 0.12, 0, -P * 0.5 + 0.3), Vector3(MARCHES_LARGE * 0.5 - 0.12, 0, -P * 0.5 + 0.3)]
	var haut_col := 2.9
	for c: Vector3 in colonnes:
		var base := MeshInstance3D.new()
		var cb := CylinderMesh.new()
		cb.top_radius = 0.19
		cb.bottom_radius = 0.24
		cb.height = 0.22
		base.mesh = cb
		base.material_override = pierre
		base.position = c + Vector3(0, H + 0.11, 0)
		t.add_child(base)
		var col := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.13
		cy.bottom_radius = 0.15
		cy.height = haut_col
		col.mesh = cy
		col.material_override = laque
		col.position = c + Vector3(0, H + haut_col * 0.5, 0)
		t.add_child(col)
		_obstacle(t, Ronde.boite(Vector3(0.34, haut_col, 0.34)), c + Vector3(0, H + haut_col * 0.5, 0))
	# Les poutres du haut, laquées, filet doré ; une enseigne au-dessus de l'escalier.
	var y_p := H + haut_col
	for z: float in [-P * 0.5 + 0.3, P * 0.5 - 0.3]:
		_bloc(t, Vector3(L - 0.3, 0.3, 0.24), laque, Vector3(0, y_p, z))
		_bloc(t, Vector3(L - 0.3, 0.04, 0.26), dore, Vector3(0, y_p - 0.17, z))
	for x: float in [-L * 0.5 + 0.3, L * 0.5 - 0.3]:
		_bloc(t, Vector3(0.24, 0.3, P - 0.3), laque, Vector3(x, y_p, 0))
	var plaque := Node3D.new()
	plaque.position = Vector3(0, y_p - 0.02, -P * 0.5 + 0.16)
	plaque.rotation.y = PI
	t.add_child(plaque)
	plaque.add_child(_enseigne("L'Autel", Vector3(0, 0, 0), 1.6))
	# Le toit : deux pans de tuiles sombres, des pignons, un faîtage aux bouts recourbés, et les
	# quatre coins relevés vers le ciel.
	var y_t := y_p + 0.2
	var monte := 1.25
	var deb := 0.75
	var pan_l := sqrt(pow(P * 0.5 + deb, 2) + monte * monte)
	var incl := atan2(monte, P * 0.5 + deb)
	for c: int in [-1, 1]:
		var pan := _bloc(t, Vector3(L + 1.5, 0.14, pan_l), tuile, Vector3(0, y_t + monte * 0.5, c * (P * 0.5 + deb) * 0.5))
		pan.rotation.x = c * incl
		# Les rangs de tuiles : des baguettes en relief, de haut en bas.
		for k in 9:
			var x := -L * 0.5 - 0.6 + k * (L + 1.2) / 8.0
			var rang := _bloc(t, Vector3(0.08, 0.06, pan_l), tuile, Vector3(x, y_t + monte * 0.5 + 0.09, c * (P * 0.5 + deb) * 0.5))
			rang.rotation.x = c * incl
		# Le bord du pan, doré.
		_bloc(t, Vector3(L + 1.5, 0.07, 0.1), dore, Vector3(0, y_t - 0.02, c * (P * 0.5 + deb)))
	for c: int in [-1, 1]:
		var pignon := MeshInstance3D.new()
		var pr := PrismMesh.new()
		pr.size = Vector3(P + 1.2, monte, 0.12)
		pignon.mesh = pr
		pignon.material_override = bois
		pignon.position = Vector3(c * (L * 0.5 - 0.1), y_t + monte * 0.5, 0)
		pignon.rotation.y = PI * 0.5
		t.add_child(pignon)
	# Un second toit, plus petit, posé sur le premier : la silhouette à deux étages des temples.
	var y_2 := y_t + monte * 0.55
	var monte2 := 0.85
	var deb2 := 0.35
	var pan2_l := sqrt(pow(P * 0.3 + deb2, 2) + monte2 * monte2)
	var incl2 := atan2(monte2, P * 0.3 + deb2)
	_bloc(t, Vector3(L * 0.62, monte * 0.5, P * 0.55), bois, Vector3(0, y_2 + 0.1, 0))
	for c: int in [-1, 1]:
		var pan2 := _bloc(t, Vector3(L * 0.75 + 0.6, 0.12, pan2_l), tuile, Vector3(0, y_2 + monte * 0.25 + monte2 * 0.5, c * (P * 0.3 + deb2) * 0.5))
		pan2.rotation.x = c * incl2
		_bloc(t, Vector3(L * 0.75 + 0.6, 0.06, 0.08), dore, Vector3(0, y_2 + monte * 0.25 - 0.02, c * (P * 0.3 + deb2)))
		for cz: int in [-1, 1]:
			var coin2 := MeshInstance3D.new()
			var cc2 := CylinderMesh.new()
			cc2.top_radius = 0.0
			cc2.bottom_radius = 0.08
			cc2.height = 0.55
			coin2.mesh = cc2
			coin2.material_override = dore
			coin2.position = Vector3(c * (L * 0.375 + 0.4), y_2 + monte * 0.25 + 0.12, cz * (P * 0.3 + deb2))
			coin2.rotation = Vector3(cz * 0.8, 0, -c * 0.8)
			t.add_child(coin2)
	monte = monte * 0.25 + monte2 + (y_2 - y_t)
	_bloc(t, Vector3(L * 0.75 + 0.2, 0.2, 0.24), tuile, Vector3(0, y_t + monte + 0.06, 0))
	for c: int in [-1, 1]:
		# Au bout du faîtage, une queue de dragon qui s'enroule vers le haut.
		var queue := MeshInstance3D.new()
		var cq := CylinderMesh.new()
		cq.top_radius = 0.0
		cq.bottom_radius = 0.11
		cq.height = 0.6
		queue.mesh = cq
		queue.material_override = tuile
		queue.position = Vector3(c * (L * 0.375 + 0.2), y_t + monte + 0.3, 0)
		queue.rotation.z = -c * 0.5
		t.add_child(queue)
		for cz: int in [-1, 1]:
			var coin := MeshInstance3D.new()
			var cc := CylinderMesh.new()
			cc.top_radius = 0.0
			cc.bottom_radius = 0.14
			cc.height = 0.95
			coin.mesh = cc
			coin.material_override = dore
			coin.position = Vector3(c * (L * 0.5 + 0.75), y_t + 0.22, cz * (P * 0.5 + deb))
			coin.rotation = Vector3(cz * 0.85, 0, -c * 0.85)
			t.add_child(coin)
	# Un paravent ajouré au fond, derrière l'autel : il cadre la pierre et coupe la vue sur la forêt.
	_bloc(t, Vector3(L - 0.7, 2.2, 0.08), bois, Vector3(0, H + 1.1, P * 0.5 - 0.3))
	for k in 7:
		_bloc(t, Vector3(0.05, 2.0, 0.1), laque, Vector3(-1.8 + k * 0.6, H + 1.1, P * 0.5 - 0.36))
	for k in 4:
		_bloc(t, Vector3(L - 0.8, 0.05, 0.1), laque, Vector3(0, H + 0.35 + k * 0.5, P * 0.5 - 0.36))
	# La balustrade : sur les côtés et de part et d'autre de l'escalier.
	var cotes := [[Vector3(-L * 0.5 + 0.08, 0, -P * 0.5 + 0.3), Vector3(-L * 0.5 + 0.08, 0, P * 0.5 - 0.3)],
		[Vector3(L * 0.5 - 0.08, 0, -P * 0.5 + 0.3), Vector3(L * 0.5 - 0.08, 0, P * 0.5 - 0.3)],
		[Vector3(-L * 0.5 + 0.3, 0, -P * 0.5 + 0.08), Vector3(-MARCHES_LARGE * 0.5 + 0.12, 0, -P * 0.5 + 0.08)],
		[Vector3(MARCHES_LARGE * 0.5 - 0.12, 0, -P * 0.5 + 0.08), Vector3(L * 0.5 - 0.3, 0, -P * 0.5 + 0.08)]]
	for c: Array in cotes:
		var a: Vector3 = c[0]
		var b: Vector3 = c[1]
		var m := (a + b) * 0.5
		var lg := a.distance_to(b)
		var le_long := absf(b.z - a.z) > absf(b.x - a.x)
		var taille := Vector3(0.07, 0.07, lg) if le_long else Vector3(lg, 0.07, 0.07)
		_bloc(t, taille, laque, m + Vector3(0, H + 0.62, 0))
		_bloc(t, taille, laque, m + Vector3(0, H + 0.18, 0))
		var nb := int(lg / 0.3)
		for k in nb + 1:
			_bloc(t, Vector3(0.04, 0.44, 0.04), laque, a.lerp(b, float(k) / maxf(1.0, nb)) + Vector3(0, H + 0.4, 0))
		_obstacle(t, Ronde.boite(taille + Vector3(0.1, 0.9, 0.1) * Vector3(1, 1, 1)), m + Vector3(0, H + 0.45, 0))
	# Deux lanternes de papier rouge, pendues à la poutre de façade.
	for c: int in [-1, 1]:
		var lanterne := Node3D.new()
		lanterne.position = Vector3(c * 1.15, y_p - 0.75, -P * 0.5 + 0.3)
		t.add_child(lanterne)
		var papier := Bouille.materiau(Color(0.75, 0.12, 0.06), 0.0, Color(1.0, 0.35, 0.12))
		papier.emission_energy_multiplier = 0.9
		lanterne.add_child(Bouille.sphere(0.2, papier, Vector3(1.0, 1.3, 1.0)))
		# Les cerceaux de bambou sous le papier : sans eux, une boule orange sans relief.
		var cerceau := Bouille.materiau(Color(0.22, 0.05, 0.03), 0.0)
		for k in 5:
			var y := (k - 2) * 0.085
			var r := 0.2 * sqrt(maxf(0.0, 1.0 - pow(y / 0.26, 2.0))) + 0.003
			var tm := TorusMesh.new()
			tm.inner_radius = r - 0.006
			tm.outer_radius = r + 0.006
			tm.rings = 24
			var mi := MeshInstance3D.new()
			mi.mesh = tm
			mi.material_override = cerceau
			mi.position.y = y
			lanterne.add_child(mi)
		_bloc(lanterne, Vector3(0.22, 0.05, 0.22), dore, Vector3(0, 0.27, 0))
		_bloc(lanterne, Vector3(0.18, 0.05, 0.18), dore, Vector3(0, -0.27, 0))
		_bloc(lanterne, Vector3(0.015, 0.45, 0.015), bois, Vector3(0, 0.5, 0))
		var lueur := OmniLight3D.new()
		lueur.light_color = Color(1.0, 0.4, 0.2)
		lueur.omni_range = 4.5
		lanterne.add_child(lueur)
		_bougies.append(lueur)
	# Deux braseros en haut des marches, sur la terrasse (Edwin, 29/10 : « des flammes, pas des
	# lampes »). Au pied, ils barraient la ruelle du sentier des quêtes dans un petit village.
	var fer := Bouille.materiau(Color(0.12, 0.12, 0.13), 0.01)
	fer.metallic = 0.7
	fer.roughness = 0.5
	for c: int in [-1, 1]:
		_brasero(t.position + Vector3(c * (L * 0.5 - 0.65), H, -P * 0.5 + 0.75), fer)
	# L'autel, sur la terrasse.
	_autel = Node3D.new()
	_autel.position = Vector3(0, H, 0)
	t.add_child(_autel)
	_sur = _autel
	_contenu_autel()
	_sur = self


## Un pavé de matière `mat`, posé dans `parent`.
func _bloc(parent: Node3D, taille: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	m.mesh = b
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m

func _maison(i: int) -> void:
	var n := Node3D.new()
	n.position = centre_maison(i)
	n.rotation.y = angle_maison(i) + PI
	add_child(n)
	_maisons.append(n)
	var penche := Node3D.new()        # la maison de guingois (discret : les murs sont lourds)
	penche.rotation.z = _rng.randf_range(-0.02, 0.02)
	penche.rotation.x = _rng.randf_range(-0.012, 0.012)
	n.add_child(penche)
	var dx := LARGEUR * 0.5
	var dz := PROFONDEUR * 0.5
	var mur: Color = MURS[i % MURS.size()].lightened(0.3).darkened(_rng.randf() * 0.1)
	var pre := "Wall_UnevenBrick_" if _rng.randf() < 0.45 else "Wall_Plaster_"
	_verre = _verre_neuf()
	_fenetres.append(_verre)
	var fen_n := pre + "Window_Wide_Flat"
	var etroit := Vector3(0.75, 1, 1)      # une fenêtre est un module de mur resserré à 1,5 m
	var z_av := dz - 0.09                   # le module a sa face extérieure à +0,09 de son origine
	var z_ar := -dz + 0.09
	var x_cote := dx - 0.06 - 0.09          # murs latéraux : un rien en retrait des angles
	var fens: Array = []                    # [position locale, direction vers l'intérieur, largeur]
	# --- Façade : fenêtre, porte, fenêtre.
	for cote: int in [-1, 1]:
		var p := Vector3(cote * 1.75, 0, z_av)
		fens.append([Vector3(cote * 1.75, 0, dz), Vector3(0, 0, -1), 1.1])
		_modele(fen_n, penche, p, 0.0, etroit, mur)
		_modele("Window_Wide_Flat1", penche, p, 0.0, etroit, mur)
		if cote == 1 and _rng.randf() < 0.45:     # des volets clos : la maison se referme sur ce qu'elle cache
			_modele("WindowShutters_Wide_Flat_Closed", penche, p, 0.0, etroit, mur)
	_modele(pre + "Door_Flat", penche, Vector3(0, 0, z_av), 0.0, Vector3.ONE, mur)
	# --- Arrière : mur plein au centre, et de part et d'autre un mur plein ou une fenêtre.
	for cote: int in [-1, 1]:
		var p := Vector3(cote * 1.75, 0, z_ar)
		if _rng.randf() < 0.3:
			fens.append([Vector3(cote * 1.75, 0, -dz), Vector3(0, 0, 1), 1.1])
			_modele(fen_n, penche, p, PI, etroit, mur)
			_modele("Window_Wide_Flat1", penche, p, PI, etroit, mur)
		else:
			_modele(pre + "Straight", penche, p, PI, etroit, mur)
	# (Plus de porte de derrière, décision d'Edwin du 01/11 : un mur plein ; on entre et sort par la façade.)
	_modele(pre + "Straight", penche, Vector3(0, 0, z_ar), PI, Vector3.ONE, mur)
	# --- Côtés : deux modules de 2 m chacun.
	for cote: int in [-1, 1]:
		for k: int in [-1, 1]:
			var p := Vector3(cote * x_cote, 0, k)
			if _rng.randf() < 0.35:
				fens.append([Vector3(cote * dx, 0, k), Vector3(-cote, 0, 0), 1.45])
				_modele(fen_n, penche, p, cote * PI * 0.5, Vector3.ONE, mur)
				_modele("Window_Wide_Flat1", penche, p, cote * PI * 0.5, Vector3.ONE, mur)
			else:
				_modele(pre + "Straight", penche, p, cote * PI * 0.5, Vector3.ONE, mur)
	# --- Poteaux d'angle.
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			_modele("Corner_Exterior_Wood", penche, Vector3(sx * dx, 0, sz * dz), 0.0, Vector3.ONE, mur)
	# --- Collisions des murs : la porte (1,3 m) reste libre, sous son linteau.
	for face: int in [1, -1]:
		var zc := face * (dz - EPAIS * 0.5)
		for cote: int in [-1, 1]:
			murs_maisons.append(_obstacle(penche, Ronde.boite(Vector3(dx - 0.65, HAUTEUR, EPAIS)), Vector3(cote * (dx + 0.65) * 0.5, HAUTEUR * 0.5, zc)))
		if face == 1:
			murs_maisons.append(_obstacle(penche, Ronde.boite(Vector3(1.3, HAUTEUR - 2.2, EPAIS)), Vector3(0, (2.2 + HAUTEUR) * 0.5, zc)))
		else:
			murs_maisons.append(_obstacle(penche, Ronde.boite(Vector3(1.3, HAUTEUR, EPAIS)), Vector3(0, HAUTEUR * 0.5, zc)))   # mur plein derrière
	for cote: int in [-1, 1]:
		murs_maisons.append(_obstacle(penche, Ronde.boite(Vector3(EPAIS, HAUTEUR, PROFONDEUR - 0.2)), Vector3(cote * (dx - 0.06 - EPAIS * 0.5), HAUTEUR * 0.5, 0)))
	# --- Un numéro gravé au-dessus de chaque porte : jamais de nom, l'Herboriste n'apprend que lui.
	for face: int in [1]:
		var chiffre := Label3D.new()
		chiffre.text = CHIFFRES[i]
		chiffre.font = Style.police("titre")
		chiffre.font_size = 64
		chiffre.outline_size = 10
		chiffre.pixel_size = 0.004
		chiffre.visibility_range_begin = 2.2   # collé à la porte, le chiffre couvrait l'écran
		chiffre.modulate = Color(0.78, 0.7, 0.58)
		chiffre.outline_modulate = Color(0.08, 0.05, 0.04)
		chiffre.position = Vector3(0, 2.62, (dz + 0.12) * face)
		chiffre.rotation.y = 0.0 if face == 1 else PI
		penche.add_child(chiffre)
		if not _chiffres.has(i):
			_chiffres[i] = []
		_chiffres[i].append(chiffre)
	# --- Plancher (six dalles de bois sombre), plafond, toit.
	for fx: int in [-1, 0, 1]:
		for fz: int in [-1, 1]:
			if fx == 0:
				_modele("Floor_WoodDark", penche, Vector3(0, 0.045, fz), 0.0, Vector3.ONE, mur)
			else:   # les dalles de rive s'arrêtent sous le mur (elles dépassaient de 45 cm : une dalle noire à plat dehors)
				_modele("Floor_WoodDark", penche, Vector3(fx * 1.65, 0.045, fz), 0.0, Vector3(0.7, 1, 1), mur)
	var plafond := _boite(Vector3(LARGEUR - 0.5, 0.05, PROFONDEUR - 0.5), Color(0.15, 0.12, 0.1))
	plafond.position.y = HAUTEUR - 0.03
	plafond.material_override = Interieur.mat_poutre()
	penche.add_child(plafond)
	var toit := _modele("Roof_RoundTiles_4x6", penche, Vector3(0, HAUTEUR + 0.26, 0), PI * 0.5, Vector3(0.85, 0.85, 0.76), mur)
	toit.rotation.x = _rng.randf_range(-0.012, 0.012)         # le toit s'affaisse d'un côté
	for cote: int in [-1, 1]:                                  # les pignons, sous les rives du toit
		_modele("Roof_Front_Brick4", penche, Vector3(cote * (dx - 0.06), HAUTEUR + 0.26, 0), cote * PI * 0.5, Vector3(1, 0.85, 1), mur)
	_sablieres(penche)
	if _rng.randf() < 0.65:                                    # cheminée
		var sens: int = [-1, 1][_rng.randi() % 2]
		_modele("Prop_Chimney2" if pre.contains("Brick") else "Prop_Chimney", penche, Vector3(sens * 1.5, HAUTEUR - 0.1, -0.9), 0.0, Vector3.ONE * 0.9, mur)
	if _rng.randf() < 0.6:                                     # du lierre qui descend de la gouttière
		var sens: int = [-1, 1][_rng.randi() % 2]
		_modele("Prop_Vine1" if _rng.randf() < 0.5 else "Prop_Vine4", penche, Vector3(sens * 2.3, HAUTEUR - 0.2, dz + 0.04), 0.0, Vector3.ONE, mur)
	# --- Intérieur : lit, table, bougie, parfois une caisse.
	var le_lit := Node3D.new()      # étiquetés « meuble » : tests/test_interieur.gd vérifie que rien ne se chevauche
	le_lit.name = "Lit"
	le_lit.set_meta("meuble", "Lit")
	penche.add_child(le_lit)
	var lit_n := _boite(Vector3(1.0, 0.45, 1.9), Color(0.35, 0.26, 0.2))
	lit_n.position = Vector3(1.4, 0.23, -0.6)
	lit_n.material_override = Interieur.mat_poutre()
	le_lit.add_child(lit_n)
	var drap := _boite(Vector3(0.95, 0.12, 1.4), Color(0.38, 0.35, 0.3))
	drap.position = Vector3(1.4, 0.5, -0.4)
	drap.material_override = Interieur.mat_laine()
	le_lit.add_child(drap)
	_obstacle(penche, Ronde.boite(Vector3(1.0, 0.58, 1.9)), Vector3(1.4, 0.29, -0.6))   # jusqu'au traversin : un livre jeté dessus s'y pose
	var la_table := Node3D.new()
	la_table.name = "Table"
	la_table.set_meta("meuble", "Table")
	penche.add_child(la_table)
	var table := _boite(Vector3(0.9, 0.06, 0.7), Color(0.3, 0.22, 0.15))
	table.position = Vector3(-1.4, 0.75, -1.2)
	la_table.add_child(table)
	for pied in [Vector2(-0.38, -0.28), Vector2(0.38, -0.28), Vector2(-0.38, 0.28), Vector2(0.38, 0.28)]:
		var pd := _boite(Vector3(0.06, 0.75, 0.06), Color(0.28, 0.2, 0.14))
		pd.position = Vector3(-1.4 + pied.x, 0.37, -1.2 + pied.y)
		la_table.add_child(pd)
	_obstacle(penche, Ronde.boite(Vector3(0.9, 0.8, 0.7)), Vector3(-1.4, 0.4, -1.2))   # Edwin, 31/10 : on la traversait
	var cire := _boite(Vector3(0.07, 0.18, 0.07), Color(0.85, 0.82, 0.7))
	cire.position = Vector3(-1.4, 0.87, -1.2)
	la_table.add_child(cire)
	var flamme := Bouille.sphere(0.035, Bouille.materiau(Color(1, 0.7, 0.3), 0.0, Color(1, 0.55, 0.15)), Vector3(1, 1.7, 1))
	flamme.position = Vector3(-1.4, 1.0, -1.2)
	penche.add_child(flamme)
	var bougie := OmniLight3D.new()
	bougie.light_color = Color(1.0, 0.6, 0.3)
	bougie.omni_range = 3.5
	bougie.shadow_enabled = true
	bougie.position = Vector3(-1.4, 1.05, -1.2)
	penche.add_child(bougie)
	_bougies.append(bougie)
	_bougie_chambre[i] = bougie
	_flamme_chambre[i] = flamme
	# La lampe de la chambre : éteinte le jour, la pièce est éclairée la nuit.
	var lampe := OmniLight3D.new()
	lampe.light_color = Color(1.0, 0.68, 0.38)
	lampe.omni_range = 3.4
	lampe.light_energy = 0.0
	lampe.position = Vector3(0, 2.45, 0)
	penche.add_child(lampe)
	_lampes.append(lampe)
	# La nuit, la lumière des fenêtres déborde dehors (Edwin, 01/11 : « les lumières des maisons doivent
	# faire plus de lumière ») : une lueur chaude par façade percée, sans ombre, qui éclaire la ruelle.
	var cotes_percees := {}
	for fen: Array in fens:
		var sortie: Vector3 = -(fen[1] as Vector3)
		var cle := Vector2i(int(roundf(sortie.x)), int(roundf(sortie.z)))
		if not cotes_percees.has(cle):
			cotes_percees[cle] = []
		(cotes_percees[cle] as Array).append(fen[0])
	for cle: Vector2i in cotes_percees:
		var moy := Vector3.ZERO
		for q: Vector3 in cotes_percees[cle]:
			moy += q
		moy /= float((cotes_percees[cle] as Array).size())
		var halo_f := OmniLight3D.new()
		halo_f.light_color = Color(1.0, 0.64, 0.34)
		halo_f.omni_range = 6.5
		halo_f.omni_attenuation = 1.4
		halo_f.shadow_enabled = false
		halo_f.position = moy + Vector3(cle.x, 0.0, cle.y) * 1.3 + Vector3(0, 1.5, 0)
		halo_f.set_meta("base", 0.8)
		penche.add_child(halo_f)
		_bougies.append(halo_f)
	_poser_rideaux(i, penche, fens)
	for feu in Interieur.meubler(penche, i, fens):     # l'intérieur : plancher, murs, poutres, âtre, objets
		_bougies.append(feu)
	if _rng.randf() < 0.5:
		var caisse := _modele("Prop_Crate", penche, Vector3(1.65, 0.045, 1.3), _rng.randf_range(-0.4, 0.4), Vector3.ONE * 0.6, mur)
		caisse.name = "Caisse"
		caisse.set_meta("meuble", "Caisse")
		_obstacle(penche, Ronde.boite(Vector3(0.65, 0.65, 0.65)), Vector3(1.65, 0.33, 1.3))
	# --- La seule porte : celle de devant.
	_porte(i, penche, "avant", dz)
	# --- Clôture cassée du jardin, derrière.
	for k in 3:
		if _rng.randf() < 0.3:
			continue
		var piquet := _modele("Prop_WoodenFence_Single", n, Vector3(-2.1 + k * 2.1, 0, -dz - 2.2), _rng.randf_range(-0.12, 0.12), Vector3.ONE, mur)
		piquet.rotation.z = _rng.randf_range(-0.2, 0.2)
		# Pas de collision sur ces clôtures : elles bordent le chemin de ronde (essai --essai-monde=…|marche :
		# avec, 100 blocages à r = 19,4 m, la marche autour du village était coupée).


## Les sablières : une poutre sombre qui comble la fente entre le haut des murs latéraux (y = 3,12) et le
## bas du pignon (y = 3,27) : à hauteur d'yeux, on voyait le ciel au travers de la maison, d'un pignon à
## l'autre (Edwin, 01/11 : « de l'espace entre les murs »). Même bois que les poutres du plafond.
func _sablieres(penche: Node3D) -> void:
	var dx := LARGEUR * 0.5
	for cote: int in [-1, 1]:
		var b := _bloc(penche, Vector3(0.5, 0.2, PROFONDEUR), Interieur.mat_poutre(), Vector3(cote * (dx - 0.25), HAUTEUR + 0.07, 0))
		b.name = "Sabliere"


## La porte : un panneau du pack, accroché par un gond au bord de l'ouverture, qui s'ouvre
## vers l'intérieur de la maison. Le repère `sup` regarde vers l'extérieur de la face
## (il est tourné de 180° sur la face arrière) : dedans, on ouvre toujours dans le même sens.
func _porte(i: int, maison: Node3D, quelle: String, z: float) -> void:
	var signe := 1.0 if quelle == "avant" else -1.0
	var sup := Node3D.new()
	sup.position = Vector3(0, 0, z - signe * 0.2)      # le milieu de l'épaisseur du mur
	sup.rotation.y = 0.0 if quelle == "avant" else PI
	maison.add_child(sup)
	var pivot := Node3D.new()
	pivot.position = Vector3(-0.6, 0, 0)               # le gond, juste contre le montant gauche
	sup.add_child(pivot)
	var nom := "Door_%d_Flat" % [2, 4, 8][_rng.randi() % 3]
	_modele(nom, pivot, Vector3.ZERO, 0.0, Vector3(1.2, 1, 1), MURS[i % MURS.size()])   # 1,07 m → l'ouverture de 1,3 m
	for v in volets_de_porte(nom):
		pivot.add_child(v)
	var corps := StaticBody3D.new()
	corps.collision_layer = COUCHE_PORTE_AVANT if quelle == "avant" else COUCHE_PORTE_ARRIERE
	var forme := CollisionShape3D.new()
	forme.shape = Ronde.boite(Vector3(1.36, 2.15, 0.26))
	forme.position = Vector3(0.64, 1.08, 0)
	corps.add_child(forme)
	pivot.add_child(corps)
	_portes["%d:%s" % [i, quelle]] = {"pivot": pivot, "forme": forme, "ouverte": false}


## Deux modèles de porte ont une lucarne à barreaux, et l'on voyait dedans (Edwin, 30/10 : « les
## joueurs ne doivent pas voir ») : un volet de bois plein la bouche, dans l'épaisseur du battant.
static func volets_de_porte(nom: String) -> Array[MeshInstance3D]:
	var r: Array[MeshInstance3D] = []
	var tailles := {"Door_2_Flat": Vector3(0.48, 0.48, 0.05), "Door_8_Flat": Vector3(0.72, 0.38, 0.05)}
	var milieux := {"Door_2_Flat": Vector3(0.63, 1.5, -0.03), "Door_8_Flat": Vector3(0.66, 1.53, -0.03)}   # charnière à gauche
	if not tailles.has(nom):
		return r
	var v := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tailles[nom]
	v.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.13, 0.08)
	m.roughness = 0.95
	v.material_override = m
	v.position = milieux[nom]
	r.append(v)
	return r


func _chemin_de_ronde() -> void:
	var couleurs := {"graviers": Color(0.42, 0.41, 0.4), "planches": Color(0.33, 0.25, 0.18),
		"flaques": Color(0.2, 0.19, 0.16), "feuilles": Color(0.4, 0.26, 0.13), "terre": Color(0.3, 0.24, 0.18)}
	# Le dessous de chaque secteur : on doit reconnaître le sol à l'œil comme à l'oreille.
	var dessous := {
		"graviers": _mat_tex("cobblestone_floor_08", 0.8, Color(0.5, 0.5, 0.5)),
		"planches": _mat_tex("brown_mud_leaves_01", 0.4, Color(0.3, 0.26, 0.22)),
		"flaques": _mat_tex("brown_mud_leaves_01", 0.4, Color(0.26, 0.24, 0.22)),
		"feuilles": _mat_tex("brown_mud_leaves_01", 0.4, Color(0.78, 0.55, 0.38)),
		"terre": _mat_tex("brown_mud_leaves_01", 0.4, Color(0.5, 0.42, 0.34)),
	}
	var mat_gravier := _mat_tex("cobblestone_floor_08", 3.0, Color(0.5, 0.5, 0.48))
	var largeur := R_CHEMIN_MAX - R_CHEMIN_MIN
	var r := (R_CHEMIN_MIN + R_CHEMIN_MAX) * 0.5
	for s in 24:
		var sol: String = SOLS[s]
		var a0 := s * TAU / 24.0
		add_child(_secteur(a0, a0 + TAU / 24.0, dessous[sol], 0.02))
		for k in 26:
			var a := a0 + _rng.randf() * TAU / 24.0
			var d := _rng.randf_range(R_CHEMIN_MIN + 0.2, R_CHEMIN_MAX - 0.2)
			var p := Vector3(sin(a) * d, 0, cos(a) * d)
			match sol:
				"graviers":
					var g := Bouille.sphere(_rng.randf_range(0.06, 0.13), mat_gravier, Vector3(1, 0.55, 1))
					g.position = p + Vector3(0, 0.04, 0)
					add_child(g)
				"feuilles":
					var f := _boite(Vector3(0.22, 0.015, 0.14), couleurs["feuilles"].lerp(Color(0.5, 0.35, 0.1), _rng.randf()))
					f.position = p + Vector3(0, 0.04, 0)
					f.rotation.y = _rng.randf() * TAU
					add_child(f)
				"flaques":
					if k % 5 == 0:
						var fl := Bouille.sphere(_rng.randf_range(0.5, 0.9), _mat_eau(), Vector3(1.4, 0.01, 1))
						fl.position = p + Vector3(0, 0.035, 0)
						fl.rotation.y = _rng.randf() * TAU
						add_child(fl)
		if sol == "planches":
			for k in 14:
				var a := a0 + (k + 0.5) * TAU / 24.0 / 14.0
				var pl := _boite(Vector3(0.32, 0.06, largeur * 0.8), couleurs["planches"].darkened(_rng.randf() * 0.3))
				pl.material_override = _mat_planches()
				pl.position = Vector3(sin(a) * r, 0.05, cos(a) * r)
				pl.rotation.y = a
				pl.rotation.z = _rng.randf_range(-0.04, 0.04)
				add_child(pl)


func _mat_eau() -> StandardMaterial3D:
	var m := Bouille.materiau(Color(0.06, 0.08, 0.09), 0.0)
	m.roughness = 0.05
	m.metallic = 0.6
	return m


func _orienter_vers_centre(n: Node3D, p: Vector3) -> void:
	n.position = p
	n.rotation.y = atan2(p.x, p.z) + PI




func _cimetiere() -> void:
	var c := lieu("cimetiere")
	var n := Node3D.new()
	_orienter_vers_centre(n, c)
	add_child(n)
	# Muret écroulé et grille.
	for k in 16:
		if _rng.randf() < 0.25:
			continue
		var a := k * TAU / 16.0
		var bloc := _boite(Vector3(1.0, _rng.randf_range(0.3, 0.8), 0.3), Color(0.35, 0.35, 0.36))
		bloc.position = Vector3(sin(a) * 5.0, 0.3, cos(a) * 5.0)
		bloc.rotation.y = a
		n.add_child(bloc)
	# Vieilles tombes anonymes, au fond.
	for k in 7:
		var vieille := _boite(Vector3(0.55, _rng.randf_range(0.5, 0.9), 0.14), Color(0.3, 0.31, 0.3))
		vieille.position = Vector3(_rng.randf_range(-3.5, 3.5), 0.35, _rng.randf_range(-4.0, -2.8))
		vieille.rotation = Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.25, 0.25))
		n.add_child(vieille)
	var arbre_mort := _boite(Vector3(0.3, 3.5, 0.3), Color(0.15, 0.13, 0.12))
	arbre_mort.position = Vector3(3.2, 1.75, -3.0)
	arbre_mort.rotation.z = 0.2
	n.add_child(arbre_mort)
	for k in 3:
		var branche := _boite(Vector3(0.12, 1.6, 0.12), Color(0.15, 0.13, 0.12))
		branche.position = Vector3(3.4 + k * 0.2, 2.6 + k * 0.4, -3.0)
		branche.rotation.z = -0.9 + k * 0.7
		n.add_child(branche)
	postes["cimetiere"] = c + (-c.normalized()) * 2.0



func _foret() -> void:
	var clairieres := []
	for l in LIEUX:
		clairieres.append(lieu(l))
	for l in PETITS_LIEUX:
		clairieres.append(petit_lieu(l))
	for k in Quetes.ANGLES_ZONES.size():
		clairieres.append(Quetes.zone(k))
	var nb := 0
	while nb < 190:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(R_CHEMIN_MAX + 1.2, r_lisiere(a) + 9.0)
		var p := Vector3(sin(a) * d, 0, cos(a) * d)
		var libre := true
		for c in clairieres:
			if p.distance_to(c) < 7.5:
				libre = false
		if p.distance_to(POS_CHARRETTE) < 5.0 or _dans_passage(p, 3.2):
			libre = false
		if not libre:
			continue
		_arbre(p, _rng.randf_range(1.0, 1.8), 0.12 if d < r_lisiere(a) - 1.0 else 0.0)
		nb += 1
	# Mur invisible au bord du village (ouvert aux trois passages de quête), et un second plus loin.
	for k in 72:
		var a := k * TAU / 72.0
		var c2 := StaticBody3D.new()
		var f2 := CollisionShape3D.new()
		f2.shape = Ronde.boite(Vector3(4.8, 4, 1))
		c2.add_child(f2)
		c2.position = Vector3(sin(a), 0, cos(a)) * (R_LIMITE_QUETE + 1.0) + Vector3(0, 2, 0)
		c2.rotation.y = a
		add_child(c2)
	for k in 96:
		var a := k * TAU / 96.0
		if _dans_passage(Vector3(sin(a), 0, cos(a)) * (r_limite(a) + 1.0), 2.6):
			continue
		var c := StaticBody3D.new()
		var f := CollisionShape3D.new()
		f.shape = Ronde.boite(Vector3(TAU * (r_limite(a) + 1.0) / 96.0 + 0.6, 4, 1))
		c.add_child(f)
		c.position = Vector3(sin(a), 0, cos(a)) * (r_limite(a) + 1.0) + Vector3(0, 2, 0)
		c.rotation.y = a
		add_child(c)


## Les buttes couvertes d'arbres : on ne voit plus jamais le bout du monde. Un MultiMesh par
## variante (aucune collision : personne ne va jusque-là), et de jeunes sapins sombres entre eux.
func _foret_lointaine() -> void:
	var paquets := []
	for k in Arbres.NB:
		paquets.append([])
	var nb := 0
	var essais := 0
	while nb < 760 and essais < 6000:
		essais += 1
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(Terre.R_BUTTES - 2.0, 128.0)
		var p := Vector3(sin(a) * d, 0, cos(a) * d)
		var proche := false
		for kz in Quetes.ANGLES_ZONES.size():
			if p.distance_to(Quetes.zone(kz)) < 23.0:
				proche = true
		if proche:
			continue
		p.y = Terre.hauteur(p.x, p.z) - 0.1
		var k := _rng.randi_range(0, 4) if _rng.randf() < 0.55 else _rng.randi_range(5, Arbres.NB - 1)
		var t := _rng.randf_range(1.3, 2.5)
		paquets[k].append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).rotated(Vector3.RIGHT, _rng.randf_range(-0.08, 0.08)).scaled(Vector3.ONE * t), p))
		if nb % 2 == 0:
			# Un jeune sapin entre les grands : un vrai sapin, petit (plus de cône noir).
			var q := p + Vector3(_rng.randf_range(-2.0, 2.0), 0, _rng.randf_range(-2.0, 2.0))
			q.y = Terre.hauteur(q.x, q.z) - 0.1
			paquets[_rng.randi_range(5, Arbres.NB - 1)].append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.55, 0.95)), q))
		nb += 1
	for k in Arbres.NB:
		var liste: Array = paquets[k]
		if liste.is_empty():
			continue
		var d := Arbres.variante(k)
		for part in ["tronc", "aiguilles"]:
			if d[part] == null:
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = d[part]
			mm.instance_count = liste.size()
			for i in liste.size():
				mm.set_instance_transform(i, liste[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = _mat_arbre if part == "tronc" else _mat_aiguilles
			add_child(mmi)


## Les buttes au-delà de la lisière ne sont plus une terre nue (Edwin, 30/10 : « ça fait vide ») :
## rochers moussus et blocs de pierre, troncs couchés, souches, racines, fougères, orties et
## branches mortes, semés entre les arbres lointains. Rien n'a de collision : personne n'y va.
func _plaine() -> void:
	var lots := {"rock_moss_set_01": [180, 1.2, 2.6], "rock_moss_set_02": [180, 1.2, 2.6], "boulder_01": [60, 1.0, 2.2],
		"stone_01": [80, 1.5, 3.0], "coast_rocks_01": [26, 0.8, 1.4], "dead_tree_trunk": [40, 1.0, 1.6],
		"dead_tree_trunk_02": [40, 1.0, 1.6], "tree_stump_01": [50, 1.0, 1.6], "tree_stump_02": [50, 1.0, 1.6],
		"root_cluster_01": [40, 1.0, 1.8], "fern_02": [420, 1.4, 2.6], "nettle_plant": [220, 1.3, 2.2],
		"dry_branches_medium_01": [140, 1.2, 2.0]}
	for nom in lots:
		var l: Array = lots[nom]
		var points := []
		var essais := 0
		while points.size() < int(l[0]) and essais < int(l[0]) * 8:
			essais += 1
			var a := _rng.randf() * TAU
			var d := _rng.randf_range(R_LISIERE + 9.0, 118.0)
			var pt := Vector3(sin(a) * d, 0, cos(a) * d)
			var pres := false
			for kz in Quetes.ANGLES_ZONES.size():
				if pt.distance_to(Quetes.zone(kz)) < 24.0:
					pres = true
			if pres or _dans_passage(pt, 4.0):
				continue
			var e := _rng.randf_range(float(l[1]), float(l[2]))
			# Enfoncé un peu dans la pente, pour ne jamais flotter.
			pt.y = Terre.hauteur(pt.x, pt.z) - 0.15 * e
			points.append([pt, e, _rng.randf() * TAU])
		Terre.semer(self, nom, points)


## Les sentiers de terre battue, de la place à chaque clairière (demande d'Edwin, 29/10) : un
## ruban aux bords rongés, bordé de pierres au-delà du chemin de ronde, deux lanternes sur poteau.
func _sentiers() -> void:
	var mat := Terre.mat_sentier()
	var pierres := []
	for k in Quetes.ANGLES_ZONES.size():
		add_child(Terre.ruban_sentier(k, mat, R_PLACE - 0.6 if k == 0 else Quetes.R_FOURCHE - 0.5))
		var r := R_CHEMIN_MAX + 0.6 if k == 0 else Quetes.R_FOURCHE + 0.5
		while r < Quetes.R_ZONE - 4.6:
			var m := Terre.sentier(k, r)
			var t := (Terre.sentier(k, r + 0.1) - m).normalized().cross(Vector3.UP)
			for cote: int in [-1, 1]:
				if _rng.randf() < 0.6 and absf(r - (R_LISIERE + 0.7)) > 0.8:
					pierres.append([m + t * cote * (Terre.LARGEUR_SENTIER * 0.5 + _rng.randf_range(0.0, 0.25)) + Vector3(0, -0.05, 0),
						_rng.randf_range(0.07, 0.15), _rng.randf() * TAU])
			r += _rng.randf_range(0.6, 1.2)
		var lanternes: Array = [[R_CHEMIN_MAX + 1.5, 1], [Quetes.R_FOURCHE - 1.2, -1]] if k == 0 else []
		lanternes.append([Quetes.R_FOURCHE + 13.0, 1 if k % 2 == 0 else -1])
		for q: Array in lanternes:
			_lanterne_de_sentier(k, q[0], q[1])
	Terre.semer(self, "rock_moss_set_02", pierres)


func _lanterne_de_sentier(k: int, r: float, cote: int) -> void:
	var m := Terre.sentier(k, r)
	var t := (Terre.sentier(k, r + 0.1) - m).normalized().cross(Vector3.UP)
	# La lanterne pend au bord du sentier, pas au-dessus : on passait la tête dedans (Edwin, 31/10).
	var pied := m + t * cote * (Terre.LARGEUR_SENTIER * 0.5 + 0.95)
	var n := Node3D.new()
	n.position = pied
	add_child(n)
	var bois := _mat_ecorce()
	var poteau := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.05
	cy.bottom_radius = 0.075
	cy.height = 2.3
	poteau.mesh = cy
	poteau.material_override = bois
	poteau.position.y = 1.1
	poteau.rotation.z = _rng.randf_range(-0.05, 0.05)
	n.add_child(poteau)
	var bras := _boite(Vector3(0.06, 0.06, 0.6), Color.WHITE)
	bras.material_override = bois
	var vers := -t * cote
	bras.position = Vector3(0, 2.15, 0) + vers * 0.28
	bras.look_at_from_position(bras.position, bras.position + vers, Vector3.UP)
	n.add_child(bras)
	var bout := Vector3(0, 2.1, 0) + vers * 0.55
	for piece: Array in Terre.maillages("wooden_lantern_01"):
		var mi := MeshInstance3D.new()
		mi.mesh = piece[0]
		mi.transform = Transform3D(Basis.IDENTITY, bout + Vector3(0, -0.45, 0)) * (piece[1] as Transform3D)
		n.add_child(mi)
	var flamme := Bouille.sphere(0.03, _braises, Vector3(1, 1.8, 1))
	flamme.position = bout + Vector3(0, -0.28, 0)
	n.add_child(flamme)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.62, 0.3)
	l.omni_range = 5.5
	l.position = bout + Vector3(0, -0.3, 0)
	n.add_child(l)
	_torches.append(l)
	_obstacle(n, Ronde.cylindre(0.1, 2.2), Vector3(0, 1.1, 0))


## Le tapis du sous-bois : herbes, fougères, pierres moussues, branches mortes, feuilles,
## champignons. Partout où l'on ne marche pas trop : ni dans les maisons, ni sur les sentiers,
## ni dans les lieux. Autour d'une clairière, un tapis à part (« sol_de_clairiere ») qu'un décor
## qui déborde peut cacher.
func _sous_bois() -> void:
	var interdit := func(p: Vector3) -> bool:
		if maison_de(p) >= 0 or Terre.sur_sentier(p, Terre.LARGEUR_SENTIER * 0.5 + 0.25):
			return true
		for l in LIEUX:
			if p.distance_to(lieu(l)) < 5.5:
				return true
		for l in PETITS_LIEUX:
			if p.distance_to(petit_lieu(l)) < 3.5:
				return true
		return p.distance_to(POS_CHARRETTE) < 3.2
	# 0 : le village et les buttes ; 1..3 : autour de la clairière k-1.
	var lots := []
	for i in 1 + Quetes.ANGLES_ZONES.size():
		lots.append({"herbes": [], "fougeres": [], "pierres": [], "branches": [], "feuilles": []})
	var ranger := func(p: Vector3) -> int:
		for kz in Quetes.ANGLES_ZONES.size():
			var dz := p.distance_to(Quetes.zone(kz))
			if dz < 10.5:
				return -1                 # le décor de la quête s'habille lui-même
			if dz < 23.0:
				return kz + 1
		return 0
	var semis := [["herbes", 3200, 12.5 + ECART, 70.0 + ECART, 2.2, 3.6], ["fougeres", 650, R_CHEMIN_MAX + 0.5, 66.0 + ECART, 1.0, 1.8],
		["pierres", 260, R_CHEMIN_MAX + 0.5, 70.0 + ECART, 0.05, 0.22], ["branches", 110, R_CHEMIN_MAX + 0.5, 55.0 + ECART, 0.8, 1.3],
		["feuilles", 1600, 13.0 + ECART, 60.0 + ECART, 0.6, 1.3]]
	for s in semis:
		var mis := 0
		var essais := 0
		while mis < int(s[1]) and essais < int(s[1]) * 4:
			essais += 1
			var a := _rng.randf() * TAU
			# Plus dense près de la lisière qu'en plein village.
			var d := lerpf(float(s[2]), float(s[3]), sqrt(_rng.randf()))
			var p := Vector3(sin(a) * d, 0, cos(a) * d)
			if d < R_CHEMIN_MAX and d > R_CHEMIN_MIN - 0.5:
				continue                  # le chemin de ronde a ses propres sols
			if interdit.call(p):
				continue
			var lot: int = ranger.call(p)
			if lot < 0:
				continue
			p.y = Terre.hauteur(p.x, p.z) - (0.04 if s[0] == "pierres" else 0.0)
			lots[lot][s[0]].append([p, _rng.randf_range(float(s[4]), float(s[5])), _rng.randf() * TAU])
			mis += 1
	var feuille := QuadMesh.new()
	feuille.size = Vector2(0.11, 0.07)
	feuille.orientation = PlaneMesh.FACE_Y
	var m_feuille := StandardMaterial3D.new()
	m_feuille.vertex_color_use_as_albedo = true
	m_feuille.roughness = 0.95
	m_feuille.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in lots.size():
		var parent: Node3D = self
		if i > 0:
			parent = Node3D.new()
			parent.add_to_group("cadre_%d" % (i - 1))
			parent.set_meta("sol_de_clairiere", true)
			add_child(parent)
		var l: Dictionary = lots[i]
		Terre.semer(parent, "grass_medium_01", l["herbes"], Color(0.75, 0.72, 0.6))
		Terre.semer(parent, "fern_02", l["fougeres"], Color(0.7, 0.72, 0.6))
		Terre.semer(parent, "rock_moss_set_01", l["pierres"])
		Terre.semer(parent, "dry_branches_medium_01", l["branches"])
		var fs: Array = l["feuilles"]
		if fs.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = feuille
		mm.instance_count = fs.size()
		for k in fs.size():
			var f: Array = fs[k]
			mm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, float(f[2])).rotated(Vector3.RIGHT, _rng.randf_range(-0.2, 0.2)).scaled(Vector3.ONE * float(f[1])), (f[0] as Vector3) + Vector3(0, 0.025, 0)))
			mm.set_instance_color(k, Color(0.42, 0.24, 0.1).lerp(Color(0.25, 0.2, 0.1), _rng.randf()).lerp(Color(0.5, 0.36, 0.12), _rng.randf() * 0.4))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = m_feuille
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)


## La lisière : une double rangée d'arbres serrés tout autour du village, et entre les troncs
## des branches entremêlées et des ronces. On voit pourquoi on ne passe pas.
func _lisiere() -> void:
	var troncs := []
	var nb := int(TAU * (R_LISIERE + 3.0) / 1.9)
	for k in nb:
		var a := (k + _rng.randf_range(-0.2, 0.2)) * TAU / nb
		for rang in 3:
			var r := r_lisiere(a) + rang * 1.3 + _rng.randf_range(-0.3, 0.3)
			var aa := a + (0.5 * TAU / nb if rang == 1 else 0.0)
			var p := Vector3(sin(aa), 0, cos(aa)) * r
			if _dans_passage(p, 4.2):
				continue
			if rang == 0:
				troncs.append(p)
			_arbre(p, _rng.randf_range(1.3, 2.2), 0.24 if rang == 0 else 0.0)
	# Les branches : des perches tordues d'un tronc à l'autre, à plusieurs hauteurs.
	var branche := CylinderMesh.new()
	branche.top_radius = 0.035
	branche.bottom_radius = 0.06
	branche.height = 1.0
	branche.radial_segments = 6
	branche.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = branche
	var poses: Array[Transform3D] = []
	for k in troncs.size():
		var a: Vector3 = troncs[k]
		var b: Vector3 = troncs[(k + 1) % troncs.size()]
		if _dans_passage((a + b) * 0.5, 4.2):
			continue
		for etage in 7:
			var h1 := 0.3 + etage * 0.45 + _rng.randf_range(-0.15, 0.25)
			var h2 := 0.3 + etage * 0.45 + _rng.randf_range(-0.25, 0.3)
			var milieu := (a + b) * 0.5 + Vector3(0, (h1 + h2) * 0.5 + _rng.randf_range(-0.3, 0.2), 0) + a.normalized() * _rng.randf_range(-0.3, 0.3)
			for seg in [[a + Vector3(0, h1, 0), milieu], [milieu, b + Vector3(0, h2, 0)]]:
				poses.append(_perche(seg[0], seg[1]))
		for k2 in 4:   # des branches en croix, d'un étage à l'autre
			var f := _rng.randf()
			poses.append(_perche(a + Vector3(0, _rng.randf_range(0.2, 1.4), 0), b + Vector3(0, _rng.randf_range(1.6, 3.2), 0)) if f < 0.5 else _perche(a + Vector3(0, _rng.randf_range(1.6, 3.2), 0), b + Vector3(0, _rng.randf_range(0.2, 1.4), 0)))
		for k2 in 10:   # des rameaux qui pointent vers le village
			var base := a.lerp(b, _rng.randf()) + Vector3(0, _rng.randf_range(0.5, 2.6), 0)
			var bout := base - a.normalized() * _rng.randf_range(0.5, 1.1) + Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.3, 0.4), _rng.randf_range(-0.4, 0.4))
			poses.append(_perche(base, bout))
	mm.instance_count = poses.size()
	for k in poses.size():
		mm.set_instance_transform(k, poses[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat_tex("bark_willow_02", 0.7, Color(0.26, 0.23, 0.21), false)
	add_child(mmi)
	# De jeunes sapins serrés entre les deux rangées (de vrais sapins, plus des cônes : Edwin,
	# 30/10, « il ne faut pas voir des arbres sans texture »), et au pied des fourrés de fougères et
	# d'orties à la place des boules unies.
	var paquets := []
	for v in Arbres.NB:
		paquets.append([])
	var fourres := []
	for k in troncs.size():
		var a: Vector3 = troncs[k]
		var b: Vector3 = troncs[(k + 1) % troncs.size()]
		if _dans_passage((a + b) * 0.5, 4.2):
			continue
		for j in 2:
			var h := _rng.randf_range(0.5, 0.85)
			var p := a.lerp(b, 0.25 + j * 0.5) + a.normalized() * _rng.randf_range(0.6, 1.1)
			paquets[_rng.randi_range(5, Arbres.NB - 1)].append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * h), p))
		for j in 3:
			var p := a.lerp(b, (j + 0.5) / 3.0) + a.normalized() * _rng.randf_range(-0.2, 0.6)
			fourres.append([p, _rng.randf_range(1.3, 2.1), _rng.randf() * TAU])
	for v in Arbres.NB:
		var liste: Array = paquets[v]
		if liste.is_empty():
			continue
		var d := Arbres.variante(v)
		for part in ["tronc", "aiguilles"]:
			var m := MultiMesh.new()
			m.transform_format = MultiMesh.TRANSFORM_3D
			m.mesh = d[part]
			m.instance_count = liste.size()
			for i in liste.size():
				m.set_instance_transform(i, liste[i])
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = m
			mi.material_override = _mat_arbre if part == "tronc" else _mat_aiguilles
			add_child(mi)
	var moitie := fourres.size() / 2
	Terre.semer(self, "fern_02", fourres.slice(0, moitie))
	Terre.semer(self, "nettle_plant", fourres.slice(moitie))


## Ce point est-il dans l'un des trois passages de quête (couloir de `marge` m de demi-largeur) ?
## Derrière la lisière, on ne voit plus rien (Edwin, 29/10 : « les branches forment un brouillard
## sombre ») : un rideau circulaire, presque noir en bas, fait de branches emmêlées qui se perdent
## dans la brume en montant. Il suit la lisière (et son détour par le cimetière) ; on le traverse
## sans s'en apercevoir sur le sentier des quêtes.
func _mur_de_tenebres() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 160
	var haut := 24.0
	for couche in 2:
		var recul := 5.0 + couche * 3.5
		for k in n:
			var a0 := k * TAU / n
			var a1 := (k + 1) * TAU / n
			var p0 := Vector3(sin(a0), 0, cos(a0)) * (r_lisiere(a0) + recul)
			var p1 := Vector3(sin(a1), 0, cos(a1)) * (r_lisiere(a1) + recul)
			var u0 := float(k) / n
			var u1 := float(k + 1) / n
			var c := Color(1, 1, 1, float(couche))
			for q: Array in [[p0, u0, 0.0], [p1, u1, 0.0], [p1 + Vector3.UP * haut, u1, 1.0],
					[p0, u0, 0.0], [p1 + Vector3.UP * haut, u1, 1.0], [p0 + Vector3.UP * haut, u0, 1.0]]:
				st.set_color(c)
				st.set_uv(Vector2(q[1], q[2]))
				st.add_vertex((q[0] as Vector3) + Vector3(0, -0.5, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec3 teinte = vec3(0.012, 0.016, 0.012);
// Les passages de quête (tronc + trois branches) : le voile y est percé. Sans ça, le trajet guidé
// vers une clairière traversait ce mur peint — « la lisière d'arbres sans texture » (Edwin, 31/10).
uniform vec4 passages[4];
uniform float demi_largeur = 3.4;
uniform float r_village = 23.4;
varying vec3 monde;
float vers_passage(vec2 q) {
	float d = 1e5;
	for (int k = 0; k < 4; k++) {
		vec2 a = passages[k].xy;
		vec2 ab = passages[k].zw - a;
		float t = clamp(dot(q - a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
		d = min(d, distance(q, a + ab * t));
	}
	return d;
}
void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 5; k++) {
		v += a * bruit(p);
		p = p * 2.1 + vec2(13.7, 5.3);
		a *= 0.5;
	}
	return v;
}
void fragment() {
	// Il ne cache que le dehors à qui est DANS le village. Vu d'une clairière (ou de plus loin), il
	// n'existe pas : on y voit les vrais arbres, pas un voile peint (Edwin, 30/10).
	if (length(CAMERA_POSITION_WORLD.xz) > length(monde.xz) - 0.5) {
		discard;
	}
	// Sur le sentier, hors du village, il disparaît tout entier : on voyait ses pans coupés net de
	// part et d'autre de la trouée, de grands rideaux plats (Edwin, 31/10).
	if (length(CAMERA_POSITION_WORLD.xz) > r_village - 1.0 && vers_passage(CAMERA_POSITION_WORLD.xz) < 5.0) {
		discard;
	}
	float trouee = smoothstep(demi_largeur, demi_largeur + 3.0, vers_passage(monde.xz));
	if (trouee <= 0.0) {
		discard;
	}
	vec2 p = vec2(UV.x * 420.0, UV.y * 30.0);
	// Des branches : des sillons sombres là où le bruit passe par 0,5, en tous sens.
	float b1 = 1.0 - smoothstep(0.0, 0.07, abs(fbm(p * 0.35) - 0.5));
	float b2 = 1.0 - smoothstep(0.0, 0.05, abs(fbm(p * 0.8 + 7.0) - 0.5));
	float branches = max(b1, b2 * 0.8);
	float brume = 0.78 + 0.22 * fbm(p * 0.12 + TIME * 0.05);
	// Il s'éteint à hauteur des cimes : plus haut, c'était une bande sombre peinte dans le ciel, un
	// voile qui flottait au-dessus des arbres au Conseil (Edwin, 31/10). Le brouillard le fond au décor.
	float bas = 1.0 - smoothstep(0.12, 0.38, UV.y);
	float a = clamp(max(brume * bas, branches * (1.0 - smoothstep(0.1, 0.32, UV.y))), 0.0, 1.0);
	// La seconde couche, plus loin, est pleine : rien ne passe.
	a = mix(a, max(a, bas * 0.97 + 0.03), COLOR.a);
	ALBEDO = teinte * (0.6 + 0.6 * (1.0 - branches));
	ALPHA = a * trouee;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("passages", segments_des_passages())
	m.set_shader_parameter("r_village", R_CHEMIN_MAX)
	mi.material_override = m
	add_child(mi)
	_mur_tenebres = mi


## Les tronçons des passages de quête, (départ.xz, arrivée.xz) : le tronc puis chaque branche.
## Prolongés vers l'extérieur, pour que le voile soit percé aussi loin qu'il s'étend.
static func segments_des_passages() -> PackedVector4Array:
	var r := PackedVector4Array()
	var fourche := Quetes.passage(0, Quetes.R_FOURCHE)
	var depart := Quetes.passage(0, R_CHEMIN_MAX)
	r.append(Vector4(depart.x, depart.z, fourche.x, fourche.z))
	for k in Quetes.ANGLES_ZONES.size():
		var z := Quetes.zone(k)
		r.append(Vector4(fourche.x, fourche.z, z.x, z.z))
	while r.size() < 4:
		r.append(Vector4(1e5, 1e5, 1e5, 1e5))
	return r


static func _dans_passage(p: Vector3, marge: float) -> bool:
	var r := Vector2(p.x, p.z).length()
	if r < R_CHEMIN_MAX:
		return false
	var q := Vector2(p.x, p.z)
	var fourche := Quetes.passage(0, Quetes.R_FOURCHE)
	var depart := Quetes.passage(0, R_CHEMIN_MAX)
	var segs := [[depart, fourche]]
	for k in Quetes.ANGLES_ZONES.size():
		segs.append([fourche, Quetes.zone(k)])
	for s: Array in segs:
		var a := Vector2((s[0] as Vector3).x, (s[0] as Vector3).z)
		var b := Vector2((s[1] as Vector3).x, (s[1] as Vector3).z)
		if q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)) < marge:
			return true
	return false


# ---------------------------------------------------------------- les quêtes

## Le tableau des quêtes : un cadre de bois sous son auvent, l'enseigne sculptée, trois parchemins
## vieillis cloués (un sceau de cire : rouge pour un rôle, vert pour un indice ; une épingle par
## inscrit ; un tampon quand elle part, réussit ou échoue), deux bougies sur la tablette. À côté,
## le panneau des indices gagnés (tout le village les lit).
func _tableau_des_quetes() -> void:
	var n := Node3D.new()
	n.position = TABLEAU
	add_child(n)
	n.look_at(Vector3(0, 0, 0), Vector3.UP)
	n.rotate_y(PI)    # le recto vers la place
	var bois := _mat_ecorce()
	for x: float in [-3.4, 1.85, 3.4]:
		var poteau := _boite(Vector3(0.14, 2.6, 0.14), Color.WHITE)
		poteau.material_override = bois
		poteau.position = Vector3(x, 1.3, 0)
		n.add_child(poteau)
	var planche := _boite(Vector3(5.3, 1.8, 0.06), Color(0.36, 0.27, 0.19))
	planche.material_override = _mat_planches()
	planche.position = Vector3(-0.78, 1.5, -0.02)
	n.add_child(planche)
	var auvent := _boite(Vector3(5.6, 0.08, 0.6), Color(0.25, 0.19, 0.15))
	auvent.material_override = _mat_planches()
	auvent.position = Vector3(-0.78, 2.62, 0.15)
	auvent.rotation.x = -0.25
	n.add_child(auvent)
	n.add_child(_enseigne("Quêtes du jour", Vector3(-0.78, 2.3, 0.05), 2.9))
	for k in 3:
		_fiches_quetes.append(_fiche(n, Vector3(-2.53 + k * 1.75, 1.32, 0.02), k))
	# La tablette et ses deux bougies.
	var tablette := _boite(Vector3(5.3, 0.05, 0.2), Color.WHITE)
	tablette.material_override = _mat_planches()
	tablette.position = Vector3(-0.78, 0.55, 0.1)
	n.add_child(tablette)
	for x: float in [-3.08, 1.52]:
		_bougie_de_tableau(n, Vector3(x, 0.58, 0.12))
	# Le panneau des indices, à droite.
	var tab := _boite(Vector3(1.5, 1.7, 0.06), Color(0.3, 0.23, 0.17))
	tab.material_override = _mat_planches()
	tab.position = Vector3(2.62, 1.4, -0.02)
	n.add_child(tab)
	n.add_child(_enseigne("Indices", Vector3(2.62, 2.3, 0.05), 1.3))
	var feuille := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.38, 1.45)
	feuille.mesh = q
	feuille.material_override = Style.materiau_parchemin(3)
	feuille.position = Vector3(2.62, 1.32, 0.02)
	n.add_child(feuille)
	_clous(n, Vector3(2.62, 1.32, 0.02), q.size)
	_texte_indices = Style.ecriture("Aucun indice pour l'instant.", 30, Style.ENCRE, "italique", 0.0026)
	_texte_indices.position = Vector3(2.62, 1.32, 0.03)
	_texte_indices.width = 480
	_texte_indices.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.add_child(_texte_indices)
	var lampe := OmniLight3D.new()
	lampe.light_color = Color(1.0, 0.7, 0.4)
	lampe.light_energy = 0.6
	lampe.omni_range = 4.0
	lampe.position = Vector3(0.8, 2.2, 1.0)
	n.add_child(lampe)
	_bougies.append(lampe)
	_obstacle(n, Ronde.boite(Vector3(6.9, 2.6, 0.3)), Vector3(0, 1.3, 0))


## Une enseigne de bois sombre, lettres taillées et dorées, clouée en haut du tableau.
func _enseigne(texte: String, pos: Vector3, large: float) -> Node3D:
	var e := Node3D.new()
	e.position = pos
	var p := _boite(Vector3(large, 0.42, 0.07), Color(0.2, 0.13, 0.08))
	p.material_override = _mat_ecorce()
	e.add_child(p)
	var l := Style.ecriture(texte, 120, Style.OR, "titre", 0.0028)
	l.outline_size = 10
	l.outline_modulate = Color(0.12, 0.07, 0.03)
	l.position = Vector3(0, -0.01, 0.04)
	e.add_child(l)
	_clous(e, Vector3(0, 0, 0.04), Vector2(large - 0.1, 0.3))
	return e


## Quatre clous de fer aux coins d'un rectangle (taille) centré en c.
func _clous(parent: Node3D, c: Vector3, taille: Vector2) -> void:
	var fer := _mat_simple(Color(0.16, 0.15, 0.14), 0.6)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var clou := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = 0.018
			sp.height = 0.02
			clou.mesh = sp
			clou.material_override = fer
			clou.position = c + Vector3(sx * (taille.x * 0.5 - 0.07), sy * (taille.y * 0.5 - 0.07), 0.012)
			parent.add_child(clou)


## Un parchemin de quête : titre, détails, sceau, épingles des inscrits, tampon d'état.
func _fiche(parent: Node3D, c: Vector3, k: int) -> Dictionary:
	var f := Node3D.new()
	f.position = c
	f.rotation.z = [-0.035, 0.02, -0.015][k]
	parent.add_child(f)
	var feuille := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.58, 1.3)
	feuille.mesh = q
	feuille.material_override = Style.materiau_parchemin(k)
	f.add_child(feuille)
	_clous(f, Vector3.ZERO, q.size)
	# Le titre pousse vers le haut, les détails vers le bas : deux lignes de titre ne mordent pas.
	var titre := Style.ecriture("", 72, Style.ENCRE, "titre", 0.0026)
	titre.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	titre.position = Vector3(0, 0.25, 0.012)
	f.add_child(titre)
	var detail := Style.ecriture("", 48, Style.ENCRE, "italique", 0.0026)
	detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail.position = Vector3(0, 0.2, 0.012)
	detail.width = 560
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	f.add_child(detail)
	var sceau := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.085
	cy.bottom_radius = 0.095
	cy.height = 0.02
	cy.radial_segments = 14
	sceau.mesh = cy
	sceau.rotation.x = PI / 2
	sceau.position = Vector3(0.56, -0.44, 0.015)
	f.add_child(sceau)
	var epingles := Node3D.new()
	epingles.position = Vector3(-0.6, -0.4, 0.015)
	f.add_child(epingles)
	var tampon := Style.ecriture("", 92, Color(0.6, 0.1, 0.08), "titre", 0.0026)
	tampon.rotation.z = 0.22
	tampon.position = Vector3(-0.05, -0.3, 0.02)
	f.add_child(tampon)
	return {"titre": titre, "detail": detail, "sceau": sceau, "epingles": epingles, "tampon": tampon, "noeud": f}


## Une bougie de suif sur la tablette, sa flamme et sa lueur (qui vacille avec les autres).
func _bougie_de_tableau(parent: Node3D, pos: Vector3) -> void:
	var cire := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.03
	cy.bottom_radius = 0.034
	cy.height = 0.16
	cire.mesh = cy
	cire.material_override = _mat_simple(Color(0.9, 0.85, 0.7), 0.0)
	cire.position = pos + Vector3(0, 0.08, 0)
	parent.add_child(cire)
	var flamme := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.016
	sp.height = 0.05
	flamme.mesh = sp
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.75, 0.35)
	flamme.material_override = m
	flamme.position = pos + Vector3(0, 0.185, 0)
	parent.add_child(flamme)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.68, 0.35)
	l.light_energy = 0.55
	l.omni_range = 2.2
	l.position = pos + Vector3(0, 0.25, 0.05)
	l.set_meta("flamme", flamme)
	parent.add_child(l)
	_bougies.append(l)


func _etiquette(texte: String, taille: float, c: Color) -> Label3D:
	var l := Style.ecriture(texte, 48, c, "titre", taille)
	l.shaded = false
	return l


## Ce qu'affiche le tableau : les quêtes du jour (pub["quetes"]) et les indices.
func regler_tableau(quetes: Array, indices: Array, propositions := false) -> void:
	for k in _fiches_quetes.size():
		var f: Dictionary = _fiches_quetes[k]
		var titre: Label3D = f["titre"]
		var detail: Label3D = f["detail"]
		var tampon: Label3D = f["tampon"]
		var sceau: MeshInstance3D = f["sceau"]
		var epingles: Node3D = f["epingles"]
		if k >= quetes.size():
			titre.text = "" if not propositions else "…"
			detail.text = ""
			tampon.text = ""
			sceau.visible = false
			_epingler(epingles, 0)
			continue
		var q: Dictionary = quetes[k]
		var n: int = (q.get("inscrits", []) as Array).size()
		# Le numéro est celui qu'on tape au vote du matin (Edwin, 30/10) : le tableau détaille.
		titre.text = "%d · %s" % [k + 1, q["nom"]]
		# Toujours une seule ligne : un nom long s'écrit plus petit.
		titre.font_size = clampi(int(900.0 / maxf(titre.text.length(), 1.0)), 32, 72)
		var jeu: Array = Quetes.JEUX.get(q.get("jeu", ""), ["", ""])
		detail.font_size = 38
		var recomp := Quetes.texte_recompense(q["recompense"], q.get("titre_seul", false), q.get("etat", "") == "finie" and q.get("reussie", false))
		detail.text = "%s — %s\n%s" % [Quetes.NOMS_NIVEAUX.get(q["niveau"], q["niveau"]), recomp, jeu[1]]
		if str(q.get("remplace", "")) != "":
			# Le tampon couvre le centre de la fiche : l'annonce prend la place de la description.
			detail.text = "%s — %s\n%s" % [Quetes.NOMS_NIVEAUX.get(q["niveau"], q["niveau"]), recomp, str(q["remplace"])]
		elif str(q.get("requis", "")) != "":
			detail.text += "\nJoueurs requis : %s" % str(q["requis"])
		var etat := ""
		var encre := Color(0.6, 0.1, 0.08)
		match q.get("etat", ""):
			"annulee":
				etat = "Annulée"
			"ecartee":
				etat = "Écartée"
				encre = Color(0.3, 0.25, 0.2)
			"trajet", "jeu", "retour":
				etat = "En route"
				encre = Color(0.15, 0.2, 0.45)
			"finie":
				etat = "Réussie" if q.get("reussie", false) else "Échouée"
				if q.get("reussie", false):
					encre = Color(0.12, 0.38, 0.14)
		tampon.text = etat
		tampon.modulate = Color(encre, 0.85)
		sceau.visible = true
		sceau.material_override = _mat_simple(Color(0.58, 0.07, 0.06) if q["recompense"] == "role" else Color(0.14, 0.34, 0.17), 0.25)
		_epingler(epingles, n)
		if k < _panneaux_zones.size():
			_panneaux_zones[k].text = q["nom"]
	if _texte_indices:
		var dernier := indices.slice(maxi(0, indices.size() - 7))
		_texte_indices.text = "\n".join(PackedStringArray(dernier)) if not dernier.is_empty() else "Aucun indice pour l'instant."


## Un matériau sans contour (fer, cire, suif) : sa couleur et son métal.
func _mat_simple(c: Color, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.55 if metal > 0.0 else 0.85
	return m


## Une épingle à tête colorée par inscrit, piquée au bas du parchemin.
func _epingler(rang: Node3D, n: int) -> void:
	if rang.get_child_count() == n:
		return
	for e in rang.get_children():
		rang.remove_child(e)
		e.queue_free()
	var couleurs := [Color(0.7, 0.15, 0.1), Color(0.15, 0.3, 0.6), Color(0.75, 0.6, 0.15), Color(0.2, 0.45, 0.2)]
	for i in n:
		var e := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.034
		sp.height = 0.068
		e.mesh = sp
		e.material_override = _mat_simple(couleurs[i % couleurs.size()], 0.3)
		e.position = Vector3((i % 6) * 0.09, -(i / 6) * 0.085, 0.0)
		rang.add_child(e)


## Les trois clairières derrière la lisière, et le portail de bois qui ferme chaque passage.
func _clairieres_de_quete() -> void:
	# Des rochers moussus (Poly Haven, CC0) bornent la clairière ; le centre reste libre : chaque
	# quête y pose son décor (quetes/decors).
	var rochers := (load("res://modeles/nature/rock_moss_set_02/rock_moss_set_02.gltf") as PackedScene).instantiate()
	var maillages := rochers.find_children("*", "MeshInstance3D", true, false)
	for k in Quetes.ANGLES_ZONES.size():
		var c := Quetes.zone(k)
		for j in 10:
			var a := j * TAU / 10.0 + 0.15 * sin(j * 2.7)
			var mi: MeshInstance3D = maillages[(j + k) % maillages.size()]
			var b := mi.get_aabb()
			var roc := MeshInstance3D.new()
			roc.mesh = mi.mesh
			var e := 0.35 + 0.12 * absf(sin(j * 1.9))
			roc.scale = Vector3.ONE * e
			roc.rotation.y = a * 3.0
			roc.position = c + Vector3(sin(a), 0, cos(a)) * 4.4 + roc.basis * (Vector3(-b.get_center().x, -b.position.y - 0.1, -b.get_center().z) * e)
			roc.add_to_group("rochers_clairiere")   # un décor plus vaste que le cercle (le cimetière de la Dame) les écarte le temps de sa quête
			add_child(roc)
		_cadre_de_clairiere(k, c)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.25)
		l.light_energy = 1.4
		l.omni_range = 7.0
		l.position = c + Vector3(0, 0.6, 0)
		add_child(l)
		_torches.append(l)
		# Le panneau qui dit quelle quête se joue ici, tourné vers le passage.
		var pan := Node3D.new()
		var fourche := Quetes.passage(k, Quetes.R_FOURCHE)
		var vient := (fourche - c).normalized()
		var ou := c + vient * 4.8 - vient.cross(Vector3.UP) * 2.9
		pan.position = ou
		add_child(pan)
		pan.look_at(Vector3(fourche.x, 0, fourche.z), Vector3.UP)
		pan.rotate_y(PI)
		var piquet := _boite(Vector3(0.1, 1.3, 0.1), Color(0.3, 0.22, 0.16))
		piquet.position = Vector3(0, 0.65, -0.06)
		pan.add_child(piquet)
		var ecriteau := _boite(Vector3(1.8, 0.4, 0.05), Color(0.36, 0.27, 0.19))
		ecriteau.material_override = _mat_planches()
		ecriteau.position.y = 1.5
		pan.add_child(ecriteau)
		var et := _etiquette("", 0.0032, Color(0.95, 0.88, 0.7))
		et.position = Vector3(0, 1.5, 0.04)
		pan.add_child(et)
		_panneaux_zones.append(et)
		_portail(k)
	_portail(-1)
	rochers.free()


## La clairière est un écrin fermé (demande d'Edwin, 29/10 : « on voit encore plein de vide ») :
## trois rangs d'arbres serrés, de jeunes sapins et des buissons noirs à hauteur d'yeux entre les
## troncs, des falaises moussues au fond. Seul le passage vers le village reste ouvert. Tout est
## dans le groupe « cadre_k » : un décor qui déborde (la rivière du Radeau) écarte ce qui le gêne.
func _cadre_de_clairiere(k: int, c: Vector3) -> void:
	var groupe := "cadre_%d" % k
	var vers_village := (Quetes.passage(k, Quetes.R_FOURCHE) - c).normalized()
	var permis := func(pt: Vector3) -> bool:
		return not _dans_passage(pt, 3.4) and Vector2(pt.x, pt.z).length() > R_LISIERE + 3.0
	var poses := 0
	var essai := 0
	while poses < 64 and essai < 900:
		essai += 1
		var a := _rng.randf() * TAU
		var pt := c + Vector3(sin(a), 0, cos(a)) * _rng.randf_range(11.0, 22.0)
		if not permis.call(pt):
			continue
		_arbre(pt, _rng.randf_range(1.3, 2.3), 0.08, groupe)
		poses += 1
	# Entre les troncs, à hauteur d'yeux : de jeunes sapins (les mêmes que les grands, en petit) et
	# des fourrés de fougères et d'orties. Plus aucun cône ni aucune boule unie (Edwin, 30/10).
	var fourres: Array = Terre.maillages("fern_02") + Terre.maillages("nettle_plant")
	for j in 80:
		var a := _rng.randf() * TAU
		var pt := c + Vector3(sin(a), 0, cos(a)) * _rng.randf_range(10.8, 15.5)
		if not permis.call(pt):
			continue
		pt.y = Terre.hauteur(pt.x, pt.z) - 0.05
		var n := Node3D.new()
		n.position = pt
		n.rotation.y = _rng.randf() * TAU
		n.add_to_group(groupe)
		add_child(n)
		if j % 3 == 0 and not fourres.is_empty():
			var f: Array = fourres[_rng.randi_range(0, fourres.size() - 1)]
			var mi := MeshInstance3D.new()
			mi.mesh = f[0]
			mi.transform = f[1]
			n.scale = Vector3.ONE * _rng.randf_range(1.4, 2.4)
			n.add_child(mi)
		else:
			var d := Arbres.variante(_rng.randi_range(5, Arbres.NB - 1))
			var tronc := MeshInstance3D.new()
			tronc.mesh = d["tronc"]
			tronc.material_override = _mat_arbre
			n.add_child(tronc)
			var ai := MeshInstance3D.new()
			ai.mesh = d["aiguilles"]
			ai.material_override = _mat_aiguilles
			tronc.add_child(ai)
			n.scale = Vector3.ONE * _rng.randf_range(0.45, 0.85)
	# Des falaises moussues au fond (Poly Haven, CC0) : l'horizon est fermé.
	var falaise: Array = Terre.maillages("namaqualand_cliff_01")[0]
	for j in 10:
		var a := j * TAU / 10.0 + _rng.randf_range(-0.15, 0.15)
		var pt := c + Vector3(sin(a), 0, cos(a)) * _rng.randf_range(20.0, 25.0)
		# Une falaise fait jusqu'à 17 m de large : trop près du village, elle tombait sur le chemin de
		# ronde (Edwin, 01/11 : « un énorme caillou autour du village »).
		if _dans_passage(pt, 5.0) or (pt - c).normalized().dot(vers_village) > 0.5 or Vector2(pt.x, pt.z).length() < R_LISIERE + 16.0:
			continue
		var n := Node3D.new()
		n.position = pt + Vector3(0, Terre.hauteur(pt.x, pt.z) - 0.8, 0)
		n.add_to_group(groupe)
		add_child(n)
		n.look_at(Vector3(c.x, n.position.y, c.z), Vector3.UP)
		n.rotate_y(_rng.randf_range(-0.3, 0.3))
		n.scale = Vector3.ONE * _rng.randf_range(1.5, 2.3)
		var mi := MeshInstance3D.new()
		mi.mesh = falaise[0]
		mi.transform = falaise[1]
		n.add_child(mi)


## Le sentier des quêtes n'a qu'un départ (Edwin, 29/10) : un portail sur le tronc, dans la
## lisière (`k` = -1), qui ne s'ouvre que si une quête est en route ; puis, à la fourche, un
## portail au départ de chaque branche, qui ne s'ouvre que pour sa quête.
func _portail(k: int) -> void:
	var r := R_LISIERE + 0.7 if k < 0 else Quetes.R_FOURCHE + 3.2
	var kk := maxi(k, 0)
	var ici := Quetes.passage(kk, r)
	var dir := Quetes.passage(kk, r + 0.5) - ici
	var n := Node3D.new()
	n.position = ici
	add_child(n)
	n.rotation.y = atan2(dir.x, dir.z)    # l'axe z local suit le passage, x le travers
	var bois := _mat_ecorce()
	for cote: int in [-1, 1]:
		var montant := _boite(Vector3(0.22, 2.8, 0.22), Color.WHITE)
		montant.material_override = bois
		montant.position = Vector3(cote * 2.1, 1.4, 0)
		n.add_child(montant)
	var linteau := _boite(Vector3(4.6, 0.2, 0.22), Color.WHITE)
	linteau.material_override = bois
	linteau.position.y = 2.8
	n.add_child(linteau)
	var battants: Array[Node3D] = []
	for cote: int in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(cote * 2.0, 0, 0)
		n.add_child(pivot)
		for j in 5:
			var planche := _boite(Vector3(0.36, 1.7, 0.06), Color(0.32, 0.24, 0.17))
			planche.material_override = _mat_planches()
			planche.position = Vector3(-cote * (0.2 + j * 0.39), 0.95 + _rng.randf_range(-0.05, 0.05), 0)
			pivot.add_child(planche)
		var barre := _boite(Vector3(1.9, 0.12, 0.08), Color(0.26, 0.19, 0.14))
		barre.position = Vector3(-cote * 0.98, 1.2, 0.05)
		barre.rotation.z = cote * 0.5
		pivot.add_child(barre)
		battants.append(pivot)
	var corps := StaticBody3D.new()
	var f := CollisionShape3D.new()
	f.shape = Ronde.boite(Vector3(4.2, 3, 0.6))
	f.position.y = 1.5
	corps.add_child(f)
	n.add_child(corps)
	var p := {"corps": f, "battants": battants, "ouvert": 0.0, "but": 0.0, "passe": false}
	if k < 0:
		_portail_tronc = p
	else:
		_portails.append(p)


## Le portail k s'ouvre (vu de tous) ; `traversable` : ce joueur-ci peut passer (son équipe).
func regler_portail(k: int, ouvert: bool, traversable: bool) -> void:
	if k < 0 or k >= _portails.size():
		return
	_portails[k]["but"] = 1.0 if ouvert else 0.0
	_portails[k]["passe"] = traversable
	(_portails[k]["corps"] as CollisionShape3D).disabled = traversable
	# Le portail du tronc : ouvert si une quête est en route, franchissable si l'une est la mienne.
	if not _portail_tronc.is_empty():
		var but := 0.0
		var passe := false
		for pt in _portails:
			but = maxf(but, pt["but"])
			passe = passe or pt["passe"]
		_portail_tronc["but"] = but
		(_portail_tronc["corps"] as CollisionShape3D).disabled = passe


func _animer_portails(delta: float) -> void:
	for pt in _portails + ([_portail_tronc] if not _portail_tronc.is_empty() else []):
		pt["ouvert"] = move_toward(pt["ouvert"], pt["but"], delta * 0.8)
		var bat: Array = pt["battants"]
		for i in bat.size():
			(bat[i] as Node3D).rotation.y = (1 if i == 0 else -1) * pt["ouvert"] * deg_to_rad(100.0)


func _perche(de: Vector3, a: Vector3) -> Transform3D:
	var d := a - de
	var y := d.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x, y * d.length(), z), (de + a) * 0.5)


## Un arbre du bois (cf. Arbres : huit variantes partagées), penché vers le village. Avec
## `chance_visage`, son écorce dessine parfois un visage tourné vers la place : deux orbites
## creuses sous des arcades noueuses, une bouche qui gémit (décision d'Edwin, 29/10 : « donner
## l'impression d'être observé »).
func _arbre(p: Vector3, taille: float, chance_visage := 0.0, groupe := "") -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(p.x, Terre.hauteur(p.x, p.z) - 0.05, p.z)
	if groupe != "":
		n.add_to_group(groupe)
	n.scale = Vector3.ONE * taille
	var vers := -Vector3(p.x, 0, p.z).normalized()
	n.rotation.y = atan2(vers.x, vers.z)
	n.rotation.x = _rng.randf_range(0.04, 0.16)
	add_child(n)
	if _mat_arbre == null:
		_mat_arbre = _mat_tex("bark_willow_02", 0.7, Color(0.27, 0.24, 0.22), false)
		_mat_aiguilles = Arbres.materiau_aiguilles()
		_mat_creux = Bouille.materiau(Color(0.015, 0.01, 0.008), 0.0)
		_mat_bois_mort = _mat_tex("bark_willow_02", 0.5, Color(0.62, 0.58, 0.52), false)
	# Deux arbres morts sur trois : le bois est malade.
	var k := _rng.randi_range(0, 4) if _rng.randf() < 0.65 else _rng.randi_range(5, Arbres.NB - 1)
	var d := Arbres.variante(k)
	var tronc := MeshInstance3D.new()
	tronc.mesh = d["tronc"]
	tronc.material_override = _mat_arbre
	tronc.rotation.y = _rng.randf_range(-0.5, 0.5)
	n.add_child(tronc)
	if d["aiguilles"]:
		var ai := MeshInstance3D.new()
		ai.mesh = d["aiguilles"]
		ai.material_override = _mat_aiguilles
		tronc.add_child(ai)
	_obstacle(n, Ronde.cylindre(0.35, 3.0), Vector3(0, 1.5, 0))
	if _rng.randf() < chance_visage:
		_visage_d_ecorce(tronc, d, clampf(1.75 / taille, 0.9, 1.6))
	return n


func _visage_d_ecorce(tronc: MeshInstance3D, d: Dictionary, h: float) -> void:
	var a: Array = Arbres.axe_a(d, h)
	var centre: Vector3 = a[0]
	var r: float = a[1]
	# Le visage regarde vers le village (le +Z de l'arbre), défait de la petite rotation du tronc.
	var f := Node3D.new()
	f.position = centre
	f.rotation.y = -tronc.rotation.y
	tronc.add_child(f)
	# Un visage plus large que le tronc n'est pas un visage : ~25 cm de large, posé sur la courbe.
	var s := maxf(r * 1.8, 0.34)
	# Une plaque de bois mort, pâle, où l'écorce est tombée : les creux noirs s'y lisent.
	_bosse(f, s, r, Vector3(0, -0.22, 0.86), 0.66, Vector3(0.82, 1.4, 0.35))
	for c: int in [-1, 1]:
		_bosse(f, s, r, Vector3(c * 0.42, 0.3, 1.02), 0.3, Vector3(1.35, 0.5, 0.6), c * -0.4)      # arcade
		_bosse(f, s, r, Vector3(c * 0.38, 0.06, 1.02), 0.21, Vector3(1.0, 1.3, 0.5), 0.0, _mat_creux) # orbite
	var yeux := StandardMaterial3D.new()
	yeux.albedo_color = Color(0.02, 0.01, 0.0)
	yeux.emission_enabled = true
	yeux.emission = Color(1.0, 0.42, 0.12)
	yeux.emission_energy_multiplier = 0.0
	for c: int in [-1, 1]:
		_bosse(f, s, r, Vector3(c * 0.38, 0.04, 1.11), 0.05, Vector3.ONE, 0.0, yeux)
	_bosse(f, s, r, Vector3(0, -0.14, 1.08), 0.16, Vector3(0.7, 1.6, 0.8))            # nez, un nœud
	_bosse(f, s, r, Vector3(0, -0.32, 1.03), 0.22, Vector3(1.4, 0.4, 0.5))            # lèvre du haut
	_bosse(f, s, r, Vector3(0, -0.62, 1.0), 0.24, Vector3(0.85, 1.55, 0.5), 0.0, _mat_creux)   # la bouche, béante
	_bosse(f, s, r, Vector3(0, -0.95, 1.0), 0.22, Vector3(1.3, 0.45, 0.5))            # menton
	visages.append({"noeud": f, "yeux": yeux})


## Une bosse (ou un creux) du visage : x, y à l'échelle s ; z : la surface du tronc (rayon r) à
## cet endroit, plus (pos.z - 0,9) × s — ce qui sort ou s'enfonce.
func _bosse(f: Node3D, s: float, r: float, pos: Vector3, rayon: float, ech: Vector3, rot_z := 0.0, mat: Material = null) -> MeshInstance3D:
	var m := Bouille.sphere(rayon * s, mat if mat else _mat_bois_mort, ech)
	var x := pos.x * s
	m.position = Vector3(x, pos.y * s, sqrt(maxf(r * r - x * x, r * r * 0.15)) + (pos.z - 0.9) * s)
	m.rotation.z = rot_z
	f.add_child(m)
	return m


## Ce qui rend le village malsain : épouvantails entre les maisons, crânes sur des piquets,
## cordes de pendu aux arbres morts, croix tordues, cage vide. Rien ne bouge… presque.
func _glauque() -> void:
	var bois := Color(0.2, 0.15, 0.11)
	var os_c := Color(0.72, 0.68, 0.58)
	var guenille := Color(0.22, 0.2, 0.17)
	# Épouvantails, dans les trouées entre les maisons, tournés vers la place.
	for k in [1, 4, 7, 10]:
		if k >= NB_MAISONS - 1:
			continue   # après la dernière maison : c'est le vide du tableau des quêtes
		var a := angle_maison(k) + TAU / NB_MAISONS * 0.5
		var p := Vector3(sin(a), 0, cos(a)) * (R_MAISON + 1.0)
		var e := Node3D.new()
		e.position = p
		e.rotation.y = a + PI
		e.rotation.z = _rng.randf_range(-0.12, 0.12)
		add_child(e)
		var pieu := _boite(Vector3(0.1, 2.2, 0.1), bois)
		pieu.position.y = 1.1
		e.add_child(pieu)
		var bras := _boite(Vector3(1.5, 0.08, 0.08), bois)
		bras.position.y = 1.65
		bras.rotation.z = _rng.randf_range(-0.15, 0.15)
		e.add_child(bras)
		var veste := MeshInstance3D.new()
		var cv := CylinderMesh.new()
		cv.top_radius = 0.2
		cv.bottom_radius = 0.34
		cv.height = 0.9
		veste.mesh = cv
		veste.position.y = 1.3
		veste.material_override = Bouille.materiau(guenille, 0.0)
		e.add_child(veste)
		var sac := Bouille.sphere(0.2, Bouille.materiau(Color(0.48, 0.42, 0.32), 0.0))
		sac.position.y = 2.0
		sac.scale = Vector3(0.9, 1.05, 0.9)
		e.add_child(sac)
		for c: int in [-1, 1]:      # deux yeux cousus en croix
			var x1 := _boite(Vector3(0.06, 0.012, 0.01), Color(0.08, 0.05, 0.05))
			x1.position = Vector3(c * 0.07, 2.04, 0.18)
			x1.rotation.z = 0.8
			e.add_child(x1)
			var x2 := x1.duplicate() as MeshInstance3D
			x2.rotation.z = -0.8
			e.add_child(x2)
		var bouche := _boite(Vector3(0.14, 0.012, 0.01), Color(0.3, 0.05, 0.04))
		bouche.position = Vector3(0, 1.93, 0.185)
		bouche.rotation.z = 0.15
		e.add_child(bouche)
		_obstacle(e, Ronde.cylindre(0.3, 2.2), Vector3(0, 1.1, 0))
	# Crânes de bêtes sur des piquets, à l'orée du bois.
	for k in 14:
		var a := k * TAU / 14.0 + _rng.randf_range(-0.1, 0.1)
		var p := Vector3(sin(a), 0, cos(a)) * (R_CHEMIN_MAX + 1.0)
		var pq := Node3D.new()
		pq.position = p
		pq.rotation = Vector3(_rng.randf_range(-0.1, 0.1), -a, _rng.randf_range(-0.12, 0.12))
		add_child(pq)
		var pieu := _boite(Vector3(0.07, 1.6, 0.07), bois)
		pieu.position.y = 0.8
		pq.add_child(pieu)
		var crane := Bouille.sphere(0.12, Bouille.materiau(os_c, 0.0))
		crane.position = Vector3(0, 1.68, 0)
		crane.scale = Vector3(0.9, 0.8, 1.3)
		pq.add_child(crane)
		var museau := _boite(Vector3(0.1, 0.08, 0.18), os_c)
		museau.position = Vector3(0, 1.63, 0.16)
		pq.add_child(museau)
		for c: int in [-1, 1]:
			var orbite := Bouille.sphere(0.03, Bouille.materiau(Color(0.02, 0.02, 0.02), 0.0))
			orbite.position = Vector3(c * 0.055, 1.71, 0.12)
			pq.add_child(orbite)
			if k % 3 == 0:          # des cornes, parfois
				var corne := _boite(Vector3(0.03, 0.22, 0.03), os_c)
				corne.position = Vector3(c * 0.09, 1.82, -0.02)
				corne.rotation.z = -c * 0.6
				pq.add_child(corne)
	# Cordes de pendu, au bord de la place : nœud coulant vide qui se balance à peine.
	for k in 3:
		var a := TAU * (0.15 + k * 0.31)
		var p := Vector3(sin(a), 0, cos(a)) * (R_CHEMIN_MIN - 1.0)
		var g := Node3D.new()
		g.position = p
		g.rotation.y = a
		add_child(g)
		var poteau := _boite(Vector3(0.16, 3.4, 0.16), bois)
		poteau.position.y = 1.7
		g.add_child(poteau)
		var potence := _boite(Vector3(1.2, 0.14, 0.14), bois)
		potence.position = Vector3(0.55, 3.3, 0)
		g.add_child(potence)
		var jambe := _boite(Vector3(0.08, 0.8, 0.08), bois)
		jambe.position = Vector3(0.25, 2.95, 0)
		jambe.rotation.z = 0.8
		g.add_child(jambe)
		var corde := Node3D.new()
		corde.position = Vector3(1.0, 3.25, 0)
		corde.set_meta("decalage", float(k) * 2.1)
		g.add_child(corde)
		var fil := _boite(Vector3(0.025, 1.0, 0.025), Color(0.45, 0.38, 0.26))
		fil.position.y = -0.5
		corde.add_child(fil)
		var noeud := MeshInstance3D.new()
		var tore := TorusMesh.new()
		tore.inner_radius = 0.1
		tore.outer_radius = 0.13
		noeud.mesh = tore
		noeud.rotation.x = PI / 2
		noeud.position.y = -1.12
		noeud.material_override = Bouille.materiau(Color(0.45, 0.38, 0.26), 0.0)
		corde.add_child(noeud)
		_cordes.append(corde)
		_obstacle(g, Ronde.cylindre(0.2, 3.4), Vector3(0, 1.7, 0))
	# Croix tordues plantées au hasard dans l'herbe, comme des tombes oubliées.
	for k in 10:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(R_CHEMIN_MAX + 0.8, R_LIMITE - 0.4)
		var p := Vector3(sin(a), 0, cos(a)) * d
		var croix := Node3D.new()
		croix.position = p
		croix.rotation = Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf() * TAU, _rng.randf_range(-0.3, 0.3))
		add_child(croix)
		var v := _boite(Vector3(0.08, 1.0, 0.06), bois)
		v.position.y = 0.45
		croix.add_child(v)
		var h := _boite(Vector3(0.5, 0.07, 0.06), bois)
		h.position.y = 0.72
		croix.add_child(h)


func _corbeaux_sur_les_toits() -> void:
	var noir := Bouille.materiau(Color(0.04, 0.04, 0.05), 0.01)
	for i in NB_MAISONS:
		if _rng.randf() < 0.45:
			continue
		var c := Node3D.new()
		var corps := Bouille.sphere(0.16, noir, Vector3(1, 0.9, 1.5))
		c.add_child(corps)
		var tete := Bouille.sphere(0.09, noir)
		tete.position = Vector3(0, 0.12, 0.17)
		c.add_child(tete)
		var bec := _boite(Vector3(0.04, 0.04, 0.12), Color(0.15, 0.13, 0.1))
		bec.position = Vector3(0, 0.11, 0.3)
		c.add_child(bec)
		for cote: int in [-1, 1]:
			var oeil := Bouille.sphere(0.02, Bouille.materiau(Color(0.6, 0.05, 0.05), 0.0, Color(0.7, 0.05, 0.03)))
			oeil.position = Vector3(cote * 0.06, 0.15, 0.24)
			c.add_child(oeil)
		var y := FAITAGE + 0.12   # sur le faîtage
		c.position = _vers_monde(i, Vector3(_rng.randf_range(-1.8, 1.8), y, 0))
		c.set_meta("y", y)
		c.set_meta("cap", _rng.randf() * TAU)
		c.set_meta("decalage", _rng.randf() * 10.0)
		add_child(c)
		_corbeaux.append(c)


## Un corbeau proche de ce point (pour le faire croasser), ou null.
func corbeau_proche(pos: Vector3, portee := 8.0) -> Node3D:
	for c in _corbeaux:
		if c.global_position.distance_to(pos) < portee:
			return c
	return null


# ---------------------------------------------------------------- matière : sol, pack, bois

## Un modèle du pack Medieval Village MegaKit (Quaternius, CC0), patiné : assombri, la vitre
## remplacée par celle de la maison en cours (elle s'éclaire la nuit).
func _modele(nom: String, parent: Node3D, pos: Vector3, rot_y := 0.0, echelle := Vector3.ONE, teinte := Color.WHITE) -> Node3D:
	var ps := load(VILLAGE + nom + ".gltf") as PackedScene
	var n := ps.instantiate() as Node3D
	n.position = pos
	n.rotation.y = rot_y
	n.scale = echelle
	_patiner(n, teinte)
	parent.add_child(n)
	return n


func _patiner(n: Node, mur: Color) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
				if m:
					mi.set_surface_override_material(s, _mat_patinee(m, mur))
	for c in n.get_children():
		_patiner(c, mur)


func _mat_patinee(m: BaseMaterial3D, mur: Color) -> Material:
	var nom := m.resource_name
	if nom == "MI_WindowGlass":
		return _verre
	var t := Color(0.5, 0.46, 0.43)                 # bois, par défaut : sombre et gorgé d'eau
	match nom:
		"MI_Plaster":
			t = mur
		"MI_UnevenBrick", "MI_Brick", "MI_RockTrim":
			t = Color(0.55, 0.53, 0.5)
		"MI_RoundTiles":
			t = Color(0.46, 0.42, 0.4)
		"MI_Vine":
			t = Color(0.42, 0.5, 0.36)
		"MI_MetalOrnaments":
			t = Color(0.5, 0.5, 0.5)
	var cle := "%d_%s" % [m.get_instance_id(), t.to_html()]
	if not _mats_pat.has(cle):
		var d := m.duplicate() as BaseMaterial3D
		d.albedo_color = m.albedo_color * t
		_mats_pat[cle] = d
	return _mats_pat[cle]


## Vitre sale : presque transparente le jour, elle luit faiblement la nuit.
func _verre_neuf() -> StandardMaterial3D:
	var mv := Bouille.materiau(Color(0.15, 0.14, 0.1, 0.2), 0.0, Color(1.0, 0.55, 0.2))
	mv.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mv.emission_energy_multiplier = 0.0
	mv.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mv


## Un matériau Poly Haven (CC0) : albedo + normales + rugosité, assombri par `teinte`.
## `echelle` : répétitions par mètre. `monde` : motif collé au monde (sols), sinon à l'objet.
## Les tuiles du temple (Edwin, 30/10 : plus d'aplat sans texture) : des rangs de tuiles rondes
## en relief, collés au monde, chacun d'un ton un peu différent, l'extrémité de chaque tuile qui
## fait une ombre, et de la mousse qui s'accroche dans les creux.
func _mat_tuiles_temple() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
varying vec3 lp;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	// Dans le repère du pan : x le long du toit, z dans la pente.
	lp = VERTEX;
}
void fragment() {
	vec2 cellule = vec2(lp.x / 0.19, lp.z / 0.24);
	vec2 id = floor(cellule);
	vec2 f = fract(cellule);
	float rond = sin(f.x * 3.14159);
	float bout = smoothstep(0.0, 0.18, f.y);
	float ton = h(id);
	float mousse = smoothstep(0.62, 0.9, h(id * 0.37 + 4.0)) * (1.0 - rond);
	vec3 c = mix(vec3(0.035, 0.04, 0.045), vec3(0.085, 0.085, 0.09), ton * 0.6 + rond * 0.4);
	c *= 0.35 + 0.65 * bout;
	c = mix(c, vec3(0.06, 0.08, 0.04), mousse * 0.8);
	ALBEDO = c;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * MODEL_MATRIX * vec4(cos(f.x * 3.14159) * 0.5, 0.0, (1.0 - bout) * 0.5, 0.0)).xyz);
	ROUGHNESS = 0.8 - 0.15 * rond;
	SPECULAR = 0.2;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _mat_tex(nom: String, echelle: float, teinte: Color, monde := true) -> StandardMaterial3D:
	var cle := "%s_%.3f_%s_%s" % [nom, echelle, teinte.to_html(), monde]
	if _mats_tex.has(cle):
		return _mats_tex[cle]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/%s_diff.jpg" % nom)
	m.albedo_color = teinte
	m.normal_enabled = true
	m.normal_texture = load("res://textures/%s_nor.jpg" % nom)
	m.roughness_texture = load("res://textures/%s_rough.jpg" % nom)
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = monde
	m.uv1_scale = Vector3.ONE * echelle
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats_tex[cle] = m
	return m


## Le bois du pack (planches) pour les passerelles du chemin de ronde.
func _mat_planches() -> StandardMaterial3D:
	if _mats_tex.has("planches"):
		return _mats_tex["planches"]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(VILLAGE + "T_WoodTrim_BaseColor.png")
	m.albedo_color = Color(0.5, 0.44, 0.4)
	m.normal_enabled = true
	m.normal_texture = load(VILLAGE + "T_WoodTrim_Normal.png")
	m.roughness_texture = load(VILLAGE + "T_WoodTrim_Roughness.png")
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats_tex["planches"] = m
	return m


## Le bois du pack, teinté : la laque rouge des piliers, les poutres sombres, la dorure du temple.
func _bois_teint(nom: String, teinte: Color, rugueux: float) -> StandardMaterial3D:
	var cle := "bois_" + nom
	if _mats_tex.has(cle):
		return _mats_tex[cle]
	var m := (_mat_planches().duplicate() as StandardMaterial3D)
	m.albedo_color = teinte * Color(0.55, 0.55, 0.55)
	m.roughness = rugueux
	_mats_tex[cle] = m
	return m


## Le sol : boue et feuilles mortes qui s'effacent par plaques sous l'herbe rase, pavés usés
## sur la place. Un seul shader, motif collé au monde (2,5 m par tuile), deux échelles mélangées
## par un bruit pour qu'on ne voie pas la répétition.
func _mat_sol() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform sampler2D boue_a : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D boue_n : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D boue_r : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D herbe_a : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D herbe_n : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D herbe_r : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D pave_a : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D pave_n : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D pave_r : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D foret_a : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D foret_n : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D foret_r : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D roche_a : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D roche_n : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D roche_r : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float tuile = 0.4;
uniform float rayon_place = 11.0;
uniform vec3 teinte_boue = vec3(0.62, 0.57, 0.52);
uniform vec3 teinte_herbe = vec3(0.66, 0.68, 0.5);
uniform vec3 teinte_pave = vec3(0.62, 0.6, 0.58);
uniform vec3 teinte_foret = vec3(0.6, 0.55, 0.5);
uniform vec3 teinte_roche = vec3(0.5, 0.52, 0.47);
varying vec3 mp;
varying vec3 wn;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * bruit(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}
void vertex() {
	mp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}
void fragment() {
	vec2 w = mp.xz;
	vec2 u1 = w * tuile;
	vec2 u2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * w * tuile * 0.41 + vec2(3.1, 7.7);
	float k = smoothstep(0.3, 0.7, bruit(w * 0.21));
	float r = length(w);
	// plaques d'herbe : plus rares près du village, qui l'a piétinée
	float g = fbm(w * 0.085 + 5.0) + smoothstep(14.0, 34.0, r) * 0.28 - 0.1;
	float herbe = smoothstep(0.4, 0.55, g);
	float place = 1.0 - smoothstep(rayon_place - 1.4, rayon_place + 0.2, r + (fbm(w * 0.7) - 0.5) * 2.4);
	// Le village est pavé d'un bout à l'autre (un seul sol, décision d'Edwin, 29/10) ; par
	// endroits les pavés manquent et la boue remonte.
	float usure = smoothstep(0.6, 0.72, fbm(w * 0.23 + 21.0)) * 0.9;
	// Des fissures qui serpentent, coupées par endroits, et un réseau plus fin dans les pavés.
	vec2 dw = vec2(fbm(w * 0.5), fbm(w * 0.5 + 4.0)) * 0.7;
	float f1 = 1.0 - smoothstep(0.006, 0.02, abs(fbm(w * 0.16 + dw) - 0.5));
	f1 *= smoothstep(0.42, 0.55, fbm(w * 0.09 + 13.0));
	float f2 = 1.0 - smoothstep(0.004, 0.012, abs(fbm(w * 0.55 + dw * 1.6 + 7.0) - 0.5));
	f2 *= smoothstep(0.55, 0.68, fbm(w * 0.2 + 40.0));
	float fissure = clamp(f1 + f2 * 0.8, 0.0, 1.0) * place;
	// Des plaques humides, sombres, et de vieilles traînées brunes entre les pierres.
	float humide = smoothstep(0.66, 0.74, fbm(w * 0.35 + 31.0)) * place;
	float vieux_sang = smoothstep(0.71, 0.76, fbm(w * 0.42 + 57.0)) * place;
	vec3 ab = mix(texture(boue_a, u1).rgb, texture(boue_a, u2).rgb, k) * teinte_boue;
	vec3 ag = mix(texture(herbe_a, u1).rgb, texture(herbe_a, u2).rgb, k) * teinte_herbe;
	vec3 ap = mix(texture(pave_a, u1).rgb, texture(pave_a, u2).rgb, k) * teinte_pave;
	vec3 nb = mix(texture(boue_n, u1).rgb, texture(boue_n, u2).rgb, k);
	vec3 ng = mix(texture(herbe_n, u1).rgb, texture(herbe_n, u2).rgb, k);
	vec3 np = mix(texture(pave_n, u1).rgb, texture(pave_n, u2).rgb, k);
	float rb = mix(texture(boue_r, u1).r, texture(boue_r, u2).r, k);
	float rg = mix(texture(herbe_r, u1).r, texture(herbe_r, u2).r, k);
	float rp = mix(texture(pave_r, u1).r, texture(pave_r, u2).r, k);
	float m_herbe = herbe * (1.0 - place);
	// Le sous-bois : au-delà du chemin de ronde, l'humus, les aiguilles, les feuilles pourries.
	vec2 uf = w * 0.32;
	vec2 uf2 = mat2(vec2(0.6, 0.8), vec2(-0.8, 0.6)) * w * 0.21 + vec2(5.3, 1.9);
	float kf = smoothstep(0.35, 0.65, bruit(w * 0.17 + 3.0));
	vec3 af = mix(texture(foret_a, uf).rgb, texture(foret_a, uf2).rgb, kf) * teinte_foret;
	vec3 nf = mix(texture(foret_n, uf).rgb, texture(foret_n, uf2).rgb, kf);
	float rf = mix(texture(foret_r, uf).r, texture(foret_r, uf2).r, kf);
	float foret = smoothstep(21.0, 27.0, r + (fbm(w * 0.25) - 0.5) * 7.0) * (0.55 + 0.45 * smoothstep(0.3, 0.6, fbm(w * 0.12 + 9.0)));
	af *= 0.75 + 0.5 * fbm(w * 0.4 + 2.0);      // des taches sombres, humides
	// Les pentes des buttes : la roche moussue affleure.
	float pente = 1.0 - normalize(wn).y;
	float roche = smoothstep(0.16, 0.32, pente + (fbm(w * 0.3) - 0.5) * 0.18);
	vec2 ur = w * 0.18;
	vec3 sa = mix(mix(ab, ag, m_herbe), af, foret);
	vec3 sn = mix(mix(nb, ng, m_herbe), nf, foret);
	float sr = mix(mix(rb, rg, m_herbe), rf, foret);
	sa = mix(sa, texture(roche_a, ur).rgb * teinte_roche, roche);
	sn = mix(sn, texture(roche_n, ur).rgb, roche);
	sr = mix(sr, texture(roche_r, ur).r, roche);
	vec3 pave = mix(ap, ab, usure);
	vec3 col = mix(sa, pave, place);
	col *= 1.0 - 0.32 * humide;
	col = mix(col, col * vec3(0.55, 0.22, 0.18), vieux_sang * 0.75);
	col *= 1.0 - 0.82 * fissure;
	ALBEDO = col;
	NORMAL_MAP = mix(sn, mix(np, nb, usure), place);
	ROUGHNESS = mix(mix(sr, mix(rp, rb, usure), place), 0.25, humide * 0.7);
	SPECULAR = 0.3;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("boue_a", load("res://textures/brown_mud_leaves_01_diff.jpg"))
	m.set_shader_parameter("boue_n", load("res://textures/brown_mud_leaves_01_nor.jpg"))
	m.set_shader_parameter("boue_r", load("res://textures/brown_mud_leaves_01_rough.jpg"))
	m.set_shader_parameter("herbe_a", load("res://textures/sparse_grass_diff.jpg"))
	m.set_shader_parameter("herbe_n", load("res://textures/sparse_grass_nor.jpg"))
	m.set_shader_parameter("herbe_r", load("res://textures/sparse_grass_rough.jpg"))
	m.set_shader_parameter("pave_a", load("res://textures/cobblestone_floor_08_diff.jpg"))
	m.set_shader_parameter("pave_n", load("res://textures/cobblestone_floor_08_nor.jpg"))
	m.set_shader_parameter("pave_r", load("res://textures/cobblestone_floor_08_rough.jpg"))
	m.set_shader_parameter("foret_a", load("res://textures/forrest_ground_01_diff.jpg"))
	m.set_shader_parameter("foret_n", load("res://textures/forrest_ground_01_nor.jpg"))
	m.set_shader_parameter("foret_r", load("res://textures/forrest_ground_01_rough.jpg"))
	m.set_shader_parameter("roche_a", load("res://textures/mossy_rock_diff.jpg"))
	m.set_shader_parameter("roche_n", load("res://textures/mossy_rock_nor.jpg"))
	m.set_shader_parameter("roche_r", load("res://textures/mossy_rock_rough.jpg"))
	m.set_shader_parameter("rayon_place", R_CHEMIN_MIN - 0.3)
	return m


## Un secteur du chemin de ronde (anneau découpé), à plat : pas de recouvrement entre voisins.
func _secteur(a0: float, a1: float, mat: Material, y: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pas := 4
	for k in pas:
		var b0 := lerpf(a0, a1, float(k) / pas)
		var b1 := lerpf(a0, a1, float(k + 1) / pas)
		var p00 := Vector3(sin(b0), 0, cos(b0)) * R_CHEMIN_MIN
		var p01 := Vector3(sin(b0), 0, cos(b0)) * R_CHEMIN_MAX
		var p10 := Vector3(sin(b1), 0, cos(b1)) * R_CHEMIN_MIN
		var p11 := Vector3(sin(b1), 0, cos(b1)) * R_CHEMIN_MAX
		for p: Vector3 in [p00, p10, p11, p00, p11, p01]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(p.x, p.z) * 0.25)
			st.add_vertex(p)
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position.y = y
	return mi


## Bois d'un rondin : l'écorce de saule, et le bout coupé avec ses cernes.
func _mat_ecorce() -> StandardMaterial3D:
	return _mat_tex("bark_willow_02", 0.9, Color(0.58, 0.54, 0.5), false)


func _mat_bout_coupe() -> StandardMaterial3D:
	if _mat_cernes:
		return _mat_cernes
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var bruit := FastNoiseLite.new()
	bruit.seed = 7
	bruit.frequency = 0.02
	for y in 256:
		for x in 256:
			var d := Vector2(x - 128.0, y - 128.0).length() / 128.0
			var tordu := bruit.get_noise_2d(x, y) * 0.035
			var cerne := 0.5 + 0.5 * sin((d + tordu) * 62.0)
			var c := Color(0.66, 0.52, 0.34).lerp(Color(0.44, 0.31, 0.19), cerne * 0.75)
			c = c.lerp(Color(0.3, 0.2, 0.12), smoothstep(0.88, 1.0, d))     # le bord, plus sombre
			if absf(float(x) - 128.0) < 1.5 and y < 128:                    # une fente du centre vers l'écorce
				c = c.darkened(0.45)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_mat_cernes = StandardMaterial3D.new()
	_mat_cernes.albedo_texture = ImageTexture.create_from_image(img)
	_mat_cernes.albedo_color = Color(0.8, 0.76, 0.72)
	_mat_cernes.roughness = 0.9
	_mat_cernes.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return _mat_cernes


## Un siège du Conseil : une souche debout, écorce, bout coupé aux cernes, assise à 0,45 m.
## Collision : cylindre de rayon 0,4 sur toute la hauteur (couche 1, celle du sol et des murs).
func _souche_siege(i: int) -> void:
	var p := souche(i)
	var corps := StaticBody3D.new()
	corps.position = p
	corps.rotation.y = _rng.randf() * TAU
	add_child(corps)
	var h := _rng.randf_range(0.43, 0.47)
	var s := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = _rng.randf_range(0.36, 0.4)
	c.bottom_radius = _rng.randf_range(0.43, 0.5)           # l'empattement des racines
	c.height = h
	c.radial_segments = 14
	c.rings = 3
	c.cap_top = false
	c.cap_bottom = false
	s.mesh = c
	s.material_override = _mat_ecorce()
	s.position.y = h * 0.5
	corps.add_child(s)
	_bout_coupe(corps, c.top_radius, Vector3(0, h + 0.002, 0), 0.0)
	_obstacle(corps, Ronde.cylindre(0.4, 0.45), Vector3(0, 0.225, 0))


## Un disque de bois clair, aux cernes (UV en cercle), posé sur un bout de rondin.
func _bout_coupe(parent: Node3D, rayon: float, pos: Vector3, bascule: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pas := 16
	for k in pas:
		var a0 := k * TAU / pas
		var a1 := (k + 1) * TAU / pas
		for pt: Vector2 in [Vector2.ZERO, Vector2(sin(a1), cos(a1)), Vector2(sin(a0), cos(a0))]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0.5 + pt.x * 0.5, 0.5 + pt.y * 0.5))
			st.add_vertex(Vector3(pt.x * rayon * 0.99, 0, pt.y * rayon * 0.99))
	var d := MeshInstance3D.new()
	d.mesh = st.commit()
	d.material_override = _mat_bout_coupe()
	d.position = pos
	d.rotation.x = bascule
	parent.add_child(d)


## Un rondin couché (tas de bois).
func _rondin_couche(pos: Vector3, longueur: float, rayon: float, cap: float) -> void:
	var s := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = rayon
	c.bottom_radius = rayon * 1.04
	c.height = longueur
	c.radial_segments = 10
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	s.mesh = c
	s.material_override = _mat_ecorce()
	s.position = pos
	s.rotation = Vector3(PI * 0.5, cap, 0)
	add_child(s)
	_bout_coupe(s, rayon, Vector3(0, longueur * 0.5 + 0.002, 0), 0.0)
	_bout_coupe(s, rayon * 1.04, Vector3(0, -longueur * 0.5 - 0.002, 0), PI)


# ---------------------------------------------------------------- outils

func _boite(taille: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = Bouille.materiau(c, 0.01)
	return mi


func _mur(parent: Node3D, taille: Vector3, pos: Vector3, c: Color) -> void:
	var m := _boite(taille, c)
	m.position = pos
	parent.add_child(m)
	_obstacle(parent, Ronde.boite(taille), pos)


func _semis(mesh: Mesh, n: int, c: Color) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = n
	mmi.multimesh = mm
	mmi.material_override = Bouille.materiau(c, 0.0)
	add_child(mmi)
	return mmi


func _obstacle(parent: Node3D, forme: Shape3D, pos: Vector3) -> StaticBody3D:
	var corps := StaticBody3D.new()
	var c := CollisionShape3D.new()
	c.shape = forme
	corps.add_child(c)
	corps.position = pos
	parent.add_child(corps)
	return corps


static func boite(taille: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = taille
	return b


static func cylindre(rayon: float, hauteur: float) -> CylinderShape3D:
	var c := CylinderShape3D.new()
	c.radius = rayon
	c.height = hauteur
	return c
