shader_type spatial;
// Tissu des villageois, dessiné sans image : trame de toile, mailles de laine, grain et
// craquelures du cuir, velours. Relief tiré du motif, taches, et boue qui monte du sol.

uniform vec3 couleur : source_color = vec3(0.3);
uniform int matiere = 0;          // 0 laine · 1 cuir · 2 toile · 3 velours
uniform float echelle = 60.0;     // mailles par unité d'UV (le corps et les formes n'ont pas la même)
uniform float salete = 0.6;

varying float hauteur;

void vertex() {
	hauteur = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * bruit(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

float motif(vec2 uv) {
	vec2 g = uv * echelle;
	if (matiere == 2) {
		// Toile : fils qui passent dessus-dessous, un carré sur deux.
		vec2 c = floor(g);
		vec2 f = fract(g);
		float fil = mod(c.x + c.y, 2.0) > 0.5 ? sin(f.x * 3.1416) : sin(f.y * 3.1416);
		return 0.78 + 0.22 * fil + 0.12 * (bruit(g * 0.37) - 0.5);
	} else if (matiere == 0) {
		// Laine : côtes tricotées en V, un peu de bourre.
		vec2 k = g * vec2(1.0, 0.7);
		float cote = abs(sin(k.x * 3.1416));
		float maille = abs(sin((k.y + abs(fract(k.x) - 0.5)) * 6.2832));
		return 0.5 + 0.28 * cote + 0.22 * maille + 0.15 * (bruit(g * 3.0) - 0.5);
	} else if (matiere == 1) {
		// Cuir : grain serré, craquelures, usure claire.
		float grain = fbm(g * 0.9);
		float craque = smoothstep(0.03, 0.0, abs(fbm(g * 0.18) - 0.5));
		return 0.72 + 0.3 * grain - 0.4 * craque;
	}
	// Velours : doux, nuancé.
	return 0.78 + 0.25 * fbm(g * 0.6);
}

void fragment() {
	float m = motif(UV);
	vec3 c = couleur * m;
	// Taches (vin, sang, suie) à grande échelle, et la boue qui remonte du sol.
	float tache = fbm(UV * 6.0 + vec2(3.1, 7.7));
	c *= mix(1.0, 0.5, smoothstep(0.58, 0.78, tache) * salete);
	float boue = 1.0 - smoothstep(0.0, 0.7, hauteur);
	c = mix(c, c * vec3(0.55, 0.48, 0.4), boue * salete);
	ALBEDO = c;
	float e = 0.15 / echelle;
	float dx = motif(UV + vec2(e, 0.0)) - m;
	float dy = motif(UV + vec2(0.0, e)) - m;
	NORMAL_MAP = normalize(vec3(-dx * 3.0, -dy * 3.0, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = matiere == 1 ? 1.2 : 0.7;
	ROUGHNESS = matiere == 1 ? 0.5 : 0.97;
	SPECULAR = matiere == 1 ? 0.35 : 0.08;
	if (matiere == 3) {
		RIM = 0.6;
		RIM_TINT = 0.3;
	}
}
