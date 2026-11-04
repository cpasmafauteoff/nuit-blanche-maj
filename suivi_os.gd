class_name SuiviOs
extends SkeletonModifier3D
## Passe après l'animation : le villageois y pose ce que la webcam voit (bras, jambes, buste)
## et efface la tête du mannequin, remplacée par le visage animé.

var bouille: Node


func _process_modification_with_delta(_delta: float) -> void:
	if bouille:
		bouille.modifier_os(get_skeleton())
