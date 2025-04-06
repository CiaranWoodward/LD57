class_name EnemyEntity
extends Entity

enum EnemyType { GRUNT, ELITE, BOSS, MINION }

# Enemy-specific properties
var enemy_type: EnemyType = EnemyType.GRUNT
var aggression_level: float = 0.5  # 0.0 to 1.0, how aggressive this enemy is
var detection_range: int = 5  # How many tiles away this enemy can detect players
var patrol_path: Array = []  # Array of grid positions for patrol route
var current_patrol_index: int = 0  # Current position in patrol route
var alert_status: String = "idle"  # "idle", "suspicious", "alert"

# Behavior tracking
var target_entity: Entity = null
var last_known_player_position: Vector2i = Vector2i(-1, -1)

# Signals
signal alert_status_changed(new_status)

func _init():
	super._init()
	entity_name = "Enemy"
	entity_id = "enemy_" + str(randi())

# Override start_turn from Entity
func start_turn():
	super.start_turn()
	
	assert(!is_moving)
	
	# Get player entities from game controller
	var player_entities = []
	if game_controller and game_controller.has_method("get_player_entities"):
		player_entities = game_controller.get_player_entities()
	
	# Process AI turn
	var did_move = process_turn(player_entities)
	
	# If we didn't move, finish turn immediately
	if not did_move:
		print("EnemyEntity: " + entity_name + " didn't move, finishing turn")
		call_deferred("finish_turn")

# Override finish_turn from Entity
func finish_turn():
	print("EnemyEntity: " + entity_name + " finishing turn")
	
	# Check if still moving - if so, delay turn finish
	if is_moving:
		print("EnemyEntity: " + entity_name + " is still moving, delaying turn finish")
		return
	
	super.finish_turn()

# Set patrol path (array of grid positions)
func set_patrol_path(path_positions: Array):
	patrol_path = path_positions
	current_patrol_index = 0

# Process AI behavior during enemy turn
func process_turn(player_entities: Array):
	# Assert that isometric_map is set
	assert(isometric_map != null, "EnemyEntity: " + entity_name + " - isometric_map reference not set!")
	
	# Reset movement
	is_moving = false
	path = []
	
	# Filter player entities to only include those on the same level
	var same_level_players = []
	for player in player_entities:
		if player.current_level == current_level:
			same_level_players.append(player)
	
	# Check for player entities in range
	var closest_player = find_closest_player(same_level_players)
	
	if closest_player:
		# Player detected - pursue or attack
		target_entity = closest_player
		last_known_player_position = closest_player.grid_position
		
		if alert_status != "alert":
			set_alert_status("alert")
		
		# Calculate path to player
		pursue_target()
	else:
		# No player in sight
		if alert_status == "alert":
			# Check last known position
			if last_known_player_position != Vector2i(-1, -1):
				# Move to last known position
				var path_to_last_known = isometric_map.find_path(grid_position, last_known_player_position)
				if path_to_last_known.size() > 0:
					path = path_to_last_known
					is_moving = true
				else:
					# Can't reach last known position, go back to patrol
					last_known_player_position = Vector2i(-1, -1)
					set_alert_status("suspicious")
					follow_patrol_path()
			else:
				set_alert_status("suspicious")
				follow_patrol_path()
		else:
			# Normal patrol behavior
			follow_patrol_path()
	
	return is_moving

# Find the closest player entity within detection range
func find_closest_player(player_entities: Array) -> Entity:
	var closest_distance = detection_range + 1
	var closest_player = null
	
	for player in player_entities:
		if player.is_defeated() or player.current_level != current_level:
			continue
			
		var distance = grid_position.distance_to(player.grid_position)
		if distance <= detection_range and distance < closest_distance:
			# Check line of sight
			if has_line_of_sight(player.grid_position):
				closest_distance = distance
				closest_player = player
	
	return closest_player

# Check if we have line of sight to a position
func has_line_of_sight(target_pos: Vector2i) -> bool:
	# Simple implementation - can be expanded with proper line of sight algorithms
	# For now, just check if there are any non-walkable tiles in between
	var line = get_line(grid_position, target_pos)
	
	for pos in line:
		var tile = isometric_map.get_tile(pos)
		if tile == null or not tile.is_walkable:
			return false
	
	return true

# Get a line of grid positions from start to end (Bresenham's line algorithm)
func get_line(start: Vector2i, end: Vector2i) -> Array:
	var line = []
	
	var x0 = start.x
	var y0 = start.y
	var x1 = end.x
	var y1 = end.y
	
	var dx = abs(x1 - x0)
	var dy = -abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx + dy
	
	while true:
		# Skip the start position
		if Vector2i(x0, y0) != start:
			line.append(Vector2i(x0, y0))
		
		if x0 == x1 and y0 == y1:
			break
			
		var e2 = 2 * err
		if e2 >= dy:
			if x0 == x1:
				break
			err += dy
			x0 += sx
		if e2 <= dx:
			if y0 == y1:
				break
			err += dx
			y0 += sy
	
	return line

# Pursue target entity
func pursue_target():
	# Assert required references exist
	assert(target_entity != null, "EnemyEntity: " + entity_name + " - target_entity is null in pursue_target")
	assert(isometric_map != null, "EnemyEntity: " + entity_name + " - isometric_map is null in pursue_target")
	
	var path_to_target = isometric_map.find_path(grid_position, target_entity.grid_position)
	
	# If path exists and is longer than 1 tile
	if path_to_target.size() > 0:
		# Only move part of the way based on aggression level
		var steps = max(1, round(path_to_target.size() * aggression_level))
		path = []
		
		for i in range(min(steps, path_to_target.size())):
			path.append(path_to_target[i])
		
		is_moving = true

# Follow patrol path
func follow_patrol_path():
	if patrol_path.size() == 0:
		return
	
	# Assert isometric_map exists
	assert(isometric_map != null, "EnemyEntity: " + entity_name + " - isometric_map is null in follow_patrol_path")
		
	# Get next patrol point
	var target_pos = patrol_path[current_patrol_index]
	
	if grid_position == target_pos:
		# Already at target, advance to next patrol point
		current_patrol_index = (current_patrol_index + 1) % patrol_path.size()
		target_pos = patrol_path[current_patrol_index]
	
	# Find path to next patrol point
	var path_to_patrol = isometric_map.find_path(grid_position, target_pos)
	if path_to_patrol.size() > 0:
		# Only take a few steps at a time
		path = []
		for i in range(min(2, path_to_patrol.size())):
			path.append(path_to_patrol[i])
		is_moving = true

# Set alert status
func set_alert_status(status: String):
	if alert_status != status:
		alert_status = status
		emit_signal("alert_status_changed", status)

# Called when the entity has completed following its path
func _on_path_completed():
	super._on_path_completed()
	
	# Check if this was during our turn, and if so, we might finish our turn
	if is_turn_active:
		print("Entity: " + entity_name + " will finish turn after movement completed")
		call_deferred("finish_turn") 
