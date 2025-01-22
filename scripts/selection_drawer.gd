extends Node2D

var is_selecting := false
var selection_rect: Rect2

func _draw() -> void:
    if is_selecting:
        var shadow_rect = Rect2(
            Vector2(selection_rect.position.x+1, selection_rect.position.y+1), 
            selection_rect.size
        )
        draw_rect(shadow_rect, Color(0, 0, 0, 0.2))  # shadow
        draw_rect(selection_rect, Color(Global.HIGHLIGHT_COLOR, 0.2))  # Fill
        draw_rect(selection_rect, Color(Global.HIGHLIGHT_COLOR, 0.8), false)  # Outline