@tool
extends PointLight2D
class_name Lumiere
## Une source de lumière à poser dans un niveau (Scenes/Ambiance/lumiere.tscn).
## Choisir un type règle couleur, puissance, taille et façon de vivre :
## une torche vacille, un cristal pulse lentement. « Personnalisée » laisse
## tout régler à la main dans l'inspecteur (Color, Energy, Texture Scale).
##
## Pensée pour les souterrains (Scenes/Ambiance/souterrain.tscn), où le
## CanvasModulate plonge le décor dans le noir : seules ces lumières éclairent,
## et le shader de l'ambiance fait ressortir leur couleur.

enum Type { TORCHE, LANTERNE, CRISTAL, CHAMPIGNON, SEVE, PERSONNALISEE }

const PRESETS := {
	Type.TORCHE: {"couleur": Color(1.0, 0.6, 0.28), "energie": 1.5, "taille": 2.4, "vacillement": 0.2, "vitesse": 9.0, "pulsation": false},
	Type.LANTERNE: {"couleur": Color(1.0, 0.82, 0.55), "energie": 1.2, "taille": 2.8, "vacillement": 0.06, "vitesse": 3.0, "pulsation": false},
	Type.CRISTAL: {"couleur": Color(0.42, 0.72, 1.0), "energie": 1.3, "taille": 2.0, "vacillement": 0.25, "vitesse": 1.2, "pulsation": true},
	Type.CHAMPIGNON: {"couleur": Color(0.72, 0.4, 1.0), "energie": 1.0, "taille": 1.6, "vacillement": 0.2, "vitesse": 0.8, "pulsation": true},
	Type.SEVE: {"couleur": Color(0.66, 0.82, 0.55), "energie": 1.1, "taille": 2.0, "vacillement": 0.15, "vitesse": 1.5, "pulsation": true},
}

@export var type: Type = Type.TORCHE:
	set(value):
		type = value
		_appliquer_preset()
## Amplitude des variations de puissance (0 = lumière fixe).
@export_range(0.0, 1.0, 0.01) var vacillement: float = 0.2
## Rapidité des variations.
@export_range(0.0, 20.0, 0.1) var vitesse: float = 9.0
## Vrai : variation lente et régulière (cristal). Faux : vacillement
## irrégulier (flamme).
@export var pulsation: bool = false
## Affiche le cœur de la source (flamme, cristal...) : un point lumineux de la
## couleur de la lumière, que le shader de l'ambiance entoure d'un halo.
## À couper si le décor dessine déjà la source.
@export var coeur_visible: bool = true:
	set(value):
		coeur_visible = value
		_maj_coeur()
## Taille du cœur, en part de la taille de la lumière.
@export_range(0.0, 0.5, 0.01) var coeur_taille: float = 0.1:
	set(value):
		coeur_taille = value
		_maj_coeur()
## Ombres portées par les LightOccluder2D (et les tuiles qui en ont).
@export var ombres: bool = false:
	set(value):
		ombres = value
		shadow_enabled = value

var _energie_base: float = 1.0
var _taille_base: float = 1.0
var _bruit := FastNoiseLite.new()
var _temps: float = 0.0
var _coeur: Sprite2D


func _ready() -> void:
	if texture == null:
		texture = _texture_douce()
	_bruit.seed = randi()
	_bruit.frequency = 1.0
	_energie_base = energy
	_taille_base = texture_scale
	shadow_enabled = ombres
	shadow_filter = Light2D.SHADOW_FILTER_PCF5
	shadow_filter_smooth = 3.0
	_maj_coeur()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or vacillement <= 0.0:
		return
	_temps += delta * vitesse
	var v: float
	if pulsation:
		v = sin(_temps)
	else:
		v = _bruit.get_noise_1d(_temps * 10.0)
	energy = _energie_base * (1.0 + v * vacillement)
	# La flamme respire un peu en taille, moins qu'en puissance.
	texture_scale = _taille_base * (1.0 + v * vacillement * 0.15)
	if _coeur != null:
		_coeur.modulate.a = clampf(0.85 + v * vacillement, 0.0, 1.0)


func _appliquer_preset() -> void:
	if not PRESETS.has(type):
		return
	var p: Dictionary = PRESETS[type]
	color = p.couleur
	energy = p.energie
	texture_scale = p.taille
	vacillement = p.vacillement
	vitesse = p.vitesse
	pulsation = p.pulsation
	_energie_base = energy
	_taille_base = texture_scale
	_maj_coeur()
	notify_property_list_changed()


## Le cœur est créé à la volée (jamais enregistré dans la scène) : il suit
## couleur et taille de la lumière, sans être lui-même éclairé ni assombri.
func _maj_coeur() -> void:
	if not is_inside_tree():
		return
	if _coeur == null:
		_coeur = Sprite2D.new()
		_coeur.texture = _texture_douce()
		var materiau := CanvasItemMaterial.new()
		materiau.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		materiau.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_coeur.material = materiau
		add_child(_coeur, false, Node.INTERNAL_MODE_FRONT)
	_coeur.visible = coeur_visible
	_coeur.scale = Vector2.ONE * texture_scale * coeur_taille
	_coeur.self_modulate = Color(color.lightened(0.35), 1.0)


## Dégradé radial doux : plein au centre, nul au bord, chute progressive.
static func _texture_douce() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.2), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
