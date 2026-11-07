shader_type canvas_item;
// Faint monitor scanlines and a dark vignette over the whole screen.

uniform float line_strength = 0.07;
uniform float vignette = 0.55;

void fragment() {
	float line = 0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159);
	vec2 uv = SCREEN_UV - 0.5;
	float v = smoothstep(0.35, 0.85, length(uv * vec2(1.0, 1.25)));
	float a = line * line_strength + v * vignette;
	COLOR = vec4(0.0, 0.0, 0.02, clamp(a, 0.0, 0.85));
}
