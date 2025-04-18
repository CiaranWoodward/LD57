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
		"emergency_teleport": return 2
		_: return super.get_ability_cost(ability_name)

# Override to provide specific descriptions for Scout abilities
func get_ability_description(ability_name: String) -> String:
	var cost = get_ability_cost(ability_name)
	match ability_name:
		"line_shot": 
			# Use enhanced description if available
			if has_meta("line_shot_description"):
				return get_meta("line_shot_description")
			return "Line Shot: Ranged attack, up to " + str(line_shot_range) + " tiles (Cost: " + str(cost) + " AP)"
		"cloak": 
			# Use enhanced description if available
			if has_meta("cloak_description"):
				return get_meta("cloak_description")
			return "Cloak: Invisible for 2 turns (Cost: " + str(cost) + " AP)"
		"emergency_teleport":
			return "Emergency Teleport: Escape to a random location (Cost: " + str(cost) + " AP)"
		_: 
			return super.get_ability_description(ability_name)

func execute_ability(ability_name: String, target) -> bool:
	# First try the parent implementation (for common abilities like drill)
	if super.execute_ability(ability_name, target):
		# If any ability is used, cancel cloak (except movement which is handled separately)
		# Don't cancel cloak if we have the enhanced_cloak upgrade
		if is_cloaked and ability_name != "move" and not has_meta("enhanced_cloak"):
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
				
				# Calculate the line of tiles in the direction
				var current_pos = grid_position
				var distance = 0
				var hit_entities = []  # Track entities hit for penetrating shot
				var path_tiles = []    # Track all tiles in the path
				var final_target_tile = null  # Furthest tile to aim at
				
				# We'll collect all tiles in the path up to max range or wall
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
					
					# Add this tile to our path
					path_tiles.append(current_tile)
					
					# Update the furthest tile we've seen
					final_target_tile = current_tile
					
					# If there's an entity on this tile, collect it for damage
					if current_tile.is_occupied and current_tile.occupying_entity is Entity:
						hit_entities.append(current_tile.occupying_entity)
						print("ScoutPlayer: line_shot hit entity " + current_tile.occupying_entity.entity_name + " at " + str(current_pos))
						
						# If we're not using penetrating shot, stop here
						if not has_meta("penetrating_shot"):
							break
				
				# No need to spend action points here, it's handled in use_ability
				
				# Spawn a projectile that will travel to the final target
				if final_target_tile and projectile_spawner:
					var current_tile = isometric_map.get_tile(grid_position)
					if current_tile:
						# Create projectile that travels to the furthest relevant tile
						var projectile = projectile_spawner.spawn_projectile_between_tiles(current_tile, final_target_tile)
						if projectile:
							# When the projectile hits, damage all collected entities
							projectile.hit_target.connect(func():
								print("ScoutPlayer: Projectile hit - damaging " + str(hit_entities.size()) + " entities")
								for entity in hit_entities:
									entity.take_damage(2)
							)
				# Fallback to immediate damage if no projectile system
				elif hit_entities.size() > 0:
					for entity in hit_entities:
						entity.take_damage(2)
				
				# Cancel cloak if we used line shot and don't have enhanced cloak
				if is_cloaked and not has_meta("enhanced_cloak"):
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
			
		"emergency_teleport":
			# Check if player has enough action points
			var cost = 2 # Default cost for emergency teleport
			if action_points < cost:
				print("ScoutPlayer: " + entity_name + " - Not enough action points for emergency teleport")
				return false
				
			# Find a random walkable and unoccupied tile to teleport to
			var valid_tiles = []
			
			# Get all tiles from the map
			if isometric_map:
				for x in range(isometric_map.map_width):
					for y in range(isometric_map.map_height):
						var tile_pos = Vector2i(x, y)
						var tile = isometric_map.get_tile(tile_pos)
						
						# Check if the tile is walkable and not occupied
						if tile and tile.is_walkable and not tile.is_occupied:
							valid_tiles.append(tile)
			
			# If we found valid tiles, choose one randomly and teleport there
			if valid_tiles.size() > 0:
				var random_tile = valid_tiles[randi() % valid_tiles.size()]
				
				# Play teleport animation
				if animation_state_machine:
					animation_state_machine.travel("Poof")
				
				# Move to the new position
				var old_tile = isometric_map.get_tile(grid_position)
				if old_tile:
					old_tile.occupying_entity = null
					old_tile.is_occupied = false
				
				grid_position = random_tile.grid_position
				position = isometric_map.grid_to_world(grid_position)
				
				random_tile.occupying_entity = self
				random_tile.is_occupied = true
				
				print("ScoutPlayer: " + entity_name + " emergency teleported to " + str(grid_position))
				
				# No need to spend action points here, it's handled in use_ability
				
				return true
			else:
				print("ScoutPlayer: " + entity_name + " - No valid tiles to teleport to")
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
			
			# If there's an entity on this tile, mark it as target and stop if not penetrating
			if current_tile.is_occupied:
				current_tile.set_action_target(true)
				has_target = true
				highlighted_count += 1
				
				# Only stop if we don't have the penetrating shot upgrade
				if not has_meta("penetrating_shot"):
					break
			
		
		# If we didn't hit anything, mark the furthest tile as target
		if path_tiles.size() > 0 and not has_target:
			path_tiles[-1].set_action_target(true)
			highlighted_count += 1
		
		# Highlight all tiles in the path except the target (which is already highlighted as action_target)
		for i in range(path_tiles.size()):
			if not path_tiles[i].is_action_target:
				path_tiles[i].set_action_target(true)
	
	print("ScoutPlayer: Highlighted " + str(highlighted_count) + " line shot targets and their paths") 

# Override take_damage to cancel cloak if hit
func take_damage(amount: int):
	super.take_damage(amount)
	
	# If we took damage and are cloaked, cancel the cloak ONLY if we don't have enhanced_cloak
	if amount > 0 and is_cloaked and not has_meta("enhanced_cloak"):
		print("ScoutPlayer: " + entity_name + " - Cloak broken by damage!")
		cancel_cloak()

# Override to implement ability unlocking for Scout class
func unlock_ability(ability_name: String) -> void:
	print("ScoutPlayer: " + entity_name + " unlocking ability: " + ability_name)
	
	match ability_name:
		"penetrating_quick_shot":
			# Enhance line_shot to penetrate through enemies
			print("ScoutPlayer: Unlocked penetrating shot - line_shot will now penetrate through enemies")
			
			# Add a property to track the upgrade state
			set_meta("penetrating_shot", true)
			
			# Update description to reflect the enhanced ability
			var cost = get_ability_cost("line_shot")
			set_meta("line_shot_description", "Line Shot: Penetrating attack, up to " + str(line_shot_range) + " tiles (Cost: " + str(cost) + " AP)")
			
		"stay_cloaked":
			# Enhance cloak to not be broken when attacking
			print("ScoutPlayer: Unlocked enhanced cloak - attacks won't break cloak")
			
			# Add a property to track the upgrade state
			set_meta("enhanced_cloak", true)
			
			# Update description to reflect the enhanced ability
			var cost = get_ability_cost("cloak")
			set_meta("cloak_description", "Cloak: Invisible for 2 turns, not broken by attacks (Cost: " + str(cost) + " AP)")
			
		"emergency_teleport":
			# Add a new emergency teleport ability to the player's abilities list
			print("ScoutPlayer: Unlocked new emergency_teleport ability")
			
			# Add the new ability if not already present
			if not abilities.has("emergency_teleport"):
				abilities.append("emergency_teleport")
			
			# Signal that abilities have changed
			emit_signal("ability_used")  # This will update the UI

func use_ability(ability_name: String, target) -> bool:
	# First check if player has this ability
	if not abilities.has(ability_name):
		print("ScoutPlayer: " + entity_name + " does not have ability: " + ability_name)
		return false
		
	# Then check if player has enough action points for the ability
	var cost = get_ability_cost(ability_name)
	if action_points < cost:
		print("ScoutPlayer: " + entity_name + " does not have enough action points for " + ability_name)
		return false
		
	# Execute the ability
	var success = execute_ability(ability_name, target)
	
	# If successful, deduct action points
	if success:
		action_points -= cost
		emit_signal("ability_used")
		
	return success
