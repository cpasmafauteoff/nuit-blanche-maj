class_name Trajets
extends RefCounted
## Les trajets des bots dans la Ronde, sans moteur physique : une suite de points sûrs.
## On passe entre les maisons par les ruelles (à mi-chemin de deux maisons), on contourne
## par le chemin de ronde, on entre et sort des maisons par leurs portes.

static var R_CENTRE := 12.0       # en deçà : la place, on va tout droit
static var R_RUELLE_IN := 12.4
static var R_RUELLE_OUT := 18.4
static var R_CHEMIN := 21.0
static var _places := 13             # maisons + le temple (cf. Ronde.configurer)


static func configurer(ecart: float, places: int) -> void:
	R_CENTRE = 12.0 + ecart
	R_RUELLE_IN = 12.4 + ecart
	R_RUELLE_OUT = 18.4 + ecart
	R_CHEMIN = 21.0 + ecart
	_places = places
const PAS_ANGLE := deg_to_rad(15.0)


## La porte par laquelle on entre dans la maison `m` ou on en sort. Le jour, celle de devant ; la nuit,
## celle de derrière (les loups sortent par là) : sauf si elle est close alors que l'autre est
## ouverte (la porte laissée ouverte pour qui était encore dehors au crépuscule). `ouvertes` : l'état
## des portes publié par l'hôte (« maison:porte » → ouverte).
static func porte_de(_m: int, _nuit: bool, _ouvertes := {}) -> String:
	return "avant"   # une seule porte par maison (01/11) : celle de devant, jour et nuit


## Les portes que le trajet de `depuis` à `vers` franchit, dans l'ordre : [{maison, porte, sortie}].
## Qui part de l'intérieur d'une maison en sort par une porte ; qui doit y entrer y entre par une porte.
## Jamais à travers un mur : le trajet les atteint (cf. chemin), et le marcheur les ouvre si elles sont closes.
static func portes_a_franchir(depuis: Vector3, vers: Vector3, nuit: bool, ouvertes := {}) -> Array[Dictionary]:
	var r: Array[Dictionary] = []
	var m_dep := Ronde.maison_de(depuis)
	var m_arr := Ronde.maison_de(vers)
	if m_dep >= 0 and m_dep == m_arr:
		return r
	if m_dep >= 0:
		r.append({"maison": m_dep, "porte": porte_de(m_dep, nuit, ouvertes), "sortie": true})
	if m_arr >= 0:
		r.append({"maison": m_arr, "porte": porte_de(m_arr, nuit, ouvertes), "sortie": false})
	return r


## Le centre d'une porte, dans le plan du mur.
static func centre_porte(m: int, _porte := "avant") -> Vector3:
	return Ronde._vers_monde(m, Vector3(0, 0, Ronde.PROFONDEUR * 0.5))


## Points de passage de `depuis` à `vers`. `nuit` : on sort et entre par la porte de derrière.
static func chemin(depuis: Vector3, vers: Vector3, nuit: bool, ouvertes := {}) -> Array[Vector3]:
	# Le temple de l'autel est en hauteur : on n'y monte, et on n'en descend, que par ses marches.
	var monte := Ronde.sur_temple(vers)
	if monte != Ronde.sur_temple(depuis):
		var pied := Ronde.pied_marches()
		if monte:
			var r := chemin(depuis, pied, nuit, ouvertes)
			var avant: Vector3 = r[-2] if r.size() >= 2 else depuis
			if _le_long_du_temple(avant):
				r.insert(r.size() - 1, Vector3(avant.x, 0, pied.z - 0.6))
			r.append(Ronde.haut_marches())
			r.append(vers)
			return r
		var r2: Array[Vector3] = [Ronde.haut_marches(), pied]
		var suite := chemin(pied, vers, nuit, ouvertes)
		if not suite.is_empty() and _le_long_du_temple(suite[0]):
			r2.append(Vector3(suite[0].x, 0, pied.z - 0.6))
		r2.append_array(suite)
		return r2
	var pts: Array[Vector3] = []
	var m_dep := Ronde.maison_de(depuis)
	var m_arr := Ronde.maison_de(vers)
	# Dans la même maison : on y reste (sortir par la porte pour y rentrer serait absurde).
	if m_dep >= 0 and m_dep == m_arr:
		pts.append(vers)
		return pts
	var a := depuis
	if m_dep >= 0:
		var porte_dep := porte_de(m_dep, nuit, ouvertes)
		pts.append(_seuil(m_dep, porte_dep, true))
		a = Ronde.devant_porte(m_dep, porte_dep)
		pts.append(a)
	var b := vers
	var fin: Array[Vector3] = []
	if m_arr >= 0:
		var porte_arr := porte_de(m_arr, nuit, ouvertes)
		b = Ronde.devant_porte(m_arr, porte_arr)
		fin.append(b)
		fin.append(_seuil(m_arr, porte_arr, true))
		fin.append(vers)
	else:
		fin.append(vers)
	pts.append_array(_dehors(a, b))
	pts = _contourner_tableau(a, pts)
	for p in fin:
		if pts.is_empty() or pts[-1].distance_to(p) > 0.05:
			pts.append(p)
	return pts


## Arrivé par la ruelle voisine, on longe le temple : on rejoint le pied des marches de face, en
## descendant d'abord vers la place (sinon on coupe par les marches et leurs limons).
static func _le_long_du_temple(p: Vector3) -> bool:
	var l := p - Ronde.centre_temple()
	var pied := Ronde.pied_marches() - Ronde.centre_temple()
	return absf(l.x) > Ronde.MARCHES_LARGE * 0.5 and absf(l.x) < Ronde.TEMPLE_LARGE * 0.5 + 3.0 and l.z > pied.z - 0.3


## Le tableau des quêtes est un mur de bois de 6,9 m au bord de la place : un pas qui le traverse
## en fait le tour par le bout le plus court (devant, puis derrière).
static func _contourner_tableau(depuis: Vector3, pts: Array[Vector3]) -> Array[Vector3]:
	if pts.is_empty():
		return pts
	var c := (-Ronde.TABLEAU).normalized()
	var axe := Vector3.UP.cross(c)
	var bouts: Array[Vector3] = [Ronde.TABLEAU + axe * -3.75, Ronde.TABLEAU + axe * 3.75]
	var de := depuis
	for i in pts.size():
		var vers := pts[i]
		if Geometry2D.segment_intersects_segment(Vector2(de.x, de.z), Vector2(vers.x, vers.z),
				Vector2(bouts[0].x, bouts[0].z), Vector2(bouts[1].x, bouts[1].z)) != null:
			var meilleur := bouts[0]
			if de.distance_to(bouts[1]) + bouts[1].distance_to(vers) < de.distance_to(bouts[0]) + bouts[0].distance_to(vers):
				meilleur = bouts[1]
			var devant := c if (de - Ronde.TABLEAU).dot(c) > 0.0 else -c
			var r: Array[Vector3] = pts.slice(0, i)
			r.append(meilleur + devant * 0.9)
			r.append(meilleur - devant * 0.9)
			r.append_array(pts.slice(i))
			return r
		de = vers
	return pts


## Juste à l'intérieur de la porte.
static func _seuil(i: int, porte: String, dedans: bool) -> Vector3:
	var z := Ronde.PROFONDEUR * 0.5 - (0.6 if dedans else -0.6)
	return Ronde._vers_monde(i, Vector3(0, 0, z if porte == "avant" else -z))


static func _r(p: Vector3) -> float:
	return Vector2(p.x, p.z).length()


static func _angle(p: Vector3) -> float:
	return atan2(p.x, p.z)


static func _sur_cercle(angle: float, r: float) -> Vector3:
	return Vector3(sin(angle), 0, cos(angle)) * r


## Angle de la ruelle la plus proche (entre deux maisons).
static func _ruelle(angle: float) -> float:
	var pas := TAU / _places
	return (floor(angle / pas) + 0.5) * pas if fposmod(angle, pas) > 0.0 else angle + pas * 0.5


## Trajet entre deux points hors des maisons.
static func _dehors(a: Vector3, b: Vector3) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var ra := _r(a)
	var rb := _r(b)
	var a_dedans := ra < R_CENTRE
	var b_dedans := rb < R_CENTRE
	# Les deux du même côté de l'anneau des maisons, côté place : tout droit.
	if a_dedans and b_dedans:
		pts.append(b)
		return pts
	if a_dedans != b_dedans:
		var exterieur := b if a_dedans else a
		var g := _ruelle(_angle(exterieur))
		var traverse: Array[Vector3] = [_sur_cercle(g, R_RUELLE_IN), _sur_cercle(g, R_RUELLE_OUT)]
		if not a_dedans:
			traverse.reverse()
			# Dehors → place : rejoindre d'abord le haut de la ruelle par le chemin de ronde.
			pts.append_array(_le_long(a, _sur_cercle(g, R_RUELLE_OUT)))
			pts.append(traverse[1])
			pts.append(b)
			return pts
		pts.append_array(traverse)
		pts.append_array(_le_long(traverse[1], b))
		return pts
	pts.append_array(_le_long(a, b))
	return pts


## Le long du chemin de ronde, par le plus court côté, à pas de 15°.
static func _le_long(a: Vector3, b: Vector3) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var a0 := _angle(a)
	var a1 := _angle(b)
	var d := wrapf(a1 - a0, -PI, PI)
	var n := int(absf(d) / PAS_ANGLE)
	if _r(a) < Ronde.R_CHEMIN_MIN or _r(a) > Ronde.R_CHEMIN_MAX:
		pts.append(_sur_cercle(a0, R_CHEMIN))
	for k in range(1, n + 1):
		pts.append(_sur_cercle(a0 + d * k / float(n + 1), R_CHEMIN))
	if _r(b) < Ronde.R_CHEMIN_MIN or _r(b) > Ronde.R_CHEMIN_MAX:
		pts.append(_sur_cercle(a1, R_CHEMIN))
	pts.append(b)
	return pts
