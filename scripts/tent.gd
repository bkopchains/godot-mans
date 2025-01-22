class_name Tent
extends Node2D

@onready var flag_sprite: Sprite2D = $FlagSprite
@onready var drop_zone: Area2D = $DropZone
@onready var spawn_shape: CollisionShape2D = $SpawnZone/SpawnShape

@export var game: Game;
@export var team_color_index: int = 0:
	set(value):
		team_color_index = value
		update_color()

func _ready() -> void:
	game.team_bases[team_color_index] = self;
	update_color();

func update_color() -> void:
	if flag_sprite:
		var mat = flag_sprite.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("modulate", Global.TEAM_COLORS[team_color_index])


func _on_drop_zone_area_entered(area: Area2D) -> void:
	if area is Flag:
		var flag = (area as Flag);
		if flag.team_color_index != team_color_index:
			# Capture dat flag
			flag.carrier.heal(50);
			flag.detach();
			game.capture_flag(team_color_index, flag);
			# Defer the spawn on the correct team's tent
			var enemy_tent = game.team_bases[flag.team_color_index] as Tent;
			enemy_tent.call_deferred("spawn_flag");
			
		
func spawn_flag() -> void:
	var spawn_point = get_random_point(spawn_shape);
	game.spawn_flag(team_color_index, spawn_point);

func get_random_point(shape_node: CollisionShape2D) -> Vector2:
	if not shape_node or not shape_node.shape or not (shape_node.shape is RectangleShape2D):
		push_error("CollisionShape2D is missing or not a RectangleShape2D!")
		return global_position  # Fallback

	var rect: RectangleShape2D = shape_node.shape
	var half_extents = rect.size / 2  # RectangleShape2D uses 'size', not extents

	# Pick a random point inside the rectangle
	var local_point = Vector2(
		randf_range(-half_extents.x, half_extents.x),
		randf_range(-half_extents.y, half_extents.y)
	)

	# Convert to global position
	return shape_node.global_position + local_point
