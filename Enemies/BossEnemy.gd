class_name BossEnemy
extends EnemyEntity

# Ranged attack parameters
var beam_attack_damage: int = 5
var beam_attack_range: int = 6
var beam_cooldown: int = 0
var cardinal_directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
var diagonal_directions = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

func _init():
	entity_name = "Boss"
	entity_id = "boss_" + str(randi())

func _ready():
	super._ready()
	enemy_type = EnemyType.BOSS
	
	# Boss-specific configuration - very fast, aggressive, and strong
	move_speed = 2.5  # Very fast movement speed
	detection_range = 15  # Can see players from very far away
	aggression_level = 1.0  # Maximum aggression
	max_health = 20
	current_health = 20

# Override process_turn to make the boss more formidable
func process_turn(player_entities: Array):
	# Reset movement
	is_moving = false
	path = []
	
	# Decrease attack cooldown if it's active
	if beam_cooldown > 0:
		beam_cooldown -= 1
	
	# Filter player entities to only include those on the same level
	var same_level_players = []
	for player in player_entities:
		if player.current_level == current_level and not player.is_defeated():
			same_level_players.append(player)
	
	# If no players on this level, use standard behavior
	if same_level_players.size() == 0:
		print("BossEnemy: " + entity_name + " no players found, using standard behavior")
		return super.process_turn(player_entities)
	
	# Try to attack if not on cooldown
	if beam_cooldown == 0:
		print("BossEnemy: " + entity_name + " attempting beam attack")
		var attack_result = find_and_perform_beam_attack(same_level_players)
		if attack_result:
			beam_cooldown = 2
			print("BossEnemy: " + entity_name + " beam attack successful")
			return false
	
	# If we didn't attack, try to move to the closest player
	var closest_player = find_closest_player(same_level_players)
	if closest_player:
		print("BossEnemy: " + entity_name + " moving toward player at " + str(closest_player.grid_position))
		return move_toward_player(closest_player, 2)
	
	# Fallback to standard behavior if all else fails
	return super.process_turn(player_entities)

# Move toward a player
func move_toward_player(player: Entity, steps: int) -> bool:
	# Set target_entity for use in find_adjacent_positions_to_target
	target_entity = player
	
	# First, try to find adjacent positions to the player
	var adjacent_positions = find_adjacent_positions_to_target()
	
	if adjacent_positions.size() > 0:
		# Find closest adjacent position
		var closest_adjacent = find_closest_position(adjacent_positions)
		
		# Path to the adjacent position
		var path_to_target = isometric_map.find_path(grid_position, closest_adjacent)
		
		if path_to_target.size() > 0:
			# Take a few steps
			path = []
			for i in range(min(steps, path_to_target.size())):
				path.append(path_to_target[i])
			
			is_moving = true
			return true
	
	# If we couldn't path to adjacent positions, try direct path
	var direct_path = isometric_map.find_path(grid_position, player.grid_position)
	if direct_path.size() > 0:
		path = []
		for i in range(min(steps, direct_path.size())):
			path.append(direct_path[i])
		
		is_moving = true
		return true
	
	return false

# Override find_adjacent_positions_to_target to include diagonal positions as well
func find_adjacent_positions_to_target() -> Array:
	var adjacent_positions = []
	
	# Check all neighbors of target position
	var target_pos = target_entity.grid_position
	
	# Include both cardinal and diagonal directions
	for dir in cardinal_directions + diagonal_directions:
		var pos = target_pos + dir
		var tile = isometric_map.get_tile(pos)
		
		if tile and tile.is_walkable and not tile.is_occupied:
			adjacent_positions.append(pos)
	
	return adjacent_positions

# Find the best position for a beam attack
func find_and_perform_beam_attack(player_entities: Array) -> bool:
	# First check if any player is in direct line of sight
	for player in player_entities:
		var direction_to_player = get_direction_to_target(player.grid_position)
		if direction_to_player != Vector2i.ZERO:
			var hit_entities = project_beam(direction_to_player)
			var can_hit_player = false
			
			for entity in hit_entities:
				if entity is PlayerEntity:
					can_hit_player = true
					break
			
			if can_hit_player:
				print("BossEnemy: " + entity_name + " found direct line to player")
				perform_beam_attack(direction_to_player, hit_entities)
				return true
	
	# If no direct line of sight, try all 8 directions to find any hit
	var best_result = find_best_beam_direction(player_entities)
	if best_result.size() > 0:
		print("BossEnemy: " + entity_name + " found best beam direction")
		perform_beam_attack(best_result.direction, best_result.hit_entities)
		return true
	
	return false

# Get a normalized direction to target if in straight line
func get_direction_to_target(target_pos: Vector2i) -> Vector2i:
	var delta = target_pos - grid_position
	
	# Check if target is in a straight line (cardinal or diagonal)
	if delta.x == 0 and delta.y != 0:
		# Vertical line
		return Vector2i(0, sign(delta.y))
	elif delta.y == 0 and delta.x != 0:
		# Horizontal line
		return Vector2i(sign(delta.x), 0)
	elif abs(delta.x) == abs(delta.y):
		# Diagonal line
		return Vector2i(sign(delta.x), sign(delta.y))
	
	# Not in a straight line
	return Vector2i.ZERO

# Project a beam in a direction and return hit entities
func project_beam(direction: Vector2i) -> Array:
	var hit_entities = []
	var current_pos = grid_position
	
	# Project the beam
	for i in range(beam_attack_range):
		current_pos += direction
		
		# Get the tile at this position
		var current_tile = isometric_map.get_tile(current_pos)
		
		# If there's no tile or it's a wall, stop the beam
		if not current_tile or not current_tile.is_walkable:
			break
		
		# If the tile has an entity, add it to hit entities
		if current_tile.is_occupied and current_tile.occupying_entity:
			var entity = current_tile.occupying_entity
			hit_entities.append(entity)
			
			# If we hit a wall or enemy, the beam stops (doesn't pass through)
			if not entity is PlayerEntity:
				break
	
	return hit_entities

# Find the best direction for a beam attack
func find_best_beam_direction(player_entities: Array) -> Dictionary:
	var result = {}
	var best_score = 0
	
	# Check in all 8 directions
	for direction in cardinal_directions + diagonal_directions:
		var hit_entities = project_beam(direction)
		
		# Calculate score for this beam direction
		var player_count = 0
		for entity in hit_entities:
			if entity is PlayerEntity:
				# Skip players that are not visible to enemies (e.g., cloaked Scout)
				if entity.has_method("is_visible_to_enemies") and not entity.is_visible_to_enemies():
					continue
				player_count += 1
		
		# Only consider directions that would hit at least one player
		if player_count > 0 and player_count > best_score:
			best_score = player_count
			result = {
				"direction": direction,
				"hit_entities": hit_entities,
				"player_count": player_count
			}
	
	return result

# Perform a beam attack in the given direction
func perform_beam_attack(attack_direction: Vector2i, hit_entities: Array):
	# Visual indication of attack
	modulate = Color(1.5, 0.0, 0.0, 1.0)  # Briefly flash red
	
	# Create a timer to reset the color
	var timer = get_tree().create_timer(0.2)
	timer.timeout.connect(func(): modulate = Color(1, 1, 1, 1))
	
	# Face the attack direction
	update_facing_direction(Vector2(attack_direction))
	
	print("BossEnemy: " + entity_name + " performing beam attack in direction " + str(attack_direction))
	
	# Draw the beam - make sure it starts from the boss's position
	var beam_line = $BeamAttackLine
	if beam_line:
		beam_line.visible = true
		beam_line.clear_points()
		
		# Start position is at the boss's center (adjusted for height)
		var start_pos = Vector2(0, -36)
		beam_line.add_point(start_pos)
		
		# Calculate end position - beam extends from boss in the attack direction
		var end_pos = start_pos + (Vector2(attack_direction) * beam_attack_range * 64)
		beam_line.add_point(end_pos)
		
		# Hide the beam after a short delay
		var line_timer = get_tree().create_timer(0.3)
		line_timer.timeout.connect(func(): beam_line.visible = false)
	
	# Play attack particles at the boss position
	var particles = $BeamAttackParticles
	if particles:
		# Ensure particles emit from the boss
		particles.position = Vector2(0, -36)
		
		# Set particle direction to match beam
		particles.direction = Vector2(attack_direction)
		particles.emitting = true
		
		# For more visual impact, add particles along the beam path
		for i in range(1, beam_attack_range + 1):
			var beam_pos = Vector2(attack_direction * i)
			var beam_particles = CPUParticles2D.new()
			add_child(beam_particles)
			
			# Configure the beam particles
			beam_particles.amount = 15
			beam_particles.lifetime = 0.3
			beam_particles.one_shot = true
			beam_particles.explosiveness = 0.8
			beam_particles.direction = Vector2(0, 0)
			beam_particles.spread = 180.0
			beam_particles.gravity = Vector2.ZERO
			beam_particles.initial_velocity_min = 20.0
			beam_particles.initial_velocity_max = 40.0
			beam_particles.scale_amount_min = 2.0
			beam_particles.scale_amount_max = 3.0
			beam_particles.color = Color(1, 0.2, 0.2, 0.7)
			
			# Position particles along the beam path
			beam_particles.position = Vector2(0, -36) + (Vector2(attack_direction) * i * 64)
			beam_particles.emitting = true
			
			# Remove particles after they finish
			var particle_timer = get_tree().create_timer(0.5)
			particle_timer.timeout.connect(func(): 
				if is_instance_valid(beam_particles):
					beam_particles.queue_free()
			)
	
	# Apply damage to hit entities
	for entity in hit_entities:
		var is_cloaked_scout = false
		# Check if it's a cloaked scout - we'll still damage them, but note that they're cloaked
		if entity is PlayerEntity and entity.has_method("is_visible_to_enemies") and not entity.is_visible_to_enemies():
			is_cloaked_scout = true
			print("BossEnemy: Beam attack found cloaked scout")
			
		entity.take_damage(beam_attack_damage)
		print("BossEnemy: Beam attack hit " + entity.entity_name + " for " + str(beam_attack_damage) + " damage")
		
		# Add hit effect at each entity's position
		if is_instance_valid(entity):
			var hit_particles = CPUParticles2D.new()
			add_child(hit_particles)
			hit_particles.amount = 30
			hit_particles.lifetime = 0.4
			hit_particles.one_shot = true
			hit_particles.explosiveness = 0.9
			hit_particles.direction = Vector2(0, 0)
			hit_particles.spread = 180.0
			hit_particles.gravity = Vector2.ZERO
			hit_particles.initial_velocity_min = 40.0
			hit_particles.initial_velocity_max = 80.0
			hit_particles.scale_amount_min = 3.0
			hit_particles.scale_amount_max = 5.0
			
			# Use special color for cloaked units being revealed
			if is_cloaked_scout:
				hit_particles.color = Color(1.0, 0.8, 0.2, 0.9) # Bright yellow to show cloak breaking
			else:
				hit_particles.color = Color(1, 0.1, 0.1, 0.8)
			
			# Position particles at the hit entity (use world coordinates)
			var world_pos = entity.global_position
			hit_particles.global_position = world_pos
			hit_particles.position.y -= 35  # Height offset to center on entity
			hit_particles.emitting = true
			
			# Remove particles after they finish
			var hit_timer = get_tree().create_timer(0.5)
			hit_timer.timeout.connect(func(): 
				if is_instance_valid(hit_particles):
					hit_particles.queue_free()
			)
	
	print("BossEnemy: Beam attack hit " + str(hit_entities.size()) + " entities") 
