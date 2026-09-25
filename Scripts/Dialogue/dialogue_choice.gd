extends Resource
class_name DialogueChoice

## Une option proposée au joueur au bas d'une réplique.
## Voir DialogueLine.choices.

## Le texte affiché sur le bouton.
@export var text: String = ""

## Étiquette (`:: nom`) vers laquelle sauter quand ce choix est retenu.
## Laisse vide pour simplement continuer à la réplique suivante.
@export var goto: StringName = &""

## Nom d'événement émis par DialogueManager.event quand ce choix est retenu.
## C'est par là que le dialogue agit sur le jeu (donner un objet, ouvrir une
## porte, lancer une quête...). Laisse vide si le choix ne fait rien.
@export var event: StringName = &""

## Argument libre transmis avec l'événement.
@export var event_arg: String = ""
