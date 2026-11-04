extends DecorQuete
## Le Grand Coffre : un vrai grand coffre cerclé de fer, sur une dalle de pavés au milieu de la
## clairière, bougies et braise autour. Devant CHAQUE joueur, un pilier de fer le relie au coffre par
## une chaîne, et au pilier pend SON cadenas à molettes (Cadenas3D). Je vise une molette et je la
## tourne (molette de la souris, ou clic tenu + glisser vers le haut / le bas), puis je saisis
## l'anse (clic tenu) et je la tire vers le haut. Mauvais code : elle résiste en cliquetant. Bon
## code : elle bascule, la ferrure tombe. Quand assez de serrures sont ouvertes, le couvercle se
## soulève sur un éclat d'or.
## Les cadenas se bâtissent à la première vue (c'est l'hôte qui décide du nombre de molettes).

const ECHELLE_COFFRE := 2.2
const SOL := 0.08                  # l'épaisseur de la dalle de pavés (on marche dessus sans buter)
const PORTEE_CADENAS := 2.6
const PX_PAR_CRAN := 30.0          # glisser de tant de pixels = un cran
const PX_POUR_TIRER := 130.0       # tirer l'anse de tant de pixels vers le haut = elle est tirée
const HAUT_COFFRE := 1.04          # dessus du corps du coffre (sous le couvercle)
const HAUT_CADENAS := 1.1         # le centre du corps du cadenas

var _coffre: Node3D
var _couvercle: Node3D
var _r_pilier := 1.8
var _piliers: Array[Node3D] = []       # un par joueur : le point d'attache de la ferrure
var _ferrures: Array[Node3D] = []      # la ferrure qui porte le cadenas (elle tombe quand il s'ouvre)
var _cadenas: Array[Cadenas3D] = []
var _chaines: Array[Node3D] = []       # les chaînes pilier -> couvercle (elles lâchent quand le coffre s'ouvre)
var _essais_vus: Array = []
var _ouverts_vus: Array = []
var _chiffres_vus: Array = []
var _chute: Array = []                 # depuis quand chaque serrure est ouverte (-1 : fermée)
var _vue := {}
var _glisse := ""                      # "", "molette" ou "anse" : ce que ma main tient
var _glisse_k := -1
var _acc := 0.0
var _clic_avant := false
var _envoye := false
var _visee_k := -1
var _visee_anse := false
var _ouvert_coffre := false
var _or: GPUParticles3D
var _lueur: OmniLight3D
var _hint: IndiceQuete
var _t := 0.0


func construire() -> void:
	meuble = ""
	_r_pilier = maxf(rayon(equipe) - 1.3, 1.6)
	var fer := matiere("metal", 3.0, Color(0.30, 0.29, 0.28))
	var fer_clair := matiere("metal", 3.0, Color(0.42, 0.41, 0.4))
	# La dalle : des pavés, une bordure de pierre, un peu de mousse.
	var dalle := _cylindre(_r_pilier + 0.75, SOL, matiere("pave", 2.5, Color(0.72, 0.72, 0.7)))
	dalle.position.y = SOL * 0.5
	dalle.add_to_group("mobile")      # pas de boîte de collision carrée sur un disque : on marche dessus
	add_child(dalle)
	var bord := _cylindre(_r_pilier + 0.95, SOL * 0.5, matiere("roche", 1.2, Color(0.78, 0.82, 0.74)))
	bord.position.y = SOL * 0.25
	bord.add_to_group("mobile")
	add_child(bord)
	for k in 5:
		morceau("moss_01", k, Vector3(sin(k * 1.9) * (_r_pilier + 0.55), SOL, cos(k * 1.9) * (_r_pilier + 0.55)), 1.6, k)
	# Le coffre, sa ferrure, son couvercle sur charnière.
	_coffre = modele("treasure_chest", Vector3(0, SOL, 0), ECHELLE_COFFRE, 0.0)
	_couvercle = _pivot_couvercle(_coffre)
	_couvercle.add_to_group("mobile")
	_ferrer_coffre(fer, fer_clair)
	# Le trésor : un tas d'or et de pièces, qu'on ne voit qu'à l'ouverture.
	var or_mat := StandardMaterial3D.new()
	or_mat.albedo_color = Color(1.0, 0.78, 0.25)
	or_mat.metallic = 0.85
	or_mat.roughness = 0.3
	or_mat.emission_enabled = true
	or_mat.emission = Color(0.4, 0.26, 0.05)
	var tas := _sphere(0.8, or_mat)
	tas.scale = Vector3(1.05, 0.34, 0.6)
	tas.position = Vector3(0, 0.95, 0)
	add_child(tas)
	var piece_rng := RandomNumberGenerator.new()
	piece_rng.seed = 77
	for i in 26:
		var piece := _cylindre(0.07, 0.015, or_mat)
		piece.position = Vector3(piece_rng.randf_range(-0.85, 0.85), 1.02 + piece_rng.randf_range(0.0, 0.12), piece_rng.randf_range(-0.38, 0.38))
		piece.rotation = Vector3(piece_rng.randf_range(-0.6, 0.6), piece_rng.randf() * TAU, piece_rng.randf_range(-0.6, 0.6))
		add_child(piece)
	# Une lueur d'or dans le coffre : elle ne s'allume qu'à l'ouverture.
	_lueur = _lumiere(Color(1.0, 0.82, 0.4), 0.0, 5.5, Vector3(0, 1.1, 0))
	add_child(_lueur)
	_or = _particules(50, 2.2, Vector3(0.75, 0.04, 0.4), Vector3(0, 1.1, 0), 0.07,
		_degrade([Color(1.0, 0.9, 0.5, 0.0), Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.7, 0.2, 0.0)]), true)
	_or.preprocess = 0.0
	_or.emitting = false
	_or.position = Vector3(0, 1.05, 0)
	add_child(_or)
	# Un pilier de fer devant chaque joueur, relié au coffre par une chaîne.
	for k in equipe:
		_piliers.append(_pilier(k, fer, fer_clair))
		_ferrures.append(null)
	# Des bougies entre les joueurs, et un éclairage chaud au-dessus du coffre.
	for k in equipe:
		bougie(entre(k, _r_pilier + 0.15) + Vector3(0, SOL, 0))
	var haut := _lumiere(Color(1.0, 0.78, 0.5), 1.1, 7.5, Vector3(0, 3.2, 0))
	add_child(haut)
	_feux.append([haut, 1.1, 3.0])
	# Ce qui traîne autour de la dalle.
	var caisse := accessoire("wooden_crate_01", Vector3(0, 0, _r_pilier + 1.9) * 1.0, 1.0, 0.4, 1.4)
	if caisse:
		modele("Lantern_01", Vector3(0, 0.35, 0), 1.2, 0.0, caisse)
	accessoire("wooden_crate_01", Vector3(-_r_pilier - 1.7, 0, -0.4), 0.9, 0.5, 1.2)
	accessoire("wooden_bucket_01", Vector3(_r_pilier + 1.8, 0, 0.5), 0.9, 0.0, 1.2)
	_batir_indice()


## Les bandes de fer qui cerclent le grand coffre (corps et couvercle), les rivets, les coins.
func _ferrer_coffre(fer: Material, fer_clair: Material) -> void:
	var s := ECHELLE_COFFRE
	var corps_h := 0.9
	for x: float in [-0.66, 0.66]:
		var bande := _boite(Vector3(0.15, corps_h + 0.04, 1.17), fer)
		bande.position = Vector3(x, SOL + corps_h * 0.5 - 0.02, 0)
		add_child(bande)
		for z: float in [-0.59, 0.59]:
			for y: float in [0.3, 0.62, 0.92]:
				var rivet := _sphere(0.03, fer_clair)
				rivet.position = Vector3(x, SOL + y - 0.1, z)
				add_child(rivet)
	for y: float in [0.2, 0.96]:
		var ceinture := _boite(Vector3(2.16, 0.09, 1.18), fer)
		ceinture.position = Vector3(0, SOL + y - 0.02, 0)
		add_child(ceinture)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var coin := _boite(Vector3(0.14, corps_h + 0.1, 0.14), fer_clair)
			coin.position = Vector3(sx * 1.04, SOL + corps_h * 0.5 - 0.02, sz * 0.56)
			add_child(coin)
	# Les bandes du couvercle (dans le repère du couvercle, avant l'échelle du modèle).
	var lid := _coffre.find_child("treasure_chest_lid", true, false) as Node3D
	if lid != null:
		for x: float in [-0.3, 0.3]:
			var b2 := _boite(Vector3(0.07, 0.215, 0.54), fer)
			b2.position = Vector3(x, 0.098, 0.262)
			lid.add_child(b2)
		var anneau_c := _boite(Vector3(0.12, 0.08, 0.02), fer_clair)
		anneau_c.position = Vector3(0, 0.1, 0.53)
		lid.add_child(anneau_c)


## Le pilier du k-ième joueur : un fût de fer à sa droite, une potence qui s'avance au-dessus de son
## cadenas, une chaîne jusqu'au coffre.
func _pilier(k: int, fer: Material, fer_clair: Material) -> Node3D:
	var ici := poste(jeu, k, equipe)
	var vers := Vector3(-ici.x, 0, -ici.z).normalized()
	var h := Node3D.new()
	h.position = Vector3(ici.x, SOL, ici.z) + vers * 1.3
	h.basis = Basis.looking_at(vers, Vector3.UP)
	add_child(h)
	var x := 1.15
	var socle := _boite(Vector3(0.3, 0.14, 0.3), fer_clair)
	socle.position = Vector3(x, 0.07, 0)
	h.add_child(socle)
	var fut := _cylindre(0.065, 1.92, fer)
	fut.position = Vector3(x, 0.98, 0)
	h.add_child(fut)
	for y: float in [0.5, 1.1, 1.75]:
		var collier := _cylindre(0.085, 0.05, fer_clair)
		collier.position = Vector3(x, y, 0)
		h.add_child(collier)
	var bout := _sphere(0.09, fer_clair)
	bout.position = Vector3(x, 1.98, 0)
	h.add_child(bout)
	# La potence : un bras horizontal et une contrefiche, jusqu'au-dessus du cadenas.
	var bras := _boite(Vector3(x + 0.04, 0.07, 0.07), fer)
	bras.position = Vector3(x * 0.5, 1.9, 0)
	h.add_child(bras)
	# La contrefiche : une barre en biais du fût au bras, avec un collier à chaque bout.
	poutre(Vector3(x, 1.28, 0), Vector3(x - 0.62, 1.88, 0), 0.024, fer, h)
	for e: Vector3 in [Vector3(x, 1.28, 0), Vector3(x - 0.62, 1.88, 0)]:
		var rivet_b := _sphere(0.04, fer_clair)
		rivet_b.position = e
		h.add_child(rivet_b)
	var anneau_h := anneau(0.05, 0.012, fer_clair, h)
	anneau_h.position = Vector3(0, 1.9, 0)
	anneau_h.rotation.x = PI / 2
	# La chaîne : du bout du pilier à un point du couvercle, du côté du pilier.
	var cote := Vector3(-vers.x, 0, -vers.z)
	var haut_pilier := h.to_global(Vector3(x, 1.98, 0)) - global_position
	var sur_coffre := Vector3(cote.x * 0.45, 1.5, cote.z * 0.45)
	_chaines.append(corde(haut_pilier, sur_coffre, 0.55, 0.018, self, fer))
	return h


## Le cadenas et sa ferrure, quand l'hôte a dit combien de molettes chacun en a.
func _poser_cadenas(longueurs: Array) -> void:
	var fer := matiere("metal", 3.0, Color(0.30, 0.29, 0.28))
	var rivet := matiere("metal", 3.0, Color(0.55, 0.5, 0.4))
	var laiton_vif := StandardMaterial3D.new()
	laiton_vif.albedo_color = Color(0.66, 0.5, 0.24)
	laiton_vif.metallic = 0.8
	laiton_vif.roughness = 0.42
	laiton_vif.emission_enabled = true
	laiton_vif.emission = Color(0.1, 0.06, 0.02)
	for k in mini(longueurs.size(), _piliers.size()):
		var n := int(longueurs[k])
		var moi := k == rang
		var larg := Cadenas3D.largeur(n)
		# La ferrure : une chaîne pendue au bout de la potence, une barre où passe l'anse.
		var ferrure := Node3D.new()
		ferrure.position = Vector3(0, 1.9, 0)
		_piliers[k].add_child(ferrure)
		var barre_y := HAUT_CADENAS + Cadenas3D.hauteur_barre() - 1.9
		var demi := (larg - 0.17) * 0.5
		for sx: float in [-1.0, 1.0]:
			# Une vraie chaîne : des maillons qui s'enfilent, un sur deux tourné d'un quart de tour.
			var nb_m := int(ceil(-barre_y / 0.055))
			for i in nb_m:
				var maillon := anneau(0.02, 0.0065, fer, ferrure)
				maillon.scale = Vector3(0.7, 1.0, 1.0)
				maillon.position = Vector3(sx * (demi - 0.015), -0.03 - i * (-barre_y - 0.06) / maxf(nb_m - 1, 1), 0)
				maillon.rotation = Vector3(PI / 2, 0, 0) if i % 2 == 0 else Vector3(PI / 2, PI / 2, 0)
		var barre := _boite(Vector3(demi * 2.0 + 0.04, 0.05, 0.06), fer)
		barre.position.y = barre_y
		ferrure.add_child(barre)
		var c := Cadenas3D.new()
		c.position = Vector3(0, HAUT_CADENAS - 1.9, 0)
		ferrure.add_child(c)
		c.construire(n, moi, COUCHE_BOUTONS if moi else 0, laiton_vif, fer, rivet)
		_ferrures[k] = ferrure
		_cadenas.append(c)
		_essais_vus.append(0)
		_ouverts_vus.append(false)
		var zeros: Array = []
		zeros.resize(n)
		zeros.fill(0)
		_chiffres_vus.append(zeros)
		_chute.append(-1.0)


## La charnière du couvercle : arête arrière du haut (on le glisse sous un pivot).
func _pivot_couvercle(coffre: Node3D) -> Node3D:
	var lid := coffre.find_child("treasure_chest_lid", true, false) as Node3D
	if lid == null:
		return Node3D.new()
	var mi: MeshInstance3D = lid if lid is MeshInstance3D else lid.find_children("*", "MeshInstance3D", true, false)[0]
	var b := mi.get_aabb()
	var pivot := Node3D.new()
	var parent := lid.get_parent()
	pivot.transform = lid.transform * Transform3D(Basis.IDENTITY, Vector3(0, b.position.y, b.position.z))
	parent.add_child(pivot)
	var t := lid.transform
	parent.remove_child(lid)
	pivot.add_child(lid)
	lid.transform = pivot.transform.affine_inverse() * t
	return pivot


# ---------------------------------------------------------------- l'indication à l'écran

func _batir_indice() -> void:
	_hint = IndiceQuete.new()
	add_child(_hint)


func _ecrire_indice(texte: String) -> void:
	_hint.ecrire(texte)


# ---------------------------------------------------------------- mes mains

func _mien() -> Cadenas3D:
	return _cadenas[rang] if rang >= 0 and rang < _cadenas.size() else null


func _etat_mien() -> Dictionary:
	var l: Array = _vue.get("cadenas", [])
	return l[rang] if rang >= 0 and rang < l.size() else {}


func _libre() -> bool:
	var e := _etat_mien()
	return not e.is_empty() and not bool(e.get("o", false)) and float(e.get("b", 0.0)) <= 0.0


func manipuler(monde: MondeQuete, delta: float) -> void:
	_monde_envoi = monde
	var mien := _mien()
	if mien == null or monde.camera == null or not monde.is_inside_tree():
		return
	# Ce que je vise : une molette de mon cadenas ou son anse.
	var cam := monde.camera
	var o := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(o, o - cam.global_basis.z * PORTEE_CADENAS, COUCHE_BOUTONS)
	q.collide_with_areas = false
	var touche := monde.get_world_3d().direct_space_state.intersect_ray(q)
	_visee_k = -1
	_visee_anse = false
	if touche:
		var c: Object = touche["collider"]
		if c.has_meta("molette"):
			_visee_k = int(c.get_meta("molette"))
		elif c.has_meta("anse"):
			_visee_anse = true
	var bas := monde._clic()
	if bas and not _clic_avant and _glisse == "" and _libre():
		if _visee_k >= 0:
			_glisse = "molette"
			_glisse_k = _visee_k
			_acc = 0.0
		elif _visee_anse:
			_glisse = "anse"
			_acc = 0.0
			_envoye = false
	if not bas and _glisse != "":
		_glisse = ""
		_glisse_k = -1
	_clic_avant = bas
	if _glisse != "" and not _libre():
		_glisse = ""          # la serrure vient de se bloquer ou de s'ouvrir
	var tirage := 0.0
	if _glisse == "anse":
		tirage = clampf(-_acc / PX_POUR_TIRER, 0.0, 1.0)
		if tirage >= 1.0 and not _envoye:
			_envoye = true
			monde.geste.emit({"tirer": true})
	elif _glisse == "molette":
		pass
	var e := _etat_mien()
	if float(e.get("b", 0.0)) > 0.0:
		tirage = minf(tirage, 0.3)
	mien.tirage = lerpf(mien.tirage, tirage, minf(1.0, delta * 25.0))
	mien.marquer(_glisse_k if _glisse == "molette" else (_visee_k if _glisse == "" else -1))
	# Ce qu'on peut faire, en toutes lettres (les gestes à la souris n'ont pas de touche).
	if bool(e.get("o", false)):
		_ecrire_indice("")
	elif float(e.get("b", 0.0)) > 0.0:
		_ecrire_indice("La serrure est bloquée : l'anse ne bouge plus. Attends un peu…")
	elif _visee_k >= 0 or _glisse == "molette":
		_ecrire_indice("Molette de la souris, ou clic tenu et glisser : tourner la molette")
	elif _visee_anse or _glisse == "anse":
		_ecrire_indice("Clic tenu, puis tire vers le haut : essayer le code")
	else:
		_ecrire_indice("Vise une molette de ton cadenas (clic tenu : tirer l'anse)")


func absorbe_souris(rel: Vector2) -> bool:
	if _glisse == "molette":
		_acc += -rel.y
		while _acc >= PX_PAR_CRAN:
			_acc -= PX_PAR_CRAN
			_pas(1)
		while _acc <= -PX_PAR_CRAN:
			_acc += PX_PAR_CRAN
			_pas(-1)
		return true
	if _glisse == "anse":
		_acc = clampf(_acc + rel.y, -PX_POUR_TIRER * 1.25, 30.0)
		return true
	return false


func molette(sens: int) -> bool:
	if _mien() == null:
		return false
	if _visee_k < 0:
		return _visee_anse          # sur l'anse, la molette ne fait rien mais ne change rien d'autre
	if _libre():
		_pas_sur(_visee_k, sens)
	return true


func _pas(sens: int) -> void:
	if _glisse_k >= 0:
		_pas_sur(_glisse_k, sens)


var _monde_envoi: MondeQuete


func _pas_sur(k: int, sens: int) -> void:
	if _monde_envoi == null:
		return
	_monde_envoi.geste.emit({"roue": k, "pas": 1 if sens > 0 else -1})


# ---------------------------------------------------------------- la vue de l'hôte

func animer(vue: Dictionary, _phase: float, delta: float) -> void:
	_t += delta
	_vue = vue
	var infos: Array = vue.get("cadenas", [])
	if _cadenas.is_empty() and not infos.is_empty():
		_poser_cadenas(infos.map(func(i): return int(i.get("n", 4))))
		# Un cadenas est rebâti si l'équipe change : le décor, lui, est refait par MondeQuete.
	var ouvertes: Array = vue.get("ouvertes", [])
	for k in mini(_cadenas.size(), infos.size()):
		var info: Dictionary = infos[k]
		var cad := _cadenas[k]
		cad.regler(info.get("r", []))
		# Les crans qu'on entend : le mien net, ceux des autres de loin.
		var nouveaux: Array = info.get("r", [])
		var anciens: Array = _chiffres_vus[k]
		for i in mini(nouveaux.size(), anciens.size()):
			if int(nouveaux[i]) != int(anciens[i]):
				SonsQuete.jouer(self, SonsQuete.cran(), cad.position_roue(i), -2.0 if k == rang else -12.0, 3.0)
				anciens[i] = nouveaux[i]
		if int(info.get("e", 0)) != int(_essais_vus[k]):
			_essais_vus[k] = int(info.get("e", 0))
			cad.resister()
			SonsQuete.jouer(self, SonsQuete.resiste(), cad.global_position, -1.0 if k == rang else -9.0, 4.0)
			secouer(_ferrures[k], 0.012)
		var ouvert := bool(info.get("o", false))
		cad.ouvrir(ouvert)
		if ouvert and not _ouverts_vus[k]:
			_ouverts_vus[k] = true
			_chute[k] = 0.0
			SonsQuete.jouer(self, SonsQuete.ouverture(), cad.global_position, 0.0 if k == rang else -8.0, 5.0)
		if ouvert and float(_chute[k]) >= 0.0:
			_chute[k] = float(_chute[k]) + delta
			# La ferrure lâche quand l'anse est sortie, et le cadenas ouvert pend au bout.
			# Elle se détache et se balance au bout de sa chaîne, puis pend, immobile.
			var tc := maxf(float(_chute[k]) - 0.5, 0.0)
			(_ferrures[k] as Node3D).rotation.z = -0.1 * (1.0 - exp(-tc * 4.0)) - 0.2 * exp(-tc * 1.4) * sin(tc * 5.0)
	# Le coffre s'ouvre quand assez de serrures le sont.
	var seuil := int(vue.get("seuil", 99))
	var ouvert_coffre := ouvertes.size() >= seuil
	if ouvert_coffre and not _ouvert_coffre:
		SonsQuete.jouer(self, SonsQuete.gonds(), global_position + Vector3(0, 1.2, 0), 2.0, 9.0)
		SonsQuete.jouer(self, SonsQuete.tresor(), global_position + Vector3(0, 1.4, 0), 0.0, 9.0)
		_or.emitting = true
	_ouvert_coffre = ouvert_coffre
	for ch: Node3D in _chaines:
		ch.visible = not ouvert_coffre
	_couvercle.rotation.x = move_toward(_couvercle.rotation.x, -1.15 if ouvert_coffre else 0.0, delta * 0.9)
	_lueur.light_energy = move_toward(_lueur.light_energy, 3.0 if ouvert_coffre else 0.0, delta * 2.0)
	if nouvelle_annonce(vue):
		secouer(_couvercle, 0.02)


# ---------------------------------------------------------------- la clairière

## La clairière est habillée au hasard (même tirage chez tous) : les rochers tombaient parfois en
## tas les uns sur les autres, sur une souche ou un poteau, et certains étaient énormes. On les
## remet en bordure, rangés : chacun à l'écart des autres objets, loin de la zone de jeu.
func habiller() -> void:
	super.habiller()
	_ranger_cailloux()


func _est_rocher(n: Node3D) -> bool:
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		return mi.mesh != null and mi.mesh.resource_name.begins_with("rock_moss")
	return false


func _ranger_cailloux() -> void:
	var rochers: Array[Node3D] = []
	var autres: Array = []
	for c in get_children():
		if not (c is Node3D) or c is GPUParticles3D:
			continue
		var n := c as Node3D
		if _est_rocher(n):
			rochers.append(n)
		else:
			var e := _empreinte(n)
			# L'herbe et les fougères ne comptent pas : un rocher peut les écraser.
			if not e.is_empty() and not n.is_in_group("traversable"):
				autres.append(e)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var poses: Array = []
	for r in rochers:
		var e := _empreinte(r)
		if e.is_empty():
			continue
		# Pas plus de ~2,6 m de large : un gros bloc de 4 m écrasait la clairière.
		var rayon_r: float = e[1]
		if rayon_r > 1.3:
			r.scale *= 1.3 / rayon_r
			rayon_r = 1.3
		var rr := rayon_r + 0.4
		var p := Vector2(r.position.x, r.position.z)
		var ok := false
		for essai in 40:
			if essai > 0:
				var a := rng.randf() * TAU
				p = Vector2(sin(a), cos(a)) * rng.randf_range(6.0, 9.0)
			if p.length() < 5.5:
				continue
			if gene(p, rayon_r):
				continue
			var libre_ici := true
			for o: Array in autres + poses:
				if p.distance_to(o[0]) < rr + o[1]:
					libre_ici = false
					break
			if libre_ici:
				ok = true
				break
		if ok:
			r.position = Vector3(p.x, -0.1, p.y)
			poses.append([p, rayon_r])
		else:
			r.queue_free()
