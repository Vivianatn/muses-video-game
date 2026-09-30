extends VBoxContainer

## Jauge de vie du joueur (DA « Jauge », variante vie) : l'étiquette, la valeur
## chiffrée, puis la piste. Elle se branche toute seule sur le premier noeud du
## groupe "player" et suit son signal `health_changed`.

## Laisse vide pour chercher automatiquement le joueur dans le groupe "player".
@export var player_path: NodePath
## Vitesse de rattrapage de la jauge (0 = saut instantané).
@export var fill_speed: float = 6.0
## Seuil (0-1) en dessous duquel le remplissage bat pour alerter.
@export_range(0.0, 1.0) var low_health_threshold: float = 0.3

@onready var _value: Label = %Value
@onready var _track: Jauge = %Track

var _target_ratio: float = 1.0
var _last_health: int = -1
var _rest_position: Vector2
var _hit_tween: Tween


func _ready() -> void:
	# L'interface bouge au rythme de l'affichage (tweens, _process) : on la
	# sort de l'interpolation physique, qui ne vaut que pour le monde.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_rest_position = position
	var player: Node = get_node_or_null(player_path)
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("HealthBar : aucun joueur trouvé.")
		return

	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)

	# Valeurs de départ, avant même le premier dégât.
	if player.has_method("get_health"):
		_on_health_changed(player.get_health(), player.get_max_health())
	_track.ratio = _target_ratio


## Ne tourne que pendant que la jauge rattrape la vie : le reste du temps,
## rien ne bouge et rien n'est recalculé.
func _process(delta: float) -> void:
	if fill_speed <= 0.0 or absf(_track.ratio - _target_ratio) < 0.001:
		_track.ratio = _target_ratio
		set_process(false)
		return
	_track.ratio = lerpf(_track.ratio, _target_ratio, 1.0 - exp(-fill_speed * delta))


func _on_health_changed(current: int, maximum: int) -> void:
	var top := maxi(maximum, 1)
	_target_ratio = float(current) / top
	set_process(true)
	_value.text = "%d / %d" % [current, top]
	_track.alert = current > 0 and _target_ratio <= low_health_threshold
	if _last_health >= 0 and current < _last_health:
		_on_hit()
	_last_health = current


## Un coup : la jauge tremble et s'éclaire un instant.
func _on_hit() -> void:
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	position = _rest_position
	_track.modulate = Color(1.8, 1.8, 1.8)
	_hit_tween = create_tween()
	_hit_tween.tween_property(_track, ^"modulate", Color.WHITE, 0.35)
	var shake := create_tween()
	for i in 6:
		var strength := 5.0 * (1.0 - i / 6.0)
		shake.tween_property(self, ^"position", _rest_position + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength, 0.035)
	shake.tween_property(self, ^"position", _rest_position, 0.05)
