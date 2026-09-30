extends Node

## Les animations de l'interface, chargé en autoload sous le nom "UiMotion".
##
## Tous les boutons du jeu s'animent tout seuls, sans rien brancher : ils
## grossissent un peu au survol et à la sélection (manette comprise), puis
## s'enfoncent à l'appui. Un bouton s'en passe avec la métadonnée « no_motion ».
##
## Les fonctions statiques animent fenêtres et listes. Pour s'en servir, on
## charge ce script par son chemin (pas besoin du nom de l'autoload) :
##     const Motion := preload("res://Scripts/UI/motion.gd")
##     Motion.pop_in(panel)
##     Motion.cascade(buttons)
##
## Toutes les animations tournent aussi jeu en pause (menus).

## Un bouton survolé grandit d'environ autant de pixels, quelle que soit sa
## taille : une case d'inventaire gagne plus en proportion qu'une longue ligne.
const GROW_PIXELS := 8.0
const GROW_MIN := 1.015
const GROW_MAX := 1.08
## Échelle d'un bouton enfoncé.
const PRESS_SCALE := 0.95
## Marge (px) laissée autour du contenu d'une liste qui défile : un bouton qui
## grossit n'y est pas rogné par le bord, ni collé à la barre de défilement.
const ROOM := 6
const SCROLLBAR_GAP := 8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	# Les boutons déjà là (autoloads chargés avant celui-ci).
	for node in get_tree().root.find_children("*", "BaseButton", true, false):
		_on_node_added(node)


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null or button.has_meta(&"no_motion") or button.has_meta(&"_motion_wired"):
		return
	button.set_meta(&"_motion_wired", true)

	button.pivot_offset = button.size * 0.5
	button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
	# Différé : l'état (survolé, sélectionné) est à jour une fois le signal passé.
	var settle_later := func() -> void: _settle.call_deferred(button)
	for signal_name in [&"mouse_entered", &"mouse_exited", &"focus_entered", &"focus_exited"]:
		button.connect(signal_name, settle_later)
	var press := func() -> void:
		button.set_meta(&"_motion_held", true)
		_settle(button)
	var release := func() -> void:
		button.set_meta(&"_motion_held", false)
		_settle(button)
	button.button_down.connect(press)
	button.button_up.connect(release)
	button.tree_entered.connect(_watch_container.bind(button))
	if button.is_inside_tree():
		_watch_container(button)


## Un conteneur remet l'échelle de ses enfants à 1 chaque fois qu'il les range :
## on rend au bouton la sienne juste après.
func _watch_container(button: BaseButton) -> void:
	var container := button.get_parent() as Container
	if container == null:
		return
	var restore := func() -> void:
		if is_instance_valid(button):
			button.scale = button.get_meta(&"_motion_scale", Vector2.ONE)
	container.sort_children.connect(restore)
	var forget := func() -> void:
		if is_instance_valid(container) and container.sort_children.is_connected(restore):
			container.sort_children.disconnect(restore)
	button.tree_exiting.connect(forget, CONNECT_ONE_SHOT)


## `target` n'est pas typé : l'appel est souvent différé, et le bouton a pu
## être libéré entre-temps (liste reconstruite, changement de scène).
static func _settle(target: Variant) -> void:
	if not is_instance_valid(target) or not (target as Node).is_inside_tree():
		return
	var button := target as BaseButton
	var goal := 1.0
	var held: bool = button.get_meta(&"_motion_held", false)
	if not button.disabled:
		if held:
			goal = PRESS_SCALE
		elif button.has_focus() or button.is_hovered():
			goal = clampf(1.0 + GROW_PIXELS / maxf(button.size.x, 1.0), GROW_MIN, GROW_MAX)
	var scale := Vector2.ONE * goal
	button.set_meta(&"_motion_scale", scale)
	if button.scale.is_equal_approx(scale):
		return
	var tween := _tween(button, &"_motion_button")
	tween.tween_property(button, ^"scale", scale, 0.07 if held else 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Fenêtres et listes ---------------------------------------------------

## Le contenu d'une liste qui défile, avec de la place autour : un
## ScrollContainer coupe ce qui déborde, dont les boutons qui grossissent au
## survol. À mettre dans le ScrollContainer à la place du contenu lui-même.
static func with_room(content: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override(&"margin_left", ROOM)
	margin.add_theme_constant_override(&"margin_top", ROOM)
	margin.add_theme_constant_override(&"margin_right", ROOM + SCROLLBAR_GAP)
	margin.add_theme_constant_override(&"margin_bottom", ROOM)
	margin.add_child(content)
	return margin


## Apparition d'une fenêtre : fondu et léger zoom vers sa taille réelle.
static func pop_in(control: Control, duration: float = 0.22, from_scale: float = 0.94) -> void:
	var size := control.size if control.size != Vector2.ZERO else control.get_combined_minimum_size()
	control.pivot_offset = size * 0.5
	control.modulate.a = 0.0
	control.scale = Vector2.ONE * from_scale
	var tween := _tween(control, &"_motion_pop").set_parallel()
	tween.tween_property(control, ^"modulate:a", 1.0, duration * 0.8)
	# Un bouton survolé revient à sa taille de survol, pas à 1.
	var rest: Vector2 = control.get_meta(&"_motion_scale", Vector2.ONE)
	tween.tween_property(control, ^"scale", rest, duration) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## Simple fondu d'entrée.
static func fade_in(control: Control, duration: float = 0.18) -> void:
	control.modulate.a = 0.0
	_tween(control, &"_motion_pop").tween_property(control, ^"modulate:a", 1.0, duration)


## Fondu de sortie, puis `then` (souvent : cacher le nœud).
static func fade_out(control: Control, duration: float = 0.15, then: Callable = Callable()) -> void:
	var tween := _tween(control, &"_motion_pop")
	tween.tween_property(control, ^"modulate:a", 0.0, duration)
	if then.is_valid():
		tween.tween_callback(then)


## Entrée en cascade : chaque élément glisse depuis `offset` en apparaissant,
## un peu après le précédent.
static func cascade(items: Array, offset: Vector2 = Vector2(0, 12), step: float = 0.04, duration: float = 0.24) -> void:
	var controls: Array[Control] = []
	for item: Variant in items:
		if item is Control:
			controls.append(item)
			(item as Control).modulate.a = 0.0
	if controls.is_empty() or not controls[0].is_inside_tree():
		return
	# Un conteneur place ses enfants à la frame suivante : on attend sa mise
	# en page pour connaître la place finale de chacun.
	await controls[0].get_tree().process_frame
	for i in controls.size():
		var control := controls[i]
		if not is_instance_valid(control) or not control.is_inside_tree():
			continue
		var target := control.position
		control.position = target + offset
		var tween := _tween(control, &"_motion_cascade").set_parallel()
		tween.tween_property(control, ^"modulate:a", 1.0, duration).set_delay(step * i)
		tween.tween_property(control, ^"position", target, duration).set_delay(step * i) \
				.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## Un tween qui tourne même jeu en pause, et remplace le précédent du même nom
## sur ce nœud (pas deux animations de survol qui se battent).
static func _tween(node: Node, key: StringName) -> Tween:
	if node.has_meta(key):
		var previous: Variant = node.get_meta(key)
		if previous is Tween and (previous as Tween).is_valid():
			(previous as Tween).kill()
	var tween := node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	node.set_meta(key, tween)
	return tween
