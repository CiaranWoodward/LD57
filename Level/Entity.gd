class_name Entity
extends Node2D

# Entity properties
var entity_id: String = ""
var entity_name: String = ""
var current_tile: IsometricTile = null
var grid_position: Vector2i = Vector2i(0, 0)
var facing_direction: Vector2i = Vector2i(1, 0)  # Default facing right

# Map reference
var isometric_map: IsometricMap = null

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
signal movement_completed()
signal entity_selected(entity)
signal health_changed(current, maximum)
signal status_effect_applied(effect_name)
signal status_effect_removed(effect_name)
signal died()

# Update the _ready method to ensure we connect input events
func _ready():
	print("Entity: Initializing " + entity_name + " [" + entity_id + "]")
	# Connect Area2D input events if available
	var area = get_node_or_null("Area2D")
	if area:
		print("Entity: " + entity_name + " connecting input events")
		if not area.is_connected("input_event", Callable(self, "_input_event")):
			area.connect("input_event", Callable(self, "_input_event"))
	else:
		push_warning("Entity: " + entity_name + " has no Area2D node")

func _process(delta):
	# Handle entity movement if we have a path
	if is_moving and path.size() > 0:
		move_along_path(delta)

# Set a path for the entity to follow
func set_path(new_path: Array):
	if new_path.size() > 0:
		print("Entity: " + entity_name + " setting new path with " + str(new_path.size()) + " steps")
		path = new_path
		is_moving = true
	else:
		print("Entity: " + entity_name + " received empty path")

# Move along the current path
func move_along_path(delta: float):
	if path.size() == 0:
		is_moving = false
		print("Entity: " + entity_name + " reached end of path")
		emit_signal("movement_completed")
		return
		
	var next_position = path[0]
	
	# Get the map if not set
	if not isometric_map:
		isometric_map = get_node("/root/Main/Game/Map")
		if not isometric_map:
			push_error("Entity: " + entity_name + " - No isometric map found in Entity.move_along_path")
			is_moving = false
			path.clear()
			emit_signal("movement_completed")
			return
	
	var target_tile = isometric_map.get_tile(next_position)
	
	if target_tile == null or not target_tile.is_walkable or (target_tile.is_occupied and target_tile != current_tile):
		# Path is blocked, stop moving
		is_moving = false
		path.clear()
		print("Entity: " + entity_name + " path blocked at " + str(next_position))
		emit_signal("movement_completed")
		return
		
	# Calculate movement direction
	var target_world_pos = target_tile.position
	var direction = (target_world_pos - position).normalized()
	var distance_to_move = move_speed * delta * 100  # Adjust as needed
	var distance_to_target = position.distance_to(target_world_pos)
	
	# Update facing direction based on movement
	update_facing_direction(direction)
	
	# If we're close enough to the target, snap to it and move to the next tile
	if distance_to_move >= distance_to_target:
		position = target_world_pos
		
		# Update entity state
		if current_tile:
			current_tile.remove_entity()
		
		grid_position = next_position
		current_tile = target_tile
		current_tile.place_entity(self)
		print("Entity: " + entity_name + " moved to " + str(grid_position))
		
		# Remove the reached position from the path
		path.remove_at(0)
		
		# If the path is now empty, we're done moving
		if path.size() == 0:
			is_moving = false
			print("Entity: " + entity_name + " completed movement")
			emit_signal("movement_completed")
	else:
		# Move toward the target
		position += direction * distance_to_move

# Place entity on a tile
func place_on_tile(tile: IsometricTile):
	if not tile:
		push_error("Entity: " + entity_name + " - Cannot place on null tile")
		return
		
	# Remove from current tile if any
	if current_tile:
		print("Entity: " + entity_name + " removing from current tile at " + str(current_tile.grid_position))
		current_tile.remove_entity()
	
	# Update entity state
	current_tile = tile
	grid_position = tile.grid_position
	position = tile.position
	print("Entity: " + entity_name + " placed on tile at " + str(grid_position))
	
	# Update tile state
	tile.place_entity(self)

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
	emit_signal("died")

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
