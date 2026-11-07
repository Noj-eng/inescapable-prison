shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// The 3D punch swipe: a 120-degree band of light lying flat at fist height
// that sweeps across the arc the punch covers. UV.x runs along the arc,
// UV.y from the inner edge (0) to the outer edge (1).

uniform float progress = 0.0;
uniform float sweep_dir = 1.0;
uniform float heavy = 0.0;
uniform vec4 tint : source_color = vec4(0.75, 0.95, 1.0, 1.0);

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
	float along = sweep_dir > 0.0 ? UV.x : 1.0 - UV.x;
	float swell = mix(0.82, 1.0 + 0.18 * progress + 0.12 * heavy, UV.y);
	float lead = exp(-pow((along - progress * 1.15) * 7.0, 2.0));
	vec2 xz = VERTEX.xz;
	vec2 outward = normalize(xz + vec2(0.0001));
	xz = xz * swell + outward * lead * UV.y * (0.12 + 0.1 * heavy);
	VERTEX.xz = xz;
	VERTEX.y += lead * UV.y * 0.08;
}

void fragment() {
	float along = sweep_dir > 0.0 ? v_uv.x : 1.0 - v_uv.x;
	float head = progress * 1.15;
	float trail = smoothstep(head - 0.55, head, along) * (1.0 - smoothstep(head, head + 0.04, along));
	float body = smoothstep(0.0, 0.5, v_uv.y) * 0.55;
	float rim = smoothstep(0.55, 0.92, v_uv.y) * (1.0 - smoothstep(0.92, 1.0, v_uv.y));
	float fade = 1.0 - smoothstep(0.65, 1.0, progress);
	float a = clamp(trail * (body + rim * 1.6) * fade * (1.3 + 0.5 * heavy), 0.0, 1.0);
	ALBEDO = mix(tint.rgb, vec3(1.0), rim * 0.55) * a * 1.6;
}
