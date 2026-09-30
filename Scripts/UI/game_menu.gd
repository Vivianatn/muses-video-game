extends CanvasLayer

## Le menu du jeu, chargé en autoload sous le nom "GameMenu" : pause,
## fenêtre Personnage (inventaire, équipement, compétences), sauvegarde,
## chargement, paramètres (plein écran, volume, touches) et retour à l'écran
## titre. On quitte le jeu depuis l'écran titre.
##
## L'écran titre s'en sert aussi, pour sa seule liste des sauvegardes :
## voir open_load_picker().
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
## Toute l'interface est construite en code (_build). Son apparence vient du
## thème du projet (Scenes/UI/muses_theme.tres, la DA « Muses ») : chaque
## nœud n'y choisit qu'un style, par son theme_type_variation.

signal opened
signal closed

## Le script de SaveGame, pour appeler ses fonctions statiques sans passer
## par l'instance de l'autoload.
const SaveGameScript := preload("res://Scripts/Save/save_game.gd")
const Motion := preload("res://Scripts/UI/motion.gd")
## L'écran titre, où mène le bouton « Écran titre » de la pause.
const TITLE_SCENE := "res://Scenes/UI/title_screen.tscn"
const ControlsPanelScript := preload("res://Scripts/UI/controls_panel.gd")

@export_group("Apparence")
## Taille (px) de toutes les fenêtres du menu. Elle est la même pour toutes
## et ne bouge jamais : ce qui dépasse défile à l'intérieur. La DA limite la
## largeur d'un panneau à 720 px.
@export var window_size: Vector2 = Vector2(720, 560)
## Durée (s) d'affichage d'une notification. Les suivantes attendent leur tour.
@export var notice_time: float = 3.0

@export_group("Inventaire")
## Nombre de cases par ligne.
@export var inventory_columns: int = 5
## Nombre de cases affichées au minimum, même vides.
@export var inventory_min_slots: int = 15
## Côté (px) d'une case.
@export var inventory_slot_size: int = Muses.EMPLACEMENT

var _open: bool = false
## Liste des sauvegardes ouverte depuis l'écran titre : reçoit l'emplacement
## choisi. Invalide en jeu, où l'on charge soi-même.
var _pick_slot: Callable
## Fenêtres ouvertes, de la plus ancienne à celle affichée.
var _stack: Array[Control] = []
## Pour chaque fenêtre recouverte, le bouton qui avait la sélection.
var _focus_memory: Dictionary[Control, Control] = {}

var _root: Control
var _main: Control
## Les boutons de la pause, qui entrent en cascade.
var _main_buttons: Array[Control] = []
var _character: Control
var _slots: Control
var _confirm: Control
var _settings: Control
## La fenêtre des touches : le panneau de l'écran titre, construit à la
## première ouverture (il interroge l'autoload Settings, chargé après ce menu).
var _controls: Control
var _fullscreen: CheckButton
var _volume: HSlider
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
var _inv_detail: VBoxContainer
var _inv_icon: TextureRect
var _inv_category: Label
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

## Notification en haut de l'écran : une à la fois, les suivantes attendent.
var _notice: Control
var _notice_category: Label
var _notice_text: Label
var _notice_tween: Tween
var _notice_queue: Array[Array] = []


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	# L'interface bouge au rythme de l'affichage (tweens, _process) : on la
	# sort de l'interpolation physique, qui ne vaut que pour le monde.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_build()
	_root.visible = false

	SaveGame.saved.connect(_on_saved)
	SaveGame.failed.connect(_on_save_failed)
	Inventory.changed.connect(_on_inventory_changed)
	# InputDevice est chargé après GameMenu : on attend qu'il soit là.
	_connect_input_device.call_deferred()
	_prewarm()


## Godot prépare polices et styles la première fois qu'il les dessine : sans
## ça, la toute première ouverture du menu fige le jeu un dixième de seconde.
## On dessine donc chaque fenêtre une fois au lancement, presque transparente
## (1 %), le temps d'une image ou deux.
func _prewarm() -> void:
	await get_tree().process_frame
	if _open:
		return
	_root.modulate.a = 0.01
	_root.visible = true
	var windows: Array[Control] = [_main, _slots, _confirm, _settings]
	for window in windows:
		_refresh(window)
		window.visible = true
		await _two_frames()
		window.visible = false
	# Les trois onglets de la fenêtre Personnage.
	_character.visible = true
	for tab in TAB_NAMES.size():
		_tab = tab
		_refresh_character()
		await _two_frames()
	_character.visible = false
	_tab = Tab.ITEMS
	if not _open:
		_root.visible = false
	_root.modulate.a = 1.0
	# Le bandeau de notification, lui aussi.
	_notice_category.text = "Sauvegarde"
	_notice_text.text = "Partie sauvegardée"
	_notice.modulate.a = 0.01
	await _two_frames()
	if _notice_tween == null or not _notice_tween.is_valid():
		_notice.modulate.a = 0.0


func _two_frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


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
	# Le voile et la fenêtre apparaissent en fondu.
	Motion.fade_in(_root, 0.18)
	_stack.clear()
	_focus_memory.clear()
	_hide_windows()
	if start == &"inventory":
		_tab = Tab.ITEMS
		_push(_character)
	else:
		_push(_main)
	opened.emit()


## Ouvre seulement la liste des sauvegardes, pour en choisir une (bouton
## « Charger » de l'écran titre). Rien n'est mis en pause : il n'y a pas de
## partie en cours. Le menu se referme au choix, puis `on_pick` reçoit
## l'emplacement : c'est à l'écran titre de le charger, avec sa transition.
func open_load_picker(on_pick: Callable) -> void:
	if _open:
		return
	_open = true
	_pick_slot = on_pick
	_root.visible = true
	Motion.fade_in(_root, 0.18)
	_stack.clear()
	_focus_memory.clear()
	_hide_windows()
	_open_slots(false)
	opened.emit()


func close() -> void:
	if not _open:
		return
	_open = false
	_pick_slot = Callable()
	# Fondu de sortie ; si le menu a été rouvert entre-temps, il reste visible.
	Motion.fade_out(_root, 0.15, func() -> void: _root.visible = _open)
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
	_animate_window(below, false)
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
	_animate_window(window, true)
	_update_hint(window)
	_focus_default(window)


## La fenêtre surgit ; celle de la pause fait entrer ses boutons un à un.
func _animate_window(window: Control, first_time: bool) -> void:
	Motion.pop_in(window.get_child(0) as Control)
	if first_time and window == _main:
		Motion.cascade(_main_buttons, Vector2(0, 14), 0.05)


func _top() -> Control:
	return null if _stack.is_empty() else _stack[-1]


func _can_open() -> bool:
	var scene := get_tree().current_scene
	if get_tree().paused or scene == null or scene.is_in_group(&"title_screen"):
		return false
	return not Dialogues.is_active() and not SaveGame.is_busy()


func _hide_windows() -> void:
	for window: Control in [_main, _character, _slots, _confirm, _settings, _controls]:
		if window != null:
			window.visible = false


func _refresh(window: Control) -> void:
	if window == _character:
		_refresh_character()
	elif window == _slots:
		_refresh_slots()
	elif window == _settings:
		# set_value_no_signal : afficher l'état actuel sans le réenregistrer.
		_fullscreen.set_pressed_no_signal(Settings.fullscreen)
		_volume.set_value_no_signal(Settings.master_volume)
	elif window == _controls:
		(window.get_child(0) as Control).call(&"open")


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


func _on_title_screen() -> void:
	_ask("Retourner à l'écran titre ?\nLa progression non sauvegardée sera perdue.", _go_to_title)


## Retour à l'écran titre : fondu vers la nuit, puis l'écran titre, qui fait
## sa propre entrée. Le voile vit à la racine de l'arbre, au-dessus de tout :
## le changement de scène ne l'emporte pas et son image vide ne se voit pas.
func _go_to_title() -> void:
	close()
	var cover := CanvasLayer.new()
	cover.layer = 100
	cover.process_mode = Node.PROCESS_MODE_ALWAYS
	cover.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var veil := ColorRect.new()
	veil.color = Color(Muses.NUIT, 0.0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(veil)
	get_tree().root.add_child(cover)

	var tween := cover.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(veil, ^"color:a", 1.0, 0.35)
	await tween.finished
	# Fond « nuit » tant qu'on est hors du jeu (l'écran titre le rétablit en
	# repartant vers une partie).
	RenderingServer.set_default_clear_color(Muses.NUIT)
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
	while get_tree().current_scene == null or get_tree().current_scene.scene_file_path != TITLE_SCENE:
		await get_tree().process_frame

	tween = cover.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(veil, ^"color:a", 0.0, 0.3)
	await tween.finished
	cover.queue_free()


# --- Personnage ----------------------------------------------------------

func _select_tab(tab: int) -> void:
	_tab = tab
	_refresh_character()
	_update_hint(_character)
	_focus_default(_character)
	Motion.fade_in(_pages[_tab], 0.18)
	if _tab == Tab.ITEMS:
		_cascade_slots()


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
	_cascade_slots()


## Les cases de l'inventaire se posent une à une, en vague rapide.
func _cascade_slots() -> void:
	Motion.cascade(_inv_grid.get_children(), Vector2(0, 8), 0.012, 0.2)


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
	slot.theme_type_variation = &"EmplacementVide" if item == null else &"Emplacement"
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
		# La quantité, en bas à droite du fond de la case.
		var badge := _label(str(amount), &"Quantite")
		badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE)
		badge.position -= Vector2(Muses.TRAIT + 6, Muses.TRAIT + 4)
		slot.add_child(badge)
	return slot


func _show_item(item: ItemData) -> void:
	# Sans objet, seule une phrase reste : centrée dans la colonne, sans la
	# place vide de l'icône et des étiquettes au-dessus d'elle.
	var empty := item == null
	for part: Control in [_inv_icon, _inv_category, _inv_name, _inv_count]:
		part.visible = not empty
	_inv_detail.alignment = BoxContainer.ALIGNMENT_CENTER if empty else BoxContainer.ALIGNMENT_BEGIN
	_inv_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if empty else HORIZONTAL_ALIGNMENT_LEFT
	if empty:
		_inv_icon.texture = null
		if not _shown_items().is_empty():
			_inv_desc.text = ""
		elif _filter < 0:
			_inv_desc.text = "Ton sac est vide."
		else:
			_inv_desc.text = "Rien dans cette catégorie."
		return
	_inv_icon.texture = item.icon
	_inv_category.text = ItemData.CATEGORY_NAMES[item.category]
	_inv_name.text = item.display_name
	_inv_count.text = "Possédé : %d" % Inventory.count(item.id)
	_inv_desc.text = item.description


# --- Onglet Équipement ----------------------------------------------------

func _refresh_equipment() -> void:
	for slot in _eq_slot_buttons:
		var part := Equipment.get_part(slot)
		_eq_slot_buttons[slot].text = ("%s : %s" % [WeaponPartData.SLOT_NAMES[slot], part.display_name if part != null else "—"]).to_upper()
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
		_eq_parts.add_child(_label("Aucune pièce de ce type pour l'instant.", &"Legende"))
	for part in parts:
		var label := part.display_name
		if Equipment.is_equipped(part.id):
			label += "  · montée"
		var button := _button(label)
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
		var button := _button(skill.display_name)
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
	var button := _button("")
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
	lines.add_child(_label(title, &"NomObjet"))

	var usable := false
	if not info.exists:
		lines.add_child(_label("Vide", &"Legende"))
	elif info.corrupted:
		var broken := _label("Fichier abîmé, illisible", &"Legende")
		# Pas de rouge dans la DA : le cuivre signale le problème.
		broken.add_theme_color_override(&"font_color", Muses.CUIVRE)
		lines.add_child(broken)
	else:
		usable = true
		var place := _label("%s · %s" % [info.location, SaveGameScript.format_playtime(info.playtime)])
		# Un nom de lieu trop long est coupé plutôt que d'élargir la fenêtre.
		place.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lines.add_child(place)
		var date := SaveGameScript.format_date(info.saved_at)
		if info.from_backup:
			date += "  (copie de secours)"
		lines.add_child(_label(date, &"HudEtiquette"))

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
	# Depuis l'écran titre, pas de partie à perdre : on rend le choix tout de suite.
	if _pick_slot.is_valid():
		var pick := _pick_slot
		close()
		pick.call(slot)
		return
	_ask("Charger cette partie ?\nLa progression non sauvegardée sera perdue.", _load_from.bind(slot))


func _load_from(slot: int) -> void:
	close()
	if await SaveGame.load_slot(slot):
		_notify("Chargement", "Partie chargée")


func _on_saved(slot: int) -> void:
	_notify("Sauvegarde", "Sauvegarde automatique" if slot == SaveGame.AUTOSAVE_SLOT else "Partie sauvegardée")


func _on_save_failed(_slot: int, message: String) -> void:
	_notify("Échec", message, true)


# --- Notifications --------------------------------------------------------

## Annonce en haut de l'écran (DA « Notification ») : une catégorie, un texte.
## Une seule à la fois ; les suivantes attendent leur tour. `problem` passe la
## catégorie en cuivre, la DA n'ayant pas de rouge.
func _notify(category: String, text: String, problem: bool = false) -> void:
	_notice_queue.append([category, text, problem])
	if _notice_tween == null or not _notice_tween.is_valid():
		_show_next_notice()


func _show_next_notice() -> void:
	if _notice_queue.is_empty():
		return
	var entry: Array = _notice_queue.pop_front()
	_notice_category.text = entry[0]
	_notice_category.add_theme_color_override(&"font_color", Muses.CUIVRE if entry[2] else Muses.SEVE)
	_notice_text.text = entry[1]
	# Le bandeau descend en apparaissant, puis remonte en s'effaçant.
	var rest := float(Muses.ESPACE_4)
	_notice.position.y = rest - 20.0
	_notice_tween = create_tween()
	_notice_tween.tween_property(_notice, ^"modulate:a", 1.0, 0.2)
	_notice_tween.parallel().tween_property(_notice, ^"position:y", rest, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_notice_tween.tween_interval(notice_time)
	_notice_tween.tween_property(_notice, ^"modulate:a", 0.0, 0.3)
	_notice_tween.parallel().tween_property(_notice, ^"position:y", rest - 12.0, 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_notice_tween.tween_callback(_show_next_notice)


# --- Petits outils --------------------------------------------------------


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
	hint.text = "   ".join(parts)

	if window == _character:
		_tab_prev_key.text = "‹ " + _key(&"menu_tab_prev")
		_tab_next_key.text = _key(&"menu_tab_next") + " ›"
		_filter_prev_key.text = "‹ " + _key(&"menu_filter_prev")
		_filter_next_key.text = _key(&"menu_filter_next") + " ›"


## Rappel des touches : on bascule clavier ↔ manette dès qu'une manette est
## branchée ou débranchée, même menu ouvert.
func _connect_input_device() -> void:
	var device := get_node_or_null(^"/root/InputDevice")
	if device != null:
		device.connect(&"changed", _on_input_device_changed)
	# F11 change aussi le plein écran : l'interrupteur des paramètres suit.
	var settings := get_node_or_null(^"/root/Settings")
	if settings != null:
		settings.connect(&"fullscreen_changed", _fullscreen.set_pressed_no_signal)


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
func _wrapped_label(style: StringName, max_lines: int) -> Label:
	var label := _label("", style)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = max_lines
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


## Un texte dans un des styles du thème (vide = le récit). Tous sont en
## capitales, sauf ceux qui se lisent : le récit et la légende.
func _label(text: String, style: StringName = &"") -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = style
	label.uppercase = style not in [&"", &"Legende"]
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Un bouton de la DA, libellé en capitales. `style` vide = le bouton
## principal, un seul par fenêtre.
func _button(text: String, style: StringName = &"BoutonSecondaire") -> Button:
	var button := Button.new()
	button.text = text.to_upper()
	button.theme_type_variation = style
	button.custom_minimum_size.y = Muses.CIBLE_MIN
	return button


## Le séparateur sous l'en-tête d'un panneau, en retrait des bords.
static func _make_circuit() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", Muses.ESPACE_3)
	margin.add_theme_constant_override(&"margin_right", Muses.ESPACE_3)
	margin.add_child(Circuit.new())
	return margin


# --- Construction de l'interface ------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Un seul panneau au premier plan : le jeu derrière s'assombrit.
	var backdrop := ColorRect.new()
	backdrop.color = Muses.VOILE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)

	_main = _build_main()
	_character = _build_character()
	_slots = _build_slots()
	_confirm = _build_confirm()
	_settings = _build_settings()
	# Hors de _root : les notifications restent visibles une fois le menu fermé.
	_notice = _build_notice()
	add_child(_notice)


## Une fenêtre centrée (DA « Panneau ») : en-tête bordeaux, circuit, contenu,
## rappel des touches. Renvoie la fenêtre (son ancêtre dans _root), le
## conteneur à remplir et le titre.
func _make_window(title: String) -> Array:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	# Taille fixe : la fenêtre ne change pas de taille d'un écran à l'autre.
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanneauEntete"
	panel.custom_minimum_size = window_size
	center.add_child(panel)

	var frame := VBoxContainer.new()
	frame.add_theme_constant_override(&"separation", 0)
	panel.add_child(frame)

	var header := PanelContainer.new()
	header.theme_type_variation = &"Entete"
	frame.add_child(header)
	var title_label := _label(title, &"TitrePanneau")
	header.add_child(title_label)
	frame.add_child(_make_circuit())

	var content := MarginContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		content.add_theme_constant_override(side, Muses.ESPACE_3)
	frame.add_child(content)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", Muses.ESPACE_2)
	content.add_child(column)

	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	var hint := _label("", &"HudEtiquette")
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
		["Écran titre", _on_title_screen],
	]:
		# « Reprendre », l'action attendue, est le seul bouton principal.
		var button := _button(entry[0], &"" if body.get_child_count() == 0 else &"BoutonSecondaire")
		button.custom_minimum_size.x = 320
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(entry[1])
		button.mouse_entered.connect(button.grab_focus)
		body.add_child(button)
		_main_buttons.append(button)
	return parts[0]


func _build_character() -> Control:
	var parts := _make_window("Personnage")
	var body: VBoxContainer = parts[1]

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override(&"separation", Muses.ESPACE_1)
	body.add_child(bar)
	_tab_prev_key = _label("", &"HudEtiquette")
	bar.add_child(_tab_prev_key)
	for i in TAB_NAMES.size():
		# L'onglet choisi prend la face bordeaux de l'appui.
		var tab := _button(TAB_NAMES[i])
		tab.toggle_mode = true
		# Pas de sélection à la croix : on change d'onglet avec menu_tab_*,
		# la croix reste au contenu de l'onglet.
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size.x = 170
		tab.pressed.connect(_select_tab.bind(i))
		bar.add_child(tab)
		_tab_buttons.append(tab)
	_tab_next_key = _label("", &"HudEtiquette")
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
	_filter_prev_key = _label("", &"HudEtiquette")
	filters.add_child(_filter_prev_key)
	var names: PackedStringArray = ["Tout"]
	names.append_array(ItemData.CATEGORY_NAMES)
	for i in names.size():
		var filter := _button(names[i], &"Filtre")
		filter.toggle_mode = true
		filter.focus_mode = Control.FOCUS_NONE
		filter.pressed.connect(_set_filter.bind(i - 1))
		filters.add_child(filter)
		_filter_buttons.append(filter)
	_filter_next_key = _label("", &"HudEtiquette")
	filters.add_child(_filter_next_key)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", Muses.ESPACE_3)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(row)

	# Beaucoup d'objets : la grille défile, la fenêtre ne grandit pas.
	var scroll := _make_scroll()
	scroll.custom_minimum_size.x = inventory_columns * inventory_slot_size + (inventory_columns - 1) * Muses.ESPACE_1 \
			+ Motion.ROOM * 2 + Motion.SCROLLBAR_GAP + 8
	row.add_child(scroll)

	_inv_grid = GridContainer.new()
	_inv_grid.columns = inventory_columns
	_inv_grid.add_theme_constant_override(&"h_separation", Muses.ESPACE_1)
	_inv_grid.add_theme_constant_override(&"v_separation", Muses.ESPACE_1)
	# Icônes en pixel art : pas de flou à l'agrandissement.
	_inv_grid.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scroll.add_child(Motion.with_room(_inv_grid))

	# La fiche de l'objet sélectionné, comme une infobulle : catégorie, nom,
	# description.
	var detail := VBoxContainer.new()
	_inv_detail = detail
	detail.custom_minimum_size = Vector2(264, 0)
	detail.add_theme_constant_override(&"separation", 4)
	row.add_child(detail)

	_inv_icon = TextureRect.new()
	_inv_icon.custom_minimum_size = Vector2(96, 96)
	_inv_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_inv_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_inv_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail.add_child(_inv_icon)

	_inv_category = _label("", &"Categorie")
	detail.add_child(_inv_category)
	_inv_name = _label("", &"TitrePanneau")
	detail.add_child(_inv_name)
	_inv_count = _label("", &"HudEtiquette")
	detail.add_child(_inv_count)
	_inv_desc = _wrapped_label(&"Legende", 8)
	_inv_desc.custom_minimum_size = Vector2(264, 0)
	detail.add_child(_inv_desc)
	return page


func _build_equipment_page() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override(&"separation", Muses.ESPACE_3)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(320, 0)
	left.add_theme_constant_override(&"separation", Muses.ESPACE_1)
	page.add_child(left)
	left.add_child(_label("Revolver", &"SousTitre"))
	for slot in WeaponPartData.Slot.values():
		var button := _button("")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.focus_entered.connect(_show_slot.bind(slot))
		button.mouse_entered.connect(button.grab_focus)
		button.pressed.connect(_focus_parts)
		left.add_child(button)
		_eq_slot_buttons[slot] = button
	_eq_totals = _wrapped_label(&"Legende", 5)
	left.add_child(_eq_totals)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", Muses.ESPACE_1)
	page.add_child(right)
	_eq_parts_title = _label("", &"SousTitre")
	right.add_child(_eq_parts_title)
	var scroll := _make_scroll()
	right.add_child(scroll)
	_eq_parts = VBoxContainer.new()
	_eq_parts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_eq_parts.add_theme_constant_override(&"separation", 6)
	scroll.add_child(Motion.with_room(_eq_parts))

	_eq_name = _label("", &"TitrePanneau")
	right.add_child(_eq_name)
	_eq_desc = _wrapped_label(&"Legende", 3)
	right.add_child(_eq_desc)
	# Les bonus sont des valeurs importantes : en sève.
	_eq_stats = _label("", &"Categorie")
	_eq_stats.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	right.add_child(_eq_stats)
	_eq_action = _label("", &"HudEtiquette")
	right.add_child(_eq_action)
	return page


func _build_skills_page() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override(&"separation", Muses.ESPACE_3)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(320, 0)
	left.add_theme_constant_override(&"separation", Muses.ESPACE_1)
	page.add_child(left)
	_sk_count = _label("", &"HudEtiquette")
	left.add_child(_sk_count)
	var scroll := _make_scroll()
	left.add_child(scroll)
	_sk_list = VBoxContainer.new()
	_sk_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sk_list.add_theme_constant_override(&"separation", 6)
	scroll.add_child(Motion.with_room(_sk_list))

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", Muses.ESPACE_1)
	page.add_child(right)
	_sk_icon = TextureRect.new()
	_sk_icon.custom_minimum_size = Vector2(96, 96)
	_sk_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sk_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sk_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	right.add_child(_sk_icon)
	_sk_name = _label("", &"TitrePanneau")
	right.add_child(_sk_name)
	_sk_input = _label("", &"Categorie")
	right.add_child(_sk_input)
	_sk_desc = _wrapped_label(&"Legende", 8)
	right.add_child(_sk_desc)
	return page


func _build_slots() -> Control:
	var parts := _make_window("Sauvegarder")
	_slots_title = parts[2]
	var scroll := _make_scroll()
	(parts[1] as VBoxContainer).add_child(scroll)
	_slots_list = VBoxContainer.new()
	_slots_list.add_theme_constant_override(&"separation", Muses.ESPACE_1)
	_slots_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(Motion.with_room(_slots_list))
	return parts[0]


## Plein écran, volume, et le bouton qui ouvre les touches : les mêmes
## réglages que les paramètres de l'écran titre.
func _build_settings() -> Control:
	var parts := _make_window("Paramètres")
	var body: VBoxContainer = parts[1]
	body.alignment = BoxContainer.ALIGNMENT_CENTER

	var column := VBoxContainer.new()
	column.custom_minimum_size.x = Muses.PANNEAU_MIN
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override(&"separation", Muses.ESPACE_2)
	body.add_child(column)

	_fullscreen = CheckButton.new()
	_fullscreen.text = "Plein écran".to_upper()
	_fullscreen.custom_minimum_size.y = Muses.CIBLE_MIN
	# Settings est chargé après ce menu : on ne le nomme qu'au moment d'agir.
	_fullscreen.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on))
	column.add_child(_fullscreen)

	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override(&"separation", Muses.ESPACE_2)
	column.add_child(volume_row)
	volume_row.add_child(_label("Volume", &"HudEtiquette"))
	_volume = HSlider.new()
	_volume.max_value = 1.0
	_volume.step = 0.05
	_volume.custom_minimum_size.y = Muses.CIBLE_MIN
	_volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_volume.value_changed.connect(func(value: float) -> void: Settings.set_master_volume(value))
	volume_row.add_child(_volume)

	var controls := _button("Touches")
	controls.pressed.connect(_open_controls)
	controls.mouse_entered.connect(controls.grab_focus)
	column.add_child(controls)
	return parts[0]


## La fenêtre des touches : le panneau de l'écran titre, dans une fenêtre
## centrée comme les autres. Son bouton Retour revient aux paramètres.
func _open_controls() -> void:
	if _controls == null:
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_root.add_child(center)
		var panel: Control = ControlsPanelScript.new()
		panel.custom_minimum_size = window_size
		panel.connect(&"closed", back)
		center.add_child(panel)
		_controls = center
	_push(_controls)


func _build_confirm() -> Control:
	var parts := _make_window("Confirmation")
	var body: VBoxContainer = parts[1]
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override(&"separation", Muses.ESPACE_3)

	_confirm_label = _label("")
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_confirm_label)

	# Les actions sont centrées sous le message, la principale en dernier.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", Muses.ESPACE_2)
	body.add_child(row)

	_confirm_no = _button("Non")
	_confirm_no.custom_minimum_size.x = 140
	_confirm_no.pressed.connect(back)
	_confirm_no.mouse_entered.connect(_confirm_no.grab_focus)
	row.add_child(_confirm_no)

	_confirm_yes = _button("Oui", &"")
	_confirm_yes.custom_minimum_size.x = 140
	_confirm_yes.pressed.connect(_on_confirm_yes)
	_confirm_yes.mouse_entered.connect(_confirm_yes.grab_focus)
	row.add_child(_confirm_yes)
	return parts[0]


## Le bandeau des notifications, en haut au centre de l'écran.
func _build_notice() -> Control:
	var area := VBoxContainer.new()
	area.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	area.offset_top = Muses.ESPACE_4
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.modulate.a = 0.0

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"Notification"
	# Largeur maximale de la DA : 420 px.
	panel.custom_minimum_size.x = 420
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(panel)

	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 2)
	panel.add_child(lines)
	_notice_category = _label("", &"Categorie")
	lines.add_child(_notice_category)
	_notice_text = _label("", &"TitrePanneau")
	_notice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(_notice_text)
	return area
