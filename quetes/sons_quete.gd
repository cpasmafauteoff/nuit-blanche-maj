class_name SonsQuete
extends RefCounted
## Les sons des mini-jeux de quête refaits à la main (Grand Coffre, Chaudron), synthétisés comme ceux
## de Sons (aucun fichier audio) : le cran d'une molette, le clac de l'anse, la serrure qui résiste,
## le liquide qu'on verse, les bulles du chaudron, une page qu'on tourne, un pot posé.

static var _cache := {}


static func _prendre(nom: String) -> AudioStreamWAV:
	return _cache.get(nom, null) as AudioStreamWAV


static func _ranger(nom: String, t: PackedFloat32Array, crete := Sons.CRETE) -> AudioStreamWAV:
	var s := Sons._finir(t, false, crete)
	_cache[nom] = s
	return s


## Un petit coup de métal : bruit bref + une résonance qui s'éteint.
static func _tic(t: PackedFloat32Array, debut: float, f: float, amp: float, tau: float, bruit: float, r: RandomNumberGenerator) -> void:
	var i0 := int(debut * Sons.FE)
	for i in range(i0, mini(i0 + int(tau * 8.0 * Sons.FE), t.size())):
		var tt := float(i - i0) / Sons.FE
		var v := sin(TAU * f * tt) * 0.6 + sin(TAU * f * 2.71 * tt) * 0.25 + sin(TAU * f * 5.4 * tt) * 0.1
		v += r.randf_range(-1.0, 1.0) * bruit * exp(-tt / 0.0018)
		t[i] += amp * v * exp(-tt / tau) * minf(tt / 0.0005, 1.0)


## Le cran d'une molette : un « tic » sec et mat.
static func cran() -> AudioStreamWAV:
	if _prendre("cran") != null:
		return _prendre("cran")
	var r := Sons._rng(301)
	var t := Sons._tampon(0.09)
	_tic(t, 0.0, 1650.0, 0.8, 0.012, 0.9, r)
	_tic(t, 0.012, 880.0, 0.35, 0.02, 0.2, r)
	return _ranger("cran", t)


## L'anse qui sort du cadenas : un clac lourd puis un tintement de métal.
static func ouverture() -> AudioStreamWAV:
	if _prendre("ouverture") != null:
		return _prendre("ouverture")
	var r := Sons._rng(302)
	var t := Sons._tampon(1.1)
	_tic(t, 0.0, 420.0, 1.0, 0.05, 1.0, r)
	_tic(t, 0.03, 2300.0, 0.6, 0.18, 0.3, r)
	_tic(t, 0.05, 3350.0, 0.35, 0.3, 0.0, r)
	_tic(t, 0.22, 1750.0, 0.3, 0.15, 0.4, r)   # l'anse retombe contre le corps
	return _ranger("ouverture", t)


## L'anse qui résiste : une butée sèche et un cliquetis qui s'éteint.
static func resiste() -> AudioStreamWAV:
	if _prendre("resiste") != null:
		return _prendre("resiste")
	var r := Sons._rng(303)
	var t := Sons._tampon(0.9)
	_tic(t, 0.0, 240.0, 1.0, 0.04, 1.0, r)
	var instant := 0.05
	var amp := 0.7
	while instant < 0.75:
		_tic(t, instant, r.randf_range(1500.0, 2600.0), amp, 0.02, 0.6, r)
		instant += r.randf_range(0.03, 0.07)
		amp *= 0.82
	return _ranger("resiste", t)


## Le couvercle du grand coffre qui se soulève : un long grincement de gonds.
static func gonds() -> AudioStreamWAV:
	if _prendre("gonds") != null:
		return _prendre("gonds")
	var r := Sons._rng(304)
	var t := Sons._tampon(1.8)
	var ph := 0.0
	for i in t.size():
		var tt := float(i) / Sons.FE
		var f := 180.0 + 90.0 * sin(tt * 3.1) + 160.0 * tt / 1.8
		ph += TAU * f / Sons.FE
		var v := sin(ph) * 0.4 + sin(ph * 2.03) * 0.3 + sin(ph * 3.1) * 0.15
		v *= (0.6 + 0.4 * sin(tt * 38.0 + sin(tt * 7.0))) * minf(tt / 0.05, 1.0) * (1.0 - tt / 1.8)
		t[i] = v * 0.6 + r.randf_range(-0.04, 0.04)
	Sons._doux(t, 2800.0, 0.03, 0.15)
	return _ranger("gonds", t, 0.7)


## Un tintement d'or et de lumière : le coffre est ouvert.
static func tresor() -> AudioStreamWAV:
	if _prendre("tresor") != null:
		return _prendre("tresor")
	var r := Sons._rng(305)
	var t := Sons._tampon(2.2)
	var notes: Array[float] = [784.0, 988.0, 1175.0, 1568.0, 1976.0, 2349.0]
	for k in notes.size():
		_tic(t, 0.09 * k, notes[k], 0.5, 0.45, 0.0, r)
		_tic(t, 0.09 * k + 0.02, notes[k] * 2.0, 0.15, 0.3, 0.0, r)
	return _ranger("tresor", t)


## Un liquide qu'on verse : un filet continu qui clapote, ~1,3 s.
static func verse() -> AudioStreamWAV:
	if _prendre("verse") != null:
		return _prendre("verse")
	var r := Sons._rng(306)
	var n := int(1.3 * Sons.FE)
	var t := Sons._bruit(r, n)
	Sons._passe_haut(t, 500.0)
	for i in n:
		var tt := float(i) / Sons.FE
		var env := minf(tt / 0.2, 1.0) * minf((1.3 - tt) / 0.3, 1.0) * 0.8
		t[i] *= env * (0.55 + 0.45 * sin(tt * 61.0 + sin(tt * 9.0) * 2.0))
	# Quelques gouttes qui tombent dans la marmite.
	for g in 9:
		var d := r.randf_range(0.1, 1.15)
		var f0 := r.randf_range(380.0, 900.0)
		var i0 := int(d * Sons.FE)
		var ph := 0.0
		for i in range(i0, mini(i0 + int(0.09 * Sons.FE), n)):
			var tt := float(i - i0) / Sons.FE
			ph += TAU * f0 * (1.0 + 4.0 * tt) / Sons.FE
			t[i] += 0.4 * sin(ph) * exp(-tt / 0.025) * minf(tt / 0.006, 1.0)
	Sons._doux(t, 1600.0, 0.1, 0.2)
	return _ranger("verse", t, 0.6)


## Une bulle qui éclate à la surface : un « bloup » qui monte.
static func bulle() -> AudioStreamWAV:
	if _prendre("bulle") != null:
		return _prendre("bulle")
	var t := Sons._tampon(0.22)
	var ph := 0.0
	for i in t.size():
		var tt := float(i) / Sons.FE
		ph += TAU * (210.0 + 900.0 * tt) / Sons.FE
		t[i] = sin(ph) * exp(-tt / 0.05) * minf(tt / 0.004, 1.0)
	return _ranger("bulle", t)


## Le chaudron qui tourne au noir : un sifflement de vapeur et un grondement.
static func gachis() -> AudioStreamWAV:
	if _prendre("gachis") != null:
		return _prendre("gachis")
	var r := Sons._rng(307)
	var n := int(1.6 * Sons.FE)
	var t := Sons._bruit(r, n)
	Sons._passe_haut(t, 700.0)
	Sons._doux(t, 2200.0, 0.0, 0.0)
	var grave := Sons._bruit(r, n)
	Sons._passe_bas(grave, 160.0)
	for i in n:
		var tt := float(i) / Sons.FE
		t[i] = t[i] * 0.5 * exp(-tt / 0.7) * minf(tt / 0.12, 1.0) + grave[i] * 5.0 * exp(-tt / 0.5) * minf(tt / 0.04, 1.0)
	Sons._doux(t, 1800.0, 0.04, 0.25)
	return _ranger("gachis", t, 0.6)


## Un ingrédient juste : une note claire qui monte.
static func juste() -> AudioStreamWAV:
	if _prendre("juste") != null:
		return _prendre("juste")
	var r := Sons._rng(308)
	var t := Sons._tampon(0.9)
	_tic(t, 0.0, 660.0, 0.6, 0.25, 0.0, r)
	_tic(t, 0.11, 880.0, 0.6, 0.35, 0.0, r)
	return _ranger("juste", t)


## Une page qu'on tourne : un froissement de papier épais.
static func page() -> AudioStreamWAV:
	if _prendre("page") != null:
		return _prendre("page")
	var r := Sons._rng(309)
	var n := int(0.45 * Sons.FE)
	var t := Sons._bruit(r, n)
	Sons._passe_haut(t, 500.0)
	for i in n:
		var tt := float(i) / Sons.FE
		t[i] *= pow(sin(PI * tt / 0.45), 1.5) * (0.85 + 0.15 * sin(tt * 60.0)) * 0.6
	Sons._doux(t, 1700.0, 0.06, 0.12)
	return _ranger("page", t, 0.45)


## Un pot de terre ou de verre qu'on saisit ou qu'on repose : un choc mat et un « tchink ».
static func pot() -> AudioStreamWAV:
	if _prendre("pot") != null:
		return _prendre("pot")
	var r := Sons._rng(310)
	var t := Sons._tampon(0.35)
	_tic(t, 0.0, 190.0, 0.9, 0.03, 0.8, r)
	_tic(t, 0.004, 1320.0, 0.45, 0.08, 0.2, r)
	return _ranger("pot", t)


## Le bouillonnement d'une marmite : un grondement liquide et des bulles, en boucle (2 s).
static func ebullition() -> AudioStreamWAV:
	if _prendre("ebullition") != null:
		return _prendre("ebullition")
	var r := Sons._rng(311)
	var n := int(2.0 * Sons.FE)
	var t := Sons._bruit(r, n)
	Sons._passe_bas(t, 520.0, true)
	for i in n:
		var tt := float(i) / Sons.FE
		t[i] *= 0.5 + 0.5 * sin(TAU * tt * 3.0 + sin(TAU * tt * 5.0))
	for b in 7:
		var d := r.randf_range(0.0, 1.8)
		var f0 := r.randf_range(160.0, 320.0)
		var i0 := int(d * Sons.FE)
		var ph := 0.0
		for i in range(i0, mini(i0 + int(0.14 * Sons.FE), n)):
			var tt := float(i - i0) / Sons.FE
			ph += TAU * f0 * (1.0 + 3.0 * tt) / Sons.FE
			t[i] += 0.6 * sin(ph) * exp(-tt / 0.045) * minf(tt / 0.012, 1.0)
	Sons._doux(t, 1400.0, 0.0, 0.0, true)
	var s := Sons._finir(t, true, 0.55)
	_cache["ebullition"] = s
	return s


## Joue un son dans l'espace, à `pos` (monde), et le libère à la fin.
static func jouer(parent: Node, flux: AudioStream, pos: Vector3, db := 0.0, portee := 6.0) -> void:
	if parent == null or flux == null or not parent.is_inside_tree():
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = flux
	a.bus = "Effets"
	a.volume_db = db
	a.unit_size = portee
	parent.add_child(a)
	a.global_position = pos
	a.play()
	a.finished.connect(a.queue_free)
