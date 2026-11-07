shader_type canvas_item;
render_mode blend_add, unshaded;
// The punch swipe: a 120-degree band of light that sweeps across the arc
// the punch covers. UV.x runs along the arc (0 = one end, 1 = the other),
// UV.y runs from the inner edge (0) to the outer edge (1).

uniform float progress = 0.0;            // 0 at the start of the swing, 1 at the end
uniform float sweep_dir = 1.0;           // 1 sweeps left-to-right, -1 right-to-left
uniform float heavy = 0.0;               // 1 for the heavy hook
uniform vec4 tint : source_color = vec4(1.0, 0.92, 0.75, 1.0);

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
	float along = sweep_dir > 0.0 ? UV.x : 1.0 - UV.x;
	// The arc swells outward as it travels, and the leading edge bulges
	// further out, like air being shoved ahead of the fist.
	float swell = mix(0.82, 1.0 + 0.18 * progress + 0.12 * heavy, UV.y);
	float lead = exp(-pow((along - progress * 1.15) * 7.0, 2.0));
	vec2 outward = normalize(VERTEX + vec2(0.0001));
	VERTEX = VERTEX * swell + outward * lead * UV.y * (0.12 + 0.1 * heavy);  // in mesh units: 1.0 = punch reach
}

void fragment() {
	float along = sweep_dir > 0.0 ? v_uv.x : 1.0 - v_uv.x;
	float head = progress * 1.15;
	// bright at the leading edge, fading out along the tail
	float trail = smoothstep(head - 0.55, head, along) * (1.0 - smoothstep(head, head + 0.04, along));
	float body = smoothstep(0.0, 0.5, v_uv.y) * 0.55;
	float rim = smoothstep(0.55, 0.92, v_uv.y) * (1.0 - smoothstep(0.92, 1.0, v_uv.y));
	float fade = 1.0 - smoothstep(0.65, 1.0, progress);
	float a = clamp(trail * (body + rim * 1.6) * fade * (1.3 + 0.5 * heavy), 0.0, 1.0);
	vec3 col = mix(tint.rgb, vec3(1.0), rim * 0.55);
	COLOR = vec4(col * a, a);
}
