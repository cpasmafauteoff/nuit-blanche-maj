class_name Apparitions
extends RefCounted
## Le screamer des fantômes (apparaître en monstre devant un vivant) : un fantôme ne peut effrayer un même
## vivant qu'UNE fois par cycle jour + nuit (Edwin, 03/11 : « il peut spammer trop de fois le screamer »).
## `deja` : {"fantome:vivant" -> numéro du jour de la dernière frayeur}. Testé dans tests/test_apparitions.gd.


static func _cle(fantome: int, vivant: int) -> String:
	return "%d:%d" % [fantome, vivant]


## Ce fantôme peut-il encore effrayer ce vivant dans ce cycle ?
static func peut(deja: Dictionary, fantome: int, vivant: int, jour: int) -> bool:
	return int(deja.get(_cle(fantome, vivant), -1)) != jour


## Parmi les témoins d'une apparition, ceux qui n'ont pas encore été effrayés par ce fantôme ce cycle.
static func restants(deja: Dictionary, fantome: int, temoins: Array, jour: int) -> Array:
	return temoins.filter(func(v): return peut(deja, fantome, int(v), jour))


## Note que ces vivants viennent d'être effrayés par ce fantôme.
static func noter(deja: Dictionary, fantome: int, temoins: Array, jour: int) -> void:
	for v in temoins:
		deja[_cle(fantome, int(v))] = jour
