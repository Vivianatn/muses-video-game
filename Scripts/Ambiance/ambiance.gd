@tool
extends Node
class_name Ambiance
## L'ambiance visuelle d'un niveau : couleur du fond, lumière ambiante et
## post-traitement de l'image. On instancie une des scènes toutes prêtes à la
## racine du niveau :
##   Scenes/Ambiance/exterieur.tscn   ciel, soleil, rayons, couleurs chaudes
##   Scenes/Ambiance/souterrain.tscn  pénombre, lumières colorées mises en valeur
##
## L'effet est posé sur la couche 1 : il touche le monde, pas le HUD, les
## dialogues ni le menu (couches 5 et plus).
## Les réglages fins sont dans Effet/Ecran → Material → Shader Parameters.

## Couleur de fond du niveau (ce qui n'est couvert par aucun décor). En
## extérieur, le shader remplace exactement cette couleur par le ciel : la
## choisir différente de toutes les couleurs des décors.
@export var couleur_fond: Color = Color(0.302, 0.502, 0.6):
	set(value):
		couleur_fond = value
		_appliquer()
## Teinte multipliée sur tout le monde. Blanc = rien ne change. Sombre en
## souterrain : seules les lumières (Scenes/Ambiance/lumiere.tscn) éclairent.
@export var lumiere_ambiante: Color = Color.WHITE:
	set(value):
		lumiere_ambiante = value
		_appliquer()
## Coupe le post-traitement, pour comparer ou pour les petites configurations.
@export var effet_actif: bool = true:
	set(value):
		effet_actif = value
		_appliquer()

var _fond_precedent: Color


func _enter_tree() -> void:
	_fond_precedent = RenderingServer.get_default_clear_color()
	# Dans l'éditeur, on ne touche pas au fond de tout le projet.
	if not Engine.is_editor_hint():
		RenderingServer.set_default_clear_color(couleur_fond)


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		RenderingServer.set_default_clear_color(_fond_precedent)


func _ready() -> void:
	_appliquer()


func _appliquer() -> void:
	if not is_inside_tree():
		return
	var modulate := get_node_or_null(^"CanvasModulate") as CanvasModulate
	if modulate != null:
		modulate.color = lumiere_ambiante
	var ecran := get_node_or_null(^"Effet/Ecran") as ColorRect
	if ecran != null:
		ecran.visible = effet_actif
		var material := ecran.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter(&"couleur_fond", Vector3(couleur_fond.r, couleur_fond.g, couleur_fond.b))
	if not Engine.is_editor_hint():
		RenderingServer.set_default_clear_color(couleur_fond)
