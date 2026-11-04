extends MiniJeu
## Le Pont de planches : un seul traverse à la fois, À PIED, planche par planche (l'hôte lit ses pieds, comme
## pour le marcheur du marais), au-dessus d'une gorge sans fond. TOUS les autres, de part et d'autre du
## tablier, tiennent leur corde pour caler les planches. Si un tenant lâche pendant la traversée, la planche
## bascule et le marcheur tombe : il retentera à la fin de la file s'il lui reste une chance.
## Ce qui peut arriver au marcheur : une PLANCHE POURRIE qui cède (les tenants la voient marquée en rouge,
## lui non : ils la lui nomment à la voix, « saute la 12 »), une RAFALE qui secoue le pont (les tenants la
## voient se lever, lui non : il doit s'arrêter net), un pas dans le vide.
## Longueur du pont : cf. Passerelle.nb_planches (c'est elle qui donne sa durée au jeu).
## Sabotage : lâcher (n'importe qui peut glisser ; un loup le fait exprès) ou mentir sur les planches. L'écran
## des autres dit seulement « Une planche a lâché ! », jamais qui.
## Réussite individuelle : avoir traversé.

const DELAI_LACHE := 0.25    # un doigt qui lâche et reprend dans ce délai ne fait pas tomber (réseau)
const CHUTES_MAX := 2
const DELAI_POURRIE := 0.3   # le temps qu'une planche pourrie tienne sous le pied
const DELAI_VIDE := 0.3      # le temps de traverser un interstice sans tomber
const VITESSE_RAFALE := 0.9  # m/s : au-delà, pendant une rafale, il perd l'équilibre
const DELAI_RAFALE := 0.5
## Les tenants préviennent des planches pourries dès qu'elles sont à cette distance (en planches) devant le marcheur.
const ZONE_APPEL := 8
## Rythme humain des bots : coup d'oeil avant de crier, réflexe d'arrêt à un « stop », oubli d'une planche pourrie.
const COUP_D_OEIL_MIN := 0.3
const COUP_D_OEIL_MAX := 0.8
const ARRET_MIN := 0.4
const ARRET_MAX := 0.9
const OUBLI_POURRIE := 0.02
## Un même tenant ne lâche pas deux fois à moins de ce délai (secondes).
const LACHER_ECART := 30.0

var file: Array[int] = []    # l'ordre des traversées : le premier marche
var nb := 20                 # le nombre de planches
var pourries: Array[int] = []
var cassees := {}            # planche -> true : une planche pourrie qui a cédé
var avance := -1             # la dernière planche atteinte par le marcheur
var engage := false          # il a posé le pied sur la deuxième planche : les cordes doivent tenir
var t_pont := 0.0            # depuis combien de temps il est engagé
var rafale := 0              # 0 calme · 1 se lève · 2 secoue le pont
var relais := 0.0            # le pont se prépare (s) entre deux marcheurs
var tient := {}              # id -> true tant que sa corde est tenue
var _lache_depuis := {}      # id -> instant où il a lâché
var chutes := {}             # id -> nombre de chutes
var annonce := ""            # « Une planche a lâché ! » : vu de tous, sans dire qui
var _annonce_t := 0.0
var _prec := Vector2.ZERO
var _prec_ok := false
var _instable := 0.0
var _t_pourri := 0.0
var _t_vide := 0.0
var _bot_t := {}             # id -> délai avant de saisir sa corde
var _dernier_lache := {}     # id -> le moment où il a lâché pour la dernière fois (sabotage ou glissade)
var _bot_lache := {}         # id -> temps restant à lâcher
var _bot_pas_t := 0.0        # le bot marcheur attend avant sa prochaine planche
var _bot_vers := -1          # la planche où il se rend
var _bot_vers_t := 0.0
var _bot_fin := false
var _parleur := -1           # le bot qui parle aux marcheurs
var _dit := {}               # ce qu'il a déjà dit pour ce marcheur
var _bots := {}              # les joueurs joués par des bots (vus passer dans `bot`)
var _parle_pret := 0.0       # le bot qui parle reprend la parole à ce moment (il finit sa phrase)
var _prevu := {}             # planche pourrie -> {"t": quand il la dit, "dit": l'a-t-il vue, "vrai": dit-il vrai}
var _vu_pourrie := {}        # planche pourrie -> quand des personnes l'auront appelée {"t", "oubli"}
var _rafale_vue := -1.0      # le moment où le bot qui parle crie la rafale
var _rafale_connue := -1.0   # le moment où le bot marcheur a entendu, compris, et s'arrête
var _bot_depart := -1.0      # le bot marcheur attend ce délai avant son premier pas (il regarde, il comprend)
var causes: Array[String] = []   # pourquoi chaque marcheur est tombé (pour les essais)


func demarrer() -> void:
	_init_vies()
	nb = Passerelle.nb_planches(niveau, ids.size())
	pourries = Passerelle.pourries(niveau, nb, rng)
	duree = Passerelle.duree_pont(niveau, ids.size(), nb)
	var ordre: Array = ids.duplicate()
	for i in range(ordre.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var x: int = ordre[i]
		ordre[i] = ordre[j]
		ordre[j] = x
	# Celui qui s'est avancé dans la zone « Marcheur » traverse le premier.
	if ordre.has(elu):
		ordre.erase(elu)
		ordre.push_front(elu)
	file.assign(ordre)
	for id in ids:
		tient[id] = false
		_lache_depuis[id] = 0.0
		chutes[id] = 0
		# Saisir sa corde : lever les yeux, la trouver, la prendre.
		_bot_t[id] = RythmeHumain.PRISE + RythmeHumain.reaction(rng)
	relais = Passerelle.pause(niveau)
	_bot_pas_t = 1.0


## Le marcheur du moment marche pour de vrai ; les autres sont cloués à leur poste.
func a_pied(id: int) -> bool:
	return not fini and not file.is_empty() and id == file[0]


func depart_locale(_id: int) -> Vector3:
	return Vector3(0.0, 0.0, Passerelle.Z_DEPART + 1.6)


func regard_depart(_id: int) -> Vector3:
	return Vector3(0.0, 1.0, -20.0)


func _poste_de(id: int) -> Vector3:
	return DecorQuete.poste("pont", maxi(ids.find(id), 0), ids.size())


func _regard_de(id: int) -> Vector3:
	return DecorQuete.regard("pont", maxi(ids.find(id), 0), ids.size())


func _tous_tiennent() -> bool:
	if file.is_empty():
		return false
	for x in ids:
		if x != file[0] and not tient.get(x, false):
			return false
	return true


func _combien_tiennent() -> int:
	var n := 0
	for x in ids:
		if file.is_empty() or x != file[0]:
			if tient.get(x, false):
				n += 1
	return n


## Le marcheur a fini (réussi ou tombé) : il retourne à son poste, le suivant monte sur le pont.
func _suivant(chute: bool) -> void:
	var m: int = file.pop_front()
	avance = -1
	engage = false
	t_pont = 0.0
	rafale = 0
	_instable = 0.0
	_t_pourri = 0.0
	_t_vide = 0.0
	_prec_ok = false
	_bot_vers = -1
	_bot_fin = false
	_dit.clear()
	_prevu.clear()
	_vu_pourrie.clear()
	_rafale_vue = -1.0
	_rafale_connue = -1.0
	_bot_depart = -1.0
	relais = Passerelle.pause(niveau)
	var ici := _poste_de(m)
	var vers := _regard_de(m)
	var seul := false
	if chute:
		chutes[m] = int(chutes.get(m, 0)) + 1
		if int(chutes[m]) < CHUTES_MAX:
			file.append(m)
		# Il est remis (fondu au noir) à son poste, puis cloué à sa place une fois revenu. S'il est le seul qui
		# reste à passer, c'est directement au départ du pont qu'on le remet.
		if not file.is_empty() and file[0] == m:
			seul = true
			rappels.append([m, depart_locale(m), regard_depart(m)])
		else:
			rappels.append([m, ici, vers])
			placements.append([m, ici, vers, "poste", 1.0])
		perdre_vie()          # niveau dur : une planche qui lâche coûte une vie à l'équipe
	else:
		placements.append([m, ici, vers, "poste", 0.0])
	if file.is_empty():
		terminer()
		return
	if not seul:
		placements.append([file[0], depart_locale(file[0]), regard_depart(file[0]), "libre", 0.6 if chute else 0.4])


func _chuter(texte: String) -> void:
	causes.append(texte)
	annonce = texte
	_annonce_t = 3.0
	_suivant(true)


func action(id: int, d: Dictionary) -> void:
	if fini or not ids.has(id):
		return
	if d.has("tenir"):
		var t: bool = bool(d["tenir"])
		tient[id] = t
		if not t:
			_lache_depuis[id] = temps
		return


## Un fantôme arrache la corde des mains : la planche tombe s'il ne la ressaisit pas à temps.
func _hanter(id: int) -> String:
	if not tient.get(id, false):
		return super._hanter(id)
	tient[id] = false
	_lache_depuis[id] = temps
	return "La corde glisse des mains de %s : sa planche va tomber." % nom(id)


func avancer(delta: float) -> void:
	super.avancer(delta)
	if fini:
		return
	_annonce_t -= delta
	if _annonce_t <= 0.0:
		annonce = ""
	if file.is_empty():
		return
	if relais > 0.0:
		relais -= delta
		return
	if engage:
		t_pont += delta
		rafale = Passerelle.rafale(t_pont, niveau)
		for x in ids:
			if x != file[0] and not tient.get(x, false) and temps - float(_lache_depuis.get(x, 0.0)) > DELAI_LACHE:
				_chuter("Une planche a lâché !")
				return
	if pieds.has(file[0]):
		_suivre_les_pieds(file[0], delta)


## Les pieds du marcheur (réels) : sur une planche il avance, sur une planche pourrie elle cède, dans le vide
## il tombe ; une rafale le jette s'il bouge. Pas de verdict en l'air (il saute).
func _suivre_les_pieds(m: int, delta: float) -> void:
	var p: Vector3 = pieds[m]
	var xz := Vector2(p.x, p.z)
	var vit := 0.0
	if _prec_ok:
		vit = (xz - _prec).length() / maxf(delta, 0.001)
	_prec = xz
	_prec_ok = true
	if p.y > 0.25:
		return
	var i := Passerelle.indice_sous(p.x, p.z, nb)
	if i >= 0:
		_t_vide = 0.0
		if i > avance and i <= avance + 3:
			avance = i
		if i >= 1 and not engage:
			engage = true
			t_pont = 0.0
		if pourries.has(i):
			_t_pourri += delta
			if _t_pourri >= DELAI_POURRIE:
				cassees[i] = true
				_chuter("Une planche a cédé !")
				return
		else:
			_t_pourri = 0.0
		if engage and rafale == 2 and vit > VITESSE_RAFALE:
			_instable += delta
		else:
			_instable = maxf(_instable - delta * 0.5, 0.0)
		if _instable > DELAI_RAFALE:
			_chuter("La rafale l'a emporté !")
		return
	_t_pourri = 0.0
	if Passerelle.dans_la_gorge(p.x, p.z, nb):
		_t_vide += delta
		if _t_vide >= DELAI_VIDE:
			_chuter("Le marcheur est tombé dans la gorge !")
		return
	_t_vide = 0.0
	# De l'autre côté : il a traversé s'il est bien passé par les dernières planches.
	if engage and avance >= nb - 2 and p.z < Passerelle.z_fin(nb) - 0.2:
		_reussis[m] = true
		annonce = "Une traversée réussie !"
		_annonce_t = 2.5
		_suivant(false)


func _donnees(id: int) -> Dictionary:
	var marche: bool = not file.is_empty() and id == file[0]
	var vue_rafale := rafale
	if marche and vue_rafale == 1:
		vue_rafale = 0       # il ne la voit pas se lever
	return {"t": "pont", "n": nb, "avance": avance, "marcheur": marche, "relais": maxf(relais, 0.0),
		"rafale": vue_rafale, "pourries": [] if marche else pourries, "cassees": cassees.keys(),
		"temps": temps, "engage": engage}


func vue_pour(id: int) -> Dictionary:
	var blocs := []
	var traverses := reussis().size()
	if file.is_empty():
		blocs.append(MiniJeu.texte("Le pont est libre. Traversées réussies : %d / %d" % [traverses, ids.size()], 22))
		return {"consigne": "Le pont est fini.", "blocs": blocs}
	var m: int = file[0]
	blocs.append(_donnees(id))
	if id == m:
		blocs.append(MiniJeu.texte("C'est ton tour : traverse à pied !", 24, "or"))
		if relais > 0.0:
			blocs.append(MiniJeu.texte("Le pont se prépare : attends que tout le monde tienne sa corde.", 18, "gris"))
		else:
			blocs.append(MiniJeu.jauge(float(maxi(avance + 1, 0)) / nb, "La traversée"))
		blocs.append(MiniJeu.texte("Cordes tenues : %d / %d" % [_combien_tiennent(), ids.size() - 1], 18, "or" if _tous_tiennent() else "rouge"))
		if rafale == 2:
			blocs.append(MiniJeu.texte("Le pont tangue ! Ne bouge plus !", 26, "rouge"))
		blocs.append(MiniJeu.texte("Marche sur les planches, une à une. Écoute les autres : une planche peut être pourrie, une rafale peut te jeter dans la gorge.", 16, "gris"))
	else:
		blocs.append({"t": "tenir", "l": "Saisis ta corde (regarde-la, poing fermé ou clic tenu) et garde-la : tu cales les planches de %s" % nom(m)})
		blocs.append(MiniJeu.jauge(float(maxi(avance + 1, 0)) / nb, "%s traverse" % nom(m)))
		if rafale == 1:
			blocs.append(MiniJeu.texte("Une rafale se lève : dis-lui de s'arrêter !", 24, "or"))
		elif rafale == 2:
			blocs.append(MiniJeu.texte("La rafale secoue le pont !", 22, "rouge"))
		if not pourries.is_empty():
			var nums := PackedStringArray()
			for p: int in pourries:
				if not cassees.has(p):
					nums.append(str(p + 1))
			if not nums.is_empty():
				blocs.append(MiniJeu.texte("Planches pourries (en rouge) : %s" % ", ".join(nums), 18, "rouge"))
		if _reussis.get(id, false):
			blocs.append(MiniJeu.texte("Tu as traversé. Maintenant, tiens bon pour les autres !", 20, "vert"))
		elif int(chutes.get(id, 0)) >= CHUTES_MAX:
			blocs.append(MiniJeu.texte("Tu es tombé trop souvent. Tiens quand même !", 20, "rouge"))
		else:
			blocs.append(MiniJeu.texte("Ton tour viendra. Ne lâche pas !", 18, "gris"))
	if annonce != "":
		blocs.append(MiniJeu.texte(annonce, 24, "rouge"))
	blocs.append(MiniJeu.texte("Traversées réussies : %d / %d (il en faut %d)" % [traverses, ids.size(), Quetes.seuil(ids.size(), niveau)], 16, "gris"))
	return {"consigne": "Un seul traverse à pied ; tous les autres saisissent leur corde et la tiennent. Lâcher, c'est le faire tomber.", "blocs": blocs}


func bot(id: int, delta: float) -> void:
	if fini or file.is_empty():
		return
	_bots[id] = true
	if id == file[0]:
		_bot_marcheur(id, delta)
		return
	if _parleur < 0 or not ids.has(_parleur) or _parleur == file[0]:
		_parleur = id
	if id == _parleur:
		_bot_parle(id)
	if float(_bot_lache.get(id, 0.0)) > 0.0:
		_bot_lache[id] = float(_bot_lache[id]) - delta
		if float(_bot_lache[id]) <= 0.0:
			action(id, {"tenir": true})
		return
	if not tient.get(id, false):
		_bot_t[id] = float(_bot_t[id]) - delta
		if float(_bot_t[id]) <= 0.0:
			action(id, {"tenir": true})
			_bot_t[id] = RythmeHumain.PRISE + RythmeHumain.reaction(rng)
		return
	# Il tient. Un saboteur lâche exprès pendant la traversée, mais rarement (pas de rafale : au plus une fois par
	# LACHER_ECART secondes) ; les autres glissent plus rarement encore.
	if engage:
		if temps - float(_dernier_lache.get(id, -99.0)) >= LACHER_ECART and rng.randf() < taux_lacher(niveau, peut_saboter(id)) * delta:
			_dernier_lache[id] = temps
			_bot_lache[id] = rng.randf_range(0.6, 1.4)
			action(id, {"tenir": false})


## La chance par seconde qu'un tenant lâche sa corde pendant la traversée : un saboteur une fois par minute
## environ, un honnête presque jamais (une main qui glisse).
static func taux_lacher(niveau: String, saboteur: bool) -> float:
	if saboteur:
		return 0.03
	return {"simple": 0.0, "normal": 0.0003, "dur": 0.0004, "extreme": 0.0005}.get(niveau, 0.0003)


## Un bot à la voix : il prévient des rafales et nomme les planches pourries (un saboteur ment). Il regarde
## d'abord (un coup d'oeil), puis dit sa phrase en entier ; il n'enchaîne pas deux phrases sans reprendre
## son souffle, et il lui arrive d'oublier une planche.
func _bot_parle(id: int) -> void:
	var cle := "rafale%d" % int(t_pont / Passerelle.periode_rafale(niveau))
	if rafale == 1 and not _dit.has(cle):
		if _rafale_vue < 0.0:
			_rafale_vue = temps + rng.randf_range(COUP_D_OEIL_MIN, COUP_D_OEIL_MAX) * 0.6
		if temps >= _rafale_vue and temps >= _parle_pret:
			_dit[cle] = true
			paroles.append([id, "Rafale ! Ne bouge plus !"])
			_parle_pret = temps + RythmeHumain.parole(4)
		return
	if rafale == 0:
		_rafale_vue = -1.0
	for p: int in pourries:
		if p > avance and p <= avance + ZONE_APPEL and not _prevu.has(p):
			# Il vient de la voir dans la zone : coup d'oeil, puis il l'annonce (ou l'oublie, ou ment).
			var oublie: bool = rng.randf() < OUBLI_POURRIE
			var ment: bool = peut_saboter(id) and rng.randf() < 0.5
			_prevu[p] = {"t": temps + rng.randf_range(COUP_D_OEIL_MIN, COUP_D_OEIL_MAX), "dit": not oublie, "vrai": not ment}
	if temps < _parle_pret:
		return
	for p: int in pourries:
		var pv: Dictionary = _prevu.get(p, {})
		if pv.is_empty() or _dit.has(p) or not bool(pv["dit"]) or temps < float(pv["t"]):
			continue
		_dit[p] = true
		if bool(pv["vrai"]):
			paroles.append([id, "Saute la planche %d !" % (p + 1)])
		else:
			paroles.append([id, "Tout va bien, avance !"])
		_parle_pret = temps + RythmeHumain.parole(4)
		return


## Le bot marcheur sait-il qu'il doit sauter la planche pourrie `p` ? 1 : oui, il la saute ; 0 : il attend
## encore l'information ; -1 : il ne sait rien (oubli, ou un saboteur lui a dit que tout allait bien) et
## marchera dessus. Un tenant bot parle (`_prevu`) ; si aucun tenant n'est un bot, ce sont des personnes
## qui l'appellent : il leur laisse le temps de voir, de dire et d'être comprises, sans les entendre.
func _pourrie_connue(p: int) -> int:
	var tenants_bots := false
	for x in _bots.keys():
		if x != file[0] and ids.has(x):
			tenants_bots = true
	if tenants_bots:
		var pv: Dictionary = _prevu.get(p, {})
		if pv.is_empty():
			return 0
		if not bool(pv["dit"]) or not bool(pv["vrai"]):
			return -1
		return 1 if temps >= float(pv["t"]) + RythmeHumain.parole(3) else 0
	if not _vu_pourrie.has(p):
		return 0
	var v: Dictionary = _vu_pourrie[p]
	if bool(v["oubli"]):
		return -1
	return 1 if temps >= float(v["t"]) else 0


## Quand des personnes tiennent les cordes, on note quand la planche pourrie p est entrée dans leur zone
## d'appel : de là part le temps qu'elles mettent à la voir, à la dire, à être comprises.
func _noter_zone() -> void:
	for p: int in pourries:
		if p > avance and p <= avance + ZONE_APPEL and not _vu_pourrie.has(p):
			_vu_pourrie[p] = {"t": temps + rng.randf_range(COUP_D_OEIL_MIN, COUP_D_OEIL_MAX) + RythmeHumain.parole(3) + RythmeHumain.reaction(rng) * 0.5,
				"oubli": rng.randf() < OUBLI_POURRIE}


## Le prochain pas du bot marcheur : la planche suivante, sauf si une pourrie l'attend et qu'il en est prévenu.
## Rend la planche visée, ou -1 s'il doit attendre.
func _prochaine_planche() -> int:
	_noter_zone()
	var j := maxi(avance + 1, 1)
	if pourries.has(j):
		var c := _pourrie_connue(j)
		if c == 0:
			return -1
		if c == 1:
			j += 1
	return j


## L'arrêt du marcheur bot devant une rafale : il ne s'arrête qu'une fois la rafale vue/annoncée ET comprise
## (un réflexe, pas une décision). Rend vrai s'il doit rester immobile.
func _bot_fige() -> bool:
	if rafale >= 1:
		if _rafale_connue < 0.0:
			_rafale_connue = temps + rng.randf_range(COUP_D_OEIL_MIN, COUP_D_OEIL_MAX) + rng.randf_range(ARRET_MIN, ARRET_MAX)
		return temps >= _rafale_connue
	if _rafale_connue >= 0.0:
		_rafale_connue = -1.0
		_bot_pas_t = maxf(_bot_pas_t, RythmeHumain.reaction(rng) * 0.5)   # la rafale est passée : il reprend
	return false


## Le bot marcheur traverse pour de vrai : une planche après l'autre, en sautant les pourries dont on l'a
## prévenu, et il s'arrête quand une rafale est annoncée (un bot qui reçoit le « stop » de son guide).
func _bot_marcheur(id: int, delta: float) -> void:
	if relais > 0.0:
		return
	if not engage:
		if not _tous_tiennent():
			_bot_depart = -1.0
			return
		# Les cordes sont prises : il regarde, il respire, il se lance (un temps de réaction).
		if _bot_depart < 0.0:
			# Le premier se lance après un temps de réaction ; les suivants attendaient déjà leur tour.
			_bot_depart = RythmeHumain.reaction(rng) if reussis().is_empty() and chutes.values().all(func(c): return int(c) == 0) else rng.randf_range(0.3, 0.6)
		_bot_depart -= delta
		if _bot_depart > 0.0:
			return
	if not pieds.has(id):
		_bot_pas_discret(id, delta)
		return
	if _bot_fige():
		_bot_pas_t = maxf(_bot_pas_t, 0.3)
	_bot_pas_t -= delta
	if _bot_vers >= 0 or _bot_fin:
		_bot_vers_t += delta
		var cible := Vector3(0.0, 0.0, Passerelle.z_fin(nb) - 1.4) if _bot_fin else Vector3(0.0, 0.0, Passerelle.z_planche(_bot_vers))
		var p: Vector3 = pieds[id]
		if Vector2(p.x - cible.x, p.z - cible.z).length() < 0.2 or _bot_vers_t > 4.0:
			if not _bot_fin:
				_bot_vers = -1
				_bot_pas_t = rng.randf_range(Passerelle.tp(niveau) - 0.35, Passerelle.tp(niveau) - 0.05)
		return
	if _bot_pas_t > 0.0:
		return
	var j := _prochaine_planche()
	if j < 0:
		return
	if j >= nb:
		_bot_fin = true
		_bot_vers_t = 0.0
		deplacements.append([id, Vector3(0.0, 0.0, Passerelle.z_fin(nb) - 1.4)])
		return
	_bot_vers = j
	_bot_vers_t = 0.0
	deplacements.append([id, Vector3(0.0, 0.0, Passerelle.z_planche(j))])


## Sans hôte pour lire ses pieds (les essais purs, sans fenêtre ni clairière), le bot marcheur « avance » d'une
## planche à la fois : mêmes règles (les cordes doivent tenir, une planche pourrie se saute si on l'a dite), pas
## de pieds.
func _bot_pas_discret(id: int, delta: float) -> void:
	if _bot_fige():
		_bot_pas_t = maxf(_bot_pas_t, 0.3)
	_bot_pas_t -= delta
	if _bot_pas_t > 0.0 or not _tous_tiennent():
		return
	var j := _prochaine_planche()
	if j < 0:
		return
	_bot_pas_t = rng.randf_range(Passerelle.tp(niveau) - 0.35, Passerelle.tp(niveau) - 0.05)
	avance = j
	if not engage:
		engage = true
		t_pont = 0.0
	if j >= nb:
		_reussis[id] = true
		_suivant(false)
