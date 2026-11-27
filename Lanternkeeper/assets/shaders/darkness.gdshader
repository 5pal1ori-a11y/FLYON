shader_type canvas_item;
// 보드 전체를 덮는 어둠. 광원 주변만 밝게 뚫리고, 따뜻한 빛 번짐을 더한다.

uniform vec4 dark_color : source_color = vec4(0.015, 0.012, 0.03, 0.80);
uniform int light_count = 0;
uniform vec4 lights[16];      // xy: 위치(px), z: 반경(px), w: 세기
uniform vec4 tints[16];       // rgb: 빛 색
uniform float time = 0.0;
uniform vec2 rect_size = vec2(672.0, 864.0);
uniform float ambient = 0.0;  // 전체 밝기 (달빛 등)

void fragment() {
	vec2 p = UV * rect_size;
	float lit = ambient;
	vec3 warm = vec3(0.0);
	float warm_a = 0.0;
	for (int i = 0; i < 16; i++) {
		if (i >= light_count) { break; }
		vec4 L = lights[i];
		float fl = 1.0 + 0.025 * sin(time * 7.3 + float(i) * 1.9) + 0.015 * sin(time * 13.1 + float(i));
		float r = L.z * fl;
		float d = distance(p, L.xy);
		float a = (1.0 - smoothstep(r * 0.45, r, d)) * L.w;
		lit = max(lit, a);
		float g = (1.0 - smoothstep(0.0, r * 0.9, d)) * L.w;
		warm += tints[i].rgb * g;
		warm_a = max(warm_a, g * 0.16);
	}
	float dark_a = dark_color.a * (1.0 - clamp(lit, 0.0, 1.0));
	vec3 col = mix(clamp(warm, 0.0, 1.0), dark_color.rgb, dark_a / max(dark_a + warm_a, 0.0001));
	COLOR = vec4(col, max(dark_a, warm_a));
}
