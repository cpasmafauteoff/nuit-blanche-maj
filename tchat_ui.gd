class_name TchatUI
extends VBoxContainer
## Le tchat écrit du lobby : les messages en haut, le champ de saisie en bas, Entrée envoie.
## Un seul exemplaire vit pendant tout le lobby ; l'écran du salon le reprend à chaque rafraîchissement.

signal envoye(texte: String)

const OR := Color(1.0, 0.82, 0.5)
const MESSAGES_MAX := 80

var _journal: RichTextLabel
var _champ: LineEdit
var _nb := 0


func _init() -> void:
	add_theme_constant_override("separation", 8)
	_journal = RichTextLabel.new()
	_journal.bbcode_enabled = true
	_journal.scroll_following = true
	_journal.selection_enabled = false
	_journal.focus_mode = Control.FOCUS_NONE
	_journal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_journal.custom_minimum_size = Vector2(0, 120)
	_journal.add_theme_font_size_override("normal_font_size", 18)
	_journal.add_theme_font_size_override("bold_font_size", 18)
	_journal.add_theme_color_override("default_color", Color(1, 1, 1, 0.9))
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0, 0, 0, 0.35)
	fond.set_corner_radius_all(4)
	for cote in ["left", "right", "top", "bottom"]:
		fond.set("content_margin_" + cote, 8)
	_journal.add_theme_stylebox_override("normal", fond)
	add_child(_journal)
	_champ = LineEdit.new()
	_champ.placeholder_text = "Écrire un message… (Entrée)"
	_champ.max_length = TchatLobby.LONGUEUR_MAX
	_champ.add_theme_font_size_override("font_size", 18)
	_champ.text_submitted.connect(_soumis)
	add_child(_champ)


func _soumis(texte: String) -> void:
	var t := TchatLobby.nettoyer(texte)
	_champ.clear()
	if t != "":
		envoye.emit(t)
	# L'entrée garde le focus : on peut enchaîner les messages.
	_champ.call_deferred("grab_focus")


## Un message reçu : « Pseudo : texte ». Les crochets ne s'interprètent jamais.
func ajouter(nom: String, texte: String) -> void:
	if _journal == null:
		return
	_nb += 1
	if _nb > MESSAGES_MAX:
		_journal.clear()
		_nb = 1
	_journal.append_text("[b][color=#%s]%s[/color][/b]  %s\n" % [OR.to_html(false), TchatLobby.echapper(nom), TchatLobby.echapper(texte)])


func vider() -> void:
	if _journal:
		_journal.clear()
	_nb = 0


func a_le_focus() -> bool:
	return _champ != null and _champ.has_focus()


func texte_saisi() -> String:
	return _champ.text if _champ else ""


func rendre_focus(texte: String) -> void:
	if _champ:
		_champ.text = texte
		_champ.grab_focus()
		_champ.caret_column = texte.length()
