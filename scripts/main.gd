extends Node2D

@export var mans_scene: PackedScene = preload("res://scenes/mans.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Create new mans at mouse position
			var new_mans = mans_scene.instantiate()
			new_mans.position = get_global_mouse_position()
			add_child(new_mans)
			# Prevent the event from propagating to other nodes
			get_viewport().set_input_as_handled()
