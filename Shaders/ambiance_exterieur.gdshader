shader_type canvas_item;
// Post-traitement des niveaux en extérieur, posé sur un ColorRect plein écran
// d'une CanvasLayer juste au-dessus du monde (voir Scenes/Ambiance/exterieur.tscn).
//
// 1. Ciel : les pixels du fond (exactement la couleur de fond du projet) sont
//    remplacés par un dégradé de ciel avec un soleil.
// 2. Rayons : la lumière du ciel est traînée vers le soleil. Le terrain et les
//    arbres la bloquent : rayons entre les feuillages et ombres portées.
// 3. Étalonnage : exposition, contraste, ombres froides et lumières chaudes.
// 4. Halo autour des zones claires, relief local, brume, vignette.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;

group_uniforms Ciel;
// Couleur de fond du niveau : réglée par le script Ambiance, ne pas toucher.
uniform vec3 couleur_fond : source_color = vec3(0.302, 0.502, 0.6);
uniform bool ciel_actif = true;
uniform vec3 ciel_haut : source_color = vec3(0.24, 0.45, 0.72);
uniform vec3 ciel_horizon : source_color = vec3(0.98, 0.80, 0.58);
// Hauteur de l'horizon dans l'écran (0 = haut, 1 = bas).
uniform float horizon : hint_range(0.0, 1.5) = 0.95;

group_uniforms Soleil;
// Position du soleil en coordonnées d'écran (0-1). Peut sortir de l'écran.
uniform vec2 soleil_position = vec2(0.82, 0.12);
uniform vec3 soleil_couleur : source_color = vec3(1.0, 0.86, 0.6);
uniform float soleil_taille : hint_range(0.0, 0.2) = 0.045;
uniform float soleil_halo : hint_range(0.0, 2.0) = 0.35;
uniform float rayons_force : hint_range(0.0, 2.0) = 0.55;
// Longueur des rayons : part du trajet vers le soleil parcourue.
uniform float rayons_longueur : hint_range(0.0, 1.0) = 0.6;
uniform float rayons_decroissance : hint_range(0.8, 1.0) = 0.965;

group_uniforms Etalonnage;
uniform float exposition : hint_range(0.0, 2.0) = 1.05;
uniform float contraste : hint_range(0.5, 2.0) = 1.12;
// Saturation intelligente : renforce surtout les couleurs ternes.
uniform float vibrance : hint_range(-1.0, 1.5) = 0.15;
uniform vec3 teinte_ombres : source_color = vec3(0.30, 0.38, 0.62);
uniform vec3 teinte_lumieres : source_color = vec3(1.0, 0.86, 0.66);
uniform float force_teintes : hint_range(0.0, 1.0) = 0.25;

group_uniforms Halo;
uniform float halo_force : hint_range(0.0, 2.0) = 0.25;
uniform float halo_seuil : hint_range(0.0, 1.0) = 0.7;

group_uniforms Relief;
// Contraste local : détache les formes et creuse les ombres.
uniform float relief : hint_range(0.0, 1.5) = 0.35;

group_uniforms Atmosphere;
uniform vec3 brume_couleur : source_color = vec3(0.82, 0.86, 0.9);
// Brume vers l'horizon (bas de l'écran), qui donne de la profondeur.
uniform float brume_force : hint_range(0.0, 1.0) = 0.12;
uniform float vignette_force : hint_range(0.0, 1.0) = 0.3;

const int RAYONS_ECHANTILLONS = 28;

float luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// Vrai si le pixel est le fond (couleur de fond exacte, avant tout effet).
float masque_ciel(vec2 uv) {
	vec3 c = textureLod(screen_tex, uv, 0.0).rgb;
	return 1.0 - step(0.012, distance(c, couleur_fond));
}

vec3 ciel(vec2 uv, float aspect) {
	float t = clamp(uv.y / max(horizon, 0.001), 0.0, 1.0);
	vec3 c = mix(ciel_haut, ciel_horizon, pow(t, 1.6));
	vec2 d = (uv - soleil_position) * vec2(aspect, 1.0);
	float dist = length(d);
	// Disque net + halo large.
	c += soleil_couleur * smoothstep(soleil_taille, soleil_taille * 0.8, dist) * 1.2;
	c += soleil_couleur * soleil_halo * exp(-dist * 9.0) * 0.6;
	return c;
}

vec3 vibrer(vec3 c, float v) {
	float l = luminance(c);
	float sat = max(max(c.r, c.g), c.b) - min(min(c.r, c.g), c.b);
	return mix(vec3(l), c, 1.0 + v * (1.0 - sat));
}

// Bruit léger qui casse le banding des dégradés.
float tramage(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec3 col = textureLod(screen_tex, uv, 0.0).rgb;

	// 1. Ciel.
	float est_ciel = ciel_actif ? masque_ciel(uv) : 0.0;
	col = mix(col, ciel(uv, aspect), est_ciel);

	// 2. Relief : écart avec une version floue de l'image.
	vec3 flou = textureLod(screen_tex, uv, 3.0).rgb;
	col += (col - flou) * relief * (1.0 - est_ciel);

	// 3. Rayons : on remonte vers le soleil en cumulant le ciel rencontré.
	if (rayons_force > 0.0 && ciel_actif) {
		vec2 pas = (soleil_position - uv) * rayons_longueur / float(RAYONS_ECHANTILLONS);
		vec2 p = uv;
		float poids = 1.0;
		float lumiere = 0.0;
		float total = 0.0;
		// Décalage par pixel : évite les marches visibles dans les rayons.
		p += pas * (tramage(FRAGCOORD.xy) + 0.5);
		for (int i = 0; i < RAYONS_ECHANTILLONS; i++) {
			p += pas;
			lumiere += masque_ciel(clamp(p, vec2(0.0), vec2(1.0))) * poids;
			total += poids;
			poids *= rayons_decroissance;
		}
		lumiere /= total;
		// Proche du soleil, les rayons sont plus forts.
		float proche = exp(-length((uv - soleil_position) * vec2(aspect, 1.0)) * 1.6);
		vec3 rayons = soleil_couleur * lumiere * proche * rayons_force;
		// Les zones à l'ombre des rayons (sous les arbres) s'assombrissent un peu.
		float ombre = (1.0 - lumiere) * proche * rayons_force * 0.35 * (1.0 - est_ciel);
		col = col * (1.0 - ombre) + rayons;
	}

	// 4. Étalonnage.
	col *= exposition;
	col = (col - 0.5) * contraste + 0.5;
	col = vibrer(max(col, 0.0), vibrance);
	float l = luminance(col);
	vec3 teinte = mix(teinte_ombres, teinte_lumieres, smoothstep(0.1, 0.8, l));
	col = mix(col, col * teinte * 1.45, force_teintes * (1.0 - est_ciel * 0.7));

	// 5. Halo : les zones claires débordent autour d'elles.
	vec3 large = textureLod(screen_tex, uv, 4.0).rgb * 0.6 + textureLod(screen_tex, uv, 5.5).rgb * 0.4;
	vec3 halo = max(large - halo_seuil, 0.0) / max(1.0 - halo_seuil, 0.001);
	col += halo * teinte_lumieres * halo_force;

	// 6. Brume vers le bas de l'écran, et vignette.
	col = mix(col, brume_couleur, brume_force * smoothstep(0.35, 1.0, uv.y) * (1.0 - est_ciel));
	col *= 1.0 - vignette_force * smoothstep(0.35, 0.95, length(uv - 0.5) * 1.4);

	col += tramage(FRAGCOORD.xy) / 255.0;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
