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
var health_bar: ProgressBar = null
var show_health_bar: bool = false

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
	
	# Create health bar
	_create_health_bar()
	
	# Connect Area2D input events if available
	var area = get_node_or_null("Area2D")
	if area:
		print("Entity: " + entity_name + " connecting input events")
		if not area.is_connected("input_event", Callable(self, "_input_event")):
			area.connect("input_event", Callable(self, "_input_event"))
		
		# Connect mouse hover signals
		if not area.is_connected("mouse_entered", Callable(self, "_on_mouse_entered")):
			area.connect("mouse_entered", Callable(self, "_on_mouse_entered"))
		if not area.is_connected("mouse_exited", Callable(self, "_on_mouse_exited")):
			area.connect("mouse_exited", Callable(self, "_on_mouse_exited"))
	else:
		push_error("Entity: " + entity_name + " has no Area2D node")
	
	# Connect to our own health changed signal
	if not is_connected("health_changed", Callable(self, "_on_health_changed")):
		connect("health_changed", Callable(self, "_on_health_changed"))

func _process(delta):
	# Handle entity movement if we have a path
	if is_moving and path.size() > 0:
		move_along_path(delta)
	
	# Update health bar position if visible
	if show_health_bar and health_bar:
		_update_health_bar_position()

# Override the start_turn function from ActionableCharacter
func start_turn():
	super.start_turn()
	print("Entity: " + entity_name + " starting turn")
	
	# Process status effects first - effects are processed at start of turn now
	process_status_effects()
	
	# If we're drilling, continue the process
	if is_drilling:
		continue_drilling()
		# If we are drilling, then we need to end the turn immediately
		call_deferred("finish_turn")
		return
		
	# If we're frozen or stunned, end the turn immediately
	if not can_take_actions():
		print("Entity: " + entity_name + " cannot take actions due to status effects, skipping turn")
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
		
		# Apply per-turn effects FIRST (at the start of the turn)
		match effect_name:
			"poison":
				print("Entity: " + entity_name + " taking poison damage: " + str(effect.strength))
				take_damage(effect.strength)
				# Create poison effect
				create_poison_burst()
			"regeneration":
				print("Entity: " + entity_name + " healing: " + str(effect.strength))
				heal_damage(effect.strength)
			# Add other per-turn effects as needed
		
		# Decrease duration
		effect.duration -= 1
		print("Entity: " + entity_name + " - " + effect_name + " effect duration: " + str(effect.duration))
		
		# Check if effect has expired
		if effect.duration <= 0:
			effects_to_remove.append(effect_name)
			print("Entity: " + entity_name + " - " + effect_name + " effect expired")
	
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
	
	# Play appropriate sound effect based on the status effect
	match effect_name:
		"freeze":
			Audio.play_sound("metal_hit", -3.0)
		"poison":
			Audio.play_sound("point", -3.0)
		"stunned":
			Audio.play_sound("metal_hit", -5.0)
		"buffed", "protected":
			Audio.play_sound("powerup", -3.0)
	
	# Apply immediate effects if needed
	match effect_name:
		"stunned":
			# Stun prevents movement
			print("Entity: " + entity_name + " stunned, stopping movement")
			is_moving = false
			path = []
		"freeze":
			# Freeze effect - stops movement and changes appearance
			print("Entity: " + entity_name + " frozen, stopping movement")
			is_moving = false
			path = []
			# Visual effect for frozen
			modulate = Color(0.7, 0.8, 1.0)
			# Add ice crystal visual to show frozen status
			add_ice_crystal_visual()
		"poison":
			# Apply poison visual effect
			print("Entity: " + entity_name + " poisoned, applying visual effect")
			modulate = Color(0.8, 1.0, 0.7)  # Greenish tint
			# Create poison particles
			create_poison_particles()
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
		"freeze":
			# Revert freeze visual effect
			print("Entity: " + entity_name + " freeze removed, restoring normal appearance")
			modulate = Color(1.0, 1.0, 1.0)
			remove_ice_crystal_visual()
		"poison":
			# Revert poison visual effect
			print("Entity: " + entity_name + " poison removed, restoring normal appearance")
			modulate = Color(1.0, 1.0, 1.0)
			remove_poison_particles()
	
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
	
	# Play drilling sound
	Audio.play_sound("drill")
	
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
	
	# Play drilling sound
	Audio.play_sound("drill")
	
	# Apply drilling effect to the current tile
	if current_tile:
		current_tile.set_drilling_effect()
	
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
	
	# Play drilling completion sound
	Audio.play_sound("drill", 3.0)
		
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
	
	# Play healing sound
	Audio.play_sound("powerup", -3.0)
	
	current_health = min(max_health, current_health + amount)
	print("Entity: " + entity_name + " health now " + str(current_health) + "/" + str(max_health))
	emit_signal("health_changed", current_health, max_health)

# Die
func die():
	print("Entity: " + entity_name + " died")
	is_dead = true
	is_moving = false
	
	# Play death sound (louder metal hit)
	Audio.play_sound("die")
	
	# Clean up the tile this entity was occupying
	if current_tile and current_tile.is_occupied and current_tile.occupying_entity == self:
		print("Entity: " + entity_name + " removing from tile at " + str(current_tile.grid_position) + " on death")
		current_tile.remove_entity()
	
	# Create death particles
	var particle_parent = null
	if isometric_map:
		particle_parent = isometric_map
	else:
		particle_parent = self
		
	# Create death particles
	var death_particles = CPUParticles2D.new()
	particle_parent.add_child(death_particles)
	
	# Configure death particles
	death_particles.z_index = 1
	death_particles.amount = 30
	death_particles.lifetime = 0.7
	death_particles.one_shot = true
	death_particles.explosiveness = 0.9
	death_particles.direction = Vector2(0, 0)
	death_particles.spread = 180.0
	death_particles.gravity = Vector2.ZERO
	death_particles.initial_velocity_min = 40.0
	death_particles.initial_velocity_max = 80.0
	death_particles.scale_amount_min = 3.0
	death_particles.scale_amount_max = 5.0
	death_particles.color = Color(0.8, 0.8, 0.8, 0.8)  # White/gray poof
	
	# Position particles
	death_particles.global_position = global_position
	death_particles.position.y -= 35  # Height offset to center on entity
	death_particles.emitting = true
	
	# Create a Tween for the fade-out effect
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.7)  # Fade to transparent
	
	# Remove particles and entity after they finish
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(death_particles):
		death_particles.queue_free()
		
	# Queue free the entity after the particles finish
	queue_free()
	
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
		
		# Play walking sound (much quieter) only if there's at least one player on the same level
		var should_play_sound = false
		if game_controller and game_controller.has_method("get_player_entities"):
			var player_entities = game_controller.get_player_entities()
			for player in player_entities:
				if player.current_level == current_level:
					should_play_sound = true
					break
					
		if should_play_sound:
			Audio.play_sound("walk", -15.0)
		
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
	
	# Play level transition sound
	Audio.play_sound("drill", 2.0)
	
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

# Create health bar
func _create_health_bar():
	# Create a ProgressBar for the health
	health_bar = ProgressBar.new()
	health_bar.min_value = 0
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.show_percentage = false
	health_bar.size = Vector2(60, 10)
	health_bar.position = Vector2(-30, -50)  # Default position above the entity
	health_bar.visible = false
	
	# Style the health bar
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.6)  # Background color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0, 0, 0)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	health_bar.add_theme_stylebox_override("background", style)
	
	# Style for the filled part
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.9, 0.2)  # Green color for health
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	health_bar.add_theme_stylebox_override("fill", fill_style)
	
	# Add the health bar as a child
	add_child(health_bar)
	
	# Position it initially
	_update_health_bar_position()

# Update health bar position to follow entity
func _update_health_bar_position():
	# Check if there's a HealthBarPos node
	var health_bar_pos = get_node_or_null("HealthBarPos")
	
	if health_bar_pos:
		# Use the HealthBarPos node's position
		health_bar.global_position = health_bar_pos.global_position
		# Center the health bar on the position node
		health_bar.position = Vector2(health_bar.position.x - (health_bar.size.x / 2), health_bar.position.y)
	else:
		# Use default position above the entity
		health_bar.position = Vector2(-30, -50)

# Mouse entered entity area
func _on_mouse_entered():
	if not is_dead and health_bar:
		show_health_bar = true
		health_bar.visible = true

# Mouse exited entity area
func _on_mouse_exited():
	if health_bar:
		show_health_bar = false
		health_bar.visible = false

# Update health bar when health changes
func _on_health_changed(current, maximum):
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current
		
		# Update health bar color based on health percentage
		var health_percent = float(current) / float(maximum)
		var fill_style = health_bar.get_theme_stylebox("fill")
		
		if health_percent > 0.6:
			fill_style.bg_color = Color(0.2, 0.9, 0.2)  # Green for high health
		elif health_percent > 0.3:
			fill_style.bg_color = Color(0.9, 0.9, 0.2)  # Yellow for medium health
		else:
			fill_style.bg_color = Color(0.9, 0.2, 0.2)  # Red for low health

# Check if entity can take actions (might be frozen or stunned)
func can_take_actions() -> bool:
	return not (status_effects.has("freeze") or status_effects.has("stunned"))

# Create poison particle effect for ongoing poison status
func create_poison_particles():
	# Check if the entity already has poison particles attached
	if has_node("PoisonParticles"):
		return
		
	# Create poison particles that will persist during the poison effect
	var poison_particles = CPUParticles2D.new()
	poison_particles.name = "PoisonParticles"
	add_child(poison_particles)
	
	# Configure poison particles
	poison_particles.z_index = 1
	poison_particles.amount = 15
	poison_particles.lifetime = 1.5
	poison_particles.explosiveness = 0.0  # Continuous emission
	poison_particles.randomness = 0.5
	poison_particles.local_coords = true
	poison_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	poison_particles.emission_sphere_radius = 20.0
	poison_particles.direction = Vector2(0, -1)
	poison_particles.spread = 30.0
	poison_particles.gravity = Vector2(0, -10)
	poison_particles.initial_velocity_min = 5.0
	poison_particles.initial_velocity_max = 15.0
	poison_particles.scale_amount_min = 2.0
	poison_particles.scale_amount_max = 4.0
	poison_particles.color = Color(0.4, 0.9, 0.3, 0.6)  # Green toxic color
	
	# Position particles over the entity
	poison_particles.position = Vector2(0, -30)  # Adjust based on entity height
	poison_particles.emitting = true

# Create a burst of poison particles when the poison damage is applied
func create_poison_burst():
	# Play poison damage sound
	Audio.play_sound("fireball", -3.0)
	
	# Create a burst of poison particles when damage is applied
	var burst = CPUParticles2D.new()
	add_child(burst)
	
	# Configure poison burst
	burst.z_index = 1
	burst.amount = 15
	burst.lifetime = 0.7
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.local_coords = true
	burst.direction = Vector2(0, -1)
	burst.spread = 180.0
	burst.gravity = Vector2(0, -20)
	burst.initial_velocity_min = 20.0
	burst.initial_velocity_max = 40.0
	burst.scale_amount_min = 3.0
	burst.scale_amount_max = 6.0
	burst.color = Color(0.5, 0.9, 0.2, 0.8)  # Bright green
	
	# Position particles
	burst.position = Vector2(0, -30)  # Adjust based on entity height
	burst.emitting = true
	
	# Play a poison sound if available
	var poison_sound = get_node_or_null("PoisonSound")
	if poison_sound and poison_sound is AudioStreamPlayer:
		poison_sound.play()
	
	# Remove burst after completion
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func():
		if is_instance_valid(burst):
			burst.queue_free()
	)

# Remove poison particles when the effect ends
func remove_poison_particles():
	var poison_particles = get_node_or_null("PoisonParticles")
	if poison_particles:
		# Stop emitting new particles
		poison_particles.emitting = false
		
		# Create a timer to remove the particles after they fade
		var timer = get_tree().create_timer(2.0)
		timer.timeout.connect(func():
			if is_instance_valid(poison_particles):
				poison_particles.queue_free()
		)

# Add an ice crystal visual on top of the entity to show frozen status
func add_ice_crystal_visual():
	# Check if the entity already has an ice crystal
	if has_node("IceCrystal"):
		return
		
	# Create a simple sprite for the ice crystal
	var ice_crystal = CPUParticles2D.new()
	ice_crystal.name = "IceCrystal"
	add_child(ice_crystal)
	
	# Configure ice crystal particles
	ice_crystal.z_index = 2  # Display above entity
	ice_crystal.amount = 1
	ice_crystal.lifetime = 0.5
	ice_crystal.emitting = true
	ice_crystal.local_coords = true
	ice_crystal.one_shot = false
	ice_crystal.explosiveness = 0.0
	ice_crystal.randomness = 0.0
	ice_crystal.direction = Vector2(0, -1)
	ice_crystal.gravity = Vector2(0, 0)
	ice_crystal.initial_velocity_min = 0.0
	ice_crystal.initial_velocity_max = 0.0
	ice_crystal.scale_amount_min = 25.0  # Make it large and visible
	ice_crystal.scale_amount_max = 25.0
	ice_crystal.color = Color(0.6, 0.9, 1.0, 0.8)  # Light blue, semi-transparent
	
	# Position the crystal above the entity
	ice_crystal.position = Vector2(0, -60)  # Adjust based on entity height
	
	# Add a small animation to the crystal
	var tween = create_tween()
	tween.set_loops()  # Make it loop indefinitely
	tween.tween_property(ice_crystal, "position:y", -65, 1.0)  # Move up
	tween.tween_property(ice_crystal, "position:y", -55, 1.0)  # Move down

# Remove the ice crystal visual when freeze effect ends
func remove_ice_crystal_visual():
	var ice_crystal = get_node_or_null("IceCrystal")
	if ice_crystal:
		# Maybe add a fade-out effect
		var tween = create_tween()
		tween.tween_property(ice_crystal, "modulate", Color(1, 1, 1, 0), 0.5)
		
		# Remove the ice crystal after the fade-out
		await tween.finished
		if is_instance_valid(ice_crystal):
			ice_crystal.queue_free()
