extends Area2D
class_name Bullet

## Projectile tiré par le joueur. Il avance en ligne droite et disparaît au
## premier contact. Pour qu'un objet réagisse au tir, il lui suffit d'exposer une
## méthode `take_damage(amount: int, from: Node)` : ennemis, cibles à abattre,
## mécanismes à déverrouiller, etc. (voir Scripts/Elements/shootable.gd).

signal hit(target: Node)

@export var speed: float = 750.0
@export var damage: int = 1
## Durée de vie (s) avant disparition automatique, si rien n'est touché.
@export var lifetime: float = 1.5

## Direction de vol, normalisée. Définie par le tireur juste après l'instanciation.
var direction: Vector2 = Vector2.RIGHT
## Noeud à ignorer (celui qui a tiré), pour ne pas se toucher soi-même.
var shooter: Node = null

var _life_timer: float = 0.0


func _ready() -> void:
	_life_timer = lifetime
	rotation = direction.angle()
	body_entered.connect(_on_impact)
	area_entered.connect(_on_impact)


func _physics_process(delta: float) -> void:
	_life_timer -= delta
	if _life_timer <= 0.0:
		queue_free()
		return

	position += direction * speed * delta


func _on_impact(node: Node) -> void:
	if node == shooter or (shooter != null and node.is_ancestor_of(shooter)):
		return

	# La zone touchée (Hurtbox) n'est souvent qu'un enfant : on remonte jusqu'au
	# noeud qui sait encaisser les dégâts.
	var receiver := node
	while receiver != null and not receiver.has_method("take_damage"):
		receiver = receiver.get_parent()
	if receiver != null:
		receiver.take_damage(damage, self)

	hit.emit(node)
	# On coupe la détection pour éviter un second impact pendant la libération.
	set_deferred("monitoring", false)
	queue_free()
