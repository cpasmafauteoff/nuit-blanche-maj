class_name Calcul
## Calculs purs, testables sans le moteur de jeu complet.


## Moindres carrés régularisés : coefficients c tels que f · c ≈ cible[axe].
## `points` = [[caracteristiques: Array (f[0] = 1), cible: Vector2], …]
static func moindres_carres(points: Array, axe: int, lambda: float) -> PackedFloat64Array:
	var n: int = points[0][0].size()
	var a := []
	for i in n:
		var ligne := PackedFloat64Array()
		ligne.resize(n + 1)
		a.append(ligne)
	for p in points:
		var f: Array = p[0]
		var b: float = p[1].x if axe == 0 else p[1].y
		for i in n:
			for j in n:
				a[i][j] += f[i] * f[j]
			a[i][n] += f[i] * b
	for i in range(1, n):  # on ne pénalise pas la constante
		a[i][i] += lambda * points.size()
	# Élimination de Gauss avec pivot partiel.
	for c in n:
		var piv := c
		for r in range(c + 1, n):
			if absf(a[r][c]) > absf(a[piv][c]):
				piv = r
		var tmp = a[c]
		a[c] = a[piv]
		a[piv] = tmp
		if absf(a[c][c]) < 1e-12:
			continue
		for r in range(c + 1, n):
			var fac: float = a[r][c] / a[c][c]
			for k in range(c, n + 1):
				a[r][k] -= fac * a[c][k]
	var x := PackedFloat64Array()
	x.resize(n)
	for i in range(n - 1, -1, -1):
		var s: float = a[i][n]
		for j in range(i + 1, n):
			s -= a[i][j] * x[j]
		x[i] = s / a[i][i] if absf(a[i][i]) > 1e-12 else 0.0
	return x
