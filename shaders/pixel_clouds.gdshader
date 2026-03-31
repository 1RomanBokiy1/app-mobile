shader_type canvas_item;

uniform float pixel_block : hint_range(2.0, 32.0) = 6.0;
uniform vec2 rect_pixels = vec2(400.0, 800.0);
uniform float scroll_speed : hint_range(0.0, 1.0) = 0.08;

uniform vec3 color_deep : source_color = vec3(0.08, 0.22, 0.52);
uniform vec3 color_mid : source_color = vec3(0.35, 0.72, 0.92);
uniform vec3 color_accent : source_color = vec3(0.45, 0.92, 0.55);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.6, 0.8), vec2(-0.8, 0.6));
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = rot * p * 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 px = uv * rect_pixels;
	px = floor(px / pixel_block) * pixel_block;
	vec2 snapped_uv = px / max(rect_pixels, vec2(1.0));

	vec2 p = snapped_uv * vec2(80.0, 140.0);
	p += vec2(TIME * scroll_speed * 12.0, TIME * scroll_speed * 4.0);

	float n = fbm(p);
	float n2 = fbm(p * 1.7 + vec2(100.0, 3.0));
	float clouds = smoothstep(0.35, 0.72, n * 0.65 + n2 * 0.5);

	float variation = fbm(p * 0.3 + vec2(0.0, TIME * 0.05));
	vec3 col = mix(color_deep, color_mid, clouds);
	col = mix(col, color_accent, clouds * variation * 0.55);

	float vig = 1.0 - length(snapped_uv - 0.5) * 0.35;
	col *= vig;

	COLOR = vec4(col, 1.0);
}
