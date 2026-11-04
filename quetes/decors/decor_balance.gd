extends DecorQuete
## La Balance : un grand mât de bois cerclé de laiton, planté sur un socle de pierre au centre de la clairière.
## À son sommet, un moyeu de laiton d'où partent les bras (un par plateau, A, B, C…) : chaque bras est un
## fléau qui PENCHE selon la charge de son plateau (il s'enfonce, rebondit, se stabilise) et porte, au bout,
## trois chaînes de laiton qui tiennent le plateau, plus un contrepoids derrière le moyeu. Au bout du bras
## pend un CADRAN, tourné vers celui qui le lit (lui seul voit l'aiguille ; les autres voient un cuir clos).
## Sur les plateaux, les poids qu'on y a posés ; sur la table de chacun, ses poids (lingots, poids ronds,
## pierres) et, pour un saboteur, ses cailloux. Tout est pris et posé à la main (cf. Prise).

const HAUT_PIVOT := 3.5
const LONG_BRAS := Dispositions.RAYON_PLATEAUX
const QUEUE := 0.55
const LONG_CHAINE := HAUT_PIVOT - Dispositions.HAUT_PLATEAU
const LIENS := 20
const BOUT := 0.62                    # le bras dépasse les chaînes de ça, pour tenir le cadran
const RAYON_CADRAN := 0.6
const NOMS := ["A", "B", "C", "D"]

var _nb := 0
var _bras: Array = []                 # Node3D (le fléau de chaque plateau, qui penche)
var _plats: Array = []                # Node3D (le plateau, au bout des chaînes)
var _chaines: Array = []              # par plateau : 3 chaînes de LIENS maillons
var _cadrans: Array = []              # par plateau : {n, aiguille, couvercle, face}
var _ang: Array = []                  # angle du bras (rad, positif = le plateau descend)
var _vit: Array = []
var _charge: Array = []               # charge vue, en proportion du total
var _charge_prec: Array = []
var _aig: Array = []                  # aiguille (lecture lissée)
var _aig_v: Array = []
var _t := 0.0
var _lien_mesh: TorusMesh
var _lien_mat: StandardMaterial3D
var _objets := {}                     # objet -> {w, n}
var _total := 16.0
var _laiton: StandardMaterial3D
var _fer: StandardMaterial3D
var _cuir: StandardMaterial3D


func construire() -> void:
	haut_etabli = Dispositions.HAUT_TABLE
	# Le laiton : un vrai métal poli (la texture « metal » du village est un bois ferré, trop mat ici).
	_laiton = StandardMaterial3D.new()
	_laiton.albedo_color = Color(0.86, 0.64, 0.24)
	_laiton.metallic = 0.85
	_laiton.roughness = 0.32
	_laiton.emission_enabled = true
	_laiton.emission = Color(0.22, 0.14, 0.04)
	_fer = matiere("metal", 3.0, Color(0.3, 0.3, 0.32))
	_cuir = matiere("vieux_bois", 3.0, Color(0.32, 0.2, 0.14))
	var bois := matiere("vieux_bois", 1.0, Color(0.85, 0.78, 0.7))
	var pierre := matiere("roche", 0.6)
	# Le sol sous la balance : des dalles, un socle de pierre taillée à deux marches.
	var dalles := _cylindre(2.0, 0.05, matiere("pave", 1.4, Color(0.7, 0.72, 0.66)))
	add_child(dalles)
	var marche := _cylindre(0.95, 0.2, matiere("roche", 0.9, Color(0.66, 0.64, 0.58)), 0.8)
	marche.position.y = 0.1
	add_child(marche)
	var marche2 := _cylindre(0.62, 0.16, pierre, 0.5)
	marche2.position.y = 0.26
	add_child(marche2)
	# Le mât : un tronc équarri, trois cerclages de laiton, un fleuron.
	poutre(Vector3(0, 0.2, 0), Vector3(0, HAUT_PIVOT + 0.5, 0), 0.13, matiere("vieux_bois", 1.0, Color(0.95, 0.88, 0.8)))
	for y: float in [0.55, 1.5, 2.55]:
		anneau(0.135, 0.022, _laiton, self).position.y = y
	var moyeu := _cylindre(0.24, 0.32, _laiton)
	moyeu.position.y = HAUT_PIVOT
	add_child(moyeu)
	for s: float in [-1.0, 1.0]:
		anneau(0.245, 0.018, _laiton, self).position.y = HAUT_PIVOT + s * 0.16
	var fleuron := _sphere(0.17, _laiton)
	fleuron.position.y = HAUT_PIVOT + 0.62
	add_child(fleuron)
	var pointe := _cylindre(0.0, 0.3, _laiton, 0.09)
	pointe.position.y = HAUT_PIVOT + 0.86
	add_child(pointe)
	# Des étais de bois contre le mât, et la lanterne qui éclaire les cadrans.
	for a: float in [0.4, 2.5, 4.6]:
		var d := Vector3(sin(a), 0, cos(a))
		poutre(d * 0.9 + Vector3(0, 0.05, 0), Vector3(0, 1.9, 0) + d * 0.1, 0.045, bois)
	modele("Lantern_01", Vector3(0, HAUT_PIVOT + 1.0, 0), 1.6)
	var lampe := _lumiere(Color(1.0, 0.78, 0.5), 1.5, 8.0, Vector3(0, HAUT_PIVOT - 0.3, 0))
	add_child(lampe)
	_feux.append([lampe, 1.5, randf() * 10.0])
	accessoire("wooden_crate_01", Vector3(0.35, 0, 0.7), 0.8, 0.5, 0.5)
	accessoire("wooden_bucket_02", Vector3(-0.5, 0, -0.55), 0.8, 0.2, 0.5)
	# Les maillons partagent un seul maillage.
	_lien_mesh = TorusMesh.new()
	_lien_mesh.inner_radius = 0.016
	_lien_mesh.outer_radius = 0.03
	_lien_mesh.rings = 10
	_lien_mesh.ring_segments = 5
	_lien_mat = matiere("metal", 3.0, Color(0.55, 0.43, 0.22))


func libre(p: Vector3) -> bool:
	return Vector2(p.x, p.z).length() > 2.5


func habiller() -> void:
	super.habiller()
	etabli()    # ma table, où sont mes poids (les autres ont la leur)


# ---------------------------------------------------------------- les plateaux

## Les bras, chaînes, plateaux et cadrans, dès qu'on sait combien il y a de plateaux.
func _batir(nb: int) -> void:
	_nb = nb
	var bois := matiere("vieux_bois", 1.0, Color(0.9, 0.82, 0.74))
	for p in nb:
		var rest := Dispositions.plateau(p, nb)
		var yaw := atan2(rest.x, rest.z)
		var racine := Node3D.new()
		racine.position = Vector3(0, HAUT_PIVOT, 0)
		racine.rotation.y = yaw
		add_child(racine)
		var bras := Node3D.new()
		racine.add_child(bras)
		poutre(Vector3(0, 0, -QUEUE), Vector3(0, 0, LONG_BRAS + BOUT), 0.06, bois, bras)
		poutre(Vector3(0, -0.02, 0.15), Vector3(0, -0.02, LONG_BRAS + BOUT), 0.075, bois, bras)
		for z: float in [0.45, 0.95]:
			var frette := anneau(0.075, 0.012, _laiton, bras)
			frette.rotation.x = PI / 2
			frette.position = Vector3(0, -0.02, z)
		var crochet := _sphere(0.05, _laiton)
		crochet.position = Vector3(0, -0.05, LONG_BRAS)
		bras.add_child(crochet)
		var contre := _sphere(0.15, _laiton)
		contre.position = Vector3(0, -0.04, -QUEUE - 0.06)
		bras.add_child(contre)
		var bout := _sphere(0.045, _laiton)
		bout.position = Vector3(0, 0, LONG_BRAS + BOUT + 0.02)
		bras.add_child(bout)
		# Le nom du plateau, cloué près du moyeu.
		var etiquette := _boite(Vector3(0.2, 0.17, 0.03), matiere("vieux_bois", 2.0, Color(0.85, 0.8, 0.72)))
		etiquette.position = Vector3(0, 0.15, 0.62)
		bras.add_child(etiquette)
		var nom := _debout(NOMS[p], 62, Vector3(0, 0.15, 0.64))
		nom.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		bras.add_child(nom)
		_bras.append(bras)
		# Le plateau : un plat de laiton à rebord, sur un cône, et ses trois chaînes.
		var plat := Node3D.new()
		plat.position = rest
		plat.add_to_group("mobile")
		add_child(plat)
		var fond := _cylindre(0.5, 0.03, _laiton)
		plat.add_child(fond)
		var cone := _cylindre(0.2, 0.13, _laiton, 0.5)
		cone.position.y = -0.08
		plat.add_child(cone)
		anneau(0.5, 0.022, _laiton, plat).position.y = 0.02
		anneau(0.36, 0.008, matiere("metal", 2.0, Color(0.55, 0.4, 0.2)), plat).position.y = 0.017
		var lettre := _debout(NOMS[p], 64, Vector3(0, -0.08, 0.5))
		lettre.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		lettre.pixel_size = 0.0017
		lettre.modulate = Color(0.25, 0.15, 0.05)
		lettre.outline_size = 0
		lettre.shaded = false
		plat.add_child(lettre)
		_plats.append(plat)
		var cs: Array = []
		for c in 3:
			var liens: Array = []
			for i in LIENS:
				var l := MeshInstance3D.new()
				l.mesh = _lien_mesh
				l.material_override = _lien_mat
				l.add_to_group("mobile")
				add_child(l)
				liens.append(l)
			cs.append(liens)
		_chaines.append(cs)
		_ang.append(0.0)
		_vit.append(0.0)
		_charge.append(0.0)
		_charge_prec.append(0.0)
		_aig.append(0.0)
		_aig_v.append(0.0)
		_cadrans.append(_batir_cadran(24))


## Un cadran de laiton (face creme, graduation, chiffres, aiguille) et son cuir clos pour qui ne le lit pas.
func _batir_cadran(maximum: int) -> Dictionary:
	var n := Node3D.new()
	n.add_to_group("mobile")
	add_child(n)
	var haut := _cylindre(RAYON_CADRAN + 0.03, 0.1, _laiton)
	haut.rotation.x = PI / 2
	n.add_child(haut)
	var lunette := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RAYON_CADRAN - 0.01
	tm.outer_radius = RAYON_CADRAN + 0.045
	tm.rings = 36
	tm.ring_segments = 8
	lunette.mesh = tm
	lunette.material_override = _laiton
	lunette.rotation.x = PI / 2
	lunette.position.z = 0.05
	n.add_child(lunette)
	var face := Node3D.new()
	n.add_child(face)
	var creme := StandardMaterial3D.new()
	creme.albedo_color = Color(0.93, 0.88, 0.76)
	creme.roughness = 0.7
	var disque := _cylindre(RAYON_CADRAN - 0.01, 0.012, creme)
	disque.rotation.x = PI / 2
	disque.position.z = 0.052
	face.add_child(disque)
	face.add_child(_graduation(maximum))
	var pas := 2 if maximum <= 32 else (4 if maximum <= 48 else 8)
	var v := 0
	while v <= maximum:
		var phi := _phi(float(v) / maximum)
		var chiffre := Label3D.new()
		chiffre.font = ThemeDB.fallback_font
		chiffre.text = str(v)
		chiffre.font_size = 64
		chiffre.pixel_size = 0.0027
		chiffre.outline_size = 0
		chiffre.modulate = Color(0.1, 0.06, 0.03)
		chiffre.shaded = false
		chiffre.double_sided = false
		chiffre.position = Vector3(sin(phi), cos(phi), 0) * (RAYON_CADRAN - 0.15) + Vector3(0, 0, 0.062)
		face.add_child(chiffre)
		v += pas
	# L'aiguille : une longue lame rouge, un contrepoids, un axe de laiton.
	var aiguille := Node3D.new()
	aiguille.position.z = 0.066
	face.add_child(aiguille)
	var rouge := matiere("flamme", 1.0, Color(0.75, 0.1, 0.06), Color(0.25, 0.02, 0.0))
	var lame := _boite(Vector3(0.024, RAYON_CADRAN - 0.07, 0.006), rouge)
	lame.position.y = (RAYON_CADRAN - 0.07) * 0.5 - 0.04
	aiguille.add_child(lame)
	var queue := _boite(Vector3(0.026, 0.08, 0.006), rouge)
	queue.position.y = -0.08
	aiguille.add_child(queue)
	var axe := _cylindre(0.028, 0.02, _laiton)
	axe.rotation.x = PI / 2
	axe.position.z = 0.012
	aiguille.add_child(axe)
	# Le cuir clos : une plaque de cuir cloutée, pour tous ceux que le cadran ne regarde pas.
	var couvercle := Node3D.new()
	n.add_child(couvercle)
	var cuir := _cylindre(RAYON_CADRAN, 0.02, _cuir)
	cuir.rotation.x = PI / 2
	cuir.position.z = 0.06
	couvercle.add_child(cuir)
	for i in 12:
		var a := TAU * i / 12.0
		var clou := _sphere(0.014, _laiton)
		clou.position = Vector3(sin(a), cos(a), 0) * (RAYON_CADRAN - 0.04) + Vector3(0, 0, 0.072)
		couvercle.add_child(clou)
	var ficelle := _debout("?", 90, Vector3(0, 0, 0.074))
	ficelle.modulate = Color(0.85, 0.7, 0.45)
	couvercle.add_child(ficelle)
	# Le crochet qui le pend au bout du bras.
	var crochet := _cylindre(0.012, 0.28, _laiton)
	crochet.position = Vector3(0, RAYON_CADRAN + 0.12, -0.03)
	n.add_child(crochet)
	return {"n": n, "aiguille": aiguille, "couvercle": couvercle, "face": face, "max": maximum}


## L'angle (horaire depuis le haut) d'une proportion 0..1 du cadran : de -135° à +135°.
static func _phi(f: float) -> float:
	return deg_to_rad(-135.0 + 270.0 * clampf(f, 0.0, 1.0))


## La graduation : un trait par unité, plus long toutes les deux, en un seul maillage de petits rectangles.
func _graduation(maximum: int) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in maximum + 1:
		var phi := _phi(float(v) / maximum)
		var long := 0.09 if v % 2 == 0 else 0.05
		var largeur := 0.009 if v % 2 == 0 else 0.005
		var r1 := RAYON_CADRAN - 0.035
		var r0 := r1 - long
		var d := Vector3(sin(phi), cos(phi), 0)
		var p := Vector3(cos(phi), -sin(phi), 0) * largeur
		var z := Vector3(0, 0, 0.0585)
		var a := d * r0 - p + z
		var b := d * r0 + p + z
		var c := d * r1 + p + z
		var e := d * r1 - p + z
		for q: Vector3 in [a, b, c, a, c, e]:
			st.set_normal(Vector3(0, 0, 1))
			st.add_vertex(q)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.06, 0.03)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi


# ---------------------------------------------------------------- les poids

func objet_prise(d: Dictionary) -> Node3D:
	var x: Dictionary = d.get("x", {})
	var t := float(x.get("t", 0.15))
	var n := Node3D.new()
	var styles := int(x.get("s", 0))
	if bool(x.get("cai", false)):
		var c := _sphere(0.04, matiere("pierre", 3.0, Color(0.8, 0.8, 0.78)))
		c.scale = Vector3(1.25, 0.7, 1.0)
		c.position.y = 0.03
		n.add_child(c)
		_objets[int(d["i"])] = {"w": 1.0, "n": n}
		return n
	var haut := t * 0.52
	match styles:
		0:
			# Un lingot de fonte : une base large, un dessus plus étroit, un anneau pour le saisir.
			var corps := _cylindre(t * 0.52, haut, _fer, t * 0.4)
			corps.position.y = haut * 0.5
			corps.scale = Vector3(1.0, 1.0, 0.72)
			n.add_child(corps)
			var anse := anneau(t * 0.17, 0.008, _fer, n)
			anse.rotation.x = PI / 2
			anse.position.y = haut + t * 0.1
		1:
			# Un poids rond de laiton, à bouton.
			var base := _cylindre(t * 0.42, haut, _laiton, t * 0.3)
			base.position.y = haut * 0.5
			n.add_child(base)
			var bouton := _sphere(t * 0.14, _laiton)
			bouton.position.y = haut + t * 0.1
			n.add_child(bouton)
		_:
			# Une pierre ronde, polie.
			var pierre := _sphere(t * 0.5, matiere("pierre", 1.6, Color(0.85, 0.85, 0.82)))
			pierre.scale = Vector3(1.05, 0.62, 0.9)
			pierre.position.y = t * 0.31
			n.add_child(pierre)
			haut = t * 0.62
	if int(x.get("v", -1)) > 0:
		var chiffre := _grave(str(int(x["v"])), 30, Vector3(0, haut + 0.004, 0))
		chiffre.font = ThemeDB.fallback_font
		chiffre.pixel_size = 0.0021
		chiffre.modulate = Color(1.0, 0.92, 0.7) if styles != 1 else Color(0.2, 0.1, 0.02)
		chiffre.outline_size = 6
		chiffre.shaded = false
		n.add_child(chiffre)
	_objets[int(d["i"])] = {"w": float(x.get("w", 1)), "n": n}
	return n


func nom_prise(d: Dictionary) -> String:
	var x: Dictionary = d.get("x", {})
	if bool(x.get("cai", false)):
		return Langue.t("ton caillou")
	return Langue.t("un poids") if int(x.get("v", -1)) < 0 else Langue.t("le poids de %d") % int(x["v"])


func cible_prise(d: Dictionary) -> Node3D:
	# Le plateau luit quand on porte un poids : un anneau ambré sur son rebord.
	var r := float((d.get("x", {}) as Dictionary).get("r", 0.5))
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = r * 0.93
	t.outer_radius = r * 1.02
	mi.mesh = t
	mi.scale = Vector3(1, 0.25, 1)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.78, 0.4, 0.7)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.7, 0.3)
	m.emission_energy_multiplier = 1.6
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position.y = 0.03
	return mi


## Jusqu'où je vise : les plateaux sont au centre, parfois à l'autre bout du cercle des joueurs.
func portee() -> float:
	return 5.8


## Où se tient le rang-ième objet d'un plateau : sur le plateau, qui penche (rang -1 : son centre).
func pos_prise(c: Dictionary, rang: int, _o: Dictionary) -> Vector3:
	var p := int((c.get("x", {}) as Dictionary).get("p", 0))
	if p >= _plats.size():
		return Vector3(c["pos"])
	var plat: Node3D = _plats[p]
	if rang < 0:
		return plat.transform * Vector3(0, 0.05, 0)
	return plat.transform * (Dispositions.place_plat(rang) + Vector3(0, 0.025, 0))


func prise_evenement(quoi: String, d: Dictionary, pos: Vector3) -> void:
	var x: Dictionary = d.get("x", {})
	var a := AudioStreamPlayer3D.new()
	a.stream = Prise.son("metal_pose" if quoi == "pose" else "metal_prend")
	a.bus = "Effets"
	a.unit_size = 6.0
	a.pitch_scale = clampf(1.35 - 0.07 * float(x.get("w", 2)), 0.7, 1.4)
	a.volume_db = -4.0 if quoi == "pose" else -9.0
	a.position = to_local(pos)
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)


# ---------------------------------------------------------------- la vue

func animer(vue: Dictionary, _phase: float, delta: float) -> void:
	_t += delta
	var prise := bloc(vue, "prise")
	if prise.is_empty():
		return
	var cases: Array = prise.get("cibles", [])
	if _nb == 0 and not cases.is_empty():
		_batir(cases.size())
		_total = maxf(float(vue.get("cible", 16)), 1.0)
		var maxi_cadran := int((cases[0]["x"] as Dictionary).get("maximum", 24))
		for p in _nb:
			_remplacer_cadran(p, maxi_cadran)
	if _nb == 0:
		return
	var masses := {}
	for o: Dictionary in prise.get("objets", []):
		masses[int(o["i"])] = float((o["x"] as Dictionary).get("w", 1))
	for c: Dictionary in cases:
		var x: Dictionary = c["x"]
		var p := int(x["p"])
		if p >= _nb:
			continue
		var charge := 0.0
		var cx := 0.0
		var cz := 0.0
		var j := 0
		for o: int in c["o"]:
			var w: float = masses.get(o, 1.0)
			var off := Dispositions.place_plat(j)
			charge += w
			cx += w * off.x
			cz += w * off.z
			j += 1
		# Le bras : sa cible dépend de la charge (la moitié du total : à plat), un ressort le fait rebondir.
		var f := charge / _total
		_charge[p] = f
		var cible := (f - 0.5) * 0.5
		var delta_charge: float = f - float(_charge_prec[p])
		_charge_prec[p] = f
		_vit[p] += delta_charge * 6.0
		_vit[p] += ((cible - _ang[p]) * 70.0 - _vit[p] * 4.2) * delta
		_ang[p] += _vit[p] * delta
		_ang[p] = clampf(_ang[p], -0.34, 0.6)
		(_bras[p] as Node3D).rotation.x = _ang[p]
		# Le plateau pend au bout des chaînes, et penche du côté où l'on a posé.
		var tip: Vector3 = to_local((_bras[p] as Node3D).to_global(Vector3(0, -0.05, LONG_BRAS)))
		var plat: Node3D = _plats[p]
		plat.position = tip - Vector3(0, LONG_CHAINE, 0)
		var dec := Vector2(cx, cz) / maxf(charge, 0.001)
		var force := clampf(charge / (_total * 0.4), 0.0, 1.0)
		plat.rotation.z = lerpf(plat.rotation.z, -clampf(dec.x * 0.9, -0.14, 0.14) * force, minf(delta * 6.0, 1.0))
		plat.rotation.x = lerpf(plat.rotation.x, clampf(dec.y * 0.9, -0.14, 0.14) * force, minf(delta * 6.0, 1.0))
		plat.rotation.y = (_bras[p] as Node3D).get_parent().rotation.y
		_tendre_chaines(p, tip)
		_regler_cadran(p, tip, int(x.get("lecture", -1)), delta)


## Le cadran change d'échelle une fois qu'on la connaît.
func _remplacer_cadran(p: int, maximum: int) -> void:
	if int(_cadrans[p]["max"]) == maximum:
		return
	(_cadrans[p]["n"] as Node3D).queue_free()
	_cadrans[p] = _batir_cadran(maximum)


func _tendre_chaines(p: int, tip: Vector3) -> void:
	var plat: Node3D = _plats[p]
	for c in 3:
		var a := TAU * c / 3.0 + 0.5
		var haut := tip + Vector3(sin(a), 0.0, cos(a)) * 0.05
		var bas := plat.transform * (Vector3(sin(a), 0.0, cos(a)) * 0.47 + Vector3(0, 0.03, 0))
		var liens: Array = _chaines[p][c]
		var d := bas - haut
		var long := d.length()
		if long < 0.01:
			continue
		var dir := d / long
		var ref := Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT
		var perp := dir.cross(ref).normalized()
		var perp2 := dir.cross(perp)
		for i in liens.size():
			var t := (i + 0.5) / liens.size()
			var axe := perp if i % 2 == 0 else perp2
			var autre := dir.cross(axe)
			(liens[i] as Node3D).transform = Transform3D(Basis(dir * (long / liens.size()) * 24.0, axe, autre), haut + d * t)


## Le cadran pend au bout du bras, tourné vers son lecteur ; l'aiguille suit la lecture (avec de l'inertie).
func _regler_cadran(p: int, _tip: Vector3, lecture: int, delta: float) -> void:
	var cd: Dictionary = _cadrans[p]
	var n: Node3D = cd["n"]
	var bout: Vector3 = to_local((_bras[p] as Node3D).to_global(Vector3(0, 0, LONG_BRAS + BOUT + 0.02)))
	var pos := bout - Vector3(0, RAYON_CADRAN + 0.3, 0)
	var lecteur := poste(jeu, p % equipe, equipe) + Vector3(0, 1.6, 0)
	var vers := lecteur - pos
	n.position = pos
	var cible := Basis.looking_at(-vers.normalized(), Vector3.UP)
	n.basis = cible
	var lit := lecture >= 0
	(cd["couvercle"] as Node3D).visible = not lit
	(cd["face"] as Node3D).visible = lit
	if lit:
		var f := float(lecture) / float(cd["max"])
		var vise := _phi(f)
		_aig_v[p] += ((vise - _aig[p]) * 60.0 - _aig_v[p] * 5.0) * delta
		_aig[p] += _aig_v[p] * delta
		_aig[p] = clampf(_aig[p], _phi(0.0) - 0.15, _phi(1.0) + 0.15)
		(cd["aiguille"] as Node3D).rotation.z = -_aig[p]
