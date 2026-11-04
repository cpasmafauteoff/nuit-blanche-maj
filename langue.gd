class_name Langue
extends RefCounted
## La langue du jeu : français (source) ou anglais. Voir `langues/traduction_en.gd`.
## Réglage « langue/choix » des Options : "auto" (langue du système), "fr" ou "en".

const CHOIX := [["auto", "Automatique / Automatic"], ["fr", "Français"], ["en", "English"]]

static var _trad: TraductionEN = null


## Appelée au démarrage, puis à chaque changement du réglage.
static func appliquer(choix: String) -> void:
	_assurer()
	TranslationServer.set_locale(code_de(choix))


static func _assurer() -> void:
	if _trad != null:
		return
	_trad = TraductionEN.new()
	_trad.locale = "en"
	_trad.charger(EnTextes.sources())
	TranslationServer.add_translation(_trad)


## À la fermeture du jeu : la traduction quitte le serveur avant d'être libérée (sinon Godot plante en
## sortant, le serveur gardant une traduction déjà détruite).
static func liberer() -> void:
	if _trad == null:
		return
	TranslationServer.remove_translation(_trad)
	_trad = null


## "auto" → langue du système : français si le système est en français, anglais sinon.
static func code_de(choix: String) -> String:
	if choix == "fr" or choix == "en":
		return choix
	return "fr" if OS.get_locale_language() == "fr" else "en"


static func code() -> String:
	return "en" if TranslationServer.get_locale().begins_with("en") else "fr"


static func en_anglais() -> bool:
	return code() == "en"


static func nom_choix(c: String) -> String:
	for x: Array in CHOIX:
		if x[0] == c:
			return x[1]
	return c


## Traduit un texte français dans la langue courante (pour ce qui n'est pas un Label : dessin, titre de fenêtre…).
static func t(texte: String) -> String:
	if texte == "":
		return texte
	return TranslationServer.translate(texte)


## Le texte anglais d'un texte français, sans regarder la langue courante (pour les tests).
static func en_de(texte: String) -> String:
	_assurer()
	return _trad.traduire(texte)


static func traduction() -> TraductionEN:
	_assurer()
	return _trad
