extends Control

## L'écran titre, première scène du jeu : nouvelle partie, continuer la
## dernière sauvegarde, paramètres, quitter.
##
## La scène est dans le groupe "title_screen" : GameMenu ne s'y ouvre pas et
## SaveGame n'y fait ni temps de jeu ni sauvegarde automatique.

## Le niveau lancé par « Nouvelle partie ».
@export_file("*.tscn") var first_level: String = "res://Scenes/Levels/scene_test.tscn"

@onready var _menu: Control = %Menu
@onready var _start: Button = %Start
@onready var _continue: Button = %Continue
@onready var _parameters: Button = %Parameters
@onready var _quit: Button = %Quit

@onready var _settings: Control = %SettingsPanel
@onready var _fullscreen: CheckButton = %Fullscreen
@onready var _volume: HSlider = %Volume
@onready var _back: Button = %Back


func _ready() -> void:
	_start.pressed.connect(_on_start)
	_continue.pressed.connect(_on_continue)
	_parameters.pressed.connect(_open_settings)
	_quit.pressed.connect(get_tree().quit)

	_fullscreen.toggled.connect(Settings.set_fullscreen)
	_volume.value_changed.connect(Settings.set_master_volume)
	_back.pressed.connect(_close_settings)

	# « Continuer » n'apparaît que s'il existe une sauvegarde.
	_continue.visible = SaveGame.latest_slot() != -1
	_settings.visible = false
	# Sans bouton sélectionné, la manette ne peut rien faire.
	(_continue if _continue.visible else _start).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _settings.visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"menu_back")):
		get_viewport().set_input_as_handled()
		_close_settings()


func _on_start() -> void:
	_set_buttons_disabled(true)
	SaveGame.new_game()
	get_tree().change_scene_to_file(first_level)


func _on_continue() -> void:
	_set_buttons_disabled(true)
	var ok: bool = await SaveGame.load_slot(SaveGame.latest_slot())
	# En cas d'échec on reste ici (GameMenu affiche le message d'erreur).
	if not ok:
		_set_buttons_disabled(false)
		_continue.grab_focus()


func _open_settings() -> void:
	# set_value_no_signal : afficher l'état actuel sans le réenregistrer.
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)
	_volume.set_value_no_signal(Settings.master_volume)
	_menu.visible = false
	_settings.visible = true
	_fullscreen.grab_focus()


func _close_settings() -> void:
	_settings.visible = false
	_menu.visible = true
	_parameters.grab_focus()


## Évite de lancer deux fois la partie en appuyant plusieurs fois.
func _set_buttons_disabled(disabled: bool) -> void:
	for button: Button in [_start, _continue, _parameters, _quit]:
		button.disabled = disabled
