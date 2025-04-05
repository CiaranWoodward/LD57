class_name PlayerEntity
extends Entity

# Player-specific properties
var action_points: int = 3
var max_action_points: int = 3
var abilities: Array = []
var experience: int = 0
var level: int = 1

# Signals
signal ability_used(ability_name)
signal level_up(new_level)
signal action_points_changed(current, maximum)
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
	move_speed = 1.0
	abilities = []

# Override start_turn from Entity
func start_turn():
	# Call parent implementation first
	super.start_turn()
	
	# Reset action points for new turn
	action_points = max_action_points
	emit_signal("action_points_changed", action_points, max_action_points)
	
	# Process status effects
	process_status_effects()
	
	# Players wait for user input, so don't finish turn automatically
	# The turn will be finished by the user's actions (movement/abilities)
	# or by the UI "End Turn" button
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
		action_points -= ap_cost
		emit_signal("action_points_changed", action_points, max_action_points)
		emit_signal("ability_used", ability_name)
		emit_signal("action_selection_changed")
		
		# Check if we should finish our turn due to no action points
		if action_points <= 0:
			print("PlayerEntity: " + entity_name + " out of action points after ability, finishing turn")
			call_deferred("finish_turn")
	
	return success

# Get the action point cost for an ability
# Override in subclasses with specific costs
func get_ability_cost(ability_name: String) -> int:
	return 1  # Default cost of 1 AP

# Execute an ability - override in subclasses with specific ability implementations
func execute_ability(ability_name: String, target) -> bool:
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
	# Default behavior - increase action points
	max_action_points += 1

# Override move_along_path to consume action points
func move_along_path(delta: float):
	# Store the original path length
	var original_path_size = path.size()
	
	# Call parent implementation
	super.move_along_path(delta)
	
	# If we completed a step, consume an action point
	if path.size() < original_path_size and original_path_size > 0:
		action_points = max(0, action_points - 1)
		print("PlayerEntity: " + entity_name + " used action point, " + str(action_points) + " remaining")
		emit_signal("action_points_changed", action_points, max_action_points)
		
		# If we're out of action points, stop movement and finish turn
		if action_points <= 0 and path.size() > 0:
			print("PlayerEntity: " + entity_name + " stopping movement due to no action points")
			path.clear()
			is_moving = false
			call_deferred("_on_path_completed")
		
		# Otherwise, check if the player has completed all their movement
		if path.size() == 0 and action_points <= 0:
			print("PlayerEntity: " + entity_name + " out of action points after movement, finishing turn")
			call_deferred("finish_turn")

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

# Called when the entity has completed following its path
func _on_path_completed():
	super._on_path_completed()
	
	# Check if this was during our turn, and if so, we might finish our turn
	if is_turn_active:
		if action_points == 0:
			print("Entity: " + entity_name + " will finish turn after movement completed")
			call_deferred("finish_turn")
		else:
			emit_signal("action_selection_changed")
