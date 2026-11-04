class_name VueNuitLoups
extends Control
## La nuit vue des loups, au récit de fin : la Ronde vue de dessus (maisons numérotées, temple,
## place) où l'on rejoue chaque nuit en accéléré. Chaque loup laisse une trace de la couleur de son
## bandeau, sa silhouette avance, la porte attaquée s'allume. Les noms sont révélés à côté des
## couleurs (fin de partie). Les positions viennent de l'hôte, qui ne les envoie qu'une fois la
## partie finie (cf. Meneur._enregistrer_loups) ; la géométrie, de Ronde.

const DUREE_REJEU := 14.0       # une nuit de 90 s se rejoue en 14 s
const PAUSE_FIN := 3.0
const FOND := Color(0.075, 0.055, 0.05)
const SOL := Color(0.13, 0.1, 0.08)
const MUR := Color(0.32, 0.25, 0.19)
const ENCRE := Color(0.93, 0.78, 0.45)
const ROUGE := Color(0.85, 0.12, 0.1)

var _nuits: Array = []
var _loups: Array = []          # [{id, nom, role, couleur, couleur_nom}] dans l'ordre d'apparition
var _noms := {}                 # id -> nom
var _nuit := 0
var _t := 0.0
var _taille_carte := 460.0


func _init() -> void:
	custom_minimum_size = Vector2(760, 470)
	mouse_filter = Control.MOUSE_FILTER_STOP


## `nuits` : res["nuits_loups"] ; `sieges` : res["sieges"] ; `roles` : res["roles"].
func donnees(nuits: Array, sieges: Dictionary, roles: Dictionary) -> void:
	_nuits = nuits
	_noms.clear()
	_loups.clear()
	for id in sieges:
		_noms[id] = str(sieges[id].get("nom", "?"))
	for n: Dictionary in nuits:
		for id in n["loups"]:
			var deja := false
			for l: Dictionary in _loups:
				if l["id"] == id:
					deja = true
			if deja:
				continue
			var k := int(sieges.get(id, {}).get("bandeau", -1))
			var couleur := Color.WHITE
			if k >= 0 and k < Bouille.BANDEAUX.size():
				couleur = Bouille.BANDEAUX[k][0]
			_loups.append({"id": id, "nom": _noms.get(id, "?"), "role": str(roles.get(id, "")), "couleur": couleur,
				"couleur_nom": Bouille.nom_bandeau(k)})
	_nuit = 0
	_t = 0.0
	queue_redraw()


func nb_nuits() -> int:
	return _nuits.size()


func numero_nuit(k: int) -> int:
	return int((_nuits[k] as Dictionary)["n"])


func choisir_nuit(k: int) -> void:
	_nuit = clampi(k, 0, maxi(_nuits.size() - 1, 0))
	_t = 0.0
	queue_redraw()


## Pour les captures : fige le rejeu à une fraction (0..1) de la nuit.
func figer_a(fraction: float) -> void:
	_t = fraction * DUREE_REJEU
	set_process(false)
	queue_redraw()


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _nuits.is_empty():
		return
	_t = fmod(_t + delta, DUREE_REJEU + PAUSE_FIN)
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_t = 0.0   # un clic sur la carte rejoue la nuit


# ---------------------------------------------------------------- dessin

func _centre() -> Vector2:
	return Vector2(_taille_carte * 0.5 + 6.0, size.y * 0.5)


func _echelle() -> float:
	return (_taille_carte * 0.5 - 8.0) / (Ronde.R_CHEMIN_MAX + 3.5)


## Le monde (x, z) sur la carte : le temple (z positif) en haut.
func _vers_carte(p: Vector3) -> Vector2:
	return _centre() + Vector2(p.x, -p.z) * _echelle()


func _vers_carte2(p: Vector2) -> Vector2:
	return _centre() + Vector2(p.x, -p.y) * _echelle()


func _draw() -> void:
	var police := Style.police("texte")
	var titre := Style.police("titre")
	var e := _echelle()
	var c := _centre()
	# La Ronde
	draw_circle(c, (Ronde.R_CHEMIN_MAX + 2.5) * e, FOND)
	draw_arc(c, Ronde.R_CHEMIN_MAX * e, 0, TAU, 96, Color(0.3, 0.23, 0.17, 0.5), 1.5, true)
	draw_arc(c, Ronde.R_CHEMIN_MIN * e, 0, TAU, 96, Color(0.3, 0.23, 0.17, 0.35), 1.0, true)
	draw_circle(c, Ronde.R_PLACE * e, SOL)
	draw_arc(c, Ronde.R_PLACE * e, 0, TAU, 96, Color(0.45, 0.35, 0.25, 0.5), 1.0, true)
	for i in Ronde.NB_MAISONS:
		var s := Ronde.souche(i)
		draw_circle(_vers_carte(s), 2.2, Color(0.4, 0.3, 0.2, 0.8))
	# Le temple et sa pierre
	var tc := Ronde.centre_temple()
	var tl := Ronde.TEMPLE_LARGE * 0.5
	var tp := Ronde.TEMPLE_PROFOND * 0.5
	var coins_t := PackedVector2Array([_vers_carte(tc + Vector3(-tl, 0, -tp)), _vers_carte(tc + Vector3(tl, 0, -tp)),
		_vers_carte(tc + Vector3(tl, 0, tp)), _vers_carte(tc + Vector3(-tl, 0, tp))])
	draw_colored_polygon(coins_t, Color(0.28, 0.27, 0.27))
	draw_polyline(coins_t + PackedVector2Array([coins_t[0]]), Color(0.6, 0.58, 0.55), 1.5)
	draw_circle(_vers_carte(Ronde.PIERRE), 3.5, Color(0.8, 0.78, 0.74))
	draw_string(titre, _vers_carte(tc) + Vector2(-26, -tp * e - 6), Langue.t("TEMPLE"), HORIZONTAL_ALIGNMENT_CENTER, 52, 11, Color(0.7, 0.68, 0.64))
	# Les maisons
	var nuit: Dictionary = _nuits[_nuit] if _nuit < _nuits.size() else {}
	var attaques: Array = nuit.get("attaques", [])
	var f := _echantillon_courant(nuit)
	var maisons_ouvertes := {}
	for a: Dictionary in attaques:
		if f >= int(a["t"]):
			maisons_ouvertes[int(a["maison"])] = a
	for i in Ronde.NB_MAISONS:
		var base := Basis(Vector3.UP, Ronde.angle_maison(i) + PI)
		var mc := Ronde.centre_maison(i)
		var coins := PackedVector2Array()
		for d: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			coins.append(_vers_carte(mc + base * Vector3(d.x * Ronde.LARGEUR * 0.5, 0, d.y * Ronde.PROFONDEUR * 0.5)))
		var touchee := maisons_ouvertes.has(i)
		draw_colored_polygon(coins, Color(0.34, 0.07, 0.06) if touchee else Color(0.2, 0.15, 0.11))
		draw_polyline(coins + PackedVector2Array([coins[0]]), ROUGE if touchee else MUR, 2.0 if touchee else 1.2)
		draw_string(titre, _vers_carte(mc) + Vector2(-20, 5), Ronde.numero(i), HORIZONTAL_ALIGNMENT_CENTER, 40, 14, Color(0.9, 0.85, 0.75))
		# Sa porte de derrière (celle que les loups ouvrent), côté forêt.
		var porte := _vers_carte(mc + base * Vector3(0, 0, -Ronde.PROFONDEUR * 0.5))
		if touchee:
			var pulse := 0.5 + 0.5 * sin(_t * 8.0)
			draw_circle(porte, 7.0 + pulse * 5.0, Color(ROUGE, 0.3 + 0.2 * pulse))
			draw_circle(porte, 4.0, ROUGE)
		else:
			draw_circle(porte, 2.0, Color(0.5, 0.4, 0.3))
	# Les traces et les silhouettes des loups
	var tailles := 0
	for l: Dictionary in _loups:
		var tab: PackedVector2Array = (nuit.get("loups", {}) as Dictionary).get(l["id"], PackedVector2Array())
		if tab.size() < 2:
			continue
		tailles = maxi(tailles, tab.size())
		var jusque := mini(f, tab.size() - 1)
		var points := PackedVector2Array()
		for k in range(0, jusque + 1):
			points.append(_vers_carte2(tab[k]))
		var couleur: Color = l["couleur"]
		if points.size() >= 2:
			draw_polyline(points, Color(0, 0, 0, 0.7), 5.0, true)
			draw_polyline(points, Color(couleur, 0.9), 3.0, true)
		var cap := Vector2(0, -1)
		for k in range(jusque, 0, -1):
			var dv := tab[k] - tab[k - 1]
			if dv.length() > 0.05:
				cap = Vector2(dv.x, -dv.y).normalized()
				break
		_silhouette(points[points.size() - 1] if not points.is_empty() else _vers_carte2(tab[0]), cap, couleur)
	# Titre de la nuit
	draw_string(titre, Vector2(12, 24), Langue.t("Nuit %d") % int(nuit.get("n", 0)) if not nuit.is_empty() else "", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ENCRE)
	# La légende : qui est quelle couleur, ce qui s'est passé
	var x := _taille_carte + 36.0
	var y := 44.0
	draw_string(titre, Vector2(x, y), Langue.t("LA MEUTE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ENCRE)
	y += 12.0
	for l: Dictionary in _loups:
		y += 28.0
		var couleur: Color = l["couleur"]
		draw_rect(Rect2(x, y - 15, 18, 18), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(x + 1, y - 14, 16, 16), couleur)
		var role := Roles.nom(l["role"]) if l["role"] != "" else ""
		draw_string(police, Vector2(x + 28, y), "%s" % l["nom"], HORIZONTAL_ALIGNMENT_LEFT, 250, 19, Color.WHITE)
		draw_string(police, Vector2(x + 28, y + 15), (Langue.t("bandeau %s · %s") % [Langue.t(l["couleur_nom"]), Langue.t(role)]) if role != "" else (Langue.t("bandeau %s") % Langue.t(l["couleur_nom"])),
			HORIZONTAL_ALIGNMENT_LEFT, 280, 13, Color(1, 1, 1, 0.55))
		y += 14.0
	y += 34.0
	draw_string(titre, Vector2(x, y), Langue.t("CETTE NUIT"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ENCRE)
	if attaques.is_empty():
		y += 26.0
		draw_string(police, Vector2(x, y), Langue.t("La meute n'a attaqué aucune porte."), HORIZONTAL_ALIGNMENT_LEFT, 300, 17, Color(1, 1, 1, 0.8))
	for a: Dictionary in attaques:
		y += 26.0
		var vue := f >= int(a["t"])
		var porte_nom := Langue.t("Porte %s") % Ronde.numero(int(a["maison"]))
		var texte := porte_nom + (": " if Langue.en_anglais() else " : ")
		if not vue:
			texte += "…"
		elif a["reussi"]:
			texte += Langue.t("%s est dévoré(e).") % Langue.t(_noms.get(a["victime"], "quelqu'un"))
		else:
			texte += Langue.t("%s résiste.") % Langue.t(_noms.get(a["victime"], "quelqu'un"))
		draw_string(police, Vector2(x, y), texte, HORIZONTAL_ALIGNMENT_LEFT, 310, 17, Color(1, 0.75, 0.7) if vue else Color(1, 1, 1, 0.4))
	y += 30.0
	draw_string(Style.police("italique"), Vector2(x, y), Langue.t("Clique sur la carte pour rejouer la nuit."), HORIZONTAL_ALIGNMENT_LEFT, 310, 14, Color(1, 1, 1, 0.45))


## L'image du rejeu (indice d'échantillon) pour l'instant courant.
func _echantillon_courant(nuit: Dictionary) -> int:
	var n := 0
	for id in nuit.get("loups", {}):
		n = maxi(n, (nuit["loups"][id] as PackedVector2Array).size())
	if n <= 1:
		return 0
	return clampi(int(_t / DUREE_REJEU * float(n - 1)), 0, n - 1)


## Un loup vu de dessus : corps, tête, oreilles, queue, tourné dans le sens de sa marche.
func _silhouette(pos: Vector2, cap: Vector2, couleur: Color) -> void:
	var av := cap.normalized() * 2.5
	var lat := Vector2(-av.y, av.x)
	var corps := PackedVector2Array([pos + av * 9.0, pos + lat * 5.5 - av * 3.0, pos - av * 9.0 + lat * 1.5, pos - av * 9.0 - lat * 1.5,
		pos - lat * 5.5 - av * 3.0])
	draw_colored_polygon(corps, Color(0.07, 0.06, 0.06))
	draw_polyline(corps + PackedVector2Array([corps[0]]), couleur, 2.0, true)
	var tete := pos + av * 9.0
	draw_colored_polygon(PackedVector2Array([tete + av * 5.0, tete + lat * 3.5 - av * 2.0, tete - lat * 3.5 - av * 2.0]), Color(0.07, 0.06, 0.06))
	for c: float in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([tete + lat * c * 3.0, tete + lat * c * 5.5 - av * 4.5, tete + lat * c * 1.0 - av * 3.0]), Color(0.07, 0.06, 0.06))
	draw_circle(tete + av * 1.5 + lat * 1.6, 1.7, Color(1, 0.2, 0.1))
	draw_circle(tete + av * 1.5 - lat * 1.6, 1.7, Color(1, 0.2, 0.1))
	# Le bandeau, en couleur, sur l'arrière de la tête.
	draw_line(tete - av * 1.5 - lat * 3.5, tete - av * 1.5 + lat * 3.5, couleur, 2.0)
