class_name Sons extends RefCounted
## Sons synthétisés par code (aucun fichier audio) : 16 bits, mono, 22050 Hz, mis en cache.

const FE: int = 22050
const CRETE: float = 0.85
const FONDU: int = 66 # ~3 ms

static var _cache: Dictionary = {}


# ---------------------------------------------------------------- outils

static func _rng(graine: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	return r


static func _tampon(duree: float) -> PackedFloat32Array:
	var t := PackedFloat32Array()
	t.resize(int(duree * FE))
	return t


static func _bruit(r: RandomNumberGenerator, n: int) -> PackedFloat32Array:
	var t := PackedFloat32Array()
	t.resize(n)
	for i in n:
		t[i] = r.randf_range(-1.0, 1.0)
	return t


## Passe-bas à un pôle ; `circ` fait un tour de chauffe pour que la boucle se raccorde.
static func _passe_bas(t: PackedFloat32Array, fc: float, circ: bool = false) -> void:
	var a: float = 1.0 - exp(-TAU * fc / FE)
	var y: float = 0.0
	if circ:
		for i in t.size():
			y += a * (t[i] - y)
	for i in t.size():
		y += a * (t[i] - y)
		t[i] = y


static func _passe_haut(t: PackedFloat32Array, fc: float, circ: bool = false) -> void:
	var b: PackedFloat32Array = t.duplicate()
	_passe_bas(b, fc, circ)
	for i in t.size():
		t[i] -= b[i]


## Normalise (crête 0.85), fondus anti-clic (sauf boucle) et produit le flux.
static func _finir(t: PackedFloat32Array, boucle: bool, crete_voulue: float = CRETE) -> AudioStreamWAV:
	var n: int = t.size()
	var crete: float = 0.0
	for i in n:
		if is_nan(t[i]) or is_inf(t[i]):
			t[i] = 0.0
		crete = maxf(crete, absf(t[i]))
	var gain: float = crete_voulue / crete if crete > 0.0 else 0.0
	var octets := PackedByteArray()
	octets.resize(n * 2)
	for i in n:
		var v: float = t[i] * gain
		if not boucle:
			if i < FONDU:
				v *= float(i) / FONDU
			elif i >= n - FONDU:
				v *= float(n - 1 - i) / FONDU
		octets.encode_s16(i * 2, clampi(roundi(v * 32767.0), -32768, 32767))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = FE
	s.stereo = false
	s.data = octets
	if boucle:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = n
	return s


## Adoucit un son à base de bruit (retour d'Edwin, 01/11 : « un son de balai ») : passe-bas à deux pôles
## (rien de fort au-dessus de `fc`), attaque et fin en douceur (`attaque`, `fin` en secondes ; ignorés en boucle).
static func _doux(t: PackedFloat32Array, fc: float, attaque: float, fin: float, boucle: bool = false) -> void:
	_passe_bas(t, fc, boucle)
	_passe_bas(t, fc, boucle)
	if boucle:
		return
	var n: int = t.size()
	var na: int = mini(int(attaque * FE), n / 2)
	var nf: int = mini(int(fin * FE), n / 2)
	for i in na:
		var u: float = float(i) / na
		t[i] *= u * u * (3.0 - 2.0 * u)
	for i in nf:
		var u2: float = float(i) / nf
		t[n - 1 - i] *= u2 * u2 * (3.0 - 2.0 * u2)


static func _ranger(nom: String, s: AudioStreamWAV) -> AudioStreamWAV:
	_cache[nom] = s
	return s


## Fréquence arrondie à un nombre entier de cycles sur la durée (boucle sans clic).
static func _entier(f: float, duree: float) -> float:
	return roundf(f * duree) / duree


## Impulsion grave qui retombe (battement de coeur).
static func _thump(t: PackedFloat32Array, debut: float, f: float, amp: float, tau: float) -> void:
	var i0: int = int(debut * FE)
	var ph: float = 0.0
	for i in range(i0, t.size()):
		var tt: float = float(i - i0) / FE
		ph += TAU * f * (0.65 + 0.35 * exp(-tt / 0.05)) / FE
		t[i] += amp * sin(ph) * minf(tt / 0.006, 1.0) * exp(-tt / tau)


## Cloche : partiels inharmoniques, les aigus s'éteignent plus vite.
static func _cloche_synth(f0: float, duree: float, tau0: float, graine: int) -> PackedFloat32Array:
	var r := _rng(graine)
	var t := _tampon(duree)
	var rap: Array[float] = [0.5, 1.0, 1.19, 1.56, 2.0, 2.66]
	var amp: Array[float] = [0.9, 1.0, 0.55, 0.45, 0.4, 0.25]
	var phi: Array[float] = []
	for k in rap.size():
		phi.append(r.randf() * TAU)
	for i in t.size():
		var tt: float = float(i) / FE
		var v: float = 0.0
		for k in rap.size():
			var tau: float = tau0 / (0.5 + rap[k])
			v += amp[k] * sin(TAU * f0 * rap[k] * tt + phi[k]) * exp(-tt / tau)
		t[i] = v * minf(tt / 0.004, 1.0)
	# frappe du battant
	var choc := _bruit(r, int(0.05 * FE))
	_passe_bas(choc, 2500.0)
	for i in choc.size():
		t[i] += 0.5 * choc[i] * exp(-float(i) / FE / 0.01)
	return t


## Crépitements : petits éclats de bruit semés au hasard (feuilles, gravier).
static func _crepitements(t: PackedFloat32Array, r: RandomNumberGenerator, n_ev: int, tau: float, profil: int) -> void:
	var duree: float = float(t.size()) / FE
	var longueur: int = int(tau * 6.0 * FE)
	var faits: int = 0
	while faits < n_ev:
		var ts: float = r.randf() * (duree - tau * 6.0)
		var p: float = sin(PI * ts / duree) if profil == 0 else exp(-ts / (duree * 0.35))
		if r.randf() > p:
			continue
		faits += 1
		var amp: float = r.randf_range(0.3, 1.0)
		var i0: int = int(ts * FE)
		for j in longueur:
			if i0 + j >= t.size():
				break
			t[i0 + j] += amp * r.randf_range(-1.0, 1.0) * exp(-float(j) / FE / tau)


# ---------------------------------------------------------------- sons ponctuels

const SOLS_PAS := ["pave", "planches", "graviers", "terre", "flaques"]


## Un vrai pas enregistré selon le sol (Kenney, CC0 : sons/pas/), 5 variantes. Les pas fabriqués
## par calcul sonnaient comme sur un plancher partout (Edwin, 31/10).
## Retour d'Edwin (01/11) : « j'entends toujours des bruits de balai » = les enregistrements « herbe »
## (0,6 à 0,8 s de frottement long). Plus aucun sol n'utilise l'herbe : de la terre au sentier, ce sont
## des pas courts et sourds (0,11 à 0,14 s), le gravier garde son craquement.
const PAS_ENREGISTRES := {
	"pave": ["concrete_001", "concrete_002", "concrete_001", "concrete_002", "concrete_000"],
	"planches": ["wood_000", "wood_001", "wood_002", "wood_003", "wood_004"],
	"graviers": ["snow_001", "snow_002", "snow_003", "snow_004", "snow_001"],
	"terre": ["concrete_000", "concrete_003", "concrete_004", "concrete_003", "concrete_000"],
	"flaques": ["concrete_004", "concrete_000", "concrete_003", "concrete_004", "concrete_000"],
	"feuilles": ["carpet_000", "carpet_003", "carpet_004", "carpet_003", "carpet_000"],
}


static func pas(sol: String, variante: int) -> AudioStream:
	var liste: Array = PAS_ENREGISTRES.get(sol, PAS_ENREGISTRES["terre"])
	var fichier := "res://sons/pas/footstep_%s.ogg" % liste[posmod(variante, liste.size())]
	if ResourceLoader.exists(fichier):
		return load(fichier)
	return pas_fabrique(sol, variante)


static func pas_fabrique(sol: String, variante: int) -> AudioStreamWAV:
	var cle := "pas_%s_%d" % [sol, variante]
	if _cache.has(cle):
		return _cache[cle] as AudioStreamWAV
	var r := _rng(300 + SOLS_PAS.find(sol) * 10 + variante)
	var t := _tampon(0.25)
	var n := t.size()
	match sol:
		"pave":
			_thump(t, 0.0, r.randf_range(95.0, 120.0), 0.5, 0.025)
			var claque := _bruit(r, n)
			_passe_haut(claque, 2200.0)
			for i in n:
				var tt := float(i) / FE
				t[i] += claque[i] * (0.9 * exp(-tt / 0.008) + 0.5 * exp(-maxf(tt - 0.06, 0.0) / 0.012) * (1.0 if tt > 0.06 else 0.0))
		"planches":
			_thump(t, 0.0, r.randf_range(150.0, 190.0), 0.8, 0.05)
			_thump(t, 0.055, r.randf_range(210.0, 260.0), 0.35, 0.04)
			var bois := _bruit(r, n)
			_passe_bas(bois, 1800.0)
			for i in n:
				t[i] += bois[i] * 0.5 * exp(-float(i) / FE / 0.02)
		"graviers":
			_thump(t, 0.0, 90.0, 0.25, 0.03)
			_crepitements(t, r, 22, 0.0018, 1)
			_passe_haut(t, 900.0)
		"terre":
			_thump(t, 0.0, r.randf_range(70.0, 90.0), 0.6, 0.04)
			var sourd := _bruit(r, n)
			_passe_bas(sourd, 700.0)
			for i in n:
				t[i] += sourd[i] * 0.8 * exp(-float(i) / FE / 0.035)
		_:
			_thump(t, 0.0, 85.0, 0.4, 0.03)
			var eau := _bruit(r, n)
			_passe_bas(eau, 2500.0)
			for i in n:
				var tt := float(i) / FE
				t[i] += eau[i] * 0.7 * exp(-tt / 0.06) * (0.6 + 0.4 * sin(TAU * 38.0 * tt))
	return _ranger(cle, _finir(t, false))

## Cloche de chapelle, grave, ~3,5 s.
static func cloche() -> AudioStreamWAV:
	if _cache.has("cloche"):
		return _cache["cloche"] as AudioStreamWAV
	return _ranger("cloche", _finir(_cloche_synth(220.0, 3.5, 1.05, 101), false))


## Glas : cloche plus grave et lente, 5 s.
static func glas() -> AudioStreamWAV:
	if _cache.has("glas"):
		return _cache["glas"] as AudioStreamWAV
	return _ranger("glas", _finir(_cloche_synth(140.0, 5.0, 1.5, 102), false))


## Battement « lub-dub » sourd, ~0,6 s.
static func coeur() -> AudioStreamWAV:
	if _cache.has("coeur"):
		return _cache["coeur"] as AudioStreamWAV
	var t := _tampon(0.6)
	_thump(t, 0.0, 70.0, 1.0, 0.07)
	_thump(t, 0.24, 58.0, 0.75, 0.08)
	return _ranger("coeur", _finir(t, false))


## Planche qui craque : grincement en glissando + bruit filtré, ~0,5 s.
static func craquement() -> AudioStreamWAV:
	if _cache.has("craquement"):
		return _cache["craquement"] as AudioStreamWAV
	var r := _rng(103)
	var duree: float = 0.5
	var t := _tampon(duree)
	var bruit := _bruit(r, t.size())
	_passe_bas(bruit, 900.0)
	var ph: float = 0.0
	for i in t.size():
		var tt: float = float(i) / FE
		var u: float = tt / duree
		ph += (150.0 + 170.0 * u * u + 25.0 * sin(TAU * 9.0 * tt)) / FE
		var scie: float = fposmod(ph, 1.0) * 2.0 - 1.0
		var accroche: float = 0.55 + 0.45 * sin(TAU * 23.0 * tt)
		var env: float = pow(sin(PI * u), 1.5)
		t[i] = (scie * accroche * 0.6 + bruit[i] * 1.5) * env
	_passe_bas(t, 2200.0)
	# claquement au début, plus mat qu'avant
	for i in int(0.018 * FE):
		t[i] += r.randf_range(-1.0, 1.0) * exp(-float(i) / FE / 0.004) * 0.3
	_doux(t, 1400.0, 0.012, 0.1)
	return _ranger("craquement", _finir(t, false, 0.65))


## Pied dans une flaque : éclaboussure + bulles, ~0,4 s.
static func clapotis() -> AudioStreamWAV:
	if _cache.has("clapotis"):
		return _cache["clapotis"] as AudioStreamWAV
	var r := _rng(104)
	var t := _bruit(r, int(0.4 * FE))
	_passe_haut(t, 400.0)
	for i in t.size():
		var tt: float = float(i) / FE
		t[i] *= 0.6 * exp(-tt / 0.07) * minf(tt / 0.01, 1.0)
	for b in 6:
		var debut: float = r.randf_range(0.0, 0.28)
		var f0: float = r.randf_range(500.0, 900.0)
		var i0: int = int(debut * FE)
		var ph: float = 0.0
		for i in range(i0, mini(i0 + int(0.12 * FE), t.size())):
			var tt: float = float(i - i0) / FE
			ph += TAU * f0 * (1.0 + 3.0 * tt) / FE
			t[i] += 0.35 * sin(ph) * exp(-tt / 0.03) * minf(tt / 0.004, 1.0)
	_doux(t, 1700.0, 0.008, 0.08)
	return _ranger("clapotis", _finir(t, false, 0.6))


## Un corps qui se cogne contre un mur : un bruit sourd, court (~0,35 s).
static func choc() -> AudioStreamWAV:
	if _cache.has("choc"):
		return _cache["choc"] as AudioStreamWAV
	var r := _rng(131)
	var t := _tampon(0.35)
	var bruit := _bruit(r, t.size())
	_passe_bas(bruit, 700.0)
	var ph: float = 0.0
	for i in t.size():
		var tt: float = float(i) / FE
		ph += TAU * (130.0 * exp(-tt * 7.0) + 45.0) / FE
		t[i] = 1.1 * sin(ph) * exp(-tt / 0.09) + bruit[i] * 1.6 * exp(-tt / 0.05)
	return _ranger("choc", _finir(t, false))


## Un caillou qui cogne une tête : un « toc » creux et sec (bois frappé), puis un petit tintement qui s'éteint
## (~0,5 s). Plus aigu et plus net que le choc contre un mur : on doit l'entendre à coup sûr.
static func toc() -> AudioStreamWAV:
	if _cache.has("toc"):
		return _cache["toc"] as AudioStreamWAV
	var r := _rng(177)
	var t := _tampon(0.5)
	var bruit := _bruit(r, t.size())
	_passe_bas(bruit, 2400.0)
	var ph: float = 0.0
	var ph2: float = 0.0
	for i in t.size():
		var tt: float = float(i) / FE
		ph += TAU * (260.0 * exp(-tt * 14.0) + 150.0) / FE
		ph2 += TAU * 1250.0 / FE
		t[i] = 1.2 * sin(ph) * exp(-tt / 0.07) + bruit[i] * 1.4 * exp(-tt / 0.012) + 0.28 * sin(ph2) * exp(-tt / 0.16) * (1.0 if tt > 0.05 else tt / 0.05)
	return _ranger("toc", _finir(t, false))


## Coup de théâtre : accord dissonant aigu + basse, ~2 s.
static func cri() -> AudioStreamWAV:
	if _cache.has("cri"):
		return _cache["cri"] as AudioStreamWAV
	var r := _rng(111)
	var t := _tampon(2.0)
	var accord: Array[float] = [880.0, 932.3, 1244.5, 1318.5, 1760.0]
	for i in t.size():
		var tt: float = float(i) / FE
		var v: float = 0.0
		for f in accord:
			v += 0.18 * sin(TAU * f * tt + 0.6 * sin(TAU * 5.5 * tt))
		v *= minf(tt / 0.01, 1.0) * exp(-tt / 0.7)
		var basse: float = sin(TAU * 55.0 * tt) + sin(TAU * 58.3 * tt)
		v += 0.5 * basse * minf(tt / 0.01, 1.0) * exp(-tt / 1.0)
		t[i] = v
	var souffle_aigu := _bruit(r, int(0.5 * FE))
	_passe_haut(souffle_aigu, 3000.0)
	for i in souffle_aigu.size():
		t[i] += 0.4 * souffle_aigu[i] * exp(-float(i) / FE / 0.15)
	return _ranger("cri", _finir(t, false))


# ---------------------------------------------------------------- vrais bruits d'objets (enregistrés)

## Les bruits d'objets sont de VRAIS enregistrements libres de droits (sons/objets/, sources et licences dans
## LICENCE.txt) : retour d'Edwin (01/11), « ils ne ressemblent pas du tout aux vrais bruits ».
## Famille -> nombre de variantes (fichiers `<famille>_<n>.ogg`).
const OBJETS := {"porte_ouvre": 4, "porte_ferme": 4, "porte_coup": 4, "poignee": 3, "chaines": 3, "caillou": 5, "gravier": 3}


## Une variante au hasard de la famille (jamais deux fois la même d'affilée si on en a plusieurs).
static func objet(famille: String) -> AudioStream:
	var n: int = OBJETS.get(famille, 0)
	if n == 0:
		return null
	var v: int = randi() % n
	if v == int(_derniere.get(famille, -1)) and n > 1:
		v = (v + 1 + randi() % (n - 1)) % n
	_derniere[famille] = v
	var fichier := "res://sons/objets/%s_%d.ogg" % [famille, v]
	return load(fichier) if ResourceLoader.exists(fichier) else null


static var _derniere: Dictionary = {}


## Une porte du village qui s'ouvre (grincement).
static func porte() -> AudioStream:
	return objet("porte_ouvre")


## Une porte qui se ferme.
static func porte_ferme() -> AudioStream:
	return objet("porte_ferme")


## Un coup contre une porte (le loup qui force la sienne).
static func porte_coup() -> AudioStream:
	return objet("porte_coup")


## Poignée / loquet.
static func poignee() -> AudioStream:
	return objet("poignee")


## Chaînes qu'on serre.
static func chaines() -> AudioStream:
	return objet("chaines")


## Un caillou qui tombe, qu'on ramasse, qui touche quelqu'un.
static func caillou() -> AudioStream:
	return objet("caillou")


## Du gravier sous le pied d'un loup.
static func gravier() -> AudioStream:
	return objet("gravier")


# ---------------------------------------------------------------- boucles

## Vent qui souffle, 8 s, en boucle.
static func vent() -> AudioStreamWAV:
	if _cache.has("vent"):
		return _cache["vent"] as AudioStreamWAV
	var r := _rng(112)
	var duree: float = 8.0
	var n: int = int(duree * FE)
	var grave := _bruit(r, n)
	_passe_bas(grave, 450.0, true)
	var medium := _bruit(r, n)
	_passe_bas(medium, 800.0, true)
	var t := _tampon(duree)
	var f_sifflet: float = _entier(520.0, duree)
	for i in n:
		var tt: float = float(i) / FE
		var a1: float = 0.6 + 0.4 * sin(TAU * 0.25 * tt)
		var a2: float = maxf(0.0, sin(TAU * 0.375 * tt + 1.0)) * (0.7 + 0.3 * sin(TAU * 0.625 * tt))
		var sifflet: float = 0.04 * sin(TAU * f_sifflet * tt) * (0.5 + 0.5 * sin(TAU * 0.125 * tt + 2.0))
		t[i] = grave[i] * 4.0 * a1 + medium[i] * 2.5 * a2 + sifflet
	_doux(t, 1100.0, 0.0, 0.0, true)
	return _ranger("vent", _finir(t, true, 0.5))


## Grillons lointains, 6 s, en boucle.
static func grillon() -> AudioStreamWAV:
	if _cache.has("grillon"):
		return _cache["grillon"] as AudioStreamWAV
	var r := _rng(114)
	var duree: float = 6.0
	var n: int = int(duree * FE)
	var brise := _bruit(r, n)
	_passe_bas(brise, 500.0, true)
	var t := _tampon(duree)
	# (fréquence porteuse, nombre de séries sur la boucle, décalage en s)
	var porteuses: Array[float] = [_entier(4200.0, duree), _entier(3700.0, duree), _entier(4550.0, duree)]
	var series: Array[float] = [5.0, 7.0, 9.0]
	var decalage: Array[float] = [0.0, 0.31, 0.12]
	for i in n:
		var tt: float = float(i) / FE
		var v: float = brise[i] * 0.5
		for c in porteuses.size():
			var periode: float = duree / series[c]
			var tp: float = fposmod(tt + decalage[c], periode)
			var env: float = 0.0
			for j in 3:
				var d: float = tp - float(j) * 0.06
				if d >= 0.0 and d < 0.035:
					env = pow(sin(PI * d / 0.035), 2.0)
			if env > 0.0:
				v += 0.35 * env * sin(TAU * porteuses[c] * tt)
		t[i] = v
	return _ranger("grillon", _finir(t, true))


# ---------------------------------------------------------------- frissons (29/10)

## Un murmure sans voix ni bruit : trois notes graves et étouffées (100 à 190 Hz) qui s'étirent, ~1,8 s.
## Quatre variantes. Remplace les « chuchotements » en bruit blanc filtré (retour d'Edwin, 01/11).
static func murmure(variante: int) -> AudioStreamWAV:
	var v: int = posmod(variante, 4)
	var cle := "murmure_%d" % v
	if _cache.has(cle):
		return _cache[cle] as AudioStreamWAV
	var gammes: Array = [[146.8, 130.8, 110.0], [164.8, 146.8, 123.5], [130.8, 110.0, 98.0], [185.0, 164.8, 138.6]]
	var notes: Array = gammes[v]
	var t := _tampon(1.8)
	for k in 3:
		var f: float = notes[k]
		var i0: int = int((0.05 + k * 0.5) * FE)
		var ph: float = 0.0
		for i in range(i0, mini(i0 + int(0.9 * FE), t.size())):
			var tt: float = float(i - i0) / FE
			ph += TAU * f * (1.0 + 0.012 * sin(TAU * 5.0 * tt)) / FE
			t[i] += (sin(ph) + 0.2 * sin(ph * 2.0)) * pow(sin(PI * tt / 0.9), 1.5) * (1.0 - 0.15 * k)
	_doux(t, 500.0, 0.02, 0.08)
	return _ranger(cle, _finir(t, false, 0.45))


## Une comptine de boîte à musique (« Au clair de la lune »), désaccordée, qui ralentit. ~10 s.
static func comptine() -> AudioStreamWAV:
	if _cache.has("comptine"):
		return _cache["comptine"] as AudioStreamWAV
	var notes: Array[float] = [1046.5, 1046.5, 1046.5, 1174.7, 1318.5, 1174.7, 1046.5, 1318.5, 1174.7, 1174.7, 1046.5]
	var durees: Array[float] = [1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 3]
	var t := _tampon(11.0)
	var debut := 0.2
	for k in notes.size():
		var lent := 1.0 + k * 0.045                      # le ressort se détend
		var f := notes[k] * pow(2.0, (-18.0 - k * 3.0) / 1200.0)
		var i0 := int(debut * FE)
		for i in range(i0, mini(i0 + int(1.6 * FE), t.size())):
			var tt := float(i - i0) / FE
			var v := sin(TAU * f * tt) + 0.35 * sin(TAU * f * 2.76 * tt) * exp(-tt / 0.08)
			t[i] += 0.5 * v * exp(-tt / 0.55) * minf(tt / 0.002, 1.0)
		debut += durees[k] * 0.5 * lent
	# Une pièce vide : deux échos.
	var sec := t.duplicate()
	for d: Array in [[0.21, 0.3], [0.47, 0.15]]:
		var n := int(float(d[0]) * FE)
		for i in range(n, t.size()):
			t[i] += sec[i - n] * float(d[1])
	return _ranger("comptine", _finir(t, false))


## Le hurlement d'un fantôme qui se matérialise : un cri qui monte et se déchire. ~1,3 s.
static func hurlement() -> AudioStreamWAV:
	if _cache.has("hurlement"):
		return _cache["hurlement"] as AudioStreamWAV
	var r := _rng(720)
	var t := _tampon(1.3)
	var souffle_ := _bruit(r, t.size())
	_passe_haut(souffle_, 900.0)
	_doux(souffle_, 2600.0, 0.0, 0.0)
	var ph1: float = 0.0
	var ph2: float = 0.0
	for i in t.size():
		var tt: float = float(i) / FE
		var f: float = 320.0 + 700.0 * minf(tt / 0.18, 1.0) - 260.0 * maxf(tt - 0.5, 0.0)
		f *= 1.0 + 0.05 * sin(TAU * 9.0 * tt)
		ph1 += f / FE
		ph2 += f * 1.49 / FE
		var scie: float = (fposmod(ph1, 1.0) * 2.0 - 1.0) + 0.6 * (fposmod(ph2, 1.0) * 2.0 - 1.0)
		var grave: float = sin(TAU * 68.0 * tt + 3.0 * sin(TAU * 31.0 * tt))
		var env: float = minf(tt / 0.015, 1.0) * (1.0 if tt < 0.9 else exp(-(tt - 0.9) / 0.15))
		t[i] = tanh(2.5 * (scie * 0.5 + grave * 0.6 + souffle_[i] * 0.5)) * env
	_doux(t, 3000.0, 0.02, 0.1)
	return _ranger("hurlement", _finir(t, false, 0.7))


## Trois coups secs contre une vitre : le doigt, puis le verre qui tremble. ~0,7 s.
static func coup_vitre() -> AudioStreamWAV:
	if _cache.has("coup_vitre"):
		return _cache["coup_vitre"] as AudioStreamWAV
	var t := _tampon(0.75)
	for k in 3:
		var debut := 0.02 + k * 0.17
		_thump(t, debut, 190.0, 1.0, 0.03)
		var i0 := int(debut * FE)
		for i in range(i0, mini(i0 + int(0.15 * FE), t.size())):
			var tt := float(i - i0) / FE
			t[i] += 0.35 * (sin(TAU * 2480.0 * tt) + 0.6 * sin(TAU * 3710.0 * tt)) * exp(-tt / 0.03)
	return _ranger("coup_vitre", _finir(t, false))


## Clic de bouton : un petit « tic » de bois feutré, très court (~60 ms).
static func clic() -> AudioStreamWAV:
	if _cache.has("clic"):
		return _cache["clic"] as AudioStreamWAV
	var r := _rng(41)
	var t := _tampon(0.06)
	var b := _bruit(r, t.size())
	_passe_haut(b, 1800.0)
	for i in t.size():
		var tt := float(i) / FE
		t[i] = 0.5 * b[i] * exp(-tt / 0.004) + sin(TAU * 1250.0 * tt) * exp(-tt / 0.012) * minf(tt / 0.0008, 1.0) \
			+ 0.5 * sin(TAU * 420.0 * tt) * exp(-tt / 0.02)
	return _ranger("clic", _finir(t, false))


# ---------------------------------------------------------------- la rivière (quête du Radeau)

## Un clapotis d'eau très doux, grave, pour le radeau : trois gouttes rondes qui retombent, ~0,5 s.
## Remplace la rivière en boucle (bruit continu, retour d'Edwin 01/11 : « ça ne ressemble pas du tout »).
static func clapotis_radeau() -> AudioStreamWAV:
	if _cache.has("clapotis_radeau"):
		return _cache["clapotis_radeau"] as AudioStreamWAV
	var r := _rng(133)
	var t := _tampon(0.5)
	for b in 3:
		var i0: int = int((0.02 + b * 0.13) * FE)
		var f0: float = r.randf_range(260.0, 420.0)
		var ph: float = 0.0
		for i in range(i0, mini(i0 + int(0.2 * FE), t.size())):
			var tt: float = float(i - i0) / FE
			ph += TAU * f0 * (1.0 + 2.0 * tt) / FE
			t[i] += (1.0 - 0.25 * b) * sin(ph) * exp(-tt / 0.045) * minf(tt / 0.01, 1.0)
	_doux(t, 800.0, 0.01, 0.1)
	return _ranger("clapotis_radeau", _finir(t, false, 0.45))


## Un coup de rame dans l'eau : une gerbe puis un « bloup », ~0,6 s.
static func rame() -> AudioStreamWAV:
	if _cache.has("rame"):
		return _cache["rame"] as AudioStreamWAV
	var r := _rng(132)
	var t := _bruit(r, int(0.6 * FE))
	_passe_haut(t, 300.0)
	_doux(t, 1500.0, 0.0, 0.0)
	for i in t.size():
		var tt: float = float(i) / FE
		t[i] *= 0.6 * exp(-tt / 0.16) * minf(tt / 0.06, 1.0)
	var ph: float = 0.0
	for i in range(int(0.05 * FE), mini(int(0.3 * FE), t.size())):
		var tt: float = float(i) / FE - 0.05
		ph += TAU * maxf(300.0 - 500.0 * tt, 80.0) / FE
		t[i] += 0.3 * sin(ph) * exp(-tt / 0.07)
	_doux(t, 1500.0, 0.03, 0.12)
	return _ranger("rame", _finir(t, false, 0.55))
