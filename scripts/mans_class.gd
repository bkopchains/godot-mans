class_name MansClass
extends Resource

@export var name: String
@export var max_hp: int = 100
@export var hp: int = max_hp
@export var attack_power: int = 10
@export var speed: float = 100.0
@export var class_type: ClassType = ClassType.MAN
@export var weak_against: ClassType = ClassType.BRUTE  # Each class is weak against another

enum ClassType {
	MAN,    # 0
	WIZARD, # 1
	BRUTE,  # 2
	DOG,    # 3
	BABY    # 4
}
