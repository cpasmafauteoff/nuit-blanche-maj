class_name VueObjets
extends Node3D
## Ce qu'on voit des carnets, des pages et des cailloux (cf. regles/objets.gd) : posés sur une table
## ou au sol, dans la main de quelqu'un, ou dans les tiennes, en bas de ta vue. Seul l'objet « en main »
## se voit sur quelqu'un ; ce qui est rangé dans les poches ne se voit pas.

## Donne la Bouille d'un joueur (ou null) : (id) -> Bouille.
var bouille_de: Callable
## Mon identifiant réseau.
var moi := 1
## Où tenir mes objets, à la première personne (enfant de la caméra).
var mes_mains: Node3D
## L'habitant d'une maison : (maison) -> [pseudo, bandeau]. Son carnet porte les deux (Edwin, 30/10 :
## « comme ça ils peuvent se fier à ça s'ils veulent le retrouver »).
var proprietaire: Callable

var _etat := {}                 # id -> objet (copie reçue de l'hôte)
var _noeuds := {}               # id -> Node3D
var _t := 0.0
## Un objet qu'on tenait vient d'être posé : (id, porteur). Principal joue le geste du corps.
signal depose(id: int, porteur: int)
## Les objets qui tombent de la main au sol : id -> {t, depuis, rot} (cf. Depose.arc).
var _chutes := {}
var _porteurs := {}             # joueurs vus avec un objet en main (leur bras est levé)
## L'inclinaison du livre ouvert dans la main des autres (réglée à l'essai).
var rot_ouvert := Vector3(PI / 2, 0, 0)


func maj(etat: Array) -> void:
	var vus := {}
	for o: Dictionary in etat:
		var id: int = o["id"]
		vus[id] = true
		var avant: Dictionary = _etat.get(id, {})
		if not avant.is_empty() and int(avant["porteur"]) >= 0 and bool(avant.get("main", false)) and int(o["porteur"]) == -1:
			depose.emit(id, int(avant["porteur"]))
		_etat[id] = o
		var ecrit: bool = str(o.get("texte", "")) != ""
		var marque := _marque(o)
		if not _noeuds.has(id) or _noeuds[id].get_meta("sorte") != o["sorte"] or _noeuds[id].get_meta("ecrit", false) != ecrit \
				or _noeuds[id].get_meta("marque", "") != marque:
			if _noeuds.has(id):
				(_noeuds[id] as Node3D).queue_free()
			var n: Node3D
			match o["sorte"]:
				"carnet":
					n = _carnet_ouvert(o) if bool(o.get("ouvert", false)) else _carnet(o)
				"caillou":
					n = _caillou(id)
				_:
					n = _page(o)
			n.set_meta("sorte", o["sorte"])
			n.set_meta("ecrit", ecrit)
			n.set_meta("marque", marque)
			_noeuds[id] = n
		_ranger(id)
	for id in _etat.keys():
		if not vus.has(id):
			_etat.erase(id)
			_chutes.erase(id)
			(_noeuds[id] as Node3D).queue_free()
			_noeuds.erase(id)
	_maj_porteurs()


## Les villageois qui tiennent un objet en main lèvent le bras pour le porter (cf. Bouille.tient_objet).
func _maj_porteurs() -> void:
	var tenants := {}
	for id in _etat:
		var o: Dictionary = _etat[id]
		if int(o["porteur"]) >= 0 and bool(o.get("main", false)) and int(o["porteur"]) != moi:
			tenants[int(o["porteur"])] = true
	if bouille_de.is_valid():
		for pid in _porteurs.keys():
			if not tenants.has(pid):
				var b0: Bouille = bouille_de.call(pid)
				if b0:
					b0.tient_objet = false
		for pid in tenants.keys():
			var b: Bouille = bouille_de.call(pid)
			if b:
				b.tient_objet = true
	_porteurs = tenants


## Les bandeaux sont tirés au lancement : les carnets se refont avec la couleur de leur habitant.
func rafraichir() -> void:
	maj(_etat.values())


func objet(id: int) -> Dictionary:
	return _etat.get(id, {})


## Mes quatre emplacements : l'id de l'objet, ou -1.
func mes_slots() -> Array[int]:
	var r: Array[int] = []
	r.resize(Objets.SLOTS)
	r.fill(-1)
	for id in _etat:
		var o: Dictionary = _etat[id]
		if o["porteur"] == moi and int(o.get("slot", -1)) >= 0 and int(o["slot"]) < Objets.SLOTS:
			r[int(o["slot"])] = id
	return r


## Ce que je porte, dans l'ordre des emplacements.
func mes_objets() -> Array[int]:
	var r: Array[int] = []
	for id in mes_slots():
		if id >= 0:
			r.append(id)
	return r


func en_main() -> int:
	for id in _etat:
		if _etat[id]["porteur"] == moi and bool(_etat[id].get("main", false)):
			return id
	return -1


## Le nœud de ce que je tiens (dans `mes_mains`), ou null.
func noeud_en_main() -> Node3D:
	var id := en_main()
	return _noeuds.get(id) as Node3D if id >= 0 else null


## Ce que je tiens : {sorte, ouvert, id} ou {} si rien.
func main_decrite() -> Dictionary:
	var id := en_main()
	if id < 0:
		return {}
	return {"sorte": _etat[id]["sorte"], "ouvert": bool(_etat[id].get("ouvert", false)), "id": id}


## L'objet posé le plus proche du point donné (yeux du joueur), à portée de main, ou -1.
## `voit(position)` écarte ceux qu'on ne voit pas (derrière un mur, une table…).
func proche(pos: Vector3, portee := 1.8, voit := Callable()) -> int:
	var meilleur := -1
	var d_min := portee
	for id in _etat:
		var o: Dictionary = _etat[id]
		if o["porteur"] != -1:
			continue
		var d := (o["pos"] as Vector3).distance_to(pos)
		if d < d_min and (not voit.is_valid() or voit.call(o["pos"])):
			d_min = d
			meilleur = id
	return meilleur


func nom(id: int) -> String:
	var o: Dictionary = _etat.get(id, {})
	if o.is_empty():
		return ""
	if o["sorte"] == "caillou":
		return "un caillou"
	var h := habitant(int(o["maison"]))
	if o["sorte"] == "carnet":
		if h[0] != "":
			return "le carnet de %s" % h[0] + (" (bandeau %s)" % Bouille.nom_bandeau(h[1]) if h[1] >= 0 else "")
		return "le carnet de la maison %s" % Ronde.numero(int(o["maison"]))
	return "une page du carnet de %s" % h[0] if h[0] != "" else "une page déchirée"


## [pseudo, bandeau] de l'habitant de cette maison (["", -1] : personne).
func habitant(maison: int) -> Array:
	if maison < 0 or not proprietaire.is_valid():
		return ["", -1]
	return proprietaire.call(maison)


func _marque(o: Dictionary) -> String:
	if o["sorte"] != "carnet":
		return ""
	var h := habitant(int(o["maison"]))
	var ecrit := false
	for page in (o.get("pages", []) as Array):
		if str(page) != "":
			ecrit = true
	return "%s|%d|%s|%s" % [h[0], h[1], "ouvert" if bool(o.get("ouvert", false)) else "ferme", ecrit]


## Place un objet là où il doit être : posé, dans une main, dans les miennes, ou nulle part (rangé).
func _ranger(id: int) -> void:
	var o: Dictionary = _etat[id]
	var n: Node3D = _noeuds[id]
	var porteur: int = o["porteur"]
	var parent: Node3D = self
	# Rangé dans une poche (ni en main, ni posé) ou en plein vol : on ne le voit pas.
	var cache: bool = porteur == Objets.EN_VOL or (porteur != -1 and not bool(o.get("main", false)))
	n.visible = not cache
	if porteur != -1 and n.has_node("RepereSol"):
		n.get_node("RepereSol").queue_free()      # la feuille de repère ne suit pas l'objet dans une main
	if cache:
		if n.get_parent() != self:
			if n.get_parent():
				n.get_parent().remove_child(n)
			add_child(n)
		return
	if porteur == moi and mes_mains:
		parent = mes_mains
	elif porteur != -1 and bouille_de.is_valid():
		var b: Bouille = bouille_de.call(porteur)
		if b:
			parent = b.main_droite()
	# Il quitte une main pour le sol : il TOMBE de la main (on part de là où elle le tenait), il ne se téléporte pas.
	if parent == self and n.get_parent() != self and n.get_parent() != null and n.is_inside_tree() and n.is_visible_in_tree() 			and o["sorte"] != "" and _chutes.get(id) == null:
		_chutes[id] = {"t": 0.0, "depuis": n.global_position, "rot": n.global_rotation}
	if n.get_parent() != parent:
		if n.get_parent():
			n.get_parent().remove_child(n)
		parent.add_child(n)
	var ouvert: bool = bool(o.get("ouvert", false)) and o["sorte"] == "carnet"
	var caillou: bool = o["sorte"] == "caillou"
	_lueur_retiree(n)
	if parent == self:
		if _chutes.has(id):
			return            # _process le fait tomber, puis le pose à `pos`
		n.position = o["pos"]
		n.rotation = Vector3(0, float(o.get("angle", 0.0)), 0)
		n.scale = Vector3.ONE
		_repere_au_sol(n, o)
	elif parent == mes_mains:
		# Ma main : en bas à droite de la vue (le livre ouvert est plus large, il vient plus au centre).
		if caillou:
			n.position = Vector3(0.2, -0.2, -0.5)
			n.rotation = Vector3.ZERO
			n.scale = Vector3.ONE * 0.5
		elif ouvert:
			n.position = Vector3(0.1, -0.3, -0.5)
			n.rotation = Vector3(1.0, 0.0, 0.0)
			n.scale = Vector3.ONE * 0.9
		else:
			n.position = Vector3(0.24, -0.25, -0.55)
			n.rotation = Vector3(1.15, -0.3, 0)
			n.scale = Vector3.ONE * 0.8
	else:
		n.scale = Vector3.ONE
		if caillou:
			n.position = Vector3(0, -0.02, 0.08)
			n.rotation = Vector3.ZERO
			n.scale = Vector3.ONE * 1.4
		elif ouvert:
			# Le livre ouvert, à plat devant la poitrine, les pages vers le haut.
			n.position = Vector3(0.02, 0.0, 0.1)
			n.rotation = rot_ouvert
		else:
			n.position = Vector3(0, -0.02, 0.06)
			n.rotation = Vector3(PI / 2, 0, 0)


## Un livre ou une page jetés dehors, sur la terre sombre, se perdaient de vue (Edwin, 01/11 : « le livre disparaît
## quand on le jette »). Posé par terre il repose donc sur une feuille claire, bien visible, sans halo ; sur un
## meuble (table, lit…) il n'en a pas besoin.
func _repere_au_sol(n: Node3D, o: Dictionary) -> void:
	var ancien := n.get_node_or_null("RepereSol")
	var au_sol := Objets.repere_au_sol(str(o["sorte"]), float(o["pos"].y), Ronde.hauteur_sol(o["pos"]))
	if not au_sol:
		if ancien:
			ancien.queue_free()
		return
	n.position.y += 0.03      # les pavés bosselés mangeaient la feuille : le tout repose un peu au-dessus
	if ancien:
		return
	var mi := MeshInstance3D.new()
	mi.name = "RepereSol"
	var b := BoxMesh.new()
	b.size = Vector3(0.3, 0.004, 0.36)
	mi.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.8, 0.62)
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = Color(0.86, 0.8, 0.62) * 0.35
	mi.material_override = m
	mi.position = Vector3(0, -0.016, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)


func _process(delta: float) -> void:
	_faire_tomber(delta)
	# Un porteur peut apparaître après les objets (arrivée, bouille reconstruite) : on range souvent.
	if Engine.get_process_frames() % 20 == 0:
		for id in _etat:
			_ranger(id)
	_t += delta
	for id in _noeuds:
		var nd: Node3D = _noeuds[id]
		if nd.has_meta("stylo"):
			var stylo: Variant = nd.get_meta("stylo")
			if stylo is Node3D and is_instance_valid(stylo):
				_animer_stylo(stylo, bool(_etat[id].get("plume", false)))


## Edwin : un objet posé ou jeté au sol ne s'éclaire pas. On enlève l'ancien halo s'il existe encore.
func _lueur_retiree(n: Node3D) -> void:
	var l := n.get_node_or_null("Lueur")
	if l != null:
		l.queue_free()


## Chaque objet qui tombe : un petit arc de la main au sol, en tournant vers sa pose.
func _faire_tomber(delta: float) -> void:
	for id: int in _chutes.keys():
		var c: Dictionary = _chutes[id]
		var n: Node3D = _noeuds.get(id)
		if n == null or not _etat.has(id) or int(_etat[id]["porteur"]) != -1:
			_chutes.erase(id)
			if n != null and _etat.has(id):
				_ranger(id)
			continue
		c["t"] = float(c["t"]) + delta
		var k := float(c["t"]) / Depose.DUREE_POSE
		var o: Dictionary = _etat[id]
		var a_terre: Vector3 = o["pos"]
		if n.get_parent() != self:
			_chutes.erase(id)
			continue
		n.global_position = Depose.arc(c["depuis"], a_terre, k)
		var fin_rot := Vector3(0, float(o.get("angle", 0.0)), 0)
		n.rotation = (c["rot"] as Vector3).lerp(fin_rot, smoothstep(0.0, 1.0, clampf(k, 0.0, 1.0)))
		n.scale = Vector3.ONE
		if k >= 1.0:
			_chutes.erase(id)
			_ranger(id)


## Un exemplaire de cet objet, pour le voir voler quand on le jette (null : inconnu).
func apercu(id: int) -> Node3D:
	var o: Dictionary = _etat.get(id, {})
	if o.is_empty():
		return null
	match o["sorte"]:
		"carnet":
			return Carnet3D.ferme(habitant(int(o.get("maison", -1))))
		"caillou":
			return _caillou(id)
	return _page(o)


## Le stylo repose dans le pli ; quand on écrit, il se lève et gribouille sur la page de droite.
func _animer_stylo(stylo: Node3D, ecrit: bool) -> void:
	if not ecrit:
		stylo.position = stylo.position.lerp(Vector3(-0.012, 0.03, 0.0), 0.2)
		stylo.rotation = stylo.rotation.lerp(Vector3(0, 0, PI / 2), 0.2)
		return
	var x := 0.07 + sin(_t * 17.0) * 0.022
	var z := -0.05 + fposmod(_t * 0.9, 1.0) * 0.1 + sin(_t * 9.0) * 0.006
	stylo.position = stylo.position.lerp(Vector3(x, 0.05 + absf(sin(_t * 17.0)) * 0.006, z), 0.45)
	stylo.rotation = stylo.rotation.lerp(Vector3(0.0, 0.0, 0.6 + sin(_t * 17.0) * 0.08), 0.35)


func _carnet(o: Dictionary) -> Node3D:
	return Carnet3D.ferme(habitant(int(o.get("maison", -1))))


## Un stylo (une plume d'oie) de 13 cm, d'axe Y, la pointe vers -Y.
func _stylo() -> Node3D:
	return Carnet3D.stylo()


## Le carnet OUVERT (les autres le voient ainsi dans ta main) : deux moitiés, les pages vers le haut,
## l'écriture lisible, la plume dans le pli, qui écrit quand tu tapes.
func _carnet_ouvert(o: Dictionary) -> Node3D:
	return Carnet3D.ouvert(o, habitant(int(o.get("maison", -1))))


## Un caillou : une boule grise, aplatie, un peu différente d'un id à l'autre.
func _caillou(id: int) -> Node3D:
	# Un caillou qu'on VOIT (Edwin, 01/11 : « je n'en vois toujours pas ») : gros comme un poing, clair sur la
	# terre sombre, avec une faible lueur propre pour ne pas disparaître la nuit.
	var n := Node3D.new()
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.1
	s.height = 0.15
	s.radial_segments = 8
	s.rings = 5
	m.mesh = s
	var mat := StandardMaterial3D.new()
	var g := 0.52 + float((id * 37) % 11) / 70.0
	mat.albedo_color = Color(g, g * 0.97, g * 0.9)
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = Color(g, g * 0.97, g * 0.9) * 0.16
	m.material_override = mat
	m.scale = Vector3(1.0 + float(id % 3) * 0.15, 1.0, 1.0 - float(id % 2) * 0.15)
	m.position.y = 0.06
	m.rotation.y = float(id)
	n.add_child(m)
	return n


func _page(o: Dictionary) -> Node3D:
	return Carnet3D.page(o)


func _boite(taille: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = m
	return mi
