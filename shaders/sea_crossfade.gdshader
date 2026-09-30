shader_type canvas_item;
// Funde dos fotogramas del fondo solo donde la máscara lo permite (franja de mar).
uniform sampler2D frame_a : filter_linear;
uniform sampler2D frame_b : filter_linear;
uniform sampler2D mask : filter_linear;
uniform float blend : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = mix(texture(frame_a, UV), texture(frame_b, UV), blend);
	COLOR = vec4(c.rgb, texture(mask, UV).r);
}
