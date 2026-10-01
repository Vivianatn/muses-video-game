class_name SpriteBounds

## Où se trouve vraiment le dessin d'un personnage. Les images ont souvent une
## marge transparente et chaque personnage cale son sprite à sa façon (offset,
## échelle, retournement) : on lit donc les pixels visibles de l'image.

## Résultat de l'analyse, par texture et morceau d'image.
static var _cache: Dictionary[String, Dictionary] = {}


## Point du monde au sommet du dessin, à l'aplomb de son centre. Le centre est
## celui de la masse des pixels visibles : il tombe sur la tête même quand un
## bâton ou une cape élargit la silhouette d'un côté. On lit la première image
## de l'animation en cours, pour que le point ne sautille pas avec elle.
## Renvoie Vector2.INF quand il n'y a rien de lisible.
static func head_of(sprite: Node2D) -> Vector2:
	var texture: Texture2D
	var region: Rect2i
	# Le rectangle, dans le repère du sprite, où l'image est dessinée.
	var drawn: Rect2
	var flip := false

	if sprite is AnimatedSprite2D:
		var animated := sprite as AnimatedSprite2D
		var frames := animated.sprite_frames
		if frames == null or not frames.has_animation(animated.animation) or frames.get_frame_count(animated.animation) == 0:
			return Vector2.INF
		texture = frames.get_frame_texture(animated.animation, 0)
		if texture == null:
			return Vector2.INF
		var size := texture.get_size()
		drawn = Rect2(animated.offset - (size * 0.5 if animated.centered else Vector2.ZERO), size)
		region = Rect2i(Vector2i.ZERO, Vector2i(size))
		flip = animated.flip_h
	elif sprite is Sprite2D:
		var still := sprite as Sprite2D
		texture = still.texture
		if texture == null:
			return Vector2.INF
		drawn = still.get_rect()
		region = Rect2i(still.region_rect) if still.region_enabled else Rect2i(Vector2i.ZERO, Vector2i(texture.get_size()))
		if still.hframes > 1 or still.vframes > 1:
			# Division entière voulue : une frame fait un nombre entier de pixels.
			@warning_ignore("integer_division")
			var frame_size := region.size / Vector2i(still.hframes, still.vframes)
			region = Rect2i(region.position + frame_size * still.frame_coords, frame_size)
		flip = still.flip_h
	else:
		return Vector2.INF

	var info := _analyse(texture, region)
	if info.is_empty():
		return Vector2.INF
	var x: float = info.center_x
	if flip:
		x = region.size.x - x
	var scale := drawn.size / Vector2(region.size)
	return sprite.to_global(drawn.position + Vector2(x, info.top) * scale)


## { top, center_x } en pixels du morceau d'image, ou {} s'il est vide.
static func _analyse(texture: Texture2D, region: Rect2i) -> Dictionary:
	var key := "%d:%s" % [texture.get_instance_id(), region]
	if _cache.has(key):
		return _cache[key]

	var info := {}
	var image := texture.get_image()
	if image != null:
		if image.is_compressed():
			image.decompress()
		image = image.get_region(region)
		image.convert(Image.FORMAT_RGBA8)
		var used := image.get_used_rect()
		if used.size != Vector2i.ZERO:
			# Centre de masse horizontal des pixels bien opaques. Une ligne et
			# une colonne sur deux suffisent, et l'analyse n'a lieu qu'une fois
			# par image.
			var data := image.get_data()
			var width := image.get_width()
			var total := 0.0
			var count := 0
			for y in range(used.position.y, used.end.y, 2):
				var row := y * width * 4
				for x in range(used.position.x, used.end.x, 2):
					if data[row + x * 4 + 3] > 128:
						total += x
						count += 1
			var center: float = total / count + 0.5 if count > 0 else float(used.get_center().x)
			info = {"top": float(used.position.y), "center_x": center}

	_cache[key] = info
	return info
