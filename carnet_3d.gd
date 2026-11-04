class_name Carnet3D
extends RefCounted
## Le carnet en volume, tel qu'on le voit dans une main (la tienne ou celle d'un autre) ou posé :
## fermé (couverture de cuir, dos bombé, coins de laiton, sangle et fermoir, tranche des pages),
## ouvert (deux pages réglées, l'écriture lisible, le ruban, la plume dans le pli) et la plume.
## Repère : le dos est du côté -X, la couverture « dessus » regarde +Y, la longueur court sur Z.
## Construit par vue_objets.gd ; les matières viennent de monde/style_carnet.gd.

const L := 0.15          # largeur d'une couverture
const LONG := 0.21       # hauteur d'une couverture
const EPAIS := 0.036     # épaisseur du carnet fermé
const PAGE_L := 0.14
const PAGE_LONG := 0.2


static func _boite(taille: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = m
	return mi


static func _cyl(r_haut: float, r_bas: float, h: float, m: Material, pos: Vector3, rot := Vector3.ZERO, segments := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_haut
	c.bottom_radius = r_bas
	c.height = h
	c.radial_segments = segments
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	return mi


static func _couleur_bandeau(h: Array) -> Variant:
	if h.size() > 1 and int(h[1]) >= 0 and int(h[1]) < Bouille.BANDEAUX.size():
		return Bouille.BANDEAUX[int(h[1])][0]
	return null


static func _tissu(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	m.emission_enabled = true
	m.emission = c * 0.12
	return m


## Le carnet fermé. `h` : [pseudo, bandeau] de son habitant.
static func ferme(h: Array) -> Node3D:
	var n := Node3D.new()
	var cuir := StyleCarnet.materiau_cuir()
	var cuir_fonce := StyleCarnet.materiau_cuir(Color(0.62, 0.55, 0.5))
	var laiton := StyleCarnet.materiau_laiton()
	var haut := EPAIS - 0.0015
	# Les deux plats de couverture (un peu plus grands que les pages : la « chasse »).
	for y: float in [0.0, EPAIS - 0.003]:
		var plat := _boite(Vector3(L, 0.0034, LONG), cuir)
		plat.position = Vector3(0.0, y, 0.0)
		n.add_child(plat)
	# Le bloc de pages, creux côté reliure, tranche visible sur trois côtés.
	var pages := _boite(Vector3(0.138, EPAIS - 0.006, 0.2), StyleCarnet.materiau_tranche())
	pages.position = Vector3(0.0045, (EPAIS - 0.003) * 0.5, 0.0)
	n.add_child(pages)
	# Le dos : un demi-cylindre bombé, avec ses nerfs.
	n.add_child(_cyl(EPAIS * 0.52, EPAIS * 0.52, LONG, cuir, Vector3(-L * 0.5 + 0.002, (EPAIS - 0.003) * 0.5, 0.0), Vector3(PI / 2, 0, 0), 20))
	for z: float in [-0.075, -0.025, 0.025, 0.075]:
		n.add_child(_cyl(EPAIS * 0.545, EPAIS * 0.545, 0.0045, cuir_fonce, Vector3(-L * 0.5 + 0.002, (EPAIS - 0.003) * 0.5, z), Vector3(PI / 2, 0, 0), 20))
	# Filet gaufré sur la couverture : un cadre en léger relief.
	var y_cadre := EPAIS - 0.003 + 0.0017 + 0.0003
	for cote: float in [-1.0, 1.0]:
		var l := _boite(Vector3(0.108, 0.0007, 0.0012), cuir_fonce)
		l.position = Vector3(0.007, y_cadre, cote * 0.085)
		n.add_child(l)
		var c := _boite(Vector3(0.0012, 0.0007, 0.17), cuir_fonce)
		c.position = Vector3(0.007 + cote * 0.054, y_cadre, 0.0)
		n.add_child(c)
	# Coins de laiton sur la couverture (côté fermoir) et au dos.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var coin := _boite(Vector3(0.02, 0.0012, 0.02), laiton)
			coin.position = Vector3(sx * (L * 0.5 - 0.0095) + 0.001, EPAIS - 0.003 + 0.0017 + 0.0006, sz * (LONG * 0.5 - 0.0095))
			n.add_child(coin)
			var rivet := _cyl(0.0022, 0.0022, 0.0016, laiton, coin.position + Vector3(0, 0.0007, 0), Vector3.ZERO, 8)
			n.add_child(rivet)
	# Le fermoir : une sangle qui passe par-dessus le bord extérieur, bouclée sur la couverture.
	var sangle := _boite(Vector3(0.05, 0.0013, 0.022), cuir_fonce)
	sangle.position = Vector3(L * 0.5 - 0.027, EPAIS - 0.003 + 0.0017 + 0.0008, 0.0)
	n.add_child(sangle)
	var tranche_s := _boite(Vector3(0.0013, EPAIS - 0.001, 0.022), cuir_fonce)
	tranche_s.position = Vector3(L * 0.5 + 0.0008, (EPAIS - 0.003) * 0.5, 0.0)
	n.add_child(tranche_s)
	var boucle := _boite(Vector3(0.014, 0.0022, 0.028), laiton)
	boucle.position = Vector3(L * 0.5 - 0.053, EPAIS - 0.003 + 0.0017 + 0.0016, 0.0)
	n.add_child(boucle)
	var ardillon := _boite(Vector3(0.006, 0.0018, 0.004), cuir_fonce)
	ardillon.position = boucle.position + Vector3(0.0, 0.0006, 0.0)
	n.add_child(ardillon)
	# Le carnet de qui : un bandeau d'étoffe à sa couleur autour de la couverture.
	var coul: Variant = _couleur_bandeau(h)
	if coul != null:
		var tissu := _tissu(coul)
		var z_b := -0.07
		var haut_b := EPAIS - 0.003 + 0.0017 + 0.0004
		var dessus := _boite(Vector3(L * 0.5 + 0.004, 0.0014, 0.014), tissu)
		dessus.position = Vector3(0.0715 - (L * 0.5 + 0.004) * 0.5 + 0.0035, haut_b + 0.0002, z_b)
		n.add_child(dessus)
		var bord := _boite(Vector3(0.0016, EPAIS, 0.014), tissu)
		bord.position = Vector3(L * 0.5 + 0.0018, (EPAIS - 0.003) * 0.5, z_b)
		n.add_child(bord)
		# Le signet : un ruban qui dépasse en bas des pages.
		var signet := _boite(Vector3(0.011, 0.0008, 0.034), tissu)
		signet.position = Vector3(0.03, EPAIS * 0.5, LONG * 0.5 + 0.012)
		signet.rotation.y = 0.08
		n.add_child(signet)
	# Le nom sur la couverture, à l'encre dorée, sur une plaque de cuir sombre.
	if h.size() > 0 and str(h[0]) != "":
		var plaque := _boite(Vector3(0.1, 0.0008, 0.044), cuir_fonce)
		plaque.position = Vector3(0.006, EPAIS - 0.003 + 0.0017 + 0.0005, 0.0)
		n.add_child(plaque)
		var l := Label3D.new()
		l.text = str(h[0])
		l.font = Style.police("titre")
		l.font_size = 64
		l.outline_size = 6
		l.modulate = Color(0.96, 0.82, 0.48)
		l.outline_modulate = Color(0.12, 0.06, 0.02)
		# Un long pseudo rapetisse pour tenir sur la plaque (~9 cm).
		l.pixel_size = minf(0.00052, 0.09 / (maxf(str(h[0]).length(), 1.0) * 38.0))
		l.rotation = Vector3(-PI / 2, 0, 0)
		l.position = Vector3(0.006, haut + 0.0014 + 0.0016, 0.0)
		l.double_sided = false
		n.add_child(l)
	# La plume, posée le long du dos sur la couverture.
	var plume := stylo()
	plume.position = Vector3(-0.047, EPAIS + 0.0015, 0.006)
	plume.rotation = Vector3(PI / 2, 0, 0.05)
	n.add_child(plume)
	return n


## Une plume d'oie : tuyau, nœud d'encre, barbes en deux ailes. Axe Y, la pointe vers -Y, ~13 cm.
static func stylo() -> Node3D:
	var s := Node3D.new()
	var os := StandardMaterial3D.new()
	os.albedo_color = Color(0.9, 0.86, 0.74)
	os.roughness = 0.6
	var encre := StandardMaterial3D.new()
	encre.albedo_color = Color(0.07, 0.04, 0.04)
	encre.roughness = 0.35
	var barbe := StandardMaterial3D.new()
	barbe.albedo_color = Color(0.93, 0.9, 0.82)
	barbe.roughness = 0.9
	barbe.cull_mode = BaseMaterial3D.CULL_DISABLED
	var barbe_fonce := StandardMaterial3D.new()
	barbe_fonce.albedo_color = Color(0.5, 0.43, 0.36)
	barbe_fonce.roughness = 0.9
	barbe_fonce.cull_mode = BaseMaterial3D.CULL_DISABLED
	s.add_child(_cyl(0.0017, 0.0012, 0.05, os, Vector3(0, -0.005, 0), Vector3.ZERO, 8))                    # le tuyau
	s.add_child(_cyl(0.0012, 0.0002, 0.014, encre, Vector3(0, -0.037, 0), Vector3.ZERO, 8))                # la pointe
	s.add_child(_cyl(0.0012, 0.0012, 0.015, os, Vector3(0, -0.026, 0), Vector3.ZERO, 8))
	s.add_child(_cyl(0.0007, 0.0004, 0.092, os, Vector3(0, 0.054, 0), Vector3.ZERO, 6))                    # la tige dans les barbes
	# Les deux ailes de la plume : des ellipses très plates, un peu décalées et inclinées.
	var aile_g := _aile(barbe, 0.0)
	aile_g.position = Vector3(-0.0065, 0.056, 0.0)
	aile_g.rotation.z = 0.1
	s.add_child(aile_g)
	var aile_d := _aile(barbe, 0.0)
	aile_d.position = Vector3(0.0075, 0.052, 0.0)
	aile_d.rotation.z = -0.13
	aile_d.scale *= Vector3(1.0, 0.92, 1.0)
	s.add_child(aile_d)
	var bout := _aile(barbe_fonce, 0.0)
	bout.position = Vector3(0.0, 0.088, 0.0)
	bout.scale *= Vector3(0.55, 0.3, 1.0)
	s.add_child(bout)
	return s


static func _aile(m: Material, _x: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.5
	sp.height = 1.0
	sp.radial_segments = 14
	sp.rings = 8
	mi.mesh = sp
	mi.material_override = m
	mi.scale = Vector3(0.017, 0.092, 0.0012)
	return mi


## Le carnet OUVERT : deux demi-livres, les pages vers le haut, le ruban dans le pli, la plume
## qui repose au milieu. `o` : l'objet (pages, texte). `h` : [pseudo, bandeau].
static func ouvert(o: Dictionary, h: Array) -> Node3D:
	var n := Node3D.new()
	var cuir := StyleCarnet.materiau_cuir()
	var cuir_fonce := StyleCarnet.materiau_cuir(Color(0.62, 0.55, 0.5))
	var textes: Array[Label3D] = []
	for cote: float in [-1.0, 1.0]:
		var plat := _boite(Vector3(L, 0.0034, LONG), cuir)
		plat.position = Vector3(cote * 0.0775, 0.0, 0.0)
		n.add_child(plat)
		# Le bloc de pages penche vers le pli : il est plus haut au bord extérieur.
		var pivot := Node3D.new()
		pivot.position = Vector3(cote * 0.004, 0.0017, 0.0)
		pivot.rotation.z = cote * 0.055
		n.add_child(pivot)
		var bloc := _boite(Vector3(PAGE_L, 0.012, 0.2), StyleCarnet.materiau_tranche())
		bloc.position = Vector3(cote * 0.073, 0.006, 0.0)
		pivot.add_child(bloc)
		# Quelques feuilles qui dépassent un peu, pour casser la régularité du bloc.
		for k in 2:
			var f := _boite(Vector3(PAGE_L - 0.004 * (k + 1), 0.0009, 0.2 - 0.003 * (k + 1)), StyleCarnet.materiau_papier(true, int(cote)))
			f.position = Vector3(cote * (0.073 + 0.0015 * (k + 1)), 0.0122 + k * 0.0004, 0.0)
			pivot.add_child(f)
		var feuille := _boite(Vector3(PAGE_L - 0.006, 0.0012, 0.196), StyleCarnet.materiau_papier(true, int(cote)))
		feuille.position = Vector3(cote * 0.0715, 0.0128, 0.0)
		pivot.add_child(feuille)
		# L'écriture de la page, lisible.
		var l := Label3D.new()
		l.font = Style.police("italique")
		l.font_size = 32
		l.modulate = Color(0.13, 0.08, 0.06)
		l.outline_size = 0
		l.double_sided = false
		l.shaded = true
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.rotation = Vector3(-PI / 2, 0, 0)
		l.position = Vector3(cote * 0.073 - 0.055, 0.0138, -0.0755)
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		pivot.add_child(l)
		textes.append(l)
	# Le dos, sous le pli.
	n.add_child(_cyl(0.0095, 0.0095, LONG, cuir, Vector3(0, -0.001, 0), Vector3(PI / 2, 0, 0), 14))
	# Le ruban dans le pli, qui retombe en bas.
	var coul: Variant = _couleur_bandeau(h)
	if coul != null:
		var ruban := _boite(Vector3(0.0075, 0.0007, 0.15), _tissu(coul))
		ruban.position = Vector3(0.0, 0.0125, 0.075 + 0.0)
		n.add_child(ruban)
		var queue := _boite(Vector3(0.0075, 0.0007, 0.02), _tissu(coul))
		queue.position = Vector3(0.0, 0.0125, 0.155)
		queue.rotation.y = 0.12
		n.add_child(queue)
	# La plume dans le pli (animée par vue_objets).
	var plume := stylo()
	plume.position = Vector3(-0.012, 0.03, 0.0)
	plume.rotation = Vector3(0, 0, PI / 2)
	n.add_child(plume)
	n.set_meta("stylo", plume)
	n.set_meta("textes", textes)
	maj_textes(n, o.get("pages", []))
	return n


## Écrit sur les deux pages visibles la dernière page écrite et celle d'avant.
static func maj_textes(n: Node3D, pages: Array) -> void:
	if not n.has_meta("textes"):
		return
	var labels: Array = n.get_meta("textes")
	var r := -1
	for i in pages.size():
		if str(pages[i]) != "":
			r = i
	var gauche := str(pages[r - 1]) if r >= 1 else ""
	var droite := str(pages[r]) if r >= 0 else ""
	_poser_texte(labels[0], gauche)
	_poser_texte(labels[1], droite)


static func _poser_texte(l: Label3D, texte: String) -> void:
	l.text = texte
	l.visible = texte != ""
	if texte == "":
		return
	# Le texte rapetisse pour tenir sur la page (13 lignes de 11 cm de large environ).
	var fs := float(l.font_size)
	var ps := minf(0.00046, sqrt(0.16 * 0.11 / (maxf(texte.length(), 1.0) * 0.5 * fs * fs * 1.25)))
	l.pixel_size = ps
	l.width = 0.11 / ps
	# Une ligne de texte par ligne réglée du papier (1,43 cm) tant que le texte n'a pas dû rapetisser.
	l.line_spacing = 0.0143 / ps - l.font.get_height(l.font_size)


## Une page déchirée, posée ou tenue : une feuille réglée, un peu gondolée, un bord arraché.
static func page(o: Dictionary) -> Node3D:
	var n := Node3D.new()
	var m := StyleCarnet.materiau_papier(true, 0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var f := _boite(Vector3(PAGE_L, 0.0018, PAGE_LONG), m)
	f.position.y = 0.002
	f.rotation.y = 0.12
	n.add_child(f)
	# Le bord arraché : des petits éclats clairs le long du côté gauche.
	var bord := StandardMaterial3D.new()
	bord.albedo_color = Color(0.95, 0.91, 0.8)
	bord.roughness = 1.0
	for k in 9:
		var e := _boite(Vector3(0.004 + (k % 3) * 0.0025, 0.0019, 0.011), bord)
		e.position = Vector3(-PAGE_L * 0.5 + 0.0005 - (k % 2) * 0.0015, 0.0021, -0.09 + k * 0.0225)
		f.add_child(e)
	var texte := str(o.get("texte", ""))
	if texte != "":
		var l := Label3D.new()
		l.font = Style.police("italique")
		l.font_size = 32
		l.modulate = Color(0.13, 0.08, 0.06)
		l.outline_size = 0
		l.double_sided = false
		l.shaded = true
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.rotation = Vector3(-PI / 2, 0, 0)
		l.position = Vector3(-0.057, 0.0022, -0.0775)
		f.add_child(l)
		_poser_texte(l, texte)
	return n
