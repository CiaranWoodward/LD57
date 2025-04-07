class_name HeavyPlayer
extends PlayerEntity

func configure_player():
	entity_name = "Heavy"
	max_action_points = 4  # Heavy has more action points for abilities
	action_points = max_action_points
	max_movement_points = 2  # But limited movement
	movement_points = max_movement_points
	move_speed = 0.7
	abilities = ["drill", "drill_smash"]
	max_health = 15
	current_health = 15

func get_ability_cost(ability_name: String) -> int:
	match ability_name:
		"drill_smash": return 2
		_: return super.get_ability_cost(ability_name)

func execute_ability(ability_name: String, target) -> bool:
	if super.execute_ability(ability_name, target):
		return true
		
	match ability_name:
		"drill_smash":
			# Drill smash damages and pushes enemies in the target area
			if target is IsometricTile:
				# Check if the target tile is in one of the cardinal directions
				var direction = target.grid_position - grid_position
				if abs(direction.x) + abs(direction.y) != 1:
					print("HeavyPlayer: " + entity_name + " drill_smash failed - target not in cardinal direction")
					return false
					
				# Calculate the tiles that would be affected (target + left/right of target)
				var affected_tiles = [target]
				
				# Find tiles to the "sides" of the target depending on direction
				if direction.x != 0:  # Horizontal direction
					var left_pos = target.grid_position + Vector2i(0, -1)
					var right_pos = target.grid_position + Vector2i(0, 1)
					var left_tile = isometric_map.get_tile(left_pos)
					var right_tile = isometric_map.get_tile(right_pos)
					if left_tile: affected_tiles.append(left_tile)
					if right_tile: affected_tiles.append(right_tile)
				else:  # Vertical direction
					var left_pos = target.grid_position + Vector2i(-1, 0)
					var right_pos = target.grid_position + Vector2i(1, 0)
					var left_tile = isometric_map.get_tile(left_pos)
					var right_tile = isometric_map.get_tile(right_pos)
					if left_tile: affected_tiles.append(left_tile)
					if right_tile: affected_tiles.append(right_tile)
				
				# Process each affected tile
				var hit_something = false
				print("HeavyPlayer: " + entity_name + " using drill_smash on " + str(affected_tiles.size()) + " tiles")
				
				for tile in affected_tiles:
					print("HeavyPlayer: Checking tile at " + str(tile.grid_position) + ", occupied: " + str(tile.is_occupied))
					
					if tile.is_occupied and tile.occupying_entity is Entity:
						var entity = tile.occupying_entity
						print("HeavyPlayer: Found entity " + entity.entity_name + " at " + str(tile.grid_position))
						
						# Damage the entity (3 points of damage)
						entity.take_damage(3)
						hit_something = true
						print("HeavyPlayer: Dealt 3 damage to " + entity.entity_name)
						
						# Push the entity away if still alive
						if not entity.is_dead:
							# Calculate push position (1 tile away from player in the same direction)
							var push_direction = direction
							var push_position = entity.grid_position + Vector2i(round(push_direction.x), round(push_direction.y))
							
							# Check if the push position is valid
							var push_tile = isometric_map.get_tile(push_position)
							if push_tile and push_tile.is_walkable and not push_tile.is_occupied:
								# Move the entity to the new position
								print("HeavyPlayer: Pushing " + entity.entity_name + " from " + str(entity.grid_position) + " to " + str(push_position))
								entity.place_on_tile(push_tile)
							else:
								print("HeavyPlayer: Cannot push " + entity.entity_name + " - destination tile invalid or occupied")
				
				if hit_something:
					print("HeavyPlayer: " + entity_name + " drill_smash succeeded - hit at least one entity")
				else:
					print("HeavyPlayer: " + entity_name + " drill_smash hit nothing")
				
				return hit_something  # Return true if we hit at least one entity
			
			print("HeavyPlayer: " + entity_name + " drill_smash failed - invalid target")
			return false
			
		_:
			return false

# Helper to find nearby enemies
func get_nearby_enemies(radius: int) -> Array:
	var nearby = []
	
	# Use the game_controller reference directly with assertion
	assert(game_controller != null, "HeavyPlayer: " + entity_name + " - GameController reference not set")
	assert(game_controller is GameController, "HeavyPlayer: " + entity_name + " - game_controller is not a GameController instance")
	
	for enemy in game_controller.enemy_entities:
		if grid_position.distance_to(enemy.grid_position) <= radius:
			nearby.append(enemy)
	
	return nearby

# Heavy has slower movement but more efficient with action points
func on_level_up():
	# Increase health more than action points
	max_health += 2
	current_health += 2
	
	# Custom allocation favoring action points over movement
	max_action_points += 1
	if level % 2 == 0:  # Only every other level
		max_movement_points += 1 

# Highlight tiles that can be targeted with drill smash
func highlight_drill_smash_targets():
	# Get the isometric map
	if not isometric_map:
		print("HeavyPlayer: Cannot highlight drill smash targets - isometric_map is null")
		return
		
	# Clear any existing highlights
	if game_controller:
		game_controller.clear_all_highlights()
	
	# Get the cardinal direction tiles
	var directions = [
		Vector2i(1, 0),  # Right
		Vector2i(-1, 0), # Left
		Vector2i(0, 1),  # Down
		Vector2i(0, -1)  # Up
	]
	
	# Highlight each valid tile
	var highlighted_count = 0
	print("HeavyPlayer: Highlighting drill smash targets from " + str(grid_position))
	
	for dir in directions:
		var target_pos = grid_position + dir
		var target_tile = isometric_map.get_tile(target_pos)
		
		if target_tile:
			# Check if this direction or the tiles to its sides contain enemies
			var has_entity = false
			var affected_tiles = [target_tile]
			
			# Find tiles to the "sides" of the target depending on direction
			if dir.x != 0:  # Horizontal direction
				var left_pos = target_pos + Vector2i(0, -1)
				var right_pos = target_pos + Vector2i(0, 1)
				var left_tile = isometric_map.get_tile(left_pos)
				var right_tile = isometric_map.get_tile(right_pos)
				if left_tile: affected_tiles.append(left_tile)
				if right_tile: affected_tiles.append(right_tile)
			else:  # Vertical direction
				var left_pos = target_pos + Vector2i(-1, 0)
				var right_pos = target_pos + Vector2i(1, 0)
				var left_tile = isometric_map.get_tile(left_pos)
				var right_tile = isometric_map.get_tile(right_pos)
				if left_tile: affected_tiles.append(left_tile)
				if right_tile: affected_tiles.append(right_tile)
			
			# Check if any affected tile has an enemy
			for tile in affected_tiles:
				if tile.is_occupied:
					has_entity = true
					break
			
			# Always highlight the cardinal direction tiles, even if they don't contain enemies
			# This allows the player to use the ability in any direction
			target_tile.set_action_target(true)
			highlighted_count += 1
			print("HeavyPlayer: Highlighted target at " + str(target_pos) + 
				" with entity nearby: " + str(has_entity))
	
	print("HeavyPlayer: Highlighted " + str(highlighted_count) + " drill smash targets") 
