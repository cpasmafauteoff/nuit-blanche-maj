class_name MainTenue
extends RefCounted
## Ma main et mon avant-bras, vus de mes yeux, qui tiennent l'objet en main. Même matière que la peau du
## corps (Bouille, `_mat(peau, 0.7)`) et même manche : la main n'est plus une boule d'une autre matière
## (Edwin, 01/11). Deux dispositions : `generique` (caillou, plume : la paume dessous, les doigts par-dessus)
## et `livre` (carnet, page : le pouce sur la couverture, les doigts DERRIÈRE, jamais dans le papier).

const COUDE := Vector3(0.5, -0.45, 0.75)   # de la main vers le coude, dans le repère de mes yeux


## Une main prête à poser. `peau` : couleur de peau du joueur ; `manche` : couleur de sa manche.
static func creer(peau: Color, manche: Color) -> Node3D:
	var racine := Node3D.new()
	racine.name = "MainTenue"
	var m_peau := StandardMaterial3D.new()
	m_peau.albedo_color = peau
	m_peau.roughness = 0.7
	var m_manche := StandardMaterial3D.new()
	m_manche.albedo_color = manche
	m_manche.roughness = 0.9
	var nu := CylinderMesh.new()
	nu.top_radius = 0.034
	nu.bottom_radius = 0.04
	nu.height = 0.06
	_piece(racine, "nu", nu, m_peau)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.046
	cm.bottom_radius = 0.058
	cm.height = 0.32
	_piece(racine, "manche", cm, m_manche)
	for nom: String in ["paume", "doigt0", "doigt1", "doigt2", "doigt3", "pouce", "racine_pouce"]:
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 20
		s.rings = 10
		_piece(racine, nom, s, m_peau)
	return racine


static func _piece(racine: Node3D, nom: String, mesh: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(mi)


## Une sphère aplatie d'un rayon donné (x, y, z en mètres : les demi-axes).
static func _ellipse(racine: Node3D, nom: String, centre: Vector3, demi: Vector3, basis := Basis.IDENTITY) -> void:
	var mi := racine.get_node(nom) as MeshInstance3D
	mi.transform = Transform3D(basis * Basis.from_scale(demi * 2.0), centre)
	mi.visible = true


static func _cacher(racine: Node3D, noms: Array) -> void:
	for n: String in noms:
		(racine.get_node(n) as Node3D).visible = false


## L'avant-bras de `depart` vers le coude (direction `d`, dans le repère de la racine).
static func _avant_bras(racine: Node3D, depart: Vector3, d: Vector3) -> void:
	d = d.normalized()
	var b := Basis(Quaternion(Vector3.UP, d))
	(racine.get_node("nu") as Node3D).transform = Transform3D(b, depart + d * 0.03)
	(racine.get_node("manche") as Node3D).transform = Transform3D(b, depart + d * 0.22)


## Caillou, plume : la paume sous l'objet, les doigts qui l'enroulent, le pouce dessus.
## `objet_pos` : où est l'objet dans mes mains ; repère de la racine = repère de mes mains.
static func generique(racine: Node3D, objet_pos: Vector3) -> void:
	var coude := COUDE.normalized()
	var b := Basis.looking_at(-coude, Vector3.UP)
	# Le centre du caillou (son nœud a le corps à 3 cm au-dessus de l'origine, une fois réduit) tombe sur `c`,
	# dans le repère de la racine : la prise est calée dessus, quelle que soit l'orientation du bras.
	var c := Vector3(0.0, 0.045, -0.02)
	racine.transform = Transform3D(b, objet_pos + Vector3(0.0, 0.03, 0.0) - b * c)
	_cacher(racine, ["racine_pouce"])
	(racine.get_node("nu") as Node3D).visible = true
	(racine.get_node("manche") as Node3D).visible = true
	# Repère de la racine : l'avant-bras part vers +Z (le coude), les doigts vont vers -Z.
	var nu := racine.get_node("nu") as Node3D
	nu.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, 0.05))
	var ma := racine.get_node("manche") as Node3D
	ma.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, 0.21))
	# Une vraie prise (Edwin, 01/11 : « la main ne paraît pas du tout naturelle ») : le caillou repose dans la
	# paume creuse, les quatre doigts le contournent par devant et par-dessus, le pouce le tient sur le côté.
	_ellipse(racine, "paume", Vector3(0.0, 0.0, 0.03), Vector3(0.05, 0.03, 0.055))
	var longueur := [0.028, 0.034, 0.034, 0.027]
	for d in 4:
		var x := (d - 1.5) * 0.023
		var pos := c + Vector3(x, 0.046, -0.03 + absf(d - 1.5) * 0.006)
		var inclinaison := Basis(Vector3.RIGHT, 1.85) * Basis(Vector3.UP, -x * 3.0)
		_ellipse(racine, "doigt%d" % d, pos, Vector3(0.0115, 0.0115, longueur[d]), inclinaison)
	var pouce := Basis(Vector3.UP, -0.7) * Basis(Vector3.RIGHT, 0.35)
	_ellipse(racine, "pouce", c + Vector3(-0.056, 0.012, -0.012), Vector3(0.014, 0.014, 0.034), pouce)


## Carnet (fermé ou ouvert) ou page : tenu par son bord du bas, le pouce posé sur la face qui me regarde,
## la paume et les doigts derrière (le papier ne traverse jamais la chair). `objet` : le nœud en main
## (dans mes mains) ; `ouvert` : le carnet ouvert (la prise est sur la page de droite).
static func livre(racine: Node3D, objet: Node3D, ouvert: bool, epais: float) -> void:
	var s := objet.scale.x
	var b := objet.basis.orthonormalized()
	racine.transform = Transform3D(b, objet.position)
	_cacher(racine, [])
	var x0 := 0.075 if ouvert else 0.04         # la prise : la moitié droite du carnet
	var bas := 0.105                            # le bord du bas (z local), demi-hauteur d'une couverture
	var devant := epais + 0.012                 # sur la face qui me regarde
	var derriere := -0.03
	# Le coude, dans le repère de l'objet.
	var d := (b.inverse() * COUDE.normalized()).normalized()
	var paume := Vector3(x0, derriere, bas - 0.01) * s
	_ellipse(racine, "paume", paume, Vector3(0.05, 0.025, 0.055))
	_avant_bras(racine, paume + d * 0.03, d)
	# Les quatre doigts : derrière, ils filent vers le dos du carnet ; on n'en voit que le bout, qui dépasse
	# du côté du pli.
	for k in 4:
		var pos := Vector3(x0 - 0.036 + k * 0.021, derriere - 0.004, bas - 0.045) * s
		_ellipse(racine, "doigt%d" % k, pos, Vector3(0.0105, 0.0105, 0.04))
	# Le pouce : sa racine passe par le bord du bas, puis il repose à plat sur la couverture.
	_ellipse(racine, "racine_pouce", Vector3(x0 + 0.03, epais * 0.5, bas + 0.003) * s, Vector3(0.016, 0.02, 0.02))
	_ellipse(racine, "pouce", Vector3(x0 + 0.02, devant, bas - 0.035) * s, Vector3(0.0125, 0.008, 0.04))
