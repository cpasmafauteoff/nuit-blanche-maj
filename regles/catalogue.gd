class_name Catalogue
extends RefCounted
## Tout ce qui existe dans le jeu, thème par thème. Une quête en tire sa part au hasard ; la liste
## complète est écrite dans le décor (menhirs, étagère) et celle du jour sur le parchment : un
## menteur peut toujours citer quelque chose de crédible, et personne ne se trahit en inventant
## un nom qui n'existe pas.

const RUNES := ["Lune", "Soleil", "Corbeau", "Loup", "Chêne", "Croix noire", "Œil", "Clé",
	"Serpent", "Couronne", "Flamme", "Goutte", "Épée", "Plume", "Crâne", "Étoile",
	"Main", "Cerf", "Tour", "Rose", "Hibou", "Ancre", "Spirale", "Cloche"]

const INGREDIENTS := ["Ortie", "Champignon noir", "Baie de sureau", "Plume de corbeau",
	"Mousse humide", "Racine de mandragore", "Toile d'araignée", "Os de souris", "Sel gris",
	"Fleur de lune", "Ail sauvage", "Écorce de bouleau", "Bave de crapaud", "Aile de chauve-souris",
	"Œil de triton", "Pétale de pavot", "Gland de chêne", "Cendre de foyer", "Larme de cire",
	"Dent de loup", "Sang de cerf", "Poil de chat noir", "Lierre grimpant", "Cire d'abeille",
	"Belladone", "Sauge", "Thym des morts", "Corne de bouc", "Écaille de serpent",
	"Rosée du matin", "Suie de cheminée", "Miel sauvage", "Pierre de lune pilée",
	"Queue de lézard", "Fiel de brochet", "Noix de galle", "Sève de pin", "Graine de pavot",
	"Cheveu de pendu", "Eau de source"]

## Les lieux où l'on fuit la Dame blanche : chacun est un repère VRAIMENT bâti autour du
## cimetière (decor_dame.gd, même ordre), avec son nom sur une plaque. REPERES[k] est le nom
## gravé, LIEUX[k] la façon de le dire (« Elle va derrière la grande tombe ! »).
const REPERES := ["La grande tombe", "L'arbre mort", "La croix penchée", "La stèle brisée",
	"Le tertre", "Les bougies", "Le vieux puits", "La souche", "Le rocher moussu", "La clôture",
	"Le caveau", "La lanterne", "Les racines", "Le banc de pierre", "La dalle fendue",
	"Le vieux coffre", "Les fougères", "Le seau renversé", "Le tas de pierres", "Le grand rocher"]
const LIEUX := ["derrière la grande tombe", "au pied de l'arbre mort", "contre la croix penchée",
	"près de la stèle brisée", "sur le tertre", "vers les bougies", "au vieux puits",
	"derrière la souche", "contre le rocher moussu", "le long de la clôture", "devant le caveau",
	"sous la lanterne", "dans les racines", "au banc de pierre", "sur la dalle fendue",
	"près du vieux coffre", "dans les fougères", "près du seau renversé",
	"derrière le tas de pierres", "derrière le grand rocher"]


## n éléments tirés d'une liste, sans doublon, dans un ordre au hasard (indices dans la liste).
static func tirer(liste: Array, n: int, rng: RandomNumberGenerator) -> Array[int]:
	var pool: Array = range(liste.size())
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var x: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = x
	var r: Array[int] = []
	for k in mini(n, pool.size()):
		r.append(int(pool[k]))
	return r
