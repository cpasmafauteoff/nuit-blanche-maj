class_name Tutoriel
extends Node
## La nuit guidée du premier lancement (décision d'Edwin, 31/10) : une VRAIE partie hors ligne, six
## villageois dont cinq bots, dans le vrai village et avec les vrais systèmes. Ce « meneur de tutoriel »
## ne simule rien : il fige les minuteries, dit au joueur quoi faire (un bandeau de texte en bas, un
## repère lumineux dans le monde), attend qu'il le fasse, puis pousse le meneur à l'étape suivante.
## L'ordre et les conditions des étapes vivent dans regles/tutoriel_etapes.gd (testées sans fenêtre).
##
## Le joueur peut passer une étape (sa touche « passer », réglée) et quitter (Échap, la pause). Rien
## n'est gagné ici : la partie ne va jamais jusqu'à son écran de fin, donc ni expérience ni succès.

const OR := Color(0.93, 0.78, 0.45)
const LUEUR := Color(1.0, 0.72, 0.3)
## Les bots qui partent en quête avec le joueur : quatre en tout, de quoi jouer à plusieurs.
const BOTS_EN_QUETE := 3
const NIVEAU_QUETE := "simple"
const JEUX := ["moulin", "puits", "cloches"]

var p: Node                       # la scène principale (principal.gd)
var m: Meneur
var etape := ""                   # "" tant que la partie n'a pas commencé
var c := TutoEtapes.constat_vide()
## Les essais automatiques n'écrivent rien dans les réglages du vrai joueur.
var sans_memoire := false
var termine := false

var _lance := false
var _calque: CanvasLayer
var _cadre: PanelContainer
var _titre: Label
var _texte: RichTextLabel
var _aide: Label
var _texte_affiche := ""
var _en_haut := false
var _repere: Node3D
var _repere_pos := Vector3.INF
var _flamme: MeshInstance3D
var _lumiere: OmniLight3D
var _t := 0.0
var _pos_av := Vector3.INF
var _yaw_av := 0.0
var _portee_av := 1


func _ready() -> void:
	m = p.meneur
	# Six villageois, un seul loup (le joueur, cette nuit), un tour des loups large : on apprend, on ne se presse pas.
	m.avec_bots = true
	m.nb_places = 6
	m.nb_loups = 1
	m.loups_regles = true
	m.durees["loups"] = 150.0
	m.tour_libre = true
	_portee_av = p._ma_portee
	_construire_banniere()


# ================================================================ boucle

func _process(delta: float) -> void:
	if termine:
		return
	_t += delta
	var en_jeu: bool = p.etape == "jeu"
	# Le bandeau s'efface pendant une lecture (le tableau ouvert) : il ne doit rien couvrir.
	_calque.visible = en_jeu and etape != "" and p._cine_t < 0.0 and not p.ecran.panneau_ouvert()
	if not en_jeu:
		return
	if etape == "":
		_attendre_la_partie()
		return
	# Tout est figé, sauf pendant la quête, qui se joue pour de vrai (son minuteur fait finir le jeu).
	m.test_fige = m.phase != "quete"
	_observer(delta)
	if TutoEtapes.remplie(etape, c):
		_suivante(false)
		if termine:
			return
	_animer_repere(delta)
	_maj_banniere()


## Le salon n'existe pas ici : on lance la partie dès qu'on y est, et on abrège la scène d'attente.
func _attendre_la_partie() -> void:
	if m.phase == "salon":
		if m.synchro == null and not _lance and m.humains.has(m.moi()):
			_lance = true
			m.lancer_partie()
		if m.synchro != null:
			m.synchro.ecoule = maxf(m.synchro.ecoule, SynchroLancement.MIN_S)
		return
	if m.partie == null:
		return
	_commencer()


func _commencer() -> void:
	# Le joueur sera le loup de cette nuit.
	m.partie.loups_preferes.assign([m.moi()])
	_poser_les_quetes()
	_ecarter_les_cailloux()
	p._carnet.tape.connect(func():
		if etape == "carnet_ecrire":
			c["carnet_ecrit"] = true)
	_pos_av = p.corps_joueur.global_position
	_entrer_etape(TutoEtapes.premiere())


## Pas de cailloux au sol : « E » ramasserait un caillou à la place de s'asseoir ou de prendre le carnet.
func _ecarter_les_cailloux() -> void:
	if m.objets == null:
		return
	for id: int in m.objets.cailloux_au_sol():
		m.objets.liste.erase(id)
	m._cailloux_t = 1.0e9
	m._envoyer_objets()


## Trois quêtes simples, dont le Moulin (la plus courte) en première : ni rôle ni titre à gagner (le
## joueur doit pouvoir être tiré loup), seulement un indice.
func _poser_les_quetes() -> void:
	m._quetes.clear()
	m._recents.clear()
	for k in JEUX.size():
		m._recents.append(JEUX[k])
		m._quetes.append({"jeu": JEUX[k], "niveau": NIVEAU_QUETE, "recompense": "indice", "inscrits": [],
			"etat": "inscription", "zone": k, "mj": null, "t": 0.0, "reussie": false})
	m._envoyer_pub(m._etat_pub())


# ================================================================ ce que fait le joueur

func _observer(delta: float) -> void:
	var corps: CharacterBody3D = p.corps_joueur
	var pos := corps.global_position
	var libre: bool = p.mode == "libre"
	var dist := 0.0
	if _pos_av != Vector3.INF and libre:
		dist = Vector2(pos.x - _pos_av.x, pos.z - _pos_av.z).length()
		if dist > 1.0:
			dist = 0.0      # une téléportation n'est pas un pas
	_pos_av = pos
	var yaw: float = corps.rotation.y + p.tete.rotation.y
	var dyaw := wrapf(yaw - _yaw_av, -PI, PI)
	if absf(dyaw) > 1.5:
		dyaw = 0.0
	_yaw_av = yaw
	var vitesse := Vector2(corps.velocity.x, corps.velocity.z).length()
	TutoEtapes.cumuler(c, delta, {
		"dist": dist, "dyaw": dyaw,
		"sprint": libre and Options.appuye("sprint") and vitesse > 4.0,
		"accroupi": bool(p._accroupi),
		"parle": Voix.detecte(),
		"ferme": Capteur.ouverture_yeux() < TutoEtapes.OUVERTURE_FERMES,
	})
	if etape == "yeux":
		# Debout dans sa chambre, Espace est le saut : le temps de cette étape, il ferme les yeux.
		Capteur.espace_ferme_yeux = true
	if p._ma_portee != _portee_av:
		_portee_av = p._ma_portee
		c["portee"] = int(c["portee"]) + 1
	var phase: String = p._phase()
	var moi: int = m.moi()
	c["phase"] = phase
	c["assis"] = bool(p._assis_libre)
	c["vote_quete"] = int(p._mon_vote_quete) >= 0
	if etape == "tableau" and p.ecran.panneau_ouvert() and phase == "tableau":
		c["tableau_lu"] = true
	c["quete"] = str(p._ma_quete().get("etat", ""))
	c["carnet_main"] = p._vue_objets != null and p._vue_objets.en_main() >= 0 			and str(p._vue_objets.objet(p._vue_objets.en_main()).get("sorte", "")) == "carnet"
	c["carnet_ouvert"] = p._carnet.visible
	c["pret"] = m._prets.has(moi)
	c["vote_cible"] = int(p._vote_cible)
	var ma: int = p._ma_maison()
	c["rentre"] = Meneur.est_rentre(pos, ma)
	var appel: String = str(m.pub.get("appel", ""))
	c["dehors"] = phase == "nuit" and appel == "loups" and Ronde.maison_de(pos) < 0
	c["sortie_ouverte"] = p._sortie != null
	c["coups"] = (p._sortie_coups as Array).size()
	c["vote_loup"] = (p._priv("votes_loups", {}) as Dictionary).has(moi)
	if p._cine_t >= 0.0:
		c["cine_vue"] = true
	elif bool(c.get("cine_vue", false)):
		c["cine_finie"] = true


# ================================================================ les étapes

func passer() -> void:
	if etape == "" or termine:
		return
	_suivante(true)


func _suivante(saute: bool) -> void:
	var fini := etape
	_sortir_etape(fini, saute)
	var suite := TutoEtapes.suivante(fini)
	if suite == "":
		_terminer()
		return
	_entrer_etape(suite)


func _entrer_etape(e: String) -> void:
	etape = e
	TutoEtapes.nouvelle_etape(c)
	_portee_av = p._ma_portee
	var ma: int = p._ma_maison()
	var dz := Ronde.PROFONDEUR * 0.5
	match e:
		"souche":
			_placer_repere(Ronde.souche(ma))
		"tableau":
			_placer_repere(Ronde.TABLEAU)
		"carnet_prendre":
			_placer_repere(Ronde.table_carnet(ma))
		"porte_arriere":
			_placer_repere(Ronde._vers_monde(ma, Vector3(0, 0, -dz + 0.7)))
		"coups":
			_placer_repere(Vector3.INF)
		"voter_porte":
			var cible := _maison_proie()
			_placer_repere(Ronde.devant_porte(cible, "arriere") if cible >= 0 else Vector3.INF)
		_:
			_placer_repere(Vector3.INF)
	_texte_affiche = ""   # le bandeau se réécrit (et s'estompe) à la prochaine image
	_maj_banniere()


## Ce qu'il faut faire avancer dans le jeu quand l'étape se termine (réussie ou passée).
func _sortir_etape(e: String, saute: bool) -> void:
	match e:
		"vote_quete":
			_lancer_la_quete()
		"pret":
			m._entrer("election")
		"maire_intro":
			m._entrer("vote_maire")
			_bots_muets()
		"maire_vote":
			_voter_avec_le_village()
			m._entrer("elu")
		"maire_elu":
			m._entrer("conseil")
		"conseil":
			m._entrer("vote")
			_bots_muets()
		"vote":
			_voter_avec_le_village()
			m.passer_etape()          # → le dépouillement
		"depouillement":
			m.passer_etape()          # → le verdict
		"verdict":
			m.test_etape("nuit")      # → la tombée de la nuit : les loups sont tirés, chacun rentre
		"yeux":
			m.passer_etape()          # → la nuit, l'appel « coucher »
		"coucher":
			m.passer_etape()          # → l'appel des loups
		"porte_arriere", "coups":
			if saute and not bool(c.get("dehors", false)):
				_forcer_la_sortie()
		"voter_porte":
			if saute:
				_forcer_le_vote_de_la_meute()
		"cine":
			if saute and p._cine_t >= 0.0:
				p._cine_t = Cinematique.DUREE   # la cinématique s'achève d'elle-même à l'image suivante


## Le joueur vote pour qui il veut ; les bots, d'un même élan, pour le même (pour que le résultat soit clair).
func _voter_avec_le_village() -> void:
	var cible: int = p._vote_cible
	if cible < 0 or not m.partie.vivant(cible):
		cible = _premier_bot()
		p._vote_cible = cible
	m.traiter(m.moi(), "voter", cible)
	for b in m._bots:
		if b != cible:
			m.traiter(b, "voter", cible)


func _premier_bot() -> int:
	var l: Array = m._bots.keys()
	l.sort()
	for b: int in l:
		if m.partie.vivant(b):
			return b
	return -1


## Les bots ne votent pas de leur propre chef : ils suivent le joueur (cf. `_voter_avec_le_village`).
func _bots_muets() -> void:
	for b in m._bots:
		m._bots[b]["vote_t"] = 99999.0


## Le vote du matin : le joueur et trois bots partent faire la première quête, les autres restent.
func _lancer_la_quete() -> void:
	var bots: Array = m._bots.keys()
	bots.sort()
	var partants: Array = [m.moi()] + bots.slice(0, BOTS_EN_QUETE)
	for id in m.sieges:
		m._votes_quete[id] = 0 if partants.has(id) else Quetes.RESTER
	p._mon_vote_quete = 0
	m._resoudre_vote_quete()


## Le joueur a passé sa porte sans la frapper : on le fait sortir, sans bruit.
func _forcer_la_sortie() -> void:
	if p._phase() != "nuit" or str(m.pub.get("appel", "")) != "loups":
		return
	var ma: int = p._ma_maison()
	p._fermer_sortie()
	m.traiter(m.moi(), "sortir", 3)
	p._appliquer_placement(Ronde.devant_porte(ma, "arriere"), Vector3.ZERO, "libre")


func _forcer_le_vote_de_la_meute() -> void:
	if m.phase != "nuit" or m._appel != "loups" or m._vote_loups_fait:
		return
	var cible := _maison_proie()
	if cible < 0:
		return
	m._votes_loups[m.moi()] = cible
	m._resoudre_t = 1.0
	m._envoyer_prives()


## La maison la plus proche de ma porte où dort un villageois vivant, libre, que la meute peut choisir.
func _maison_proie() -> int:
	var ma: int = p._ma_maison()
	var meilleure := -1
	var d_min := INF
	for i in Ronde.NB_MAISONS:
		if i == ma:
			continue
		var h: int = m._habitant(i)
		if h < 0 or not m.partie.vivant(h) or h == m._attache or m.partie.est_loup(h):
			continue
		var d := Ronde.devant_porte(i, "arriere").distance_to(Ronde.devant_porte(ma, "arriere"))
		if d < d_min:
			d_min = d
			meilleure = i
	return meilleure


## Fin de la nuit guidée : on l'écrit dans les réglages, et on rentre au menu.
func _terminer() -> void:
	termine = true
	_placer_repere(Vector3.INF)
	if not sans_memoire:
		p._memoriser_tutoriel("fait")
	p._retour_menu("")


# ================================================================ le repère dans le monde

## Une lanterne posée au sol, une flamme qui flotte au-dessus et une colonne de lumière douce : on la voit
## de loin, sans flèche d'interface.
func _placer_repere(pos: Vector3) -> void:
	_repere_pos = pos
	if pos == Vector3.INF:
		if _repere != null:
			_repere.visible = false
		return
	if _repere == null:
		_repere = _fabriquer_repere()
		p.add_child(_repere)
	_repere.visible = true
	_repere.global_position = Vector3(pos.x, Ronde.hauteur_sol(pos), pos.z)


func _fabriquer_repere() -> Node3D:
	var n := Node3D.new()
	var corps := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.1
	cyl.bottom_radius = 0.13
	cyl.height = 0.3
	corps.mesh = cyl
	corps.material_override = Bouille.materiau(Color(0.1, 0.07, 0.05), 0.0, Color(0.9, 0.5, 0.15))
	corps.position.y = 0.15
	n.add_child(corps)
	_flamme = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.11
	s.height = 0.26
	_flamme.mesh = s
	var mf := StandardMaterial3D.new()
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mf.albedo_color = Color(1.0, 0.85, 0.5)
	_flamme.material_override = mf
	_flamme.position.y = 0.95
	n.add_child(_flamme)
	var colonne := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.02
	cc.bottom_radius = 0.3
	cc.height = 7.0
	cc.cap_top = false
	cc.cap_bottom = false
	colonne.mesh = cc
	var mc := StandardMaterial3D.new()
	mc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mc.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mc.cull_mode = BaseMaterial3D.CULL_DISABLED
	mc.albedo_color = Color(LUEUR, 0.12)
	colonne.material_override = mc
	colonne.position.y = 3.5
	colonne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(colonne)
	_lumiere = OmniLight3D.new()
	_lumiere.light_color = LUEUR
	_lumiere.omni_range = 5.5
	_lumiere.light_energy = 2.2
	_lumiere.position.y = 1.0
	n.add_child(_lumiere)
	return n


func _animer_repere(_delta: float) -> void:
	if _repere == null or not _repere.visible:
		return
	_flamme.position.y = 0.95 + sin(_t * 2.2) * 0.06
	_lumiere.light_energy = 2.0 + sin(_t * 9.0) * 0.25 + sin(_t * 5.3) * 0.2


# ================================================================ le bandeau du narrateur

func _construire_banniere() -> void:
	_calque = CanvasLayer.new()
	_calque.layer = 6
	_calque.visible = false
	add_child(_calque)
	var racine := Control.new()
	racine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_calque.add_child(racine)
	_cadre = PanelContainer.new()
	_cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.03, 0.035, 0.9)
	style.border_color = Color(0.72, 0.55, 0.3, 0.7)
	style.set_border_width_all(1)
	style.border_width_top = 3
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size = 22
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_cadre.add_theme_stylebox_override("panel", style)
	_cadre.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_cadre.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cadre.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cadre.offset_bottom = -70
	racine.add_child(_cadre)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cadre.add_child(v)
	_titre = Label.new()
	_titre.add_theme_font_override("font", Style.police("titre"))
	_titre.add_theme_font_size_override("font_size", 19)
	_titre.add_theme_color_override("font_color", Color(OR, 0.85))
	_titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_titre)
	_texte = RichTextLabel.new()
	_texte.bbcode_enabled = true
	_texte.fit_content = true
	_texte.scroll_active = false
	_texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texte.add_theme_font_override("normal_font", Style.police("texte"))
	_texte.add_theme_font_size_override("normal_font_size", 28)
	_texte.add_theme_color_override("default_color", Color(0.97, 0.93, 0.86))
	_texte.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_texte.add_theme_constant_override("outline_size", 4)
	v.add_child(_texte)
	_aide = Label.new()
	_aide.add_theme_font_override("font", Style.police("italique"))
	_aide.add_theme_font_size_override("font_size", 18)
	_aide.add_theme_color_override("font_color", Color(0.9, 0.84, 0.74, 0.7))
	_aide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_aide)


func _maj_banniere() -> void:
	if etape == "" or not is_inside_tree():
		return
	# Le bas est pris par la fiche d'une quête et par la barre des trois coups : le bandeau monte alors sous le titre.
	var haut: bool = p._phase() == "quete" or p._sortie != null
	if haut != _en_haut:
		_en_haut = haut
		if haut:
			_cadre.set_anchors_preset(Control.PRESET_CENTER_TOP)
			_cadre.grow_vertical = Control.GROW_DIRECTION_END
			_cadre.offset_top = 112
			_cadre.offset_bottom = 112
		else:
			_cadre.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			_cadre.grow_vertical = Control.GROW_DIRECTION_BEGIN
			_cadre.offset_top = 0
	# Le carnet ouvert occupe le milieu : le bandeau se colle au bord du bas pour ne pas le couvrir.
	if not _en_haut:
		_cadre.offset_bottom = -12 if p._carnet.visible else -70
	var largeur := clampf(get_viewport().get_visible_rect().size.x * 0.6, 520.0, 1000.0)
	_texte.custom_minimum_size.x = largeur
	var gabarit: String = TutoEtapes.etape(etape)["texte"]
	if gabarit != _texte_affiche:
		_texte_affiche = gabarit
		_titre.text = TutoEtapes.titre_chapitre(etape)
		# Les touches du joueur ressortent en or, comme dans « Comment jouer ».
		var re := RegEx.create_from_string("\\{(\\w+)\\}")
		_texte.text = Options.avec_touches(re.sub(Langue.t(gabarit), "[color=#ffd180]{$1}[/color]", true))
		_cadre.modulate.a = 0.0
		create_tween().tween_property(_cadre, "modulate:a", 1.0, 0.45)
	_aide.text = Options.avec_touches("{passer} : passer cette étape   ·   Échap : quitter")
