extends Resource
class_name ItemData

## La fiche d'un objet : ce que l'inventaire affiche et ce qu'il sait en faire.
## Une fiche par objet, rangée dans res://Items/ (clic droit → Nouvelle
## ressource → ItemData) : l'autoload Inventory les charge toutes au démarrage.

## Identifiant unique, utilisé par le code et les sauvegardes. Ne le change
## plus une fois le jeu distribué : les sauvegardes existantes le perdraient.
@export var id: StringName = &""
## Nom affiché dans l'inventaire.
@export var display_name: String = ""
## Texte affiché quand l'objet est sélectionné.
@export_multiline var description: String = ""
## Image de la case d'inventaire.
@export var icon: Texture2D = null
## Quantité maximale qu'on peut porter. 0 = pas de limite.
@export var max_count: int = 0
## Ordre d'affichage dans l'inventaire : les plus petits en premier.
@export var sort_order: int = 0

@export_group("Dialogues")
## Variable de dialogue tenue à jour avec la quantité possédée, pour que les
## PNJ puissent en parler : {connaissances}, [si connaissances >= 3].
## Vide = pas de variable.
@export var dialogue_var: StringName = &""
