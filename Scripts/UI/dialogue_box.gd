extends CanvasLayer
class_name DialogueBox

## L'affichage d'un dialogue : portrait, nom, texte qui se tape tout seul, et
## boutons de choix. La boîte court sur toute la largeur de l'écran et reste
## basse ; les choix flottent à gauche, au-dessus d'elle, sur des faces
## translucides, pour laisser voir le jeu. Elle ne décide de rien — c'est l'autoload Dialogues qui
## lui dit quoi montrer et qui écoute ses signaux.
##
## Une copie est créée automatiquement par l'autoload. Pour une présentation
## différente dans un niveau (boîte en haut, autre thème...), instancie
## Scenes/UI/dialogue_box.tscn dans ce niveau et ajoute sa racine au groupe
## "dialogue_box" : l'autoload l'utilisera à la place.

## Le joueur a validé la réplique en cours (pas de choix affiché).
signal advanced
## Le joueur a retenu l'option n° index.
signal choice_selected(index: int)

@export_group("Frappe")
## Vitesse d'affichage du texte, en caractères par seconde. 0 = tout d'un coup.
@export var type_speed: float = 45.0
## Une première validation termine la frappe, la seconde passe à la suite.
## Décoche pour que la validation passe toujours directement à la suite.
@export var allow_skip_typing: bool = true

@export_group("Entrées")
## Actions qui font avancer le dialogue. Celles qui n'existent pas dans la
## carte d'entrées du projet sont simplement ignorées.
@export var advance_actions: Array[StringName] = [&"interact", &"ui_accept", &"jump"]
## Actions qui remontent d'une option quand des choix sont affichés. Les
## actions du jeu y sont pour que le stick de la manette marche aussi.
@export var choice_up_actions: Array[StringName] = [&"ui_up", &"look_up"]
## Actions qui descendent d'une option quand des choix sont affichés.
@export var choice_down_actions: Array[StringName] = [&"ui_down", &"look_down"]

@export_group("Distribution")
## Portrait par personnage : la clé est le nom écrit dans le dialogue.
## Une réplique peut toujours imposer le sien via DialogueLine.portrait.
@export var portraits: Dictionary[String, Texture2D] = {}
## Couleur du nom par personnage, pour les distinguer d'un coup d'œil. Le nom
## est écrit sur l'en-tête bordeaux : la DA y permet parchemin, argile, sève.
@export var speaker_colors: Dictionary[String, Color] = {}
## Couleur utilisée pour un personnage absent de speaker_colors.
@export var default_speaker_color: Color = Muses.PARCHEMIN

@export_group("Tailles de texte")
## Taille du texte des répliques (police Barlow, style « Dialogue »).
@export_range(8, 72, 1) var text_size: int = 19
## Taille du nom du personnage, dans l'en-tête (style « titre de panneau »).
@export_range(8, 72, 1) var speaker_size: int = 18
## Taille du texte des options de choix.
@export_range(8, 72, 1) var choice_size: int = 19

@export_group("Apparence")
## La boîte se règle sur la hauteur de son contenu au lieu de garder la hauteur
## fixe de la scène : elle reste basse pour une simple réplique et ne s'agrandit
## que pour un texte long ou une liste de choix.
@export var auto_height: bool = true
## Hauteur (px) en deçà de laquelle la boîte ne descend pas, quand auto_height
## est actif.
@export var min_height: float = 76.0
## Écart (px) entre les choix et le haut de la boîte.
@export var choices_gap: float = 16.0
## Durée (s) du fondu à l'ouverture et à la fermeture. 0 = apparition sèche.
@export var fade_time: float = 0.12
## Taille du portrait. Mets (0, 0) pour garder la taille de l'image.
@export var portrait_size: Vector2 = Vector2(56, 56)
## Le petit signe clignotant qui indique qu'on peut continuer.
@export var continue_hint: String = "▼"

const Motion := preload("res://Scripts/UI/motion.gd")

@onready var root: Control = $Root
@onready var panel: PanelContainer = %Panel
@onready var header: Control = %Header
@onready var header_circuit: Control = %HeaderCircuit
@onready var portrait_rect: TextureRect = %Portrait
@onready var speaker_label: Label = %Speaker
@onready var body: RichTextLabel = %Body
@onready var choices_box: VBoxContainer = %Choices
@onready var indicator: Label = %Indicator

var _line: DialogueLine = null
## Vrai tant que le texte est en train de se taper.
var _typing: bool = false
var _typed: float = 0.0
var _speed: float = 0.0
var _auto_timer: float = 0.0
var _tween: Tween = null


func _ready() -> void:
	# La boîte reste vivante et lisible même quand le jeu est en pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# L'interface bouge au rythme de l'affichage (tweens, _process) : on la
	# sort de l'interpolation physique, qui ne vaut que pour le monde.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	indicator.text = continue_hint
	_apply_text_sizes()
	_hide_now()
	_prewarm()


## Dessine la boîte une fois au lancement, presque transparente (1 %), avec
## un texte en gras et en italique et une option : ses polices et ses styles
## sont prêts avant le premier dialogue, qui ne fige plus le jeu.
func _prewarm() -> void:
	await get_tree().process_frame
	if _line != null:
		return
	speaker_label.text = "Muses"
	body.text = "Muses [b]Muses[/b] [i]Muses[/i] ÀÉÈÊÇàéèêç"
	var sample := Button.new()
	sample.theme_type_variation = &"Choix"
	sample.text = body.text
	choices_box.add_child(sample)
	choices_box.visible = true
	panel.modulate.a = 0.01
	panel.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	choices_box.remove_child(sample)
	sample.queue_free()
	choices_box.visible = false
	body.text = ""
	# Un dialogue a pu commencer entre-temps : on ne cache que si rien ne joue.
	if _line == null:
		_hide_now()


func _process(delta: float) -> void:
	if not panel.visible:
		return
	# Recalculé en continu : le RichTextLabel ne connaît sa hauteur définitive
	# qu'après la mise en page, soit une frame après avoir reçu son texte.
	_fit_height()
	_navigate_choices()

	if _typing:
		_typed += _speed * delta
		body.visible_characters = int(_typed)
		if body.visible_characters >= body.get_total_character_count():
			_finish_typing()
		return

	if indicator.visible:
		# Clignotement du repère « continuer ».
		indicator.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0))

	# Enchaînement automatique, pour les répliques qui ne demandent rien.
	if _auto_timer > 0.0:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			advanced.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible_now() or _line == null:
		return
	if not _is_advance_pressed(event):
		return

	get_viewport().set_input_as_handled()

	# Choix affichés : on valide l'option sélectionnée. Le bouton gère lui-même
	# ui_accept (Entrée, Espace) ; ici arrivent les autres, dont A à la manette.
	if not choices_box.get_children().is_empty():
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused == null or focused.get_parent() != choices_box:
			# Sélection perdue (clic à côté...) : on la remet sur la première
			# option, sans valider un choix que le joueur ne voyait pas.
			(choices_box.get_child(0) as Button).grab_focus()
			return
		focused.pressed.emit()
		return

	if _typing and allow_skip_typing:
		_finish_typing()
		return
	advanced.emit()


# --- Appelé par l'autoload ------------------------------------------------

func open() -> void:
	if not visible_now():
		# La boîte monte du bas de l'écran en apparaissant.
		root.position.y = 24.0
		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(root, ^"position:y", 0.0, 0.3) \
				.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	panel.visible = true
	_fade_to(1.0)


func close() -> void:
	_line = null
	_typing = false
	_auto_timer = 0.0
	_clear_choices()
	_fade_to(0.0)


## Affiche une réplique : portrait, nom, texte, puis choix éventuels.
func show_line(line: DialogueLine) -> void:
	_line = line
	_auto_timer = 0.0
	_clear_choices()

	_apply_speaker(line)

	body.text = line.text
	body.visible_characters = 0
	_typed = 0.0
	_speed = line.type_speed if line.type_speed > 0.0 else type_speed

	if _speed <= 0.0:
		_finish_typing()
	else:
		_typing = true
		indicator.visible = false


func visible_now() -> bool:
	return panel.visible and panel.modulate.a > 0.01


## Applique les tailles de police réglées dans l'inspecteur. Le RichTextLabel
## en demande une par style, sans quoi le gras et l'italique repasseraient à la
## taille par défaut au milieu d'une phrase.
func _apply_text_sizes() -> void:
	for style in [&"normal_font_size", &"bold_font_size", &"italics_font_size",
			&"bold_italics_font_size", &"mono_font_size"]:
		body.add_theme_font_size_override(style, text_size)

	speaker_label.add_theme_font_size_override(&"font_size", speaker_size)
	indicator.add_theme_font_size_override(&"font_size", text_size)


# --- Détail ---------------------------------------------------------------

func _apply_speaker(line: DialogueLine) -> void:
	var has_speaker := not line.speaker.is_empty()
	# Sans nom (narration), le panneau n'a pas d'en-tête.
	header.visible = has_speaker
	header_circuit.visible = has_speaker
	speaker_label.text = line.speaker

	var color := default_speaker_color
	var cast_name := _cast_name(line)
	if speaker_colors.has(cast_name):
		color = speaker_colors[cast_name]
	# La réplique peut imposer sa couleur ; alpha à 0 = « laisse la distribution ».
	if line.speaker_color.a > 0.0:
		color = line.speaker_color
	speaker_label.add_theme_color_override(&"font_color", color)

	var texture := line.portrait
	if texture == null and portraits.has(cast_name):
		texture = portraits[cast_name]
	portrait_rect.texture = texture
	portrait_rect.visible = texture != null
	if texture != null and portrait_size != Vector2.ZERO:
		portrait_rect.custom_minimum_size = portrait_size


## Nom sous lequel chercher le personnage dans Portraits et Speaker Colors.
## Le nom affiché d'abord (« Vory »), sinon celui de la variable qui le porte
## (« vory » pour `{vory}`) : on garde ainsi le même portrait sous « Robot
## étrange » en déclarant l'entrée sous le nom de la variable.
func _cast_name(line: DialogueLine) -> String:
	if portraits.has(line.speaker) or speaker_colors.has(line.speaker):
		return line.speaker
	if not line.speaker_key.is_empty():
		return line.speaker_key
	return line.speaker


func _finish_typing() -> void:
	_typing = false
	body.visible_characters = -1

	if _line == null:
		return

	if not _line.choices.is_empty():
		_build_choices(_line.choices)
		indicator.visible = false
		return

	if _line.auto_advance > 0.0:
		_auto_timer = _line.auto_advance
		indicator.visible = false
		return

	indicator.visible = true


func _build_choices(choices: Array[DialogueChoice]) -> void:
	for i in choices.size():
		var button := Button.new()
		button.theme_type_variation = &"Choix"
		button.custom_minimum_size.y = Muses.CIBLE_MIN
		button.text = choices[i].text
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# La colonne a une largeur fixe : une option longue passe à la ligne.
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override(&"font_size", choice_size)
		button.pressed.connect(_on_choice_pressed.bind(i))
		choices_box.add_child(button)
		# La navigation entre options passe par _navigate_choices() : on coupe
		# celle de Godot, sinon les flèches déplaceraient la sélection deux fois.
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			button.set_focus_neighbor(side, ^".")
		button.focus_next = ^"."
		button.focus_previous = ^"."

	choices_box.visible = true
	# Les options arrivent de la gauche, l'une après l'autre.
	Motion.cascade(choices_box.get_children(), Vector2(-28, 0), 0.06, 0.28)
	# Le premier bouton prend le focus : le dialogue reste jouable au clavier
	# et à la manette, sans obliger à viser à la souris.
	if choices_box.get_child_count() > 0:
		(choices_box.get_child(0) as Button).grab_focus()


## Monte ou descend d'une option, au clavier comme au stick ou à la croix.
## Lu à chaque frame plutôt qu'en _unhandled_input : le stick envoie un flot
## d'événements tant qu'il est penché, alors qu'on ne veut bouger que d'un cran.
func _navigate_choices() -> void:
	var count := choices_box.get_child_count()
	if count == 0:
		return

	var step := 0
	if _any_just_pressed(choice_up_actions):
		step -= 1
	if _any_just_pressed(choice_down_actions):
		step += 1
	if step == 0:
		return

	var focused := get_viewport().gui_get_focus_owner()
	var current := focused.get_index() if focused != null and focused.get_parent() == choices_box else 0
	# On boucle : descendre depuis la dernière option ramène à la première.
	(choices_box.get_child(posmod(current + step, count)) as Button).grab_focus()


func _any_just_pressed(actions: Array[StringName]) -> bool:
	for action in actions:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			return true
	return false


func _on_choice_pressed(index: int) -> void:
	# On vide tout de suite : sans ça, une deuxième pression sur le bouton
	# encore affiché relancerait le même choix.
	_clear_choices()
	choice_selected.emit(index)


func _clear_choices() -> void:
	for child in choices_box.get_children():
		child.queue_free()
		# Le nœud ne disparaît qu'à la fin de la frame : on le sort du groupe
		# de focus tout de suite pour qu'il n'intercepte plus rien.
		choices_box.remove_child(child)
	choices_box.visible = false


func _is_advance_pressed(event: InputEvent) -> bool:
	for action in advance_actions:
		if InputMap.has_action(action) and event.is_action_pressed(action):
			return true
	return false


func _fade_to(target: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	if fade_time <= 0.0:
		panel.modulate.a = target
		panel.visible = target > 0.0
		return

	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(panel, "modulate:a", target, fade_time)
	if target <= 0.0:
		_tween.tween_callback(_hide_now)


func _hide_now() -> void:
	panel.visible = false
	panel.modulate.a = 0.0
	indicator.visible = false


## Règle la hauteur de la boîte sur celle de son contenu. Les ancres du Panel
## sont collées au bas de l'écran, donc c'est offset_top qui porte la hauteur.
## Les choix se posent juste au-dessus, et montent quand ils sont nombreux.
func _fit_height() -> void:
	if auto_height:
		var needed := maxf(panel.get_combined_minimum_size().y, min_height)
		panel.offset_top = panel.offset_bottom - needed
	choices_box.offset_bottom = panel.offset_top - choices_gap
	choices_box.offset_top = choices_box.offset_bottom - choices_box.get_combined_minimum_size().y
