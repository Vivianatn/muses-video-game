class_name SettingsView
extends VBoxContainer

## Le contenu de la fenêtre Paramètres : plein écran, volume et commandes.
## Construit en code et partagé par l'écran titre et le menu en jeu, qui
## l'habillent chacun avec leur thème.
##
## Changer une commande : on choisit la touche (colonne Clavier ou Manette),
## puis on appuie sur la nouvelle. Échap (ou Start à la manette) annule.
## Pendant l'attente, cette vue garde toutes les touches pour elle : le menu
## qui la contient ne doit pas réagir (voir is_listening).

const InputDeviceScript := preload("res://Scripts/Input/input_device.gd")
const SettingsScript := preload("res://Scripts/Settings/settings.gd")

## Inclinaison d'un stick ou d'une gâchette à partir de laquelle elle compte.
const AXIS_THRESHOLD := 0.6

## Couleur des titres de section.
var accent_color: Color = Color(1, 0.86, 0.55)
## Couleur des explications.
var dim_text_color: Color = Color(0.6, 0.58, 0.55)
## Taille des explications.
var small_size: int = 16

var _fullscreen: CheckButton
var _volume: HSlider
var _rows: VBoxContainer
var _reset: Button
## Pour chaque action, ses boutons [clavier, manette].
var _buttons: Dictionary[StringName, Array] = {}

## Le bouton qui attend une touche, ou null.
var _listening: Button
var _listen_action: StringName
var _listen_pad: bool
## Vrai une image après le début de l'attente : l'appui qui a choisi la
## commande ne doit pas être pris pour la nouvelle touche.
var _armed: bool = false
## La touche qu'on vient d'attribuer : son relâchement ne doit pas arriver
## au menu (il revaliderait le bouton).
var _captured: InputEvent


func _init() -> void:
	add_theme_constant_override(&"separation", 10)
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# GameMenu nous crée avant que l'autoload Settings soit chargé : on attend
	# la fin de l'image, quand tous les autoloads sont là.
	_setup.call_deferred()


func _setup() -> void:
	_build()
	Settings.controls_changed.connect(_refresh_controls)
	refresh()


## Remet l'affichage à jour avec les valeurs actuelles, sans rien enregistrer.
func refresh() -> void:
	if _fullscreen == null:
		return
	_stop_listening()
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)
	_volume.set_value_no_signal(Settings.master_volume)
	_refresh_controls()


## Vrai pendant qu'on attend la nouvelle touche d'une commande.
func is_listening() -> bool:
	return _listening != null


func focus_first() -> void:
	if _fullscreen != null:
		_fullscreen.grab_focus()


func _input(event: InputEvent) -> void:
	if _captured != null and not event.is_pressed() and event.is_match(_captured):
		get_viewport().set_input_as_handled()
		_captured = null
		return
	if _listening == null:
		return
	# Tant qu'on attend, rien ne passe : ni le menu, ni les boutons.
	get_viewport().set_input_as_handled()
	if not _armed or not event.is_pressed() or event.is_echo():
		return

	var key := event as InputEventKey
	if key != null and key.physical_keycode == KEY_ESCAPE:
		_stop_listening()
		return
	var pad_button := event as InputEventJoypadButton
	if pad_button != null and pad_button.button_index == JOY_BUTTON_START:
		_stop_listening()
		return

	if _listen_pad:
		var motion := event as InputEventJoypadMotion
		if pad_button == null and (motion == null or absf(motion.axis_value) < AXIS_THRESHOLD):
			return
	elif key == null and event is not InputEventMouseButton:
		return

	var action := _listen_action
	var button := _listening
	# Un axe n'a pas de relâchement net : rien à retenir.
	_captured = null if event is InputEventJoypadMotion else event
	_stop_listening()
	Settings.rebind(action, event)
	button.grab_focus()


func _start_listening(action: StringName, pad: bool) -> void:
	_stop_listening()
	_listening = _buttons[action][1 if pad else 0]
	_listen_action = action
	_listen_pad = pad
	_listening.text = "Appuie sur un bouton…" if pad else "Appuie sur une touche…"
	_armed = false
	await get_tree().process_frame
	_armed = true


func _stop_listening() -> void:
	if _listening == null:
		return
	_listening = null
	_armed = false
	_refresh_controls()


func _refresh_controls() -> void:
	for action in _buttons:
		for pad in [false, true]:
			var button: Button = _buttons[action][1 if pad else 0]
			if button == _listening:
				continue
			var event := Settings.get_binding(action, pad)
			button.text = InputDeviceScript.event_label(event) if event != null else "—"


func _on_reset() -> void:
	_stop_listening()
	Settings.reset_controls()


# --- Construction ---------------------------------------------------------

func _build() -> void:
	_fullscreen = CheckButton.new()
	_fullscreen.text = "Plein écran"
	_fullscreen.toggled.connect(Settings.set_fullscreen)
	_fullscreen.mouse_entered.connect(_fullscreen.grab_focus)
	add_child(_fullscreen)

	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override(&"separation", 12)
	add_child(volume_row)
	volume_row.add_child(_label("Volume"))
	_volume = HSlider.new()
	_volume.max_value = 1.0
	_volume.step = 0.05
	_volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_volume.value_changed.connect(Settings.set_master_volume)
	_volume.mouse_entered.connect(_volume.grab_focus)
	volume_row.add_child(_volume)

	var title := _label("Commandes")
	title.add_theme_color_override(&"font_color", accent_color)
	add_child(title)
	var help := _label("Choisis une commande, puis appuie sur la nouvelle touche. Échap ou Start : annuler.")
	help.add_theme_font_size_override(&"font_size", small_size)
	help.add_theme_color_override(&"font_color", dim_text_color)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)

	var header := _row()
	add_child(header)
	header.add_child(_expanding(_label("")))
	for column in ["Clavier / souris", "Manette"]:
		var label := _label(column)
		label.add_theme_font_size_override(&"font_size", small_size)
		label.add_theme_color_override(&"font_color", dim_text_color)
		label.custom_minimum_size.x = 220
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(label)

	# Beaucoup de commandes : la liste défile, la fenêtre ne grandit pas.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_rows)

	for action in SettingsScript.ACTION_NAMES:
		if not InputMap.has_action(action):
			continue
		var row := _row()
		_rows.add_child(row)
		var name_label := _label(SettingsScript.ACTION_NAMES[action])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(name_label)
		var pair: Array[Button] = []
		for pad in [false, true]:
			var button := Button.new()
			button.custom_minimum_size.x = 220
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			button.pressed.connect(_start_listening.bind(action, pad))
			button.mouse_entered.connect(button.grab_focus)
			row.add_child(button)
			pair.append(button)
		_buttons[action] = pair

	_reset = Button.new()
	_reset.text = "Commandes par défaut"
	_reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reset.pressed.connect(_on_reset)
	_reset.mouse_entered.connect(_reset.grab_focus)
	add_child(_reset)


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	return row


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _expanding(control: Control) -> Control:
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return control
