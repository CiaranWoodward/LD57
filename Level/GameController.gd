class_name GameController
extends Node

# References to game nodes
var isometric_map: IsometricMap
var player_entity: Entity = null
var selected_entity: Entity = null

# References to scenes
@export var entity_scene: PackedScene  # Reference to the entity scene to instantiate

# Game state
var current_turn: String = "player"  # "player" or "enemy"
var game_state: String = "idle"  # "idle", "player_turn", "enemy_turn", "game_over"

# Signals
signal turn_changed(turn)
signal entity_moved(entity)
signal game_state_changed(state)

func _ready():
	# Find the map in the scene
	isometric_map = get_node_or_null("../Map")
	if isometric_map:
		isometric_map.connect("tile_selected", Callable(self, "_on_tile_selected"))

# Called when a tile is selected on the map
func _on_tile_selected(tile: IsometricTile):
	# If we have a selected entity and it's player's turn, try to move it
	if selected_entity and current_turn == "player" and game_state == "player_turn":
		move_entity_to_tile(selected_entity, tile.grid_position)

# Called when an entity is selected
func _on_entity_selected(entity: Entity):
	if current_turn == "player" and game_state == "player_turn":
		if selected_entity:
			# Deselect previous entity
			# (visual feedback would be implemented here)
			pass
		
		selected_entity = entity
		# Visual feedback for selection would be implemented here

# Move an entity to a specific tile
func move_entity_to_tile(entity: Entity, target_grid_pos: Vector2i):
	if not entity or not isometric_map:
		return
		
	# Get the path to the target
	var path = isometric_map.find_path(entity.grid_position, target_grid_pos)
	
	if path.size() > 0:
		# Set the path for the entity to follow
		entity.connect("movement_completed", Callable(self, "_on_entity_movement_completed").bind(entity), 4)  # One-shot connection
		entity.set_path(path)

# Called when an entity finishes moving
func _on_entity_movement_completed(entity: Entity):
	emit_signal("entity_moved", entity)
	
	# If it was player's turn, check if all player entities have moved
	if current_turn == "player":
		check_end_player_turn()
	else:
		check_end_enemy_turn()

# Check if player turn should end
func check_end_player_turn():
	# This is a placeholder. Implement your turn logic here
	# For example, you might end the turn after all player entities have moved
	
	# For now, just end the turn
	end_player_turn()

# Check if enemy turn should end
func check_end_enemy_turn():
	# This is a placeholder. Implement your turn logic here
	
	# For now, just end the turn
	end_enemy_turn()

# End the player's turn and start enemy turn
func end_player_turn():
	current_turn = "enemy"
	game_state = "enemy_turn"
	emit_signal("turn_changed", current_turn)
	emit_signal("game_state_changed", game_state)
	
	# Start enemy AI actions
	process_enemy_turn()

# End the enemy's turn and start player turn
func end_enemy_turn():
	current_turn = "player"
	game_state = "player_turn"
	emit_signal("turn_changed", current_turn)
	emit_signal("game_state_changed", game_state)

# Process the enemy turn with AI
func process_enemy_turn():
	# This is a placeholder for enemy AI
	# Implement your enemy turn logic here
	
	# For now, just end the enemy turn immediately
	end_enemy_turn()

# Start a new game
func start_game():
	game_state = "player_turn"
	current_turn = "player"
	emit_signal("game_state_changed", game_state)
	emit_signal("turn_changed", current_turn)

# Spawn a player entity on the map
func spawn_player(grid_pos: Vector2i, texture: Texture2D = null) -> Entity:
	var entity: Entity
	
	if entity_scene:
		entity = entity_scene.instantiate()
	else:
		entity = Entity.new()
		
	entity.entity_id = "player"
	entity.entity_name = "Player"
	
	if texture:
		entity.set_texture(texture)
	
	# Set the map reference
	entity.isometric_map = isometric_map
	
	add_child(entity)
	
	# Place on the tile
	var tile = isometric_map.get_tile(grid_pos)
	if tile:
		entity.place_on_tile(tile)
	
	# Connect signals
	entity.connect("entity_selected", Callable(self, "_on_entity_selected"))
	
	player_entity = entity
	return entity

# Spawn an enemy on the map
func spawn_enemy(grid_pos: Vector2i, enemy_type: String, texture: Texture2D = null) -> Entity:
	var entity: Entity
	
	if entity_scene:
		entity = entity_scene.instantiate()
	else:
		entity = Entity.new()
		
	entity.entity_id = "enemy_" + str(randi())
	entity.entity_name = enemy_type
	
	if texture:
		entity.set_texture(texture)
	
	# Set the map reference
	entity.isometric_map = isometric_map
	
	add_child(entity)
	
	# Place on the tile
	var tile = isometric_map.get_tile(grid_pos)
	if tile:
		entity.place_on_tile(tile)
	
	return entity 