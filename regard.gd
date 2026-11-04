extends Node
## Transforme les mesures du capteur en point regardé sur l'écran.
##
## Trois sources de réglage :
##  1. la taille de l'écran (lue sur Windows, corrigeable) et la distance de jeu
##     (mesurée par l'iris, que le joueur confirme) ;
##  2. le calibrage « luciole » : le joueur suit des yeux une luciole ;
##  3. le recalage discret : chaque clic sur un personnage ajoute un point,
##     puisqu'on regarde forcément ce sur quoi on clique.

const FICHIER := "user://reglages.cfg"
const LAMBDA := 0.00001       # régularisation, évite les coefficients fous
const MAX_CLICS := 40
const NB_MESURES := 7  # taille de caracteristiques()

var ecran_pouces := 24.0
var ecran_auto := false        # vrai si la taille vient de Windows
var distance_ref_cm := 60.0    # distance au moment du calibrage
var correction_focale := 1.0   # ajuste l'estimation par l'iris à la distance annoncée
var neutre_tx := 0.0
var neutre_ty := 0.0
var calibre := false
var precision_cm := -1.0

var _coef_x := PackedFloat64Array()
var _coef_y := PackedFloat64Array()
var _echantillons: Array = []  # [caracteristiques: Array, cible: Vector2]
var _clics: Array = []
var _lisse := Vector2(-1, -1)
var _thread: Thread


func _ready() -> void:
	_charger()
	if not ecran_auto:
		_thread = Thread.new()
		_thread.start(_lire_taille_ecran)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


## Lit la taille physique de l'écran dans l'EDID via Windows (en cm).
func _lire_taille_ecran() -> void:
	var sortie := []
	var cmd := "Get-CimInstance -Namespace root\\wmi -ClassName WmiMonitorBasicDisplayParams | ForEach-Object { \"$($_.MaxHorizontalImageSize) $($_.MaxVerticalImageSize)\" }"
	OS.execute("powershell", ["-NoProfile", "-Command", cmd], sortie)
	for ligne in "\n".join(sortie).split("\n"):
		var p := ligne.strip_edges().split(" ")
		if p.size() == 2 and p[0].to_float() > 10:
			var diag_cm := Vector2(p[0].to_float(), p[1].to_float()).length()
			call_deferred("_taille_trouvee", diag_cm / 2.54)
			return


func _taille_trouvee(pouces: float) -> void:
	ecran_pouces = snappedf(pouces, 0.1)
	ecran_auto = true


## Pixels du viewport par centimètre réel sur l'écran.
func pixels_par_cm() -> float:
	var ecran := Vector2(DisplayServer.screen_get_size())
	var diag_cm := ecran_pouces * 2.54
	var px_cm_ecran := ecran.length() / diag_cm
	var vue := get_viewport().get_visible_rect().size
	var fenetre := Vector2(DisplayServer.window_get_size())
	var echelle := fenetre.x / vue.x if vue.x > 0 else 1.0
	return px_cm_ecran / echelle


func distance_cm() -> float:
	return Capteur.distance_cm(correction_focale)


## Le joueur annonce sa distance : on recale l'estimation par l'iris dessus.
func annoncer_distance(cm: float) -> void:
	var brute := Capteur.distance_cm(1.0)
	if brute > 0:
		correction_focale = cm / brute
	distance_ref_cm = cm


func caracteristiques() -> Array:
	var d := distance_cm()
	var k := d / distance_ref_cm if d > 0 else 1.0
	k = clampf(k, 0.5, 2.0)
	# Deux lectures indépendantes du regard : la position de l'iris dans l'œil
	# (géométrie) et la direction des yeux estimée par MediaPipe (réseau dédié).
	# Le calibrage apprend combien se fier à chacune.
	var e := func(n): return Capteur.expression(n)
	var bh: float = (e.call("eyeLookOutLeft") + e.call("eyeLookInRight") - e.call("eyeLookInLeft") - e.call("eyeLookOutRight")) * 0.5
	var bv: float = (e.call("eyeLookUpLeft") + e.call("eyeLookUpRight") - e.call("eyeLookDownLeft") - e.call("eyeLookDownRight")) * 0.5
	return [
		1.0,
		(Capteur.gx - 0.5) * k,
		(Capteur.gy - 0.5) * k,
		(Capteur.tx - neutre_tx) * k,
		(Capteur.ty - neutre_ty) * k,
		bh * k,
		bv * k,
	]


func noter_neutre() -> void:
	neutre_tx = Capteur.tx
	neutre_ty = Capteur.ty


func vider_calibrage() -> void:
	_echantillons.clear()
	_clics.clear()
	calibre = false


func ajouter(cible: Vector2) -> void:
	_echantillons.append([caracteristiques(), cible])


## Recalage discret : le joueur a cliqué sur `cible`, il la regardait.
func recaler_sur(cible: Vector2) -> void:
	if not calibre or Capteur.mode_souris:
		return
	_clics.append([caracteristiques(), cible])
	if _clics.size() > MAX_CLICS:
		_clics.pop_front()
	ajuster()


func ajuster() -> bool:
	var tous := _echantillons + _clics
	if tous.size() < 10:
		return false
	_coef_x = Calcul.moindres_carres(tous, 0, LAMBDA)
	_coef_y = Calcul.moindres_carres(tous, 1, LAMBDA)
	calibre = true
	_sauver()
	return true


func point_brut() -> Vector2:
	if Capteur.mode_souris:
		# Souris capturée (vue à la première personne) : on regarde au centre.
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			return get_viewport().get_visible_rect().size * 0.5
		return get_viewport().get_mouse_position()
	if not calibre:
		var vue := get_viewport().get_visible_rect().size
		return vue * 0.5
	var f := caracteristiques()
	var p := Vector2.ZERO
	for i in f.size():
		p.x += _coef_x[i] * f[i]
		p.y += _coef_y[i] * f[i]
	return p


## Point regardé, lissé et borné à l'écran.
func point_ecran(delta: float) -> Vector2:
	var vue := get_viewport().get_visible_rect().size
	var p := point_brut().clamp(Vector2.ZERO, vue)
	if _lisse.x < 0:
		_lisse = p
	_lisse = _lisse.lerp(p, clampf(delta * 12.0, 0.0, 1.0))
	return _lisse


func _sauver() -> void:
	var c := ConfigFile.new()
	c.set_value("ecran", "pouces", ecran_pouces)
	c.set_value("ecran", "auto", ecran_auto)
	c.set_value("regard", "distance_ref_cm", distance_ref_cm)
	c.set_value("regard", "correction_focale", correction_focale)
	c.set_value("regard", "neutre", Vector2(neutre_tx, neutre_ty))
	c.set_value("regard", "coef_x", _coef_x)
	c.set_value("regard", "coef_y", _coef_y)
	c.set_value("regard", "precision_cm", precision_cm)
	c.save(FICHIER)


func sauver() -> void:
	_sauver()


func _charger() -> void:
	var c := ConfigFile.new()
	if c.load(FICHIER) != OK:
		return
	ecran_pouces = c.get_value("ecran", "pouces", ecran_pouces)
	ecran_auto = c.get_value("ecran", "auto", false)
	distance_ref_cm = c.get_value("regard", "distance_ref_cm", distance_ref_cm)
	correction_focale = c.get_value("regard", "correction_focale", 1.0)
	var n: Vector2 = c.get_value("regard", "neutre", Vector2.ZERO)
	neutre_tx = n.x
	neutre_ty = n.y
	_coef_x = c.get_value("regard", "coef_x", PackedFloat64Array())
	_coef_y = c.get_value("regard", "coef_y", PackedFloat64Array())
	precision_cm = c.get_value("regard", "precision_cm", -1.0)
	# Un réglage fait avec une autre liste de mesures ne vaut plus : on recalibre.
	calibre = _coef_x.size() == NB_MESURES and _coef_y.size() == NB_MESURES
	if not calibre:
		precision_cm = -1.0
