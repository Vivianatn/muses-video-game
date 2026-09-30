@tool
class_name Circuit
extends Control

## Séparateur de la DA, repris de la ligne d'énergie qui traverse le logo :
## une piste sève de 2 px terminée par deux points de connexion. Se place
## sous l'en-tête d'un panneau ou entre deux sections d'un menu.
##
## La variante végétale porte une pousse en son centre. Elle est réservée aux
## écrans importants (titre, fin d'étage, découverte), une seule par écran.
## La pousse déborde de 22 px au-dessus de la piste : prévoir la place.
##
## Animations : de temps en temps, une impulsion d'énergie parcourt la piste ;
## `reveal` (de 0 à 1) trace la piste depuis le centre, allume les nœuds puis
## fait pousser la plante, pour une entrée en scène.

@export var vegetal: bool = false:
	set(value):
		vegetal = value
		queue_redraw()
## Part tracée, de 0 (rien) à 1 (tout). Se tweene pour une apparition.
@export_range(0.0, 1.0) var reveal: float = 1.0:
	set(value):
		reveal = clampf(value, 0.0, 1.0)
		queue_redraw()
## L'impulsion d'énergie qui parcourt la piste.
@export var pulse: bool = true:
	set(value):
		pulse = value
		queue_redraw()

## Une impulsion toutes les PULSE_PERIOD secondes, qui met PULSE_TRAVEL à
## traverser la piste.
const PULSE_PERIOD := 4.5
const PULSE_TRAVEL := 1.3
const PULSE_LENGTH := 36.0

## La pousse, tracée dans une boîte de 44 × 30 px (tige, feuilles, bourgeon).
const _POUSSE_TAILLE := Vector2(44, 30)
const _TIGE: Array[Vector2] = [Vector2(22, 26), Vector2(21, 18), Vector2(23, 14), Vector2(22, 8)]
const _FEUILLE_HAUT: Array[Vector2] = [Vector2(22, 14), Vector2(26, 7), Vector2(36, 6), Vector2(42, 10)]
const _FEUILLE_HAUT_DESSOUS: Array[Vector2] = [Vector2(42, 10), Vector2(36, 15), Vector2(27, 17), Vector2(22, 14)]
const _FEUILLE_BAS: Array[Vector2] = [Vector2(22, 18), Vector2(18, 12), Vector2(8, 11), Vector2(2, 15)]
const _FEUILLE_BAS_DESSOUS: Array[Vector2] = [Vector2(2, 15), Vector2(8, 20), Vector2(17, 21), Vector2(22, 18)]
const _BOURGEON := Vector2(22, 7)
## Le pied de la tige, autour duquel la pousse grandit.
const _PIED := Vector2(22, 26)

## Chaque circuit a son propre rythme : ils ne pulsent pas tous ensemble.
var _clock: float = randf() * PULSE_PERIOD


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not pulse or Engine.is_editor_hint() or not is_visible_in_tree():
		return
	_clock += delta
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(Muses.NOEUD * 2.0, Muses.NOEUD)


func _draw() -> void:
	var y := size.y * 0.5
	var r := Muses.NOEUD * 0.5
	# La piste se trace depuis le centre (70 % de reveal), puis les nœuds
	# s'allument, puis la pousse sort.
	var line := ease(clampf(reveal / 0.7, 0.0, 1.0), 0.4)
	var half := size.x * 0.5 * line
	draw_rect(Rect2(size.x * 0.5 - half, y - Muses.TRAIT * 0.5, half * 2.0, Muses.TRAIT), Muses.SEVE)
	var node := clampf((reveal - 0.7) / 0.15, 0.0, 1.0)
	if node > 0.0:
		draw_circle(Vector2(r, y), r * node, Muses.SEVE, true, -1.0, true)
		draw_circle(Vector2(size.x - r, y), r * node, Muses.SEVE, true, -1.0, true)

	if pulse and reveal >= 1.0:
		_draw_pulse(y)

	var growth := clampf((reveal - 0.8) / 0.2, 0.0, 1.0)
	if vegetal and growth > 0.0:
		# Le pied de la tige se pose sur la piste, au centre.
		_draw_pousse(Vector2(size.x * 0.5 - _POUSSE_TAILLE.x * 0.5, y - r - 22.0), ease(growth, -2.0))


## Un éclat clair qui court le long de la piste, du nœud gauche au droit.
func _draw_pulse(y: float) -> void:
	var t := fmod(_clock, PULSE_PERIOD) / PULSE_TRAVEL
	if t >= 1.0:
		return
	var x := lerpf(-PULSE_LENGTH, size.x + PULSE_LENGTH, ease(t, -1.6))
	var from := clampf(x - PULSE_LENGTH, 0.0, size.x)
	var to := clampf(x + PULSE_LENGTH, 0.0, size.x)
	if to - from < 1.0:
		return
	var glow := Color(Muses.PARCHEMIN, 0.0)
	var core := Color(Muses.PARCHEMIN, 0.9)
	var mid := clampf(x, from, to)
	for part in [[from, mid, glow, core], [mid, to, core, glow]]:
		var a: float = part[0]
		var b: float = part[1]
		if b - a < 0.5:
			continue
		draw_polygon(
				PackedVector2Array([Vector2(a, y - 1.5), Vector2(b, y - 1.5), Vector2(b, y + 1.5), Vector2(a, y + 1.5)]),
				PackedColorArray([part[2], part[3], part[3], part[2]]))


func _draw_pousse(origin: Vector2, growth: float = 1.0) -> void:
	# La pousse grandit depuis son pied, posé sur la piste.
	draw_set_transform(origin + _PIED * (1.0 - growth), 0.0, Vector2.ONE * growth)
	var tige := _bezier(_TIGE)
	draw_polyline(tige, Muses.FORET, 2.0, true)
	# Bouts arrondis.
	draw_circle(tige[0], 1.0, Muses.FORET, true, -1.0, true)
	draw_circle(tige[-1], 1.0, Muses.FORET, true, -1.0, true)

	# Chaque feuille : la feuille entière, puis sa moitié ombrée par-dessus
	# (le bord supérieur refermé par la nervure).
	var haut := _bezier(_FEUILLE_HAUT)
	_draw_shape(haut + _bezier(_FEUILLE_HAUT_DESSOUS), Muses.MOUSSE)
	_draw_shape(haut + PackedVector2Array([_FEUILLE_HAUT[3]]), Muses.MOUSSE_OMBRE)
	var bas := _bezier(_FEUILLE_BAS)
	_draw_shape(bas + _bezier(_FEUILLE_BAS_DESSOUS), Muses.JADE)
	_draw_shape(bas + PackedVector2Array([_FEUILLE_BAS[3]]), Muses.JADE_OMBRE)

	draw_circle(_BOURGEON, 3.0, Muses.BORDEAUX_CLAIR, true, -1.0, true)
	draw_set_transform(Vector2.ZERO)


## Forme pleine aux bords lissés (draw_colored_polygon ne lisse pas).
func _draw_shape(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, 1.0, true)


## Courbe de Bézier cubique en segments. Le point d'arrivée est omis : il est
## le départ de la courbe suivante, ou le polygone se referme dessus.
static func _bezier(p: Array[Vector2], steps: int = 12) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps:
		points.append(p[0].bezier_interpolate(p[1], p[2], p[3], float(i) / steps))
	return points
