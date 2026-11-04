class_name GestesUI
extends Control
## Ce que les gestes face à quelqu'un montrent sur l'écran : la petite roue autour du viseur, l'invite
## « X te propose… : {interagir} accepter », la marque jaune sur le bord quand on nous tape sur l'épaule,
## et l'étourdissement d'un choc contre un mur (1 s d'écran noir, puis flou, étoiles, léger tremblement ; Edwin, 31/10).

signal choisi(type: String)
signal annule

const OR := Color(1.0, 0.82, 0.5)
const R_INTERNE := 46.0
const R_EXTERNE := 132.0
const JAUNE := Color(1.0, 0.85, 0.15)

var camera: Camera3D                 # pour le tremblement

var _ouverte := false
var _titre := ""
var _curseur := Vector2.ZERO         # le déplacement accumulé du pointeur depuis l'ouverture
var _choix := -1                     # le secteur visé
var _age := 0.0

var _proposition: Label
var _proposition_t := 0.0
var _marque_t := 0.0
var _marque_cote := 0
var _etourdi_t := 0.0
var _etourdi_total := 1.0
var _voile: ColorRect
var _mat: ShaderMaterial
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform sampler2D ecran : hint_screen_texture, filter_linear_mipmap;\nuniform float force = 0.0;\nvoid fragment() {\n\tvec3 c = textureLod(ecran, SCREEN_UV, force * 2.4).rgb;\n\tvec2 d = SCREEN_UV - vec2(0.5);\n\tc = mix(c, c * 0.7, force * smoothstep(0.15, 0.75, length(d)));\n\tCOLOR = vec4(c, clamp(force * 3.0, 0.0, 1.0));\n}\n"
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_voile = ColorRect.new()
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile.material = _mat
	_voile.visible = false
	_voile.show_behind_parent = true      # les étoiles se dessinent PAR-DESSUS le flou
	add_child(_voile)
	_voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_proposition = Label.new()
	_proposition.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_proposition.anchor_left = 0.0
	_proposition.anchor_right = 1.0
	_proposition.anchor_top = 0.66
	_proposition.anchor_bottom = 0.66
	_proposition.offset_left = 0
	_proposition.offset_right = 0
	_proposition.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_proposition.add_theme_font_size_override("font_size", 26)
	_proposition.add_theme_color_override("font_color", OR)
	_proposition.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_proposition.add_theme_constant_override("outline_size", 8)
	_proposition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_proposition.visible = false
	add_child(_proposition)


# ---------------------------------------------------------------- la roue

func roue_ouverte() -> bool:
	return _ouverte


func ouvrir(titre: String) -> void:
	_ouverte = true
	_titre = titre
	_curseur = Vector2.ZERO
	_choix = -1
	_age = 0.0
	queue_redraw()


func fermer() -> void:
	_ouverte = false
	queue_redraw()


## Le pointeur de la roue : la souris (ou le stick) y pousse un curseur, borné au rayon.
func bouger(relatif: Vector2) -> void:
	if not _ouverte:
		return
	_curseur += relatif * 0.9
	if _curseur.length() > R_EXTERNE:
		_curseur = _curseur.normalized() * R_EXTERNE
	_choix = Gestes.secteur(_curseur)
	queue_redraw()


## Les flèches : on passe au secteur suivant ou précédent.
func tourner(pas: int) -> void:
	if not _ouverte:
		return
	var n := Gestes.CHOIX.size()
	_choix = 0 if _choix < 0 and pas > 0 else (n - 1 if _choix < 0 else posmod(_choix + pas, n))
	var a := _choix * TAU / n
	_curseur = Vector2(sin(a), -cos(a)) * (R_INTERNE + 20.0)
	queue_redraw()


func choix_courant() -> String:
	return Gestes.CHOIX[_choix][0] if _choix >= 0 else ""


## Valide le secteur visé ; rien de visé : la roue reste ouverte. Rend vrai si un geste est parti.
func valider() -> bool:
	if not _ouverte or _choix < 0:
		return false
	var type: String = Gestes.CHOIX[_choix][0]
	fermer()
	choisi.emit(type)
	return true


func annuler() -> void:
	if _ouverte:
		fermer()
		annule.emit()


func age_roue() -> float:
	return _age


# ---------------------------------------------------------------- invite, marque, étourdissement

func proposer(texte: String, secondes: float) -> void:
	_proposition.text = Options.avec_touches(texte)
	_proposition.visible = true
	_proposition_t = secondes


func proposition_active() -> bool:
	return _proposition_t > 0.0


func effacer_proposition() -> void:
	_proposition_t = 0.0
	_proposition.visible = false


func marquer(cote: int, secondes := Gestes.DUREE_MARQUE) -> void:
	_marque_cote = cote
	_marque_t = secondes
	queue_redraw()


func marque_cote() -> int:
	return _marque_cote if _marque_t > 0.0 else 0


## On vient d'être poussé : la vue part en arrière d'un coup (la tête bascule, le regard monte),
## puis revient. Le corps, lui, recule vraiment (cf. principal._subir_poussee).
const DUREE_BOUSCULE := 0.55
var _bouscule_t := 0.0
## Je pousse : la vue plonge un peu en avant avec les mains (cf. principal._mains_qui_poussent).
const DUREE_ELAN := 0.6
var _elan_t := 0.0


func bousculer() -> void:
	_bouscule_t = DUREE_BOUSCULE


func elancer() -> void:
	_elan_t = DUREE_ELAN


func _secousses(delta: float) -> void:
	if camera == null or camera.top_level or _etourdi_t > 0.0:
		return
	if _bouscule_t > 0.0 or _elan_t > 0.0:
		_bouscule_t = maxf(_bouscule_t - delta, 0.0)
		_elan_t = maxf(_elan_t - delta, 0.0)
		var b := Emotes._coup((DUREE_BOUSCULE - _bouscule_t) * 0.8) if _bouscule_t > 0.0 else 0.0
		var e := Emotes._coup(DUREE_ELAN - _elan_t) if _elan_t > 0.0 else 0.0
		camera.rotation.x = 0.12 * b - 0.05 * e
		camera.rotation.z = 0.03 * b * sin(_t * 40.0)
		camera.position.z = 0.12 * b - 0.18 * e
		camera.v_offset = -0.05 * b
		if _bouscule_t <= 0.0 and _elan_t <= 0.0:
			camera.rotation = Vector3.ZERO
			camera.position = Vector3.ZERO
			camera.v_offset = 0.0


const DUREE_NOIR := 1.0
var _noir: ColorRect
var _noir_t := 0.0


## Le choc : une seconde d'écran noir, puis la tête qui tourne (étoiles, flou) pendant `secondes`.
func etourdir(secondes := Gestes.DUREE_ETOURDI) -> void:
	_etourdi_t = secondes + DUREE_NOIR
	_etourdi_total = maxf(secondes + DUREE_NOIR, 0.1)
	_voile.visible = true
	if _noir == null:
		_noir = ColorRect.new()
		_noir.color = Color.BLACK
		_noir.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_noir.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_noir)
	_noir_t = DUREE_NOIR
	_noir.modulate.a = 1.0
	_noir.visible = true


func etourdi() -> bool:
	return _etourdi_t > 0.0


func _process(delta: float) -> void:
	_t += delta
	_secousses(delta)
	if _ouverte:
		_age += delta
	if _proposition_t > 0.0:
		_proposition_t -= delta
		_proposition.modulate.a = clampf(_proposition_t, 0.0, 1.0)
		if _proposition_t <= 0.0:
			_proposition.visible = false
	if _marque_t > 0.0:
		_marque_t -= delta
		queue_redraw()
	if _noir_t > 0.0:
		_noir_t -= delta
		_noir.modulate.a = clampf(_noir_t / 0.3, 0.0, 1.0)   # se rouvre sur les 0,3 dernières secondes
		if _noir_t <= 0.0:
			_noir.visible = false
	if _etourdi_t > 0.0:
		_etourdi_t -= delta
		var f := clampf(_etourdi_t / _etourdi_total, 0.0, 1.0)
		var intensite := minf(clampf((1.0 - f) * 10.0, 0.0, 1.0), clampf(f / 0.35, 0.0, 1.0))
		_mat.set_shader_parameter("force", intensite)
		if camera:
			var amp := 0.045 * clampf(f * 1.5, 0.0, 1.0)
			camera.h_offset = sin(_t * 71.0) * amp
			camera.v_offset = cos(_t * 63.0) * amp
		queue_redraw()
		if _etourdi_t <= 0.0:
			_voile.visible = false
			if camera:
				camera.h_offset = 0.0
				camera.v_offset = 0.0
			queue_redraw()


# ---------------------------------------------------------------- dessin

func _draw() -> void:
	var taille := size
	var centre := taille * 0.5
	if _marque_t > 0.0:
		_dessiner_marque(taille)
	if _etourdi_t > 0.0:
		_dessiner_etoiles(centre)
	if _ouverte:
		_dessiner_roue(centre)


func _dessiner_marque(taille: Vector2) -> void:
	var a := clampf(_marque_t, 0.0, 1.0) * (0.75 + 0.25 * sin(_t * 6.0))
	var larg := 92.0
	var bord := 0.0 if _marque_cote < 0 else taille.x
	var vers := larg if _marque_cote < 0 else -larg
	var haut := taille.y * 0.18
	var bas := taille.y * 0.82
	var plein := Color(JAUNE.r, JAUNE.g, JAUNE.b, a * 0.85)
	var vide := Color(JAUNE.r, JAUNE.g, JAUNE.b, 0.0)
	draw_polygon(PackedVector2Array([Vector2(bord, haut), Vector2(bord + vers, haut), Vector2(bord + vers, bas), Vector2(bord, bas)]),
		PackedColorArray([plein, vide, vide, plein]))
	# La marque d'une main : trois petites barres au bord, là où l'on a tapé.
	var y0 := taille.y * 0.5
	for k in 3:
		var y := y0 + (k - 1) * 26.0
		draw_line(Vector2(bord + (vers / larg) * 10.0, y), Vector2(bord + (vers / larg) * 44.0, y), Color(1, 0.95, 0.5, a), 7.0, true)


func _dessiner_etoiles(centre: Vector2) -> void:
	var f := clampf(_etourdi_t / _etourdi_total, 0.0, 1.0)
	var haut := Vector2(centre.x, size.y * 0.3)
	for k in 6:
		var a := _t * 5.0 + k * TAU / 6.0
		var p := haut + Vector2(cos(a) * size.x * 0.17, sin(a) * size.y * 0.06) + Vector2(0, sin(_t * 9.0 + k) * 6.0)
		_etoile(p, 16.0 + 4.0 * sin(_t * 8.0 + k), Color(1.0, 0.9, 0.3, clampf(f * 1.6, 0.0, 1.0)))


func _etoile(p: Vector2, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var rr := r if i % 2 == 0 else r * 0.38
		var an := i * PI / 4.0 - PI / 2.0
		pts.append(p + Vector2(cos(an), sin(an)) * rr)
	draw_colored_polygon(pts, c)


func _dessiner_roue(centre: Vector2) -> void:
	var n := Gestes.CHOIX.size()
	var police := get_theme_default_font()
	var ouv := clampf(_age * 7.0, 0.0, 1.0)         # la roue s'ouvre en un clin d'œil
	var r_int := R_INTERNE * ouv
	var r_ext := R_EXTERNE * (0.6 + 0.4 * ouv)
	draw_circle(centre, r_ext + 6.0, Color(0, 0, 0, 0.25 * ouv))
	for i in n:
		var a0 := (i - 0.5) * TAU / n + 0.025
		var a1 := (i + 0.5) * TAU / n - 0.025
		var pts := PackedVector2Array()
		var pas := 10
		for k in pas + 1:
			var a := lerpf(a0, a1, float(k) / pas)
			pts.append(centre + Vector2(sin(a), -cos(a)) * r_ext)
		for k in pas + 1:
			var a := lerpf(a1, a0, float(k) / pas)
			pts.append(centre + Vector2(sin(a), -cos(a)) * r_int)
		var vise := i == _choix
		var accord: bool = Gestes.CHOIX[i][3] == "accord"
		var fond := Color(0.09, 0.07, 0.07, 0.78) if not vise else Color(0.62, 0.45, 0.16, 0.92)
		draw_colored_polygon(pts, fond)
		var bord_c := OR if vise else (Color(0.8, 0.7, 0.55, 0.55) if accord else Color(0.55, 0.5, 0.45, 0.5))
		var contour := pts.duplicate()
		contour.append(pts[0])
		draw_polyline(contour, bord_c, 2.0 if vise else 1.2, true)
		var am := i * TAU / n
		var milieu := centre + Vector2(sin(am), -cos(am)) * (r_ext + r_int) * 0.5
		if ouv > 0.8:
			var nom: String = Langue.t(Gestes.CHOIX[i][1])
			draw_string(police, milieu + Vector2(-44, 5), nom, HORIZONTAL_ALIGNMENT_CENTER, 88, 15, Color.WHITE if vise else Color(0.9, 0.86, 0.8))
	# Le curseur, et le nom complet de ce qu'on vise.
	draw_circle(centre + _curseur * (r_int / R_EXTERNE) * 1.2, 4.0, OR)
	if ouv > 0.8:
		var titre := Langue.t(_titre)
		draw_string(police, centre + Vector2(-260, -r_ext - 16), titre, HORIZONTAL_ALIGNMENT_CENTER, 520, 20, OR)
		var bas: String = Langue.t(Gestes.CHOIX[_choix][2] if _choix >= 0 else "Choisis à la souris, aux flèches ou au stick")
		draw_string(police, centre + Vector2(-260, r_ext + 30), bas, HORIZONTAL_ALIGNMENT_CENTER, 520, 22, Color.WHITE)
		if _choix >= 0 and Gestes.CHOIX[_choix][3] == "accord":
			draw_string(police, centre + Vector2(-260, r_ext + 54), Langue.t("(il devra accepter)"), HORIZONTAL_ALIGNMENT_CENTER, 520, 15, Color(0.85, 0.8, 0.7))
		draw_string(police, centre + Vector2(-260, r_ext + 78), Langue.t("Clic ou relâcher : valider · Échap : annuler"), HORIZONTAL_ALIGNMENT_CENTER, 520, 14, Color(0.7, 0.66, 0.6))
