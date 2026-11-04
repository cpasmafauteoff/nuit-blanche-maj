class_name EssaiPas
extends RefCounted
## Essai (--essai-pas=<dossier>) : ENREGISTRE le bus Master pendant des séquences scriptées (marche libre au
## clavier simulé, course libre, trajet guidé, bot à 3/8/15 m, saut + atterrissage) et mesure les crêtes de
## pas. Écrit un .wav par séquence et affiche : crête, nombre de pas par seconde, crête moyenne d'un pas.
## « play() appelé » ne prouve rien : ici on mesure le son réellement mixé.

const SEUIL := 0.008        # amplitude (0..1) au-dessus de laquelle un bloc compte comme un pas
const BLOC := 0.01          # s
const REPOS := 0.16         # s : deux pas ne se touchent pas

var p: Node
var dossier: String
var _rec: AudioEffectRecord
var _bus_master := 0


func _init(principal: Node, dir: String) -> void:
	p = principal
	dossier = dir


func attendre(t: float) -> void:
	await p.get_tree().create_timer(t).timeout


func touche(action: String, bas: bool) -> void:
	for k: int in Options.touches(action):
		var ev := InputEventKey.new()
		ev.keycode = k as Key
		ev.physical_keycode = k as Key
		ev.pressed = bas
		Input.parse_input_event(ev)


func _preparer() -> void:
	for nom in ["Ambiance", "Musique", "Voix"]:
		var i := AudioServer.get_bus_index(nom)
		if i >= 0:
			AudioServer.set_bus_mute(i, true)
	_rec = AudioEffectRecord.new()
	_rec.format = AudioStreamWAV.FORMAT_16_BITS
	_bus_master = AudioServer.get_bus_index("Master")
	AudioServer.add_bus_effect(_bus_master, _rec)


## Enregistre `duree` s pendant que `action` (Callable asynchrone) se déroule ; renvoie le résumé.
func enregistrer(nom: String, duree: float, action: Callable) -> Dictionary:
	print("[pas-audio] enregistre ", nom)
	_rec.set_recording_active(true)
	var t0 := Time.get_ticks_msec()
	await action.call()
	var reste := duree - (Time.get_ticks_msec() - t0) / 1000.0
	if reste > 0.0:
		await attendre(reste)
	_rec.set_recording_active(false)
	var wav := _rec.get_recording()
	wav.save_to_wav("%s/%s.wav" % [dossier, nom])
	var r := analyser(wav)
	print("[pas-audio] %-26s crête=%.3f pas=%2d (%.1f/s) crête_moy_pas=%.3f durée=%.1fs" % [nom, r["crete"], r["pas"], r["par_s"], r["moy"], r["duree"]])
	return r


## Crêtes de pas dans un enregistrement 16 bits (stéréo ou mono).
static func analyser(wav: AudioStreamWAV) -> Dictionary:
	var d := wav.data
	var canaux := 2 if wav.stereo else 1
	var fe := float(wav.mix_rate)
	var n := d.size() / (2 * canaux)
	var bloc := int(fe * BLOC)
	var crete := 0.0
	var crete_pas: Array[float] = []
	var dernier := -10.0
	var i := 0
	var pic_courant := 0.0
	var en_pas := false
	var fin_pas := -10.0
	while i + bloc <= n:
		var m := 0.0
		for j in range(i, i + bloc):
			for c in canaux:
				var v := absf(d.decode_s16((j * canaux + c) * 2) / 32768.0)
				m = maxf(m, v)
		var t := float(i) / fe
		crete = maxf(crete, m)
		if m > SEUIL:
			if not en_pas and t - fin_pas > REPOS:
				en_pas = true
				pic_courant = 0.0
			if en_pas:
				pic_courant = maxf(pic_courant, m)
				fin_pas = t
		elif en_pas and t - fin_pas > 0.04:
			en_pas = false
			crete_pas.append(pic_courant)
		i += bloc
	if en_pas:
		crete_pas.append(pic_courant)
	var somme := 0.0
	for c: float in crete_pas:
		somme += c
	var duree := float(n) / fe
	return {"crete": crete, "pas": crete_pas.size(), "par_s": float(crete_pas.size()) / maxf(duree, 0.001),
		"moy": somme / maxf(crete_pas.size(), 1), "duree": duree}


func placer(pos: Vector3, vers: Vector3) -> void:
	p._appliquer_placement(pos, vers, "libre")


func lancer() -> void:
	print("[pas-audio] début")
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	p._auto = false
	await attendre(2.0)
	print("[pas-audio] prépare")
	_preparer()
	print("[pas-audio] prêt")
	DirAccess.make_dir_recursive_absolute(dossier)
	var sortie := {}
	var depart := Vector3(-8, 0, -6)
	var vers := Vector3(8, 0, -6)
	# (a) marche libre au clavier simulé
	sortie["a_marche_libre"] = await enregistrer("a_marche_libre", 4.5, func():
		placer(depart, vers)
		await attendre(0.3)
		touche("avancer", true)
		await attendre(3.5)
		touche("avancer", false))
	await attendre(0.5)
	# (b) course libre (avancer + sprint)
	sortie["b_course_libre"] = await enregistrer("b_course_libre", 3.5, func():
		placer(depart, vers)
		await attendre(0.3)
		touche("avancer", true)
		touche("sprint", true)
		await attendre(2.8)
		touche("avancer", false)
		touche("sprint", false))
	await attendre(0.5)
	# (c) déplacement automatique (marche guidée)
	sortie["c_deplacement_auto"] = await enregistrer("c_deplacement_auto", 4.0, func():
		placer(depart, vers)
		await attendre(0.3)
		p._sur_placement(Vector3(8, 0, -6), Vector3(8, 0, 0), "libre")
		await attendre(3.4))
	await attendre(1.0)
	# (d) un bot qui marche à 3, 8 et 15 m
	var id_bot := -1
	for id in p.meneur._bots:
		if id_bot < 0:
			id_bot = id
	for dist in [3, 8, 15]:
		var nom := "d_bot_%02dm" % dist
		sortie[nom] = await enregistrer(nom, 5.0, func():
			var moi := Vector3(0, 0, -10)
			placer(moi, moi + Vector3(0, 0, 1))
			p.tete.rotation.x = 0.0
			for id in p.meneur._bots:
				var b: Dictionary = p.meneur._bots[id]
				if id == id_bot:
					b["pos"] = Vector3(-6, 0, -10 + dist)
					b["chemin"] = [Vector3(30, 0, -10 + dist)]
					b["mode"] = "libre" if b["mode"] == "mort" else b["mode"]
				else:
					b["pos"] = Vector3(0, 0, 80)
					b["chemin"] = []
			await attendre(0.4)
			for k in 8:
				var b: Dictionary = p.meneur._bots[id_bot]
				if (b["chemin"] as Array).is_empty():
					b["chemin"] = [Vector3(30, 0, -10 + dist)]
				await attendre(0.5))
	for id in p.meneur._bots:
		(p.meneur._bots[id] as Dictionary)["pos"] = Vector3(0, 0, 80)
		(p.meneur._bots[id] as Dictionary)["chemin"] = []
	await attendre(1.0)
	# (e) un saut sur place + atterrissage, puis une chute de plus haut
	sortie["e_saut"] = await enregistrer("e_saut", 3.0, func():
		placer(depart, vers)
		await attendre(0.6)
		touche("sauter", true)
		await attendre(0.1)
		touche("sauter", false)
		await attendre(1.4))
	await attendre(0.5)
	# (g) calibrage 3D : _jouer_pas à 0 dB à 1, 3, 8, 15, 22 m devant soi
	for dist in [1, 3, 8, 15, 22]:
		var nom3 := "g_3d_%02dm" % dist
		await enregistrer(nom3, 0.8, func():
			placer(Vector3(0, 0, -10), Vector3(0, 0, 0))
			await attendre(0.2)
			var ici: Vector3 = p.corps_joueur.global_position
			var devant: Vector3 = -p.corps_joueur.global_transform.basis.z
			p._jouer_pas(Sons.pas("pave", 0), ici + devant * float(dist), false, 0.0, 1.0)
			await attendre(0.5))
	# (f) calibrage : la crête de CHAQUE échantillon de pas joué seul à 0 dB
	var dir_ogg := DirAccess.open("res://sons/pas")
	for fichier: String in dir_ogg.get_files():
		if not fichier.ends_with(".ogg"):
			continue
		var r := await enregistrer("f_" + fichier.get_basename(), 0.6, func():
			var a := AudioStreamPlayer.new()
			a.stream = load("res://sons/pas/" + fichier)
			a.bus = "Effets"
			p.add_child(a)
			a.play()
			await attendre(0.5)
			a.queue_free())
	print("[pas-audio] RESUME ", JSON.stringify(sortie))
	p.get_tree().quit()
