class_name GameController
extends Node

# State machine states
enum GameState {
	IDLE,
	PLAYER_TURN_ACTIVE,
	ENEMY_TURN_ACTIVE,
	GAME_OVER
}

# References to game nodes
var isometric_map = null
var selected_entity = null
var turn_sequencer = null

# Entity management
var player_entities = []
var enemy_entities = []

# Game state 
var current_state = GameState.IDLE
var current_turn_count: int = 0  # Tracks the number of turns that have passed

# Signals
signal turn_changed(turn)
signal entity_moved(entity)
signal game_state_changed(state)
signal player_activated(player_entity)
signal turn_count_updated(count)

func _ready():
	print("GameController: Initializing")
	
	# Add self to a group for easier finding by entities
	add_to_group("game_controller")
	
	# Find the map in the scene
	isometric_map = get_node_or_null("../Map")
	if isometric_map:
		print("GameController: Map found, connecting signals")
		isometric_map.tile_selected.connect(_on_tile_selected)
	else:
		push_error("GameController: Map not found!")
	
	# Create a TurnSequencer
	turn_sequencer = TurnSequencer.new()
	add_child(turn_sequencer)
	
	# Connect turn sequencer signals
	turn_sequencer.turn_started.connect(_on_turn_started)
	turn_sequencer.turn_ended.connect(_on_turn_ended)
	turn_sequencer.group_turns_started.connect(_on_group_turns_started)
	turn_sequencer.group_turns_completed.connect(_on_group_turns_completed)
	
	print("GameController: TurnSequencer created and connected")

# State machine handling
func change_state(new_state):
	# Prevent changing to the same state
	if new_state == current_state:
		print("GameController: Already in state " + get_state_name(new_state) + ", ignoring transition")
		return
	
	# Debug output
	var old_state = current_state
	print("GameController: State changing from " + get_state_name(old_state) + " to " + get_state_name(new_state))
	
	# Update the state
	current_state = new_state
	
	# Entry state actions
	match new_state:
		GameState.PLAYER_TURN_ACTIVE:
			print("GameController: Player turn active")
			emit_signal("turn_changed", "player")
			emit_signal("game_state_changed", "player_turn")
			
		GameState.ENEMY_TURN_ACTIVE:
			print("GameController: Enemy turn active")
			emit_signal("turn_changed", "enemy")
			emit_signal("game_state_changed", "enemy_turn")
			
		GameState.GAME_OVER:
			print("GameController: Game over")
			emit_signal("game_state_changed", "game_over")

# Returns the name of the state for debugging
func get_state_name(state):
	match state:
		GameState.IDLE: return "IDLE"
		GameState.PLAYER_TURN_ACTIVE: return "PLAYER_TURN_ACTIVE" 
		GameState.ENEMY_TURN_ACTIVE: return "ENEMY_TURN_ACTIVE"
		GameState.GAME_OVER: return "GAME_OVER"
		_: return "UNKNOWN"

# Called when a tile is selected on the map
func _on_tile_selected(tile):
	print("GameController: Tile selected at " + str(tile.grid_position) + " in state " + get_state_name(current_state))
	
	# Check if a player entity is selected and it's the player's turn
	if current_state == GameState.PLAYER_TURN_ACTIVE and selected_entity and selected_entity in player_entities and selected_entity.is_turn_active:
		print("GameController: Attempting to move entity " + selected_entity.entity_name + " to " + str(tile.grid_position))
		move_entity_to_tile(selected_entity, tile.grid_position)
	else:
		print("GameController: Cannot move - no selected entity or not player turn")

# Called when an entity is selected
func _on_entity_selected(entity):
	print("GameController: Entity selected: " + entity.entity_name)
	
	# Only allow selection of player entities during their turn
	if current_state == GameState.PLAYER_TURN_ACTIVE and entity in player_entities and entity.is_turn_active:
		if selected_entity:
			# Deselect previous entity
			print("GameController: Deselecting previous entity")
			# Visual feedback would be implemented here
			pass
		
		selected_entity = entity
		print("GameController: New entity selected: " + entity.entity_name)
		# Visual feedback for selection would be implemented here
		emit_signal("player_activated", entity)

# Move an entity to a specific tile
func move_entity_to_tile(entity, target_grid_pos):
	if not entity or not isometric_map:
		push_error("GameController: Cannot move entity - entity or map is null")
		return
		
	# Check if entity is already moving
	if entity.is_moving:
		print("GameController: Entity is already moving, cannot set new path")
		return
		
	# For player entities, check action points
	if entity in player_entities:
		if entity.action_points <= 0:
			# Not enough action points
			print("GameController: Entity has no action points left")
			return
	
	# Get the target tile
	var target_tile = isometric_map.get_tile(target_grid_pos)
	if not target_tile:
		print("GameController: Cannot move - target tile does not exist")
		return
	
	# Check if target tile is walkable
	if not target_tile.is_walkable:
		print("GameController: Cannot move - target tile is not walkable")
		return
	
	# Check if target tile is already occupied by a different entity
	if target_tile.is_occupied and target_tile != entity.current_tile:
		print("GameController: Cannot move - target tile is already occupied")
		return
	
	# Get the path to the target (A* will also verify tile occupation)
	var path = isometric_map.find_path(entity.grid_position, target_grid_pos)
	
	if path.size() > 0:
		print("GameController: Path found with " + str(path.size()) + " steps")
		
		# Set the entity's game_controller reference
		entity.game_controller = self
		
		# Set the path
		entity.set_path(path)
		
		# Signal that entity is moving
		emit_signal("entity_moved", entity)
	else:
		print("GameController: No path found to target position")

# Event handler for when a turn starts for a character
func _on_turn_started(character):
	print("GameController: Character " + character.entity_name + " turn started")
	
	# If this is a player entity, activate it in the UI
	if character in player_entities:
		selected_entity = character
		emit_signal("player_activated", character)

# Event handler for when a turn ends for a character
func _on_turn_ended(character):
	print("GameController: Character " + character.entity_name + " turn ended")
	
	# If this was a player entity, deselect it
	if character in player_entities and selected_entity == character:
		selected_entity = null

# Event handler for when a group starts its turns
func _on_group_turns_started(group_name):
	print("GameController: Group " + group_name + " turns starting")
	
	if group_name == "player":
		change_state(GameState.PLAYER_TURN_ACTIVE)
	elif group_name == "enemy":
		change_state(GameState.ENEMY_TURN_ACTIVE)

# Event handler for when a group completes all its turns
func _on_group_turns_completed(group_name):
	print("GameController: Group " + group_name + " turns completed")
	
	if group_name == "player":
		# After all players have finished their turns, start enemy turns
		turn_sequencer.start_group_turns("enemy")
	elif group_name == "enemy":
		# After all enemies have finished their turns, increase turn count
		current_turn_count += 1
		print("GameController: Turn " + str(current_turn_count) + " completed")
		emit_signal("turn_count_updated", current_turn_count)
		
		# Start player turns again
		turn_sequencer.start_group_turns("player")

# Update the game view after changes
func update_view():
	# This function refreshes any visual elements that need updating
	emit_signal("entity_moved", null)

# Start a new game
func start_game():
	print("GameController: Starting new game")
	current_turn_count = 0
	# Start the first player turn
	turn_sequencer.start_group_turns("player")

# Force the current player to end their turn
func end_current_player_turn():
	if current_state == GameState.PLAYER_TURN_ACTIVE and selected_entity and selected_entity in player_entities:
		if selected_entity.has_method("end_turn"):
			print("GameController: Manually ending turn for " + selected_entity.entity_name)
			selected_entity.end_turn()
		else:
			print("GameController: Selected player entity does not have end_turn method")
	else:
		print("GameController: No player selected or not in player turn state")

# Get all player entities - used by enemy AI
func get_player_entities():
	return player_entities

# Spawn an entity helper function
func _spawn_entity_helper(entity, grid_pos):
	# Set the map reference
	entity.isometric_map = isometric_map
	
	# Ensure game_controller reference is set
	entity.game_controller = self
	
	# Add entity to the map's Y-sorted container
	if isometric_map:
		isometric_map.add_entity(entity)
	else:
		push_error("GameController: Cannot spawn entity - map is null")
		return false
	
	# Place on the tile
	var tile = isometric_map.get_tile(grid_pos)
	if tile:
		entity.place_on_tile(tile)
		print("GameController: Entity placed on tile at " + str(grid_pos))
		
		# One more check to ensure the entity still has its GameController reference
		if entity.game_controller != self:
			print("GameController: WARNING - Entity lost GameController reference during placement, restoring")
			entity.game_controller = self
			
		return true
	else:
		push_error("GameController: Could not find tile at " + str(grid_pos))
		return false

# Spawn a player entity on the map
func spawn_player(grid_pos, player_type: String):
	print("GameController: Spawning player of type " + player_type + " at " + str(grid_pos))
	var entity
	
	# Instantiate the appropriate player scene based on type
	match player_type.to_lower():
		"heavy":
			entity = load("res://Players/HeavyPlayer.tscn").instantiate()
		
		"support":
			entity = load("res://Players/SupportPlayer.tscn").instantiate()
		
		"scout":
			entity = load("res://Players/ScoutPlayer.tscn").instantiate()
		
		"medic":
			entity = load("res://Players/MedicPlayer.tscn").instantiate()
		
		_:
			# Fallback to generic player if type not recognized
			push_error("GameController: Unknown player type: " + player_type)
			return null
	
	# Explicitly set the game_controller reference
	entity.game_controller = self
	print("GameController: Set self as game_controller for " + entity.entity_name)
	
	# Place the entity on the map
	if not _spawn_entity_helper(entity, grid_pos):
		return null
	
	# Connect signals
	entity.entity_selected.connect(_on_entity_selected)
	entity.died.connect(_on_entity_died)
	
	# Add to player entities array
	player_entities.append(entity)
	print("GameController: Player " + entity.entity_name + " added to player entities")
	
	# Add to turn sequencer's player group
	turn_sequencer.add_character_to_group(entity, "player")
	print("GameController: Player " + entity.entity_name + " added to turn sequencer player group")
	
	return entity

# Spawn an enemy on the map
func spawn_enemy(grid_pos, enemy_type_id):
	print("GameController: Spawning enemy of type " + str(enemy_type_id) + " at " + str(grid_pos))
	var entity
	
	# Instantiate the appropriate enemy scene based on type
	match enemy_type_id:
		EnemyEntity.EnemyType.GRUNT:
			entity = load("res://Enemies/GruntEnemy.tscn").instantiate()
		
		EnemyEntity.EnemyType.ELITE:
			entity = load("res://Enemies/EliteEnemy.tscn").instantiate()
		
		EnemyEntity.EnemyType.BOSS:
			entity = load("res://Enemies/BossEnemy.tscn").instantiate()
		
		EnemyEntity.EnemyType.MINION:
			entity = load("res://Enemies/MinionEnemy.tscn").instantiate()
		
		_:
			# Fallback to generic enemy if type not recognized
			push_error("GameController: Unknown enemy type: " + str(enemy_type_id))
			return null
	
	# Explicitly set the game_controller reference
	entity.game_controller = self
	print("GameController: Set self as game_controller for " + entity.entity_name)
	
	# Place the entity on the map
	if not _spawn_entity_helper(entity, grid_pos):
		return null
	
	# Connect signals
	entity.died.connect(_on_entity_died)
	
	# Add to enemy entities array
	enemy_entities.append(entity)
	print("GameController: Enemy " + entity.entity_name + " added to enemy entities")
	
	# Add to turn sequencer's enemy group
	turn_sequencer.add_character_to_group(entity, "enemy")
	print("GameController: Enemy " + entity.entity_name + " added to turn sequencer enemy group")
	
	return entity

# Called when an entity dies
func _on_entity_died(entity):
	print("GameController: Entity died: " + entity.entity_name)
	# Handle entity death
	if entity in player_entities:
		player_entities.erase(entity)
		print("GameController: Player removed from game, " + str(player_entities.size()) + " players remaining")
		
		# Remove from turn sequencer
		turn_sequencer.remove_character(entity)
		
		# If this was the selected entity, clear the selection
		if selected_entity == entity:
			selected_entity = null
		
		# Check if game is over (all players dead)
		if player_entities.size() == 0:
			change_state(GameState.GAME_OVER)
	
	elif entity in enemy_entities:
		enemy_entities.erase(entity)
		print("GameController: Enemy removed from game, " + str(enemy_entities.size()) + " enemies remaining")
		
		# Remove from turn sequencer
		turn_sequencer.remove_character(entity)
		
		# Check if all enemies are defeated
		if enemy_entities.size() == 0:
			# Victory condition
			print("GameController: Victory - all enemies defeated")
			change_state(GameState.GAME_OVER)
