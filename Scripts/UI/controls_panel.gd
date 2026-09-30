extends PanelContainer

## Le panneau « Touches » des paramètres : pour chaque action du jeu, deux
## touches du clavier et un bouton de manette, à réaffecter. Choisir une case
## puis presser la nouvelle touche ; Échap annule, Suppr efface la case.
##
## Tout est construit en code à partir des actions du projet : une action
## ajoutée plus tard dans Projet → Paramètres du projet → Contrôles apparaît
## toute seule (dans « Autres » tant qu'elle n'a pas de nom ci-dessous).
## Les réaffectations passent par l'autoload Settings, qui les enregistre.

## Le joueur a quitté le panneau (bouton Retour, Échap ou B).
signal closed

const InputDeviceScript := preload("res://Scripts/Input/input_device.gd")
const CircuitScript := preload("res://Scripts/UI/circuit.gd")
const Motion := preload("res://Scripts/UI/motion.gd")

## Les rubriques, et le nom affiché de chaque action.
const SECTIONS: Array = [
	["Déplacements", {
		&"move_left": "Aller à gauche",
		&"move_right": "Aller à droite",
		&"look_up": "Regarder en haut",
		&"look_down": "Regarder en bas",
		&"jump": "Sauter",
		&"run": "Courir",
		&"dash": "Dash",
	}],
	["Actions", {
		&"fire": "Tirer",
		&"interact": "Parler ou examiner",
		&"camera_zoom_out": "Dézoomer la caméra",
	}],
	["Menus", {
		&"menu": "Menu pause",
		&"inventory": "Inventaire",
		&"menu_back": "Retour",
		&"menu_tab_prev": "Onglet précédent",
		&"menu_tab_next": "Onglet suivant",
		&"menu_filter_prev": "Filtre précédent",
		&"menu_filter_next": "Filtre suivant",
		&"toggle_fullscreen": "Plein écran",
	}],
]
## Case de la manette : les cases 0 et 1 sont les deux touches du clavier.
const PAD_SLOT := -1
## Inclinaison à partir de laquelle un stick ou une gâchette compte.
const AXIS_THRESHOLD := 0.6
const EMPTY := "—"
## Largeur des cases : la manette a des noms plus longs (« Stick gauche ← »).
const KEY_WIDTH := 125.0
const PAD_WIDTH := 205.0
## Place à droite des cases (la barre de défilement et la marge de la liste),
## pour aligner les titres des colonnes sur les cases.
const SCROLLBAR_WIDTH := 8.0 + Motion.ROOM + Motion.SCROLLBAR_GAP

var _list: VBoxContainer
var _status: Label
var _reset: Button
var _back: Button
## Les cases de chaque action : [touche 1, touche 2, manette].
var _cells: Dictionary[StringName, Array] = {}
## La case qui attend une touche : [action, case, bouton], ou vide.
var _waiting: Array = []


func _ready() -> void:
	theme_type_variation = &"PanneauEntete"
	# Le panneau travaille aussi quand le jeu est en pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	var settings := get_node_or_null(^"/root/Settings")
	if settings != null:
		settings.connect(&"controls_changed", _refresh)


## Affiche le panneau, sélection sur la première case.
func open() -> void:
	visible = true
	Motion.pop_in(self)
	_cancel_waiting()
	_status.text = ""
	_refresh()
	var first: Array = _cells.values()[0] if not _cells.is_empty() else []
	if not first.is_empty():
		(first[0] as Button).grab_focus()


func close() -> void:
	_cancel_waiting()
	visible = false
	closed.emit()


# --- Saisie d'une touche --------------------------------------------------

func _input(event: InputEvent) -> void:
	if _waiting.is_empty() or not visible:
		return
	var slot: int = _waiting[1]

	var key := event as InputEventKey
	if key != null:
		if not key.pressed or key.echo:
			return
		get_viewport().set_input_as_handled()
		if key.keycode == KEY_ESCAPE:
			_cancel_waiting()
		elif key.keycode == KEY_DELETE:
			_assign(null)
		elif slot != PAD_SLOT:
			_assign(key)
		return

	if slot == PAD_SLOT:
		var button := event as InputEventJoypadButton
		if button != null and button.pressed:
			get_viewport().set_input_as_handled()
			_assign(button)
			return
		var motion := event as InputEventJoypadMotion
		if motion != null and absf(motion.axis_value) >= AXIS_THRESHOLD:
			get_viewport().set_input_as_handled()
			_assign(motion)
			return

	# Un clic ailleurs abandonne la saisie.
	if event is InputEventMouseButton and event.pressed:
		_cancel_waiting()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _waiting.is_empty():
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"menu_back"):
		get_viewport().set_input_as_handled()
		close()


func _start_waiting(action: StringName, slot: int, button: Button) -> void:
	_cancel_waiting()
	_waiting = [action, slot, button]
	button.text = "…"
	if slot == PAD_SLOT:
		_status.text = "Presse un bouton de la manette. Échap : annuler, Suppr : effacer."
	else:
		_status.text = "Presse une touche du clavier. Échap : annuler, Suppr : effacer."
	_status.remove_theme_color_override(&"font_color")


func _cancel_waiting() -> void:
	if _waiting.is_empty():
		return
	_waiting = []
	_status.text = ""
	_refresh()


## Enregistre la touche saisie (null = efface la case), puis signale si une
## autre action l'utilise déjà : c'est permis (B sert au dash comme au retour
## des menus), mais le joueur doit le savoir.
func _assign(event: InputEvent) -> void:
	var action: StringName = _waiting[0]
	var slot: int = _waiting[1]
	var button: Button = _waiting[2]
	_waiting = []

	if slot == PAD_SLOT:
		Settings.set_pad(action, event)
	else:
		Settings.set_key(action, slot, event as InputEventKey)
	_refresh()
	button.grab_focus()
	# La nouvelle touche « tombe » dans sa case.
	Motion.pop_in(button, 0.2, 1.25)

	_status.text = ""
	if event == null:
		return
	var names: PackedStringArray = []
	for other in Settings.actions_using(event, action):
		names.append(_action_name(other))
	if not names.is_empty():
		_status.text = "Aussi utilisée par : %s" % ", ".join(names)
		_status.add_theme_color_override(&"font_color", Muses.CUIVRE)


func _on_reset() -> void:
	_cancel_waiting()
	Settings.reset_controls()
	_status.text = "Touches d'origine rétablies."
	_status.remove_theme_color_override(&"font_color")


# --- Affichage ------------------------------------------------------------

func _refresh() -> void:
	for action in _cells:
		var cells: Array = _cells[action]
		var keys: Array[InputEventKey] = Settings.key_events(action)
		for slot in 2:
			(cells[slot] as Button).text = _event_name(keys[slot] if slot < keys.size() else null)
		(cells[2] as Button).text = _event_name(Settings.pad_event(action))


static func _event_name(event: InputEvent) -> String:
	if event == null:
		return EMPTY
	var label := InputDeviceScript.event_label(event)
	return label.to_upper() if label != "" else EMPTY


static func _action_name(action: StringName) -> String:
	for section: Array in SECTIONS:
		var names: Dictionary = section[1]
		if names.has(action):
			return names[action]
	return String(action)


func _build() -> void:
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override(&"separation", 0)
	add_child(frame)

	var header := PanelContainer.new()
	header.theme_type_variation = &"Entete"
	frame.add_child(header)
	var title := _label("Touches", &"TitrePanneau")
	header.add_child(title)

	var circuit_margin := MarginContainer.new()
	circuit_margin.add_theme_constant_override(&"margin_left", Muses.ESPACE_3)
	circuit_margin.add_theme_constant_override(&"margin_right", Muses.ESPACE_3)
	circuit_margin.add_child(CircuitScript.new())
	frame.add_child(circuit_margin)

	var content := MarginContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		content.add_theme_constant_override(side, Muses.ESPACE_3)
	frame.add_child(content)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	content.add_child(column)

	# Titres des colonnes, alignés sur les cases.
	var heading := _row()
	var corner := _label("", &"HudEtiquette")
	corner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(corner)
	for text in ["Touche", "Autre touche", "Manette"]:
		var cell := _label(text, &"HudEtiquette")
		cell.custom_minimum_size.x = PAD_WIDTH if text == "Manette" else KEY_WIDTH
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.add_child(cell)
	var scrollbar_gap := Control.new()
	scrollbar_gap.custom_minimum_size.x = SCROLLBAR_WIDTH
	heading.add_child(scrollbar_gap)
	column.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 6)
	scroll.add_child(Motion.with_room(_list))

	# Les rubriques connues, puis les actions du projet sans nom ici.
	var shown: Array[StringName] = []
	for section: Array in SECTIONS:
		var actions: Array[StringName] = []
		for action: StringName in (section[1] as Dictionary):
			if InputMap.has_action(action):
				actions.append(action)
		_add_section(section[0], actions)
		shown.append_array(actions)
	var others: Array[StringName] = []
	for action in Settings.remappable_actions():
		if action not in shown:
			others.append(action)
	_add_section("Autres", others)

	_status = _label("", &"Legende")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

	# Actions du panneau centrées, la principale en dernier.
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override(&"separation", Muses.ESPACE_2)
	column.add_child(footer)
	_reset = _button("Rétablir", &"BoutonSecondaire")
	_reset.pressed.connect(_on_reset)
	footer.add_child(_reset)
	_back = _button("Retour", &"")
	_back.pressed.connect(close)
	footer.add_child(_back)


func _add_section(title: String, actions: Array[StringName]) -> void:
	if actions.is_empty():
		return
	var heading := _label(title, &"SousTitre")
	if _list.get_child_count() > 0:
		# Un peu d'air avant chaque rubrique, sauf la première.
		var spacer := Control.new()
		spacer.custom_minimum_size.y = Muses.ESPACE_1
		_list.add_child(spacer)
	_list.add_child(heading)

	for action in actions:
		var row := _row()
		var name_label := _label(_action_name(action))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(name_label)
		var cells: Array[Button] = []
		for slot in [0, 1, PAD_SLOT]:
			var cell := _button(EMPTY, &"BoutonSecondaire")
			cell.custom_minimum_size.x = PAD_WIDTH if slot == PAD_SLOT else KEY_WIDTH
			cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			cell.pressed.connect(func() -> void: _start_waiting(action, slot, cell))
			cell.mouse_entered.connect(cell.grab_focus)
			row.add_child(cell)
			cells.append(cell)
		_cells[action] = cells
		_list.add_child(row)


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", Muses.ESPACE_1)
	return row


func _label(text: String, style: StringName = &"") -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = style
	label.uppercase = style not in [&"", &"Legende"]
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, style: StringName) -> Button:
	var button := Button.new()
	button.text = text.to_upper()
	button.theme_type_variation = style
	button.custom_minimum_size.y = Muses.CIBLE_MIN
	return button
