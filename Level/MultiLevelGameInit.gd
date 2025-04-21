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

# Entity type mapping dictionary
var entity_type_map = {
	"hellbomb": EnemyEntity.EnemyType.HELLBOMB,
	"hellbomb_chaser": EnemyEntity.EnemyType.HELLBOMB_CHASER,
	"minion": EnemyEntity.EnemyType.MINION,
	"elite": EnemyEntity.EnemyType.ELITE,
	"grunt": EnemyEntity.EnemyType.GRUNT,
	"boss": EnemyEntity.EnemyType.BOSS
}

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
		
		# Connect to the entities_to_spawn signal
		first_level.entities_to_spawn.connect(_on_level_entities_to_spawn.bind(0))
		
		# Initialize the game controller with the first level map reference
		print("MultiLevelGameInit: Setting isometric_map reference in GameController")
		game_controller.set_active_level(0, first_level)
		
		# Initialize additional levels and connect signals
		var all_levels = [first_level]
		for level_index in range(1, level_manager.level_maps.size()):
			print("MultiLevelGameInit: Initializing level " + str(level_index))
			var new_level = level_manager.initialize_level(level_index)
			
			# Ensure the newly created level is initially invisible
			new_level.visible = false
			new_level.modulate = Color(1.0, 1.0, 1.0, 0.0)
			new_level.set_meta("is_visible_to_player", false)
			
			# Connect to the entities_to_spawn signal for this level
			new_level.entities_to_spawn.connect(_on_level_entities_to_spawn.bind(level_index))
			all_levels.append(new_level)
		
		# Connect to game events
		print("MultiLevelGameInit: Connecting to game events")
		game_controller.turn_changed.connect(_on_turn_changed)
		game_controller.game_state_changed.connect(_on_game_state_changed)
		
		# Connect to LevelManager events
		level_manager.player_descended.connect(_on_player_descended)
		
		# Now that all connections are established, initialize entities for each level
		print("MultiLevelGameInit: Initializing entities for all levels")
		for level in all_levels:
			level.initialize_entities()
		
		# Start the game
		print("MultiLevelGameInit: Starting the game")
		game_controller.start_game()
	else:
		push_error("MultiLevelGameInit: Could not find LevelManager or GameController nodes")
		if not level_manager:
			push_error("MultiLevelGameInit: LevelManager node not found")
		if not game_controller:
			push_error("MultiLevelGameInit: GameController node not found")

# Handle entities to spawn in a level
func _on_level_entities_to_spawn(entity_list, level_index):
	print("MultiLevelGameInit: Received entities_to_spawn signal for level " + str(level_index) + " with " + str(entity_list.size()) + " entities")
	
	# Add further details about entities
	for entity in entity_list:
		print("MultiLevelGameInit: Entity to spawn - type: " + str(entity.entity_type) + " at position: " + str(entity.position))
	
	# Store original active level and map to restore later
	var previous_level = game_controller.current_active_level
	var previous_map = game_controller.isometric_map
	
	print("MultiLevelGameInit: Current active level is " + str(previous_level) + ", temporarily switching to level " + str(level_index))
	
	# Temporarily switch game controller to the target level for initialization
	var target_level_map = level_manager.level_nodes[level_index]
	game_controller.set_active_level(level_index, target_level_map)
	
	# Store original enemy entities to restore them later (if switching levels)
	var original_enemies = []
	if level_index != previous_level:
		for enemy in game_controller.enemy_entities:
			original_enemies.append(enemy)
		# Clear enemy entities temporarily to avoid mixing levels
		game_controller.enemy_entities = []
	
	# Create array to track enemies spawned on this level
	if not enemy_level_distribution.has(level_index):
		enemy_level_distribution[level_index] = []
	
	# Process each entity to spawn
	var spawned_players = 0
	var spawned_enemies = 0
	
	for entity_info in entity_list:
		var position = entity_info.position
		var entity_type = entity_info.entity_type
		
		# Handle player entities
		if entity_type == "player_heavy":
			var player = game_controller.spawn_player(position, "heavy", level_index)
			if player:
				spawned_players += 1
				print("MultiLevelGameInit: Spawned heavy player at " + str(position) + " on level " + str(level_index))
		elif entity_type == "player_scout":
			var player = game_controller.spawn_player(position, "scout", level_index)
			if player:
				spawned_players += 1
				print("MultiLevelGameInit: Spawned scout player at " + str(position) + " on level " + str(level_index))
		elif entity_type == "player_wizard":
			var player = game_controller.spawn_player(position, "wizard", level_index)
			if player:
				spawned_players += 1
				print("MultiLevelGameInit: Spawned wizard player at " + str(position) + " on level " + str(level_index))
		# Handle enemy entities
		elif entity_type_map.has(entity_type):
			print("MultiLevelGameInit: Attempting to spawn enemy " + entity_type + " at " + str(position))
			var enemy_enum_type = entity_type_map[entity_type]
			var enemy = game_controller.spawn_enemy(position, enemy_enum_type, level_index)
			if enemy:
				enemy_level_distribution[level_index].append(enemy)
				spawned_enemies += 1
				print("MultiLevelGameInit: Successfully spawned " + entity_type + " at " + str(position))
				
				# Generate random patrol path for certain enemy types
				if entity_type == "grunt" or entity_type == "minion" or entity_type == "elite":
					var patrol_path = level_manager.generate_random_patrol_path(target_level_map, position)
					enemy.set_patrol_path(patrol_path)
					print("MultiLevelGameInit: Set random patrol path for " + entity_type + " at " + str(position))
	
	print("MultiLevelGameInit: Spawned " + str(spawned_players) + " players and " + 
		str(spawned_enemies) + " enemies on level " + str(level_index))
	
	# If we switched levels, restore the original enemies and add the new ones
	if level_index != previous_level:
		var new_enemies = game_controller.enemy_entities.duplicate()
		game_controller.enemy_entities = original_enemies
		game_controller.enemy_entities.append_array(new_enemies)
		
		# Restore game controller to previous level
		game_controller.set_active_level(previous_level, previous_map)
		print("MultiLevelGameInit: Restored game controller to level " + str(previous_level))
	
	# If this is a deeper level, ensure it remains invisible after initialization
	if level_index > 0:
		target_level_map.visible = false
		target_level_map.set_meta("is_visible_to_player", false)
		print("MultiLevelGameInit: Set level " + str(level_index) + " to invisible for now")

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
