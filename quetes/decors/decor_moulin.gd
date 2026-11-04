extends DecorQuete
## Le Moulin : une meule de pierre sur son socle de moellons, traversée par un arbre de bois et
## une longue barre que l'équipe fait tourner au battement. La farine s'amasse au pied et vole en
## poussière ; des paniers pleins attendent. Devant moi, MA manivelle sur l'établi : sa poignée
## passe en haut à chaque battement, c'est là que ma main doit passer en tournant. Un coup à contretemps fait
## cogner la meule.

var _meule: Node3D
var _manivelle: Node3D
var _farine: MeshInstance3D
var _poussiere: GPUParticles3D
var _repere: MeshInstance3D
var _frappe := 0.0
var _sac_haut: Node3D            # le sac versé dans la trémie : il se vide
var _sacs_moulus: Array = []     # les sacs de farine empilés, un par sac fini
var _roue: Node3D                # la roue à aubes du moulin, dehors
var _grains: GPUParticles3D      # le grain qui tombe de la trémie
var _sac_vu := -1
var _lumiere_four: OmniLight3D


func libre(p: Vector3) -> bool:
	# Le moulin lui-même (maison, bief) ne se laisse pas semer d'arbres.
	return not (p.distance_to(Vector3(-9.5, 0, -4.5)) < 6.0 or p.distance_to(Vector3(8.5, 0, 4.5)) < 3.2)


func construire() -> void:
	var socle := _cylindre(1.05, 0.55, matiere("mousse", 0.7))
	socle.position.y = 0.27
	add_child(socle)
	anneau(1.02, 0.06, matiere("roche", 1.0), self).position.y = 0.55
	_meule = Node3D.new()
	_meule.add_to_group("mobile")
	_meule.position = Vector3(0, 0.68, 0)
	add_child(_meule)
	var pierre := _cylindre(0.88, 0.24, matiere("roche", 0.9, Color(0.85, 0.83, 0.8)))
	_meule.add_child(pierre)
	var oeil := _cylindre(0.14, 0.25, matiere("metal", 2.0, Color(0.25, 0.24, 0.23)))
	_meule.add_child(oeil)
	# L'arbre et la barre qui tournent avec la meule.
	poutre(Vector3(0, -0.1, 0), Vector3(0, 1.4, 0), 0.09, matiere("vieux_bois", 1.0), _meule)
	# La barre balaie un cercle de 1,15 m : rien de fixe ne se trouve dans ce cercle (portique à 1,5 m).
	poutre(Vector3(-1.15, 0.55, 0), Vector3(1.15, 0.55, 0), 0.06, matiere("vieux_bois", 1.0), _meule)
	for x: float in [-1.08, 1.08]:
		var lien := anneau(0.075, 0.014, matiere("chanvre", 1.0, Color(0.5, 0.42, 0.3)), _meule)
		lien.rotation.z = PI / 2
		lien.position = Vector3(x, 0.55, 0)
	# Un portique au-dessus tient l'arbre droit.
	var cote := Vector3(1.5, 0, 0)
	for s: float in [-1.0, 1.0]:
		poutre(cote * s + Vector3(0, -0.1, 0), cote * s + Vector3(0, 2.4, 0), 0.08)
	poutre(-cote * 1.04 + Vector3(0, 2.35, 0), cote * 1.04 + Vector3(0, 2.35, 0), 0.07)
	# Le haut de l'arbre tourne dans un collier de fer cloué à la traverse.
	var collier := anneau(0.12, 0.025, matiere("metal", 2.0, Color(0.3, 0.29, 0.28)), self)
	collier.position.y = 2.1
	poutre(Vector3(0, 2.1, 0), Vector3(0, 2.35, 0), 0.05)
	_farine = _sphere(0.5, matiere("farine", 1.0, Color(0.9, 0.88, 0.82)))
	_farine.scale = Vector3(1, 0.05, 1)
	_farine.position = Vector3(1.0, 0.0, 0.6)
	add_child(_farine)
	_poussiere = _particules(24, 2.5, Vector3(0.9, 0.05, 0.9), Vector3(0, 0.15, 0), 0.25,
		_degrade([Color(0.95, 0.93, 0.88, 0.0), Color(0.95, 0.93, 0.88, 0.3), Color(0.95, 0.93, 0.88, 0.0)]), false)
	_poussiere.position.y = 0.6
	add_child(_poussiere)
	for k in 3:
		var p := Vector3(sin(3.4 + k * 0.42), 0, cos(3.4 + k * 0.42)) * 1.5
		var panier := accessoire("wicker_basket_01", p, 1.3, k, 0.6)
		if panier:
			var tas := _sphere(0.16 / 1.3, matiere("farine", 1.0, Color(0.9, 0.88, 0.82)))
			tas.scale = Vector3(1, 0.4, 0.8)
			tas.position = Vector3(0, 0.12 / 1.3, 0)
			panier.add_child(tas)
	accessoire("wooden_crate_01", Vector3(sin(0.5), 0, cos(0.5)) * 1.45, 0.8, 0.6, 0.6)
	# Ma manivelle, fixée sur l'établi : une roue, sa poignée, et le repère du haut.
	var e := etabli()
	# Deux montants cloués sur l'établi ; l'axe les traverse ; la roue tourne devant eux sans rien toucher.
	for z: float in [-0.09, -0.05]:
		var montant := _boite(Vector3(0.05, 0.27, 0.025), matiere("vieux_bois", 2.0))
		montant.position = Vector3(0.45, haut_etabli + 0.135, z)
		e.add_child(montant)
	var axe := _cylindre(0.012, 0.2, matiere("metal", 2.0, Color(0.3, 0.29, 0.28)))
	axe.rotation.x = PI / 2
	axe.position = Vector3(0.45, haut_etabli + 0.23, -0.04)
	e.add_child(axe)
	_manivelle = Node3D.new()
	_manivelle.position = Vector3(0.45, haut_etabli + 0.23, 0.04)
	e.add_child(_manivelle)
	var roue := anneau(0.13, 0.018, matiere("vieux_bois", 2.0), _manivelle)
	roue.rotation.x = PI / 2
	for k in 4:
		var rayon := _boite(Vector3(0.012, 0.26, 0.012), matiere("vieux_bois", 2.0))
		rayon.rotation.z = k * PI / 4
		_manivelle.add_child(rayon)
	var poignee := _cylindre(0.022, 0.13, matiere("metal", 2.0, Color(0.3, 0.29, 0.28)))
	poignee.rotation.x = PI / 2
	poignee.position = Vector3(0, 0.13, 0.07)
	_manivelle.add_child(poignee)
	_repere = _sphere(0.03, matiere("repere", 1.0, Color(1.0, 0.8, 0.35), Color(1.0, 0.7, 0.3)))
	_repere.position = Vector3(0.45, haut_etabli + 0.42, 0)
	e.add_child(_repere)


	_batir_exterieur()
	_batir_tremie()


## Autour de la clairière : la maison du moulin, sa roue à aubes dans le bief, une charrette de sacs.
func _batir_exterieur() -> void:
	var maison := Node3D.new()
	maison.position = Vector3(-9.5, 0, -4.5)
	maison.rotation.y = 0.9
	add_child(maison)
	var planches := matiere("vieux_bois", 0.8, Color(0.8, 0.72, 0.64))
	var murs := _boite(Vector3(5.0, 3.0, 4.0), planches)
	murs.position.y = 1.5
	maison.add_child(murs)
	var pierre := _boite(Vector3(5.2, 0.7, 4.2), matiere("mousse", 0.7))
	pierre.position.y = 0.35
	maison.add_child(pierre)
	var tuiles := matiere("tuiles", 1.2, Color(0.6, 0.5, 0.45))
	for cote: float in [-1.0, 1.0]:
		var pan := _boite(Vector3(5.6, 0.1, 2.9), tuiles)
		pan.position = Vector3(0, 3.65, cote * 1.05)
		pan.rotation.x = cote * 0.62
		maison.add_child(pan)
	var porte := _boite(Vector3(1.0, 1.9, 0.08), matiere("vieux_bois", 1.0, Color(0.5, 0.38, 0.28)))
	porte.position = Vector3(-1.2, 0.95, 2.03)
	maison.add_child(porte)
	var fenetre := _boite(Vector3(0.9, 0.7, 0.06), matiere("lueur_moulin", 1.0, Color(1.0, 0.75, 0.4), Color(1.0, 0.65, 0.25)))
	fenetre.position = Vector3(1.2, 1.9, 2.03)
	maison.add_child(fenetre)
	_lumiere_four = _lumiere(Color(1.0, 0.7, 0.35), 2.0, 9.0, Vector3(1.2, 1.9, 3.0))
	maison.add_child(_lumiere_four)
	# La roue à aubes, sur le flanc, dans le bief.
	_roue = Node3D.new()
	_roue.position = Vector3(2.9, 1.5, 0.0)
	maison.add_child(_roue)
	var bois := matiere("vieux_bois", 1.0)
	for k in 2:
		var cercle := anneau(1.45, 0.07, bois, _roue)
		cercle.rotation.z = PI / 2
		cercle.position.x = -0.35 + k * 0.7
	for k in 8:
		var a := TAU * k / 8.0
		var rayon := _boite(Vector3(0.06, 2.9, 0.06), bois)
		rayon.rotation.x = a
		_roue.add_child(rayon)
		var aube := _boite(Vector3(0.8, 0.5, 0.05), bois)
		aube.position = Vector3(0, sin(a) * 1.45 * -1.0, cos(a) * 1.45)
		aube.rotation.x = a
		_roue.add_child(aube)
	_roue.add_to_group("mobile")
	eau(Vector2(8.0, 3.0), Vector3(-9.5, 0.04, -4.5) + Vector3(2.9, 0, 0).rotated(Vector3.UP, 0.9) + Vector3(0, 0, 0), 1.0, Color(0.03, 0.07, 0.08))
	# Une charrette de sacs, des tonneaux, du foin.
	var charrette := Node3D.new()
	charrette.position = Vector3(8.5, 0, 4.5)
	charrette.rotation.y = 2.3
	add_child(charrette)
	var plateau := _boite(Vector3(2.2, 0.12, 1.2), bois)
	plateau.position.y = 0.7
	charrette.add_child(plateau)
	for z: float in [-0.7, 0.7]:
		var roue_c := anneau(0.45, 0.05, bois, charrette)
		roue_c.rotation.z = PI / 2
		roue_c.position = Vector3(0, 0.45, z)
	for k in 6:
		var sac := _sphere(0.32, matiere("farine", 1.0, Color(0.82, 0.76, 0.64)))
		sac.scale = Vector3(1.0, 0.7, 0.8)
		sac.position = Vector3(-0.7 + (k % 3) * 0.7, 1.0 + (k / 3) * 0.4, -0.2 + (k / 3) * 0.2)
		charrette.add_child(sac)
	accessoire("wooden_barrels_01", Vector3(-7.0, 0, 1.5), 1.2, 0.4)
	accessoire("wine_barrel_01", Vector3(-6.4, 0, 2.3), 1.2, 1.0)


## Au-dessus de la meule : une trémie de bois, le sac qu'on y vide, le grain qui tombe, et les sacs
## de farine qu'on empile à côté, un par sac fini.
func _batir_tremie() -> void:
	var bois := matiere("vieux_bois", 1.0, Color(0.8, 0.72, 0.62))
	var tremie := _cylindre(0.55, 0.5, bois, 0.2)
	tremie.position = Vector3(0, 1.45, 0)
	add_child(tremie)
	_grains = _particules(18, 0.7, Vector3(0.06, 0.02, 0.06), Vector3(0, -0.8, 0), 0.06,
		_degrade([Color(0.8, 0.7, 0.4, 0.0), Color(0.82, 0.72, 0.42, 0.9), Color(0.8, 0.7, 0.4, 0.0)]), false)
	_grains.position = Vector3(0, 1.2, 0)
	_grains.emitting = false
	add_child(_grains)
	# Le sac qu'on vide ne flotte pas : il repose sur une planche scellée au montant du portique.
	var planche := _boite(Vector3(0.98, 0.07, 0.55), bois)
	planche.position = Vector3(1.03, 1.56, 0.0)
	add_child(planche)
	var fer_m := matiere("metal", 2.0, Color(0.3, 0.29, 0.28))
	poutre(Vector3(1.5, 0.95, 0.0), Vector3(0.9, 1.53, 0.0), 0.035, bois)
	var bande := _boite(Vector3(0.1, 0.1, 0.6), fer_m)
	bande.position = Vector3(1.43, 1.56, 0.0)
	add_child(bande)
	_sac_haut = Node3D.new()
	_sac_haut.position = Vector3(0.78, 1.6, 0.0)      # le pivot est au pied du sac : il se vide en s'affaissant sur la planche
	_sac_haut.rotation.z = -0.5
	add_child(_sac_haut)
	var toile := matiere("farine", 1.0, Color(0.78, 0.7, 0.55))
	var corps := _sphere(0.26, toile)
	corps.scale = Vector3(0.9, 1.25, 0.8)
	corps.position.y = 0.32
	_sac_haut.add_child(corps)
	var nouet := _cylindre(0.1, 0.12, toile)
	nouet.position.y = 0.72
	_sac_haut.add_child(nouet)
	_sac_haut.add_to_group("mobile")
	for k in 4:
		var sf := Node3D.new()
		sf.position = Vector3(1.85 + 0.0, 0.0, 0.2) + Vector3(0.45 * (k % 2), 0.28 * (k / 2), 0.35 * (k / 2))
		sf.visible = false
		add_child(sf)
		var c := _sphere(0.3, matiere("farine", 1.0, Color(0.9, 0.88, 0.82)))
		c.scale = Vector3(1.0, 0.6, 0.75)
		c.position.y = 0.2
		sf.add_child(c)
		_sacs_moulus.append(sf)


func cible_geste() -> Node3D:
	return _manivelle


func geste_rythme() -> String:
	return "manivelle"


func frappe() -> void:
	_frappe = 0.25


func animer(vue: Dictionary, phase: float, delta: float) -> void:
	var grain := jauge(vue, "grain", 0.0)
	var mo: Dictionary = vue.get("moulin", {})
	var periode := float(mo.get("periode", 1.0))
	var pause := bool(mo.get("pause", false))
	# La meule tourne au pas du sac (plus vif, plus vite) ; elle ralentit quand on verse le suivant.
	_meule.rotation.y += delta * (0.25 if pause else 1.2 / maxf(periode, 0.4) * 0.5)
	_roue.rotation.x += delta * (0.3 if pause else 0.8 / maxf(periode, 0.4))
	var sac := int(mo.get("sac", 0))
	if sac != _sac_vu and not mo.is_empty():
		_sac_vu = sac
		for k in _sacs_moulus.size():
			(_sacs_moulus[k] as Node3D).visible = k < sac
		_sac_haut.scale = Vector3(1, 0.1, 1)
		create_tween().tween_property(_sac_haut, "scale", Vector3.ONE, 0.8)
	if not mo.is_empty() and not pause:
		# Le sac se vide au fil du sac en cours.
		var reste := 1.0 - float(mo.get("prog", 0.0))
		_sac_haut.scale = _sac_haut.scale.lerp(Vector3(1.0, 0.25 + 0.75 * reste, 1.0), minf(delta * 3.0, 1.0))
	_grains.emitting = not pause and not mo.is_empty()
	if manivelle >= 0.0:
		# C'est ma main qui la tourne : le battement, lui, se lit sur le repère.
		_manivelle.rotation.z = lerp_angle(_manivelle.rotation.z, -manivelle * TAU, minf(1.0, delta * 12.0))
	elif phase >= 0.0:
		# Phase 0 = en haut : la poignée y passe à chaque battement.
		_manivelle.rotation.z = -phase * TAU
		_repere.scale = Vector3.ONE
	_farine.scale = _farine.scale.lerp(Vector3(1.0 + grain * 0.5, 0.05 + grain * 0.7, 1.0 + grain * 0.5), delta * 2.0)
	_poussiere.amount_ratio = 0.2 + grain * 0.8
	_frappe -= delta
	# Le repère bat la mesure (il enfle quand le battement passe en haut) et éclate à mon coup.
	var bat := 1.0 + 0.6 * maxf(0.0, cos(maxf(phase, 0.0) * TAU)) ** 8
	_repere.scale = Vector3.ONE * (2.2 if _frappe > 0.0 else bat)
	if nouvelle_annonce(vue):
		secouer(_meule, 0.08)
