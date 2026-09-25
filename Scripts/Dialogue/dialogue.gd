extends Resource
class_name Dialogue

## Une conversation complète : une suite de DialogueLine, éventuellement
## étiquetées pour permettre des sauts et des embranchements.
##
## Deux façons de l'écrire :
##  1. Une ressource .tres montée à la main dans l'inspecteur.
##  2. Un fichier texte .txt, bien plus rapide à écrire (voir from_text()).

@export var lines: Array[DialogueLine] = []


## Index de la réplique portant cette étiquette, ou -1.
func index_of(id: StringName) -> int:
	if id == &"":
		return -1
	for i in lines.size():
		if lines[i].id == id:
			return i
	return -1


func is_empty() -> bool:
	return lines.is_empty()


# --- Écriture en texte ----------------------------------------------------

## Construit un Dialogue à partir du format texte du projet :
##
##     # ceci est un commentaire
##     :: depart                   # étiquette, cible d'un saut
##     Vory: Bonjour, toi.
##     Tu as l'air perdu.          # sans nom : Vory continue de parler
##     - Oui, un peu. -> aide      # un choix, et où il mène
##     - Non, ça va. -> fin
##
##     :: aide
##     Vory: Alors suis-moi.
##     @ donne_carte               # événement envoyé au jeu
##     $ vory = Vory               # variable (?= valeur de départ, += ajout)
##     {vory}: On se connaît.      # {nom} affiche la valeur d'une variable
##     -> fin                      # saut
##     - Qui es-tu ? [si vory != Vory]   # condition, sur n'importe quelle ligne
##     >> vory_habituel            # conversation que le PNJ tiendra la prochaine fois
##
##     :: fin
##     Vory: À bientôt !
##
## Une ligne vide sépare deux répliques sans rien changer d'autre.
static func from_text(source: String) -> Dialogue:
	var dialogue := Dialogue.new()
	var last_speaker := ""
	# Étiquette lue en attente : elle se pose sur la prochaine réplique créée.
	var pending_id := &""

	for raw in source.split("\n"):
		var line := _strip_comment(raw).strip_edges()
		if line.is_empty():
			continue

		# :: etiquette
		if line.begins_with("::"):
			pending_id = StringName(line.substr(2).strip_edges())
			continue

		# ... [si condition] : possible sur toutes les sortes de ligne ci-dessous.
		var condition := _take_condition(line)
		if not condition.is_empty():
			line = line.substr(0, line.rfind("[")).strip_edges()

		# >> conversation que le PNJ tiendra la prochaine fois
		if line.begins_with(">>"):
			var next := DialogueLine.new()
			next.next_dialogue = line.substr(2).strip_edges()
			next.condition = condition
			pending_id = _attach(dialogue, next, pending_id)
			continue

		# -> saut
		if line.begins_with("->"):
			var jump := DialogueLine.new()
			jump.goto = StringName(line.substr(2).strip_edges())
			jump.condition = condition
			pending_id = _attach(dialogue, jump, pending_id)
			continue

		# @ evenement [argument]
		if line.begins_with("@"):
			var body := line.substr(1).strip_edges()
			var space := body.find(" ")
			var ev := DialogueLine.new()
			ev.event = StringName(body if space < 0 else body.substr(0, space))
			ev.event_arg = "" if space < 0 else body.substr(space + 1).strip_edges()
			ev.condition = condition
			pending_id = _attach(dialogue, ev, pending_id)
			continue

		# $ variable = valeur   (ou ?= pour une valeur de départ, += pour ajouter)
		if line.begins_with("$"):
			var assign := _parse_var(line.substr(1).strip_edges())
			if assign == null:
				push_warning("Dialogue : variable mal écrite, ignorée (%s)." % line)
				continue
			assign.condition = condition
			pending_id = _attach(dialogue, assign, pending_id)
			continue

		# - choix -> etiquette : il se raccroche à la dernière réplique écrite.
		if line.begins_with("-"):
			var choice := DialogueChoice.new()
			var label := line.substr(1).strip_edges()
			var arrow := label.rfind("->")
			if arrow >= 0:
				choice.goto = StringName(label.substr(arrow + 2).strip_edges())
				label = label.substr(0, arrow).strip_edges()
			choice.text = label
			choice.condition = condition
			if dialogue.lines.is_empty():
				push_warning("Dialogue : un choix arrive avant toute réplique, ignoré.")
				continue
			dialogue.lines[-1].choices.append(choice)
			continue

		# Nom: texte  (ou juste du texte, qui garde le nom précédent)
		var entry := DialogueLine.new()
		var colon := _speaker_colon(line)
		if colon >= 0:
			last_speaker = line.substr(0, colon).strip_edges()
			entry.text = line.substr(colon + 1).strip_edges()
		else:
			entry.text = line
		entry.speaker = last_speaker
		entry.condition = condition
		pending_id = _attach(dialogue, entry, pending_id)

	return dialogue


## Lit un fichier texte du projet, par exemple "res://Dialogues/vory_intro.txt".
static func load_text(path: String) -> Dialogue:
	if not FileAccess.file_exists(path):
		push_error("Dialogue : fichier introuvable (%s)." % path)
		return Dialogue.new()
	return from_text(FileAccess.get_file_as_string(path))


static func _attach(dialogue: Dialogue, line: DialogueLine, pending_id: StringName) -> StringName:
	line.id = pending_id
	dialogue.lines.append(line)
	return &""


## Condition écrite en fin de ligne, « ... [si vory != Vory] », ou "" s'il n'y
## en a pas. Seuls les crochets qui commencent par « si » comptent : le BBCode
## ([b], [color=red]...) reste du texte.
static func _take_condition(line: String) -> String:
	if not line.ends_with("]"):
		return ""
	var open := line.rfind("[")
	if open < 0:
		return ""
	var inside := line.substr(open + 1, line.length() - open - 2).strip_edges()
	if not inside.begins_with("si "):
		return ""
	return inside.substr(3).strip_edges()


## Lit « nom = valeur », « nom ?= valeur » ou « nom += nombre ». Renvoie null
## si la ligne ne ressemble à rien de tout ça.
static func _parse_var(body: String) -> DialogueLine:
	var equal := body.find("=")
	if equal <= 0:
		return null

	var line := DialogueLine.new()
	var name_end := equal
	match body[equal - 1]:
		"?":
			line.var_op = DialogueLine.VarOp.DEFAULT
			name_end -= 1
		"+":
			line.var_op = DialogueLine.VarOp.ADD
			name_end -= 1
		_:
			line.var_op = DialogueLine.VarOp.SET

	var var_name := body.substr(0, name_end).strip_edges()
	if not var_name.is_valid_identifier():
		return null
	line.var_name = StringName(var_name)
	line.var_value = body.substr(equal + 1).strip_edges()
	return line


## Position du ":" qui sépare le nom du texte, ou -1 s'il n'y en a pas.
## On n'accepte qu'un nom court et sans ponctuation, pour que "Attention : un
## piège !" reste une phrase et ne devienne pas un personnage nommé "Attention".
static func _speaker_colon(line: String) -> int:
	var colon := line.find(":")
	if colon <= 0 or colon > 24:
		return -1
	var name_part := line.substr(0, colon)
	for c in name_part:
		# Les accolades permettent un nom tiré d'une variable : « {vory}: ... ».
		if not (c.is_valid_identifier() or c in [" ", "-", "'", "{", "}"] or c.unicode_at(0) > 127):
			return -1
	return colon


## Retire un commentaire en fin de ligne. Pour écrire un vrai « # » dans une
## réplique, il faut le faire précéder d'une contre-oblique.
static func _strip_comment(line: String) -> String:
	var hash_pos := line.find("#")
	if hash_pos < 0:
		return line

	# String.chr(92) = la contre-oblique, écrite ainsi pour ne pas avoir à
	# l'échapper au milieu d'une chaîne.
	var escape := String.chr(92)
	if hash_pos > 0 and line[hash_pos - 1] == escape:
		return line.replace(escape + "#", "#")

	return line.substr(0, hash_pos)
