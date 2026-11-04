class_name PanneauExclusion
extends PanelContainer
## La petite fenêtre du vote d'exclusion : visible de tous les humains, en haut à droite. Elle ne
## coupe ni la marche ni la tête ; on répond par les touches (Options : « exclusion_oui » et
## « exclusion_non ») ou au clic quand la souris est libre (Alt, pause, salon).
## Règles : regles/exclusion.gd. Ici, seulement l'affichage.

signal repond(oui: bool)

const OR := Color(1.0, 0.82, 0.5)

var _titre: Label
var _decompte: Label
var _aide: Label
var _oui: Button
var _non: Button
var _reste := 0.0
var _ouvert := false
var _mon_vote := -1        # -1 pas encore, 0 non, 1 oui
var _peut_voter := false
var _id_vote := -1         # (cible, demandeur) : un nouveau vote remet ma réponse à zéro


func _init() -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.035, 0.035, 0.9)
	st.border_color = Color(0.85, 0.16, 0.08, 0.85)
	st.set_border_width_all(1)
	st.border_width_left = 4
	st.set_corner_radius_all(8)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 12
	for cote in ["left", "right", "top", "bottom"]:
		st.set("content_margin_" + cote, 16)
	add_theme_stylebox_override("panel", st)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_left = -24
	offset_right = -24
	offset_top = 110
	custom_minimum_size.x = 360
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	_titre = _etiquette(20, OR)
	_titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_titre.custom_minimum_size.x = 328
	v.add_child(_titre)
	_decompte = _etiquette(17, Color(1, 1, 1, 0.8))
	_decompte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_decompte.custom_minimum_size.x = 328
	v.add_child(_decompte)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	_oui = Button.new()
	_oui.pressed.connect(func(): _repondre(true))
	_non = Button.new()
	_non.pressed.connect(func(): _repondre(false))
	Options.lier_texte(_oui, "  Oui ({exclusion_oui})  ")
	Options.lier_texte(_non, "  Non ({exclusion_non})  ")
	h.add_child(_oui)
	h.add_child(_non)
	v.add_child(h)
	_aide = _etiquette(14, Color(1, 1, 1, 0.55))
	_aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aide.custom_minimum_size.x = 328
	v.add_child(_aide)


func _etiquette(taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func ouvert() -> bool:
	return _ouvert


## Un état reçu de l'hôte ({} : le vote est fini). `moi` : mon identifiant ; `libelle` : comment
## nommer un joueur (bandeau en partie, pseudo au salon).
func maj(etat: Dictionary, moi: int, libelle: Callable) -> void:
	if etat.is_empty():
		_ouvert = false
		visible = false
		_id_vote = -1
		return
	var cle := int(etat["cible"]) * 100003 + int(etat["demandeur"])
	if cle != _id_vote:
		_id_vote = cle
		_mon_vote = 1 if int(etat["demandeur"]) == moi else -1
	_ouvert = true
	visible = true
	_reste = float(etat["reste"])
	var cible := int(etat["cible"])
	_peut_voter = (etat["electeurs"] as Array).has(moi)
	_titre.text = "Exclure %s ?" % str(libelle.call(cible)) if cible != moi else "Un vote d'exclusion te vise."
	_decompte.text = "Demandé par %s · %d oui, %d non · il en faut %d" % [
		str(libelle.call(int(etat["demandeur"]))), int(etat["oui"]), int(etat["non"]), int(etat["besoin"])]
	_rafraichir()


func _rafraichir() -> void:
	_oui.visible = _peut_voter
	_non.visible = _peut_voter
	_oui.disabled = _mon_vote == 1
	_non.disabled = _mon_vote == 0
	if _peut_voter:
		_aide.text = Options.avec_touches("Tu peux changer ta réponse jusqu'au bout. Un silence compte « non ». Alt : libérer la souris.")
	else:
		_aide.text = "Tu ne votes pas."


func _repondre(oui: bool) -> void:
	if not _peut_voter or not _ouvert:
		return
	_mon_vote = 1 if oui else 0
	_rafraichir()
	repond.emit(oui)


## Une touche (Oui / Non) : vrai si elle a été prise.
func touche(oui: bool) -> bool:
	if not _ouvert or not _peut_voter:
		return false
	_repondre(oui)
	return true


func _process(delta: float) -> void:
	if not _ouvert:
		return
	_reste = maxf(0.0, _reste - delta)
	var base := _decompte.text.get_slice("\n", 0)
	_decompte.text = "%s\n%d s" % [base, ceili(_reste)]
