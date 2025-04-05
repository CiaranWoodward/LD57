class_name BossEnemy
extends EnemyEntity

func _init():
	entity_name = "Boss"
	entity_id = "boss_" + str(randi())

func _ready():
	super._ready()
	enemy_type = EnemyType.BOSS
	
	# Additional boss-specific configuration
	move_speed = 0.6
	detection_range = 8
	aggression_level = 0.9
	max_health = 20
	current_health = 20 
