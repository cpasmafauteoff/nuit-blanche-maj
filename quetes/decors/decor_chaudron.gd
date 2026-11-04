extends DecorQuete
## Le Chaudron, joué pour de vrai (01/11). Au centre, un foyer de pierres, un grand trépied de
## perches et une marmite de fonte pendue à sa chaîne : la mixture change de couleur à chaque
## ingrédient juste, bouillonne, fume, noircit et crache quand on se trompe. D'un côté, l'ÉTAGÈRE
## aux pots, du côté opposé à l'entrée : chaque pot a son étiquette, MES pots ont l'étiquette dorée.
## Sur le cercle, un PUPITRE avec un vrai grimoire : le lecteur le feuillette (clic à droite / à
## gauche, ou la molette), les autres le voient fermé et scellé.
##
## Mes mains : je vise un de mes pots et je clique (ou E) pour le prendre ; il apparaît dans ma main.
## Je marche jusqu'au chaudron, je tiens le clic gauche et je bascule la souris vers le bas : le pot
## se penche, le filet coule dans la marmite. Pour reposer un pot : E (ou un clic bref) face à
## l'étagère. Le saboteur, sans pot en main, fait le même geste avec son sachet noir.
## L'hôte décide de tout : il lit mes pieds (portée de l'étagère, du chaudron).

const TEINTE_BASE := Color(0.18, 0.5, 0.3)
const NOIR := Color(0.025, 0.025, 0.03)
const OR := Color(1.0, 0.8, 0.3)
const PORTEE_VISEE := 3.3
const PX_BASCULE := 150.0         # glisser de tant de pixels vers le bas = pot renversé à fond
const MAX_BASCULE := 2.0          # rad
const SEUIL_VERSE := 1.15         # rad : au-delà, ça coule
const CRAN_MARMITE := Vector3(0, 0.98, 0)
const RAYON_MARMITE := 0.82
const ETAGES: Array[float] = [0.42, 1.0, 1.58]
const ECH_POT := 1.3              # les pots, un peu plus grands que nature : on les voit et on les vise

## Les modèles de pots : [modèle ou "", échelle, hauteur du goulot].
const POTS := [["ceramic_pot", 0.38, 0.145], ["jug_01", 0.9, 0.19], ["ceramic_vase_01", 0.5, 0.2],
	["wooden_bucket_01", 0.5, 0.175], ["", 1.0, 0.16], ["", 1.0, 0.17], ["wicker_basket_01", 0.55, 0.065],
	["wooden_bowl_01", 0.6, 0.056]]

var _marmite: Node3D
var _mat_bouillon: StandardMaterial3D
var _crachat: GPUParticles3D
var _eclat: GPUParticles3D
var _bulles: GPUParticles3D
var _vapeur: GPUParticles3D
var _lumiere_mix: OmniLight3D
var _etagere: Node3D
var _pots := {}                   # ing -> {"racine": Node3D, "etiquette": Label3D, "corps": StaticBody3D, "mien": bool}
var _pots_faits := false
var _pupitre: Node3D
var _grimoire: Grimoire3D
var _indice: IndiceQuete
var _main: ObjetMain
var _main_ing := -1
var _main_sachet := false
var _vue := {}
var _monde: MondeQuete
var _clic_avant := false
var _agir_avant := false
var _basc_actif := false
var _basc_px := 0.0
var _basc_vise_etagere := false
var _verse_t := 0.0
var _verse_envoye := false
var _filet: Node3D
var _ecume: MeshInstance3D
const FILET_SEG := 10             # le filet est une courbe de tant de segments
var _verses_vus := 0
var _gachis_vus := 0
var _couleur := TEINTE_BASE
var _couleur_but := TEINTE_BASE
var _noir_t := 0.0
var _flash := 0.0
var _termine := false
var _visee_pot := -1
var _visee_etagere := false
var _visee_livre := 0
var _t := 0.0
var _bulle_t := 1.0
var _son_ebull: AudioStreamPlayer3D
var _refus_t := 0.0


func construire() -> void:
	meuble = ""
	_foyer()
	_trepied_et_marmite()
	_etagere_construire()
	_pupitre_construire()
	_alentours()
	_indice = IndiceQuete.new()
	add_child(_indice)
	_son_ebull = AudioStreamPlayer3D.new()
	_son_ebull.stream = SonsQuete.ebullition()
	_son_ebull.volume_db = -13.0
	_son_ebull.unit_size = 7.0
	_son_ebull.bus = "Effets"
	_son_ebull.position = Vector3(0, 1.0, 0)
	add_child(_son_ebull)
	_son_ebull.play()


# ---------------------------------------------------------------- la clairière du chaudron

func libre(p: Vector3) -> bool:
	var h := Vector2(p.x, p.z)
	if h.length() < 2.3:
		return false
	var e := LieuxChaudron.etagere(zone, equipe)
	if h.distance_to(Vector2(e.x, e.z)) < 2.8:
		return false
	var l := LieuxChaudron.pupitre(zone, equipe)
	return h.distance_to(Vector2(l.x, l.z)) >= 1.5


func _foyer() -> void:
	# Un cercle de pierre et de terre brûlée, un foyer, des branches, un vrai feu.
	var cendre := _cylindre(2.0, 0.04, matiere("boue", 2.0, Color(0.32, 0.27, 0.22)))
	cendre.position.y = 0.02
	add_child(cendre)
	modele("stone_fire_pit", Vector3(0, 0.23, 0), 1.4)
	modele("dry_branches_medium_01", Vector3(0, 0.05, 0), 0.55, 0.6)
	feu(Vector3(0, 0.15, 0), 1.25)


func _trepied_et_marmite() -> void:
	# Le trépied : trois grosses perches plantées autour du foyer, liées au sommet.
	var sommet := Vector3(0, 3.0, 0)
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		poutre(Vector3(sin(a), 0, cos(a)) * 1.75 + Vector3(0, -0.1, 0), sommet + Vector3(sin(a), 0, cos(a)) * 0.1, 0.075)
	corde(sommet + Vector3(0, 0.02, 0.1), sommet + Vector3(0.1, -0.1, -0.05), 0.04, 0.03)
	var fer_c := matiere("metal", 3.0, Color(0.3, 0.29, 0.28))
	# La marmite, pendue à sa chaîne : un ventre de fonte, un lourd bourrelet, deux anses.
	_marmite = Node3D.new()
	_marmite.position = CRAN_MARMITE
	add_child(_marmite)
	var fonte := matiere("metal", 1.5, Color(0.2, 0.19, 0.19))
	fonte.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ventre := _cylindre(RAYON_MARMITE, 0.62, fonte, RAYON_MARMITE * 0.98)
	(ventre.mesh as CylinderMesh).cap_top = false
	_marmite.add_child(ventre)
	var fond := _sphere(RAYON_MARMITE * 0.86, fonte)
	fond.scale = Vector3(1, 0.5, 1)
	fond.position.y = -0.31
	_marmite.add_child(fond)
	var levre := anneau(RAYON_MARMITE, 0.05, fonte, _marmite)
	levre.position.y = 0.31
	for cote: float in [-1.0, 1.0]:
		var oreille := anneau(0.09, 0.016, fonte, _marmite)
		oreille.rotation.x = PI / 2
		oreille.position = Vector3(cote * (RAYON_MARMITE + 0.05), 0.22, 0)
		oreille.rotation.z = PI / 2
	var anse := anneau(RAYON_MARMITE, 0.016, fonte, _marmite)
	anse.rotation.z = PI / 2
	anse.position.y = 0.31
	corde(sommet, _marmite.position + Vector3(0, 1.1, 0), 0.0, 0.02, self, fer_c)
	_mat_bouillon = StandardMaterial3D.new()
	_mat_bouillon.albedo_color = TEINTE_BASE
	_mat_bouillon.emission_enabled = true
	_mat_bouillon.emission = TEINTE_BASE * 0.8
	_mat_bouillon.roughness = 0.12
	var bouillon := _cylindre(RAYON_MARMITE * 0.96, 0.02, _mat_bouillon)
	bouillon.position.y = 0.22
	_marmite.add_child(bouillon)
	_bulles = _particules(46, 0.8, Vector3(0.52, 0.01, 0.52), Vector3(0, 0.14, 0), 0.09,
		_degrade([Color(0.7, 1.0, 0.6, 0.0), Color(0.7, 1.0, 0.6, 0.9), Color(0.7, 1.0, 0.6, 0.0)]), true)
	_bulles.position.y = 0.24
	_marmite.add_child(_bulles)
	_vapeur = _particules(22, 3.4, Vector3(0.45, 0.02, 0.45), Vector3(0, 0.5, 0), 0.95,
		_degrade([Color(0.7, 0.85, 0.7, 0.0), Color(0.65, 0.8, 0.65, 0.28), Color(0.7, 0.75, 0.7, 0.0)]), false)
	_vapeur.position.y = 0.32
	_marmite.add_child(_vapeur)
	_crachat = _particules(60, 1.4, Vector3(0.45, 0.05, 0.45), Vector3(0, 2.1, 0), 0.9,
		_degrade([Color(0.8, 0.1, 0.05, 0.0), Color(0.7, 0.08, 0.05, 0.8), Color(0.3, 0.05, 0.05, 0.0)]), false)
	_crachat.position.y = 0.3
	_crachat.one_shot = true
	_crachat.preprocess = 0.0
	_crachat.emitting = false
	_marmite.add_child(_crachat)
	_eclat = _particules(50, 1.0, Vector3(0.3, 0.02, 0.3), Vector3(0, 1.6, 0), 0.07,
		_degrade([Color(1.0, 0.95, 0.7, 0.0), Color(1.0, 0.95, 0.75, 1.0), Color(1.0, 0.9, 0.6, 0.0)]), true)
	_eclat.position.y = 0.3
	_eclat.one_shot = true
	_eclat.preprocess = 0.0
	_eclat.emitting = false
	_marmite.add_child(_eclat)
	_lumiere_mix = _lumiere(TEINTE_BASE, 1.1, 7.0, Vector3(0, 1.55, 0))
	add_child(_lumiere_mix)
	# Le filet de liquide qui coule du pot (visible seulement quand je verse).
	_filet = Node3D.new()
	_filet.visible = false
	add_child(_filet)
	for i in FILET_SEG:
		var seg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.012
		cm.bottom_radius = 0.012
		cm.height = 1.0
		cm.radial_segments = 8
		seg.mesh = cm
		var mf := StandardMaterial3D.new()
		mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mf.albedo_color = Color(0.7, 0.9, 0.6, 0.85)
		mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		seg.material_override = mf
		_filet.add_child(seg)
	# L'éclaboussure où le filet touche la mixture : un petit anneau d'écume.
	_ecume = anneau(0.07, 0.012, _mat_ecume(), self)
	_ecume.visible = false


# ---------------------------------------------------------------- l'étagère et ses pots

func _etagere_construire() -> void:
	var pos := LieuxChaudron.etagere(zone, equipe)
	_etagere = Node3D.new()
	_etagere.position = pos
	# Le devant (+Z) regarde le chaudron.
	_etagere.basis = Basis.looking_at(Vector3(pos.x, 0, pos.z).normalized(), Vector3.UP)
	add_child(_etagere)
	set_meta("liste_pos", pos)
	var bois := matiere("vieux_bois", 1.4)
	var bois_clair := matiere("bois", 1.5, Color(0.7, 0.55, 0.4))
	for x: float in [-1.58, 1.58]:
		var montant := _boite(Vector3(0.12, 2.15, 0.55), bois)
		montant.position = Vector3(x, 1.075, 0)
		_etagere.add_child(montant)
	var dos := _boite(Vector3(3.2, 2.1, 0.05), bois)
	dos.position = Vector3(0, 1.05, -0.26)
	_etagere.add_child(dos)
	var toit := _boite(Vector3(3.5, 0.08, 0.7), bois_clair)
	toit.position = Vector3(0, 2.17, 0.02)
	_etagere.add_child(toit)
	for y in ETAGES:
		var planche := _boite(Vector3(3.2, 0.1, 0.55), bois_clair)
		planche.position = Vector3(0, y, 0)
		_etagere.add_child(planche)
	var pied := _boite(Vector3(3.3, 0.14, 0.62), bois)
	pied.position = Vector3(0, 0.07, 0)
	_etagere.add_child(pied)
	# Une enseigne au-dessus : « Les pots du jour ».
	var plaque := _debout("La réserve", 46, Vector3(0, 2.38, 0.06))
	plaque.width = 600.0
	_etagere.add_child(plaque)
	# Pour reposer un pot : toute l'étagère se vise.
	var corps := StaticBody3D.new()
	corps.collision_layer = COUCHE_BOUTONS
	corps.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(3.3, 2.2, 0.1)
	cs.shape = bx
	corps.add_child(cs)
	corps.position = Vector3(0, 1.1, -0.26)     # le fond seulement : les pots, devant, se visent avant lui
	corps.set_meta("etagere", true)
	_etagere.add_child(corps)


## Un pot, pied au sol : modèle, contenu coloré, bouche. Rend le nœud et la hauteur du goulot.
func _pot_construire(ing: int, parent: Node3D) -> Node3D:
	var type: Array = POTS[ing % POTS.size()]
	var n := Node3D.new()
	n.scale = Vector3.ONE * ECH_POT
	parent.add_child(n)
	var col := LieuxChaudron.couleur_ingredient(ing)
	var haut: float = type[2]
	if str(type[0]) != "":
		modele(str(type[0]), Vector3.ZERO, float(type[1]), ing * 0.7, n)
		var dedans := _sphere(0.055, matiere("ing", 1.0, col, col * 0.25))
		dedans.scale = Vector3(1, 0.55, 1)
		dedans.position.y = haut - 0.015
		n.add_child(dedans)
	elif ing % POTS.size() == 4:
		# Un sachet de toile noué au cou.
		var toile := matiere("enduit", 3.0, col.lerp(Color(0.8, 0.72, 0.55), 0.55))
		var ventre := _sphere(0.085, toile)
		ventre.scale = Vector3(1, 0.95, 1)
		ventre.position.y = 0.085
		n.add_child(ventre)
		var cou := _cylindre(0.03, 0.06, toile, 0.045)
		cou.position.y = 0.16
		n.add_child(cou)
		var lien := anneau(0.034, 0.006, matiere("bois", 4.0, Color(0.4, 0.28, 0.18)), n)
		lien.position.y = 0.145
	else:
		# Un bocal de verre, un bouchon de liège.
		var verre := StandardMaterial3D.new()
		verre.albedo_color = Color(0.7, 0.85, 0.8, 0.35)
		verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		verre.roughness = 0.1
		var corps := _cylindre(0.065, 0.16, verre)
		corps.position.y = 0.08
		n.add_child(corps)
		var matiere_b := _cylindre(0.058, 0.12, matiere("ing", 1.0, col, col * 0.2))
		matiere_b.position.y = 0.065
		n.add_child(matiere_b)
		var bouchon := _cylindre(0.042, 0.035, matiere("vieux_bois", 3.0, Color(0.6, 0.45, 0.3)))
		bouchon.position.y = 0.175
		n.add_child(bouchon)
	n.set_meta("bouche", Vector3(0, haut, 0))
	return n


## La fiole qu'on tient en main (le pot de l'étagère reste sur l'étagère) : ventre de verre rempli de
## la couleur de l'ingrédient, col étroit, bouchon de liège. Rend le nœud et sa bouche (au bord du col).
func _fiole_construire(ing: int, parent: Node3D) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var col := LieuxChaudron.couleur_ingredient(ing)
	var verre := StandardMaterial3D.new()
	verre.albedo_color = Color(0.75, 0.88, 0.85, 0.32)
	verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	verre.roughness = 0.08
	verre.metallic_specular = 1.0
	var ventre := _sphere(0.075, verre)
	ventre.position.y = 0.075
	n.add_child(ventre)
	var liquide := _sphere(0.066, matiere("ing", 1.0, col, col * 0.3))
	liquide.scale = Vector3(1, 0.78, 1)
	liquide.position.y = 0.068
	n.add_child(liquide)
	var col_v := _cylindre(0.024, 0.1, verre, 0.028)
	col_v.position.y = 0.19
	n.add_child(col_v)
	var levre := anneau(0.03, 0.006, verre, n)
	levre.position.y = 0.24
	var bouchon := _cylindre(0.03, 0.045, matiere("vieux_bois", 3.0, Color(0.6, 0.45, 0.3)), 0.022)
	bouchon.position = Vector3(0.0, 0.26, 0.0)
	bouchon.visible = false          # débouchée : le bouchon est dans l'autre main
	n.add_child(bouchon)
	n.set_meta("bouche", Vector3(0, 0.24, 0))
	return n


func _pots_construire(pots: Array) -> void:
	_pots_faits = true
	# Rangés par ordre alphabétique : tout le monde voit la même étagère.
	var tri := pots.duplicate()
	tri.sort_custom(func(a, b): return str(a[1]) < str(b[1]))
	var mes: Array = _vue.get("mes", [])
	for i in tri.size():
		var ing := int(tri[i][0])
		var c := LieuxChaudron.case_pot(i)
		var x := (c.x - (LieuxChaudron.POTS_PAR_ETAGE - 1) * 0.5) * 0.38
		var y: float = ETAGES[mini(c.y, ETAGES.size() - 1)] + 0.05
		var racine := _pot_construire(ing, _etagere)
		racine.position = Vector3(x, y, 0.03)
		var mien := mes.has(ing)
		var etiquette := Label3D.new()
		etiquette.font = Style.police("italique")
		etiquette.font_size = 28
		etiquette.pixel_size = 0.0017
		etiquette.outline_size = 8
		etiquette.modulate = Color(1.0, 0.86, 0.45) if mien else Color(0.93, 0.9, 0.82)
		etiquette.outline_modulate = Color(0.08, 0.04, 0.02)
		etiquette.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiquette.width = 170.0
		etiquette.text = Langue.t(str(tri[i][1]))
		etiquette.position = Vector3(x, y - 0.1, 0.285)
		_etagere.add_child(etiquette)
		var corps := StaticBody3D.new()
		corps.collision_layer = COUCHE_BOUTONS
		corps.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(0.36, 0.5, 0.44)
		cs.shape = bx
		corps.add_child(cs)
		corps.position = Vector3(x, y + 0.2, 0.03)
		corps.set_meta("pot", ing)
		_etagere.add_child(corps)
		_pots[ing] = {"racine": racine, "etiquette": etiquette, "corps": corps, "mien": mien, "y": y, "x": x}


# ---------------------------------------------------------------- le pupitre et son grimoire

func _pupitre_construire() -> void:
	var pos := LieuxChaudron.pupitre(zone, equipe)
	_pupitre = Node3D.new()
	_pupitre.position = pos
	_pupitre.basis = Basis.looking_at(Vector3(pos.x, 0, pos.z).normalized(), Vector3.UP)
	add_child(_pupitre)
	var bois := matiere("vieux_bois", 1.4)
	var socle := _boite(Vector3(0.7, 0.1, 0.6), bois)
	socle.position.y = 0.05
	_pupitre.add_child(socle)
	var fut := _cylindre(0.09, 0.9, bois)
	fut.position.y = 0.5
	_pupitre.add_child(fut)
	var tablette := _boite(Vector3(0.82, 0.05, 0.6), matiere("bois", 1.5, Color(0.62, 0.48, 0.34)))
	tablette.position = Vector3(0, 1.0, 0)
	tablette.rotation.x = 0.5
	_pupitre.add_child(tablette)
	var butee := _boite(Vector3(0.82, 0.06, 0.04), bois)
	butee.position = Vector3(0, 0.89, 0.25)
	butee.rotation.x = 0.5
	_pupitre.add_child(butee)
	# Le livre : posé à plat sur la tablette inclinée, face au lecteur (+Z).
	var cuir := matiere("bois", 3.0, Color(0.38, 0.14, 0.1))
	var papier := _mat("papier", Color(0.9, 0.84, 0.68))
	_grimoire = Grimoire3D.new()
	_grimoire.position = Vector3(0, 1.05, -0.02)
	_grimoire.rotation.x = 0.5
	_grimoire.scale = Vector3.ONE * 1.4
	_pupitre.add_child(_grimoire)
	_grimoire.construire(COUCHE_BOUTONS, cuir, papier, Style.police("texte"))
	_grimoire.add_to_group("mobile")
	# Une bougie sur le pupitre : on lit à sa lueur.
	bougie(Vector3(0.5, 1.17, -0.2), _pupitre)


func _alentours() -> void:
	# Ce qui traîne : un seau, un panier et une jarre près du feu, des caisses et une échelle.
	accessoire("wooden_bucket_02", Vector3(sin(0.9), 0, cos(0.9)) * 2.3, 0.8, 0.3, 0.5)
	accessoire("wicker_basket_01", Vector3(sin(3.0), 0, cos(3.0)) * 2.4, 1.1, 0.2, 0.5)
	accessoire("ceramic_pot", Vector3(sin(5.0), 0, cos(5.0)) * 2.4, 0.7, 2.0, 0.5)
	var r := rayon(equipe) + 1.9
	var echelle := accessoire("wooden_ladder", entre(0, r), 1.0, 1.2, 0.7)
	if echelle:
		echelle.basis = Basis.looking_at(-echelle.position.normalized(), Vector3.UP)
	var caisse := accessoire("wooden_crate_01", entre(equipe / 2, r), 1.0, 1.1, 0.7)
	if caisse:
		modele("wooden_crate_01", Vector3(0.03, 0.35, -0.02), 0.85, 0.3, caisse)


# ---------------------------------------------------------------- mes mains

func _cle(action: String, defaut: String) -> String:
	var o := get_node_or_null("/root/Options")
	return str(o.texte_touches(action)) if o != null else defaut


func _agir_appuye() -> bool:
	var o := get_node_or_null("/root/Options")
	return o != null and bool(o.appuye("agir"))


func _assurer_main(cam: Camera3D) -> void:
	if _main == null:
		_main = ObjetMain.new()
		cam.add_child(_main)


func _exit_tree() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null


func _pres_du_chaudron(cam: Camera3D) -> bool:
	var p := to_local(cam.global_position)
	return Vector2(p.x, p.z).length() <= LieuxChaudron.RAYON_VERSER + 0.1


func manipuler(monde: MondeQuete, delta: float) -> void:
	_monde = monde
	var cam := monde.camera
	if cam == null or not monde.is_inside_tree() or _vue.is_empty():
		return
	_assurer_main(cam)
	# Ce que je vise : un pot, l'étagère, le grimoire.
	var o := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(o, o - cam.global_basis.z * PORTEE_VISEE, COUCHE_BOUTONS)
	q.collide_with_areas = false
	var touche := monde.get_world_3d().direct_space_state.intersect_ray(q)
	_visee_pot = -1
	_visee_etagere = false
	_visee_livre = 0
	if touche:
		var c: Object = touche["collider"]
		if c.has_meta("pot"):
			_visee_pot = int(c.get_meta("pot"))
			_visee_etagere = true
		elif c.has_meta("etagere"):
			_visee_etagere = true
		elif c.has_meta("grimoire"):
			_visee_livre = int(c.get_meta("cote"))
	var tient := int(_vue.get("main", -1))
	var sachet := bool(_vue.get("sachet", false))
	var proche := _pres_du_chaudron(cam)
	var bas := monde._clic()
	var agir := _agir_appuye()
	var presse := bas and not _clic_avant
	var agir_presse := agir and not _agir_avant
	# Le geste de verser (tenir puis basculer) : commence au clic quand on tient un pot (ou le sachet).
	if presse and not _basc_actif and _visee_livre == 0 and (tient != -1 or (sachet and proche and tient == -1 and _visee_pot < 0)):
		_basc_actif = true
		_basc_px = 0.0
		_basc_vise_etagere = _visee_etagere
		_verse_envoye = false
		_verse_t = 0.0
		if tient == -1:
			_tenir_sachet()
	elif presse and tient == -1:
		if _visee_pot >= 0:
			_essayer_prendre(_visee_pot)
		elif _visee_livre != 0:
			_feuilleter(_visee_livre)
	if agir_presse:
		if tient != -1 and (_visee_etagere or _pres_etagere(cam)):
			_poser()
		elif tient == -1 and _visee_pot >= 0:
			_essayer_prendre(_visee_pot)
		elif tient == -1 and _visee_livre != 0:
			_feuilleter(_visee_livre)
	if not bas and _basc_actif:
		# Un clic bref face à l'étagère, sans avoir basculé : on repose le pot.
		if tient != -1 and _basc_px < 16.0 and _basc_vise_etagere:
			_poser()
		_basc_actif = false
		if tient == -1 and _main_sachet:
			_main.lacher()
			_main_sachet = false
		_verse_envoye = false
	_clic_avant = bas
	_agir_avant = agir
	# L'inclinaison du pot en main.
	var angle := 0.0
	if _basc_actif:
		angle = clampf(_basc_px / PX_BASCULE * MAX_BASCULE, 0.0, MAX_BASCULE)
	_main.incliner(angle)
	var verse := _basc_actif and angle >= SEUIL_VERSE and proche and (tient != -1 or _main_sachet)
	if verse:
		_verse_t += delta
		if _verse_t >= 0.3 and not _verse_envoye:
			_verse_envoye = true
			if tient != -1:
				monde.geste.emit({"verser": tient})
			else:
				monde.geste.emit({"pincee": true})
			SonsQuete.jouer(self, SonsQuete.verse(), global_position + Vector3(0, 1.2, 0), -1.0, 6.0)
	else:
		_verse_t = 0.0
		if angle < 0.6:
			_verse_envoye = false
	_filet_maj(verse and (tient != -1 or _main_sachet), tient)
	_refus_t = maxf(_refus_t - delta, 0.0)
	_ecrire_hint(tient, sachet, proche)


func _pres_etagere(cam: Camera3D) -> bool:
	var e := LieuxChaudron.etagere(zone, equipe)
	var p := to_local(cam.global_position)
	return Vector2(p.x - e.x, p.z - e.z).length() <= LieuxChaudron.RAYON_ETAGERE + 0.3


func _essayer_prendre(ing: int) -> void:
	if not _pots.has(ing):
		return
	var mes: Array = _vue.get("mes", [])
	if mes.has(ing):
		var etat := 0
		for p in _vue.get("pots", []):
			if int(p[0]) == ing:
				etat = int(p[2])
		if etat == 0 and _monde != null:
			_monde.geste.emit({"prendre": ing})
			SonsQuete.jouer(self, SonsQuete.pot(), (_pots[ing]["racine"] as Node3D).global_position, -3.0, 5.0)
	else:
		_refus_t = 2.0
		var r: Node3D = _pots[ing]["racine"]
		secouer(r, 0.03)


func _poser() -> void:
	if _monde != null:
		_monde.geste.emit({"poser": true})
		SonsQuete.jouer(self, SonsQuete.pot(), global_position + Vector3(0, 1.0, 0) + LieuxChaudron.etagere(zone, equipe), -4.0, 5.0)


func _feuilleter(cote: int) -> void:
	if _grimoire != null and bool(_vue.get("lecteur", false)) and _grimoire.feuilleter(cote):
		SonsQuete.jouer(self, SonsQuete.page(), _grimoire.global_position, -3.0, 4.0)


func absorbe_souris(rel: Vector2) -> bool:
	if _basc_actif:
		_basc_px = clampf(_basc_px + rel.y, -30.0, PX_BASCULE * 1.25)
		return true
	return false


func molette(sens: int) -> bool:
	if _visee_livre != 0 and bool(_vue.get("lecteur", false)):
		_feuilleter(-sens)
		return true
	return false


func _tenir_sachet() -> void:
	if _main == null:
		return
	var n := Node3D.new()
	var toile := matiere("enduit", 3.0, Color(0.1, 0.09, 0.1))
	var ventre := _sphere(0.075, toile)
	ventre.scale = Vector3(1, 0.95, 1)
	ventre.position.y = 0.075
	n.add_child(ventre)
	var cou := _cylindre(0.028, 0.06, toile, 0.04)
	cou.position.y = 0.15
	n.add_child(cou)
	n.position.y = -0.075      # tenu par le ventre, comme un pot
	var w := Node3D.new()
	w.add_child(n)
	_main.tenir(w, Vector3(0, 0.075, 0))
	_main_sachet = true


func _mat_ecume() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.5)
	return m


## Le filet qui coule : de la bouche du pot (ou du sachet) à la surface de la mixture.
func _filet_maj(coule: bool, ing: int) -> void:
	if not coule or _main == null or not _main.tient():
		_filet.visible = false
		_ecume.visible = false
		return
	var a := _main.bouche()
	var b := to_global(Vector3(0, CRAN_MARMITE.y + 0.22, 0))
	b.x = lerpf(a.x, b.x, 0.95)
	b.z = lerpf(a.z, b.z, 0.95)
	b.y = minf(b.y, a.y - 0.1)         # un liquide tombe : jamais de filet qui remonte vers la marmite
	var d := b - a
	var longueur := d.length()
	if longueur < 0.05:
		_filet.visible = false
		_ecume.visible = false
		return
	var col := Color(0.15, 0.15, 0.17) if ing < 0 else LieuxChaudron.couleur_ingredient(ing).lightened(0.2)
	col.a = 0.85
	# Le liquide quitte la lèvre en filant vers la marmite, puis tombe : la hauteur suit t au carré.
	var pts: Array[Vector3] = []
	for i in FILET_SEG + 1:
		var t := float(i) / FILET_SEG
		pts.append(Vector3(lerpf(a.x, b.x, t), lerpf(a.y, b.y, t * t), lerpf(a.z, b.z, t)))
	for i in FILET_SEG:
		var seg := _filet.get_child(i) as MeshInstance3D
		var l := pts[i].distance_to(pts[i + 1])
		var dir := (pts[i + 1] - pts[i]) / maxf(l, 0.0001)
		var xx := dir.cross(Vector3.RIGHT if absf(dir.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
		var zz := xx.cross(dir)
		var epais := lerpf(1.0, 0.6, float(i) / FILET_SEG)
		seg.global_transform = Transform3D(Basis(xx * epais, dir * (l + 0.004), zz * epais), (pts[i] + pts[i + 1]) * 0.5)
		(seg.material_override as StandardMaterial3D).albedo_color = col
	_ecume.global_position = b
	_ecume.scale = Vector3.ONE * (1.0 + 0.25 * sin(_t * 18.0))
	(_ecume.material_override as StandardMaterial3D).albedo_color = Color(col.r, col.g, col.b, 0.5).lightened(0.3)
	_ecume.visible = true
	_filet.visible = true


## Ce que ma main peut faire, en toutes lettres.
func _ecrire_hint(tient: int, sachet: bool, proche: bool) -> void:
	var agir := _cle("agir", "E")
	if tient != -1:
		if proche:
			_indice.ecrire("Clic gauche tenu, puis bascule la souris vers le bas : verser (%s : reposer le pot)", [agir])
		else:
			_indice.ecrire("Marche jusqu'au chaudron avec ton pot (%s ou un clic face à l'étagère : le reposer)", [agir])
	elif _visee_pot >= 0:
		var nom_pot := ""
		for p in _vue.get("pots", []):
			if int(p[0]) == _visee_pot:
				nom_pot = Langue.t(str(p[1]))
		if (_vue.get("mes", []) as Array).has(_visee_pot):
			_indice.ecrire("Clic ou %s : prendre ce pot (%s)", [agir, nom_pot])
		else:
			_indice.ecrire("Ce pot n'est pas à toi : un autre joueur le tient.")
	elif _visee_livre != 0:
		_indice.ecrire("Clic à droite ou à gauche (ou la molette) : tourner la page" if bool(_vue.get("lecteur", false)) else "Ce grimoire est scellé : seul le lecteur peut le lire.")
	elif sachet and proche:
		_indice.ecrire("Sachet noir : clic gauche tenu, puis bascule la souris vers le bas (sans pot en main) : glisser une pincée")
	elif not (_vue.get("mes", []) as Array).is_empty():
		_indice.ecrire("Prends tes pots sur l'étagère, au fond (clic ou %s), et verse-les dans le chaudron au bon moment", [agir])
	else:
		_indice.ecrire("")


# ---------------------------------------------------------------- la vue de l'hôte

func animer(vue: Dictionary, _phase: float, delta: float) -> void:
	_t += delta
	_vue = vue
	if not _pots_faits and not (vue.get("pots", []) as Array).is_empty():
		_pots_construire(vue.get("pots", []))
	_maj_pots(vue)
	_maj_main(vue)
	_maj_grimoire(vue)
	_maj_mixture(vue, delta)
	_maj_sons(delta)


func _maj_pots(vue: Dictionary) -> void:
	for p in vue.get("pots", []):
		var ing := int(p[0])
		if _pots.has(ing):
			(_pots[ing]["racine"] as Node3D).visible = int(p[2]) == 0


func _maj_main(vue: Dictionary) -> void:
	if _main == null:
		return
	var tient := int(vue.get("main", -1))
	if tient != _main_ing:
		_main_ing = tient
		if tient == -1:
			if not _main_sachet:
				_main.lacher()
		else:
			_main_sachet = false
			# Le pot est tenu par le milieu du ventre : il pivote autour de la main, pas autour de son pied.
			var racine := Node3D.new()
			var pot := _fiole_construire(tient, racine)
			var bouche_pot := (pot.get_meta("bouche", Vector3.ZERO) as Vector3)
			pot.position = Vector3(0, -bouche_pot.y * 0.5, 0)
			racine.scale = Vector3.ONE * 0.85
			_main.tenir(racine, Vector3(0, bouche_pot.y * 0.5, 0))
			# Une étiquette qui pend au goulot : on sait ce qu'on tient.
			var nom_pot := ""
			for p in vue.get("pots", []):
				if int(p[0]) == tient:
					nom_pot = Langue.t(str(p[1]))
			var tag := Label3D.new()
			tag.font = Style.police("italique")
			tag.font_size = 24
			tag.pixel_size = 0.0007
			tag.outline_size = 6
			tag.modulate = Color(1.0, 0.86, 0.45, 0.8)
			tag.outline_modulate = Color(0.08, 0.04, 0.02)
			tag.text = nom_pot
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tag.position = Vector3(0, -bouche_pot.y * 0.5 - 0.05, 0.02)
			racine.add_child(tag)


func _maj_grimoire(vue: Dictionary) -> void:
	if _grimoire == null:
		return
	var g: Dictionary = vue.get("grimoire", {})
	_grimoire.regler(g.get("lignes", []), int(g.get("etape", 0)), bool(vue.get("lecteur", false)) and not g.is_empty())


func _maj_mixture(vue: Dictionary, delta: float) -> void:
	var verses := int(vue.get("verses", 0))
	var gachis := int(vue.get("gachis", 0))
	var etape := int(vue.get("etape", 0))
	var total := int(vue.get("total", 1))
	if verses != _verses_vus:
		if verses > _verses_vus:
			var col := LieuxChaudron.couleur_ingredient(int(vue.get("dernier", 0)))
			_couleur_but = _couleur_but.lerp(col, 0.5)
			_flash = 1.0
			_eclat.restart()
			_eclat.emitting = true
			SonsQuete.jouer(self, SonsQuete.juste(), to_global(Vector3(0, 1.3, 0)), -2.0, 8.0)
		_verses_vus = verses
	if gachis != _gachis_vus:
		if gachis > _gachis_vus:
			_couleur_but = NOIR
			_noir_t = 2.6
			_crachat.restart()
			_crachat.emitting = true
			secouer(_marmite, 0.05)
			SonsQuete.jouer(self, SonsQuete.gachis(), to_global(Vector3(0, 1.3, 0)), 0.0, 8.0)
		_gachis_vus = gachis
	if _noir_t > 0.0:
		_noir_t -= delta
		if _noir_t <= 0.0:
			_couleur_but = TEINTE_BASE
	_termine = etape >= total and total > 1
	if _termine:
		_couleur_but = OR
	_couleur = _couleur.lerp(_couleur_but, minf(1.0, delta * 2.5))
	_flash = maxf(_flash - delta * 1.5, 0.0)
	_mat_bouillon.albedo_color = _couleur
	_mat_bouillon.emission = _couleur * (0.7 + 0.9 * _flash)
	_lumiere_mix.light_color = _couleur.lightened(0.2)
	_lumiere_mix.light_energy = 1.0 + 1.2 * _flash + (1.6 if _termine else 0.0)
	# Plus on avance dans la recette, plus ça bouillonne et plus ça fume.
	var avance := float(etape) / maxf(total, 1)
	_bulles.speed_scale = 0.8 + 1.4 * avance + 1.5 * _flash
	_vapeur.speed_scale = 0.8 + avance
	# La marmite se balance doucement à sa chaîne.
	_marmite.rotation.z = 0.015 * sin(_t * 0.9)
	_marmite.rotation.x = 0.012 * sin(_t * 0.7)


func _maj_sons(delta: float) -> void:
	_bulle_t -= delta
	if _bulle_t <= 0.0:
		var avance := float(int(_vue.get("etape", 0))) / maxf(float(int(_vue.get("total", 1))), 1.0)
		_bulle_t = randf_range(0.35, 1.2) / (0.7 + avance)
		SonsQuete.jouer(self, SonsQuete.bulle(), to_global(Vector3(randf_range(-0.4, 0.4), 1.3, randf_range(-0.4, 0.4))), -16.0, 4.0)
