class_name Cadenas3D
extends Node3D
## Un cadenas à molettes en 3D, grand et détaillé (le Grand Coffre) : un corps de laiton avec ses
## rivets, N molettes qui tournent (dix chiffres gravés sur le pourtour de la mienne), et une anse
## qui monte quand on la tire, résiste quand la serrure est bloquée et bascule quand le code est bon.
##
## Il se tourne vers son joueur : +Z est le devant (là où l'on lit les chiffres), +Y le haut. Le
## décor lui donne la matière (`matiere`) et le son. Les corps physiques pour la visée portent la
## méta « molette » (index) ou « anse » ; ils sont posés sur la couche des objets à toucher.

const PAS := 0.085                  # entraxe des molettes
const RAYON := 0.056                # rayon d'une molette
const HAUTEUR_CORPS := 0.22
const PROFONDEUR := 0.13
const HAUT_ANSE := 0.27             # hauteur des jambes de l'anse au-dessus du chapeau
const LEVEE_MAX := 0.09            # de combien l'anse monte quand on la tire à fond

var n := 4
var moi := false                    # le mien : les chiffres sont gravés, les molettes se visent
var _roues: Array[Node3D] = []
var _angles: Array[float] = []      # l'angle affiché de chaque molette (rad), qui rattrape la cible
var _cibles: Array[int] = []
var _mats: Array[StandardMaterial3D] = []
var _anse: Node3D
var _chapeau: Node3D
var _mat_anse: StandardMaterial3D
var _corps_visee: Array[StaticBody3D] = []
var _anse_visee: StaticBody3D
var ouvert := false
var tirage := 0.0                   # 0..1 : l'anse tirée par le joueur (calculé par le décor)
var _levee := 0.0                   # la hauteur actuelle de l'anse
var _bascule := 0.0                 # l'ouverture actuelle (0 fermée, 1 grande ouverte)
var _secousse := -1.0               # depuis combien de temps l'anse résiste (-1 : calme)
var _t := 0.0
var _lumiere: OmniLight3D
var _marque := -1                   # la molette visée (surlignée)


## Bâtit le cadenas : `couche` est la couche des corps de visée, `lait`, `fer` et `cuivre` ses matières.
func construire(nb: int, mien: bool, couche: int, laiton: Material, fer: Material, ecrou: Material) -> void:
	n = nb
	moi = mien
	var larg := largeur(n)
	# Le corps : un bloc de laiton, un chapeau plus large dessus, un socle dessous.
	var corps := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(larg, HAUTEUR_CORPS, PROFONDEUR)
	corps.mesh = bm
	corps.material_override = laiton
	add_child(corps)
	var socle := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(larg + 0.03, 0.03, PROFONDEUR + 0.025)
	socle.mesh = sm
	socle.material_override = fer
	socle.position.y = -HAUTEUR_CORPS * 0.5 - 0.015
	add_child(socle)
	_chapeau = Node3D.new()
	_chapeau.position.y = HAUTEUR_CORPS * 0.5
	add_child(_chapeau)
	var cm := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(larg + 0.03, 0.05, PROFONDEUR + 0.025)
	cm.mesh = cb
	cm.material_override = fer
	cm.position.y = 0.0225
	_chapeau.add_child(cm)
	# Deux plaques de fer aux extrémités et deux ceintures : un corps forgé, pas une caisse.
	for sx: float in [-1.0, 1.0]:
		var plaque := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.022, HAUTEUR_CORPS + 0.012, PROFONDEUR + 0.016)
		plaque.mesh = pm
		plaque.material_override = fer
		plaque.position.x = sx * (larg * 0.5 - 0.008)
		add_child(plaque)
	for sy: float in [-1.0, 1.0]:
		var ceinture := MeshInstance3D.new()
		var qm := BoxMesh.new()
		qm.size = Vector3(larg - 0.02, 0.014, PROFONDEUR + 0.012)
		ceinture.mesh = qm
		ceinture.material_override = fer
		ceinture.position.y = sy * (HAUTEUR_CORPS * 0.5 - 0.012)
		add_child(ceinture)
	# Les rivets aux quatre coins du devant.
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var r := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.0085
			s.height = 0.017
			r.mesh = s
			r.material_override = ecrou
			r.position = Vector3(sx * (larg * 0.5 - 0.016), sy * (HAUTEUR_CORPS * 0.5 - 0.02), PROFONDEUR * 0.5 + 0.002)
			add_child(r)
	# Une plaque gravée sous les molettes : le cadran où se lit le code.
	var fenetre := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(n * PAS + 0.03, RAYON * 2.0 + 0.02, 0.012)
	fenetre.mesh = fm
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color(0.05, 0.045, 0.04)
	noir.roughness = 0.8
	fenetre.material_override = noir
	fenetre.position = Vector3(0, 0, PROFONDEUR * 0.5 + 0.004)
	add_child(fenetre)
	# Les molettes : un cylindre cranté, deux flasques, et (pour la mienne) dix chiffres gravés.
	for k in n:
		var x := (k - (n - 1) * 0.5) * PAS
		var roue := Node3D.new()
		roue.position = Vector3(x, 0, PROFONDEUR * 0.5 + RAYON * 0.55)
		add_child(roue)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.17, 0.13)
		m.metallic = 0.5
		m.roughness = 0.45
		m.emission_enabled = true
		m.emission = Color(1.0, 0.7, 0.3)
		m.emission_energy_multiplier = 0.0
		_mats.append(m)
		var tambour := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = RAYON
		tm.bottom_radius = RAYON
		tm.height = PAS - 0.012
		tm.radial_segments = 40
		tambour.mesh = tm
		tambour.rotation.z = PI / 2
		tambour.material_override = m
		roue.add_child(tambour)
		# Les crans : dix petites arêtes sur le pourtour (on les voit défiler).
		for i in CRANS_VISIBLES:
			var a := TAU * i / float(CRANS_VISIBLES)
			var arete := MeshInstance3D.new()
			var ab := BoxMesh.new()
			ab.size = Vector3(PAS - 0.008, 0.007, 0.007)
			arete.mesh = ab
			arete.material_override = fer
			arete.position = Vector3(0, sin(a) * (RAYON + 0.001), cos(a) * (RAYON + 0.001))
			arete.rotation.x = -a
			roue.add_child(arete)
		if moi:
			for i in 10:
				var a2 := -TAU * i / 10.0
				var chiffre := Label3D.new()
				chiffre.text = str(i)
				chiffre.font = ThemeDB.fallback_font
				chiffre.font_size = 64
				chiffre.pixel_size = 0.001
				chiffre.outline_size = 8
				chiffre.modulate = Color(1.0, 0.9, 0.62)
				chiffre.outline_modulate = Color(0.1, 0.05, 0.02)
				chiffre.double_sided = false
				chiffre.shaded = false
				chiffre.position = Vector3(0, sin(a2) * (RAYON + 0.006), cos(a2) * (RAYON + 0.006))
				chiffre.rotation.x = -a2
				roue.add_child(chiffre)
		_roues.append(roue)
		_angles.append(0.0)
		_cibles.append(0)
		# La visée : une boîte un peu plus large que la molette.
		var corps_v := StaticBody3D.new()
		corps_v.collision_layer = couche
		corps_v.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(PAS, RAYON * 2.2, 0.14)
		cs.shape = bx
		corps_v.add_child(cs)
		corps_v.position = roue.position
		corps_v.set_meta("molette", k)
		add_child(corps_v)
		_corps_visee.append(corps_v)
	_construire_anse(larg, fer, couche)
	if moi:
		_lumiere = OmniLight3D.new()
		_lumiere.light_color = Color(1.0, 0.82, 0.55)
		_lumiere.light_energy = 0.55
		_lumiere.omni_range = 1.8
		_lumiere.position = Vector3(0, 0.1, 0.5)
		add_child(_lumiere)


const CRANS_VISIBLES := 10


## La hauteur, au-dessus du centre du corps, où passe la barre de la ferrure (dans l'arc de l'anse).
static func hauteur_barre() -> float:
	return HAUTEUR_CORPS * 0.5 + 0.045 + 0.07


static func largeur(nb: int) -> float:
	return nb * PAS + 0.12


func _construire_anse(larg: float, fer: Material, couche: int) -> void:
	# L'anse : deux jambes d'acier et un arc, qui coulisse dans le chapeau.
	_anse = Node3D.new()
	_anse.position = Vector3(0, HAUTEUR_CORPS * 0.5 + 0.045, 0)
	add_child(_anse)
	_mat_anse = StandardMaterial3D.new()
	_mat_anse.albedo_color = Color(0.72, 0.72, 0.76)
	_mat_anse.metallic = 0.9
	_mat_anse.roughness = 0.28
	_mat_anse.emission_enabled = true
	_mat_anse.emission = Color(1.0, 0.7, 0.3)
	_mat_anse.emission_energy_multiplier = 0.0
	var demi := larg * 0.5 - 0.06
	var r_jambe := 0.0105
	for sx: float in [-1.0, 1.0]:
		var j := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r_jambe
		cm.bottom_radius = r_jambe
		cm.height = HAUT_ANSE
		cm.radial_segments = 14
		j.mesh = cm
		j.material_override = _mat_anse
		j.position = Vector3(sx * demi, HAUT_ANSE * 0.5 - 0.03, 0)
		_anse.add_child(j)
	# L'arc : huit segments sur un demi-cercle.
	var seg := 8
	for i in seg:
		var a0 := PI * i / seg
		var a1 := PI * (i + 1) / seg
		var p0 := Vector3(cos(a0) * demi, sin(a0) * demi * 0.55, 0)
		var p1 := Vector3(cos(a1) * demi, sin(a1) * demi * 0.55, 0)
		var s := MeshInstance3D.new()
		var cm2 := CylinderMesh.new()
		cm2.top_radius = r_jambe
		cm2.bottom_radius = r_jambe
		cm2.height = p0.distance_to(p1) + 0.004
		cm2.radial_segments = 14
		s.mesh = cm2
		s.material_override = _mat_anse
		var milieu := (p0 + p1) * 0.5
		s.position = Vector3(milieu.x, HAUT_ANSE - 0.03 + milieu.y, 0)
		var d := (p1 - p0).normalized()
		s.basis = Basis(Vector3(0, 0, 1), atan2(-d.x, d.y))
		_anse.add_child(s)
	# La prise de visée : tout l'arc et ses jambes.
	_anse_visee = StaticBody3D.new()
	_anse_visee.collision_layer = couche
	_anse_visee.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(larg, HAUT_ANSE * 1.1, 0.14)
	cs.shape = bx
	_anse_visee.add_child(cs)
	_anse_visee.position = Vector3(0, HAUT_ANSE * 0.6, 0)
	_anse_visee.set_meta("anse", true)
	_anse.add_child(_anse_visee)


## Les chiffres que la vue de l'hôte affiche (une valeur par molette).
func regler(chiffres: Array) -> void:
	for k in mini(chiffres.size(), _cibles.size()):
		_cibles[k] = posmod(int(chiffres[k]), 10)


func chiffre(k: int) -> int:
	return _cibles[k] if k >= 0 and k < _cibles.size() else 0


func nb_roues() -> int:
	return _roues.size()


## La molette surlignée (le joueur la vise) ou -1.
func marquer(k: int) -> void:
	_marque = k


## L'anse résiste : une secousse sèche et un tremblement.
func resister() -> void:
	_secousse = 0.0
	_mat_anse.emission = Color(1.0, 0.25, 0.12)


func ouvrir(oui: bool) -> void:
	ouvert = oui


## La position d'une molette dans le monde (pour le son).
func position_roue(k: int) -> Vector3:
	return _roues[clampi(k, 0, _roues.size() - 1)].global_position


func _process(delta: float) -> void:
	_t += delta
	# Les molettes rattrapent leur chiffre par le chemin le plus court, avec un petit rebond.
	for k in _roues.size():
		var but := -_cibles[k] * TAU / 10.0
		var d := wrapf(but - _angles[k], -PI, PI)
		_angles[k] += d * minf(1.0, delta * 16.0)
		_roues[k].rotation.x = _angles[k]
		var visee := k == _marque
		var cible_e := 0.9 if visee else 0.0
		_mats[k].emission_energy_multiplier = lerpf(_mats[k].emission_energy_multiplier, cible_e, minf(1.0, delta * 12.0))
	# L'anse : tirée, elle monte ; bloquée, elle bute puis revient en tremblant ; ouverte, elle bascule.
	var levee_but := tirage * LEVEE_MAX
	var tremble := 0.0
	if _secousse >= 0.0:
		_secousse += delta
		tremble = sin(_secousse * 70.0) * 0.006 * exp(-_secousse * 5.0)
		levee_but = LEVEE_MAX * 0.35 * exp(-_secousse * 7.0)
		if _secousse > 0.9:
			_secousse = -1.0
	if ouvert:
		levee_but = LEVEE_MAX
	_levee = lerpf(_levee, levee_but, minf(1.0, delta * 20.0))
	_bascule = move_toward(_bascule, 1.0 if ouvert else 0.0, delta * 2.4)
	var demi_larg := largeur(n) * 0.5 - 0.06
	# On pivote autour de la jambe gauche, là où l'anse reste prise dans le chapeau.
	var pivot := Vector3(-demi_larg, 0, 0)
	var ang := -_bascule * 1.35
	var base := Vector3(0, HAUTEUR_CORPS * 0.5 + 0.045 + _levee, 0)
	_anse.transform = Transform3D(Basis(Vector3(0, 1, 0), ang), base + pivot - Basis(Vector3(0, 1, 0), ang) * pivot + Vector3(tremble, 0, 0))
	if _mat_anse:
		_mat_anse.emission_energy_multiplier = lerpf(_mat_anse.emission_energy_multiplier, 0.0 if _secousse < 0.0 else 1.6, minf(1.0, delta * 8.0))
	if _lumiere:
		_lumiere.light_energy = 0.55 + 0.05 * sin(_t * 2.0)
