shader_type spatial;
// Le plafond de nuages du jour : un dôme qui suit la caméra, des masses sombres qui
// défilent lentement et voilent le soleil. `couverture` 0 = ciel dégagé, 1 = tout bouché.
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, shadows_disabled;

uniform float couverture = 0.7;
uniform float opacite = 1.0;
uniform vec3 couleur : source_color = vec3(0.2, 0.21, 0.21);
uniform vec3 bord : source_color = vec3(0.45, 0.46, 0.44);
uniform vec3 soleil = vec3(0.4, 0.5, 0.3);
uniform float vitesse = 0.006;

varying vec3 dir;

// Bruit lisse et sans couture fourni par le jeu (NoiseTexture2D) : un bruit calculé ici
// laissait voir sa grille, en carrés durs.
uniform sampler2D bruit_tex : filter_linear_mipmap, repeat_enable;

float fbm(vec2 p) {
	return texture(bruit_tex, p * 0.07).r * 0.65 + texture(bruit_tex, p * 0.19 + vec2(0.37, 0.71)).r * 0.35;
}

void vertex() {
	dir = normalize(VERTEX);
}

void fragment() {
	vec3 d = normalize(dir);
	if (d.y < -0.02) {
		discard;
	}
	// Projection sur un plafond plat : les nuages s'écrasent vers l'horizon.
	vec2 p = d.xz / (d.y + 0.12) * 1.6;
	float t = TIME * vitesse;
	p += 0.8 * vec2(fbm(p * 0.5 + vec2(t * 0.5, 3.1)), fbm(p * 0.5 + vec2(7.4, t * 0.3)));
	float n = fbm(p + vec2(t, t * 0.4) * 6.0);
	float masse = smoothstep(1.0 - couverture - 0.15, 1.0 - couverture + 0.35, n);
	// Les bords des nuages s'éclairent un peu du côté du soleil.
	float vers_soleil = pow(max(dot(d, normalize(soleil)), 0.0), 6.0);
	vec3 c = mix(bord, couleur, smoothstep(0.2, 0.9, masse));
	c += vec3(0.25, 0.22, 0.18) * vers_soleil * (1.0 - masse) * 0.6;
	float horizon = smoothstep(-0.02, 0.18, d.y);
	// Le soleil : un disque pâle et terne, voilé quand une masse passe devant.
	float cs = dot(d, normalize(soleil));
	float disque = smoothstep(0.9975, 0.999, cs) * (1.0 - masse * 0.75);
	float halo = pow(max(cs, 0.0), 60.0) * (1.0 - masse * 0.6) * 0.35;
	c = mix(c, vec3(0.86, 0.82, 0.7), clamp(disque + halo, 0.0, 1.0));
	ALBEDO = c;
	ALPHA = clamp(max(masse, disque * 0.95 + halo), 0.0, 1.0) * horizon * opacite;
}
