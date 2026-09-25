@tool
class_name SpriteFit

## Cale le sprite d'un personnage pour l'animation en cours : décalage et
## taille propres à chaque animation. Utilisé par le joueur, les ennemis et
## les PNJ, qui exposent un couple offset / scale par animation.
##
## La taille est appliquée en gardant les PIEDS à la même place : agrandir le
## sprite ne l'enfonce pas dans le sol et le rapetisser ne le fait pas flotter.
## Seul le dessin change de taille : la forme de collision n'est pas touchée.


## `offset` : décalage en pixels d'écran (non agrandis), X vers l'avant du
## personnage, Y vers le bas. `size` : 1 = taille d'origine. `facing` : 1 ou -1
## selon le sens du regard, car flip_h ne retourne pas l'offset.
static func apply(sprite: AnimatedSprite2D, offset: Vector2, size: float, facing: float) -> void:
	size = maxf(size, 0.01)
	sprite.scale = Vector2(size, size)

	# Le sprite est centré : son bas est à la demi-hauteur de la frame. On
	# corrige l'offset (exprimé dans l'espace agrandi du sprite) pour que ce bas
	# reste là où il serait à la taille 1.
	var half_height := _frame_height(sprite) * 0.5
	var y := (offset.y + half_height) / size - half_height
	sprite.offset = Vector2(offset.x * facing / size, y)


static func _frame_height(sprite: AnimatedSprite2D) -> float:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(sprite.animation):
		return 0.0
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	return 0.0 if texture == null else float(texture.get_height())
