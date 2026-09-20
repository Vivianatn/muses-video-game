shader_type canvas_item;

// Force globale de l'effet (0 = invisible, 1 = plein). Pilotée par le script.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
// Taille de la zone claire au centre (1.0 = touche les bords de l'écran).
uniform float radius : hint_range(0.0, 2.0) = 1.0;
// Douceur de la transition entre le centre clair et les bords sombres.
uniform float softness : hint_range(0.01, 2.0) = 0.5;
// Forme de l'ovale : (1, 1) = ovale qui épouse l'écran (assombrit autant haut/bas
// que gauche/droite). Augmenter X rétrécit sur les côtés, augmenter Y rétrécit haut/bas.
uniform vec2 shape = vec2(1.0, 1.0);
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	// UV va de 0 à 1 sur chaque axe : la distance est donc naturellement
	// relative à la largeur ET à la hauteur de l'écran (ovale), pas un cercle.
	vec2 centered = (UV - vec2(0.5)) * 2.0 * shape;
	float dist = length(centered);

	float vignette = smoothstep(radius, radius + softness, dist);
	COLOR = vec4(color.rgb, color.a * vignette * intensity);
}
