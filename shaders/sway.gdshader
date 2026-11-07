shader_type canvas_item;
// Structural instability for pillars and walls. The base is locked to the
// floor; the higher a vertex is, the further it moves.

uniform float height = 80.0;   // pixels from the floor to the top
uniform float sway = 0.0;      // idle creaking, in pixels at the top
uniform float tremor = 0.0;    // 0..1: fast shaking during aftershocks and impacts
uniform float shear = 0.0;     // lasting lean after being hit, in pixels at the top
uniform float seed = 0.0;

void vertex() {
	float h = clamp(-VERTEX.y / height, 0.0, 1.2);
	h *= h;   // bend like a beam: barely at the bottom, most at the top
	float creak = sin(TIME * 1.3 + seed) * sway + sin(TIME * 3.1 + seed * 2.0) * sway * 0.3;
	float shake = sin(TIME * 38.0 + seed) * tremor * 3.0;
	VERTEX.x += (creak + shake + shear) * h;
	VERTEX.y += abs(shear) * 0.35 * h;   // a buckled pillar also sags
}
