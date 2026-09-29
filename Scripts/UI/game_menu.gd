extends CanvasLayer

## Le menu du jeu, chargé en autoload sous le nom "GameMenu" : pause,
## fenêtre Personnage (inventaire, équipement, compétences), sauvegarde,
## chargement et paramètres (écran, son, commandes).
##
## Touches (Projet → Paramètres du projet → Contrôles) :
##   menu               Échap / Start          ouvre ou ferme le menu
##   inventory          I / Select             ouvre directement l'inventaire
##   menu_back          Retour arrière / B     revient à la fenêtre précédente
##   menu_tab_prev/next A E (AZERTY) / LB RB   onglet précédent / suivant
##   menu_filter_*      W C (AZERTY) / LT RT   filtre de l'inventaire
##
## Les fenêtres s'empilent : chaque « retour » ferme celle du dessus et rend
## la sélection là où on l'avait laissée. Retour sur la dernière = le menu se
## ferme. Le jeu est en pause tant que le menu est ouvert.
##
## Toute l'interface est construite en code (_build) : l'apparence se règle
## avec les champs du groupe « Apparence ».

signal opened
signal closed

## Le script de SaveGame, pour appeler ses fonctions statiques sans passer
## par l'instance de l'autoload.
const SaveGameScript := preload("res://Scripts/Save/save_game.gd")

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
## Taille (px) de toutes les fenêtres du menu. Elle est la même pour toutes
## et ne bouge jamais : ce qui dépasse défile à l'intérieur.
@export var window_size: Vector2 = Vector2(900, 560)

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
var _character: Control
var _slots: Control
var _settings: Control
var _settings_view: SettingsView
var _confirm: Control
var _hints: Dictionary[Control, Label] = {}

## Les onglets de la fenêtre Personnage, dans l'ordre de TAB_NAMES.
enum Tab { ITEMS, EQUIPMENT, SKILLS }
const TAB_NAMES: PackedStringArray = ["Inventaire", "Équipement", "Compétences"]
var _tab: int = Tab.ITEMS
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _tab_prev_key: Label
var _tab_next_key: Label

## Filtre de l'onglet Inventaire : -1 = tout, sinon une ItemData.Category.
var _filter: int = -1
var _filter_buttons: Array[Button] = []
var _filter_prev_key: Label
var _filter_next_key: Label

var _inv_grid: GridContainer
var _inv_icon: TextureRect
var _inv_name: Label
var _inv_count: Label
var _inv_desc: Label

var _eq_slot: int = 0
var _eq_part: WeaponPartData
var _eq_slot_buttons: Dictionary[int, Button] = {}
var _eq_totals: Label
var _eq_parts_title: Label
var _eq_parts: VBoxContainer
var _eq_name: Label
var _eq_desc: Label
var _eq_stats: Label
var _eq_action: Label

var _sk_current: SkillData
var _sk_list: VBoxContainer
var _sk_count: Label
var _sk_icon: TextureRect
var _sk_name: Label
var _sk_input: Label
var _sk_desc: Label

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
	# InputDevice et Settings sont chargés après GameMenu : on attend qu'ils
	# soient là.
	_connect_late_autoloads.call_deferred()


func _input(event: InputEvent) -> void:
	if not _open:
		if event.is_action_pressed(&"menu") and _can_open():
			get_viewport().set_input_as_handled()
			open()
		elif event.is_action_pressed(&"inventory") and _can_open():
			get_viewport().set_input_as_handled()
			open(&"inventory")
		return

	# On attend la nouvelle touche d'une commande : la vue Paramètres garde
	# tout pour elle.
	if _settings_view.is_listening():
		return
	if event.is_action_pressed(&"menu"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed(&"inventory") and _top() == _character:
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed(&"menu_back") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


# Onglets et filtres ici plutôt que dans _input : les gâchettes (LT/RT) sont
# des axes qui envoient un flot d'événements, just_pressed n'en garde qu'un.
func _process(_delta: float) -> void:
	if not _open or _top() != _character:
		return
	if Input.is_action_just_pressed(&"menu_tab_prev"):
		_select_tab(wrapi(_tab - 1, 0, TAB_NAMES.size()))
	elif Input.is_action_just_pressed(&"menu_tab_next"):
		_select_tab(wrapi(_tab + 1, 0, TAB_NAMES.size()))
	elif _tab == Tab.ITEMS:
		# Les filtres vont de -1 (tout) à la dernière catégorie, en boucle.
		var count := ItemData.CATEGORY_NAMES.size() + 1
		if Input.is_action_just_pressed(&"menu_filter_prev"):
			_set_filter(wrapi(_filter, 0, count) - 1)
		elif Input.is_action_just_pressed(&"menu_filter_next"):
			_set_filter(wrapi(_filter + 2, 0, count) - 1)


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
	for window in [_main, _character, _slots, _settings, _confirm]:
		window.visible = false
	if start == &"inventory":
		_tab = Tab.ITEMS
		_push(_character)
	else:
		_push(_main)
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
	var scene := get_tree().current_scene
	if get_tree().paused or scene == null or scene.is_in_group(&"title_screen"):
		return false
	return not Dialogues.is_active() and not SaveGame.is_busy()


func _refresh(window: Control) -> void:
	if window == _character:
		_refresh_character()
	elif window == _slots:
		_refresh_slots()
	elif window == _settings:
		_settings_view.refresh()


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
		# Onglet caché : ses boutons ne comptent pas.
		var control := child as Control
		if control != null and not control.visible:
			continue
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


# --- Personnage ----------------------------------------------------------

func _select_tab(tab: int) -> void:
	_tab = tab
	_refresh_character()
	_update_hint(_character)
	_focus_default(_character)


func _refresh_character() -> void:
	for i in _pages.size():
		_pages[i].visible = i == _tab
		_tab_buttons[i].set_pressed_no_signal(i == _tab)
	match _tab:
		Tab.ITEMS:
			_refresh_items()
		Tab.EQUIPMENT:
			_refresh_equipment()
		Tab.SKILLS:
			_refresh_skills()


func _on_inventory_changed(_id: StringName, _count: int) -> void:
	if _open and _top() == _character:
		_refresh_character()


# --- Onglet Inventaire ----------------------------------------------------

func _set_filter(filter: int) -> void:
	_filter = filter
	_refresh_items()
	_update_hint(_character)
	_focus_default(_pages[Tab.ITEMS])


## Les objets de l'onglet : tout sauf les pièces du revolver (elles ont leur
## onglet), et seulement ceux du filtre choisi.
func _shown_items() -> Array[ItemData]:
	var shown: Array[ItemData] = []
	for item in Inventory.get_owned_items():
		if item is WeaponPartData:
			continue
		if _filter >= 0 and item.category != _filter:
			continue
		shown.append(item)
	return shown


func _refresh_items() -> void:
	for i in _filter_buttons.size():
		_filter_buttons[i].set_pressed_no_signal(i == _filter + 1)

	_clear(_inv_grid)
	_inv_grid.columns = inventory_columns

	var items := _shown_items()
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
		if not _shown_items().is_empty():
			_inv_name.text = "—"
		elif _filter < 0:
			_inv_name.text = "Ton sac est vide."
		else:
			_inv_name.text = "Rien dans cette catégorie."
		_inv_count.text = ""
		_inv_desc.text = ""
		return
	_inv_icon.texture = item.icon
	_inv_name.text = item.display_name
	_inv_count.text = "%s · Possédé : %d" % [ItemData.CATEGORY_NAMES[item.category], Inventory.count(item.id)]
	_inv_desc.text = item.description


# --- Onglet Équipement ----------------------------------------------------

func _refresh_equipment() -> void:
	for slot in _eq_slot_buttons:
		var part := Equipment.get_part(slot)
		_eq_slot_buttons[slot].text = "%s : %s" % [WeaponPartData.SLOT_NAMES[slot], part.display_name if part != null else "—"]
	var stats := Equipment.stats_text()
	if stats == "":
		_eq_totals.text = "Aucune pièce montée : le revolver est d'origine."
	else:
		_eq_totals.text = "Bonus du revolver :\n" + stats.replace(" · ", "\n")
	_show_slot(_eq_slot)


## Liste à droite les pièces possédées pour cet emplacement.
func _show_slot(slot: int) -> void:
	_eq_slot = slot
	_eq_parts_title.text = "Emplacement : %s" % WeaponPartData.SLOT_NAMES[slot]
	_clear(_eq_parts)

	var parts := Equipment.get_owned_parts(slot)
	if parts.is_empty():
		_eq_parts.add_child(_label("Aucune pièce de ce type pour l'instant.", small_size, dim_text_color))
	for part in parts:
		var button := Button.new()
		button.text = part.display_name
		if Equipment.is_equipped(part.id):
			button.text += "  · montée"
		button.icon = part.icon
		button.add_theme_constant_override(&"icon_max_width", 32)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.focus_entered.connect(_show_part.bind(part))
		button.mouse_entered.connect(button.grab_focus)
		button.pressed.connect(_on_part_pressed.bind(part))
		_eq_parts.add_child(button)
		# Vers la gauche, on revient toujours sur l'emplacement qu'on regardait.
		button.focus_neighbor_left = button.get_path_to(_eq_slot_buttons[slot])

	_show_part(Equipment.get_part(slot))


func _show_part(part: WeaponPartData) -> void:
	_eq_part = part
	if part == null:
		_eq_name.text = "Rien de monté"
		if Equipment.get_owned_parts(_eq_slot).is_empty():
			_eq_desc.text = "Trouve des pièces pour améliorer le revolver."
		else:
			_eq_desc.text = "Choisis une pièce dans la liste pour la monter."
		_eq_stats.text = ""
		_eq_action.text = ""
		return
	_eq_name.text = part.display_name
	_eq_desc.text = part.description
	_eq_stats.text = part.stats_text()
	var mounted := Equipment.is_equipped(part.id)
	_eq_action.text = "%s : %s" % [_key(&"ui_accept"), "retirer" if mounted else "monter"]


## Valider sur un emplacement : on passe à la liste de ses pièces.
func _focus_parts() -> void:
	var first := _first_focusable(_eq_parts)
	if first != null:
		first.grab_focus()


func _on_part_pressed(part: WeaponPartData) -> void:
	var index := _focused_index(_eq_parts)
	if Equipment.is_equipped(part.id):
		Equipment.unequip(part.slot)
	else:
		Equipment.equip(part.id)
	_refresh_equipment()
	# La liste vient d'être reconstruite : on remet la sélection au même rang.
	if index >= 0 and index < _eq_parts.get_child_count():
		(_eq_parts.get_child(index) as Control).grab_focus()


# --- Onglet Compétences ---------------------------------------------------

func _refresh_skills() -> void:
	_clear(_sk_list)
	var owned := Skills.get_owned_skills()
	_sk_count.text = "%d / %d compétences" % [owned.size(), Skills.total_count()]
	for skill in owned:
		var button := Button.new()
		button.text = skill.display_name
		button.icon = skill.icon
		button.add_theme_constant_override(&"icon_max_width", 32)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.focus_entered.connect(_show_skill.bind(skill))
		button.mouse_entered.connect(button.grab_focus)
		_sk_list.add_child(button)
	_show_skill(owned[0] if not owned.is_empty() else null)


func _show_skill(skill: SkillData) -> void:
	_sk_current = skill
	if skill == null:
		_sk_icon.texture = null
		_sk_name.text = "Aucune compétence"
		_sk_input.text = ""
		_sk_desc.text = ""
		return
	_sk_icon.texture = skill.icon
	_sk_icon.visible = skill.icon != null
	_sk_name.text = skill.display_name
	var keys: PackedStringArray = []
	for action in skill.actions:
		var key := _key(action)
		if key != "" and not keys.has(key):
			keys.append(key)
	_sk_input.text = "Commande : " + " / ".join(keys) if not keys.is_empty() else ""
	_sk_desc.text = skill.description


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
	button.custom_minimum_size = Vector2(0, 92)
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
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		var place := _label("%s · %s" % [info.location, SaveGameScript.format_playtime(info.playtime)], small_size, text_color)
		# Un nom de lieu trop long est coupé plutôt que d'élargir la fenêtre.
		place.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lines.add_child(place)
		var date := SaveGameScript.format_date(info.saved_at)
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
	var parts: PackedStringArray = []
	if window == _character:
		parts.append("%s %s : onglet" % [_key(&"menu_tab_prev"), _key(&"menu_tab_next")])
		if _tab == Tab.ITEMS:
			parts.append("%s %s : filtre" % [_key(&"menu_filter_prev"), _key(&"menu_filter_next")])
	parts.append("%s : valider" % _key(&"ui_accept"))
	parts.append("%s : retour" % _key(&"menu_back"))
	parts.append("%s : fermer" % _key(&"menu"))
	hint.text = "     ".join(parts)

	if window == _character:
		_tab_prev_key.text = "‹ " + _key(&"menu_tab_prev")
		_tab_next_key.text = _key(&"menu_tab_next") + " ›"
		_filter_prev_key.text = "‹ " + _key(&"menu_filter_prev")
		_filter_next_key.text = _key(&"menu_filter_next") + " ›"


## Rappel des touches : on bascule clavier ↔ manette dès qu'une manette est
## branchée ou débranchée, et on suit les commandes changées, même menu ouvert.
func _connect_late_autoloads() -> void:
	var device := get_node_or_null(^"/root/InputDevice")
	if device != null:
		device.connect(&"changed", _on_input_device_changed)
	var settings := get_node_or_null(^"/root/Settings")
	if settings != null:
		settings.connect(&"controls_changed", _on_input_device_changed.bind(false))


func _on_input_device_changed(_gamepad_connected: bool) -> void:
	for window in _hints:
		_update_hint(window)
	# Les touches affichées dans les détails changent aussi.
	if _open and _top() == _character:
		if _tab == Tab.EQUIPMENT:
			_show_part(_eq_part)
		elif _tab == Tab.SKILLS:
			_show_skill(_sk_current)


## Nom de la touche d'une action, clavier ou manette selon ce qui est branché.
func _key(action: StringName) -> String:
	var device := get_node_or_null(^"/root/InputDevice")
	return String(device.call(&"action_label", action)) if device != null else ""


func _focused_index(container: Node) -> int:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and focused.get_parent() == container:
		return focused.get_index()
	return -1


static func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


## Texte sur plusieurs lignes, coupé au-delà de `max_lines` pour ne jamais
## agrandir la fenêtre.
func _wrapped_label(size: int, color: Color, max_lines: int) -> Label:
	var label := _label("", size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = max_lines
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


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
	_character = _build_character()
	_slots = _build_slots()
	_settings = _build_settings()
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

	# Taille fixe : la fenêtre ne change pas de taille d'un écran à l'autre.
	var panel := PanelContainer.new()
	panel.custom_minimum_size = window_size
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 16)
	panel.add_child(column)

	var title_label := _label(title, title_size, accent_color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title_label)

	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	var hint := _label("", small_size, dim_text_color)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Un rappel trop long est coupé plutôt que d'élargir la fenêtre.
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(hint)
	_hints[center] = hint

	return [center, body, title_label]


## Zone qui défile verticalement et suit la sélection (manette comprise).
func _make_scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return scroll


func _build_main() -> Control:
	var parts := _make_window("Pause")
	var body: VBoxContainer = parts[1]
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	for entry in [
		["Reprendre", _on_resume],
		["Personnage", func() -> void: _push(_character)],
		["Sauvegarder", _open_slots.bind(true)],
		["Charger", _open_slots.bind(false)],
		["Paramètres", func() -> void: _push(_settings)],
		["Quitter le jeu", _on_quit],
	]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(320, 0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(entry[1])
		button.mouse_entered.connect(button.grab_focus)
		body.add_child(button)
	return parts[0]


func _build_character() -> Control:
	var parts := _make_window("Personnage")
	var body: VBoxContainer = parts[1]
	# Les onglets font office de titre.
	(parts[2] as Label).visible = false

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override(&"separation", 12)
	body.add_child(bar)
	_tab_prev_key = _label("", small_size, dim_text_color)
	bar.add_child(_tab_prev_key)
	for i in TAB_NAMES.size():
		var tab := Button.new()
		tab.text = TAB_NAMES[i]
		tab.toggle_mode = true
		# Pas de sélection à la croix : on change d'onglet avec menu_tab_*,
		# la croix reste au contenu de l'onglet.
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(200, 0)
		tab.pressed.connect(_select_tab.bind(i))
		bar.add_child(tab)
		_tab_buttons.append(tab)
	_tab_next_key = _label("", small_size, dim_text_color)
	bar.add_child(_tab_next_key)

	_pages.append(_build_items_page())
	_pages.append(_build_equipment_page())
	_pages.append(_build_skills_page())
	for page in _pages:
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(page)
	return parts[0]


func _build_items_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override(&"separation", 12)

	var filters := HBoxContainer.new()
	filters.alignment = BoxContainer.ALIGNMENT_CENTER
	filters.add_theme_constant_override(&"separation", 6)
	page.add_child(filters)
	_filter_prev_key = _label("", small_size, dim_text_color)
	filters.add_child(_filter_prev_key)
	var names: PackedStringArray = ["Tout"]
	names.append_array(ItemData.CATEGORY_NAMES)
	for i in names.size():
		var filter := Button.new()
		filter.text = names[i]
		filter.toggle_mode = true
		filter.focus_mode = Control.FOCUS_NONE
		filter.add_theme_font_size_override(&"font_size", small_size)
		filter.pressed.connect(_set_filter.bind(i - 1))
		filters.add_child(filter)
		_filter_buttons.append(filter)
	_filter_next_key = _label("", small_size, dim_text_color)
	filters.add_child(_filter_next_key)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(row)

	# Beaucoup d'objets : la grille défile, la fenêtre ne grandit pas.
	var scroll := _make_scroll()
	scroll.custom_minimum_size.x = inventory_columns * inventory_slot_size + (inventory_columns - 1) * 6 + 12
	row.add_child(scroll)

	_inv_grid = GridContainer.new()
	_inv_grid.columns = inventory_columns
	_inv_grid.add_theme_constant_override(&"h_separation", 6)
	_inv_grid.add_theme_constant_override(&"v_separation", 6)
	# Icônes en pixel art : pas de flou à l'agrandissement.
	_inv_grid.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scroll.add_child(_inv_grid)

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
	_inv_desc = _wrapped_label(small_size, text_color, 8)
	_inv_desc.custom_minimum_size = Vector2(280, 0)
	detail.add_child(_inv_desc)
	return page


func _build_equipment_page() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override(&"separation", 32)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(320, 0)
	left.add_theme_constant_override(&"separation", 8)
	page.add_child(left)
	left.add_child(_label("Revolver", text_size, accent_color))
	for slot in WeaponPartData.Slot.values():
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.focus_entered.connect(_show_slot.bind(slot))
		button.mouse_entered.connect(button.grab_focus)
		button.pressed.connect(_focus_parts)
		left.add_child(button)
		_eq_slot_buttons[slot] = button
	_eq_totals = _wrapped_label(small_size, text_color, 5)
	left.add_child(_eq_totals)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 8)
	page.add_child(right)
	_eq_parts_title = _label("", text_size, accent_color)
	right.add_child(_eq_parts_title)
	var scroll := _make_scroll()
	right.add_child(scroll)
	_eq_parts = VBoxContainer.new()
	_eq_parts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_eq_parts.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_eq_parts)

	_eq_name = _label("", text_size, accent_color)
	right.add_child(_eq_name)
	_eq_desc = _wrapped_label(small_size, text_color, 3)
	right.add_child(_eq_desc)
	_eq_stats = _label("", small_size, accent_color)
	_eq_stats.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	right.add_child(_eq_stats)
	_eq_action = _label("", small_size, dim_text_color)
	right.add_child(_eq_action)
	return page


func _build_skills_page() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override(&"separation", 32)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(320, 0)
	left.add_theme_constant_override(&"separation", 8)
	page.add_child(left)
	_sk_count = _label("", small_size, dim_text_color)
	left.add_child(_sk_count)
	var scroll := _make_scroll()
	left.add_child(scroll)
	_sk_list = VBoxContainer.new()
	_sk_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sk_list.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_sk_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 8)
	page.add_child(right)
	_sk_icon = TextureRect.new()
	_sk_icon.custom_minimum_size = Vector2(96, 96)
	_sk_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sk_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sk_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	right.add_child(_sk_icon)
	_sk_name = _label("", title_size, accent_color)
	right.add_child(_sk_name)
	_sk_input = _label("", text_size, text_color)
	right.add_child(_sk_input)
	_sk_desc = _wrapped_label(small_size, text_color, 8)
	right.add_child(_sk_desc)
	return page


func _build_slots() -> Control:
	var parts := _make_window("Sauvegarder")
	_slots_title = parts[2]
	var scroll := _make_scroll()
	(parts[1] as VBoxContainer).add_child(scroll)
	_slots_list = VBoxContainer.new()
	_slots_list.add_theme_constant_override(&"separation", 8)
	_slots_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_slots_list)
	return parts[0]


func _build_settings() -> Control:
	var parts := _make_window("Paramètres")
	_settings_view = SettingsView.new()
	_settings_view.accent_color = accent_color
	_settings_view.dim_text_color = dim_text_color
	_settings_view.small_size = small_size
	(parts[1] as VBoxContainer).add_child(_settings_view)
	return parts[0]


func _build_confirm() -> Control:
	var parts := _make_window("Confirmation")
	var body: VBoxContainer = parts[1]
	body.alignment = BoxContainer.ALIGNMENT_CENTER

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
	# Onglet ou filtre choisi, sous la souris.
	theme.set_stylebox(&"hover_pressed", &"Button", _box(accent_color.darkened(0.5), Color.TRANSPARENT, 0, 8, 10))
	theme.set_stylebox(&"disabled", &"Button", _box(Color(1, 1, 1, 0.02), Color.TRANSPARENT, 0, 8, 10))
	# Dessinée par-dessus les autres : le cadre doré montre la sélection,
	# indispensable à la manette.
	theme.set_stylebox(&"focus", &"Button", _box(Color.TRANSPARENT, accent_color, 3, 8, 10))

	theme.set_font_size(&"font_size", &"Button", text_size)
	theme.set_color(&"font_color", &"Button", text_color)
	theme.set_color(&"font_hover_color", &"Button", accent_color)
	theme.set_color(&"font_focus_color", &"Button", accent_color)
	theme.set_color(&"font_pressed_color", &"Button", accent_color)
	theme.set_color(&"font_hover_pressed_color", &"Button", accent_color)
	theme.set_color(&"font_disabled_color", &"Button", dim_text_color.darkened(0.3))
	# Les cases à cocher (Paramètres) suivent les boutons.
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		theme.set_stylebox(state, &"CheckButton", theme.get_stylebox(state, &"Button"))
	theme.set_font_size(&"font_size", &"CheckButton", text_size)
	theme.set_color(&"font_color", &"CheckButton", text_color)
	theme.set_color(&"font_hover_color", &"CheckButton", accent_color)
	theme.set_color(&"font_focus_color", &"CheckButton", accent_color)
	theme.set_color(&"font_pressed_color", &"CheckButton", text_color)
	theme.set_color(&"font_hover_pressed_color", &"CheckButton", accent_color)
	# Le curseur du volume montre aussi la sélection.
	theme.set_stylebox(&"focus", &"HSlider", _box(Color.TRANSPARENT, accent_color, 3, 8, 4))
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
