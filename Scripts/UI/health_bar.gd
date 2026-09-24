extends ProgressBar

## Barre de vie du joueur. Elle se branche toute seule sur le premier noeud du
## groupe "player" et suit son signal `health_changed`.

## Laisse vide pour chercher automatiquement le joueur dans le groupe "player".
@export var player_path: NodePath
## Vitesse de rattrapage de la barre (0 = saut instantané).
@export var fill_speed: float = 6.0
## Couleur de la barre quand la vie est basse.
@export var low_health_color: Color = Color(0.9, 0.2, 0.2)
## Seuil (0-1) en dessous duquel la barre passe en couleur d'alerte.
@export_range(0.0, 1.0) var low_health_threshold: float = 0.3

var _target_value: float = 0.0
var _normal_color: Color = Color.WHITE


func _ready() -> void:
	var player: Node = get_node_or_null(player_path)
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("HealthBar : aucun joueur trouvé.")
		return

	var fill := get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		# On duplique le style pour ne pas teinter toutes les barres du projet.
		fill = fill.duplicate()
		add_theme_stylebox_override("fill", fill)
		_normal_color = fill.bg_color

	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)

	# Valeurs de départ, avant même le premier dégât.
	if player.has_method("get_health"):
		_on_health_changed(player.get_health(), player.get_max_health())
	value = _target_value


func _process(delta: float) -> void:
	if fill_speed <= 0.0:
		value = _target_value
		return
	value = lerpf(value, _target_value, 1.0 - exp(-fill_speed * delta))


func _on_health_changed(current: int, maximum: int) -> void:
	max_value = maxf(float(maximum), 1.0)
	_target_value = float(current)

	var fill := get_theme_stylebox("fill") as StyleBoxFlat
	if fill == null:
		return
	var ratio := float(current) / max_value
	fill.bg_color = low_health_color if ratio <= low_health_threshold else _normal_color
