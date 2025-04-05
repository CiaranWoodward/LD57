extends Node2D

# This script initializes the game by setting up the map and entities
# Attach this to the main Game scene

# Reference to key nodes
@onready var map = $Map
@onready var game_controller = $GameController
@onready var end_turn_button = $CanvasLayer/UI/EndTurnButton

func _ready():
	print("GameInit: Initializing game")
	# Wait for one frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Set up UI elements
	setup_ui()
	
	# Get references to nodes
	var map_node = get_node_or_null("Map")
	var game_controller = get_node_or_null("GameController")
	
	if map_node and game_controller:
		print("GameInit: Found Map and GameController nodes")

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
		var grunt = game_controller.spawn_enemy(Vector2i(7, 7), EnemyEntity.EnemyType.GRUNT)
		var elite = game_controller.spawn_enemy(Vector2i(8, 8), EnemyEntity.EnemyType.ELITE)
		print("GameInit: Spawned " + str(game_controller.enemy_entities.size()) + " enemies")
		
		# Set up patrol paths for enemies
		if game_controller.enemy_entities.size() > 0:
			print("GameInit: Setting up patrol path for first enemy")
			var patrol_path = [Vector2i(7, 7), Vector2i(7, 5), Vector2i(5, 5), Vector2i(5, 7)]
			game_controller.enemy_entities[0].set_patrol_path(patrol_path)
		
		# Connect to game events
		print("GameInit: Connecting to game events")
		game_controller.turn_changed.connect(_on_turn_changed)
		game_controller.game_state_changed.connect(_on_game_state_changed)
		
		# Start the game
		print("GameInit: Starting the game")
		game_controller.start_game()
	else:
		push_error("GameInit: Could not find Map or GameController nodes")
		if not map_node:
			push_error("GameInit: Map node not found")
		if not game_controller:
			push_error("GameInit: GameController node not found")

# Set up UI elements
func setup_ui():
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_button_pressed)
		# Initially hide the button until player turn
		end_turn_button.visible = false
	else:
		push_error("GameInit: End Turn Button not found in UI")

# Handle turn changes
func _on_turn_changed(turn: String):
	print("GameInit: Turn changed to: " + turn)
	
	# Show/hide end turn button based on turn
	if end_turn_button:
		end_turn_button.visible = (turn == "player")

# Handle game state changes
func _on_game_state_changed(state: String):
	print("GameInit: Game state changed to: " + state)
	
	# Update UI based on game state
	if state == "player_turn":
		if end_turn_button:
			end_turn_button.visible = true
	else:
		if end_turn_button:
			end_turn_button.visible = false
	
	# Show game over screen if needed
	if state == "game_over":
		print("GameInit: Game over detected, showing end screen")
		# Implementation for game over screen would go here

# Handle end turn button press
func _on_end_turn_button_pressed():
	print("GameInit: End Turn button pressed")
	if game_controller:
		game_controller.end_current_player_turn() 
