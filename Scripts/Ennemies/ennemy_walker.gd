extends CharacterBody2D
class_name EnnemyWalker

## Ennemi de base : soumis à la gravité, il erre au hasard (marche / pause) en
## faisant demi-tour devant un mur ou un vide, et poursuit le joueur dès qu'il
## entre dans sa zone de détection.

signal hurt(remaining: int, from: Node)
signal died(from: Node)

enum State { IDLE, WALK, CHASE, ATTACK, DEAD }

@export_group("Déplacement")
@export var walk_speed: float = 45.0
@export var chase_speed: float = 170.0
@export var acceleration: float = 500.0
## Accélération utilisée en poursuite : il s'élance plus franchement.
@export var chase_acceleration: float = 900.0
@export var friction: float = 700.0
@export var max_fall_speed: float = 900.0

@export_group("Errance")
## Durée (s) d'une pause : tirée au hasard entre X et Y.
@export var idle_time: Vector2 = Vector2(0.8, 2.2)
## Durée (s) d'une marche : tirée au hasard entre X et Y.
@export var walk_time: Vector2 = Vector2(1.5, 4.0)
## Faire demi-tour au bord d'un vide plutôt que de tomber.
@export var turn_on_ledge: bool = true
## Faire demi-tour devant un mur.
@export var turn_on_wall: bool = true
## Délai (s) minimum entre deux demi-tours, pour éviter de vibrer sur place.
@export var turn_cooldown: float = 0.3
## Probabilité de repartir dans l'autre sens à chaque reprise de la marche.
## 0 = il garde toujours son cap, 0.5 = une fois sur deux, 1 = à chaque fois.
@export_range(0.0, 1.0) var turn_chance_on_walk: float = 0.5
## Distance (px) max autorisée de part et d'autre du point de départ.
## Au-delà, il fait demi-tour. 0 = pas de limite.
@export var patrol_radius: float = 0.0

@export_group("Détection du terrain")
## Distance (px) devant les pieds où l'on sonde le sol.
@export var ground_probe_ahead: float = 6.0
## Profondeur (px) de la sonde sous les pieds.
@export var ground_probe_depth: float = 18.0
## Distance (px) devant le corps où l'on cherche un mur.
@export var wall_probe_ahead: float = 6.0

@export_group("Vision")
## Ouverture totale du champ de vision, en degrés, centrée sur l'avant.
## 360 = détection tout autour (comportement d'avant).
@export_range(10.0, 360.0) var vision_angle: float = 110.0
## Un obstacle entre les deux coupe la détection.
@export var require_line_of_sight: bool = true
## Couches considérées comme obstacles à la vue (1 = le monde).
@export_flags_2d_physics var sight_obstacle_mask: int = 1
## Distance (px) en deçà de laquelle il repère le joueur même dans son dos.
@export var close_range_alert: float = 40.0
## Hauteur des yeux, en px depuis le centre du corps (négatif = vers le haut).
## 0 = calculée automatiquement d'après la forme de collision.
@export var eye_height: float = 0.0

@export_group("Poursuite")
## L'ennemi s'arrête aussi au bord d'un vide quand il poursuit le joueur.
@export var chase_respects_ledges: bool = true
## Délai (s) avant d'abandonner la poursuite une fois le joueur hors de portée.
@export var lose_target_delay: float = 1.5
## Distance (px) à laquelle il cesse d'avancer vers le joueur. À garder proche
## de attack_range : il se place à portée de frappe au lieu de venir se coller.
@export var stop_distance: float = 82.0
## Sous cette fraction de stop_distance, il recule pour se replacer.
## 0 = il ne recule jamais.
@export_range(0.0, 1.0) var back_off_ratio: float = 0.6

@export_group("Attaque")
@export var attack_enabled: bool = true
## Distance (px) a laquelle il declenche son attaque.
@export var attack_range: float = 90.0
@export var attack_damage: int = 1
## Le coup ne devient dangereux qu'une fois l'animation d'attaque terminee.
## La duree est lue directement dans le SpriteFrames, donc elle suit
## automatiquement le nombre de frames et la vitesse de l'animation.
@export var attack_hit_after_anim: bool = true
## Temps (s) de preparation, utilise seulement si attack_hit_after_anim est
## desactive (ou si l'animation d'attaque est introuvable).
@export var attack_windup: float = 0.3
## Temps (s) pendant lequel la zone de frappe est active.
@export var attack_active_time: float = 0.15
## Temps (s) de recuperation apres le coup, pendant lequel il reste vulnerable.
@export var attack_recovery: float = 0.35
## Delai (s) entre deux attaques.
@export var attack_cooldown: float = 1.4
## Taille de la zone de frappe.
@export var attack_hitbox_size: Vector2 = Vector2(62, 66)
## Position de la zone de frappe devant lui (X positif = vers l'avant).
@export var attack_hitbox_offset: Vector2 = Vector2(38, 0)

@export_group("Combat")
@export var max_health: int = 3
## Blesse le joueur au simple contact, en plus de son attaque.
@export var contact_damage_enabled: bool = false
## Dégâts infligés au joueur au contact (via la Hitbox).
@export var contact_damage: int = 1
## Recul horizontal appliqué quand il encaisse un tir.
@export var knockback_force: float = 220.0
## Petit soulèvement vertical au moment du recul.
@export var knockback_lift: float = 90.0
## Durée (s) pendant laquelle il subit le recul sans pouvoir se déplacer.
@export var hurt_stun_time: float = 0.25

@export_group("Retour visuel")
## Couleur du clignotement quand il est touché.
@export var hurt_flash_color: Color = Color(1, 0.25, 0.25)
## Durée (s) totale du clignotement.
@export var hurt_flash_time: float = 0.45
## Durée (s) d'une alternance : plus c'est petit, plus ça clignote vite.
@export var hurt_flash_interval: float = 0.06

@export_group("Animations")
## Noms des animations dans le SpriteFrames. Laisse vide pour en ignorer une.
@export var idle_anim: StringName = &"idle"
@export var walk_anim: StringName = &"walk"
@export var chase_anim: StringName = &"run"
@export var death_anim: StringName = &"die"
@export var attack_anim: StringName = &"attack"

@export_group("Sprite")
## Décalage et taille du sprite par animation, pour compenser les tailles de
## frame différentes et garder le personnage aligné sur sa collision.
## Offset : Y positif descend le sprite ; X positif le décale vers l'avant.
## Scale : 1 = taille d'origine. Les pieds restent en place, et seule l'image
## change de taille : pas la collision ni les zones d'attaque. Voir SpriteFit.
@export var idle_sprite_offset: Vector2 = Vector2.ZERO
@export var walk_sprite_offset: Vector2 = Vector2.ZERO
@export var chase_sprite_offset: Vector2 = Vector2.ZERO
@export var death_sprite_offset: Vector2 = Vector2.ZERO
@export var attack_sprite_offset: Vector2 = Vector2.ZERO
@export_range(0.1, 4.0, 0.01) var idle_sprite_scale: float = 1.0
@export_range(0.1, 4.0, 0.01) var walk_sprite_scale: float = 1.0
@export_range(0.1, 4.0, 0.01) var chase_sprite_scale: float = 1.0
@export_range(0.1, 4.0, 0.01) var death_sprite_scale: float = 1.0
@export_range(0.1, 4.0, 0.01) var attack_sprite_scale: float = 1.0

@export_group("Mort")
## Laisse le corps retomber au sol avant de figer la dépouille.
@export var death_settle_on_ground: bool = true
## Durée (s) avant que la dépouille disparaisse. 0 = elle reste indéfiniment.
@export var corpse_lifetime: float = 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var collision: CollisionShape2D = $Collision
@onready var detection_zone: Area2D = $DetectionZone
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var ground_check: RayCast2D = $GroundCheck
@onready var wall_check: RayCast2D = $WallCheck
@onready var state_timer: Timer = $StateTimer

## Rayon de ligne de vue : n'importe quel RayCast2D enfant autre que les deux
## sondes de terrain. S'il n'y en a pas, le script en crée un.
@onready var sight_check: RayCast2D = _resolve_sight_check()
## Zone de frappe, creee automatiquement si elle n'est pas dans la scene.
@onready var attack_hitbox: Area2D = _resolve_attack_hitbox()

var _state: State = State.WALK
var _direction: float = 1.0
var _health: int = 0
var _target: Node2D = null
var _lose_timer: float = 0.0
var _turn_timer: float = 0.0
var _spawn_x: float = 0.0
var _hurt_timer: float = 0.0
var _flash_timer: float = 0.0
var _corpse_cleared: bool = false
## Joueur présent dans la zone de détection, vu ou non.
var _player_in_range: Node2D = null

var _attack_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _attack_phase: int = 0
var _attack_hit: Array[Node] = []

# Valeurs de référence des rayons, pour les retourner avec l'ennemi.
var _ground_check_offset: float = 0.0
var _wall_check_length: float = 0.0


func _ready() -> void:
	_health = max_health
	_spawn_x = global_position.x
	_place_probes()

	# Déjà vaincu dans la partie chargée : load_state() le retire du niveau.
	SaveGame.register(self)
	if is_queued_for_deletion():
		return

	detection_zone.body_entered.connect(_on_detection_body_entered)
	detection_zone.body_exited.connect(_on_detection_body_exited)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	state_timer.timeout.connect(_on_state_timer_timeout)

	# Départ dans une direction aléatoire, pour que deux ennemis identiques
	# posés dans un niveau ne se déplacent pas en miroir.
	_direction = 1.0 if randf() < 0.5 else -1.0
	_apply_direction()
	_enter_state(State.WALK)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		velocity.y = minf(velocity.y, max_fall_speed)

	if _state == State.DEAD:
		_process_death(delta)
		return

	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)
	_update_perception()
	_update_hurt_flash(delta)

	if _hurt_timer > 0.0:
		# Sonné : on laisse le recul l'emporter, l'IA reprend la main après.
		_hurt_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, friction * 0.4 * delta)
		move_and_slide()
		return

	match _state:
		State.IDLE:
			_process_idle(delta)
		State.WALK:
			_process_walk(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)

	move_and_slide()
	_update_animation()


# --- États ---------------------------------------------------------------

func _process_idle(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * _delta)


func _process_walk(delta: float) -> void:
	_turn_timer = maxf(_turn_timer - delta, 0.0)
	if _turn_timer <= 0.0 and _should_turn_around():
		_direction = -_direction
		_apply_direction()
		_turn_timer = turn_cooldown

	velocity.x = move_toward(velocity.x, _direction * walk_speed, acceleration * delta)


func _process_chase(delta: float) -> void:
	# Cible perdue (morte, libérée) : retour à l'errance.
	if not is_instance_valid(_target):
		_target = null
		_enter_state(State.WALK)
		return

	# Le joueur est sorti de la zone : on le poursuit encore un instant.
	if _lose_timer > 0.0:
		_lose_timer -= delta
		if _lose_timer <= 0.0:
			_target = null
			_enter_state(State.WALK)
			return

	var to_target := _target.global_position.x - global_position.x
	_direction = signf(to_target) if to_target != 0.0 else _direction
	_apply_direction()

	# A portee et pret : on frappe.
	if attack_enabled and _attack_cooldown_timer <= 0.0 and absf(to_target) <= attack_range:
		_enter_state(State.ATTACK)
		return

	var blocked := chase_respects_ledges and _is_ledge_ahead()
	var distance := absf(to_target)

	# Collé au joueur : il prend du recul pour retrouver sa distance de frappe.
	if distance < stop_distance * back_off_ratio and not blocked:
		velocity.x = move_toward(velocity.x, -_direction * walk_speed, acceleration * delta)
		return

	# À bonne distance, ou au bord d'un vide qu'on refuse de franchir : il attend.
	if distance <= stop_distance or blocked or _is_wall_ahead():
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		return

	velocity.x = move_toward(velocity.x, _direction * chase_speed, chase_acceleration * delta)


func _process_attack(delta: float) -> void:
	# Il reste plante pendant toute l'attaque.
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# Pendant la fenetre active, on blesse tout joueur present dans la zone.
	if _attack_phase == 1:
		for body in attack_hitbox.get_overlapping_bodies():
			_try_hit(body)

	_attack_timer -= delta
	if _attack_timer > 0.0:
		return

	match _attack_phase:
		0:
			# Fin de la preparation : le coup part.
			_attack_phase = 1
			_attack_timer = attack_active_time
			_set_attack_hitbox_active(true)
		1:
			# Fin de la fenetre active : recuperation.
			_attack_phase = 2
			_attack_timer = attack_recovery
			_set_attack_hitbox_active(false)
		_:
			_attack_cooldown_timer = attack_cooldown
			_set_attack_hitbox_active(false)
			_enter_state(State.CHASE if _target != null else State.WALK)


## Duree de la phase de preparation : celle de l'animation si on attend sa fin.
func _attack_windup_duration() -> float:
	if not attack_hit_after_anim:
		return attack_windup
	var duration := _anim_duration(attack_anim)
	return duration if duration > 0.0 else attack_windup


## Duree totale d'une animation du SpriteFrames, en secondes.
func _anim_duration(anim: StringName) -> float:
	var frames := sprite.sprite_frames
	if frames == null or anim == &"" or not frames.has_animation(anim):
		return 0.0

	var speed := frames.get_animation_speed(anim)
	if speed <= 0.0:
		return 0.0

	var total := 0.0
	for i in frames.get_frame_count(anim):
		total += frames.get_frame_duration(anim, i)
	return total / speed


func _try_hit(body: Node) -> void:
	if body in _attack_hit or not body.is_in_group("player"):
		return
	_attack_hit.append(body)
	if body.has_method("take_damage"):
		body.take_damage(attack_damage, self)


func _set_attack_hitbox_active(active: bool) -> void:
	attack_hitbox.set_deferred("monitoring", active)


## Recupere la zone de frappe de la scene, ou en fabrique une.
func _resolve_attack_hitbox() -> Area2D:
	var existing := get_node_or_null("AttackHitbox")
	if existing is Area2D:
		return existing as Area2D

	var area := Area2D.new()
	area.name = "AttackHitbox"
	var shape_node := CollisionShape2D.new()
	shape_node.shape = RectangleShape2D.new()
	area.add_child(shape_node)
	add_child(area)
	return area


func _enter_state(next: State) -> void:
	_state = next
	match next:
		State.IDLE:
			state_timer.start(randf_range(idle_time.x, idle_time.y))
		State.WALK:
			# Repartir tantôt à gauche, tantôt à droite : sans ça il traverserait
			# tout le niveau dans le même sens jusqu'au premier obstacle.
			if randf() < turn_chance_on_walk:
				_direction = -_direction
				_apply_direction()
			state_timer.start(randf_range(walk_time.x, walk_time.y))
		State.CHASE:
			state_timer.stop()
		State.ATTACK:
			state_timer.stop()
			_attack_phase = 0
			_attack_timer = _attack_windup_duration()
			_attack_hit.clear()
			_set_attack_hitbox_active(false)
			_play(attack_anim)


func _on_state_timer_timeout() -> void:
	# La poursuite n'est pas rythmée par le minuteur.
	if _state == State.CHASE:
		return
	_enter_state(State.IDLE if _state == State.WALK else State.WALK)


# --- Perception ----------------------------------------------------------

## Positionne les rayons d'après la forme de collision réelle du corps, pour que
## la détection reste juste quel que soit le gabarit donné à l'ennemi.
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

	# La sonde de sol part juste au-dessus des pieds, devant l'ennemi.
	_ground_check_offset = half_width + ground_probe_ahead
	ground_check.position = Vector2(_ground_check_offset, feet_y - 2.0)
	ground_check.target_position = Vector2(0.0, ground_probe_depth)

	# La sonde de mur part du centre du corps.
	_wall_check_length = half_width + wall_probe_ahead
	wall_check.position = Vector2(0.0, collision.position.y)
	wall_check.target_position = Vector2(_wall_check_length, 0.0)

	# Zone de frappe : taille et position devant lui.
	if attack_hitbox != null:
		attack_hitbox.collision_layer = 8
		attack_hitbox.collision_mask = 2
		attack_hitbox.monitoring = false
		var attack_shape := attack_hitbox.get_child(0) as CollisionShape2D
		if attack_shape != null:
			if attack_shape.shape is RectangleShape2D:
				(attack_shape.shape as RectangleShape2D).size = attack_hitbox_size
			attack_shape.position = attack_hitbox_offset

	# La Hitbox de contact n'est active que si on le demande.
	hitbox.monitoring = contact_damage_enabled

	# Le rayon de vue part des yeux, dans le quart supérieur du corps.
	if sight_check != null:
		var eye_y := eye_height if eye_height != 0.0 else -half_height * 0.7
		sight_check.position = Vector2(0.0, collision.position.y + eye_y)
		sight_check.collision_mask = sight_obstacle_mask
		sight_check.exclude_parent = true

	_apply_direction()


func _apply_direction() -> void:
	sprite.flip_h = _direction < 0.0
	ground_check.position.x = _ground_check_offset * _direction
	wall_check.target_position.x = _wall_check_length * _direction

	if attack_hitbox != null:
		var attack_shape := attack_hitbox.get_child(0) as CollisionShape2D
		if attack_shape != null:
			attack_shape.position.x = attack_hitbox_offset.x * _direction

	# Les rayons viennent de bouger : on les réévalue tout de suite, sinon ils
	# renvoient encore le résultat de leur ancienne position pendant une frame.
	if is_inside_tree():
		ground_check.force_raycast_update()
		wall_check.force_raycast_update()


func _is_ledge_ahead() -> bool:
	# Le rayon est décalé devant l'ennemi : s'il ne touche rien, c'est le vide.
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


func _on_detection_body_entered(body: Node2D) -> void:
	# La zone ne donne que la portée : c'est _update_perception() qui décide
	# si le joueur est réellement dans le champ de vision.
	if body.is_in_group("player"):
		_player_in_range = body


func _on_detection_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null


## Évalue à chaque frame si le joueur est visible, et déclenche ou relâche la
## poursuite en conséquence.
func _update_perception() -> void:
	if _state == State.DEAD:
		return

	var seen := _player_in_range != null and is_instance_valid(_player_in_range) and _can_see(_player_in_range)

	if seen:
		_target = _player_in_range
		_lose_timer = 0.0
		if _state != State.CHASE and _state != State.ATTACK:
			_enter_state(State.CHASE)
		return

	# Plus en vue : on amorce le délai d'abandon, sans couper net la poursuite.
	if _target != null and _lose_timer <= 0.0:
		_lose_timer = lose_target_delay


func _can_see(target: Node2D) -> bool:
	var to_target := target.global_position - global_position

	# Trop près : il le remarque même dans son dos.
	if to_target.length() <= close_range_alert:
		return _has_line_of_sight(target)

	# Angle entre la direction du regard et la direction du joueur.
	var facing := Vector2(_direction, 0.0)
	if absf(rad_to_deg(facing.angle_to(to_target))) > vision_angle / 2.0:
		return false

	return _has_line_of_sight(target)


func _has_line_of_sight(target: Node2D) -> bool:
	if not require_line_of_sight or sight_check == null:
		return true

	# target_position est en coordonnées locales au rayon.
	sight_check.target_position = sight_check.to_local(target.global_position)
	sight_check.force_raycast_update()
	return not sight_check.is_colliding()


## Récupère le RayCast2D de ligne de vue, ou en fabrique un s'il manque.
func _resolve_sight_check() -> RayCast2D:
	for child in get_children():
		if child is RayCast2D and child != $GroundCheck and child != $WallCheck:
			return child as RayCast2D

	var ray := RayCast2D.new()
	ray.name = "SightCheck"
	add_child(ray)
	return ray


func _on_hitbox_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(contact_damage, self)


# --- Dégâts --------------------------------------------------------------

## Appelée par les projectiles du joueur (voir Scripts/Weapons/bullet.gd).
func take_damage(amount: int, from: Node = null) -> void:
	if _health <= 0 or _state == State.DEAD:
		return

	_health -= amount
	hurt.emit(_health, from)

	_flash_timer = hurt_flash_time

	# Un coup encaisse interrompt l'attaque en cours.
	if _state == State.ATTACK:
		_set_attack_hitbox_active(false)
		_attack_cooldown_timer = attack_cooldown
		_enter_state(State.CHASE if _target != null else State.WALK)

	# Recul dans le sens du tir.
	if from is Node2D and knockback_force > 0.0:
		var push := signf(global_position.x - (from as Node2D).global_position.x)
		if push == 0.0:
			push = -_direction
		velocity.x = push * knockback_force
		if knockback_lift > 0.0 and is_on_floor():
			velocity.y = -knockback_lift
		_hurt_timer = hurt_stun_time

	if _health <= 0:
		_die(from)
		return

	# Se faire tirer dessus révèle la position du joueur.
	if _target == null and from is Bullet:
		var shooter := (from as Bullet).shooter
		if shooter is Node2D:
			_target = shooter as Node2D
			_lose_timer = lose_target_delay
			_enter_state(State.CHASE)


func _die(from: Node) -> void:
	_state = State.DEAD
	_target = null
	_flash_timer = 0.0
	sprite.modulate = Color.WHITE
	state_timer.stop()

	_play(death_anim)

	# Plus aucune interaction : il ne peut ni blesser, ni être touché, ni voir.
	_disable_area(hitbox)
	_disable_area(hurtbox)
	_disable_area(detection_zone)
	_disable_area(attack_hitbox)

	# Retenu tout de suite : il va être libéré avant la prochaine sauvegarde.
	SaveGame.store(self, {"dead": true})
	died.emit(from)

	if not (death_settle_on_ground and not is_on_floor()):
		_clear_corpse()


func _process_death(delta: float) -> void:
	# La dépouille finit sa chute, puis on ne garde que le corps et son sprite.
	if _corpse_cleared:
		return

	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	move_and_slide()

	if is_on_floor():
		_clear_corpse()


## Ne conserve que le CharacterBody2D et son AnimatedSprite2D : toutes les zones,
## formes de collision, sondes et minuteurs sont libérés.
func _clear_corpse() -> void:
	if _corpse_cleared:
		return
	_corpse_cleared = true

	velocity = Vector2.ZERO
	for child in get_children():
		if child != sprite:
			child.queue_free()

	# Le corps ne bouge plus et ne heurte plus rien.
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)

	if corpse_lifetime > 0.0:
		await get_tree().create_timer(corpse_lifetime).timeout
		if is_instance_valid(self):
			queue_free()


func _disable_area(area: Area2D) -> void:
	# Tout en différé : _die() peut être appelée depuis un signal de collision,
	# et le moteur physique interdit ces modifications pendant son traitement.
	area.set_deferred("monitoring", false)
	area.set_deferred("monitorable", false)
	area.set_deferred("collision_layer", 0)
	area.set_deferred("collision_mask", 0)


func _update_hurt_flash(delta: float) -> void:
	if _flash_timer <= 0.0:
		return

	_flash_timer -= delta
	if _flash_timer <= 0.0:
		sprite.modulate = Color.WHITE
		return

	# Alternance régulière entre la couleur de dégât et l'apparence normale.
	var on := int(_flash_timer / maxf(hurt_flash_interval, 0.01)) % 2 == 0
	sprite.modulate = hurt_flash_color if on else Color.WHITE


func _update_animation() -> void:
	# L'animation d'attaque est lancee une fois a l'entree dans l'etat et ne
	# doit pas etre remplacee tant que le coup n'est pas termine.
	if _state == State.ATTACK:
		return

	var anim := idle_anim
	if _state == State.CHASE:
		anim = chase_anim
	elif absf(velocity.x) > 5.0:
		anim = walk_anim
	_play(anim)


## Joue une animation et applique le décalage de sprite qui lui correspond.
func _play(anim: StringName) -> void:
	if sprite.sprite_frames == null or anim == &"":
		return
	if not sprite.sprite_frames.has_animation(anim):
		# Animation absente du SpriteFrames : on retombe sur la marche plutôt que
		# de laisser le sprite figé sur sa pose précédente.
		if anim == walk_anim or not sprite.sprite_frames.has_animation(walk_anim):
			return
		anim = walk_anim

	if sprite.animation != anim:
		sprite.play(anim)

	var off := idle_sprite_offset
	var size := idle_sprite_scale
	if anim == walk_anim:
		off = walk_sprite_offset
		size = walk_sprite_scale
	if anim == chase_anim:
		off = chase_sprite_offset
		size = chase_sprite_scale
	if anim == death_anim:
		off = death_sprite_offset
		size = death_sprite_scale
	if anim == attack_anim:
		off = attack_sprite_offset
		size = attack_sprite_scale

	SpriteFit.apply(sprite, off, size, _direction)


# --- Sauvegarde -----------------------------------------------------------

func save_state() -> Dictionary:
	return {"dead": _state == State.DEAD}


func load_state(data: Dictionary) -> void:
	# Un ennemi vaincu ne revient pas au chargement d'une partie.
	if data.get("dead", false):
		queue_free()
