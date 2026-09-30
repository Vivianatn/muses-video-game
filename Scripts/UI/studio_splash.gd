extends Control

## L'intro du studio Tharros, toute première scène du jeu : la vidéo du logo,
## puis un fondu vers l'écran titre. Une touche, un clic ou un bouton de la
## manette la passe.
##
## Pendant la vidéo, l'écran titre se charge en arrière-plan : il s'affiche
## sans attente dès qu'elle se termine.
##
## La scène est dans le groupe "title_screen", comme l'écran titre : le menu
## du jeu ne s'y ouvre pas et rien n'y est sauvegardé.

## La scène qui suit l'intro.
@export_file("*.tscn") var next_scene: String = "res://Scenes/UI/title_screen.tscn"
## Durée (s) du fondu vers l'écran titre.
@export var fade_time: float = 0.6
## Durée (s) du fondu quand le joueur passe la vidéo.
@export var skip_fade_time: float = 0.25

@onready var _video: VideoStreamPlayer = %Video
@onready var _veil: ColorRect = %Veil

var _leaving: bool = false


func _ready() -> void:
	# L'interface bouge au rythme de l'affichage : hors interpolation physique.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# Fond par défaut « nuit » jusqu'au jeu : une image sans scène (pendant un
	# changement de scène) ne peut plus faire de flash gris. L'écran titre
	# rétablit la couleur du projet en partant vers le jeu.
	RenderingServer.set_default_clear_color(Muses.NUIT)
	ResourceLoader.load_threaded_request(next_scene)
	_video.finished.connect(_leave.bind(fade_time))
	_video.play()


## Jeu quitté pendant l'intro : on récupère quand même l'écran titre chargé en
## arrière-plan, sans quoi Godot le signale comme perdu à la fermeture.
func _exit_tree() -> void:
	if not _leaving:
		ResourceLoader.load_threaded_get(next_scene)


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventJoypadButton and event.pressed) \
			or (event is InputEventMouseButton and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		_leave(skip_fade_time)


## Fondu au noir de la vidéo, puis l'écran titre (qui fait sa propre entrée).
##
## Pas de change_scene_to_packed : il retire l'intro une image avant
## d'installer la suivante, et cette image vide se voyait comme un flash.
## L'écran titre est donc posé par-dessus l'intro (même fond nuit que le
## voile), qui ne s'en va qu'après.
func _leave(duration: float) -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(_veil, ^"color:a", 1.0, duration)
	await tween.finished
	_video.visible = false
	_video.stop()
	var scene := ResourceLoader.load_threaded_get(next_scene) as PackedScene
	if scene == null:
		scene = load(next_scene) as PackedScene
	var next := scene.instantiate()
	get_tree().root.add_child(next)
	get_tree().current_scene = next
	queue_free()
