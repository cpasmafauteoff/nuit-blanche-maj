class_name PriseMonde
extends Node3D
## PRENDRE / PORTER / POSER, côté JOUEUR : les objets de la quête sont de vrais objets 3D (bâtis par
## le décor), on les vise, on les prend (E, ou clic gauche TENU, ou poing fermé), ils suivent la main
## (devant la caméra) et on les pose dans une case (E, lâcher le clic, ou poing). L'hôte (Prise) fait foi :
## ici on envoie des intentions et on montre ; ce que je décide s'affiche tout de suite (0,8 s de
## crédit), puis l'hôte reprend la main.
##
## Le décor peut définir (tous facultatifs) :
##   objet_prise(d) -> Node3D          l'objet (pied à y = 0). d = objet du bloc de vue (cf. Prise.bloc)
##   nom_prise(d) -> String            ce qu'on lit dans l'invite (par défaut d.l)
##   cible_prise(d) -> Node3D          le repère d'une case (par défaut un anneau qui luit quand on porte)
##   pos_prise(c, rang, o) -> Vector3  où se tient le rang-ième objet de la case c (repère de la clairière) ;
##                                     rang -1 : le centre de la case (un plateau qui bouge l'indique ici)
##   prise_evenement(quoi, o, pos)     "prend" | "pose" | "repose" (bruit, étincelle) ; sinon un bruit de pierre

signal agir(d: Dictionary)

const CREDIT := 0.8          # secondes pendant lesquelles ma décision prime sur la vue de l'hôte
const DELAI_LACHER := 0.3    # un clic plus bref que ça = je bascule en mode « porter jusqu'à la case »

var decor: DecorQuete
var camera: Camera3D
var clic := Callable()       # () -> bool : le bouton gauche est-il enfoncé ?

var _objets := {}            # i -> {n: Node3D, corps: StaticBody3D, d: Dictionary, sig: String}
var _cases := {}             # c -> {corps: StaticBody3D, rep: Node3D, d: Dictionary}
var _tenu := -1              # ce que je porte
var _tenu_t := -10.0
var _local := {}             # i -> [case, instant] : posé par moi, pas encore confirmé
var _muet := {}              # i -> instant : mon geste a déjà fait son bruit
var _t := 0.0
var _pris_clic := false
var _pris_t := 0.0
var _vise := {}              # {"k": "o"|"c", "i": n} ou {}
var _action := ""            # "prend" | "pose" | "repose" | "plein" | ""
var _cible_visee := -1
var _objet_vise := -1


## Le bloc de vue de l'hôte (~10 par seconde).
func maj(bloc: Dictionary) -> void:
	var ht := int(bloc.get("tenu", -1))
	if _t - _tenu_t > CREDIT:
		_tenu = ht
	var vus := {}
	for d: Dictionary in bloc.get("objets", []):
		var i := int(d["i"])
		vus[i] = true
		if not _objets.has(i):
			_creer_objet(i, d)
		var e: Dictionary = _objets[i]
		e["d"] = d
		var sig := "%s/%s" % [d["s"], d["p"]]
		if e["sig"] != sig:
			if e["sig"] != "" and _t - float(_muet.get(i, -9.0)) > 1.5:
				_evenement(i, d, e["sig"])
			e["sig"] = sig
		if _local.has(i) and (_t - float(_local[i][1]) > CREDIT or int(d["s"]) == int(_local[i][0])):
			_local.erase(i)
	for i in _objets.keys():
		if not vus.has(i):
			(_objets[i]["n"] as Node3D).queue_free()
			_objets.erase(i)
	var vues := {}
	for d: Dictionary in bloc.get("cibles", []):
		var c := int(d["c"])
		vues[c] = true
		if not _cases.has(c):
			_creer_case(c, d)
		_cases[c]["d"] = d
	for c in _cases.keys():
		if not vues.has(c):
			(_cases[c]["corps"] as Node3D).queue_free()
			_cases.erase(c)


func _creer_objet(i: int, d: Dictionary) -> void:
	var n: Node3D = decor.objet_prise(d) if decor.has_method("objet_prise") else _objet_par_defaut(d)
	n.position = d["r"]
	add_child(n)
	var corps := StaticBody3D.new()
	corps.collision_layer = DecorQuete.COUCHE_BOUTONS
	corps.collision_mask = 0
	var forme := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	var t := float((d.get("x", {}) as Dictionary).get("t", 0.2))
	bx.size = Vector3(t + 0.05, t * 0.55 + 0.02, t + 0.05)
	forme.shape = bx
	forme.position.y = t * 0.3
	corps.add_child(forme)
	corps.set_meta("prise_o", i)
	n.add_child(corps)
	_objets[i] = {"n": n, "corps": corps, "d": d, "sig": ""}


func _objet_par_defaut(d: Dictionary) -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.16, 0.08, 0.16)
	mi.mesh = b
	mi.position.y = 0.04
	n.add_child(mi)
	return n


func _creer_case(c: int, d: Dictionary) -> void:
	var corps := StaticBody3D.new()
	corps.collision_layer = DecorQuete.COUCHE_BOUTONS
	corps.collision_mask = 0
	var forme := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	var r := float((d.get("x", {}) as Dictionary).get("r", 0.12))
	bx.size = Vector3(r * 2.0, float((d.get("x", {}) as Dictionary).get("h", 0.06)), r * 2.0)
	forme.shape = bx
	corps.add_child(forme)
	corps.set_meta("prise_c", c)
	corps.position = _centre_case(d)
	add_child(corps)
	var rep: Node3D = decor.cible_prise(d) if decor.has_method("cible_prise") else _repere_par_defaut(r)
	if rep != null:
		rep.visible = false
		corps.add_child(rep)
	_cases[c] = {"corps": corps, "rep": rep, "d": d}


func _repere_par_defaut(r: float) -> Node3D:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = r * 0.9
	t.outer_radius = r
	mi.mesh = t
	mi.scale = Vector3(1, 0.1, 1)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.75, 0.35, 0.7)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.65, 0.25)
	m.emission_energy_multiplier = 0.8
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position.y = 0.03
	return mi


func _centre_case(d: Dictionary) -> Vector3:
	if decor.has_method("pos_prise"):
		return decor.pos_prise(d, -1, {})
	return d["pos"]


# ---------------------------------------------------------------- viser, prendre, poser

## Ce que je regarde, à `portee` : met à jour l'action possible. Vrai s'il y a quelque chose à faire.
func viser(portee: float) -> bool:
	_vise = {}
	_action = ""
	_cible_visee = -1
	_objet_vise = -1
	if camera == null:
		return false
	var o := camera.global_position
	var q := PhysicsRayQueryParameters3D.create(o, o - camera.global_basis.z * portee, DecorQuete.COUCHE_BOUTONS)
	q.collide_with_areas = false
	var t := get_world_3d().direct_space_state.intersect_ray(q)
	if t:
		var corps: Object = t["collider"]
		if corps.has_meta("prise_o"):
			_vise = {"k": "o", "i": int(corps.get_meta("prise_o"))}
		elif corps.has_meta("prise_c"):
			_vise = {"k": "c", "i": int(corps.get_meta("prise_c"))}
	if _tenu < 0:
		# Une encoche qui porte un objet, visée par-dessus : c'est l'objet qu'on vise.
		if _vise.get("k", "") == "c" and _cases.has(_vise["i"]):
			var cd0: Dictionary = _cases[_vise["i"]]["d"]
			if int(cd0.get("cap", 1)) == 1 and (cd0["o"] as Array).size() == 1:
				_vise = {"k": "o", "i": int((cd0["o"] as Array)[0])}
		if _vise.get("k", "") == "o" and _objets.has(_vise["i"]) and bool(_objets[_vise["i"]]["d"]["m"]) and not _local.has(_vise["i"]):
			_action = "prend"
			_objet_vise = _vise["i"]
		return _action != ""
	# Je porte quelque chose : regarder une case libre la pose, regarder ailleurs le repose.
	var c := -1
	if _vise.get("k", "") == "c":
		c = int(_vise["i"])
	elif _vise.get("k", "") == "o" and _objets.has(_vise["i"]) and int(_objets[_vise["i"]]["d"]["s"]) >= 0:
		c = int(_objets[_vise["i"]]["d"]["s"])
	if c >= 0 and _cases.has(c):
		var cd: Dictionary = _cases[c]["d"]
		_cible_visee = c
		if bool(cd["m"]) and (cd["o"] as Array).size() < int(cd.get("cap", 1)):
			_action = "pose"
		else:
			_action = "plein"
		return true
	_action = "repose"
	return true


func invite() -> String:
	match _action:
		"prend":
			return Langue.t("{agir} ou clic tenu : prendre %s") % _nom(_objets[_objet_vise]["d"])
		"pose":
			return Langue.t("{agir} ou lâcher le clic : poser ici")
		"repose":
			return Langue.t("{agir} ou lâcher le clic : reposer %s") % _nom(_objets[_tenu]["d"]) if _objets.has(_tenu) else ""
		"plein":
			return Langue.t("Cette place est prise")
	return ""


func _nom(d: Dictionary) -> String:
	if decor.has_method("nom_prise"):
		return str(decor.nom_prise(d))
	return str(d.get("l", ""))


## E, clic ou poing sur ce que je vise. Rend vrai si le geste a été traité.
func toucher() -> bool:
	match _action:
		"prend":
			var i := _objet_vise
			_tenu = i
			_tenu_t = _t
			_pris_clic = clic.is_valid() and bool(clic.call())
			_pris_t = _t
			_muet[i] = _t
			_son("prend", i)
			agir.emit({"prend": i})
			return true
		"pose":
			var i2 := _tenu
			var c := _cible_visee
			_tenu = -1
			_tenu_t = _t
			_muet[i2] = _t
			_local[i2] = [c, _t]
			(_objets[i2]["d"] as Dictionary)["s"] = c
			(_objets[i2]["d"] as Dictionary)["p"] = -1
			_evenement(i2, _objets[i2]["d"], "")
			agir.emit({"pose": c})
			return true
		"repose":
			var i3 := _tenu
			_tenu = -1
			_tenu_t = _t
			_muet[i3] = _t
			_son("repose", i3)
			agir.emit({"repose": true})
			return true
		"plein":
			return true
	return false


func porte() -> bool:
	return _tenu >= 0


## Ce que je porte m'échappe (hanté) : il retourne à sa place d'origine.
func lacher() -> void:
	if _tenu < 0:
		return
	_muet[_tenu] = _t
	_tenu = -1
	_tenu_t = _t
	agir.emit({"repose": true})


# ---------------------------------------------------------------- l'image

func avancer(delta: float) -> void:
	_t += delta
	if decor == null:
		return
	# Clic tenu : lâcher le bouton ailleurs que tout de suite, c'est poser (ou reposer).
	if _tenu >= 0 and _pris_clic and _t - _pris_t > DELAI_LACHER and clic.is_valid() and not bool(clic.call()):
		_pris_clic = false
		viser(decor.portee())
		toucher()
	var main := _main()
	var porte_ := _tenu >= 0
	for i in _objets:
		var e: Dictionary = _objets[i]
		var n: Node3D = e["n"]
		var d: Dictionary = e["d"]
		var but := _but(int(i), d, main)
		if int(i) == _tenu:
			n.position = n.position.lerp(but, 1.0 - exp(-24.0 * delta))
			n.rotation.y = lerp_angle(n.rotation.y, camera.global_rotation.y if camera else 0.0, 1.0 - exp(-10.0 * delta))
			n.rotation.x = lerpf(n.rotation.x, 0.0, 1.0 - exp(-8.0 * delta))
		else:
			n.position = n.position.lerp(but, 1.0 - exp(-14.0 * delta))
			n.rotation.y = lerp_angle(n.rotation.y, float((d.get("x", {}) as Dictionary).get("rot", 0.0)), 1.0 - exp(-8.0 * delta))
		n.visible = true
		# Je porte quelque chose : seuls les objets DÉJÀ dans une case se visent (le reste ne gêne pas la visée d'une case).
		var actif: bool = int(i) != _tenu and (not porte_ or int(d["s"]) >= 0) and int(d["p"]) < 1
		(e["corps"] as StaticBody3D).collision_layer = DecorQuete.COUCHE_BOUTONS if actif else 0
		var vise := int(i) == _objet_vise
		n.scale = n.scale.lerp(Vector3.ONE * (1.1 if vise else 1.0), 1.0 - exp(-14.0 * delta))
	for c in _cases:
		var e2: Dictionary = _cases[c]
		(e2["corps"] as Node3D).position = _centre_case(e2["d"])
		var rep: Node3D = e2["rep"]
		if rep != null:
			var libre: bool = (e2["d"]["o"] as Array).size() < int(e2["d"].get("cap", 1)) and bool(e2["d"]["m"])
			rep.visible = porte_ and libre
			rep.scale = Vector3.ONE * (1.0 + (0.12 + 0.05 * sin(_t * 8.0) if int(c) == _cible_visee else 0.0))


## Où est ma main : devant la caméra, un peu à droite et plus bas.
func _main() -> Vector3:
	if camera == null:
		return Vector3.ZERO
	var b := camera.global_basis
	var p := camera.global_position - b.z * 0.62 + b.x * 0.2 - b.y * 0.22
	return to_local(p)


func _but(i: int, d: Dictionary, main: Vector3) -> Vector3:
	if i == _tenu:
		return main
	if int(d["p"]) == 1:
		# Un autre le tient : il flotte un peu au-dessus de sa place, le temps qu'il le pose.
		return Vector3(d["r"]) + Vector3(0, 0.42 + 0.03 * sin(_t * 3.0 + i), 0)
	var s := int(d["s"])
	var rang := -1
	if _local.has(i):
		s = int(_local[i][0])
	if s >= 0 and _cases.has(s):
		var cd: Dictionary = _cases[s]["d"]
		var liste: Array = cd["o"]
		rang = liste.find(i)
		if rang < 0:
			rang = liste.size()
		if decor.has_method("pos_prise"):
			return decor.pos_prise(cd, rang, d)
		return cd["pos"]
	return d["r"]


# ---------------------------------------------------------------- bruits

## Un changement d'état d'un objet (posé, pris par un autre) : le bruit qui va avec.
func _evenement(i: int, d: Dictionary, avant: String) -> void:
	var s_avant := int(avant.get_slice("/", 0)) if avant != "" else -1
	if int(d["s"]) >= 0 and int(d["s"]) != s_avant:
		_son("pose", i)
	elif int(d["p"]) == 1:
		_son("prend", i)


func _son(quoi: String, i: int) -> void:
	if not _objets.has(i) or not is_inside_tree():
		return
	var n: Node3D = _objets[i]["n"]
	var pos := n.global_position
	if decor.has_method("prise_evenement"):
		decor.prise_evenement(quoi, _objets[i]["d"], pos)
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = Prise.son("pierre_pose" if quoi == "pose" else "pierre_prend")
	a.bus = "Effets"
	a.unit_size = 5.0
	a.position = pos
	get_parent().add_child(a)
	a.play()
	a.finished.connect(a.queue_free)
