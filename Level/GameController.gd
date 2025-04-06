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
	if Global.hud:
		Global.hud.DrillButtonHovered.connect(_on_drill_button_hovered)
		Global.hud.DrillButtonUnhovered.connect(_on_drill_button_unhovered)
		
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
		# Make sure the tile is on the same level as the player
		if tile_level == selected_entity.current_level:
			print("GameController: Attempting to move entity " + selected_entity.entity_name + " to " + str(tile.grid_position) + " on level " + str(selected_entity.current_level))
			move_entity_to_tile(selected_entity, tile.grid_position)
		else:
			print("GameController: Cannot move - tile is on level " + str(tile_level) + " but player is on level " + str(selected_entity.current_level))
	else:
		print("GameController: Cannot move - no selected entity or not player turn")

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
	
# Update highlight display based on movement points
func update_highlights():
	if selected_entity and selected_entity in player_entities and selected_entity.is_turn_active:
		# First clear all highlights
		clear_all_highlights()
		# Then highlight new movement range if the entity still has movement points
		if selected_entity.movement_points > 0 and not selected_entity.is_drilling:
			highlight_movement_range(selected_entity)

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
			# Players who are drilling can't be selected, but their turns still progress
			if character.continue_drilling():
				print("GameController: Player " + character.entity_name + " completed drilling")
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
	entity.current_level = level_index
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
	
	# Connect to relevant signals
	entity.connect("action_selection_changed", _on_player_action_selection_changed)
	entity.connect("movement_points_changed", _on_player_movement_points_changed)
	entity.connect("action_points_changed", _on_player_action_points_changed)
	
	# Add to turn sequencer's player group
	turn_sequencer.add_character_to_group(entity, "player")
	print("GameController: Player " + entity.entity_name + " added to turn sequencer player group")
	
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
		
		_:
			# Fallback to generic enemy if type not recognized
			push_error("GameController: Unknown enemy type: " + str(enemy_type_id))
			return null
	
	# Explicitly set the game_controller reference
	entity.game_controller = self
	entity.current_level = level_index
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

# Clear all tile highlights on all maps
func clear_all_highlights():
	# Clear highlights on all level maps if we have a level manager
	if level_manager:
		for level_index in level_manager.level_nodes:
			var map = level_manager.level_nodes[level_index]
			for tile in map.tiles.values():
				if tile.is_highlighted or tile.is_move_selectable or tile.is_attackable:
					tile.highlight(false)
		print("GameController: Cleared highlights on all maps")
	# Fallback to just clearing the active map if no level manager
	elif isometric_map:
		for tile in isometric_map.tiles.values():
			if tile.is_highlighted or tile.is_move_selectable or tile.is_attackable:
				tile.highlight(false)
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

# Event handler for when the drill button is hovered
func _on_drill_button_hovered(player: PlayerEntity):
	print("GameController: Drill button hovered for player: " + player.entity_name)
	
	# Only show if we have a valid player who can drill
	if not player or not player.abilities.has("drill"):
		return
		
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
	# Using the new action_target property will make it orange and work with wall transparency
	target_tile.set_action_target(true)

# Event handler for when the drill button is unhovered
func _on_drill_button_unhovered():
	print("GameController: Drill button unhovered")
	
	# Hide the drilling line
	drilling_line_node.visible = false
	drilling_line_node.clear_points()
	
	# Clear any highlighted tiles on all maps
	clear_all_highlights()
	
	# If we have a selected entity with movement points, restore their movement highlights
	if selected_entity and selected_entity in player_entities and selected_entity.is_turn_active:
		if selected_entity.movement_points > 0 and not selected_entity.is_drilling:
			highlight_movement_range(selected_entity)
