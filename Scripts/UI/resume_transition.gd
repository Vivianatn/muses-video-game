extends CanvasLayer

## La transition du bouton « Continuer » de l'écran titre : le souvenir de la
## partie se ranime.
##
## 1. L'écran titre s'efface ; une ligne d'énergie sève se trace au centre.
## 2. Elle s'ouvre comme une fente sur la miniature de la sauvegarde (l'endroit
##    exact où l'on a quitté le jeu), figée en sépia dans un cadre cuivre,
##    le nom du lieu gravé dessous : une relique qu'on vient de dégager.
## 3. Le niveau se charge derrière. Un balayage sève rend ses couleurs au
##    souvenir, de haut en bas.
## 4. Le souvenir grandit jusqu'à remplir l'écran, puis se fond dans le jeu
##    bien réel, là où on l'avait laissé.
##
## Le jeu reste en pause du chargement jusqu'à ce qu'il soit entièrement
## visible, plus un court temps d'arrêt : le joueur ne peut ni bouger ni
## ouvrir le menu sans voir ce qu'il y a devant lui.
##
## Elle vit à la racine de l'arbre : le changement de scène ne l'emporte pas.
## Si le chargement échoue, tout se replie et `failed` est émis : l'écran
## titre reprend la main.
##
## Usage (depuis l'écran titre) :
##     var transition := preload("res://Scripts/UI/resume_transition.gd").new()
##     get_tree().root.add_child(transition)
##     transition.play(slot, menu)

## Le chargement a échoué : la transition s'est repliée d'elle-même.
signal failed

const SaveGameScript := preload("res://Scripts/Save/save_game.gd")

## Temps minimal (s) pendant lequel on voit le souvenir avant qu'il se ranime,
## même si le niveau se charge en un éclair.
const MIN_MEMORY_TIME := 0.9
## Temps (s) où le jeu, enfin visible, reste figé avant de repartir : le
## joueur voit où il est avant de pouvoir bouger.
const RESUME_HOLD := 0.2

## Sépia de pierre et de parchemin sous la ligne de balayage, vraies couleurs
## au-dessus, et un trait sève sur la ligne elle-même.
const _SHADER := """
shader_type canvas_item;

uniform float restore : hint_range(0.0, 1.0) = 0.0;
uniform vec4 scan_color : source_color = vec4(0.66, 0.82, 0.55, 1.0);

void fragment() {
	vec4 base = COLOR;
	float grey = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 sepia = vec3(grey) * vec3(1.0, 0.86, 0.7) * 0.9;
	vec3 rgb = mix(sepia, base.rgb, step(UV.y, restore));
	float on_line = smoothstep(0.025, 0.0, abs(UV.y - restore)) * step(0.001, restore) * step(restore, 0.999);
	rgb = mix(rgb, scan_color.rgb, on_line * 0.85);
	COLOR = vec4(rgb, base.a);
}
"""

var _veil: ColorRect
var _beam: Control
var _card: Control
var _frame: Control
var _image: TextureRect
var _caption: VBoxContainer


func _init() -> void:
	layer = 100
	# Tourne pendant le chargement et pendant que le niveau reste en pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# L'interface bouge au rythme de l'affichage (tweens, _process) : on la
	# sort de l'interpolation physique, qui ne vaut que pour le monde.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## Joue toute la transition et charge l'emplacement `slot`. `title_ui` est
## la partie de l'écran titre à effacer d'abord (les boutons, le logo).
func play(slot: int, title_ui: Control) -> void:
	var info := SaveGame.get_slot_info(slot)
	var view := get_viewport().get_visible_rect().size
	var thumbnail: Texture2D = info.get("thumbnail")
	var card_rect := _card_rect(view, thumbnail)
	_build(view, card_rect, thumbnail, info)

	# 1. Le titre s'efface, la nuit tombe, la ligne d'énergie se trace.
	var tween := _tween()
	tween.tween_property(title_ui, ^"modulate:a", 0.0, 0.35)
	tween.tween_property(_veil, ^"color:a", 1.0, 0.5)
	tween.tween_property(_beam, ^"scale:x", 1.0, 0.45).set_delay(0.25) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await tween.finished

	# 2. La fente s'ouvre sur le souvenir, le lieu se grave dessous.
	tween = _tween()
	if thumbnail != null:
		tween.tween_property(_card, ^"position:y", card_rect.position.y, 0.5) \
				.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(_card, ^"size:y", card_rect.size.y, 0.5) \
				.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(_beam, ^"modulate:a", 0.0, 0.3).set_delay(0.2)
	tween.tween_property(_caption, ^"modulate:a", 1.0, 0.4).set_delay(0.3)
	await tween.finished

	# 3. Le niveau se charge derrière le voile, pendant qu'on regarde.
	var shown_at := Time.get_ticks_msec()
	var ok: bool = await SaveGame.load_slot(slot)
	if not ok:
		await _fold(title_ui)
		failed.emit()
		queue_free()
		return
	# Le jeu attend, figé, d'être révélé : le personnage ne bouge pas avant.
	get_tree().paused = true
	var waited := (Time.get_ticks_msec() - shown_at) / 1000.0
	if waited < MIN_MEMORY_TIME:
		await get_tree().create_timer(MIN_MEMORY_TIME - waited).timeout

	if thumbnail != null:
		# Le balayage sève rend ses couleurs au souvenir.
		tween = _tween()
		# Par une fonction : un paramètre de shader n'est pas une propriété
		# qu'un tween sait animer tant qu'il n'a jamais été défini.
		var material := _image.material as ShaderMaterial
		tween.tween_method(func(value: float) -> void: material.set_shader_parameter(&"restore", value),
				0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished

		# 4. Le souvenir grandit jusqu'à remplir l'écran...
		tween = _tween()
		tween.tween_property(_caption, ^"modulate:a", 0.0, 0.2)
		tween.tween_property(_frame, ^"modulate:a", 0.0, 0.35)
		tween.tween_property(_card, ^"position", Vector2.ZERO, 0.6) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(_card, ^"size", view, 0.6) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
		# ... il couvre tout : le voile n'a plus lieu d'être.
		_veil.color.a = 0.0

	# ... et se fond dans le jeu, toujours en pause : le joueur ne peut pas
	# bouger sans voir ce qu'il y a devant lui.
	tween = _tween()
	tween.tween_property(_card, ^"modulate:a", 0.0, 0.45)
	tween.tween_property(_veil, ^"color:a", 0.0, 0.45)
	tween.tween_property(_caption, ^"modulate:a", 0.0, 0.25)
	await tween.finished
	# Un court temps d'arrêt sur l'image nette, puis le jeu repart.
	await get_tree().create_timer(RESUME_HOLD).timeout
	get_tree().paused = false
	queue_free()


## Chargement raté : la fente se referme, le titre revient.
func _fold(title_ui: Control) -> void:
	var tween := _tween()
	tween.tween_property(_card, ^"modulate:a", 0.0, 0.3)
	tween.tween_property(_caption, ^"modulate:a", 0.0, 0.3)
	tween.tween_property(_beam, ^"modulate:a", 0.0, 0.3)
	tween.tween_property(_veil, ^"color:a", 0.0, 0.4)
	if is_instance_valid(title_ui):
		tween.tween_property(title_ui, ^"modulate:a", 1.0, 0.4)
	await tween.finished


## Place du souvenir : la moitié de la largeur de l'écran, aux proportions de
## la miniature, un peu au-dessus du centre pour laisser la place au lieu.
static func _card_rect(view: Vector2, thumbnail: Texture2D) -> Rect2:
	var ratio := 9.0 / 16.0
	if thumbnail != null and thumbnail.get_width() > 0:
		ratio = float(thumbnail.get_height()) / thumbnail.get_width()
	var size := Vector2(view.x * 0.5, view.x * 0.5 * ratio)
	if size.y > view.y * 0.5:
		size = Vector2(view.y * 0.5 / ratio, view.y * 0.5)
	return Rect2(Vector2((view.x - size.x) * 0.5, (view.y - size.y) * 0.5 - 30.0), size)


## Tween parallèle qui tourne même jeu en pause.
func _tween() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()


func _build(view: Vector2, card_rect: Rect2, thumbnail: Texture2D, info: Dictionary) -> void:
	# Le voile nuit : il cache l'écran titre puis le chargement du niveau, et
	# arrête la souris.
	_veil = ColorRect.new()
	_veil.color = Color(Muses.NUIT, 0.0)
	_veil.size = view
	add_child(_veil)

	var middle_y := card_rect.get_center().y

	# La ligne d'énergie : un trait sève et sa lueur, qui s'étire depuis le centre.
	_beam = Control.new()
	_beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_beam.position = Vector2(card_rect.position.x, middle_y)
	_beam.size = Vector2(card_rect.size.x, 0.0)
	_beam.pivot_offset = Vector2(card_rect.size.x * 0.5, 0.0)
	_beam.scale.x = 0.0
	add_child(_beam)
	var glow := ColorRect.new()
	glow.color = Muses.LUEUR
	glow.position = Vector2(0.0, -4.0)
	glow.size = Vector2(card_rect.size.x, 8.0)
	_beam.add_child(glow)
	var core := ColorRect.new()
	core.color = Muses.SEVE
	core.position = Vector2(0.0, -1.0)
	core.size = Vector2(card_rect.size.x, 2.0)
	_beam.add_child(core)

	# Le souvenir : la miniature, qui s'ouvre depuis la ligne (hauteur 0).
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.clip_contents = true
	_card.position = Vector2(card_rect.position.x, middle_y)
	_card.size = Vector2(card_rect.size.x, 0.0)
	_card.visible = thumbnail != null
	add_child(_card)

	_image = TextureRect.new()
	_image.texture = thumbnail
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = _SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	_image.material = material
	_card.add_child(_image)

	# Les coins coupés de l'image : l'image est rectangulaire, son angle
	# dépasserait du biseau du cadre. On y peint la nuit du voile derrière.
	var corners := Control.new()
	corners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corners.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corners.draw.connect(func() -> void:
		var c := Muses.CHANFREIN_MD
		var end := corners.size
		corners.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(c, 0.0), Vector2(0.0, c)]), Muses.NUIT)
		corners.draw_colored_polygon(PackedVector2Array([end, Vector2(end.x - c, end.y), Vector2(end.x, end.y - c)]), Muses.NUIT))
	corners.resized.connect(corners.queue_redraw)

	# Le cadre cuivre biseauté, par-dessus l'image. Les coins masqués en font
	# partie : ils s'effacent avec lui quand le souvenir remplit l'écran.
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.add_child(corners)
	var border := Panel.new()
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = Muses.CUIVRE
	box.set_border_width_all(int(Muses.TRAIT))
	box.corner_detail = 1
	box.corner_radius_top_left = int(Muses.CHANFREIN_MD)
	box.corner_radius_bottom_right = int(Muses.CHANFREIN_MD)
	border.add_theme_stylebox_override(&"panel", box)
	_frame.add_child(border)
	_card.add_child(_frame)

	# Le lieu et le temps de jeu, gravés sous le souvenir.
	_caption = VBoxContainer.new()
	_caption.alignment = BoxContainer.ALIGNMENT_BEGIN
	_caption.add_theme_constant_override(&"separation", 4)
	_caption.position = Vector2(0.0, card_rect.end.y + Muses.ESPACE_2)
	_caption.size = Vector2(view.x, 0.0)
	_caption.modulate.a = 0.0
	add_child(_caption)
	if thumbnail == null:
		_caption.position.y = view.y * 0.5 - 30.0
	var place := String(info.get("location", ""))
	for line: Array in [
		["Reprise de la fouille", &"Categorie"],
		[place if place != "" else "Partie en cours", &"TitrePanneau"],
		[SaveGameScript.format_playtime(float(info.get("playtime", 0.0))), &"HudEtiquette"],
	]:
		var label := Label.new()
		label.text = line[0]
		label.theme_type_variation = line[1]
		label.uppercase = true
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_caption.add_child(label)
