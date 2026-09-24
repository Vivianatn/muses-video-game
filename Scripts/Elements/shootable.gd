extends Area2D
class_name Shootable

## Cible générique que l'on peut abattre au pistolet : ennemi simple, interrupteur,
## caisse, cristal à briser... Branche le signal `triggered` sur ce que tu veux
## déclencher (ouvrir une porte, faire apparaître une plateforme, etc.).

signal damaged(remaining: int, from: Node)
signal triggered(from: Node)

## Nombre de points de dégâts à encaisser avant de se déclencher.
@export var hit_points: int = 1
## Si vrai, la cible disparaît une fois déclenchée.
@export var free_on_trigger: bool = false
## Si vrai, la cible peut être redéclenchée après coup (interrupteur répétable).
@export var reusable: bool = false

var _remaining: int = 0
var _spent: bool = false


func _ready() -> void:
	_remaining = hit_points


## Appelée automatiquement par les projectiles (voir Scripts/Weapons/bullet.gd).
func take_damage(amount: int, from: Node = null) -> void:
	if _spent and not reusable:
		return

	_remaining -= amount
	damaged.emit(_remaining, from)
	if _remaining > 0:
		return

	_spent = true
	triggered.emit(from)

	if free_on_trigger:
		queue_free()
	elif reusable:
		_remaining = hit_points
		_spent = false
