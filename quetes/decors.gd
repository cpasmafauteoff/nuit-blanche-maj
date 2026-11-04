class_name Decors
extends RefCounted
## Le décor de chaque quête (cf. DecorQuete). Un jeu sans décor à lui garde l'établi gravé.

const SCRIPTS := {
	"runes": "res://quetes/decors/decor_runes.gd",
	"pont": "res://quetes/decors/decor_pont.gd",
	"coffre": "res://quetes/decors/decor_coffre.gd",
	"dame": "res://quetes/decors/decor_dame.gd",
	"lanternes": "res://quetes/decors/decor_lanternes.gd",
	"cloches": "res://quetes/decors/decor_cloches.gd",
	"chaudron": "res://quetes/decors/decor_chaudron.gd",
	"puits": "res://quetes/decors/decor_puits.gd",
	"moulin": "res://quetes/decors/decor_moulin.gd",
	"balance": "res://quetes/decors/decor_balance.gd",
	"radeau": "res://quetes/decors/decor_radeau.gd",
	"incendie": "res://quetes/decors/decor_incendie.gd",
}


static func creer(jeu: String) -> DecorQuete:
	var chemin: String = SCRIPTS.get(jeu, "")
	if chemin != "" and ResourceLoader.exists(chemin):
		var s: GDScript = load(chemin)
		if s and s.can_instantiate():
			return s.new()
	return DecorQuete.new()
