extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal died

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

@export_group("Mur")
## Active l'agrippage aux murs et le saut mural.
@export var wall_grab_enabled: bool = true
## Vitesse de glissade le long du mur (px/s, plus petit = on s'accroche mieux).
@export var wall_slide_speed: float = 70.0
## Impulsion verticale du saut mural.
@export var wall_jump_velocity: float = -480.0
## Poussée horizontale du saut mural quand on s'éloigne du mur.
@export var wall_jump_push: float = 170.0
## Temps (s) pendant lequel le saut mural reste possible après avoir quitté le mur.
@export var wall_coyote_time: float = 0.2
## Temps (s) où l'on reste collé au mur en dirigeant à l'opposé, avant de lâcher.
## Laisse le temps d'appuyer sur saut sans décrocher par accident.
@export var wall_stick_time: float = 0.15
## Temps (s) de pause de la glissade au moment où l'on attrape le mur.
@export var wall_grab_hang_time: float = 0.12
## Durée (s) pendant laquelle le contrôle horizontal est bloqué après un saut mural.
@export var wall_jump_lock_time: float = 0.1
## S'agripper recharge les sauts en l'air.
@export var wall_grab_resets_jumps: bool = true
## S'agripper recharge le dash.
@export var wall_grab_resets_dash: bool = true

@export_group("Dash")
@export var dash_speed: float = 600.0
## Durée (s) du dash.
@export var dash_duration: float = 0.15
## Délai (s) avant de pouvoir redasher.
@export var dash_cooldown: float = 0.4
## Si vrai, le dash se recharge uniquement en touchant le sol (classique metroidvania).
@export var dash_resets_on_floor: bool = true
## Le dash n'est utilisable qu'en l'air.
@export var dash_only_in_air: bool = true
## Une direction doit être enfoncée pour que le dash parte.
@export var dash_requires_direction: bool = true
## Temps (s) pendant lequel l'appui sur dash reste mémorisé en attendant
## qu'une direction soit indiquée.
@export var dash_buffer_time: float = 0.2

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

@export_group("Vie")
@export var max_health: int = 5
## Durée (s) d'invulnérabilité après un coup reçu.
@export var invincibility_time: float = 1.0
## Recul horizontal subi, à l'opposé de la source du dégât.
@export var hurt_knockback: float = 230.0
## Soulèvement vertical subi.
@export var hurt_lift: float = 170.0
## Durée (s) pendant laquelle on ne contrôle plus le personnage après un coup.
@export var hurt_stun_time: float = 0.25
## Le dash rend invulnérable.
@export var dash_invincible: bool = false
@export var hurt_flash_color: Color = Color(1, 0.35, 0.35)
## Durée (s) d'une alternance du clignotement d'invulnérabilité.
@export var hurt_flash_interval: float = 0.08
## Délai (s) avant de relancer la scène à la mort. 0 = pas de relance.
@export var respawn_delay: float = 1.2

@export_group("Dégâts de chute")
@export var fall_damage_enabled: bool = true
## Hauteur (px) de chute en dessous de laquelle l'atterrissage est sans risque.
@export var fall_damage_min_height: float = 340.0
## Hauteur (px) supplémentaire qui coûte un point de vie de plus.
@export var fall_damage_height_per_point: float = 140.0
## Dégâts maximum encaissables sur une seule chute.
@export var fall_damage_max: int = 3

@export_group("Arme")
## Projectile instancié à chaque tir (Scenes/Weapons/bullet.tscn).
@export var bullet_scene: PackedScene
## Délai (s) entre deux tirs.
@export var fire_cooldown: float = 0.45
## Durée (s) pendant laquelle la pose de tir reste affichée.
## Repère : nombre de frames de l'animation / sa vitesse (3 / 10 = 0.3 s).
@export var fire_anim_time: float = 0.3
## Délai (s) entre l'appui et le départ réel de la balle. Sert à caler le tir sur
## la frame où l'arme fait feu : 0 = départ immédiat, fire_anim_time = à la toute fin.
@export var fire_spawn_delay: float = 0.2
## Si vrai, le tir ne part pas si l'animation est interrompue (dash, dézoom...).
@export var fire_cancel_on_interrupt: bool = true
## Durée (s) d'immobilisation au tir : le personnage se plante et ne peut plus se
## retourner, le temps que le coup parte. À garder >= fire_spawn_delay.
@export var fire_lock_time: float = 0.25
## Ralentissement appliqué une fois l'immobilisation passée (1 = aucun, 0 = immobile).
@export_range(0.0, 1.0) var fire_move_penalty: float = 0.5

@export_group("Sprite")
## Décalage du sprite par animation, pour compenser les tailles de frame
## différentes d'une planche à l'autre et garder le personnage aligné sur sa
## capsule de collision. Y positif descend le sprite.
## Repère : les frames font 96x96 (idle), 88x88 (walk) et 64x64 (les autres),
## d'où un décalage de départ de (96 - taille) / 2 en Y.
@export var idle_sprite_offset: Vector2 = Vector2.ZERO
@export var walk_sprite_offset: Vector2 = Vector2(0, 4)
@export var run_sprite_offset: Vector2 = Vector2(0, 16)
@export var jump_sprite_offset: Vector2 = Vector2(0, 16)
@export var fall_sprite_offset: Vector2 = Vector2(0, 16)
@export var grab_sprite_offset: Vector2 = Vector2(0, 16)
@export var fire_sprite_offset: Vector2 = Vector2(0, 2)

@export_group("Limites")
## Le bord gauche du joueur ne peut pas aller plus à gauche que cette position.
@export var wall_left_x: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var collision: CollisionShape2D = $Collision_simple
@onready var vignette: ColorRect = $FocusLayer/Vignette
@onready var muzzle: Marker2D = $Muzzle

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false
var _jumps_left: int = 0
var _fall_timer: float = 0.0

var _is_wall_grabbing: bool = false
var _wall_normal: Vector2 = Vector2.ZERO
var _wall_jump_lock_timer: float = 0.0
var _wall_coyote_timer: float = 0.0
var _wall_stick_timer: float = 0.0
var _wall_hang_timer: float = 0.0

var _health: int = 0
var _invincible_timer: float = 0.0
var _hurt_timer: float = 0.0
var _hurt_flash_timer: float = 0.0
var _is_dead: bool = false
## Point le plus haut atteint depuis le dernier contact avec le sol.
var _fall_peak_y: float = 0.0

var _fire_cooldown_timer: float = 0.0
var _fire_anim_timer: float = 0.0
# Tir amorcé, en attente de la bonne frame de l'animation.
var _fire_spawn_timer: float = 0.0
var _fire_pending: bool = false
var _fire_pending_facing: float = 1.0
var _fire_lock_timer: float = 0.0

var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: float = 1.0
var _dash_available: bool = true
var _dash_buffer_timer: float = 0.0
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
	_health = max_health
	_fall_peak_y = global_position.y
	# Émis en différé : la barre de vie doit être prête à écouter.
	health_changed.emit.call_deferred(_health, max_health)

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

	_update_damage_timers(delta)
	_update_fall_damage(on_floor)

	if _is_dead:
		_process_dead(delta)
		return

	if _hurt_timer > 0.0:
		# Sonné : on subit le recul, sans contrôle ni action.
		_apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, air_friction * delta)
		move_and_slide()
		_clamp_to_left_wall()
		# Pas d'animation de dégât pour l'instant : on garde la pose en cours.
		_was_on_floor = on_floor
		return

	_update_camera_zoom(delta)

	if _zoom_out_active:
		# Dézoom actif : le joueur est figé. On garde la gravité pour qu'il
		# finisse de retomber au sol, mais on freine et on ignore les entrées.
		_apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		_is_sprinting = false
		_jump_buffer_timer = 0.0
		_dash_timer = 0.0
		_is_wall_grabbing = false
		_cancel_pending_fire()
		move_and_slide()
		_clamp_to_left_wall()
		if on_floor:
			_play("idle")
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
		_play("jump")  # pas encore de sprite de dash : on réutilise la pose de saut
		_was_on_floor = on_floor
		return

	_handle_fire(delta)

	_wall_jump_lock_timer = maxf(_wall_jump_lock_timer - delta, 0.0)
	_update_wall_grab(delta, on_floor)

	# Le saut mural est prioritaire sur le double saut.
	var wall_jumped := _try_wall_jump()

	if _is_wall_grabbing:
		_wall_slide(delta)
	else:
		_apply_gravity(delta)
		if not wall_jumped:
			_handle_jump()

	# Après un saut mural, le contrôle horizontal est brièvement neutralisé
	# pour que la poussée ne soit pas annulée par les entrées.
	if not _is_wall_grabbing and _wall_jump_lock_timer <= 0.0:
		_handle_horizontal(delta, on_floor)

	move_and_slide()
	_clamp_to_left_wall()

	# Temps passé en descente (remis à zéro au sol ou dès qu'on remonte).
	if not on_floor and velocity.y > 0.0 and not _is_wall_grabbing:
		_fall_timer += delta
	else:
		_fall_timer = 0.0

	if _fire_anim_timer > 0.0:
		_play("fire")
	elif _is_wall_grabbing:
		_play("grab")
	else:
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


func _update_wall_grab(delta: float, on_floor: bool) -> void:
	if not wall_grab_enabled or on_floor or _wall_jump_lock_timer > 0.0:
		_is_wall_grabbing = false
		_wall_coyote_timer = 0.0 if on_floor else maxf(_wall_coyote_timer - delta, 0.0)
		return

	# Contact avec un mur vertical : l'agrippage est automatique, sans touche à tenir.
	var normal := get_wall_normal()
	if not is_on_wall_only() or absf(normal.x) < 0.5:
		_is_wall_grabbing = false
		_wall_coyote_timer = maxf(_wall_coyote_timer - delta, 0.0)
		return

	_wall_normal = normal
	_wall_coyote_timer = wall_coyote_time

	if not _is_wall_grabbing:
		# Premier contact : on recharge les ressources aériennes, on stoppe net la
		# chute et on accorde un court temps de suspension pour réagir.
		if wall_grab_resets_jumps:
			_jumps_left = extra_jumps
		if wall_grab_resets_dash:
			_dash_available = true
		velocity.y = minf(velocity.y, 0.0)
		_wall_hang_timer = wall_grab_hang_time
		_wall_stick_timer = wall_stick_time
		_is_wall_grabbing = true

	# Diriger à l'opposé du mur décroche, mais seulement après wall_stick_time :
	# on a ainsi le temps d'enchaîner sur un saut mural sans lâcher par accident.
	if signf(Input.get_axis("move_left", "move_right")) == signf(normal.x):
		_wall_stick_timer -= delta
		if _wall_stick_timer <= 0.0:
			_is_wall_grabbing = false
			return
	else:
		_wall_stick_timer = wall_stick_time

	# Le personnage se tourne face au mur auquel il se tient.
	_facing = -signf(normal.x)
	sprite.flip_h = _facing < 0.0


func _wall_slide(delta: float) -> void:
	# On reste plaqué contre le mur.
	velocity.x = -_wall_normal.x * 10.0

	if _wall_hang_timer > 0.0:
		# Suspension : on ne glisse pas encore.
		_wall_hang_timer -= delta
		velocity.y = 0.0
		return

	velocity.y = move_toward(velocity.y, wall_slide_speed, absf(get_gravity().y) * delta)


func _try_wall_jump() -> bool:
	if _jump_buffer_timer <= 0.0 or _wall_coyote_timer <= 0.0:
		return false

	# Appuyer sur saut suffit : le personnage se retourne aussitôt dos au mur.
	var away := signf(_wall_normal.x)
	velocity = Vector2(away * wall_jump_push, wall_jump_velocity)
	_facing = away
	sprite.flip_h = _facing < 0.0

	_is_wall_grabbing = false
	_wall_coyote_timer = 0.0
	_wall_hang_timer = 0.0
	_jump_buffer_timer = 0.0
	_wall_jump_lock_timer = wall_jump_lock_time
	return true


# --- Vie et dégâts -------------------------------------------------------

func get_health() -> int:
	return _health


func get_max_health() -> int:
	return max_health


## Appelée par tout ce qui blesse le joueur (Hitbox d'ennemi, pièges...).
func take_damage(amount: int, from: Node = null) -> void:
	if _is_dead or _invincible_timer > 0.0:
		return
	if dash_invincible and _is_dashing():
		return

	_health = maxi(_health - amount, 0)
	health_changed.emit(_health, max_health)

	_invincible_timer = invincibility_time
	_hurt_flash_timer = invincibility_time
	_hurt_timer = hurt_stun_time

	# Toute action en cours est interrompue.
	_cancel_pending_fire()
	_is_wall_grabbing = false
	_dash_timer = 0.0
	_is_sprinting = false

	# Recul à l'opposé de la source.
	if from is Node2D:
		var push := signf(global_position.x - (from as Node2D).global_position.x)
		if push == 0.0:
			push = -_facing
		velocity.x = push * hurt_knockback
		if hurt_lift > 0.0:
			velocity.y = -hurt_lift

	if _health <= 0:
		_die()


func heal(amount: int) -> void:
	if _is_dead:
		return
	_health = mini(_health + amount, max_health)
	health_changed.emit(_health, max_health)


func _die() -> void:
	_is_dead = true
	_hurt_timer = 0.0
	_hurt_flash_timer = 0.0
	sprite.modulate = Color.WHITE
	died.emit()

	if respawn_delay > 0.0:
		await get_tree().create_timer(respawn_delay).timeout
		if is_instance_valid(self):
			get_tree().reload_current_scene()


func _process_dead(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	move_and_slide()


## Mesure la hauteur de chute et inflige des dégâts à l'atterrissage.
func _update_fall_damage(on_floor: bool) -> void:
	if not fall_damage_enabled or _is_dead:
		return

	# Atterrissage : on mesure avant de réinitialiser le repère.
	if on_floor and not _was_on_floor:
		var height := global_position.y - _fall_peak_y
		if height > fall_damage_min_height:
			var extra := (height - fall_damage_min_height) / maxf(fall_damage_height_per_point, 1.0)
			take_damage(mini(1 + int(extra), fall_damage_max))

	# S'accrocher à un mur ou dasher coupe la chute : le compteur repart de zéro.
	if on_floor or _is_wall_grabbing or _is_dashing():
		_fall_peak_y = global_position.y
	else:
		_fall_peak_y = minf(_fall_peak_y, global_position.y)


func _update_damage_timers(delta: float) -> void:
	_invincible_timer = maxf(_invincible_timer - delta, 0.0)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)

	if _hurt_flash_timer <= 0.0:
		return

	_hurt_flash_timer -= delta
	if _hurt_flash_timer <= 0.0:
		sprite.modulate = Color.WHITE
		return

	var on := int(_hurt_flash_timer / maxf(hurt_flash_interval, 0.01)) % 2 == 0
	sprite.modulate = hurt_flash_color if on else Color.WHITE


func _handle_fire(delta: float) -> void:
	_fire_cooldown_timer = maxf(_fire_cooldown_timer - delta, 0.0)
	_fire_anim_timer = maxf(_fire_anim_timer - delta, 0.0)
	_fire_lock_timer = maxf(_fire_lock_timer - delta, 0.0)

	# La balle ne part qu'une fois l'animation arrivée à la frame de tir.
	if _fire_pending:
		_fire_spawn_timer -= delta
		if _fire_spawn_timer <= 0.0:
			_fire_pending = false
			_spawn_bullet(_fire_pending_facing)

	if not Input.is_action_just_pressed("fire"):
		return
	if _fire_cooldown_timer > 0.0 or _fire_pending or bullet_scene == null:
		return

	_fire_cooldown_timer = fire_cooldown
	_fire_anim_timer = fire_anim_time
	# On mémorise l'orientation du tir : se retourner pendant l'animation ne
	# change pas la trajectoire de la balle déjà amorcée.
	_fire_pending_facing = _facing
	_fire_spawn_timer = minf(fire_spawn_delay, fire_anim_time)
	_fire_lock_timer = maxf(fire_lock_time, fire_spawn_delay)
	_fire_pending = true


func _cancel_pending_fire() -> void:
	if fire_cancel_on_interrupt:
		_fire_pending = false
	_fire_anim_timer = 0.0
	_fire_lock_timer = 0.0


func _spawn_bullet(facing: float) -> void:
	var bullet := bullet_scene.instantiate() as Bullet
	if bullet == null:
		push_warning("bullet_scene ne contient pas un noeud Bullet.")
		return
	bullet.direction = Vector2(facing, 0.0)
	bullet.shooter = self

	# Le projectile vit dans le niveau, pas dans le joueur : il ne doit pas
	# suivre ses déplacements après le tir.
	var container := get_parent()
	container.add_child(bullet)

	# Le canon suit l'orientation du personnage.
	bullet.global_position = global_position + Vector2(muzzle.position.x * facing, muzzle.position.y)


func _is_dashing() -> bool:
	return _dash_timer > 0.0


func _handle_dash(delta: float, on_floor: bool) -> void:
	if _is_dashing():
		_dash_timer -= delta
		return

	# L'appui reste mémorisé un instant : on peut presser dash puis la direction.
	_dash_buffer_timer = maxf(_dash_buffer_timer - delta, 0.0)
	if Input.is_action_just_pressed("dash"):
		_dash_buffer_timer = dash_buffer_time

	if _dash_buffer_timer <= 0.0:
		return
	if dash_only_in_air and on_floor:
		return
	if not _dash_available or _dash_cooldown_timer > 0.0:
		return

	# Direction du dash : celle enfoncée, sinon celle vers laquelle on regarde.
	var input_dir := Input.get_axis("move_left", "move_right")
	if dash_requires_direction and input_dir == 0.0:
		# Aucune direction indiquée : on attend, l'appui reste en mémoire.
		return

	_dash_direction = signf(input_dir) if input_dir != 0.0 else _facing
	sprite.flip_h = _dash_direction < 0.0
	_dash_buffer_timer = 0.0

	_cancel_pending_fire()
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

	if _fire_lock_timer > 0.0:
		# Le personnage se plante pour tirer : ni déplacement, ni demi-tour,
		# pour que le sprite reste cohérent avec la trajectoire de la balle.
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)
		return

	if _fire_anim_timer > 0.0:
		# Une fois le coup parti, on repart mais plus lentement.
		target_speed *= fire_move_penalty

	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * target_speed, accel * delta)
		_facing = signf(direction)
		sprite.flip_h = direction < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)


func _play(anim: StringName) -> void:
	if sprite.animation != anim:
		sprite.play(anim)
	# Chaque planche n'a pas la même taille de frame : on recale le sprite pour
	# qu'il reste aligné sur la capsule de collision d'une animation à l'autre.
	var off := Vector2.ZERO
	match anim:
		&"idle": off = idle_sprite_offset
		&"walk": off = walk_sprite_offset
		&"run": off = run_sprite_offset
		&"jump": off = jump_sprite_offset
		&"fall": off = fall_sprite_offset
		&"grab": off = grab_sprite_offset
		&"fire": off = fire_sprite_offset
	# offset.x n'est pas inversé par flip_h : on le suit à la main.
	sprite.offset = Vector2(off.x * _facing, off.y)


func _update_animation(on_floor: bool) -> void:
	if not on_floor:
		if _fall_timer >= fall_anim_delay:
			_play("fall")
		else:
			_play("jump")
		return

	var speed := absf(velocity.x)
	if speed < 10.0:
		_play("idle")
	elif speed > walk_speed + 10.0:
		_play("run")
	else:
		_play("walk")


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
