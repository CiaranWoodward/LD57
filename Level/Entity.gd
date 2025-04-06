class_name Entity
extends ActionableCharacter

# Entity properties
var entity_id: String = ""
var current_tile: IsometricTile = null
var grid_position: Vector2i = Vector2i(0, 0)
var facing_direction: Vector2i = Vector2i(1, 0)  # Default facing right
var current_level: int = 0  # Track which level this entity is on

# Map reference
var isometric_map: IsometricMap = null
var game_controller = null  # Direct reference to the GameController - this should be set by the GameController

# Movement properties
var move_speed: float = 1.0  # Speed multiplier
var is_moving: bool = false
var path: Array = []  # Array of Vector2i grid positions
var entity_width: int = 64
var entity_height: int = 64

# Health and status tracking
var max_health: int = 10
var current_health: int = 10
var is_dead: bool = false
var status_effects: Dictionary = {}

# Signals
signal entity_selected(entity)
signal health_changed(current, maximum)
signal status_effect_applied(effect_name)
signal status_effect_removed(effect_name)
signal died(entity)

# Drilling state properties
var is_drilling: bool = false
var drilling_turns_left: int = 0
var drilling_target_level: int = 0
var drilling_target_position: Vector2i = Vector2i.ZERO

# Update the _ready method to initialize entity
func _init():
	entity_id = "entity_" + str(randi())
	entity_name = "Entity"

func _ready():
	print("Entity: Initializing " + entity_name + " [" + entity_id + "]")
	
	# Connect Area2D input events if available
	var area = get_node_or_null("Area2D")
	if area:
		print("Entity: " + entity_name + " connecting input events")
		if not area.is_connected("input_event", Callable(self, "_input_event")):
			area.connect("input_event", Callable(self, "_input_event"))
	else:
		push_error("Entity: " + entity_name + " has no Area2D node")

func _process(delta):
	# Handle entity movement if we have a path
	if is_moving and path.size() > 0:
		move_along_path(delta)

# Override the start_turn function from ActionableCharacter
func start_turn():
	super.start_turn()
	print("Entity: " + entity_name + " starting turn")
	
	# If we're drilling, continue the process
	if is_drilling:
		continue_drilling()
		# If we are drilling, then we need to end the turn immediately
		call_deferred("finish_turn")
		return

# Override the finish_turn function from ActionableCharacter
func finish_turn():
	print("Entity: " + entity_name + " finishing turn")
	
	# Make sure we're not moving before finishing the turn
	if is_moving:
		print("Entity: " + entity_name + " is still moving, delaying turn finish")
		return
	
	super.finish_turn()

# Set a path for the entity to follow
func set_path(new_path: Array):
	if new_path.size() > 0:
		print("Entity: " + entity_name + " setting new path with " + str(new_path.size()) + " steps")
		path = new_path
		is_moving = true
	else:
		print("Entity: " + entity_name + " received empty path")

# Place entity on a tile
func place_on_tile(tile: IsometricTile):
	if not tile:
		push_error("Entity: " + entity_name + " - Cannot place on null tile")
		return
		
	# Log attempt to place
	print("Entity: " + entity_name + " (ID: " + entity_id + ") attempting to place on tile at " + str(tile.grid_position) + " on level " + str(current_level))
	
	# Check if the tile is already occupied by another entity
	if tile.is_occupied and tile.occupying_entity != self:
		push_error("Entity: " + entity_name + " - Cannot place on tile at " + str(tile.grid_position) + " - already occupied by " + 
			(tile.occupying_entity.entity_name if tile.occupying_entity else "unknown entity"))
		return
		
	# Remove from current tile if any
	if current_tile:
		print("Entity: " + entity_name + " removing from current tile at " + str(current_tile.grid_position) + " on level " + str(current_level))
		
		# Verify that we are the occupying entity before removing
		if current_tile.is_occupied and current_tile.occupying_entity == self:
			current_tile.remove_entity()
		else:
			push_error("Entity: " + entity_name + " - Current tile is occupied by different entity or not occupied at all")
			if current_tile.occupying_entity:
				print("   Current occupying entity: " + current_tile.occupying_entity.entity_name)
			
			# Force clear our reference, but don't touch the tile state
			current_tile = null
	
	# Update entity state
	current_tile = tile
	grid_position = tile.grid_position
	position = tile.get_entity_position()
	print("Entity: " + entity_name + " placed on tile at " + str(grid_position) + " on level " + str(current_level))
	
	# Update tile state
	tile.place_entity(self)
	
	# Verify that we are properly set as the occupying entity
	if not tile.is_occupied or tile.occupying_entity != self:
		push_error("Entity: " + entity_name + " - Failed to properly set occupation on tile at " + str(grid_position))

# Update the facing direction based on movement
func update_facing_direction(direction: Vector2):
	var old_direction = facing_direction
	
	if abs(direction.x) > abs(direction.y):
		facing_direction = Vector2i(sign(direction.x), 0)
	else:
		facing_direction = Vector2i(0, sign(direction.y))
		
	if old_direction != facing_direction:
		print("Entity: " + entity_name + " changed facing direction to " + str(facing_direction))

# Process status effects each turn/tick
func process_status_effects():
	print("Entity: " + entity_name + " processing " + str(status_effects.size()) + " status effects")
	var effects_to_remove = []
	
	# Process each active status effect
	for effect_name in status_effects:
		var effect = status_effects[effect_name]
		
		# Decrease duration
		effect.duration -= 1
		print("Entity: " + entity_name + " - " + effect_name + " effect duration: " + str(effect.duration))
		
		# Check if effect has expired
		if effect.duration <= 0:
			effects_to_remove.append(effect_name)
			print("Entity: " + entity_name + " - " + effect_name + " effect expired")
		else:
			# Apply any per-turn effects
			match effect_name:
				"poison":
					print("Entity: " + entity_name + " taking poison damage: " + str(effect.strength))
					take_damage(effect.strength)
				"regeneration":
					print("Entity: " + entity_name + " healing: " + str(effect.strength))
					heal_damage(effect.strength)
				# Add other per-turn effects as needed
	
	# Remove expired effects
	for effect_name in effects_to_remove:
		remove_status_effect(effect_name)

# Apply a status effect to this entity
func apply_status_effect(effect_name: String, duration: int, strength: float = 1.0):
	print("Entity: " + entity_name + " applying " + effect_name + " effect for " + str(duration) + " turns with strength " + str(strength))
	# Store effect details
	status_effects[effect_name] = {
		"duration": duration,
		"strength": strength
	}
	
	# Apply immediate effects if needed
	match effect_name:
		"stunned":
			# Stun prevents movement
			print("Entity: " + entity_name + " stunned, stopping movement")
			is_moving = false
			path = []
		"buffed":
			# Buff could temporarily increase stats
			print("Entity: " + entity_name + " buffed, increasing move speed to " + str(move_speed * strength))
			move_speed *= strength
		"debuffed":
			# Debuff could temporarily decrease stats
			print("Entity: " + entity_name + " debuffed, decreasing move speed to " + str(move_speed / strength))
			move_speed /= strength
		"protected":
			# Protection could reduce damage taken
			print("Entity: " + entity_name + " protected")
			pass
	
	emit_signal("status_effect_applied", effect_name)

# Remove a status effect
func remove_status_effect(effect_name: String):
	if not status_effects.has(effect_name):
		return
		
	print("Entity: " + entity_name + " removing " + effect_name + " effect")
	
	# Revert any stat changes from the effect
	match effect_name:
		"buffed":
			# Revert buff
			print("Entity: " + entity_name + " buff removed, resetting move speed")
			move_speed /= status_effects[effect_name].strength
		"debuffed":
			# Revert debuff
			print("Entity: " + entity_name + " debuff removed, resetting move speed")
			move_speed *= status_effects[effect_name].strength
	
	# Remove effect
	status_effects.erase(effect_name)
	emit_signal("status_effect_removed", effect_name)

# Start drilling to the level below
func start_drilling(turns_required: int = 2):
	print("Entity: " + entity_name + " starting to drill down")
	is_drilling = true
	drilling_turns_left = turns_required
	drilling_target_level = current_level + 1
	drilling_target_position = grid_position
	
	# Apply visual effect or animation if needed
	modulate = Color(0.7, 0.7, 0.7)  # Dim the entity to show drilling
	
	# Can't move while drilling
	is_moving = false
	path = []

# Continue drilling progress
func continue_drilling() -> bool:
	if not is_drilling:
		return false
		
	drilling_turns_left -= 1
	print("Entity: " + entity_name + " drilling progress: " + str(drilling_turns_left) + " turns left")
	
	# Check if drilling is complete
	if drilling_turns_left <= 0:
		complete_drilling()
		return true
	
	return false

# Complete the drilling process and move to the lower level
func complete_drilling() -> bool:
	print("Entity: " + entity_name + " completed drilling")
	is_drilling = false
	modulate = Color(1, 1, 1)  # Restore normal appearance
	
	# Check with game_controller to see if we can move to the target level
	if game_controller and game_controller.level_manager:
		# Use the level manager to handle the descent
		return game_controller.level_manager.descend_player(self, current_level, grid_position)
	
	return false

# Take damage
func take_damage(amount: int):
	if is_dead:
		return
		
	print("Entity: " + entity_name + " taking " + str(amount) + " damage")
	
	# Check for protection status
	if status_effects.has("protected"):
		var reduced_amount = max(1, amount - round(status_effects["protected"].strength))
		print("Entity: " + entity_name + " protected, damage reduced from " + str(amount) + " to " + str(reduced_amount))
		amount = reduced_amount
	
	current_health = max(0, current_health - amount)
	print("Entity: " + entity_name + " health now " + str(current_health) + "/" + str(max_health))
	emit_signal("health_changed", current_health, max_health)
	
	# Check for death
	if current_health <= 0:
		die()
	
	# If we were drilling, interrupt it
	if is_drilling:
		print("Entity: " + entity_name + " drilling interrupted by damage")
		is_drilling = false
		modulate = Color(1, 1, 1)  # Restore normal appearance

# Heal damage
func heal_damage(amount: int):
	if is_dead:
		return
		
	print("Entity: " + entity_name + " healing " + str(amount) + " health")
	current_health = min(max_health, current_health + amount)
	print("Entity: " + entity_name + " health now " + str(current_health) + "/" + str(max_health))
	emit_signal("health_changed", current_health, max_health)

# Die
func die():
	print("Entity: " + entity_name + " died")
	is_dead = true
	is_moving = false
	
	# Clean up the tile this entity was occupying
	if current_tile and current_tile.is_occupied and current_tile.occupying_entity == self:
		print("Entity: " + entity_name + " removing from tile at " + str(current_tile.grid_position) + " on death")
		current_tile.remove_entity()
	
	emit_signal("died", self)

# Revive a dead entity
func revive(health_amount: int = -1):
	if not is_dead:
		return
		
	is_dead = false
	modulate = Color(1, 1, 1, 1)  # Restore color
	
	# Restore health
	if health_amount < 0:
		current_health = max_health / 2  # Default to half health
	else:
		current_health = min(max_health, health_amount)
	
	emit_signal("health_changed", current_health, max_health)

# Check if entity is defeated
func is_defeated() -> bool:
	return is_dead

# Check if entity has a status effect
func has_status_effect(effect_name: String) -> bool:
	return status_effects.has(effect_name)

# Update the _input_event method to handle entity selection
func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Entity clicked: ", entity_name)
		emit_signal("entity_selected", self) 

# Move along the current path
func move_along_path(delta: float):
	if path.size() == 0:
		_on_path_completed()
		return
		
	var next_position = path[0]
	
	# Assert that isometric_map reference exists
	if not isometric_map:
		push_error("Entity: " + entity_name + " - No isometric map found in Entity.move_along_path")
		_on_path_completed()
		return
	
	var target_tile = isometric_map.get_tile(next_position)
	
	if target_tile == null or not target_tile.is_walkable:
		# Path is blocked, stop moving
		print("Entity: " + entity_name + " path blocked at " + str(next_position) + " - tile is null or not walkable")
		_on_path_completed()
		return
	
	# Check if the tile is occupied by a different entity
	if target_tile.is_occupied and target_tile.occupying_entity != self:
		print("Entity: " + entity_name + " path blocked at " + str(next_position) + 
			  " on level " + str(current_level) + " - tile is occupied by " + 
			  (target_tile.occupying_entity.entity_name if target_tile.occupying_entity else "unknown entity"))
		_on_path_completed()
		return
		
	# Calculate movement direction
	var target_world_pos = target_tile.get_entity_position()
	var direction = (target_world_pos - position).normalized()
	var distance_to_move = move_speed * delta * 1000  # Adjust as needed
	var distance_to_target = position.distance_to(target_world_pos)
	
	# Update facing direction based on movement
	update_facing_direction(direction)
	
	# If we're close enough to the target, snap to it and move to the next tile
	if distance_to_move >= distance_to_target:
		position = target_world_pos
		
		# Update entity state
		if current_tile:
			# Verify that we are the occupying entity before removing
			if current_tile.is_occupied and current_tile.occupying_entity == self:
				current_tile.remove_entity()
			else:
				push_error("Entity: " + entity_name + " - Current tile is not properly occupied before update in move_along_path")
				if current_tile.occupying_entity:
					print("   Current occupying entity: " + current_tile.occupying_entity.entity_name)
		
		grid_position = next_position
		current_tile = target_tile
		
		# Double-check if the tile is still available
		if target_tile.is_occupied and target_tile.occupying_entity != self:
			push_error("Entity: " + entity_name + " - Target tile became occupied during movement!")
			# Find an alternative tile to move to
			var nearby_tile = find_nearby_unoccupied_tile(target_tile)
			if nearby_tile:
				print("Entity: " + entity_name + " - Found nearby unoccupied tile at " + str(nearby_tile.grid_position))
				current_tile = nearby_tile
				grid_position = nearby_tile.grid_position
			else:
				push_error("Entity: " + entity_name + " - No nearby unoccupied tiles found!")
				_on_path_completed()
				return
		
		current_tile.place_entity(self)
		print("Entity: " + entity_name + " moved to " + str(grid_position) + " on level " + str(current_level))
		
		# Remove the reached position from the path
		path.remove_at(0)
		
		# If the path is now empty, we're done moving
		if path.size() == 0:
			_on_path_completed()
	else:
		# Move toward the target
		position += direction * distance_to_move

# Called when the entity has completed following its path
func _on_path_completed():
	print("Entity: " + entity_name + " completed movement")
	is_moving = false
	path.clear()

# Set the entity's level index
func set_level(level_index: int):
	print("Entity: " + entity_name + " changing from level " + str(current_level) + " to level " + str(level_index))
	current_level = level_index
	
	# Update the isometric_map reference to match the new level
	if game_controller and game_controller.level_manager:
		var new_map = game_controller.level_manager.level_nodes.get(level_index)
		
		if new_map:
			if isometric_map != new_map:
				print("Entity: " + entity_name + " updating isometric_map reference for level " + str(level_index))
				isometric_map = new_map
		else:
			push_error("Entity: " + entity_name + " - Cannot find isometric_map for level " + str(level_index))
	else:
		push_error("Entity: " + entity_name + " - No game_controller or level_manager to update isometric_map reference")

# Method for descending to a lower level
# This will be used when implementing the drilling mechanic
func descend_to_level(next_level_index: int, target_tile: IsometricTile):
	print("Entity: " + entity_name + " (ID: " + entity_id + ") descending from level " + str(current_level) + " to level " + str(next_level_index))
	
	# Get the current tile before changing levels
	var previous_tile = current_tile
	var previous_level = current_level
	
	# Remove from current tile - but don't set current_tile to null yet
	if previous_tile:
		if previous_tile.is_occupied and previous_tile.occupying_entity == self:
			print("Entity: " + entity_name + " removing from tile at " + str(previous_tile.grid_position) + " on level " + str(current_level))
			previous_tile.remove_entity()
		else:
			push_error("Entity: " + entity_name + " - Current tile is not properly occupied on level " + str(current_level))
	
	# Change level - this will also update the isometric_map reference through set_level
	var old_level = current_level
	set_level(next_level_index)
	
	# Verify that isometric_map was properly updated
	if game_controller and game_controller.level_manager:
		var expected_map = game_controller.level_manager.level_nodes.get(next_level_index)
		if expected_map != isometric_map:
			push_error("Entity: " + entity_name + " - isometric_map reference was not properly updated! Fixing it now.")
			isometric_map = expected_map
	
	# Check if target tile exists and is available
	if target_tile:
		# Ensure the target tile belongs to the correct level map
		if target_tile.get_parent() != isometric_map:
			push_error("Entity: " + entity_name + " - Target tile is from the wrong level map!")
			# Try to get the equivalent tile from the correct map
			if isometric_map:
				var equivalent_tile = isometric_map.get_tile(target_tile.grid_position)
				if equivalent_tile:
					print("Entity: " + entity_name + " - Found equivalent tile on correct level map")
					target_tile = equivalent_tile
				else:
					push_error("Entity: " + entity_name + " - Could not find equivalent tile on level " + str(next_level_index))
					
					# Revert to old level
					set_level(old_level)
					if previous_tile and previous_tile.is_walkable and not previous_tile.is_occupied:
						place_on_tile(previous_tile)
					return false
		
		# Check if the target tile is already occupied
		if target_tile.is_occupied and target_tile.occupying_entity != self:
			push_error("Entity: " + entity_name + " - Target tile at " + str(target_tile.grid_position) + 
				" on level " + str(next_level_index) + " is already occupied by " + 
				(target_tile.occupying_entity.entity_name if target_tile.occupying_entity else "unknown entity"))
			
			# Try to find a nearby unoccupied tile
			print("Entity: " + entity_name + " - Searching for a nearby unoccupied tile on level " + str(next_level_index))
			var nearby_tile = find_nearby_unoccupied_tile(target_tile)
			
			if nearby_tile:
				print("Entity: " + entity_name + " - Found nearby unoccupied tile at " + str(nearby_tile.grid_position))
				target_tile = nearby_tile
			else:
				push_error("Entity: " + entity_name + " - No nearby unoccupied tiles found on level " + str(next_level_index))
				# Revert to old level if we can't find a place on the new level
				set_level(old_level)
				if previous_tile and previous_tile.is_walkable and not previous_tile.is_occupied:
					place_on_tile(previous_tile)
				return false
		
		# Place on target tile in new level
		place_on_tile(target_tile)
		
		# Verify entity is correctly placed
		if current_tile != target_tile or current_level != next_level_index:
			push_error("Entity: " + entity_name + " - Failed to place on target tile after level change")
			return false
			
		print("Entity: " + entity_name + " successfully descended from level " + str(previous_level) + 
			  " to level " + str(current_level) + " and placed on tile at " + str(current_tile.grid_position))
		return true
	else:
		push_error("Entity: " + entity_name + " - Cannot descend to null tile on level " + str(next_level_index))
		
		# Try to restore to old level if possible
		set_level(old_level)
		if previous_tile and previous_tile.is_walkable and not previous_tile.is_occupied:
			place_on_tile(previous_tile)
		return false

# Find an unoccupied tile near the given tile
func find_nearby_unoccupied_tile(center_tile: IsometricTile) -> IsometricTile:
	if not isometric_map:
		push_error("Entity: " + entity_name + " - Cannot find nearby tile, no isometric_map reference")
		return null
		
	# Get directions
	var directions = [
		Vector2i(0, 1),   # Down
		Vector2i(1, 0),   # Right
		Vector2i(0, -1),  # Up
		Vector2i(-1, 0),  # Left
		Vector2i(1, 1),   # Down-Right
		Vector2i(-1, 1),  # Down-Left
		Vector2i(1, -1),  # Up-Right
		Vector2i(-1, -1)  # Up-Left
	]
	
	# Check center_tile first
	if not center_tile.is_occupied and center_tile.is_walkable:
		return center_tile
	
	# Then check neighbors in order of directions
	for dir in directions:
		var pos = center_tile.grid_position + dir
		var tile = isometric_map.get_tile(pos)
		
		if tile and tile.is_walkable and not tile.is_occupied:
			return tile
	
	# If still not found, try a wider search
	for dir in directions:
		for dist in range(2, 4):  # Check 2 and 3 tiles away
			var pos = center_tile.grid_position + (dir * dist)
			var tile = isometric_map.get_tile(pos)
			
			if tile and tile.is_walkable and not tile.is_occupied:
				return tile
	
	# No suitable tile found
	return null
