class_name MiniJeu
extends RefCounted
## Un mini-jeu de quête, côté HÔTE : il décide de tout. Les joueurs n'envoient que des actions
## (`action`) et chacun reçoit SA vue (`vue_pour`), décrite en données que `VueQuete` dessine.
## Aucun nœud, aucun affichage ici : tout se teste sans moteur (cf. tests/test_quetes.gd).
##
## Pour écrire un jeu : hériter, surcharger `demarrer`, `action`, `avancer` (appeler super),
## `vue_pour` et `bot`, et marquer `_reussis[id] = true` pour chaque joueur qui réussit SA part.
## L'équipe réussit si assez de joueurs ont réussi (Quetes.seuil) : c'est le meneur qui compte.
##
## Le sabotage est permis aux seuls `saboteurs` (des loups, à partir du jour 2) : un jeu ne
## montre son geste de sabotage qu'à eux, et ce geste doit être DISCRET (rien ne dit à l'écran
## des autres qui l'a fait).
##
## La vue : {"consigne": String, "blocs": [bloc…]} ; le titre et le temps restant sont ajoutés
## par le meneur. Les blocs que sait dessiner VueQuete :
##   {"t": "texte", "v": String, "taille": int = 20, "ton": "" | "or" | "gris" | "rouge" | "vert"}
##   {"t": "boutons", "v": [{"l": String, "a": Dictionary, "off": bool, "ton": String}], "taille": int = 22}
##       un clic envoie `a` comme action ; les touches 1 à 9 cliquent les neuf premiers.
##   {"t": "jauge", "v": float 0..1, "l": String, "zone": [min, max] (facultatif), "ton": String}
##   {"t": "tenir", "l": String}            la main saisit / lâche (MondeQuete) : {"tenir": true/false}
##   {"t": "rame", "l": String}             la main tient une rame : chaque coup tiré vers soi envoie {"rame": true}
##       (sans regarder la rame : on a les yeux sur la rivière, cf. Radeau)
##   {"t": "rythme", "periode": float, "phase": float 0..1, "l": String}
##       un battement qui tourne ; un coup de main (corde tirée, manivelle en haut) envoie {"coup": true, "phase": phase vue}
##   {"t": "yeux", "l": String}             envoie {"yeux": true/false} (fermés) : la caméra, ou
##       Espace tenu sans caméra
##   {"t": "grille", "l": int, "h": int, "v": String (l*h caractères), "clic": bool}
##       . vide, # vase, o lanterne, @ toi, * un équipier, ? inconnu, X arrivée, ~ eau, ^ rocher ;
##       un clic envoie {"case": index} si "clic"
##   {"t": "pont", ...}                     des données pour le décor du pont (planches, rafale…), rien à l'écran

var ids: Array[int] = []
var niveau := "simple"
var saboteurs: Array[int] = []
var noms := {}                  # id -> nom, pour les vues
var rng := RandomNumberGenerator.new()
var temps := 0.0
var duree := 90.0
var fini := false
## Ce que disent les bots (ils ne parlent pas) : [[id, texte]] ; le meneur le vide et l'affiche.
var paroles: Array = []
## La règle du jour, tirée au hasard dans `demarrer` (« miroir », « deux grimoires »…) : son nom
## s'affiche avec le titre, et la consigne l'explique. "" = la règle de base.
var variante := ""
## Le joueur qui a pris le rôle unique du jeu (marcheur, guide, lecteur : cf. Quetes.ROLES_UNIQUES)
## en se mettant dans la zone, ou -1 : le jeu tire alors au hasard. Posé par le meneur avant `demarrer`.
var elu := -1
## La clairière où se joue la quête (0, 1 ou 2) : un jeu qui place un objet du côté opposé à l'entrée en a besoin.
var clairiere := 0
var _reussis := {}
## Les jeux où un joueur marche POUR DE VRAI dans la clairière (Lanternes : le marcheur) : l'hôte
## lit ses pieds (`pieds`, id -> position locale à la clairière, y compris les bots) avant chaque
## `avancer`, et le jeu demande en retour de faire marcher un bot (`deplacements`) ou de replacer un
## joueur tombé (`rappels`). Vides pour tous les autres jeux.
var pieds := {}
var deplacements: Array = []     # [[id, Vector3 locale]] : un bot (ou un pilote auto) marche jusque-là
var rappels: Array = []          # [[id, Vector3 locale, Vector3 regard]] : on replace ce joueur (chute)
## Le jeu change des joueurs de place ET de mode (le pont : le suivant monte sur les planches, celui qui a fini
## ou qui est tombé retourne tenir sa corde à son poste) : [[id, Vector3 locale, Vector3 regard locale,
## mode ("libre" = il marche, "poste" = cloué à sa place), délai en secondes]]. L'hôte les exécute (bots compris).
var placements: Array = []
## Les joueurs hantés par un fantôme : id -> le moment (temps) où ça leur est arrivé.
var hantes := {}
## Niveau dur : 3 vies PARTAGÉES par l'équipe (Quetes.VIES_DUR). Chaque faute du jeu (cf. `perdre_vie`)
## en coûte une à tout le monde ; à 0, la quête échoue sur-le-champ. -1 : pas de compteur commun.
## Les jeux qui ont déjà leurs propres vies (Coffre, Chaudron, Lanternes, Radeau) les règlent par
## niveau eux-mêmes et ne s'en servent pas.
var vies_equipe := -1
var vies_equipe_max := -1
var _vies_epuisees := false
## Un humain a envoyé au moins une action : sans cela, les bots seuls ne peuvent pas perdre la dernière
## vie avant `Quetes.duree_min` (cf. RythmeHumain). Posé par l'hôte quand une personne agit.
var humain_a_agi := false


## Les vies restantes d'un compteur après une faute (cf. RythmeHumain.vies_apres_faute).
func vies_apres(restantes: int) -> int:
	return RythmeHumain.vies_apres_faute(restantes, temps, niveau, humain_a_agi)


## À appeler au début de `demarrer` des jeux qui n'ont pas leurs propres vies.
func _init_vies() -> void:
	vies_equipe_max = Quetes.vies_equipe(niveau)
	vies_equipe = vies_equipe_max


## Une faute de l'équipe : une vie de moins (niveau dur seulement). À 0, la quête échoue tout de
## suite. Rend vrai si c'était la dernière.
func perdre_vie() -> bool:
	if vies_equipe_max <= 0 or fini:
		return false
	vies_equipe = vies_apres(vies_equipe)
	if vies_equipe > 0:
		return false
	_vies_epuisees = true
	terminer()
	return true


## Ajoute à la vue d'un joueur les vies de l'équipe : pour le décor (`vies`, `vies_max`) et, quand le
## jeu utilise le compteur commun, une ligne du parchemin. Les jeux à vies propres ont déjà posé
## `vies_max` dans leur vue : on n'y touche pas.
func ajouter_vies(v: Dictionary) -> void:
	if vies_equipe_max <= 0 or v.has("vies_max"):
		return
	v["vies"] = vies_equipe
	v["vies_max"] = vies_equipe_max
	var rondes := "●".repeat(vies_equipe) + "○".repeat(vies_equipe_max - vies_equipe)
	if v.has("blocs"):
		(v["blocs"] as Array).append(texte("Vies de l'équipe : %s  (à 0, la quête échoue)" % rondes, 16, "rouge" if vies_equipe <= 1 else "or"))


## Prépare la partie. Le meneur a déjà rempli ids, niveau, saboteurs, noms et la graine de rng.
func demarrer() -> void:
	pass


func action(_id: int, _d: Dictionary) -> void:
	pass


## Ce joueur marche-t-il pour de vrai (il n'est pas cloué à son poste) ?
func a_pied(_id: int) -> bool:
	return false


## Où il commence, en local à la clairière (ceux qui marchent seulement).
func depart_locale(_id: int) -> Vector3:
	return Vector3.ZERO


## Vers où il regarde au départ (local à la clairière), ou Vector3.ZERO : le regard de son poste.
func regard_depart(_id: int) -> Vector3:
	return Vector3.ZERO


func avancer(delta: float) -> void:
	if fini:
		return
	temps += delta
	if temps >= duree:
		terminer()


func vue_pour(_id: int) -> Dictionary:
	return {"consigne": "", "blocs": []}


## Tout ce qui existe dans CETTE partie, pour ce thème (les runes de la pierre, les ingrédients
## de la réserve…) : {"titre": String, "v": [String]}, la même liste pour tous. Le parchemin
## l'écrit en bas : un menteur ment avec un nom qui existe, personne n'invente. {} : rien.
func liste() -> Dictionary:
	return {}


## Un bot participant joue (appelé à chaque image de l'hôte). Il réussit souvent, pas toujours ;
## un bot saboteur sabote parfois.
func bot(_id: int, _delta: float) -> void:
	pass


## Un fantôme hante le joueur id (l'hôte a déjà vérifié son énergie). Chaque jeu fait ce qui
## l'embête le plus ; par défaut, un froid qui fait perdre 5 secondes à toute l'équipe.
## Rend ce qui est arrivé, en une phrase (pour le fantôme), ou "" s'il n'y avait rien à faire.
func hanter(id: int) -> String:
	if fini or not ids.has(id):
		return ""
	hantes[id] = temps
	return _hanter(id)


func _hanter(id: int) -> String:
	temps = minf(temps + 5.0, duree - 1.0)
	return "Un froid glacé saisit %s : 5 secondes envolées." % nom(id)


## Hanté il y a moins d'une seconde et demie (la vue le dit, pour secouer l'écran du joueur).
func vient_d_etre_hante(id: int) -> bool:
	return hantes.has(id) and temps - float(hantes[id]) < 1.5


func terminer() -> void:
	fini = true


func reussis() -> Array[int]:
	var r: Array[int] = []
	for id in ids:
		if _reussis.get(id, false):
			r.append(id)
	return r


## L'équipe a-t-elle réussi ? Par défaut : assez de joueurs ont réussi leur part (Quetes.seuil).
## Un jeu qui a d'autres règles (des vies, des serrures à ouvrir…) la surcharge, avec `seuil_requis`.
func equipe_reussit() -> bool:
	if _vies_epuisees:
		return false
	return Quetes.reussie(reussis().size(), ids.size(), niveau)


func seuil_requis() -> int:
	return Quetes.seuil(ids.size(), niveau)


func reste() -> float:
	return maxf(duree - temps, 0.0)


func peut_saboter(id: int) -> bool:
	return saboteurs.has(id)


func nom(id: int) -> String:
	return noms.get(id, "?")


## Tout le monde a fini sa part (réussie) : on peut s'arrêter avant la fin du temps.
func tous_reussis() -> bool:
	for id in ids:
		if not _reussis.get(id, false):
			return false
	return true


# ---------------------------------------------------------------- aides pour écrire les vues

## Côté CLIENT, à l'affichage : le texte d'une vue (écrit en français par l'hôte) dans la langue du joueur.
## Un gabarit ne traduit pas les éléments d'une LISTE de mots du jeu (« Ta suite : Lune · Soleil »,
## « Les lieux possibles : a, b », « Lune   ?   Soleil ») : on traduit alors chaque élément, puis le
## gabarit « préfixe + %s ». Une phrase qui contient des virgules n'est jamais découpée : il faut que
## TOUS ses morceaux soient des mots connus.
static func tr_vue(t: String) -> String:
	if t == "" or not Langue.en_anglais():
		return t
	for sep: String in [" · ", ", ", "   "]:
		if not t.contains(sep):
			continue
		var morceaux := t.split(sep)
		var prefixe := ""
		var k := morceaux[0].rfind(" : ")
		if k >= 0:
			prefixe = morceaux[0].substr(0, k + 3)
			morceaux[0] = morceaux[0].substr(k + 3)
		var sortie := PackedStringArray()
		var tous := true
		for m in morceaux:
			var en := Langue.t(m)
			if en == m and m.length() > 2 and not m.is_valid_int():
				tous = false
				break
			sortie.append(en)
		if not tous:
			continue
		var liste := sep.join(sortie)
		if prefixe == "":
			return liste
		var modele := Langue.t(prefixe + "%s")
		if modele != prefixe + "%s":
			return modele % liste
	return Langue.t(t)


static func texte(v: String, taille := 20, ton := "") -> Dictionary:
	return {"t": "texte", "v": v, "taille": taille, "ton": ton}


static func bouton(l: String, a: Dictionary, off := false, ton := "") -> Dictionary:
	return {"l": l, "a": a, "off": off, "ton": ton}


static func boutons(v: Array, taille := 22) -> Dictionary:
	return {"t": "boutons", "v": v, "taille": taille}


static func jauge(v: float, l: String, zone := [], ton := "") -> Dictionary:
	return {"t": "jauge", "v": clampf(v, 0.0, 1.0), "l": l, "zone": zone, "ton": ton}
