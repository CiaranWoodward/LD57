class_name MinionEnemy
extends EnemyEntity

func _init():
	entity_name = "Minion"
	entity_id = "minion_" + str(randi())

func _ready():
	super._ready()
	set_enemy_type(EnemyType.MINION)
	
	# Additional minion-specific configuration
	move_speed = 1.2
	detection_range = 3
	aggression_level = 0.3
	max_health = 5
	current_health = 5 
