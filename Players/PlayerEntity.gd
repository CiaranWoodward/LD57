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

func _init():
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

# Start a new turn for this player
func start_turn():
	action_points = max_action_points
	process_status_effects()

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
		emit_signal("ability_used", ability_name)
	
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
	# Assert GameController reference exists
	assert(game_controller != null, "PlayerEntity: " + entity_name + " - GameController reference not set!")
	
	# Store the original path length
	var original_path_size = path.size()
	
	# Call parent implementation
	super.move_along_path(delta)
	
	# If we completed a step, consume an action point
	if path.size() < original_path_size and original_path_size > 0:
		action_points = max(0, action_points - 1)
		print("PlayerEntity: " + entity_name + " used action point, " + str(action_points) + " remaining")
		
		# If we're out of action points, make sure the game controller knows
		if action_points <= 0:
			print("PlayerEntity: " + entity_name + " is out of action points")
			
			# If we can't continue further because we're out of action points, stop and finish movement
			if path.size() > 0:
				print("PlayerEntity: " + entity_name + " stopping movement due to no action points")
				finish_movement()
				
			# Verify GameController has required method
			assert(game_controller.has_method("check_player_action_points"), 
				"PlayerEntity: " + entity_name + " - GameController missing check_player_action_points method!")
			
			# Call deferred to avoid frame timing issues
			call_deferred("notify_zero_action_points")

# Helper to notify GameController about zero action points
func notify_zero_action_points():
	assert(game_controller != null, "PlayerEntity: " + entity_name + " - GameController reference not set!")
	assert(game_controller.has_method("check_player_action_points"), 
		"PlayerEntity: " + entity_name + " - GameController missing check_player_action_points method!")
	
	print("PlayerEntity: " + entity_name + " calling check_player_action_points")
	game_controller.check_player_action_points(self)

# Get the current action points
func get_action_points() -> int:
	return action_points
