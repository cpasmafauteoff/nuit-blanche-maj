class_name PorteVoix
extends RefCounted
## Porte d'émission du micro. Avant : chaque bloc de 40 ms sous le seuil était jeté, donc chaque
## creux entre deux syllabes laissait un trou, et le récepteur entendait une radio qui hache.
## Maintenant la porte reste ouverte un moment après la dernière parole (maintien).

var maintien := 0.28
var _reste := 0.0


## `niveau` du bloc, `seuil`, `duree` du bloc en secondes. Vrai : ce bloc doit partir.
func ouvert(niveau: float, seuil: float, duree: float) -> bool:
	if niveau > seuil:
		_reste = maintien
	else:
		_reste = maxf(_reste - duree, 0.0)
	return _reste > 0.0


func fermer() -> void:
	_reste = 0.0
