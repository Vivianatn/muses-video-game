extends Node

## L'équipement du joueur, chargé en autoload sous le nom "Equipment" : les
## pièces montées sur le revolver.
##
## Une pièce (fiche WeaponPartData dans res://Items/) se ramasse comme un
## objet, puis s'équipe sur son emplacement, une par emplacement. Elle reste
## dans l'inventaire pendant qu'elle est montée ; si elle en sort, elle est
## démontée.
##     Equipment.equip(&"canon_raye")
##     Equipment.unequip(WeaponPartData.Slot.BARREL)
##     Equipment.damage_bonus()

## Émis quand une pièce est montée ou démontée.
signal changed

## Identifiant de la pièce montée, par emplacement. Absent = rien de monté.
var _equipped: Dictionary[int, StringName] = {}


func _ready() -> void:
	Inventory.changed.connect(_on_inventory_changed)


# --- Pièces ---------------------------------------------------------------

## La pièce montée sur l'emplacement, ou null.
func get_part(slot: int) -> WeaponPartData:
	if not _equipped.has(slot):
		return null
	return Inventory.get_item(_equipped[slot]) as WeaponPartData


func is_equipped(id: StringName) -> bool:
	return _equipped.values().has(id)


## Monte une pièce possédée à sa place, en remplaçant celle qui y était.
func equip(id: StringName) -> bool:
	var part := Inventory.get_item(id) as WeaponPartData
	if part == null or not Inventory.has(id):
		return false
	_equipped[part.slot] = id
	changed.emit()
	return true


func unequip(slot: int) -> void:
	if _equipped.erase(slot):
		changed.emit()


## Les pièces possédées pour un emplacement, dans l'ordre de l'inventaire.
func get_owned_parts(slot: int) -> Array[WeaponPartData]:
	var parts: Array[WeaponPartData] = []
	for item in Inventory.get_owned_items():
		var part := item as WeaponPartData
		if part != null and part.slot == slot:
			parts.append(part)
	return parts


func clear() -> void:
	if not _equipped.is_empty():
		_equipped.clear()
		changed.emit()


# --- Effets sur le tir ----------------------------------------------------

func damage_bonus() -> int:
	var total := 0
	for part in _parts():
		total += part.damage_bonus
	return total


func fire_rate_bonus() -> float:
	var total := 0.0
	for part in _parts():
		total += part.fire_rate_bonus
	return total


func bullet_speed_bonus() -> float:
	var total := 0.0
	for part in _parts():
		total += part.bullet_speed_bonus
	return total


func range_bonus() -> float:
	var total := 0.0
	for part in _parts():
		total += part.range_bonus
	return total


## À multiplier au délai entre deux tirs : tirer 25 % plus vite, c'est
## attendre 1 / 1.25 fois le délai.
func fire_cooldown_multiplier() -> float:
	return 1.0 / maxf(1.0 + fire_rate_bonus(), 0.1)


func bullet_speed_multiplier() -> float:
	return maxf(1.0 + bullet_speed_bonus(), 0.1)


func range_multiplier() -> float:
	return maxf(1.0 + range_bonus(), 0.1)


## Tous les bonus cumulés, à afficher : « Dégâts +1 · Cadence +20 % ».
func stats_text() -> String:
	return WeaponPartData.format_stats(damage_bonus(), fire_rate_bonus(), bullet_speed_bonus(), range_bonus())


# --- Sauvegarde -----------------------------------------------------------

func save_state() -> Dictionary:
	var data := {}
	for slot in _equipped:
		data[str(slot)] = String(_equipped[slot])
	return data


## À appeler après Inventory.load_state() : on ne monte que ce qu'on possède.
func load_state(data: Dictionary) -> void:
	_equipped.clear()
	for key in data:
		var id := StringName(data[key])
		var part := Inventory.get_item(id) as WeaponPartData
		if part != null and Inventory.has(id):
			_equipped[part.slot] = id
	changed.emit()


# --- Détail ---------------------------------------------------------------

func _parts() -> Array[WeaponPartData]:
	var parts: Array[WeaponPartData] = []
	for slot in _equipped:
		var part := get_part(slot)
		if part != null:
			parts.append(part)
	return parts


func _on_inventory_changed(id: StringName, count: int) -> void:
	# Pièce perdue (vendue, retirée, nouvelle partie) : elle est démontée.
	if count > 0 or not is_equipped(id):
		return
	for slot in _equipped.keys():
		if _equipped[slot] == id:
			_equipped.erase(slot)
	changed.emit()
