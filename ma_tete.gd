class_name MaTete
extends RefCounted
## « Ma tête » : une photo de face, prise UNE fois par le capteur, posée sur le visage du villageois.
## Les yeux clignent et la bouche s'ouvre par-dessus la photo, suivant la webcam comme avant.
##
## La photo reste sur ce PC (user://ma_tete.jpg) ; elle n'est envoyée qu'aux joueurs d'un lobby
## PRIVÉ (venus par le code), directement de PC à PC, jamais à un site. Désactivée par défaut.

const FICHIER := "user://ma_tete.jpg"
const REPERES := "user://ma_tete.json"
const TAILLE_MAX := 60000          # octets : une photo légitime en fait ~10 000

# Le visage du villageois (coordonnées de la tête, cf. Bouille) : yeux et bouche dessinés.
const OEIL_Y := 0.012
const OEIL_X := 0.045
const BOUCHE_Y := -0.068

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back;
uniform sampler2D photo : source_color, filter_linear;
uniform vec2 oeil_a = vec2(0.35, 0.42);
uniform vec2 oeil_b = vec2(0.65, 0.42);
uniform float oeil_l = 0.12;
uniform vec2 bouche = vec2(0.5, 0.75);
uniform float bouche_l = 0.25;
uniform float ferme_a = 0.0;
uniform float ferme_b = 0.0;
uniform float ouvre = 0.0;
uniform vec3 peau = vec3(0.8, 0.65, 0.55);

float paupiere(vec2 uv, vec2 c, float ferme) {
	vec2 d = (uv - c) / vec2(oeil_l * 0.62, oeil_l * 0.36);
	if (dot(d, d) > 1.0) return 0.0;
	// La paupière descend du haut de l'œil.
	return step(d.y, -1.0 + 2.0 * ferme) * smoothstep(1.0, 0.8, dot(d, d));
}

void fragment() {
	vec2 uv = UV;
	vec4 c = texture(photo, uv);
	vec2 o = (uv - vec2(0.5, 0.52)) / vec2(0.5, 0.5);
	float masque = smoothstep(1.0, 0.86, length(o));
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) masque = 0.0;
	vec3 col = c.rgb;
	col = mix(col, peau, max(paupiere(uv, oeil_a, ferme_a), paupiere(uv, oeil_b, ferme_b)));
	vec2 b = (uv - bouche) / vec2(bouche_l * 0.42, max(bouche_l * 0.32 * ouvre, 0.0001));
	float dedans = smoothstep(1.0, 0.75, dot(b, b)) * step(0.05, ouvre);
	col = mix(col, vec3(0.08, 0.02, 0.02), dedans);
	ALBEDO = col;
	ALPHA = masque;
	ROUGHNESS = 0.75;
}
"""


static func existe() -> bool:
	return FileAccess.file_exists(FICHIER) and FileAccess.file_exists(REPERES)


static func enregistrer(octets: PackedByteArray, reperes: Dictionary) -> void:
	var f := FileAccess.open(FICHIER, FileAccess.WRITE)
	f.store_buffer(octets)
	f.close()
	var j := FileAccess.open(REPERES, FileAccess.WRITE)
	j.store_string(JSON.stringify(reperes))
	j.close()


## [octets, repères] de ma photo, ou [] s'il n'y en a pas.
static func charger() -> Array:
	if not existe():
		return []
	var r = JSON.parse_string(FileAccess.get_file_as_string(REPERES))
	if not r is Dictionary:
		return []
	return [FileAccess.get_file_as_bytes(FICHIER), r]


static func effacer() -> void:
	for f in [FICHIER, REPERES]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


## Repères plausibles (tous entre 0 et 1, yeux au-dessus de la bouche) : une photo reçue d'un
## autre joueur est vérifiée avant d'être affichée.
static func reperes_valides(r: Dictionary) -> bool:
	for k in ["ax", "ay", "bx", "by", "mx", "my", "ol", "ml"]:
		if not r.has(k) or not (r[k] is float or r[k] is int):
			return false
		if float(r[k]) < 0.0 or float(r[k]) > 1.0:
			return false
	return float(r["my"]) > float(r["ay"]) and float(r["bx"]) > float(r["ax"]) + 0.05


static func image(octets: PackedByteArray) -> Image:
	if octets.is_empty() or octets.size() > TAILLE_MAX:
		return null
	var img := Image.new()
	if img.load_jpg_from_buffer(octets) != OK or img.get_width() > 512 or img.get_height() > 512:
		return null
	return img


## Le masque posé sur le visage : un morceau de la surface de la tête (un peu en avant), dont les
## coordonnées de texture placent les yeux et la bouche de la photo sur ceux du villageois.
static func masque(img: Image, r: Dictionary) -> MeshInstance3D:
	var ech_x := (2.0 * OEIL_X) / maxf(float(r["bx"]) - float(r["ax"]), 0.05)
	var ech_y := (OEIL_Y - BOUCHE_Y) / maxf(float(r["my"]) - (float(r["ay"]) + float(r["by"])) * 0.5, 0.05)
	var u0 := (float(r["ax"]) + float(r["bx"])) * 0.5
	var v0 := (float(r["ay"]) + float(r["by"])) * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 36
	var pts := []
	for j in n + 1:
		var ligne := []
		for i in n + 1:
			var x := lerpf(-0.1, 0.1, float(i) / n)
			var y := lerpf(-0.135, 0.115, float(j) / n)
			ligne.append(Vector3(x, y, _avant(x, y)))
		pts.append(ligne)
	for j in n:
		for i in n:
			var quad := [pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j + 1][i]]
			for tri in [[0, 2, 1], [0, 3, 2]]:
				if (quad[tri[0]] as Vector3).z < 0.0 or (quad[tri[1]] as Vector3).z < 0.0 or (quad[tri[2]] as Vector3).z < 0.0:
					continue
				for k in tri:
					var p: Vector3 = quad[k]
					st.set_uv(Vector2(u0 + p.x / ech_x, v0 + (OEIL_Y - p.y) / ech_y))
					st.set_normal(Vector3(p.x / 0.0924, p.y / 0.1176, p.z / 0.105).normalized())
					st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	m.shader = sh
	m.set_shader_parameter("photo", ImageTexture.create_from_image(img))
	m.set_shader_parameter("oeil_a", Vector2(r["ax"], r["ay"]))
	m.set_shader_parameter("oeil_b", Vector2(r["bx"], r["by"]))
	m.set_shader_parameter("oeil_l", float(r["ol"]))
	m.set_shader_parameter("bouche", Vector2(r["mx"], r["my"]))
	m.set_shader_parameter("bouche_l", float(r["ml"]))
	var teint := _teint(img, r)
	m.set_shader_parameter("peau", Vector3(teint.r, teint.g, teint.b))
	mi.material_override = m
	return mi


## Profondeur de la surface du visage en (x, y) : le crâne (ellipsoïde) ou la mâchoire, le plus
## en avant des deux, un rien devant pour ne pas s'y enfoncer. Négatif : hors du visage.
static func _avant(x: float, y: float) -> float:
	var t := 1.0 - pow(x / 0.0924, 2) - pow(y / 0.1176, 2)
	var crane := 0.105 * sqrt(t) if t > 0.0 else -1.0
	var m := 1.0 - pow(x / 0.06, 2) - pow((y + 0.06) / 0.054, 2)
	var machoire := 0.025 + 0.066 * sqrt(m) if m > 0.0 else -1.0
	var z := maxf(crane, machoire)
	return z + 0.003 if z > 0.02 else -1.0


## Le teint, pris sous les yeux (joues) : c'est la couleur des paupières qui se ferment.
static func _teint(img: Image, r: Dictionary) -> Color:
	var somme := Color(0, 0, 0)
	var nb := 0
	for k in [["ax", "ay"], ["bx", "by"]]:
		var cx := int(float(r[k[0]]) * img.get_width())
		var cy := int((float(r[k[1]]) + float(r["ol"]) * 0.6) * img.get_height())
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var px := clampi(cx + dx, 0, img.get_width() - 1)
				var py := clampi(cy + dy, 0, img.get_height() - 1)
				somme += img.get_pixel(px, py)
				nb += 1
	return somme / float(maxi(nb, 1))
