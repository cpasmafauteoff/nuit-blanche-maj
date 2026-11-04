class_name DosDeCarte
extends Control
## Le dos de la carte de rôle, dessiné (cf. Cosmetiques, famille « carte ») : celui d'origine,
## la gravure, le vitrail ou le sang séché. Il ne se voit que sur l'écran de son propriétaire.

var sorte := ""
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if sorte == "vitrail":
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var c := size * 0.5
	var m := minf(size.x, size.y)
	match sorte:
		"gravure":
			draw_rect(r, Color(0.86, 0.8, 0.66))
			for k in 40:
				var y := r.size.y * k / 40.0
				draw_line(Vector2(0, y), Vector2(r.size.x, y + 6), Color(0.35, 0.28, 0.2, 0.15), 1.0)
			_cadre(r, Color(0.22, 0.16, 0.1), 3.0)
			_entrelacs(r.grow(-12), Color(0.25, 0.18, 0.12))
			_loup(c, m * 0.32, Color(0.18, 0.13, 0.09))
			draw_arc(c + Vector2(0, -m * 0.05), m * 0.3, 0, TAU, 48, Color(0.25, 0.18, 0.12), 1.5)
		"vitrail":
			draw_rect(r, Color(0.05, 0.05, 0.07))
			var rng := RandomNumberGenerator.new()
			rng.seed = 41
			var couleurs := [Color(0.55, 0.08, 0.1), Color(0.1, 0.22, 0.55), Color(0.65, 0.48, 0.1), Color(0.12, 0.38, 0.2), Color(0.35, 0.1, 0.45)]
			var pts := []
			for k in 22:
				pts.append(Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y))
			# Des éclats de verre : un triangle par voisin, sertis de plomb.
			for k in pts.size():
				var a: Vector2 = pts[k]
				var b: Vector2 = pts[(k + 3) % pts.size()]
				var d: Vector2 = pts[(k + 7) % pts.size()]
				var lueur := 0.75 + 0.25 * sin(_t * 1.5 + k)
				draw_colored_polygon(PackedVector2Array([a, b, d]), (couleurs[k % couleurs.size()] as Color) * lueur)
				draw_polyline(PackedVector2Array([a, b, d, a]), Color(0.08, 0.07, 0.06), 2.5)
			draw_circle(c, m * 0.2, Color(0.95, 0.9, 0.7, 0.95))
			draw_arc(c, m * 0.2, 0, TAU, 40, Color(0.08, 0.07, 0.06), 4.0)
			draw_circle(c + Vector2(m * 0.08, -m * 0.03), m * 0.15, Color(0.05, 0.05, 0.07, 0.9))
			_cadre(r, Color(0.08, 0.07, 0.06), 6.0)
			_cadre(r.grow(-6), Color(0.65, 0.5, 0.2), 1.5)
		"sang":
			draw_rect(r, Color(0.78, 0.68, 0.5))
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for k in 60:
				var p := Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
				draw_circle(p, rng.randf_range(1, 5), Color(0.45, 0.33, 0.2, 0.12))
			for k in 18:
				var p := c + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4)) * size
				draw_circle(p, rng.randf_range(2, 9), Color(0.38, 0.03, 0.03, 0.85))
			# L'empreinte de patte : quatre doigts, une paume.
			var rouge := Color(0.42, 0.02, 0.02, 0.92)
			draw_circle(c + Vector2(0, m * 0.08), m * 0.13, rouge)
			for k in 4:
				var a := -PI / 2 + (k - 1.5) * 0.42
				draw_circle(c + Vector2(cos(a), sin(a)) * m * 0.22 + Vector2(0, m * 0.02), m * 0.055, rouge)
			_cadre(r, Color(0.3, 0.2, 0.12), 3.0)
		_:
			# Celui d'origine : velours sang, filets d'or, une lune.
			draw_rect(r, Color(0.28, 0.04, 0.05))
			for k in 12:
				var y := r.size.y * k / 12.0
				draw_line(Vector2(0, y), Vector2(r.size.x, y), Color(0.2, 0.02, 0.03), 1.0)
			_cadre(r.grow(-8), Color(0.85, 0.65, 0.3), 2.0)
			_cadre(r.grow(-14), Color(0.85, 0.65, 0.3, 0.5), 1.0)
			draw_circle(c, m * 0.18, Color(0.9, 0.82, 0.6))
			draw_circle(c + Vector2(m * 0.07, -m * 0.03), m * 0.15, Color(0.28, 0.04, 0.05))


func _cadre(r: Rect2, c: Color, e: float) -> void:
	draw_rect(r, c, false, e)


func _entrelacs(r: Rect2, c: Color) -> void:
	for k in 8:
		var t := k / 8.0
		for coin: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			draw_arc(coin, 10.0 + k * 3.0, 0, TAU, 20, Color(c, 0.4 - t * 0.04), 1.0)


func _loup(c: Vector2, t: float, col: Color) -> void:
	# Une tête de loup de profil, levée vers la lune.
	var pts := PackedVector2Array([
		c + Vector2(-0.55, 0.6) * t, c + Vector2(-0.4, 0.1) * t, c + Vector2(-0.45, -0.35) * t,
		c + Vector2(-0.3, -0.55) * t, c + Vector2(-0.2, -0.95) * t, c + Vector2(-0.05, -0.5) * t,
		c + Vector2(0.15, -0.45) * t, c + Vector2(0.6, -0.75) * t, c + Vector2(0.55, -0.55) * t,
		c + Vector2(0.3, -0.25) * t, c + Vector2(0.25, 0.05) * t, c + Vector2(0.4, 0.6) * t])
	draw_colored_polygon(pts, col)
	draw_circle(c + Vector2(0.05, -0.42) * t, t * 0.05, Color(0.86, 0.8, 0.66))
