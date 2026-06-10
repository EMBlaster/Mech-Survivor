extends ColorRect

const GRID_SPACING: float = 100.0
const GRID_COLOR: Color = Color(1, 1, 1, 0.08)

func _draw() -> void:
	var x := 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_COLOR, 1.0)
		x += GRID_SPACING
	var y := 0.0
	while y <= size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID_COLOR, 1.0)
		y += GRID_SPACING
