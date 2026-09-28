extends Resource
class_name SkillData

## La fiche d'une compétence du joueur (une mécanique : dash, double saut...).
## Une fiche par compétence, rangée dans res://Skills/ (clic droit → Nouvelle
## ressource → SkillData) : l'autoload Skills les charge toutes au démarrage.

## Identifiant, utilisé par le code (Skills.has(&"dash")) et les sauvegardes.
## Ne le change plus une fois le jeu distribué.
@export var id: StringName = &""
## Nom affiché dans l'onglet Compétences.
@export var display_name: String = ""
## Texte affiché quand la compétence est sélectionnée.
@export_multiline var description: String = ""
## Image de la compétence. Facultative.
@export var icon: Texture2D = null
## Actions (Projet → Paramètres du projet → Contrôles) dont on affiche la
## touche : clavier ou manette selon ce qui est branché.
@export var actions: Array[StringName] = []
## Acquise dès le début de la partie. Sinon, elle se débloque en jeu avec
## Skills.unlock(&"id").
@export var unlocked_at_start: bool = true
## Ordre d'affichage : les plus petits en premier.
@export var sort_order: int = 0
