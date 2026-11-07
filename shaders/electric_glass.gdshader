shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// An electrified containment wall: a faint blue sheen with jagged arcs of
// lightning crawling across it. UV runs 0..1 across the panel.

uniform vec4 tint : source_color = vec4(0.3, 0.65, 1.0, 1.0);
uniform float intensity = 1.0;
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
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
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void fragment() {
	float t = TIME + seed * 13.0;
	vec2 uv = UV;
	// arcs: thin bright lines where a jittering noise field crosses 0.5
	float jump = floor(t * 11.0);
	float n1 = fbm(uv * vec2(2.5, 4.0) + vec2(jump * 0.37, t * 0.25) + seed);
	float n2 = fbm(uv * vec2(5.0, 2.5) - vec2(t * 0.6, jump * 0.21) + seed * 2.0);
	float bolt = 1.0 - smoothstep(0.0, 0.025, abs(n1 - 0.5));
	bolt += (1.0 - smoothstep(0.0, 0.015, abs(n2 - 0.5))) * 0.7;
	float glow = (1.0 - smoothstep(0.0, 0.12, abs(n1 - 0.5))) * 0.25;
	float flicker = 0.65 + 0.35 * step(0.35, hash(vec2(jump, seed)));
	// brighter at the frame edges, like the field is strongest there
	float edge = max(smoothstep(0.4, 0.5, abs(uv.x - 0.5)), smoothstep(0.4, 0.5, abs(uv.y - 0.5)));
	vec3 col = tint.rgb * (0.06 + edge * 0.35 + glow) + vec3(0.75, 0.92, 1.0) * bolt * flicker;
	ALBEDO = col * intensity;
}
