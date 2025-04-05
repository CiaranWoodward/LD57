class_name HeavyPlayer
extends PlayerEntity

func configure_player():
	entity_name = "Heavy"
	max_action_points = 2
	action_points = max_action_points
	move_speed = 0.7
	abilities = ["shield_bash", "taunt"]
	max_health = 15
	current_health = 15

func get_ability_cost(ability_name: String) -> int:
	match ability_name:
		"shield_bash": return 1
		"taunt": return 1
		_: return super.get_ability_cost(ability_name)

func execute_ability(ability_name: String, target) -> bool:
	match ability_name:
		"shield_bash":
			# Shield bash pushes an enemy back and stuns them
			if target is EnemyEntity:
				# Calculate direction from player to target
				var direction = (target.grid_position - grid_position).normalized()
				var push_position = target.grid_position + Vector2i(direction)
				
				# Check if the push position is valid
				var push_tile = isometric_map.get_tile(push_position)
				if push_tile and push_tile.is_walkable and not push_tile.is_occupied:
					# Move the enemy to the new position
					target.place_on_tile(push_tile)
					# Apply stun effect
					target.apply_status_effect("stunned", 1) # 1 turn duration
					return true
			return false
			
		"taunt":
			# Taunt forces nearby enemies to target this player
			var nearby_enemies = get_nearby_enemies(3) # 3 tile radius
			for enemy in nearby_enemies:
				if enemy is EnemyEntity:
					enemy.target_entity = self
					enemy.set_alert_status("alert")
			return nearby_enemies.size() > 0
			
		_:
			return false

# Helper to find nearby enemies
func get_nearby_enemies(radius: int) -> Array:
	var nearby = []
	
	# This assumes the GameController is a parent or has a reference to all enemies
	var game_controller = get_parent()
	if game_controller is GameController:
		for enemy in game_controller.enemy_entities:
			if grid_position.distance_to(enemy.grid_position) <= radius:
				nearby.append(enemy)
	
	return nearby

# Override level up to focus on defense/tankiness
func on_level_up():
	super.on_level_up()
	max_health += 2
	current_health += 2 
