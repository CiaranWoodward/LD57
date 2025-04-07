class_name HellBombEnemy
extends BaseBombEnemy

func _init():
	entity_name = "Hell Bomb"
	entity_id = "hellbomb_" + str(randi())

func _ready():
	super._ready()
	# Set the correct enemy type
	enemy_type = EnemyType.HELLBOMB
	
	# Additional bomb-specific configuration
	move_speed = 0.0  # Cannot move
	detection_range = 1  # Only detects players in adjacent tiles
	aggression_level = 1.0  # Always on high alert
	max_health = 6
	current_health = 6

# Override process_turn to implement bomb-specific behavior
func process_turn(player_entities: Array):
	# Reset movement
	is_moving = false
	path = []
	
	# Filter player entities to only include those on the same level
	var same_level_players = []
	for player in player_entities:
		if player.current_level == current_level:
			same_level_players.append(player)
	
	# Check for players in adjacent tiles
	for player in same_level_players:
		var distance = grid_position.distance_to(player.grid_position)
		# If a player is adjacent (Manhattan distance of 1), explode immediately
		if distance <= 1:
			print("HellBombEnemy: Player detected in adjacent tile, exploding!")
			explode()
			return false  # No movement
	
	# Bomb doesn't move or do anything else
	return false

# Override pursue_target to do nothing (bombs don't move)
func pursue_target():
	# Do nothing - bombs don't move
	pass

# Override follow_patrol_path to do nothing (bombs don't patrol)
func follow_patrol_path():
	# Do nothing - bombs don't move
	pass

# Return the entity type for better debugging
func get_bomb_type() -> String:
	return "HellBombEnemy" 
