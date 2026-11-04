class_name DecorQuete
extends Node3D
## Le décor d'une quête dans sa clairière, chez un joueur (décision d'Edwin, 28/10 : « des vraies
## quêtes jouables dans le décor, pas un écran qui apparaît »).
##
## L'hôte décide de tout (MiniJeu) ; ce décor ne fait que MONTRER sa vue et offrir des objets à
## toucher. Chaque jeu hérite et surcharge :
##   construire()                     ses accessoires au centre de la clairière (origine locale) ;
##   objet_bouton(b, k) -> Node3D     l'objet qui porte le k-ième bouton (sinon : une tablette gravée) ;
##   animer(vue, phase, delta)        ses accessoires suivent la vue (jauges, battement, annonces) ;
##   cible_tenir() -> Node3D          ce qu'on agrippe quand la vue dit « tenir » (corde, planche).
## Les postes des joueurs : `poste(jeu, k, n)` (statique, l'hôte s'en sert pour les placer).

const COUCHE_BOUTONS := 1 << 18      # corps physiques des objets à toucher (rayon de visée seulement)

var jeu := ""
var zone := 0                       # la clairière où il se tient (les jeux qui placent un objet selon l'entrée)
var rang := 0                       # mon rang dans l'équipe
var equipe := 1
var niveau := ""                    # le niveau de la quête, quand on le sait avant la première vue ("" sinon)
var _etabli: Node3D                 # devant moi : là où sont posés mes objets à toucher
var meuble := "table"               # « table » (bois), « autel » (dalle de pierre), « » (aucun)
const RANG_RADEAU := 0.95
var haut_etabli := 0.85
var _mats := {}


## Où se tient le k-ième joueur (sur n), en local de la clairière. Par défaut : un cercle face au
## centre ; un jeu peut ranger ses joueurs autrement (les deux rives d'un pont, autour d'un puits…).
static func poste(j: String, k: int, n: int) -> Vector3:
	match j:
		"pont":
			# Les tenants de part et d'autre de la gorge, le long du tablier ; le marcheur part de la rive sud.
			return Passerelle.poste(k)
		"radeau":
			# Deux rameurs par rangée, les rangées espacées entre les traverses (cf. decor_radeau).
			var bord := -1.0 if k % 2 == 0 else 1.0
			var rangs := (n + 1) / 2
			return Vector3(bord * 0.75, 0.35, ((k / 2) - (rangs - 1) * 0.5) * RANG_RADEAU - 0.3)
		"incendie":
			# La chaîne : du puits (ouest) à la grange (est).
			return Vector3(-3.6 + 7.2 * k / maxf(n - 1, 1), 0, 1.2)
		"dame":
			# Un cercle serré au centre du cimetière, face à la Dame : les tombes commencent à 5 m (cf. Cimetiere).
			var ad := TAU * k / maxi(n, 1) + PI
			return Vector3(sin(ad), 0, cos(ad)) * Cimetiere.rayon_depart(n)
		"runes":
			# Plus large que le cercle ordinaire : chacun a devant lui un grand autel (cf. Dispositions).
			var ar := TAU * k / maxi(n, 1) + PI
			return Vector3(sin(ar), 0, cos(ar)) * (rayon(n) + 0.9)
		"lanternes":
			# Sur la rive sud du grand marais, en arc léger qui s'ouvre vers le sud : 1,6 m entre deux guides.
			var x_l := (k - (n - 1) * 0.5) * minf(1.6, 12.0 / maxf(n - 1, 1))
			return Vector3(x_l, 0, 4.1 + 0.014 * x_l * x_l)
	var a := TAU * k / maxi(n, 1) + PI
	return Vector3(sin(a), 0, cos(a)) * rayon(n)


## Entre le joueur k et le suivant, à la distance r du centre (cercle seulement) : là où l'on
## peut poser quelque chose sans gêner personne.
func entre(k: int, r: float) -> Vector3:
	var a := TAU * (k + 0.5) / maxi(equipe, 1) + PI
	return Vector3(sin(a), 0, cos(a)) * r


## Le rayon du cercle des joueurs : assez large pour que les établis ne se touchent pas.
static func rayon(n: int) -> float:
	# 2,3 m d'arc par joueur : à 8 et plus, la table du voisin ne mange plus la vue.
	return maxf(2.9, n * 2.3 / TAU + 0.8)


## Où l'on arrive dans la clairière : 1,6 m derrière sa place, à l'opposé du centre du décor.
static func arrivee(j: String, k: int, n: int) -> Vector3:
	var p := poste(j, k, n)
	p.y = 0
	var dehors := p.normalized() if p.length() > 0.2 else Vector3.BACK
	return p + dehors * 1.6


static func regard(j: String, k: int, n: int) -> Vector3:
	match j:
		"pont":
			return Vector3(0, 1.0, poste(j, k, n).z)
		"radeau":
			return Vector3(0, 1.0, 9.0)
		"incendie":
			# Tous tournés vers le hameau en feu : le milieu des foyers (cf. FOYERS dans decor_incendie.gd).
			return Vector3(0.6, 1.0, -5.0)
		"lanternes":
			return Vector3(0, 0.5, -6.0)
	return Vector3(0, 1.0, 0)


## Où se pose la ZONE du rôle unique (« Marcheur »…) dans la clairière k, en local : à GAUCHE de
## l'arrivée (on entre par le couloir qui vient de la fourche), mais jamais sur un poste, une
## arrivée, un établi, le couloir d'entrée ni la voie propre au jeu (`libre`). Le décor ne sait pas
## de quelle clairière il est : ce qu'il sème évite donc les trois emplacements (cf. `gene`).
static var _zones_roles := {}


static func zone_role(j: String, k: int, n: int) -> Vector3:
	var cle := "%s/%d/%d" % [j, k, n]
	if _zones_roles.has(cle):
		return _zones_roles[cle]
	var entre := Quetes.passage(k, Quetes.R_FOURCHE) - Quetes.zone(k)
	entre.y = 0
	var vers := -entre.normalized()
	var gauche := Vector3.UP.cross(vers)
	var base := atan2(gauche.x, gauche.z)
	var d := Decors.creer(j)
	d.jeu = j
	d.equipe = n
	d.zone = k
	var bout := Vector2(entre.x, entre.z).normalized() * 13.0
	var choix := Vector3.INF
	for r: float in [6.4, 7.6, 5.2, 9.0, 10.5]:
		for off: float in [0.0, 20.0, -20.0, 40.0, -40.0, 60.0, -60.0, 80.0, -80.0, 100.0, -100.0, 120.0, -120.0, 140.0, -140.0, 160.0, -160.0, 180.0]:
			var a := base + deg_to_rad(off)
			var p := Vector3(sin(a), 0, cos(a)) * r
			if d._zone_possible(p, bout):
				choix = p
				break
		if choix != Vector3.INF:
			break
	d.free()
	if choix == Vector3.INF:
		choix = gauche * 6.4
	_zones_roles[cle] = choix
	return choix


## Vrai si la zone du rôle peut se poser en p (local) : ni dans la voie du jeu, ni sur un joueur.
func _zone_possible(p: Vector3, bout: Vector2) -> bool:
	var marge := Quetes.RAYON_ROLE + 1.4
	if not libre(p):
		return false
	for i in 8:
		var t := TAU * i / 8.0
		if not libre(p + Vector3(sin(t), 0, cos(t)) * (Quetes.RAYON_ROLE + 0.8)):
			return false
	var h := Vector2(p.x, p.z)
	for k in equipe:
		var ici := poste(jeu, k, equipe)
		var a := arrivee(jeu, k, equipe)
		if _dist_segment(h, Vector2(ici.x, ici.z), Vector2(a.x, a.z)) < marge:
			return false
		var la := regard(jeu, k, equipe) - ici
		la.y = 0
		var t2 := ici + (la.normalized() if la.length() > 0.01 else Vector3.FORWARD) * 0.75
		if h.distance_to(Vector2(t2.x, t2.z)) < marge + 0.4:
			return false
	return _dist_segment(h, Vector2.ZERO, bout) >= Quetes.RAYON_ROLE + 1.5


## Vrai si (c, r) mord sur l'une des zones de rôle possibles (une par clairière).
func sur_zone_role(c: Vector2, r: float, marge := 0.5) -> bool:
	if Quetes.role_unique(jeu) == "":
		return false
	for z in Quetes.ANGLES_ZONES.size():
		var zr := zone_role(jeu, z, equipe)
		if c.distance_to(Vector2(zr.x, zr.z)) - r < Quetes.RAYON_ROLE + marge:
			return true
	return false


func construire() -> void:
	pass


## Ce que le décor occupe au-delà de la clairière (rectangles x/z dans son repère) : le cadre de
## la clairière (arbres, buissons, falaises de Ronde) s'en écarte le temps de la quête.
func degage() -> Array[Rect2]:
	return []


## Les objets à toucher : par défaut, des tablettes de bois gravées sur un établi devant mon poste.
func objet_bouton(b: Dictionary, k: int, total: int) -> Node3D:
	var n := Node3D.new()
	var t := _boite(Vector3(0.23, 0.05, 0.16), _mat("bois_clair", Color(0.46, 0.34, 0.22)))
	n.add_child(t)
	n.add_child(_grave(str(b.get("l", "")), 20, Vector3(0, 0.03, 0)))
	_poser_sur_etabli(n, k, total)
	return n


func animer(_vue: Dictionary, _phase: float, _delta: float) -> void:
	pass


# ---------------------------------------------------------------- les vies de l'équipe

var _vies_lanternes: Array = []       # les sphères-lanternes (dans `_vies_noeud`)
var _vies_max_vu := -1
var _vies_restantes_vue := -2
var _vies_noeud: Node3D


## Les vies de l'équipe : un cerceau suspendu devant moi, à 2,4 m de mon poste vers ce que je regarde, à
## hauteur d'yeux (au-dessus du regard posé sur l'établi) ; une lanterne allumée par vie restante
## (niveau dur : 3 ; le Coffre, le Chaudron et le Radeau y montrent aussi les leurs). Le marais des
## Lanternes a sa propre poutre : il ne s'en sert pas. Vue : `vies`, `vies_max`.
func afficher_vies(vue: Dictionary) -> void:
	var maxi := int(vue.get("vies_max", 0))
	if jeu == "lanternes" or maxi <= 0 or maxi > 12:
		maxi = 0
	if maxi != _vies_max_vu:
		_vies_max_vu = maxi
		_vies_restantes_vue = -2
		_vies_lanternes.clear()
		if _vies_noeud != null:
			_vies_noeud.queue_free()
			_vies_noeud = null
		if maxi > 0:
			var ici := poste(jeu, rang, equipe)
			var vers := regard(jeu, rang, equipe) - ici
			vers.y = 0
			vers = vers.normalized() if vers.length() > 0.01 else Vector3.FORWARD
			_vies_noeud = Node3D.new()
			# Loin devant et haut : un cercle de petites lanternes pendues, qu'on voit en levant les yeux,
			# jamais devant l'établi.
			_vies_noeud.position = ici + vers * 3.4 + Vector3(0, 2.75, 0)
			add_child(_vies_noeud)
			var bois := _mat("poteau", Color(0.14, 0.1, 0.07))
			var rayon_ := 0.2 + 0.045 * maxi
			var cerceau := anneau(rayon_, 0.01, bois, _vies_noeud)
			cerceau.position = Vector3(0, 0.0, 0)
			var chaine := _cylindre(0.004, 0.5, bois)
			chaine.position = Vector3(0, 0.25, 0)
			_vies_noeud.add_child(chaine)
			for i in maxi:
				var a_ := TAU * i / maxi
				var n := Node3D.new()
				n.position = Vector3(sin(a_), 0, cos(a_)) * rayon_
				var cordon := _cylindre(0.003, 0.12, bois)
				cordon.position = Vector3(0, -0.06, 0)
				n.add_child(cordon)
				modele("wooden_lantern_01", Vector3(0, -0.33, 0), 0.4, a_, n)
				var flamme := _sphere(0.02, _mat("vie_off", Color(0.16, 0.15, 0.15)))
				flamme.scale = Vector3(1, 1.7, 1)
				flamme.name = "cage"
				flamme.position = Vector3(0, -0.24, 0)
				n.add_child(flamme)
				var halo := _sphere(0.07, _mat_halo())
				halo.name = "halo"
				halo.position = flamme.position
				halo.visible = false
				n.add_child(halo)
				_vies_noeud.add_child(n)
				_vies_lanternes.append(n)
			var plaque := _debout("Vies de l'équipe", 30, Vector3(0, 0.5, 0))
			plaque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			plaque.autowrap_mode = TextServer.AUTOWRAP_OFF
			_vies_noeud.add_child(plaque)
	var restantes := int(vue.get("vies", 0))
	if maxi > 0 and restantes != _vies_restantes_vue:
		_vies_restantes_vue = restantes
		for i in _vies_lanternes.size():
			var ln := _vies_lanternes[i] as Node3D
			var allumee: bool = i < restantes
			(ln.get_node("cage") as MeshInstance3D).material_override = _mat("vie_on", Color(1.0, 0.85, 0.45), Color(1.0, 0.7, 0.25)) if allumee 				else _mat("vie_off", Color(0.16, 0.15, 0.15))
			(ln.get_node("halo") as MeshInstance3D).visible = allumee


## Le halo doux d'une flamme de vie : translucide, additif, sans ombre.
func _mat_halo() -> StandardMaterial3D:
	if not _mats.has("halo_vie"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(1.0, 0.66, 0.28, 0.09)
		_mats["halo_vie"] = m
	return _mats["halo_vie"]


func cible_tenir() -> Node3D:
	return null


## Un retour visuel quand j'appuie sur un objet (il s'enfonce, sonne…).
func touche(n: Node3D) -> void:
	var tw := create_tween()
	tw.tween_property(n, "position:y", n.position.y - 0.025, 0.06)
	tw.tween_property(n, "position:y", n.position.y, 0.12)


# ---------------------------------------------------------------- l'établi et les outils

func etabli() -> Node3D:
	if _etabli == null:
		_etabli = _meuble_de(rang)
		if _solides:
			solidifier(_etabli)
	return _etabli


## Les établis des autres joueurs : les mêmes que le mien, sans rien dessus. Tout le monde voit
## donc la même clairière, chacun derrière sa table.
func etablis_des_autres() -> void:
	if meuble == "":
		return
	for k in equipe:
		if k != rang:
			_meuble_de(k)


func _meuble_de(k: int) -> Node3D:
	var e := Node3D.new()
	var ici := poste(jeu, k, equipe)
	var vers := regard(jeu, k, equipe) - ici
	vers.y = 0
	var devant := vers.normalized() if vers.length() > 0.01 else Vector3.FORWARD
	e.position = ici + devant * 0.75
	e.position.y = 0.0
	e.basis = Basis.looking_at(devant, Vector3.UP)
	add_child(e)
	if meuble == "autel":
		# Une dalle de pierre posée sur deux blocs.
		var dalle := _boite(Vector3(1.55, 0.12, 0.62), matiere("roche", 0.7))
		dalle.position = Vector3(0, haut_etabli - 0.06, 0)
		e.add_child(dalle)
		for x: float in [-0.55, 0.55]:
			# Roche verdie : la matière « mousse » sort noire sur les faces verticales.
			var bloc := _boite(Vector3(0.34, haut_etabli - 0.12, 0.5), matiere("roche", 0.9, Color(0.72, 0.8, 0.66)))
			bloc.position = Vector3(x, (haut_etabli - 0.12) * 0.5, 0)
			e.add_child(bloc)
		morceau("moss_01", 0, Vector3(0.3, haut_etabli, -0.22), 1.6, 0.4, e)
	else:
		# Une vraie table de bois (Poly Haven), rehaussée à hauteur d'établi.
		var table := modele("WoodenTable_01", Vector3.ZERO, 1.0, 0.0, e)
		table.scale = Vector3(0.85, haut_etabli / 0.55, 0.85)
	return e


## Vrai si p (local de la clairière) laisse la place aux joueurs : loin de chaque poste, de son
## établi et de son point d'arrivée.
func loin_des_joueurs(p: Vector3, marge := 0.95) -> bool:
	var h := Vector2(p.x, p.z)
	if sur_zone_role(h, marge * 0.5):
		return false
	for k in equipe:
		var ici := poste(jeu, k, equipe)
		var la := regard(jeu, k, equipe) - ici
		la.y = 0
		var devant := la.normalized() if la.length() > 0.01 else Vector3.FORWARD
		for q: Vector3 in [ici, ici + devant * 0.4, arrivee(jeu, k, equipe), ici.lerp(arrivee(jeu, k, equipe), 0.5)]:
			if h.distance_to(Vector2(q.x, q.z)) < marge:
				return false
		if meuble != "":
			# L'établi : un rectangle de 1,55 × 0,56 m, plus un peu d'air autour.
			var d := p - (ici + devant * 0.75)
			var cote := devant.cross(Vector3.UP)
			if absf(d.dot(cote)) < 0.78 + 0.3 and absf(d.dot(devant)) < 0.28 + 0.3:
				return false
	return true


## Un accessoire posé au sol (caisse, seau, panier) : s'il gêne un joueur, on l'écarte vers
## l'extérieur ; s'il gêne encore, on ne le pose pas.
func accessoire(nom: String, pos: Vector3, echelle := 1.0, rot_y := 0.0, marge := 0.95) -> Node3D:
	var p := pos
	var dehors := Vector3(p.x, 0, p.z).normalized() if Vector2(p.x, p.z).length() > 0.1 else Vector3.BACK
	for essai in 4:
		if loin_des_joueurs(p, marge):
			return modele(nom, p, echelle, rot_y)
		p += dehors * 0.8
	return null


## Range le k-ième objet sur l'établi : rangées de six, de gauche à droite, face au joueur.
func _poser_sur_etabli(n: Node3D, k: int, total: int) -> void:
	var e := etabli()
	var par_rang := mini(total, 6)
	var rangee := k / 6
	var col := k % 6
	var dans := mini(total - rangee * 6, 6)
	var x := (col - (dans - 1) * 0.5) * 0.24 + 0.14
	n.position = Vector3(x, haut_etabli + 0.03, 0.1 - rangee * 0.19)
	if par_rang > 0:
		e.add_child(n)


func _grave(texte: String, taille: int, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.font = Style.police("titre")
	l.text = Langue.t(texte)
	l.font_size = taille
	l.pixel_size = 0.0022
	l.outline_size = 6
	l.modulate = Color(0.95, 0.88, 0.7)
	l.outline_modulate = Color(0.1, 0.06, 0.04)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.width = 120.0
	l.position = pos
	l.rotation.x = -PI / 2
	l.double_sided = false
	return l


func _mat(cle: String, c: Color, emission := Color.BLACK) -> StandardMaterial3D:
	var k := "%s/%s" % [cle, c.to_html()]
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		if emission != Color.BLACK:
			m.emission_enabled = true
			m.emission = emission
		_mats[k] = m
	return _mats[k]


func _boite(taille: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = m
	return mi


func _cylindre(r: float, h: float, m: Material, r_haut := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = r if r_haut < 0.0 else r_haut
	c.height = h
	mi.mesh = c
	mi.material_override = m
	return mi


func _sphere(r: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.material_override = m
	return mi


## Les jauges de la vue, par libellé (le texte exact dépend du jeu).
static func jauges(vue: Dictionary) -> Array:
	var r := []
	for b: Dictionary in vue.get("blocs", []):
		if b.get("t", "") == "jauge":
			r.append(b)
	return r


static func jauge(vue: Dictionary, morceau: String, defaut := -1.0) -> float:
	for b in jauges(vue):
		if str(b.get("l", "")).contains(morceau):
			return float(b.get("v", 0.0))
	return defaut


static func texte_contient(vue: Dictionary, morceau: String) -> bool:
	for b: Dictionary in vue.get("blocs", []):
		if b.get("t", "") == "texte" and str(b.get("v", "")).contains(morceau):
			return true
	return false


## Une gravure debout, face au joueur (sur une pierre, une planche dressée, une étiquette de pot).
func _debout(texte: String, taille: int, pos: Vector3, couleur := Color(0.95, 0.88, 0.7)) -> Label3D:
	var l := _grave(texte, taille, pos)
	l.rotation = Vector3.ZERO
	l.modulate = couleur
	return l


## La dernière annonce de l'hôte (texte rouge : fausse note, rocher heurté, pincée de trop…).
static func annonce(vue: Dictionary) -> String:
	for b: Dictionary in vue.get("blocs", []):
		if b.get("t", "") == "texte" and b.get("ton", "") == "rouge":
			return str(b.get("v", ""))
	return ""


static func bloc(vue: Dictionary, t: String) -> Dictionary:
	for b: Dictionary in vue.get("blocs", []):
		if b.get("t", "") == t:
			return b
	return {}


## Le premier texte d'une couleur donnée (souvent : ce que moi seul sais, en « or »).
static func texte_ton(vue: Dictionary, ton: String) -> String:
	for b: Dictionary in vue.get("blocs", []):
		if b.get("t", "") == "texte" and b.get("ton", "") == ton:
			return str(b.get("v", ""))
	return ""


## Ma main (cf. MondeQuete._gestes), pour l'animation seulement — l'hôte reçoit le vrai geste :
## tenu = je serre ce que le jeu me fait tenir ; main = son déplacement depuis que je l'ai saisi ;
## manivelle = l'angle de ma main sur son cercle (0 en haut), -1 si je ne tourne pas.
var tenu := false
var main := Vector2.ZERO
var manivelle := -1.0


## Ce qu'on saisit pour le geste du jeu (la corde, la planche, la manivelle) : par défaut, ce
## qu'on agrippe pour « tenir ».
func cible_geste() -> Node3D:
	return cible_tenir()


## Le geste d'un battement : "corde" (on tire, la main descend) ou "manivelle" (on tourne).
func geste_rythme() -> String:
	return "corde"


## Ce que je touche peut dépendre de ce que je vise (l'Incendie : le foyer où va le seau) : le décor complète
## l'action avant qu'elle parte chez l'hôte. Par défaut, rien à ajouter.
func affiner_action(a: Dictionary) -> Dictionary:
	return a


## Un objet à toucher qui se saisit puis se lance ("lancer"), ou "" (on le touche, c'est tout).
func geste_bouton(_a: Dictionary) -> String:
	return ""


## Jusqu'où je vise un objet à toucher, et la taille de sa prise (un objet au loin, sur le
## marais, se vise plus gros qu'une tablette sur mon établi).
func portee() -> float:
	return MondeQuete.PORTEE


func taille_visee() -> float:
	return 0.28


## L'objet saisi suit ma main (d = son déplacement depuis la prise).
func porter(_n: Node3D, _d: Vector2) -> void:
	pass


## Un coup donné (cloche tirée, manivelle passée en haut) : l'éclat qui va avec.
func frappe() -> void:
	pass


# ---------------------------------------------------------------- manipulations à la première personne
# (Grand Coffre, Chaudron : 01/11). Le décor lit lui-même ce que fait ma main : molette de la souris,
# clic tenu, glisser. Il envoie ses intentions à l'hôte par `monde.geste.emit(…)`.

## Une image : viser, saisir, tourner, tirer, verser. `monde` donne la caméra et le clic.
func manipuler(_monde: MondeQuete, _delta: float) -> void:
	pass


## La souris bouge pendant une manipulation en cours : vrai si le décor la prend (la tête ne tourne plus).
func absorbe_souris(_rel: Vector2) -> bool:
	return false


## La molette de la souris (+1 vers le haut, -1 vers le bas) : vrai si le décor l'a utilisée.
func molette(_sens: int) -> bool:
	return false


var _derniere_annonce := ""


## Vrai une seule fois par nouvelle annonce : c'est là qu'on secoue, qu'on fume, qu'on éclabousse.
func nouvelle_annonce(vue: Dictionary) -> bool:
	var a := annonce(vue)
	if a == _derniere_annonce:
		return false
	_derniere_annonce = a
	return a != ""


func secouer(n: Node3D, force := 0.06) -> void:
	var p := n.position
	var tw := create_tween()
	for k in 6:
		var s := force * (1.0 - k / 6.0)
		tw.tween_property(n, "position", p + Vector3(s * (1 if k % 2 == 0 else -1), 0, s * 0.5), 0.04)
	tw.tween_property(n, "position", p, 0.05)


func _lumiere(c: Color, energie: float, portee: float, pos: Vector3) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.light_color = c
	o.light_energy = energie
	o.omni_range = portee
	o.position = pos
	return o


## Un objet posé à côté de mon poste plutôt que sur l'établi (rame, corde, seau).
func a_cote(n: Node3D, decalage: Vector3) -> void:
	var ici := poste(jeu, rang, equipe)
	var vers := regard(jeu, rang, equipe) - ici
	vers.y = 0
	var devant := vers.normalized() if vers.length() > 0.01 else Vector3.FORWARD
	var droite := devant.cross(Vector3.UP)
	n.position = ici + droite * decalage.x + Vector3.UP * decalage.y + devant * decalage.z
	n.basis = Basis.looking_at(devant, Vector3.UP)
	add_child(n)


# ================================================================ la matière du décor
# Modèles CC0 Poly Haven (modeles/nature), textures du pack village et de Poly Haven, cordes qui
# pendent entre deux attaches, vrai feu en particules, clairière habillée. Rien ne flotte : tout
# ce qui est en l'air est tenu (corde, chaîne, poteau, potence).

const NATURE := "res://modeles/nature/%s/%s.gltf"
const VILLAGE_TEX := "res://modeles/village/T_%s_%s.png"
const TABLE_HAUT := 0.85            # dessus de l'établi (WoodenTable_01 rehaussée)

static var _scenes := {}
static var _morceaux := {}          # "nom/k" -> [Mesh, décalage pour poser le pied à y = 0]
static var _matieres := {}
static var _tache_tex: GradientTexture2D
var _feux: Array = []               # [OmniLight3D, énergie de base, graine]
var _t_base := 0.0


func _process(delta: float) -> void:
	_t_base += delta
	for f: Array in _feux:
		var l: OmniLight3D = f[0]
		if is_instance_valid(l):
			var g: float = f[2]
			l.light_energy = float(f[1]) * (0.82 + 0.12 * sin(_t_base * 13.0 + g) + 0.08 * sin(_t_base * 29.0 + g * 2.0))


func _scene(nom: String) -> PackedScene:
	if not _scenes.has(nom):
		_scenes[nom] = load(NATURE % [nom, nom])
	return _scenes[nom]


## Un modèle entier, pied au sol (Poly Haven pose ses modèles à l'origine).
func modele(nom: String, pos: Vector3, echelle := 1.0, rot_y := 0.0, parent: Node = null) -> Node3D:
	var n: Node3D = _scene(nom).instantiate()
	n.position = pos
	n.rotation.y = rot_y
	n.scale = Vector3.ONE * echelle
	(parent if parent else self).add_child(n)
	return n


## Un seul élément d'un lot (rocher, fougère, touffe d'herbe…), recentré pied au sol.
func morceau(nom: String, k: int, pos: Vector3, echelle := 1.0, rot_y := 0.0, parent: Node = null) -> Node3D:
	var cle := "%s/%d" % [nom, k]
	if not _morceaux.has(cle):
		var s := _scene(nom).instantiate()
		var ms := s.find_children("*", "MeshInstance3D", true, false)
		var mi: MeshInstance3D = ms[k % ms.size()]
		var b := mi.get_aabb()
		_morceaux[cle] = [mi.mesh, Vector3(-b.get_center().x, -b.position.y, -b.get_center().z)]
		s.free()
	var porte := Node3D.new()
	porte.position = pos
	porte.rotation.y = rot_y
	porte.scale = Vector3.ONE * echelle
	var m := MeshInstance3D.new()
	m.mesh = _morceaux[cle][0]
	m.position = _morceaux[cle][1]
	porte.add_child(m)
	(parent if parent else self).add_child(porte)
	return porte


static func nb_morceaux(nom: String) -> int:
	return {"rock_moss_set_01": 6, "rock_moss_set_02": 7, "fern_02": 4, "grass_medium_01": 17}.get(nom, 1)


## Une matière texturée : bois, pierre, brique, tuiles, metal, enduit (pack village) ; ecorce,
## boue, pave, herbe (Poly Haven). Motif en triplanaire : marche sur n'importe quelle forme.
func matiere(nom: String, rep := 1.0, teinte := Color.WHITE, emission := Color.BLACK) -> StandardMaterial3D:
	var cle := "%s/%.2f/%s/%s" % [nom, rep, teinte.to_html(), emission.to_html()]
	if _matieres.has(cle):
		return _matieres[cle]
	# « roche », « mousse », « vieux_bois » : la matière d'un modèle scanné, reposée en triplanaire.
	var scannes := {"roche": "boulder_01", "mousse": "rock_moss_set_01", "vieux_bois": "wooden_crate_01",
		"tronc": "dead_tree_trunk_02", "fer": "Lantern_01"}
	if scannes.has(nom):
		var s := _scene(scannes[nom]).instantiate()
		var mi: MeshInstance3D = s.find_children("*", "MeshInstance3D", true, false)[0]
		var src := mi.get_active_material(0) as StandardMaterial3D
		var d: StandardMaterial3D = src.duplicate() if src else StandardMaterial3D.new()
		s.free()
		d.uv1_triplanar = true
		d.uv1_scale = Vector3.ONE * rep
		d.albedo_color = teinte
		if emission != Color.BLACK:
			d.emission_enabled = true
			d.emission = emission
		_matieres[cle] = d
		return d
	var m := StandardMaterial3D.new()
	var village := {"bois": "WoodTrim", "pierre": "RockTrim", "brique": "UnevenBrick", "tuiles": "RoundTiles",
		"metal": "MetalOrnaments", "enduit": "Plaster"}
	var poly := {"ecorce": "bark_willow_02", "boue": "brown_mud_leaves_01", "pave": "cobblestone_floor_08", "herbe": "sparse_grass"}
	if village.has(nom):
		var v: String = village[nom]
		m.albedo_texture = load(VILLAGE_TEX % [v, "BaseColor"])
		if ResourceLoader.exists(VILLAGE_TEX % [v, "Normal"]):
			m.normal_enabled = true
			m.normal_texture = load(VILLAGE_TEX % [v, "Normal"])
		if ResourceLoader.exists(VILLAGE_TEX % [v, "Roughness"]):
			m.roughness_texture = load(VILLAGE_TEX % [v, "Roughness"])
	elif poly.has(nom):
		var p: String = poly[nom]
		m.albedo_texture = load("res://textures/%s_diff.jpg" % p)
		m.normal_enabled = true
		m.normal_texture = load("res://textures/%s_nor.jpg" % p)
		m.roughness_texture = load("res://textures/%s_rough.jpg" % p)
	m.albedo_color = teinte
	m.roughness = 1.0
	if nom == "metal":
		m.metallic = 0.75
		m.roughness = 0.55
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * rep
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
	_matieres[cle] = m
	return m


## Un tronc ou un poteau de bois brut entre deux points (base, sommet).
func poutre(a: Vector3, b: Vector3, r: float, m: Material = null, parent: Node = null) -> MeshInstance3D:
	var c := _cylindre(r, 1.0, m if m else matiere("ecorce", 1.5, Color(0.7, 0.62, 0.55)))
	_orienter(c, a, b)
	c.basis = c.basis * Basis.from_scale(Vector3(1, a.distance_to(b), 1))
	(parent if parent else self).add_child(c)
	return c


func _orienter(n: Node3D, a: Vector3, b: Vector3) -> void:
	var d := (b - a).normalized()
	var q := Quaternion(Vector3.UP, d) if d.dot(Vector3.UP) > -0.999 else Quaternion(Vector3.RIGHT, PI)
	n.basis = Basis(q)
	n.position = (a + b) * 0.5


## Une corde de chanvre qui pend entre deux attaches (mou = flèche au milieu, en mètres).
func corde(a: Vector3, b: Vector3, mou := 0.12, r := 0.014, parent: Node = null, m: Material = null) -> Node3D:
	var n := Node3D.new()
	(parent if parent else self).add_child(n)
	refaire_corde(n, a, b, mou, r, m)
	return n


func refaire_corde(n: Node3D, a: Vector3, b: Vector3, mou := 0.12, r := 0.014, m: Material = null) -> void:
	var mat: Material = m if m else matiere("chanvre", 1.0, Color(0.5, 0.42, 0.3))
	var seg := 8
	var pts: Array[Vector3] = []
	for i in seg + 1:
		var t := float(i) / seg
		pts.append(a.lerp(b, t) + Vector3.DOWN * mou * 4.0 * t * (1.0 - t))
	while n.get_child_count() < seg:
		n.add_child(_cylindre(r, 1.0, mat))
	for i in seg:
		var c: MeshInstance3D = n.get_child(i)
		c.material_override = mat
		var l := pts[i].distance_to(pts[i + 1])
		_orienter(c, pts[i], pts[i + 1])
		c.basis = c.basis * Basis.from_scale(Vector3(1, l + r, 1))


## Un vrai feu : flammes et fumée en particules, lumière qui vacille. `taille` 1 = feu de camp.
func feu(pos: Vector3, taille := 1.0, parent: Node = null, fumee := true) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	(parent if parent else self).add_child(n)
	n.add_child(_particules(int(46 * taille), 0.9, Vector3(0.18, 0.05, 0.18) * taille, Vector3(0, 0.9, 0) * taille,
		0.42 * taille, _degrade([Color(1.0, 0.9, 0.5, 0.0), Color(1.0, 0.75, 0.25, 0.9), Color(1.0, 0.35, 0.05, 0.7), Color(0.6, 0.1, 0.02, 0.0)]), true))
	if fumee:
		var f := _particules(int(18 * taille), 3.2, Vector3(0.2, 0.05, 0.2) * taille, Vector3(0, 0.7, 0) * taille,
			0.9 * taille, _degrade([Color(0.2, 0.2, 0.2, 0.0), Color(0.16, 0.16, 0.17, 0.35), Color(0.2, 0.2, 0.22, 0.0)]), false)
		f.position.y = 0.6 * taille
		n.add_child(f)
	var l := _lumiere(Color(1.0, 0.52, 0.18), 1.6 * taille, 5.0 * taille, Vector3(0, 0.5 * taille, 0))
	n.add_child(l)
	_feux.append([l, 1.6 * taille, randf() * 10.0])
	return n


static func _degrade(couleurs: Array) -> Gradient:
	var g := Gradient.new()
	var o := PackedFloat32Array()
	for i in couleurs.size():
		o.append(float(i) / (couleurs.size() - 1))
	g.offsets = o
	g.colors = PackedColorArray(couleurs)
	return g


static func _particules(nb: int, vie: float, boite: Vector3, vitesse: Vector3, taille: float, couleurs: Gradient, additif: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(nb, 4)
	p.lifetime = vie
	p.preprocess = vie
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = boite
	pm.direction = vitesse.normalized() if vitesse.length() > 0.0 else Vector3.UP
	pm.spread = 14.0
	pm.initial_velocity_min = vitesse.length() * 0.6
	pm.initial_velocity_max = vitesse.length() * 1.2
	pm.gravity = Vector3(0, 0.3, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.1
	var courbe := Curve.new()
	courbe.add_point(Vector2(0, 0.6))
	courbe.add_point(Vector2(0.35, 1.0))
	courbe.add_point(Vector2(1, 0.25 if additif else 1.0))
	var ct := CurveTexture.new()
	ct.curve = courbe
	pm.scale_curve = ct
	var gt := GradientTexture1D.new()
	gt.gradient = couleurs
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2.ONE * taille
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additif else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_texture = _tache()
	m.disable_receive_shadows = true
	# Une tache qui touche le sol ou un objet s'y fond : sans ça, chaque grande nappe de brume se
	# coupait en ligne droite sur la terre (le « voile » rectangulaire vu par Edwin, 30/10).
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = minf(taille * 0.6, 2.0)
	q.material = m
	p.draw_pass_1 = q
	return p


## Une tache ronde et douce (flamme, fumée, luciole, brume).
static func _tache() -> GradientTexture2D:
	if _tache_tex == null:
		_tache_tex = GradientTexture2D.new()
		_tache_tex.fill = GradientTexture2D.FILL_RADIAL
		_tache_tex.fill_from = Vector2(0.5, 0.5)
		_tache_tex.fill_to = Vector2(1.0, 0.5)
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		_tache_tex.gradient = g
		_tache_tex.width = 64
		_tache_tex.height = 64
	return _tache_tex


## Une lanterne pendue au bras d'un poteau planté dans le sol : poteau, bras, jambe de force,
## corde et lanterne se tiennent.
func poteau_lanterne(pos: Vector3, vers: Vector3, haut := 2.3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	var h := Vector3(vers.x, 0, vers.z)
	var d := h.normalized() if h.length() > 0.01 else Vector3.FORWARD
	poutre(Vector3(0, -0.15, 0), Vector3(0, haut, 0), 0.07, null, n)
	var bout := d * 0.65 + Vector3(0, haut - 0.12, 0)
	poutre(Vector3(0, haut - 0.12, 0) - d * 0.06, bout + d * 0.05, 0.04, null, n)
	poutre(Vector3(0, haut - 0.6, 0), d * 0.38 + Vector3(0, haut - 0.14, 0), 0.03, null, n)
	corde(bout, bout + Vector3(0, -0.28, 0), 0.0, 0.01, n)
	var lan := modele("wooden_lantern_01", bout + Vector3(0, -0.8, 0), 1.0, 0.0, n)
	var flamme := _sphere(0.035, matiere("flamme", 1.0, Color(1, 0.8, 0.4), Color(1.0, 0.7, 0.3)))
	flamme.position = Vector3(0, 0.22, 0)
	lan.add_child(flamme)
	var l := _lumiere(Color(1.0, 0.68, 0.35), 1.3, 6.0, bout + Vector3(0, -0.55, 0))
	n.add_child(l)
	_feux.append([l, 1.3, randf() * 10.0])
	return n


## Une bougie qui brûle (bougeoir de bois, flamme, petite lumière).
func bougie(pos: Vector3, parent: Node = null) -> Node3D:
	var b := modele("wooden_candlestick", pos, 1.0, randf() * TAU, parent)
	var flamme := _sphere(0.012, matiere("flamme", 1.0, Color(1, 0.85, 0.5), Color(1.0, 0.75, 0.35)))
	flamme.scale = Vector3(1, 2.2, 1)
	flamme.position = Vector3(0, 0.235, 0)
	b.add_child(flamme)
	var l := _lumiere(Color(1.0, 0.7, 0.4), 0.35, 1.6, Vector3(0, 0.3, 0))
	b.add_child(l)
	_feux.append([l, 0.35, randf() * 10.0])
	return b


## Vrai si un accessoire posé en p ne gêne pas le jeu (couloir du pont, rivière, chaîne…).
func libre(_p: Vector3) -> bool:
	return true


## La clairière autour du jeu : rochers moussus, souches, troncs couchés, fougères, herbes,
## racines, lanternes sur poteaux, lucioles et brume au ras du sol. Même tirage chez tous.
func habiller() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(jeu)
	etablis_des_autres()
	var avant := get_children()
	var postes: Array[Vector3] = []
	for k in equipe:
		postes.append(poste(jeu, k, equipe))
		postes.append(arrivee(jeu, k, equipe))
		var la := regard(jeu, k, equipe) - poste(jeu, k, equipe)
		la.y = 0
		postes.append(poste(jeu, k, equipe) + la.normalized() * 0.75)
	if Quetes.role_unique(jeu) != "":
		for z in Quetes.ANGLES_ZONES.size():
			postes.append(zone_role(jeu, z, equipe))
	for i in 9:
		var p := _place_libre(rng, postes, 6.0, 9.5, 2.7)
		if p != Vector3.INF:
			var lot := "rock_moss_set_01" if i % 2 == 0 else "rock_moss_set_02"
			morceau(lot, rng.randi() % nb_morceaux(lot), p + Vector3(0, -0.12, 0), rng.randf_range(0.6, 1.1), rng.randf() * TAU)
	var gros := ["tree_stump_01", "tree_stump_02", "dead_tree_trunk_02", "root_cluster_01"]
	var gros_y := [0.12, 0.15, 0.25, 0.0]
	var gros_e := [0.9, 0.8, 0.8, 0.6]
	for i in 4:
		# Un tronc couché fait 3,6 m : 2 m de marge laissaient son bout sur l'arrivée d'un joueur.
		var p := _place_libre(rng, postes, 5.5, 9.0, 2.7)
		if p != Vector3.INF:
			modele(gros[i], p + Vector3(0, gros_y[i], 0), gros_e[i], rng.randf() * TAU)
	for i in 16:
		var p := _place_libre(rng, postes, 4.0, 9.5, 1.2)
		if p != Vector3.INF:
			morceau("fern_02", rng.randi() % 4, p, rng.randf_range(0.6, 1.0), rng.randf() * TAU).add_to_group("traversable")
	for i in 34:
		var p := _place_libre(rng, postes, 3.2, 10.0, 0.9)
		if p != Vector3.INF:
			morceau("grass_medium_01", rng.randi() % 17, p, rng.randf_range(0.8, 1.4), rng.randf() * TAU).add_to_group("traversable")
	var petits := ["dry_branches_medium_01", "pine_roots", "nettle_plant"]
	for i in 5:
		var p := _place_libre(rng, postes, 4.0, 8.0, 1.5)
		if p != Vector3.INF:
			modele(petits[i % 3], p, rng.randf_range(0.8, 1.2), rng.randf() * TAU).add_to_group("traversable")
	for i in 2:
		var p := _place_libre(rng, postes, 4.2, 5.4, 1.6)
		if p != Vector3.INF:
			poteau_lanterne(p, -p)
	_degager_le_chemin(avant, rng)
	_lucioles()
	_brume()


## Le dernier mot sur la clairière semée : ce qui a atterri sur le chemin est remis en bordure
## (ou retiré s'il n'y a pas de place). Les tirages ne connaissent que le CENTRE d'un objet ; un
## tronc de 3,6 m ou un gros rocher dont le centre est hors du chemin pouvait en barrer un bout
## (testeur, 31/10 : « des décors en plein milieu du chemin », jeu du pont de planches).
## Le chemin, c'est : la place de chaque joueur et le pas qui y mène, les couloirs par où l'on
## arrive de la fourche (un par clairière, le décor ne sait pas laquelle il est), et la voie
## propre au jeu (`libre()` : planches, chaîne, eau, marais).
const AIR_JOUEUR := 1.0             # vide exigé entre le bord d'un objet et un joueur
const DEMI_COULOIR := 1.2           # demi-largeur du couloir d'arrivée, bord de l'objet compris


func _degager_le_chemin(avant: Array, rng: RandomNumberGenerator) -> void:
	var fixes: Array = []
	var semes: Array = []
	for c in get_children():
		if not (c is Node3D) or c is GPUParticles3D or c.is_in_group("traversable"):
			continue
		var e := _empreinte(c as Node3D)
		if e.is_empty():
			continue
		if avant.has(c):
			fixes.append(e)
		else:
			semes.append([c, e[0], e[1]])
	var gardes: Array = []
	for s in semes:
		var n: Node3D = s[0]
		var c: Vector2 = s[1]
		var r: float = s[2]
		if not gene(c, r):
			gardes.append([c, r])
			continue
		var ok := false
		for essai in 40:
			var a := rng.randf() * TAU
			var q := Vector2(sin(a), cos(a)) * rng.randf_range(5.5, 9.5)
			if gene(q, r):
				continue
			var libre_ici := true
			for o: Array in fixes + gardes:
				if q.distance_to(o[0]) < (r + o[1]) * 0.8:
					libre_ici = false
					break
			if libre_ici:
				n.position += Vector3(q.x - c.x, 0, q.y - c.y)
				gardes.append([q, r])
				ok = true
				break
		if not ok:
			# free() et non queue_free() : solidifier() passe tout de suite après et fabriquerait
			# une boîte de collision fantôme pour un objet « supprimé » mais encore dans l'arbre.
			n.free()


## Vrai si un objet rond (centre c, rayon r, local de la clairière) barre le chemin.
func gene(c: Vector2, r: float) -> bool:
	for k in equipe:
		var p := poste(jeu, k, equipe)
		var a := arrivee(jeu, k, equipe)
		if _dist_segment(c, Vector2(p.x, p.z), Vector2(a.x, a.z)) - r < AIR_JOUEUR:
			return true
		if meuble != "":
			# L'établi, devant le joueur : 1,55 m de large, plus un peu d'air.
			var la := regard(jeu, k, equipe) - p
			la.y = 0
			var t := p + (la.normalized() if la.length() > 0.01 else Vector3.FORWARD) * 0.75
			if c.distance_to(Vector2(t.x, t.z)) - r < 0.9:
				return true
	if sur_zone_role(c, r):
		return true
	for z in Quetes.ANGLES_ZONES.size():
		var v := Quetes.passage(z, Quetes.R_FOURCHE) - Quetes.zone(z)
		var bout := Vector2(v.x, v.z).normalized() * 13.0
		if _dist_segment(c, Vector2.ZERO, bout) - r < DEMI_COULOIR:
			return true
	if not libre(Vector3(c.x, 0, c.y)):
		return true
	for i in 8:
		var t := TAU * i / 8.0
		if not libre(Vector3(c.x + sin(t) * r * 0.8, 0, c.y + cos(t) * r * 0.8)):
			return true
	return false


static func _dist_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 0.0001 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Où un objet se tient vraiment au sol : [centre x/z local, rayon], ou [] s'il n'a rien à voir.
func _empreinte(n: Node3D) -> Array:
	var u := AABB()
	var premier := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.get_parent() is GPUParticles3D:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		u = b if premier else u.merge(b)
		premier = false
	if premier:
		return []
	var c := to_local(u.get_center())
	return [Vector2(c.x, c.z), maxf(u.size.x, u.size.z) * 0.5]


func _place_libre(rng: RandomNumberGenerator, postes: Array[Vector3], r0: float, r1: float, marge: float) -> Vector3:
	for essai in 12:
		var a := rng.randf() * TAU
		var p := Vector3(sin(a), 0, cos(a)) * rng.randf_range(r0, r1)
		if not libre(p):
			continue
		var loin := true
		for q in postes:
			if Vector2(p.x - q.x, p.z - q.z).length() < marge:
				loin = false
		if loin:
			return p
	return Vector3.INF


func _lucioles() -> void:
	var p := _particules(40, 6.0, Vector3(8, 1.2, 8), Vector3(0, 0.05, 0), 0.05,
		_degrade([Color(1.0, 0.9, 0.4, 0.0), Color(1.0, 0.85, 0.35, 1.0), Color(1.0, 0.8, 0.3, 0.0)]), true)
	var pm := p.process_material as ParticleProcessMaterial
	pm.spread = 180.0
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	p.position.y = 1.4
	add_child(p)


func _brume() -> void:
	var p := _particules(26, 14.0, Vector3(9, 0.15, 9), Vector3(0.12, 0, 0.05), 3.4,
		_degrade([Color(0.7, 0.72, 0.75, 0.0), Color(0.62, 0.65, 0.7, 0.12), Color(0.6, 0.62, 0.68, 0.0)]), false)
	(p.process_material as ParticleProcessMaterial).gravity = Vector3.ZERO
	p.position.y = 0.3
	add_child(p)



## Une eau sombre qui file (rivière, marais) : reflets, petites vagues qui avancent, écume.
## `courant` : vitesse en m/s le long de z (0 = eau dormante).
func eau(taille: Vector2, pos: Vector3, courant := 0.0, teinte := Color(0.04, 0.08, 0.09)) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = taille
	p.subdivide_width = 24
	p.subdivide_depth = 24
	m.mesh = p
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 teinte : source_color = vec3(0.04, 0.08, 0.09);
uniform float courant = 0.0;
uniform sampler2D bruit : filter_linear_mipmap, repeat_enable;
varying vec3 monde;
void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += 0.025 * sin(monde.x * 2.1 + TIME * 1.3) * sin(monde.z * 1.7 - TIME * (1.0 + courant));
}
void fragment() {
	vec2 uv = monde.xz * 0.18 + vec2(0.0, -TIME * courant * 0.18);
	vec2 uv2 = monde.xz * 0.41 + vec2(TIME * 0.02, -TIME * courant * 0.35);
	float n = texture(bruit, uv).r * 0.6 + texture(bruit, uv2).r * 0.4;
	vec3 nm = normalize(vec3((n - 0.5) * 0.9, 1.0, (texture(bruit, uv2 + 0.13).r - 0.5) * 0.9));
	NORMAL = normalize((VIEW_MATRIX * vec4(nm, 0.0)).xyz);
	float ecume = smoothstep(0.72, 0.9, n) * clamp(courant, 0.0, 1.0);
	ALBEDO = mix(teinte, vec3(0.55, 0.6, 0.62), ecume * 0.6);
	ROUGHNESS = 0.08 + ecume * 0.5;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	// Les bords se perdent dans la berge, en dents irrégulières : plus de rectangle net.
	float bord = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	ALPHA = smoothstep(0.0, 0.07, bord - (n - 0.5) * 0.05);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("teinte", teinte)
	mat.set_shader_parameter("courant", courant)
	var bruit := NoiseTexture2D.new()
	bruit.seamless = true
	bruit.width = 256
	bruit.height = 256
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	bruit.noise = fn
	mat.set_shader_parameter("bruit", bruit)
	m.material_override = mat
	m.position = pos
	add_child(m)
	return m


## Une cloche de bronze (corps évasé, lèvre, battant) ; pivot en haut, à l'anse.
func cloche_bronze(r: float, parent: Node) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var bronze := matiere("metal", 2.0, Color(0.72, 0.52, 0.26))
	var corps := _cylindre(r, r * 1.4, bronze, r * 0.52)
	corps.position.y = -r * 0.85
	(corps.mesh as CylinderMesh).cap_bottom = false
	bronze.cull_mode = BaseMaterial3D.CULL_DISABLED
	n.add_child(corps)
	var calotte := _sphere(r * 0.53, bronze)
	calotte.scale = Vector3(1, 0.5, 1)
	calotte.position.y = -r * 0.15
	n.add_child(calotte)
	var levre := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = r * 0.92
	t.outer_radius = r * 1.08
	levre.mesh = t
	levre.material_override = bronze
	levre.position.y = -r * 1.55
	n.add_child(levre)
	var battant := _sphere(r * 0.16, matiere("metal", 2.0, Color(0.25, 0.24, 0.24)))
	battant.position.y = -r * 1.35
	n.add_child(battant)
	poutre(Vector3(0, -r * 0.2, 0), Vector3(0, -r * 1.3, 0), r * 0.04, matiere("metal", 2.0, Color(0.25, 0.24, 0.24)), n)
	return n


## Un anneau (lèvre de chaudron, cerclage, anse).
func anneau(r: float, epaisseur: float, m: Material, parent: Node) -> MeshInstance3D:
	var a := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = r - epaisseur
	t.outer_radius = r + epaisseur
	a.mesh = t
	a.material_override = m
	parent.add_child(a)
	return a


# ---------------------------------------------------------------- les collisions

## Tout ce qui se voit dans le décor arrête le joueur : une boîte par maillage, orientée comme
## lui. Ne sont pas solides : les particules, les textes, ce qui est fin comme une corde, et ce
## qui est rangé dans les groupes « traversable » (herbes, fougères) ou « mobile » (ce qui bouge :
## meule, cloches, plateaux, la Dame).
var _solides: StaticBody3D


func solidifier(racine: Node = null) -> void:
	if _solides == null:
		_solides = StaticBody3D.new()
		_solides.name = "solides"
		_solides.collision_layer = 1
		_solides.collision_mask = 0
		add_child(_solides)
	for mi: MeshInstance3D in (racine if racine else self).find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or _hors_solide(mi):
			continue
		var b := mi.get_aabb()
		var t := _dans_decor(mi) * Transform3D(Basis.IDENTITY, b.get_center())
		var taille := b.size * t.basis.get_scale()
		var dims := [taille.x, taille.y, taille.z]
		dims.sort()
		if dims[1] < 0.05 or dims[2] < 0.12:
			continue
		# Les formes de collision n'aiment pas l'échelle : on la reporte sur la taille de la boîte.
		var forme := CollisionShape3D.new()
		var boite := BoxShape3D.new()
		boite.size = taille.abs()
		forme.shape = boite
		forme.transform = Transform3D(t.basis.orthonormalized(), t.origin)
		forme.set_meta("de", _nom_de(mi))
		_solides.add_child(forme)


func _hors_solide(n: Node) -> bool:
	var x := n
	while x and x != self:
		if x.is_in_group("traversable") or x.is_in_group("mobile") or x is GPUParticles3D or x == _solides:
			return true
		x = x.get_parent()
	return false


## La transformation d'un nœud dans le repère du décor (sans passer par l'arbre de scène).
func _dans_decor(n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var x: Node = n
	while x and x != self:
		if x is Node3D:
			t = (x as Node3D).transform * t
		x = x.get_parent()
	return t


## D'où vient un maillage (nom du modèle, ou type de forme) : pour les messages des tests.
func _nom_de(mi: MeshInstance3D) -> String:
	var x: Node = mi
	while x and x != self:
		if not str(x.name).begins_with("@") and x != mi:
			return str(x.name)
		x = x.get_parent()
	return mi.mesh.get_class().replace("Mesh", "")
