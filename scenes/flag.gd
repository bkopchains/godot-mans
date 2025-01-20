class_name Flag
extends Area2D

@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow

var colors = [
	Color(1, 0.3, 0.3),  # Red
	Color(0.3, 0.3, 1),  # Blue
	Color(0.3, 1, 0.3),  # Green
	Color(1, 1, 0.3),    # Yellow
	Color(1, 0.3, 1),    # Purple
]

var team_color_index: int = 0:
	set(value):
		team_color_index = value
		update_color()

var carrier: Mans = null

signal flag_dropped(flag: Flag)
signal flag_captured(flag: Flag, by_team: int)

func _ready() -> void:
	add_to_group("flags")
	update_color()
	shadow.visible = carrier == null

func update_color() -> void:
	if sprite:
		var material = sprite.material as ShaderMaterial
		if material:
			material.set_shader_parameter("modulate", colors[team_color_index])

func _physics_process(_delta: float) -> void:
	if carrier:
		if is_instance_valid(carrier):
			# Follow carrier with slight offset
			global_position = carrier.global_position + Vector2(0, -8)
		else:
			# Carrier was freed, detach the flag
			detach()

func attach_to(mans: Mans) -> void:
	if carrier:
		carrier.carried_flag = null
	carrier = mans
	mans.carried_flag = self
	shadow.visible = false
	
	if mans.team_color_index != team_color_index:
		flag_captured.emit(self, mans.team_color_index)

func detach() -> void:
	if carrier and is_instance_valid(carrier):
		carrier.carried_flag = null
	carrier = null
	shadow.visible = true
	flag_dropped.emit(self)

# Called when an enemy mans attacks the flag
func attack(attacker: Mans) -> void:
	if attacker.carried_flag:  # Don't allow pickup if already carrying
		return
		
	if carrier and carrier.team_color_index != attacker.team_color_index:
		attach_to(attacker)
		flag_captured.emit(self, attacker.team_color_index)
	elif !carrier:  # Allow picking up dropped flags
		attach_to(attacker)
		if attacker.team_color_index != team_color_index:
			flag_captured.emit(self, attacker.team_color_index)

func _on_body_entered(body: Node2D) -> void:
	if body is Mans and !body.carried_flag:  # Only allow pickup if not carrying
		if !carrier:  # Flag is dropped
			attach_to(body)
