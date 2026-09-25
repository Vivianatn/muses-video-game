extends Resource
class_name DialogueLine

## Une réplique de dialogue : qui parle, ce qui est dit, et ce qui se passe
## ensuite. C'est la brique de base d'une ressource Dialogue.

@export_group("Contenu")
## Nom affiché au-dessus de la boîte. Vide = pas d'en-tête.
@export var speaker: String = ""
## Le texte affiché. Le BBCode est accepté : [b]gras[/b], [i]italique[/i],
## [color=red]…[/color], [shake]…[/shake], etc.
@export_multiline var text: String = ""

@export_group("Apparence")
## Portrait affiché à gauche. Vide = celui déclaré dans la distribution de la
## DialogueBox pour ce `speaker`, sinon aucun.
@export var portrait: Texture2D = null
## Couleur du nom. Alpha à 0 = celle de la distribution, sinon la couleur par
## défaut de la boîte.
@export var speaker_color: Color = Color(0, 0, 0, 0)
## Vitesse de frappe en caractères/seconde, uniquement pour cette réplique.
## 0 = la vitesse par défaut de la boîte.
@export var type_speed: float = 0.0

@export_group("Enchaînement")
## Étiquette de cette réplique, cible possible d'un `goto`.
@export var id: StringName = &""
## Saut vers une autre étiquette après cette réplique (ignoré s'il y a des
## choix). Vide = on passe simplement à la réplique suivante.
@export var goto: StringName = &""
## Enchaîner tout seul après X secondes, sans attendre le joueur. 0 = attendre.
@export var auto_advance: float = 0.0
## Options proposées au joueur. Dès qu'il y en a, la boîte attend un choix.
@export var choices: Array[DialogueChoice] = []

@export_group("Événement")
## Nom émis par DialogueManager.event au moment où la réplique s'affiche.
@export var event: StringName = &""
## Argument libre transmis avec l'événement.
@export var event_arg: String = ""


## Vrai si la réplique n'existe que pour déclencher un événement ou un saut :
## elle est alors traversée sans rien afficher.
func is_silent() -> bool:
	return text.strip_edges().is_empty() and choices.is_empty()
