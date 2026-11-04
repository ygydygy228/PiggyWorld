shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0);
uniform float snow : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.rgb * tint.rgb;
	float l = dot(rgb, vec3(0.333));
	vec3 white = vec3(0.90, 0.95, 1.0) * (0.82 + l * 0.35);
	COLOR = vec4(mix(rgb, white, snow), c.a);
}
