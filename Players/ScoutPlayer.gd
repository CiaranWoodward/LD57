class_name ScoutPlayer
extends PlayerEntity

var vision_range: int = 6 # Scouts have better vision than other classes
var line_shot_range: int = 5 # Maximum range for line shot ability

func configure_player():
	entity_name = "Scout"
	max_action_points = 3
	action_points = max_action_points
	max_movement_points = 5  # Scouts have more movement points
	movement_points = max_movement_points
	move_speed = 1.5
	abilities = ["quick_shot", "recon", "drill", "line_shot"]
	max_health = 8
	current_health = 8

func get_ability_cost(ability_name: String) -> int:
	match ability_name:
		"quick_shot": return 1
		"recon": return 2
		"line_shot": return 2
		_: return super.get_ability_cost(ability_name)

func execute_ability(ability_name: String, target) -> bool:
	# First try the parent implementation (for common abilities like drill)
	if super.execute_ability(ability_name, target):
		return true
		
	# Then handle Scout-specific abilities
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
			
		"line_shot":
			# Line shot is a ranged attack that fires in a straight line until it hits something
			if target is IsometricTile:
				# Check if player has enough action points
				var cost = get_ability_cost("line_shot")
				if action_points < cost:
					print("ScoutPlayer: " + entity_name + " - Not enough action points for line_shot")
					return false
				
				# Get target position and calculate direction
				var target_pos = target.grid_position
				var direction = target_pos - grid_position
				
				# Normalize direction to a unit vector
				if direction.x != 0 and direction.y != 0:
					# We only want cardinal directions
					if abs(direction.x) != abs(direction.y):
						print("ScoutPlayer: " + entity_name + " line_shot failed - invalid direction")
						return false
				else:
					if direction.x != 0: direction.x = sign(direction.x)
					if direction.y != 0: direction.y = sign(direction.y)
				
				print("ScoutPlayer: " + entity_name + " firing line_shot in direction " + str(direction))
				
				# Calculate the line of tiles in the direction, up to max range or until we hit a wall
				var current_pos = grid_position
				var has_hit = false
				var distance = 0
				
				# We'll stop if we hit a wall or if we go beyond the maximum range
				while distance < line_shot_range:
					# Move one step in the direction
					current_pos += Vector2i(direction)
					distance += 1
					
					# Get the tile at this position
					var current_tile = isometric_map.get_tile(current_pos)
					
					# If there's no tile or it's a wall, stop
					if not current_tile or not current_tile.is_walkable:
						print("ScoutPlayer: line_shot hit a wall at " + str(current_pos))
						break
					
					# If there's an entity on this tile, damage it and stop
					if current_tile.is_occupied and current_tile.occupying_entity is Entity:
						var entity = current_tile.occupying_entity
						print("ScoutPlayer: line_shot hit entity " + entity.entity_name + " at " + str(current_pos))
						
						# Damage the entity (2 points of damage)
						entity.take_damage(2)
						has_hit = true
						break
				
				return true  # Return true even if we didn't hit anything, as the ability was still used
			
			print("ScoutPlayer: " + entity_name + " line_shot failed - invalid target")
			return false
			
		_:
			return false  # No ability matched

# Override level up to focus on movement and vision
func on_level_up():
	super.on_level_up()
	max_movement_points += 1  # Extra movement bonus
	vision_range += 1
	move_speed += 0.1
	
	# Increase line shot range on every 2nd level
	if level % 2 == 0:
		line_shot_range += 1

# Highlight tiles that can be targeted with line shot
func highlight_line_shot_targets():
	# Get the isometric map
	if not isometric_map:
		print("ScoutPlayer: Cannot highlight line shot targets - isometric_map is null")
		return
		
	# Clear any existing highlights
	if game_controller:
		game_controller.clear_all_highlights()
	
	# Get the directions (cardinal and diagonal)
	var directions = [
		Vector2(1, 0),   # Right
		Vector2(-1, 0),  # Left
		Vector2(0, 1),   # Down
		Vector2(0, -1),  # Up
	]
	
	var highlighted_count = 0
	print("ScoutPlayer: Highlighting line shot targets from " + str(grid_position))
	
	# For each direction, trace a line until we hit a wall or an entity
	for dir in directions:
		var current_pos = grid_position
		var distance = 0
		var path_tiles = []
		var has_target = false
		
		# Trace the line
		while distance < line_shot_range:
			# Move one step in the direction
			current_pos += Vector2i(dir)
			distance += 1
			
			# Get the tile at this position
			var current_tile = isometric_map.get_tile(current_pos)
			
			# If there's no tile or it's a wall, stop
			if not current_tile or not current_tile.is_walkable:
				break
			
			# Add this tile to the path
			path_tiles.append(current_tile)
			
			# If there's an entity on this tile, mark it as target and stop
			if current_tile.is_occupied:
				current_tile.set_action_target(true)
				has_target = true
				highlighted_count += 1
				break
		
		# If we didn't hit anything, mark the furthest tile as target
		if path_tiles.size() > 0 and not has_target:
			path_tiles[-1].set_action_target(true)
			highlighted_count += 1
		
		# Highlight all tiles in the path except the target (which is already highlighted as action_target)
		for i in range(path_tiles.size() - 1):
			if not path_tiles[i].is_action_target:
				path_tiles[i].set_action_target(true)
	
	print("ScoutPlayer: Highlighted " + str(highlighted_count) + " line shot targets and their paths") 
