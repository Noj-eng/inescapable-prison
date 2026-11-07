shader_type canvas_item;
// Slow drifting fog drawn over the level. Noise is generated here, no textures.
render_mode unshaded;

uniform vec4 tint : source_color = vec4(0.55, 0.6, 0.72, 1.0);
uniform float density = 0.16;

varying vec2 world_pos;

void vertex() {
	world_pos = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
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
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = world_pos * vec2(0.006, 0.012);
	float n = fbm(p + vec2(TIME * 0.035, TIME * 0.012));
	n *= fbm(p * 0.6 - vec2(TIME * 0.02, 0.0) + 7.0);
	COLOR = vec4(tint.rgb, clamp((n - 0.12) * density * 3.0, 0.0, 0.3));
}
