extends Node2D

# This script initializes the game by setting up the map and entities
# Attach this to the main Game scene

# Reference to key nodes
@onready var map = $Map
@onready var game_controller = $GameController

func _ready():
	print("GameInit: Initializing game")
	# Wait for one frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Get references to nodes
	var map_node = get_node_or_null("Map")
	var game_controller = get_node_or_null("GameController")
	
	if map_node and game_controller:
		print("GameInit: Found Map and GameController nodes")
		# Ensure the map has the IsometricMap script or is an instance of IsometricMap
		if map_node.has_method("generate_map"):
			print("GameInit: Map has generate_map method, generating map")
			# Generate the map
			map_node.generate_map()
			
			# Initialize the game controller with the map reference
			print("GameInit: Setting isometric_map reference in GameController")
			game_controller.isometric_map = map_node
			
			# Spawn players at specific positions
			print("GameInit: Spawning players")
			var heavy = game_controller.spawn_player(Vector2i(2, 2), "heavy")
			var scout = game_controller.spawn_player(Vector2i(3, 2), "scout")
			print("GameInit: Spawned " + str(game_controller.player_entities.size()) + " players")
			
			# Spawn some enemies
			print("GameInit: Spawning enemies")
			var grunt = game_controller.spawn_enemy(Vector2i(7, 7), 0)  # Grunt
			var elite = game_controller.spawn_enemy(Vector2i(8, 8), 1)  # Elite
			print("GameInit: Spawned " + str(game_controller.enemy_entities.size()) + " enemies")
			
			# Set up patrol paths for enemies
			if game_controller.enemy_entities.size() > 0:
				print("GameInit: Setting up patrol path for first enemy")
				var patrol_path = [Vector2i(7, 7), Vector2i(7, 5), Vector2i(5, 5), Vector2i(5, 7)]
				game_controller.enemy_entities[0].set_patrol_path(patrol_path)
			
			# Connect to game events
			print("GameInit: Connecting to game events")
			game_controller.connect("turn_changed", Callable(self, "_on_turn_changed"))
			game_controller.connect("game_state_changed", Callable(self, "_on_game_state_changed"))
			
			# Start the game
			print("GameInit: Starting the game")
			game_controller.start_game()
		else:
			push_error("GameInit: Map node does not have generate_map method")
	else:
		push_error("GameInit: Could not find Map or GameController nodes")
		if not map_node:
			push_error("GameInit: Map node not found")
		if not game_controller:
			push_error("GameInit: GameController node not found")

# Handle turn changes
func _on_turn_changed(turn: String):
	print("GameInit: Turn changed to: " + turn)
	
	# You can implement UI updates or other logic here
	# For example, display whose turn it is on the screen

# Handle game state changes
func _on_game_state_changed(state: String):
	print("GameInit: Game state changed to: " + state)
	
	# You can implement UI updates or other logic here
	# For example, show a game over screen if state is "game_over" 
