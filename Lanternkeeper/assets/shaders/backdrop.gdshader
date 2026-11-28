shader_type canvas_item;
// 모든 화면의 배경: 먹빛 밤 + 아래에서 번지는 등불빛 + 천천히 흐르는 안개.

uniform vec4 top_col : source_color = vec4(0.043, 0.039, 0.086, 1.0);
uniform vec4 bot_col : source_color = vec4(0.10, 0.082, 0.19, 1.0);
uniform vec4 glow_col : source_color = vec4(1.0, 0.6, 0.24, 1.0);
uniform vec2 glow_pos = vec2(0.5, 1.08);
uniform float glow_amt = 0.30;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	vec3 c = mix(top_col.rgb, bot_col.rgb, smoothstep(0.0, 1.0, uv.y));
	vec2 d = (uv - glow_pos) * vec2(0.62, 1.0);
	float flick = 1.0 + 0.04 * sin(TIME * 5.3) + 0.03 * sin(TIME * 8.7);
	c += glow_col.rgb * exp(-dot(d, d) * 3.2) * glow_amt * flick;
	float n = noise(uv * vec2(2.5, 5.0) + vec2(TIME * 0.015, 0.0)) * 0.6
		+ noise(uv * vec2(6.0, 11.0) - vec2(TIME * 0.022, TIME * 0.008)) * 0.4;
	c += glow_col.rgb * (n - 0.5) * 0.045;
	float v = smoothstep(1.15, 0.35, length((uv - vec2(0.5, 0.55)) * vec2(1.0, 1.15)));
	c *= mix(0.6, 1.0, v);
	c += (hash(uv * vec2(733.0, 1291.0)) - 0.5) * 0.012;
	COLOR = vec4(c, 1.0);
}
