extends Node

## L'inventaire du joueur, chargé en autoload sous le nom "Inventory".
##
## Les objets sont décrits par des fiches ItemData rangées dans res://Items/,
## chargées toutes seules au démarrage. L'inventaire ne retient que des
## quantités par identifiant :
##     Inventory.add(&"connaissance")
##     Inventory.count(&"connaissance")
##     Inventory.remove(&"connaissance", 2)
##     Inventory.changed.connect(_on_inventory_changed)

## Émis à chaque changement de quantité.
signal changed(id: StringName, count: int)

## Dossier où sont rangées les fiches d'objets.
const ITEMS_DIR := "res://Items/"

## Toutes les fiches connues, par identifiant.
var _items: Dictionary[StringName, ItemData] = {}
## Quantité possédée par identifiant. Absent = zéro.
var _counts: Dictionary[StringName, int] = {}


func _ready() -> void:
	_load_items()


# --- Fiches ---------------------------------------------------------------

## La fiche d'un objet, ou null s'il n'existe pas.
func get_item(id: StringName) -> ItemData:
	return _items.get(id)


# --- Quantités ------------------------------------------------------------

## Ajoute des objets. Renvoie la quantité réellement ajoutée : moins que
## `amount` si l'objet a un maximum.
func add(id: StringName, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	var item := get_item(id)
	if item == null:
		push_warning("Inventory : objet inconnu « %s ». Crée sa fiche dans %s." % [id, ITEMS_DIR])
		return 0

	var before := count(id)
	var after := before + amount
	if item.max_count > 0:
		after = mini(after, item.max_count)
	_set_count(id, after)
	return after - before


## Retire des objets. Renvoie false (et ne retire rien) s'il n'y en a pas assez.
func remove(id: StringName, amount: int = 1) -> bool:
	if amount <= 0:
		return true
	var current := count(id)
	if current < amount:
		return false
	_set_count(id, current - amount)
	return true


func count(id: StringName) -> int:
	return _counts.get(id, 0)


func has(id: StringName, amount: int = 1) -> bool:
	return count(id) >= amount


## Les objets possédés, dans l'ordre d'affichage : [ItemData, ...].
func get_owned_items() -> Array[ItemData]:
	var owned: Array[ItemData] = []
	for id in _counts:
		var item := get_item(id)
		if item != null and _counts[id] > 0:
			owned.append(item)
	owned.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return a.display_name < b.display_name)
	return owned


func clear() -> void:
	for id in _counts.keys():
		_set_count(id, 0)


# --- Sauvegarde -----------------------------------------------------------

func save_state() -> Dictionary:
	var data := {}
	for id in _counts:
		data[String(id)] = _counts[id]
	return data


func load_state(data: Dictionary) -> void:
	clear()
	for key in data:
		var id := StringName(key)
		if get_item(id) == null:
			# Objet retiré du jeu depuis la sauvegarde : on l'oublie.
			push_warning("Inventory : « %s » n'existe plus, ignoré au chargement." % id)
			continue
		_set_count(id, int(data[key]))


# --- Détail ---------------------------------------------------------------

func _set_count(id: StringName, value: int) -> void:
	if value <= 0:
		_counts.erase(id)
		value = 0
	else:
		_counts[id] = value

	var item := get_item(id)
	if item != null and item.dialogue_var != &"":
		Dialogues.set_var(item.dialogue_var, value)
	changed.emit(id, value)


func _load_items() -> void:
	# list_directory() donne les vrais noms de ressources, y compris dans un
	# jeu exporté où les .tres sont convertis et renommés.
	for file in ResourceLoader.list_directory(ITEMS_DIR):
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var item := load(ITEMS_DIR + file) as ItemData
		if item == null:
			continue
		if item.id == &"":
			push_warning("Inventory : %s n'a pas d'identifiant, ignoré." % file)
			continue
		if _items.has(item.id):
			push_warning("Inventory : identifiant « %s » en double (%s)." % [item.id, file])
			continue
		_items[item.id] = item
