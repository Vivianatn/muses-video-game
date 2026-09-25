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
## Émis quand une variable de dialogue change, depuis un fichier (`$ ...`) ou
## depuis un script (set_var()).
signal variable_changed(name: StringName, value: Variant)
## Émis quand le dialogue choisit la prochaine conversation du PNJ (`>> ...`).
## Le déclencheur qui a lancé la conversation s'en charge tout seul ; ce signal
## sert aux autres scripts qui voudraient réagir.
signal next_dialogue_requested(target: String, context: Node)

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
## Variables de dialogue, partagées par toutes les conversations du jeu.
var _vars: Dictionary[StringName, Variant] = {}
## Repère `{nom}` dans un texte.
var _var_pattern := RegEx.create_from_string("\\{([A-Za-z_][A-Za-z0-9_]*)\\}")
## Options réellement proposées pour la réplique affichée, dans l'ordre des
## boutons : celles dont la condition est fausse n'y sont pas, donc l'index
## renvoyé par la boîte ne correspond plus forcément à line.choices.
var _shown_choices: Array[DialogueChoice] = []


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


# --- Variables ------------------------------------------------------------

## Valeur d'une variable de dialogue, ou `default` si elle n'existe pas.
func get_var(var_name: StringName, default: Variant = null) -> Variant:
	return _vars.get(var_name, default)


## Donne une valeur à une variable. C'est le point d'entrée d'une sauvegarde
## ou d'un script de quête : Dialogues.set_var(&"vory", "Vory").
func set_var(var_name: StringName, value: Variant) -> void:
	# typeof() d'abord : comparer un nombre à un texte n'a pas de sens.
	if _vars.has(var_name) and typeof(_vars[var_name]) == typeof(value) and _vars[var_name] == value:
		return
	_vars[var_name] = value
	variable_changed.emit(var_name, value)


func has_var(var_name: StringName) -> bool:
	return _vars.has(var_name)


## Toutes les variables, pour les sauvegarder. Copie : la modifier ne change
## rien au jeu.
func get_vars() -> Dictionary[StringName, Variant]:
	return _vars.duplicate()


## Oublie toutes les variables (nouvelle partie).
func clear_vars() -> void:
	_vars.clear()


## Vrai si la condition est remplie. Vide = toujours vrai. Formes acceptées :
##     vory == Vory        vory != Vory        (texte ou nombre)
##     visites >= 2        visites < 3         (<, >, <=, >= : nombres)
##     chemin_montre       pas chemin_montre   (la variable existe et ne vaut
##                                              ni 0, ni vide, ni « non »)
## La valeur à droite peut contenir des `{nom}`.
func check(condition: String) -> bool:
	var text := condition.strip_edges()
	if text.is_empty():
		return true

	for negation in ["pas ", "non ", "!"]:
		if text.begins_with(negation):
			return not check(text.substr(negation.length()))

	for op in ["==", "!=", "<=", ">=", "<", ">"]:
		var at := text.find(op)
		if at < 0:
			continue
		var var_name := StringName(text.substr(0, at).strip_edges())
		var expected: Variant = _parse_value(format_text(text.substr(at + op.length()).strip_edges()))
		return _compare(get_var(var_name), op, expected)

	return _is_truthy(get_var(StringName(text)))


static func _compare(value: Variant, op: String, expected: Variant) -> bool:
	var numbers := (value is int or value is float) and (expected is int or expected is float)
	match op:
		"==":
			if numbers:
				return value == expected
			return value != null and str(value) == str(expected)
		"!=":
			if numbers:
				return value != expected
			return value == null or str(value) != str(expected)
	if not numbers:
		# Une variable pas encore définie (ou du texte) n'est ni plus grande ni
		# plus petite que quoi que ce soit.
		return false
	match op:
		"<=": return value <= expected
		">=": return value >= expected
		"<": return value < expected
		">": return value > expected
	return false


static func _is_truthy(value: Variant) -> bool:
	if value == null:
		return false
	if value is bool:
		return value
	if value is int or value is float:
		return value != 0
	var text := str(value).strip_edges().to_lower()
	return not (text.is_empty() or text in ["non", "faux", "false", "0"])


## Remplace chaque `{nom}` par la valeur de la variable. Une variable inconnue
## reste écrite telle quelle, pour qu'une faute de frappe se voie à l'écran.
func format_text(source: String) -> String:
	if not source.contains("{"):
		return source
	var result := ""
	var last := 0
	for found in _var_pattern.search_all(source):
		var var_name := StringName(found.get_string(1))
		result += source.substr(last, found.get_start() - last)
		result += str(_vars[var_name]) if _vars.has(var_name) else found.get_string()
		last = found.get_end()
	return result + source.substr(last)


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

		if not check(line.condition):
			# Condition fausse : la ligne n'existe pas, saut compris.
			_index += 1
			continue

		if line.var_name != &"":
			_apply_var(line)

		if not line.next_dialogue.is_empty():
			_request_next_dialogue(format_text(line.next_dialogue))

		if line.event != &"":
			event.emit(line.event, format_text(line.event_arg))
			# stop() a pu être appelé depuis l'écoute de l'événement.
			if not _active:
				return

		if line.is_silent():
			if not _advance_index(line.goto):
				return
			continue

		var shown := _resolve_line(line)
		line_shown.emit(shown)
		_box.show_line(shown)
		return


func _apply_var(line: DialogueLine) -> void:
	var value := format_text(line.var_value)
	match line.var_op:
		DialogueLine.VarOp.DEFAULT:
			if not has_var(line.var_name):
				set_var(line.var_name, _parse_value(value))
		DialogueLine.VarOp.ADD:
			var current: Variant = get_var(line.var_name, 0)
			var amount: Variant = _parse_value(value)
			if not (current is int or current is float) or not (amount is int or amount is float):
				push_warning("Dialogues : « %s += %s » ne porte pas sur des nombres, ignoré." % [line.var_name, value])
				return
			set_var(line.var_name, current + amount)
		_:
			set_var(line.var_name, _parse_value(value))


## « 3 » devient le nombre 3, le reste reste du texte.
static func _parse_value(value: String) -> Variant:
	if value.is_valid_int():
		return value.to_int()
	if value.is_valid_float():
		return value.to_float()
	return value


## Copie de la réplique avec les `{nom}` remplacés, pour l'affichage. On ne
## touche pas à l'original : la même réplique peut revenir plus tard avec une
## autre valeur (Vory, d'abord « Robot étrange », puis « Vory »).
func _resolve_line(line: DialogueLine) -> DialogueLine:
	var shown := line.duplicate() as DialogueLine
	shown.speaker = format_text(line.speaker)
	shown.speaker_key = line.speaker.replace("{", "").replace("}", "").strip_edges()
	shown.text = format_text(line.text)

	_shown_choices.clear()
	var choices: Array[DialogueChoice] = []
	for choice in line.choices:
		if not check(choice.condition):
			continue
		_shown_choices.append(choice)
		var copy := choice.duplicate() as DialogueChoice
		copy.text = format_text(choice.text)
		choices.append(copy)
	# Si toutes les options sont masquées, la réplique se valide comme une
	# réplique normale et on passe à la suite.
	shown.choices = choices
	return shown


## Transmet `>> ...` au nœud qui a lancé la conversation (le déclencheur du
## PNJ), qui sait quelles conversations il possède.
func _request_next_dialogue(target: String) -> void:
	next_dialogue_requested.emit(target, _context)
	if _context != null and _context.has_method(&"request_next_dialogue"):
		_context.request_next_dialogue(target)
	else:
		push_warning("Dialogues : « >> %s » ignoré, la conversation n'a pas été lancée par un DialogueTrigger." % target)


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
	if index < 0 or index >= _shown_choices.size():
		return

	var choice: DialogueChoice = _shown_choices[index]
	_shown_choices.clear()
	choice_made.emit(index, choice)

	if choice.event != &"":
		event.emit(choice.event, format_text(choice.event_arg))
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
