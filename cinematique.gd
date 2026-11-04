class_name Cinematique
extends Node3D
## La cinématique de la nuit : LA seule coupure du jeu, 8 s au plus. Elle part dès que la meute a
## choisi sa porte (décision d'Edwin, 29/10 : « depuis la chambre »).
## Stylisée : image passée au rouge sang et à l'os, grain, vignette, bandes noires.
##   1. une chambre, à la bougie — on ne dit pas laquelle (jamais celle du joueur) ;
##   2. la poignée de la porte de derrière grince et tourne ;
##   3. la porte s'ouvre lentement sur le noir : deux yeux s'allument ;
##   4. la bougie s'éteint, les yeux se jettent en avant, cri — coupure au noir.
## Personne n'apparaît : l'habitant de la chambre choisie est caché le temps du plan.

const DUREE := 8.0
const T_PORTE := 1.7             # la porte s'ouvre d'un coup : la victime cesse de danser
const SHADER_STYLE := """
shader_type canvas_item;
uniform sampler2D ecran : hint_screen_texture, filter_linear_mipmap;
uniform float temps = 0.0;
uniform float force = 1.0;
float bruit(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec3 c = texture(ecran, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	l = floor(pow(l, 0.85) * 5.0 + 0.5) / 5.0;
	vec3 ombre = vec3(0.02, 0.0, 0.01);
	vec3 sang = vec3(0.55, 0.04, 0.03);
	vec3 os = vec3(0.93, 0.86, 0.72);
	vec3 duo = l < 0.5 ? mix(ombre, sang, l * 2.0) : mix(sang, os, (l - 0.5) * 2.0);
	float grain = (bruit(SCREEN_UV * 900.0 + temps * 37.0) - 0.5) * 0.16;
	vec2 v = SCREEN_UV - 0.5;
	float vignette = smoothstep(0.85, 0.25, length(v * vec2(1.3, 1.0)));
	COLOR = vec4(mix(c, (duo + grain) * vignette, force), 1.0);
}
"""

var victimes := 0
var ma_maison := -1              # utilisée seulement si maison_cible < 0 : alors jamais la chambre du joueur qui regarde
## La chambre de la victime (Edwin, 03/11 : « les autres voient la cinématique de la maison de la victime »).
var maison_cible := -1
## Vrai pour la victime elle-même : elle vit la scène en vrai, à la 1re personne, dans SA chambre : ses yeux
## sont la caméra, le loup ouvre SA porte et lui saute dessus. Ni bandes noires, ni image stylisée.
var pov := false
## Vrai pour un loup (humain) de la meute : il vit la scène EN VRAI lui aussi, à la 1re personne, avec les
## yeux du loup, depuis le seuil de la porte qu'il ouvre (Edwin, 04/11). Il voit la victime, pas la bête.
var loup_pov := false
## (essai) préfixe des photos prises à des instants précis de la scène (indépendant de la fluidité de l'image).
var photos := ""
var _photos_k := 0
var camera: Camera3D
var ronde: Ronde
var jouer_son: Callable          # (nom, volume_db)

var _t := 0.0
var _u := Vector3.FORWARD        # du point de départ vers la pierre
var _s := Vector3.RIGHT          # sur le côté du chemin
var _depart := Vector3.ZERO
var _arret := Vector3.ZERO
var _loup: Bouille
var _draps: Array[Bouille] = []
var _lueur: OmniLight3D
var _lune: SpotLight3D
var _calque: CanvasLayer
var _style: ColorRect
var _bande_haut: ColorRect
var _bande_bas: ColorRect
var _noir: ColorRect
var _phrase: Label
var _sons_joues := {}
var _maison := 0
var _pivot: Node3D = null
var _pivot_rot := 0.0
var _victime: Bouille
var _bete: CinemaLoup
var _lune_porte: OmniLight3D
var _bougie: OmniLight3D
var _caches: Array[Node3D] = []
var _oeil_a := Vector3.ZERO     # la caméra, choisie par tests de visibilité (locale à la maison)
var _oeil_b := Vector3.ZERO
## Les yeux de la victime (pov), locaux à la maison : décalés de quelques dizaines de centimètres par rapport à
## sa place, là où le poteau de bois ne masque plus la porte ni le loup (cherché par lancers de rayons, maison par maison).
var _tete := Vector3(0.3, 1.6, 0.0)


func _ready() -> void:
	var a := randf() * TAU
	_u = -Vector3(sin(a), 0, cos(a))
	_s = _u.cross(Vector3.UP).normalized()
	_depart = -_u * 6.0
	_arret = -_u * 1.35
	_construire_ecran()
	_lueur = OmniLight3D.new()
	_lueur.light_color = Color(0.85, 0.12, 0.06)
	_lueur.omni_range = 6.0
	_lueur.light_energy = 0.5
	_lueur.position = Ronde.PIERRE + Vector3(0, 1.4, 0)
	add_child(_lueur)
	_lune = SpotLight3D.new()
	_lune.light_color = Color(0.55, 0.62, 0.8)
	_lune.light_energy = 0.0
	_lune.spot_range = 9.0
	_lune.spot_angle = 22.0
	add_child(_lune)
	if victimes <= 0:
		return
	_preparer_chambre()


## Un vrai corps de villageois, recouvert d'un drap sale : tout le maillage prend la toile.
func _drap(k: int) -> Bouille:
	var b := Bouille.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + k
	b.apparence = Bouille.decoder(Bouille.au_hasard(rng))
	b.apparence["objet"] = 0      # ni chapeau ni objet sous le drap : la silhouette ne doit trahir personne
	b.apparence["tete"] = 0
	b.autonome = false
	return b


func _couvrir(n: Node, m: Material = null) -> void:
	if m == null:
		var toile := StandardMaterial3D.new()
		toile.albedo_color = Color(0.72, 0.68, 0.6)
		toile.roughness = 1.0
		m = toile
	for e in n.get_children():
		if e is MeshInstance3D and (e as MeshInstance3D).mesh:
			var mi := e as MeshInstance3D
			mi.material_override = null
			for k in mi.mesh.get_surface_count():
				mi.set_surface_override_material(k, m)
		elif e is Label3D:
			(e as Label3D).visible = false
		_couvrir(e, m)


func _construire_ecran() -> void:
	_calque = CanvasLayer.new()
	_calque.layer = 60
	add_child(_calque)
	_style = ColorRect.new()
	_style.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = SHADER_STYLE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_style.material = mat
	_calque.add_child(_style)
	_bande_haut = ColorRect.new()
	_bande_bas = ColorRect.new()
	for b: ColorRect in [_bande_haut, _bande_bas]:
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_calque.add_child(b)
	_bande_haut.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_bande_bas.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_noir = ColorRect.new()
	_noir.color = Color(0, 0, 0, 1)
	_noir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_noir.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_calque.add_child(_noir)
	_phrase = Label.new()
	_phrase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phrase.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phrase.add_theme_font_size_override("font_size", 30)
	_phrase.add_theme_color_override("font_color", Color(0.86, 0.82, 0.74))
	_phrase.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_calque.add_child(_phrase)


func fini() -> bool:
	return _t >= DUREE


## Avance d'une image. Rend la phrase du plan en cours (pour les dormeurs, qui ne voient rien d'autre).
func avancer(delta: float) -> String:
	_t += delta
	# Les corps de la chambre restent cachés (la synchro des positions peut les rallumer à chaque image).
	for c in _caches:
		if is_instance_valid(c):
			c.visible = false
	var h := _calque.get_viewport().get_visible_rect().size.y
	var bande := 0.0 if (pov or loup_pov) else h * 0.11
	_bande_haut.offset_bottom = bande
	_bande_bas.offset_top = -bande
	_phrase.offset_top = -bande
	_phrase.offset_bottom = 0
	(_style.material as ShaderMaterial).set_shader_parameter("temps", _t)
	(_style.material as ShaderMaterial).set_shader_parameter("force", 0.3 if (pov or loup_pov) else 1.0)
	var texte := _jouer_vide() if victimes <= 0 else _jouer()
	_phrase.text = texte
	var instants := [1.0, 2.5, 3.5, 4.2, 4.8, 5.05, 5.4, 7.0]
	if photos != "" and _photos_k < instants.size() and _t >= instants[_photos_k]:
		_calque.get_viewport().get_texture().get_image().save_png("%s_%d.png" % [photos, _photos_k])
		_photos_k += 1
	return texte


func _une_fois(cle: String, quand: float, nom: String, db := 0.0) -> void:
	if _t >= quand and not _sons_joues.has(cle):
		_sons_joues[cle] = true
		if jouer_son.is_valid():
			jouer_son.call(nom, db)


func _fondu(de: float, a: float, t0: float, t1: float) -> float:
	return lerpf(de, a, clampf((_t - t0) / (t1 - t0), 0.0, 1.0))


func _viser(pos: Vector3, cible: Vector3) -> void:
	camera.global_position = pos
	camera.look_at(cible, Vector3.UP)


func _jouer_vide() -> String:
	_noir.color.a = _fondu(1.0, 0.0, 0.0, 0.6) if _t < 6.5 else _fondu(0.0, 1.0, 7.2, DUREE)
	var k := _t / DUREE
	# Depuis la place, on s'approche du temple où la pierre reste froide.
	_viser(Ronde.PIERRE + Vector3(_s.x * 2.5, 0, -(11.0 - k * 6.0)) + Vector3.UP * (4.5 - k * 3.2), Ronde.PIERRE + Vector3.UP * 0.6)
	_une_fois("glas", 0.3, "glas", -6.0)
	if _t < 3.5:
		return "Minuit. La meute s'est réunie autour de la pierre…"
	return "…mais elle n'a choisi personne. La pierre reste froide."


## Le plan est construit comme si la porte était au fond (-Z) ; la seule porte de la maison est celle de
## devant (+Z) : on retourne donc toute la scène d'un demi-tour autour de la maison.
func _local(v: Vector3) -> Vector3:
	return Ronde._vers_monde(_maison, Vector3(-v.x, v.y, -v.z))


## Une chambre au hasard (pas celle du joueur), sa porte de derrière, deux yeux dans le noir.
func _preparer_chambre() -> void:
	var choix := []
	for i in Ronde.NB_MAISONS:
		if i != ma_maison:
			choix.append(i)
	_maison = maison_cible if maison_cible >= 0 else choix[randi() % choix.size()]
	if ronde and ronde._portes.has("%d:avant" % _maison):
		_pivot = ronde._portes["%d:avant" % _maison]["pivot"]
		_pivot_rot = _pivot.rotation.y
	# L'habitant (et quiconque est dans cette chambre) disparaît le temps du plan.
	var scene := get_parent()
	if scene:
		for b: Node in scene.find_children("*", "Bouille", true, false):
			var n3 := b as Node3D
			if n3.visible and Ronde.maison_de(n3.global_position) == _maison:
				n3.visible = false
				_caches.append(n3)
	_bougie = OmniLight3D.new()
	_bougie.light_color = Color(1.0, 0.62, 0.3)
	_bougie.omni_range = 4.5
	_bougie.light_energy = 1.6
	_bougie.shadow_enabled = true
	add_child(_bougie)
	_bougie.global_position = _local(Vector3(-1.4, 1.1, -1.2))
	# La victime : un villageois réveillé, debout face à la porte (pas celui de la chambre : il reste caché).
	_victime = _drap(_maison + 7)
	_victime.visible = false
	add_child(_victime)
	_victime.jouer_emote("gigue")      # elle danse chez elle, sans rien soupçonner
	# Le loup, qu'on voit enfin, et la lune qui l'éclaire derrière la porte.
	_bete = CinemaLoup.new()
	_bete.visible = false
	add_child(_bete)
	_lune_porte = OmniLight3D.new()
	_lune_porte.light_color = Color(0.7, 0.78, 1.0)
	_lune_porte.omni_range = 7.0
	_lune_porte.light_energy = 4.0
	add_child(_lune_porte)
	_lune_porte.global_position = _local(Vector3(-1.2, 2.0, -Ronde.PROFONDEUR * 0.5 - 1.6))
	_choisir_camera()
	if pov:
		_choisir_tete()


## Où la victime a les yeux : on essaie de petits décalages autour de sa place (le poteau de l'encadrement
## n'est pas au même endroit selon la maison) et on garde celui d'où l'on voit le mieux, sans interruption,
## toute la porte et la trajectoire du loup (seuil, milieu de pièce, gorge), le plus près possible de sa place.
func _choisir_tete() -> void:
	var dz := Ronde.PROFONDEUR * 0.5
	var vz := -dz + 1.8
	_tete = Vector3(0.3, 1.6, vz)
	var espace := get_world_3d().direct_space_state if is_inside_tree() else null
	if espace == null:
		return
	if _pivot:
		_pivot.rotation.y = _pivot_rot + deg_to_rad(78.0)
	var cibles: Array[Vector3] = []
	for x in [-0.15, 0.15, 0.45]:
		for y in [0.45, 0.9, 1.4]:
			cibles.append(Vector3(x, y, -dz - 0.2))
	for x in [0.0, 0.2, 0.4]:
		cibles.append(Vector3(x, 0.8, -dz + 0.7))
	# Le battant ouvert : un segment dans le plan du sol (ses vrais points dans le monde, la physique n'ayant
	# pas encore suivi la rotation) — c'est lui, vu presque de profil, qui masquait le loup (Edwin, 04/11).
	var sans: Array[RID] = []     # le corps du battant, resté « fermé » pour la physique jusqu'à la prochaine image
	if ronde and ronde._portes.has("%d:avant" % _maison):
		var corps_porte := (ronde._portes["%d:avant" % _maison]["forme"] as Node).get_parent() as CollisionObject3D
		if corps_porte:
			sans.append(corps_porte.get_rid())
	var battant_a := Vector2.ZERO
	var battant_b := Vector2.ZERO
	if _pivot:
		var ga := _pivot.to_global(Vector3(0.0, 1.0, 0.0))
		var gb := _pivot.to_global(Vector3(1.36, 1.0, 0.0))
		battant_a = Vector2(ga.x, ga.z)
		battant_b = Vector2(gb.x, gb.z)
	var meilleur := -1.0
	for dx in [0.0, -0.2, 0.2, -0.4, 0.4, -0.6, 0.6]:
		for ddz in [0.0, 0.2, -0.2, 0.4]:
			var e := Vector3(0.3 + dx, 1.6, vz + ddz)
			var cam := _local(e)
			var requete := PhysicsPointQueryParameters3D.new()
			requete.position = cam
			if not espace.intersect_point(requete, 1).is_empty():
				continue
			var libres := 0.0
			for c in cibles:
				var but := _local(c)
				var rayon_t := PhysicsRayQueryParameters3D.create(cam, but)
				rayon_t.exclude = sans
				var bloque_battant := _pivot != null and Geometry2D.segment_intersects_segment(Vector2(cam.x, cam.z), Vector2(but.x, but.z), battant_a, battant_b) != null
				if espace.intersect_ray(rayon_t).is_empty() and not bloque_battant:
					libres += 1.0
			# Le gond est de ce côté-là (x > 0) : s'écarter vers l'autre éloigne le battant ouvert de la ligne de mire.
			var score := libres * 10.0 - absf(dx + 0.35) * 6.0 - absf(ddz) * 2.0
			if score > meilleur:
				meilleur = score
				_tete = e
	if _pivot:
		_pivot.rotation.y = _pivot_rot


## Où se tient la caméra : un point DANS la pièce d'où la porte, le loup et la victime se voient sans
## qu'un mur, la porte ouverte ou un meuble s'interpose (lancers de rayons, la porte étant essayée
## ouverte). Le point d'origine (près du mur) n'est gardé que si rien ne le gêne.
func _choisir_camera() -> void:
	var dz := Ronde.PROFONDEUR * 0.5
	var vz := -dz + 1.8
	_oeil_a = Vector3(-2.3, 1.35, 1.3)
	_oeil_b = Vector3(-2.15, 1.3, 0.9)
	var espace := get_world_3d().direct_space_state if is_inside_tree() else null
	if espace == null:
		return
	if _pivot:
		_pivot.rotation.y = _pivot_rot + deg_to_rad(78.0)   # essayée ouverte, le pire cas
	var cibles: Array[Vector3] = [Vector3(0.3, 1.5, vz), Vector3(0.3, 0.9, vz), Vector3(0.2, 1.0, -dz + 0.25),
		Vector3(0.2, 0.8, -dz + 1.0), Vector3(0.3, 0.8, vz + 0.5), Vector3(0.2, 1.4, -dz + 0.6)]
	var meilleur := -1.0
	var essais: Array[Vector3] = []
	# Le battant ouvert est planté en x = 0,6 (gond) : on reste de l'autre côté, loin de son plan.
	for x in [-1.8, -1.3, -0.8, -0.3, 0.1]:
		for z in [1.9, 1.5, 1.1, 0.7]:
			essais.append(Vector3(x, 1.45, z))
	for e in essais:
		var cam := _local(e)
		var requete := PhysicsPointQueryParameters3D.new()
		requete.position = cam
		if not espace.intersect_point(requete, 1).is_empty():
			continue                    # dans un meuble ou un mur
		var libres := 0.0
		for c in cibles:
			var rayon := PhysicsRayQueryParameters3D.create(cam, _local(c))
			if espace.intersect_ray(rayon).is_empty():
				libres += 1.0
		var d := Vector2(e.x - 0.3, e.z - vz).length()
		var score := libres * 10.0 - absf(d - 3.0) - (2.0 if absf(e.x) > 2.0 else 0.0) - absf(e.x + 1.4) * 1.0
		if libres >= cibles.size() and score > meilleur:
			meilleur = score
			_oeil_a = e
			_oeil_b = e + (Vector3(0.3, 1.3, vz) - e).normalized() * 0.5
	if _pivot:
		_pivot.rotation.y = _pivot_rot
	if meilleur < 0.0:
		# Aucun point entièrement dégagé : on garde celui qui voit le plus de cibles.
		var pire := -1.0
		for e in essais:
			var cam2 := _local(e)
			var requete2 := PhysicsPointQueryParameters3D.new()
			requete2.position = cam2
			if not espace.intersect_point(requete2, 1).is_empty():
				continue
			var n := 0.0
			for c in cibles:
				if espace.intersect_ray(PhysicsRayQueryParameters3D.create(cam2, _local(c))).is_empty():
					n += 1.0
			if n > pire:
				pire = n
				_oeil_a = e
				_oeil_b = e + (Vector3(0.3, 1.3, vz) - e).normalized() * 0.5


func _exit_tree() -> void:
	if _pivot:
		_pivot.rotation.y = _pivot_rot
	for b in _caches:
		if is_instance_valid(b):
			b.visible = true


## Le repère de la maison choisie : local -> monde, pour orienter ce qu'on y pose.
func _base() -> Basis:
	return Basis(Vector3.UP, Ronde.angle_maison(_maison))


func _poser(n: Node3D, pos_locale: Vector3, orientation: Basis) -> void:
	n.global_transform = Transform3D(_base() * orientation, _local(pos_locale))


func _jouer() -> String:
	var texte := ""
	var dz := Ronde.PROFONDEUR * 0.5
	var vz := -dz + 1.8                   # là où se tient la victime, face à la porte
	var vx := 0.3
	var t_bond := 4.4                     # le loup quitte le sol
	var t_coupe := 5.1                    # il atteint sa gorge : coupure
	# Le noir : ouverture rapide, coupure sèche à l'impact, éclair rouge juste avant.
	var noir := Color(0, 0, 0, 0)
	if _t < 0.8:
		noir.a = _fondu(1.0, 0.0, 0.0, 0.8)
	elif _t < t_coupe:
		noir.a = 0.0
	elif _t < t_coupe + 0.14:
		noir = Color(0.25, 0.0, 0.0, 0.6)
	else:
		noir.a = 1.0
	_noir.color = noir
	_bougie.light_energy = 1.6 * (0.85 + 0.15 * sin(_t * 13.0) * sin(_t * 7.1 + 1.0))

	# La porte : la poignée grince, puis elle s'ouvre vers la chambre (le gond est du côté +x).
	if _pivot:
		var ouvre := _fondu(0.0, 1.0, T_PORTE, T_PORTE + 0.35)   # la porte s'ouvre d'un coup
		_pivot.rotation.y = _pivot_rot + deg_to_rad(78.0) * ouvre * ouvre * (3.0 - 2.0 * ouvre)
	_une_fois("glas", 0.2, "glas", -8.0)
	_une_fois("poignee", T_PORTE - 0.2, "poignee", -2.0)

	# Le loup : dans le noir derrière la porte, il trotte, s'élance dans la pièce, puis bondit à la gorge.
	var z_porte := -dz
	var z_dep := z_porte - 3.2
	var z_ecart := z_porte - 2.2
	var z_decolle := z_porte - 0.3
	var lx := 0.15
	var loup := Vector3(lx, 0.0, z_dep)
	var tendu := 0.0
	var phase := 0.0
	var gueule := 0.0
	var pitch := 0.0
	if _t < 2.5:
		loup.z = z_dep
	elif _t < 3.4:
		loup.z = lerpf(z_dep, z_ecart, (_t - 2.5) / 0.9)
		phase = _t * 9.0
	elif _t < t_bond:
		var k := (_t - 3.4) / (t_bond - 3.4)
		loup.z = lerpf(z_ecart, z_decolle, k * k)
		phase = 30.0 + _t * lerpf(9.0, 20.0, k)
		gueule = clampf((k - 0.5) * 2.0, 0.0, 1.0) * 0.4
	else:
		var s := clampf((_t - t_bond) / (t_coupe - t_bond), 0.0, 1.0)
		var e := s * s * (3.0 - 2.0 * s)
		loup.z = lerpf(z_decolle, (vz - 0.5) if pov else (vz + 0.05), s)
		loup.x = lerpf(lx, vx, s)
		loup.y = (lerpf(0.0, 1.0, e) + 0.2 * sin(PI * s)) if pov else (lerpf(0.0, 0.35, e) + 0.28 * sin(PI * s))
		pitch = lerpf(0.5, -0.2, s)
		tendu = clampf(s * 3.0, 0.0, 1.0)
		gueule = lerpf(0.4, 1.0, clampf(s * 2.5, 0.0, 1.0))
		phase = 30.0 + _t * 20.0
	_bete.visible = _t > 2.5 and _t < t_coupe + 0.14 and not loup_pov   # le loup, c'est la caméra
	_bete.poser(phase, gueule, tendu)
	# La bête regarde vers -Z (cf. CinemaLoup) et doit foncer vers la victime, à +Z : on la retourne d'abord
	# (sans cela elle avançait à reculons, croupe en avant, et bondissait « à l'envers »).
	_poser(_bete, loup, Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, pitch))
	_bete.lueur.light_energy = _fondu(0.0, 1.4, 2.6, 3.4)

	# La victime : elle se fige face à la porte, recule d'un pas, puis bascule en arrière sous le choc.
	_victime.visible = _t < t_coupe + 0.14 and not pov   # à la 1re personne, la victime, c'est la caméra
	# Elle danse jusqu'à l'ouverture de la porte, s'arrête net, se tourne vers elle.
	if _t >= T_PORTE and not _sons_joues.has("arret_danse"):
		_sons_joues["arret_danse"] = true
		_victime.jouer_emote("")
	var tourne := _fondu(0.0, 1.0, T_PORTE + 0.05, T_PORTE + 0.45)
	var recul := _fondu(0.0, 0.25, 3.6, t_bond + 0.3)
	var chute := _fondu(0.0, 1.0, t_bond + 0.35, t_coupe + 0.1)
	var bascule := Basis(Vector3.RIGHT, chute * 0.95)
	_poser(_victime, Vector3(vx, 0.0, vz + recul + chute * 0.35), bascule * Basis(Vector3.UP, PI * tourne))

	if pov:
		# Ses propres yeux, debout dans sa chambre : elle se tourne vers la porte, voit le loup foncer sur elle.
		var tete := _local(_tete)
		var vise := _local(Vector3(0.2, 1.1, -1.4)).lerp(_local(Vector3(lx, 1.1 + loup.y * 0.5, loup.z)), _fondu(0.0, 1.0, 1.5, 3.6))
		var sec := Vector3.ZERO
		if _t > t_bond + 0.2 and _t < t_coupe + 0.14:
			sec = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.06 * _fondu(0.3, 1.0, t_bond, t_coupe)
		_viser(tete + sec + Vector3(0, 0.05 * sin(_t * 1.7), 0), vise + sec * 0.5)
		if _t > t_bond + 0.1 and not _sons_joues.has("bougie"):
			_sons_joues["bougie"] = true
			_bougie.visible = false
			if ronde:
				ronde.souffler_bougie(_local(Vector3(-1.4, 1.05, -1.2)), 1.5)
		_une_fois("cri", t_coupe - 0.2, "cri", 0.0)
		_une_fois("coeur", 6.6, "coeur", -3.0)
		if _t < 1.7:
			return "Un bruit, chez toi. La poignée de ta porte tourne…"
		if _t < t_coupe + 0.14:
			return "La porte s'ouvre. C'est TOI qu'il est venu chercher."
		return "Il t'a dévoré. Tu deviens un fantôme."

	if loup_pov:
		# Les yeux du loup, bas, depuis le seuil : il trotte vers la porte qui s'ouvre, voit la victime se figer,
		# bondit sur elle. La caméra est la tête de la bête (même trajectoire que le loup vu des autres).
		var ras := 0.75 + 0.04 * sin(phase * 0.5) * (1.0 if _t < t_bond else 0.0)
		var tete_l := _local(Vector3(loup.x, ras + loup.y, loup.z - 0.15))
		var haut := 1.15 + 0.35 * _fondu(0.0, 1.0, T_PORTE, T_PORTE + 1.0)
		var vise_l := _local(Vector3(vx, haut, vz + recul + chute * 0.35))
		if _t < T_PORTE:
			vise_l = _local(Vector3(lx, 1.0, -dz + 1.0))
		var sec_l := Vector3.ZERO
		if _t > t_bond + 0.2 and _t < t_coupe + 0.14:
			sec_l = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.06 * _fondu(0.3, 1.0, t_bond, t_coupe)
		_viser(tete_l + sec_l, vise_l + sec_l * 0.5)
		if _t > t_bond + 0.1 and not _sons_joues.has("bougie"):
			_sons_joues["bougie"] = true
			_bougie.visible = false
			if ronde:
				ronde.souffler_bougie(_local(Vector3(-1.4, 1.05, -1.2)), 1.5)
		_une_fois("cri", t_coupe - 0.2, "cri", 0.0)
		_une_fois("coeur", 6.6, "coeur", -3.0)
		if _t < T_PORTE:
			return "Tu poses la patte sur la porte. Quelqu'un danse derrière."
		if _t < t_coupe + 0.14:
			return "La porte cède. Tu bondis."
		return "Tu l'as dévoré(e)."

	# La caméra : de l'autre côté de l'ouverture, dans la pièce ; elle suit le loup sans le quitter.
	var avance := _fondu(0.0, 1.0, 0.0, t_coupe)
	var oeil := _local(_oeil_a).lerp(_local(_oeil_b), avance)
	var secousse := Vector3.ZERO
	if _t > t_bond + 0.2 and _t < t_coupe + 0.14:
		secousse = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.045 * _fondu(0.3, 1.0, t_bond, t_coupe)
	var cible_attente := _local(Vector3(0.2, 1.0, -1.2))
	var cible_porte := _local(Vector3(0.0, 1.0, -1.4))
	var cible := cible_attente.lerp(cible_porte, _fondu(0.0, 1.0, 1.5, 3.4))
	if _t >= t_bond:
		cible = cible.lerp(_local(Vector3(vx, 1.05, vz - 0.5)), _fondu(0.0, 1.0, t_bond, t_coupe))
	_viser(oeil + secousse, cible + secousse * 0.5)

	# La bougie s'éteint d'un coup quand il bondit.
	if _t > t_bond + 0.1 and not _sons_joues.has("bougie"):
		_sons_joues["bougie"] = true
		_bougie.visible = false
		if ronde:
			ronde.souffler_bougie(_local(Vector3(-1.4, 1.05, -1.2)), 1.5)
	_une_fois("cri", t_coupe - 0.2, "cri", 0.0)
	_une_fois("coeur", 6.6, "coeur", -3.0)

	if _t < 2.4:
		texte = "Minuit. Quelque part dans la Ronde, une porte grince…"
	elif _t < t_coupe + 0.14:
		texte = "Le loup entre chez quelqu'un."
	else:
		texte = "Le village se réveille."
	return texte


## Les bras levés, comme la webcam les décrirait (segments 0 à 3 vers le haut).
func _bras(leves: bool) -> PackedFloat32Array:
	var p := PackedFloat32Array()
	p.resize(36)
	if leves:
		for seg in 4:
			var dir := Vector3(0.25 * (-1.0 if seg < 2 else 1.0), 1.0, 0.15).normalized()
			p[seg * 4] = dir.x
			p[seg * 4 + 1] = dir.y
			p[seg * 4 + 2] = dir.z
			p[seg * 4 + 3] = 1.0
	return p
