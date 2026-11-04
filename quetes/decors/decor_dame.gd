extends DecorQuete
## La Dame blanche : un vieux cimetière oublié, dans une clairière élargie (01/11). Une enceinte de
## pierre et de grilles rouillées (trois portes, une par sentier), des dizaines de tombes penchées,
## de croix, d'obélisques, des arbres morts qui griffent le ciel, de la brume au ras du sol et un clair
## de lune froid. Vingt LIEUX bâtis à leur place (Cimetiere.lieu_pos : la grande tombe, l'arbre mort, le
## caveau, le vieux puits…), chacun avec sa plaque ; ceux de la manche s'éclairent d'une colonne de
## lumière pâle pendant la préparation.
## La Dame est une femme pâle et translucide, en robe longue, qui flotte au-dessus de l'herbe. Le GUIDE la
## voit glisser vers son lieu ; les FUYARDS, eux, sont dans le noir (un voile presque opaque posé sur
## leur écran) : ils ne l'entendent que par des chuchotements et une boîte à musique, spatialisés
## (AudioStreamPlayer3D accrochés à la Dame). Quand la manche finit, la lumière revient, un disque rouge
## marque où la Dame attrape, et qui s'est fait prendre voit un éclair rouge et entend un cri.

const FILLERS := 34

var _dames: Array[Node3D] = []   # la Dame, et la seconde de la règle « Deux dames »
var _voiles: Array[BaseMaterial3D] = []
var _t := 0.0
var _lieux_vus: Array = []       # [nom gravé (Label3D), lueur (OmniLight3D), colonne de lumière, matière de la colonne]
var _eclat: Array[float] = []    # 0..1 : à quel point chaque lieu est éclairé
var _actifs: Array[int] = []     # les lieux de la manche
var _fixes: Array = []           # [Vector2 centre, rayon] : tout ce que le décor pose (les rochers semés l'évitent)
var _voile_noir: ColorRect       # l'écran des fuyards, presque noir
var _voile_rouge: ColorRect      # l'éclair rouge de qui est attrapé
var _a_noir := 0.0
var _flash := 0.0
var _etat_avant := ""
var _murmures: Array[AudioStreamPlayer3D] = []
var _musiques: Array[AudioStreamPlayer3D] = []
var _son_t := 0.0
var _disque: MeshInstance3D      # là où la Dame attrape (bilan)
var _disque_mat: StandardMaterial3D
var _pierre: StandardMaterial3D
var _roche: StandardMaterial3D
var _bois: StandardMaterial3D
var _fer: StandardMaterial3D
var _mousse: StandardMaterial3D
var _rng := RandomNumberGenerator.new()

const NOIR_MAX := 0.9            # l'opacité du voile des fuyards : presque noir, les lueurs filtrent à peine


## Les lieux (et seulement eux) sont la voie du jeu : rien de semé ne s'y pose.
func libre(p: Vector3) -> bool:
	return Cimetiere.hors_lieux(p, -0.15)


## La clairière est à nous : le sous-bois n'a rien à faire dans le cimetière.
func degage() -> Array[Rect2]:
	return [Rect2(-10.0, -10.0, 20.0, 20.0)]


## Ce qui est semé (rochers, souches…) évite aussi nos tombes.
func gene(c: Vector2, r: float) -> bool:
	if super.gene(c, r):
		return true
	for f: Array in _fixes:
		if c.distance_to(f[0]) < float(f[1]) + r * 0.8:
			return true
	return false


func construire() -> void:
	meuble = ""
	_rng.seed = 51966
	_materiaux()
	_sol()
	var coulisses := _directions_des_sentiers()
	for k in Cimetiere.NB_LIEUX:
		_lieu(k)
	_enceinte(coulisses)
	_tombes(coulisses)
	_arbres(coulisses)
	_brumes()
	_lumieres()
	_voiles_ecran()
	_dames.append(_creer_dame(4, 0))
	var seconde := _creer_dame(5, 1)
	seconde.visible = false
	_dames.append(seconde)
	for d in _dames:
		_sons_de(d)
	_disque_rouge()


## Les gros rochers qui bornent la clairière (à 4,4 m du centre) tomberaient en plein cimetière : on les
## écarte le temps de la quête, ils reviennent quand le décor disparaît.
var _rochers_ecartes: Array[Node3D] = []


func _ecarter_les_rochers() -> void:
	if not is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group("rochers_clairiere"):
		var nd := n as Node3D
		if nd != null and nd.visible and nd.global_position.distance_to(global_position) < 7.0:
			nd.visible = false
			_rochers_ecartes.append(nd)


func _exit_tree() -> void:
	for nd in _rochers_ecartes:
		if is_instance_valid(nd):
			nd.visible = true
	_rochers_ecartes.clear()


func _materiaux() -> void:
	_pierre = matiere("pierre", 0.9, Color(0.62, 0.68, 0.66))
	_roche = matiere("roche", 0.8, Color(0.72, 0.75, 0.74))
	_bois = matiere("vieux_bois", 1.2, Color(0.72, 0.68, 0.64))
	_fer = matiere("fer", 1.0, Color(0.34, 0.33, 0.35))
	_mousse = matiere("mousse", 1.0, Color(0.62, 0.78, 0.55))


## L'angle (radians, 0 = +Z) des trois sentiers par où l'on peut entrer : la clairière ne sait pas
## laquelle elle est, on laisse une porte à chacun.
func _directions_des_sentiers() -> Array[float]:
	var r: Array[float] = []
	for z in Quetes.ANGLES_ZONES.size():
		var v := Quetes.passage(z, Quetes.R_FOURCHE) - Quetes.zone(z)
		r.append(atan2(v.x, v.z))
	return r


static func _pres_d_un_angle(a: float, angles: Array[float], marge: float) -> bool:
	for b in angles:
		if absf(wrapf(a - b, -PI, PI)) < marge:
			return true
	return false


# ---------------------------------------------------------------- le sol

func _sol() -> void:
	# Une terre sombre et rase, tachée d'herbe morte, qui couvre toute la clairière.
	var terre := _cylindre(9.6, 0.03, matiere("herbe", 0.5, Color(0.3, 0.34, 0.28)))
	terre.position.y = 0.012
	terre.add_to_group("traversable")
	add_child(terre)
	# La place du centre, pavée de dalles fendues, là où l'on commence.
	var place := _cylindre(2.9, 0.035, matiere("pave", 0.45, Color(0.5, 0.52, 0.55)))
	place.position.y = 0.02
	place.add_to_group("traversable")
	add_child(place)
	# Une allée de gravier en couronne entre les deux rangs de lieux.
	var allee := MeshInstance3D.new()
	var tore := TorusMesh.new()
	tore.inner_radius = 6.0
	tore.outer_radius = 6.9
	tore.rings = 64
	tore.ring_segments = 4
	allee.mesh = tore
	allee.scale = Vector3(1, 0.03, 1)
	allee.material_override = matiere("boue", 0.6, Color(0.5, 0.46, 0.42))
	allee.position.y = 0.025
	allee.add_to_group("traversable")
	add_child(allee)
	# Un cercle de bougies sur la place, au centre : la Dame y naît.
	for i in 6:
		var a := TAU * i / 6.0 + 0.4
		var b := bougie(Vector3(sin(a), 0.03, cos(a)) * 1.05)
		b.add_to_group("traversable")
	# Des mousses et des herbes folles sur la terre, hors de l'emprise des lieux.
	for i in 40:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(3.0, 8.4)
		var p := Vector3(sin(a), 0, cos(a)) * r
		if not Cimetiere.hors_lieux(p, 0.3):
			continue
		if i % 3 == 0:
			morceau("moss_01", i % 3, p, _rng.randf_range(0.8, 1.6), _rng.randf() * TAU).add_to_group("traversable")
		else:
			morceau("grass_medium_01", i % 17, p, _rng.randf_range(0.7, 1.2), _rng.randf() * TAU).add_to_group("traversable")


# ---------------------------------------------------------------- les vingt lieux

func _lieu(k: int) -> void:
	var p := Cimetiere.lieu_pos(k)
	var dehors := Vector3(p.x, 0, p.z).normalized()
	var r := Node3D.new()
	r.position = p
	# Le devant (+Z) regarde le centre : la plaque se lit depuis le cercle.
	r.basis = Basis.looking_at(dehors, Vector3.UP)
	add_child(r)
	_repere(k, r)
	_fixes.append([Vector2(p.x, p.z), Cimetiere.EMPREINTE * 0.8])
	if k == 0:
		set_meta("liste_pos", p)
	# Sa plaque, assez grande pour se lire depuis le cercle.
	var plaque := Node3D.new()
	plaque.position = Vector3(0.65, 0, 0.9)
	r.add_child(plaque)
	poutre(Vector3(0, -0.1, 0), Vector3(0, 0.95, 0), 0.03, _bois, plaque)
	var planche := _boite(Vector3(1.0, 0.26, 0.03), matiere("vieux_bois", 1.5, Color(0.8, 0.75, 0.7)))
	planche.position = Vector3(0, 0.95, 0.035)
	plaque.add_child(planche)
	var nom := _debout(Catalogue.REPERES[k], 44, Vector3(0, 0.95, 0.055))
	nom.pixel_size = 0.0036
	nom.width = 270.0
	nom.modulate = Color(0.5, 0.46, 0.42)
	plaque.add_child(nom)
	# Éclairé seulement quand le lieu est dans la manche : une lueur froide et une colonne de lumière pâle.
	var lueur := _lumiere(Color(0.7, 0.82, 1.0), 0.0, 4.2, Vector3(0, 1.3, 0.5))
	plaque.add_child(lueur)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.6, 0.78, 1.0, 0.0)
	mat.disable_receive_shadows = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var colonne := _cylindre(0.3, 4.0, mat, 0.05)
	colonne.position.y = 2.0
	colonne.add_to_group("mobile")
	r.add_child(colonne)
	_lieux_vus.append([nom, lueur, colonne, mat])
	_eclat.append(0.0)


## Le repère k (même ordre que Catalogue.REPERES), bâti dans son nœud : +Z vers le centre.
func _repere(k: int, r: Node3D) -> void:
	match k:
		0:  # La grande tombe : dalle, haute stèle cintrée à croix gravée, urnes, tertre
			var dalle := _boite(Vector3(1.3, 0.22, 2.0), _pierre)
			dalle.position = Vector3(0, 0.11, 0.55)
			r.add_child(dalle)
			var haut := _boite(Vector3(1.0, 1.55, 0.24), _pierre)
			haut.position = Vector3(0, 0.98, -0.35)
			r.add_child(haut)
			var cintre := _cylindre(0.5, 0.24, _pierre)
			cintre.rotation.x = PI / 2
			cintre.position = Vector3(0, 1.75, -0.35)
			r.add_child(cintre)
			_croix_gravee(r, Vector3(0, 1.1, -0.21), 0.9)
			for cote in [-0.62, 0.62]:
				var urne := _cylindre(0.14, 0.4, _pierre, 0.09)
				urne.position = Vector3(cote, 0.42, -0.1)
				r.add_child(urne)
				var col := _sphere(0.13, _pierre)
				col.position = Vector3(cote, 0.68, -0.1)
				r.add_child(col)
		1:  # L'arbre mort : un grand arbre nu, ses racines, des branches tombées
			_arbre_mort(r, Vector3.ZERO, 5.2, matiere("tronc", 1.2, Color(0.5, 0.47, 0.44)), 0.0)
			modele("root_cluster_01", Vector3(0.5, 0, 0.3), 0.28, 0.6, r)
			modele("dry_branches_medium_01", Vector3(-0.7, 0.02, 0.5), 1.0, 1.2, r).add_to_group("traversable")
		2:  # La croix penchée : bois gris, couronne de fleurs mortes, tertre
			var c := Node3D.new()
			c.rotation.z = 0.32
			r.add_child(c)
			poutre(Vector3(0, -0.15, 0), Vector3(0, 1.5, 0), 0.055, _bois, c)
			poutre(Vector3(-0.42, 1.08, 0), Vector3(0.42, 1.08, 0), 0.05, _bois, c)
			var couronne := MeshInstance3D.new()
			var tore := TorusMesh.new()
			tore.inner_radius = 0.16
			tore.outer_radius = 0.22
			couronne.mesh = tore
			couronne.material_override = matiere("tronc", 3.0, Color(0.35, 0.25, 0.2))
			couronne.rotation.x = PI / 2
			couronne.position = Vector3(0, 1.08, 0.05)
			couronne.add_to_group("traversable")
			c.add_child(couronne)
			_tertre(r, 0.9)
		3:  # La stèle brisée : le haut est tombé à côté
			var s := _boite(Vector3(0.7, 0.75, 0.16), _pierre)
			s.position.y = 0.36
			s.rotation.z = 0.08
			r.add_child(s)
			var bout := _boite(Vector3(0.55, 0.4, 0.16), _pierre)
			bout.position = Vector3(0.5, 0.1, 0.35)
			bout.rotation = Vector3(PI / 2 - 0.25, 0.5, 0.15)
			r.add_child(bout)
			_croix_gravee(r, Vector3(0, 0.5, 0.09), 0.5)
		4:  # Le tertre : un grand monticule moussu, une planche plantée
			_tertre(r, 1.7)
			morceau("moss_01", 0, Vector3(0, 0.12, 0.3), 1.8, 0.0, r).add_to_group("traversable")
			poutre(Vector3(0.7, -0.1, 0.1), Vector3(0.7, 0.8, 0.1), 0.03, _bois, r)
		5:  # Les bougies : un autel bas couvert de cire, sept flammes
			var dalle := _boite(Vector3(1.0, 0.16, 0.7), _pierre)
			dalle.position.y = 0.08
			r.add_child(dalle)
			for b in 7:
				var cb := bougie(Vector3(-0.38 + b * 0.126, 0.16, 0.09 * sin(b * 2.0)), r)
				cb.add_to_group("traversable")
			r.add_child(_lumiere(Color(1.0, 0.7, 0.4), 0.7, 2.6, Vector3(0, 0.5, 0.2)))
		6:  # Le vieux puits : margelle, deux montants, poulie, auvent de planches
			for b in 12:
				var aa := TAU * b / 12.0
				var pierre_puits := _boite(Vector3(0.3, 0.55, 0.2), _pierre)
				pierre_puits.position = Vector3(sin(aa) * 0.55, 0.27, cos(aa) * 0.55)
				pierre_puits.rotation.y = aa
				r.add_child(pierre_puits)
			var fond := _cylindre(0.46, 0.02, matiere("boue", 1.0, Color(0.03, 0.03, 0.03)))
			fond.position.y = 0.4
			r.add_child(fond)
			poutre(Vector3(-0.6, 0.0, 0), Vector3(-0.6, 1.6, 0), 0.05, _bois, r)
			poutre(Vector3(0.6, 0.0, 0), Vector3(0.6, 1.6, 0), 0.05, _bois, r)
			poutre(Vector3(-0.7, 1.55, 0), Vector3(0.7, 1.55, 0), 0.05, _bois, r)
			var toit := _boite(Vector3(1.6, 0.05, 1.2), _bois)
			toit.position = Vector3(0, 1.75, 0)
			toit.rotation.x = 0.0
			r.add_child(toit)
			corde(Vector3(0, 1.55, 0), Vector3(0, 0.7, 0), 0.05, 0.015, r)
			modele("wooden_bucket_02", Vector3(0, 0.55, 0), 0.8, 0.0, r).add_to_group("traversable")
		7:  # La souche : un tronc scié, des champignons pâles
			modele("tree_stump_01", Vector3.ZERO, 0.7, 0.4, r)
			for b in 5:
				var pied := _cylindre(0.012, 0.09, matiere("flamme", 1.0, Color(0.9, 0.88, 0.8)))
				pied.position = Vector3(0.45 + 0.1 * b, 0.05, 0.1 * b - 0.2)
				pied.add_to_group("traversable")
				r.add_child(pied)
				var chap := _sphere(0.045, matiere("flamme", 1.0, Color(0.85, 0.82, 0.74)))
				chap.scale = Vector3(1, 0.45, 1)
				chap.position = Vector3(0.45 + 0.1 * b, 0.1, 0.1 * b - 0.2)
				chap.add_to_group("traversable")
				r.add_child(chap)
		8:  # Le rocher moussu
			morceau("rock_moss_set_02", 1, Vector3.ZERO, 0.85, 0.5, r)
			morceau("rock_moss_set_02", 3, Vector3(0.6, 0, 0.4), 0.5, 1.5, r)
		9:  # La clôture : cinq piquets, deux lisses, un pan cassé
			for b in 5:
				var h := 1.0 if b != 3 else 0.55
				poutre(Vector3(-1.0 + b * 0.5, -0.1, 0), Vector3(-1.0 + b * 0.5, h, 0), 0.045, _bois, r)
			poutre(Vector3(-1.05, 0.75, 0.03), Vector3(0.6, 0.7, 0.03), 0.03, _bois, r)
			poutre(Vector3(-1.05, 0.4, 0.03), Vector3(1.05, 0.46, 0.03), 0.03, _bois, r)
			poutre(Vector3(0.55, 0.7, 0.03), Vector3(0.95, 0.12, 0.2), 0.03, _bois, r)
		10:  # Le caveau : fronton, colonnes, marches, porte de fer entrouverte
			var corps := _boite(Vector3(1.9, 1.5, 1.4), _pierre)
			corps.position = Vector3(0, 0.75, -0.2)
			r.add_child(corps)
			var toit := _boite(Vector3(2.15, 0.18, 1.65), _pierre)
			toit.position = Vector3(0, 1.58, -0.2)
			r.add_child(toit)
			for cote in [-0.7, 0.7]:
				var colonne := _cylindre(0.13, 1.5, _pierre)
				colonne.position = Vector3(cote, 0.75, 0.65)
				r.add_child(colonne)
			var fronton := _boite(Vector3(1.9, 0.14, 0.24), _pierre)
			fronton.position = Vector3(0, 1.45, 0.65)
			r.add_child(fronton)
			var porte := _boite(Vector3(0.55, 1.05, 0.05), _fer)
			porte.position = Vector3(0.0, 0.55, 0.51)
			porte.rotation.y = 0.5
			r.add_child(porte)
			for m in 2:
				var marche := _boite(Vector3(1.3 + m * 0.3, 0.1, 0.3), _pierre)
				marche.position = Vector3(0, 0.05 + m * 0.0, 0.85 + m * 0.28)
				marche.add_to_group("traversable")
				r.add_child(marche)
		11:  # La lanterne : un haut poteau de fer, une lanterne qui vacille
			var lan := Node3D.new()
			r.add_child(lan)
			poutre(Vector3(0, -0.15, 0), Vector3(0, 2.2, 0), 0.055, _fer, lan)
			poutre(Vector3(0, 2.15, 0), Vector3(0, 2.15, 0.45), 0.035, _fer, lan)
			modele("wooden_lantern_01", Vector3(0, 1.5, 0.45), 1.0, 0.0, lan)
			var l := _lumiere(Color(1.0, 0.68, 0.38), 1.0, 5.0, Vector3(0, 1.7, 0.5))
			lan.add_child(l)
			_feux.append([l, 1.0, randf() * 10.0])
		12:  # Les racines : un chicot arraché
			modele("root_cluster_01", Vector3.ZERO, 0.4, 0.0, r)
			modele("pine_roots", Vector3(0.35, 0, -0.25), 0.5, 1.0, r)
		13:  # Le banc de pierre
			for x in [-0.55, 0.55]:
				var pied := _boite(Vector3(0.2, 0.42, 0.4), _pierre)
				pied.position = Vector3(x, 0.21, 0)
				r.add_child(pied)
			var assise := _boite(Vector3(1.5, 0.12, 0.46), _pierre)
			assise.position.y = 0.48
			r.add_child(assise)
			var dossier := _boite(Vector3(1.5, 0.35, 0.08), _pierre)
			dossier.position = Vector3(0, 0.78, -0.22)
			dossier.rotation.x = -0.12
			r.add_child(dossier)
		14:  # La dalle fendue : deux moitiés, une fissure d'ombre
			for x in [-0.3, 0.31]:
				var d := _boite(Vector3(0.58, 0.12, 1.3), _pierre)
				d.position = Vector3(x, 0.06, 0)
				d.rotation.y = x * 0.2
				r.add_child(d)
			var fente := _boite(Vector3(0.06, 0.13, 1.2), matiere("boue", 1.0, Color(0.02, 0.02, 0.02)))
			fente.position = Vector3(0.0, 0.06, 0)
			r.add_child(fente)
		15:  # Le vieux coffre : à moitié enterré
			modele("treasure_chest", Vector3(0, 0.0, 0), 0.9, 0.3, r)
			_tertre(r, 0.6)
		16:  # Les fougères
			for b in 7:
				morceau("fern_02", b, Vector3(-0.55 + b * 0.18, 0, 0.2 * sin(b * 1.7)), 1.1, b * 1.3, r).add_to_group("traversable")
			var souche := _boite(Vector3(0.3, 0.3, 0.3), _roche)
			souche.position = Vector3(0, 0.15, -0.3)
			r.add_child(souche)
		17:  # Le seau renversé
			var seau := modele("wooden_bucket_01", Vector3(0, 0.2, 0), 1.1, 0.0, r)
			seau.rotation = Vector3(PI / 2, 0.3, 0)
			_fixes.append([Vector2(r.position.x, r.position.z), 0.4])
			var flaque := _cylindre(0.45, 0.01, matiere("boue", 1.0, Color(0.02, 0.03, 0.04)))
			flaque.position = Vector3(0, 0.02, 0.55)
			flaque.add_to_group("traversable")
			r.add_child(flaque)
		18:  # Le tas de pierres : un cairn
			for b in 9:
				morceau("stone_01", 0, Vector3(0.28 * cos(b * 1.1), 0.1 * (b / 3), 0.28 * sin(b * 1.1)), 1.4 - 0.1 * (b / 3), b * 0.9, r)
		19:  # Le grand rocher
			modele("boulder_01", Vector3.ZERO, 0.6, 0.8, r)
			morceau("moss_01", 1, Vector3(0, 0.6, 0), 1.0, 0.0, r).add_to_group("traversable")


func _tertre(r: Node3D, longueur: float) -> void:
	var t := _sphere(0.5, matiere("boue", 1.0, Color(0.5, 0.45, 0.4)))
	t.scale = Vector3(0.75, 0.2, longueur)
	t.position = Vector3(0, 0, 0.35 + longueur * 0.35)
	# Un bourrelet de terre de dix centimètres : on l'enjambe.
	t.add_to_group("traversable")
	r.add_child(t)


## Une croix en creux sur une pierre (deux barrettes plus claires).
func _croix_gravee(r: Node3D, pos: Vector3, taille: float) -> void:
	var clair := matiere("pierre", 0.9, Color(0.82, 0.85, 0.84))
	var v := _boite(Vector3(0.07, 0.5 * taille, 0.025), clair)
	v.position = pos
	r.add_child(v)
	var h := _boite(Vector3(0.3 * taille, 0.07, 0.025), clair)
	h.position = pos + Vector3(0, 0.1 * taille, 0)
	r.add_child(h)


# ---------------------------------------------------------------- l'enceinte

func _enceinte(sentiers: Array[float]) -> void:
	var n := 48
	var pilier_haut := 1.35
	# La zone lumineuse du rôle de guide peut tomber sur l'enceinte : on y laisse un passage libre.
	var pads: Array[Vector3] = []
	for z in Quetes.ANGLES_ZONES.size():
		pads.append(zone_role(jeu, z, equipe))
	for i in n:
		var a := TAU * i / n + 0.04
		var a2 := TAU * (i + 1) / n + 0.04
		var sur_pad := false
		var pt := Vector3(sin(a), 0, cos(a)) * Cimetiere.R_ENCEINTE
		for pad in pads:
			if Vector2(pt.x - pad.x, pt.z - pad.z).length() < Quetes.RAYON_ROLE + 1.0:
				sur_pad = true
		if sur_pad:
			continue
		var porte := _pres_d_un_angle(a, sentiers, 0.2) or _pres_d_un_angle(a2, sentiers, 0.2)
		var p := Vector3(sin(a), 0, cos(a)) * Cimetiere.R_ENCEINTE
		var q := Vector3(sin(a2), 0, cos(a2)) * Cimetiere.R_ENCEINTE
		var nid := Node3D.new()
		add_child(nid)
		# Le pilier.
		var h := pilier_haut * (1.0 + 0.0) + (0.3 if _pres_d_un_angle(a, sentiers, 0.26) else 0.0)
		var pil := _boite(Vector3(0.32, h, 0.32), _pierre)
		pil.position = p + Vector3(0, h * 0.5, 0)
		pil.rotation.y = a
		nid.add_child(pil)
		var chap := _boite(Vector3(0.42, 0.1, 0.42), _pierre)
		chap.position = p + Vector3(0, h + 0.05, 0)
		chap.rotation.y = a
		nid.add_child(chap)
		_fixes.append([Vector2(p.x, p.z), 0.3])
		if porte:
			continue
		var genre := (i * 7 + 3) % 5
		if genre == 0:
			continue   # un trou dans la clôture
		if genre <= 2:
			# Un muret bas, usé.
			var m := (p + q) * 0.5
			var longueur := p.distance_to(q)
			var mur := _boite(Vector3(longueur, 0.5 + 0.1 * (i % 3), 0.24), _pierre)
			mur.position = m + Vector3(0, 0.27, 0)
			mur.rotation.y = (a + a2) * 0.5
			nid.add_child(mur)
		else:
			# Une grille de fer rouillée : deux lisses et des barreaux (trop fins pour arrêter un pas).
			for hh in [0.35, 1.0]:
				poutre(p + Vector3(0, hh, 0), q + Vector3(0, hh - 0.04 * (i % 2), 0), 0.02, _fer, nid)
			for b in 5:
				var u := p.lerp(q, (b + 0.5) / 5.0)
				poutre(u + Vector3(0, 0.0, 0), u + Vector3(0, 1.1 - 0.35 * float((b + i) % 4 == 0), 0), 0.012, _fer, nid)


# ---------------------------------------------------------------- tombes, croix, obélisques

func _tombes(sentiers: Array[float]) -> void:
	var pads: Array[Vector3] = []
	for z in Quetes.ANGLES_ZONES.size():
		pads.append(zone_role(jeu, z, equipe))
	var poses: Array[Vector2] = []
	var essais := 0
	while poses.size() < FILLERS and essais < 900:
		essais += 1
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(4.5, 8.1)
		if _pres_d_un_angle(a, sentiers, 0.3):
			continue
		var p := Vector3(sin(a), 0, cos(a)) * r
		if not Cimetiere.hors_lieux(p, 0.9):
			continue
		var bon := true
		for pad in pads:
			if Vector2(p.x - pad.x, p.z - pad.z).length() < Quetes.RAYON_ROLE + 1.1:
				bon = false
		for o in poses:
			if Vector2(p.x, p.z).distance_to(o) < 1.7:
				bon = false
		if bon:
			poses.append(Vector2(p.x, p.z))
			_tombe(p, a, poses.size())
			_fixes.append([Vector2(p.x, p.z), 0.8])


func _tombe(p: Vector3, a: float, n: int) -> void:
	var nid := Node3D.new()
	nid.position = p
	# Toutes tournées vers le centre, à quelques degrés près : un cimetière ancien, qui a bougé.
	nid.basis = Basis.looking_at(Vector3(sin(a), 0, cos(a)), Vector3.UP) * Basis.from_euler(Vector3(0, _rng.randf_range(-0.35, 0.35), 0))
	add_child(nid)
	var genre := n % 6
	var teinte := _rng.randf_range(0.8, 1.0)
	var m := matiere("pierre", 0.9, Color(0.6 * teinte, 0.66 * teinte, 0.64 * teinte))
	match genre:
		0, 1, 5:  # Une stèle cintrée, penchée, sur sa dalle
			var h := _rng.randf_range(0.75, 1.2)
			var s := Node3D.new()
			s.rotation = Vector3(_rng.randf_range(-0.1, 0.1), 0, _rng.randf_range(-0.14, 0.14))
			nid.add_child(s)
			var corps := _boite(Vector3(0.58, h, 0.14), m)
			corps.position.y = h * 0.5
			s.add_child(corps)
			var cintre := _cylindre(0.29, 0.14, m)
			cintre.rotation.x = PI / 2
			cintre.position.y = h
			s.add_child(cintre)
			if genre != 5:
				_croix_gravee(s, Vector3(0, h * 0.62, 0.08), 0.8)
			var socle := _boite(Vector3(0.8, 0.1, 0.32), m)
			socle.position.y = 0.05
			nid.add_child(socle)
			_tertre(nid, 0.8)
		2:  # Une croix de pierre
			var h := _rng.randf_range(1.0, 1.5)
			var c := Node3D.new()
			c.rotation.z = _rng.randf_range(-0.12, 0.12)
			nid.add_child(c)
			var tige := _boite(Vector3(0.14, h, 0.12), m)
			tige.position.y = h * 0.5
			c.add_child(tige)
			var bras := _boite(Vector3(0.56, 0.13, 0.12), m)
			bras.position.y = h * 0.78
			c.add_child(bras)
			var socle2 := _boite(Vector3(0.5, 0.18, 0.5), m)
			socle2.position.y = 0.09
			nid.add_child(socle2)
		3:  # Un obélisque
			var haut := _rng.randf_range(1.7, 2.3)
			var ob := _cylindre(0.3, haut, m, 0.14)
			(ob.mesh as CylinderMesh).radial_segments = 4
			ob.position.y = haut * 0.5 + 0.15
			nid.add_child(ob)
			var pointe := _cylindre(0.14, 0.3, m, 0.0)
			(pointe.mesh as CylinderMesh).radial_segments = 4
			pointe.position.y = haut + 0.3
			nid.add_child(pointe)
			var base := _boite(Vector3(0.8, 0.15, 0.8), m)
			base.position.y = 0.075
			nid.add_child(base)
		4:  # Une tombe plate : grande dalle fendue, mousse
			var d := _boite(Vector3(0.85, 0.16, 1.7), m)
			d.position.y = 0.08
			d.rotation.z = _rng.randf_range(-0.05, 0.05)
			nid.add_child(d)
			morceau("moss_01", 0, Vector3(0.1, 0.16, 0.2), 1.0, _rng.randf() * TAU, nid).add_to_group("traversable")
	# Çà et là, une bougie qui brûle : quelqu'un vient encore.
	if n % 7 == 3:
		var b := bougie(Vector3(0.4, 0.0, 0.6), nid)
		b.add_to_group("traversable")


# ---------------------------------------------------------------- arbres morts

func _arbres(sentiers: Array[float]) -> void:
	var bois := matiere("tronc", 1.2, Color(0.5, 0.47, 0.44))
	var places: Array[Vector3] = []
	for i in 12:
		var a := TAU * i / 12.0 + _rng.randf_range(-0.2, 0.2)
		if _pres_d_un_angle(a, sentiers, 0.32):
			continue
		var r := Cimetiere.R_ENCEINTE + _rng.randf_range(0.7, 1.7)
		places.append(Vector3(sin(a), 0, cos(a)) * r)
	# Deux ou trois à l'intérieur, contre le mur.
	for i in 3:
		var a := TAU * (i + 0.5) / 3.0 + 0.7
		if not _pres_d_un_angle(a, sentiers, 0.35):
			places.append(Vector3(sin(a), 0, cos(a)) * (Cimetiere.R_ENCEINTE - 0.9))
	for p in places:
		if not Cimetiere.hors_lieux(p, 0.5):
			continue
		var nid := Node3D.new()
		nid.position = p
		add_child(nid)
		_arbre_mort(nid, Vector3.ZERO, _rng.randf_range(4.2, 6.8), bois, _rng.randf())
		_fixes.append([Vector2(p.x, p.z), 0.6])


## Un arbre mort : tronc qui s'effile, racines qui sortent de terre, branches tordues sans feuilles.
func _arbre_mort(parent: Node3D, pied: Vector3, haut: float, bois: Material, graine: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(graine * 1000.0) + 7
	var penche := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
	var cime := pied + Vector3(0, haut, 0) + penche * haut
	var tronc := poutre(pied + Vector3(0, -0.2, 0), cime, 0.13, bois, parent)
	(tronc.mesh as CylinderMesh).top_radius = 0.045
	(tronc.mesh as CylinderMesh).bottom_radius = 0.22
	for r in 5:
		var a := r * TAU / 5.0 + rng.randf()
		var bout := pied + Vector3(sin(a), 0.0, cos(a)) * rng.randf_range(0.5, 0.9)
		poutre(pied + Vector3(0, 0.4, 0), bout + Vector3(0, -0.05, 0), 0.08, bois, parent).add_to_group("traversable")
	for b in rng.randi_range(6, 9):
		var t := rng.randf_range(0.3, 0.95)
		var a := rng.randf() * TAU
		var depart := pied + Vector3(0, haut * t, 0) + penche * haut * t
		var l := rng.randf_range(0.8, 1.9) * (1.2 - t * 0.5)
		var arrivee := depart + Vector3(sin(a) * l, rng.randf_range(0.2, 0.9) * l, cos(a) * l)
		poutre(depart, arrivee, 0.05 * (1.2 - t * 0.6), bois, parent).add_to_group("traversable")
		var a2 := a + rng.randf_range(-1.0, 1.0)
		poutre(arrivee, arrivee + Vector3(sin(a2) * l * 0.45, l * 0.3, cos(a2) * l * 0.45), 0.02, bois, parent).add_to_group("traversable")


# ---------------------------------------------------------------- brume, lune, écran

func _brumes() -> void:
	var basse := _particules(46, 14.0, Vector3(9.0, 0.08, 9.0), Vector3(0.08, 0, 0.05), 3.2,
		_degrade([Color(0.62, 0.7, 0.78, 0.0), Color(0.6, 0.68, 0.78, 0.22), Color(0.55, 0.64, 0.74, 0.0)]), false)
	(basse.process_material as ParticleProcessMaterial).gravity = Vector3.ZERO
	basse.position.y = 0.2
	add_child(basse)
	var moyenne := _particules(22, 16.0, Vector3(9.5, 0.3, 9.5), Vector3(-0.06, 0, 0.04), 4.6,
		_degrade([Color(0.5, 0.58, 0.68, 0.0), Color(0.46, 0.55, 0.66, 0.12), Color(0.44, 0.52, 0.64, 0.0)]), false)
	(moyenne.process_material as ParticleProcessMaterial).gravity = Vector3.ZERO
	moyenne.position.y = 0.8
	add_child(moyenne)
	# Des lucioles pâles : des âmes qui ne trouvent pas le repos.
	var ames := _particules(18, 8.0, Vector3(8.0, 0.8, 8.0), Vector3(0, 0.04, 0), 0.07,
		_degrade([Color(0.5, 0.8, 1.0, 0.0), Color(0.6, 0.88, 1.0, 0.9), Color(0.5, 0.8, 1.0, 0.0)]), true)
	var pm := ames.process_material as ParticleProcessMaterial
	pm.spread = 180.0
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	ames.position.y = 1.0
	add_child(ames)


func _lumieres() -> void:
	# Le clair de lune : un projecteur froid d'en haut (les ombres des tombes s'allongent), et une lueur
	# diffuse pour que l'on devine encore les formes dans l'ombre.
	var lune := SpotLight3D.new()
	lune.light_color = Color(0.58, 0.68, 0.95)
	lune.light_energy = 2.6
	lune.spot_range = 26.0
	lune.spot_angle = 52.0
	lune.shadow_enabled = true
	lune.position = Vector3(2.5, 12.0, 3.0)
	lune.rotation_degrees = Vector3(-90, 0, 0)
	add_child(lune)
	add_child(_lumiere(Color(0.45, 0.55, 0.8), 0.5, 11.0, Vector3(0, 2.4, 0)))


## Les deux calques de l'écran : le voile presque noir des fuyards, et l'éclair rouge de qui est attrapé.
## Posés SOUS le parchemin et les menus (calque 0) : on lit toujours sa note.
func _voiles_ecran() -> void:
	var calque := CanvasLayer.new()
	calque.layer = 0
	add_child(calque)
	_voile_noir = ColorRect.new()
	_voile_noir.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile_noir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile_noir.color = Color(0.0, 0.0, 0.01, 0.0)
	calque.add_child(_voile_noir)
	_voile_rouge = ColorRect.new()
	_voile_rouge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile_rouge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile_rouge.color = Color(0.7, 0.02, 0.02, 0.0)
	calque.add_child(_voile_rouge)


func _disque_rouge() -> void:
	_disque_mat = StandardMaterial3D.new()
	_disque_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disque_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disque_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_disque_mat.albedo_color = Color(0.8, 0.1, 0.08, 0.3)
	_disque_mat.disable_receive_shadows = true
	_disque = _cylindre(2.5, 0.02, _disque_mat)
	_disque.position.y = 0.06
	_disque.visible = false
	_disque.add_to_group("mobile")
	add_child(_disque)


# ---------------------------------------------------------------- la Dame

func _creer_dame(cheveux: int, visage: int) -> Node3D:
	var d := Node3D.new()
	var f := Bouille.new()
	f.apparence = {"tete": cheveux, "visage": visage, "habit": 0, "teinte": 7, "matiere": 1, "objet": 0,
		"peau": 0, "yeux": 3, "corps": 1}
	f.autonome = true
	d.add_child(f)
	# Sa robe longue tombe jusqu'à l'herbe et s'évase : c'est elle, la « dame blanche ».
	var robe_m := StandardMaterial3D.new()
	robe_m.albedo_color = Color(0.62, 0.66, 0.76, 0.5)
	robe_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	robe_m.emission_enabled = true
	robe_m.emission = Color(0.14, 0.16, 0.22)
	robe_m.rim_enabled = true
	robe_m.rim = 1.0
	robe_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_voiles.append(robe_m)
	var robe := _cylindre(0.42, 0.98, robe_m, 0.16)
	(robe.mesh as CylinderMesh).radial_segments = 24
	(robe.mesh as CylinderMesh).cap_top = false
	(robe.mesh as CylinderMesh).cap_bottom = false
	robe.position.y = 0.5
	d.add_child(robe)
	var traine := _particules(40, 2.8, Vector3(0.25, 0.7, 0.25), Vector3(0, 0.12, -0.25), 0.55,
		_degrade([Color(0.85, 0.9, 1.0, 0.0), Color(0.85, 0.9, 1.0, 0.16), Color(0.85, 0.9, 1.0, 0.0)]), true)
	(traine.process_material as ParticleProcessMaterial).gravity = Vector3.ZERO
	traine.local_coords = false
	traine.position.y = 0.5
	d.add_child(traine)
	# Une brume au ras de ses pieds : elle ne marche pas, elle glisse.
	var brume := _particules(24, 2.0, Vector3(0.3, 0.04, 0.3), Vector3(0, 0.04, 0), 0.4,
		_degrade([Color(0.8, 0.85, 0.95, 0.0), Color(0.8, 0.85, 0.95, 0.1), Color(0.8, 0.85, 0.95, 0.0)]), true)
	(brume.process_material as ParticleProcessMaterial).gravity = Vector3.ZERO
	brume.position.y = 0.05
	d.add_child(brume)
	var halo := _lumiere(Color(0.75, 0.82, 1.0), 0.7, 4.0, Vector3(0, 1.55, 0.35))
	d.add_child(halo)
	d.position = Vector3.ZERO
	d.add_to_group("mobile")
	d.set_meta("femme", f)
	d.set_meta("halo", halo)
	add_child(d)
	return d


## Ses bruits, accrochés à elle : un chuchotement sans voix, et une boîte à musique désaccordée.
func _sons_de(d: Node3D) -> void:
	var murmure := AudioStreamPlayer3D.new()
	murmure.bus = "Effets"
	murmure.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	murmure.unit_size = 3.0
	murmure.max_distance = 32.0
	murmure.volume_db = 2.0
	murmure.position.y = 1.4
	d.add_child(murmure)
	_murmures.append(murmure)
	var musique := AudioStreamPlayer3D.new()
	musique.bus = "Effets"
	musique.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	musique.unit_size = 3.0
	musique.max_distance = 32.0
	musique.volume_db = -9.0
	musique.position.y = 1.0
	d.add_child(musique)
	_musiques.append(musique)


## La femme devient spectre : chaque étoffe, la peau, les cheveux gardent leur dessin mais pâlissent
## vers un blanc bleuté, deviennent translucides (sans se voir les uns à travers les autres : passe
## de profondeur) et brillent d'eux-mêmes sur les bords.
func _spectre(n: Node) -> void:
	for e in n.get_children():
		if e is Label3D:
			(e as Label3D).visible = false
		elif e is MeshInstance3D and (e as MeshInstance3D).mesh and (e as MeshInstance3D).visible:
			var mi := e as MeshInstance3D
			for k in mi.mesh.get_surface_count():
				var m := mi.get_active_material(k)
				if m is BaseMaterial3D:
					var g := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
					var c := g.albedo_color
					g.albedo_color = Color(lerpf(c.r, 0.9, 0.78), lerpf(c.g, 0.93, 0.78), lerpf(c.b, 1.0, 0.78), 0.6)
					g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
					g.emission_enabled = true
					g.emission = Color(0.34, 0.38, 0.48)
					g.rim_enabled = true
					g.rim = 1.0
					g.rim_tint = 0.2
					g.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
					mi.set_surface_override_material(k, g)
					_voiles.append(g)
		_spectre(e)


# ---------------------------------------------------------------- l'animation

## Où je me tiens (local au décor), à plat : la caméra du joueur.
func _moi() -> Vector3:
	if not is_inside_tree():
		return Vector3(0, 0, 3)
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3(0, 0, 3)
	var p := to_local(cam.global_position)
	p.y = 0.0
	return p


func animer(vue: Dictionary, _phase: float, delta: float) -> void:
	_t += delta
	var cim: Dictionary = vue.get("cim", {})
	var etat := str(cim.get("phase", ""))
	var aveugle: bool = cim.get("aveugle", false)
	var moi := _moi()
	# Les lieux de la manche s'éclairent, doucement ; les autres s'éteignent.
	var liste: Array = cim.get("lieux", [])
	_actifs.clear()
	for x in liste:
		_actifs.append(int(x))
	for k in _lieux_vus.size():
		var cible := 1.0 if _actifs.has(k) else 0.0
		_eclat[k] = move_toward(_eclat[k], cible, delta * 1.5)
		var e: float = _eclat[k]
		(_lieux_vus[k][0] as Label3D).modulate = Color(0.5, 0.46, 0.42).lerp(Color(1.0, 0.95, 0.85), e)
		(_lieux_vus[k][1] as OmniLight3D).light_energy = 2.4 * e
		(_lieux_vus[k][3] as StandardMaterial3D).albedo_color.a = 0.34 * e * (0.85 + 0.15 * sin(_t * 2.0 + k))
		(_lieux_vus[k][2] as Node3D).visible = e > 0.01
	# Les Dames : l'hôte les fait glisser, nous les suivons.
	var dames: Array = cim.get("dames", [])
	_deux = dames.size() > 1
	var pris: String = str(cim.get("pris", ""))
	for k in _dames.size():
		var d := _dames[k]
		var existe := k < dames.size() or (k == 0 and cim.is_empty())
		d.visible = existe and (not aveugle or etat != "actif")
		if not existe:
			continue
		var cible := Vector3.ZERO
		if k < dames.size():
			cible = Vector3(float(dames[k][0]), 0, float(dames[k][1]))
		if etat == "bilan" and pris == "dame" and k == 0:
			# Elle est venue jusqu'à moi.
			var v := cible - moi
			cible = moi + (v.normalized() * 1.3 if v.length() > 0.01 else Vector3(0, 0, 1.3))
		var f := d.get_meta("femme") as Bouille
		if not d.has_meta("spectre") and f.is_inside_tree() and f.get_child_count() > 0:
			d.set_meta("spectre", true)
			_spectre(f)
		var vitesse := 6.0 if etat == "bilan" and pris == "dame" else 4.0
		var p := d.position.lerp(cible, minf(1.0, delta * vitesse))
		# Juste au-dessus de l'herbe : plus haut, le personnage se croirait en plein saut.
		p.y = 0.09 + 0.05 * sin(_t * 1.7 + k * 2.0)
		d.position = p
		# Elle se tourne vers moi (+Z du personnage), et ses yeux me suivent.
		var vers := moi - Vector3(d.position.x, 0, d.position.z)
		if vers.length() > 0.05:
			d.basis = d.basis.orthonormalized().slerp(Basis.looking_at(-vers, Vector3.UP), minf(1.0, delta * 1.5))
		if f.is_inside_tree():
			f.regarder(to_global(moi + Vector3(0, 1.55, 0)))
		(d.get_meta("halo") as OmniLight3D).light_energy = 0.7 + 0.25 * sin(_t * 3.1 + k)
	var a := 0.5 + 0.12 * sin(_t * 2.3)
	for m in _voiles:
		m.albedo_color.a = a
	# Là où la Dame attrape : un disque rouge, le temps du bilan.
	_disque.visible = etat == "bilan" and not dames.is_empty()
	if _disque.visible:
		_disque.position = Vector3(float(dames[0][0]), 0.06, float(dames[0][1]))
		_disque.scale = Vector3.ONE * (float(cim.get("rayon", 2.5)) / 2.5)
		_disque_mat.albedo_color.a = 0.22 + 0.08 * sin(_t * 4.0)
	# L'écran des fuyards : presque noir pendant la manche, la lumière revient au bilan.
	var cible_noir := NOIR_MAX if bool(cim.get("noir", false)) else 0.0
	_a_noir = move_toward(_a_noir, cible_noir, delta * (1.6 if cible_noir > 0.0 else 3.0))
	_voile_noir.color.a = _a_noir
	if etat != _etat_avant:
		if etat == "bilan" and pris != "" and aveugle:
			_flash = 0.55
			_cri()
		_etat_avant = etat
		for mu in _musiques:
			if etat != "actif":
				mu.stop()
	_flash = maxf(_flash - delta * 0.5, 0.0)
	_voile_rouge.color.a = _flash
	_sons(etat, delta)


## Murmures graves (notes étouffées, plus de bruit blanc) et boîte à musique, de la Dame vers le joueur (spatialisés) : seuls les fuyards,
## dans le noir, en ont vraiment besoin ; le guide les entend aussi.
func _sons(etat: String, delta: float) -> void:
	if etat != "actif":
		return
	var nb := 2 if _deux else 1
	_son_t -= delta
	if _son_t <= 0.0:
		_son_t = _rng.randf_range(1.8, 3.2)
		for k in nb:
			var mu := _murmures[k]
			if mu.playing:
				continue
			mu.stream = Sons.murmure(_rng.randi_range(0, 3))
			mu.pitch_scale = _rng.randf_range(0.85, 1.1) * (1.0 if k == 0 else 0.8)
			mu.play()
	for k in nb:
		var mu2 := _musiques[k]
		if not mu2.playing:
			mu2.stream = Sons.comptine()
			mu2.pitch_scale = 1.0 if k == 0 else 0.84
			mu2.play()


var _deux := false


func _cri() -> void:
	var a := AudioStreamPlayer.new()
	a.stream = Sons.cri()
	a.bus = "Effets"
	a.volume_db = -4.0
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)
