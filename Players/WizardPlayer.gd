class_name WizardPlayer
extends PlayerEntity

var fireball_range: int = 5  # Maximum range for fireball ability
var aoe_radius: int = 1      # Radius for area of effect (1 = 3x3 grid)

func configure_player():
	entity_name = "Wizard"
	max_action_points = 4  # Heavy has more action points for abilities
	action_points = max_action_points
	max_movement_points = 2  # But limited movement
	movement_points = max_movement_points
	move_speed = 0.7
	abilities = ["drill", "fireball"]
	max_health = 15
	current_health = 15

func get_ability_cost(ability_name: String) -> int:
	match ability_name:
		"fireball": return 3  # Fireball costs more than most abilities
		_: return super.get_ability_cost(ability_name)

func execute_ability(ability_name: String, target) -> bool:
	if super.execute_ability(ability_name, target):
		return true
		
	match ability_name:	
		"fireball":
			# Fireball is an AOE ranged attack that damages all entities in a radius
			if target is IsometricTile:
				# Check if player has enough action points
				var cost = get_ability_cost("fireball")
				if action_points < cost:
					print("WizardPlayer: " + entity_name + " - Not enough action points for fireball")
					return false
				
				# Get target position and calculate direction
				var target_pos = target.grid_position
				var direction = target_pos - grid_position
				
				# Normalize direction to a unit vector
				if direction.x != 0: direction.x = sign(direction.x)
				if direction.y != 0: direction.y = sign(direction.y)
				
				print("WizardPlayer: " + entity_name + " firing fireball in direction " + str(direction))
				
				# Calculate the line of tiles in the direction, up to max range or until we hit a wall
				var current_pos = grid_position
				var distance = 0
				var impact_pos = null
				
				# We'll stop if we hit a wall or if we go beyond the maximum range
				while distance < fireball_range:
					# Move one step in the direction
					current_pos += Vector2i(direction)
					distance += 1
					
					# Get the tile at this position
					var current_tile = isometric_map.get_tile(current_pos)
					
					# If there's no tile or it's a wall, we impact at the last valid position
					if not current_tile or not current_tile.is_walkable:
						print("WizardPlayer: fireball hit a wall at " + str(current_pos))
						break
					
					# If this is the target tile, this is our impact position
					if current_tile.grid_position == target_pos:
						impact_pos = target_pos
						break
				
				# If we didn't find an impact position, the ability failed
				if not impact_pos:
					print("WizardPlayer: fireball failed - no valid impact position")
					return false
					
				# Calculate the area of effect
				var affected_entities = []
				
				# Loop through all tiles within radius of the impact position
				for x in range(-aoe_radius, aoe_radius + 1):
					for y in range(-aoe_radius, aoe_radius + 1):
						var aoe_pos = impact_pos + Vector2i(x, y)
						var aoe_tile = isometric_map.get_tile(aoe_pos)
						
						# If the tile exists and has an entity, damage it
						if aoe_tile and aoe_tile.is_occupied and aoe_tile.occupying_entity is Entity:
							var entity = aoe_tile.occupying_entity
							print("WizardPlayer: fireball hit entity " + entity.entity_name + " at " + str(aoe_pos))
							
							# Don't damage self (in case wizard is in the AOE)
							if entity != self:
								# Add to the list of affected entities
								affected_entities.append(entity)
				
				# Apply damage to all affected entities (3 points of damage)
				for entity in affected_entities:
					entity.take_damage(3)
				
				print("WizardPlayer: fireball affected " + str(affected_entities.size()) + " entities")
				return true  # Return true even if we didn't hit anything, as the ability was still used
			
			print("WizardPlayer: " + entity_name + " fireball failed - invalid target")
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

# Highlight tiles that can be targeted with fireball
func highlight_fireball_targets():
	# Get the isometric map
	if not isometric_map:
		print("WizardPlayer: Cannot highlight fireball targets - isometric_map is null")
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
		Vector2(1, 1),   # Down-Right
		Vector2(-1, 1),  # Down-Left
		Vector2(1, -1),  # Up-Right
		Vector2(-1, -1)  # Up-Left
	]
	
	var highlighted_count = 0
	print("WizardPlayer: Highlighting fireball targets from " + str(grid_position))
	
	# For each direction, trace a line until we hit a wall or max range
	for dir in directions:
		var current_pos = grid_position
		var distance = 0
		var path_tiles = []
		
		# Trace the line
		while distance < fireball_range:
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
			
			# Mark this tile as a target
			current_tile.set_action_target(true)
			highlighted_count += 1
		
	print("WizardPlayer: Highlighted " + str(highlighted_count) + " fireball targets") 

# Wizard gets more action points and occasionally increases fireball effects
func on_level_up():
	# Increase health and action points
	max_health += 2
	current_health += 2
	
	# Custom allocation favoring action points over movement
	max_action_points += 1
	if level % 2 == 0:  # Only every other level
		max_movement_points += 1 
		
	# Increase fireball range every other level
	if level % 2 == 0:
		fireball_range += 1
