class_name IndiceQuete
extends CanvasLayer
## L'indication, en toutes lettres, de ce que ma main peut faire dans une quête jouée à la souris
## (viser une molette, prendre un pot…) : une ligne discrète en bas de l'écran, au-dessus de la
## touche d'action. Les gestes à la souris n'ont pas de touche : on dit quoi faire.

var _label: Label


func _init() -> void:
	layer = 1   # sous l'écran (2), la pause (3) : jamais devant un menu
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.add_theme_font_override("font", Style.police("italique"))
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.8, 0.92))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.offset_top = -170
	_label.offset_bottom = -130
	add_child(_label)


## Écrit le texte (en français ; le gabarit est traduit ici, puis les `%s` remplis par `args`) ; "" l'efface.
func ecrire(texte: String, args: Array = []) -> void:
	if texte == "":
		_label.text = ""
		return
	var t := Langue.t(texte)
	_label.text = t % args if not args.is_empty() else t
