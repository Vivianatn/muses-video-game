extends Control

## L'écran titre, première scène du jeu : nouvelle partie, continuer la
## dernière sauvegarde, paramètres, quitter.
##
## La scène est dans le groupe "title_screen" : GameMenu ne s'y ouvre pas et
## SaveGame n'y fait ni temps de jeu ni sauvegarde automatique.
##
## Le contenu des paramètres (écran, son, commandes) est une SettingsView,
## la même que dans le menu en jeu : elle est ajoutée en code au-dessus du
## bouton Retour.

## Le niveau lancé par « Nouvelle partie ».
@export_file("*.tscn") var first_level: String = "res://Scenes/Levels/scene_test.tscn"

@onready var _menu: Control = %Menu
@onready var _start: Button = %Start
@onready var _continue: Button = %Continue
@onready var _parameters: Button = %Parameters
@onready var _quit: Button = %Quit

@onready var _settings: Control = %SettingsPanel
@onready var _back: Button = %Back

var _settings_view: SettingsView


func _ready() -> void:
	_start.pressed.connect(_on_start)
	_continue.pressed.connect(_on_continue)
	_parameters.pressed.connect(_open_settings)
	_quit.pressed.connect(get_tree().quit)

	_settings_view = SettingsView.new()
	_back.add_sibling(_settings_view)
	_back.get_parent().move_child(_settings_view, _back.get_index())
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.custom_minimum_size.x = 200
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
	# Afficher l'état actuel sans le réenregistrer.
	_settings_view.refresh()
	_menu.visible = false
	_settings.visible = true
	_settings_view.focus_first()


func _close_settings() -> void:
	_settings.visible = false
	_menu.visible = true
	_parameters.grab_focus()


## Évite de lancer deux fois la partie en appuyant plusieurs fois.
func _set_buttons_disabled(disabled: bool) -> void:
	for button: Button in [_start, _continue, _parameters, _quit]:
		button.disabled = disabled
