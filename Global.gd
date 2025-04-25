extends Node

signal xp_changed(new_xp: int)
signal deepest_layer_changed(new_layer: int)

# Global game state and utility functions
var debug_mode: bool = true
var current_level: int = 1
var hud : HUD = null
var upgrade_menu : UpgradeMenu = null
var xp: int = 0  # Global XP counter shared between all players
var main_node = null  # Reference to the Main node

# Additional tracking variables
var total_xp_acquired: int = 0  # Tracks all positive XP, regardless of spending
var enemies_killed: int = 0  # Tracks total number of enemies killed
var deepest_layer_reached: int = 1  # Tracks the deepest layer of the map reached

func _ready():
	print("Global singleton initialized")

# Register the Main node with the singleton
func register_main(main_instance):
	main_node = main_instance
	print("Global: Main node registered")

# Call gameover function on the Main node
func gameover(state):
	if main_node:
		main_node.gameover(state)
	else:
		push_error("Global: Cannot call gameover - Main node not registered")

# Utility function to get a file path
func get_resource_path(resource_name: String) -> String:
	return "res://" + resource_name 

# Add XP to the global counter
func add_xp(amount: int):
	xp += amount
	
	# Also track total positive XP acquired
	if amount > 0:
		total_xp_acquired += amount
		
	print("Global: Added " + str(amount) + " XP, new total: " + str(xp))
	
	# Update the HUD if it exists
	if hud:
		hud.update_xp_counter(xp)
		
	# Emit signal with new XP value
	xp_changed.emit(xp)

# Increment the enemy kill counter
func increment_enemy_kill_count():
	enemies_killed += 1
	print("Global: Enemy killed, total enemies defeated: " + str(enemies_killed))

# Update the deepest layer reached
func update_deepest_layer(layer: int):
	if layer > deepest_layer_reached:
		deepest_layer_reached = layer
		print("Global: New deepest layer reached: " + str(deepest_layer_reached))
		
		# Emit signal with new deepest layer
		deepest_layer_changed.emit(deepest_layer_reached)

# Reset all tracking statistics when starting a new game
func reset_stats():
	xp = 0
	total_xp_acquired = 0
	enemies_killed = 0
	deepest_layer_reached = 1
	print("Global: Stats reset for new game")
	# Emit signal with reset XP value
	xp_changed.emit(xp) 
