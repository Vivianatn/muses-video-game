shader_type canvas_item;
// Post-traitement des niveaux souterrains, posé sur un ColorRect plein écran
// d'une CanvasLayer juste au-dessus du monde (voir Scenes/Ambiance/souterrain.tscn).
//
// Le noir vient du CanvasModulate de l'ambiance, la lumière des PointLight2D
// (Scenes/Ambiance/lumiere.tscn). Ce shader met les lumières en valeur :
// 1. Les zones éclairées gagnent en saturation : la couleur de chaque
//    lumière s'affirme sur ce qu'elle touche.
// 2. Halo coloré et diffusion dans l'air : chaque source baigne ses alentours
//    de sa teinte, comme dans une poussière en suspension.
// 3. Poussières qui scintillent uniquement dans la lumière.
// 4. Les ombres glissent vers une teinte froide et désaturée, sans tomber
//    dans le noir complet, pour rester lisibles.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;

group_uniforms Lumieres;
// Saturation ajoutée là où il y a de la lumière.
uniform float saturation_lumieres : hint_range(0.0, 2.0) = 0.5;
uniform float exposition : hint_range(0.0, 3.0) = 1.1;

group_uniforms Halo;
uniform float halo_force : hint_range(0.0, 3.0) = 0.6;
uniform float halo_seuil : hint_range(0.0, 1.0) = 0.3;
// Renforce la couleur du halo pour qu'il porte la teinte de sa source.
uniform float halo_couleur : hint_range(0.0, 2.0) = 0.8;
// Lumière diffusée dans l'air, très large.
uniform float diffusion : hint_range(0.0, 2.0) = 0.3;

group_uniforms Ombres;
uniform vec3 teinte_ombres : source_color = vec3(0.10, 0.12, 0.24);
// Plancher des noirs : 0 = noir complet, plus haut = ombres lisibles.
uniform float noirs_releves : hint_range(0.0, 0.3) = 0.04;
uniform float desaturation_ombres : hint_range(0.0, 1.0) = 0.55;
uniform float contraste : hint_range(0.5, 2.0) = 1.15;

group_uniforms Poussieres;
uniform float poussieres_force : hint_range(0.0, 2.0) = 0.8;
uniform float poussieres_densite : hint_range(10.0, 200.0) = 70.0;
uniform float poussieres_vitesse : hint_range(0.0, 0.2) = 0.02;

group_uniforms Finition;
uniform float vignette_force : hint_range(0.0, 1.0) = 0.55;
uniform float grain : hint_range(0.0, 0.2) = 0.035;
// Décalage des couleurs sur les bords de l'écran.
uniform float aberration : hint_range(0.0, 0.01) = 0.0015;

float luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 saturer(vec3 c, float s) {
	return mix(vec3(luminance(c)), c, s);
}

// Particules : une par case de la grille, qui dérive et scintille.
float poussieres(vec2 uv, float aspect) {
	vec2 p = uv * vec2(aspect, 1.0) * poussieres_densite;
	p += vec2(TIME * poussieres_vitesse * 40.0, -TIME * poussieres_vitesse * 25.0);
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float h = hash(cell);
	if (h < 0.75) {
		return 0.0;
	}
	vec2 centre = vec2(hash(cell + 3.1), hash(cell + 7.7)) * 0.6 + 0.2;
	centre += 0.15 * vec2(sin(TIME * 0.7 + h * 40.0), cos(TIME * 0.9 + h * 30.0));
	float d = length(f - centre);
	float scintille = 0.5 + 0.5 * sin(TIME * (1.5 + h * 3.0) + h * 60.0);
	return smoothstep(0.09, 0.0, d) * scintille;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;

	// Légère aberration chromatique, nulle au centre.
	vec2 dir = (uv - 0.5) * aberration * length(uv - 0.5) * 4.0;
	vec3 col;
	col.r = textureLod(screen_tex, uv + dir, 0.0).r;
	col.g = textureLod(screen_tex, uv, 0.0).g;
	col.b = textureLod(screen_tex, uv - dir, 0.0).b;
	col *= exposition;

	float l = luminance(col);
	float eclaire = smoothstep(0.05, 0.6, l);

	// 1. Couleur des lumières affirmée sur ce qu'elles touchent.
	col = saturer(col, 1.0 + saturation_lumieres * eclaire);

	// 4. Ombres froides et désaturées.
	vec3 ombre = mix(col, vec3(l), desaturation_ombres) * (vec3(1.0) + teinte_ombres * 2.0);
	col = mix(ombre, col, eclaire);
	col = (col - 0.18) * contraste + 0.18;
	col = max(col, 0.0) + teinte_ombres * noirs_releves * 4.0 * (1.0 - eclaire);

	// 2. Halo coloré (moyen) et diffusion dans l'air (large).
	vec3 moyen = textureLod(screen_tex, uv, 3.0).rgb * 0.5 + textureLod(screen_tex, uv, 4.0).rgb * 0.5;
	vec3 large = textureLod(screen_tex, uv, 5.5).rgb * 0.6 + textureLod(screen_tex, uv, 7.0).rgb * 0.4;
	vec3 halo = max(moyen * exposition - halo_seuil, 0.0) / max(1.0 - halo_seuil, 0.001);
	halo = saturer(halo, 1.0 + halo_couleur);
	vec3 air = saturer(large * exposition, 1.0 + halo_couleur);
	col += max(halo, 0.0) * halo_force + max(air, 0.0) * diffusion;

	// 3. Poussières, visibles seulement là où l'air est éclairé.
	float lumiere_air = luminance(large * exposition);
	vec3 teinte_air = large / max(max(large.r, max(large.g, large.b)), 0.001);
	col += teinte_air * poussieres(uv, aspect) * poussieres_force * smoothstep(0.02, 0.3, lumiere_air);

	// Finition.
	col *= 1.0 - vignette_force * smoothstep(0.3, 0.9, length(uv - 0.5) * 1.4);
	col += (hash(FRAGCOORD.xy + fract(TIME) * 100.0) - 0.5) * grain;
	// Compression douce des hautes lumières : les sources restent colorées
	// au lieu de tourner au blanc.
	col = col / (1.0 + max(col - 1.0, 0.0));
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
