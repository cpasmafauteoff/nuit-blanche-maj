class_name Emotes
extends RefCounted
## Gestes et danses (touche R) : certains jouent une animation du mannequin, les autres
## posent les bras et les doigts heure par heure, comme le ferait la webcam.
## Directions dans les axes du villageois : -X son côté droit, +X son côté gauche, +Z devant.

## id, nom affiché, animation (ou ""), durée en secondes. Chacun dure son temps, même en marchant.
const LISTE := [
	["saluer", "Saluer", "", 2.6],
	["applaudir", "Applaudir", "", 3.0],
	["pointer", "Montrer du doigt", "", 2.5],
	["chut", "Chut !", "", 2.2],
	["hausser", "Hausser les épaules", "", 1.8],
	["croiser", "Bras croisés", "", 5.0],
	["danse_feu", "Danse du feu", "", 6.0],
	["gigue", "Gigue", "", 6.0],
	["danse", "Danse du village", "Dance", 6.0],
	["accroupi", "S'accroupir", "Crouch_Idle", 5.0],
	["oh_non", "Mains sur la tête", "", 2.2],
	["incanter", "Incanter", "Spell_Simple_Shoot", 1.6],
	# Achetés à la roulotte du colporteur (cf. Cosmetiques) :
	["reverence", "Révérence", "", 2.6],
	["rire_dement", "Rire dément", "", 3.0],
	["signe_croix", "Signe de croix", "", 2.8],
	["hurlement", "Hurlement", "", 3.2],
]
## Les gestes faits À QUELQU'UN (cf. Gestes) : ils ne figurent ni dans la liste G ni chez les bots qui
## flânent. id, nom, animation, durée.
const SOCIAUX := [
	["poignee", "Poignée de main", "", 2.4],
	["chuchoter", "Chuchoter", "", 4.5],
	["accolade", "Accolade", "", 2.8],
	["check", "Check", "", 1.8],
	["montrer", "Montrer du doigt", "", 4.0],
	["epaule", "Taper sur l'épaule", "", 1.2],
	["pousser", "Pousser", "", 0.8],
	["bouscule", "Bousculé", "", 0.9],   # celui qu'on pousse : il part en arrière, les bras en l'air
	["lancer", "Lancer", "", 0.85],      # le bras armé en arrière, puis le jet (un caillou)
	["poser", "Poser", "", 0.9],         # le buste qui se penche, le bras qui pose l'objet devant soi
]
## Les gestes qui s'achètent : id → article de la roulotte.
const PAYANTES := {"reverence": "emote_reverence", "rire_dement": "emote_rire_dement",
	"signe_croix": "emote_signe_croix", "hurlement": "emote_hurlement"}


## Les gestes qui montrent quelqu'un du doigt : le bras vise la personne (cf. Bouille._viser_cible).
static func pointe(id: String) -> bool:
	return id == "pointer" or id == "montrer"


static func existe(id: String) -> bool:
	return info(id).size() > 0


static func info(id: String) -> Array:
	for e: Array in LISTE:
		if e[0] == id:
			return e
	for e: Array in SOCIAUX:
		if e[0] == id:
			return e
	return []


static func nom(id: String) -> String:
	var e := info(id)
	return Langue.t(e[1]) if e.size() > 0 else id


static func animation(id: String) -> String:
	var e := info(id)
	return e[2] if e.size() > 0 else ""


static func duree(id: String) -> float:
	var e := info(id)
	return float(e[3]) if e.size() > 0 else 0.0


static func _seg(l: PackedFloat32Array, d: Vector3) -> void:
	d = d.normalized()
	l.append_array([d.x, d.y, d.z, 1.0])


static func _rien(l: PackedFloat32Array) -> void:
	l.append_array([0.0, -1.0, 0.0, 0.0])


## Les 4 segments des bras (droit haut/bas, gauche haut/bas) au temps t, ou vide (animation).
static func bras(id: String, t: float) -> PackedFloat32Array:
	var l := PackedFloat32Array()
	var s := sin(t * 9.0)
	match id:
		"saluer":
			_seg(l, Vector3(-0.6, 0.75, 0.2))
			_seg(l, Vector3(-0.25 + 0.4 * s, 1.0, 0.15))
			_rien(l); _rien(l)
		"applaudir":
			var e := 0.35 + 0.3 * (sin(t * 15.0) * 0.5 + 0.5)
			_seg(l, Vector3(-0.35, -0.45, 0.8))
			_seg(l, Vector3(e, 0.25, 0.8))
			_seg(l, Vector3(0.35, -0.45, 0.8))
			_seg(l, Vector3(-e, 0.25, 0.8))
		"lancer":
			var p := _pose_lancer(t)
			_seg(l, p[0])
			_seg(l, p[1])
			_rien(l); _rien(l)
		"poser":
			var p := _pose_poser(t)
			_seg(l, p[0])
			_seg(l, p[1])
			_rien(l); _rien(l)
		"pointer", "montrer":
			_seg(l, Vector3(-0.15, 0.12, 1.0))
			_seg(l, Vector3(-0.1, 0.1, 1.0))
			_rien(l); _rien(l)
		"poignee":
			var p := sin(t * 11.0) * 0.18
			_seg(l, Vector3(-0.2, -0.3, 0.9))
			_seg(l, Vector3(0.05, 0.1 + p, 1.0))
			_rien(l); _rien(l)
		"check":
			var p := maxf(0.0, sin(t * 3.5)) * 0.25
			_seg(l, Vector3(-0.2, -0.3, 0.9))
			_seg(l, Vector3(0.0, 0.15, 1.0 - p))
			_rien(l); _rien(l)
		"accolade":
			var o := clampf(t * 1.6, 0.0, 1.0)
			_seg(l, Vector3(-0.85, 0.1, 0.55 + 0.3 * o))
			_seg(l, Vector3(-0.8 + 1.0 * o, 0.2, 0.7))
			_seg(l, Vector3(0.85, 0.1, 0.55 + 0.3 * o))
			_seg(l, Vector3(0.8 - 1.0 * o, 0.2, 0.7))
		"chuchoter":
			# La main en coupe contre le côté de la bouche, la tête qui se penche (cf. rebond).
			_seg(l, Vector3(-0.25, -0.5, 0.6))
			_seg(l, Vector3(-0.15, 0.9, 0.35))
			_rien(l); _rien(l)
		"epaule":
			var p := absf(sin(t * 9.0)) * 0.35
			_seg(l, Vector3(-0.25, -0.2, 0.9))
			_seg(l, Vector3(0.1, 0.45 - p, 0.95))
			_rien(l); _rien(l)
		"pousser":
			# Les deux paumes partent d'un coup à hauteur de poitrine, puis reviennent (Edwin, 31/10).
			var o := _coup(t)
			_seg(l, Vector3(-0.3, -0.35 + 0.35 * o, 0.45 + 0.55 * o))
			_seg(l, Vector3(-0.05, 0.25 + 0.1 * o, 1.0))
			_seg(l, Vector3(0.3, -0.35 + 0.35 * o, 0.45 + 0.55 * o))
			_seg(l, Vector3(0.05, 0.25 + 0.1 * o, 1.0))
		"bouscule":
			# Déséquilibré : les bras jaillissent sur les côtés et moulinent pour se rattraper.
			var m := sin(t * 18.0) * 0.35 * clampf(1.0 - t / 0.9, 0.0, 1.0)
			_seg(l, Vector3(-0.85, 0.35 + m, 0.35))
			_seg(l, Vector3(-0.6, 0.75 - m, 0.45))
			_seg(l, Vector3(0.85, 0.35 - m, 0.35))
			_seg(l, Vector3(0.6, 0.75 + m, 0.45))
		"chut":
			_seg(l, Vector3(-0.25, -0.5, 0.6))
			_seg(l, Vector3(0.35, 0.92, 0.25))
			_rien(l); _rien(l)
		"hausser":
			var h := minf(t * 4.0, 1.0)
			_seg(l, Vector3(-0.3, -0.9, 0.15))
			_seg(l, Vector3(-0.7, -0.2 + 0.3 * h, 0.7))
			_seg(l, Vector3(0.3, -0.9, 0.15))
			_seg(l, Vector3(0.7, -0.2 + 0.3 * h, 0.7))
		"oh_non":
			_seg(l, Vector3(-0.75, 0.55, 0.25))
			_seg(l, Vector3(0.55, 0.65, 0.35))
			_seg(l, Vector3(0.75, 0.55, 0.25))
			_seg(l, Vector3(-0.55, 0.65, 0.35))
		"croiser":
			_seg(l, Vector3(-0.3, -0.75, 0.45))
			_seg(l, Vector3(0.95, 0.15, 0.3))
			_seg(l, Vector3(0.3, -0.75, 0.5))
			_seg(l, Vector3(-0.95, 0.2, 0.25))
		"danse_feu":
			var a := sin(t * 4.0)
			var b := sin(t * 4.0 + PI)
			_seg(l, Vector3(-0.55 + 0.25 * a, 0.8, 0.15))
			_seg(l, Vector3(-0.2 + 0.6 * sin(t * 6.0), 1.0, 0.1))
			_seg(l, Vector3(0.55 + 0.25 * b, 0.8, 0.15))
			_seg(l, Vector3(0.2 + 0.6 * sin(t * 6.0 + 1.5), 1.0, 0.1))
		"gigue":
			var haut := fmod(t * 2.5, 2.0) < 1.0
			_seg(l, Vector3(-0.3, 0.9, 0.3) if haut else Vector3(-0.25, -0.6, 0.6))
			_seg(l, Vector3(-0.1, 1.0, 0.2) if haut else Vector3(0.3, 0.4, 0.8))
			_seg(l, Vector3(0.25, -0.6, 0.6) if haut else Vector3(0.3, 0.9, 0.3))
			_seg(l, Vector3(-0.3, 0.4, 0.8) if haut else Vector3(0.1, 1.0, 0.2))
		"reverence":
			# Le bras droit replié sur le cœur, le gauche qui s'ouvre vers le bas, comme à la cour.
			var o := minf(t * 2.5, 1.0)
			_seg(l, Vector3(-0.25, -0.75, 0.6))
			_seg(l, Vector3(0.9, 0.2, 0.4))
			_seg(l, Vector3(0.5 * o + 0.2, -0.85, 0.2 - 0.3 * o))
			_seg(l, Vector3(0.75 * o + 0.1, -0.6, 0.1 - 0.4 * o))
		"rire_dement":
			# Les mains sur le ventre, les épaules qui sautent (cf. rebond).
			_seg(l, Vector3(-0.35, -0.85, 0.4))
			_seg(l, Vector3(0.6, -0.3, 0.75))
			_seg(l, Vector3(0.35, -0.85, 0.4))
			_seg(l, Vector3(-0.6, -0.3, 0.75))
		"signe_croix":
			# Front, poitrine, épaule gauche, épaule droite : la main droite fait le tour.
			var etape := clampi(int(t / 0.55), 0, 4)
			var cibles := [Vector3(0.1, 1.0, 0.35), Vector3(0.15, 0.95, 0.4), Vector3(0.55, 0.3, 0.7), Vector3(0.85, 0.6, 0.35), Vector3(0.2, 0.75, 0.6)]
			_seg(l, Vector3(-0.2, -0.65, 0.7))
			_seg(l, cibles[etape])
			_rien(l); _rien(l)
		"hurlement":
			# Les bras qui s'ouvrent vers la lune, les poings fermés.
			var o := minf(t * 1.5, 1.0)
			_seg(l, Vector3(-0.8, 0.1 + 0.7 * o, 0.3))
			_seg(l, Vector3(-0.6, 0.6 + 0.4 * o, 0.25))
			_seg(l, Vector3(0.8, 0.1 + 0.7 * o, 0.3))
			_seg(l, Vector3(0.6, 0.6 + 0.4 * o, 0.25))
		_:
			return l
	return l


## Les mains (même format que le capteur, 44 nombres) au temps t, ou vide.
static func mains(id: String, t: float) -> PackedFloat32Array:
	var dr := Vector3.ZERO
	var plis_d := [0.0, 0.0, 0.0, 0.0, 0.0]
	var plis_g := plis_d.duplicate()
	var nd := Vector3.BACK
	var ng := Vector3.BACK
	var g := false
	var dg := Vector3.ZERO
	match id:
		"saluer":
			dr = Vector3(-0.25 + 0.4 * sin(t * 9.0), 1.0, 0.15)
		"poignee", "check", "epaule":
			dr = Vector3(0.0, 0.15, 1.0)
			plis_d = [0.0, 0.0, 0.0, 0.0, 0.0] if id == "poignee" else [1.2, 1.5, 1.5, 1.5, 1.5]
			nd = Vector3.LEFT
		"chuchoter":
			dr = Vector3(-0.1, 0.9, 0.3)
			plis_d = [0.3, 0.2, 0.2, 0.2, 0.2]
			nd = Vector3.LEFT
		"lancer":
			dr = (_pose_lancer(t)[1] as Vector3)
			plis_d = [0.2, 0.1, 0.1, 0.1, 0.1] if t < 0.3 else [0.0, 0.0, 0.0, 0.0, 0.0]
			nd = Vector3.LEFT
		"poser":
			dr = (_pose_poser(t)[1] as Vector3)
			plis_d = [0.5, 0.4, 0.4, 0.4, 0.4] if t < 0.4 else [0.0, 0.0, 0.0, 0.0, 0.0]
			nd = Vector3.LEFT
		"pointer", "montrer":
			dr = Vector3(-0.1, 0.1, 1.0)
			plis_d = [1.0, 0.0, 1.5, 1.5, 1.5]
			nd = Vector3.RIGHT
		"chut":
			dr = Vector3(0.1, 1.0, 0.1)
			plis_d = [1.2, 0.0, 1.5, 1.5, 1.5]
			nd = Vector3.LEFT
		"hausser":
			dr = Vector3(-0.8, 0.1, 0.6)
			dg = Vector3(0.8, 0.1, 0.6)
			nd = Vector3.UP
			ng = Vector3.UP
			g = true
		"applaudir":
			dr = Vector3(0.4, 0.3, 0.85)
			dg = Vector3(-0.4, 0.3, 0.85)
			nd = Vector3.RIGHT
			ng = Vector3.LEFT
			g = true
		"pousser":
			# Paumes ouvertes vers l'autre, doigts en l'air : on pousse, on ne frappe pas.
			dr = Vector3(0.1, 0.85, 0.5)
			dg = Vector3(-0.1, 0.85, 0.5)
			nd = Vector3.BACK
			ng = Vector3.BACK
			g = true
		"bouscule":
			dr = Vector3(-0.6, 0.75, 0.2)
			dg = Vector3(0.6, 0.75, 0.2)
			plis_d = [0.0, 0.0, 0.1, 0.2, 0.3]
			plis_g = plis_d
			nd = Vector3.BACK
			ng = Vector3.BACK
			g = true
		"croiser":
			dr = Vector3(1.0, 0.1, 0.0)
			dg = Vector3(-1.0, 0.1, 0.0)
			plis_d = [0.6, 0.7, 0.7, 0.7, 0.7]
			plis_g = plis_d
			nd = Vector3.BACK
			ng = Vector3.BACK
			g = true
		_:
			return PackedFloat32Array()
	var l := _main(dr, nd, plis_d)
	l.append_array(_main(dg, ng, plis_g) if g else _main(Vector3.ZERO, Vector3.ZERO, [], false))
	return l


static func _main(d: Vector3, n: Vector3, plis: Array, vue := true) -> PackedFloat32Array:
	var l := PackedFloat32Array([1.0 if vue else 0.0, d.x, d.y, d.z, n.x, n.y, n.z])
	for k in 15:
		l.append(float(plis[k / 3]) if vue and plis.size() == 5 else 0.0)
	return l


## Le jet : le bras droit part en arrière et en haut (0 → 0,2 s), puis fouette vers l'avant (→ 0,32 s),
## puis retombe (0,45 → 0,75 s). Renvoie [haut du bras, avant-bras] dans les axes du villageois.
static func _pose_lancer(t: float) -> Array:
	var repos := [Vector3(-0.25, -0.9, 0.15), Vector3(-0.1, -0.9, 0.35)]
	var arme := [Vector3(-0.35, 0.55, -0.75), Vector3(-0.1, 0.95, -0.25)]
	var jet := [Vector3(-0.1, 0.3, 1.0), Vector3(-0.05, 0.15, 1.0)]
	var r := []
	for i in 2:
		var a: Vector3 = (repos[i] as Vector3).lerp(arme[i], smoothstep(0.0, 0.2, t))
		a = a.lerp(jet[i], smoothstep(0.2, 0.32, t))
		a = a.lerp(repos[i], smoothstep(0.45, 0.75, t))
		r.append(a.normalized())
	return r


## Poser : le bras descend devant soi vers le sol (0 -> 0,25 s), lâche (0,4 s), remonte (-> 0,8 s).
## Renvoie [haut du bras, avant-bras] dans les axes du villageois.
static func _pose_poser(t: float) -> Array:
	var repos := [Vector3(-0.25, -0.9, 0.15), Vector3(-0.1, -0.9, 0.35)]
	var bas := [Vector3(-0.1, -0.55, 0.85), Vector3(-0.05, -0.75, 0.75)]
	var k := Depose.geste(t)
	var r := []
	for i in 2:
		r.append(((repos[i] as Vector3).lerp(bas[i], k)).normalized())
	return r


## La poussée : un aller sec (0,12 s), un temps, un retour plus lent. 0 → 1 → 0.
static func _coup(t: float) -> float:
	if t < 0.12:
		return t / 0.12
	return clampf(1.0 - (t - 0.3) / 0.45, 0.0, 1.0)


## Le buste qui bascule (radians, + : en avant). Celui qui pousse y met son poids ; celui qu'on
## pousse part en arrière puis se rattrape.
static func bascule(id: String, t: float) -> float:
	match id:
		"pousser":
			return 0.28 * _coup(t)
		"poser":
			return 0.6 * Depose.geste(t)
		"lancer":
			return -0.2 * smoothstep(0.0, 0.2, t) + 0.5 * smoothstep(0.2, 0.32, t) - 0.3 * smoothstep(0.45, 0.75, t)
		"bouscule":
			var a := minf(t / 0.1, 1.0)
			return -0.45 * a * clampf(1.0 - (t - 0.15) / 0.7, 0.0, 1.0)
	return 0.0


## Les danses font rebondir et balancer le bassin.
static func rebond(id: String, t: float) -> Vector2:
	match id:
		"danse_feu":
			return Vector2(absf(sin(t * 4.0)) * 0.045, sin(t * 2.0) * 0.12)
		"gigue":
			return Vector2(absf(sin(t * 7.85)) * 0.06, sin(t * 3.9) * 0.06)
		"rire_dement":
			return Vector2(absf(sin(t * 22.0)) * 0.025, sin(t * 11.0) * 0.08)
		"hurlement":
			return Vector2(minf(t, 1.0) * 0.03, 0.0)
		"chuchoter":
			return Vector2(0.0, minf(t * 2.0, 1.0) * 0.1)
	return Vector2.ZERO
