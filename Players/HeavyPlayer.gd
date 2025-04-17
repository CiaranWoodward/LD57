class_name HeavyPlayer
extends PlayerEntity

var hover_target: IsometricTile = null  # Track currently hovered target for AOE preview
var defend_active: bool = false  # Track if defend ability is active
var animation_tree: AnimationTree
var animation_state_machine: AnimationNodeStateMachinePlayback

func configure_player():
	entity_name = "Heavy"
	max_action_points = 4  # Heavy has more action points for abilities
	action_points = max_action_points
	max_movement_points = 2  # But limited movement
	movement_points = max_movement_points
	move_speed = 0.7
	abilities = ["drill", "drill_smash", "big_drill", "defend"]
	max_health = 15
	current_health = 15
	
	# Setup animation tree
	animation_tree = $Sprite2D/AnimationTree
	animation_tree.active = true
	animation_state_machine = animation_tree["parameters/playback"]

func get_ability_cost(ability_name: String) -> int:
	match ability_name:
		"drill_smash": return 2
		"big_drill": return 3
		"defend": return 1
		"charge_attack": return 2
		_: return super.get_ability_cost(ability_name)

# Override to provide specific descriptions for Heavy abilities
func get_ability_description(ability_name: String) -> String:
	var cost = get_ability_cost(ability_name)
	match ability_name:
		"drill_smash": 
			if has_meta("drill_smash_description"):
				return get_meta("drill_smash_description")
			return "Drill Smash: AOE damage nearby (Cost: " + str(cost) + " AP)"
		"big_drill": 
			if has_meta("big_drill_description"):
				return get_meta("big_drill_description")
			return "Big Drill: Takes 4 turns, brings adjacent allies down too (Cost: " + str(cost) + " AP)"
		"defend": 
			return "Defend: Increase defense until next turn (Cost: " + str(cost) + " AP)"
		"charge_attack":
			return "Charge Attack: Rush toward enemy and deal damage (Cost: " + str(cost) + " AP)"
		_: 
			return super.get_ability_description(ability_name)

func execute_ability(ability_name: String, target) -> bool:
	if super.execute_ability(ability_name, target):
		# For drill ability, play the drilling animation
		if ability_name == "drill":
			if animation_state_machine:
				animation_state_machine.travel("Drilling")
		return true
		
	match ability_name:
		"defend":
			# Activate the defend ability, which halves damage until next turn
			print("HeavyPlayer: " + entity_name + " activates defend")
			defend_active = true
			
			# Apply a visual effect to show the defend status
			modulate = Color(0.7, 0.7, 1.2)  # Bluish tint to indicate defense mode
			
			# Play the shielding animation
			if animation_state_machine:
				animation_state_machine.travel("Shielding")
				
			return true
			
		"drill_smash":
			# Drill smash damages and pushes enemies in the target area
			if target is IsometricTile:
				# Check if the target tile is in one of the cardinal directions
				var direction = target.grid_position - grid_position
				if abs(direction.x) + abs(direction.y) != 1:
					print("HeavyPlayer: " + entity_name + " drill_smash failed - target not in cardinal direction")
					return false
					
				# Get all tiles that would be affected using our helper function
				var affected_tiles = _get_affected_tiles_for_direction(direction)
				print("HeavyPlayer: " + entity_name + " using drill_smash on " + str(affected_tiles.size()) + " tiles")
				
				# Play the swing animation for drill smash
				if animation_state_machine:
					animation_state_machine.travel("Swing")
				
				# Process each affected tile
				var hit_something = false
				var pushed_entities = []  # Keep track of entities we've already pushed
				
				for tile in affected_tiles:
					print("HeavyPlayer: Checking tile at " + str(tile.grid_position) + ", occupied: " + str(tile.is_occupied))
					
					if tile.is_occupied and tile.occupying_entity is Entity:
						var entity = tile.occupying_entity
						print("HeavyPlayer: Found entity " + entity.entity_name + " at " + str(tile.grid_position))
						
						# Damage the entity (3 points of damage)
						entity.take_damage(3)
						hit_something = true
						print("HeavyPlayer: Dealt 3 damage to " + entity.entity_name)
						
						# Push the entity away if still alive and hasn't been pushed yet
						if not entity.is_dead and not (entity in pushed_entities):
							# Add to the list of pushed entities
							pushed_entities.append(entity)
							
							# Ensure push is exactly 1 tile in the nearest cardinal direction
							var push_position = entity.grid_position + Vector2i(
								clamp(round(direction.x), -1, 1),
								clamp(round(direction.y), -1, 1)
							)
							
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
			
		"big_drill":
			# Check if we can drill (if there's a valid level below)
			if not game_controller or not game_controller.level_manager:
				print("HeavyPlayer: " + entity_name + " - Cannot big drill, game_controller or level_manager not set")
				return false
				
			# Check if the tile below is valid for drilling
			if not game_controller.level_manager.has_valid_tile_below(current_level, grid_position):
				print("HeavyPlayer: " + entity_name + " - Cannot big drill, no valid tile below")
				return false
				
			# Start the drilling process - takes longer than regular drill
			start_big_drilling(4)  # Takes 4 turns to complete
			
			# Play drilling animation
			if animation_state_machine:
				animation_state_machine.travel("Drilling")
			
			# End the turn immediately after starting to drill
			call_deferred("finish_turn")
			return true
			
		"charge_attack":
			# Charge attack rushes toward an enemy and deals damage
			if target is IsometricTile and target.is_occupied and target.occupying_entity is Entity:
				var target_entity = target.occupying_entity
				var target_position = target.grid_position
				
				# Calculate the direction from player to target
				var direction = target_position - grid_position
				
				# We want to normalize to a cardinal direction
				var normalized_direction = Vector2i(0, 0)
				if abs(direction.x) > abs(direction.y):
					normalized_direction.x = sign(direction.x)
				else:
					normalized_direction.y = sign(direction.y)
				
				# Determine the position adjacent to the target in the direction we're coming from
				var charge_position = target_position - normalized_direction
				var charge_tile = isometric_map.get_tile(charge_position)
				
				# Make sure the charge position is valid
				if charge_tile and charge_tile.is_walkable and not charge_tile.is_occupied:
					# First move to the charge position
					print("HeavyPlayer: " + entity_name + " charging from " + str(grid_position) + " to " + str(charge_position))
					
					# Store original tile for reference
					var original_tile = current_tile
					
					# Actually move the player to the charge position
					place_on_tile(charge_tile)
					
					# Play the charge animation
					if animation_state_machine:
						animation_state_machine.travel("Swing")  # Reuse swing animation for now
					
					# Damage the target entity
					target_entity.take_damage(4)  # More damage than drill_smash
					print("HeavyPlayer: " + entity_name + " charge attacked " + target_entity.entity_name + " for 4 damage")
					
					# Push the target entity back if still alive
					if not target_entity.is_dead:
						# Calculate push position (1 tile away from target in the same direction)
						var push_position = target_position + normalized_direction
						
						# Check if the push position is valid
						var push_tile = isometric_map.get_tile(push_position)
						if push_tile and push_tile.is_walkable and not push_tile.is_occupied:
							# Move the entity to the new position
							print("HeavyPlayer: Pushing " + target_entity.entity_name + " from " + str(target_position) + " to " + str(push_position))
							target_entity.place_on_tile(push_tile)
						else:
							print("HeavyPlayer: Cannot push " + target_entity.entity_name + " - destination tile invalid or occupied")
					
					return true
				else:
					print("HeavyPlayer: " + entity_name + " charge_attack failed - no valid position to charge to")
				
			print("HeavyPlayer: " + entity_name + " charge_attack failed - invalid target")
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
			
			# Connect highlight change signal for AOE preview
			if not target_tile.is_connected("tile_highlight_change", Callable(self, "_on_tile_highlight_change")):
				target_tile.connect("tile_highlight_change", Callable(self, "_on_tile_highlight_change"))
				
			highlighted_count += 1
			print("HeavyPlayer: Highlighted target at " + str(target_pos) + 
				" with entity nearby: " + str(has_entity))
	
	print("HeavyPlayer: Highlighted " + str(highlighted_count) + " drill smash targets") 

# Handle tile highlight changes to show AOE preview
func _on_tile_highlight_change(tile: IsometricTile):
	# If hovering on a target tile, show AOE preview
	if tile.is_action_target and tile.is_hovered:
		# If we're already hovering a tile, clear its AOE preview first
		if hover_target != null and hover_target != tile:
			# Clear the AOE preview of the previous hovered tile
			var direction = hover_target.grid_position - grid_position
			clear_drill_smash_aoe(direction)
		
		# Set new hover target and show its AOE
		hover_target = tile
		highlight_drill_smash_aoe(tile.grid_position - grid_position)
	
	# When no longer hovering a target tile, clear AOE preview
	elif hover_target == tile and not tile.is_hovered:
		# Calculate affected tiles based on direction
		var direction = tile.grid_position - grid_position
		clear_drill_smash_aoe(direction)
		
		hover_target = null

# Clear the AOE highlighting for drill_smash in the given direction
func clear_drill_smash_aoe(direction: Vector2i):
	if not isometric_map:
		return
		
	print("HeavyPlayer: Clearing drill_smash AOE preview in direction " + str(direction))
	
	# Get affected tiles based on direction
	var affected_tiles = _get_affected_tiles_for_direction(direction)
	
	# Clear highlighting on all tiles in the affected area
	for aoe_tile in affected_tiles:
		# Don't modify the target tile itself, only the side tiles
		if aoe_tile != hover_target and not aoe_tile.is_action_target:
			aoe_tile.set_attackable(false)

# Highlight the AOE area for drill_smash in the given direction
func highlight_drill_smash_aoe(direction: Vector2i):
	if not isometric_map:
		return
		
	print("HeavyPlayer: Showing drill_smash AOE preview in direction " + str(direction))
	
	# Get affected tiles based on direction
	var affected_tiles = _get_affected_tiles_for_direction(direction)
	
	# Highlight all tiles in the affected area
	for tile in affected_tiles:
		# Don't modify the target tile itself, only the side tiles
		if tile != hover_target and not tile.is_action_target:
			tile.set_attackable(true)

# Helper function to get affected tiles for a direction
func _get_affected_tiles_for_direction(direction: Vector2i) -> Array:
	var affected_tiles = []
	
	# Target position is player position + direction
	var target_pos = grid_position + direction
	var target_tile = isometric_map.get_tile(target_pos)
	
	if target_tile:
		affected_tiles.append(target_tile)
		
		# Find tiles to the "sides" of the target depending on direction
		if direction.x != 0:  # Horizontal direction
			# Add side tiles
			var left_pos = target_pos + Vector2i(0, -1)
			var right_pos = target_pos + Vector2i(0, 1)
			var left_tile = isometric_map.get_tile(left_pos)
			var right_tile = isometric_map.get_tile(right_pos)
			if left_tile: affected_tiles.append(left_tile)
			if right_tile: affected_tiles.append(right_tile)
			
			# If enhanced, add additional tiles in all three directions
			if has_meta("enhanced_drill_smash"):
				# Extended main direction
				var extended_pos = target_pos + direction
				var extended_tile = isometric_map.get_tile(extended_pos)
				if extended_tile: affected_tiles.append(extended_tile)
				
				# Extended left side
				var extended_left_pos = extended_pos + Vector2i(0, -1)
				var extended_left_tile = isometric_map.get_tile(extended_left_pos)
				if extended_left_tile: affected_tiles.append(extended_left_tile)
				
				# Extended right side
				var extended_right_pos = extended_pos + Vector2i(0, 1)
				var extended_right_tile = isometric_map.get_tile(extended_right_pos)
				if extended_right_tile: affected_tiles.append(extended_right_tile)
		else:  # Vertical direction
			# Add side tiles
			var left_pos = target_pos + Vector2i(-1, 0)
			var right_pos = target_pos + Vector2i(1, 0)
			var left_tile = isometric_map.get_tile(left_pos)
			var right_tile = isometric_map.get_tile(right_pos)
			if left_tile: affected_tiles.append(left_tile)
			if right_tile: affected_tiles.append(right_tile)
			
			# If enhanced, add additional tiles in all three directions
			if has_meta("enhanced_drill_smash"):
				# Extended main direction
				var extended_pos = target_pos + direction
				var extended_tile = isometric_map.get_tile(extended_pos)
				if extended_tile: affected_tiles.append(extended_tile)
				
				# Extended left side
				var extended_left_pos = extended_pos + Vector2i(-1, 0)
				var extended_left_tile = isometric_map.get_tile(extended_left_pos)
				if extended_left_tile: affected_tiles.append(extended_left_tile)
				
				# Extended right side
				var extended_right_pos = extended_pos + Vector2i(1, 0)
				var extended_right_tile = isometric_map.get_tile(extended_right_pos)
				if extended_right_tile: affected_tiles.append(extended_right_tile)
	
	return affected_tiles 

# Helper to find adjacent player allies
func get_adjacent_players() -> Array:
	var range_distance = get_big_drill_range()
	return get_allies_in_range(range_distance)

# Starts the big drilling operation, which affects adjacent players too
func start_big_drilling(turns_required: int = 4):
	print("HeavyPlayer: " + entity_name + " starting big drill operation")
	
	# Check for adjacent player allies - just for visual feedback
	var adjacent_allies = get_adjacent_players()
	print("HeavyPlayer: Found " + str(adjacent_allies.size()) + " adjacent allies for big drill operation")
	
	for ally in adjacent_allies:
		print("HeavyPlayer: " + entity_name + " adding " + ally.entity_name + " to big drill team")
		# Apply a visual effect to allies to show they're part of the operation
		ally.modulate = Color(0.7, 0.7, 0.9)  # Slightly different color to show they're supporting
	
	# Start special drilling that takes longer but brings all adjacent allies too
	is_drilling = true
	drilling_turns_left = turns_required
	drilling_target_level = current_level + 1
	drilling_target_position = grid_position
	
	# Apply visual effect
	modulate = Color(0.5, 0.5, 0.8)  # Different color than normal drilling
	
	# Can't move while drilling
	is_moving = false
	path = []
	
	# Show drilling visualization for this player and all allies
	if game_controller:
		# Show drill visualization for the heavy player
		game_controller.show_drill_visualization(current_level, grid_position, current_level + 1, grid_position)
		
		# Show drill visualization for all allies
		for ally in adjacent_allies:
			game_controller.show_drill_visualization(ally.current_level, ally.grid_position, ally.current_level + 1, ally.grid_position)

# Override continue_drilling to handle big drill operation
func continue_drilling() -> bool:
	if not is_drilling:
		return false
		
	# Check if we're doing a big drill operation (has the special color)
	var is_big_drill = modulate.is_equal_approx(Color(0.5, 0.5, 0.8))
	
	if is_big_drill:
		drilling_turns_left -= 1
		print("HeavyPlayer: " + entity_name + " big drill progress: " + str(drilling_turns_left) + " turns left")
		
		# Make sure we have access to the target level map
		if not game_controller or not game_controller.level_manager:
			print("HeavyPlayer: Cannot continue drilling - game_controller or level_manager not set")
			return false
			
		var target_level = current_level + 1
		var target_map = game_controller.level_manager.level_nodes.get(target_level)
		if not target_map:
			print("HeavyPlayer: Cannot continue drilling - target level map not found")
			return false
		
		# Apply drilling effect to the current tile if tile below is walkable
		if current_tile:
			var target_tile = target_map.get_tile(grid_position)
			if target_tile and target_tile.is_walkable:
				current_tile.set_drilling_effect()  # Use default intensity
		
		# Get range distance for area of effect
		var range_distance = get_big_drill_range()
		
		# Apply drilling effect to all tiles within range that have walkable tiles below
		for x in range(-range_distance, range_distance + 1):
			for y in range(-range_distance, range_distance + 1):
				if x == 0 and y == 0:  # Skip the center tile (self)
					continue
					
				# Calculate the Manhattan distance
				if abs(x) + abs(y) <= range_distance:
					var adjacent_pos = grid_position + Vector2i(x, y)
					var tile = isometric_map.get_tile(adjacent_pos)
					
					# Check if the corresponding tile on the level below is walkable
					var target_tile = target_map.get_tile(adjacent_pos)
					
					if tile and target_tile and target_tile.is_walkable:
						tile.set_drilling_effect()  # Use default intensity
						
		# Check if drilling is complete
		if drilling_turns_left <= 0:
			print("HeavyPlayer: Big drill operation complete!")
			complete_big_drilling()
			return true
			
		return false
	else:
		# Normal drilling behavior
		var result = super.continue_drilling()
		
		# If we're no longer drilling, go back to idle animation
		if !is_drilling && animation_state_machine:
			animation_state_machine.travel("Idle")
			
		return result

# Complete the big drilling process and move all players to the lower level
func complete_big_drilling() -> bool:
	print("HeavyPlayer: " + entity_name + " completed big drilling")
	is_drilling = false
	modulate = Color(1, 1, 1)  # Restore normal appearance
	
	# We no longer remove the drilling effect - it persists
	
	# Return to idle animation
	if animation_state_machine:
		animation_state_machine.travel("Idle")
	
	# Find current adjacent allies (don't rely on status effects)
	var adjacent_allies = get_adjacent_players()
	print("HeavyPlayer: Found " + str(adjacent_allies.size()) + " adjacent allies for descent")
	
	# We no longer remove the drilling effect from allies' tiles - it persists
	
	# Check with game_controller to see if we can move to the target level
	if game_controller and game_controller.level_manager:
		# First, collect all players that should descend together
		var all_descending_players = [self] + adjacent_allies
		print("HeavyPlayer: " + entity_name + " descending with " + str(adjacent_allies.size()) + " allies")
		
		# Then move the heavy player down
		print("HeavyPlayer: Descending self from level " + str(current_level) + " to level " + str(current_level + 1))
		var success = game_controller.level_manager.descend_player(self, current_level, grid_position)
		print("HeavyPlayer: Self descent " + ("succeeded" if success else "failed"))
		
		# If successful, move all adjacent allies down
		if success and adjacent_allies.size() > 0:
			var all_success = true
			for ally in adjacent_allies:
				# Restore visual appearance
				ally.modulate = Color(1, 1, 1)
				
				print("HeavyPlayer: Moving ally " + ally.entity_name + " from level " + str(ally.current_level) + " to level " + str(ally.current_level + 1))
				var ally_success = game_controller.level_manager.descend_player(ally, ally.current_level, ally.grid_position)
				if not ally_success:
					print("HeavyPlayer: Failed to move ally " + ally.entity_name + " to next level")
					all_success = false
			return success and all_success
		
		return success
	else:
		print("HeavyPlayer: No game_controller or level_manager, cannot descend")
	
	return false

# Override complete_drilling to handle animation transition
func complete_drilling() -> bool:
	var result = super.complete_drilling()
	
	# Return to idle animation when drilling completes
	if animation_state_machine:
		animation_state_machine.travel("Idle")
		
	return result

# Override the take_damage method to handle interruption of big drilling
func take_damage(amount: int):
	var was_big_drilling = is_drilling and modulate.is_equal_approx(Color(0.5, 0.5, 0.8))
	
	# If defend is active, halve the damage
	if defend_active:
		var original_amount = amount
		amount = max(1, amount / 2)  # At least 1 damage
		print("HeavyPlayer: " + entity_name + " defend ability reduced damage from " + str(original_amount) + " to " + str(amount))
	
	# Call the parent take_damage method
	super.take_damage(amount)
	
	# If we were big drilling and got interrupted, reset the appearance of adjacent allies
	if was_big_drilling and not is_drilling:
		print("HeavyPlayer: " + entity_name + " big drilling interrupted - resetting ally appearance")
		
		# We no longer remove the drilling effect - it persists
		
		# Reset the appearance of all adjacent allies
		var adjacent_allies = get_adjacent_players()
		for ally in adjacent_allies:
			print("HeavyPlayer: Resetting appearance for " + ally.entity_name)
			ally.modulate = Color(1, 1, 1)
			
			# We no longer remove the drilling effect from ally tiles - it persists
		
		# Hide drill visualization
		if game_controller:
			game_controller.hide_drill_visualization()

# Highlight tiles that can be big drilled - requires at least one adjacent player
func highlight_big_drill_targets():
	# Check if we have a valid tile below
	if not game_controller or not game_controller.level_manager:
		print("HeavyPlayer: Cannot highlight big drill targets - game_controller or level_manager not set")
		return
		
	# Check if the tile below is valid for drilling
	if not game_controller.level_manager.has_valid_tile_below(current_level, grid_position):
		print("HeavyPlayer: Cannot highlight big drill targets - no valid tile below")
		return
		
	# Get the target level map
	var target_level = current_level + 1
	var target_map = game_controller.level_manager.level_nodes.get(target_level)
	if not target_map:
		print("HeavyPlayer: Cannot highlight big drill targets - target level map not found")
		return
		
	# Clear any existing highlights
	if game_controller:
		game_controller.clear_all_highlights()
		
	# Get range distance for area of effect
	var range_distance = get_big_drill_range()
		
	# Highlight the current tile as the target
	var current_tile = isometric_map.get_tile(grid_position)
	if current_tile:
		# Check if the tile below is passable
		var target_tile = target_map.get_tile(grid_position)
		if target_tile and target_tile.is_walkable:
			current_tile.set_action_target(true)
			print("HeavyPlayer: Highlighting current tile for big drill at position " + str(grid_position))
		
	# Highlight all tiles within the big drill range
	for x in range(-range_distance, range_distance + 1):
		for y in range(-range_distance, range_distance + 1):
			# Skip the center tile (already handled above)
			if x == 0 and y == 0:
				continue
				
			# Calculate the Manhattan distance (|x| + |y|)
			if abs(x) + abs(y) <= range_distance:
				var pos = grid_position + Vector2i(x, y)
				var tile = isometric_map.get_tile(pos)
				
				# Check if the corresponding tile on the level below is passable
				var target_tile = target_map.get_tile(pos)
				
				if tile and tile.is_walkable and target_tile and target_tile.is_walkable:
					tile.set_action_target(true)
					print("HeavyPlayer: Highlighting tile in range at position " + str(pos))
			
	# Also highlight the target level tiles that are passable
	for x in range(-range_distance, range_distance + 1):
		for y in range(-range_distance, range_distance + 1):
			# Calculate the Manhattan distance (|x| + |y|)
			if abs(x) + abs(y) <= range_distance:
				var pos = grid_position + Vector2i(x, y)
				var tile = target_map.get_tile(pos)
				
				if tile and tile.is_walkable:
					tile.set_action_target(true)
					print("HeavyPlayer: Highlighting target level tile in range at level " + str(target_level) + ", position " + str(pos))

# Override start_turn to handle defend ability reset
func start_turn():
	# Reset defend status at the start of turn
	if defend_active:
		print("HeavyPlayer: " + entity_name + " defend ability expired")
		defend_active = false
		modulate = Color(1, 1, 1, 1)  # Reset visual effect
		
		# Return to idle animation
		if animation_state_machine:
			animation_state_machine.travel("Idle")
	
	# Call parent implementation
	super.start_turn()

# Override to implement ability unlocking for Heavy class
func unlock_ability(ability_name: String) -> void:
	print("HeavyPlayer: " + entity_name + " unlocking ability: " + ability_name)
	
	match ability_name:
		"more_drill_smash":
			# Enhance drill_smash to have a larger area of effect
			print("HeavyPlayer: Unlocked enhanced drill_smash - larger area effect")
			
			# Add a property to track the upgrade state
			set_meta("enhanced_drill_smash", true)
			
			# Update description to reflect the enhanced ability
			var cost = get_ability_cost("drill_smash")
			set_meta("drill_smash_description", "Drill Smash: Extended range in all directions (6 tiles total) (Cost: " + str(cost) + " AP)")
			
		"more_big_drill":
			# Enhance big_drill to have a larger range for allies
			print("HeavyPlayer: Unlocked enhanced big_drill - can bring distant allies down")
			
			# Add a property to track the upgrade state
			set_meta("enhanced_big_drill", true)
			
			# Update description to reflect the enhanced ability
			var cost = get_ability_cost("big_drill")
			set_meta("big_drill_description", "Big Drill: Takes 4 turns, brings nearby allies down too (Cost: " + str(cost) + " AP)")
			
		"charge_attack":
			# Add a new charge attack ability to the player's abilities list
			print("HeavyPlayer: Unlocked new charge_attack ability")
			
			# Add the new ability if not already present
			if not abilities.has("charge_attack"):
				abilities.append("charge_attack")
			
			# Signal that abilities have changed
			emit_signal("ability_used")  # This will update the UI

# Helper function to get the big drill range (enhanced if upgraded)
func get_big_drill_range() -> int:
	return 2 if has_meta("enhanced_big_drill") else 1

# Helper function to get the drill smash range (enhanced if upgraded)
func get_drill_smash_sides_count() -> int:
	return 2 if has_meta("enhanced_drill_smash") else 1

# Helper function to get allies within a certain range
func get_allies_in_range(range_distance: int) -> Array:
	var allies_in_range = []
	
	# Use the game_controller reference
	assert(game_controller != null, "HeavyPlayer: " + entity_name + " - GameController reference not set")
	
	# Check for player entities in range
	for player in game_controller.player_entities:
		if player != self:  # Don't include self
			var distance = grid_position.distance_to(player.grid_position)
			if distance <= range_distance:
				allies_in_range.append(player)
	
	return allies_in_range

# Highlight the charge attack targets
func highlight_charge_attack_targets():
	# Get the isometric map
	if not isometric_map:
		print("HeavyPlayer: Cannot highlight charge attack targets - isometric_map is null")
		return
		
	# Clear any existing highlights
	if game_controller:
		game_controller.clear_all_highlights()
	
	# Let's look for enemies that are in a straight line (cardinal directions)
	var directions = [
		Vector2i(1, 0),   # Right
		Vector2i(-1, 0),  # Left
		Vector2i(0, 1),   # Down
		Vector2i(0, -1),  # Up
	]
	
	var max_charge_distance = 4  # Maximum distance for charge attack
	var highlighted_count = 0
	
	# Check in each cardinal direction
	for dir in directions:
		var current_pos = grid_position
		var distance = 0
		
		# Check up to max_charge_distance tiles in this direction
		while distance < max_charge_distance:
			current_pos += dir
			distance += 1
			
			# Check if tile exists and is walkable
			var current_tile = isometric_map.get_tile(current_pos)
			if not current_tile or not current_tile.is_walkable:
				break
			
			# If there's an entity on this tile, highlight it as a target
			if current_tile.is_occupied and current_tile.occupying_entity is Entity:
				var entity = current_tile.occupying_entity
				
				# Only highlight enemy entities as targets
				if entity in game_controller.enemy_entities:
					# Make sure there's a free tile adjacent to the enemy that we can charge to
					var charge_position = current_pos - dir
					var charge_tile = isometric_map.get_tile(charge_position)
					
					# Only highlight if we have a valid position to charge to
					if charge_tile and charge_tile.is_walkable and not charge_tile.is_occupied and charge_position != grid_position:
						current_tile.set_action_target(true)
						highlighted_count += 1
						print("HeavyPlayer: Highlighted charge target at " + str(current_pos))
					break
	
	print("HeavyPlayer: Highlighted " + str(highlighted_count) + " charge attack targets")
