extends Area2D
class_name Collectable

## Objet à ramasser en passant dessus (une Connaissance, par exemple). Il
## flotte, éclaire les alentours, et disparaît en fondu quand le joueur le
## touche, en ajoutant `value` exemplaires de `item_id` à l'inventaire.
##
## Une fois ramassé, il ne revient plus, même après un chargement de partie :
## il est retenu par SaveGame.
##
## Si la fiche de l'objet (res://Items/) déclare une variable de dialogue, les
## PNJ peuvent parler du total : {connaissances}, [si connaissances >= 3].

## Émis au ramassage, avec la nouvelle quantité possédée.
signal collected(total: int)

@export_group("Collecte")
## Identifiant de l'objet ajouté à l'inventaire : le champ `id` de sa fiche
## dans res://Items/.
@export var item_id: StringName = &"connaissance"
## Ce que vaut cet objet (un gros cristal peut compter pour plusieurs).
@export var value: int = 1
## Son joué au ramassage. Vide = silence.
@export var pickup_sound: AudioStream = null

@export_group("Flottement")
## Amplitude (px) du flottement de haut en bas. 0 = immobile.
@export var bob_height: float = 4.0
## Oscillations par seconde.
@export var bob_speed: float = 0.5

@export_group("Lumière")
## Amplitude de la pulsation de la lumière, en part de son intensité :
## 0.15 = elle varie de ±15 %. 0 = lumière fixe.
@export_range(0.0, 1.0) var light_pulse: float = 0.15
## Pulsations par seconde.
@export var light_pulse_speed: float = 0.8

@export_group("Disparition")
## Durée (s) de l'effet de ramassage : l'objet monte, grossit et s'efface.
@export var vanish_time: float = 0.35
## Hauteur (px) dont il monte pendant qu'il disparaît.
@export var vanish_rise: float = 24.0

## Le dessin de l'objet : un Sprite2D (image fixe) ou un AnimatedSprite2D
## (animation), du moment que le nœud s'appelle « Sprite ».
@onready var sprite: Node2D = $Sprite
@onready var light: PointLight2D = $Light

var _time: float = 0.0
var _base_energy: float = 1.0
var _collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Déjà ramassé dans la partie chargée : load_state() le fait disparaître.
	SaveGame.register(self)
	_base_energy = light.energy
	# Départ décalé au hasard : plusieurs objets posés côte à côte ne flottent
	# pas en rythme, ce qui ferait mécanique.
	_time = randf() * 10.0


func _process(delta: float) -> void:
	if _collected:
		return
	_time += delta
	sprite.position.y = sin(_time * TAU * bob_speed) * bob_height
	light.position.y = sprite.position.y
	light.energy = _base_energy * (1.0 + light_pulse * sin(_time * TAU * light_pulse_speed))


func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	collect()


## Ramasse l'objet, comme si le joueur l'avait touché. Appelable depuis un
## autre script (aimant, fin de combat...).
func collect() -> void:
	if _collected:
		return
	_collected = true
	# Plus de détection : un deuxième contact pendant le fondu ne doit pas
	# compter l'objet deux fois. set_deferred car on est dans un signal physique.
	set_deferred(&"monitoring", false)

	Inventory.add(item_id, value)
	# Retenu tout de suite : l'objet va être libéré avant la prochaine sauvegarde.
	SaveGame.store(self, save_state())
	_play_sound()
	collected.emit(Inventory.count(item_id))
	_vanish()


# --- Sauvegarde -----------------------------------------------------------

func save_state() -> Dictionary:
	return {"collected": _collected}


func load_state(data: Dictionary) -> void:
	if data.get("collected", false):
		_collected = true
		queue_free()


func _vanish() -> void:
	if vanish_time <= 0.0:
		queue_free()
		return

	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, ^"position:y", sprite.position.y - vanish_rise, vanish_time) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite, ^"scale", sprite.scale * 1.4, vanish_time)
	tween.tween_property(sprite, ^"modulate:a", 0.0, vanish_time)
	# La lumière s'éteint avec lui au lieu de disparaître d'un coup.
	tween.tween_property(light, ^"energy", 0.0, vanish_time)
	tween.chain().tween_callback(queue_free)


## Le son est confié au niveau : l'objet disparaît avant la fin du son, qui
## serait sinon coupé net.
func _play_sound() -> void:
	if pickup_sound == null:
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = pickup_sound
	# Il sera frère de l'objet : même parent, donc même position locale.
	player.position = position
	player.autoplay = true
	player.finished.connect(player.queue_free)
	# Différé : on est dans un signal physique, où l'arbre n'aime pas changer.
	get_parent().add_child.call_deferred(player)
