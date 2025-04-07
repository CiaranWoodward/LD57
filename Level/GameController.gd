class_name GameController
extends Node2D

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
var level_manager = null

# Entity management
var player_entities = []
var enemy_entities = []

# Game state 
var current_state = GameState.IDLE
var current_turn_count: int = 0  # Tracks the number of turns that have passed
var current_ability: String = ""  # Currently selected ability waiting for a target

# Add a property to track the current active level
var current_active_level: int = 0

# Drilling visualization
var drilling_line_node: Line2D = null

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
	
	# Set process input
	set_process_input(true)
	
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
	
	# Get the reference to the LevelManager
	level_manager = get_parent().get_node_or_null("LevelManager")
	if not level_manager:
		push_error("GameController: LevelManager not found")
	else:
		print("GameController: Found LevelManager")
		
	# Connect to HUD signals
	_connect_hud_signals()
		
	# Create the drilling line visualization
	drilling_line_node = Line2D.new()
	drilling_line_node.width = 5.0
	drilling_line_node.default_color = Color(1.0, 0.5, 0.0, 0.8)  # Orange-ish, semi-transparent
	drilling_line_node.z_index = 100  # Display above other elements
	drilling_line_node.visible = false
	add_child(drilling_line_node)

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

# Reset the current ability and clear highlights
func cancel_current_ability():
	if current_ability != "":
		print("GameController: Canceling ability " + current_ability)
		
		# Save the current ability before resetting it
		var prev_ability = current_ability
		current_ability = ""
		
		# Use the HUD's update method to properly reset button states
		if Global.hud:
			Global.hud.update_action_buttons()
		
		# Reset highlights and restore movement range if applicable
		update_highlights()

# Called when a tile is selected on the map
func _on_tile_selected(tile):
	# Find which level map contains this tile
	var tile_level = current_active_level
	
	if level_manager:
		for level_idx in level_manager.level_nodes:
			var level_map = level_manager.level_nodes[level_idx]
			if level_map.tiles.has(tile.grid_position) and level_map.tiles[tile.grid_position] == tile:
				tile_level = level_idx
				break
	
	print("GameController: Tile selected at " + str(tile.grid_position) + " on level " + str(tile_level) + " in state " + get_state_name(current_state))
	
	# Check if a player entity is selected and it's the player's turn
	if current_state == GameState.PLAYER_TURN_ACTIVE and selected_entity and selected_entity in player_entities and selected_entity.is_turn_active:
		# Check if we're waiting for a target for a specific ability
		if current_ability != "":
			print("GameController: Processing ability " + current_ability + " targeting tile at " + str(tile.grid_position))
			
			# Handle tile selection for abilities
			_handle_tile_selection_for_abilities(tile, selected_entity)
			
			return
		
		# First check if the tile is highlighted for an action
		elif tile.is_action_target:
			_handle_action_target_tile(tile, selected_entity)
			return
		
		# If not an ability target, try to move to the tile
		# Make sure the tile is on the same level as the player
		if tile_level == selected_entity.current_level:
			print("GameController: Attempting to move entity " + selected_entity.entity_name + " to " + str(tile.grid_position) + " on level " + str(selected_entity.current_level))
			move_entity_to_tile(selected_entity, tile.grid_position)
		else:
			print("GameController: Cannot move - tile is on level " + str(tile_level) + " but player is on level " + str(selected_entity.current_level))
	else:
		print("GameController: Cannot move - no selected entity or not player turn")

# Handle tiles marked as action targets
func _handle_action_target_tile(tile: IsometricTile, entity: PlayerEntity):
	print("GameController: Tile is an action target, checking for abilities")
			
	# Check if the player has the drill_smash ability
	if entity.abilities.has("drill_smash") and entity is HeavyPlayer:
		# Calculate direction from player to tile to verify it's a valid target
		var direction = tile.grid_position - entity.grid_position
		if abs(direction.x) + abs(direction.y) == 1:  # Adjacent in cardinal direction
			print("GameController: Using drill_smash ability on tile at " + str(tile.grid_position))
			entity.use_ability("drill_smash", tile)
			
			# Clear highlights after using the ability
			clear_all_highlights()
			
			# Highlight movement range if the player still has movement points
			if entity.movement_points > 0:
				highlight_movement_range(entity)
			
			return

# Handle tile selection for abilities
func _handle_tile_selection_for_abilities(tile: IsometricTile, selected_entity: PlayerEntity):
	print("GameController: Processing ability " + current_ability + " targeting tile at " + str(tile.grid_position))
	
	# Check if the ability exists for the entity
	if selected_entity.abilities.has(current_ability):
		# Check if the tile is a valid target (should be highlighted)
		if tile.is_action_target:
			print("GameController: Using " + current_ability + " ability on tile at " + str(tile.grid_position))
			var success = selected_entity.use_ability(current_ability, tile)
			print("GameController: Ability use " + ("succeeded" if success else "failed"))
			
			if success:
				# Reset current ability only if the ability was actually used
				current_ability = ""
				
				# Clear highlights after using the ability
				clear_all_highlights()
				
				# Update HUD buttons to ensure they're properly deselected
				if Global.hud:
					Global.hud.update_action_buttons()
				
				# Highlight movement range if the player still has movement points
				if selected_entity.movement_points > 0:
					highlight_movement_range(selected_entity)
			else:
				print("GameController: Ability failed to execute, keeping ability mode active")
		else:
			print("GameController: Invalid target for " + current_ability + ", canceling ability")
			cancel_current_ability()
	else:
		print("GameController: Entity doesn't have the ability " + current_ability)
		cancel_current_ability()

# Called when an entity is selected
func _on_entity_selected(entity):
	print("GameController: Entity selected: " + entity.entity_name)
	
	# Only allow selection of player entities during their turn
	if current_state == GameState.PLAYER_TURN_ACTIVE and entity in player_entities and entity.is_turn_active:
		# Don't allow selection of players who are drilling
		if entity.is_drilling:
			print("GameController: Cannot select " + entity.entity_name + " because they are drilling")
			return
		
		if selected_entity:
			# Deselect previous entity
			print("GameController: Deselecting previous entity")
			# Clear all highlighted tiles
			clear_all_highlights()
		
		selected_entity = entity
		print("GameController: New entity selected: " + entity.entity_name)
		# Visual feedback for selection would be implemented here
		emit_signal("player_activated", entity)
		
		# Update the HUD with the selected player
		if Global.hud:
			Global.hud.set_active_player(entity)
		
		# Highlight movement range for the selected entity
		highlight_movement_range(entity)

# Move an entity to a specific tile
func move_entity_to_tile(entity, target_grid_pos):
	if not entity:
		push_error("GameController: Cannot move entity - entity is null")
		return
	
	# Verify the entity has the correct isometric_map reference for its level
	if level_manager and level_manager.level_nodes.has(entity.current_level):
		var expected_map = level_manager.level_nodes[entity.current_level]
		if entity.isometric_map != expected_map:
			push_error("GameController: Entity has incorrect isometric_map reference for level " + 
					  str(entity.current_level) + " - fixing it now")
			entity.isometric_map = expected_map
	
	# Get the map that belongs to this entity
	var entity_map = entity.isometric_map
	if not entity_map:
		push_error("GameController: Cannot move entity - entity's map is null")
		return
		
	# Check if entity is already moving
	if entity.is_moving:
		print("GameController: Entity is already moving, cannot set new path")
		return
	
	# Get the target tile
	var target_tile = entity_map.get_tile(target_grid_pos)
	if not target_tile:
		print("GameController: Cannot move - target tile does not exist")
		return
	
	# Check if target tile is walkable
	if not target_tile.is_walkable:
		print("GameController: Cannot move - target tile is not walkable")
		return
	
	# Check if target tile is already occupied by a different entity
	if target_tile.is_occupied and target_tile.occupying_entity != entity:
		print("GameController: Cannot move - target tile at " + str(target_grid_pos) + 
			" on level " + str(entity.current_level) + " is occupied by " + 
			(target_tile.occupying_entity.entity_name if target_tile.occupying_entity else "unknown entity"))
		return
	
	# Get the path to the target (A* will also verify tile occupation)
	var path = entity_map.find_path(entity.grid_position, target_grid_pos)
	
	if path.size() > 0:
		print("GameController: Path found with " + str(path.size()) + " steps for entity " + entity.entity_name)
		
		# For player entities, check and consume movement points before movement
		if entity in player_entities:
			# Check if path length exceeds available movement points
			if path.size() > entity.movement_points:
				print("GameController: Path too long for available movement points")
				
				# Optionally, could limit the path to the available movement points
				path = path.slice(0, entity.movement_points)
				print("GameController: Path trimmed to " + str(path.size()) + " steps to match movement points")
				
				# If the destination is now different, get that tile instead
				if path.size() > 0:
					target_grid_pos = path[path.size() - 1]
					target_tile = entity_map.get_tile(target_grid_pos)
				else:
					print("GameController: No valid path within movement point range")
					return
			
			# Double-check that the target tile is still available
			if target_tile.is_occupied and target_tile.occupying_entity != entity:
				print("GameController: Target tile became occupied during path planning")
				return
			
			# Consume movement points for the path
			if not entity.consume_movement_points_for_path(path.size()):
				print("GameController: Entity doesn't have enough movement points for the path")
				return
		
		# Set the entity's game_controller reference
		entity.game_controller = self
		
		# Clear highlighted tiles before movement
		clear_all_highlights()
		
		# Set the path
		entity.set_path(path)
		
		# Signal that entity is moving
		emit_signal("entity_moved", entity)
		
		# Connect to the entity's movement_points_changed signal to update highlights
		if entity in player_entities:
			if not entity.is_connected("movement_points_changed", Callable(self, "_on_player_movement_points_changed")):
				entity.connect("movement_points_changed", Callable(self, "_on_player_movement_points_changed"))
	else:
		print("GameController: No path found to target position")

# Handle when a player's movement points change
func _on_player_movement_points_changed(_current, _maximum):
	update_highlights()
	
# Handle when a player's action points change
func _on_player_action_points_changed(_current, _maximum):
	# We don't need to update movement highlights when action points change
	pass

# When player selections/states change
func _on_player_action_selection_changed():
	update_highlights()
	
# Update highlight display based on current state
func update_highlights():
	# First clear all existing highlights
	clear_all_highlights()
	
	# Then apply appropriate highlights based on context
	if selected_entity and selected_entity in player_entities and selected_entity.is_turn_active:
		# Show movement range if the entity has movement points
		if selected_entity.movement_points > 0 and not selected_entity.is_drilling:
			highlight_movement_range(selected_entity)
			
		# If an ability is selected, show its targets
		if current_ability != "":
			_highlight_ability_targets(current_ability, selected_entity)

# Event handler for when a turn starts for a character
func _on_turn_started(character):
	print("GameController: Character " + character.entity_name + " turn started on level " + str(character.current_level))
	
	# If this is a player entity, activate it in the UI regardless of level
	if character in player_entities:
		# Only select the character if they're not drilling
		if not character.is_drilling:
			selected_entity = character
			emit_signal("player_activated", character)
			
			# Update the HUD with the current player
			if Global.hud:
				Global.hud.set_active_player(character)
				
			# If the player is on a different level, switch the active level
			if character.current_level != current_active_level:
				if level_manager and level_manager.level_nodes.has(character.current_level):
					print("GameController: Switching active level to " + str(character.current_level) + " for player " + character.entity_name)
					set_active_level(character.current_level, level_manager.level_nodes[character.current_level])
		else:
			print("GameController: Player " + character.entity_name + " is drilling and can't be controlled")
			# For drilling players, we don't need to do anything here as the drilling progress is handled 
			# in the character's start_turn method which automatically ends their turn while drilling
			
			# Update the HUD with the drilling player
			if Global.hud:
				Global.hud.set_active_player(character)
	# For enemy entities, skip if not on active level
	elif character in enemy_entities and character.current_level != current_active_level:
		print("GameController: Skipping enemy on inactive level " + str(character.current_level))
		# End the turn immediately for enemies on other levels
		if character.has_method("end_turn"):
			character.end_turn()

# Event handler for when a turn ends for a character
func _on_turn_ended(character):
	print("GameController: Character " + character.entity_name + " turn ended")
	
	# If this was a player entity, deselect it
	if character in player_entities and selected_entity == character:
		selected_entity = null
		
		if character.has_method("on_turn_end"):
			character.on_turn_end()
		
		# Clear the active player in the HUD
		if Global.hud and Global.hud.current_player == character:
			Global.hud.set_active_player(null)

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
	# We need access to the level manager to get the correct map
	var entity_map = level_manager.level_nodes.get(entity.current_level)
	if entity_map:
		entity.isometric_map = entity_map
	else:
		push_error("GameController: Cannot find map for level " + str(entity.current_level) + ", using current active map")
		entity.isometric_map = isometric_map
	
	# Ensure game_controller reference is set
	entity.game_controller = self
	
	# Add entity to the Y-sorted container of the appropriate map
	if entity.isometric_map:
		entity.isometric_map.add_entity(entity)
	else:
		push_error("GameController: Cannot spawn entity - map is null for entity level " + str(entity.current_level))
		return false
	
	# Place on the tile
	var tile = entity.isometric_map.get_tile(grid_pos)
	if tile:
		entity.place_on_tile(tile)
		print("GameController: Entity placed on tile at " + str(grid_pos) + " on level " + str(entity.current_level))
		
		# One more check to ensure the entity still has its GameController reference
		if entity.game_controller != self:
			print("GameController: WARNING - Entity lost GameController reference during placement, restoring")
			entity.game_controller = self
			
		return true
	else:
		push_error("GameController: Could not find tile at " + str(grid_pos) + " on level " + str(entity.current_level))
		return false

# Spawn a player entity on the map
func spawn_player(grid_pos, player_type: String, level_index: int = 0):
	print("GameController: Spawning player of type " + player_type + " at " + str(grid_pos) + " on level " + str(level_index))
	var entity
	
	# Instantiate the appropriate player scene based on type
	match player_type.to_lower():
		"heavy":
			entity = load("res://Players/HeavyPlayer.tscn").instantiate()
		
		"scout":
			entity = load("res://Players/ScoutPlayer.tscn").instantiate()
		
		"wizard":
			entity = load("res://Players/WizardPlayer.tscn").instantiate()
		
		_:
			# Fallback to generic player if type not recognized
			push_error("GameController: Unknown player type: " + player_type)
			return null
	
	# Setup common player entity properties
	_setup_entity(entity, grid_pos, level_index, "player")
	
	return entity

# Spawn an enemy on the map
func spawn_enemy(grid_pos, enemy_type_id, level_index: int = 0):
	print("GameController: Spawning enemy of type " + str(enemy_type_id) + " at " + str(grid_pos) + " on level " + str(level_index))
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
		
		EnemyEntity.EnemyType.HELLBOMB:
			entity = load("res://Enemies/HellBombEnemy.tscn").instantiate()
		
		EnemyEntity.EnemyType.HELLBOMB_CHASER:
			entity = load("res://Enemies/HellBombChaserEnemy.tscn").instantiate()
		
		_:
			# Fallback to generic enemy if type not recognized
			push_error("GameController: Unknown enemy type: " + str(enemy_type_id))
			return null
	
	# Setup common enemy entity properties
	_setup_entity(entity, grid_pos, level_index, "enemy")
	
	return entity

# Common setup logic for all entities
func _setup_entity(entity, grid_pos, level_index: int, entity_type: String):
	# Explicitly set the game_controller reference
	entity.game_controller = self
	entity.current_level = level_index
	print("GameController: Set self as game_controller for " + entity.entity_name)
	
	# Place the entity on the map
	if not _spawn_entity_helper(entity, grid_pos):
		return null
	
	# Connect common signals
	entity.died.connect(_on_entity_died)
	
	# Handle type-specific setup
	if entity_type == "player":
		# Connect player-specific signals
		entity.entity_selected.connect(_on_entity_selected)
		entity.connect("action_selection_changed", _on_player_action_selection_changed)
		entity.connect("movement_points_changed", _on_player_movement_points_changed)
		entity.connect("action_points_changed", _on_player_action_points_changed)
		
		# Add to player entities array
		player_entities.append(entity)
		print("GameController: Player " + entity.entity_name + " added to player entities")
		
		# Add to turn sequencer's player group
		turn_sequencer.add_character_to_group(entity, "player")
	else: # enemy
		# Add to enemy entities array
		enemy_entities.append(entity)
		print("GameController: Enemy " + entity.entity_name + " added to enemy entities")
		
		# Add to turn sequencer's enemy group
		turn_sequencer.add_character_to_group(entity, "enemy")
		
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

# Clear all tile highlights on all maps
func clear_all_highlights():
	# Clear highlights on all level maps if we have a level manager
	if level_manager:
		for level_index in level_manager.level_nodes:
			var map = level_manager.level_nodes[level_index]
			for tile in map.tiles.values():
				if tile.is_highlighted or tile.is_move_selectable or tile.is_attackable or tile.is_action_target:
					tile.clear_state()
		print("GameController: Cleared highlights on all maps")
	# Fallback to just clearing the active map if no level manager
	elif isometric_map:
		for tile in isometric_map.tiles.values():
			if tile.is_highlighted or tile.is_move_selectable or tile.is_attackable or tile.is_action_target:
				tile.clear_state()
		print("GameController: Cleared highlights on active map only")

# Highlight tiles within movement range of the entity
func highlight_movement_range(entity):
	if not entity:
		return
	
	# Get the correct map for the entity's current level
	var entity_map
	if level_manager and level_manager.level_nodes.has(entity.current_level):
		entity_map = level_manager.level_nodes[entity.current_level]
	else:
		entity_map = entity.isometric_map
		
	if not entity_map:
		push_error("GameController: Cannot highlight movement range - entity's map is null")
		return
		
	# Get entity's current position and movement points
	var start_pos = entity.grid_position
	var max_mp = entity.movement_points
	
	# Make sure the entity has movement points to move
	if max_mp <= 0:
		print("GameController: Entity has no movement points, not highlighting movement range")
		return
	
	# First make sure we clear any existing highlights on ALL maps
	clear_all_highlights()
	
	# Use the method to find all reachable tiles within movement points range
	var movable_tiles = entity_map.find_reachable_tiles(start_pos, max_mp)
	
	# Highlight all movable tiles
	for tile in movable_tiles:
		tile.set_move_selectable(true)
		
	print("GameController: Highlighted " + str(movable_tiles.size()) + " movable tiles on level " + str(entity.current_level))

# Set the current active level and change the isometric_map reference
func set_active_level(level_index: int, level_map: IsometricMap):
	print("GameController: Setting active level to " + str(level_index))
	
	# Don't change if it's already the active level
	if current_active_level == level_index and isometric_map == level_map:
		print("GameController: Level " + str(level_index) + " is already active")
		return
	
	# Disconnect signal from old map if it exists
	if isometric_map and isometric_map.is_connected("tile_selected", Callable(self, "_on_tile_selected")):
		isometric_map.tile_selected.disconnect(_on_tile_selected)
		print("GameController: Disconnected tile_selected signal from previous map")
	
	# Restore the previous level's z_index to its default value (negative of level index)
	if level_manager and level_manager.level_nodes.has(current_active_level):
		var previous_level_map = level_manager.level_nodes[current_active_level]
		if previous_level_map:
			previous_level_map.z_index = -current_active_level
			# Fade previous active level to grey
			var tween = create_tween()
			tween.tween_property(previous_level_map, "modulate", Color(0.7, 0.7, 0.7, 1.0), 0.3)
			print("GameController: Restored z_index of level " + str(current_active_level) + " to " + str(-current_active_level))
	
	# Change active level and map
	current_active_level = level_index
	isometric_map = level_map
	
	# Set the new active level's z_index to 10 to bring it forward
	if isometric_map:
		isometric_map.z_index = 10
		# Fade active level to full color
		var tween = create_tween()
		tween.tween_property(isometric_map, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
		print("GameController: Set z_index of active level " + str(level_index) + " to 10")
	
	# Apply grey modulation to all non-active levels
	if level_manager:
		for idx in level_manager.level_nodes:
			var map = level_manager.level_nodes[idx]
			if idx != level_index and map:
				var tween = create_tween()
				tween.tween_property(map, "modulate", Color(0.7, 0.7, 0.7, 1.0), 0.3)
	
	# Connect signal to new map
	if isometric_map and not isometric_map.is_connected("tile_selected", Callable(self, "_on_tile_selected")):
		isometric_map.tile_selected.connect(_on_tile_selected)
		print("GameController: Connected tile_selected signal to new map at level " + str(level_index))
	
	# Make sure all level maps have the tile_selected signal connected
	if level_manager:
		for idx in level_manager.level_nodes:
			var map = level_manager.level_nodes[idx]
			if map and not map.is_connected("tile_selected", Callable(self, "_on_tile_selected")):
				map.tile_selected.connect(_on_tile_selected)
				print("GameController: Connected tile_selected signal to map at level " + str(idx))

# Get all active entities for a specific level
func get_entities_at_level(level_index: int, entity_type: String = "all") -> Array:
	var result = []
	
	match entity_type:
		"player":
			for entity in player_entities:
				if entity.current_level == level_index:
					result.append(entity)
		"enemy":
			for entity in enemy_entities:
				if entity.current_level == level_index:
					result.append(entity)
		_: # "all" or any other value
			for entity in player_entities:
				if entity.current_level == level_index:
					result.append(entity)
			for entity in enemy_entities:
				if entity.current_level == level_index:
					result.append(entity)
	
	return result

# Connect signals from the HUD
func _connect_hud_signals():
	print("GameController: Connecting HUD signals")
	
	if Global.hud:
		# Connect end turn button
		var end_turn_button = Global.hud.get_end_turn_button()
		if end_turn_button:
			end_turn_button.pressed.connect(_on_end_turn_button_pressed)
			
		# Connect drill button hover signals
		if not Global.hud.is_connected("DrillButtonHovered", Callable(self, "_on_drill_button_hovered")):
			Global.hud.DrillButtonHovered.connect(_on_drill_button_hovered)
			
		if not Global.hud.is_connected("DrillButtonUnhovered", Callable(self, "_on_drill_button_unhovered")):
			Global.hud.DrillButtonUnhovered.connect(_on_drill_button_unhovered)
			
		# Connect drill smash button hover signals
		if not Global.hud.is_connected("DrillSmashButtonHovered", Callable(self, "_on_drill_smash_button_hovered")):
			Global.hud.DrillSmashButtonHovered.connect(_on_drill_smash_button_hovered)
			
		if not Global.hud.is_connected("DrillSmashButtonUnhovered", Callable(self, "_on_drill_smash_button_unhovered")):
			Global.hud.DrillSmashButtonUnhovered.connect(_on_drill_smash_button_unhovered)
			
		# Connect line shot button hover signals
		if not Global.hud.is_connected("LineShotButtonHovered", Callable(self, "_on_line_shot_button_hovered")):
			Global.hud.LineShotButtonHovered.connect(_on_line_shot_button_hovered)
			
		if not Global.hud.is_connected("LineShotButtonUnhovered", Callable(self, "_on_line_shot_button_unhovered")):
			Global.hud.LineShotButtonUnhovered.connect(_on_line_shot_button_unhovered)
			
		# Connect fireball button hover signals
		if not Global.hud.is_connected("FireballButtonHovered", Callable(self, "_on_fireball_button_hovered")):
			Global.hud.FireballButtonHovered.connect(_on_fireball_button_hovered)
			
		if not Global.hud.is_connected("FireballButtonUnhovered", Callable(self, "_on_fireball_button_unhovered")):
			Global.hud.FireballButtonUnhovered.connect(_on_fireball_button_unhovered)
			
		# Connect big drill button hover signals
		if not Global.hud.is_connected("BigDrillButtonHovered", Callable(self, "_on_big_drill_button_hovered")):
			Global.hud.BigDrillButtonHovered.connect(_on_big_drill_button_hovered)
			
		if not Global.hud.is_connected("BigDrillButtonUnhovered", Callable(self, "_on_big_drill_button_unhovered")):
			Global.hud.BigDrillButtonUnhovered.connect(_on_big_drill_button_unhovered)
	else:
		push_error("GameController: Cannot connect HUD signals - Global.hud is null")

# Individual button handlers that forward to the generic handlers
func _on_drill_button_hovered(player):
	_on_ability_button_hovered(player, "drill")

func _on_drill_button_unhovered():
	_on_ability_button_unhovered("drill")

func _on_drill_smash_button_hovered(player):
	_on_ability_button_hovered(player, "drill_smash")

func _on_drill_smash_button_unhovered():
	_on_ability_button_unhovered("drill_smash")

func _on_line_shot_button_hovered(player):
	_on_ability_button_hovered(player, "line_shot")

func _on_line_shot_button_unhovered():
	_on_ability_button_unhovered("line_shot")

func _on_fireball_button_hovered(player):
	_on_ability_button_hovered(player, "fireball")

func _on_fireball_button_unhovered():
	_on_ability_button_unhovered("fireball")

func _on_big_drill_button_hovered(player):
	_on_ability_button_hovered(player, "big_drill")

func _on_big_drill_button_unhovered():
	_on_ability_button_unhovered("big_drill")

# Generic handler for ability button hover
func _on_ability_button_hovered(player: PlayerEntity, ability_name: String):
	print("GameController: " + ability_name + " button hovered for player: " + player.entity_name)
	
	# Only show if we have a valid player who can use this ability
	if not player or not player.abilities.has(ability_name):
		return
		
	# Don't show hover effects if an ability is already selected
	if current_ability != "":
		print("GameController: Not showing " + ability_name + " hover effect because ability " + current_ability + " is already selected")
		return
	
	# Clear any existing highlights
	clear_all_highlights()
	
	# Handle special cases for each ability type
	match ability_name:
		"drill":
			_handle_drill_hover(player)
		"drill_smash":
			if player.has_method("highlight_drill_smash_targets"):
				player.highlight_drill_smash_targets()
		"line_shot":
			if player.has_method("highlight_line_shot_targets"):
				player.highlight_line_shot_targets()
		"fireball":
			if player.has_method("highlight_fireball_targets"):
				player.highlight_fireball_targets()
		"big_drill":
			if player.has_method("highlight_big_drill_targets"):
				player.highlight_big_drill_targets()
				_handle_big_drill_hover(player)

# Generic handler for ability button unhover
func _on_ability_button_unhovered(ability_name: String):
	print("GameController: " + ability_name + " button unhovered")
	
	# If we're in ability selection mode for this ability, don't clear the highlights
	if current_ability == ability_name:
		print("GameController: Keeping " + ability_name + " highlights active since ability is selected")
		return
	
	# Clear any highlighted tiles on all maps
	clear_all_highlights()
	
	# Hide the drill visualization for abilities that use it
	if ability_name == "drill" or ability_name == "big_drill":
		hide_drill_visualization()
	
	# If we have a selected entity with movement points, restore their movement highlights
	if selected_entity and selected_entity in player_entities and selected_entity.is_turn_active:
		if selected_entity.movement_points > 0 and not selected_entity.is_drilling:
			highlight_movement_range(selected_entity)

# Handle drill ability hover visualization
func _handle_drill_hover(player: PlayerEntity):
	# Don't show if player is already drilling
	if player.is_drilling:
		return
		
	# Check if we can drill
	if not level_manager:
		return
		
	# Make sure there's a valid tile below
	if not level_manager.has_valid_tile_below(player.current_level, player.grid_position):
		return
		
	# Get the player's current position in world space
	var start_pos = player.global_position
	
	# Get the target level and tile
	var target_level_index = player.current_level + 1
	var target_map = level_manager.level_nodes.get(target_level_index)
	
	if not target_map:
		return
		
	# Get target tile at the same grid position on the level below
	var target_tile = target_map.get_tile(player.grid_position)
	if not target_tile:
		return
		
	# If the target tile is occupied, find the first unoccupied neighbor
	if target_tile.is_occupied:
		var found_alternative = false
		var neighbors = target_map.get_neighbors(player.grid_position)
		
		for neighbor_tile in neighbors:
			if neighbor_tile.is_walkable and not neighbor_tile.is_occupied:
				target_tile = neighbor_tile
				found_alternative = true
				break
				
		if not found_alternative:
			return  # No valid destination found
	
	# Get the target position in world space
	var end_pos = target_tile.global_position
	
	# Clear any existing points
	drilling_line_node.clear_points()
	
	# Add the start and end points
	drilling_line_node.add_point(start_pos)
	drilling_line_node.add_point(end_pos)
	
	# Make sure the line is visible
	drilling_line_node.visible = true
	
	# Highlight the target tile using the built-in tile highlighting system
	target_tile.set_action_target(true)

# Handle big drill hover visualization
func _handle_big_drill_hover(player: PlayerEntity):
	# Show drilling visualization from current position to the level below
	if level_manager:
		# Get the current level and position
		var current_level = player.current_level
		var current_pos = player.grid_position
		
		# Verify the targets are valid
		if level_manager.has_valid_tile_below(current_level, current_pos):
			# Show drill visualization
			show_drill_visualization(current_level, current_pos, current_level + 1, current_pos)
			
			# Also show drill visualization for adjacent allies
			var adjacent_allies = player.get_adjacent_players()
			for ally in adjacent_allies:
				show_drill_visualization(ally.current_level, ally.grid_position, ally.current_level + 1, ally.grid_position)

# Event handler for when the end turn button is pressed
func _on_end_turn_button_pressed():
	print("GameController: End turn button pressed")
	end_current_player_turn()

# Handle input events (keyboard, etc.)
func _input(event):
	# Cancel ability selection with Escape key
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if current_ability != "":
			print("GameController: Escape key pressed, canceling ability")
			cancel_current_ability()

# Shows a drilling visualization line from source level/position to target level/position
func show_drill_visualization(source_level: int, source_pos: Vector2i, target_level: int, target_pos: Vector2i):
	print("GameController: Showing drill visualization from level " + str(source_level) + " to level " + str(target_level))
	
	# Get the source and target maps
	var source_map = level_manager.level_nodes.get(source_level)
	var target_map = level_manager.level_nodes.get(target_level)
	
	if not source_map or not target_map:
		print("GameController: Cannot show drill visualization - source or target map is null")
		return
		
	# Get the source and target tiles
	var source_tile = source_map.get_tile(source_pos)
	var target_tile = target_map.get_tile(target_pos)
	
	if not source_tile or not target_tile:
		print("GameController: Cannot show drill visualization - source or target tile is null")
		return
		
	# Get the world positions
	var start_pos = source_tile.global_position
	var end_pos = target_tile.global_position
	
	# Add points to the drilling line
	drilling_line_node.add_point(start_pos)
	drilling_line_node.add_point(end_pos)
	
	# Make the line visible
	drilling_line_node.visible = true
	
	# Highlight the target tile
	target_tile.set_action_target(true)

# Hides the drilling visualization
func hide_drill_visualization():
	print("GameController: Hiding drill visualization")
	
	# Clear the points and hide the line
	drilling_line_node.clear_points()
	drilling_line_node.visible = false

# Highlight targets for a specific ability
func _highlight_ability_targets(ability_name: String, entity: PlayerEntity):
	if not entity or not entity.abilities.has(ability_name):
		return
		
	match ability_name:
		"drill_smash":
			if entity.has_method("highlight_drill_smash_targets"):
				entity.highlight_drill_smash_targets()
		"line_shot":
			if entity.has_method("highlight_line_shot_targets"):
				entity.highlight_line_shot_targets()
		"fireball":
			if entity.has_method("highlight_fireball_targets"):
				entity.highlight_fireball_targets()
		"big_drill":
			if entity.has_method("highlight_big_drill_targets"):
				entity.highlight_big_drill_targets()
				
				# Show drill visualization for big drill
				if level_manager:
					var current_level = entity.current_level
					var current_pos = entity.grid_position
					
					if level_manager.has_valid_tile_below(current_level, current_pos):
						show_drill_visualization(current_level, current_pos, current_level + 1, current_pos)
						
						var adjacent_allies = entity.get_adjacent_players()
						for ally in adjacent_allies:
							show_drill_visualization(ally.current_level, ally.grid_position, ally.current_level + 1, ally.grid_position)
		"drill":
			# Handle drill specifically since it needs level-based visualization
			_handle_drill_hover(entity)
