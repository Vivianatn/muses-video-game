extends CharacterBody2D

## Déplacement type metroidvania : accélération/friction, course, saut à hauteur
## variable, coyote time, jump buffer et vitesse de chute limitée.

@export_group("Déplacement")
@export var walk_speed: float = 150.0
@export var run_speed: float = 260.0
@export var acceleration: float = 1800.0
@export var friction: float = 2200.0
@export var air_acceleration: float = 1200.0
@export var air_friction: float = 600.0
## Délai max (s) entre deux appuis sur la même direction pour lancer la course.
@export var double_tap_time: float = 0.25
## Délai (s) sans direction enfoncée avant que la course s'arrête.
## Permet de changer de sens (ou de relâcher très brièvement) sans perdre le sprint.
@export var sprint_release_grace: float = 0.15

@export_group("Saut")
@export var jump_velocity: float = -420.0
## Multiplicateur de gravité quand on relâche le saut tôt (saut court).
@export var jump_cut_multiplier: float = 0.4
## Gravité plus forte en descente pour un saut moins "flottant".
@export var fall_gravity_multiplier: float = 1.6
@export var max_fall_speed: float = 900.0
## Temps (s) pendant lequel on peut encore sauter après avoir quitté le sol.
@export var coyote_time: float = 0.1
## Temps (s) pendant lequel un appui sur saut est mémorisé avant d'atterrir.
@export var jump_buffer_time: float = 0.12
## Nombre de sauts supplémentaires en l'air (1 = double saut).
@export var extra_jumps: int = 1
## Vitesse du saut en l'air (souvent un peu plus faible que le saut au sol).
@export var double_jump_velocity: float = -380.0
## Durée (s) de chute avant de passer du sprite de saut au sprite de chute.
@export var fall_anim_delay: float = 0.5

@export_group("Dash")
@export var dash_speed: float = 600.0
## Durée (s) du dash.
@export var dash_duration: float = 0.15
## Délai (s) avant de pouvoir redasher.
@export var dash_cooldown: float = 0.4
## Si vrai, le dash se recharge uniquement en touchant le sol (classique metroidvania).
@export var dash_resets_on_floor: bool = true

@export_group("Caméra")
## Le zoom de base se règle directement sur le nœud Camera2D dans l'éditeur.
## Facteur de dézoom quand on maintient camera_zoom_out (2.0 = on voit 2x plus loin).
@export var camera_zoom_out_factor: float = 2.0
## Durée (s) de maintien avant que le dézoom commence.
@export var camera_hold_time: float = 0.3
## Vitesse de transition entre les deux zooms.
@export var camera_zoom_speed: float = 6.0
## Réactivité de la caméra quand on la déplace avec les flèches (plus grand = plus vif).
@export var camera_pan_speed: float = 7.0
## Réactivité du retour de la caméra sur le joueur quand on relâche.
@export var camera_pan_return_speed: float = 10.0
## Distance max (px monde) dont la caméra s'éloigne du joueur, par axe.
@export var camera_pan_max_distance: Vector2 = Vector2(300, 200)
## Intensité max de l'assombrissement des bords pendant le dézoom (0 = désactivé).
@export_range(0.0, 1.0) var focus_vignette_strength: float = 0.8

@export_group("Limites")
## Le bord gauche du joueur ne peut pas aller plus à gauche que cette position.
@export var wall_left_x: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var collision: CollisionShape2D = $Collision_simple
@onready var vignette: ColorRect = $FocusLayer/Vignette

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false
var _jumps_left: int = 0
var _fall_timer: float = 0.0

var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: float = 1.0
var _dash_available: bool = true
var _facing: float = 1.0

# Double-tap : direction du dernier appui et temps restant pour le second appui.
var _last_tap_direction: float = 0.0
var _double_tap_timer: float = 0.0
var _is_sprinting: bool = false
var _sprint_release_timer: float = 0.0

var _zoom_hold_timer: float = 0.0
var _base_zoom: float = 1.0
var _zoom_out_active: bool = false
# Direction verrouillée pendant le balayage caméra (ZERO = aucune).
var _pan_lock: Vector2 = Vector2.ZERO
# Distance entre le centre du joueur et le bord de sa collision.
var _half_width: float = 0.0


func _ready() -> void:
	# Zoom de base = celui défini sur le Camera2D dans l'éditeur.
	_base_zoom = camera.zoom.x

	var shape := collision.shape
	if shape is CapsuleShape2D:
		_half_width = shape.radius
	elif shape is RectangleShape2D:
		_half_width = shape.size.x / 2.0
	elif shape is CircleShape2D:
		_half_width = shape.radius
	_half_width -= collision.position.x


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	_update_camera_zoom(delta)

	if _zoom_out_active:
		# Dézoom actif : le joueur est figé. On garde la gravité pour qu'il
		# finisse de retomber au sol, mais on freine et on ignore les entrées.
		_apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		_is_sprinting = false
		_jump_buffer_timer = 0.0
		_dash_timer = 0.0
		move_and_slide()
		_clamp_to_left_wall()
		if on_floor:
			sprite.play("idle")
		_was_on_floor = on_floor
		return

	_update_timers(delta, on_floor)
	_update_sprint(delta)
	_handle_dash(delta, on_floor)

	if _is_dashing():
		# Pendant le dash : vitesse horizontale constante, pas de gravité, pas d'entrées.
		velocity.x = _dash_direction * dash_speed
		velocity.y = 0.0
		move_and_slide()
		_clamp_to_left_wall()
		sprite.play("jump")  # pas encore de sprite de dash : on réutilise la pose de saut
		_was_on_floor = on_floor
		return

	_apply_gravity(delta)
	_handle_jump()
	_handle_horizontal(delta, on_floor)

	move_and_slide()
	_clamp_to_left_wall()

	# Temps passé en descente (remis à zéro au sol ou dès qu'on remonte).
	if not on_floor and velocity.y > 0.0:
		_fall_timer += delta
	else:
		_fall_timer = 0.0

	_update_animation(on_floor)
	_was_on_floor = on_floor


func _update_timers(delta: float, on_floor: bool) -> void:
	if on_floor:
		_coyote_timer = coyote_time
		_jumps_left = extra_jumps
		if dash_resets_on_floor:
			_dash_available = true
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	if not dash_resets_on_floor and _dash_cooldown_timer == 0.0:
		_dash_available = true

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return

	var gravity := get_gravity()
	if velocity.y > 0.0:
		# Descente : gravité renforcée.
		gravity *= fall_gravity_multiplier
	elif not Input.is_action_pressed("jump"):
		# Montée sans maintenir le saut : on coupe l'élan (saut court).
		gravity *= 1.0 / jump_cut_multiplier

	velocity += gravity * delta
	velocity.y = minf(velocity.y, max_fall_speed)


func _handle_jump() -> void:
	if _jump_buffer_timer <= 0.0:
		return

	if _coyote_timer > 0.0:
		# Saut normal depuis le sol (ou juste après l'avoir quitté).
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
	elif _jumps_left > 0:
		# Saut en l'air : on consomme une charge.
		velocity.y = double_jump_velocity
		_jumps_left -= 1
		_jump_buffer_timer = 0.0


func _is_dashing() -> bool:
	return _dash_timer > 0.0


func _handle_dash(delta: float, on_floor: bool) -> void:
	if _is_dashing():
		_dash_timer -= delta
		return

	if not Input.is_action_just_pressed("dash"):
		return
	if not _dash_available or _dash_cooldown_timer > 0.0:
		return

	# Direction du dash : celle enfoncée, sinon celle vers laquelle on regarde.
	var input_dir := Input.get_axis("move_left", "move_right")
	_dash_direction = signf(input_dir) if input_dir != 0.0 else _facing
	sprite.flip_h = _dash_direction < 0.0

	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	# Au sol, le dash reste disponible en continu (cooldown seulement).
	_dash_available = not dash_resets_on_floor or on_floor


func _update_sprint(delta: float) -> void:
	_double_tap_timer = maxf(_double_tap_timer - delta, 0.0)

	var direction := Input.get_axis("move_left", "move_right")

	# La course persiste au changement de sens. Elle ne s'arrête que si aucune
	# direction n'est enfoncée pendant plus de sprint_release_grace secondes.
	if direction == 0.0:
		_sprint_release_timer += delta
		if _sprint_release_timer > sprint_release_grace:
			_is_sprinting = false
	else:
		_sprint_release_timer = 0.0

	# Nouvel appui sur une direction (détecté via just_pressed).
	var tapped := 0.0
	if Input.is_action_just_pressed("move_left"):
		tapped = -1.0
	elif Input.is_action_just_pressed("move_right"):
		tapped = 1.0

	if tapped != 0.0:
		if tapped == _last_tap_direction and _double_tap_timer > 0.0:
			# Second appui dans la fenêtre : on sprinte.
			_is_sprinting = true
			_double_tap_timer = 0.0
		else:
			# Premier appui : on ouvre la fenêtre de double-tap.
			_double_tap_timer = double_tap_time
		_last_tap_direction = tapped


func _handle_horizontal(delta: float, on_floor: bool) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var running := _is_sprinting or Input.is_action_pressed("run")
	var target_speed := run_speed if running else walk_speed
	var accel := acceleration if on_floor else air_acceleration
	var fric := friction if on_floor else air_friction

	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * target_speed, accel * delta)
		_facing = signf(direction)
		sprite.flip_h = direction < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)


func _update_animation(on_floor: bool) -> void:
	if not on_floor:
		if _fall_timer >= fall_anim_delay:
			sprite.play("fall")
		else:
			sprite.play("jump")
		return

	var speed := absf(velocity.x)
	if speed < 10.0:
		sprite.play("idle")
	elif speed > walk_speed + 10.0:
		sprite.play("run")
	else:
		sprite.play("walk")


func _clamp_to_left_wall() -> void:
	var left := global_position.x - _half_width
	if left < wall_left_x:
		global_position.x = wall_left_x + _half_width
		velocity.x = maxf(velocity.x, 0.0)  # stoppe le déplacement vers la gauche


func _update_camera_zoom(delta: float) -> void:
	# Appui long : on ne dézoome qu'après camera_hold_time de maintien.
	if Input.is_action_pressed("camera_zoom_out"):
		_zoom_hold_timer += delta
	else:
		_zoom_hold_timer = 0.0

	_zoom_out_active = _zoom_hold_timer >= camera_hold_time
	var target := _base_zoom / camera_zoom_out_factor if _zoom_out_active else _base_zoom
	var z := lerpf(camera.zoom.x, target, camera_zoom_speed * delta)
	camera.zoom = Vector2(z, z)

	_update_camera_pan(delta)

	# Vignette : suit la progression du zoom (0 = zoom normal, 1 = dézoom complet).
	var zoom_out := _base_zoom / camera_zoom_out_factor
	var progress := inverse_lerp(_base_zoom, zoom_out, camera.zoom.x) if zoom_out != _base_zoom else 0.0
	var mat := vignette.material as ShaderMaterial
	mat.set_shader_parameter("intensity", clampf(progress, 0.0, 1.0) * focus_vignette_strength)


func _update_camera_pan(delta: float) -> void:
	if _zoom_out_active:
		# Direction verrouillée : tant que sa touche reste enfoncée, on ignore les autres.
		if _pan_lock != Vector2.ZERO:
			if not Input.is_action_pressed(_pan_action(_pan_lock)):
				_pan_lock = Vector2.ZERO
		else:
			# Aucun verrou : on n'en prend un que si exactement UNE direction est enfoncée.
			var pressed: Array[Vector2] = []
			for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				if Input.is_action_pressed(_pan_action(dir)):
					pressed.append(dir)
			if pressed.size() == 1:
				_pan_lock = pressed[0]
	else:
		_pan_lock = Vector2.ZERO

	# Cible : le point le plus éloigné dans la direction verrouillée,
	# ou le centre du joueur si aucune flèche n'est enfoncée.
	# On déplace la POSITION locale de la caméra (et non son offset) : c'est elle
	# que Godot contraint avec limit_left/right/top/bottom, donc les limites
	# définies sur le Camera2D de chaque scène sont respectées automatiquement.
	var target := _pan_lock * camera_pan_max_distance
	var speed := camera_pan_speed if _pan_lock != Vector2.ZERO else camera_pan_return_speed
	camera.position = camera.position.lerp(target, 1.0 - exp(-speed * delta))


func _pan_action(dir: Vector2) -> StringName:
	match dir:
		Vector2.LEFT: return &"move_left"
		Vector2.RIGHT: return &"move_right"
		Vector2.UP: return &"look_up"
		_: return &"look_down"
