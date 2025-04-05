class_name EliteEnemy
extends EnemyEntity

func _init():
	entity_name = "Elite"
	entity_id = "elite_" + str(randi())

func _ready():
	super._ready()
	set_enemy_type(EnemyType.ELITE)
	
	# Additional elite-specific configuration
	move_speed = 1.0
	detection_range = 6
	aggression_level = 0.7
	max_health = 12
	current_health = 12 
