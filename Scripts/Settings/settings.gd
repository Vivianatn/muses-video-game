extends Node

## Les paramètres du joueur, chargé en autoload sous le nom "Settings".
## Ils sont appliqués au lancement du jeu et enregistrés à chaque changement
## dans user://settings.cfg (à part des sauvegardes : ils valent pour toutes
## les parties).
##
## Usage :
##     Settings.set_fullscreen(true)
##     Settings.set_master_volume(0.5)
##     Settings.set_key(&"jump", 0, event)   # touche principale du saut
##     Settings.set_pad(&"jump", event)      # bouton de manette du saut
##
## F11 (action toggle_fullscreen) bascule le plein écran partout, menus et
## pause compris.
##
## Touches : chaque action du jeu (Projet → Paramètres du projet → Contrôles,
## sauf les ui_* de Godot) peut être réaffectée. Seules les actions changées
## sont enregistrées ; les autres suivent les valeurs du projet.

## Le plein écran vient de changer (menu Paramètres ou F11).
signal fullscreen_changed(fullscreen: bool)
## Une touche vient d'être réaffectée, ou toutes remises par défaut.
signal controls_changed

const PATH := "user://settings.cfg"

## Plein écran ou fenêtré.
var fullscreen: bool = false
## Volume général, de 0 (muet) à 1.
var master_volume: float = 1.0

## Les touches d'origine de chaque action, lues dans le projet au lancement.
var _default_controls: Dictionary[StringName, Array] = {}


func _ready() -> void:
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			_default_controls[action] = InputMap.action_get_events(action)

	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		fullscreen = config.get_value("video", "fullscreen", fullscreen)
		master_volume = config.get_value("audio", "master_volume", master_volume)
		if config.has_section("controls"):
			for action in config.get_section_keys("controls"):
				var saved: Variant = config.get_value("controls", action)
				if InputMap.has_action(action) and saved is Array:
					_set_events(action, _decode_all(saved))
	_apply()
	# F11 doit marcher même jeu en pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_choose_physics_interpolation()


## L'interpolation physique lisse le mouvement sur un écran plus rapide que la
## physique (120, 144 Hz...), où sans elle le personnage avancerait par à-coups.
## Sur un écran à 60 Hz, chaque image a déjà son pas de physique : elle n'y
## ajouterait que de petites irrégularités. On ne l'active donc qu'au besoin.
## L'interface (menus, HUD, dialogues) en est exclue de toute façon.
func _choose_physics_interpolation() -> void:
	var refresh := DisplayServer.screen_get_refresh_rate()
	get_tree().physics_interpolation = refresh > Engine.physics_ticks_per_second + 1.0


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		get_viewport().set_input_as_handled()
		set_fullscreen(not fullscreen)


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply()
	_save()
	fullscreen_changed.emit(fullscreen)


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply()
	_save()


# --- Touches --------------------------------------------------------------

## Les actions réaffectables, dans l'ordre du projet.
func remappable_actions() -> Array[StringName]:
	var actions: Array[StringName] = []
	actions.assign(_default_controls.keys())
	return actions


## Les touches du clavier d'une action, dans l'ordre (principale d'abord).
func key_events(action: StringName) -> Array[InputEventKey]:
	var keys: Array[InputEventKey] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			keys.append(event)
	return keys


## Le bouton (ou l'axe) de manette d'une action, ou null.
func pad_event(action: StringName) -> InputEvent:
	for event in InputMap.action_get_events(action):
		if _is_pad(event):
			return event
	return null


## Remplace la touche n° `slot` du clavier d'une action ; null l'efface. Un
## `slot` au-delà des touches existantes en ajoute une.
func set_key(action: StringName, slot: int, event: InputEventKey) -> void:
	var keys := key_events(action)
	var others: Array[InputEvent] = []
	for existing in InputMap.action_get_events(action):
		if existing is not InputEventKey:
			others.append(existing)

	var clean: InputEventKey = null
	if event != null:
		clean = _clean(event) as InputEventKey
	if slot < keys.size():
		if clean != null:
			keys[slot] = clean
		else:
			keys.remove_at(slot)
	elif clean != null:
		keys.append(clean)

	var events: Array[InputEvent] = []
	events.append_array(keys)
	events.append_array(others)
	_set_events(action, events)
	_after_controls_change()


## Remplace le bouton de manette d'une action ; null l'efface.
func set_pad(action: StringName, event: InputEvent) -> void:
	var events: Array[InputEvent] = []
	var replaced := false
	for existing in InputMap.action_get_events(action):
		if _is_pad(existing) and not replaced:
			replaced = true
			if event != null:
				events.append(_clean(event))
			continue
		events.append(existing)
	if not replaced and event != null:
		events.append(_clean(event))
	_set_events(action, events)
	_after_controls_change()


## Remet toutes les touches du projet.
func reset_controls() -> void:
	for action in _default_controls:
		_set_events(action, _default_controls[action])
	_after_controls_change()


## Les actions (hors `except`) qui utilisent déjà cette touche ou ce bouton.
func actions_using(event: InputEvent, except: StringName = &"") -> Array[StringName]:
	var wanted := _encode(event)
	var found: Array[StringName] = []
	for action in _default_controls:
		if action == except:
			continue
		for existing in InputMap.action_get_events(action):
			if _encode(existing) == wanted:
				found.append(action)
				break
	return found


func _after_controls_change() -> void:
	_save()
	controls_changed.emit()


func _set_events(action: StringName, events: Array) -> void:
	InputMap.action_erase_events(action)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


static func _is_pad(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


## Une copie réduite à l'essentiel : la touche physique (la même place quelle
## que soit la disposition du clavier), le bouton, ou l'axe et son sens.
static func _clean(event: InputEvent) -> InputEvent:
	return _decode(_encode(event))


## Touche, bouton ou axe → dictionnaire enregistrable (et comparable).
static func _encode(event: InputEvent) -> Dictionary:
	var key := event as InputEventKey
	if key != null:
		if key.physical_keycode != KEY_NONE:
			return {"type": "key", "physical": key.physical_keycode}
		return {"type": "key", "keycode": key.keycode}
	var button := event as InputEventJoypadButton
	if button != null:
		return {"type": "button", "index": button.button_index}
	var motion := event as InputEventJoypadMotion
	if motion != null:
		return {"type": "axis", "axis": motion.axis, "value": signf(motion.axis_value)}
	var mouse := event as InputEventMouseButton
	if mouse != null:
		return {"type": "mouse", "index": mouse.button_index}
	return {}


static func _decode(data: Dictionary) -> InputEvent:
	match data.get("type", ""):
		"key":
			var key := InputEventKey.new()
			if data.has("physical"):
				key.physical_keycode = int(data.physical) as Key
			else:
				key.keycode = int(data.get("keycode", KEY_NONE)) as Key
			return key
		"button":
			var button := InputEventJoypadButton.new()
			button.button_index = int(data.get("index", 0)) as JoyButton
			return button
		"axis":
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(data.get("axis", 0)) as JoyAxis
			motion.axis_value = float(data.get("value", 1.0))
			return motion
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(data.get("index", MOUSE_BUTTON_LEFT)) as MouseButton
			return mouse
	return null


static func _decode_all(saved: Array) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for data: Variant in saved:
		if data is Dictionary:
			var event := _decode(data)
			if event != null:
				events.append(event)
	return events


static func _encode_all(events: Array) -> Array[Dictionary]:
	var encoded: Array[Dictionary] = []
	for event: InputEvent in events:
		var data := _encode(event)
		if not data.is_empty():
			encoded.append(data)
	return encoded


# --- Application et enregistrement ----------------------------------------

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
	# Seulement les actions changées : une touche ajoutée plus tard au projet
	# arrive chez le joueur sans qu'il ait à tout remettre par défaut.
	for action in _default_controls:
		var current := _encode_all(InputMap.action_get_events(action))
		if current != _encode_all(_default_controls[action]):
			config.set_value("controls", action, current)
	config.save(PATH)
