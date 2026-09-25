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
## Petit texte flottant affiché quand le joueur peut parler.
@export var prompt_text: String = "E"
## Taille du texte de l'invite.
@export_range(8, 72, 1) var prompt_size: int = 30
## Cacher complètement l'invite (utile en auto_start).
@export var show_prompt: bool = true
## Poser l'invite juste au-dessus de la tête de l'interlocuteur, déduite de sa
## forme de collision. Décoche pour la laisser à prompt_height.
@export var prompt_follows_speaker: bool = true
## Écart (px) entre le sommet du PNJ et le bas de l'invite. Une valeur
## négative fait descendre le « E » sur la tête plutôt que de le laisser
## flotter au-dessus : c'est souvent ce qu'on veut, la forme de collision
## montant en général un peu plus haut que le crâne du sprite.
@export var prompt_margin: float = -16.0
## Hauteur (px) de l'invite au-dessus du déclencheur, quand on ne suit pas la
## tête du PNJ (ou qu'il n'a pas de forme de collision exploitable).
@export var prompt_height: float = -48.0

@onready var prompt: Label = $Prompt

var _player: Node2D = null
var _played: bool = false
## Rang de la prochaine conversation à jouer dans dialogue_files.
var _next: int = 0
var _cooldown_timer: float = 0.0
var _running: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Dialogues.finished.connect(_on_dialogue_finished)

	prompt.text = prompt_text
	prompt.add_theme_font_size_override(&"font_size", prompt_size)
	# La taille du Label suit son texte : _update_prompt_position() s'en sert
	# pour centrer l'invite sur la tête du PNJ.
	prompt.reset_size()
	prompt.visible = false
	_update_prompt_position()


func _process(delta: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	prompt.visible = show_prompt and _can_start() and not _running
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
	prompt.visible = false
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
		prompt.visible = false


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
		return dialogue_files[randi() % dialogue_files.size()]

	var last := dialogue_files.size() - 1
	var path := dialogue_files[clampi(_next, 0, last)]

	_next += 1
	if repeat_mode == RepeatMode.LOOP and _next > last:
		_next = 0
	else:
		# En SEQUENCE, on s'arrête sur la dernière : c'est elle qui se répète.
		_next = mini(_next, last)

	return path


# --- Invite ---------------------------------------------------------------

## Pose le « E » juste au-dessus de la tête de l'interlocuteur, centré sur lui.
func _update_prompt_position() -> void:
	# L'invite ne suit ni l'échelle du PNJ ni celle du déclencheur : le « E »
	# garde la même taille à l'écran quel que soit le gabarit du personnage.
	var factor := global_scale
	prompt.scale = Vector2(
		1.0 / factor.x if factor.x != 0.0 else 1.0,
		1.0 / factor.y if factor.y != 0.0 else 1.0
	)

	var size := prompt.size
	if size == Vector2.ZERO:
		# Avant la première mise en page, `size` vaut encore zéro.
		size = prompt.get_combined_minimum_size()

	var head := _speaker_head()
	if head == Vector2.INF:
		# Pas de tête repérable : on retombe sur la hauteur réglée à la main.
		prompt.position = Vector2(-size.x * 0.5, prompt_height)
		return

	prompt.global_position = head - Vector2(size.x * 0.5, size.y + prompt_margin)


## Point du monde situé au sommet de l'interlocuteur, déduit de ses formes de
## collision. Renvoie Vector2.INF s'il n'en a aucune d'exploitable — le cas
## d'un déclencheur posé à la racine d'un niveau, dont le parent n'est pas un
## personnage.
func _speaker_head() -> Vector2:
	if not prompt_follows_speaker:
		return Vector2.INF

	var speaker := get_speaker()
	if speaker is not Node2D:
		return Vector2.INF

	var head := Vector2.INF
	for child in (speaker as Node2D).get_children():
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
