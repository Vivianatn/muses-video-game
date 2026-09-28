extends Node

## Sait si une manette est branchée, chargé en autoload sous le nom
## "InputDevice". Sert à choisir quelles touches afficher à l'écran.
##
## La manette a la priorité sur le clavier : dès qu'il y en a une de branchée,
## le jeu affiche les boutons de la manette, même si l'on joue au clavier.
##
## Usage :
##     if InputDevice.is_gamepad(): ...
##     InputDevice.changed.connect(_on_input_device_changed)

## Émis quand on passe du clavier à la manette ou inversement.
signal changed(gamepad: bool)

var _gamepad: bool = false


func _ready() -> void:
	# Les invites restent justes même si l'on branche une manette pendant une
	# pause ou un dialogue.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_gamepad = not Input.get_connected_joypads().is_empty()
	_add_gamepad_ui_controls()


## Vrai si au moins une manette est branchée.
func is_gamepad() -> bool:
	return _gamepad


## Nom à afficher pour la touche d'une action, selon ce qui est branché :
## « Espace », « A », « LB »... Pour le clavier, c'est la vraie lettre de la
## disposition du joueur (AZERTY, QWERTY...). Vide si l'action n'a rien pour
## ce périphérique.
func action_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		var pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
		if pad == _gamepad:
			var label := event_label(event)
			if label != "":
				return label
	return ""


## Nom à afficher pour une touche, un bouton ou un axe.
static func event_label(event: InputEvent) -> String:
	var button := event as InputEventJoypadButton
	if button != null:
		return PAD_BUTTON_NAMES.get(button.button_index, "Bouton %d" % button.button_index)

	var motion := event as InputEventJoypadMotion
	if motion != null:
		match motion.axis:
			JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
				return "Stick gauche"
			_:
				return "Stick droit"

	var key := event as InputEventKey
	if key != null:
		var code := key.keycode
		if key.physical_keycode != KEY_NONE:
			code = key.physical_keycode
			# Touche physique : on demande quelle lettre elle porte sur ce
			# clavier (sauf sans fenêtre, où il n'y a pas de clavier à lire).
			if DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
		var key_name := OS.get_keycode_string(code)
		return KEY_NAMES.get(key_name, key_name)

	if event is InputEventMouseButton:
		return "Clic"
	return ""


const PAD_BUTTON_NAMES: Dictionary[int, String] = {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Select",
	JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "↑",
	JOY_BUTTON_DPAD_DOWN: "↓",
	JOY_BUTTON_DPAD_LEFT: "←",
	JOY_BUTTON_DPAD_RIGHT: "→",
}

## Noms anglais de Godot → noms affichés.
const KEY_NAMES: Dictionary[String, String] = {
	"Space": "Espace",
	"Shift": "Maj",
	"Escape": "Échap",
	"Enter": "Entrée",
	"Kp Enter": "Entrée",
	"Backspace": "Retour arrière",
	"Up": "↑",
	"Down": "↓",
	"Left": "←",
	"Right": "→",
}


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	# On recompte plutôt que de se fier à `_connected` : avec deux manettes, en
	# débrancher une ne doit pas faire revenir au clavier.
	var gamepad := not Input.get_connected_joypads().is_empty()
	if gamepad == _gamepad:
		return
	_gamepad = gamepad
	changed.emit(_gamepad)


## Les actions ui_* de Godot, qui pilotent tous les boutons et menus, ne
## connaissent pas le bouton A de la manette : on l'ajoute au démarrage.
func _add_gamepad_ui_controls() -> void:
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	if InputMap.has_action(&"ui_accept") and not InputMap.action_has_event(&"ui_accept", accept):
		InputMap.action_add_event(&"ui_accept", accept)


# --- Stick gauche dans les menus ------------------------------------------
#
# On ne lie pas le stick aux actions ui_* : il envoie un flot d'événements
# tant qu'il est penché, et la sélection sauterait plusieurs cases d'un coup.
# À la place, chaque fois qu'il franchit le seuil, on simule UN appui sur la
# direction, exactement comme la croix.

## Inclinaison à partir de laquelle le stick compte comme une direction.
const STICK_THRESHOLD := 0.5

## Direction en cours sur chaque axe : -1, 0 ou 1.
var _stick_state: Dictionary[int, int] = {JOY_AXIS_LEFT_X: 0, JOY_AXIS_LEFT_Y: 0}


func _input(event: InputEvent) -> void:
	var motion := event as InputEventJoypadMotion
	if motion == null or not _stick_state.has(motion.axis):
		return

	var state := 0
	if motion.axis_value >= STICK_THRESHOLD:
		state = 1
	elif motion.axis_value <= -STICK_THRESHOLD:
		state = -1
	var previous: int = _stick_state[motion.axis]
	if state == previous:
		return
	_stick_state[motion.axis] = state

	if previous != 0:
		_send_ui(_ui_action(motion.axis, previous), false)
	if state != 0:
		_send_ui(_ui_action(motion.axis, state), true)


static func _ui_action(axis: int, direction: int) -> StringName:
	if axis == JOY_AXIS_LEFT_X:
		return &"ui_left" if direction < 0 else &"ui_right"
	return &"ui_up" if direction < 0 else &"ui_down"


func _send_ui(action: StringName, pressed: bool) -> void:
	var fake := InputEventAction.new()
	fake.action = action
	fake.pressed = pressed
	Input.parse_input_event(fake)
