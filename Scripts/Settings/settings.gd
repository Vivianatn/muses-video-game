extends Node

## Les paramètres du joueur, chargé en autoload sous le nom "Settings".
## Ils sont appliqués au lancement du jeu et enregistrés à chaque changement
## dans user://settings.cfg (à part des sauvegardes : ils valent pour toutes
## les parties).
##
## Usage :
##     Settings.set_fullscreen(true)
##     Settings.set_master_volume(0.5)

const PATH := "user://settings.cfg"

## Plein écran ou fenêtré.
var fullscreen: bool = false
## Volume général, de 0 (muet) à 1.
var master_volume: float = 1.0


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		fullscreen = config.get_value("video", "fullscreen", fullscreen)
		master_volume = config.get_value("audio", "master_volume", master_volume)
	_apply()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply()
	_save()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply()
	_save()


func _apply() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	var master := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(master, master_volume <= 0.0)
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(master_volume, 0.0001)))


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("audio", "master_volume", master_volume)
	config.save(PATH)
