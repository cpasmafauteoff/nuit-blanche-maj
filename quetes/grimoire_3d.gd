class_name Grimoire3D
extends Node3D
## Un grimoire en 3D posé à plat sur son pupitre (le Chaudron) : une reliure de cuir, deux piles de
## pages, huit lignes d'encre sur la double page, un marque-page, et une feuille qui se tourne quand
## on feuillette. Fermé et scellé pour ceux qui ne sont pas lecteurs : ils ne voient rien.
## Repère : +Y le haut de la page, +Z le bord qui regarde le lecteur, l'origine sur le dos de la reliure.
## Les corps de visée (couche des objets à toucher) portent la méta « grimoire » et « cote » (-1 page
## gauche, +1 page droite) : un clic à droite tourne vers l'avant, à gauche vers l'arrière.

const LARGE := 0.30                 # une page
const HAUTE := 0.42
const LIGNES := 3                   # lignes par page (chacune peut passer sur deux rangs)
const ECART := 0.125

var page := 0                       # la double page ouverte
var lignes: Array = []              # [[k, nom, fait]…]
var etape := 0
var ouvert := false
var _ouv := 0.0                     # 0 fermé, 1 ouvert (animé)
var _etiquettes_g: Array[Label3D] = []
var _etiquettes_d: Array[Label3D] = []
var _pile_g: MeshInstance3D
var _pile_d: MeshInstance3D
var _couv_g: Node3D
var _feuille: Node3D
var _anim := -1.0                   # le temps de la feuille qui se tourne (-1 : au repos)
var _sens := 1
var _a_afficher := 0
var _sceau: MeshInstance3D
var _corps: Array[StaticBody3D] = []
var _signet: MeshInstance3D


func construire(couche: int, cuir: Material, papier: Material, police: Font) -> void:
	# La reliure : deux plats de cuir et un dos.
	var dos := _boite(Vector3(0.035, 0.07, HAUTE + 0.03), cuir)
	dos.position = Vector3(0, -0.02, 0)
	add_child(dos)
	var plat_d := _boite(Vector3(LARGE + 0.03, 0.026, HAUTE + 0.03), cuir)
	plat_d.position = Vector3(LARGE * 0.5 + 0.02, -0.03, 0)
	add_child(plat_d)
	_couv_g = Node3D.new()
	add_child(_couv_g)
	var plat_g := _boite(Vector3(LARGE + 0.03, 0.026, HAUTE + 0.03), cuir)
	plat_g.position = Vector3(-LARGE * 0.5 - 0.02, -0.03, 0)
	_couv_g.add_child(plat_g)
	# Un fermoir de laiton sur le plat gauche : on le voit quand il est refermé.
	var fermoir := _boite(Vector3(0.05, 0.012, 0.06), _laiton())
	fermoir.position = Vector3(-LARGE - 0.03, -0.012, 0)
	_couv_g.add_child(fermoir)
	# Les piles de pages.
	_pile_d = _boite(Vector3(LARGE, 1.0, HAUTE), papier)
	add_child(_pile_d)
	_pile_g = _boite(Vector3(LARGE, 1.0, HAUTE), papier)
	_couv_g.add_child(_pile_g)
	# La feuille qu'on tourne.
	_feuille = Node3D.new()
	add_child(_feuille)
	var f := _boite(Vector3(LARGE, 0.004, HAUTE - 0.01), papier)
	f.position.x = LARGE * 0.5
	_feuille.add_child(f)
	_feuille.visible = false
	# Le texte : quatre lignes par page, la gauche puis la droite.
	for cote: int in [-1, 1]:
		for i in LIGNES:
			var l := Label3D.new()
			l.font = police
			l.font_size = 24
			l.pixel_size = 0.0016
			l.outline_size = 0
			l.shaded = false   # lisible quelle que soit la lueur : une encre pâle sur la page, c'est un grimoire vide
			l.double_sided = false
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.width = (LARGE - 0.07) / 0.0016
			l.modulate = Color(0.1, 0.05, 0.02)
			l.rotation.x = -PI / 2
			l.position = Vector3(-LARGE + 0.03 if cote < 0 else 0.03, 0.03, -HAUTE * 0.5 + 0.07 + i * ECART)
			add_child(l)
			(_etiquettes_g if cote < 0 else _etiquettes_d).append(l)
	# Un marque-page rouge qui pend du dos.
	_signet = _boite(Vector3(0.018, 0.003, 0.16), _mat(Color(0.5, 0.06, 0.05)))
	_signet.position = Vector3(0.025, 0.02, HAUTE * 0.5 + 0.06)
	add_child(_signet)
	# Le sceau de cire des livres fermés.
	_sceau = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.04
	cm.height = 0.014
	_sceau.mesh = cm
	_sceau.material_override = _mat(Color(0.55, 0.05, 0.04), Color(0.2, 0.0, 0.0))
	_sceau.position = Vector3(0.1, 0.09, 0.0)
	add_child(_sceau)
	# La visée : une boîte par page.
	for cote: int in [-1, 1]:
		var corps := StaticBody3D.new()
		corps.collision_layer = couche
		corps.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(LARGE, 0.1, HAUTE)
		cs.shape = bx
		corps.add_child(cs)
		corps.position = Vector3(cote * (LARGE * 0.5 + 0.01), 0.02, 0)
		corps.set_meta("grimoire", true)
		corps.set_meta("cote", cote)
		add_child(corps)
		_corps.append(corps)
	_poser_texte()


func _boite(taille: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = m
	return mi


func _mat(c: Color, emission := Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
	return m


func _laiton() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.65, 0.28)
	m.metallic = 0.6
	m.roughness = 0.4
	return m


## Le nombre de doubles pages du livre.
func nb_pages() -> int:
	return maxi(1, int(ceil(float(lignes.size()) / float(LIGNES * 2))))


## Le contenu du livre : ce que lit MON lecteur (`ouvert_` faux : le livre reste fermé et scellé).
func regler(nouvelles: Array, etape_: int, ouvert_: bool) -> void:
	var change := nouvelles != lignes or etape_ != etape or ouvert_ != ouvert
	lignes = nouvelles
	etape = etape_
	ouvert = ouvert_
	if page >= nb_pages():
		page = 0
	if change:
		_poser_texte()


## On tourne vers l'avant (+1) ou vers l'arrière (-1). Rend vrai si la page a bougé.
func feuilleter(sens: int) -> bool:
	if not ouvert or _anim >= 0.0 or nb_pages() <= 1:
		return false
	_sens = 1 if sens > 0 else -1
	_a_afficher = posmod(page + _sens, nb_pages())
	_anim = 0.0
	_feuille.visible = true
	return true


func _epaisseurs(frac: float) -> void:
	# Plus on avance, plus la pile de gauche grossit et celle de droite maigrit.
	var hg := 0.006 + 0.034 * frac
	var hd := 0.006 + 0.034 * (1.0 - frac)
	(_pile_g.mesh as BoxMesh).size = Vector3(LARGE, hg, HAUTE)
	_pile_g.position = Vector3(-LARGE * 0.5, hg * 0.5 - 0.012, 0)
	(_pile_d.mesh as BoxMesh).size = Vector3(LARGE, hd, HAUTE)
	_pile_d.position = Vector3(LARGE * 0.5, hd * 0.5 - 0.012, 0)
	for l in _etiquettes_g:
		l.position.y = hg - 0.012 + 0.002
	for l in _etiquettes_d:
		l.position.y = hd - 0.012 + 0.002
	_feuille.position.y = maxf(hd, hg) - 0.012 + 0.004


func _poser_texte() -> void:
	var total := nb_pages()
	_epaisseurs(float(page) / float(total - 1) if total > 1 else 0.5)
	for cote: int in [-1, 1]:
		var jeu := _etiquettes_g if cote < 0 else _etiquettes_d
		for i in LIGNES:
			var idx := page * LIGNES * 2 + (0 if cote < 0 else LIGNES) + i
			var l: Label3D = jeu[i]
			if idx < lignes.size() and ouvert:
				var ligne: Array = lignes[idx]
				l.text = "%d.  %s" % [int(ligne[0]) + 1, Langue.t(str(ligne[1]))]
				if bool(ligne[2]):
					l.modulate = Color(0.38, 0.32, 0.26, 0.55)
				elif int(ligne[0]) == etape:
					l.modulate = Color(0.55, 0.04, 0.02)
				else:
					l.modulate = Color(0.1, 0.05, 0.02)
			else:
				l.text = ""


func _process(delta: float) -> void:
	_ouv = move_toward(_ouv, 1.0 if ouvert else 0.0, delta * 2.2)
	_couv_g.rotation.z = -(1.0 - _ouv) * PI
	var visible_ouvert := _ouv > 0.85
	for l in _etiquettes_g:
		l.visible = visible_ouvert
	for l in _etiquettes_d:
		l.visible = visible_ouvert
	_sceau.visible = _ouv < 0.4
	_signet.visible = _ouv > 0.5
	_pile_g.visible = _ouv > 0.15
	if _anim >= 0.0:
		_anim += delta
		var u := clampf(_anim / 0.55, 0.0, 1.0)
		var e := ease(u, -2.0)
		# Vers l'avant : la feuille part de la droite (0) et finit à gauche (π) ; en arrière, l'inverse.
		_feuille.rotation.z = e * PI if _sens > 0 else (1.0 - e) * PI
		if u >= 0.5 and page != _a_afficher:
			page = _a_afficher
			_poser_texte()
		if u >= 1.0:
			_anim = -1.0
			_feuille.visible = false
