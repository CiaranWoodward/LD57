class_name GruntEnemy
extends EnemyEntity

func _init():
	entity_name = "Grunt"
	entity_id = "grunt_" + str(randi())

func _ready():
	super._ready()
	set_enemy_type(EnemyType.GRUNT)
	
	# Additional grunt-specific configuration
	move_speed = 0.8
	detection_range = 4
	aggression_level = 0.4
	max_health = 8
	current_health = 8 
