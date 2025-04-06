class_name PlayerEntity
extends Entity

# Player-specific properties
@export var action_points: int = 3
@export var max_action_points: int = 3
@export var movement_points: int = 3
@export var max_movement_points: int = 3
@export var abilities: Array = []
@export var experience: int = 0
@export var level: int = 1

# Visual properties
@export var profile_texture: Texture2D = preload("res://images/image_face.png")
@export var profile_tint: Color = Color(1.0, 1.0, 1.0, 1.0)

# Signals
signal ability_used(ability_name)
signal level_up(new_level)
signal action_points_changed(current, maximum)
signal movement_points_changed(current, maximum)
signal action_selection_changed

func _init():
	super._init()
	entity_name = "Player"
	entity_id = "player_" + str(randi())

# Override ready to add player-specific initialization
func _ready():
	super._ready()
	configure_player()

# Override to configure class-specific properties in subclasses
func configure_player():
	# Base configuration - subclasses should override this
	entity_name = "Generic Player"
	max_action_points = 3
	action_points = max_action_points
	max_movement_points = 3
	movement_points = max_movement_points
	move_speed = 1.0
	abilities = ["drill"]

# Override start_turn from Entity
func start_turn():
	# Call parent implementation first
	super.start_turn()
	
	# Reset action points and movement points for new turn
	action_points = max_action_points
	movement_points = max_movement_points
	emit_signal("action_points_changed", action_points, max_action_points)
	emit_signal("movement_points_changed", movement_points, max_movement_points)
	
	# Process status effects
	process_status_effects()
	
	# Check if we're drilling and continue the process
	if is_drilling:
		continue_drilling()
	
	# Players wait for user input, so don't finish turn automatically
	# The turn will be finished when the user clicks the "End Turn" button
	print("PlayerEntity: " + entity_name + " waiting for player input")
	emit_signal("action_selection_changed")

# Use an ability (returns true if successfully used)
func use_ability(ability_name: String, target) -> bool:
	if not abilities.has(ability_name) or action_points <= 0:
		return false
	
	# Get action point cost for this ability
	var ap_cost = get_ability_cost(ability_name)
	
	# Check if we have enough action points
	if action_points < ap_cost:
		return false
	
	# Execute the ability
	var success = execute_ability(ability_name, target)
	
	if success:
		# Consume action points
		action_points -= ap_cost
		emit_signal("action_points_changed", action_points, max_action_points)
		emit_signal("ability_used", ability_name)
		emit_signal("action_selection_changed")
	
	return success

# Get the action point cost for an ability
# Override in subclasses with specific costs
func get_ability_cost(ability_name: String) -> int:
	match ability_name:
		"drill": return 2  # Drilling costs 2 action points
		_: return 1  # Default cost of 1 AP

# Execute an ability - override in subclasses with specific ability implementations
func execute_ability(ability_name: String, target) -> bool:
	match ability_name:
		"drill":
			# Check if we can drill (if there's a valid level below)
			if not game_controller or not game_controller.level_manager:
				print("PlayerEntity: " + entity_name + " - Cannot drill, game_controller or level_manager not set")
				return false
				
			# Check if the tile below is valid for drilling
			if not game_controller.level_manager.has_valid_tile_below(current_level, grid_position):
				print("PlayerEntity: " + entity_name + " - Cannot drill, no valid tile below")
				return false
				
			# Start the drilling process
			start_drilling(2)  # Takes 2 turns to complete
			return true
			
		_:
			# Base class implementation should never be called directly
			push_error("PlayerEntity: " + entity_name + " - Using base class implementation for ability: " + ability_name + ". This should be overridden in subclasses.")
			return false

# Add experience and handle level up if needed
func add_experience(amount: int):
	experience += amount
	
	# Simple leveling formula: level = experience / 100 + 1
	var new_level = (experience / 100) + 1
	
	if new_level > level:
		level = new_level
		on_level_up()
		emit_signal("level_up", level)

# Called when the player levels up
# Override in subclasses with specific level-up behavior
func on_level_up():
	# Default behavior - increase action points and movement points
	max_action_points += 1
	max_movement_points += 1

# Override move_along_path - we don't need to check for automatic turn ending
func move_along_path(delta: float):
	# Call parent implementation without consuming action points
	super.move_along_path(delta)
	
	# Check if we've completed all movement
	if path.size() == 0 and is_turn_active:
		print("PlayerEntity: " + entity_name + " completed movement")
		emit_signal("action_selection_changed")

# Consume movement points for a path
func consume_movement_points_for_path(path_length: int) -> bool:
	if path_length <= 0:
		return true  # No movement points needed for empty path
		
	# Check if we have enough movement points
	if movement_points < path_length:
		print("PlayerEntity: " + entity_name + " doesn't have enough movement points for path of length " + str(path_length))
		return false
		
	# Consume the movement points
	movement_points = max(0, movement_points - path_length)
	print("PlayerEntity: " + entity_name + " consumed " + str(path_length) + " movement points, " + str(movement_points) + " remaining")
	emit_signal("movement_points_changed", movement_points, max_movement_points)
	
	return true

# Force end the player's turn when requested by UI
func end_turn():
	print("PlayerEntity: " + entity_name + " turn manually ended by player")
	
	# If we're moving, stop movement
	if is_moving:
		path.clear()
		is_moving = false
	
	# Finish the turn
	call_deferred("finish_turn")

# Get the current action points
func get_action_points() -> int:
	return action_points

# Get the current movement points
func get_movement_points() -> int:
	return movement_points

# Called when the entity has completed following its path
func _on_path_completed():
	super._on_path_completed()
	
	# Signal that movement is completed for UI updates
	if is_turn_active:
		emit_signal("action_selection_changed")
