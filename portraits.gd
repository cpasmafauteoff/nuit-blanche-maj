class_name Portraits
extends Node
## La petite icône d'un joueur : son villageois en gros plan, photographié une fois hors écran
## puis gardé en mémoire (une apparence = une image).

const TAILLE := 96

var _vue: SubViewport
var _cache := {}          # apparence -> ImageTexture
var _attente := {}        # apparence -> [Callable]
var _file: Array[int] = []
var _sujet: Bouille
var _en_cours := -1
var _images := 0


func _ready() -> void:
	_vue = SubViewport.new()
	_vue.size = Vector2i(TAILLE, TAILLE)
	_vue.own_world_3d = true
	_vue.transparent_bg = false
	_vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vue)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.09, 0.06, 0.06)
	env.environment.ambient_light_color = Color(0.4, 0.38, 0.42)
	env.environment.ambient_light_energy = 0.6
	_vue.add_child(env)
	var lampe := OmniLight3D.new()
	lampe.light_color = Color(1.0, 0.7, 0.45)
	lampe.light_energy = 2.0
	lampe.omni_range = 4.0
	lampe.position = Vector3(0.5, 1.9, 1.0)
	_vue.add_child(lampe)
	var cam := Camera3D.new()
	cam.fov = 24
	_vue.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.62, 1.35), Vector3(0, 1.56, 0))


## Donne l'image tout de suite si elle existe, sinon l'appelle dès qu'elle est prise.
func demander(apparence: int, rappel: Callable) -> void:
	if _cache.has(apparence):
		rappel.call(_cache[apparence])
		return
	if not _attente.has(apparence):
		_attente[apparence] = []
		_file.append(apparence)
	_attente[apparence].append(rappel)


## Une case prête à poser dans l'interface ; l'image arrive quand elle est prise.
func icone(apparence: int, cote := 40) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(cote, cote)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# Référence faible : la case peut être libérée (panneau refermé) avant que l'image arrive.
	var w: WeakRef = weakref(t)
	demander(apparence, func(tex: Texture2D):
		var c = w.get_ref()
		if c != null:
			c.texture = tex)
	return t


func _process(_delta: float) -> void:
	if _en_cours < 0:
		if _file.is_empty():
			return
		if DisplayServer.get_name() == "headless":
			_file.clear()
			_attente.clear()
			return
		_en_cours = _file.pop_front()
		if _sujet:
			_sujet.queue_free()
		_sujet = Bouille.new()
		_sujet.autonome = false
		_sujet.apparence = Bouille.decoder(_en_cours)
		_vue.add_child(_sujet)
		_sujet.regarder(Vector3(0, 1.6, 2.0))
		_images = 0
		return
	_images += 1
	if _images < 4:
		return
	var img := _vue.get_texture().get_image()
	if img == null or img.is_empty():
		# sans carte graphique (tests --headless) : pas de photo, la case reste vide
		_attente.erase(_en_cours)
		_en_cours = -1
		return
	var tex := ImageTexture.create_from_image(img)
	_cache[_en_cours] = tex
	for r: Callable in _attente.get(_en_cours, []):
		if r.is_valid():
			r.call(tex)
	_attente.erase(_en_cours)
	_en_cours = -1
