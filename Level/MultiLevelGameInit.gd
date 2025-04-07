extends Node2D

# This script initializes the multi-level game by setting up the LevelManager and entities
# Attach this to the main MultiLevelGame scene

# Reference to key nodes
@onready var level_manager = $LevelManager
@onready var game_controller = $GameController
@onready var end_turn_button = Global.hud.get_end_turn_button()

# Level indices for entity management
var current_player_level: int = 0
var enemy_level_distribution: Dictionary = {}  # Level index -> array of enemies

func _ready():
	print("MultiLevelGameInit: Initializing game")
	# Wait for one frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Set up UI elements
	setup_ui()
	
	# Get references to nodes
	if level_manager and game_controller:
		print("MultiLevelGameInit: Found LevelManager and GameController nodes")

		# Initialize the first level
		var first_level = level_manager.initialize_level(0)
		
		# Initialize the game controller with the first level map reference
		print("MultiLevelGameInit: Setting isometric_map reference in GameController")
		game_controller.set_active_level(0, first_level)
		
		# Spawn players at specific positions on the first level
		print("MultiLevelGameInit: Spawning players")
		var heavy = game_controller.spawn_player(Vector2i(2, 2), "heavy", 0)
		var scout = game_controller.spawn_player(Vector2i(3, 2), "scout", 0)
		var wizard = game_controller.spawn_player(Vector2i(4, 2), "wizard", 0)
		print("MultiLevelGameInit: Spawned " + str(game_controller.player_entities.size()) + " players")
		
		# Spawn some enemies on the first level
		print("MultiLevelGameInit: Spawning enemies on first level")
		var hellbomb = game_controller.spawn_enemy(Vector2i(6, 6), EnemyEntity.EnemyType.HELLBOMB, 0)
		
		# Store reference to level 0 enemies
		enemy_level_distribution[0] = []
		for enemy in game_controller.enemy_entities:
			enemy.current_level = 0
			enemy_level_distribution[0].append(enemy)
			
		print("MultiLevelGameInit: Spawned " + str(enemy_level_distribution[0].size()) + " enemies on first level")
		
		# Initialize the second level
		var second_level = level_manager.initialize_level(1)
		
		# Temporarily switch game controller to second level for initialization
		var previous_level = game_controller.current_active_level
		var previous_map = game_controller.isometric_map
		game_controller.set_active_level(1, second_level)
		
		# Spawn enemies on the second level
		print("MultiLevelGameInit: Spawning enemies on second level")
		# Instead of clearing, we keep all existing enemies and add new ones
		var brute = game_controller.spawn_enemy(Vector2i(4, 4), EnemyEntity.EnemyType.ELITE, 1)
		var grunt2 = game_controller.spawn_enemy(Vector2i(9, 9), EnemyEntity.EnemyType.GRUNT, 1)
		
		# Store reference to level 1 enemies
		enemy_level_distribution[1] = []
		for enemy in game_controller.enemy_entities:
			if enemy.current_level != 0:  # Only process new enemies from level 1
				enemy.current_level = 1
				enemy_level_distribution[1].append(enemy)
				
		print("MultiLevelGameInit: Spawned " + str(enemy_level_distribution[1].size()) + " enemies on second level")
		
		# Set up patrol paths for second level enemies
		var patrol_path = [Vector2i(4, 4), Vector2i(4, 6), Vector2i(6, 6), Vector2i(6, 4)]
		enemy_level_distribution[1][0].set_patrol_path(patrol_path)
		
		# Restore game controller to first level for now
		game_controller.set_active_level(previous_level, previous_map)
		
		# Connect to game events
		print("MultiLevelGameInit: Connecting to game events")
		game_controller.turn_changed.connect(_on_turn_changed)
		game_controller.game_state_changed.connect(_on_game_state_changed)
		
		# Connect to LevelManager events
		level_manager.player_descended.connect(_on_player_descended)
		
		# Start the game
		print("MultiLevelGameInit: Starting the game")
		game_controller.start_game()
	else:
		push_error("MultiLevelGameInit: Could not find LevelManager or GameController nodes")
		if not level_manager:
			push_error("MultiLevelGameInit: LevelManager node not found")
		if not game_controller:
			push_error("MultiLevelGameInit: GameController node not found")

# Set up UI elements
func setup_ui():
	if end_turn_button:
		# Initially hide the button until player turn
		end_turn_button.visible = false
	else:
		push_error("MultiLevelGameInit: End Turn Button not found in UI")

# Handle turn changes
func _on_turn_changed(turn: String):
	print("MultiLevelGameInit: Turn changed to: " + turn)
	
	# Show/hide end turn button based on turn
	if end_turn_button:
		end_turn_button.visible = (turn == "player")

# Handle game state changes
func _on_game_state_changed(state: String):
	print("MultiLevelGameInit: Game state changed to: " + state)
	
	# Update UI based on game state
	if state == "player_turn":
		if end_turn_button:
			end_turn_button.visible = true
	else:
		if end_turn_button:
			end_turn_button.visible = false
	
	# Show game over screen if needed
	if state == "game_over":
		print("MultiLevelGameInit: Game over detected, showing end screen")
		# Implementation for game over screen would go here

# Handle player descended event
func _on_player_descended(player, from_level, to_level):
	print("MultiLevelGameInit: Player " + str(player.name) + " descended from level " + str(from_level) + " to " + str(to_level))
	
	# The player's current_level is already updated by the LevelManager
	
	# Count how many players are on each level
	var players_per_level = {}
	for player_entity in game_controller.player_entities:
		var level = player_entity.current_level
		if not players_per_level.has(level):
			players_per_level[level] = 0
		players_per_level[level] += 1
	
	# Find the level with the most players to focus on
	var focus_level = 0
	var max_players = 0
	for level in players_per_level:
		if players_per_level[level] > max_players:
			max_players = players_per_level[level]
			focus_level = level
	
	# Switch the camera and active map to the focus level
	if focus_level != current_player_level:
		game_controller.set_active_level(focus_level, level_manager.level_nodes[focus_level])
		current_player_level = focus_level
		print("MultiLevelGameInit: Focus shifted to level " + str(focus_level) + " with " + str(max_players) + " players")
