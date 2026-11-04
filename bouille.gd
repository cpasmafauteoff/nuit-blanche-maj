class_name Bouille
extends Node3D
## Villageois de Nuit Blanche : un humain d'1,75 m au visage blafard, entièrement
## construit en code (aucun fichier 3D). Les yeux, les paupières, les sourcils,
## la bouche et la tête suivent soit le visage du joueur (via `appliquer`),
## soit une petite vie automatique pour les villageois.
## Son allure vient de `apparence` (tête, visage, habit, teinte, matière, objet, peau),
## transportée sur le réseau sous la forme d'un seul entier (`coder` / `decoder`).
## Convention : il regarde vers +Z.

const CENTRE_Y := 1.1          # hauteur du buste
const HAUT_TETE := 1.69        # centre de la tête, debout

## Les bandeaux (décision d'Edwin, 29/10) : plus aucun nom au-dessus des têtes pendant la partie,
## mais chacun porte un bandeau de couleur noué au front, tiré au hasard au lancement. Deux joueurs
## au même habit se distinguent ainsi — sans que le jeu dise jamais qui porte quelle couleur.
const BANDEAUX := [[Color(0.78, 0.08, 0.06), "rouge"], [Color(0.12, 0.3, 0.85), "bleu"],
	[Color(0.98, 0.93, 0.18), "jaune"], [Color(0.15, 0.6, 0.2), "vert"], [Color(0.95, 0.95, 0.92), "blanc"],
	[Color(0.95, 0.45, 0.05), "orange"], [Color(0.68, 0.12, 0.9), "violet"], [Color(0.95, 0.45, 0.7), "rose"],
	[Color(0.1, 0.75, 0.75), "turquoise"], [Color(0.82, 0.58, 0.16), "doré"], [Color(0.62, 0.36, 0.12), "marron"],
	[Color(0.62, 0.64, 0.68), "gris"], [Color(0.5, 0.8, 1.0), "bleu ciel"], [Color(0.62, 0.95, 0.22), "vert pomme"],
	[Color(0.45, 0.03, 0.14), "bordeaux"], [Color(0.78, 0.66, 0.98), "mauve"]]
const TETES := ["nue", "haut_de_forme", "ras", "raie", "longs", "chignons", "capuche", "courts"]
const NOMS_TETES := ["Crâne nu", "Haut-de-forme", "Cheveux ras", "Raie sur le côté", "Cheveux longs", "Chignons", "Capuche", "Cheveux courts"]
## Coiffures et capuche : modèles du même pack que le corps (Quaternius, CC0), recalés sur notre tête.
const CHEVEUX := {"ras": preload("res://modeles/cheveux/Hair_Buzzed.gltf"),
	"raie": preload("res://modeles/cheveux/Hair_SimpleParted.gltf"), "longs": preload("res://modeles/cheveux/Hair_Long.gltf"),
	"chignons": preload("res://modeles/cheveux/Hair_Buns.gltf"), "courts": preload("res://modeles/cheveux/Hair_BuzzedFemale.gltf"),
	"haut_de_forme": preload("res://modeles/cheveux/Hair_SimpleParted.gltf")}
## Les coiffures longues ont une frange plus basse : on les remonte et on les gonfle un peu, pour
## dégager les yeux et couvrir le haut de notre crâne (plus haut que le leur).
const AJUSTE_CHEVEUX := {"longs": [Vector3(1.04, 1.12, 1.06), Vector3(0, 0.03, -0.005)],
	"chignons": [Vector3(1.04, 1.12, 1.06), Vector3(0, 0.03, -0.005)], "courts": [Vector3(1.03, 1.08, 1.04), Vector3(0, 0.015, 0)]}
const BARBE := preload("res://modeles/cheveux/Hair_Beard.gltf")
const CAPUCHES := [preload("res://modeles/tenues/Male_Ranger_Head_Hood.gltf"), preload("res://modeles/tenues/Female_Ranger_Head_Hood.gltf")]
## Leur tête d'origine est réaliste ; la nôtre a le front plus haut (les yeux sont gros) et le crâne plus large.
## Le sourcil d'origine (y 1.71) se pose sur le nôtre, la largeur et la profondeur suivent notre crâne.
const CRANE_ECHELLE := Vector3(1.22, 1.0, 1.12)
const CRANE_DECALAGE := Vector3(0, -1.66, 0.0)
const BARBE_ECHELLE := Vector3(1.2, 0.65, 1.12)
const BARBE_DECALAGE := Vector3(0, -1.745, -0.017)
const VISAGES := ["fixe", "creux", "sourire", "cicatrice", "vieux", "taches"]
const NOMS_VISAGES := ["Regard fixe", "Orbites creuses", "Sourire figé", "Balafre", "Vieillard", "Taches"]
const HABITS := ["paysan", "rodeur"]
const NOMS_HABITS := ["Paysan", "Rôdeur"]
const TEINTES := [Color(0.16, 0.18, 0.16), Color(0.26, 0.1, 0.11), Color(0.24, 0.17, 0.12), Color(0.13, 0.13, 0.17),
		Color(0.3, 0.27, 0.2), Color(0.2, 0.12, 0.2), Color(0.1, 0.09, 0.09), Color(0.36, 0.33, 0.3)]
## L'étoffe choisit entre les deux jeux de couleurs du modèle de tenue.
const MATIERES := ["ordinaire", "dimanche"]
const NOMS_MATIERES := ["Ordinaire", "Du dimanche"]
## Les huit premiers sont gratuits ; la suite s'achète à la roulotte du colporteur (Cosmetiques).
const OBJETS := ["aucun", "lanterne", "chapelet", "cle", "fleur", "poupee", "pipe", "cloche",
	"lanterne_bleue", "crane_lanterne", "cloche_sonneur", "grimoire", "lanterne_fondateur", "crane_fondateur", "grimoire_fondateur"]
const NB_OBJETS_GRATUITS := 8
const NOMS_OBJETS := ["Rien", "Lanterne éteinte", "Chapelet", "Grosse clé", "Fleur fanée", "Poupée de chiffon", "Pipe", "Clochette"]
const PEAUX := [Color(0.78, 0.76, 0.7), Color(0.8, 0.74, 0.7), Color(0.7, 0.66, 0.6), Color(0.62, 0.56, 0.5)]
const YEUX := ["ronds", "noirs", "fentes", "laiteux", "rouges", "boutons", "lueur", "vairons"]
const NOMS_YEUX := ["Grands ronds", "Tout noirs", "Fentes jaunes", "Laiteux", "Injectés de sang", "Boutons cousus", "Lueur pâle", "Vairons"]
const CORPS := ["homme", "femme"]
const NOMS_CORPS := ["Homme", "Femme"]
const CHAMPS := ["tete", "visage", "habit", "teinte", "matiere", "objet", "peau", "yeux", "corps"]

## Ancienne API (couleur + chapeau) : gardée pour les appels qui ne connaissent pas l'apparence.
@export var couleur := Color(0.16, 0.18, 0.16)
@export var chapeau := ""
@export var nom_affiche := ""
var apparence := {}

var corps: Node3D            # le buste (tout ce qui est au-dessus des hanches)
var _tete: Node3D
var _visage: Node3D          # les traits humains (cachés quand il devient bête)
var _tete_loup: Node3D
var _yeux: Array[Node3D] = []
var _pupilles: Array[Node3D] = []
var _paupieres: Array[MeshInstance3D] = []
var _sourcils: Array[Node3D] = []
var _bouche_ouverte: MeshInstance3D
var _bouche_coins: Array[Node3D] = []
var _bouche_milieu: MeshInstance3D
var _machoire_n: Node3D
## Le corps : mannequin articulé (Quaternius, CC0) — vraie marche, mort, gestes.
const MODELE := preload("res://modeles/mannequin.glb")
## 0-7 : membres suivis par la webcam (bras -X, bras +X, jambe -X, jambe +X ; haut puis bas),
## 8-9 : buste, 10 : tête, 11 : bassin, 12 : main +X.
const OS_NOMS := ["DEF-upper_arm.R", "DEF-forearm.R", "DEF-upper_arm.L", "DEF-forearm.L",
	"DEF-thigh.R", "DEF-shin.R", "DEF-thigh.L", "DEF-shin.L",
	"DEF-spine.001", "DEF-spine.003", "DEF-head", "DEF-hips", "DEF-hand.L"]
## Le corps visible : une tenue complète, avec le corps qu'elle habille (Quaternius, CC0). Il ne joue
## rien lui-même : il recopie à chaque image la pose du mannequin (invisible), qui porte les animations
## et le suivi webcam. Les deux squelettes ont la même pose de repos (bras en croix).
## [homme, femme] × [paysan, rôdeur]. La tête est la nôtre.
const TENUES := [[preload("res://modeles/tenues/Male_Peasant.gltf"), preload("res://modeles/tenues/Male_Ranger.gltf")],
	[preload("res://modeles/tenues/Female_Peasant.gltf"), preload("res://modeles/tenues/Female_Ranger.gltf")]]
const TEXTURES_BIS := [preload("res://modeles/tenues/T_Peasant_2_BaseColor.png"), preload("res://modeles/tenues/T_Ranger_3_BaseColor.png")]
## Pièces du rôdeur qu'un villageois ne porte pas (armure, capuche qui passerait dans notre tête).
const PIECES_ECARTEES := ["pauldron", "bracer", "hood"]
const COPIE_OS := {"DEF-hips": "pelvis", "DEF-spine.001": "spine_01", "DEF-spine.002": "spine_02",
	"DEF-spine.003": "spine_03", "DEF-neck": "neck_01", "DEF-head": "Head",
	"DEF-shoulder.L": "clavicle_l", "DEF-upper_arm.L": "upperarm_l", "DEF-forearm.L": "lowerarm_l", "DEF-hand.L": "hand_l",
	"DEF-shoulder.R": "clavicle_r", "DEF-upper_arm.R": "upperarm_r", "DEF-forearm.R": "lowerarm_r", "DEF-hand.R": "hand_r",
	"DEF-thigh.L": "thigh_l", "DEF-shin.L": "calf_l", "DEF-foot.L": "foot_l", "DEF-toe.L": "ball_l",
	"DEF-thigh.R": "thigh_r", "DEF-shin.R": "calf_r", "DEF-foot.R": "foot_r", "DEF-toe.R": "ball_r",
	"DEF-f_index.01.L": "index_01_l", "DEF-f_index.02.L": "index_02_l", "DEF-f_index.03.L": "index_03_l",
	"DEF-f_middle.01.L": "middle_01_l", "DEF-f_middle.02.L": "middle_02_l", "DEF-f_middle.03.L": "middle_03_l",
	"DEF-f_ring.01.L": "ring_01_l", "DEF-f_ring.02.L": "ring_02_l", "DEF-f_ring.03.L": "ring_03_l",
	"DEF-f_pinky.01.L": "pinky_01_l", "DEF-f_pinky.02.L": "pinky_02_l", "DEF-f_pinky.03.L": "pinky_03_l",
	"DEF-thumb.01.L": "thumb_01_l", "DEF-thumb.02.L": "thumb_02_l", "DEF-thumb.03.L": "thumb_03_l",
	"DEF-f_index.01.R": "index_01_r", "DEF-f_index.02.R": "index_02_r", "DEF-f_index.03.R": "index_03_r",
	"DEF-f_middle.01.R": "middle_01_r", "DEF-f_middle.02.R": "middle_02_r", "DEF-f_middle.03.R": "middle_03_r",
	"DEF-f_ring.01.R": "ring_01_r", "DEF-f_ring.02.R": "ring_02_r", "DEF-f_ring.03.R": "ring_03_r",
	"DEF-f_pinky.01.R": "pinky_01_r", "DEF-f_pinky.02.R": "pinky_02_r", "DEF-f_pinky.03.R": "pinky_03_r",
	"DEF-thumb.01.R": "thumb_01_r", "DEF-thumb.02.R": "thumb_02_r", "DEF-thumb.03.R": "thumb_03_r"}
var _peaux: Array = []           # [maillage, surface] de la peau visible (mains, cou) : le loup la couvre
var _humain: Node3D
var _hsk: Skeleton3D
var _copie: Array = []           # [os mannequin, os humain, repos mannequin⁻¹, repos humain] (parents d'abord)
var _h_tete := -1
var _h_bras_d := -1
## Le bassin de la tenue est plus haut que celui du mannequin : sans ce décalage, les pieds s'enfoncent.
var _decal_bassin := 0.0
var _modele: Node3D
var _mat_peau: Material
var _sk: Skeleton3D
var _ap: AnimationPlayer
var _os: Array[int] = []
var _repos: Array[Transform3D] = []
var _torse: Node3D           # suiveurs : ils collent à un os, dans les coordonnées du villageois debout
var _cou: Node3D
var _bassin: Node3D
var _poing: Node3D
## Essais : montrer le mannequin (qui porte les animations) à côté du corps visible.
static var voir_mannequin := false
var _liens: Array = []           # [suiveur, os de l'humain, repos⁻¹] : ce qui colle au corps visible
var _main: Node3D
var _tete_rot := Vector3.ZERO
var _dir_suivi: Array[Vector3] = []
var _poids_suivi := PackedFloat32Array()
var _parle_t := 0.0
## Mort : il s'effondre et reste au sol.
var mort := false
var assis := false   # sur son rondin, au Conseil
var couche := false  # attaché sur la pierre, après le vote
var accroupi := false  # Ctrl tenu : il marche accroupi (une animation le relève)
const AVANCE_ASSIS := 0.36
var _avance_assis := 0.0
var corps_suivi := PackedFloat32Array()
## Il tient un objet dans la main droite : son bras se lève pour le porter (sauf si un geste ou la webcam le mène).
var tient_objet := false
## Mon propre bras droit s'efface : à la première personne, c'est le bras tenu devant mes yeux qui le remplace
## (sinon deux bras droits, dont un d'une autre matière).
var bras_droit_cache := false
var _manche_c := Color.BLACK
var _manche_ok := false
## Mains et doigts vus par la webcam (44 nombres, cf. capteur_web/capteur.js lireMains) ; vide sinon.
var mains_suivi := PackedFloat32Array()
## « Ma tête » : la photo du joueur posée sur le visage (cf. MaTete), ou null.
var _photo: MeshInstance3D
var _cernes: Array[Node3D] = []
## Geste ou danse en cours (cf. Emotes), "" sinon ; il s'arrête quand on marche.
var emote := ""
var cible_emote: Node3D                  # celui qu'on montre du doigt (le geste « pointer » / « montrer »)
var _emote_t := 0.0
var _emote_bras := PackedFloat32Array()
var _emote_mains := PackedFloat32Array()
var _os_mains: Array[int] = []           # [droite, gauche]
var _os_doigts: Array = []               # [main][doigt][phalange] -> os
var _poids_main := [0.0, 0.0]
var _dir_main: Array[Vector3] = [Vector3.DOWN, Vector3.DOWN]
var _norm_main: Array[Vector3] = [Vector3.FORWARD, Vector3.FORWARD]
var _plis := PackedFloat32Array()        # 2 × 15 angles lissés
# Souplesse : les membres suivis ont de l'inertie (ressort amorti), le buste se penche dans
# l'accélération, les bras traînent quand on tourne, et l'on respire.
var _vit_suivi: Array[Vector3] = []
var _pos_avant := Vector3.ZERO
var _vit_avant := Vector3.ZERO
var _cap_avant := 0.0
var _penche := Vector2.ZERO              # x : avant/arrière, y : côté (radians)
var _penche_v := Vector2.ZERO
var _trainee := 0.0                      # retard des bras quand on tourne
var _trainee_v := 0.0
var _souffle := randf() * TAU
var _corps_t := 0.0
var _bulle: Label3D
var _etiquette: Label3D
var _bandeau: Node3D
var bandeau := -1           # rang dans BANDEAUX, -1 : aucun
var _mat_iris: StandardMaterial3D
var _sourire_fige := 0.0

# État lissé des expressions.
var _ouv := [1.0, 1.0]
var _sourire := 0.0
var _moue := 0.0
var _machoire := 0.0
var _sourcil_bas := [0.0, 0.0]
var _sourcil_haut_int := 0.0
var _sourcil_haut_ext := [0.0, 0.0]
var _joue := 0.0
var _regard_local := [Vector2.ZERO, Vector2.ZERO]
var _tete_cible := Vector3.ZERO  # lacet, tangage, roulis (radians)
## Niveau de la voix qui sort de ce villageois (0 = silence, ~0.15 = fort) : la mâchoire suit.
var parole := 0.0
var _parole_ouv := 0.0
var _langue: MeshInstance3D
var _langue_v := 0.0
var _bisou := 0.0
var _travers := 0.0
var _nez := 0.0
var _nez_n: MeshInstance3D

# Vie automatique (villageois).
var autonome := true
var _prochain_clin := 2.0
var _clin_t := -1.0
var _cible_regard: Vector3 = Vector3.ZERO
var _a_une_cible := false
var _t := 0.0
var _marche := 0.0
var _phase_pas := 0.0
var est_loup := false
var dort := false:
	set(v):
		if dort and not v:
			_ouv = [1.0, 1.0]
		dort = v
var _bulle_t := 0.0
## Tenue, familier, traces et allure de fantôme achetés à la roulotte (cf. atours.gd).
var _atours: Atours


func _ready() -> void:
	if apparence.is_empty():
		apparence = _depuis_ancienne_api()
	_construire()
	_prochain_clin = randf_range(1.5, 4.0)
	_t = randf() * 10.0


# ================================================================ apparence

## Range une apparence dans un entier (4 bits par champ) pour le réseau.
static func coder(a: Dictionary) -> int:
	var n := 0
	for i in CHAMPS.size():
		n |= (int(a.get(CHAMPS[i], 0)) & 15) << (4 * i)
	# Les cosmétiques portés (bits 36 à 63), cf. Cosmetiques.
	for e: String in Cosmetiques.EMPLACEMENTS:
		if a.has(e):
			n = Cosmetiques.poser(n, e, str(a[e]))
	return n


static func decoder(n: int) -> Dictionary:
	var tailles := [TETES.size(), VISAGES.size(), HABITS.size(), TEINTES.size(), MATIERES.size(), OBJETS.size(), PEAUX.size(), YEUX.size(), CORPS.size()]
	var a := {}
	for i in CHAMPS.size():
		a[CHAMPS[i]] = ((n >> (4 * i)) & 15) % int(tailles[i])
	a.merge(Cosmetiques.lire(n))
	return a


static func au_hasard(rng: RandomNumberGenerator) -> int:
	return coder({"tete": rng.randi_range(0, TETES.size() - 1), "visage": rng.randi_range(0, VISAGES.size() - 1),
		"habit": rng.randi_range(0, HABITS.size() - 1), "teinte": rng.randi_range(0, TEINTES.size() - 1),
		"matiere": rng.randi_range(0, MATIERES.size() - 1), "objet": rng.randi_range(0, NB_OBJETS_GRATUITS - 1),
		"peau": rng.randi_range(0, PEAUX.size() - 1), "yeux": rng.randi_range(0, YEUX.size() - 1),
		"corps": rng.randi_range(0, CORPS.size() - 1)})


func _depuis_ancienne_api() -> Dictionary:
	var a := {"tete": 0, "visage": 0, "habit": 0, "teinte": 6, "matiere": 0, "objet": 0, "peau": 2}
	var i := TETES.find(chapeau)
	if i >= 0:
		a["tete"] = i
	return a


# ================================================================ matériaux

static func materiau(c: Color, contour := 0.012, emission := Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.6
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = 1.5
	if contour > 0:
		var contour_mat := StandardMaterial3D.new()
		contour_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		contour_mat.albedo_color = Color(0.08, 0.05, 0.1)
		contour_mat.cull_mode = BaseMaterial3D.CULL_FRONT
		contour_mat.grow = true
		contour_mat.grow_amount = contour
		m.next_pass = contour_mat
	return m


static func sphere(rayon: float, mat: Material, echelle := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = rayon
	s.height = rayon * 2.0
	s.radial_segments = 24
	s.rings = 12
	mi.mesh = s
	mi.material_override = mat
	mi.scale = echelle
	return mi


static func capsule(rayon: float, hauteur: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = rayon
	c.height = hauteur
	mi.mesh = c
	mi.material_override = mat
	return mi


func _mat(c: Color, rugueux := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugueux
	return m


func _noir() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _lueur(c: Color, force := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = force
	return m


## Tissu : trame, mailles ou grain dessinés par `tissu.gdshader` (relief, taches, boue).
## `echelle` : densité du motif — les formes simples (pans, bonnets) n'ont pas les UV du corps.
const TISSU := preload("res://tissu.gdshader")
const MATIERES_SHADER := {"laine": 0, "cuir": 1, "toile": 2, "velours": 3}
const ECHELLE_CORPS := 125.0


func _tissu(c: Color, matiere: String, echelle := 46.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TISSU
	m.set_shader_parameter("couleur", c)
	m.set_shader_parameter("matiere", MATIERES_SHADER.get(matiere, 0))
	m.set_shader_parameter("echelle", echelle)
	return m


# ================================================================ formes

func _boule(p: Node3D, r: float, mat: Material, pos: Vector3, ech := Vector3.ONE) -> MeshInstance3D:
	var m := sphere(r, mat, ech)
	m.position = pos
	p.add_child(m)
	return m


func _boite(p: Node3D, taille: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	m.mesh = b
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	p.add_child(m)
	return m


func _cone(p: Node3D, r_haut: float, r_bas: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_haut
	c.bottom_radius = r_bas
	c.height = h
	c.radial_segments = 16
	m.mesh = c
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	p.add_child(m)
	return m


func _membre(p: Node3D, a: Vector3, b: Vector3, r: float, mat: Material, r_fin := -1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r if r_fin < 0 else r_fin
	c.height = maxf(a.distance_to(b), 0.001)
	c.radial_segments = 8
	c.rings = 1
	m.mesh = c
	m.material_override = mat
	p.add_child(m)
	m.position = (a + b) * 0.5
	var dir := (a - b).normalized()
	var axe := Vector3.UP.cross(dir)
	if axe.length() > 0.0001:
		m.basis = Basis(axe.normalized(), Vector3.UP.angle_to(dir))
	elif dir.y < 0:
		m.basis = Basis(Vector3.RIGHT, PI)
	return m


func _anneau(p: Node3D, r_int: float, r_ext: float, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = r_int
	t.outer_radius = r_ext
	t.rings = 16
	t.ring_segments = 8
	m.mesh = t
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	p.add_child(m)
	return m


# ================================================================ construction

func _construire() -> void:
	var tenue := str(apparence.get("tenue", ""))
	if tenue != "":
		var t_reglage: Array = Atours.REGLAGE_TENUE.get(tenue, [])
		if t_reglage.size() == 3:
			apparence["habit"] = t_reglage[0]
			apparence["matiere"] = t_reglage[1]
		if Atours.a_un_chapeau(tenue) and TETES[int(apparence.get("tete", 0))] in ["haut_de_forme", "capuche"]:
			apparence["tete"] = TETES.find("courts")
	var tete_n: String = TETES[int(apparence.get("tete", 0))]
	var visage_n: String = VISAGES[int(apparence.get("visage", 0))]
	var habit_n: String = HABITS[int(apparence.get("habit", 0)) % HABITS.size()]
	var objet_n: String = OBJETS[int(apparence.get("objet", 0))]
	var teinte: Color = TEINTES[int(apparence.get("teinte", 0))]
	if Atours.REGLAGE_TENUE.has(tenue):
		teinte = Atours.REGLAGE_TENUE[tenue][2]
	var peau_c: Color = PEAUX[int(apparence.get("peau", 0))]
	var peau := _mat(peau_c, 0.7)
	var cerne := _mat(peau_c.darkened(0.45), 0.9)
	var cheveux := _mat(Color(0.12, 0.09, 0.07) if visage_n != "vieux" else Color(0.55, 0.53, 0.5), 0.8)

	# Le corps animé
	_modele = MODELE.instantiate()
	add_child(_modele)
	_sk = _modele.find_child("Skeleton3D", true, false)
	_ap = _modele.find_child("AnimationPlayer", true, false)
	(_modele.find_child("Mannequin", true, false) as MeshInstance3D).visible = voir_mannequin
	var rodeur := HABITS.find(habit_n)
	_humain = (TENUES[int(apparence.get("corps", 0)) % TENUES.size()][rodeur] as PackedScene).instantiate()
	add_child(_humain)
	_hsk = _humain.find_children("*", "Skeleton3D", true, false)[0]
	# Le tissu prend la teinte choisie (multipliée sur la texture, assombrie : rien de propre au village).
	var variante := int(apparence.get("matiere", 0)) == 1
	var mats := {}
	for mi: MeshInstance3D in _humain.find_children("*", "MeshInstance3D", true, false):
		var nom := mi.name.to_lower()
		if PIECES_ECARTEES.any(func(p: String) -> bool: return nom.contains(p)):
			mi.visible = false
			continue
		for k in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(k)
			if source == null:
				continue
			if source.resource_name.contains("Regular"):
				mi.set_surface_override_material(k, peau)
				_peaux.append([mi, k])
				continue
			if not mats.has(source):
				var m := source.duplicate() as StandardMaterial3D
				if variante:
					m.albedo_texture = TEXTURES_BIS[rodeur]
				m.albedo_color = teinte.lerp(Color(0.62, 0.58, 0.52), 0.55)
				mats[source] = m
			mi.set_surface_override_material(k, mats[source])
	_mat_peau = peau
	for n: String in OS_NOMS:
		var i := _sk.find_bone(n)
		_os.append(i)
		_repos.append(_sk.get_bone_global_rest(i).orthonormalized().affine_inverse())
	for k in 9:
		_dir_suivi.append(Vector3.DOWN)
		_vit_suivi.append(Vector3.ZERO)
	_poids_suivi.resize(9)
	for cote in ["R", "L"]:
		_os_mains.append(_sk.find_bone("DEF-hand." + cote))
		var main := []
		for doigt in ["thumb", "f_index", "f_middle", "f_ring", "f_pinky"]:
			var phalanges: Array[int] = []
			for j in 3:
				phalanges.append(_sk.find_bone("DEF-%s.0%d.%s" % [doigt, j + 1, cote]))
			main.append(phalanges)
		_os_doigts.append(main)
	_plis.resize(30)
	_pos_avant = global_position if is_inside_tree() else Vector3.ZERO
	var mod := SuiviOs.new()
	mod.bouille = self
	_sk.add_child(mod)
	_sk.skeleton_updated.connect(_suivre_os)
	for i in _sk.get_bone_count():           # ordre du squelette = parents avant enfants
		var n := _sk.get_bone_name(i)
		if COPIE_OS.has(n):
			var h := _hsk.find_bone(COPIE_OS[n])
			if h >= 0:
				_copie.append([i, h, _sk.get_bone_global_rest(i).basis.orthonormalized().inverse(),
					_hsk.get_bone_global_rest(h).basis.orthonormalized()])
	_h_tete = _hsk.find_bone("Head")
	_h_bras_d = _hsk.find_bone("upperarm_r")
	_decal_bassin = _hsk.get_bone_global_rest(_hsk.find_bone("pelvis")).origin.y - _sk.get_bone_global_rest(_sk.find_bone("DEF-hips")).origin.y
	_ap.play("Idle")
	_ap.seek(randf() * 2.0, true)          # pas tous dans le même temps
	_torse = _lier("spine_03")
	_cou = _lier("Head")
	_bassin = _lier("pelvis")
	_poing = _lier("hand_l")
	_main = Node3D.new()
	_main.position = _repos_h("hand_l") + Vector3(0.07, 0, 0.0)
	_main.rotation.z = PI / 2              # le « bas » de la main suit les doigts
	_poing.add_child(_main)

	# Buste
	corps = Node3D.new()
	corps.position = Vector3(0, CENTRE_Y, 0)
	_torse.add_child(corps)

	# Tête
	_tete = Node3D.new()
	_tete.position = _repos_h("Head") + Vector3(0, 0.065, 0.05)   # posée sur le cou du corps choisi
	_tete.scale = Vector3.ONE * 1.15      # une tête un peu forte : le visage est ce qu'on regarde
	_cou.add_child(_tete)
	# Le cou : la tenue s'arrête au col, le corps qu'elle habille n'a pas de cou visible.
	_membre(_cou, _repos_h("neck_01") + Vector3(0, -0.02, 0.0), _tete.position + Vector3(0, -0.06, -0.03), 0.045, peau, 0.04)
	_visage = Node3D.new()
	_tete.add_child(_visage)
	_boule(_visage, 0.105, peau, Vector3.ZERO, Vector3(0.88, 1.12, 1.0))
	_machoire_n = Node3D.new()
	_visage.add_child(_machoire_n)
	_boule(_machoire_n, 0.06, peau, Vector3(0, -0.06, 0.025), Vector3(1.0, 0.9, 1.1))
	for c: int in [-1, 1]:
		_boule(_visage, 0.018, peau, Vector3(c * 0.094, 0.0, 0.0), Vector3(0.45, 1.0, 0.8))      # oreilles
	_nez_n = _boule(_visage, 0.014, peau, Vector3(0, -0.02, 0.1), Vector3(0.8, 1.6, 1.2))        # nez

	# Yeux : gros et lisibles de loin (c'est ce qu'on regarde chez l'autre), dans un style au choix.
	# Le globe s'écrase pour cligner ; le pivot porte l'iris, qui suit la cible.
	var yeux_n: String = YEUX[int(apparence.get("yeux", 0)) % YEUX.size()]
	_mat_iris = _mat(Color(0.03, 0.02, 0.02), 0.2)
	var creux := visage_n == "creux"
	var r := 0.031            # le blanc de l'oeil, bien visible de loin
	var globe: Material = _mat(Color(0.88, 0.87, 0.82), 0.25)
	(globe as StandardMaterial3D).emission_enabled = true
	(globe as StandardMaterial3D).emission = Color(0.88, 0.87, 0.82)
	(globe as StandardMaterial3D).emission_energy_multiplier = 0.12
	var iris_r := 0.0
	var iris_c := Color.BLACK
	var pupille := 0.009
	match yeux_n:
		"noirs":
			globe = _mat(Color(0.02, 0.02, 0.02), 0.08)
			pupille = 0.0
		"fentes":
			globe = _lueur(Color(0.85, 0.66, 0.12), 0.5)
			pupille = 0.0
		"laiteux":
			globe = _mat(Color(0.72, 0.76, 0.8), 0.2)
			iris_r = 0.013
			iris_c = Color(0.86, 0.88, 0.9)
			pupille = 0.004
		"rouges":
			globe = _mat(Color(0.82, 0.6, 0.57), 0.3)
			iris_r = 0.013
			iris_c = Color(0.5, 0.04, 0.03)
			pupille = 0.006
		"boutons":
			globe = _mat(Color(0.05, 0.04, 0.04), 0.15)
			pupille = 0.0
		"lueur":
			globe = _lueur(Color(0.78, 0.9, 0.82), 1.8)
			pupille = 0.006
		"vairons":
			iris_r = 0.014
			pupille = 0.006
	for c: int in [-1, 1]:
		var x := 0.045 * c
		_cernes.append(_boule(_visage, r + 0.005 if not creux else 0.033, cerne if not creux else _noir(), Vector3(x, 0.01, 0.084), Vector3(1.12, 1.0, 0.5)))
		var oeil := Node3D.new()
		oeil.position = Vector3(x, 0.012, 0.094)
		_visage.add_child(oeil)
		var avant := r * 0.7             # la surface du globe, vers l'avant
		if not creux:
			var g := _boule(oeil, r, globe, Vector3.ZERO, Vector3(1, 1, 0.7))
			if yeux_n == "boutons":
				g.scale = Vector3(1, 1, 0.45)
				for k in 4:                  # quatre trous, et le fil cousu en croix
					var a := k * TAU / 4.0 + PI / 4
					_boule(oeil, 0.0035, _mat(Color(0.4, 0.38, 0.34)), Vector3(cos(a) * 0.008, sin(a) * 0.008, r * 0.45 + 0.001))
				for d: float in [0.8, -0.8]:
					_boite(oeil, Vector3(0.024, 0.0025, 0.002), _mat(Color(0.55, 0.12, 0.1)), Vector3(0, 0, r * 0.45 + 0.003), Vector3(0, 0, d))
		var pivot := Node3D.new()
		oeil.add_child(pivot)
		var voile := visage_n == "cicatrice" and c == 1
		if creux:
			_boule(pivot, 0.004, _lueur(Color(1, 0.95, 0.85), 1.6), Vector3(0, 0, 0.009), Vector3(1, 1, 0.4))
		elif yeux_n == "fentes":
			_boule(pivot, 0.012, _mat_iris, Vector3(0, 0, avant - 0.002), Vector3(0.22, 1.5, 0.4))
		elif yeux_n != "boutons":
			if yeux_n == "vairons":
				iris_c = Color(0.25, 0.5, 0.65) if c == -1 else Color(0.35, 0.22, 0.1)
			if iris_r > 0.0:
				_boule(pivot, iris_r, _mat(iris_c, 0.3), Vector3(0, 0, avant - 0.003), Vector3(1, 1, 0.35))
			if pupille > 0.0:
				_boule(pivot, pupille, _mat_iris if not voile else _mat(Color(0.75, 0.78, 0.8), 0.2), Vector3(0, 0, avant - 0.001), Vector3(1, 1, 0.35))
		if not creux and yeux_n != "boutons":
			_boule(pivot, 0.004, _lueur(Color(1, 0.95, 0.85), 1.5), Vector3(0.006, 0.007, avant + 0.001))   # éclat
		var paupiere := _boite(_visage, Vector3(0.058, 0.005, 0.008), cerne, Vector3(x, 0.01, 0.1))
		paupiere.visible = false
		_yeux.append(oeil)
		_pupilles.append(pivot)
		_paupieres.append(paupiere)
		var sourcil := Node3D.new()
		sourcil.position = Vector3(x, 0.056, 0.094)
		_visage.add_child(sourcil)
		var epais := 0.009 if visage_n == "vieux" else 0.005
		_boite(sourcil, Vector3(0.05, epais, 0.008), cheveux, Vector3.ZERO)
		_sourcils.append(sourcil)

	# Bouche (dans la mâchoire : elle descend quand on parle)
	var mat_levres := _mat(Color(0.25, 0.12, 0.1) if visage_n != "taches" else Color(0.4, 0.1, 0.08))
	_bouche_ouverte = _boule(_machoire_n, 0.02, _noir(), Vector3(0, -0.068, 0.086), Vector3(1.1, 0.1, 0.4))
	_langue = _boule(_machoire_n, 0.016, _mat(Color(0.55, 0.22, 0.24), 0.5), Vector3(0, -0.072, 0.086), Vector3(0.9, 0.4, 1.8))
	_langue.visible = false
	_bouche_milieu = _boite(_machoire_n, Vector3(0.024, 0.004, 0.006), mat_levres, Vector3(0, -0.068, 0.09))
	for c: int in [-1, 1]:
		var coin := Node3D.new()
		coin.position = Vector3(0.011 * c, -0.068, 0.089)
		_boite(coin, Vector3(0.016, 0.004, 0.006), mat_levres, Vector3(0.008 * c, 0, 0))
		_machoire_n.add_child(coin)
		_bouche_coins.append(coin)

	match visage_n:
		"sourire":
			_sourire_fige = 0.9
			_boite(_machoire_n, Vector3(0.05, 0.007, 0.004), _mat(Color(0.86, 0.82, 0.7), 0.4), Vector3(0, -0.071, 0.091))
		"cicatrice":
			var rouge := _mat(Color(0.4, 0.12, 0.1))
			_boite(_visage, Vector3(0.006, 0.08, 0.006), rouge, Vector3(0.04, 0.0, 0.097), Vector3(0, 0, 0.35))
			for k in 4:
				_boite(_visage, Vector3(0.014, 0.003, 0.006), rouge, Vector3(0.04 - 0.012 + k * 0.006, 0.03 - k * 0.02, 0.097))
		"vieux":
			for k in 3:
				_boite(_visage, Vector3(0.05 - k * 0.008, 0.002, 0.004), cerne, Vector3(0, 0.07 + k * 0.012, 0.086 - k * 0.006))
			_greffer(BARBE, _machoire_n, BARBE_ECHELLE, BARBE_DECALAGE, _teinte_cheveux())
		"taches":
			var t := _mat(peau_c.darkened(0.55))
			var rng := RandomNumberGenerator.new()
			rng.seed = int(apparence.get("peau", 0)) * 31 + 7
			for k in 9:
				var a := rng.randf_range(-1.2, 1.2)
				var h := rng.randf_range(-0.07, 0.07)
				_boule(_visage, rng.randf_range(0.004, 0.009), t, Vector3(sin(a) * 0.09, h, cos(a) * 0.098), Vector3(1, 1, 0.3))

	_coiffer(tete_n, cheveux)
	_porter(objet_n)
	_construire_tete_loup()
	_atours = Atours.new()
	_atours.name = "Atours"
	add_child(_atours)
	_atours.habiller(self, apparence)

	_bulle = Label3D.new()
	_bulle.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bulle.position.y = 2.3
	# Petite, coupée en lignes, et cachée de trop près : collée au visage, une bulle de 96 px
	# couvrait tout l'écran et passait sous le panneau de quête.
	_bulle.font = Style.police("italique")
	_bulle.font_size = 44
	_bulle.pixel_size = 0.004
	_bulle.outline_size = 12
	_bulle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bulle.width = 420
	_bulle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_bulle.visibility_range_begin = 1.8
	_bulle.modulate = Color(1, 0.95, 0.6)
	_bulle.text = ""
	add_child(_bulle)

	if nom_affiche != "":
		_etiquette = Label3D.new()
		_etiquette.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_etiquette.text = nom_affiche
		_etiquette.font = Style.police("titre")
		_etiquette.font_size = 40
		_etiquette.outline_size = 12
		_etiquette.position.y = 2.05
		_etiquette.pixel_size = 0.004
		_etiquette.visibility_range_begin = 1.8
		_etiquette.modulate = Color(1, 1, 1, 0.8)
		add_child(_etiquette)


func _coiffer(sorte: String, _cheveux: Material) -> void:
	if CHEVEUX.has(sorte):
		var aj: Array = AJUSTE_CHEVEUX.get(sorte, [Vector3.ONE, Vector3.ZERO])
		var g := _greffer(CHEVEUX[sorte], _visage, CRANE_ECHELLE * (aj[0] as Vector3), CRANE_DECALAGE, _teinte_cheveux())
		g.position += aj[1]
	match sorte:
		"haut_de_forme":
			var feutre := _mat(Color(0.07, 0.06, 0.06), 0.85)
			_cone(_visage, 0.085, 0.09, 0.19, feutre, Vector3(0, 0.235, -0.01), Vector3(-0.06, 0, 0))
			_cone(_visage, 0.15, 0.15, 0.012, feutre, Vector3(0, 0.14, -0.01))
			_cone(_visage, 0.091, 0.091, 0.03, _mat(Color(0.18, 0.05, 0.04), 0.6), Vector3(0, 0.162, -0.01))   # ruban
		"capuche":
			var drap := (TEINTES[int(apparence.get("teinte", 0))] as Color).lerp(Color(0.62, 0.58, 0.52), 0.55)
			_greffer(CAPUCHES[int(apparence.get("corps", 0)) % CAPUCHES.size()], _visage, CRANE_ECHELLE * Vector3(1.0, 1.05, 1.0), CRANE_DECALAGE + Vector3(0, -0.04, -0.01), drap)


func _teinte_cheveux() -> Color:
	# Les textures de cheveux sont grises : la couleur se multiplie dessus.
	return Color(1.2, 1.18, 1.12) if VISAGES[int(apparence.get("visage", 0))] == "vieux" else Color(0.3, 0.22, 0.17)


## Pose un modèle du pack (fait pour une tête réaliste) sur la nôtre, teinté. Les maillages animés
## (la capuche suit l'os de la tête) sont figés dans leur pose de repos : ils suivent déjà notre tête.
func _greffer(scene: PackedScene, parent: Node3D, echelle: Vector3, decalage: Vector3, teinte: Color) -> Node3D:
	var n := Node3D.new()
	n.scale = echelle
	n.position = decalage * echelle
	parent.add_child(n)
	var inst := scene.instantiate()
	n.add_child(inst)
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		mi.skin = null
		mi.skeleton = NodePath()
		for k in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(k)
			if source is StandardMaterial3D:
				var m := source.duplicate() as StandardMaterial3D
				m.albedo_color = teinte
				mi.set_surface_override_material(k, m)
	return n


func _porter(sorte: String) -> void:
	var main: Node3D = _main                         # une main (côté +X)
	var poignet := Vector3(0.0, -0.03, 0.0)
	match sorte:
		"lanterne":
			# Lanterne de fer forgé, vitres encrassées, bougie morte : un anneau, un chapeau, quatre montants.
			var fer := _mat(Color(0.1, 0.09, 0.08), 0.45)
			fer.metallic = 0.6
			var vitre := _mat(Color(0.32, 0.3, 0.22, 0.45), 0.15)
			vitre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var c := poignet + Vector3(0, -0.2, 0.01)
			_anneau(main, 0.012, 0.018, fer, poignet + Vector3(0, -0.035, 0), Vector3(0, 0, PI / 2))
			_membre(main, poignet + Vector3(0, -0.05, 0), c + Vector3(0, 0.1, 0), 0.0035, fer)
			_cone(main, 0.012, 0.06, 0.05, fer, c + Vector3(0, 0.085, 0))                      # chapeau
			_cone(main, 0.062, 0.062, 0.012, fer, c + Vector3(0, 0.058, 0))
			_cone(main, 0.06, 0.06, 0.016, fer, c + Vector3(0, -0.066, 0))                     # socle
			_cone(main, 0.052, 0.052, 0.11, vitre, c)
			for k in 4:
				var a := k * TAU / 4.0 + PI / 4
				_membre(main, c + Vector3(cos(a) * 0.055, -0.06, sin(a) * 0.055), c + Vector3(cos(a) * 0.055, 0.058, sin(a) * 0.055), 0.004, fer)
			_cone(main, 0.011, 0.012, 0.045, _mat(Color(0.78, 0.74, 0.62), 0.6), c + Vector3(0, -0.035, 0))   # bougie
			_boite(main, Vector3(0.002, 0.008, 0.002), _noir(), c + Vector3(0, -0.008, 0))                    # mèche
		"chapelet":
			var bois := _mat(Color(0.2, 0.12, 0.08), 0.5)
			for k in 14:
				var a := k * TAU / 14.0
				_boule(corps, 0.008, bois, Vector3(sin(a) * 0.075, 0.43 - absf(cos(a * 0.5)) * 0.12, 0.05 + cos(a) * 0.05))
			_boite(corps, Vector3(0.006, 0.035, 0.004), bois, Vector3(0, 0.29, 0.155))
			_boite(corps, Vector3(0.022, 0.006, 0.004), bois, Vector3(0, 0.298, 0.155))
		"cle":
			var fer := _mat(Color(0.32, 0.28, 0.22), 0.35)
			fer.metallic = 0.7
			_anneau(_bassin, 0.016, 0.024, fer, Vector3(0.17, 0.92, 0.12), Vector3(PI / 2, 0, 0))
			_membre(_bassin, Vector3(0.17, 0.9, 0.12), Vector3(0.17, 0.77, 0.12), 0.005, fer)
			_boite(_bassin, Vector3(0.025, 0.012, 0.004), fer, Vector3(0.18, 0.78, 0.12))
		"fleur":
			var tige := _mat(Color(0.18, 0.2, 0.1))
			_membre(corps, Vector3(-0.09, 0.3, 0.19), Vector3(-0.1, 0.4, 0.2), 0.003, tige)
			for k in 5:
				var a := k * TAU / 5.0
				_boule(corps, 0.012, _mat(Color(0.3, 0.05, 0.06)), Vector3(-0.1 + sin(a) * 0.012, 0.39, 0.2 + cos(a) * 0.012), Vector3(1, 0.5, 1))
		"poupee":
			# Poupée de chiffon tenue par un bras : un œil-bouton, l'autre cousu en croix.
			var chiffon := _tissu(Color(0.58, 0.48, 0.4), "toile", 14.0)
			var fil := _mat(Color(0.35, 0.08, 0.07))
			var p := poignet + Vector3(0, -0.1, 0.02)
			_boule(main, 0.042, chiffon, p, Vector3(0.9, 1.25, 0.75))                       # corps
			_boule(main, 0.036, chiffon, p + Vector3(0, 0.075, 0))                           # tête
			for c: int in [-1, 1]:
				_membre(main, p + Vector3(c * 0.03, 0.02, 0), p + Vector3(c * 0.055, -0.03, 0.005), 0.012, chiffon)
				_membre(main, p + Vector3(c * 0.018, -0.04, 0), p + Vector3(c * 0.022, -0.1, 0.01), 0.013, chiffon)
			_boule(main, 0.008, _noir(), p + Vector3(-0.013, 0.082, 0.031), Vector3(1, 1, 0.4))
			_boite(main, Vector3(0.016, 0.003, 0.003), fil, p + Vector3(0.013, 0.082, 0.033), Vector3(0, 0, 0.8))
			_boite(main, Vector3(0.016, 0.003, 0.003), fil, p + Vector3(0.013, 0.082, 0.033), Vector3(0, 0, -0.8))
			_boite(main, Vector3(0.02, 0.003, 0.003), fil, p + Vector3(0, 0.06, 0.033))       # bouche cousue
		"pipe":
			var bois := _mat(Color(0.25, 0.14, 0.08), 0.4)
			_membre(_machoire_n, Vector3(0.015, -0.07, 0.09), Vector3(0.045, -0.085, 0.13), 0.004, bois)
			_cone(_machoire_n, 0.011, 0.009, 0.025, bois, Vector3(0.048, -0.075, 0.135))
		"cloche":
			# Clochette de laiton au bout d'un manche de bois, battant visible.
			var laiton := _mat(Color(0.48, 0.38, 0.18), 0.3)
			laiton.metallic = 0.85
			var bois := _mat(Color(0.2, 0.12, 0.08), 0.6)
			var c := poignet + Vector3(0, -0.09, 0.02)
			_membre(main, poignet + Vector3(0, 0.02, 0.02), c + Vector3(0, 0.03, 0), 0.009, bois)
			_boule(main, 0.03, laiton, c + Vector3(0, 0.005, 0), Vector3(1, 0.7, 1))
			_cone(main, 0.03, 0.05, 0.055, laiton, c + Vector3(0, -0.03, 0))
			_cone(main, 0.05, 0.052, 0.006, laiton, c + Vector3(0, -0.058, 0))
			_boule(main, 0.01, _mat(Color(0.08, 0.07, 0.06), 0.5), c + Vector3(0, -0.062, 0))


## La bête (seulement pour la cinématique et un loup démasqué) : museau, oreilles, crinière.
func _construire_tete_loup() -> void:
	_tete_loup = Node3D.new()
	_tete_loup.visible = false
	_tete.add_child(_tete_loup)
	var poil := _tissu(Color(0.18, 0.17, 0.17), "laine")
	_boule(_tete_loup, 0.12, poil, Vector3(0, 0.0, 0.0), Vector3(0.95, 1.0, 1.1))
	_cone(_tete_loup, 0.03, 0.065, 0.16, poil, Vector3(0, -0.035, 0.14), Vector3(PI / 2 + 0.15, 0, 0))
	_boule(_tete_loup, 0.018, _noir(), Vector3(0, -0.02, 0.22))
	var dent := _mat(Color(0.85, 0.82, 0.7), 0.3)
	for c: int in [-1, 1]:
		_cone(_tete_loup, 0.0, 0.045, 0.13, poil, Vector3(c * 0.065, 0.13, -0.01), Vector3(0, 0, -c * 0.3))
		_boule(_tete_loup, 0.013, _lueur(Color(1.0, 0.15, 0.05), 4.0), Vector3(c * 0.045, 0.03, 0.105))
		_cone(_tete_loup, 0.0, 0.006, 0.025, dent, Vector3(c * 0.025, -0.085, 0.17), Vector3(PI, 0, 0))
	_boule(_tete_loup, 0.17, poil, Vector3(0, -0.13, -0.03), Vector3(1.2, 0.6, 1.0))


# ================================================================ API

## Applique le visage du joueur. `bs` = expressions MediaPipe (0..1).
## `regard_monde` : point 3D que l'avatar doit regarder.
func appliquer(bs: Dictionary, tx: float, ty: float, roulis: float, regard_monde: Vector3) -> void:
	autonome = false
	var g := func(n): return float(bs.get(n, 0.0))
	# MediaPipe nomme les yeux du point de vue du visage ; image en miroir :
	# l'œil « Right » apparaît à gauche de l'écran, comme l'œil gauche de l'avatar
	# qui nous fait face. On garde donc l'ordre [écran gauche, écran droite].
	_ouv = [_vers_ouverture(g.call("eyeBlinkRight"), g.call("eyeWideRight")),
			_vers_ouverture(g.call("eyeBlinkLeft"), g.call("eyeWideLeft"))]
	_sourire = (g.call("mouthSmileLeft") + g.call("mouthSmileRight")) * 0.5
	_moue = (g.call("mouthFrownLeft") + g.call("mouthFrownRight")) * 0.5
	_machoire = g.call("jawOpen")
	_sourcil_bas = [g.call("browDownRight"), g.call("browDownLeft")]
	_sourcil_haut_int = g.call("browInnerUp")
	_sourcil_haut_ext = [g.call("browOuterUpRight"), g.call("browOuterUpLeft")]
	_joue = g.call("cheekPuff")
	_bisou = maxf(g.call("mouthPucker"), g.call("mouthFunnel"))
	_langue_v = g.call("tongueOut")
	_travers = g.call("mouthRight") - g.call("mouthLeft")     # image en miroir, comme les yeux
	_nez = (g.call("noseSneerLeft") + g.call("noseSneerRight")) * 0.5
	_tete_cible = Vector3(tx * 2.4, ty, deg_to_rad(roulis))
	_cible_regard = regard_monde
	_a_une_cible = true


func _vers_ouverture(clin: float, grand: float) -> float:
	# Le clignement MediaPipe sature rarement à 1 : on étire la plage utile.
	var o := 1.0 - clampf((clin - 0.15) / 0.55, 0.0, 1.0)
	return o + grand * 0.25


## La main droite, pour tenir un carnet ou une page (créée au premier besoin).
var _main_d: Node3D
func main_droite() -> Node3D:
	if _main_d == null:
		if _hsk == null or _hsk.find_bone("hand_r") < 0:
			return self
		var poing := _lier("hand_r")
		_main_d = Node3D.new()
		_main_d.position = _repos_h("hand_r") + Vector3(-0.07, 0, 0.0)
		_main_d.rotation.z = -PI / 2
		poing.add_child(_main_d)
	return _main_d


## Range tous les maillages sur une couche de rendu (1..20) : ton propre villageois
## n'est visible que du petit miroir, pas de ta vue à la première personne.
## Mon propre corps, vu de mes yeux : tout reste visible (on se voit en baissant la tête), sauf
## ce qui est au-dessus des épaules (tête, cou, bulle), rangé sur `couche_tete` que ma caméra ignore.
var _couche_tete := 0


func vue_interieure(couche_tete: int) -> void:
	_couche_tete = couche_tete
	calque(1)
	calque(couche_tete, _cou)
	for l: Label3D in [_bulle, _etiquette]:
		if l:
			l.layers = 1 << (couche_tete - 1)


func calque(couche: int, n: Node = self) -> void:
	for enfant in n.get_children():
		if enfant is VisualInstance3D:
			enfant.layers = 1 << (couche - 1)
		calque(couche, enfant)


## La tête (os de la tenue), en coordonnées monde : la caméra subjective la suit, sinon un
## sprint penché fait passer le cou devant les yeux.
func position_tete() -> Vector3:
	if _hsk == null or _h_tete < 0:
		return global_position + Vector3(0, 1.5, 0)
	return _hsk.global_transform * _hsk.get_bone_global_pose(_h_tete).origin


func regarder(point: Vector3) -> void:
	_cible_regard = point
	_a_une_cible = true


func ne_plus_regarder() -> void:
	_a_une_cible = false


## Un mort, vu par un autre mort ou par le Médium : pâle, translucide, sans ombre.
var _fantome := false


func fantome(oui: bool) -> void:
	if oui == _fantome:
		return
	_fantome = oui
	_translucide(self, oui)
	if _atours:
		_atours.en_fantome(oui)


func _translucide(n: Node, oui: bool) -> void:
	for e in n.get_children():
		if e is GeometryInstance3D:
			var g := e as GeometryInstance3D
			g.transparency = 0.55 if oui else 0.0
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if oui else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_translucide(e, oui)


static func nom_bandeau(k: int) -> String:
	return BANDEAUX[k][1] if k >= 0 and k < BANDEAUX.size() else ""


## Noue (ou change) le bandeau de couleur autour du front ; au-dessus d'une capuche, il la serre.
func porter_bandeau(k: int) -> void:
	if k == bandeau or _visage == null:
		return
	bandeau = k
	if _bandeau:
		_bandeau.queue_free()
		_bandeau = null
	if k < 0 or k >= BANDEAUX.size():
		return
	# Un peu de lueur : il doit se lire dans la brume et au crépuscule, de loin.
	var tissu := _mat(BANDEAUX[k][0], 0.75)
	tissu.emission_enabled = true
	tissu.emission = (BANDEAUX[k][0] as Color) * 0.5
	_bandeau = Node3D.new()
	var sorte: String = TETES[int(apparence.get("tete", 0))]
	_bandeau.scale = Vector3.ONE * (1.22 if sorte == "capuche" else 1.0)
	_bandeau.position = Vector3(0, 0.058 if sorte != "capuche" else 0.04, -0.006)
	_bandeau.rotation.x = -0.18          # plus haut sur le front que sur la nuque
	if sorte == "haut_de_forme":
		# Sous le bord il ne se lirait pas : il prend la place du ruban.
		_bandeau.scale = Vector3(0.86, 0.75, 0.86)
		_bandeau.position = Vector3(0, 0.165, -0.01)
		_bandeau.rotation.x = 0.0
	_visage.add_child(_bandeau)
	var anneau := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.108          # par-dessus les cheveux, pas dedans
	t.outer_radius = 0.128
	t.rings = 24
	t.ring_segments = 6
	anneau.mesh = t
	anneau.material_override = tissu
	anneau.scale = Vector3(0.92, 2.6, 1.0)
	_bandeau.add_child(anneau)
	# Le nœud sur la nuque, et ses deux pans qui pendent.
	_boule(_bandeau, 0.026, tissu, Vector3(0, 0.0, -0.126), Vector3(1.2, 0.9, 0.8))
	for c: int in [-1, 1]:
		_boite(_bandeau, Vector3(0.03, 0.14, 0.008), tissu, Vector3(c * 0.02, -0.07, -0.132), Vector3(0.25, 0, c * 0.22))
	if _fantome:
		_translucide(_bandeau, true)
	if _couche_tete > 0:
		calque(_couche_tete, _bandeau)


## Sans nom (les loups se voient ainsi la nuit, et tout le monde pendant la partie).
func anonyme(oui: bool) -> void:
	if _etiquette:
		_etiquette.visible = not oui


func dire(texte: String, duree := 1.6) -> void:
	_bulle.text = texte
	_bulle_t = duree


## La bête prend le dessus : le visage humain disparaît sous la tête de loup.
## La métamorphose vue de dehors (un fantôme qui regarde, Edwin 31/10) : le corps frissonne et
## se tasse, puis la bête apparaît d'un coup et se redresse. Durée en secondes ; 0 = aucune.
const DUREE_METAMORPHOSE := 1.8
var _metamorphose := 0.0


## `animer` : la métamorphose se joue quand on passe d'humain à bête (sinon, changement sec).
func devenir_loup(oui: bool, animer := false) -> void:
	if oui and not est_loup and animer and _metamorphose <= 0.0:
		_metamorphose = DUREE_METAMORPHOSE
	if oui and _metamorphose > DUREE_METAMORPHOSE * 0.5:
		oui = false   # première moitié : encore humain, qui frissonne
	if oui == est_loup:
		return
	est_loup = oui
	if _atours:
		_atours.cacher(oui)          # la bête ne promène ni son chat ni sa tenue de fête
	_visage.visible = not oui
	_tete_loup.visible = oui
	var patte := _tissu(Color(0.1, 0.09, 0.09), "laine", ECHELLE_CORPS)
	for p: Array in _peaux:
		(p[0] as MeshInstance3D).set_surface_override_material(p[1], patte if oui else _mat_peau)


## Pose la photo de face du joueur sur le visage ; faux si elle est illisible.
func poser_photo(octets: PackedByteArray, reperes: Dictionary) -> bool:
	retirer_photo()
	if not MaTete.reperes_valides(reperes):
		return false
	var img := MaTete.image(octets)
	if img == null or _visage == null:
		return false
	_photo = MaTete.masque(img, reperes)
	_visage.add_child(_photo)
	_traits_dessines(false)
	return true


func retirer_photo() -> void:
	if _photo:
		_photo.queue_free()
		_photo = null
		_traits_dessines(true)


func a_une_photo() -> bool:
	return _photo != null


## Les yeux, sourcils, nez et bouche dessinés : cachés sous la photo (elle a les siens).
func _traits_dessines(oui: bool) -> void:
	for n: Node3D in _yeux + _sourcils + _bouche_coins + _cernes:
		n.visible = oui
	for n: Node3D in [_nez_n, _bouche_ouverte, _bouche_milieu]:
		if n:
			n.visible = oui
	if not oui:
		for p in _paupieres:
			p.visible = false
		_langue.visible = false


## Les yeux fermés de force (un choc contre un mur, un geste) : `secondes`, puis ils s'ouvrent seuls.
var _yeux_fermes_t := 0.0
var _coup_tete_t := 0.0            # un caillou en pleine tête : la tête part en arrière puis revient, des étoiles tournent
var _etoiles_coup: Node3D
const DUREE_COUP_TETE := 1.3


func fermer_les_yeux(secondes: float) -> void:
	_yeux_fermes_t = maxf(_yeux_fermes_t, secondes)


## Un caillou dans la tête : elle bascule en arrière un instant et trois étoiles tournent au-dessus (cartoon).
func coup_tete() -> void:
	_coup_tete_t = DUREE_COUP_TETE
	if _etoiles_coup == null and _tete != null:
		_etoiles_coup = Node3D.new()
		_etoiles_coup.position = Vector3(0, 0.2, 0)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.88, 0.25)
		for k in 3:
			var e := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.028
			sm.height = 0.056
			sm.radial_segments = 6
			sm.rings = 3
			e.mesh = sm
			e.material_override = mat
			e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			e.name = "etoile%d" % k
			_etoiles_coup.add_child(e)
		_tete.add_child(_etoiles_coup)
	_yeux_fermes_t = maxf(_yeux_fermes_t, 0.6)


func yeux_fermes() -> bool:
	return _yeux_fermes_t > 0.0


## `vers` : pour pointer du doigt, celui qu'on accuse — le bras et le doigt le suivent tant que dure le geste.
func jouer_emote(id: String, vers: Node3D = null) -> void:
	emote = id if Emotes.existe(id) else ""
	_emote_t = 0.0
	cible_emote = vers if Emotes.pointe(emote) else null
	if emote != "":
		accroupi = false      # une animation relève


func marcher(vitesse: float) -> void:
	_marche = vitesse


## La tête touchée : un grand coup en arrière (vif), qui revient en oscillant ; les étoiles tournent puis s'effacent.
func _animer_coup_tete(delta: float) -> void:
	if _coup_tete_t <= 0.0:
		if _etoiles_coup != null:
			_etoiles_coup.queue_free()
			_etoiles_coup = null
		return
	_coup_tete_t = maxf(_coup_tete_t - delta, 0.0)
	var k := 1.0 - _coup_tete_t / DUREE_COUP_TETE      # 0 au choc, 1 à la fin
	var env := exp(-k * 4.0) * cos(k * 9.0)             # revient en oscillant
	_tete.rotation.x -= 0.5 * env
	_tete.rotation.z += 0.15 * env
	if _etoiles_coup != null:
		var a := clampf(1.0 - maxf(k - 0.6, 0.0) / 0.4, 0.0, 1.0)
		for i in 3:
			var e := _etoiles_coup.get_node("etoile%d" % i) as Node3D
			var ang := _t * 7.0 + i * TAU / 3.0
			e.position = Vector3(cos(ang) * 0.14, sin(_t * 9.0 + i) * 0.015, sin(ang) * 0.14)
			e.scale = Vector3.ONE * a


# ================================================================ animation

func _process(delta: float) -> void:
	_t += delta
	if _metamorphose > 0.0 and _humain:
		_metamorphose = maxf(0.0, _metamorphose - delta)
		var k := 1.0 - _metamorphose / DUREE_METAMORPHOSE
		var frisson := sin(_t * 70.0) * 0.04 * sin(PI * k)
		# Se tasse en frissonnant, puis la bête se redresse plus grande avant de revenir à sa taille.
		var taille := 1.0 - 0.12 * sin(PI * minf(k * 2.0, 1.0)) if k < 0.5 else 1.0 + 0.15 * sin(PI * (k - 0.5) * 2.0)
		_humain.scale = Vector3(taille + frisson, taille, taille - frisson)
		if _metamorphose <= 0.0:
			_humain.scale = Vector3.ONE
	if autonome:
		_vie_autonome(delta)

	var lisse := clampf(delta * 18.0, 0.0, 1.0)
	# Yeux et paupières
	_yeux_fermes_t = maxf(_yeux_fermes_t - delta, 0.0)
	for i in 2:
		var o: float = 0.0 if _yeux_fermes_t > 0.0 else _ouv[i]
		var oeil := _yeux[i]
		var sy := lerpf(oeil.scale.y, clampf(lerpf(0.06, 1.0, o), 0.06, 1.25), lisse)
		oeil.scale = Vector3(1.0 + (1.0 - minf(o, 1.0)) * 0.08, sy, 1.0)
		var ferme := sy < 0.16
		oeil.visible = not ferme and _photo == null
		_paupieres[i].visible = ferme and _photo == null

	# Iris vers la cible
	for i in 2:
		var voulu := Vector2.ZERO
		if _a_une_cible:
			var local := _yeux[i].global_transform.affine_inverse() * _cible_regard
			local = local.normalized()
			voulu = Vector2(clampf(atan2(local.x, local.z), -0.6, 0.6),
							clampf(atan2(local.y, Vector2(local.x, local.z).length()), -0.45, 0.45))
		_regard_local[i] = _regard_local[i].lerp(voulu, clampf(delta * 25.0, 0, 1))
		_pupilles[i].rotation = Vector3(-_regard_local[i].y, _regard_local[i].x, 0)

	# Sourcils : [écran gauche, écran droite] ; l'intérieur est vers le centre.
	for i in 2:
		var cote := -1.0 if i == 0 else 1.0
		var s := _sourcils[i]
		var monte := _sourcil_haut_int * 0.5 + float(_sourcil_haut_ext[i]) * 0.5 - float(_sourcil_bas[i]) * 0.6 - _nez * 0.4
		s.position.y = lerpf(s.position.y, 0.056 + monte * 0.014, lisse)
		var penche := (float(_sourcil_bas[i]) * 0.55 - _sourcil_haut_int * 0.5) * cote
		s.rotation.z = lerpf(s.rotation.z, penche, lisse)

	# Bouche et mâchoire : la caméra, ou la voix (syllabes simulées par une petite oscillation).
	var voulu_parole := 0.0
	if parole > 0.02:
		voulu_parole = clampf((parole - 0.02) / 0.1, 0.0, 1.0) * (0.55 + 0.45 * absf(sin(_t * 17.0)))
	_parole_ouv = lerpf(_parole_ouv, voulu_parole, clampf(delta * (30.0 if voulu_parole > _parole_ouv else 12.0), 0, 1))
	var ouvre := clampf(maxf(_machoire * 1.6, _parole_ouv * 0.8), 0.0, 1.0)
	var sourire := clampf(_sourire + _sourire_fige, 0.0, 1.2)
	# Bisou : bouche ronde et resserrée. Travers : la bouche glisse d'un côté.
	var serre := 1.0 - _bisou * 0.55
	var ouvre_bisou := maxf(ouvre, _bisou * 0.35)
	_bouche_ouverte.scale = _bouche_ouverte.scale.lerp(Vector3((1.1 + sourire * 0.4) * serre, 0.1 + ouvre_bisou * 0.9, 0.4 + _bisou * 0.4), lisse)
	var dx := clampf(_travers, -1.0, 1.0) * 0.014
	_bouche_ouverte.position.x = lerpf(_bouche_ouverte.position.x, dx, lisse)
	_bouche_milieu.position.x = _bouche_ouverte.position.x
	_bouche_milieu.scale.x = serre
	for i in 2:
		_bouche_coins[i].position.x = lerpf(_bouche_coins[i].position.x, (0.011 * serre) * (-1.0 if i == 0 else 1.0) + dx, lisse)
	# Langue tirée : elle sort de la bouche (la mâchoire s'ouvre un peu pour la laisser passer).
	var langue := clampf((_langue_v - 0.25) / 0.5, 0.0, 1.0)
	_langue.visible = langue > 0.05 and _photo == null
	_langue.position = Vector3(_bouche_ouverte.position.x, -0.072 - langue * 0.006, 0.086 + langue * 0.024)
	if langue > 0.05:
		ouvre = maxf(ouvre, 0.35)
	# Nez retroussé : il remonte, les sourcils froncent un peu.
	_nez_n.position.y = lerpf(_nez_n.position.y, -0.02 + _nez * 0.006, lisse)
	_machoire_n.position.y = lerpf(_machoire_n.position.y, -ouvre * 0.012, lisse)
	_bouche_milieu.visible = ouvre < 0.25 and _photo == null
	var angle := sourire * 0.6 - _moue * 0.5
	for i in 2:
		var cote := -1.0 if i == 0 else 1.0
		var coin := _bouche_coins[i]
		coin.rotation.z = lerpf(coin.rotation.z, angle * cote, lisse)
		coin.visible = ouvre < 0.45 and _photo == null

	# Tête : le cou tourne (le buste suit un peu, cf. modifier_os)
	var rot := Vector3(_tete_cible.y * 0.9, _tete_cible.x * 0.9, -_tete_cible.z * 0.8)
	rot = rot.clamp(Vector3(-0.5, -0.9, -0.5), Vector3(0.5, 0.9, 0.5))
	_tete_rot = _tete_rot.lerp(rot, clampf(delta * 14.0, 0, 1))
	_tete.rotation = _tete_rot
	_animer_coup_tete(delta)

	if _photo:
		var m := _photo.material_override as ShaderMaterial
		m.set_shader_parameter("ferme_a", 1.0 if _yeux_fermes_t > 0.0 else clampf(1.0 - float(_ouv[0]), 0.0, 1.0))
		m.set_shader_parameter("ferme_b", 1.0 if _yeux_fermes_t > 0.0 else clampf(1.0 - float(_ouv[1]), 0.0, 1.0))
		m.set_shader_parameter("ouvre", ouvre)

	# Geste ou danse : fini au bout de sa durée, ou dès qu'on marche.
	if emote != "":
		_emote_t += delta
		var duree := Emotes.duree(emote)
		# Un geste dure son temps, même si l'on marche ou saute (Edwin, 30/10 : bouger ne l'annule
		# plus, on danse en marchant). Seuls la mort et le fait de s'asseoir l'arrêtent.
		if _emote_t > duree or mort or assis:
			emote = ""
	_emote_bras = Emotes.bras(emote, _emote_t) if emote != "" else PackedFloat32Array()
	_emote_mains = Emotes.mains(emote, _emote_t) if emote != "" else PackedFloat32Array()
	if cible_emote != null and not is_instance_valid(cible_emote):
		cible_emote = null
	if cible_emote != null and Emotes.pointe(emote) and _emote_bras.size() >= 16 and _emote_mains.size() >= 44:
		_viser_cible(cible_emote)

	# Ce que fait le corps : marcher, parler avec les mains, tomber.
	_parle_t = clampf(_parle_t + (delta if parole > 0.05 else -delta * 0.6), 0.0, 1.5)
	var anim := "Idle"
	if mort:
		anim = "Death01"
	elif assis:
		anim = "Sitting_Talking" if _parle_t > 0.6 else "Sitting_Idle"
	elif couche:
		anim = "Idle"
	elif emote != "" and Emotes.animation(emote) != "" and _ap.has_animation(Emotes.animation(emote)):
		# Le geste prime sur la marche : on danse en avançant ; accroupi, on avance accroupi.
		anim = Emotes.animation(emote)
		if anim == "Crouch_Idle" and _marche > 0.12 and _ap.has_animation("Crouch_Fwd"):
			anim = "Crouch_Fwd"
	elif accroupi and not mort and _ap.has_animation("Crouch_Idle"):
		anim = "Crouch_Fwd" if _marche > 0.12 and _ap.has_animation("Crouch_Fwd") else "Crouch_Idle"
	elif global_position.y - Ronde.hauteur_sol(global_position) > 0.15:
		# En l'air : au-dessus du sol sous ses pieds (la terrasse du temple est à 1,5 m).
		anim = "Jump"
	elif _marche > 1.55:
		anim = "Sprint"
	elif _marche > 0.12:
		anim = "Walk"
	elif _parle_t > 0.6:
		anim = "Idle_Talking"
	if _ap.assigned_animation != anim:
		_ap.play(anim, 0.3)
	_ap.speed_scale = lerpf(0.6, 1.2, clampf(_marche, 0.0, 1.0)) if anim == "Walk" else 1.0
	# L'animation assise pose le bassin loin derrière les pieds : sans avancer le corps, les
	# jambes plongent dans la souche (mesuré sur tests/maquettes_assis.gd).
	_avance_assis = lerpf(_avance_assis, AVANCE_ASSIS if assis else 0.0, minf(delta * 6.0, 1.0))
	_modele.position.z = _avance_assis
	_humain.position.z = _avance_assis

	# Membres vus par la webcam : ils prennent la main sur l'animation (sauf les jambes en marchant).
	# Ils suivent par un ressort amorti : un geste vif dépasse un peu et revient, rien n'est sec.
	for seg in 9:
		var d := _segment(seg)
		var voulu := 0.0 if d == Vector3.ZERO or mort else 1.0
		if seg >= 4 and seg < 8 and (_marche > 0.2 or assis):
			voulu = 0.0
		if d != Vector3.ZERO:
			var etat := Bouille.ressort(_dir_suivi[seg], _vit_suivi[seg], d, delta, 5.0, 0.62)
			_dir_suivi[seg] = (etat[0] as Vector3).normalized()
			_vit_suivi[seg] = etat[1]
		_poids_suivi[seg] = lerpf(_poids_suivi[seg], voulu, clampf(delta * 6.0, 0, 1))

	# Mains et doigts.
	for c in 2:
		var b := c * 22
		var src := _emote_mains if _emote_mains.size() >= 44 else mains_suivi
		var vue := src.size() >= 44 and src[b] > 0.5 and not mort
		_poids_main[c] = lerpf(_poids_main[c], 1.0 if vue else 0.0, clampf(delta * 8.0, 0, 1))
		if not vue:
			continue
		var d := Vector3(src[b + 1], src[b + 2], src[b + 3])
		var n := Vector3(src[b + 4], src[b + 5], src[b + 6])
		var k := clampf(delta * 14.0, 0, 1)
		if d.length() > 0.1:
			_dir_main[c] = _dir_main[c].lerp(d.normalized(), k).normalized()
		if n.length() > 0.1:
			_norm_main[c] = _norm_main[c].lerp(n.normalized(), k).normalized()
		for i in 15:
			_plis[c * 15 + i] = lerpf(_plis[c * 15 + i], clampf(src[b + 7 + i], 0.0, 1.9), k)

	_souplesse(delta)

	if _bulle_t > 0:
		_bulle_t -= delta
		_bulle.modulate.a = clampf(_bulle_t * 2.0, 0, 1)
		if _bulle_t <= 0:
			_bulle.text = ""


## Le point qu'on montre : la tête de la personne (ou, à défaut, un point à hauteur de poitrine).
static func point_vise(cible: Node3D) -> Vector3:
	if cible is Bouille:
		return (cible as Bouille).position_tete()
	return cible.global_position + Vector3(0, 1.4, 0)


## Bras et main droits tendus droit vers la cible, dans les axes du villageois (donc le bras suit si l'on
## tourne ou si l'autre bouge). L'épaule est lue sur le squelette ; le bras entier prend la même direction.
func _viser_cible(cible: Node3D) -> void:
	if _sk == null or _os.is_empty():
		return
	var epaule := _sk.global_transform * _sk.get_bone_global_pose(_os[0]).origin
	var monde := point_vise(cible) - epaule
	if monde.length() < 0.2:
		return
	var local := global_transform.basis.orthonormalized().inverse() * monde.normalized()
	for seg in 2:
		_emote_bras[seg * 4] = local.x
		_emote_bras[seg * 4 + 1] = local.y
		_emote_bras[seg * 4 + 2] = local.z
	_emote_mains[1] = local.x
	_emote_mains[2] = local.y
	_emote_mains[3] = local.z


## Ressort amorti (semi-implicite, sous-pas courts) : renvoie [position, vitesse].
## `frequence` en Hz, `amorti` 1 = sans rebond ; en dessous, un léger dépassement.
static func ressort(x: Variant, v: Variant, cible: Variant, delta: float, frequence: float, amorti: float) -> Array:
	var w := TAU * frequence
	var reste := minf(delta, 0.25)
	while reste > 0.0:
		var dt := minf(reste, 1.0 / 120.0)
		v += (cible - x) * (w * w) * dt - v * (2.0 * amorti * w) * dt
		x += v * dt
		reste -= dt
	return [x, v]


## Le corps vit : penché dans l'accélération, bras qui traînent dans les virages, respiration.
func _souplesse(delta: float) -> void:
	if delta <= 0.0 or not is_inside_tree():
		return
	var pos := global_position
	var vit := (pos - _pos_avant) / delta
	if (pos - _pos_avant).length() > 3.0:
		vit = _vit_avant                     # téléporté : ce n'est pas une accélération
	var acc := (vit - _vit_avant) / delta
	_pos_avant = pos
	_vit_avant = vit
	var locale := global_transform.basis.orthonormalized().inverse() * acc
	var cible := Vector2(clampf(locale.z * 0.035, -0.22, 0.22), clampf(-locale.x * 0.03, -0.16, 0.16))
	if mort or assis:
		cible = Vector2.ZERO
	var e := Bouille.ressort(_penche, _penche_v, cible, delta, 1.6, 0.45)
	_penche = e[0]
	_penche_v = e[1]
	var cap := rotation.y
	var vit_cap := wrapf(cap - _cap_avant, -PI, PI) / delta
	_cap_avant = cap
	var t := Bouille.ressort(_trainee, _trainee_v, clampf(-vit_cap * 0.12, -0.5, 0.5), delta, 2.2, 0.4)
	_trainee = t[0]
	_trainee_v = t[1]
	_souffle += delta * lerpf(1.5, 3.2, clampf(_marche / 2.0, 0, 1))


## Direction d'un segment suivi par la webcam, ou ZERO s'il n'est pas dans le champ.
func _segment(seg: int) -> Vector3:
	var b := seg * 4
	if seg < 4 and _emote_bras.size() >= 16:
		if _emote_bras[b + 3] < 0.5:
			return _pose_tient(seg)
		return Vector3(_emote_bras[b], _emote_bras[b + 1], _emote_bras[b + 2]).normalized()
	if corps_suivi.size() < b + 4 or corps_suivi[b + 3] < 0.5:
		return _pose_tient(seg)
	var d := Vector3(corps_suivi[b], corps_suivi[b + 1], corps_suivi[b + 2])
	return d.normalized() if d.length() > 0.01 else Vector3.ZERO


## Le bras droit qui porte un objet : le bras tombe devant le flanc, l'avant-bras remonte devant le ventre
## (axes du villageois : avant = +Z, son côté droit = -X). ZERO : rien à imposer.
func _pose_tient(seg: int) -> Vector3:
	if not tient_objet or mort or seg > 1:
		return Vector3.ZERO
	return Vector3(-0.12, -0.9, 0.4).normalized() if seg == 0 else Vector3(0.12, 0.2, 0.97).normalized()


## La couleur de la manche, lue sur la tenue (la texture aux endroits des bras) : la main tenue à la première
## personne la reprend, au lieu d'une couleur à peu près (Edwin, 01/11 : un bras « blanc » à côté de ceux du corps).
func couleur_manche() -> Color:
	if _manche_ok:
		return _manche_c
	_manche_ok = true
	var somme := Vector3.ZERO
	var n := 0
	var mult := Color.WHITE
	for mi: MeshInstance3D in _humain.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null or mi.mesh == null:
			continue
		for k in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(k) as StandardMaterial3D
			if mat == null or mat == _mat_peau or mat.albedo_texture == null:
				continue
			var img := mat.albedo_texture.get_image()
			if img == null:
				continue
			if img.is_compressed():
				img.decompress()
			var a := mi.mesh.surface_get_arrays(k)
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var os_: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var poids: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			if uv.is_empty() or os_.is_empty():
				continue
			var par := os_.size() / uv.size()
			for v in uv.size():
				var meilleur := 0
				for j in par:
					if poids[v * par + j] > poids[v * par + meilleur]:
						meilleur = j
				var nom := mi.skin.get_bind_name(os_[v * par + meilleur]).to_lower()
				if nom == "":
					nom = _hsk.get_bone_name(mi.skin.get_bind_bone(os_[v * par + meilleur])).to_lower()
				if not nom.begins_with("lowerarm") and not nom.begins_with("upperarm"):
					continue
				var x := int(fposmod(uv[v].x, 1.0) * (img.get_width() - 1))
				var y := int(fposmod(uv[v].y, 1.0) * (img.get_height() - 1))
				var c := img.get_pixel(x, y)
				somme += Vector3(c.r, c.g, c.b)
				n += 1
			mult = mat.albedo_color
	if n > 0:
		somme /= float(n)
		_manche_c = Color(somme.x * mult.r, somme.y * mult.g, somme.z * mult.b)
	else:
		_manche_c = (TEINTES[int(apparence.get("teinte", 0))] as Color).lerp(Color(0.62, 0.58, 0.52), 0.55)
	return _manche_c


## Appelé après l'animation, à chaque image (SuiviOs).
func modifier_os(sk: Skeleton3D) -> void:
	sk.set_bone_pose_scale(_os[10], Vector3.ONE * 0.01)    # la tête du mannequin s'efface, la nôtre la remplace
	if not mort:
		_tourner(sk, _os[8], Basis(Vector3.RIGHT, 0.35 if est_loup else -0.1))   # redressé : l'animation de repos est très voûtée
		_tourner(sk, _os[9], Basis(Vector3.UP, _tete_rot.y * 0.25))
	# Les axes du villageois (avant = +Z, côté = +X) ramenés dans ceux du squelette.
	var s := (global_transform.basis.orthonormalized().inverse() * sk.global_transform.basis.orthonormalized())
	var vers_sk := func(b: Basis) -> Basis: return s.inverse() * b * s
	if not mort:
		# Penché dans l'accélération, et la respiration qui soulève le buste.
		var penche := Basis(Vector3.RIGHT, _penche.x) * Basis(Vector3.BACK, _penche.y)
		_tourner(sk, _os[11], vers_sk.call(Basis(Vector3.BACK, sin(_t * 0.45 + _souffle * 0.1) * 0.025)))   # le poids passe d'une jambe à l'autre
		_tourner(sk, _os[8], vers_sk.call(penche))
		_tourner(sk, _os[9], vers_sk.call(Basis(Vector3.RIGHT, -sin(_souffle) * 0.018)))
		var bascule := Emotes.bascule(emote, _emote_t) if emote != "" else 0.0
		if bascule != 0.0:
			_tourner(sk, _os[8], vers_sk.call(Basis(Vector3.RIGHT, bascule)))
		var r := Emotes.rebond(emote, _emote_t) if emote != "" else Vector2.ZERO
		if r != Vector2.ZERO:
			var g := sk.get_bone_global_pose(_os[11])
			g.origin += s.inverse() * Vector3(0, r.x, 0) / maxf(sk.global_transform.basis.get_scale().y, 0.001)
			g.basis = vers_sk.call(Basis(Vector3.BACK, r.y)) * g.basis
			sk.set_bone_global_pose(_os[11], g)
	if _poids_suivi[8] > 0.01:
		_orienter(sk, _os[8], _dir_suivi[8], _poids_suivi[8] * 0.8)
	for seg in 8:
		if _poids_suivi[seg] > 0.01:
			_orienter(sk, _os[seg], _dir_suivi[seg], _poids_suivi[seg])
	if not mort and absf(_trainee) > 0.002:
		# Les bras traînent derrière quand on tourne, puis rattrapent.
		for seg in [0, 2]:
			_tourner(sk, _os[seg], vers_sk.call(Basis(Vector3.UP, _trainee * (1.0 - _poids_suivi[seg]))))
	_poser_mains(sk)


## La main suit la webcam (direction, paume), puis chaque doigt se plie phalange par phalange.
func _poser_mains(sk: Skeleton3D) -> void:
	for c in 2:
		var p: float = _poids_main[c]
		if p < 0.01 or _os_mains[c] < 0:
			continue
		var os := _os_mains[c]
		_orienter(sk, os, _dir_main[c], p)
		# Paume : on tourne la main autour de son axe pour que son côté paume regarde la normale
		# (-X de l'os à droite, +X à gauche : squelette en miroir ; vérifié par maquettes_doigts.gd).
		var g := sk.get_bone_global_pose(os)
		var axe := g.basis.y.normalized()
		var paume := g.basis.x.normalized() * (-1.0 if c == 0 else 1.0)
		var voulu := (_norm_main[c] - axe * _norm_main[c].dot(axe))
		if voulu.length() > 0.2:
			var a := paume.signed_angle_to(voulu.normalized(), axe)
			g.basis = Basis(axe, a * p) * g.basis
			sk.set_bone_global_pose(os, g)
		for d in 5:
			for j in 3:
				var i: int = _os_doigts[c][d][j]
				if i < 0:
					continue
				var angle: float = _plis[c * 15 + d * 3 + j] * p
				# À partir du repos (doigts tendus), pas de l'animation, qui a les doigts à demi fermés.
				var anim := sk.get_bone_pose_rotation(i)
				var vu := sk.get_bone_rest(i).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, angle * PLI_SENS)
				sk.set_bone_pose_rotation(i, anim.slerp(vu, p))


## Sens de la pliure des doigts autour de l'axe X local de chaque phalange (cf. maquettes_doigts.gd).
const PLI_SENS := -1.0


func _tourner(sk: Skeleton3D, os: int, b: Basis) -> void:
	var g := sk.get_bone_global_pose(os)
	g.basis = b * g.basis
	sk.set_bone_global_pose(os, g)


## Amène l'axe de l'os (+Y, de l'articulation vers le bout) sur `dir`, avec un poids.
func _orienter(sk: Skeleton3D, os: int, dir: Vector3, poids: float) -> void:
	var g := sk.get_bone_global_pose(os)
	var de := g.basis.y.normalized()
	var q: Quaternion
	if de.dot(dir) < -0.999:
		q = Quaternion(g.basis.x.normalized(), PI)
	else:
		q = Quaternion(de, dir)
	var avant := g.basis.get_rotation_quaternion()
	g.basis = Basis(avant.slerp((q * avant).normalized(), clampf(poids, 0.0, 1.0)))
	sk.set_bone_global_pose(os, g)


func _suiveur() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	return n


## Les suiveurs collent aux os : tête, buste, bassin, main.
func _suivre_os() -> void:
	# L'humain prend la pose du mannequin : même rotation par rapport au repos, os par os.
	for c: Array in _copie:
		var pm := _sk.get_bone_global_pose(c[0])
		var g := _hsk.get_bone_global_pose(c[1])
		g.basis = (pm.basis.orthonormalized() * (c[2] as Basis)) * (c[3] as Basis)
		if c[1] == _copie[0][1]:
			g.origin = pm.origin + Vector3(0, _decal_bassin, 0)   # le bassin suit aussi en position (marche, chute)
		_hsk.set_bone_global_pose(c[1], g)
	if _h_tete >= 0:
		_hsk.set_bone_pose_scale(_h_tete, Vector3.ONE * 0.01)      # sa tête s'efface, la nôtre la remplace
	if bras_droit_cache and _h_bras_d >= 0:
		_hsk.set_bone_pose_scale(_h_bras_d, Vector3.ONE * 0.01)    # tout le bras droit avec (la main dans son sillage)
	for l: Array in _liens:
		var p := _hsk.get_bone_global_pose(l[1])
		p.basis = p.basis.orthonormalized()
		var n: Node3D = l[0]
		n.transform = _humain.transform * p * (l[2] as Transform3D)
		if n == _cou and not mort:
			# La tête reste droite (seule la caméra la tourne) ; elle suit seulement la position du cou.
			var centre := n.transform * _tete.position
			n.transform = Transform3D(Basis(), centre - _tete.position)


## Un suiveur collé à un os du corps visible ; ses enfants se construisent en coordonnées « debout, au repos ».
func _lier(os_nom: String) -> Node3D:
	var n := _suiveur()
	var i := _hsk.find_bone(os_nom)
	_liens.append([n, i, _hsk.get_bone_global_rest(i).orthonormalized().affine_inverse()])
	return n


func _repos_h(os_nom: String) -> Vector3:
	return _hsk.get_bone_global_rest(_hsk.find_bone(os_nom)).origin


## Il tombe (cinématique, mort au vote) ; `false` le relève.
func mourir(oui := true) -> void:
	mort = oui


func _vie_autonome(delta: float) -> void:
	if dort:
		_ouv = [0.0, 0.0]
		_sourire = 0.0
		if _bulle_t <= 0:
			dire("Zzz", 2.0)
		return
	_prochain_clin -= delta
	if _prochain_clin <= 0 and _clin_t < 0:
		_clin_t = 0.0
		_prochain_clin = randf_range(3.0, 8.0)      # ils clignent peu : c'est ce qui dérange
	if _clin_t >= 0:
		_clin_t += delta
		var o := absf(_clin_t - 0.08) / 0.08
		_ouv = [clampf(o, 0, 1), clampf(o, 0, 1)]
		if _clin_t > 0.16:
			_clin_t = -1.0
			_ouv = [1.0, 1.0]
	_sourire = lerpf(_sourire, 0.05 + sin(_t * 0.3) * 0.05, delta)
	# La tête se penche lentement, parfois trop.
	_tete_cible = Vector3(sin(_t * 0.23) * 0.15, sin(_t * 0.17) * 0.05, 0.0)
	_sourcil_bas = [0.0, 0.0]
	_machoire = 0.0
