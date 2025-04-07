class_name HellBombChaserEnemy
extends BaseBombEnemy

# Chaser-specific properties
var explosion_range: int = 1  # Distance to explode when near a player

func _init():
	entity_name = "Hell Bomb Chaser"
	entity_id = "hellbombchaser_" + str(randi())

func _ready():
	super._ready()
	# Use the HELLBOMB_CHASER type from the enum
	enemy_type = EnemyType.HELLBOMB_CHASER
	
	# Chaser configuration
	move_speed = 1.4  # Moves faster than a regular minion
	detection_range = 8
	aggression_level = 1.0  # Always highly aggressive
	max_health = 4  # Less health than regular bombs
	current_health = 4

# Override process_turn to implement chaser-specific behavior
func process_turn(player_entities: Array):
	# Reset movement
	is_moving = false
	path = []
	
	# Filter player entities to only include those on the same level
	var same_level_players = []
	for player in player_entities:
		if player.current_level == current_level:
			same_level_players.append(player)
	
	# Check for players in close proximity to explode
	for player in same_level_players:
		var distance = grid_position.distance_to(player.grid_position)
		# If a player is within explosion range, explode immediately
		if distance <= explosion_range:
			print("HellBombChaserEnemy: Player detected in explosion range, exploding!")
			explode()
			return false  # No movement
	
	# Find the closest player to chase
	var closest_player = find_closest_player(same_level_players)
	
	if closest_player:
		# Player detected - pursue
		target_entity = closest_player
		last_known_player_position = closest_player.grid_position
		
		if alert_status != "alert":
			set_alert_status("alert")
		
		# Calculate path to player
		pursue_target()
		return is_moving
	else:
		# No player in sight, move to last known position or patrol
		if alert_status == "alert" and last_known_player_position != Vector2i(-1, -1):
			# Move to last known position
			var path_to_last_known = isometric_map.find_path(grid_position, last_known_player_position)
			if path_to_last_known.size() > 0:
				path = path_to_last_known
				is_moving = true
			else:
				# Can't reach last known position, go back to patrol
				last_known_player_position = Vector2i(-1, -1)
				set_alert_status("suspicious")
				follow_patrol_path()
		else:
			# Normal patrol behavior
			follow_patrol_path()
	
	return is_moving

# Return the entity type for better debugging
func get_bomb_type() -> String:
	return "HellBombChaserEnemy" 
