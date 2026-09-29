extends Node

## Les paramètres du joueur, chargé en autoload sous le nom "Settings".
## Ils sont appliqués au lancement du jeu et enregistrés à chaque changement
## dans user://settings.cfg (à part des sauvegardes : ils valent pour toutes
## les parties).
##
## Usage :
##     Settings.set_fullscreen(true)
##     Settings.set_master_volume(0.5)
##     Settings.rebind(&"jump", event)     # change une commande
##     Settings.reset_controls()           # remet les commandes d'origine

## Émis quand une commande change : les rappels de touches à l'écran doivent
## se mettre à jour.
signal controls_changed

const PATH := "user://settings.cfg"

## Les commandes que le joueur peut changer, dans l'ordre d'affichage. Les
## touches des menus n'y sont pas : on ne doit jamais pouvoir s'enfermer
## dehors.
const ACTION_NAMES: Dictionary[StringName, String] = {
	&"move_left": "Aller à gauche",
	&"move_right": "Aller à droite",
	&"look_up": "Regarder en haut",
	&"look_down": "Regarder en bas",
	&"jump": "Sauter",
	&"run": "Courir",
	&"dash": "Dash",
	&"fire": "Tirer",
	&"interact": "Parler / interagir",
	&"camera_zoom_out": "Dézoomer la caméra",
	&"inventory": "Inventaire",
}

## Plein écran ou fenêtré.
var fullscreen: bool = false
## Volume général, de 0 (muet) à 1.
var master_volume: float = 1.0

## Les touches d'origine (Paramètres du projet), pour pouvoir y revenir.
var _default_events: Dictionary[StringName, Array] = {}


func _ready() -> void:
	for action in ACTION_NAMES:
		if InputMap.has_action(action):
			_default_events[action] = InputMap.action_get_events(action)

	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		fullscreen = config.get_value("video", "fullscreen", fullscreen)
		master_volume = config.get_value("audio", "master_volume", master_volume)
		for action in _default_events:
			if not config.has_section_key("controls", String(action)):
				continue
			var saved: Variant = config.get_value("controls", String(action))
			if saved is Array:
				_load_action(action, saved)
	_apply()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply()
	_save()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply()
	_save()


# --- Commandes ------------------------------------------------------------

## Vrai pour un bouton ou un axe de manette, faux pour le clavier et la souris.
static func is_pad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


## La touche principale d'une action pour la manette (`pad`) ou le clavier et
## la souris, ou null s'il n'y en a pas. C'est celle que l'on remplace.
func get_binding(action: StringName, pad: bool) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for event in InputMap.action_get_events(action):
		if is_pad_event(event) == pad:
			return event
	return null


## Donne `event` à l'action, à la place de sa touche principale du même
## périphérique. Si une autre commande avait déjà cette touche, elle récupère
## l'ancienne en échange : deux commandes ne se retrouvent jamais sur la même.
func rebind(action: StringName, event: InputEvent) -> void:
	if not _default_events.has(action):
		return
	var new_event := _clean(event)
	if new_event == null:
		return
	var old := get_binding(action, is_pad_event(new_event))
	if old != null and _same(old, new_event):
		return

	for other in _default_events:
		if other == action:
			continue
		for existing in InputMap.action_get_events(other):
			if _same(existing, new_event):
				_replace(other, existing, old)

	_replace(action, old, new_event)
	_save()
	controls_changed.emit()


## Remet toutes les commandes d'origine.
func reset_controls() -> void:
	for action in _default_events:
		InputMap.action_erase_events(action)
		for event in _default_events[action]:
			InputMap.action_add_event(action, event)
	_save()
	controls_changed.emit()


## Remplace `old` par `new` dans l'action, à la même place. `old` null : on
## ajoute `new` ; `new` null : on retire `old`. Un doublon de `new` plus loin
## dans la liste disparaît.
func _replace(action: StringName, old: InputEvent, new: InputEvent) -> void:
	var events := InputMap.action_get_events(action)
	var result: Array[InputEvent] = []
	var placed := false
	for event in events:
		if old != null and event == old:
			if new != null and not placed:
				result.append(new)
				placed = true
		elif new != null and _same(event, new):
			if not placed:
				result.append(new)
				placed = true
		else:
			result.append(event)
	if new != null and not placed:
		result.append(new)
	InputMap.action_erase_events(action)
	for event in result:
		InputMap.action_add_event(action, event)


## Une copie propre de l'événement, telle qu'on la range dans une action :
## touche physique (même place quel que soit le clavier), axe à fond.
static func _clean(event: InputEvent) -> InputEvent:
	return _from_dict(_to_dict(event))


static func _same(a: InputEvent, b: InputEvent) -> bool:
	var da := _to_dict(a)
	return not da.is_empty() and da == _to_dict(b)


## Un événement sous forme de dictionnaire simple, pour settings.cfg : pas
## d'objets dans le fichier, donc rien qui puisse exécuter du code.
static func _to_dict(event: InputEvent) -> Dictionary:
	var key := event as InputEventKey
	if key != null:
		if key.physical_keycode != KEY_NONE:
			return {"type": "key", "code": int(key.physical_keycode)}
		return {"type": "keycode", "code": int(key.keycode)}
	var mouse := event as InputEventMouseButton
	if mouse != null:
		return {"type": "mouse", "button": int(mouse.button_index)}
	var button := event as InputEventJoypadButton
	if button != null:
		return {"type": "pad_button", "button": int(button.button_index)}
	var motion := event as InputEventJoypadMotion
	if motion != null:
		return {"type": "pad_axis", "axis": int(motion.axis), "value": 1.0 if motion.axis_value >= 0.0 else -1.0}
	return {}


static func _from_dict(data: Dictionary) -> InputEvent:
	match data.get("type"):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(data.get("code", KEY_NONE)) as Key
			return key
		"keycode":
			var key := InputEventKey.new()
			key.keycode = int(data.get("code", KEY_NONE)) as Key
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(data.get("button", MOUSE_BUTTON_LEFT)) as MouseButton
			return mouse
		"pad_button":
			var button := InputEventJoypadButton.new()
			button.button_index = int(data.get("button", JOY_BUTTON_A)) as JoyButton
			return button
		"pad_axis":
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(data.get("axis", JOY_AXIS_LEFT_X)) as JoyAxis
			motion.axis_value = 1.0 if float(data.get("value", 1.0)) >= 0.0 else -1.0
			return motion
	return null


func _load_action(action: StringName, saved: Array) -> void:
	var events: Array[InputEvent] = []
	for data in saved:
		if data is Dictionary:
			var event := _from_dict(data)
			if event != null:
				events.append(event)
	# Un fichier abîmé ne doit pas laisser une commande sans aucune touche.
	if events.is_empty():
		return
	InputMap.action_erase_events(action)
	for event in events:
		InputMap.action_add_event(action, event)


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
	# Seules les commandes changées sont écrites : les autres suivent les
	# Paramètres du projet, même s'ils changent dans une mise à jour du jeu.
	for action in _default_events:
		var current: Array = InputMap.action_get_events(action).map(_to_dict)
		var defaults: Array = _default_events[action].map(_to_dict)
		if current != defaults:
			config.set_value("controls", String(action), current)
	config.save(PATH)
