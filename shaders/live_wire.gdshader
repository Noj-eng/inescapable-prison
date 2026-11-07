shader_type canvas_item;
// A severed high-voltage cable hanging from the ceiling. The anchor stays
// put; the loose end snaps into a new violent pose several times a second
// while a high-frequency buzz runs down its length.

uniform float length_px = 130.0;  // anchor is at y = -length_px, the loose end at y = 0
uniform float intensity = 1.0;
uniform float seed = 0.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void vertex() {
	float w = clamp((VERTEX.y + length_px) / length_px, 0.0, 1.0);  // 0 at the anchor, 1 at the end
	w *= w;
	float snap = floor(TIME * 6.0 + seed);
	float blend = smoothstep(0.0, 0.25, fract(TIME * 6.0 + seed));   // whip quickly into each pose
	vec2 pose_a = vec2(hash(snap - 1.0) - 0.5, hash(snap + 2.3) - 0.5);
	vec2 pose_b = vec2(hash(snap) - 0.5, hash(snap + 3.3) - 0.5);
	vec2 pose = mix(pose_a, pose_b, blend) * vec2(34.0, 12.0);
	float buzz = sin(VERTEX.y * 0.12 + TIME * 32.0 + seed) * 2.5;
	// a loop: the lower part curls back around
	float curl = sin(w * 6.28 + TIME * 9.0 + seed) * 5.0 * w;
	VERTEX += (pose + vec2(buzz + curl, 0.0)) * w * intensity;
}
