extends ItemData
class_name WeaponPartData

## Une pièce qui se monte sur le revolver (onglet Équipement du menu). C'est un
## objet comme un autre : on la ramasse, elle entre dans l'inventaire, puis on
## l'équipe sur son emplacement. Une seule pièce par emplacement.
##
## Fiche à ranger dans res://Items/ comme les autres objets (clic droit →
## Nouvelle ressource → WeaponPartData). Elle n'apparaît pas dans l'onglet
## Inventaire, seulement dans Équipement.

## Les emplacements du revolver.
enum Slot { BARREL, CYLINDER, GRIP, SIGHT }

## Nom affiché de chaque emplacement, dans l'ordre de Slot.
const SLOT_NAMES: PackedStringArray = ["Canon", "Barillet", "Crosse", "Viseur"]

@export_group("Pièce de revolver")
## L'emplacement où elle se monte.
@export var slot: Slot = Slot.BARREL
## Dégâts ajoutés à chaque balle.
@export var damage_bonus: int = 0
## Cadence de tir en plus : 0.2 = on tire 20 % plus vite.
@export_range(-0.9, 3.0, 0.05) var fire_rate_bonus: float = 0.0
## Vitesse des balles en plus : 0.25 = 25 % plus rapides.
@export_range(-0.9, 3.0, 0.05) var bullet_speed_bonus: float = 0.0
## Portée en plus : 0.5 = les balles vont 50 % plus loin.
@export_range(-0.9, 3.0, 0.05) var range_bonus: float = 0.0


func stats_text() -> String:
	return format_stats(damage_bonus, fire_rate_bonus, bullet_speed_bonus, range_bonus)


## « Dégâts +1 · Cadence +20 % », en ne gardant que ce qui change.
static func format_stats(damage: int, fire_rate: float, bullet_speed: float, range_ratio: float) -> String:
	var parts: PackedStringArray = []
	if damage != 0:
		parts.append("Dégâts %+d" % damage)
	if not is_zero_approx(fire_rate):
		parts.append("Cadence %+d %%" % roundi(fire_rate * 100.0))
	if not is_zero_approx(bullet_speed):
		parts.append("Vitesse des balles %+d %%" % roundi(bullet_speed * 100.0))
	if not is_zero_approx(range_ratio):
		parts.append("Portée %+d %%" % roundi(range_ratio * 100.0))
	return " · ".join(parts)
