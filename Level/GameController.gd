class_name GameController
extends Node

# State machine states
enum GameState {
	IDLE,
	PLAYER_TURN_INIT,
	PLAYER_TURN_ACTIVE,
	PLAYER_TURN_END,
	ENEMY_TURN_INIT,
	ENEMY_TURN_ACTIVE,
	ENEMY_TURN_END,
	GAME_OVER
}

# References to game nodes
var isometric_map = null
var selected_entity = null

# Entity management
var player_entities = []
var enemy_entities = []

# References to scenes
@export var player_entity_scene: PackedScene  # Reference to the player entity scene to instantiate
@export var enemy_entity_scene: PackedScene   # Reference to the enemy entity scene to instantiate

# Game state 
var current_state = GameState.IDLE
var active_player_index: int = 0   # Index of the current active player entity
var processing_enemy_index: int = -1 # Index of the enemy currently being processed
var entities_in_motion: Array = [] # Tracks entities that are currently moving

# Signals
signal turn_changed(turn)
signal entity_moved(entity)
signal game_state_changed(state)
signal player_activated(player_entity)

func _ready():
	print("GameController: Initializing")
	
	# Add self to a group for easier finding by entities
	add_to_group("game_controller")
	
	# Find the map in the scene
	isometric_map = get_node_or_null("../Map")
	if isometric_map:
		print("GameController: Map found, connecting signals")
		isometric_map.connect("tile_selected", Callable(self, "_on_tile_selected"))
	else:
		push_error("GameController: Map not found!")

# State machine handling
func change_state(new_state):
	# Prevent changing to the same state
	if new_state == current_state:
		print("GameController: Already in state " + get_state_name(new_state) + ", ignoring transition")
		return
	
	# Debug output
	var old_state = current_state
	print("GameController: State changing from " + get_state_name(old_state) + " to " + get_state_name(new_state))
	
	# Exit state actions
	match old_state:
		GameState.PLAYER_TURN_ACTIVE:
			# Clean up any player turn specific state
			selected_entity = null
		GameState.ENEMY_TURN_ACTIVE:
			# Clean up any enemy turn specific state
			entities_in_motion.clear()
	
	# Update the state
	current_state = new_state
	
	# Entry state actions
	match new_state:
		GameState.PLAYER_TURN_INIT:
			print("GameController: Initializing player turn")
			# Reset player entities for new turn
			active_player_index = 0
			for player in player_entities:
				player.start_turn()
				print("GameController: Reset player: " + player.entity_name + " with " + str(player.action_points) + " action points")
			
			# Transition to active player turn
			emit_signal("turn_changed", "player")
			emit_signal("game_state_changed", "player_turn")
			
			# Defer the state change to avoid issues with signal processing
			call_deferred("change_state", GameState.PLAYER_TURN_ACTIVE)
			
		GameState.PLAYER_TURN_ACTIVE:
			print("GameController: Starting player turn")
			# Activate first player with action points
			activate_next_player(true)
			
		GameState.PLAYER_TURN_END:
			print("GameController: Ending player turn")
			# Clean up player turn
			selected_entity = null
			
			# Defer the state change to avoid issues with signal processing
			call_deferred("change_state", GameState.ENEMY_TURN_INIT)
			
		GameState.ENEMY_TURN_INIT:
			print("GameController: Initializing enemy turn")
			# Set up enemy turn
			processing_enemy_index = -1
			entities_in_motion.clear()
			
			emit_signal("turn_changed", "enemy")
			emit_signal("game_state_changed", "enemy_turn")
			
			# Defer the state change to avoid issues with signal processing
			call_deferred("change_state", GameState.ENEMY_TURN_ACTIVE)
			
		GameState.ENEMY_TURN_ACTIVE:
			print("GameController: Starting enemy turn")
			# Start processing enemies one by one
			call_deferred("process_next_enemy")
			
		GameState.ENEMY_TURN_END:
			print("GameController: Ending enemy turn")
			# Clean up enemy turn
			entities_in_motion.clear()
			
			# Print debug info for verification
			print("GameController: About to transition to player turn")
			
			# Defer the state change to avoid issues with signal processing
			call_deferred("change_state", GameState.PLAYER_TURN_INIT)
			
		GameState.GAME_OVER:
			print("GameController: Game over")
			emit_signal("game_state_changed", "game_over")

# Returns the name of the state for debugging
func get_state_name(state):
	match state:
		GameState.IDLE: return "IDLE"
		GameState.PLAYER_TURN_INIT: return "PLAYER_TURN_INIT"
		GameState.PLAYER_TURN_ACTIVE: return "PLAYER_TURN_ACTIVE" 
		GameState.PLAYER_TURN_END: return "PLAYER_TURN_END"
		GameState.ENEMY_TURN_INIT: return "ENEMY_TURN_INIT"
		GameState.ENEMY_TURN_ACTIVE: return "ENEMY_TURN_ACTIVE"
		GameState.ENEMY_TURN_END: return "ENEMY_TURN_END"
		GameState.GAME_OVER: return "GAME_OVER"
		_: return "UNKNOWN"

# Called when a tile is selected on the map
func _on_tile_selected(tile):
	print("GameController: Tile selected at " + str(tile.grid_position) + " in state " + get_state_name(current_state))
	
	# Check current state and handle appropriately
	match current_state:
		GameState.PLAYER_TURN_ACTIVE:
			if selected_entity and selected_entity in player_entities:
				print("GameController: Attempting to move entity " + selected_entity.entity_name + " to " + str(tile.grid_position))
				move_entity_to_tile(selected_entity, tile.grid_position)
			else:
				print("GameController: Cannot move entity - no entity selected")
		
		GameState.PLAYER_TURN_INIT:
			print("GameController: Player turn is initializing, please wait...")
			# We're in the process of transitioning to player turn, ignore the selection for now
		
		GameState.ENEMY_TURN_END:
			print("GameController: Enemy turn is ending, please wait for player turn...")
			# We're in the process of transitioning to player turn, ignore the selection for now
		
		_:
			print("GameController: Cannot move - not player turn (current state: " + get_state_name(current_state) + ")")

# Called when an entity is selected
func _on_entity_selected(entity):
	print("GameController: Entity selected: " + entity.entity_name)
	if current_state == GameState.PLAYER_TURN_ACTIVE:
		if entity in player_entities:
			if selected_entity:
				# Deselect previous entity
				print("GameController: Deselecting previous entity")
				# Visual feedback would be implemented here
				pass
			
			selected_entity = entity
			# Update active_player_index to match the selected entity
			active_player_index = player_entities.find(entity)
			print("GameController: New entity selected: " + entity.entity_name + " at index " + str(active_player_index))
			# Visual feedback for selection would be implemented here

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
		
		# Disconnect any existing movement signal to prevent duplicates
		if entity.is_connected("movement_completed", Callable(self, "_on_entity_movement_completed")):
			print("GameController: Disconnecting existing movement signal for " + entity.entity_name)
			entity.disconnect("movement_completed", Callable(self, "_on_entity_movement_completed"))
		
		# Connect the movement_completed signal explicitly
		print("GameController: Connecting movement_completed signal for " + entity.entity_name)
		entity.connect("movement_completed", Callable(self, "_on_entity_movement_completed").bind(entity), CONNECT_ONE_SHOT)
		
		# Add to entities in motion
		if not entity in entities_in_motion:
			entities_in_motion.append(entity)
		
		# Set the path
		entity.set_path(path)
	else:
		print("GameController: No path found to target position")

# Called when an entity completes its movement
func _on_entity_movement_completed(entity):
	print("GameController: Entity " + entity.entity_name + " completed movement in state " + get_state_name(current_state))
	
	# Handle only once per entity per movement cycle
	if not entity in entities_in_motion:
		print("GameController: WARNING - Entity " + entity.entity_name + " movement completed but not in entities_in_motion list!")
	else:
		entities_in_motion.erase(entity)
		print("GameController: Removed " + entity.entity_name + " from entities in motion. Remaining: " + str(entities_in_motion.size()))
	
	emit_signal("entity_moved", entity)
	
	# Handle player turn
	if current_state == GameState.PLAYER_TURN_ACTIVE:
		# Make sure the entity is a player entity
		if entity in player_entities:
			var player = entity
			
			# Check if this is the currently selected player
			if player == selected_entity:
				print("GameController: Player " + player.entity_name + " has " + str(player.action_points) + " action points left")
				
				# If player is out of action points, go to next player
				if player.action_points <= 0:
					print("GameController: Player " + player.entity_name + " out of action points")
					deactivate_current_player()
					
					# Try to activate the next player
					if not activate_next_player():
						# If no players left to activate, end player turn
						print("GameController: No more players to activate, ending turn")
						change_state(GameState.PLAYER_TURN_END)
	
	# Handle enemy turn
	elif current_state == GameState.ENEMY_TURN_ACTIVE:
		# Check if entity is an enemy
		if entity in enemy_entities:
			print("GameController: Enemy " + entity.entity_name + " finished moving")
			
			# Process the next enemy only if all entities have stopped moving
			if entities_in_motion.size() == 0:
				print("GameController: All entities finished moving, processing next enemy")
				call_deferred("process_next_enemy")
		else:
			print("GameController: WARNING - Non-enemy entity " + entity.entity_name + " movement completed during enemy turn")
	
	# Update the visual display after an entity moves
	update_view()

# Process the next enemy in the list
func process_next_enemy():
	print("GameController: Processing next enemy, index: " + str(processing_enemy_index + 1) + "/" + str(enemy_entities.size()))
	print("GameController: Entities in motion: " + str(entities_in_motion.size()))
	
	# Make sure we're still in the enemy turn
	if current_state != GameState.ENEMY_TURN_ACTIVE:
		print("GameController: Not in enemy turn state, aborting enemy processing")
		return
	
	# If we've processed all enemies (index is at or past the last enemy)
	if processing_enemy_index >= enemy_entities.size() - 1:
		print("GameController: All enemies have been processed")
		
		# If no entities are still moving, end the turn
		if entities_in_motion.size() == 0:
			print("GameController: Enemy turn complete, ending turn")
			call_deferred("change_state", GameState.ENEMY_TURN_END)
		else:
			print("GameController: Some entities still moving, waiting for completion")
		return
	
	# Increment to the next enemy
	processing_enemy_index += 1
	
	# Get the current enemy to process
	var enemy = enemy_entities[processing_enemy_index]
	print("GameController: Processing enemy " + enemy.entity_name + " (" + str(processing_enemy_index) + ")")
	
	# Ensure the enemy has its game_controller reference set
	enemy.game_controller = self
	
	# Skip if this enemy is already moving
	if enemy.is_moving:
		print("GameController: Enemy " + enemy.entity_name + " is already moving, adding to tracking")
		if not enemy in entities_in_motion:
			entities_in_motion.append(enemy)
			print("GameController: Added " + enemy.entity_name + " to entities in motion")
		
		# Check if this was the last enemy
		if processing_enemy_index >= enemy_entities.size() - 1:
			print("GameController: Last enemy is already moving, waiting for completion")
		else:
			# Continue to next enemy
			call_deferred("process_next_enemy")
		return
	
	# Disconnect any existing movement signal to prevent duplicates
	if enemy.is_connected("movement_completed", Callable(self, "_on_entity_movement_completed")):
		print("GameController: Disconnecting existing movement signal for " + enemy.entity_name)
		enemy.disconnect("movement_completed", Callable(self, "_on_entity_movement_completed"))
	
	# Connect the movement signal explicitly
	print("GameController: Connecting movement signal for enemy " + enemy.entity_name)
	enemy.connect("movement_completed", Callable(self, "_on_entity_movement_completed").bind(enemy), CONNECT_ONE_SHOT)
	
	# Process the enemy's turn
	print("GameController: Executing turn for enemy " + enemy.entity_name)
	var did_move = enemy.process_turn(player_entities)
	
	if did_move:
		print("GameController: Enemy " + enemy.entity_name + " started moving")
		if not enemy in entities_in_motion:
			entities_in_motion.append(enemy)
			print("GameController: Added " + enemy.entity_name + " to entities in motion")
			
		# If this was the last enemy and it's now moving, we wait for its completion
		if processing_enemy_index >= enemy_entities.size() - 1:
			print("GameController: Last enemy started moving, waiting for completion")
	else:
		print("GameController: Enemy " + enemy.entity_name + " didn't move")
		
		# Check if we've processed all enemies
		if processing_enemy_index >= enemy_entities.size() - 1:
			# If this was the last enemy and no entities are moving, end the turn
			if entities_in_motion.size() == 0:
				print("GameController: All enemies processed with no movement, ending turn")
				call_deferred("change_state", GameState.ENEMY_TURN_END)
			else:
				print("GameController: Last enemy processed but waiting for others to complete movement")
		else:
			# Continue to next enemy
			call_deferred("process_next_enemy")

# Deactivate the current player
func deactivate_current_player():
	if active_player_index < player_entities.size():
		var player = player_entities[active_player_index]
		print("GameController: Deactivating player: " + player.entity_name)
		# Additional visual feedback could be added here
	
	# Clear the selection
	selected_entity = null

# Activate the next player with action points
# If reset is true, start from the first player
func activate_next_player(reset: bool = false):
	if reset:
		active_player_index = -1
	
	print("GameController: Current active player index: " + str(active_player_index))
	active_player_index += 1
	print("GameController: Activating next player, index: " + str(active_player_index))
	
	# Find the next player with action points
	while active_player_index < player_entities.size():
		var player = player_entities[active_player_index]
		if player.action_points > 0:
			selected_entity = player
			print("GameController: Activated player: " + player.entity_name + " with " + str(player.action_points) + " action points")
			emit_signal("player_activated", player)
			return true
		
		print("GameController: Player " + player.entity_name + " has no action points, skipping")
		active_player_index += 1
	
	# If we get here, no players have action points left
	print("GameController: No more players with action points")
	selected_entity = null
	return false

# Update the game view after changes
func update_view():
	# This function refreshes any visual elements that need updating
	emit_signal("entity_moved", null)

# Start a new game
func start_game():
	print("GameController: Starting new game")
	change_state(GameState.PLAYER_TURN_INIT)

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
	entity.connect("entity_selected", Callable(self, "_on_entity_selected"))
	entity.connect("died", Callable(self, "_on_entity_died"))
	
	# Ensure movement signal is connected
	if not entity.is_connected("movement_completed", Callable(self, "_on_entity_movement_completed")):
		print("GameController: Connecting movement signal during spawn for " + entity.entity_name)
		entity.connect("movement_completed", Callable(self, "_on_entity_movement_completed").bind(entity), CONNECT_ONE_SHOT)
	
	# Add to player entities array
	player_entities.append(entity)
	print("GameController: Player " + entity.entity_name + " added to player entities")
	
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
	entity.connect("died", Callable(self, "_on_entity_died"))
	
	# Ensure movement signal is connected before processing
	if not entity.is_connected("movement_completed", Callable(self, "_on_entity_movement_completed")):
		print("GameController: Connecting movement signal during spawn for " + entity.entity_name)
		entity.connect("movement_completed", Callable(self, "_on_entity_movement_completed").bind(entity), CONNECT_ONE_SHOT)
	
	# Add to enemy entities array
	enemy_entities.append(entity)
	print("GameController: Enemy " + entity.entity_name + " added to enemy entities")
	
	return entity

# Called when an entity dies
func _on_entity_died(entity):
	print("GameController: Entity died: " + entity.entity_name)
	# Handle entity death
	if entity in player_entities:
		player_entities.erase(entity)
		print("GameController: Player removed from game, " + str(player_entities.size()) + " players remaining")
		
		# Check if game is over (all players dead)
		if player_entities.size() == 0:
			change_state(GameState.GAME_OVER)
	
	elif entity in enemy_entities:
		enemy_entities.erase(entity)
		print("GameController: Enemy removed from game, " + str(enemy_entities.size()) + " enemies remaining")
		
		# Check if all enemies are defeated
		if enemy_entities.size() == 0:
			# Victory condition
			print("GameController: Victory - all enemies defeated")
			pass

# Called directly from a player entity when they run out of action points
func check_player_action_points(player_entity):
	print("GameController: Checking action points for " + player_entity.entity_name)
	
	# Only handle during player turn
	if current_state != GameState.PLAYER_TURN_ACTIVE:
		print("GameController: Not in player turn, ignoring action point check")
		return
	
	# Make sure this is a player entity
	if not player_entity in player_entities:
		print("GameController: Entity is not a player, ignoring action point check")
		return
	
	# Check if this is the currently selected player
	if player_entity == selected_entity:
		print("GameController: Selected player " + player_entity.entity_name + " is out of action points")
		
		# Check if player is really out of action points
		if player_entity.action_points <= 0:
			print("GameController: Deactivating " + player_entity.entity_name + " and trying next player")
			deactivate_current_player()
			
			# Try to activate the next player
			if not activate_next_player():
				# If no players left to activate, end player turn
				print("GameController: No more players to activate, ending player turn")
				change_state(GameState.PLAYER_TURN_END)
			
	# This is not the active player but still needs to check for game state consistency
	elif player_entity.action_points <= 0:
		print("GameController: Non-active player " + player_entity.entity_name + " is out of action points")
		
		# Check if all players are out of action points
		var all_out_of_points = true
		for player in player_entities:
			if player.action_points > 0:
				all_out_of_points = false
				break
		
		if all_out_of_points:
			print("GameController: All players out of action points, ending player turn")
			change_state(GameState.PLAYER_TURN_END)
