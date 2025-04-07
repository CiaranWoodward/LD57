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
		var hellbomb_chaser = game_controller.spawn_enemy(Vector2i(6, 7), EnemyEntity.EnemyType.HELLBOMB_CHASER, 0)
		var minion = game_controller.spawn_enemy(Vector2i(6, 8), EnemyEntity.EnemyType.MINION, 0)
		
		# Store reference to level 0 enemies
		enemy_level_distribution[0] = []
		for enemy in game_controller.enemy_entities:
			enemy.current_level = 0
			enemy_level_distribution[0].append(enemy)
			
		print("MultiLevelGameInit: Spawned " + str(enemy_level_distribution[0].size()) + " enemies on first level")
		
		# Initialize the second level
		var enemies_level_1 = [
			[Vector2i(4, 4), EnemyEntity.EnemyType.ELITE, [Vector2i(4, 4), Vector2i(4, 6), Vector2i(6, 6), Vector2i(6, 4)]],
			[Vector2i(9, 9), EnemyEntity.EnemyType.GRUNT, [Vector2i(9, 9), Vector2i(1, 4), Vector2i(3, 2), Vector2i(12, 14)]]
		]
		initialise_additional_levels(1, enemies_level_1)
		
		var enemies_level_2 = [
			[Vector2i(7, 3), EnemyEntity.EnemyType.ELITE, [Vector2i(7, 3), Vector2i(14, 1), Vector2i(1, 3), Vector2i(6, 4)]],
			[Vector2i(2, 5), EnemyEntity.EnemyType.GRUNT, [Vector2i(2, 5), Vector2i(1, 4), Vector2i(3, 2), Vector2i(12, 14)]],
			[Vector2i(12, 11), EnemyEntity.EnemyType.GRUNT, [Vector2i(12, 11), Vector2i(10, 8), Vector2i(9, 5), Vector2i(14, 8)]]
		]
		initialise_additional_levels(2, enemies_level_2)
		
		var enemies_level_3 = [
			[Vector2i(7, 7), EnemyEntity.EnemyType.BOSS, [Vector2i(2, 7), Vector2i(7, 13), Vector2i(14, 7), Vector2i(7, 2)]]
		]
		initialise_additional_levels(3, enemies_level_3)
		
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

func initialise_additional_levels(level_index, enemies):
	var new_level = level_manager.initialize_level(level_index)
		
	# Temporarily switch game controller to second level for initialization
	var previous_level = game_controller.current_active_level
	var previous_map = game_controller.isometric_map
	game_controller.set_active_level(level_index, new_level)
		
	# Spawn enemies on the second level
	print("MultiLevelGameInit: Spawning enemies on level " + str(level_index))
	# Instead of clearing, we keep all existing enemies and add new ones
	
	for enemy in game_controller.enemy_entities:
		if enemy.current_level == 0:  # This may cause problems, previous version assumed only one previous level existed
			enemy.current_level = -1
	
	for enemy in enemies:
		game_controller.spawn_enemy(enemy[0], enemy[1])
	
	# Store reference to level 1 enemies
	enemy_level_distribution[level_index] = []
	for enemy in game_controller.enemy_entities:
		if enemy.current_level == 0:
			enemy.current_level = level_index
			enemy_level_distribution[level_index].append(enemy)
	
	for enemy in game_controller.enemy_entities:
		if enemy.current_level == -1:  # This may cause problems, previous version assumed only one previous level existed
			enemy.current_level = 0
	
	print("MultiLevelGameInit: Spawned " + str(enemy_level_distribution[1].size()) + " enemies on level" + str(level_index))
	
	# Set up patrol paths for second level enemies
	for i in range(enemies.size()):
		enemy_level_distribution[level_index][i].set_patrol_path(enemies[i][2]) 
	
	# Restore game controller to first level for now
	game_controller.set_active_level(previous_level, previous_map)

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
