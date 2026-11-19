shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.42;
uniform float scan_strength : hint_range(0.0, 0.3) = 0.030;
uniform float noise_strength : hint_range(0.0, 0.2) = 0.016;
uniform float aberration : hint_range(0.0, 0.01) = 0.0016;
uniform float tint_amount : hint_range(0.0, 1.0) = 0.12;
uniform vec3 tint_color = vec3(0.62, 0.82, 1.0);
uniform float flash = 0.0;
uniform vec3 flash_color = vec3(1.0, 0.3, 0.2);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(aberration, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(aberration, 0.0)).b;

	// 扫描线（每 3 像素一条）
	float s = sin(uv.y * 1000.0 * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scan_strength * s;

	// 噪点
	float n = hash(uv * vec2(1920.0, 1080.0) + vec2(TIME * 37.0, TIME * 61.0));
	col += (n - 0.5) * noise_strength;

	// 暗角
	vec2 d = uv - 0.5;
	float v = smoothstep(0.95, 0.28, length(d));
	col *= mix(1.0, v, vignette_strength);

	// 冷色倾向
	col = mix(col, col * tint_color, tint_amount);

	// 受击闪红
	col = mix(col, flash_color, flash);

	COLOR = vec4(col, 1.0);
}
