shader_type canvas_item;

// Customizable properties via script
uniform vec4 outline_color: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width: hint_range(0.0, 10.0) = 1.0;
uniform bool enabled = false;
uniform vec4 modulate: source_color = vec4(1.0, 1.0, 1.0, 1.0);

// for each pixel?
void fragment() {
	// Get color of current pixel
	vec4 col = texture(TEXTURE, UV);

	// Get size of one pixel in uv
	vec2 ps = TEXTURE_PIXEL_SIZE;

	// Apply modulation first
	col *= modulate;

	if (enabled) {
		float a;
		float maxa = col.a;

		// Check all pixels surrounding current
		for (float x = -outline_width; x <= outline_width; x++) {
			for (float y = -outline_width; y <= outline_width; y++) {
				// Skip center
				if(x == 0.0 && y == 0.0) continue;

				// Get alpha of neighbor
				a = texture(TEXTURE, UV + vec2(x, y) * ps).a;

				// Hold on to max alpha
				maxa = max(a, maxa);
			}
		}

		// Create outline w/ alpha based on neighbors
		vec4 outline = outline_color;
		// Only outline where there's no pixels
		outline.a *= maxa - col.a;

		// Blend original and outline
		col = mix(col, outline, outline.a);
	}
	COLOR = col;
}