class_name InventaireUI
extends Control
## En bas à droite : les quatre emplacements (touches 1 à 4), l'aide de la souris pour l'objet en main,
## et, au centre de l'écran, la jauge de visée et le « hitmarker » d'un caillou reçu.
## Tout est dessiné en code, dans le style du reste du HUD (IM Fell, parchemin et ombre).

const TAILLE := 64.0
const ECART := 8.0
const MARGE := 26.0
const OR := Color(0.93, 0.78, 0.45)
const PARCHEMIN := Color(0.78, 0.71, 0.56)
const FOND := Color(0.06, 0.04, 0.04, 0.74)
const DUREE_COUP := 0.75

var _slots: Array = [{}, {}, {}, {}]    # {sorte, ouvert, main} ou {}
var _aide := {"gauche": "", "droite": ""}
var _charge := -1.0                     # < 0 : on ne vise pas
var _coups: Array = []                  # {angle, t, tete}
var _t := 0.0
var _verrouille := false                # le vote de quête a les touches 1 à 4 : on grise les numéros
var _choisie := -1                     # la case choisie quand elle est vide (mains vides)
var _invite := Rect2()                  # où est l'invite « Interagir » (vide : pas d'icône)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `slots` : 4 dictionnaires {sorte, ouvert, main} (vides s'il n'y a rien). `aide` : Clics.aide().
func maj(slots: Array, aide: Dictionary, verrouille := false, choisie := -1) -> void:
	if slots != _slots or aide != _aide or verrouille != _verrouille or choisie != _choisie:
		_choisie = choisie
		_slots = slots.duplicate(true)
		_aide = aide.duplicate()
		_verrouille = verrouille
		queue_redraw()


## Une petite souris (bouton gauche éclairé) à gauche du texte « Interagir » (`rect` : celui du texte).
func souris_invite(rect: Rect2) -> void:
	if rect != _invite:
		_invite = rect
		queue_redraw()


func charge(f: float) -> void:
	if not is_equal_approx(f, _charge):
		_charge = f
		queue_redraw()


## Un caillou m'a touché : `angle` = d'où il vient (0 devant, PI/2 à droite…).
func coup(angle: float, tete := false) -> void:
	_coups.append({"angle": angle, "t": DUREE_COUP, "tete": tete})
	queue_redraw()


func a_quelque_chose() -> bool:
	for s: Dictionary in _slots:
		if not s.is_empty():
			return true
	return false


func _process(delta: float) -> void:
	_t += delta
	if not _coups.is_empty():
		for c: Dictionary in _coups:
			c["t"] = float(c["t"]) - delta
		_coups = _coups.filter(func(c): return float(c["t"]) > 0.0)
		queue_redraw()


func _draw() -> void:
	var police := Style.police("titre")
	var texte := Style.police("texte")
	if a_quelque_chose():
		_dessiner_emplacements(police)
		_dessiner_aide(texte)
	var centre := size * 0.5
	if _invite.size != Vector2.ZERO:
		_souris(Vector2(_invite.position.x - 30.0, _invite.position.y + (_invite.size.y - 26.0) * 0.5), true)
	if _charge >= 0.0:
		draw_arc(centre, 24.0, -PI / 2, -PI / 2 + TAU, 40, Color(0, 0, 0, 0.5), 5.0, true)
		draw_arc(centre, 24.0, -PI / 2, -PI / 2 + TAU * clampf(_charge, 0.0, 1.0), 40, OR, 3.0, true)
	for c: Dictionary in _coups:
		_dessiner_coup(centre, c)


func _origine() -> Vector2:
	# Le coin haut-gauche de la rangée d'emplacements.
	var largeur := TAILLE * 4 + ECART * 3
	return Vector2(size.x - MARGE - largeur, size.y - MARGE - TAILLE)


func _dessiner_emplacements(police: Font) -> void:
	var o := _origine()
	for i in 4:
		var r := Rect2(o + Vector2(i * (TAILLE + ECART), 0), Vector2(TAILLE, TAILLE))
		var s: Dictionary = _slots[i]
		var en_main: bool = not s.is_empty() and bool(s.get("main", false))
		var vide_choisie: bool = s.is_empty() and i == _choisie
		draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.45))
		draw_rect(r, FOND)
		draw_rect(r, OR if en_main else (Color(OR, 0.55) if vide_choisie else Color(0.78, 0.71, 0.56, 0.4)), false, 3.0 if (en_main or vide_choisie) else 1.5)
		if en_main:
			draw_rect(r.grow(-4), Color(OR, 0.12))
		if not s.is_empty():
			_icone(r, s)
		var num := str(i + 1)
		var c_num := OR if (en_main or vide_choisie) else Color(0.9, 0.84, 0.7, 0.85)
		if _verrouille:
			c_num.a = 0.3
		draw_string(police, r.position + Vector2(7, 19), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, c_num)


func _icone(r: Rect2, s: Dictionary) -> void:
	var c := r.get_center() + Vector2(0, 3)
	match str(s.get("sorte", "")):
		"caillou":
			var pts := PackedVector2Array()
			for k in 10:
				var a := k * TAU / 10.0
				pts.append(c + Vector2(cos(a) * (16.0 + (k % 3)), sin(a) * (12.0 + ((k + 1) % 2) * 1.5)))
			draw_colored_polygon(pts, Color(0.46, 0.44, 0.41))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.22, 0.2, 0.18), 2.0, true)
			draw_circle(c + Vector2(-5, -4), 3.5, Color(0.64, 0.62, 0.58))
		"page":
			var p := Rect2(c - Vector2(14, 19), Vector2(28, 38))
			draw_rect(p, PARCHEMIN)
			draw_rect(p, Color(0.36, 0.24, 0.14), false, 1.5)
			for k in 4:
				draw_line(p.position + Vector2(5, 9 + k * 7), p.position + Vector2(23 - (k % 2) * 5, 9 + k * 7), Color(0.2, 0.12, 0.1), 1.5)
		_:
			if bool(s.get("ouvert", false)):
				draw_rect(Rect2(c - Vector2(24, 15), Vector2(23, 30)), Color(0.48, 0.28, 0.14))
				draw_rect(Rect2(c + Vector2(1, -15), Vector2(23, 30)), Color(0.48, 0.28, 0.14))
				draw_rect(Rect2(c - Vector2(22, 13), Vector2(21, 26)), PARCHEMIN)
				draw_rect(Rect2(c + Vector2(1, -13), Vector2(21, 26)), PARCHEMIN)
			else:
				var l := Rect2(c - Vector2(15, 20), Vector2(30, 40))
				draw_rect(l, Color(0.48, 0.28, 0.14))
				draw_rect(l, Color(0.26, 0.15, 0.08), false, 1.5)
				draw_rect(Rect2(l.position + Vector2(3, 4), Vector2(3, 32)), Color(0.34, 0.2, 0.1))
			# Le stylo incrusté.
			draw_line(c + Vector2(10, 18), c + Vector2(10, -16), Color(0.1, 0.07, 0.07), 3.0)
			draw_line(c + Vector2(10, -10), c + Vector2(10, -14), OR, 3.0)


## L'aide de la souris, au-dessus des emplacements : une petite souris par bouton utile.
func _dessiner_aide(police: Font) -> void:
	var lignes: Array = []
	if str(_aide.get("gauche", "")) != "":
		lignes.append([true, str(_aide["gauche"])])
	if str(_aide.get("droite", "")) != "":
		lignes.append([false, str(_aide["droite"])])
	if lignes.is_empty():
		return
	var o := _origine()
	var larg := TAILLE * 4 + ECART * 3
	var haut := 30.0 * lignes.size() + 14.0
	var fond := Rect2(Vector2(o.x, o.y - 14.0 - haut), Vector2(larg, haut))
	draw_rect(Rect2(fond.position + Vector2(3, 4), fond.size), Color(0, 0, 0, 0.4))
	draw_rect(fond, FOND)
	draw_rect(fond, Color(0.78, 0.71, 0.56, 0.4), false, 1.5)
	for k in lignes.size():
		var y := fond.position.y + 8.0 + k * 30.0
		_souris(Vector2(fond.position.x + 16.0, y + 1.0), bool(lignes[k][0]))
		draw_string(police, Vector2(fond.position.x + 44.0, y + 21.0), Langue.t(str(lignes[k][1])), HORIZONTAL_ALIGNMENT_LEFT, larg - 56.0, 20, Color(0.95, 0.9, 0.78))


## Une petite souris (15 x 22 px) vue de dessus, le bouton gauche ou droit éclairé.
func _souris(h: Vector2, gauche: bool) -> void:
	var w := 18.0
	var hh := 26.0
	var corps := PackedVector2Array()
	for k in 13:
		var a := PI + k * PI / 12.0       # demi-cercle du haut
		corps.append(h + Vector2(w * 0.5 + cos(a) * w * 0.5, w * 0.5 + sin(a) * w * 0.5))
	corps.append(h + Vector2(w, hh - 4.0))
	corps.append(h + Vector2(w - 3.0, hh))
	corps.append(h + Vector2(3.0, hh))
	corps.append(h + Vector2(0.0, hh - 4.0))
	draw_colored_polygon(corps, Color(0.16, 0.13, 0.12))
	var allume := Color(1.0, 0.82, 0.42)
	# Le bouton éclairé : le quart de cercle du haut, côté choisi, prolongé jusqu'à la séparation.
	var zone := PackedVector2Array()
	zone.append(h + Vector2(w * 0.5, w * 0.5 + 3.5))
	var x_bord := 0.0 if gauche else w
	zone.append(h + Vector2(x_bord, w * 0.5 + 3.5))
	var arc := PackedVector2Array()
	for k in 7:
		var a := PI + k * (PI / 2.0) / 6.0 + (0.0 if gauche else PI / 2.0)
		arc.append(h + Vector2(w * 0.5 + cos(a) * w * 0.5, w * 0.5 + sin(a) * w * 0.5))
	if not gauche:
		arc.reverse()
	zone.append_array(arc)
	draw_colored_polygon(zone, allume)
	draw_polyline(corps + PackedVector2Array([corps[0]]), Color(0.78, 0.71, 0.56, 0.9), 1.4, true)
	draw_line(h + Vector2(w * 0.5, 1.0), h + Vector2(w * 0.5, w * 0.5 + 3.5), Color(0.78, 0.71, 0.56, 0.9), 1.2)
	draw_line(h + Vector2(1.0, w * 0.5 + 3.5), h + Vector2(w - 1.0, w * 0.5 + 3.5), Color(0.78, 0.71, 0.56, 0.9), 1.2)


## Le hitmarker : quatre petits traits en V, dans la direction d'où vient le coup, autour du centre.
func _dessiner_coup(centre: Vector2, c: Dictionary) -> void:
	var f := clampf(float(c["t"]) / DUREE_COUP, 0.0, 1.0)
	var a := float(c["angle"])
	var dir := Vector2(sin(a), -cos(a))
	var perp := Vector2(-dir.y, dir.x)
	f = sqrt(f)      # il reste lisible presque jusqu'au bout
	var rayon := 84.0 + (1.0 - f) * 18.0
	var couleur := Color(1.0, 0.14, 0.08, f) if bool(c["tete"]) else Color(1.0, 0.28, 0.16, f)
	var base := centre + dir * rayon
	for s: float in [-1.0, 1.0]:
		var bout := base + perp * s * 22.0 - dir * 19.0
		draw_line(base + dir * 6.0, bout, Color(0, 0, 0, f * 0.8), 12.0, true)
		draw_line(base + dir * 6.0, bout, couleur, 8.0, true)
	# Un arc discret sous la pointe : on sent d'où ça vient même du coin de l'œil.
	draw_arc(centre, rayon - 8.0, a - PI / 2 - 0.45, a - PI / 2 + 0.45, 16, Color(1.0, 0.25, 0.15, f * 0.55), 4.0, true)
