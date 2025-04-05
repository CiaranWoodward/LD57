class_name ScoutPlayer
extends PlayerEntity

var vision_range: int = 6 # Scouts have better vision than other classes

func configure_player():
	entity_name = "Scout"
	max_action_points = 4
	action_points = max_action_points
	move_speed = 1.5
	abilities = ["quick_shot", "recon"]
	max_health = 8
	current_health = 8

func get_ability_cost(ability_name: String) -> int:
	match ability_name:
		"quick_shot": return 1
		"recon": return 2
		_: return super.get_ability_cost(ability_name)

func execute_ability(ability_name: String, target) -> bool:
	match ability_name:
		"dash":
			# Dash allows the scout to move quickly to a target position
			# This would normally calculate a path and move there
			print("Scout: Using dash ability")
			
			if target is IsometricTile:
				# In a real implementation, this would dash to the target tile
				print("Scout: Dashing to " + str(target.grid_position))
				
				# Simulate the dash by just teleporting there
				if current_tile:
					current_tile.remove_entity()
				current_tile = target
				grid_position = target.grid_position
				position = target.get_entity_position()
				target.place_entity(self)
				
				return true
			return false
			
		"recon":
			# Recon reveals a large area and any hidden enemies
			assert(game_controller != null, "ScoutPlayer: " + entity_name + " - GameController reference not set")
			assert(game_controller is GameController, "ScoutPlayer: " + entity_name + " - game_controller is not a GameController instance")
			
			# In a real implementation, this would update fog of war or similar
			# For now, we'll just print a message about enemies in range
			var enemies_in_range = []
			
			for enemy in game_controller.enemy_entities:
				if grid_position.distance_to(enemy.grid_position) <= vision_range:
					enemies_in_range.append(enemy)
			
			print("Recon revealed " + str(enemies_in_range.size()) + " enemies")
			# Additional scout-specific effects could be added here
			
			# Could also mark tiles as "scouted" for a few turns
			return true
			
		_:
			push_error("ScoutPlayer: " + entity_name + " - Unknown ability: " + ability_name)
			return false

# Scout moves more efficiently (costs less AP)
func move_along_path(delta: float):
	# Store the original path length
	var original_path_size = path.size()
	
	# Call parent implementation from Entity (skip PlayerEntity)
	super.move_along_path(delta)
	
	# If we completed a step, consume action points with 25% chance of no cost
	if path.size() < original_path_size and original_path_size > 0:
		if randf() > 0.25:  # 25% chance of free movement
			action_points = max(0, action_points - 1)

# Override level up to focus on movement and vision
func on_level_up():
	super.on_level_up()
	vision_range += 1
	move_speed += 0.1 
