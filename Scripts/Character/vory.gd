@tool
extends CharacterBody2D
class_name Vory

## Vory : personnage non joueur. Il est soumis à la gravité et erre au hasard
## (alternance marche / pause), en faisant demi-tour devant un mur ou au bord
## d'un vide pour ne jamais tomber d'une plateforme.
##
## Le script tourne aussi dans l'éditeur (@tool), uniquement pour afficher en
## direct le décalage du sprite réglé dans le groupe « Sprite ». Tout le reste
## (déplacement, errance) ne s'exécute qu'en jeu.

enum State { IDLE, WALK }

@export_group("Déplacement")
@export var walk_speed: float = 40.0
@export var acceleration: float = 400.0
@export var friction: float = 600.0
@export var max_fall_speed: float = 900.0

@export_group("Errance")
## Durée (s) d'une pause : tirée au hasard entre X et Y.
@export var idle_time: Vector2 = Vector2(1.0, 3.0)
## Durée (s) d'une marche : tirée au hasard entre X et Y.
@export var walk_time: Vector2 = Vector2(1.5, 4.0)
## Probabilité de repartir dans l'autre sens à chaque reprise de la marche.
## 0 = il garde toujours son cap, 0.5 = une fois sur deux, 1 = à chaque fois.
@export_range(0.0, 1.0) var turn_chance_on_walk: float = 0.5
## Distance (px) max autorisée de part et d'autre du point de départ.
## Au-delà, il fait demi-tour. 0 = pas de limite.
@export var patrol_radius: float = 0.0
## Délai (s) minimum entre deux demi-tours, pour éviter de vibrer sur place.
@export var turn_cooldown: float = 0.3

@export_group("Détection du terrain")
## Faire demi-tour au bord d'un vide plutôt que de tomber.
@export var turn_on_ledge: bool = true
## Faire demi-tour devant un mur.
@export var turn_on_wall: bool = true
## Distance (px) devant les pieds où l'on sonde le sol.
@export var ground_probe_ahead: float = 6.0
## Profondeur (px) de la sonde sous les pieds : au-delà, c'est un vide.
@export var ground_probe_depth: float = 18.0
## Distance (px) devant le corps où l'on cherche un mur.
@export var wall_probe_ahead: float = 6.0

@export_group("Animations")
## Noms des animations dans le SpriteFrames. Laisse vide pour en ignorer une.
@export var idle_anim: StringName = &"idle"
@export var walk_anim: StringName = &"walk"

@export_group("Sprite")
## Décalage et taille du sprite par animation, pour caler le dessin sur la
## forme de collision quand les planches n'ont pas la même taille ou le même
## cadrage. Voir SpriteFit.
##  - Offset : X positif avance le sprite dans le sens où regarde le
##    personnage, Y positif le descend.
##  - Scale : 1 = taille d'origine, 1.5 = moitié plus grand. Les pieds restent
##    en place ; seule l'image change de taille, pas la collision.
## Se voit en direct dans l'éditeur : choisis l'animation dans
## l'AnimatedSprite2D, puis règle-la ici.
@export var idle_sprite_offset: Vector2 = Vector2.ZERO:
	set(value):
		idle_sprite_offset = value
		_apply_sprite_offset()
@export var walk_sprite_offset: Vector2 = Vector2.ZERO:
	set(value):
		walk_sprite_offset = value
		_apply_sprite_offset()
@export_range(0.1, 4.0, 0.01) var idle_sprite_scale: float = 1.0:
	set(value):
		idle_sprite_scale = value
		_apply_sprite_offset()
@export_range(0.1, 4.0, 0.01) var walk_sprite_scale: float = 1.0:
	set(value):
		walk_sprite_scale = value
		_apply_sprite_offset()

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var collision: CollisionShape2D = $Body
@onready var ground_check: RayCast2D = $GroundCheck
@onready var wall_check: RayCast2D = $WallCheck
@onready var state_timer: Timer = $StateTimer

var _state: State = State.WALK
var _direction: float = 1.0
var _turn_timer: float = 0.0
var _spawn_x: float = 0.0
## Vrai pendant un dialogue : il reste planté et ne choisit plus sa direction.
var _frozen: bool = false

# Valeurs de référence des rayons, pour les retourner avec Vory.
var _ground_check_offset: float = 0.0
var _wall_check_length: float = 0.0


func _ready() -> void:
	_apply_sprite_offset()
	if Engine.is_editor_hint():
		return
	# _process ne sert qu'à l'aperçu dans l'éditeur.
	set_process(false)

	_spawn_x = global_position.x
	_place_probes()
	state_timer.timeout.connect(_on_state_timer_timeout)

	# Départ dans une direction aléatoire : deux Vory posés dans un niveau ne
	# se déplacent pas en miroir.
	_direction = 1.0 if randf() < 0.5 else -1.0
	_apply_direction()
	_enter_state(State.WALK)


func _process(_delta: float) -> void:
	# Dans l'éditeur, on suit l'animation choisie dans l'AnimatedSprite2D pour
	# montrer le bon décalage quand on passe de idle à walk.
	if Engine.is_editor_hint():
		_apply_sprite_offset()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
		velocity.y = minf(velocity.y, max_fall_speed)

	if _frozen:
		# Figé pour un dialogue : il finit de retomber au sol, freine, et garde
		# l'orientation qu'on lui a donnée.
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	else:
		match _state:
			State.IDLE:
				velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			State.WALK:
				_process_walk(delta)

	move_and_slide()
	_update_animation()


func _process_walk(delta: float) -> void:
	_turn_timer = maxf(_turn_timer - delta, 0.0)
	if _turn_timer <= 0.0 and _should_turn_around():
		_direction = -_direction
		_apply_direction()
		_turn_timer = turn_cooldown

	velocity.x = move_toward(velocity.x, _direction * walk_speed, acceleration * delta)


func _enter_state(next: State) -> void:
	_state = next
	if next == State.WALK:
		# Repartir tantôt à gauche, tantôt à droite : sans ça il traverserait
		# toute la plateforme dans le même sens jusqu'au premier obstacle.
		if randf() < turn_chance_on_walk:
			_direction = -_direction
			_apply_direction()
	_start_state_timer()


## (Re)lance le minuteur avec une durée tirée au hasard pour l'état courant.
func _start_state_timer() -> void:
	if _frozen:
		return
	if _state == State.IDLE:
		state_timer.start(randf_range(idle_time.x, idle_time.y))
	else:
		state_timer.start(randf_range(walk_time.x, walk_time.y))


func _on_state_timer_timeout() -> void:
	_enter_state(State.IDLE if _state == State.WALK else State.WALK)


# --- Dialogue -------------------------------------------------------------

## Immobilise Vory (ou lui rend sa liberté). Appelée par DialogueTrigger le
## temps d'une conversation.
func set_frozen(frozen: bool) -> void:
	if _frozen == frozen:
		return
	_frozen = frozen

	if frozen:
		state_timer.stop()
		return

	# En repartant, on lui laisse le délai habituel avant de pouvoir faire
	# demi-tour : sinon il pivote dans la même frame que la fin du dialogue.
	_turn_timer = turn_cooldown
	_start_state_timer()


## Le tourne vers un point du monde (typiquement la position du joueur).
func face_toward(point: Vector2) -> void:
	var side := signf(point.x - global_position.x)
	if side == 0.0:
		return
	_direction = side
	_apply_direction()


# --- Détection du terrain -------------------------------------------------

## Positionne les rayons d'après la forme de collision réelle, pour que la
## détection reste juste quel que soit le gabarit donné au personnage.
func _place_probes() -> void:
	var half_width := 10.0
	var half_height := 20.0

	var shape := collision.shape
	if shape is CapsuleShape2D:
		half_width = (shape as CapsuleShape2D).radius
		half_height = (shape as CapsuleShape2D).height / 2.0
	elif shape is RectangleShape2D:
		half_width = (shape as RectangleShape2D).size.x / 2.0
		half_height = (shape as RectangleShape2D).size.y / 2.0
	elif shape is CircleShape2D:
		half_width = (shape as CircleShape2D).radius
		half_height = half_width

	var feet_y := collision.position.y + half_height

	# La sonde de sol part juste au-dessus des pieds, devant lui : si elle ne
	# touche rien, c'est qu'il n'y a plus de plancher là où il va poser le pied.
	_ground_check_offset = half_width + ground_probe_ahead
	ground_check.position = Vector2(_ground_check_offset, feet_y - 2.0)
	ground_check.target_position = Vector2(0.0, ground_probe_depth)

	# La sonde de mur part du centre du corps.
	_wall_check_length = half_width + wall_probe_ahead
	wall_check.position = Vector2(collision.position.x, collision.position.y)
	wall_check.target_position = Vector2(_wall_check_length, 0.0)

	_apply_direction()


func _apply_direction() -> void:
	sprite.flip_h = _direction < 0.0
	# Le décalage en X suit le sens du regard : flip_h ne le retourne pas.
	_apply_sprite_offset()
	ground_check.position.x = collision.position.x + _ground_check_offset * _direction
	wall_check.target_position.x = _wall_check_length * _direction

	# Les rayons viennent de bouger : on les réévalue tout de suite, sinon ils
	# renvoient encore le résultat de leur ancienne position pendant une frame.
	if is_inside_tree():
		ground_check.force_raycast_update()
		wall_check.force_raycast_update()


func _is_ledge_ahead() -> bool:
	# Le rayon est décalé devant lui : s'il ne touche rien, c'est le vide.
	return is_on_floor() and not ground_check.is_colliding()


func _is_wall_ahead() -> bool:
	return wall_check.is_colliding() or is_on_wall()


func _should_turn_around() -> bool:
	if turn_on_ledge and _is_ledge_ahead():
		return true
	if turn_on_wall and _is_wall_ahead():
		return true
	# Trop loin de son point de départ, et il continue de s'en éloigner.
	if patrol_radius > 0.0:
		var offset := global_position.x - _spawn_x
		if absf(offset) > patrol_radius and signf(offset) == _direction:
			return true
	return false


# --- Animation ------------------------------------------------------------

func _update_animation() -> void:
	_play(walk_anim if absf(velocity.x) > 5.0 else idle_anim)


func _play(anim: StringName) -> void:
	if sprite.sprite_frames == null or anim == &"":
		return
	if not sprite.sprite_frames.has_animation(anim):
		return
	if sprite.animation != anim:
		sprite.play(anim)
		_apply_sprite_offset()


## Recale le sprite selon l'animation en cours (voir le groupe « Sprite »).
func _apply_sprite_offset() -> void:
	# Le setter d'un réglage peut être appelé au chargement, avant _ready.
	var node := get_node_or_null(^"Sprite") as AnimatedSprite2D
	if node == null:
		return

	var off := Vector2.ZERO
	var size := 1.0
	if node.animation == walk_anim:
		off = walk_sprite_offset
		size = walk_sprite_scale
	elif node.animation == idle_anim:
		off = idle_sprite_offset
		size = idle_sprite_scale

	SpriteFit.apply(node, off, size, -1.0 if node.flip_h else 1.0)
