class_name StoneWallTile
extends IsometricTile

# Reference to the isometric map for accessing other tiles
var isometric_map: IsometricMap = null
var needs_transparency_update: bool = true
var watched_tiles = []

func _init():
	type = "stone_wall"
	is_walkable = false  # Cannot walk through walls
	movement_cost = 0.0  # Not applicable for walls

func _ready():
	super._ready()
	
	# Add a process method for dynamic transparency updates
	set_process(true)
	
	# Find the isometric map in the scene hierarchy
	var parent = get_parent()
	while parent and not parent is IsometricMap:
		parent = parent.get_parent()
	
	isometric_map = parent as IsometricMap
	if not isometric_map:
		push_error("StoneWallTile: Could not find IsometricMap parent")
	
	# Initial transparency update
	update_transparency()
	
	# Connect to tile selection signal for when highlights change
	if isometric_map:
		isometric_map.connect("tile_selected", _on_any_tile_selected)
		
		# Connect to signals from nearby tiles for more responsive updates
		call_deferred("connect_to_nearby_tiles")
		
	# Find the game controller to monitor entity movements
	var game_controller = find_game_controller()
	if game_controller:
		game_controller.connect("entity_moved", _on_entity_moved)
		game_controller.connect("player_activated", _on_player_activated)

# Try to find the game controller node
func find_game_controller():
	# Look for a node in the "game_controller" group
	var controllers = get_tree().get_nodes_in_group("game_controller")
	if controllers.size() > 0:
		return controllers[0]
	return null

func _process(delta):
	if needs_transparency_update:
		update_transparency()
		needs_transparency_update = false

# Mark for transparency update when a tile is selected
func _on_any_tile_selected(_tile):
	needs_transparency_update = true

# Mark for transparency update when an entity moves
func _on_entity_moved(_entity):
	needs_transparency_update = true

# Mark for transparency update when a player is activated
func _on_player_activated(_player):
	needs_transparency_update = true

# Update the wall's transparency based on what's behind it
func update_transparency():
	assert(is_instance_valid(isometric_map))
	
	var wall_sprite = get_node_or_null("Sprite2D")
	if not wall_sprite:
		return
	
	# Check for entity or highlight in any of these 3 adjacent tiles
	var modulation = 0.25
	for adj_tile in watched_tiles:
		if adj_tile.is_occupied or adj_tile.is_highlighted or adj_tile.is_move_selectable or adj_tile.is_attackable or adj_tile.is_hovered:
			# Entity or highlight found in a neighboring tile, set to 25% transparency
			wall_sprite.self_modulate = Color(1, 1, 1, modulation)
			return
		modulation = 0.5
	
	# No relevant entities or highlights found, restore normal transparency
	wall_sprite.self_modulate = Color(1, 1, 1, 1.0)

# Connect to signals from nearby tiles that might affect our transparency
func connect_to_nearby_tiles():
	if not isometric_map:
		return
		
	# We only care about the north tile and its three adjacent tiles
	var north_pos = grid_position + Vector2i(-1, -1)
	var north_tile = isometric_map.get_tile(north_pos)
	
	# Connect to the adjacent tiles
	if north_tile:
		var adjacent_positions = [
			north_pos,
			north_pos + Vector2i(-1, 0),  
			north_pos + Vector2i(0, -1),  
			north_pos + Vector2i(1, 0),
			north_pos + Vector2i(0, 1),
			north_pos + Vector2i(-1, -1),
		]
		
		for adj_pos in adjacent_positions:
			var adj_tile = isometric_map.get_tile(adj_pos)
			if adj_tile:
				watched_tiles.append(adj_tile)
				adj_tile.connect("tile_clicked", Callable(self, "_on_nearby_tile_clicked"))
				adj_tile.connect("tile_hover_change", Callable(self, "_on_nearby_tile_clicked"))

# When a nearby tile is clicked
func _on_nearby_tile_clicked(_tile):
	needs_transparency_update = true
