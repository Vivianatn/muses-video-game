@tool
class_name StyleBoxChamfer
extends StyleBox

## Le cadre de tous les widgets de la DA : deux couches aux coins haut-gauche
## et bas-droit coupés, comme les lettres du logo. D'abord le contour, puis la
## face, décalée de `border_width` et biseautée de la même façon. En option,
## le relief (ombre portée nette, sans flou) et la lueur sève.
##
## Utilisé par la Jauge. Le thème du projet, lui, s'en tient aux StyleBoxFlat
## natifs (voir tools/build_theme.gd) : Godot le charge avant l'arbre de
## scène, trop tôt pour un style scripté quand le débogueur est branché.

## Couleur de la face. Transparente, il ne reste que le contour : c'est le
## style de focus, dessiné par-dessus celui du bouton.
@export var face_color: Color = Muses.SURFACE:
	set(value):
		face_color = value
		emit_changed()
@export var border_color: Color = Muses.CUIVRE:
	set(value):
		border_color = value
		emit_changed()
@export var border_width: float = Muses.TRAIT:
	set(value):
		border_width = maxf(value, 0.0)
		emit_changed()
## Longueur (px) du biseau, mesurée sur chaque côté.
@export var chamfer: float = Muses.CHANFREIN_SM:
	set(value):
		chamfer = maxf(value, 0.0)
		_glow = null
		emit_changed()
@export var cut_top_left: bool = true:
	set(value):
		cut_top_left = value
		_glow = null
		emit_changed()
@export var cut_bottom_right: bool = true:
	set(value):
		cut_bottom_right = value
		_glow = null
		emit_changed()

@export_group("Relief")
## Transparente = pas de relief.
@export var relief_color: Color = Color(Muses.RACINE, 0.0):
	set(value):
		relief_color = value
		emit_changed()
@export var relief_offset: Vector2 = Muses.RELIEF:
	set(value):
		relief_offset = value
		emit_changed()

@export_group("Lueur")
## Transparente = pas de lueur.
@export var glow_color: Color = Color(Muses.SEVE, 0.0):
	set(value):
		glow_color = value
		_glow = null
		emit_changed()
@export var glow_size: int = Muses.LUEUR_TAILLE:
	set(value):
		glow_size = maxi(value, 0)
		_glow = null
		emit_changed()

## La lueur, seul flou permis par la DA : l'ombre de StyleBoxFlat s'en charge.
var _glow: StyleBoxFlat


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if glow_color.a > 0.0 and glow_size > 0:
		_glow_box().draw(to_canvas_item, rect)

	if relief_color.a > 0.0:
		var shifted := Rect2(rect.position + relief_offset, rect.size)
		fill(to_canvas_item, outline(shifted, chamfer, cut_top_left, cut_bottom_right), relief_color)

	var outer := outline(rect, chamfer, cut_top_left, cut_bottom_right)
	var inner := outline(rect.grow(-border_width), chamfer, cut_top_left, cut_bottom_right)
	var has_face := face_color.a > 0.0
	if border_width > 0.0 and border_color.a > 0.0:
		if has_face:
			fill(to_canvas_item, outer, border_color)
		else:
			ring(to_canvas_item, outer, inner, border_color)
	if has_face:
		fill(to_canvas_item, inner if border_width > 0.0 else outer, face_color)


func _get_draw_rect(rect: Rect2) -> Rect2:
	var drawn := rect
	if relief_color.a > 0.0:
		drawn = drawn.merge(Rect2(rect.position + relief_offset, rect.size))
	if glow_color.a > 0.0:
		drawn = drawn.grow(glow_size)
	return drawn


func _glow_box() -> StyleBoxFlat:
	if _glow == null:
		_glow = StyleBoxFlat.new()
		_glow.draw_center = false
		_glow.shadow_color = glow_color
		_glow.shadow_size = glow_size
		_glow.corner_detail = 1
		_glow.corner_radius_top_left = int(chamfer) if cut_top_left else 0
		_glow.corner_radius_bottom_right = int(chamfer) if cut_bottom_right else 0
	return _glow


# --- Géométrie, partagée avec Jauge ---------------------------------------

## Les six sommets d'un rectangle biseauté, dans le sens horaire depuis le
## haut-gauche. Un coin non coupé donne deux sommets confondus : le compte ne
## change jamais, ce qui permet d'apparier contour extérieur et intérieur.
static func outline(rect: Rect2, cut: float, top_left: bool = true, bottom_right: bool = true) -> PackedVector2Array:
	var c := minf(cut, minf(rect.size.x, rect.size.y) * 0.5)
	var tl := c if top_left else 0.0
	var br := c if bottom_right else 0.0
	var p := rect.position
	var e := rect.end
	return PackedVector2Array([
		Vector2(p.x + tl, p.y), Vector2(e.x, p.y),
		Vector2(e.x, e.y - br), Vector2(e.x - br, e.y),
		Vector2(p.x, e.y), Vector2(p.x, p.y + tl),
	])


## Remplit un polygone convexe, bords lissés.
static func fill(canvas_item: RID, points: PackedVector2Array, color: Color) -> void:
	var clean := _without_duplicates(points)
	if clean.size() < 3:
		return
	RenderingServer.canvas_item_add_polygon(canvas_item, clean, PackedColorArray([color]))
	_smooth_edges(canvas_item, clean, color)


## Le contour seul : la bande entre deux polygones appariés, en quadrilatères.
static func ring(canvas_item: RID, outer: PackedVector2Array, inner: PackedVector2Array, color: Color) -> void:
	var colors := PackedColorArray([color, color, color, color])
	for i in outer.size():
		var j := (i + 1) % outer.size()
		RenderingServer.canvas_item_add_primitive(canvas_item,
				PackedVector2Array([outer[i], outer[j], inner[j], inner[i]]), colors, PackedVector2Array(), RID())
	_smooth_edges(canvas_item, _without_duplicates(outer), color)
	_smooth_edges(canvas_item, _without_duplicates(inner), color)


## Les polygones ne sont pas lissés : un trait fin antialiasé sur leur bord
## adoucit les biseaux.
static func _smooth_edges(canvas_item: RID, points: PackedVector2Array, color: Color) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	RenderingServer.canvas_item_add_polyline(canvas_item, closed, PackedColorArray([color]), 1.0, true)


static func _without_duplicates(points: PackedVector2Array) -> PackedVector2Array:
	var clean := PackedVector2Array()
	for point in points:
		if clean.is_empty() or not clean[-1].is_equal_approx(point):
			clean.append(point)
	if clean.size() > 1 and clean[0].is_equal_approx(clean[-1]):
		clean.remove_at(clean.size() - 1)
	return clean
