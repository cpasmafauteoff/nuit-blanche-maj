## GENERE par generer.py : la liste des fichiers de traduction anglaise.
class_name EnTextes
extends RefCounted

static func sources() -> Array:
	return [
		preload("res://langues/en_00-glossaire.gd").T,
		preload("res://langues/en_10-principal.gd").T,
		preload("res://langues/en_20-hote.gd").T,
		preload("res://langues/en_30-menus.gd").T,
		preload("res://langues/en_40-boutique.gd").T,
		preload("res://langues/en_50-quetes.gd").T,
		preload("res://langues/en_60-ecran.gd").T,
	]
