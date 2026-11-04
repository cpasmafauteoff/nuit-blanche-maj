shader_type spatial;
// Les étoiles (Edwin, 30/10 : « rajoute des étoiles dans le ciel ») : un dôme juste derrière celui
// des nuages, qui suit la caméra. Des points semés sur la sphère, quelques gros, qui scintillent
// chacun à son rythme ; ils pâlissent vers l'horizon, là où la brume les avale.
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, shadows_disabled, blend_add;

uniform float force = 0.0;

varying vec3 dir;

float h(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

float semis(vec3 d, float densite, float seuil, float taille) {
	vec3 q = d * densite;
	vec3 id = floor(q);
	float tirage = h(id);
	if (tirage < seuil) {
		return 0.0;
	}
	vec3 centre = id + 0.2 + 0.6 * vec3(h(id + 1.3), h(id + 7.1), h(id + 3.7));
	float e = length(q - centre);
	float scintille = 0.65 + 0.35 * sin(TIME * (1.5 + 3.0 * h(id + 9.0)) + tirage * 60.0);
	return smoothstep(taille, 0.0, e) * scintille * (0.4 + 0.6 * h(id + 5.0));
}

void vertex() {
	dir = normalize(VERTEX);
}

void fragment() {
	vec3 d = normalize(dir);
	if (d.y < 0.0 || force <= 0.001) {
		discard;
	}
	float s = semis(d, 220.0, 0.965, 0.22) + semis(d, 70.0, 0.985, 0.16) * 1.6;
	float horizon = smoothstep(0.04, 0.35, d.y);
	vec3 teinte = mix(vec3(0.75, 0.82, 1.0), vec3(1.0, 0.9, 0.75), h(floor(d * 70.0) + 2.0));
	ALBEDO = teinte * s * horizon * force;
	ALPHA = 1.0;
}
