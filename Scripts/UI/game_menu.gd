extends CanvasLayer

## Le menu du jeu, chargé en autoload sous le nom "GameMenu" : pause,
## inventaire, sauvegarde et chargement.
##
## Touches (Projet → Paramètres du projet → Contrôles) :
##   menu       Échap / Start          ouvre ou ferme le menu
##   inventory  I / Select             ouvre directement l'inventaire
##   menu_back  Retour arrière / B     revient à la fenêtre précédente
##
## Les fenêtres s'empilent : chaque « retour » ferme celle du dessus et rend
## la sélection là où on l'avait laissée. Retour sur la dernière = le menu se
## ferme. Le jeu est en pause tant que le menu est ouvert.
##
## Toute l'interface est construite en code (_build) : l'apparence se règle
## avec les champs du groupe « Apparence ».

signal opened
signal closed

@export_group("Apparence")
@export var accent_color: Color = Color(1, 0.86, 0.55)
@export var text_color: Color = Color(0.93, 0.91, 0.87)
@export var dim_text_color: Color = Color(0.6, 0.58, 0.55)
@export var panel_color: Color = Color(0.07, 0.06, 0.09, 0.95)
@export var button_color: Color = Color(1, 1, 1, 0.06)
## Voile posé sur le jeu derrière le menu.
@export var backdrop_color: Color = Color(0, 0, 0, 0.55)
@export_range(8, 72, 1) var title_size: int = 34
@export_range(8, 72, 1) var text_size: int = 22
@export_range(8, 72, 1) var small_size: int = 16

@export_group("Inventaire")
## Nombre de cases par ligne.
@export var inventory_columns: int = 6
## Nombre de cases affichées au minimum, même vides.
@export var inventory_min_slots: int = 18
## Côté (px) d'une case.
@export var inventory_slot_size: int = 72

var _open: bool = false
## Fenêtres ouvertes, de la plus ancienne à celle affichée.
var _stack: Array[Control] = []
## Pour chaque fenêtre recouverte, le bouton qui avait la sélection.
var _focus_memory: Dictionary[Control, Control] = {}

var _root: Control
var _main: Control
var _inventory: Control
var _slots: Control
var _confirm: Control
var _hints: Dictionary[Control, Label] = {}

var _inv_grid: GridContainer
var _inv_icon: TextureRect
var _inv_name: Label
var _inv_count: Label
var _inv_desc: Label

var _slots_title: Label
var _slots_list: VBoxContainer
var _slots_save_mode: bool = true

var _confirm_label: Label
var _confirm_yes: Button
var _confirm_no: Button
var _confirm_action: Callable

var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false

	SaveGame.saved.connect(_on_saved)
	SaveGame.failed.connect(_on_save_failed)
	Inventory.changed.connect(_on_inventory_changed)


func _input(event: InputEvent) -> void:
	if not _open:
		if event.is_action_pressed(&"menu") and _can_open():
			get_viewport().set_input_as_handled()
			open()
		elif event.is_action_pressed(&"inventory") and _can_open():
			get_viewport().set_input_as_handled()
			open(&"inventory")
		return

	if event.is_action_pressed(&"menu"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed(&"inventory") and _top() == _inventory:
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed(&"menu_back") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


# --- Ouvrir, fermer, naviguer ---------------------------------------------

func is_open() -> bool:
	return _open


## Ouvre le menu. `start` = &"inventory" pour arriver directement sur
## l'inventaire (un retour ferme alors le menu).
func open(start: StringName = &"") -> void:
	if _open:
		return
	# Avant d'afficher quoi que ce soit : la miniature de sauvegarde doit
	# montrer le jeu, pas le menu.
	SaveGame.capture_thumbnail()
	_open = true
	get_tree().paused = true
	_root.visible = true
	_stack.clear()
	_focus_memory.clear()
	for window in [_main, _inventory, _slots, _confirm]:
		window.visible = false
	_push(_inventory if start == &"inventory" else _main)
	opened.emit()


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	_stack.clear()
	_focus_memory.clear()
	get_viewport().gui_release_focus()
	SaveGame.clear_thumbnail()
	closed.emit()

	# Deux images de pause de plus : le bouton qui vient de fermer le menu
	# (B sert aussi au dash) ne doit pas arriver au joueur comme un appui neuf.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not _open:
		get_tree().paused = false


## Ferme la fenêtre du dessus, ou le menu s'il n'en reste qu'une.
func back() -> void:
	if _stack.size() <= 1:
		close()
		return
	var top: Control = _stack.pop_back()
	top.visible = false
	var below := _top()
	_refresh(below)
	below.visible = true
	_update_hint(below)

	var remembered: Control = _focus_memory.get(below)
	_focus_memory.erase(below)
	if remembered != null and is_instance_valid(remembered) and remembered.is_visible_in_tree():
		remembered.grab_focus()
	else:
		_focus_default(below)


func _push(window: Control) -> void:
	var top := _top()
	if top != null:
		_focus_memory[top] = get_viewport().gui_get_focus_owner()
		top.visible = false
	_stack.append(window)
	_refresh(window)
	window.visible = true
	_update_hint(window)
	_focus_default(window)


func _top() -> Control:
	return null if _stack.is_empty() else _stack[-1]


func _can_open() -> bool:
	if get_tree().paused or get_tree().current_scene == null:
		return false
	return not Dialogues.is_active() and not SaveGame.is_busy()


func _refresh(window: Control) -> void:
	if window == _inventory:
		_refresh_inventory()
	elif window == _slots:
		_refresh_slots()


func _focus_default(window: Control) -> void:
	if window == _confirm:
		# « Non » par défaut : un appui de trop ne doit rien détruire.
		_confirm_no.grab_focus()
		return
	var first := _first_focusable(window)
	if first != null:
		first.grab_focus()


func _first_focusable(node: Node) -> Control:
	for child in node.get_children():
		var button := child as BaseButton
		if button != null and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			return button
		var found := _first_focusable(child)
		if found != null:
			return found
	return null


## Demande confirmation, puis appelle `action` si le joueur accepte.
func _ask(message: String, action: Callable) -> void:
	_confirm_label.text = message
	_confirm_action = action
	_push(_confirm)


func _on_confirm_yes() -> void:
	var action := _confirm_action
	_confirm_action = Callable()
	back()
	if action.is_valid():
		action.call()


# --- Menu principal -------------------------------------------------------

func _on_resume() -> void:
	close()


func _on_quit() -> void:
	_ask("Quitter le jeu ?\nLa progression non sauvegardée sera perdue.", get_tree().quit)


# --- Inventaire -----------------------------------------------------------

func _refresh_inventory() -> void:
	_clear(_inv_grid)
	_inv_grid.columns = inventory_columns

	var items := Inventory.get_owned_items()
	var total := maxi(inventory_min_slots, items.size())
	# Des lignes complètes : la navigation à la croix reste régulière.
	total = ceili(float(total) / inventory_columns) * inventory_columns

	for i in total:
		var item: ItemData = items[i] if i < items.size() else null
		_inv_grid.add_child(_make_item_slot(item))

	_show_item(items[0] if not items.is_empty() else null)


func _make_item_slot(item: ItemData) -> Button:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(inventory_slot_size, inventory_slot_size)
	slot.focus_mode = Control.FOCUS_ALL
	slot.expand_icon = true
	slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.focus_entered.connect(_show_item.bind(item))
	slot.mouse_entered.connect(slot.grab_focus)
	if item == null:
		return slot

	slot.icon = item.icon
	slot.tooltip_text = item.display_name
	var amount := Inventory.count(item.id)
	if amount > 1:
		var badge := Label.new()
		badge.text = "×%d" % amount
		badge.add_theme_font_size_override(&"font_size", small_size)
		badge.add_theme_color_override(&"font_outline_color", Color.BLACK)
		badge.add_theme_constant_override(&"outline_size", 4)
		badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(badge)
	return slot


func _show_item(item: ItemData) -> void:
	if item == null:
		_inv_icon.texture = null
		_inv_name.text = "Ton sac est vide." if Inventory.get_owned_items().is_empty() else "—"
		_inv_count.text = ""
		_inv_desc.text = ""
		return
	_inv_icon.texture = item.icon
	_inv_name.text = item.display_name
	_inv_count.text = "Possédé : %d" % Inventory.count(item.id)
	_inv_desc.text = item.description


func _on_inventory_changed(_id: StringName, _count: int) -> void:
	if _open and _top() == _inventory:
		_refresh_inventory()


# --- Sauvegarder / charger ------------------------------------------------

func _open_slots(save_mode: bool) -> void:
	_slots_save_mode = save_mode
	_slots_title.text = "Sauvegarder" if save_mode else "Charger"
	_push(_slots)


func _refresh_slots() -> void:
	_clear(_slots_list)
	var slots: Array[int] = []
	if not _slots_save_mode:
		# La sauvegarde automatique se charge, mais on n'y écrit pas soi-même.
		slots.append(SaveGame.AUTOSAVE_SLOT)
	for slot in range(1, SaveGame.slot_count + 1):
		slots.append(slot)
	for slot in slots:
		_slots_list.add_child(_make_save_slot(slot, SaveGame.get_slot_info(slot)))


func _make_save_slot(slot: int, info: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(560, 92)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_entered.connect(button.grab_focus)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	row.add_theme_constant_override(&"separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)

	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(128, 72)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.texture = info.get("thumbnail")
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(thumb)

	var lines := VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lines)

	var title := "Sauvegarde automatique" if slot == SaveGame.AUTOSAVE_SLOT else "Emplacement %d" % slot
	lines.add_child(_label(title, text_size, accent_color))

	var usable := false
	if not info.exists:
		lines.add_child(_label("Vide", small_size, dim_text_color))
	elif info.corrupted:
		lines.add_child(_label("Fichier abîmé, illisible", small_size, Color(1, 0.5, 0.45)))
	else:
		usable = true
		lines.add_child(_label("%s · %s" % [info.location, SaveGame.format_playtime(info.playtime)], small_size, text_color))
		var date := SaveGame.format_date(info.saved_at)
		if info.from_backup:
			date += "  (copie de secours)"
		lines.add_child(_label(date, small_size, dim_text_color))

	if _slots_save_mode:
		button.pressed.connect(_on_save_slot_pressed.bind(slot, info.exists))
	else:
		button.disabled = not usable
		button.pressed.connect(_on_load_slot_pressed.bind(slot))
	return button


func _on_save_slot_pressed(slot: int, exists: bool) -> void:
	if exists:
		_ask("Écraser l'emplacement %d ?" % slot, _save_to.bind(slot))
	else:
		_save_to(slot)


func _save_to(slot: int) -> void:
	var focused_index := _focused_index(_slots_list)
	SaveGame.save_slot(slot)
	_refresh_slots()
	# La liste vient d'être reconstruite : on remet la sélection au même rang.
	if focused_index >= 0 and focused_index < _slots_list.get_child_count():
		(_slots_list.get_child(focused_index) as Control).grab_focus()


func _on_load_slot_pressed(slot: int) -> void:
	_ask("Charger cette partie ?\nLa progression non sauvegardée sera perdue.", _load_from.bind(slot))


func _load_from(slot: int) -> void:
	close()
	if await SaveGame.load_slot(slot):
		_show_toast("Partie chargée")


func _on_saved(slot: int) -> void:
	_show_toast("Sauvegarde automatique" if slot == SaveGame.AUTOSAVE_SLOT else "Partie sauvegardée")


func _on_save_failed(_slot: int, message: String) -> void:
	_show_toast(message, Color(1, 0.5, 0.45))


# --- Petits outils --------------------------------------------------------

func _show_toast(message: String, color: Color = accent_color) -> void:
	_toast.text = message
	_toast.add_theme_color_override(&"font_color", color)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, ^"modulate:a", 0.0, 0.5)


func _update_hint(window: Control) -> void:
	var hint: Label = _hints.get(window)
	if hint == null:
		return
	if _gamepad():
		hint.text = "A : valider     B : retour     Start : fermer"
	else:
		hint.text = "Entrée : valider     Retour arrière : retour     Échap : fermer"


func _gamepad() -> bool:
	var device := get_node_or_null(^"/root/InputDevice")
	return device != null and bool(device.call(&"is_gamepad"))


func _focused_index(container: Node) -> int:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and focused.get_parent() == container:
		return focused.get_index()
	return -1


static func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# --- Construction de l'interface ------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = _make_theme()
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.color = backdrop_color
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)

	_main = _build_main()
	_inventory = _build_inventory()
	_slots = _build_slots()
	_confirm = _build_confirm()

	_toast = Label.new()
	_toast.add_theme_font_size_override(&"font_size", text_size)
	_toast.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override(&"outline_size", 6)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hors de _root : les messages restent visibles une fois le menu fermé.
	add_child(_toast)


## Une fenêtre centrée : titre, contenu, rappel des touches. Renvoie le
## conteneur à remplir ; la fenêtre elle-même est son ancêtre dans _root.
func _make_window(title: String) -> Array:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 16)
	panel.add_child(column)

	var title_label := _label(title, title_size, accent_color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title_label)

	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 10)
	column.add_child(body)

	var hint := _label("", small_size, dim_text_color)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	_hints[center] = hint

	return [center, body, title_label]


func _build_main() -> Control:
	var parts := _make_window("Pause")
	var body: VBoxContainer = parts[1]
	for entry in [
		["Reprendre", _on_resume],
		["Inventaire", func() -> void: _push(_inventory)],
		["Sauvegarder", _open_slots.bind(true)],
		["Charger", _open_slots.bind(false)],
		["Quitter le jeu", _on_quit],
	]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(320, 0)
		button.pressed.connect(entry[1])
		button.mouse_entered.connect(button.grab_focus)
		body.add_child(button)
	return parts[0]


func _build_inventory() -> Control:
	var parts := _make_window("Inventaire")
	var body: VBoxContainer = parts[1]

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	body.add_child(row)

	_inv_grid = GridContainer.new()
	_inv_grid.columns = inventory_columns
	_inv_grid.add_theme_constant_override(&"h_separation", 6)
	_inv_grid.add_theme_constant_override(&"v_separation", 6)
	row.add_child(_inv_grid)

	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(280, 0)
	detail.add_theme_constant_override(&"separation", 8)
	row.add_child(detail)

	_inv_icon = TextureRect.new()
	_inv_icon.custom_minimum_size = Vector2(96, 96)
	_inv_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_inv_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_inv_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail.add_child(_inv_icon)

	_inv_name = _label("", text_size, accent_color)
	detail.add_child(_inv_name)
	_inv_count = _label("", small_size, dim_text_color)
	detail.add_child(_inv_count)
	_inv_desc = _label("", small_size, text_color)
	_inv_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inv_desc.custom_minimum_size = Vector2(280, 0)
	detail.add_child(_inv_desc)

	# Icônes en pixel art : pas de flou à l'agrandissement.
	_inv_grid.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return parts[0]


func _build_slots() -> Control:
	var parts := _make_window("Sauvegarder")
	_slots_title = parts[2]
	_slots_list = VBoxContainer.new()
	_slots_list.add_theme_constant_override(&"separation", 8)
	(parts[1] as VBoxContainer).add_child(_slots_list)
	return parts[0]


func _build_confirm() -> Control:
	var parts := _make_window("Confirmation")
	var body: VBoxContainer = parts[1]

	_confirm_label = _label("", text_size, text_color)
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_confirm_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 16)
	body.add_child(row)

	_confirm_yes = Button.new()
	_confirm_yes.text = "Oui"
	_confirm_yes.custom_minimum_size = Vector2(140, 0)
	_confirm_yes.pressed.connect(_on_confirm_yes)
	_confirm_yes.mouse_entered.connect(_confirm_yes.grab_focus)
	row.add_child(_confirm_yes)

	_confirm_no = Button.new()
	_confirm_no.text = "Non"
	_confirm_no.custom_minimum_size = Vector2(140, 0)
	_confirm_no.pressed.connect(back)
	_confirm_no.mouse_entered.connect(_confirm_no.grab_focus)
	row.add_child(_confirm_no)
	return parts[0]


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.set_stylebox(&"panel", &"PanelContainer", _box(panel_color, accent_color.darkened(0.3), 2, 12, 24))

	theme.set_stylebox(&"normal", &"Button", _box(button_color, Color.TRANSPARENT, 0, 8, 10))
	theme.set_stylebox(&"hover", &"Button", _box(button_color.lightened(0.1), Color.TRANSPARENT, 0, 8, 10))
	theme.set_stylebox(&"pressed", &"Button", _box(accent_color.darkened(0.6), Color.TRANSPARENT, 0, 8, 10))
	theme.set_stylebox(&"disabled", &"Button", _box(Color(1, 1, 1, 0.02), Color.TRANSPARENT, 0, 8, 10))
	# Dessinée par-dessus les autres : le cadre doré montre la sélection,
	# indispensable à la manette.
	theme.set_stylebox(&"focus", &"Button", _box(Color.TRANSPARENT, accent_color, 3, 8, 10))

	theme.set_font_size(&"font_size", &"Button", text_size)
	theme.set_color(&"font_color", &"Button", text_color)
	theme.set_color(&"font_hover_color", &"Button", accent_color)
	theme.set_color(&"font_focus_color", &"Button", accent_color)
	theme.set_color(&"font_pressed_color", &"Button", accent_color)
	theme.set_color(&"font_disabled_color", &"Button", dim_text_color.darkened(0.3))
	theme.set_font_size(&"font_size", &"Label", text_size)
	theme.set_color(&"font_color", &"Label", text_color)
	return theme


static func _box(bg: Color, border: Color, border_width: int, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box
