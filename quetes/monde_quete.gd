class_name MondeQuete
extends Node3D
## La quête jouée DANS la clairière, chez un joueur : le décor du jeu, les objets à toucher sur
## mon établi, et un parchemin dans ma main gauche pour ce que moi seul sais (mes runes, mon
## indice, la recette…). Remplace le panneau de VueQuete, qui ne sert plus qu'à lire les yeux.
##
## Les gestes (MainGeste) : on SAISIT ce qu'on regarde — poing fermé devant la webcam, ou clic
## gauche tenu. Tenir la corde, la planche ; tourner la manivelle (un cercle de la main) ; tirer la
## corde de la cloche (la main descend) ; attraper le seau puis le lancer (la main part et s'ouvre).

signal geste(d: Dictionary)

const PORTEE := 3.2

var camera: Camera3D
var decor: DecorQuete
var jeu := ""
var _vue := {}
var _forme := ""
var _boutons: Array = []          # [{n: Node3D, a: Dictionary, off: bool, l: String}]
var _recu_t := 0.0
var _parchemin: CanvasLayer          # le parchemin, collé au coin bas-gauche de l'écran
var _ranger: Label                   # « W : ranger la note » sous la feuille, ou « W » seul quand elle est rangée
var _feuille: TextureRect
var _debut_parchemin := 0
const CONSIGNE_MS := 12000
var _vp: SubViewport
var _texte: Label
var _liste: Label
var _visee := -1
var main := MainGeste.new()
var _prise := ""                  # ce que ma main tient : "", "tenir", "manivelle", "corde", "lancer"
var _prise_bouton := -1           # le bouton saisi (lancer)
var _depart := Vector2.ZERO       # la main au moment de saisir
var _haut_corde := 0.0            # le plus haut de la main depuis le dernier coup de cloche
var _angle_avant := -1.0
var _tour := 0.0                  # le chemin tourné (en tours, signé) depuis le dernier coup
var _serre_avant := false
var _hante := false
var _prise_cache := {}            # le fixe du bloc « prise » (Prise.decompacter)
var _pm: PriseMonde               # prendre / porter / poser (bloc « prise » de la vue), cf. Prise
const VISEE_PRISE := 1 << 20      # ce que `viser()` rend quand c'est un objet de la prise que je vise
## Pour les essais (tests/test_gestes.gd) : remplace la webcam et le clic.
var essai := {}


## La vue de l'hôte (~10 par seconde). Le premier appel bâtit le décor au centre de la clairière.
func afficher(vue: Dictionary) -> void:
	var rang := int(vue.get("rang", 0))
	var equipe := int(vue.get("equipe", 1))
	if decor != null and (decor.rang != rang or decor.equipe != equipe or jeu != str(vue.get("jeu", ""))):
		decor.queue_free()   # posé à l'aller avec une équipe qui a changé depuis
		decor = null
		if _pm != null:
			_pm.queue_free()
			_pm = null
		_prise_cache.clear()
	if decor == null:
		_batir(str(vue.get("jeu", "")), int(vue.get("zone", 0)), rang, equipe)
	_vue = vue
	_recu_t = 0.0
	_maj_prise(vue)
	# Hanté : ce que je tenais m'échappe ; il faudra le ressaisir (main rouverte puis refermée).
	var hante: bool = vue.get("hante", false)
	if hante and not _hante and _prise != "":
		_lacher()
	if hante and not _hante and _pm != null:
		_pm.lacher()   # ce que je portais m'échappe : il retourne à sa place
	_hante = hante
	var boutons := _boutons_de(vue)
	var forme := "|".join(boutons.map(func(b): return "%s/%s" % [b.get("l", ""), b.get("off", false)]))
	if forme != _forme:
		_forme = forme
		_refaire_boutons(boutons)
	_ecrire_parchemin(vue)


## Le décor seul, dès le départ de l'équipe (la vue de l'hôte arrive au début du jeu).
func preparer(jeu_: String, zone: int, rang: int, equipe: int, niveau := "") -> void:
	if decor == null:
		_niveau_prepare = niveau
		_batir(jeu_, zone, rang, equipe)


var _niveau_prepare := ""


func _batir(jeu_: String, zone: int, rang: int, equipe: int) -> void:
	jeu = jeu_
	position = Quetes.zone(zone)
	decor = Decors.creer(jeu)
	decor.jeu = jeu
	decor.zone = zone
	decor.rang = rang
	decor.equipe = equipe
	decor.niveau = _niveau_prepare
	add_child(decor)
	decor.construire()
	decor.habiller()
	decor.solidifier()
	_degager_le_cadre(zone)
	if _parchemin == null:
		_construire_parchemin()


# ---------------------------------------------------------------- la zone du rôle unique

var _zone_role: Node3D
var _role_fin_ms := 0
var _role_info := {}
var _role_mat: StandardMaterial3D
var _role_label: Label3D
var _role_compte: Label3D
var _role_anneau: MeshInstance3D
var _role_lumiere: OmniLight3D


## Le choix du rôle en cours (le dictionnaire `role` de ma quête, cf. Meneur._quetes_pub), ou {}
## s'il n'y en a plus : une zone lumineuse au sol, à gauche, marquée du nom du rôle.
func regler_role(info: Dictionary, zone: int) -> void:
	if info.is_empty():
		if _zone_role != null:
			_zone_role.queue_free()
			_zone_role = null
		_role_info = {}
		return
	if _zone_role == null:
		_construire_zone_role(info, zone)
	_role_info = info
	_role_fin_ms = Time.get_ticks_msec() + int(float(info.get("reste", 0.0)) * 1000.0)


func reste_role() -> float:
	if _role_info.is_empty() or int(_role_info.get("elu", -1)) >= 0:
		return 0.0
	return maxf(float(_role_fin_ms - Time.get_ticks_msec()) / 1000.0, 0.0)


func _construire_zone_role(info: Dictionary, zone: int) -> void:
	var nom := str(info.get("nom", "Rôle"))
	_zone_role = Node3D.new()
	_zone_role.position = info.get("pos", Vector3.ZERO)
	add_child(_zone_role)
	var r := Quetes.RAYON_ROLE
	_role_mat = StandardMaterial3D.new()
	_role_mat.albedo_color = Color(0.45, 0.8, 1.0, 0.4)
	_role_mat.emission_enabled = true
	_role_mat.emission = Color(0.3, 0.65, 1.0)
	_role_mat.emission_energy_multiplier = 1.4
	_role_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_role_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var disque := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.03
	cm.radial_segments = 48
	disque.mesh = cm
	disque.material_override = _role_mat
	disque.position.y = 0.04
	_zone_role.add_child(disque)
	_role_anneau = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.07
	tm.outer_radius = r
	tm.rings = 48
	tm.ring_segments = 8
	_role_anneau.mesh = tm
	_role_anneau.scale.y = 0.35
	_role_anneau.position.y = 0.06
	_role_anneau.material_override = _role_mat
	_zone_role.add_child(_role_anneau)
	# Une colonne de lumière, pour la repérer de loin entre les arbres.
	var colonne := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = r * 0.9
	cc.bottom_radius = r * 0.9
	cc.height = 3.2
	cc.radial_segments = 32
	colonne.mesh = cc
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.5, 0.8, 1.0, 0.07)
	mc.emission_enabled = true
	mc.emission = Color(0.3, 0.6, 1.0)
	mc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mc.cull_mode = BaseMaterial3D.CULL_DISABLED
	mc.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	colonne.material_override = mc
	colonne.position.y = 1.6
	_zone_role.add_child(colonne)
	_role_lumiere = OmniLight3D.new()
	_role_lumiere.light_color = Color(0.5, 0.8, 1.0)
	_role_lumiere.light_energy = 1.6
	_role_lumiere.omni_range = 5.0
	_role_lumiere.position.y = 0.9
	_zone_role.add_child(_role_lumiere)
	# Le nom du rôle, écrit au sol (lisible en arrivant par le sentier), puis flottant au-dessus.
	var entre := Quetes.passage(zone, Quetes.R_FOURCHE) - Quetes.zone(zone)
	var vers := -Vector3(entre.x, 0, entre.z).normalized()
	var sol := Label3D.new()
	sol.text = Langue.t(nom).to_upper()
	sol.font = Style.police("titre")
	sol.font_size = 96
	sol.pixel_size = 0.0045
	sol.outline_size = 10
	sol.modulate = Color(0.9, 0.97, 1.0)
	sol.outline_modulate = Color(0.05, 0.15, 0.3)
	sol.rotation = Vector3(-PI / 2, atan2(-vers.x, -vers.z), 0)
	sol.position.y = 0.07
	_zone_role.add_child(sol)
	_role_label = Label3D.new()
	_role_label.font = Style.police("titre")
	_role_label.font_size = 64
	_role_label.pixel_size = 0.005
	_role_label.outline_size = 10
	_role_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_role_label.modulate = Color(0.95, 0.98, 1.0)
	_role_label.outline_modulate = Color(0.05, 0.15, 0.3)
	_role_label.position.y = 2.1
	_zone_role.add_child(_role_label)
	# Le compte à rebours : en chiffres bien lisibles (la police du jeu a des chiffres elzéviriens).
	_role_compte = Label3D.new()
	_role_compte.font = ThemeDB.fallback_font
	_role_compte.font_size = 150
	_role_compte.pixel_size = 0.006
	_role_compte.outline_size = 16
	_role_compte.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_role_compte.modulate = Color(1.0, 0.95, 0.7)
	_role_compte.outline_modulate = Color(0.05, 0.15, 0.3)
	_role_compte.position.y = 1.2
	_zone_role.add_child(_role_compte)
	_maj_zone_role()


func _maj_zone_role() -> void:
	if _zone_role == null or _role_info.is_empty():
		return
	var nom := str(_role_info.get("nom", "Rôle"))
	if int(_role_info.get("elu", -1)) >= 0:
		_role_label.text = "%s : %s" % [Langue.t(nom), Langue.t(str(_role_info.get("elu_nom", "?")))]
		_role_mat.albedo_color = Color(0.5, 1.0, 0.6, 0.4)
		_role_mat.emission = Color(0.3, 1.0, 0.5)
		_role_lumiere.light_color = Color(0.5, 1.0, 0.6)
		_role_compte.visible = false
	else:
		_role_compte.text = str(int(ceil(reste_role())))
		_role_label.text = "%s\n%s" % [Langue.t(nom), Langue.t("Si personne ne s'avance, le hasard décide")]
	var pouls := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 3.0)
	_role_mat.emission_energy_multiplier = 1.0 + 0.8 * pouls
	_role_anneau.scale.x = 1.0 + 0.015 * pouls
	_role_anneau.scale.z = 1.0 + 0.015 * pouls


## Le bloc « prise » de la vue (objets à prendre et cases où les poser) : les objets 3D qui le portent.
func _maj_prise(vue: Dictionary) -> void:
	var bloc := DecorQuete.bloc(vue, "prise")
	if bloc.is_empty():
		return
	if bloc.has("z"):
		# Reçu compact (cf. Prise.compacter) : on le développe, sur place, pour le décor aussi.
		var plein := Prise.decompacter(bloc, _prise_cache)
		var blocs: Array = vue["blocs"]
		blocs[blocs.find(bloc)] = plein if not plein.is_empty() else {"t": "prise", "objets": [], "cibles": [], "tenu": -1}
		if plein.is_empty():
			return
		bloc = plein
	if _pm == null:
		_pm = PriseMonde.new()
		_pm.decor = decor
		_pm.camera = camera
		_pm.clic = Callable(self, "_clic")
		_pm.agir.connect(func(d: Dictionary): geste.emit(d))
		add_child(_pm)
	_pm.maj(bloc)


func _boutons_de(vue: Dictionary) -> Array:
	var r := []
	for b: Dictionary in vue.get("blocs", []):
		if b.get("t", "") == "boutons":
			r.append_array(b.get("v", []))
	return r


func _refaire_boutons(boutons: Array) -> void:
	for x: Dictionary in _boutons:
		(x["n"] as Node3D).queue_free()
	_boutons.clear()
	for k in boutons.size():
		var b: Dictionary = boutons[k]
		var n := decor.objet_bouton(b, k, boutons.size())
		# Un corps invisible pour la visée : le rayon ne touche que lui (couche à part).
		var corps := StaticBody3D.new()
		corps.collision_layer = DecorQuete.COUCHE_BOUTONS
		corps.collision_mask = 0
		var forme := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3.ONE * decor.taille_visee()
		forme.shape = bx
		corps.add_child(forme)
		corps.set_meta("bouton", k)
		n.add_child(corps)
		if b.get("off", false):
			_eteindre(n)
		_boutons.append({"n": n, "a": b.get("a", {}), "off": b.get("off", false), "l": str(b.get("l", ""))})


func _eteindre(n: Node) -> void:
	for e in n.get_children():
		if e is Label3D:
			(e as Label3D).modulate.a = 0.3
		_eteindre(e)


## Le bouton visé (au centre de l'écran, à portée), ou -1.
func viser() -> int:
	_visee = -1
	if _pm != null:
		return VISEE_PRISE if decor != null and _pm.viser(decor.portee()) else -1
	if camera == null or _boutons.is_empty():
		return -1
	var o := camera.global_position
	var q := PhysicsRayQueryParameters3D.create(o, o - camera.global_basis.z * decor.portee(), DecorQuete.COUCHE_BOUTONS)
	q.collide_with_areas = false
	var t := get_world_3d().direct_space_state.intersect_ray(q)
	if t and t["collider"].has_meta("bouton"):
		var k: int = t["collider"].get_meta("bouton")
		if k < _boutons.size() and not _boutons[k]["off"]:
			_visee = k
	return _visee


func invite() -> String:
	if _pm != null:
		return _pm.invite()
	if _visee < 0:
		return ""
	if decor.geste_bouton(_boutons[_visee]["a"]) == "lancer":
		return Langue.t("Attrape (clic tenu ou poing fermé) : %s — puis lance") % Langue.t(str(_boutons[_visee]["l"]))
	return Langue.t("{agir} ou poing fermé : %s") % Langue.t(str(_boutons[_visee]["l"]))


## E ou clic sur l'objet visé : le geste part chez l'hôte. Un objet à lancer, saisi au clic, ne
## part qu'au lâcher (cf. _gestes).
func toucher() -> bool:
	if _pm != null:
		return _pm.toucher()
	if _visee < 0 or _visee >= _boutons.size():
		return false
	var b: Dictionary = _boutons[_visee]
	if decor.geste_bouton(b["a"]) == "lancer" and _clic():
		_saisir("lancer", _visee)
		return true
	geste.emit(decor.affiner_action(b["a"]))
	decor.touche(b["n"])
	return true


## Tant que je serre, la souris déplace ma main et pas ma tête (appelé par principal).
func absorber_souris(rel: Vector2) -> bool:
	if decor != null and decor.absorbe_souris(rel):
		return true
	if _prise == "" or main.vue:
		return false
	main.souris(rel)
	return true


## La molette de la souris, pour les jeux qui tournent quelque chose (cadenas du Grand Coffre).
func molette(sens: int) -> bool:
	return decor != null and decor.molette(sens)


func _clic() -> bool:
	if essai.has("clic"):
		return bool(essai["clic"])
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


## Le geste que demande ma vue : "tenir", "manivelle", "corde" ou "".
func _geste_attendu() -> String:
	for b: Dictionary in _vue.get("blocs", []):
		match b.get("t", ""):
			"tenir":
				return "tenir"
			"rame":
				return "rame"
			"rythme":
				return decor.geste_rythme()
	return ""


## Est-ce que je regarde cet objet (assez près, assez en face) ?
func regarde(n: Node3D) -> bool:
	if n == null or camera == null or not n.is_inside_tree():
		return false
	var d := n.global_position - camera.global_position
	var l := d.length()
	if l > PORTEE + 0.6 or l < 0.01:
		return false
	return (-camera.global_basis.z).angle_to(d) < clampf(atan(0.5 / l), 0.18, 0.6)


func _saisir(quoi: String, bouton := -1) -> void:
	_prise = quoi
	_prise_bouton = bouton
	_depart = main.pos
	_haut_corde = main.pos.y
	_angle_avant = -1.0
	_tour = 0.0
	decor.tenu = true
	if quoi == "tenir":
		geste.emit({"tenir": true})


func _lacher() -> void:
	if _prise == "tenir":
		geste.emit({"tenir": false})
	elif _prise == "lancer" and _prise_bouton >= 0 and _prise_bouton < _boutons.size():
		var b: Dictionary = _boutons[_prise_bouton]
		# Un seau lâché sans élan retombe à sa place : il faut le lancer.
		if (main.pos - _depart).length() > 0.35 and not b["off"]:
			geste.emit(decor.affiner_action(b["a"]))
			decor.touche(b["n"])
		decor.porter(b["n"], Vector2.ZERO)
	_prise = ""
	_prise_bouton = -1
	decor.tenu = false
	decor.main = Vector2.ZERO
	decor.manivelle = -1.0
	main.lacher_souris()


## Une image de gestes : saisir ce qu'on regarde, tenir, tourner, tirer, lancer, lâcher.
func _gestes(delta: float, phase: float) -> void:
	# Capteur par son chemin : les essais (sans autoload) passent par `essai`.
	var cap := get_node_or_null("/root/Capteur") if is_inside_tree() else null
	var webcam: bool = cap != null and not cap.mode_souris
	var mains: PackedFloat32Array = essai.get("mains", cap.mains if webcam else PackedFloat32Array())
	var corps: PackedFloat32Array = essai.get("corps", cap.corps if webcam else PackedFloat32Array())
	main.lire(mains, corps, _clic(), delta)
	var serre := main.serre
	var attendu := _geste_attendu()
	if _prise != "" and (not serre or (_prise != "lancer" and _prise != attendu)):
		_lacher()
	elif _prise == "" and serre and not _serre_avant:
		if attendu == "rame":
			# La rame se prend sans la regarder : on a les yeux sur la rivière (cf. Radeau).
			_saisir("rame")
		elif attendu != "" and regarde(decor.cible_geste()):
			_saisir(attendu)
		elif main.vue and not _clic() and viser() >= 0:
			# Le poing fermé sur un objet visé, c'est le même geste que E.
			if _pm != null:
				toucher()
			elif decor.geste_bouton(_boutons[_visee]["a"]) == "lancer":
				_saisir("lancer", _visee)
			else:
				toucher()
	_serre_avant = serre
	if _prise == "":
		return
	var d := main.pos - _depart
	decor.main = d
	match _prise:
		"corde":
			# Un coup de cloche : la main redescend d'un bon tiers de bras depuis son plus haut.
			_haut_corde = maxf(_haut_corde, main.pos.y)
			if _haut_corde - main.pos.y > 0.4:
				_haut_corde = main.pos.y
				geste.emit({"coup": true, "phase": maxf(phase, 0.0)})
				decor.frappe()
		"rame":
			# Un coup de rame : la main (ou la souris) descend, vers moi, d'un bon tiers de bras depuis
			# son plus haut ; pour en donner un autre, il faut la remonter (ou lâcher et reprendre).
			_haut_corde = maxf(_haut_corde, main.pos.y)
			if _haut_corde - main.pos.y > 0.4:
				_haut_corde = main.pos.y
				geste.emit({"rame": true})
				decor.frappe()
		"manivelle":
			# Un tour : la main repasse en haut du cercle qu'elle trace.
			var a := main.angle()
			decor.manivelle = a
			# Il faut avoir vraiment tourné (trois quarts de tour dans le même sens) : un va-et-vient
			# qui traverse le haut ne compte pas.
			if a >= 0.0 and _angle_avant >= 0.0:
				var pas := wrapf(a - _angle_avant, -0.5, 0.5)
				if absf(pas) < 0.3:
					_tour += pas
				if absf(a - _angle_avant) > 0.5 and absf(_tour) >= 0.75:
					geste.emit({"coup": true, "phase": maxf(phase, 0.0)})
					decor.frappe()
					_tour = 0.0
			_angle_avant = a
		"lancer":
			if _prise_bouton < _boutons.size():
				decor.porter(_boutons[_prise_bouton]["n"], d)


func _process(delta: float) -> void:
	_maj_zone_role()
	if decor == null:
		return
	_recu_t += delta
	var phase := -1.0
	for b: Dictionary in _vue.get("blocs", []):
		if b.get("t", "") == "rythme":
			phase = fposmod(float(b.get("phase", 0.0)) + _recu_t / maxf(float(b.get("periode", 1.0)), 0.05), 1.0)
	_gestes(delta, phase)
	decor.manipuler(self, delta)
	if _pm != null:
		_pm.avancer(delta)
	decor.animer(_vue, phase, delta)
	decor.afficher_vies(_vue)


# ---------------------------------------------------------------- le parchemin (main gauche)

func _construire_parchemin() -> void:
	_vp = SubViewport.new()
	# Mise en page sur 512 × 660, rendue au double : l'écriture reste nette quand il est grand.
	_vp.size = Vector2i(1024, 1320)
	_vp.size_2d_override = Vector2i(512, 660)
	_vp.size_2d_override_stretch = true
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	# Un vrai parchemin, taché et brûlé sur les bords (Style), écrit à la plume.
	var fond := TextureRect.new()
	fond.texture = Style.parchemin(1)
	fond.stretch_mode = TextureRect.STRETCH_SCALE
	fond.size = Vector2(512, 660)
	_vp.add_child(fond)
	# Le texte en haut ; en bas, la liste de tout ce qui existe dans la partie, à l'encre pâle.
	var colonne := VBoxContainer.new()
	colonne.position = Vector2(38, 34)
	colonne.size = Vector2(436, 594)
	colonne.add_theme_constant_override("separation", 10)
	_vp.add_child(colonne)
	_texte = Label.new()
	_texte.custom_minimum_size = Vector2(436, 0)
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texte.add_theme_font_override("font", Style.police("texte"))
	_texte.add_theme_font_size_override("font_size", 38)
	_texte.add_theme_color_override("font_color", Color(0.08, 0.04, 0.02))
	colonne.add_child(_texte)
	_liste = Label.new()
	_liste.custom_minimum_size = Vector2(436, 0)
	_liste.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_liste.add_theme_font_override("font", Style.police("italique"))
	_liste.add_theme_font_size_override("font_size", 26)
	_liste.add_theme_color_override("font_color", Color(0.22, 0.12, 0.06))
	colonne.add_child(_liste)
	# Collé au coin bas-gauche de l'écran, grand (plus de la moitié de la hauteur) : on le lit d'un
	# coup d'œil sans cacher le jeu, qui reste au centre (cf. _placer_parchemin).
	_parchemin = CanvasLayer.new()
	_parchemin.layer = 1   # SOUS l'écran (2), la pause (3) et F10 : la note ne couvre jamais un menu
	add_child(_parchemin)
	_feuille = TextureRect.new()
	_feuille.texture = _vp.get_texture()
	_feuille.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_feuille.stretch_mode = TextureRect.STRETCH_SCALE
	_feuille.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feuille.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_parchemin.add_child(_feuille)
	# La touche qui range la note (W par défaut, comme la note du matin) : écrite sous la feuille ; rangée,
	# il ne reste qu'un « W » à peine visible dans le coin (Edwin, 01/11).
	_ranger = Label.new()
	_ranger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ranger.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_ranger.add_theme_font_override("font", Style.police("italique"))
	_ranger.add_theme_font_size_override("font_size", 16)
	_ranger.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_ranger.add_theme_constant_override("shadow_offset_x", 1)
	_ranger.add_theme_constant_override("shadow_offset_y", 1)
	_parchemin.add_child(_ranger)
	if is_inside_tree():
		get_viewport().size_changed.connect(_placer_parchemin)
	var opts := get_node_or_null("/root/Options")
	if opts:
		opts.change.connect(func(cle: String): if cle == "interface/note_reduite" or cle.begins_with("touches"): _placer_parchemin())
	_placer_parchemin()
	_debut_parchemin = Time.get_ticks_msec()


## Le parchemin au coin bas-gauche : 58 % de la hauteur de l'écran, mais jamais plus du tiers de
## sa largeur (en 4:3 il ne mord pas sur le centre), à 1,5 % de marge du bord.
const PARCHEMIN_HAUTEUR := 0.58
const PARCHEMIN_LARGEUR_MAX := 0.33


func _placer_parchemin() -> void:
	if _feuille == null or not is_inside_tree():
		return
	var ecran := get_viewport().get_visible_rect().size
	var h := ecran.y * PARCHEMIN_HAUTEUR
	var l := h * 512.0 / 660.0
	if l > ecran.x * PARCHEMIN_LARGEUR_MAX:
		l = ecran.x * PARCHEMIN_LARGEUR_MAX
		h = l * 660.0 / 512.0
	var marge := ecran.y * 0.015
	_feuille.size = Vector2(l, h)
	_feuille.position = Vector2(marge, ecran.y - h - marge)
	if _ranger == null:
		return
	var opts := get_node_or_null("/root/Options")
	var rangee: bool = opts != null and bool(opts.valeur("interface/note_reduite"))
	_feuille.visible = not rangee
	if rangee:
		_ranger.text = opts.texte_touches("note")
		_ranger.add_theme_color_override("font_color", Color(1, 1, 1, 0.38))
		_ranger.position = Vector2(18, ecran.y - 40)
	else:
		_ranger.text = opts.avec_touches("{note} : ranger la note") if opts else ""
		_ranger.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82, 0.7))
		_ranger.position = Vector2(marge + 6, ecran.y - h - marge - 24)


## Ce que moi seul vois, à l'encre : la consigne, puis les textes et les jauges de ma vue.
func _ecrire_parchemin(vue: Dictionary) -> void:
	if _texte == null:
		return
	var l := PackedStringArray()
	var regle := str(vue.get("variante", ""))
	l.append("%s%s — %s s" % [Langue.t(str(vue.get("titre", "Quête"))), " · " + Langue.t(regle) if regle != "" else "", int(ceil(float(vue.get("reste", 0.0))))])
	# La consigne ne reste que le temps de la lire : ensuite, seul ce qui change compte.
	if Time.get_ticks_msec() - _debut_parchemin < CONSIGNE_MS:
		l.append(Langue.t(str(vue.get("consigne", ""))))
	l.append("")
	for b: Dictionary in vue.get("blocs", []):
		match b.get("t", ""):
			"texte":
				l.append(MiniJeu.tr_vue(str(b.get("v", ""))))
			"jauge":
				var n := int(round(clampf(float(b.get("v", 0.0)), 0, 1) * 12))
				l.append("%s  [%s%s]" % [Langue.t(str(b.get("l", ""))), "|".repeat(n), "·".repeat(12 - n)])
			"tenir", "yeux", "rythme":
				l.append("» " + Langue.t(str(b.get("l", ""))))
	_texte.text = "\n".join(l)
	var li: Dictionary = vue.get("liste", {})
	var tout: Array = li.get("v", [])
	var tout_en := PackedStringArray()
	for x: Variant in tout:
		tout_en.append(Langue.t(str(x)))
	_liste.text = "" if tout.is_empty() else "%s : %s." % [Langue.t(str(li.get("titre", "Tout ce qui existe"))), ", ".join(tout_en)]
	_ajuster_parchemin()


## Rien ne doit sortir du parchemin : on part de la grande écriture et on la resserre tant que
## le texte et la liste dépassent (jamais sous 22 : en dessous, ça ne se lit plus).
func _ajuster_parchemin() -> void:
	var police := _texte.get_theme_font("font")
	var taille := 38
	while taille > 22:
		var t_liste := maxi(17, int(round(taille * 0.7)))
		var h := police.get_multiline_string_size(_texte.text, HORIZONTAL_ALIGNMENT_LEFT, 424, taille).y
		if _liste.text != "":
			h += 10 + police.get_multiline_string_size(_liste.text, HORIZONTAL_ALIGNMENT_LEFT, 424, t_liste).y
		if h <= 584:
			break
		taille -= 1
	_texte.add_theme_font_size_override("font_size", taille)
	_liste.add_theme_font_size_override("font_size", maxi(17, int(round(taille * 0.7))))


## Un décor qui déborde de la clairière (la rivière du Radeau) écarte les arbres, buissons et
## falaises du cadre qui seraient dedans ; ils reviennent quand la quête se termine.
var _ecartes: Array[Node3D] = []


func _degager_le_cadre(zone: int) -> void:
	var zones := decor.degage()
	if zones.is_empty() or not is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group("cadre_%d" % zone):
		var nd := n as Node3D
		var dedans := nd.has_meta("sol_de_clairiere")
		if not dedans:
			var p := to_local(nd.global_position)
			for z in zones:
				if z.grow(1.0).has_point(Vector2(p.x, p.z)):
					dedans = true
		if dedans and nd.visible:
			nd.visible = false
			nd.process_mode = Node.PROCESS_MODE_DISABLED
			_ecartes.append(nd)


func _exit_tree() -> void:
	for nd in _ecartes:
		if is_instance_valid(nd):
			nd.visible = true
			nd.process_mode = Node.PROCESS_MODE_INHERIT
	_ecartes.clear()


## Le parchemin s'efface quand un menu (pause, F10) est ouvert : rien ne doit gêner la lecture ni le clic.
func montrer_parchemin(oui: bool) -> void:
	if _parchemin != null and _parchemin.visible != oui:
		_parchemin.visible = oui


func cacher() -> void:
	if _prise != "":
		_lacher()
	if _parchemin:
		_parchemin.queue_free()
	queue_free()
