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

# Level progression tracking
var turns_spent_on_level = {}  # Dictionary tracking turns spent on each level
var MIN_TURNS_BEFORE_NEXT_LEVEL = 9  # Minimum turns before next level becomes available

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
	
	# Get the reference to the LevelManager first
	level_manager = get_parent().get_node_or_null("LevelManager")
	if not level_manager:
		push_error("GameController: LevelManager not found")
	else:
		print("GameController: Found LevelManager")
		
		# Find the map in the scene - only use the first level as the active map
		if level_manager.level_nodes.has(0):
			isometric_map = level_manager.level_nodes[0]
			current_active_level = 0
			
			if isometric_map:
				print("GameController: Map found, connecting signals")
				isometric_map.tile_selected.connect(_on_tile_selected)
		else:
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
	
	# Connect to HUD signals
	_connect_hud_signals()
	
	# Create the drilling line visualization
	drilling_line_node = Line2D.new()
	drilling_line_node.width = 5.0
	drilling_line_node.default_color = Color(1.0, 0.5, 0.0, 0.8)  # Orange-ish, semi-transparent
	drilling_line_node.z_index = 100  # Display above other elements
	drilling_line_node.visible = false
	add_child(drilling_line_node)
	
	# Initialize level visibility AFTER all nodes are set up
	# We need to call this at the end of _ready to override LevelManager's default visibility
	if level_manager:
		# Wait for one frame to ensure all levels are initialized
		call_deferred("initialize_level_visibility")

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
	
	# Check if drilling abilities should be blocked due to turns requirement
	if (current_ability == "drill" or current_ability == "big_drill") and (
		not turns_spent_on_level.has(selected_entity.current_level) or 
		turns_spent_on_level[selected_entity.current_level] < MIN_TURNS_BEFORE_NEXT_LEVEL
	):
		print("GameController: Drilling blocked - haven't spent enough turns on current level")
		cancel_current_ability()
		return
	
	# For drilling abilities, check if the target level is visible
	if (current_ability == "drill" or current_ability == "big_drill"):
		var target_level = selected_entity.current_level + 1
		if not level_manager.level_nodes.has(target_level):
			print("GameController: Drilling blocked - target level does not exist")
			cancel_current_ability()
			return
			
		var target_level_map = level_manager.level_nodes[target_level]
		if not target_level_map.get_meta("is_visible_to_player", false):
			print("GameController: Drilling blocked - target level not visible yet")
			cancel_current_ability()
			return
	
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
func _select_entity(entity):
	# Clear any existing highlights
	clear_all_highlights()
	
	# Set the selected entity
	if entity != selected_entity and is_instance_valid(selected_entity) and selected_entity is PlayerEntity:
		# Reset the previous entity's appearance
		if selected_entity is PlayerEntity:
			selected_entity.deselect()
	
	selected_entity = entity
	
	# Handle player-specific selection
	if entity is PlayerEntity:
		print("GameController: Selected player entity: " + entity.entity_name)
		
		# Make sure the HUD has a reference to the selected player
		if Global.hud:
			Global.hud.set_active_player(entity)
		
		# Mark the player as selected
		entity.select()
		
		# If this is a player, highlight their movement range
		if entity.is_turn_active and not entity.is_drilling:
			if selected_entity.movement_points > 0:
				highlight_movement_range(entity)
				
			# Check if there's a current ability selection
			if current_ability != "":
				print("GameController: Active ability: " + current_ability)
				
				# Highlight the appropriate targets for the ability
				match current_ability:
					"drill":
						# Handle drill specifically since it needs level-based visualization
						_handle_drill_hover(entity)
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
					"charge_attack":
						if entity.has_method("highlight_charge_attack_targets"):
							entity.highlight_charge_attack_targets()
					"healing_aoe":
						if entity.has_method("highlight_aoe_targets"):
							entity.highlight_aoe_targets()
					"freeze_aoe":
						if entity.has_method("highlight_aoe_targets"):
							entity.highlight_aoe_targets()
					"poison_aoe":
						if entity.has_method("highlight_aoe_targets"):
							entity.highlight_aoe_targets()
	
	elif entity is EnemyEntity:
		# Enemy selection behavior
		print("GameController: Selected enemy entity: " + entity.entity_name)
		
		# If we have a player entity selected that's in active turn, check if they can target this enemy
		if is_instance_valid(selected_entity) and selected_entity is PlayerEntity and selected_entity.is_turn_active and current_ability != "":
			# Players might want to target enemies with some abilities, but for now we keep the enemy selected
			pass

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
	
	# Check if we should remove any obsolete levels
	check_for_obsolete_levels()

# Event handler for when a group starts its turns
func _on_group_turns_started(group_name):
	print("GameController: Group " + group_name + " turns starting")
	
	if group_name == "player":
		change_state(GameState.PLAYER_TURN_ACTIVE)
	elif group_name == "enemy":
		# Check if all enemies are defeated before starting enemy turns
		var real_enemies_remaining = 0
		for enemy in enemy_entities:
			if enemy.enemy_type != EnemyEntity.EnemyType.EXPLOSIVE_BARREL and enemy.enemy_type != EnemyEntity.EnemyType.DESTRUCTIBLE_WALL:
				real_enemies_remaining += 1
				
		if real_enemies_remaining == 0:
			# Victory condition
			print("GameController: Victory - all enemies defeated")
			change_state(GameState.GAME_OVER)
			# Call gameover with victory state
			Global.gameover(1)
			return
			
		change_state(GameState.ENEMY_TURN_ACTIVE)
		emit_signal("turn_changed", "enemy")
		emit_signal("game_state_changed", "enemy_turn")

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
		
		# Update turns spent on levels
		update_turns_spent_on_levels()
		
		# Check if we should remove any obsolete levels
		check_for_obsolete_levels()
		
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
	
	# Initialize the upgrade button visibility
	update_upgrade_button_visibility()

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

		EnemyEntity.EnemyType.EXPLOSIVE_BARREL:
			entity = load("res://Enemies/ExplosiveBarrel.tscn").instantiate()
		
		EnemyEntity.EnemyType.DESTRUCTIBLE_WALL:
			entity = load("res://Enemies/DestructibleWall.tscn").instantiate()
		
		_:
			assert(false, "GameController: Unknown enemy type: " + str(enemy_type_id))
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
		entity.entity_selected.connect(_select_entity)
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
		
		# Player removed - this changes active levels, so notify camera
		emit_signal("entity_moved", null)
		
		# Check if game is over (all players dead)
		if player_entities.size() == 0:
			change_state(GameState.GAME_OVER)
		else:
			# Check if we can remove any obsolete levels
			check_for_obsolete_levels()
	
	elif entity in enemy_entities:
		enemy_entities.erase(entity)
		print("GameController: Enemy removed from game, " + str(enemy_entities.size()) + " enemies remaining")
		
		# Add XP to the global counter if the entity was an enemy
		if entity is EnemyEntity:
			var xp_amount = entity.xp_value
			print("GameController: Awarding " + str(xp_amount) + " XP for killing " + entity.entity_name)
			Global.add_xp(xp_amount)
			Global.increment_enemy_kill_count()
		
		# Remove from turn sequencer
		turn_sequencer.remove_character(entity)
		
		# Check if all enemies are defeated
		var real_enemies_remaining = 0
		for enemy in enemy_entities:
			if enemy.enemy_type != EnemyEntity.EnemyType.EXPLOSIVE_BARREL and enemy.enemy_type != EnemyEntity.EnemyType.DESTRUCTIBLE_WALL:
				real_enemies_remaining += 1
				
		if real_enemies_remaining == 0:
			# Victory condition
			print("GameController: Victory - all enemies defeated")
			change_state(GameState.GAME_OVER)
			# Call gameover with victory state
			Global.gameover(1)
		
		# Check if all enemies on this specific level are defeated
		check_level_enemies_cleared(entity.current_level)
		
		# Update upgrade button visibility
		update_upgrade_button_visibility()

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

# Set the current active level and change the isometric_map reference - update to handle visibility
func set_active_level(level_index: int, level_map: IsometricMap):
	# Don't change if it's already the active level
	if current_active_level == level_index and isometric_map == level_map:
		print("GameController: Level " + str(level_index) + " is already active")
		return
	
	# Make sure the level is visible before making it active
	if level_manager.level_nodes.has(level_index):
		var target_level_map = level_manager.level_nodes[level_index]
		if not target_level_map.get_meta("is_visible_to_player", false):
			print("GameController: Cannot make level " + str(level_index) + " active - it's not visible yet")
			
			# If we really need to make it active (for example, a player moved there),
			# we should reveal it first
			reveal_level(level_index)
	
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
	
	# Apply grey modulation to all non-active levels that are visible
	if level_manager:
		for idx in level_manager.level_nodes:
			var map = level_manager.level_nodes[idx]
			if idx != level_index and map and map.get_meta("is_visible_to_player", false):
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
	
	# Notify camera that active level has changed
	emit_signal("entity_moved", null)
	
	# Update the upgrade button visibility based on the new active level
	update_upgrade_button_visibility()
	
	# Check if we can remove any obsolete levels
	check_for_obsolete_levels()

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
func _connect_hud_signals() -> void:
	print("GameController: Connecting HUD signals")
	if Global.hud:
		# Connect the HUD signal for when players want to interact with the map
		if not Global.hud.is_connected("DrillButtonHovered", Callable(self, "_on_drill_button_hovered")):
			Global.hud.DrillButtonHovered.connect(_on_drill_button_hovered)
			
		if not Global.hud.is_connected("DrillButtonUnhovered", Callable(self, "_on_drill_button_unhovered")):
			Global.hud.DrillButtonUnhovered.connect(_on_drill_button_unhovered)
			
		if not Global.hud.is_connected("DrillSmashButtonHovered", Callable(self, "_on_drill_smash_button_hovered")):
			Global.hud.DrillSmashButtonHovered.connect(_on_drill_smash_button_hovered)
			
		if not Global.hud.is_connected("DrillSmashButtonUnhovered", Callable(self, "_on_drill_smash_button_unhovered")):
			Global.hud.DrillSmashButtonUnhovered.connect(_on_drill_smash_button_unhovered)
			
		if not Global.hud.is_connected("LineShotButtonHovered", Callable(self, "_on_line_shot_button_hovered")):
			Global.hud.LineShotButtonHovered.connect(_on_line_shot_button_hovered)
			
		if not Global.hud.is_connected("LineShotButtonUnhovered", Callable(self, "_on_line_shot_button_unhovered")):
			Global.hud.LineShotButtonUnhovered.connect(_on_line_shot_button_unhovered)
			
		if not Global.hud.is_connected("FireballButtonHovered", Callable(self, "_on_fireball_button_hovered")):
			Global.hud.FireballButtonHovered.connect(_on_fireball_button_hovered)
			
		if not Global.hud.is_connected("FireballButtonUnhovered", Callable(self, "_on_fireball_button_unhovered")):
			Global.hud.FireballButtonUnhovered.connect(_on_fireball_button_unhovered)
			
		if not Global.hud.is_connected("BigDrillButtonHovered", Callable(self, "_on_big_drill_button_hovered")):
			Global.hud.BigDrillButtonHovered.connect(_on_big_drill_button_hovered)
			
		if not Global.hud.is_connected("BigDrillButtonUnhovered", Callable(self, "_on_big_drill_button_unhovered")):
			Global.hud.BigDrillButtonUnhovered.connect(_on_big_drill_button_unhovered)
			
		if not Global.hud.is_connected("ChargeAttackButtonHovered", Callable(self, "_on_charge_attack_button_hovered")):
			Global.hud.ChargeAttackButtonHovered.connect(_on_charge_attack_button_hovered)
			
		if not Global.hud.is_connected("ChargeAttackButtonUnhovered", Callable(self, "_on_charge_attack_button_unhovered")):
			Global.hud.ChargeAttackButtonUnhovered.connect(_on_charge_attack_button_unhovered)
			
		# Initial update of the upgrade button state
		update_upgrade_button_visibility()
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
	
func _on_charge_attack_button_hovered(player):
	_on_ability_button_hovered(player, "charge_attack")

func _on_charge_attack_button_unhovered():
	_on_ability_button_unhovered("charge_attack")

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
				
				# Show drill visualization for big drill
				if level_manager:
					var current_level = player.current_level
					var current_pos = player.grid_position
					
					if level_manager.has_valid_tile_below(current_level, current_pos):
						show_drill_visualization(current_level, current_pos, current_level + 1, current_pos)
						
						var adjacent_allies = player.get_adjacent_players()
						for ally in adjacent_allies:
							show_drill_visualization(ally.current_level, ally.grid_position, ally.current_level + 1, ally.grid_position)
		"drill":
			# Handle drill specifically since it needs level-based visualization
			_handle_drill_hover(player)
		"charge_attack":
			if player.has_method("highlight_charge_attack_targets"):
				player.highlight_charge_attack_targets()
		"healing_aoe":
			if player.has_method("highlight_aoe_targets"):
				player.highlight_aoe_targets()
		"freeze_aoe":
			if player.has_method("highlight_aoe_targets"):
				player.highlight_aoe_targets()
		"poison_aoe":
			if player.has_method("highlight_aoe_targets"):
				player.highlight_aoe_targets()

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
		
	# Check if the player has spent enough turns on the current level
	if not turns_spent_on_level.has(player.current_level) or turns_spent_on_level[player.current_level] < MIN_TURNS_BEFORE_NEXT_LEVEL:
		return
	
	# Check if the next level is visible
	var next_level = player.current_level + 1
	if not level_manager.level_nodes.has(next_level):
		return
		
	var next_level_map = level_manager.level_nodes[next_level]
	if not next_level_map.get_meta("is_visible_to_player", false):
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
	
	# Player is about to change levels, notify camera
	emit_signal("entity_moved", player)

# Handle big drill hover visualization
func _handle_big_drill_hover(player: PlayerEntity):
	# Check if the player has spent enough turns on the current level
	if not turns_spent_on_level.has(player.current_level) or turns_spent_on_level[player.current_level] < MIN_TURNS_BEFORE_NEXT_LEVEL:
		return
	
	# Check if the next level is visible
	var next_level = player.current_level + 1
	if not level_manager.level_nodes.has(next_level):
		return
		
	var next_level_map = level_manager.level_nodes[next_level]
	if not next_level_map.get_meta("is_visible_to_player", false):
		return
	
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
		"charge_attack":
			if entity.has_method("highlight_charge_attack_targets"):
				entity.highlight_charge_attack_targets()
		"healing_aoe":
			if entity.has_method("highlight_aoe_targets"):
				entity.highlight_aoe_targets()
		"freeze_aoe":
			if entity.has_method("highlight_aoe_targets"):
				entity.highlight_aoe_targets()
		"poison_aoe":
			if entity.has_method("highlight_aoe_targets"):
				entity.highlight_aoe_targets()

func _add_entity(entity: Entity, tile: IsometricTile) -> bool:
	# Ensure the entity isn't already on a tile
	if entity.current_tile:
		print("GameController: Entity " + entity.entity_name + " is already on a tile at " + str(entity.grid_position))
		return false
		
	# Place the entity on the tile
	if tile.is_walkable and not tile.is_occupied:
		# Clear any existing selection
		if selected_entity and selected_entity is PlayerEntity:
			selected_entity.deselect()
			selected_entity = null
			clear_all_highlights()
		
		# Set the entity's position
		entity.place_on_tile(tile)
		
		# Connect signals from the entity
		if not entity.is_connected("entity_selected", Callable(self, "_select_entity")):
			entity.entity_selected.connect(_select_entity)
		
		# Add the entity to the appropriate list
		if entity is PlayerEntity:
			if not player_entities.has(entity):
				player_entities.append(entity)
				
			# Set the entity's game controller reference
			entity.game_controller = self
			print("GameController: Added player " + entity.entity_name + " at " + str(tile.grid_position))
		elif entity is EnemyEntity:
			if not enemy_entities.has(entity):
				enemy_entities.append(entity)
				
			# Set the entity's game controller reference
			entity.game_controller = self
			print("GameController: Added enemy " + entity.entity_name + " at " + str(tile.grid_position))
		else:
			print("GameController: Added entity " + entity.entity_name + " at " + str(tile.grid_position))
		
		return true
	
	print("GameController: Failed to add entity " + entity.entity_name + " - tile is not walkable or is occupied")
	return false

# Check for and remove obsolete levels (levels with no players on or above them)
func check_for_obsolete_levels():
	if not level_manager or level_manager.level_nodes.size() <= 1:
		return
	
	var player_levels = []
	
	# Collect all levels that have players
	for player in player_entities:
		if not player_levels.has(player.current_level):
			player_levels.append(player.current_level)
	
	# Sort the levels to find the highest level that has a player
	player_levels.sort()
	var lowest_player_level = player_levels[0] if player_levels.size() > 0 else 0
	
	# Check all levels below the lowest player level
	var obsolete_levels = []
	for level_idx in level_manager.level_nodes.keys():
		if level_idx < lowest_player_level:
			obsolete_levels.append(level_idx)
	
	# Remove the obsolete levels
	var levels_removed = false
	for level_idx in obsolete_levels:
		remove_level(level_idx)
		levels_removed = true
		
	# Notify camera of level changes if any levels were removed
	if levels_removed:
		emit_signal("entity_moved", null)
	
	# Update the upgrade button visibility after level changes
	update_upgrade_button_visibility()

# Remove a level from the game with a smooth fade-out
func remove_level(level_idx: int):
	if not level_manager or not level_manager.level_nodes.has(level_idx):
		return
	
	var level_map = level_manager.level_nodes[level_idx]
	if not level_map:
		return
	
	print("GameController: Removing obsolete level " + str(level_idx))
	
	# Disconnect signals from the map
	if level_map.is_connected("tile_selected", Callable(self, "_on_tile_selected")):
		level_map.tile_selected.disconnect(_on_tile_selected)
	
	# Handle enemies on this level - first verify that all enemies have correct level assignment
	var enemies_to_remove = []
	
	# First pass: check for enemies that should be on this level
	for enemy in enemy_entities:
		# If an enemy is physically on this level but has incorrect level index,
		# update its current_level to match
		if enemy.get_parent() == level_map and enemy.current_level != level_idx:
			print("GameController: Found enemy " + enemy.entity_name + " on level " + str(level_idx) + 
				  " but its current_level is " + str(enemy.current_level) + ", correcting")
			enemy.current_level = level_idx
		
		# Add all enemies that are actually on this level to the removal list
		if enemy.current_level == level_idx:
			enemies_to_remove.append(enemy)
	
	# Second pass: clean up and remove the enemies
	for enemy in enemies_to_remove:
		print("GameController: Cleaning up enemy " + enemy.entity_name + " on obsolete level " + str(level_idx))
		
		# Verify the enemy's isometric_map reference matches its level
		if enemy.isometric_map != level_map:
			print("GameController: Enemy " + enemy.entity_name + " has incorrect isometric_map reference, fixing")
			enemy.isometric_map = level_map
		
		# Remove from turn sequencer first
		turn_sequencer.remove_character(enemy)
		
		# Remove from our array
		enemy_entities.erase(enemy)
		
		# Disconnect and free the enemy entity
		if enemy.is_connected("died", Callable(self, "_on_entity_died")):
			enemy.died.disconnect(_on_entity_died)
		
		# Remove from its current tile
		if enemy.current_tile:
			enemy.current_tile.remove_entity()
		
		# Check if enemy is still valid before trying to queue_free it
		if is_instance_valid(enemy):
			# Queue for deferred deletion to avoid crashes
			enemy.queue_free()
	
	# Start fade-out animation
	var tween = create_tween()
	tween.tween_property(level_map, "modulate", Color(0.7, 0.7, 0.7, 0.0), 1.0)
	
	# Remove the level after the animation completes
	await tween.finished
	
	# Remove from level manager
	level_manager.level_nodes.erase(level_idx)
	
	# Free the map node itself
	if is_instance_valid(level_map):
		level_map.queue_free()
	
	print("GameController: Level " + str(level_idx) + " removed")
	
	# If this was the active level, change to a valid level
	if level_idx == current_active_level and level_manager.level_nodes.size() > 0:
		var new_active_level = level_manager.level_nodes.keys().min()
		set_active_level(new_active_level, level_manager.level_nodes[new_active_level])

# Initialize level visibility (only make the first level visible)
func initialize_level_visibility():
	if not level_manager:
		return
		
	print("GameController: Initializing level visibility")
	
	# Reset turns spent on levels
	turns_spent_on_level[0] = 0
	
	# Make all other levels invisible
	for level_idx in level_manager.level_nodes:
		var level_map = level_manager.level_nodes[level_idx]
		
		if level_idx == 0:
			# First level is visible
			level_map.modulate = Color(1.0, 1.0, 1.0, 1.0)
			level_map.visible = true
			level_map.set_meta("is_visible_to_player", true)
		else:
			# All other levels are invisible
			level_map.modulate = Color(1.0, 1.0, 1.0, 0.0)
			level_map.visible = false
			level_map.set_meta("is_visible_to_player", false)
			turns_spent_on_level[level_idx] = 0
	
	# Force deeper levels to be hidden - use call_deferred to make sure this happens after current frame
	for level_idx in level_manager.level_nodes:
		if level_idx > 0:
			print("GameController: Hiding level " + str(level_idx))
			var level_map = level_manager.level_nodes[level_idx]
			# Force invisible state
			level_map.visible = false
			level_map.set_meta("is_visible_to_player", false)
			# Set z-index to keep it behind the first level
			level_map.z_index = -level_idx
			
			# Stop any ongoing animations
			level_map.modulate = Color(1.0, 1.0, 1.0, 0.0)
	
	# Update the upgrade button visibility
	update_upgrade_button_visibility()

# Update tracking of turns spent on each level and reveal next levels if needed
func update_turns_spent_on_levels():
	if not level_manager:
		return
		
	# Track which levels have players
	var levels_with_players = {}
	
	# Increment turn count for levels that have players
	for player in player_entities:
		var level = player.current_level
		levels_with_players[level] = true
		
		if not turns_spent_on_level.has(level):
			turns_spent_on_level[level] = 0
			
		turns_spent_on_level[level] += 1
		
		print("GameController: Players have spent " + str(turns_spent_on_level[level]) + " turns on level " + str(level))
		
		# Check if we should reveal the next level
		if turns_spent_on_level[level] >= MIN_TURNS_BEFORE_NEXT_LEVEL:
			reveal_next_level(level)
			
	# Now check if any level has players for the first time
	for level in levels_with_players:
		var level_map = level_manager.level_nodes.get(level)
		if level_map and not level_map.has_meta("is_visible_to_player"):
			level_map.set_meta("is_visible_to_player", true)
			reveal_level(level)
	
	# Update the upgrade button visibility
	update_upgrade_button_visibility()

# Reveal the level below the given level
func reveal_next_level(current_level):
	if not level_manager:
		return
		
	var next_level = current_level + 1
	
	# Check if this level exists and is not already visible
	if level_manager.level_nodes.has(next_level):
		var level_map = level_manager.level_nodes[next_level]
		if not level_map.get_meta("is_visible_to_player", false):
			reveal_level(next_level)

# Reveal a specific level with animation
func reveal_level(level_idx):
	if not level_manager or not level_manager.level_nodes.has(level_idx):
		return
		
	var level_map = level_manager.level_nodes[level_idx]
	
	# Skip if already visible
	if level_map.get_meta("is_visible_to_player", false):
		return
		
	print("GameController: Revealing level " + str(level_idx))
	
	# Mark as visible
	level_map.set_meta("is_visible_to_player", true)
	if not turns_spent_on_level.has(level_idx):
		turns_spent_on_level[level_idx] = 0
	
	# Make sure it's visible first
	level_map.visible = true
	
	# Fade in animation
	var tween = create_tween()
	tween.tween_property(level_map, "modulate", Color(0.7, 0.7, 0.7, 1.0), 1.0)
	
	# Connect tile_selected signal if not already connected
	if not level_map.is_connected("tile_selected", Callable(self, "_on_tile_selected")):
		level_map.tile_selected.connect(_on_tile_selected)

# Check if all enemies on a specific level have been defeated
func check_level_enemies_cleared(level_index: int):
	# Count how many enemies are still on this level
	var enemies_on_level = 0
	for enemy in enemy_entities:
		# Skip exploding barrels and destructible walls for level clearing check
		if enemy.current_level == level_index and enemy.enemy_type != EnemyEntity.EnemyType.EXPLOSIVE_BARREL and enemy.enemy_type != EnemyEntity.EnemyType.DESTRUCTIBLE_WALL:
			enemies_on_level += 1
	
	print("GameController: Level " + str(level_index) + " has " + str(enemies_on_level) + " enemies remaining")
	
	# If no enemies left on this level, reveal the next level
	if enemies_on_level == 0:
		print("GameController: All enemies on level " + str(level_index) + " defeated, revealing next level")
		# Reveal the next level immediately, regardless of turn counter
		reveal_next_level(level_index)
		
	# Update the upgrade button visibility based on enemies remaining
	update_upgrade_button_visibility()
	
	return enemies_on_level == 0

# Check if there are enemies on the current active level
func has_enemies_on_active_level() -> bool:
	for enemy in enemy_entities:
		if enemy.current_level == current_active_level and enemy.enemy_type != EnemyEntity.EnemyType.EXPLOSIVE_BARREL and enemy.enemy_type != EnemyEntity.EnemyType.DESTRUCTIBLE_WALL:
			return true
	return false

# Update the upgrade button visibility in the HUD
func update_upgrade_button_visibility() -> void:
	if Global.hud:
		var has_enemies = has_enemies_on_active_level()
		# Hide the upgrade button if there are enemies on the current level
		Global.hud.set_upgrade_button_enabled(!has_enemies)
		
		if has_enemies:
			print("GameController: Hiding upgrade button - enemies still on level")
		else:
			print("GameController: Showing upgrade button - level cleared")
