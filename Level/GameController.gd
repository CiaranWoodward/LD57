class_name GameController
extends Node

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
var current_turn: String = "player"  # "player" or "enemy"
var game_state: String = "idle"  # "idle", "player_turn", "enemy_turn", "game_over"
var active_player_index: int = 0   # Index of the current active player entity

# Signals
signal turn_changed(turn)
signal entity_moved(entity)
signal game_state_changed(state)
signal player_activated(player_entity)

func _ready():
	print("GameController: Initializing")
	# Find the map in the scene
	isometric_map = get_node_or_null("../Map")
	if isometric_map:
		print("GameController: Map found, connecting signals")
		isometric_map.connect("tile_selected", Callable(self, "_on_tile_selected"))
	else:
		push_error("GameController: Map not found!")

# Called when a tile is selected on the map
func _on_tile_selected(tile):
	print("GameController: Tile selected at " + str(tile.grid_position))
	# If we have a selected entity and it's player's turn, try to move it
	if selected_entity and current_turn == "player" and game_state == "player_turn":
		if "grid_position" in selected_entity and selected_entity in player_entities:
			print("GameController: Attempting to move entity " + selected_entity.entity_name + " to " + str(tile.grid_position))
			move_entity_to_tile(selected_entity, tile.grid_position)
		else:
			print("GameController: Cannot move entity - invalid conditions")
	else:
		print("GameController: Cannot move - no selected entity or not player turn")

# Called when an entity is selected
func _on_entity_selected(entity):
	print("GameController: Entity selected: " + entity.entity_name)
	if current_turn == "player" and game_state == "player_turn":
		if entity in player_entities:
			if selected_entity:
				# Deselect previous entity
				print("GameController: Deselecting previous entity")
				# (visual feedback would be implemented here)
				pass
			
			selected_entity = entity
			print("GameController: New entity selected: " + entity.entity_name)
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
	
	# Get the path to the target
	var path = isometric_map.find_path(entity.grid_position, target_grid_pos)
	
	if path.size() > 0:
		print("GameController: Path found with " + str(path.size()) + " steps")
		# Set the path for the entity to follow
		if not entity.is_connected("movement_completed", Callable(self, "_on_entity_movement_completed")):
			print("GameController: Connecting movement_completed signal")
			entity.connect("movement_completed", Callable(self, "_on_entity_movement_completed").bind(entity), CONNECT_ONE_SHOT)
		entity.set_path(path)
	else:
		print("GameController: No path found to target position")

# Called when an entity finishes moving
func _on_entity_movement_completed(entity : Node):
	print("GameController: Entity " + entity.entity_name + " completed movement")
	emit_signal("entity_moved", entity)
	
	# If it was player's turn, check if all player entities have moved
	if current_turn == "player":
		check_end_player_turn()
	else:
		check_end_enemy_turn()

# Check if player turn should end
func check_end_player_turn():
	print("GameController: Checking if player turn should end")
	# Check if current active player has no more action points
	if active_player_index < player_entities.size():
		var active_player = player_entities[active_player_index]
		
		if active_player.action_points <= 0:
			print("GameController: Active player has no more action points")
			activate_next_player()
		
	# If all players have moved (or we have no players)
	if active_player_index >= player_entities.size():
		print("GameController: All players have moved, ending turn")
		end_player_turn()

# Activate the next player with action points
func activate_next_player():
	active_player_index += 1
	print("GameController: Activating next player, index: " + str(active_player_index))
	
	# Find the next player with action points
	while active_player_index < player_entities.size():
		var player = player_entities[active_player_index]
		if player.action_points > 0:
			selected_entity = player
			print("GameController: Activated player: " + player.entity_name + " with " + str(player.action_points) + " action points")
			emit_signal("player_activated", player)
			return
		active_player_index += 1
	
	# If we get here, no players have action points left
	print("GameController: No more players with action points")
	selected_entity = null

# Check if enemy turn should end
func check_end_enemy_turn():
	print("GameController: Checking if enemy turn should end")
	# Check if all enemies have moved
	var all_enemies_moved = true
	
	for enemy in enemy_entities:
		if enemy.is_moving:
			all_enemies_moved = false
			break
	
	if all_enemies_moved:
		print("GameController: All enemies have moved, ending turn")
		end_enemy_turn()

# End the player's turn and start enemy turn
func end_player_turn():
	print("GameController: Ending player turn, starting enemy turn")
	current_turn = "enemy"
	game_state = "enemy_turn"
	emit_signal("turn_changed", current_turn)
	emit_signal("game_state_changed", game_state)
	
	# Start enemy AI actions
	process_enemy_turn()

# End the enemy's turn and start player turn
func end_enemy_turn():
	print("GameController: Ending enemy turn, starting player turn")
	current_turn = "player"
	game_state = "player_turn"
	emit_signal("turn_changed", current_turn)
	emit_signal("game_state_changed", game_state)
	
	# Reset player entities for new turn
	active_player_index = 0
	for player in player_entities:
		player.start_turn()
	
	# Activate first player
	if player_entities.size() > 0:
		selected_entity = player_entities[0]
		print("GameController: Activated first player: " + selected_entity.entity_name)
		emit_signal("player_activated", selected_entity)
	else:
		selected_entity = null

# Process the enemy turn with AI
func process_enemy_turn():
	print("GameController: Processing enemy turn for " + str(enemy_entities.size()) + " enemies")
	# Process each enemy's turn
	var any_enemy_moving = false
	
	for enemy in enemy_entities:
		# Have the enemy process its turn
		print("GameController: Processing turn for enemy: " + enemy.entity_name)
		if enemy.process_turn(player_entities):
			any_enemy_moving = true
	
	# If no enemies are moving, end the turn
	if not any_enemy_moving:
		print("GameController: No enemies are moving, ending turn")
		end_enemy_turn()

# Start a new game
func start_game():
	print("GameController: Starting new game")
	game_state = "player_turn"
	current_turn = "player"
	active_player_index = 0
	
	# Reset all entities
	for player in player_entities:
		player.start_turn()
	
	emit_signal("game_state_changed", game_state)
	emit_signal("turn_changed", current_turn)
	
	# Activate first player
	if player_entities.size() > 0:
		selected_entity = player_entities[0]
		print("GameController: First player activated: " + selected_entity.entity_name)
		emit_signal("player_activated", selected_entity)

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
	
	# Set the map reference
	entity.isometric_map = isometric_map
	
	add_child(entity)
	
	# Place on the tile
	var tile = isometric_map.get_tile(grid_pos)
	if tile:
		entity.place_on_tile(tile)
		print("GameController: Player placed on tile at " + str(grid_pos))
	else:
		push_error("GameController: Could not find tile at " + str(grid_pos))
	
	# Connect signals
	entity.connect("entity_selected", Callable(self, "_on_entity_selected"))
	entity.connect("died", Callable(self, "_on_entity_died"))
	
	# Add to player entities array
	player_entities.append(entity)
	print("GameController: Player " + entity.entity_name + " added to player entities")
	
	return entity

# Spawn an enemy on the map
func spawn_enemy(grid_pos, enemy_type_id):
	print("GameController: Spawning enemy of type " + str(enemy_type_id) + " at " + str(grid_pos))
	var entity = load("res://Level/EnemyEntity.gd").new()
	
	# Configure enemy
	entity.set_enemy_type(enemy_type_id)
	
	# Set the map reference
	entity.isometric_map = isometric_map
	
	add_child(entity)
	
	# Place on the tile
	var tile = isometric_map.get_tile(grid_pos)
	if tile:
		entity.place_on_tile(tile)
		print("GameController: Enemy placed on tile at " + str(grid_pos))
	else:
		push_error("GameController: Could not find tile at " + str(grid_pos))
	
	# Connect signals
	entity.connect("died", Callable(self, "_on_entity_died"))
	
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
			game_state = "game_over"
			print("GameController: Game over - all players are dead")
			emit_signal("game_state_changed", game_state)
	
	elif entity in enemy_entities:
		enemy_entities.erase(entity)
		print("GameController: Enemy removed from game, " + str(enemy_entities.size()) + " enemies remaining")
		
		# Check if all enemies are defeated
		if enemy_entities.size() == 0:
			# Victory condition
			print("GameController: Victory - all enemies defeated")
			pass 
