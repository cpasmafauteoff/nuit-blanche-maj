class_name Invites
extends RefCounted
## L'invite du bas (« E ») ne dit plus une phrase : sa touche + UN mot sur ce qu'elle fait, selon la cible
## regardée (Edwin, 01/11 : « E Livre », « E Écouter »). Règle pure, sans scène : on lit le texte
## d'action (« {agir} : prendre le carnet de… ») et on en tire le mot, en français ; l'écran le traduit.

## Le texte après les deux-points, sans la touche (« Maintiens {agir} : écarter… » → « écarter… »).
static func _reste(invite: String) -> String:
	var i := invite.find(":")
	return (invite.substr(i + 1) if i >= 0 else invite).strip_edges().to_lower()


## Le mot (français, capitalisé) de cette action ; "" si l'action n'est pas reconnue.
static func mot(invite: String) -> String:
	var r := _reste(invite)
	if r.begins_with("donner"):
		return "Donner"
	if r.begins_with("prendre"):
		return "Page" if "page" in r else "Livre"
	if r.begins_with("ramasser"):
		return "Caillou"
	if r.begins_with("hanter"):
		return "Hanter"
	if r.begins_with("apparaître"):
		return "Apparaître"
	if r.begins_with("t'asseoir"):
		return "S'asseoir"
	if r.begins_with("lire le tableau"):
		return "Tableau"
	if r.begins_with("ouvrir") or r.begins_with("fermer"):
		return "Porte"
	if r.begins_with("examiner"):
		return "Examiner"
	if r.begins_with("désigner"):
		return "Désigner"
	if r.begins_with("rouvrir ton carnet"):
		return "Carnet"
	if r.begins_with("choisir"):
		return "Choisir"
	if r.begins_with("sortir"):
		return "Sortir"
	if r.begins_with("écarter le rideau"):
		return "Rideau"
	if r.begins_with("la bougie"):
		return "Bougie"
	if r.begins_with("écouter"):
		return "Écouter"
	if r.begins_with("mordre"):
		return "Mordre"
	return ""


## Tous les mots possibles (pour les traductions et le test).
const MOTS := ["Donner", "Page", "Livre", "Caillou", "Hanter", "Apparaître", "S'asseoir", "Tableau", "Porte",
	"Examiner", "Désigner", "Carnet", "Choisir", "Sortir", "Rideau", "Bougie", "Écouter", "Mordre"]
