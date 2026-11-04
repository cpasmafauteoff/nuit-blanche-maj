class_name Prise
extends RefCounted
## PRENDRE / PORTER / POSER un objet de quête : la mécanique générique, côté HÔTE (l'hôte fait foi).
## Le côté joueur (visée, objet qui suit la main, déposé dans une case) est PriseMonde ; le rendu
## des objets et des cases est celui du décor (DecorQuete.objet_prise / cible_prise).
##
## Un jeu qui s'en sert :
##   var prise := Prise.new()
##   var i := prise.ajouter_objet("galet", "Lune", repos, dest)      # un objet posé en `repos`
##   var c := prise.ajouter_cible(pos, pour)                          # une case où le poser
##   func action(id, d): var r := prise.agir(id, d)                   # {"quoi": "prend"|"pose"|"repose", "o", "c"}
##   (dans vue_pour) blocs.append(prise.bloc(id))                     # TOUJOURS le dernier bloc de la vue
##
## Les intentions que le joueur envoie (dictionnaires de `jeu`) :
##   {"prend": i}   prendre l'objet i (libre, à moi ou à tous, et je ne porte rien)
##   {"pose": c}    poser ce que je porte dans la case c (libre, et qui m'est ouverte)
##   {"repose": true}  remettre ce que je porte là où il était au départ
## Tout est validé ICI ; un objet pris dans une case la libère (on peut donc en retirer un).
## Les positions sont en repère LOCAL de la clairière (celui de DecorQuete).

## {"f": forme, "l": libellé, "repos": Vector3, "dest": id (-1 : à tous ; -2 : à personne, verrouillé), "sur": case ou -1,
##  "par": porteur ou -1, "x": Dictionary de ce que le décor veut savoir (taille, valeur…)}
var objets: Array[Dictionary] = []
## {"pos": Vector3, "pour": id (-1 : ouverte à tous ; -2 : fermée), "cap": combien d'objets elle porte (1 : une encoche,
##  plus : un plateau), "occupe": [objets posés, dans l'ordre], "x": Dictionary}
var cibles: Array[Dictionary] = []


func ajouter_objet(forme: String, libelle: String, repos: Vector3, dest := -1, extra := {}) -> int:
	objets.append({"f": forme, "l": libelle, "repos": repos, "dest": dest, "sur": -1, "par": -1, "x": extra})
	return objets.size() - 1


func ajouter_cible(pos: Vector3, pour := -1, extra := {}, cap := 1) -> int:
	cibles.append({"pos": pos, "pour": pour, "cap": cap, "occupe": [], "x": extra})
	return cibles.size() - 1


## L'objet que porte ce joueur, ou -1.
func tenu(id: int) -> int:
	for i in objets.size():
		if int(objets[i]["par"]) == id:
			return i
	return -1


## Le premier objet posé dans cette case, ou -1.
func objet_sur(c: int) -> int:
	if c < 0 or c >= cibles.size() or (cibles[c]["occupe"] as Array).is_empty():
		return -1
	return int((cibles[c]["occupe"] as Array)[0])


func peut_prendre(id: int, i: int) -> bool:
	if i < 0 or i >= objets.size() or tenu(id) >= 0:
		return false
	var o: Dictionary = objets[i]
	return int(o["par"]) < 0 and (int(o["dest"]) == -1 or int(o["dest"]) == id)


func peut_poser(id: int, c: int) -> bool:
	if c < 0 or c >= cibles.size() or tenu(id) < 0:
		return false
	var k: Dictionary = cibles[c]
	return (k["occupe"] as Array).size() < int(k["cap"]) and (int(k["pour"]) == -1 or int(k["pour"]) == id)


func prendre(id: int, i: int) -> bool:
	if not peut_prendre(id, i):
		return false
	var o: Dictionary = objets[i]
	_sortir(i)
	o["par"] = id
	return true


## Retire l'objet i de la case où il est.
func _sortir(i: int) -> void:
	var o: Dictionary = objets[i]
	if int(o["sur"]) >= 0:
		(cibles[int(o["sur"])]["occupe"] as Array).erase(i)
		o["sur"] = -1


## Pose ce que `id` porte dans la case c. Rend l'objet posé, ou -1 (rien ne bouge).
func poser(id: int, c: int) -> int:
	if not peut_poser(id, c):
		return -1
	var i := tenu(id)
	objets[i]["par"] = -1
	objets[i]["sur"] = c
	(cibles[c]["occupe"] as Array).append(i)
	return i


## Remet ce que `id` porte à sa place de départ. Rend l'objet, ou -1.
func reposer(id: int) -> int:
	var i := tenu(id)
	if i >= 0:
		objets[i]["par"] = -1
	return i


## Remet un objet à sa place de départ, où qu'il soit (une case est alors libérée).
func renvoyer(i: int) -> void:
	if i < 0 or i >= objets.size():
		return
	_sortir(i)
	objets[i]["par"] = -1


## Quelqu'un lâche ce qu'il tient (hanté, hors-jeu).
func lacher(id: int) -> void:
	reposer(id)


## L'intention d'un joueur. Rend {"quoi": "prend" | "pose" | "repose" | "", "o": objet, "c": case}.
func agir(id: int, d: Dictionary) -> Dictionary:
	if d.has("prend"):
		var i := int(d["prend"])
		if prendre(id, i):
			return {"quoi": "prend", "o": i, "c": -1}
	elif d.has("pose"):
		var c := int(d["pose"])
		var i2 := poser(id, c)
		if i2 >= 0:
			return {"quoi": "pose", "o": i2, "c": c}
	elif d.get("repose", false):
		var i3 := reposer(id)
		if i3 >= 0:
			return {"quoi": "repose", "o": i3, "c": -1}
	return {"quoi": "", "o": -1, "c": -1}


## Le bloc de vue de ce joueur. `voir` (facultatif, Callable(id, i) -> bool) dit quels objets il voit ;
## `cases` (facultatif, Callable(id, c) -> bool) quelles cases. Par défaut : tout.
## Chaque objet : {i, f, l, r (repos), s (case), p (-1 libre, 0 je le porte, 1 un autre le porte),
## m (puis-je le prendre ?), x}. Chaque case : {c, pos, o (objets posés), m (m'est ouverte), x}.
func bloc(id: int, voir := Callable(), cases := Callable()) -> Dictionary:
	var os: Array = []
	for i in objets.size():
		if voir.is_valid() and not voir.call(id, i):
			continue
		var o: Dictionary = objets[i]
		var par := int(o["par"])
		os.append({"i": i, "f": o["f"], "l": o["l"], "r": o["repos"], "s": o["sur"],
			"p": -1 if par < 0 else (0 if par == id else 1), "m": peut_prendre(id, i), "x": o["x"]})
	var cs: Array = []
	for c in cibles.size():
		if cases.is_valid() and not cases.call(id, c):
			continue
		var k: Dictionary = cibles[c]
		cs.append({"c": c, "pos": k["pos"], "cap": k["cap"], "o": (k["occupe"] as Array).duplicate(), "m": int(k["pour"]) == -1 or int(k["pour"]) == id, "x": k["x"]})
	return {"t": "prise", "objets": os, "cibles": cs, "tenu": tenu(id)}


# ---------------------------------------------------------------- sur le réseau

## Une vue pèse 8 à 16 Ko avec tous ses objets : trop pour 10 envois par seconde et par joueur. On n'envoie donc
## que ce qui bouge (qui porte quoi, où est posé quoi) ; le reste (positions de repos, libellés, tailles, gravures)
## part compressé de temps en temps (chaque seconde) et dès qu'il change. Le client le garde (cf. `decompacter`).
const FIXE_TOUS_LES := 10

static var _envois := {}      # joueur -> {h: empreinte du fixe envoyé, n: nombre d'envois}


## Côté HÔTE, juste avant d'envoyer la vue à `cle` : le bloc « prise » de la vue est remplacé par sa forme compacte.
static func compacter(vue: Dictionary, cle: int) -> void:
	var blocs: Array = vue.get("blocs", [])
	for i in blocs.size():
		var b: Dictionary = blocs[i]
		if b.get("t", "") != "prise" or b.has("z"):
			continue
		blocs[i] = _compacter_bloc(b, cle)
		return


static func _compacter_bloc(b: Dictionary, cle: int) -> Dictionary:
	var fixe_o: Array = []
	var dyn := PackedInt32Array()
	for o: Dictionary in b["objets"]:
		fixe_o.append({"i": o["i"], "f": o["f"], "l": o["l"], "r": o["r"], "x": o["x"]})
		dyn.append_array(PackedInt32Array([int(o["i"]), int(o["s"]), int(o["p"]), 1 if o["m"] else 0]))
	var fixe_c: Array = []
	var cs := PackedInt32Array()
	var lect := {}
	for c: Dictionary in b["cibles"]:
		var x: Dictionary = (c["x"] as Dictionary).duplicate()
		if x.has("lecture"):
			lect[c["c"]] = x["lecture"]
			x.erase("lecture")
		fixe_c.append({"c": c["c"], "pos": c["pos"], "cap": c["cap"], "x": x})
		cs.append_array(PackedInt32Array([int(c["c"]), 1 if c["m"] else 0, (c["o"] as Array).size()]))
		cs.append_array(PackedInt32Array(c["o"]))
	var octets := var_to_bytes({"o": fixe_o, "c": fixe_c})
	var h := hash(octets)
	var etat: Dictionary = _envois.get(cle, {"h": 0, "n": 0})
	var envoyer: bool = int(etat["h"]) != h or int(etat["n"]) % FIXE_TOUS_LES == 0
	etat["h"] = h
	etat["n"] = int(etat["n"]) + 1
	_envois[cle] = etat
	var r := {"t": "prise", "z": 1, "fh": h, "tenu": b["tenu"], "d": dyn, "k": cs, "lect": lect}
	for k in b:
		if not r.has(k) and k != "objets" and k != "cibles":
			r[k] = b[k]
	if envoyer:
		r["fn"] = octets.size()
		r["fz"] = octets.compress(FileAccess.COMPRESSION_ZSTD)
	return r


## Côté JOUEUR : le bloc compact reçu, développé en bloc complet (celui que Prise.bloc avait fabriqué) avec ce
## que `cache` a retenu du fixe. Rend {} tant que le fixe n'est pas arrivé (il revient chaque seconde).
static func decompacter(b: Dictionary, cache: Dictionary) -> Dictionary:
	if not b.has("z"):
		return b
	if b.has("fz"):
		var octets: PackedByteArray = (b["fz"] as PackedByteArray).decompress(int(b["fn"]), FileAccess.COMPRESSION_ZSTD)
		cache["fixe"] = bytes_to_var(octets)
		cache["fh"] = b["fh"]
	if not cache.has("fixe") or cache["fh"] != b["fh"]:
		return {}
	var fixe: Dictionary = cache["fixe"]
	var dyn: PackedInt32Array = b["d"]
	var par_id := {}
	for q in dyn.size() / 4:
		par_id[dyn[q * 4]] = [dyn[q * 4 + 1], dyn[q * 4 + 2], dyn[q * 4 + 3]]
	var objets: Array = []
	for o: Dictionary in fixe["o"]:
		var d: Array = par_id.get(int(o["i"]), [-1, -1, 0])
		objets.append({"i": o["i"], "f": o["f"], "l": o["l"], "r": o["r"], "s": d[0], "p": d[1], "m": d[2] == 1, "x": o["x"]})
	var occupe := {}
	var ouvert := {}
	var k: PackedInt32Array = b["k"]
	var pos := 0
	while pos + 3 <= k.size():
		var c := k[pos]
		var nb := k[pos + 2]
		ouvert[c] = k[pos + 1] == 1
		occupe[c] = Array(k.slice(pos + 3, pos + 3 + nb))
		pos += 3 + nb
	var cibles: Array = []
	for c: Dictionary in fixe["c"]:
		var x: Dictionary = (c["x"] as Dictionary).duplicate()
		if (b["lect"] as Dictionary).has(c["c"]):
			x["lecture"] = (b["lect"] as Dictionary)[c["c"]]
		cibles.append({"c": c["c"], "pos": c["pos"], "cap": c["cap"], "o": occupe.get(int(c["c"]), []), "m": ouvert.get(int(c["c"]), false), "x": x})
	var r := {"t": "prise", "objets": objets, "cibles": cibles, "tenu": b["tenu"]}
	for key in b:
		if not r.has(key) and not ["z", "fh", "d", "k", "lect", "fn", "fz"].has(key):
			r[key] = b[key]
	return r


# ---------------------------------------------------------------- le banc d'un joueur

## Le repère du banc (autel, établi) de ce joueur, `avance` mètres devant son poste, en repère local de
## la clairière. L'avant est -Z, la droite +X : `banc(…) * Vector3(x, y, z)` donne la position réelle.
## L'hôte (qui place les objets) et le décor (qui bâtit l'autel) s'y tiennent tous deux.
static func banc(jeu: String, k: int, n: int, avance := 0.75) -> Transform3D:
	var ici := DecorQuete.poste(jeu, k, n)
	var vers := DecorQuete.regard(jeu, k, n) - ici
	vers.y = 0
	var devant := vers.normalized() if vers.length() > 0.01 else Vector3.FORWARD
	return Transform3D(Basis.looking_at(devant, Vector3.UP), Vector3(ici.x, 0, ici.z) + devant * avance)


# ---------------------------------------------------------------- les sons (pierre, bois, métal)

static var _sons := {}


## Un petit bruit synthétisé et mis en cache : "pierre_prend", "pierre_pose", "metal_prend", "metal_pose",
## "refus", "carillon" (une rune juste), "tintement" (le plateau se pose).
static func son(nom: String) -> AudioStreamWAV:
	if _sons.has(nom):
		return _sons[nom]
	# durée, bruit (amplitude, constante de temps, coupure : 0 = aucune), partiels [[Hz, amplitude, tau]…]
	var modeles := {
		"pierre_prend": [0.16, 0.9, 0.012, 0.4, [[420.0, 0.25, 0.03]]],
		"pierre_pose": [0.42, 1.0, 0.02, 0.35, [[170.0, 0.9, 0.09], [310.0, 0.45, 0.05], [96.0, 0.7, 0.14]]],
		"metal_prend": [0.22, 0.5, 0.01, 0.0, [[1900.0, 0.3, 0.05], [2800.0, 0.2, 0.04]]],
		"metal_pose": [0.7, 0.8, 0.012, 0.0, [[640.0, 0.7, 0.16], [1320.0, 0.5, 0.11], [2410.0, 0.3, 0.07], [180.0, 0.6, 0.12]]],
		"refus": [0.45, 0.6, 0.03, 0.3, [[120.0, 0.9, 0.12], [127.0, 0.9, 0.12]]],
		"carillon": [1.1, 0.0, 0.01, 0.0, [[523.0, 0.55, 0.45], [784.0, 0.4, 0.4], [1568.0, 0.2, 0.3]]],
		"tintement": [0.9, 0.2, 0.01, 0.0, [[1180.0, 0.4, 0.2], [1770.0, 0.3, 0.14], [2650.0, 0.15, 0.1]]],
	}
	var m: Array = modeles.get(nom, modeles["pierre_pose"])
	var fe := 22050
	var n := int(float(m[0]) * fe)
	var r := RandomNumberGenerator.new()
	r.seed = hash(nom)
	var t := PackedFloat32Array()
	t.resize(n)
	var y := 0.0
	var coupure: float = m[3]
	for i in n:
		var tt := float(i) / fe
		var b := r.randf_range(-1.0, 1.0)
		if coupure > 0.0:
			y += coupure * (b - y)
			b = y * 2.2
		var v: float = float(m[1]) * b * exp(-tt / float(m[2]))
		for p: Array in m[4]:
			v += float(p[1]) * sin(TAU * float(p[0]) * tt) * exp(-tt / float(p[2]))
		t[i] = v * minf(tt / 0.002, 1.0)
	var crete := 0.001
	for v in t:
		crete = maxf(crete, absf(v))
	var octets := PackedByteArray()
	octets.resize(n * 2)
	for i in n:
		octets.encode_s16(i * 2, int(clampf(t[i] / crete * 0.8, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = fe
	w.stereo = false
	w.data = octets
	_sons[nom] = w
	return w
