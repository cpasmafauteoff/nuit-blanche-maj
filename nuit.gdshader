shader_type canvas_item;
// Voile de la nuit : ce que voit le joueur selon l'ouverture de ses paupières.

uniform sampler2D ecran : hint_screen_texture, filter_linear_mipmap;
uniform float nuit = 0.0;   // 0 jour, 1 nuit
uniform float vue = 0.0;    // 0 rien, 1 tout (ouverture effective des yeux)
uniform float flou = 0.0;   // niveau de flou
uniform float alerte = 0.0; // rougeoiement quand un loup approche du repérage
uniform float temps = 0.0;
uniform float plein = 0.0;  // 1 : vision de loup, sans fente
uniform float mort = 0.0;   // 1 : le monde vu par un fantôme (terne, bleuté, bords qui s'effacent)

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 scene = textureLod(ecran, uv, flou).rgb;
	vec2 c = uv - vec2(0.5);
	c.x *= 1.5;
	// Une fente qui s'ouvre comme des paupières, plus large au centre.
	float demi = mix(0.0, 0.62, vue);
	float bord = abs(c.y) + c.x * c.x * 0.9;
	float masque = 1.0 - smoothstep(demi * 0.55, demi * 0.55 + 0.09, bord);
	masque *= step(0.001, vue);
	masque = mix(masque, 1.0 - smoothstep(0.55, 0.95, length(c)) * 0.6, plein);
	vec3 vu = mix(scene * vec3(0.7, 0.78, 1.15), scene * vec3(1.15, 0.8, 0.8), plein);
	vec3 col = vu * masque;
	float pouls = 0.5 + 0.5 * sin(temps * 9.0);
	col += vec3(0.55, 0.0, 0.03) * alerte * pouls * (1.0 - masque * 0.6) * length(c) * 1.6;
	vec3 fin = mix(scene, col, nuit);
	// Le monde des morts : les couleurs s'éteignent, un froid bleu monte des bords, qui ondulent.
	float gris = dot(fin, vec3(0.3, 0.59, 0.11));
	vec3 terne = mix(fin, vec3(gris) * vec3(0.78, 0.9, 1.12), 0.72);
	float bords = smoothstep(0.35, 0.95, length(c) + 0.015 * sin(temps * 1.3 + uv.y * 12.0));
	terne = mix(terne, vec3(0.16, 0.22, 0.34), bords * 0.75);
	COLOR = vec4(mix(fin, terne, mort), 1.0);
}
