class_name Frissons
extends Node3D
## Ce qui rend le village angoissant, pour MOI seul (décision d'Edwin, 29/10) : rien ne passe par
## le réseau, chacun vit ses propres frayeurs. Quatre familles — apparitions, sons, objets,
## bêtes — de loin en loin, et au plus deux vrais screamers par partie : l'épouvantail planté
## dans mon dos quand je me retourne, le visage collé à une vitre. Aucune n'apprend quoi que ce
## soit au joueur : c'est de l'ambiance, jamais un indice.
##
## Et le monstre d'un fantôme (Meneur.apparition) : un visage déformé qui hurle, une seconde,
## devant mes yeux.

const PAUSE_MIN := 35.0          # entre deux petites frayeurs
const PAUSE_MAX := 75.0
const PREMIER_SCREAMER := 240.0  # pas avant 4 min de jeu
const ECART_SCREAMERS := 300.0   # puis 5 min au moins entre deux
const PETITES := ["silhouette", "yeux_arbre", "yeux_lisiere", "pas", "chuchote", "comptine",
	"cloche", "porte", "bougie", "ombre", "corbeaux", "chien", "rats"]

var camera: Camera3D
var corps: Node3D
var ronde: Ronde
var permis: Callable          # () -> bool : le moment s'y prête-t-il (vivant, de jour, rien d'ouvert) ?
var seul: Callable            # () -> bool : personne à moins de 8 m
var sol_pas: Callable         # (Vector3) -> String
var secouer: Callable         # (float) -> void
var ma_maison := -1
var maison_vide: Callable = func(_i: int) -> bool: return false   # la maison d'un mort, close
var journal := false          # partie de test : chaque frayeur s'écrit dans la console

var _rng := RandomNumberGenerator.new()
var _t_jeu := 0.0
var _prochaine := 45.0
var _screamers_prevus := 1
var _screamers := 0
var _screamer_a := PREMIER_SCREAMER
var _scene: Dictionary = {}       # la frayeur en cours : {sorte, t, noeud…}
var _poupee: Node3D
var _poupee_vue := false
var _poupee_t := 0.0
var _avant := Vector3.ZERO        # où était le corps à l'image d'avant (vitesse)
var _vitesse := 0.0
var _mats := {}


func _ready() -> void:
	_rng.randomize()
	_screamers_prevus = _rng.randi_range(1, 2)
	_screamer_a = PREMIER_SCREAMER + _rng.randf_range(0.0, 180.0)


## Une nouvelle partie : tout repart de zéro.
func remettre() -> void:
	_fin()
	_t_jeu = 0.0
	_prochaine = _rng.randf_range(40.0, 70.0)
	_screamers = 0
	_ready()
	if _poupee:
		_poupee.queue_free()
		_poupee = null


func _process(delta: float) -> void:
	if camera == null or corps == null or ronde == null or not permis.is_valid():
		return
	var ici := corps.global_position
	_vitesse = lerpf(_vitesse, Vector2(ici.x - _avant.x, ici.z - _avant.z).length() / maxf(delta, 0.001), 0.2)
	_avant = ici
	var ok: bool = permis.call()
	if not _scene.is_empty():
		if not ok:
			_fin()
		else:
			_scene["t"] = float(_scene["t"]) + delta
			_jouer(delta)
		return
	if not ok:
		return
	_t_jeu += delta
	_poupee_tick(delta)
	if _screamers < _screamers_prevus and _t_jeu >= _screamer_a:
		if _rng.randf() < 0.5 and _debut_epouvantail() or _debut_vitre() or _debut_epouvantail():
			return
		_screamer_a = _t_jeu + 12.0
	_prochaine -= delta
	if _prochaine <= 0.0:
		_prochaine = _rng.randf_range(PAUSE_MIN, PAUSE_MAX)
		var l := PETITES.duplicate()
		l.shuffle()
		for sorte: String in l:
			if call("_debut_" + sorte):
				return
		_prochaine = 8.0


# ================================================================ outils

func _devant() -> Vector3:
	var d := -camera.global_basis.z
	d.y = 0
	return d.normalized()


## L'angle (rad) entre ce que je regarde et ce point.
func _angle(p: Vector3) -> float:
	return (-camera.global_basis.z).angle_to(p - camera.global_position)


## Rien entre mes yeux et ce point (murs, troncs) ?
func _vue_libre(p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(camera.global_position, p, Corps.SANS_JOUEURS)
	if corps is CollisionObject3D:
		q.exclude = [(corps as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _dehors() -> bool:
	return Ronde.maison_de(corps.global_position) < 0


func _mat(c: Color, emission := 0.0, sans_profondeur := false) -> StandardMaterial3D:
	var cle := "%s/%f/%s" % [c.to_html(), emission, sans_profondeur]
	if _mats.has(cle):
		return _mats[cle]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	if sans_profondeur:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[cle] = m
	return m


func _boule(parent: Node3D, r: float, mat: Material, pos: Vector3, ech := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	m.mesh = s
	m.material_override = mat
	m.position = pos
	m.scale = ech
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


func _boite(parent: Node3D, taille: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	m.mesh = b
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


func _cone(parent: Node3D, r_haut: float, r_bas: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_haut
	c.bottom_radius = r_bas
	c.height = h
	c.radial_segments = 10
	m.mesh = c
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


## Un son posé dans le monde. `screamer` : suit le réglage « Frayeurs » (volume, cri coupé).
func _son(flux: AudioStream, pos: Vector3, volume_db: float, screamer := false, hauteur := 1.0, net := false) -> void:
	if flux == null:
		return
	if screamer:
		var o := get_node_or_null("/root/Options")
		if o:
			if not bool(o.valeur("frayeurs/cri")):
				return
			volume_db += linear_to_db(maxf(float(o.valeur("son/frayeurs")) / 100.0, 0.001))
	var a := AudioStreamPlayer3D.new()
	a.stream = flux
	a.bus = "Effets"
	a.volume_db = volume_db
	a.pitch_scale = hauteur
	a.unit_size = 6.0
	if net:
		a.attenuation_filter_cutoff_hz = 20500.0   # un bruit métallique garde son aigu (le filtre 5 kHz par défaut l'étouffe)
	add_child(a)
	a.global_position = pos
	a.play()
	a.finished.connect(a.queue_free)


## Une frayeur se joue-t-elle en ce moment (pour les statistiques des yeux) ?
func frayeur_en_cours() -> bool:
	return not _scene.is_empty()


func _scener(sorte: String, noeud: Node3D = null, extra := {}) -> bool:
	if journal:
		print("[frisson] %s (t=%.0f s de jeu)" % [sorte, _t_jeu])
	_scene = {"sorte": sorte, "t": 0.0, "noeud": noeud}
	_scene.merge(extra)
	return true


func _fin() -> void:
	if _scene.is_empty():
		return
	var n: Node3D = _scene.get("noeud")
	if is_instance_valid(n) and n.get_parent() == self:
		n.queue_free()
	var yeux: StandardMaterial3D = _scene.get("yeux")
	if yeux:
		yeux.emission_energy_multiplier = 0.0
	if _scene.get("screamer", false):
		if _scene.get("vu", false):
			_screamers += 1
			_screamer_a = _t_jeu + ECART_SCREAMERS + _rng.randf_range(0.0, 240.0)
		else:
			_screamer_a = _t_jeu + 30.0
	_scene = {}


func _jouer(delta: float) -> void:
	var t: float = _scene["t"]
	var n: Node3D = _scene.get("noeud")
	match _scene["sorte"]:
		"epouvantail":
			_jouer_epouvantail(delta)
		"vitre":
			_jouer_vitre(delta)
		"silhouette", "chien":
			var p := n.global_position + Vector3(0, 1.2, 0)
			var d := Vector2(p.x - corps.global_position.x, p.z - corps.global_position.z).length()
			if _scene["sorte"] == "chien" and _scene.get("fuit", false):
				n.global_position += n.global_basis.z * delta * 4.5
				n.global_position.y = absf(sin(t * 14.0)) * 0.05
				if t > float(_scene["fuit_t"]) + 1.4:
					_fin()
				return
			# Elle s'évanouit quand on la regarde en face, ou qu'on s'approche.
			var regarde: bool = _angle(p) < deg_to_rad(9.0) and _vue_libre(p)
			_scene["fixe"] = float(_scene.get("fixe", 0.0)) + (delta if regarde else 0.0)
			var fuir: bool = d < 10.0 or t > 14.0 or float(_scene["fixe"]) > (0.15 if _scene["sorte"] == "silhouette" else 2.2)
			if fuir:
				if _scene["sorte"] == "chien":
					n.rotate_y(PI)
					_scene["fuit"] = true
					_scene["fuit_t"] = t
				else:
					_fin()
		"yeux_arbre":
			var yeux: StandardMaterial3D = _scene["yeux"]
			yeux.emission_energy_multiplier = clampf(t / 0.6, 0.0, 1.0) * 3.0 * (0.85 + 0.15 * sin(t * 9.0))
			var o: Node3D = _scene["visage"]
			if t > 4.0 or o.global_position.distance_to(corps.global_position) < 6.0:
				_fin()
		"yeux_lisiere":
			var cligne: bool = fposmod(t, 3.1) < 0.12
			n.scale = Vector3(1, 0.1 if cligne else 1.0, 1)
			if t > 10.0 or n.global_position.distance_to(corps.global_position) < 9.0 or float(_scene.get("fixe", 0.0)) > 1.5:
				_fin()
			elif _angle(n.global_position) < deg_to_rad(6.0):
				_scene["fixe"] = float(_scene.get("fixe", 0.0)) + delta
		"pas":
			# Des pas qui me suivent, calés sur les miens… et un de trop quand je m'arrête.
			_scene["prochain"] = float(_scene["prochain"]) - delta
			if _vitesse > 1.0:
				_scene["arret"] = 0.0
				if float(_scene["prochain"]) <= 0.0:
					_scene["prochain"] = 0.5
					_scene["n"] = int(_scene["n"]) + 1
					var p := corps.global_position - _devant() * 2.6
					_son(Sons.pas(sol_pas.call(p), int(_scene["n"]) % 4), p, -9.0)
			else:
				_scene["arret"] = float(_scene.get("arret", 0.0)) + delta
				if float(_scene["arret"]) > 0.45 and not _scene.get("dernier", false):
					_scene["dernier"] = true
					var p := corps.global_position - _devant() * 2.0
					_son(Sons.pas(sol_pas.call(p), 1), p, -7.0)
			if int(_scene["n"]) > 9 or _scene.get("dernier", false) and float(_scene["arret"]) > 1.0 or t > 16.0:
				_fin()
		"ombre":
			(_scene["porteur"] as Node3D).position.x = lerpf(-2.3, 2.3, clampf(t / 1.8, 0.0, 1.0))
			if t > 1.9:
				_fin()
		"rats":
			for k in n.get_child_count():
				var r: Node3D = n.get_child(k)
				var u := clampf((t - k * 0.13) / 1.0, 0.0, 1.0)
				r.position.x = lerpf(-3.0, 3.0, u)
				r.position.y = absf(sin(t * 30.0 + k)) * 0.015
			if t > 1.8:
				_fin()
		_:
			if t > float(_scene.get("duree", 3.0)):
				_fin()


# ================================================================ apparitions

func _debut_silhouette() -> bool:
	if not _dehors():
		return false
	for essai in 8:
		var cote := 1.0 if _rng.randf() < 0.5 else -1.0
		var dir := _devant().rotated(Vector3.UP, cote * _rng.randf_range(0.45, 0.7))
		var p := corps.global_position + dir * _rng.randf_range(17.0, 27.0)
		p.y = 0.0
		if Vector2(p.x, p.z).length() > Ronde.R_LISIERE - 1.5 or Ronde.maison_de(p) >= 0 or not _vue_libre(p + Vector3(0, 1.4, 0)):
			continue
		var n := Node3D.new()
		var noir := _mat(Color(0.01, 0.01, 0.012))
		_cone(n, 0.1, 0.17, 1.5, noir, Vector3(0, 0.9, 0))               # un corps trop long
		_boule(n, 0.13, noir, Vector3(0, 1.85, 0), Vector3(0.85, 1.25, 0.85))
		for c: int in [-1, 1]:                                            # des bras jusqu'aux genoux
			_cone(n, 0.035, 0.02, 1.25, noir, Vector3(c * 0.2, 1.05, 0), Vector3(0, 0, c * 0.08))
			_cone(n, 0.045, 0.03, 0.9, noir, Vector3(c * 0.08, 0.45, 0))
		add_child(n)
		n.global_position = p
		n.look_at(Vector3(corps.global_position.x, 0, corps.global_position.z), Vector3.UP, true)
		return _scener("silhouette", n)
	return false


func _debut_yeux_arbre() -> bool:
	for v: Dictionary in ronde.visages:
		var o: Node3D = v["noeud"]
		var p := o.global_position
		var d := p.distance_to(corps.global_position)
		if d > 8.0 and d < 30.0 and _angle(p) < deg_to_rad(28.0) and _vue_libre(p + (corps.global_position - p).normalized() * 0.6):
			return _scener("yeux_arbre", null, {"yeux": v["yeux"], "visage": o})
	return false


func _debut_yeux_lisiere() -> bool:
	var ici := corps.global_position
	var r := Vector2(ici.x, ici.z).length()
	if r < Ronde.R_LISIERE - 15.0 or not _dehors():
		return false
	var a := atan2(ici.x, ici.z) + _rng.randf_range(-0.12, 0.12)
	var p := Vector3(sin(a), 0, cos(a)) * (Ronde.R_LISIERE + 1.3) + Vector3(0, _rng.randf_range(0.5, 1.1), 0)
	if _angle(p) > deg_to_rad(40.0):
		return false
	var n := Node3D.new()
	var lueur := _mat(Color(0.85, 0.9, 0.55), 4.0)
	for c: int in [-1, 1]:
		_boule(n, 0.022, lueur, Vector3(c * 0.055, 0, 0))
	add_child(n)
	n.global_position = p
	n.look_at(Vector3(ici.x, p.y, ici.z), Vector3.UP, true)
	return _scener("yeux_lisiere", n)


# ================================================================ sons

func _debut_pas() -> bool:
	if not _dehors() or _vitesse < 1.0:
		return false
	return _scener("pas", null, {"n": 0, "prochain": 0.25})


func _debut_chuchote() -> bool:
	var cote := camera.global_basis.x * (1.0 if _rng.randf() < 0.5 else -1.0)
	_son(Sons.murmure(_rng.randi_range(0, 3)), camera.global_position + cote * 1.3, -12.0)
	return _scener("chuchote", null, {"duree": 2.0})


func _debut_comptine() -> bool:
	var a := _rng.randf() * TAU
	_son(Sons.comptine(), Vector3(sin(a), 0, cos(a)) * (Ronde.R_LISIERE + 4.0) + Vector3(0, 1.0, 0), -2.0)
	return _scener("comptine", null, {"duree": 11.0})


func _debut_cloche() -> bool:
	_son(Sons.cloche(), Ronde.centre_temple() + Vector3(0, 6, 0), -10.0, false, 0.62)
	return _scener("cloche", null, {"duree": 4.0})


# ================================================================ objets

func _debut_porte() -> bool:
	for i in Ronde.NB_MAISONS:
		if i == ma_maison or Ronde.maison_de(corps.global_position) == i:
			continue
		var p := Ronde.devant_porte(i, "avant")
		var d := p.distance_to(corps.global_position)
		if d > 5.0 and d < 16.0 and _angle(p + Vector3(0, 1, 0)) < deg_to_rad(35.0) and ronde.entrouvrir(i, "avant"):
			_son(Sons.craquement(), p + Vector3(0, 1, 0), -6.0, false, 0.7)
			get_tree().create_timer(3.3).timeout.connect(func(): _son(Sons.poignee(), p + Vector3(0, 1, 0), -4.0, false, 1.0, true))
			return _scener("porte", null, {"duree": 4.0})
	return false


func _debut_bougie() -> bool:
	var p := ronde.souffler_bougie(corps.global_position, 7.0)
	if p == Vector3.INF:
		return false
	return _scener("bougie", null, {"duree": 2.0})


func _debut_ombre() -> bool:
	for i in Ronde.NB_MAISONS:
		var c := Ronde.centre_maison(i)
		var d := c.distance_to(corps.global_position)
		var f: Array = Ronde.fenetre(i, 1)
		var mur: Vector3 = (f[0] as Vector3) - (f[1] as Vector3) * 0.0
		if d < 6.0 or d > 14.0 or Ronde.maison_de(corps.global_position) == i or (f[1] as Vector3).dot(corps.global_position - mur) < 0.0:
			continue
		var milieu := Ronde.devant_porte(i, "avant") + Vector3(0, 1.0, 0)
		if _angle(milieu) > deg_to_rad(30.0) or not _vue_libre(milieu + (f[1] as Vector3) * 0.4):
			continue
		# Un plan noir à silhouette humaine, collé au mur, qui glisse d'une fenêtre à l'autre.
		var ancre := Node3D.new()
		add_child(ancre)
		var n: Vector3 = f[1]
		ancre.global_basis = Basis(n.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, n)
		ancre.global_position = Vector3(milieu.x, 0.0, milieu.z) + n * 0.33
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.0, 2.0)
		q.mesh = qm
		var m := StandardMaterial3D.new()
		m.albedo_texture = Frissons.silhouette_tex()
		m.albedo_color = Color(0, 0, 0, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		q.material_override = m
		q.position = Vector3(0, 1.15, 0)
		var porteur := Node3D.new()
		ancre.add_child(porteur)
		porteur.add_child(q)
		_scener("ombre", ancre, {"porteur": porteur})
		return true
	return false


static var _tex_silhouette: ImageTexture


## Une silhouette humaine floue, en niveaux d'alpha (64×128).
static func silhouette_tex() -> ImageTexture:
	if _tex_silhouette:
		return _tex_silhouette
	var img := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 64:
			var px := (x - 32.0) / 32.0
			var py := (y - 0.0) / 128.0
			var a := 0.0
			a = maxf(a, 1.0 - Vector2(px / 0.22, (py - 0.1) / 0.08).length())          # tête
			a = maxf(a, 1.0 - Vector2(px / 0.42, (py - 0.36) / 0.2).length())          # torse
			a = maxf(a, 1.0 - Vector2((absf(px) - 0.5) / 0.1, (py - 0.42) / 0.24).length())   # bras
			a = maxf(a, 1.0 - Vector2((absf(px) - 0.15) / 0.13, (py - 0.75) / 0.25).length()) # jambes
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a * 3.0, 0.0, 1.0)))
	_tex_silhouette = ImageTexture.create_from_image(img)
	return _tex_silhouette


## La poupée de chiffon : posée quelque part sur la place… et ailleurs quand on repasse.
func _poupee_tick(delta: float) -> void:
	if _poupee == null:
		_poupee = _faire_poupee()
		add_child(_poupee)
		_poser_poupee(true)
		return
	_poupee_t += delta
	var p := _poupee.global_position + Vector3(0, 0.2, 0)
	var d := p.distance_to(corps.global_position)
	if d < 16.0 and _angle(p) < deg_to_rad(25.0) and _vue_libre(p):
		_poupee_vue = true
	elif _poupee_vue and _angle(p) > deg_to_rad(80.0) and d > 5.0 and _poupee_t > 100.0 and _rng.randf() < delta / 20.0:
		_poser_poupee(false)


func _poser_poupee(au_hasard: bool) -> void:
	var places: Array[Vector3] = []
	for i in Ronde.NB_MAISONS:
		# Au pied d'une porte, de l'autre côté que le carnet d'un mort.
		var devant := Ronde.devant_porte(i, "avant")
		var dehors := (devant - Ronde.centre_maison(i)) * Vector3(1, 0, 1)
		dehors = dehors.normalized()
		places.append(Vector3(devant.x, 0.0, devant.z) + dehors * 0.2 - dehors.cross(Vector3.UP) * 0.75)
	places.shuffle()
	for p in places:
		var d := p.distance_to(corps.global_position)
		if au_hasard or (d > 4.0 and d < 14.0 and _angle(p) > deg_to_rad(70.0)):
			_poupee.global_position = p
			_poupee.look_at(Vector3(corps.global_position.x, p.y, corps.global_position.z), Vector3.UP, true)
			_poupee_vue = false
			_poupee_t = 0.0
			return


func _faire_poupee() -> Node3D:
	var n := Node3D.new()
	var toile := _mat(Color(0.62, 0.52, 0.4))
	var robe := _mat(Color(0.35, 0.12, 0.12))
	var noir := _mat(Color(0.02, 0.02, 0.02))
	var laine := _mat(Color(0.25, 0.14, 0.08))
	_cone(n, 0.06, 0.1, 0.16, robe, Vector3(0, 0.08, 0))
	_boule(n, 0.065, toile, Vector3(0, 0.22, 0), Vector3(1, 1.05, 0.95))
	for c: int in [-1, 1]:
		_boule(n, 0.013, noir, Vector3(c * 0.025, 0.235, 0.058))              # boutons
		_cone(n, 0.012, 0.016, 0.1, toile, Vector3(c * 0.07, 0.11, 0.0), Vector3(0, 0, c * 0.5))
		_cone(n, 0.014, 0.018, 0.1, toile, Vector3(c * 0.03, 0.0, 0.05), Vector3(1.4, 0, 0))
		_boite(n, Vector3(0.012, 0.13, 0.012), laine, Vector3(c * 0.055, 0.19, -0.01), Vector3(0, 0, c * 0.2))
	_boite(n, Vector3(0.05, 0.004, 0.004), _mat(Color(0.45, 0.05, 0.05)), Vector3(0, 0.195, 0.062), Vector3(0, 0, 0.12))
	return n


# ================================================================ bêtes

func _debut_corbeaux() -> bool:
	var p := ronde.envoler_corbeau(corps.global_position, 13.0)
	if p == Vector3.INF:
		return false
	# Ils s'envolent sans un bruit : plus de croassements ni de battements d'ailes (Edwin, 31/10).
	return _scener("corbeaux", null, {"duree": 2.5})


func _debut_chien() -> bool:
	if not _dehors():
		return false
	for essai in 8:
		var cote := 1.0 if _rng.randf() < 0.5 else -1.0
		var p := corps.global_position + _devant().rotated(Vector3.UP, cote * _rng.randf_range(0.3, 0.6)) * _rng.randf_range(14.0, 22.0)
		p.y = 0.0
		if Vector2(p.x, p.z).length() > Ronde.R_LISIERE - 1.5 or Ronde.maison_de(p) >= 0 or not _vue_libre(p + Vector3(0, 0.6, 0)):
			continue
		var n := Node3D.new()
		var poil := _mat(Color(0.03, 0.03, 0.035))
		_boule(n, 0.2, poil, Vector3(0, 0.55, 0), Vector3(0.9, 0.9, 2.0))
		_boule(n, 0.13, poil, Vector3(0, 0.78, 0.42))
		_boite(n, Vector3(0.1, 0.09, 0.16), poil, Vector3(0, 0.74, 0.56))
		for c: int in [-1, 1]:
			_cone(n, 0.0, 0.04, 0.12, poil, Vector3(c * 0.07, 0.92, 0.38))
			_boule(n, 0.016, _mat(Color(0.8, 0.85, 0.5), 2.5), Vector3(c * 0.05, 0.8, 0.53))
			for av: float in [-0.3, 0.3]:
				_cone(n, 0.03, 0.04, 0.5, poil, Vector3(c * 0.1, 0.25, av))
		_cone(n, 0.01, 0.03, 0.4, poil, Vector3(0, 0.55, -0.48), Vector3(-1.0, 0, 0))
		add_child(n)
		n.global_position = p
		n.look_at(Vector3(corps.global_position.x, 0, corps.global_position.z), Vector3.UP, true)
		return _scener("chien", n)
	return false


func _debut_rats() -> bool:
	if not _dehors() or _vitesse > 2.5:
		return false
	var devant := corps.global_position + _devant() * 2.6
	if Ronde.maison_de(devant) >= 0 or not _vue_libre(devant + Vector3(0, 0.3, 0)):
		return false
	var n := Node3D.new()
	add_child(n)
	n.global_position = devant
	n.global_basis = Basis(_devant().cross(Vector3.UP).normalized() * -1.0, Vector3.UP, _devant()).rotated(Vector3.UP, PI * 0.5 * (1.0 if _rng.randf() < 0.5 else -1.0))
	var gris := _mat(Color(0.18, 0.16, 0.15))
	for k in _rng.randi_range(3, 5):
		var r := Node3D.new()
		n.add_child(r)
		r.position = Vector3(-3.0, 0, _rng.randf_range(-0.4, 0.4))
		_boule(r, 0.05, gris, Vector3(0, 0.045, 0), Vector3(2.2, 0.9, 1.0))
		_boule(r, 0.028, gris, Vector3(0.11, 0.05, 0), Vector3(1.4, 1.0, 1.0))
		_boite(r, Vector3(0.16, 0.008, 0.008), _mat(Color(0.35, 0.25, 0.25)), Vector3(-0.17, 0.035, 0), Vector3(0, 0, 0.15))
	return _scener("rats", n)


# ================================================================ les deux screamers

## L'épouvantail : armé, il se tient juste dans mon dos (il se replace tant que je ne le vois
## pas). Quand je me retourne, son visage est à un mètre, face à la caméra.
func _debut_epouvantail() -> bool:
	if not _dehors():
		return false
	var n := _faire_epouvantail()
	add_child(n)
	n.visible = false
	return _scener("epouvantail", n, {"screamer": true})


func _jouer_epouvantail(delta: float) -> void:
	var n: Node3D = _scene["noeud"]
	var t: float = _scene["t"]
	if _scene.get("vu", false):
		var u := t - float(_scene["vu_t"])
		n.global_position += (camera.global_position - n.global_position) * delta * 1.2 * float(u < 0.25)
		if u > 0.75:
			_fin()
		return
	var tete := n.global_position + Vector3(0, 1.75, 0)
	var dans_le_champ := _angle(tete) < deg_to_rad(38.0)
	if not dans_le_champ and _angle(tete) > deg_to_rad(105.0):
		# Il se replace dans mon dos.
		var p := corps.global_position - _devant() * 1.05
		p.y = 0.0
		n.global_position = p
		n.look_at(Vector3(camera.global_position.x, 0, camera.global_position.z), Vector3.UP, true)
		n.visible = _vue_libre(p + Vector3(0, 1.5, 0)) and Ronde.maison_de(p) < 0 and _dehors()
	elif dans_le_champ and n.visible and t > 2.0:
		_scene["vu"] = true
		_scene["vu_t"] = t
		_son(Sons.cri(), tete, 2.0, true)
		_son(Sons.hurlement(), tete, -4.0, true, 0.75)
		if secouer.is_valid():
			secouer.call(0.12)
	elif dans_le_champ:
		n.visible = false
	if t > 70.0:
		_fin()


func _faire_epouvantail() -> Node3D:
	var n := Node3D.new()
	var bois := _mat(Color(0.2, 0.15, 0.1))
	var jute := _mat(Color(0.38, 0.31, 0.22))
	var guenille := _mat(Color(0.18, 0.16, 0.13))
	var paille := _mat(Color(0.75, 0.62, 0.3))
	var noir := _mat(Color(0.0, 0.0, 0.0))
	var fil := _mat(Color(0.12, 0.05, 0.04))
	_boite(n, Vector3(0.09, 1.9, 0.09), bois, Vector3(0, 0.95, -0.05))
	_boite(n, Vector3(1.5, 0.07, 0.07), bois, Vector3(0, 1.45, -0.05), Vector3(0, 0, 0.06))
	_cone(n, 0.22, 0.36, 0.95, guenille, Vector3(0, 1.1, 0))
	for c: int in [-1, 1]:
		_cone(n, 0.07, 0.1, 0.62, guenille, Vector3(c * 0.42, 1.45, 0), Vector3(0, 0, c * PI * 0.5))
		for k in 4:
			_boite(n, Vector3(0.012, 0.14, 0.012), paille, Vector3(c * (0.74 + k * 0.012), 1.4 - k * 0.02, k * 0.02 - 0.03), Vector3(0.2 * k, 0, c * (0.3 + k * 0.3)))
	for k in 7:
		_boite(n, Vector3(0.012, 0.16, 0.012), paille, Vector3((k - 3) * 0.035, 1.6, 0.05), Vector3(0.3, 0, (k - 3) * 0.25))
	# La tête : un sac de jute recousu, deux trous noirs, une bouche cousue trop large.
	var tete := Node3D.new()
	tete.position = Vector3(0, 1.78, 0.02)
	tete.rotation.z = 0.18
	n.add_child(tete)
	_boule(tete, 0.21, jute, Vector3.ZERO, Vector3(0.95, 1.12, 0.92))
	for c: int in [-1, 1]:
		# Deux trous inégaux, une lueur d'épingle au fond, et ce qui a coulé dessous.
		_boule(tete, 0.05 if c < 0 else 0.064, noir, Vector3(c * 0.078, 0.05 + c * 0.012, 0.17), Vector3(1.0, 1.3, 0.5))
		_boule(tete, 0.006, _mat(Color(1.0, 0.35, 0.2), 3.0), Vector3(c * 0.075, 0.04, 0.2))
		_boite(tete, Vector3(0.012, 0.09, 0.006), _mat(Color(0.18, 0.04, 0.03)), Vector3(c * 0.08, -0.03, 0.19), Vector3(-0.3, 0, c * 0.1))
	# La couture a cédé au milieu : la bouche s'ouvre sur du noir.
	_boule(tete, 0.05, noir, Vector3(0.0, -0.075, 0.17), Vector3(1.6, 0.9, 0.5))
	for k in 9:
		var x := (k - 4) * 0.032
		var y := -0.085 + 0.0016 * (k - 4) * (k - 4)
		_boite(tete, Vector3(0.026, 0.006, 0.006), noir, Vector3(x, y, 0.192 - absf(k - 4) * 0.008), Vector3(0, -x * 2.0, 0))
		_boite(tete, Vector3(0.005, 0.045, 0.005), fil, Vector3(x, y, 0.196 - absf(k - 4) * 0.008), Vector3(0, -x * 2.0, 0.2))
	_cone(tete, 0.0, 0.14, 0.24, _mat(Color(0.3, 0.24, 0.14)), Vector3(0, 0.26, -0.01), Vector3(-0.15, 0, 0.1))
	_cone(tete, 0.3, 0.3, 0.015, _mat(Color(0.3, 0.24, 0.14)), Vector3(0, 0.16, -0.01), Vector3(-0.15, 0, 0.1))
	return n


## Le visage à la vitre : une fenêtre à quelques mètres, dans un coin de mon regard. Quand je la
## regarde, trois coups secs contre le verre… et il est là, collé.
func _debut_vitre() -> bool:
	if not _dehors():
		return false
	for i in Ronde.NB_MAISONS:
		# Seulement chez un mort : un visage chez un vivant passerait pour un indice.
		if i == ma_maison or not maison_vide.call(i):
			continue
		for cote: int in [-1, 1]:
			var f: Array = Ronde.fenetre(i, cote)
			var c: Vector3 = f[0]
			var nrm: Vector3 = f[1]
			var d := c.distance_to(camera.global_position)
			if d < 2.5 or d > 8.0 or nrm.dot(camera.global_position - c) < 0.5 or _angle(c) > deg_to_rad(50.0) or not _vue_libre(c + nrm * 0.3):
				continue
			var n := _faire_visage(false)
			add_child(n)
			n.global_position = c - nrm * 0.32
			n.look_at(n.global_position + nrm, Vector3.UP, true)
			n.visible = false
			return _scener("vitre", n, {"screamer": true, "normale": nrm, "vitre": c})
	return false


func _jouer_vitre(delta: float) -> void:
	var n: Node3D = _scene["noeud"]
	var t: float = _scene["t"]
	var c: Vector3 = _scene["vitre"]
	if _scene.get("vu", false):
		var u := t - float(_scene["vu_t"])
		n.visible = true
		n.global_position = n.global_position.lerp(c - (_scene["normale"] as Vector3) * 0.08, minf(1.0, delta * 18.0))
		if u > 0.9:
			_fin()
		return
	if _angle(c) < deg_to_rad(11.0) and c.distance_to(camera.global_position) < 9.0:
		_scene["vu"] = true
		_scene["vu_t"] = t
		_son(Sons.coup_vitre(), c, 4.0, true)
		_son(Sons.cri(), c, -2.0, true, 1.1)
		if secouer.is_valid():
			secouer.call(0.08)
	elif t > 45.0 or c.distance_to(camera.global_position) > 11.0:
		_fin()


## Un visage blafard : orbites creuses et inégales, pupilles d'épingle, larmes noires, bouche
## tordue qui n'en finit pas. `devant_les_yeux` : le monstre d'un fantôme, collé à la caméra
## (plus de lueur propre : il doit frapper même à l'ombre).
func _faire_visage(devant_les_yeux: bool) -> Node3D:
	var lueur := 0.45 if devant_les_yeux else 0.3
	var n := Node3D.new()
	var peau := _mat(Color(0.6, 0.64, 0.56), lueur)
	var creux := _mat(Color(0.0, 0.0, 0.0))
	var cerne := _mat(Color(0.4, 0.43, 0.36), lueur * 0.5)
	var oeil := _mat(Color(1.0, 0.95, 0.85), 3.0)
	var dent := _mat(Color(0.72, 0.66, 0.48), 0.2)
	var cheveux := _mat(Color(0.03, 0.03, 0.03))
	_boule(n, 0.16, peau, Vector3(0, 0, 0), Vector3(0.78, 1.45, 0.82))
	_boule(n, 0.05, cerne, Vector3(-0.055, 0.05, 0.095), Vector3(1.0, 1.4, 0.5))
	_boule(n, 0.056, cerne, Vector3(0.06, 0.03, 0.093), Vector3(1.0, 1.45, 0.5))
	var orbites := [[-0.052, 0.075, 0.042, 0.0], [0.058, 0.05, 0.05, -0.25]]
	for o: Array in orbites:
		var m := _boule(n, float(o[2]), creux, Vector3(float(o[0]), float(o[1]), 0.105), Vector3(1.0, 1.55, 0.55))
		m.rotation.z = float(o[3])
		_boule(n, 0.006, oeil, Vector3(float(o[0]) + 0.006, float(o[1]) - 0.008, 0.128))
		# Une larme noire qui coule jusqu'au menton.
		for k in 3:
			_boite(n, Vector3(0.008, 0.06, 0.006), creux, Vector3(float(o[0]) + 0.004 * (k % 2), float(o[1]) - 0.07 - k * 0.055, 0.118 - k * 0.006), Vector3(-0.2, 0, 0.12 * (k - 1)))
	var bouche := _boule(n, 0.055, creux, Vector3(0.01, -0.17, 0.095), Vector3(0.78, 2.6, 0.5))
	bouche.rotation.z = 0.09
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for k in 7:
		if k == 2 or k == 5:
			continue            # des dents qui manquent
		var x := (k - 3.0) * 0.014 + 0.01
		_cone(n, 0.0, rng.randf_range(0.004, 0.008), rng.randf_range(0.02, 0.045), dent, Vector3(x, -0.06, 0.11), Vector3(PI, 0, rng.randf_range(-0.3, 0.3)))
		_cone(n, 0.0, rng.randf_range(0.004, 0.007), rng.randf_range(0.015, 0.035), dent, Vector3(x + 0.004, -0.29, 0.1), Vector3(0, 0, rng.randf_range(-0.3, 0.3)))
	for c: int in [-1, 1]:
		for k in 4:
			_boite(n, Vector3(0.0035, rng.randf_range(0.22, 0.34), 0.0035), cheveux, Vector3(c * (0.1 + k * 0.012), 0.0 - k * 0.03, -0.01 + k * 0.012), Vector3(0, 0, c * rng.randf_range(0.0, 0.1)))
	return n


## Le monstre d'un fantôme, une seconde devant mes yeux (Meneur.apparition).
func monstre() -> void:
	if journal:
		print("[frisson] monstre d'un fantôme")
	var n := _faire_visage(true)
	camera.add_child(n)
	n.position = Vector3(0, -0.03, -1.3)
	var tw := create_tween()
	tw.tween_property(n, "position:z", -0.5, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	for k in 6:
		tw.tween_property(n, "position:x", 0.015 * (1 if k % 2 == 0 else -1), 0.06)
	tw.tween_property(n, "position:z", -0.42, 0.25)
	tw.tween_callback(func(): n.visible = false)
	tw.tween_interval(0.05)
	tw.tween_callback(func(): n.visible = true)
	tw.tween_interval(0.06)
	tw.tween_callback(n.queue_free)
	var o := get_node_or_null("/root/Options")
	var vol := 0.0
	var cri := true
	if o:
		cri = bool(o.valeur("frayeurs/cri"))
		vol = linear_to_db(maxf(float(o.valeur("son/frayeurs")) / 100.0, 0.001))
	if cri:
		var a := AudioStreamPlayer.new()
		a.stream = Sons.hurlement()
		a.bus = "Effets"
		a.volume_db = vol
		add_child(a)
		a.play()
		a.finished.connect(a.queue_free)
	if secouer.is_valid():
		secouer.call(0.14)


## Mode test : cette frayeur, tout de suite, si le lieu s'y prête. Renvoie false sinon.
func forcer(sorte: String) -> bool:
	if sorte == "monstre":
		monstre()
		return true
	if not _scene.is_empty():
		_fin()
	return bool(call("_debut_" + sorte))
