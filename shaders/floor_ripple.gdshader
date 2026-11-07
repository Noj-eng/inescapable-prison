shader_type canvas_item;
// An aftershock rolling through the floor: a ring that travels out from
// the epicentre and lifts the tiles as it passes.

uniform vec2 origin = vec2(0.0);  // epicentre, in floor coordinates
uniform float age = 100.0;        // seconds since the shockwave started
uniform float strength = 0.0;     // how far tiles lift, in pixels
uniform float speed = 280.0;      // how fast the ring travels, pixels/second

void vertex() {
	vec2 d = VERTEX - origin;
	d.y *= 2.0;                       // undo the isometric squash: distance on the flat floor
	float dist = length(d);
	float front = age * speed;
	float band = exp(-pow((dist - front) / 50.0, 2.0));   // only near the travelling ring
	float fade = exp(-age * 1.3);
	VERTEX.y -= sin(dist * 0.09 - age * 18.0) * strength * band * fade;
}
