@tool
class_name Jauge
extends Control

## La piste d'une jauge du HUD (DA « Jauge ») : cadre cuivre biseauté, fond
## racine, remplissage en dégradé découpé en dix segments. L'étiquette et la
## valeur chiffrée sont posées à côté par la scène qui l'utilise : vie et
## énergie ne se distinguent jamais par la seule couleur.

enum Kind {
	## Le chaud du logo : bordeaux → brique.
	LIFE,
	## Le vert des circuits : jade-ombre → jade → sève. Pleine, elle luit.
	ENERGY,
}

@export var kind: Kind = Kind.LIFE:
	set(value):
		kind = value
		queue_redraw()
## Part remplie, de 0 à 1.
@export_range(0.0, 1.0) var ratio: float = 1.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		# Moins d'un dixième de pixel d'écart ne se voit pas : pas de redessin.
		if is_equal_approx(value, ratio) or (size.x > 0.0 and absf(value - ratio) * size.x < 0.1):
			return
		ratio = value
		queue_redraw()
## Fait battre la jauge, pour une alerte (vie basse...). Le battement passe
## par une teinte : il ne redessine rien.
@export var alert: bool = false:
	set(value):
		alert = value
		set_process(alert)
		if not alert:
			self_modulate = Color.WHITE

const _SEGMENTS := 10
## Hauteur fixe de la piste.
const _HEIGHT := 20.0
## Les dégradés : couleur et position (0-1) le long du remplissage.
const _LIFE_STOPS: Array = [[Muses.BORDEAUX, 0.0], [Muses.BRIQUE, 1.0]]
const _ENERGY_STOPS: Array = [[Muses.JADE_OMBRE, 0.0], [Muses.JADE, 0.6], [Muses.SEVE, 1.0]]

var _frame := StyleBoxChamfer.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.face_color = Muses.RACINE
	set_process(false)


func _get_minimum_size() -> Vector2:
	return Vector2(160, _HEIGHT)


func _process(_delta: float) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
	self_modulate = Color.WHITE.lerp(Color(1.45, 1.35, 1.3), pulse)


func _draw() -> void:
	var rect := Rect2(Vector2(0.0, (size.y - _HEIGHT) * 0.5), Vector2(size.x, _HEIGHT))
	var full := kind == Kind.ENERGY and ratio >= 1.0
	_frame.glow_color = Muses.LUEUR if full else Color(Muses.SEVE, 0.0)
	draw_style_box(_frame, rect)

	var inner := StyleBoxChamfer.outline(rect.grow(-Muses.TRAIT), Muses.CHANFREIN_SM)
	var left := inner[5].x
	var width := inner[1].x - left
	var fill_end := left + width * ratio

	if ratio > 0.0:
		var stops: Array = _ENERGY_STOPS if kind == Kind.ENERGY else _LIFE_STOPS
		# Le dégradé court sur la partie remplie. Une tranche par paire de
		# couleurs : l'interpolation par sommet reste alors exacte.
		for i in stops.size() - 1:
			var from_x := lerpf(left, fill_end, stops[i][1])
			var to_x := lerpf(left, fill_end, stops[i + 1][1])
			var piece := _slab(inner, from_x, to_x)
			if piece.size() < 3:
				continue
			var colors := PackedColorArray()
			for point in piece:
				var t := inverse_lerp(from_x, to_x, point.x) if to_x > from_x else 0.0
				var color: Color = (stops[i][0] as Color).lerp(stops[i + 1][0], t)
				colors.append(color)
			draw_polygon(piece, colors)

	# Les séparations : les 2 derniers px de chaque dixième, en racine,
	# coupées par le biseau comme le reste du fond.
	for i in range(1, _SEGMENTS + 1):
		var x := left + width * i / _SEGMENTS
		var gap := _slab(inner, x - Muses.TRAIT, x)
		if gap.size() >= 3:
			draw_colored_polygon(gap, Muses.RACINE)


## La partie d'un polygone convexe comprise entre deux verticales.
static func _slab(points: PackedVector2Array, from_x: float, to_x: float) -> PackedVector2Array:
	return _clip(_clip(points, from_x, 1.0), to_x, -1.0)


## Garde le côté du polygone où `side * (x - limit) >= 0` (Sutherland-Hodgman).
static func _clip(points: PackedVector2Array, limit: float, side: float) -> PackedVector2Array:
	var kept := PackedVector2Array()
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var a_in := side * (a.x - limit) >= 0.0
		var b_in := side * (b.x - limit) >= 0.0
		if a_in:
			kept.append(a)
		if a_in != b_in:
			kept.append(a.lerp(b, (limit - a.x) / (b.x - a.x)))
	# Retire les sommets confondus, que draw_polygon refuse.
	var clean := PackedVector2Array()
	for point in kept:
		if clean.is_empty() or not clean[-1].is_equal_approx(point):
			clean.append(point)
	if clean.size() > 1 and clean[0].is_equal_approx(clean[-1]):
		clean.remove_at(clean.size() - 1)
	return clean
