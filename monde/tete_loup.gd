class_name TeteLoup
extends RefCounted
## La tête de loup sculptée en relief dans la pierre, au fond de l'autel (Edwin, 31/10 : l'ancien
## loup découpé « ne ressemble pas du tout à un loup »). De profil, gueule grande ouverte, crocs,
## oreilles pointues, long museau, crinière hérissée, œil de braise. Faite de couches de pierre
## superposées (la silhouette, puis des plans en retrait) et de petits volumes (crocs, œil, rides).
##
## Le dessin est en 2D, x vers la droite de l'écran, y vers le haut ; le museau pointe à gauche.
## Le relief avance vers -z (vers la place, donc vers celui qui regarde l'autel).

## La silhouette de la tête et de la crinière (mètres, origine au milieu de la tête).
const CONTOUR := [
	# museau long : le bout du nez, puis le dessus qui monte doucement vers le front
	Vector2(-0.62, 0.00), Vector2(-0.58, 0.09), Vector2(-0.44, 0.12), Vector2(-0.28, 0.15), Vector2(-0.16, 0.24),
	Vector2(-0.08, 0.32),
	# les deux oreilles, hautes et pointues
	Vector2(-0.06, 0.38), Vector2(0.00, 0.80), Vector2(0.20, 0.44), Vector2(0.32, 0.74), Vector2(0.40, 0.38),
	# la crinière derrière la tête, en petites touffes
	Vector2(0.52, 0.34), Vector2(0.60, 0.36), Vector2(0.56, 0.22), Vector2(0.70, 0.18), Vector2(0.60, 0.06),
	Vector2(0.72, -0.04), Vector2(0.60, -0.14), Vector2(0.68, -0.28), Vector2(0.52, -0.30), Vector2(0.46, -0.40),
	# la gorge, puis la mâchoire du bas, abaissée (gueule ouverte)
	Vector2(0.30, -0.38), Vector2(0.10, -0.36), Vector2(-0.12, -0.44), Vector2(-0.40, -0.52), Vector2(-0.52, -0.50),
	Vector2(-0.54, -0.41),
	# le dessus de la mâchoire du bas (les crocs du bas y sont plantés), jusqu'au coin de la gueule
	Vector2(-0.42, -0.36), Vector2(-0.20, -0.26), Vector2(0.00, -0.17), Vector2(0.06, -0.10),
	# le dessous de la mâchoire du haut, retour vers le nez
	Vector2(-0.14, -0.10), Vector2(-0.30, -0.08), Vector2(-0.46, -0.06), Vector2(-0.58, -0.03)]

## Le centre visuel du dessin, pour le poser au milieu du médaillon.
const CENTRE := Vector2(0.06, 0.14)


## Construit la tête. `pierre` : la pierre du relief ; `fond` : la pierre sombre du fond (visible
## dans la gueule) ; `braise` : l'œil ; `os` : les crocs. Rend le nœud, à poser au centre du médaillon.
static func construire(pierre: Material, fond: Material, braise: Material, os: Material) -> Node3D:
	var n := Node3D.new()
	var contour := PackedVector2Array()
	for p: Vector2 in CONTOUR:
		contour.append(p - CENTRE)
	# 1) la grande silhouette, puis deux plans plus hauts et en retrait : c'est ce qui fait le relief.
	n.add_child(_extruder(contour, 0.0, 0.08, pierre))
	var cran := 0.0
	var epaisseur := 0.08
	for retrait: float in [0.035, 0.09]:
		var plans: Array = Geometry2D.offset_polygon(contour, -retrait)
		cran += 0.04
		for pl: PackedVector2Array in plans:
			n.add_child(_extruder(pl, 0.0, epaisseur + cran, pierre))
	# 2) l'intérieur des oreilles, creusé en sombre, et le fond de la gueule (le fond affleure déjà
	# par l'ouverture ; on y ajoute un velours plus noir pour qu'elle s'enfonce).
	for oreille: Array in [
			[Vector2(0.00, 0.44), Vector2(0.01, 0.68), Vector2(0.13, 0.46)],
			[Vector2(0.24, 0.46), Vector2(0.31, 0.66), Vector2(0.36, 0.42)]]:
		var tri := PackedVector2Array()
		for p: Vector2 in oreille:
			tri.append(p - CENTRE)
		n.add_child(_extruder(tri, 0.0, 0.13, fond))
	# 3) les crocs : deux grands en haut, deux en bas, plus quelques petites dents.
	_croc(n, Vector2(-0.47, -0.06) - CENTRE, 0.2, 0.042, true, os)
	_croc(n, Vector2(-0.28, -0.08) - CENTRE, 0.13, 0.03, true, os)
	_croc(n, Vector2(-0.12, -0.10) - CENTRE, 0.08, 0.024, true, os)
	_croc(n, Vector2(-0.48, -0.385) - CENTRE, 0.18, 0.04, false, os)
	_croc(n, Vector2(-0.32, -0.32) - CENTRE, 0.12, 0.03, false, os)
	_croc(n, Vector2(-0.17, -0.245) - CENTRE, 0.08, 0.024, false, os)
	# 4) l'œil de braise : une fente oblique sous un arc sourcilier qui le rend mauvais.
	var oeil := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	oeil.mesh = sm
	oeil.material_override = braise
	oeil.scale = Vector3(1.7, 0.7, 0.8)
	oeil.rotation.z = deg_to_rad(-22.0)
	oeil.position = Vector3(-(Vector2(-0.20, 0.18) - CENTRE).x, (Vector2(-0.20, 0.18) - CENTRE).y, -0.2)
	n.add_child(oeil)
	var arcade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, 0.03, 0.06)
	arcade.mesh = bm
	arcade.material_override = fond
	arcade.rotation.z = deg_to_rad(-24.0)
	arcade.position = Vector3(-(Vector2(-0.20, 0.25) - CENTRE).x, (Vector2(-0.20, 0.25) - CENTRE).y, -0.2)
	n.add_child(arcade)
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(1.0, 0.18, 0.06)
	lueur.light_energy = 0.7
	lueur.omni_range = 1.1
	lueur.position = oeil.position + Vector3(0, 0, -0.25)
	n.add_child(lueur)
	# 5) la truffe et les naseaux, les plis du museau, les rainures du poil dans la crinière.
	var truffe := MeshInstance3D.new()
	var tm := SphereMesh.new()
	tm.radius = 0.05
	tm.height = 0.1
	truffe.mesh = tm
	truffe.material_override = fond
	truffe.scale = Vector3(1.0, 0.8, 0.8)
	truffe.position = Vector3(-(Vector2(-0.57, 0.06) - CENTRE).x, (Vector2(-0.57, 0.06) - CENTRE).y, -0.24)
	n.add_child(truffe)
	for pli: Array in [[Vector2(-0.40, 0.04), -8.0, 0.16], [Vector2(-0.33, 0.00), -12.0, 0.18], [Vector2(-0.38, 0.09), 4.0, 0.12]]:
		_rainure(n, pli[0] - CENTRE, pli[1], pli[2], 0.012, fond, -0.165)
	for poil: Array in [
			[Vector2(0.44, 0.22), 160.0, 0.14], [Vector2(0.52, 0.08), 175.0, 0.18], [Vector2(0.48, -0.08), 190.0, 0.16],
			[Vector2(0.38, -0.20), 200.0, 0.16], [Vector2(0.30, 0.14), 150.0, 0.12], [Vector2(0.26, -0.04), 185.0, 0.14],
			[Vector2(0.18, -0.18), 205.0, 0.12], [Vector2(0.10, 0.20), 120.0, 0.10]]:
		_rainure(n, poil[0] - CENTRE, poil[1], poil[2], 0.014, fond, -0.165)
	return n


## Un solide de pierre : le contour `poly` (dessin 2D), de `z0` à `z0 - ep` (vers -z).
static func _extruder(poly: PackedVector2Array, z0: float, ep: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var zf := z0 - ep
	# la face avant : on corrige le sens de chaque triangle (la face avant se lit dans le sens horaire)
	var idx := Geometry2D.triangulate_polygon(poly)
	for t in range(0, idx.size(), 3):
		var a := poly[idx[t]]
		var b := poly[idx[t + 1]]
		var c := poly[idx[t + 2]]
		# vue de l'écran (x vers la droite), un sens horaire s'obtient avec un produit croisé négatif
		if (b - a).cross(c - a) > 0.0:
			var tmp := b
			b = c
			c = tmp
		for q: Vector2 in [a, b, c]:
			st.set_normal(Vector3(0, 0, -1))
			st.add_vertex(Vector3(-q.x, q.y, zf))
	# les flancs
	var aire := 0.0
	for i in poly.size():
		aire += poly[i].cross(poly[(i + 1) % poly.size()])
	for i in poly.size():
		var p := poly[i]
		var s := poly[(i + 1) % poly.size()]
		var d := s - p
		if d.length() < 0.0001:
			continue
		var ext := Vector2(d.y, -d.x).normalized() * (1.0 if aire > 0.0 else -1.0)
		var nor := Vector3(-ext.x, ext.y, 0)
		var v0 := Vector3(-p.x, p.y, z0)
		var v1 := Vector3(-s.x, s.y, z0)
		var v2 := Vector3(-s.x, s.y, zf)
		var v3 := Vector3(-p.x, p.y, zf)
		for v: Vector3 in [v0, v1, v2, v0, v2, v3]:
			st.set_normal(nor)
			st.add_vertex(v)
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	var mat_ds: Material = mat.duplicate()
	if mat_ds is BaseMaterial3D:
		(mat_ds as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat_ds
	return m


## Un croc (cône) planté dans la mâchoire du haut (pointe vers le bas) ou du bas (pointe vers le haut).
static func _croc(parent: Node3D, base: Vector2, longueur: float, rayon: float, vers_le_bas: bool, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.height = longueur
	c.top_radius = rayon if vers_le_bas else 0.0
	c.bottom_radius = 0.0 if vers_le_bas else rayon
	c.radial_segments = 10
	m.mesh = c
	m.material_override = mat
	var dy := -longueur * 0.5 if vers_le_bas else longueur * 0.5
	m.position = Vector3(-base.x, base.y + dy, -0.23)
	m.rotation.z = deg_to_rad(8.0 if vers_le_bas else -8.0)
	parent.add_child(m)


## Une rainure gravée : un petit trait sombre de `longueur` à l'angle `deg` (dessin 2D, 0° vers la droite).
static func _rainure(parent: Node3D, milieu: Vector2, deg: float, longueur: float, epaisseur: float, mat: Material, z: float) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(longueur, epaisseur, 0.02)
	m.mesh = b
	m.material_override = mat
	m.position = Vector3(-milieu.x, milieu.y, z)
	m.rotation.z = -deg_to_rad(deg)
	parent.add_child(m)
