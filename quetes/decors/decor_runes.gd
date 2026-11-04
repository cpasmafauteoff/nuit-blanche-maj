extends DecorQuete
## Les Runes : un cercle de menhirs au fond de la clairière, et au milieu la stèle — un grand pilier carré,
## moussu, planté entre les racines. Chacun n'y déchiffre que SES signes, qui luisent comme des braises sur
## ses quatre faces. Devant soi, SON autel de pierre : sa réserve de galets gravés (de vrais objets qu'on prend
## et qu'on pose, cf. Prise) et, derrière, ses encoches numérotées, entre deux bougies. Un galet posé
## fait luire sa gravure ; une suite juste embrase l'autel ; une suite fausse le fait trembler, rouge.
## Les menhirs portent, gravé, l'alphabet entier des 24 runes du jeu : on peut y vérifier qu'une
## rune annoncée existe bien (la pierre du jour n'en use qu'une poignée).

const AMBRE := Color(1.0, 0.62, 0.25)
const VERT_OR := Color(0.72, 1.0, 0.45)
const ROUGE := Color(1.0, 0.16, 0.1)

var _stele: Node3D
var _gravures: Array[Label3D] = []
var _lueur: OmniLight3D
var _autel_vu := false
var _encoches: Array = []          # [{anneau: MeshInstance3D, mat: StandardMaterial3D, braise: float}] (mon autel)
var _lumiere_autel: OmniLight3D
var _galets := {}                  # objet -> {n: Node3D, label: Label3D}
var _juste_vu := false
var _echecs_vus := 0
var _flash := 0.0
var _onde := 0.0                   # la vague de lumière d'une suite juste (secondes depuis le début)
var _nb_encoches := 0
var _autels := {}                  # joueur -> son autel (Node3D)


func construire() -> void:
	meuble = "autel"
	haut_etabli = Dispositions.HAUT_AUTEL
	var pierre := matiere("roche", 0.45)
	var pierre_vieille := matiere("roche", 0.8, Color(0.62, 0.6, 0.55))
	var pierre_verte := matiere("roche", 0.9, Color(0.72, 0.8, 0.66))
	# Le sol de la place : de vieilles dalles autour de la stèle, bordées de pierres couchées.
	var dalles := _cylindre(2.15, 0.06, matiere("pave", 1.4, Color(0.72, 0.74, 0.68)))
	dalles.position.y = 0.0
	add_child(dalles)
	for i in 14:
		var a := TAU * i / 14.0
		var bord := _boite(Vector3(0.62, 0.16, 0.3), pierre_vieille)
		bord.position = Vector3(sin(a), 0.05, cos(a)) * 2.2
		bord.rotation.y = a
		add_child(bord)
	# La stèle : un pilier carré au centre, le même pour tous. Ses quatre faces sont creusées d'un
	# cartouche où luisent MES signes : on les lit d'où qu'on soit.
	_stele = Node3D.new()
	_stele.rotation = Vector3(0.03, PI / 4, -0.02)
	add_child(_stele)
	var socle := _boite(Vector3(1.55, 0.3, 1.55), pierre_vieille)
	socle.position.y = 0.1
	_stele.add_child(socle)
	var socle2 := _boite(Vector3(1.3, 0.28, 1.3), pierre_verte)
	socle2.position.y = 0.38
	_stele.add_child(socle2)
	var fut := _boite(Vector3(1.0, 2.7, 1.0), pierre)
	fut.position.y = 1.7
	_stele.add_child(fut)
	var tete := _boite(Vector3(0.84, 0.34, 0.84), pierre)
	tete.position.y = 3.2
	tete.rotation.y = 0.12
	_stele.add_child(tete)
	var pointe := _cylindre(0.0, 0.42, pierre_vieille, 0.52)
	pointe.position.y = 3.58
	pointe.rotation.y = PI / 4
	_stele.add_child(pointe)
	var ambre := matiere("flamme", 1.0, Color(1.0, 0.7, 0.35), Color(1.0, 0.45, 0.12))
	for f in 4:
		var face := Node3D.new()
		face.rotation.y = f * PI / 2
		_stele.add_child(face)
		# Le cartouche, à peine creusé dans la pierre et noirci par la suie de la lueur.
		var creux := _boite(Vector3(0.8, 1.45, 0.05), matiere("roche", 0.8, Color(0.5, 0.46, 0.42)))
		creux.position = Vector3(0, 1.85, 0.5)
		face.add_child(creux)
		# Un filet de braise autour du cartouche, et des encoches de chaque côté.
		for y: float in [1.1, 2.6]:
			var filet := _boite(Vector3(0.84, 0.014, 0.012), ambre)
			filet.position = Vector3(0, y, 0.532)
			face.add_child(filet)
		for x: float in [-0.41, 0.41]:
			var montant := _boite(Vector3(0.014, 1.5, 0.012), ambre)
			montant.position = Vector3(x, 1.85, 0.532)
			face.add_child(montant)
		var g := Label3D.new()
		g.font = Style.police("titre")
		g.font_size = 30
		g.pixel_size = 0.0042
		g.outline_size = 10
		g.modulate = Color(1.0, 0.62, 0.25)
		g.outline_modulate = Color(0.25, 0.05, 0.0)
		g.width = 220.0
		g.shaded = false
		g.position = Vector3(0, 1.9, 0.54)
		g.double_sided = false
		face.add_child(g)
		_gravures.append(g)
	_lueur = _lumiere(Color(1.0, 0.5, 0.2), 0.9, 3.4, Vector3(0, 1.9, 0))
	_stele.add_child(_lueur)
	# Mousse, lierre et racines : la stèle est là depuis longtemps.
	morceau("moss_01", 2, Vector3(0.3, 3.4, 0.0), 2.8, 0.3, _stele)
	morceau("moss_01", 5, Vector3(-0.38, 1.0, 0.3), 2.4, 1.2, _stele)
	morceau("moss_01", 3, Vector3(0.45, 0.58, -0.4), 2.0, 2.0, _stele)
	morceau("moss_01", 1, Vector3(-0.4, 3.0, -0.4), 1.6, 0.7, _stele)
	modele("root_cluster_01", Vector3(0, -0.15, -0.5), 0.55, 0.0, _stele)
	modele("root_cluster_01", Vector3(0.5, -0.12, 0.55), 0.45, 2.4, _stele)
	for k in 6:
		morceau("rock_moss_set_01", k, Vector3(-1.1 + k * 0.45, -0.05, -0.8 + (k % 2) * 1.6), 0.26, k * 1.3, _stele)
	# Le cercle de menhirs, derrière la stèle (au-delà des postes des joueurs).
	for k in 9:
		var a := TAU * k / 9.0 + 0.3
		var p := Vector3(sin(a), 0, cos(a)) * (rayon(equipe) + 3.9)
		var h := 1.7 + 0.7 * absf(sin(k * 2.1))
		var m := _boite(Vector3(0.7, h, 0.5), pierre)
		m.position = p + Vector3(0, h * 0.5 - 0.1, 0)
		m.rotation = Vector3(0.05 * sin(k * 3.0), a, 0.06 * cos(k * 1.7))
		add_child(m)
		morceau("moss_01", k, p + Vector3(0, h - 0.12, 0), 1.9, a)
		morceau("grass_medium_01", k * 2, p + Vector3(0.3, 0, 0.2), 1.2, a)
		morceau("fern_02", k % 4, p + Vector3(-0.5, 0, 0.1), 0.9, a)
		# Sa part de l'alphabet, sur la face tournée vers la stèle.
		var noms := PackedStringArray()
		for r in range(k * Catalogue.RUNES.size() / 9, (k + 1) * Catalogue.RUNES.size() / 9):
			noms.append(Langue.t(Catalogue.RUNES[r]))
		var g := Label3D.new()
		g.font = Style.police("titre")
		g.text = "\n".join(noms)
		g.font_size = 46
		g.pixel_size = 0.0036
		g.outline_size = 8
		g.modulate = Color(0.95, 0.72, 0.42)
		g.outline_modulate = Color(0.12, 0.08, 0.06)
		g.double_sided = false
		g.position = Vector3(0, 0.1, -0.255)
		g.rotation.y = PI
		m.add_child(g)
		if k == 0:
			set_meta("liste_pos", p)


## L'autel de chacun : une grande dalle sur quatre piliers, un socle, de la mousse ; les encoches viennent
## avec la première vue de l'hôte (on ne sait pas avant combien il y en a).
func _meuble_de(k: int) -> Node3D:
	var e := Node3D.new()
	e.transform = Dispositions.autel(k, equipe)
	add_child(e)
	_autels[k] = e
	var haut := Dispositions.HAUT_AUTEL
	var pierre := matiere("pierre", 0.55, Color(0.82, 0.82, 0.78))
	var vieille := matiere("roche", 0.9, Color(0.66, 0.64, 0.58))
	var verte := matiere("roche", 0.9, Color(0.72, 0.8, 0.66))
	# Deux marches de socle, la dalle, quatre piliers.
	var marche := _boite(Vector3(2.5, 0.1, 1.6), vieille)
	marche.position = Vector3(0, 0.05, 0.0)
	e.add_child(marche)
	var marche2 := _boite(Vector3(2.3, 0.1, 1.54), verte)
	marche2.position = Vector3(0, 0.15, 0.0)
	e.add_child(marche2)
	for x: float in [-0.92, 0.92]:
		for z: float in [-0.56, 0.56]:
			var pilier := _boite(Vector3(0.34, haut - 0.34, 0.34), vieille)
			pilier.position = Vector3(x, 0.2 + (haut - 0.34) * 0.5, z)
			e.add_child(pilier)
			var chapiteau := _boite(Vector3(0.44, 0.07, 0.44), pierre)
			chapiteau.position = Vector3(x, haut - 0.17, z)
			e.add_child(chapiteau)
	var dalle := _boite(Vector3(2.2, 0.14, 1.58), pierre)
	dalle.position = Vector3(0, haut - 0.07, 0)
	e.add_child(dalle)
	var bordure := _boite(Vector3(2.26, 0.05, 1.62), verte)
	bordure.position = Vector3(0, haut - 0.145, 0)
	e.add_child(bordure)
	# Le tablier du fond (sous la dalle) et de la mousse sur les bords.
	var fond := _boite(Vector3(1.9, haut - 0.4, 0.1), vieille)
	fond.position = Vector3(0, 0.2 + (haut - 0.4) * 0.5, -0.6)
	e.add_child(fond)
	morceau("moss_01", 0, Vector3(1.0, haut, -0.7), 1.8, 0.4, e)
	morceau("moss_01", 4, Vector3(-1.02, haut, 0.55), 1.6, 2.1, e)
	morceau("moss_01", 6, Vector3(-0.2, haut, -0.78), 1.4, 1.1, e)
	morceau("grass_medium_01", 3 + k, Vector3(1.2, 0.05, 0.7), 1.0, k, e)
	# Le liseré gravé de la réserve, pour dire où ranger les galets.
	var reserve := _boite(Vector3(2.02, 0.006, 0.78), matiere("roche", 0.8, Color(0.5, 0.48, 0.45)))
	reserve.position = Vector3(0, haut + 0.003, 0.33)
	e.add_child(reserve)
	var sillon := _boite(Vector3(2.02, 0.01, 0.02), matiere("flamme", 1.0, Color(0.9, 0.55, 0.25), Color(0.7, 0.3, 0.08)))
	sillon.position = Vector3(0, haut + 0.005, -0.06)
	e.add_child(sillon)
	if k == rang:
		_lumiere_autel = _lumiere(AMBRE, 0.55, 3.2, Vector3(0, haut + 1.0, 0.1))
		e.add_child(_lumiere_autel)
	return e


func habiller() -> void:
	super.habiller()
	# Deux bougies aux coins du fond de l'autel.
	var e := etabli()
	bougie(Vector3(-0.98, Dispositions.HAUT_AUTEL, -0.66), e)
	bougie(Vector3(0.98, Dispositions.HAUT_AUTEL, -0.66), e)


## Rien à semer (ni fougère ni lanterne) sur les autels, ni dans l'allée qui y mène.
func libre(p: Vector3) -> bool:
	for k in equipe:
		var l := Dispositions.autel(k, equipe).affine_inverse() * p
		if absf(l.x) < 1.5 and l.z > -1.1 and l.z < 1.4:
			return false
	return true


## Les encoches de tous les autels, dès qu'on sait combien il y en a.
func _batir_encoches(nb: int) -> void:
	_nb_encoches = nb
	for k in equipe:
		var e: Node3D = _autels[k] if _autels.has(k) else etabli()
		for j in nb:
			var l := Dispositions.encoche_locale(j, nb)
			var creux := _boite(Vector3(0.21, 0.012, 0.21), matiere("roche", 1.0, Color(0.16, 0.15, 0.14)))
			creux.position = Vector3(l.x, l.y + 0.004, l.z)
			e.add_child(creux)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.25, 0.14, 0.08)
			mat.emission_enabled = true
			mat.emission = AMBRE
			mat.emission_energy_multiplier = 0.25
			mat.roughness = 0.8
			var anneau_ := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.1
			tm.outer_radius = 0.118
			tm.rings = 24
			tm.ring_segments = 6
			anneau_.mesh = tm
			anneau_.scale = Vector3(1, 0.14, 1)
			anneau_.material_override = mat
			anneau_.position = Vector3(l.x, l.y + 0.012, l.z)
			e.add_child(anneau_)
			# Le numéro d'ordre, gravé devant l'encoche.
			var num := _grave(str(j + 1), 26, Vector3(l.x, l.y + 0.012, l.z + 0.155))
			num.modulate = Color(0.85, 0.7, 0.5)
			e.add_child(num)
			if k == rang:
				_encoches.append({"anneau": anneau_, "mat": mat, "braise": 0.25, "col": AMBRE})


# ---------------------------------------------------------------- les galets

func objet_prise(d: Dictionary) -> Node3D:
	var x: Dictionary = d.get("x", {})
	var t := float(x.get("t", 0.17))
	var n := Node3D.new()
	var s := int(x.get("s", 0))
	var teinte := Color(0.72 + 0.04 * (s % 5), 0.7 + 0.03 * (s % 4), 0.64 + 0.04 * (s % 3))
	var galet := _sphere(t * 0.5, matiere("roche", 2.2, teinte))
	galet.scale = Vector3(1.12, 0.5, 0.92)
	galet.position.y = t * 0.25
	galet.rotation.y = float(s) * 0.9
	n.add_child(galet)
	var l := Label3D.new()
	l.font = Style.police("titre")
	l.text = Langue.t(str(d.get("l", "")))
	l.font_size = 24
	l.pixel_size = 0.0022
	l.outline_size = 7
	l.modulate = Color(1.0, 0.7, 0.34)
	l.outline_modulate = Color(0.2, 0.08, 0.02)
	l.shaded = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.width = 92.0
	l.rotation.x = -PI / 2
	l.position.y = t * 0.5 + 0.004
	l.double_sided = false
	n.add_child(l)
	_galets[int(d["i"])] = {"n": n, "label": l}
	return n


func nom_prise(d: Dictionary) -> String:
	return Langue.t("le galet « %s »") % Langue.t(str(d.get("l", "")))


func pos_prise(c: Dictionary, _rang: int, _o: Dictionary) -> Vector3:
	return Vector3(c["pos"]) + (Vector3(0, 0.04, 0) if _rang < 0 else Vector3.ZERO)


func prise_evenement(quoi: String, _d: Dictionary, pos: Vector3) -> void:
	_son(Prise.son("pierre_pose" if quoi == "pose" else "pierre_prend"), pos, 0.0)


func _son(flux: AudioStream, pos: Vector3, db: float) -> void:
	if not is_inside_tree():
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = flux
	a.bus = "Effets"
	a.unit_size = 5.0
	a.volume_db = db
	if pos != Vector3.ZERO:
		a.position = to_local(pos)
	elif _etabli != null:
		a.position = _etabli.position + Vector3(0, 1.0, 0)
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)


# ---------------------------------------------------------------- la vue

func animer(vue: Dictionary, _phase: float, delta: float) -> void:
	# « Lune   ?   ? » devient une rune par ligne, avec sa place : on sait laquelle est où.
	var morceaux := texte_ton(vue, "or").split("   ")
	var lignes := PackedStringArray()
	for k in morceaux.size():
		lignes.append("%d   %s" % [k + 1, Langue.t(morceaux[k])])
	var g := "\n".join(lignes) if morceaux[0] != "" else ""
	for gravure in _gravures:
		if gravure.text != g:
			gravure.text = g
	var prise := bloc(vue, "prise")
	if prise.is_empty():
		return
	var cases: Array = prise.get("cibles", [])
	if not _autel_vu and not cases.is_empty():
		_autel_vu = true
		_batir_encoches(cases.size())
	_animer_autel(prise, cases, delta)
	# Une suite juste embrase la pierre.
	var juste: bool = prise.get("juste", false)
	_lueur.light_energy = move_toward(_lueur.light_energy, 2.8 if juste else 0.9, delta * 2.0)


func _animer_autel(prise: Dictionary, cases: Array, delta: float) -> void:
	var juste: bool = prise.get("juste", false)
	var echecs := int(prise.get("echecs", 0))
	var conf: Array = prise.get("conf", [])
	if echecs > _echecs_vus:
		_echecs_vus = echecs
		_flash = 1.0
		_son(Prise.son("refus"), Vector3.ZERO, 0.0)
		if _etabli != null:
			secouer(_etabli, 0.03)
	if juste and not _juste_vu:
		_juste_vu = true
		_onde = 0.0
		_son(Prise.son("carillon"), Vector3.ZERO, 2.0)
	_flash = maxf(_flash - delta * 1.1, 0.0)
	if juste:
		_onde += delta
	# Les galets : la gravure d'un galet posé luit.
	var posees := {}
	for c: Dictionary in cases:
		for o: int in c["o"]:
			posees[o] = int(c["c"])
	for i: int in _galets.keys():
		var ent: Dictionary = _galets[i]
		if not is_instance_valid(ent["n"]):
			_galets.erase(i)
			continue
		var l: Label3D = ent["label"]
		var vise := Color(1.0, 0.7, 0.34)
		if posees.has(i):
			vise = Color(1.4, 0.95, 0.5) if not juste else Color(1.1, 1.5, 0.7)
		l.modulate = l.modulate.lerp(vise, minf(delta * 8.0, 1.0))
	# Les anneaux des encoches : braise éteinte, galet posé, confirmé par la stèle, onde dorée, éclair rouge.
	var cible_lum := 0.6 if not posees.is_empty() else 0.45
	for j in _encoches.size():
		var ent2: Dictionary = _encoches[j]
		var pleine := false
		if j < cases.size():
			pleine = not (cases[j]["o"] as Array).is_empty()
		var col := AMBRE
		var e := 0.25
		if pleine:
			e = 1.3
		if conf.has(j):
			col = VERT_OR
			e = 2.0
		if juste:
			var t := _onde - j * 0.12
			col = VERT_OR
			e = 2.6 if t > 0.0 else e
		if _flash > 0.0:
			col = col.lerp(ROUGE, _flash)
			e = maxf(e, 3.0 * _flash)
		ent2["braise"] = lerpf(ent2["braise"], e, minf(delta * 10.0, 1.0))
		ent2["col"] = (ent2["col"] as Color).lerp(col, minf(delta * 10.0, 1.0))
		var m: StandardMaterial3D = ent2["mat"]
		m.emission = ent2["col"]
		m.emission_energy_multiplier = ent2["braise"]
	if _lumiere_autel != null:
		var cible_c := ROUGE if _flash > 0.2 else (VERT_OR if juste else AMBRE)
		_lumiere_autel.light_color = _lumiere_autel.light_color.lerp(cible_c, minf(delta * 6.0, 1.0))
		_lumiere_autel.light_energy = move_toward(_lumiere_autel.light_energy, 0.65 if juste else (1.6 if _flash > 0.2 else cible_lum), delta * 3.0)
