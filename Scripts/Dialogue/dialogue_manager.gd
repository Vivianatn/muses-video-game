extends Node

## Chef d'orchestre des dialogues, chargé en autoload sous le nom "Dialogues".
## Il détient la boîte de dialogue, déroule les répliques, gère les sauts et
## les choix, et relaie au jeu les événements écrits dans la conversation.
##
## Utilisation courante, depuis n'importe où :
##     Dialogues.start_file("res://Dialogues/vory_intro.txt")
##     Dialogues.start_text("Vory: Salut !")
##     Dialogues.start(mon_dialogue_tres)
##
## Pour réagir à ce qui est dit :
##     Dialogues.event.connect(_on_dialogue_event)
##     Dialogues.finished.connect(_on_dialogue_finished)

## Émis quand une conversation démarre.
signal started(dialogue: Dialogue)
## Émis quand elle se termine (fin naturelle ou stop()).
signal finished(dialogue: Dialogue)
## Émis à chaque réplique affichée.
signal line_shown(line: DialogueLine)
## Émis quand le joueur retient une option.
signal choice_made(index: int, choice: DialogueChoice)
## Le point d'accroche du dialogue sur le reste du jeu : `@ nom argument`
## dans un fichier, ou le champ `event` d'une réplique / d'un choix.
signal event(name: StringName, arg: String)

## Scène de la boîte utilisée si aucune n'est déjà présente dans le niveau.
const BOX_SCENE := preload("res://Scenes/UI/dialogue_box.tscn")

## Groupe dans lequel chercher une boîte déjà posée dans le niveau, quand on
## veut une présentation particulière pour une scène donnée.
const BOX_GROUP := &"dialogue_box"

## Bloque les entrées des nœuds du groupe "player" pendant la conversation, en
## appelant leur méthode set_input_locked(). Voir Scripts/Character/player.gd.
@export var lock_player: bool = true

## Met tout l'arbre en pause pendant la conversation. Plus radical que
## lock_player : les ennemis se figent aussi. La boîte, elle, reste active.
@export var pause_tree: bool = false

var _box: DialogueBox = null
## Boîte par défaut, créée par l'autoload et réutilisée dans tout le jeu.
var _default_box: DialogueBox = null
var _dialogue: Dialogue = null
var _index: int = 0
var _active: bool = false
## Nœud qui a lancé la conversation (le PNJ, le déclencheur...). Transmis tel
## quel aux scripts qui écoutent, pour savoir qui parle.
var _context: Node = null


func _ready() -> void:
	# L'autoload continue de tourner même si le jeu est en pause.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# La boîte par défaut est créée une fois pour toutes : elle existe donc
	# déjà quand un dialogue démarre depuis un signal de collision, où l'on ne
	# peut pas ajouter de nœud à l'arbre sur-le-champ.
	_default_box = BOX_SCENE.instantiate() as DialogueBox
	add_child(_default_box)


# --- Démarrage ------------------------------------------------------------

## Lance une conversation déjà construite.
func start(dialogue: Dialogue, context: Node = null) -> void:
	if dialogue == null or dialogue.is_empty():
		push_warning("Dialogues : conversation vide, rien à afficher.")
		return
	if _active:
		stop()

	_dialogue = dialogue
	_context = context
	_index = 0
	_active = true

	_ensure_box()
	if _box == null:
		_active = false
		_dialogue = null
		_context = null
		return

	_set_world_frozen(true)
	_box.open()
	started.emit(_dialogue)
	_show_current()


## Lance une conversation écrite dans un fichier texte du projet.
func start_file(path: String, context: Node = null) -> void:
	start(Dialogue.load_text(path), context)


## Lance une conversation écrite directement dans du code.
func start_text(source: String, context: Node = null) -> void:
	start(Dialogue.from_text(source), context)


## Coupe court à la conversation en cours.
func stop() -> void:
	if not _active:
		return
	var ended := _dialogue
	_active = false
	_dialogue = null
	_index = 0
	if _box != null:
		_box.close()
	_set_world_frozen(false)
	finished.emit(ended)
	_context = null


func is_active() -> bool:
	return _active


## Le nœud qui a lancé la conversation en cours, ou null.
func get_context() -> Node:
	return _context


# --- Déroulé --------------------------------------------------------------

func _show_current() -> void:
	# On traverse les répliques muettes (sauts, événements seuls) sans jamais
	# rendre la main à l'affichage : une limite évite de boucler à l'infini si
	# deux étiquettes se renvoient l'une à l'autre.
	var guard := 0
	while _active:
		guard += 1
		if guard > 1000:
			push_error("Dialogues : boucle infinie de sauts, conversation coupée.")
			stop()
			return

		if _index < 0 or _index >= _dialogue.lines.size():
			stop()
			return

		var line: DialogueLine = _dialogue.lines[_index]

		if line.event != &"":
			event.emit(line.event, line.event_arg)
			# stop() a pu être appelé depuis l'écoute de l'événement.
			if not _active:
				return

		if line.is_silent():
			if not _advance_index(line.goto):
				return
			continue

		line_shown.emit(line)
		_box.show_line(line)
		return


## Avance l'index, en suivant `goto` s'il est renseigné.
## Renvoie false si la conversation s'est arrêtée au passage.
func _advance_index(goto: StringName) -> bool:
	if goto == &"":
		_index += 1
		return true

	var target := _dialogue.index_of(goto)
	if target < 0:
		push_warning("Dialogues : étiquette « %s » introuvable, fin de la conversation." % goto)
		stop()
		return false

	_index = target
	return true


## Appelée par la boîte quand le joueur valide une réplique sans choix.
func _on_box_advanced() -> void:
	if not _active:
		return
	var line: DialogueLine = _dialogue.lines[_index]
	if _advance_index(line.goto):
		_show_current()


## Appelée par la boîte quand le joueur retient une option.
func _on_box_choice(index: int) -> void:
	if not _active:
		return
	var line: DialogueLine = _dialogue.lines[_index]
	if index < 0 or index >= line.choices.size():
		return

	var choice: DialogueChoice = line.choices[index]
	choice_made.emit(index, choice)

	if choice.event != &"":
		event.emit(choice.event, choice.event_arg)
		if not _active:
			return

	if _advance_index(choice.goto):
		_show_current()


# --- Boîte et gel du monde ------------------------------------------------

func _ensure_box() -> void:
	# Une boîte posée dans le niveau a la priorité : c'est le moyen de donner
	# une présentation particulière à une scène sans toucher à l'autoload.
	var found := get_tree().get_first_node_in_group(BOX_GROUP)
	var wanted := _default_box
	if found is DialogueBox:
		wanted = found as DialogueBox

	if wanted == null:
		push_error("Dialogues : aucune boîte de dialogue disponible.")
		return

	if wanted == _box:
		return

	_disconnect_box()
	_box = wanted
	_box.advanced.connect(_on_box_advanced)
	_box.choice_selected.connect(_on_box_choice)


func _disconnect_box() -> void:
	if not is_instance_valid(_box):
		return
	if _box.advanced.is_connected(_on_box_advanced):
		_box.advanced.disconnect(_on_box_advanced)
	if _box.choice_selected.is_connected(_on_box_choice):
		_box.choice_selected.disconnect(_on_box_choice)


func _set_world_frozen(frozen: bool) -> void:
	if lock_player:
		get_tree().call_group(&"player", &"set_input_locked", frozen)
	if pause_tree:
		get_tree().paused = frozen
