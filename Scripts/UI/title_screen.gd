extends Control

## L'écran titre : nouvelle partie, continuer la dernière sauvegarde, charger
## une sauvegarde au choix, paramètres (dont le panneau des touches), quitter.
##
## La scène est dans le groupe "title_screen" : GameMenu ne s'y ouvre pas et
## SaveGame n'y fait ni temps de jeu ni sauvegarde automatique.

const Motion := preload("res://Scripts/UI/motion.gd")
const ResumeTransition := preload("res://Scripts/UI/resume_transition.gd")

## Le niveau lancé par « Nouvelle partie ».
@export_file("*.tscn") var first_level: String = "res://Scenes/Levels/scene_test.tscn"

@onready var _menu: Control = %Menu
@onready var _logo: Control = $Menu/Logo
@onready var _circuit: Control = $Menu/Circuit
@onready var _start: Button = %Start
@onready var _continue: Button = %Continue
@onready var _load: Button = %Load
@onready var _parameters: Button = %Parameters
@onready var _quit: Button = %Quit

@onready var _settings: Control = %SettingsPanel
@onready var _fullscreen: CheckButton = %Fullscreen
@onready var _volume: HSlider = %Volume
@onready var _back: Button = %Back
@onready var _controls_button: Button = %Controls
@onready var _controls = %ControlsPanel


func _ready() -> void:
	# L'interface bouge au rythme de l'affichage (tweens, _process) : on la
	# sort de l'interpolation physique, qui ne vaut que pour le monde.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_start.pressed.connect(_on_start)
	_continue.pressed.connect(_on_continue)
	_load.pressed.connect(_on_load)
	GameMenu.closed.connect(_on_load_list_closed)
	_parameters.pressed.connect(_open_settings)
	_quit.pressed.connect(get_tree().quit)

	_fullscreen.toggled.connect(Settings.set_fullscreen)
	# F11 change aussi le plein écran : l'interrupteur suit sans se relancer.
	Settings.fullscreen_changed.connect(_fullscreen.set_pressed_no_signal)
	_volume.value_changed.connect(Settings.set_master_volume)
	_back.pressed.connect(_close_settings)
	_controls_button.pressed.connect(_open_controls)
	_controls.closed.connect(_close_controls)

	# « Continuer » et « Charger » n'apparaissent que s'il existe une sauvegarde.
	_continue.visible = SaveGame.latest_slot() != -1
	_load.visible = _continue.visible
	_settings.visible = false
	# Un seul bouton principal par écran (DA) : l'action attendue, qui a aussi
	# la sélection. Sans bouton sélectionné, la manette ne peut rien faire.
	var primary := _continue if _continue.visible else _start
	for button: Button in [_start, _continue]:
		button.theme_type_variation = &"" if button == primary else &"BoutonSecondaire"
	primary.grab_focus()
	_intro()


## On part vers le jeu : la couleur de fond par défaut redevient celle du
## projet (l'intro studio l'avait passée en « nuit »), celle que les niveaux
## montrent en guise de ciel.
func _exit_tree() -> void:
	RenderingServer.set_default_clear_color(ProjectSettings.get_setting(&"rendering/environment/defaults/default_clear_color"))


## L'entrée en scène : le logo apparaît, la ligne d'énergie se trace et la
## pousse sort, puis les boutons arrivent un à un.
func _intro() -> void:
	_logo.modulate.a = 0.0
	_circuit.set(&"reveal", 0.0)
	var tween := create_tween()
	tween.tween_property(_logo, ^"modulate:a", 1.0, 0.7).set_delay(0.1)
	tween.parallel().tween_property(_circuit, ^"reveal", 1.0, 1.1).set_delay(0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var buttons: Array[Control] = []
	for button: Button in [_start, _continue, _load, _parameters, _quit]:
		if button.visible:
			buttons.append(button)
			button.modulate.a = 0.0
	await get_tree().create_timer(0.7).timeout
	Motion.cascade(buttons, Vector2(0, 16), 0.07, 0.35)


func _unhandled_input(event: InputEvent) -> void:
	if _settings.visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"menu_back")):
		get_viewport().set_input_as_handled()
		_close_settings()


func _on_start() -> void:
	_set_buttons_disabled(true)
	SaveGame.new_game()
	get_tree().change_scene_to_file(first_level)


## « Continuer » : la sauvegarde la plus récente.
func _on_continue() -> void:
	_resume(SaveGame.latest_slot())


## « Charger » : la liste des sauvegardes du menu du jeu, pour en choisir une.
func _on_load() -> void:
	GameMenu.open_load_picker(_resume)


## La liste refermée sans rien choisir : la sélection revient sur « Charger ».
func _on_load_list_closed() -> void:
	if not _load.disabled and is_inside_tree():
		_load.grab_focus.call_deferred()


## Le souvenir de la partie se ranime (voir resume_transition.gd), puis la
## sauvegarde `slot` se charge. Même transition pour Continuer et Charger.
func _resume(slot: int) -> void:
	_set_buttons_disabled(true)
	var transition := ResumeTransition.new()
	get_tree().root.add_child(transition)
	transition.failed.connect(_on_continue_failed)
	transition.play(slot, _menu)


## Chargement raté : on reste ici (GameMenu affiche le message d'erreur).
func _on_continue_failed() -> void:
	_set_buttons_disabled(false)
	_continue.grab_focus()


func _open_settings() -> void:
	# set_value_no_signal : afficher l'état actuel sans le réenregistrer.
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)
	_volume.set_value_no_signal(Settings.master_volume)
	_menu.visible = false
	_settings.visible = true
	Motion.pop_in(_settings)
	_fullscreen.grab_focus()


func _open_controls() -> void:
	_settings.visible = false
	_controls.open()


func _close_controls() -> void:
	_settings.visible = true
	Motion.pop_in(_settings)
	_controls_button.grab_focus()


func _close_settings() -> void:
	_settings.visible = false
	_menu.visible = true
	Motion.fade_in(_menu, 0.2)
	_parameters.grab_focus()


## Évite de lancer deux fois la partie en appuyant plusieurs fois.
func _set_buttons_disabled(disabled: bool) -> void:
	for button: Button in [_start, _continue, _load, _parameters, _quit]:
		button.disabled = disabled
