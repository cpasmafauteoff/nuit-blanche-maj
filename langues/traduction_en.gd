class_name TraductionEN
extends Translation
## La traduction anglaise de Nuit Blanche. Le français est la langue SOURCE : la clé, c'est le texte
## français lui-même (comme dans le code). Godot appelle `_get_message` pour tout texte d'un Label, d'un
## Button, d'un Label3D… et pour tout `tr()`. On cherche :
##   1. le texte exact ;
##   2. un gabarit (« La personne au bandeau %s est élue maire. »), dont on traduit aussi les valeurs ;
##   3. ligne par ligne, pour les textes assemblés avec des retours à la ligne.
## Ce qui vient de l'hôte reste donc en français sur le réseau et chaque joueur le lit dans SA langue.

var _exact := {}          # français -> anglais
var _gabarits: Array = [] # [{parts, types, en_parts, poids}], les plus longs d'abord
var _cache := {}
var _profondeur := 0


func charger(sources: Array) -> void:
	_exact.clear()
	_gabarits.clear()
	_cache.clear()
	for src: Variant in sources:
		var d: Dictionary = src
		for fr: String in d:
			var en: String = d[fr]
			if en == "":
				continue
			_exact[fr] = en
			if _a_des_valeurs(fr):
				var g := _compiler(fr, en)
				if not g.is_empty():
					_gabarits.append(g)
	# Les plus précis d'abord : ceux qui se terminent par du texte fixe avant ceux qui finissent par un %s
	# (« La personne au bandeau %s » avalerait toute la phrase), puis par poids décroissant.
	_gabarits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var oa: bool = (a.parts as Array).back() == ""
		var ob: bool = (b.parts as Array).back() == ""
		if oa != ob:
			return not oa
		return a.poids > b.poids)


## Ce texte a-t-il une traduction (exacte, par gabarit, ou ligne à ligne) ?
func a_une(s: String) -> bool:
	var coeur := s.strip_edges()
	if _exact.has(s) or _exact.has(coeur):
		return true
	if _gabarit(coeur) != "":
		return true
	if "
" in coeur:
		for l in coeur.split("
"):
			if l.strip_edges() != "" and not a_une(l):
				return false
		return true
	return false


func entrees() -> Dictionary:
	return _exact


func nombre() -> int:
	return _exact.size()


func gabarits() -> int:
	return _gabarits.size()


static func _a_des_valeurs(s: String) -> bool:
	var i := s.find("%")
	while i >= 0 and i + 1 < s.length():
		if s[i + 1] == "%":
			i = s.find("%", i + 2)
			continue
		return true
	return false


## Découpe « a %s b %d c » en parts ["a ", " b ", " c"] et types ["s", "d"]. `%%` devient `%`.
static func decouper(s: String) -> Dictionary:
	var parts: Array = []
	var types: Array = []
	var cur := ""
	var i := 0
	while i < s.length():
		var c := s[i]
		if c == "%" and i + 1 < s.length():
			if s[i + 1] == "%":
				cur += "%"
				i += 2
				continue
			var j := i + 1
			while j < s.length() and s[j] in "+-#0123456789.":
				j += 1
			if j < s.length() and s[j] in "sdfxX":
				parts.append(cur)
				types.append(s[j])
				cur = ""
				i = j + 1
				continue
		cur += c
		i += 1
	parts.append(cur)
	return {"parts": parts, "types": types}


static func _compiler(fr: String, en: String) -> Dictionary:
	var a := decouper(fr)
	var b := decouper(en)
	if (a.types as Array).size() != (b.types as Array).size() or (a.types as Array).is_empty():
		return {}
	var poids := 0
	for p: String in a.parts:
		poids += p.length()
	if poids < 3:
		return {}
	return {"parts": a.parts, "types": a.types, "en_parts": b.parts, "en_types": b.types, "poids": poids}


func _get_message(src: StringName, _contexte: StringName) -> StringName:
	var s := String(src)
	if s.length() < 2:
		return &""
	var r := traduire(s)
	return StringName(r) if r != s else &""


func traduire(s: String) -> String:
	if _cache.has(s):
		return _cache[s]
	var r := _traduire(s)
	if _cache.size() > 20000:
		_cache.clear()
	_cache[s] = r
	return r


func _traduire(s: String) -> String:
	if _exact.has(s):
		return _exact[s]
	if _profondeur > 3:
		return s
	# Espaces et retours en bordure : on traduit le coeur.
	var coeur := s.strip_edges()
	if coeur != s and coeur != "":
		var i0 := s.find(coeur)
		return s.substr(0, i0) + traduire(coeur) + s.substr(i0 + coeur.length())
	var g := _gabarit(s)
	if g != "":
		return g
	if "\n" in s:
		var lignes := s.split("\n")
		var sortie := PackedStringArray()
		var change := false
		for l in lignes:
			var t := traduire(l) if l != "" else l
			change = change or t != l
			sortie.append(t)
		if change:
			return "\n".join(sortie)
	return s


func _gabarit(s: String) -> String:
	for g: Dictionary in _gabarits:
		var vals := _essayer(g, s)
		if vals.size() == (g.types as Array).size() and not vals.is_empty():
			_profondeur += 1
			var out := ""
			var parts: Array = g.en_parts
			for k in parts.size():
				out += parts[k]
				if k < vals.size():
					out += traduire(vals[k]) if _traduisible(vals[k], g.types[k]) else vals[k]
			_profondeur -= 1
			return out
	return ""


static func _traduisible(v: String, type: String) -> bool:
	return type == "s" and v.length() > 1


## Les valeurs du texte pour ce gabarit, ou [] si le texte n'y colle pas.
static func _essayer(g: Dictionary, s: String) -> Array:
	var parts: Array = g.parts
	var types: Array = g.types
	var debut: String = parts[0]
	var fin: String = parts[parts.size() - 1]
	if not s.begins_with(debut) or not s.ends_with(fin) or s.length() < debut.length() + fin.length():
		return []
	var pos := debut.length()
	var limite := s.length() - fin.length()
	var vals: Array = []
	for k in types.size():
		var suivant: String = parts[k + 1]
		var fin_val: int
		if k == types.size() - 1:
			fin_val = limite
		else:
			fin_val = s.find(suivant, pos)
			if fin_val < 0 or fin_val + suivant.length() > limite:
				return []
		if fin_val < pos:
			return []
		var v := s.substr(pos, fin_val - pos)
		var t: String = types[k]
		if t == "d" and not v.strip_edges().is_valid_int():
			return []
		if (t == "f") and not v.strip_edges().is_valid_float():
			return []
		# Un gabarit ne s'étend pas sur plusieurs lignes (sauf s'il en contient lui-même) : ce sont alors
		# les lignes qui se traduisent une à une.
		if "\n" in v and not _multiligne(parts):
			return []
		if v == "" and t != "s":
			return []
		vals.append(v)
		pos = fin_val + (suivant.length() if k < types.size() - 1 else 0)
	return vals

static func _multiligne(parts: Array) -> bool:
	for p: String in parts:
		if "\n" in p:
			return true
	return false
