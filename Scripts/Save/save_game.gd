extends Node

## Sauvegarde et chargement de la partie, chargé en autoload sous le nom
## "SaveGame". Voir Scripts/Save/LISEZMOI.md pour le détail.
##
## Ce qui est sauvegardé :
##  - le niveau en cours, la position et la vie du joueur ;
##  - l'inventaire et les variables de dialogue ;
##  - l'état de chaque élément du monde qui le demande (objet ramassé, ennemi
##    vaincu, avancement des conversations d'un PNJ...) ;
##  - de quoi présenter l'emplacement : date, temps de jeu, lieu, miniature.
##
## Emplacements : 0 est la sauvegarde automatique, 1 à slot_count les
## sauvegardes manuelles.
##
## Rendre un nœud sauvegardable : dans son _ready(), appeler
##     SaveGame.register(self)
## et lui donner deux méthodes :
##     func save_state() -> Dictionary      # ce qu'il faut retenir
##     func load_state(data: Dictionary)    # le remettre dans cet état
## Pour un nœud qui disparaît (objet ramassé, ennemi tué), appeler aussi
## SaveGame.store(self, {...}) au moment où ça arrive : une fois libéré, on
## ne peut plus lui demander son état.

signal saved(slot: int)
signal loaded(slot: int)
## Émis quand une sauvegarde ou un chargement échoue, avec un message lisible.
signal failed(slot: int, message: String)

const SAVE_DIR := "user://saves/"
const AUTOSAVE_SLOT := 0
const GROUP := &"saveable"

## Signature en tête de chaque fichier : un fichier qui ne commence pas par là
## n'est pas une sauvegarde du jeu.
const MAGIC := "MUSE"
## Version du format. À augmenter quand la structure des données change, en
## ajoutant de quoi convertir les anciennes dans _migrate().
const FORMAT_VERSION := 1

## Nombre d'emplacements de sauvegarde manuelle.
@export var slot_count: int = 3
## Sauvegarde automatique toutes les X secondes de jeu (hors pause et hors
## dialogue). 0 = jamais.
@export var autosave_interval: float = 300.0
## Largeur (px) de la miniature enregistrée avec chaque sauvegarde.
@export var thumbnail_width: int = 320

## Temps de jeu cumulé (s), pauses exclues.
var playtime: float = 0.0

## État des éléments du monde, par clé « scène::chemin du nœud ». Il couvre
## tous les niveaux visités, pas seulement celui en cours.
var _world: Dictionary[String, Dictionary] = {}
var _autosave_timer: float = 0.0
## Miniature prise juste avant l'ouverture du menu, pour ne pas y voir le menu.
var _pending_thumbnail: Image = null
var _busy: bool = false


func _ready() -> void:
	# Doit tourner pendant la pause : on sauvegarde depuis le menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	playtime += delta

	if autosave_interval <= 0.0 or Dialogues.is_active():
		return
	_autosave_timer += delta
	if _autosave_timer >= autosave_interval:
		autosave()


## Vrai pendant un chargement : mieux vaut ne rien lancer d'autre.
func is_busy() -> bool:
	return _busy


# --- Éléments du monde ----------------------------------------------------

## Inscrit un nœud : il sera interrogé à chaque sauvegarde (save_state) et
## remis dans son état sauvegardé tout de suite s'il en a un (load_state).
func register(node: Node) -> void:
	node.add_to_group(GROUP)
	var key := key_of(node)
	if _world.has(key) and node.has_method(&"load_state"):
		node.load_state(_world[key])


## Retient l'état d'un nœud tout de suite, sans attendre la prochaine
## sauvegarde. Indispensable pour un nœud qui va être libéré.
func store(node: Node, state: Dictionary) -> void:
	_world[key_of(node)] = state


## État retenu pour ce nœud, ou un dictionnaire vide.
func get_stored(node: Node) -> Dictionary:
	return _world.get(key_of(node), {})


## Identifiant stable d'un nœud : sa scène de niveau et son chemin dedans.
## Renommer ou déplacer le nœud dans l'arbre lui fait perdre son état.
func key_of(node: Node) -> String:
	var level := get_tree().current_scene
	if level == null or not level.is_ancestor_of(node):
		return str(node.get_path())
	return "%s::%s" % [level.scene_file_path, level.get_path_to(node)]


# --- Sauvegarder ----------------------------------------------------------

## Sauvegarde dans l'emplacement donné. Renvoie true si tout s'est bien passé.
func save_slot(slot: int) -> bool:
	if _busy:
		return false
	var level := get_tree().current_scene
	if level == null:
		failed.emit(slot, "Aucun niveau à sauvegarder.")
		return false

	_collect_world()
	var data := {
		"version": FORMAT_VERSION,
		"meta": {
			"saved_at": int(Time.get_unix_time_from_system()),
			"playtime": playtime,
			"location": _location_name(level),
			"thumbnail": _thumbnail_bytes(),
		},
		"scene": level.scene_file_path,
		"player": _player_state(),
		"inventory": Inventory.save_state(),
		"dialogue_vars": _dialogue_vars(),
		"world": _world.duplicate(true),
	}

	var error := _write_file(_path(slot), var_to_bytes(data))
	if error != OK:
		failed.emit(slot, "Écriture impossible (%s)." % error_string(error))
		return false

	if slot == AUTOSAVE_SLOT:
		_autosave_timer = 0.0
	saved.emit(slot)
	return true


func autosave() -> bool:
	_autosave_timer = 0.0
	return save_slot(AUTOSAVE_SLOT)


## À appeler juste avant d'afficher un menu d'où l'on sauvegardera : la
## miniature montre alors le jeu, et pas le menu par-dessus.
func capture_thumbnail() -> void:
	_pending_thumbnail = _capture_image()


func clear_thumbnail() -> void:
	_pending_thumbnail = null


# --- Charger --------------------------------------------------------------

## Charge l'emplacement : change de niveau si besoin, puis remet chaque chose
## en place. À attendre avec await si l'on a besoin de savoir quand c'est fini.
func load_slot(slot: int) -> bool:
	if _busy:
		return false
	var data := _read_slot(slot)
	if data.is_empty():
		failed.emit(slot, "Sauvegarde illisible ou absente.")
		return false

	var scene_path: String = data.get("scene", "")
	if not ResourceLoader.exists(scene_path):
		failed.emit(slot, "Le niveau « %s » n'existe plus." % scene_path)
		return false

	_busy = true
	Dialogues.stop()

	# Tout ce qui ne dépend pas du niveau d'abord : les nœuds du niveau
	# rechargé liront _world dès leur _ready().
	playtime = float(data.get("meta", {}).get("playtime", 0.0))
	_autosave_timer = 0.0
	_world.clear()
	var world: Dictionary = data.get("world", {})
	for key in world:
		_world[String(key)] = world[key]

	Dialogues.clear_vars()
	var vars: Dictionary = data.get("dialogue_vars", {})
	for var_name in vars:
		Dialogues.set_var(StringName(var_name), vars[var_name])
	Inventory.load_state(data.get("inventory", {}))

	get_tree().paused = false
	var previous := get_tree().current_scene
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		_busy = false
		failed.emit(slot, "Chargement du niveau impossible (%s)." % error_string(error))
		return false
	# Le changement de scène se fait à la fin de l'image : on attend que le
	# nouveau niveau soit en place et prêt (même quand on recharge le même).
	while true:
		var level := get_tree().current_scene
		if level != null and level != previous and level.is_node_ready():
			break
		await get_tree().process_frame

	var player := get_tree().get_first_node_in_group(&"player")
	if player != null and player.has_method(&"load_state"):
		player.load_state(data.get("player", {}))

	_busy = false
	loaded.emit(slot)
	return true


## Emplacement de la sauvegarde la plus récente, ou -1 s'il n'y en a aucune.
## C'est ce que charge un bouton « Continuer ».
func latest_slot() -> int:
	var best := -1
	var best_time := -1
	for slot in range(0, slot_count + 1):
		var info := get_slot_info(slot)
		if info.get("exists", false) and not info.get("corrupted", false) and info.saved_at > best_time:
			best = slot
			best_time = info.saved_at
	return best


# --- Emplacements ---------------------------------------------------------

## Ce qu'il faut pour présenter un emplacement dans un menu :
##   exists, corrupted, saved_at (unix), playtime (s), location,
##   thumbnail (Texture2D ou null), from_backup (fichier principal abîmé,
##   copie de secours utilisée).
func get_slot_info(slot: int) -> Dictionary:
	var info := {"exists": false, "corrupted": false, "from_backup": false}
	if not FileAccess.file_exists(_path(slot)) and not FileAccess.file_exists(_path(slot) + ".bak"):
		return info
	info.exists = true

	var result := _read_with_backup(_path(slot))
	if result.data.is_empty():
		info.corrupted = true
		return info
	info.from_backup = result.from_backup

	var meta: Dictionary = result.data.get("meta", {})
	info.saved_at = int(meta.get("saved_at", 0))
	info.playtime = float(meta.get("playtime", 0.0))
	info.location = String(meta.get("location", ""))
	info.thumbnail = null
	var bytes: PackedByteArray = meta.get("thumbnail", PackedByteArray())
	if not bytes.is_empty():
		var image := Image.new()
		if image.load_png_from_buffer(bytes) == OK:
			info.thumbnail = ImageTexture.create_from_image(image)
	return info


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_path(slot)) or FileAccess.file_exists(_path(slot) + ".bak")


func delete_slot(slot: int) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_path(slot) + suffix):
			DirAccess.remove_absolute(_path(slot) + suffix)


## « 1 h 05 min » ou « 12 min », pour afficher un temps de jeu.
static func format_playtime(seconds: float) -> String:
	var minutes := int(seconds) / 60
	if minutes < 60:
		return "%d min" % minutes
	return "%d h %02d min" % [minutes / 60, minutes % 60]


## « 25/09/2026 14:03 », pour afficher la date d'une sauvegarde.
static func format_date(unix_time: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(unix_time + bias)
	return "%02d/%02d/%d %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]


# --- Collecte -------------------------------------------------------------

func _collect_world() -> void:
	for node in get_tree().get_nodes_in_group(GROUP):
		if is_instance_valid(node) and node.has_method(&"save_state"):
			_world[key_of(node)] = node.save_state()


func _player_state() -> Dictionary:
	var player := get_tree().get_first_node_in_group(&"player")
	if player != null and player.has_method(&"save_state"):
		return player.save_state()
	return {}


func _dialogue_vars() -> Dictionary:
	var vars := {}
	var source := Dialogues.get_vars()
	for var_name in source:
		vars[String(var_name)] = source[var_name]
	return vars


## Nom du lieu affiché dans le menu : la métadonnée « level_name » de la
## racine du niveau si elle existe, sinon le nom de ce nœud.
func _location_name(level: Node) -> String:
	return String(level.get_meta(&"level_name", level.name))


func _capture_image() -> Image:
	var image := get_viewport().get_texture().get_image()
	if image == null or image.get_width() == 0:
		return null
	var height := int(thumbnail_width * float(image.get_height()) / image.get_width())
	image.resize(thumbnail_width, height, Image.INTERPOLATE_BILINEAR)
	return image


func _thumbnail_bytes() -> PackedByteArray:
	var image := _pending_thumbnail if _pending_thumbnail != null else _capture_image()
	if image == null:
		return PackedByteArray()
	return image.save_png_to_buffer()


# --- Fichiers -------------------------------------------------------------
#
# Un fichier de sauvegarde, c'est :
#   "MUSE" | version (u32) | taille des données (u32) | SHA-256 (32 octets) | données
# Les données sont un Dictionary passé par var_to_bytes() : pas d'objets, donc
# un fichier trafiqué ne peut pas faire exécuter de code au chargement.
#
# L'écriture passe par un fichier .tmp, et l'ancienne sauvegarde devient .bak
# avant d'être remplacée : une coupure de courant en pleine écriture ne détruit
# jamais la dernière sauvegarde valide.

func _path(slot: int) -> String:
	if slot == AUTOSAVE_SLOT:
		return SAVE_DIR + "autosave.sav"
	return SAVE_DIR + "slot_%d.sav" % slot


func _write_file(path: String, payload: PackedByteArray) -> Error:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(MAGIC.to_ascii_buffer())
	file.store_32(FORMAT_VERSION)
	file.store_32(payload.size())
	file.store_buffer(_hash(payload))
	file.store_buffer(payload)
	var error := file.get_error()
	file.close()
	if error != OK:
		return error

	# On relit ce qu'on vient d'écrire avant de toucher à l'ancienne sauvegarde.
	if _read_file(tmp).is_empty():
		return ERR_FILE_CORRUPT

	var backup := path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		DirAccess.rename_absolute(path, backup)
	return DirAccess.rename_absolute(tmp, path)


## Lit un fichier. Renvoie un dictionnaire vide s'il est absent, abîmé, ou
## d'une version plus récente que le jeu.
func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() < 44 or file.get_buffer(4).get_string_from_ascii() != MAGIC:
		return {}

	var version := file.get_32()
	if version > FORMAT_VERSION:
		push_warning("SaveGame : %s vient d'une version plus récente du jeu." % path)
		return {}
	var size := file.get_32()
	var expected := file.get_buffer(32)
	var payload := file.get_buffer(size)
	if payload.size() != size or _hash(payload) != expected:
		push_warning("SaveGame : %s est abîmé (somme de contrôle fausse)." % path)
		return {}

	var data: Variant = bytes_to_var(payload)
	if data is not Dictionary:
		return {}
	return _migrate(data, version)


## Lit le fichier, ou sa copie de secours s'il est abîmé.
func _read_with_backup(path: String) -> Dictionary:
	var data := _read_file(path)
	if not data.is_empty():
		return {"data": data, "from_backup": false}
	data = _read_file(path + ".bak")
	return {"data": data, "from_backup": not data.is_empty()}


func _read_slot(slot: int) -> Dictionary:
	var result := _read_with_backup(_path(slot))
	if result.from_backup:
		push_warning("SaveGame : emplacement %d abîmé, copie de secours chargée." % slot)
	return result.data


## Met à niveau des données écrites par une version plus ancienne du format.
## Exemple le jour où FORMAT_VERSION passe à 2 :
##     if version < 2:
##         data["player"]["mana"] = 10
func _migrate(data: Dictionary, _version: int) -> Dictionary:
	return data


static func _hash(bytes: PackedByteArray) -> PackedByteArray:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish()
