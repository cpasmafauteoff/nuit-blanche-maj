extends DecorQuete
## L'Incendie : un hameau en feu — la grange, une meule de foin, une étable, un atelier, un fenil — avec
## flammes aux fenêtres et sur les toits, colonnes de fumée, braises qui volent. Un puits à l'autre bout de
## la chaîne. Chacun a un seau vide à ses pieds ; quand un seau plein m'arrive, il est là, dans mes mains :
## je l'attrape et je le lance au voisin. Le dernier de la chaîne le jette sur le foyer qu'il VISE (un anneau
## doré marque le foyer visé). Les flammes suivent l'intensité de chaque foyer ; un bâtiment perdu noircit.

const GRANGE := Vector3(2.4, 0, -4.2)
const PUITS := Vector3(-5.2, 0, -1.2)
## Les foyers, dans l'ordre de DimGestes.I_FOYERS : position du bâtiment (pour viser) et hauteur du feu.
const FOYERS := [Vector3(2.4, 0, -4.2), Vector3(-1.8, 0, -5.8), Vector3(7.2, 0, -3.0), Vector3(-6.2, 0, -5.0), Vector3(2.8, 0, -9.6)]

var _foyers: Array = []           # par foyer : {"flammes": [[Node3D, taille]], "lueur": OmniLight3D, "fumee": GPUParticles3D, "noir": [Material]}
var _vue_inc := {}
var _anneau: MeshInstance3D       # l'anneau doré sur le foyer visé
var _vise := -1
var _jets: Array = []
var _jet_k := 0
var _braises: GPUParticles3D
var _t := 0.0


func libre(p: Vector3) -> bool:
	for f: Vector3 in FOYERS:
		if p.distance_to(f) < 4.4:
			return false
	if p.distance_to(PUITS) < 1.8:
		return false
	return not (absf(p.z - 1.2) < 1.4 and absf(p.x) < 5.0)


func construire() -> void:
	meuble = ""
	var bois := matiere("vieux_bois", 0.8, Color(0.75, 0.68, 0.62))
	var tuiles := matiere("tuiles", 1.0, Color(0.55, 0.45, 0.4))
	var foin := matiere("chanvre", 1.0, Color(0.55, 0.4, 0.17))
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color(0.02, 0.01, 0.01)
	noir.emission_enabled = true
	noir.emission = Color(0.35, 0.08, 0.0)
	# 0. La grange : murs de planches, porte béante, deux fenêtres, toit de tuiles, échelle.
	var g := Node3D.new()
	g.position = GRANGE
	g.rotation.y = 0.25
	add_child(g)
	var murs := _boite(Vector3(4.0, 2.6, 3.4), bois)
	murs.position.y = 1.3
	g.add_child(murs)
	for ouv: Array in [[Vector3(0.0, 0.9, 1.71), Vector3(1.3, 1.8, 0.02)], [Vector3(-1.3, 1.7, 1.71), Vector3(0.6, 0.5, 0.02)], [Vector3(1.3, 1.7, 1.71), Vector3(0.6, 0.5, 0.02)]]:
		var o := _boite(ouv[1], noir)
		o.position = ouv[0]
		g.add_child(o)
	for cote: float in [-1.0, 1.0]:
		var pan := _boite(Vector3(4.4, 0.08, 2.3), tuiles)
		pan.position = Vector3(0, 3.15, cote * 0.9)
		pan.rotation.x = cote * 0.62
		g.add_child(pan)
	modele("wooden_ladder", Vector3(-1.6, 0, 1.75), 1.6, 0.0, g).rotation.x = -0.25
	modele("wooden_crate_01", Vector3(2.4, 0, 1.2), 1.0, 0.8, g)
	modele("wicker_basket_01", Vector3(-2.4, 0, 1.0), 1.4, 0.3, g)
	_foyers.append(_flammes(g, [[Vector3(0, 0.3, 1.8), 1.3], [Vector3(-1.3, 1.6, 1.8), 0.8], [Vector3(1.3, 1.6, 1.8), 0.8], [Vector3(-1.0, 3.3, 0.4), 1.4], [Vector3(0.9, 3.4, -0.3), 1.6]], Vector3(0, 3.6, 0), 2.5))
	# 1. La meule de foin.
	var meule := Node3D.new()
	meule.position = FOYERS[1]
	add_child(meule)
	var base := _cylindre(1.2, 1.3, foin, 1.0)
	base.position.y = 0.65
	meule.add_child(base)
	var haut := _sphere(1.0, foin)
	haut.scale = Vector3(1.0, 0.75, 1.0)
	haut.position.y = 1.35
	meule.add_child(haut)
	poutre(Vector3(0, 1.9, 0), Vector3(0.2, 2.5, 0), 0.04, bois, meule)
	modele("wooden_ladder", Vector3(1.2, 0, 0.6), 1.3, 1.2, meule).rotation.x = -0.3
	_foyers.append(_flammes(meule, [[Vector3(0, 1.8, 0), 1.2], [Vector3(0.6, 1.2, 0.5), 0.8], [Vector3(-0.6, 1.0, -0.4), 0.8]], Vector3(0, 2.2, 0), 1.8))
	# 2. L'étable : un abri ouvert d'un côté, toit de tuiles.
	var etable := Node3D.new()
	etable.position = FOYERS[2]
	etable.rotation.y = -0.5
	add_child(etable)
	var fond := _boite(Vector3(3.6, 2.3, 0.2), bois)
	fond.position = Vector3(0, 1.15, -1.0)
	etable.add_child(fond)
	for x: float in [-1.7, 1.7]:
		var flanc := _boite(Vector3(0.2, 2.3, 2.2), bois)
		flanc.position = Vector3(x, 1.15, 0.0)
		etable.add_child(flanc)
	var toit := _boite(Vector3(4.0, 0.1, 2.8), tuiles)
	toit.position = Vector3(0, 2.5, 0.0)
	toit.rotation.x = 0.18
	etable.add_child(toit)
	modele("wooden_barrels_01", Vector3(-1.0, 0, 0.2), 1.1, 0.3, etable)
	modele("wooden_crate_01", Vector3(0.9, 0, 0.0), 1.1, 0.1, etable)
	_foyers.append(_flammes(etable, [[Vector3(0, 0.4, 0.4), 1.0], [Vector3(-1.2, 1.6, -0.4), 0.9], [Vector3(1.2, 2.6, 0.0), 1.1]], Vector3(0, 2.8, 0), 1.6))
	# 3. L'atelier : une cabane de planches.
	var atelier := Node3D.new()
	atelier.position = FOYERS[3]
	atelier.rotation.y = 0.7
	add_child(atelier)
	var cab := _boite(Vector3(2.8, 2.2, 2.4), bois)
	cab.position.y = 1.1
	atelier.add_child(cab)
	var porte := _boite(Vector3(0.9, 1.6, 0.04), noir)
	porte.position = Vector3(0.0, 0.8, 1.21)
	atelier.add_child(porte)
	for cote: float in [-1.0, 1.0]:
		var pan := _boite(Vector3(3.1, 0.07, 1.6), tuiles)
		pan.position = Vector3(0, 2.6, cote * 0.55)
		pan.rotation.x = cote * 0.55
		atelier.add_child(pan)
	modele("wooden_crate_01", Vector3(1.9, 0, 0.9), 1.0, 0.4, atelier)
	modele("wine_barrel_01", Vector3(-1.9, 0, 0.9), 1.2, 0.0, atelier)
	_foyers.append(_flammes(atelier, [[Vector3(0, 0.3, 1.4), 1.0], [Vector3(0.0, 2.6, 0.0), 1.2], [Vector3(-1.0, 1.5, 1.3), 0.7]], Vector3(0, 2.8, 0), 1.4))
	# 4. Le fenil : une grande bâtisse haute, derrière la grange.
	var fenil := Node3D.new()
	fenil.position = FOYERS[4]
	fenil.rotation.y = -0.2
	add_child(fenil)
	var tour := _boite(Vector3(3.2, 3.6, 3.0), bois)
	tour.position.y = 1.8
	fenil.add_child(tour)
	var lucarne := _boite(Vector3(0.9, 0.9, 0.04), noir)
	lucarne.position = Vector3(0.0, 3.0, 1.52)
	fenil.add_child(lucarne)
	for cote: float in [-1.0, 1.0]:
		var pan := _boite(Vector3(3.6, 0.08, 2.1), tuiles)
		pan.position = Vector3(0, 4.3, cote * 0.85)
		pan.rotation.x = cote * 0.7
		fenil.add_child(pan)
	_foyers.append(_flammes(fenil, [[Vector3(0, 3.0, 1.7), 1.2], [Vector3(-0.8, 4.4, 0.2), 1.4], [Vector3(0.9, 4.5, -0.2), 1.2]], Vector3(0, 4.8, 0), 2.0))
	# Braises qui volent au-dessus de tout.
	_braises = _particules(60, 2.5, Vector3(5.0, 0.4, 3.0), Vector3(0.3, 2.4, 0.2), 0.05,
		_degrade([Color(1.0, 0.6, 0.2, 0.0), Color(1.0, 0.55, 0.15, 1.0), Color(0.8, 0.2, 0.05, 0.0)]), true)
	_braises.position = Vector3(1.0, 3.5, -6.0)
	add_child(_braises)
	# Le puits, à l'autre bout de la chaîne.
	var margelle := _cylindre(0.7, 0.75, matiere("mousse", 0.8))
	margelle.position = PUITS + Vector3(0, 0.37, 0)
	add_child(margelle)
	poutre(PUITS + Vector3(-0.75, 0.5, 0), PUITS + Vector3(-0.75, 2.0, 0), 0.06)
	poutre(PUITS + Vector3(0.75, 0.5, 0), PUITS + Vector3(0.75, 2.0, 0), 0.06)
	poutre(PUITS + Vector3(-0.85, 1.9, 0), PUITS + Vector3(0.85, 1.9, 0), 0.07, matiere("vieux_bois", 1.0))
	corde(PUITS + Vector3(0, 1.85, 0), PUITS + Vector3(0, 1.1, 0), 0.0, 0.012)
	modele("wooden_bucket_01", PUITS + Vector3(0, 0.6, 0), 0.8)
	modele("wooden_barrels_01", PUITS + Vector3(-1.6, 0, 0.8), 1.2, 0.5)
	modele("wooden_bucket_02", PUITS + Vector3(1.2, 0, 0.9), 0.8, 0.3)
	# Un seau vide aux pieds de chacun, le long de la chaîne.
	for k in equipe:
		var p := poste(jeu, k, equipe)
		modele("wooden_bucket_01", p + Vector3(0, 0, -0.55), 0.75, k)
	# L'anneau qui marque le foyer visé, et les gerbes d'eau.
	_anneau = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 6
	_anneau.mesh = tm
	var ma := StandardMaterial3D.new()
	ma.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ma.albedo_color = Color(1.0, 0.85, 0.4, 0.75)
	ma.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ma.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_anneau.material_override = ma
	_anneau.visible = false
	_anneau.add_to_group("mobile")
	add_child(_anneau)
	for k in 5:
		var j := _particules(30, 0.8, Vector3(0.3, 0.05, 0.3), Vector3(0, 2.2, 0), 0.1,
			_degrade([Color(0.7, 0.85, 0.95, 0.0), Color(0.75, 0.9, 1.0, 0.8), Color(0.7, 0.85, 0.95, 0.0)]), false)
		j.one_shot = true
		j.explosiveness = 0.9
		j.emitting = false
		j.preprocess = 0.0
		add_child(j)
		_jets.append(j)


## Les flammes d'un bâtiment, sa lueur, sa colonne de fumée.
func _flammes(parent: Node3D, liste: Array, fumee_pos: Vector3, lueur_h: float) -> Dictionary:
	var fl: Array = []
	for f: Array in liste:
		var flamme := feu(f[0], f[1], parent, false)
		# Les taches de flamme s'additionnent : on les assombrit vers l'orange pour que le feu ne blanchisse pas.
		for c in flamme.get_children():
			if c is GPUParticles3D:
				var tache := ((c as GPUParticles3D).draw_pass_1 as QuadMesh).material as StandardMaterial3D
				tache.albedo_color = Color(1.0, 0.55, 0.3, 0.55)
		fl.append([flamme, float(f[1])])
	var fumee := _particules(40, 7.0, Vector3(1.2, 0.2, 1.0), Vector3(0.3, 1.8, 0), 3.2,
		_degrade([Color(0.1, 0.1, 0.1, 0.0), Color(0.06, 0.06, 0.07, 0.75), Color(0.15, 0.15, 0.16, 0.0)]), false)
	fumee.position = fumee_pos
	parent.add_child(fumee)
	var lueur := _lumiere(Color(1.0, 0.45, 0.12), 3.0, 11.0, Vector3(0, lueur_h, 2.0))
	parent.add_child(lueur)
	return {"flammes": fl, "lueur": lueur, "fumee": fumee}


func objet_bouton(b: Dictionary, _k: int, _total: int) -> Node3D:
	var n := Node3D.new()
	var a: Dictionary = b.get("a", {})
	if a.has("renverser"):
		# Le geste du saboteur : un seau déjà à moitié vide, à mes pieds, qu'on peut faire basculer.
		modele("wooden_bucket_01", Vector3(0, 0, 0), 0.7, 0.0, n)
		a_cote(n, Vector3(-0.45, 0.0, 0.3))
		n.visible = not b.get("off", false)
		return n
	# Le seau plein, dans mes mains : il n'apparaît que quand j'en tiens un. Aucune étiquette : c'est un seau.
	modele("wooden_bucket_01", Vector3(0, -0.2, 0), 0.75, 0.0, n)
	var eau_seau := _cylindre(0.13, 0.01, matiere("eau_seau", 1.0, Color(0.15, 0.3, 0.38)))
	eau_seau.position.y = 0.17
	n.add_child(eau_seau)
	if a.has("jet"):
		n.set_meta("jet", true)
	a_cote(n, Vector3(0, 1.0, 0.45))
	n.visible = not b.get("off", false)
	return n


func geste_bouton(a: Dictionary) -> String:
	return "lancer" if a.has("passer") else ""


## Le dernier de la chaîne jette sur le foyer qu'il vise : l'action le dit à l'hôte.
func affiner_action(a: Dictionary) -> Dictionary:
	if not a.has("jet"):
		return a
	var b := a.duplicate()
	b["foyer"] = _foyer_vise()
	return b


## Le foyer en feu le plus proche du regard (-1 si je ne regarde aucun foyer en feu).
func _foyer_vise() -> int:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return -1
	var dir := -cam.global_basis.z
	var meilleur := -1
	var angle_min := 0.7
	var etats: Array = _vue_inc.get("foyers", [])
	for k in FOYERS.size():
		if k >= etats.size() or str(etats[k][1]) != "feu":
			continue
		var vers := (to_global(FOYERS[k] + Vector3(0, 1.4, 0)) - cam.global_position).normalized()
		var a := dir.angle_to(vers)
		if a < angle_min:
			angle_min = a
			meilleur = k
	return meilleur


## Le seau saisi suit ma main ; lâché sans élan, il revient.
func porter(n: Node3D, d: Vector2) -> void:
	if not n.has_meta("base"):
		n.set_meta("base", n.position)
	var b: Vector3 = n.get_meta("base")
	var cam := get_viewport().get_camera_3d()
	if cam == null or n.get_parent() == null:
		return
	# Le déplacement de la main, pris dans le plan de l'écran puis ramené chez le parent du seau.
	var monde := cam.global_basis * Vector3(d.x * 0.35, d.y * 0.25, 0)
	n.position = b + (n.get_parent() as Node3D).global_basis.inverse() * monde


func touche(n: Node3D) -> void:
	var tw := create_tween()
	if n.has_meta("jet") and _vise >= 0:
		# Le seau part vers le foyer visé et s'y vide en gerbe.
		var cible: Vector3 = FOYERS[_vise] + Vector3(0, 1.2, 0)
		var depart := n.global_position
		var f := func(u: float):
			if is_instance_valid(n):
				var p := depart.lerp(to_global(cible), u)
				p.y += sin(u * PI) * 1.2
				n.global_position = p
		tw.tween_method(f, 0.0, 1.0, 0.45)
		tw.tween_callback(func():
			n.visible = false
			_gerbe(cible))
		return
	# Le seau part vers le voisin, côté grange.
	tw.tween_property(n, "position", n.position + Vector3(0.9, 0.1, 0), 0.25)
	tw.tween_callback(func(): n.visible = false)


func _gerbe(pos: Vector3) -> void:
	var j: GPUParticles3D = _jets[_jet_k % _jets.size()]
	_jet_k += 1
	j.position = pos
	j.restart()
	j.emitting = true


func animer(vue: Dictionary, _phase: float, delta: float) -> void:
	_t += delta
	_vue_inc = vue.get("incendie", {})
	var etats: Array = _vue_inc.get("foyers", [])
	for k in _foyers.size():
		var d: Dictionary = _foyers[k]
		var f := 0.0
		var etat := "sain"
		if k < etats.size():
			f = float(etats[k][0])
			etat = str(etats[k][1])
		var vif := etat == "feu"
		var s := 0.25 + f * 1.1 if vif else (0.0 if etat == "sain" else 0.35)
		for fl: Array in d["flammes"]:
			var n: Node3D = fl[0]
			n.visible = s > 0.05
			n.scale = n.scale.lerp(Vector3.ONE * maxf(s, 0.05), delta * 2.0)
		(d["lueur"] as OmniLight3D).light_energy = lerpf((d["lueur"] as OmniLight3D).light_energy, (0.4 + f * 4.0) if vif else (0.5 if etat == "ruine" else 0.0), delta * 2.0)
		(d["fumee"] as GPUParticles3D).amount_ratio = clampf(0.1 + f * 0.9, 0.05, 1.0) if etat != "sain" else 0.0
	_braises.amount_ratio = clampf(jauge(vue, "feu", 0.5) * 1.6, 0.1, 1.0)
	# L'anneau du foyer visé (seulement pour celui qui jette).
	if bool(_vue_inc.get("dernier", false)):
		_vise = _foyer_vise()
	else:
		_vise = -1
	_anneau.visible = _vise >= 0
	if _vise >= 0:
		var pouls := 1.0 + 0.06 * sin(_t * 6.0)
		_anneau.position = FOYERS[_vise] + Vector3(0, 0.15, 0)
		_anneau.scale = Vector3(2.3, 0.4, 2.3) * pouls
	if nouvelle_annonce(vue):
		_braises.restart()
