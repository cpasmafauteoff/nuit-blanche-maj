class_name CodecVoix
extends RefCounted
## Codec de la voix : IMA ADPCM 4 bits, mono 8000 Hz.
## Chaque paquet se décode SEUL : 3 octets d'en-tête (prédicteur int16 LE + index de pas)
## puis 2 échantillons par octet. 40 ms = 320 échantillons = 163 octets.

const TAUX := 8000
const ENTETE := 3

const _PAS: Array[int] = [
	7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
	50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230,
	253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963,
	1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327,
	3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442,
	11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794,
	32767,
]
const _DELTA_INDEX: Array[int] = [-1, -1, -1, -1, 2, 4, 6, 8]


## Un échantillon -1..1 -> int16.
static func _vers_int16(v: float) -> int:
	return clampi(roundi(v * 32767.0), -32768, 32767)


## Applique un code de 4 bits : renvoie (nouveau prédicteur, nouvel index).
static func _avancer(pred: int, index: int, code: int) -> Vector2i:
	var pas: int = _PAS[index]
	var diff := pas >> 3
	if code & 4:
		diff += pas
	if code & 2:
		diff += pas >> 1
	if code & 1:
		diff += pas >> 2
	if code & 8:
		pred -= diff
	else:
		pred += diff
	pred = clampi(pred, -32768, 32767)
	index = clampi(index + _DELTA_INDEX[code & 7], 0, 88)
	return Vector2i(pred, index)


static func encoder(echantillons: PackedFloat32Array) -> PackedByteArray:
	var sortie := PackedByteArray()
	var n := echantillons.size()
	if n == 0:
		return sortie
	var pred := _vers_int16(echantillons[0])
	var index := _index_depart(echantillons)
	sortie.resize(ENTETE + (n + 1) / 2)
	sortie.encode_s16(0, pred)
	sortie[2] = index
	var octet := 0
	for i in range(n):
		var diff := _vers_int16(echantillons[i]) - pred
		var code := 0
		if diff < 0:
			code = 8
			diff = -diff
		var pas: int = _PAS[index]
		if diff >= pas:
			code |= 4
			diff -= pas
		if diff >= pas >> 1:
			code |= 2
			diff -= pas >> 1
		if diff >= pas >> 2:
			code |= 1
		var etat := _avancer(pred, index, code)
		pred = etat.x
		index = etat.y
		if i % 2 == 0:
			octet = code
		else:
			sortie[ENTETE + i / 2] = octet | (code << 4)
	if n % 2 == 1:
		sortie[ENTETE + n / 2] = octet
	return sortie


## Index de pas de départ, estimé sur le début du paquet (le paquet doit se décoder seul,
## sans avoir « chauffé » l'adaptation sur les précédents).
static func _index_depart(e: PackedFloat32Array) -> int:
	var m := mini(e.size() - 1, 16)
	if m < 1:
		return 0
	var somme := 0.0
	for i in range(m):
		somme += absf(e[i + 1] - e[i])
	var cible := somme / m * 32767.0
	var idx := 0
	while idx < 88 and _PAS[idx] < cible:
		idx += 1
	return idx


static func decoder(donnees: PackedByteArray) -> PackedFloat32Array:
	var sortie := PackedFloat32Array()
	if donnees.size() <= ENTETE:
		return sortie
	var pred := donnees.decode_s16(0)
	var index := clampi(donnees[2], 0, 88)
	var n := (donnees.size() - ENTETE) * 2
	sortie.resize(n)
	for i in range(n):
		var octet := donnees[ENTETE + i / 2]
		var code := (octet >> 4) if i % 2 == 1 else (octet & 15)
		var etat := _avancer(pred, index, code)
		pred = etat.x
		index = etat.y
		sortie[i] = pred / 32768.0
	return sortie


## Interpolation linéaire. Sans filtre : suffisant pour la voix (< 4 kHz utile).
static func reechantillonner(src: PackedFloat32Array, de_hz: int, vers_hz: int) -> PackedFloat32Array:
	var sortie := PackedFloat32Array()
	if src.is_empty() or de_hz <= 0 or vers_hz <= 0:
		return sortie
	if de_hz == vers_hz:
		return src.duplicate()
	var n := int(float(src.size()) * vers_hz / de_hz)
	sortie.resize(n)
	var pas := float(de_hz) / float(vers_hz)
	var dernier := src.size() - 1
	if pas > 1.5:
		# Réduction (48 kHz -> 8 kHz) : sans filtre, les aigus se replient dans la voix (grésillement
		# de radio). Moyenne glissante sur la largeur d'un pas = passe-bas simple avant l'échantillonnage.
		var demi := int(pas * 0.5)
		for i in range(n):
			var c := int(i * pas + pas * 0.5)
			var a := maxi(c - demi, 0)
			var b := mini(c + demi, dernier)
			var somme := 0.0
			for k in range(a, b + 1):
				somme += src[k]
			sortie[i] = somme / float(b - a + 1)
		return sortie
	for i in range(n):
		var pos := i * pas
		var k := mini(int(pos), dernier)
		var f := pos - k
		var b := src[mini(k + 1, dernier)]
		sortie[i] = src[k] + (b - src[k]) * f
	return sortie


## Niveau RMS 0..1.
static func niveau(echantillons: PackedFloat32Array) -> float:
	if echantillons.is_empty():
		return 0.0
	var somme := 0.0
	for v in echantillons:
		somme += v * v
	return sqrt(somme / echantillons.size())
