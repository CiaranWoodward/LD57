class_name ScoutPlayer
extends PlayerEntity

var vision_range: int = 6 # Scouts have better vision than other classes
var line_shot_range: int = 5 # Maximum range for line shot ability
var is_cloaked: bool = false
var cloak_turns_remaining: int = 0
@onready var sprite_node = $Sprite2D # Reference to the player's sprite node
@onready var animation_tree = $Sprite2D/AnimationTree
@onready var animation_state_machine = animation_tree.get("parameters/playback")
@onready var projectile_spawner = $ProjectileSpawner

func configure_player():
	entity_name = "Scout"
	max_action_points = 3
	action_points = max_action_points
	max_movement_points = 5  # Scouts have more movement points
	movement_points = max_movement_points
	move_speed = 1.5
	abilities = ["drill", "line_shot", "cloak"]
	max_health = 8
	current_health = 8
	
	# Activate animation tree
	if animation_tree:
		animation_tree.active = true

func get_ability_cost(ability_name: String) -> int:
	match ability_name:
		"line_shot": return 2
		"cloak": return 2
		_: return super.get_ability_cost(ability_name)

# Override to provide specific descriptions for Scout abilities
func get_ability_description(ability_name: String) -> String:
	var cost = get_ability_cost(ability_name)
	match ability_name:
		"line_shot": 
			return "Line Shot: Ranged attack, up to " + str(line_shot_range) + " tiles (Cost: " + str(cost) + " AP)"
		"cloak": 
			return "Cloak: Invisible for 2 turns (Cost: " + str(cost) + " AP)"
		_: 
			return super.get_ability_description(ability_name)

func execute_ability(ability_name: String, target) -> bool:
	# First try the parent implementation (for common abilities like drill)
	if super.execute_ability(ability_name, target):
		# If any ability is used, cancel cloak (except movement which is handled separately)
		if is_cloaked and ability_name != "move":
			cancel_cloak()
		return true
		
	# Then handle Scout-specific abilities
	match ability_name:		
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
				
				# Play shoot animation
				if animation_state_machine:
					animation_state_machine.travel("Shoot")
				
				# Calculate the line of tiles in the direction, up to max range or until we hit a wall
				var current_pos = grid_position
				var has_hit = false
				var distance = 0
				var target_entity = null
				var target_tile = null
				var farthest_tile = null
				
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
					
					# Keep track of the farthest walkable tile
					farthest_tile = current_tile
					
					# If there's an entity on this tile, damage it and stop
					if current_tile.is_occupied and current_tile.occupying_entity is Entity:
						target_entity = current_tile.occupying_entity
						target_tile = current_tile
						print("ScoutPlayer: line_shot hit entity " + target_entity.entity_name + " at " + str(current_pos))
						has_hit = true
						break
				
				# If no entity was hit, set the target to the farthest tile
				if not has_hit and farthest_tile:
					target_tile = farthest_tile
				
				# Spawn a projectile for the attack if we have a target tile
				if target_tile and projectile_spawner:
					var current_tile = isometric_map.get_tile(grid_position)
					if current_tile:
						# Create projectile and connect to the hit signal
						var projectile = projectile_spawner.spawn_projectile_between_tiles(current_tile, target_tile)
						if projectile:
							projectile.hit_target.connect(func():
								# Apply damage to the target entity if there was one
								if target_entity:
									target_entity.take_damage(2)
							)
				# Otherwise fallback to the original immediate damage logic
				elif target_entity:
					target_entity.take_damage(2)
				
				# Cancel cloak if we used line shot
				if is_cloaked:
					cancel_cloak()
					
				return true  # Return true even if we didn't hit anything, as the ability was still used
			
			print("ScoutPlayer: " + entity_name + " line_shot failed - invalid target")
			return false
		
		"cloak":
			# Check if player has enough action points
			var cost = get_ability_cost("cloak")
			if action_points < cost:
				print("ScoutPlayer: " + entity_name + " - Not enough action points for cloak")
				return false
				
			# Apply cloak effect
			is_cloaked = true
			cloak_turns_remaining = 2
			print("ScoutPlayer: " + entity_name + " activates cloak for 2 turns")
			
			# Play poof and hide animation
			if animation_state_machine:
				animation_state_machine.travel("Poof")
			
			# Visual effect (would need to be implemented in the entity's sprite)
			if sprite_node:
				sprite_node.modulate.a = 0.5 # Make sprite semi-transparent
			
			return true
			
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


# Process end of turn to update cloak duration
func on_turn_end():
	if is_cloaked:
		cloak_turns_remaining -= 1
		print("ScoutPlayer: " + entity_name + " - Cloak turns remaining: " + str(cloak_turns_remaining))
		
		if cloak_turns_remaining <= 0:
			cancel_cloak()

# Cancel cloak effect
func cancel_cloak():
	if is_cloaked:
		is_cloaked = false
		cloak_turns_remaining = 0
		print("ScoutPlayer: " + entity_name + " - Cloak cancelled")
		
		# Reset visual effect and animation
		if sprite_node:
			sprite_node.modulate.a = 1.0
		
		# Return to idle animation
		if animation_state_machine:
			animation_state_machine.travel("Idle")
			
# Check if player is visible to enemies (for AI targeting)
func is_visible_to_enemies() -> bool:
	return !is_cloaked

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

# Override take_damage to cancel cloak if hit
func take_damage(amount: int):
	super.take_damage(amount)
	
	# If we took damage and are cloaked, cancel the cloak
	if amount > 0 and is_cloaked:
		print("ScoutPlayer: " + entity_name + " - Cloak broken by damage!")
		cancel_cloak()
