class_name SynchroVues
extends RefCounted
## Les plans de caméra lents qui défilent derrière la scène de synchronisation : le village vu de
## haut, le seuil d'une maison, la pierre du Conseil… Chaque plan dure PLAN_S, avec un fondu au noir
## à chaque bord. Tout est fonction du temps écoulé : rien à stocker, rien à resynchroniser.

const PLAN_S := 6.5
const FONDU_S := 0.9
const NB_PLANS := 5


static func numero(t: float) -> int:
	return int(maxf(t, 0.0) / PLAN_S)


## L'opacité du noir : 1 au début et à la fin de chaque plan, 0 entre les deux.
static func fondu(t: float) -> float:
	var local := fposmod(t, PLAN_S)
	if local < FONDU_S:
		return 1.0 - local / FONDU_S
	if local > PLAN_S - FONDU_S:
		return (local - (PLAN_S - FONDU_S)) / FONDU_S
	return 0.0


## La pose de la caméra à l'instant t.
static func vue(t: float) -> Transform3D:
	var k := numero(t)
	var u := fposmod(t, PLAN_S) / PLAN_S      # 0..1 dans le plan
	var n := maxi(Ronde.NB_MAISONS, 1)
	var pos := Vector3.ZERO
	var but := Vector3.ZERO
	match k % NB_PLANS:
		0, 4:
			# Au-dessus des toits, qui tourne lentement autour de la place.
			var a := (0.6 if k % NB_PLANS == 0 else 3.9) + u * 0.5
			var d := Vector3(sin(a), 0, cos(a))
			pos = d * Ronde.R_PLACE * 0.6 + Vector3(0, 7.5, 0)
			but = -d * (Ronde.R_MAISON + 4.0) + Vector3(0, 3.0, 0)
		1, 3:
			# Le seuil d'une maison, vu de la place, qui avance doucement vers elle.
			var i := (n / 4 if k % NB_PLANS == 1 else (n * 3) / 4) % n
			var p := Ronde.depart(i)
			var d := Vector3(p.x, 0, p.z).normalized()
			pos = d * (Ronde.R_PLACE * 0.5 + u * 2.5) + Vector3(0, 1.7, 0)
			but = d * (Ronde.R_MAISON + 1.0) + Vector3(0, 3.2, 0)
		_:
			# La pierre du Conseil, d'un peu loin, qui se laisse contourner.
			var c := Ronde.PIERRE
			var a := 1.3 + u * 0.6
			pos = c + Vector3(sin(a), 0, cos(a)) * 9.0 + Vector3(0, 2.4 - u * 0.4, 0)
			but = c + Vector3(0, 0.3, 0)
	if pos.distance_to(but) < 0.01:
		but = pos + Vector3.FORWARD
	return Transform3D(Basis.IDENTITY, pos).looking_at(but, Vector3.UP)
