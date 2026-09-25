extends Resource
class_name DialogueLine

## Une réplique de dialogue : qui parle, ce qui est dit, et ce qui se passe
## ensuite. C'est la brique de base d'une ressource Dialogue.

## Façons de modifier une variable de dialogue.
enum VarOp {
	## `$ nom = valeur` : remplace la valeur.
	SET,
	## `$ nom ?= valeur` : seulement si la variable n'existe pas encore. Sert
	## à donner une valeur de départ sans écraser ce qu'on a appris depuis.
	DEFAULT,
	## `$ nom += 1` : ajoute un nombre (compteur de visites, etc.).
	ADD,
}

## Nom tel qu'écrit dans le dialogue, avant remplacement des variables : pour
## `{vory}`, c'est « vory ». Rempli par l'autoload sur la copie affichée, pour
## que portraits et couleurs restent attachés au personnage quel que soit le
## nom sous lequel on le connaît.
var speaker_key: String = ""

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

@export_group("Condition")
## La réplique n'est jouée que si cette condition est vraie, sinon elle est
## sautée comme si elle n'existait pas (avec son texte, ses choix, son saut,
## sa variable, son événement). Vide = toujours jouée. Ex. « vory != Vory »,
## « visites >= 2 », « pas chemin_montre ». Voir DialogueManager.check().
@export var condition: String = ""

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

@export_group("Variable")
## Variable modifiée au moment où la réplique est atteinte. Vide = aucune.
## Voir DialogueManager.set_var() : les variables survivent d'une conversation
## à l'autre, et `{nom}` dans un texte ou un nom affiche leur valeur.
@export var var_name: StringName = &""
## Ce qu'on fait de la variable.
@export var var_op: VarOp = VarOp.SET
## La valeur (un nombre pour ADD). Peut elle-même contenir des `{nom}`.
@export var var_value: String = ""

@export_group("Conversation suivante")
## Choisit la conversation que le PNJ tiendra la prochaine fois qu'on lui
## parle : un rang (« 2 » = la deuxième de sa liste Dialogue Files), le nom
## d'un fichier (« vory_habituel »), ou « suivante ». Vide = rien à changer.
## Voir DialogueTrigger.request_next_dialogue().
@export var next_dialogue: String = ""

@export_group("Événement")
## Nom émis par DialogueManager.event au moment où la réplique s'affiche.
@export var event: StringName = &""
## Argument libre transmis avec l'événement.
@export var event_arg: String = ""


## Vrai si la réplique n'existe que pour déclencher un événement, un saut ou
## une variable :
## elle est alors traversée sans rien afficher.
func is_silent() -> bool:
	return text.strip_edges().is_empty() and choices.is_empty()
