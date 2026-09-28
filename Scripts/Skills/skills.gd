extends Node

## Les compétences du joueur, chargé en autoload sous le nom "Skills".
##
## Les compétences sont décrites par des fiches SkillData rangées dans
## res://Skills/, chargées toutes seules au démarrage. Le joueur ne peut se
## servir d'une mécanique que s'il possède la compétence :
##     Skills.has(&"dash")
##     Skills.unlock(&"dash")        # par exemple au ramassage d'une relique
##     Skills.changed.connect(_on_skills_changed)
##
## Une compétence sans fiche n'est pas bloquée : supprimer une fiche par
## erreur ne retire pas la mécanique au joueur.

## Émis quand une compétence est débloquée.
signal changed(id: StringName)

const SKILLS_DIR := "res://Skills/"

var _skills: Dictionary[StringName, SkillData] = {}
var _unlocked: Dictionary[StringName, bool] = {}


func _ready() -> void:
	_load_skills()
	reset()


func get_skill(id: StringName) -> SkillData:
	return _skills.get(id)


func has(id: StringName) -> bool:
	return not _skills.has(id) or _unlocked.has(id)


func unlock(id: StringName) -> void:
	if not _skills.has(id):
		push_warning("Skills : compétence inconnue « %s ». Crée sa fiche dans %s." % [id, SKILLS_DIR])
		return
	if _unlocked.has(id):
		return
	_unlocked[id] = true
	changed.emit(id)


## Les compétences acquises, dans l'ordre d'affichage.
func get_owned_skills() -> Array[SkillData]:
	var owned: Array[SkillData] = []
	for id in _unlocked:
		owned.append(_skills[id])
	owned.sort_custom(func(a: SkillData, b: SkillData) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return a.display_name < b.display_name)
	return owned


func total_count() -> int:
	return _skills.size()


## Retour aux compétences du début de partie.
func reset() -> void:
	_unlocked.clear()
	for id in _skills:
		if _skills[id].unlocked_at_start:
			_unlocked[id] = true


# --- Sauvegarde -----------------------------------------------------------

func save_state() -> Array:
	var ids: Array = []
	for id in _unlocked:
		ids.append(String(id))
	return ids


## Les compétences de départ restent acquises, même si la sauvegarde est plus
## ancienne qu'elles.
func load_state(data: Array) -> void:
	reset()
	for key in data:
		var id := StringName(key)
		if _skills.has(id):
			_unlocked[id] = true


# --- Détail ---------------------------------------------------------------

func _load_skills() -> void:
	for file in ResourceLoader.list_directory(SKILLS_DIR):
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var skill := load(SKILLS_DIR + file) as SkillData
		if skill == null:
			continue
		if skill.id == &"":
			push_warning("Skills : %s n'a pas d'identifiant, ignoré." % file)
			continue
		if _skills.has(skill.id):
			push_warning("Skills : identifiant « %s » en double (%s)." % [skill.id, file])
			continue
		_skills[skill.id] = skill
