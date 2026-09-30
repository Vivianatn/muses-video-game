extends Area2D
class_name DialogueTrigger

## Zone à poser près d'un PNJ (ou n'importe où dans un niveau) pour déclencher
## une conversation. Deux modes :
##  - le joueur entre et appuie sur « interact » (par défaut) ;
##  - ou la conversation part toute seule à l'entrée (auto_start).
##
## La source du texte se règle dans l'inspecteur : un fichier .txt, une
## ressource Dialogue, ou du texte écrit directement sur le déclencheur.

## Émis quand la conversation lancée par ce déclencheur se termine.
signal dialogue_finished

## Comment enchaîner les conversations de la liste Dialogue Files.
enum RepeatMode {
	## Dans l'ordre, et la dernière se répète ensuite indéfiniment.
	## C'est le cas courant : rencontre, puis bavardage habituel.
	SEQUENCE,
	## Une au hasard à chaque fois.
	RANDOM,
	## Dans l'ordre, puis on repart de la première.
	LOOP,
}

@export_group("Contenu")
## Fichier texte du dialogue, ex. "res://Dialogues/vory_intro.txt".
## Pour un PNJ qui a plusieurs conversations, remplis Dialogue Files.
@export_file("*.txt") var dialogue_file: String = ""
## Ressource Dialogue montée à la main. Prioritaire sur le fichier.
@export var dialogue: Dialogue = null
## Dialogue écrit directement ici, au même format que les fichiers .txt.
## Pratique pour une réplique unique. Utilisé si les deux champs au-dessus
## sont vides.
@export_multiline var inline_text: String = ""

@export_group("Plusieurs conversations")
## Les conversations successives de ce PNJ, dans l'ordre : la première fois
## qu'on lui parle, la deuxième, etc. Chaque fichier est indépendant des
## autres, donc la première rencontre peut n'avoir aucun rapport avec la
## suite. Prioritaire sur Dialogue File.
@export_file("*.txt") var dialogue_files: Array[String] = []
## Ce qui se passe une fois la liste épuisée.
@export var repeat_mode: RepeatMode = RepeatMode.SEQUENCE
## Passer tout seul à la conversation suivante chaque fois qu'on a parlé au
## PNJ. Décoche pour que ce soit le dialogue qui décide, avec une ligne
## « >> ... » : tant qu'il ne l'a pas dit, le PNJ répète la même conversation.
## Qu'elle soit cochée ou non, une ligne « >> ... » a toujours le dernier mot.
@export var auto_advance: bool = true

@export_group("Déclenchement")
## Partir dès que le joueur entre, sans qu'il ait à appuyer sur une touche.
@export var auto_start: bool = false
## Action qui lance la conversation quand le joueur est dans la zone.
@export var interact_action: StringName = &"interact"
## Ne jouer la conversation qu'une seule fois.
@export var once: bool = false
## Délai (s) minimum avant de pouvoir relancer la conversation.
@export var cooldown: float = 0.5

@export_group("Interlocuteur")
## Le PNJ qui parle. Vide = le parent du déclencheur, ce qui couvre le cas
## courant où le déclencheur est posé en enfant du personnage.
@export var speaker_path: NodePath
## L'immobiliser pendant la conversation, via sa méthode set_frozen(bool).
@export var freeze_speaker: bool = true
## Le tourner vers le joueur au début, via sa méthode face_toward(Vector2).
@export var speaker_faces_player: bool = true

@export_group("Invite")
## Petit texte flottant affiché quand le joueur peut parler, au clavier.
## Vide = la touche de interact_action, qui suit les touches choisies par le
## joueur dans les paramètres.
@export var prompt_text: String = ""
## Le même texte quand une manette est branchée. Elle a la priorité sur le
## clavier : c'est celui-ci qui s'affiche dès qu'une manette est détectée.
## Vide = le bouton de interact_action.
@export var prompt_text_gamepad: String = ""
## Taille du texte de l'invite, en pixels d'écran (le zoom de la caméra ne la
## change pas). L'apparence vient du style « Touche » du thème.
@export_range(8, 72, 1) var prompt_size: int = 16
## Cacher complètement l'invite (utile en auto_start).
@export var show_prompt: bool = true
## Poser l'invite au-dessus de la tête de l'interlocuteur, centrée sur lui.
## La tête est trouvée toute seule dans son dessin (les pixels visibles de son
## sprite), quel que soit le personnage ; à défaut de sprite, d'après sa forme
## de collision. Décoche pour la laisser à prompt_height.
@export var prompt_follows_speaker: bool = true
## Écart (px d'écran) entre le haut du dessin du PNJ et le bas de la touche.
@export var prompt_margin: float = 18.0
## Hauteur (px) de l'invite au-dessus du déclencheur, quand on ne suit pas la
## tête du PNJ (ou qu'il n'a pas de forme de collision exploitable).
@export var prompt_height: float = -48.0

## Chargé par son chemin plutôt que par son nom de classe : le script compile
## même si l'éditeur n'a pas encore enregistré la classe SpriteBounds.
const SpriteBoundsScript := preload("res://Scripts/Character/sprite_bounds.gd")

@onready var prompt: Label = $Prompt

## Le sprite du PNJ, gardé d'une image à l'autre (le chercher coûte).
var _sprite: Node2D = null

## Amplitude (px d'écran) et vitesse du flottement de la touche au repos.
const PROMPT_BOB := 1.5
const PROMPT_BOB_SPEED := 2.6
## La touche arrive de PROMPT_SLIDE px plus bas et à PROMPT_START_SCALE de sa
## taille ; elle repart de la même façon.
const PROMPT_SLIDE := 8.0
const PROMPT_START_SCALE := 0.85
## Durées (s) de l'apparition et de la disparition (plus vive).
const PROMPT_IN_TIME := 0.2
const PROMPT_OUT_TIME := 0.14
## De 0 (cachée) à 1 (en place) : l'avancement de l'apparition.
var _prompt_pop: float = 1.0
var _prompt_tween: Tween
## Vrai quand la touche doit être affichée ; elle reste visible un instant
## après être passée à faux, le temps de son animation de disparition.
var _prompt_shown: bool = false

var _player: Node2D = null
var _played: bool = false
## Rang de la prochaine conversation à jouer dans dialogue_files.
var _next: int = 0
## Rang de la conversation en cours, pour savoir laquelle est « la suivante ».
var _playing: int = 0
var _cooldown_timer: float = 0.0
var _running: bool = false
## L'autoload InputDevice, cherché par son chemin plutôt que par son nom : le
## script compile même si l'éditeur ne connaît pas encore l'autoload.
var _input_device: Node = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Dialogues.finished.connect(_on_dialogue_finished)
	# Reprend l'avancement des conversations de la partie chargée.
	SaveGame.register(self)
	_input_device = get_node_or_null(^"/root/InputDevice")
	if _input_device != null:
		_input_device.connect(&"changed", _on_input_device_changed)
	else:
		push_warning("DialogueTrigger : autoload InputDevice absent, l'invite reste celle du clavier.")
	# Le joueur peut changer la touche dans les paramètres : l'invite suit.
	var settings := get_node_or_null(^"/root/Settings")
	if settings != null:
		settings.connect(&"controls_changed", _refresh_prompt_text)

	prompt.add_theme_font_size_override(&"font_size", prompt_size)
	# La touche est replacée et animée à chaque image d'affichage : pas
	# d'interpolation physique pour elle.
	prompt.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_refresh_prompt_text()
	prompt.visible = false
	# Le dessin du PNJ est analysé dès le chargement du niveau, pas au moment
	# où l'invite apparaît (ce qui ferait accrocher la course du joueur).
	_speaker_head.call_deferred()


func _process(delta: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	var wanted := show_prompt and _can_start() and not _running
	if wanted and not _prompt_shown:
		_pop_prompt()
	elif not wanted and _prompt_shown:
		_hide_prompt()
	if prompt.visible:
		# Le PNJ se déplace : l'invite le suit tant qu'elle est affichée.
		_update_prompt_position()


func _unhandled_input(event: InputEvent) -> void:
	if auto_start or not _can_start():
		return
	if not InputMap.has_action(interact_action) or not event.is_action_pressed(interact_action):
		return
	get_viewport().set_input_as_handled()
	start()


## Lance la conversation, quelles que soient les conditions d'entrée. Appelable
## depuis un autre script : $DialogueTrigger.start().
func start() -> void:
	var content := _build_dialogue()
	if content == null or content.is_empty():
		push_warning("DialogueTrigger (%s) : aucun dialogue à jouer." % name)
		return

	_played = true
	_running = true
	_hide_prompt()
	_hold_speaker(true)
	Dialogues.start(content, self)


func has_played() -> bool:
	return _played


## Remet le déclencheur à zéro : le dialogue `once` peut rejouer, et la liste
## Dialogue Files repart de sa première entrée.
func reset() -> void:
	_played = false
	_cooldown_timer = 0.0
	_next = 0


## Rang de la conversation qui sera jouée au prochain contact.
func get_next_dialogue() -> int:
	return _next


## Choisit la conversation jouée au prochain contact. C'est le point d'entrée
## d'une sauvegarde ou d'un script de quête : set_next_dialogue(2) fait passer
## Vory directement à sa troisième conversation.
func set_next_dialogue(index: int) -> void:
	_next = clampi(index, 0, maxi(dialogue_files.size() - 1, 0))


## Appelée par l'autoload Dialogues quand la conversation contient une ligne
## « >> ... ». `target` vaut :
##  - « suivante » : celle qui suit la conversation en cours dans la liste ;
##  - un rang compté à partir de 1 : « 2 » = la deuxième de Dialogue Files ;
##  - un nom de fichier, avec ou sans « .txt » ni chemin : « vory_habituel ».
## Prend effet au prochain contact : la conversation en cours va à son terme.
func request_next_dialogue(target: String) -> void:
	if dialogue_files.is_empty():
		push_warning("DialogueTrigger (%s) : « >> %s » ignoré, Dialogue Files est vide." % [name, target])
		return

	var wanted := target.strip_edges()
	if wanted.to_lower() in ["suivante", "suivant"]:
		_next = _following(_playing)
		return
	if wanted.is_valid_int():
		set_next_dialogue(wanted.to_int() - 1)
		return

	for i in dialogue_files.size():
		var path := dialogue_files[i]
		if path == wanted or path.get_file() == wanted or path.get_file().get_basename() == wanted:
			_next = i
			return

	push_warning("DialogueTrigger (%s) : « >> %s » ne correspond à aucune conversation de Dialogue Files." % [name, target])


# --- Sauvegarde -----------------------------------------------------------

func save_state() -> Dictionary:
	return {"next": _next, "played": _played}


func load_state(data: Dictionary) -> void:
	_next = int(data.get("next", _next))
	_played = bool(data.get("played", _played))


# --- Détail ---------------------------------------------------------------

func _can_start() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if once and _played:
		return false
	if _cooldown_timer > 0.0:
		return false
	return not Dialogues.is_active()


func _build_dialogue() -> Dialogue:
	if not dialogue_files.is_empty():
		return Dialogue.load_text(_take_next_file())
	if dialogue != null and not dialogue.is_empty():
		return dialogue
	if not dialogue_file.is_empty():
		return Dialogue.load_text(dialogue_file)
	if not inline_text.strip_edges().is_empty():
		return Dialogue.from_text(inline_text)
	return null


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player = body
	if auto_start and _can_start():
		start()


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		_hide_prompt()


func _on_dialogue_finished(_dialogue: Dialogue) -> void:
	if not _running:
		return
	_running = false
	_hold_speaker(false)
	# Le délai empêche de relancer aussitôt la même conversation avec la touche
	# qui vient de la fermer.
	_cooldown_timer = cooldown
	dialogue_finished.emit()


## Le PNJ rattaché à ce déclencheur, ou null.
func get_speaker() -> Node:
	if not speaker_path.is_empty():
		return get_node_or_null(speaker_path)
	return get_parent()


## Immobilise l'interlocuteur et le tourne vers le joueur pendant la
## conversation, puis lui rend sa liberté à la fin.
##
## Les deux méthodes sont appelées seulement si le PNJ les possède : n'importe
## quel personnage devient « parlable » en implémentant
##   func set_frozen(frozen: bool)
##   func face_toward(point: Vector2)
## Voir Scripts/Character/vory.gd pour l'exemple.
func _hold_speaker(held: bool) -> void:
	var speaker := get_speaker()
	if speaker == null:
		return

	if held and speaker_faces_player and speaker.has_method(&"face_toward"):
		var target := _player
		if target == null or not is_instance_valid(target):
			target = get_tree().get_first_node_in_group(&"player") as Node2D
		if target != null:
			speaker.face_toward(target.global_position)

	if freeze_speaker and speaker.has_method(&"set_frozen"):
		speaker.set_frozen(held)


## Renvoie le fichier à jouer maintenant et prépare le suivant.
func _take_next_file() -> String:
	if repeat_mode == RepeatMode.RANDOM:
		_playing = randi() % dialogue_files.size()
		return dialogue_files[_playing]

	_playing = clampi(_next, 0, dialogue_files.size() - 1)
	# Préparé dès maintenant : une ligne « >> ... » pendant la conversation
	# pourra encore le remplacer.
	if auto_advance:
		_next = _following(_playing)
	return dialogue_files[_playing]


## Rang de la conversation qui suit `index`, selon repeat_mode.
func _following(index: int) -> int:
	var last := dialogue_files.size() - 1
	if repeat_mode == RepeatMode.LOOP and index >= last:
		return 0
	# En SEQUENCE, on s'arrête sur la dernière : c'est elle qui se répète.
	return mini(index + 1, last)


# --- Invite ---------------------------------------------------------------

## Affiche la touche du clavier ou le bouton de la manette, selon ce qui est
## branché.
func _refresh_prompt_text() -> void:
	var gamepad: bool = _input_device != null and _input_device.call(&"is_gamepad")
	var text := prompt_text_gamepad if gamepad else prompt_text
	if text.is_empty() and _input_device != null:
		text = String(_input_device.call(&"action_label", interact_action))
	prompt.text = text
	# La taille du Label suit son texte : _update_prompt_position() s'en sert
	# pour centrer l'invite sur la tête du PNJ.
	prompt.reset_size()
	_update_prompt_position()


func _on_input_device_changed(_gamepad: bool) -> void:
	_refresh_prompt_text()


## La touche monte se poser au-dessus du personnage en apparaissant, sans
## rebond : un fondu et une décélération douce.
func _pop_prompt() -> void:
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt_shown = true
	prompt.visible = true
	# Repart d'où elle en était si elle était en train de disparaître.
	if _prompt_pop >= 1.0:
		_prompt_pop = 0.0
	_prompt_tween = create_tween()
	_prompt_tween.tween_property(self, ^"_prompt_pop", 1.0, PROMPT_IN_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Le chemin inverse, plus vif : la touche redescend un peu, rétrécit et
## s'efface, puis est cachée.
func _hide_prompt() -> void:
	if not _prompt_shown:
		return
	_prompt_shown = false
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt_tween = create_tween()
	_prompt_tween.tween_property(self, ^"_prompt_pop", 0.0, PROMPT_OUT_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_prompt_tween.tween_callback(func() -> void:
		if not _prompt_shown:
			prompt.visible = false
			_prompt_pop = 1.0)


## Pose le « E » juste au-dessus de la tête de l'interlocuteur, centré sur lui.
func _update_prompt_position() -> void:
	# L'invite ne suit ni l'échelle du PNJ, ni celle du déclencheur, ni le zoom
	# de la caméra : comme le reste du HUD, la touche garde la même taille à
	# l'écran quel que soit le gabarit du personnage.
	var factor := get_global_transform_with_canvas().get_scale()
	var base_scale := Vector2(
		1.0 / factor.x if factor.x != 0.0 else 1.0,
		1.0 / factor.y if factor.y != 0.0 else 1.0
	)

	var size := prompt.size
	if size == Vector2.ZERO:
		# Avant la première mise en page, `size` vaut encore zéro.
		size = prompt.get_combined_minimum_size()
	# Combien d'unités du monde vaut un pixel d'écran, puis la taille de la
	# touche dans le repère du déclencheur et dans celui du monde.
	var world_per_pixel := global_scale.abs() / factor.abs()
	var local_size := size * base_scale
	var world_size := size * world_per_pixel

	# Apparition et disparition : fondu, taille de PROMPT_START_SCALE à 1
	# (depuis le centre), et glissement de PROMPT_SLIDE px depuis le bas.
	# Au repos, un léger flottement de ±PROMPT_BOB px.
	var pop := clampf(_prompt_pop, 0.0, 1.0)
	prompt.pivot_offset = size * 0.5
	prompt.scale = base_scale * lerpf(PROMPT_START_SCALE, 1.0, pop)
	prompt.modulate.a = pop
	var bob := sin(Time.get_ticks_msec() * 0.001 * PROMPT_BOB_SPEED) * PROMPT_BOB
	# Vers le bas = positif.
	bob += (1.0 - pop) * PROMPT_SLIDE

	var head := _speaker_head()
	if head == Vector2.INF:
		# Pas de tête repérable : on retombe sur la hauteur réglée à la main.
		prompt.position = Vector2(-local_size.x * 0.5, prompt_height + bob * base_scale.y)
		return

	prompt.global_position = head - Vector2(world_size.x * 0.5, world_size.y + (prompt_margin - bob) * world_per_pixel.y)


## Point du monde au sommet de l'interlocuteur, centré sur lui : d'après son
## dessin, sinon d'après ses formes de collision. Renvoie Vector2.INF s'il n'a
## ni l'un ni l'autre — le cas d'un déclencheur posé à la racine d'un niveau,
## dont le parent n'est pas un personnage.
func _speaker_head() -> Vector2:
	if not prompt_follows_speaker:
		return Vector2.INF

	var speaker := get_speaker()
	if speaker is not Node2D:
		return Vector2.INF

	if not is_instance_valid(_sprite) or not _sprite.is_visible_in_tree() or not _sprite.is_ancestor_of(speaker) and not speaker.is_ancestor_of(_sprite):
		_sprite = _speaker_sprite(speaker)
	var sprite := _sprite
	if sprite != null:
		var top := SpriteBoundsScript.head_of(sprite)
		if top != Vector2.INF:
			return top
	return _collision_head(speaker as Node2D)


## Le sprite visible du personnage (le premier trouvé, animé de préférence).
static func _speaker_sprite(speaker: Node) -> Node2D:
	for type in ["AnimatedSprite2D", "Sprite2D"]:
		for node in speaker.find_children("*", type, true, false):
			if (node as CanvasItem).is_visible_in_tree():
				return node as Node2D
	return null


## Sommet des formes de collision du personnage.
func _collision_head(speaker: Node2D) -> Vector2:
	var head := Vector2.INF
	for child in speaker.get_children():
		if child is not CollisionShape2D:
			continue
		var shape_node := child as CollisionShape2D
		var half := _shape_half_height(shape_node.shape)
		if half <= 0.0:
			continue
		# to_global() applique au passage la position et l'échelle du nœud, donc
		# le sommet est juste même si la forme est décalée sur le personnage.
		var top := shape_node.to_global(Vector2(0.0, -half))
		if head == Vector2.INF or top.y < head.y:
			head = top

	return head


static func _shape_half_height(shape: Shape2D) -> float:
	if shape is CapsuleShape2D:
		return (shape as CapsuleShape2D).height / 2.0
	if shape is RectangleShape2D:
		return (shape as RectangleShape2D).size.y / 2.0
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius
	return 0.0
