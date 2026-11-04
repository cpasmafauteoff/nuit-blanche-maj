class_name Partie
extends RefCounted
## Les règles d'une partie, sans rien d'affiché : c'est l'hôte qui les fait tourner et qui fait foi.
## Phases : salon → nuit → aube → jour → conseil → nuit … → fin.
## Chaque changement notable s'ajoute à `evenements` (que le meneur vide et transmet).
## Un événement qui porte la clé "pour" est privé : seul ce joueur doit le recevoir.

var joueurs := {}           # id -> fiche (voir _fiche)
var phase := "salon"
var nuit_n := 0             # numéro de la nuit en cours (1 = première)
var faim := 0               # nuits de suite sans victime pour la meute
var evenements: Array[Dictionary] = []
## Tout ce qui s'est passé, dans l'ordre (révélé à la fin de la partie) : {n, type, id, cause…}.
var chronique: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _victime_meute := -1
var _victime_solitaire := -1
var _empoisonne := -1
var _sauve := -1
var _attente: Array[int] = []      # victimes d'attaque à l'aube (l'Herboriste peut en sauver une)
var _trappeurs: Array[int] = []
var _votes := {}                   # votant -> cible
var _morsure_faite := false
var _potion_vie := true
var _potion_mort := true
var _souffles := 2
var _garde := -1                   # joueur dont la porte est gardée cette nuit
var _garde_prec := -1              # la nuit d'avant (jamais deux fois de suite la même)
var _lu_cette_nuit := false
var _examine_ce_jour := false
## Mode quêtes : tout le monde commence villageois, les loups ne sont tirés qu'à la première nuit.
## Tant qu'ils ne le sont pas, personne ne peut gagner.
var loups_tires := true
var maire := -1
var maire_a_remplacer := -1       # le maire vient de mourir : il désigne son successeur
var _liseuse_a_vu_loup := false


func _fiche(id: int, nom: String, role: String, maison: int) -> Dictionary:
	return {
		"id": id, "nom": nom, "role": role, "maison": maison, "vivant": true,
		"loup": Roles.est_loup(role), "amoureux": -1, "modele": -1, "peut_voter": true,
		"doyen_touche": false, "gracie": false, "mordu_nuit": -1, "ancien_role": "", "venin": false,
		"titre": "", "role_gagne": false,
	}


## liste : [{id, nom}], composition : un rôle par joueur. Rôles et maisons tirés au sort.
func configurer(liste: Array, composition: Array, graine: int) -> void:
	_rng.seed = graine
	var roles := composition.duplicate()
	_melanger(roles)
	configurer_fixe(liste, roles, graine)
	var maisons := range(liste.size())
	_melanger(maisons)
	var i := 0
	for id in joueurs:
		joueurs[id]["maison"] = maisons[i]
		i += 1


## Les rôles que l'hôte a retirés de cette partie : jamais gagnés aux quêtes, jamais tirés.
var roles_retires: Array = []
## Pour les essais seulement (--loup=invite|hote) : les joueurs que le tirage des loups prend d'abord.
var loups_preferes: Array[int] = []


## Mode quêtes : tout le monde villageois, maisons tirées au sort ; les loups viendront la 1re nuit.
func configurer_quetes(liste: Array, graine: int) -> void:
	var roles := []
	for l in liste:
		roles.append("villageois")
	configurer(liste, roles, graine)
	loups_tires = false


## Une quête réussie : ce joueur reçoit un rôle (ou un simple titre), en secret.
func donner_role(id: int, r: String, titre := "", quete := "") -> void:
	var f: Dictionary = joueurs[id]
	f["role"] = r
	f["titre"] = titre
	f["loup"] = Roles.est_loup(r)
	f["role_gagne"] = true
	evenements.append({"type": "role_gagne", "pour": id, "role": r, "titre": titre})
	chronique.append({"n": nuit_n, "type": "role_gagne", "id": id, "role": r, "titre": titre, "quete": quete})


## Les rôles (et titres) déjà tenus : un rôle n'existe qu'une fois.
func roles_pris() -> Array:
	var p := []
	for id in joueurs:
		var f: Dictionary = joueurs[id]
		if f["role_gagne"]:
			p.append(f["titre"] if f["titre"] != "" else f["role"])
	return p


## Le nom du rôle tel que le joueur le lit : son titre s'il en a un.
func nom_role(id: int) -> String:
	var f: Dictionary = joueurs[id]
	return f["titre"] if f["titre"] != "" else Roles.nom(f["role"])


## Le plus de loups qu'un village de `n` supporte sans être perdu d'avance.
static func loups_max(n: int) -> int:
	return clampi((n - 2) / 2, 1, 4)


## Le nombre de loups conseillé : un pour quatre (6-7 joueurs : un seul ; à deux contre quatre,
## la meute gagnait 87 parties sur 100).
static func loups_conseilles(n: int) -> int:
	return clampi(n / 4, 1, loups_max(n))


## La première nuit : n loups tirés parmi ceux qui n'ont gagné aucun rôle. Jamais plus que
## loups_max, et au moins un : avec (vivants - 1) / 2, une seule victime la nuit 1 mettait la
## meute à égalité et la partie était perdue à l'aube, avant tout vote (7 joueurs, 3 loups).
## Renvoie les élus.
func tirer_loups(n: int) -> Array[int]:
	var types := Quetes.types_loups(roles_retires)
	var libres: Array = []
	for id in vivants():
		if not joueurs[id]["role_gagne"]:
			libres.append(id)
	if libres.is_empty():
		libres = vivants()
	_melanger(libres)
	# Essais (--loup=invite|hote) : ces joueurs sont tirés en premier.
	for pref in loups_preferes:
		if libres.has(pref):
			libres.erase(pref)
			libres.push_front(pref)
	var nb := clampi(n, 1, loups_max(vivants().size()))
	nb = mini(nb, libres.size())
	var elus: Array[int] = []
	var taille := vivants().size()
	# Le Loup solitaire (12 joueurs et plus) prend la place du dernier loup tiré : la meute garde
	# au moins un vrai loup, il chasse avec elle mais gagne seul.
	var solitaire := taille >= Quetes.SEUIL_SOLITAIRE and nb >= 2 and not roles_retires.has("solitaire")
	for i in nb:
		var id: int = libres[i]
		var f: Dictionary = joueurs[id]
		f["role"] = "solitaire" if solitaire and i == nb - 1 else types[i % types.size()]
		f["titre"] = ""
		f["loup"] = true
		elus.append(id)
		evenements.append({"type": "devient_loup", "id": id, "pour": id, "cause": "tirage"})
	# Le Traître (10 joueurs et plus) : un villageois sans rôle qui gagne avec la meute. Seulement
	# s'il reste de la marge : meute + traître doit rester en minorité après la première victime.
	if taille >= Quetes.SEUIL_TRAITRE and not roles_retires.has("traitre") and nb + 1 <= loups_max(taille) 			and libres.size() > nb:
		var t: int = libres[nb]
		joueurs[t]["role"] = "traitre"
		joueurs[t]["titre"] = ""
		evenements.append({"type": "devient_traitre", "id": t, "pour": t})
	loups_tires = true
	return elus


## Rôles donnés dans l'ordre de la liste (pour les tests).
func configurer_fixe(liste: Array, roles: Array, graine: int) -> void:
	_rng.seed = graine
	joueurs.clear()
	for i in liste.size():
		var id: int = liste[i]["id"]
		joueurs[id] = _fiche(id, liste[i]["nom"], roles[i], i)
	phase = "salon"


func _melanger(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var x = a[i]
		a[i] = a[j]
		a[j] = x


# ---------------------------------------------------------------- lecture

func role(id: int) -> String:
	return joueurs[id]["role"]


func nom(id: int) -> String:
	return joueurs[id]["nom"] if joueurs.has(id) else "?"


func vivant(id: int) -> bool:
	return joueurs.has(id) and joueurs[id]["vivant"]


func est_loup(id: int) -> bool:
	return joueurs.has(id) and joueurs[id]["loup"]


func vivants() -> Array[int]:
	var v: Array[int] = []
	for id in joueurs:
		if joueurs[id]["vivant"]:
			v.append(id)
	return v


## Loups vivants, Loup solitaire compris : ceux qui chassent la nuit.
func chasseurs() -> Array[int]:
	var v: Array[int] = []
	for id in vivants():
		if est_loup(id):
			v.append(id)
	return v


func _couple_interdit() -> Array[int]:
	for id in joueurs:
		var a: int = joueurs[id]["amoureux"]
		if a > 0 and id < a and est_loup(id) != est_loup(a):
			return [id, a]
	return []


## village, meute, solitaire ou amoureux (couple loup + non-loup).
func camp(id: int) -> String:
	if _couple_interdit().has(id):
		return "amoureux"
	if role(id) == "solitaire":
		return Roles.SOLITAIRE
	if est_loup(id) or role(id) == "traitre":
		return Roles.MEUTE
	return Roles.VILLAGE


## Qui ce joueur sait être loup, nommément : personne. Les loups ne se connaissent pas (révision 27/10).
func connus_par(_id: int) -> Array[int]:
	return []


## Les silhouettes qu'un loup voit la nuit, sans nom : les autres chasseurs vivants.
func silhouettes(id: int) -> Array[int]:
	var v: Array[int] = []
	if not est_loup(id) or not vivant(id):
		return v
	for autre in chasseurs():
		if autre != id:
			v.append(autre)
	return v


## Ce que la Liseuse voit : un mordu garde son ancien visage la nuit qui suit sa morsure.
func role_lu(id: int) -> String:
	var f: Dictionary = joueurs[id]
	if f["mordu_nuit"] > 0 and nuit_n <= f["mordu_nuit"]:
		return f["ancien_role"]
	if f["loup"] and not Roles.est_loup(f["role"]):
		return "loup"
	return f["role"]


func porte_gardee(id: int) -> bool:
	return phase == "nuit" and _garde == id


func trappeur_attendu() -> int:
	return _trappeurs[0] if not _trappeurs.is_empty() else -1


## Pendant la nuit : la ou les victimes désignées (meute, solitaire). Après : celles en attente.
func victimes_attaque() -> Array[int]:
	if phase == "nuit":
		var v: Array[int] = []
		for x in [_victime_meute, _victime_solitaire]:
			if x > 0 and not v.has(x):
				v.append(x)
		return v
	return _attente.duplicate()


## Ceux que le loup mange VRAIMENT cette nuit (la scène leur est jouée) : désignés, vivants, ni sauvés par
## l'Herboriste, ni Doyen encore indemne (il survit à la première attaque). Valable pendant la nuit.
func victimes_a_manger() -> Array[int]:
	var r: Array[int] = []
	if phase != "nuit":
		return r
	for v in victimes_attaque():
		if not vivant(v) or v == _sauve:
			continue
		if role(v) == "doyen" and not joueurs[v]["doyen_touche"]:
			continue
		r.append(v)
	return r


## Les loups qui entrent chez `victime` (Edwin, 04/11 : le loup mange EN VRAI). Pour la victime de la meute :
## toute la meute vivante ; pour celle du Solitaire (qui chasse seul) : le Solitaire seulement.
func agresseurs(victime: int) -> Array[int]:
	var r: Array[int] = []
	if phase != "nuit":
		return r
	if victime == _victime_meute:
		return chasseurs()
	if victime == _victime_solitaire:
		for l in chasseurs():
			if role(l) == "solitaire":
				r.append(l)
	return r


## La scène de `victime` vient de se jouer : elle meurt TOUT DE SUITE (fantôme), sans attendre l'aube
## ni les autres scènes (Edwin, 04/11). Rend vrai si elle est bien morte à l'instant.
func manger_maintenant(victime: int) -> bool:
	if not victimes_a_manger().has(victime):
		return false
	_mourir(victime, "loups" if victime == _victime_meute else "solitaire")
	return not vivant(victime)


func potions() -> Dictionary:
	return {"vie": _potion_vie, "mort": _potion_mort}


func peut_mordre() -> bool:
	return not _morsure_faite


func souffles_restants() -> int:
	return _souffles


func solitaire_peut_tuer() -> bool:
	return nuit_n % 2 == 0


# ---------------------------------------------------------------- phases

func commencer_nuit() -> void:
	phase = "nuit"
	nuit_n += 1
	_victime_meute = -1
	_victime_solitaire = -1
	_empoisonne = -1
	_sauve = -1
	_garde_prec = _garde
	_garde = -1
	_lu_cette_nuit = false
	_attente.clear()
	# Le venin du Vampire agit : le mordu du jour rejoint la meute, et il l'apprend quand on l'appelle.
	for id in joueurs:
		var f: Dictionary = joueurs[id]
		if f["venin"] and f["vivant"]:
			f["venin"] = false
			f["ancien_role"] = f["role"]
			f["mordu_nuit"] = nuit_n
			f["loup"] = true
			evenements.append({"type": "devient_loup", "id": id, "pour": id, "cause": "morsure"})


func fin_nuit() -> void:
	_premiere_nuit_par_defaut()
	_attente.clear()
	for v in [_victime_meute, _victime_solitaire]:
		if v > 0 and vivant(v) and not _attente.has(v):
			if role(v) == "doyen" and not joueurs[v]["doyen_touche"]:
				joueurs[v]["doyen_touche"] = true
				evenements.append({"type": "doyen", "id": v})
			else:
				_attente.append(v)
	faim = 0 if _victime_meute > 0 else faim + 1
	phase = "aube"


## L'Entremetteuse et l'Enfant sauvage qui n'ont pas choisi : le hasard choisit pour eux. Ils se
## gagnent aux quêtes : c'est leur première nuit avec le rôle, pas forcément la nuit 1.
func _premiere_nuit_par_defaut() -> void:
	for id in joueurs:
		var f: Dictionary = joueurs[id]
		if not f["vivant"]:
			continue
		if f["role"] == "enfant" and f["modele"] < 0:
			f["modele"] = _au_hasard_sauf([id])
			evenements.append({"type": "modele", "pour": id, "cible": f["modele"]})
		if f["role"] == "entremetteuse" and not _deja_lie():
			var a := _au_hasard_sauf([])
			var b := _au_hasard_sauf([a])
			if a > 0 and b > 0:
				_lier(a, b)


## L'Entremetteuse ou l'Enfant sauvage vivant qui n'a pas encore fait son choix : on l'appelle.
func doit_choisir(r: String) -> bool:
	for id in vivants():
		if role(id) != r:
			continue
		if r == "entremetteuse" and not _deja_lie():
			return true
		if r == "enfant" and joueurs[id]["modele"] < 0 and not est_loup(id):
			return true
	return false


func _deja_lie() -> bool:
	for id in joueurs:
		if joueurs[id]["amoureux"] > 0:
			return true
	return false


func _au_hasard_sauf(exclus: Array) -> int:
	var choix := []
	for id in vivants():
		if not exclus.has(id):
			choix.append(id)
	return choix[_rng.randi_range(0, choix.size() - 1)] if not choix.is_empty() else -1


func resoudre_aube() -> void:
	for v in _attente:
		if v == _sauve:
			evenements.append({"type": "sauve", "id": v})
			chronique.append({"n": nuit_n, "type": "sauve", "id": v})
		else:
			_mourir(v, "loups" if v == _victime_meute else "solitaire")
	if _empoisonne > 0:
		_mourir(_empoisonne, "potion")
	_attente.clear()
	phase = "jour"
	_examine_ce_jour = false


func commencer_conseil() -> void:
	phase = "conseil"
	_votes.clear()


func voter(id: int, cible: int) -> String:
	if phase != "conseil":
		return "Le vote n'est pas ouvert."
	if not vivant(id):
		return "Les morts ne votent pas."
	if not joueurs[id]["peut_voter"]:
		return "Tu as perdu ton droit de vote."
	if cible != -1 and not vivant(cible):
		return "On ne peut accuser que les vivants."
	if cible == id:
		return "On ne vote pas pour soi."
	if cible == -1:
		_votes.erase(id)
	else:
		_votes[id] = cible
	return ""


func votes() -> Dictionary:
	return _votes.duplicate()


## Le dépouillement, sans rien trancher : les voix de chacun (celle du maire compte double) et
## ceux qui sont en tête (un seul, plusieurs à égalité, ou personne si nul n'a voté).
func depouiller() -> Dictionary:
	var compte := {}
	for votant in _votes:
		var c: int = _votes[votant]
		if vivant(c):
			compte[c] = compte.get(c, 0) + (2 if votant == maire else 1)
	var max_voix := 0
	for c in compte:
		max_voix = maxi(max_voix, compte[c])
	var en_tete: Array[int] = []
	for c in compte:
		if compte[c] == max_voix:
			en_tete.append(c)
	return {"compte": compte, "en_tete": en_tete}


## Le plus accusé est éliminé ; en cas d'égalité, personne. La voix du maire compte double.
## `designe` : celui que le Conseil (ou le maire, à égalité) a désigné — il est éliminé quoi qu'il
## arrive, sauf le Simplet, gracié une fois (décision d'Edwin, 29/10 : toujours un éliminé).
func resoudre_vote(designe := -1) -> Dictionary:
	var d := depouiller()
	var compte: Dictionary = d["compte"]
	var en_tete: Array = d["en_tete"]
	var meilleur: int = designe if designe > 0 and vivant(designe) else (en_tete[0] if en_tete.size() == 1 else -1)
	var res := {"elimine": -1, "compte": compte, "gracie": -1}
	chronique.append({"n": nuit_n, "type": "vote", "compte": compte.duplicate(), "votes": _votes.duplicate()})
	if meilleur > 0:
		var f: Dictionary = joueurs[meilleur]
		if f["role"] == "simplet" and not f["gracie"]:
			f["gracie"] = true
			f["peut_voter"] = false
			res["gracie"] = meilleur
			evenements.append({"type": "gracie", "id": meilleur})
		else:
			res["elimine"] = meilleur
			_mourir(meilleur, "vote")
	phase = "jour"
	return res


## Le Conseil d'élection : le plus de voix devient maire ; à égalité, le sort tranche entre eux ;
## personne n'a voté, le sort choisit parmi les vivants.
func elire_maire() -> int:
	var compte := {}
	for votant in _votes:
		compte[_votes[votant]] = compte.get(_votes[votant], 0) + 1
	var max_voix := 0
	for c in compte:
		max_voix = maxi(max_voix, compte[c])
	var tete: Array = []
	for c in compte:
		if compte[c] == max_voix and vivant(c):
			tete.append(c)
	if tete.is_empty():
		tete = vivants()
	maire = tete[_rng.randi_range(0, tete.size() - 1)] if not tete.is_empty() else -1
	chronique.append({"n": nuit_n, "type": "maire", "id": maire, "votes": _votes.duplicate()})
	evenements.append({"type": "maire", "id": maire})
	phase = "jour"
	return maire


## Le maire mort désigne qui lui succède (cible = -1 : le sort choisit).
func designer_successeur(id: int, cible: int) -> String:
	if maire_a_remplacer != id:
		return "Ce n'est pas à toi de choisir."
	if cible == -1:
		cible = _au_hasard_sauf([id])
	if not vivant(cible) or cible == id:
		return "Choisis un vivant."
	maire = cible
	maire_a_remplacer = -1
	chronique.append({"n": nuit_n, "type": "maire", "id": maire, "votes": {}})
	evenements.append({"type": "maire", "id": maire, "successeur": true})
	return ""


func _mourir(id: int, cause: String) -> void:
	if not vivant(id):
		return
	var f: Dictionary = joueurs[id]
	f["vivant"] = false
	if id == maire:
		maire = -1
		maire_a_remplacer = id
	evenements.append({"type": "mort", "id": id, "cause": cause, "role": f["role"]})
	chronique.append({"n": nuit_n, "type": "mort", "id": id, "cause": cause})
	if f["role"] == "trappeur" and cause != "parti":   # parti, il ne tirera pas : on ne l'attend pas
		_trappeurs.append(id)
		evenements.append({"type": "trappeur", "id": id})
	for autre in joueurs:
		var g: Dictionary = joueurs[autre]
		if g["role"] == "enfant" and g["modele"] == id and g["vivant"] and not g["loup"]:
			g["loup"] = true
			evenements.append({"type": "devient_loup", "id": autre, "pour": autre, "cause": "modele"})
			chronique.append({"n": nuit_n, "type": "devient_loup", "id": autre})
	var a: int = f["amoureux"]
	if a > 0 and vivant(a):
		_mourir(a, "chagrin")


## Un joueur quitte la partie (Edwin, 30/10 : aucun bot ne prend sa place) : il sort du village
## comme un mort — son amoureux le suit, le maire est remplacé, la victoire se recompte.
func quitter(id: int) -> void:
	_mourir(id, "parti")


func trappeur_renonce() -> void:
	if not _trappeurs.is_empty():
		_trappeurs.pop_front()


# ---------------------------------------------------------------- actions

## Renvoie "" si l'action est faite, sinon la raison du refus (à afficher au joueur).
func action(id: int, type: String, cible := -1, cible2 := -1) -> String:
	if not joueurs.has(id):
		return "Joueur inconnu."
	var r := role(id)
	if type == "trappe":
		if trappeur_attendu() != id:
			return "Ce n'est pas à toi de tirer."
		if not vivant(cible) or cible == id:
			return "Vise un vivant."
		_trappeurs.pop_front()
		_mourir(cible, "trappeur")
		return ""
	if not vivant(id):
		return "Tu es mort."
	match type:
		"tuer":
			if phase != "nuit" or not est_loup(id):
				return "Seule la meute tue, la nuit."
			if not vivant(cible) or est_loup(cible):
				return "Choisis une proie vivante, hors de la meute."
			if cible == _garde:
				return "La porte est gardée."
			_victime_meute = cible
			return ""
		"mordre":
			# Le Vampire, le jour, une fois par partie. Il ne connaît pas la meute : mordre un loup le tue.
			if phase != "jour" or r != "vampire":
				return "Seul le Loup vampire mord, et seulement le jour."
			if _morsure_faite:
				return "Tu as déjà mordu : une seule morsure par partie."
			if not vivant(cible) or cible == id:
				return "Mords un vivant."
			_morsure_faite = true
			if est_loup(cible):
				_mourir(id, "surdose")
			else:
				joueurs[cible]["venin"] = true
			return ""
		"tuer_seul":
			if phase != "nuit" or r != "solitaire":
				return "Seul le Loup solitaire chasse seul."
			if not solitaire_peut_tuer():
				return "Pas cette nuit : une nuit sur deux."
			if not vivant(cible) or est_loup(cible):
				return "Choisis une proie vivante, hors de la meute."
			_victime_solitaire = cible
			return ""
		"lire":
			if phase != "nuit" or r != "liseuse":
				return "Seule la Liseuse lit les âmes, la nuit."
			if _lu_cette_nuit:
				return "Tu as déjà lu une âme cette nuit."
			if not vivant(cible) or cible == id:
				return "Choisis une autre maison habitée."
			_lu_cette_nuit = true
			if Roles.est_loup(role_lu(cible)):
				_liseuse_a_vu_loup = true
			evenements.append({"type": "lecture", "pour": id, "cible": cible, "role": role_lu(cible)})
			return ""
		"poison":
			if phase != "nuit" or r != "herboriste" or not _potion_mort:
				return "Plus de potion de mort."
			if not vivant(cible):
				return "Choisis un vivant."
			_potion_mort = false
			_empoisonne = cible
			return ""
		"sauver":
			if phase != "nuit" or r != "herboriste" or not _potion_vie:
				return "Plus de potion de vie."
			if not victimes_attaque().has(cible):
				return "Cette personne n'a pas été attaquée."
			_potion_vie = false
			_sauve = cible
			return ""
		"lier":
			if phase != "nuit" or r != "entremetteuse" or _deja_lie():
				return "L'Entremetteuse ne lie qu'un seul couple."
			if cible == cible2 or not vivant(cible) or not vivant(cible2):
				return "Choisis deux vivants différents."
			_lier(cible, cible2)
			return ""
		"modele":
			if phase != "nuit" or r != "enfant" or joueurs[id]["modele"] > 0:
				return "L'Enfant sauvage a déjà choisi son modèle."
			if not vivant(cible) or cible == id:
				return "Choisis un autre joueur."
			joueurs[id]["modele"] = cible
			return ""
		"garder":
			if phase != "nuit" or r != "veilleur":
				return "Seul le Veilleur garde une porte, la nuit."
			if not vivant(cible):
				return "Choisis une maison habitée."
			if cible == _garde_prec:
				return "Tu as gardé cette porte la nuit dernière : choisis-en une autre."
			_garde = cible
			return ""
		"faux_bruit":
			if phase != "nuit" or r != "souffleur" or _souffles <= 0:
				return "Plus de faux bruit."
			_souffles -= 1
			return ""
		"examiner":
			if phase != "jour" or r != "fossoyeur":
				return "Le Fossoyeur examine les morts le jour."
			if _examine_ce_jour:
				return "Un examen par jour."
			if not joueurs.has(cible) or vivant(cible):
				return "On n'examine que les morts."
			_examine_ce_jour = true
			evenements.append({"type": "examen", "pour": id, "cible": cible, "loup": est_loup(cible)})
			return ""
	return "Action inconnue."


func _lier(a: int, b: int) -> void:
	joueurs[a]["amoureux"] = b
	joueurs[b]["amoureux"] = a
	evenements.append({"type": "amoureux", "pour": a, "cible": b})
	evenements.append({"type": "amoureux", "pour": b, "cible": a})


# ---------------------------------------------------------------- victoire

## En dessous de 3 joueurs, personne ne gagne : la meute serait victorieuse dès son tirage (seul,
## on est le loup ; à deux, un contre un). On visite, on essaie jour et nuit, jusqu'à quitter.
const SEUIL_VICTOIRE := 3


## "" tant que la partie continue ; sinon village, meute, solitaire, amoureux ou personne.
func victoire() -> String:
	if not loups_tires:
		return ""
	var v := vivants()
	if v.is_empty():
		return "personne"
	if joueurs.size() < SEUIL_VICTOIRE:
		return ""
	var couple := _couple_interdit()
	if v.size() == 2 and couple.size() == 2 and v.has(couple[0]) and v.has(couple[1]):
		return "amoureux"
	if v.size() == 1 and role(v[0]) == "solitaire":
		return "solitaire"
	if chasseurs().is_empty():
		return "village"
	var meute := 0
	var loups_meute := 0
	for id in v:
		if camp(id) == Roles.MEUTE:
			meute += 1
			if est_loup(id):
				loups_meute += 1
	if loups_meute > 0 and meute >= v.size() - meute:
		return "meute"
	return ""


func gagnants(camp_gagnant: String) -> Array[int]:
	var g: Array[int] = []
	for id in joueurs:
		if camp(id) == camp_gagnant:
			g.append(id)
	return g


# ---------------------------------------------------------------- indices des tâches

## Un indice pour le joueur qui a fini une tâche. Saboté, il est faux.
## {texte, sorte, noms|cible|nombre} : `indice_est_vrai` sait le vérifier.
func indice_tache(pour: int, sabotee: bool) -> Dictionary:
	var loups := chasseurs()
	var autres: Array[int] = []
	for id in vivants():
		if not est_loup(id) and id != pour:
			autres.append(id)
	var sortes := ["trois", "innocent", "nombre"]
	var sorte: String = sortes[_rng.randi_range(0, 2)]
	if sorte == "trois" and (loups.is_empty() or autres.size() < 3):
		sorte = "nombre"
	if sorte == "innocent" and (autres.is_empty() or (sabotee and loups.is_empty())):
		sorte = "nombre"
	match sorte:
		"trois":
			var noms: Array[int] = []
			if sabotee:
				var pris := autres.duplicate()
				_melanger(pris)
				noms.assign(pris.slice(0, 3))
			else:
				noms.append(loups[_rng.randi_range(0, loups.size() - 1)])
				var pris := autres.duplicate()
				_melanger(pris)
				noms.append_array(pris.slice(0, 2))
				_melanger(noms)
			return {"sorte": "trois", "ids": noms,
				"texte": "Un loup dort chez %s, %s ou %s." % [nom(noms[0]), nom(noms[1]), nom(noms[2])]}
		"innocent":
			var c: int = loups[_rng.randi_range(0, loups.size() - 1)] if sabotee else autres[_rng.randi_range(0, autres.size() - 1)]
			return {"sorte": "innocent", "cible": c, "texte": "%s n'est pas un loup." % nom(c)}
	var n := loups.size()
	if sabotee:
		n = n + 1 if n <= 1 or _rng.randf() < 0.5 else n - 1
	return {"sorte": "nombre", "nombre": n,
		"texte": ("La meute compte encore %d loups." if n > 1 else "La meute compte encore %d loup.") % n}


func indice_est_vrai(ind: Dictionary) -> bool:
	match ind["sorte"]:
		"trois":
			for id in ind["ids"]:
				if est_loup(id) and vivant(id):
					return true
			return false
		"innocent":
			return not est_loup(ind["cible"])
	return ind["nombre"] == chasseurs().size()


# ---------------------------------------------------------------- indices des quêtes

## Un indice gagné à une quête : toujours VRAI (le mensonge passe par les joueurs, pas par le jeu),
## tiré au hasard dans le niveau. `participants` : ceux qui ont fait la quête.
## {sorte, texte, …} : `indice_est_vrai` sait le vérifier (tests).
func indice_quete(niveau: String, participants: Array) -> Dictionary:
	if not loups_tires:
		return {"sorte": "aucun", "texte": "Personne n'est encore loup : le mal s'éveillera cette nuit, parmi ceux qui n'ont pas de rôle."}
	var loups := chasseurs()
	if loups.is_empty():
		return {"sorte": "aucun", "texte": "Les bois sont calmes : plus aucun loup ne rôde."}
	var innocents: Array[int] = []
	for id in vivants():
		if not est_loup(id):
			innocents.append(id)
	var dans := 0
	for id in participants:
		if est_loup(id) and vivant(id):
			dans += 1
	var c: Array[Dictionary] = []
	match niveau:
		"simple":
			# (« il reste au moins un loup » est retiré : vrai tant que la partie dure, il n'apprenait rien.)
			if dans < loups.size():
				c.append({"sorte": "pas_tous", "ids": participants.duplicate(),
					"texte": "Les loups ne sont pas tous parmi ceux qui ont fait cette quête."})
			var m: int = joueurs[loups[_rng.randi_range(0, loups.size() - 1)]]["maison"]
			var demi := joueurs.size() / 2
			var moitie := 0 if m < demi else 1
			c.append({"sorte": "moitie", "moitie": moitie, "demi": demi,
				"texte": "Un loup dort du côté %s du village (maisons %s à %s)." % [["levant", "couchant"][moitie],
					_num(0 if moitie == 0 else demi), _num(demi - 1 if moitie == 0 else joueurs.size() - 1)]})
		"normal":
			c.append({"sorte": "dans_quete", "ids": participants.duplicate(), "oui": dans > 0,
				"texte": "Au moins un loup a participé à cette quête." if dans > 0 else "Aucun loup n'a participé à cette quête."})
			c.append({"sorte": "nombre", "nombre": loups.size(),
				"texte": ("La meute compte encore %d loups." if loups.size() > 1 else "La meute compte encore %d loup.") % loups.size()})
			var m2: int = joueurs[loups[_rng.randi_range(0, loups.size() - 1)]]["maison"]
			c.append({"sorte": "parite", "pair": (m2 + 1) % 2 == 0,
				"texte": "Un loup dort dans une maison au numéro %s." % ("pair" if (m2 + 1) % 2 == 0 else "impair")})
			if not innocents.is_empty():
				var x: int = innocents[_rng.randi_range(0, innocents.size() - 1)]
				c.append({"sorte": "innocent", "cible": x, "texte": "%s n'est pas un loup." % nom(x)})
			if _role_tenu("liseuse"):
				c.append({"sorte": "liseuse", "oui": _liseuse_a_vu_loup,
					"texte": "La Liseuse a déjà lu l'âme d'un loup." if _liseuse_a_vu_loup else "La Liseuse n'a encore jamais vu de loup."})
		_:
			c.append({"sorte": "nb_quete", "ids": participants.duplicate(), "nombre": dans,
				"texte": ("Exactement %d loups ont participé à cette quête." if dans > 1 else "Exactement %d loup a participé à cette quête.") % dans})
			if innocents.size() >= 2:
				var pris := innocents.duplicate()
				_melanger(pris)
				var ids: Array[int] = [loups[_rng.randi_range(0, loups.size() - 1)], pris[0], pris[1]]
				_melanger(ids)
				c.append({"sorte": "trois", "ids": ids,
					"texte": "Un loup dort chez %s, %s ou %s." % [nom(ids[0]), nom(ids[1]), nom(ids[2])]})
			if not innocents.is_empty():
				var ids2: Array[int] = [loups[_rng.randi_range(0, loups.size() - 1)], innocents[_rng.randi_range(0, innocents.size() - 1)]]
				_melanger(ids2)
				c.append({"sorte": "deux", "ids": ids2,
					"texte": "L'un de ces deux est un loup : %s ou %s." % [nom(ids2[0]), nom(ids2[1])]})
			if _role_tenu("vampire"):
				c.append({"sorte": "vampire", "oui": _morsure_faite,
					"texte": "Le loup vampire a déjà mordu quelqu'un." if _morsure_faite else "Le loup vampire n'a encore mordu personne."})
			var couple := _couple_interdit()
			if _deja_lie():
				c.append({"sorte": "lies", "interdit": not couple.is_empty(),
					"texte": "Un loup est lié à un villageois." if not couple.is_empty() else "Deux âmes sont liées, et aucune n'est loup… ou toutes deux le sont."})
	return c[_rng.randi_range(0, c.size() - 1)]


func _num(i: int) -> String:
	return Ronde.numero(i)


func _role_tenu(r: String) -> bool:
	for id in joueurs:
		if joueurs[id]["role"] == r:
			return true
	return false


## Vrai si l'indice de quête dit toujours vrai (pour les tests).
func indice_quete_vrai(ind: Dictionary) -> bool:
	var loups := chasseurs()
	match ind["sorte"]:
		"aucun":
			return loups.is_empty()
		"reste":
			return not loups.is_empty()
		"pas_tous":
			for l in loups:
				if not (ind["ids"] as Array).has(l):
					return true
			return false
		"moitie":
			for l in loups:
				if int(joueurs[l]["maison"] >= int(ind.get("demi", 6))) == ind["moitie"]:
					return true
			return false
		"dans_quete", "nb_quete":
			var n := 0
			for id in ind["ids"]:
				if est_loup(id) and vivant(id):
					n += 1
			return (n > 0) == ind["oui"] if ind["sorte"] == "dans_quete" else n == ind["nombre"]
		"nombre":
			return loups.size() == ind["nombre"]
		"parite":
			for l in loups:
				if ((joueurs[l]["maison"] + 1) % 2 == 0) == ind["pair"]:
					return true
			return false
		"innocent":
			return not est_loup(ind["cible"])
		"liseuse":
			return _liseuse_a_vu_loup == ind["oui"]
		"trois", "deux":
			for id in ind["ids"]:
				if est_loup(id) and vivant(id):
					return true
			return false
		"vampire":
			return _morsure_faite == ind["oui"]
		"lies":
			return (not _couple_interdit().is_empty()) == ind["interdit"]
	return false
