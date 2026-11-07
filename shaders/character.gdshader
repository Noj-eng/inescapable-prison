shader_type canvas_item;
// Attack and damage animation for characters, done by moving vertices.
// The feet stay planted: only things drawn above the floor are affected,
// so the shadow underneath never moves.

uniform float hit = 0.0;          // 0..1: damage shake + flash
uniform float squash = 0.0;       // >0 squash flat (impact), <0 stretch tall (wind-up)
uniform float lean = 0.0;         // shear the top of the body left (-) or right (+)
uniform float wobble = 0.0;       // 0..1: dizzy sway when stunned
uniform float seed = 0.0;         // so two characters never shake in sync
uniform float body_height = 50.0; // pixels from feet to the top of the head
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying float body_mask;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void vertex() {
	float up = -VERTEX.y;
	float above = smoothstep(2.0, 10.0, up);   // 0 for the shadow, 1 for the body
	float h = clamp(up / body_height, 0.0, 1.5);
	body_mask = above;

	// squash & stretch around the feet
	VERTEX.y *= 1.0 - squash * 0.28 * above;
	VERTEX.x *= 1.0 + squash * 0.18 * above;

	// lean: the head travels, the feet don't
	VERTEX.x += lean * h * body_height * 0.35 * above;

	// stunned: a slow drunken sway
	VERTEX.x += sin(TIME * 7.0 + seed) * wobble * h * 6.0 * above;

	// damage: a violent jitter that snaps to a new offset 40 times a second
	float t = floor(TIME * 40.0);
	vec2 jitter = vec2(hash(t + seed), hash(t * 1.7 + seed + 0.37)) - 0.5;
	VERTEX += jitter * hit * 7.0 * above;
}

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, hit * 0.7 * body_mask);
}
