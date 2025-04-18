class_name WizardPlayer
extends PlayerEntity

var fireball_range: int = 5  # Maximum range for fireball ability
var aoe_radius: int = 1      # Radius for area of effect (1 = 3x3 grid)
var hover_target: IsometricTile = null  # Track currently hovered target for AOE preview
var animation_tree: AnimationTree
var animation_state_machine: AnimationNodeStateMachinePlayback

func configure_player():
	entity_name = "Wizard"
	max_action_points = 4  # Heavy has more action points for abilities
	action_points = max_action_points
	max_movement_points = 2  # But limited movement
	movement_points = max_movement_points
	move_speed = 0.7
	abilities = ["drill", "fireball"]
	max_health = 15
	current_health = 15
	
	# Setup animation tree
	animation_tree = $Sprite2D/AnimationTree
	animation_tree.active = true
	animation_state_machine = animation_tree["parameters/playback"]

func get_ability_cost(ability_name: String) -> int:
	match ability_name:
		"fireball": return 3  # Fireball costs more than most abilities
		"healing_aoe": return 2
		"freeze_aoe": return 2
		"poison_aoe": return 2
		_: return super.get_ability_cost(ability_name)

# Override to provide specific descriptions for Wizard abilities
func get_ability_description(ability_name: String) -> String:
	var cost = get_ability_cost(ability_name)
	match ability_name:
		"fireball": 
			return "Fireball: Ranged AOE, up to " + str(fireball_range) + " tiles (Cost: " + str(cost) + " AP)"
		"healing_aoe":
			return "Healing Splash: AOE healing for allies (Cost: " + str(cost) + " AP)"
		"freeze_aoe":
			return "Freeze Zone: AOE that freezes enemies (Cost: " + str(cost) + " AP)"
		"poison_aoe":
			return "Poison Cloud: AOE poison damage over time (Cost: " + str(cost) + " AP)"
		_: 
			return super.get_ability_description(ability_name)

func execute_ability(ability_name: String, target) -> bool:
	if super.execute_ability(ability_name, target):
		return true
		
	match ability_name:
		"fireball":
			if target is IsometricTile:
				# Check if player has enough action points
				var cost = get_ability_cost("fireball")
				if action_points < cost:
					print("WizardPlayer: " + entity_name + " - Not enough action points for fireball")
					return false
				
				# Play cast animation
				animation_state_machine.travel("Cast")
				
				# Get target position and calculate direction
				var target_pos = target.grid_position
				var direction = target_pos - grid_position
				
				# Normalize direction to a unit vector
				if direction.x != 0: direction.x = sign(direction.x)
				if direction.y != 0: direction.y = sign(direction.y)
				
				print("WizardPlayer: " + entity_name + " firing fireball in direction " + str(direction))
				
				# Calculate the line of tiles in the direction, up to max range or until we hit a wall
				var current_pos = grid_position
				var distance = 0
				var impact_pos = null
				
				# We'll stop if we hit a wall or if we go beyond the maximum range
				while distance < fireball_range:
					# Move one step in the direction
					current_pos += Vector2i(direction)
					distance += 1
					
					# Get the tile at this position
					var current_tile = isometric_map.get_tile(current_pos)
					
					# If there's no tile or it's a wall, we impact at the last valid position
					if not current_tile or not current_tile.is_walkable:
						print("WizardPlayer: fireball hit a wall at " + str(current_pos))
						break
					
					# If this is the target tile, this is our impact position
					if current_tile.grid_position == target_pos:
						impact_pos = target_pos
						break
				
				# If we didn't find an impact position, the ability failed
				if not impact_pos:
					print("WizardPlayer: fireball failed - no valid impact position")
					return false
				
				# Fire a projectile to the impact position
				var projectile_spawner = $ProjectileSpawner
				if projectile_spawner and isometric_map:
					# Get the current tile and target tile
					var source_tile = isometric_map.get_tile(grid_position)
					var target_tile = isometric_map.get_tile(impact_pos)
					
					if source_tile and target_tile:
						# Spawn projectile between tiles
						var projectile = projectile_spawner.spawn_projectile_between_tiles(source_tile, target_tile)
						
						if projectile:
							# When the projectile reaches its target, create the explosion effect
							projectile.hit_target.connect(func():
								# Execute the explosion effect
								apply_fireball_explosion(impact_pos)
							)
							
							return true
				
				# Fallback if no projectile spawner - apply the damage directly
				apply_fireball_explosion(impact_pos)
				
				return true
			
			print("WizardPlayer: " + entity_name + " fireball failed - invalid target")
			return false
			
		"healing_aoe":
			if target is IsometricTile:
				# Play cast animation
				animation_state_machine.travel("Cast")
				
				# Apply healing effect in area around the target
				var affected_allies = apply_healing_aoe(target.grid_position)
				
				# Return true if we healed at least one ally
				return affected_allies > 0
			
			print("WizardPlayer: " + entity_name + " healing_aoe failed - invalid target")
			return false
			
		"freeze_aoe":
			if target is IsometricTile:
				# Play cast animation
				animation_state_machine.travel("Cast")
				
				# Apply freeze effect in area around the target
				var affected_enemies = apply_freeze_aoe(target.grid_position)
				
				# Return true if we froze at least one enemy
				return affected_enemies > 0
			
			print("WizardPlayer: " + entity_name + " freeze_aoe failed - invalid target")
			return false
			
		"poison_aoe":
			if target is IsometricTile:
				# Play cast animation
				animation_state_machine.travel("Cast")
				
				# Apply poison effect in area around the target
				var affected_enemies = apply_poison_aoe(target.grid_position)
				
				# Return true if we poisoned at least one enemy
				return affected_enemies > 0
			
			print("WizardPlayer: " + entity_name + " poison_aoe failed - invalid target")
			return false
			
		_:
			return false

# Helper function to apply fireball explosion and damage
func apply_fireball_explosion(impact_pos: Vector2i):
	# Calculate the area of effect
	var affected_entities = []
	
	# Create explosion particles at the impact position
	var impact_tile = isometric_map.get_tile(impact_pos)
	if impact_tile:
		var impact_world_pos = impact_tile.get_entity_position()
		
		# Get parent for the particles (prefer isometric_map)
		var particle_parent = null
		if isometric_map:
			particle_parent = isometric_map
		else:
			particle_parent = self
		
		# Create explosion particles
		var explosion = CPUParticles2D.new()
		particle_parent.add_child(explosion)
		
		# Configure explosion particles
		explosion.z_index = 1
		explosion.amount = 60
		explosion.lifetime = 0.6
		explosion.one_shot = true
		explosion.explosiveness = 0.9
		explosion.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		explosion.emission_sphere_radius = 10.0
		explosion.direction = Vector2(0, 0)
		explosion.spread = 180.0
		explosion.gravity = Vector2(0, 0)
		explosion.initial_velocity_min = 80.0
		explosion.initial_velocity_max = 150.0
		explosion.scale_amount_min = 4.0
		explosion.scale_amount_max = 8.0
		explosion.color = Color(1, 0.3, 0.1, 0.8)
		
		# Position explosion at impact point
		explosion.global_position = impact_world_pos
		explosion.position.y -= 35  # Height adjustment
		explosion.emitting = true
		
		# Remove explosion particles after they finish
		var timer = get_tree().create_timer(0.8)
		timer.timeout.connect(func(): 
			if is_instance_valid(explosion):
				explosion.queue_free()
		)
	
	# Loop through all tiles within radius of the impact position
	for x in range(-aoe_radius, aoe_radius + 1):
		for y in range(-aoe_radius, aoe_radius + 1):
			var aoe_pos = impact_pos + Vector2i(x, y)
			var aoe_tile = isometric_map.get_tile(aoe_pos)
			
			# If the tile exists and has an entity, damage it
			if aoe_tile and aoe_tile.is_occupied and aoe_tile.occupying_entity is Entity:
				var entity = aoe_tile.occupying_entity
				print("WizardPlayer: fireball hit entity " + entity.entity_name + " at " + str(aoe_pos))
				
				# Don't damage self (in case wizard is in the AOE)
				if entity != self:
					# Add to the list of affected entities
					affected_entities.append(entity)
					
					# Create hit particles at entity position
					var hit_pos = aoe_tile.get_entity_position()
					create_hit_effect(entity, hit_pos)
	
	# Apply damage to all affected entities (3 points of damage)
	for entity in affected_entities:
		entity.take_damage(3)
	
	print("WizardPlayer: fireball affected " + str(affected_entities.size()) + " entities")

# Create hit effect at the target position
func create_hit_effect(target_entity: Entity, position: Vector2):
	if is_instance_valid(target_entity):
		# Get parent for the particles (prefer isometric_map)
		var particle_parent = null
		if isometric_map:
			particle_parent = isometric_map
		else:
			particle_parent = self
		
		# Create hit particles
		var hit_particles = CPUParticles2D.new()
		particle_parent.add_child(hit_particles)
		
		# Configure hit particles
		hit_particles.z_index = 1
		hit_particles.amount = 20
		hit_particles.lifetime = 0.4
		hit_particles.one_shot = true
		hit_particles.explosiveness = 0.9
		hit_particles.direction = Vector2(0, 0)
		hit_particles.spread = 180.0
		hit_particles.gravity = Vector2.ZERO
		hit_particles.initial_velocity_min = 40.0
		hit_particles.initial_velocity_max = 80.0
		hit_particles.scale_amount_min = 2.0
		hit_particles.scale_amount_max = 4.0
		hit_particles.color = Color(1, 0.3, 0.1, 0.7)
		
		# Position particles
		hit_particles.global_position = position
		hit_particles.position.y -= 35  # Height offset to center on entity
		hit_particles.emitting = true
		
		# Remove particles after they finish
		var timer = get_tree().create_timer(0.5)
		timer.timeout.connect(func(): 
			if is_instance_valid(hit_particles):
				hit_particles.queue_free()
		)

# Helper to find nearby enemies
func get_nearby_enemies(radius: int) -> Array:
	var nearby = []
	
	# Use the game_controller reference directly with assertion
	assert(game_controller != null, "HeavyPlayer: " + entity_name + " - GameController reference not set")
	assert(game_controller is GameController, "HeavyPlayer: " + entity_name + " - game_controller is not a GameController instance")
	
	for enemy in game_controller.enemy_entities:
		if grid_position.distance_to(enemy.grid_position) <= radius:
			nearby.append(enemy)
	
	return nearby

# Highlight tiles that can be targeted with fireball
func highlight_fireball_targets():
	# Get the isometric map
	if not isometric_map:
		print("WizardPlayer: Cannot highlight fireball targets - isometric_map is null")
		return
		
	# Clear any existing highlights
	if game_controller:
		game_controller.clear_all_highlights()
	
	# Get the directions (cardinal)
	var directions = [
		Vector2(1, 0),   # Right
		Vector2(-1, 0),  # Left
		Vector2(0, 1),   # Down
		Vector2(0, -1),  # Up
	]
	
	var highlighted_count = 0
	print("WizardPlayer: Highlighting fireball targets from " + str(grid_position))
	
	# For each direction, trace a line until we hit a wall or max range
	for dir in directions:
		var current_pos = grid_position
		var distance = 0
		var path_tiles = []
		
		# Trace the line
		while distance < fireball_range:
			# Move one step in the direction
			current_pos += Vector2i(dir)
			distance += 1
			
			# Get the tile at this position
			var current_tile = isometric_map.get_tile(current_pos)
			
			# If there's no tile or it's a wall, stop
			if not current_tile or not current_tile.is_walkable:
				break
			
			# Add this tile to the path
			path_tiles.append(current_tile)
			
			# Set up hover signal connection for AOE preview
			if not current_tile.is_connected("tile_highlight_change", Callable(self, "_on_tile_highlight_change")):
				current_tile.connect("tile_highlight_change", Callable(self, "_on_tile_highlight_change"))
			
			# Mark this tile as a target
			current_tile.set_action_target(true)
			highlighted_count += 1
		
	print("WizardPlayer: Highlighted " + str(highlighted_count) + " fireball targets") 

# Handle tile highlight changes to show AOE preview
func _on_tile_highlight_change(tile: IsometricTile):
	# If hovering on a target tile, show AOE preview
	if tile.is_action_target and tile.is_hovered:
		# If we're already hovering a tile, clear its AOE preview first
		if hover_target != null and hover_target != tile:
			# Only clear if it's still action_target but not highlighted as AOE
			for x in range(-aoe_radius, aoe_radius + 1):
				for y in range(-aoe_radius, aoe_radius + 1):
					var prev_aoe_pos = hover_target.grid_position + Vector2i(x, y)
					var prev_aoe_tile = isometric_map.get_tile(prev_aoe_pos)
					
					# Don't modify the actual target tiles, only the AOE previews
					if prev_aoe_tile and prev_aoe_tile != hover_target and not prev_aoe_tile.is_action_target:
						prev_aoe_tile.set_attackable(false)
		
		# Set new hover target and show its AOE
		hover_target = tile
		highlight_fireball_aoe(tile.grid_position)
	
	# When no longer hovering a target tile, clear AOE preview
	elif hover_target == tile and not tile.is_hovered:
		# Clear AOE highlighting but leave target highlighting
		clear_fireball_aoe(tile.grid_position)
		
		hover_target = null

# Clear the AOE area highlighting around the targeted position
func clear_fireball_aoe(target_pos: Vector2i):
	if not isometric_map:
		return
		
	print("WizardPlayer: Clearing fireball AOE preview at " + str(target_pos))
	
	# Clear all tiles in AOE radius
	for x in range(-aoe_radius, aoe_radius + 1):
		for y in range(-aoe_radius, aoe_radius + 1):
			var aoe_pos = target_pos + Vector2i(x, y)
			var aoe_tile = isometric_map.get_tile(aoe_pos)
			
			# Only clear attackable on non-target tiles
			if aoe_tile and aoe_tile != hover_target and not aoe_tile.is_action_target:
				aoe_tile.set_attackable(false)

# Highlight the AOE area around the targeted position
func highlight_fireball_aoe(target_pos: Vector2i):
	if not isometric_map:
		return
		
	print("WizardPlayer: Showing fireball AOE preview at " + str(target_pos))
	
	# Highlight all tiles in AOE radius (including walls to show full blast area)
	for x in range(-aoe_radius, aoe_radius + 1):
		for y in range(-aoe_radius, aoe_radius + 1):
			var aoe_pos = target_pos + Vector2i(x, y)
			var aoe_tile = isometric_map.get_tile(aoe_pos)
			
			# Mark all tiles in the AOE range as attackable, except the target itself
			if aoe_tile and not aoe_tile.is_action_target:
				aoe_tile.set_attackable(true)

# Wizard gets more action points and occasionally increases fireball effects
func on_level_up():
	# Increase health and action points
	max_health += 2
	current_health += 2
	
	# Custom allocation favoring action points over movement
	max_action_points += 1
	if level % 2 == 0:  # Only every other level
		max_movement_points += 1 
		
	# Increase fireball range every other level
	if level % 2 == 0:
		fireball_range += 1

# Override to implement ability unlocking for Wizard class
func unlock_ability(ability_name: String) -> void:
	print("WizardPlayer: " + entity_name + " unlocking ability: " + ability_name)
	
	match ability_name:
		"healing_aoe":
			# Add a new healing splash ability to the player's abilities list
			print("WizardPlayer: Unlocked new healing_aoe ability")
			
			# Add the new ability if not already present
			if not abilities.has("healing_aoe"):
				abilities.append("healing_aoe")
			
			# Signal that abilities have changed
			emit_signal("ability_used")  # This will update the UI
			
		"freeze_aoe":
			# Add a new freeze zone ability to the player's abilities list
			print("WizardPlayer: Unlocked new freeze_aoe ability")
			
			# Add the new ability if not already present
			if not abilities.has("freeze_aoe"):
				abilities.append("freeze_aoe")
			
			# Signal that abilities have changed
			emit_signal("ability_used")  # This will update the UI
			
		"poison_aoe":
			# Add a new poison cloud ability to the player's abilities list
			print("WizardPlayer: Unlocked new poison_aoe ability")
			
			# Add the new ability if not already present
			if not abilities.has("poison_aoe"):
				abilities.append("poison_aoe")
			
			# Signal that abilities have changed
			emit_signal("ability_used")  # This will update the UI

# Highlight tiles that can be targeted with healing AOE
func highlight_healing_aoe_targets():
	highlight_aoe_targets()  # Use the same targeting logic as fireball

# Highlight tiles that can be targeted with freeze or poison AOE
func highlight_offensive_aoe_targets():
	highlight_aoe_targets()  # Use the same targeting logic as fireball

# Generic helper to highlight potential AOE ability targets (now using the same logic as fireball)
func highlight_aoe_targets():
	# Get the isometric map
	if not isometric_map:
		print("WizardPlayer: Cannot highlight AOE targets - isometric_map is null")
		return
		
	# Clear any existing highlights
	if game_controller:
		game_controller.clear_all_highlights()
	
	# Get the directions (cardinal)
	var directions = [
		Vector2(1, 0),   # Right
		Vector2(-1, 0),  # Left
		Vector2(0, 1),   # Down
		Vector2(0, -1),  # Up
	]
	
	var highlighted_count = 0
	print("WizardPlayer: Highlighting AOE targets from " + str(grid_position))
	
	# For each direction, trace a line until we hit a wall or max range
	for dir in directions:
		var current_pos = grid_position
		var distance = 0
		var path_tiles = []
		
		# Trace the line
		while distance < fireball_range:
			# Move one step in the direction
			current_pos += Vector2i(dir)
			distance += 1
			
			# Get the tile at this position
			var current_tile = isometric_map.get_tile(current_pos)
			
			# If there's no tile or it's a wall, stop
			if not current_tile or not current_tile.is_walkable:
				break
			
			# Add this tile to the path
			path_tiles.append(current_tile)
			
			# Set up hover signal connection for AOE preview
			if not current_tile.is_connected("tile_highlight_change", Callable(self, "_on_tile_highlight_change")):
				current_tile.connect("tile_highlight_change", Callable(self, "_on_tile_highlight_change"))
			
			# Mark this tile as a target
			current_tile.set_action_target(true)
			highlighted_count += 1
		
	print("WizardPlayer: Highlighted " + str(highlighted_count) + " AOE targets") 

# Helper function to apply healing AOE - now using fireball-like targeting
func apply_healing_aoe(target_pos: Vector2i) -> int:
	# Calculate the area of effect
	var affected_entities = []
	
	# Create healing particles at the impact position
	var impact_tile = isometric_map.get_tile(target_pos)
	if impact_tile:
		var impact_world_pos = impact_tile.get_entity_position()
		
		# Get parent for the particles (prefer isometric_map)
		var particle_parent = null
		if isometric_map:
			particle_parent = isometric_map
		else:
			particle_parent = self
		
		# Create healing particles
		var healing = CPUParticles2D.new()
		particle_parent.add_child(healing)
		
		# Configure healing particles
		healing.z_index = 1
		healing.amount = 60
		healing.lifetime = 0.8
		healing.one_shot = true
		healing.explosiveness = 0.8
		healing.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		healing.emission_sphere_radius = 12.0
		healing.direction = Vector2(0, -1)
		healing.spread = 90.0
		healing.gravity = Vector2(0, -20)
		healing.initial_velocity_min = 30.0
		healing.initial_velocity_max = 60.0
		healing.scale_amount_min = 3.0
		healing.scale_amount_max = 6.0
		healing.color = Color(0.3, 1.0, 0.4, 0.8)
		
		# Position healing at impact point
		healing.global_position = impact_world_pos
		healing.position.y -= 20  # Height adjustment
		healing.emitting = true
		
		# Remove healing particles after they finish
		var timer = get_tree().create_timer(1.0)
		timer.timeout.connect(func(): 
			if is_instance_valid(healing):
				healing.queue_free()
		)
	
	# Loop through all tiles within radius of the impact position
	for x in range(-aoe_radius, aoe_radius + 1):
		for y in range(-aoe_radius, aoe_radius + 1):
			var aoe_pos = target_pos + Vector2i(x, y)
			var aoe_tile = isometric_map.get_tile(aoe_pos)
			
			# If the tile exists and has an entity, heal it
			if aoe_tile and aoe_tile.is_occupied and aoe_tile.occupying_entity is Entity:
				var entity = aoe_tile.occupying_entity
				
				# Heal any entity except self (change from healing only allies)
				if entity != self:
					print("WizardPlayer: healing_aoe healed entity " + entity.entity_name + " at " + str(aoe_pos))
					
					# Heal the entity (3 points of healing)
					entity.heal_damage(3)
					affected_entities.append(entity)
					
					# Create healing effect at entity position
					var heal_pos = aoe_tile.get_entity_position()
					create_healing_effect(entity, heal_pos)
	
	print("WizardPlayer: healing_aoe affected " + str(affected_entities.size()) + " entities")
	return affected_entities.size()

# Helper function to apply freeze AOE - now using fireball-like targeting
func apply_freeze_aoe(target_pos: Vector2i) -> int:
	# Calculate the area of effect
	var affected_entities = []
	
	# Create freeze particles at the impact position
	var impact_tile = isometric_map.get_tile(target_pos)
	if impact_tile:
		var impact_world_pos = impact_tile.get_entity_position()
		
		# Get parent for the particles (prefer isometric_map)
		var particle_parent = null
		if isometric_map:
			particle_parent = isometric_map
		else:
			particle_parent = self
		
		# Create freeze particles
		var freeze = CPUParticles2D.new()
		particle_parent.add_child(freeze)
		
		# Configure freeze particles - make them more icy looking
		freeze.z_index = 1
		freeze.amount = 25
		freeze.lifetime = 0.7
		freeze.one_shot = true
		freeze.explosiveness = 0.8
		freeze.direction = Vector2(0, 0)
		freeze.spread = 180.0
		freeze.gravity = Vector2(0, 0)
		freeze.initial_velocity_min = 10.0
		freeze.initial_velocity_max = 30.0
		freeze.scale_amount_min = 3.0
		freeze.scale_amount_max = 6.0
		freeze.color = Color(0.2, 0.6, 1.0, 0.8)  # Brighter blue
		
		# Position particles
		freeze.global_position = impact_world_pos
		freeze.position.y -= 35  # Height offset to center on entity
		freeze.emitting = true
		
		# Create ice crystal decorations around the entity
		for i in range(4):
			var ice_shard = CPUParticles2D.new()
			particle_parent.add_child(ice_shard)
			
			# Configure ice shards
			ice_shard.z_index = 1
			ice_shard.amount = 1
			ice_shard.lifetime = 2.0
			ice_shard.one_shot = true
			ice_shard.emitting = true
			ice_shard.explosiveness = 1.0
			ice_shard.direction = Vector2(0, 0)
			ice_shard.gravity = Vector2(0, 0)
			ice_shard.initial_velocity_min = 0
			ice_shard.initial_velocity_max = 0
			ice_shard.scale_amount_min = 8.0
			ice_shard.scale_amount_max = 12.0
			ice_shard.color = Color(0.6, 0.9, 1.0, 0.7)  # Light blue
			
			# Position ice shards around entity
			var angle = i * PI/2  # Evenly spaced around entity
			var offset = Vector2(cos(angle), sin(angle)) * 25
			ice_shard.global_position = position + offset
			ice_shard.position.y -= 20  # Height offset
			
			# Remove shards after they finish
			var shard_timer = get_tree().create_timer(2.1)
			shard_timer.timeout.connect(func():
				if is_instance_valid(ice_shard):
					ice_shard.queue_free()
			)
		
		# Visually freeze the entity - this is now handled by the entity's apply_status_effect method
		
		# Remove particles after they finish
		var timer = get_tree().create_timer(0.8)
		timer.timeout.connect(func(): 
			if is_instance_valid(freeze):
				freeze.queue_free()
		)
	
	# Loop through all tiles within radius of the impact position
	for x in range(-aoe_radius, aoe_radius + 1):
		for y in range(-aoe_radius, aoe_radius + 1):
			var aoe_pos = target_pos + Vector2i(x, y)
			var aoe_tile = isometric_map.get_tile(aoe_pos)
			
			# If the tile exists and has an entity, apply freeze to it
			if aoe_tile and aoe_tile.is_occupied and aoe_tile.occupying_entity is Entity:
				var entity = aoe_tile.occupying_entity
				
				# Apply to any entity except self
				if entity != self:
					print("WizardPlayer: freeze_aoe froze entity " + entity.entity_name + " at " + str(aoe_pos))
					
					# Deal 1 damage and apply freeze effect
					entity.take_damage(1)
					
					# Apply freezing effect for 2 turns - entity will be unable to move or act
					if entity.has_method("apply_status_effect"):
						entity.apply_status_effect("freeze", 2) # Apply freeze for 2 turns
					else:
						print("WizardPlayer: entity doesn't support status effects")
					
					affected_entities.append(entity)
					
					# Create freeze effect at entity position
					var freeze_pos = aoe_tile.get_entity_position()
					create_freeze_effect(entity, freeze_pos)
	
	print("WizardPlayer: freeze_aoe affected " + str(affected_entities.size()) + " entities")
	return affected_entities.size()

# Helper function to apply poison AOE - now using fireball-like targeting
func apply_poison_aoe(target_pos: Vector2i) -> int:
	# Calculate the area of effect
	var affected_entities = []
	
	# Create poison particles at the impact position
	var impact_tile = isometric_map.get_tile(target_pos)
	if impact_tile:
		var impact_world_pos = impact_tile.get_entity_position()
		
		# Get parent for the particles (prefer isometric_map)
		var particle_parent = null
		if isometric_map:
			particle_parent = isometric_map
		else:
			particle_parent = self
		
		# Create poison particles
		var poison = CPUParticles2D.new()
		particle_parent.add_child(poison)
		
		# Configure poison particles
		poison.z_index = 1
		poison.amount = 80
		poison.lifetime = 1.0
		poison.one_shot = true
		poison.explosiveness = 0.7
		poison.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		poison.emission_sphere_radius = 12.0
		poison.direction = Vector2(0, -1)
		poison.spread = 180.0
		poison.gravity = Vector2(0, -5)
		poison.initial_velocity_min = 30.0
		poison.initial_velocity_max = 50.0
		poison.scale_amount_min = 4.0
		poison.scale_amount_max = 7.0
		poison.color = Color(0.5, 0.8, 0.2, 0.8)
		
		# Position poison at impact point
		poison.global_position = impact_world_pos
		poison.position.y -= 20  # Height adjustment
		poison.emitting = true
		
		# Remove poison particles after they finish
		var timer = get_tree().create_timer(1.2)
		timer.timeout.connect(func(): 
			if is_instance_valid(poison):
				poison.queue_free()
		)
	
	# Loop through all tiles within radius of the impact position
	for x in range(-aoe_radius, aoe_radius + 1):
		for y in range(-aoe_radius, aoe_radius + 1):
			var aoe_pos = target_pos + Vector2i(x, y)
			var aoe_tile = isometric_map.get_tile(aoe_pos)
			
			# If the tile exists and has an entity, apply poison to it
			if aoe_tile and aoe_tile.is_occupied and aoe_tile.occupying_entity is Entity:
				var entity = aoe_tile.occupying_entity
				
				# Apply to any entity except self
				if entity != self:
					print("WizardPlayer: poison_aoe poisoned entity " + entity.entity_name + " at " + str(aoe_pos))
					
					# Apply poison effect (damage over time) for 2 turns
					if entity.has_method("apply_status_effect"):
						entity.apply_status_effect("poison", 2, 2.0) # 2 turns of poison with 2 damage per turn
					else:
						# Fallback if entity doesn't support effects - just do direct damage
						entity.take_damage(2)
					
					affected_entities.append(entity)
					
					# Create poison effect at entity position
					var poison_pos = aoe_tile.get_entity_position()
					create_poison_effect(entity, poison_pos)
	
	print("WizardPlayer: poison_aoe affected " + str(affected_entities.size()) + " entities")
	return affected_entities.size()

# Create healing effect at the target position
func create_healing_effect(target_entity: Entity, position: Vector2):
	if is_instance_valid(target_entity):
		# Get parent for the particles (prefer isometric_map)
		var particle_parent = null
		if isometric_map:
			particle_parent = isometric_map
		else:
			particle_parent = self
		
		# Create healing particles
		var healing_particles = CPUParticles2D.new()
		particle_parent.add_child(healing_particles)
		
		# Configure healing particles
		healing_particles.z_index = 1
		healing_particles.amount = 15
		healing_particles.lifetime = 0.5
		healing_particles.one_shot = true
		healing_particles.explosiveness = 0.8
		healing_particles.direction = Vector2(0, -1)
		healing_particles.spread = 60.0
		healing_particles.gravity = Vector2(0, -40)
		healing_particles.initial_velocity_min = 20.0
		healing_particles.initial_velocity_max = 40.0
		healing_particles.scale_amount_min = 2.0
		healing_particles.scale_amount_max = 4.0
		healing_particles.color = Color(0.3, 1.0, 0.4, 0.7)
		
		# Position particles
		healing_particles.global_position = position
		healing_particles.position.y -= 35  # Height offset to center on entity
		healing_particles.emitting = true
		
		# Remove particles after they finish
		var timer = get_tree().create_timer(0.6)
		timer.timeout.connect(func(): 
			if is_instance_valid(healing_particles):
				healing_particles.queue_free()
		)

# Create freeze effect at the target position
func create_freeze_effect(target_entity: Entity, position: Vector2):
	if is_instance_valid(target_entity):
		# Get parent for the particles (prefer isometric_map)
		var particle_parent = null
		if isometric_map:
			particle_parent = isometric_map
		else:
			particle_parent = self
		
		# Create freeze particles
		var freeze_particles = CPUParticles2D.new()
		particle_parent.add_child(freeze_particles)
		
		# Configure freeze particles - make them more icy looking
		freeze_particles.z_index = 1
		freeze_particles.amount = 25
		freeze_particles.lifetime = 0.7
		freeze_particles.one_shot = true
		freeze_particles.explosiveness = 0.8
		freeze_particles.direction = Vector2(0, 0)
		freeze_particles.spread = 180.0
		freeze_particles.gravity = Vector2(0, 0)
		freeze_particles.initial_velocity_min = 10.0
		freeze_particles.initial_velocity_max = 30.0
		freeze_particles.scale_amount_min = 3.0
		freeze_particles.scale_amount_max = 6.0
		freeze_particles.color = Color(0.2, 0.6, 1.0, 0.8)  # Brighter blue
		
		# Position particles
		freeze_particles.global_position = position
		freeze_particles.position.y -= 35  # Height offset to center on entity
		freeze_particles.emitting = true
		
		# Create ice crystal decorations around the entity
		for i in range(4):
			var ice_shard = CPUParticles2D.new()
			particle_parent.add_child(ice_shard)
			
			# Configure ice shards
			ice_shard.z_index = 1
			ice_shard.amount = 1
			ice_shard.lifetime = 2.0
			ice_shard.one_shot = true
			ice_shard.emitting = true
			ice_shard.explosiveness = 1.0
			ice_shard.direction = Vector2(0, 0)
			ice_shard.gravity = Vector2(0, 0)
			ice_shard.initial_velocity_min = 0
			ice_shard.initial_velocity_max = 0
			ice_shard.scale_amount_min = 8.0
			ice_shard.scale_amount_max = 12.0
			ice_shard.color = Color(0.6, 0.9, 1.0, 0.7)  # Light blue
			
			# Position ice shards around entity
			var angle = i * PI/2  # Evenly spaced around entity
			var offset = Vector2(cos(angle), sin(angle)) * 25
			ice_shard.global_position = position + offset
			ice_shard.position.y -= 20  # Height offset
			
			# Remove shards after they finish
			var shard_timer = get_tree().create_timer(2.1)
			shard_timer.timeout.connect(func():
				if is_instance_valid(ice_shard):
					ice_shard.queue_free()
			)
		
		# Visually freeze the entity - this is now handled by the entity's apply_status_effect method
		
		# Remove particles after they finish
		var timer = get_tree().create_timer(0.8)
		timer.timeout.connect(func(): 
			if is_instance_valid(freeze_particles):
				freeze_particles.queue_free()
		)

# Create poison effect at the target position
func create_poison_effect(target_entity: Entity, position: Vector2):
	if is_instance_valid(target_entity):
		# Get parent for the particles (prefer isometric_map)
		var particle_parent = null
		if isometric_map:
			particle_parent = isometric_map
		else:
			particle_parent = self
		
		# Create poison particles for the initial hit
		var poison_particles = CPUParticles2D.new()
		particle_parent.add_child(poison_particles)
		
		# Configure poison particles - make them more toxic looking
		poison_particles.z_index = 1
		poison_particles.amount = 30
		poison_particles.lifetime = 0.8
		poison_particles.one_shot = true
		poison_particles.explosiveness = 0.9
		poison_particles.direction = Vector2(0, -1)
		poison_particles.spread = 120.0
		poison_particles.gravity = Vector2(0, -20)
		poison_particles.initial_velocity_min = 30.0
		poison_particles.initial_velocity_max = 60.0
		poison_particles.scale_amount_min = 3.0
		poison_particles.scale_amount_max = 6.0
		poison_particles.color = Color(0.5, 0.9, 0.2, 0.8)  # Bright toxic green
		
		# Position particles
		poison_particles.global_position = position
		poison_particles.position.y -= 35  # Height offset to center on entity
		poison_particles.emitting = true
		
		# Create skull emblem for a more dramatic effect
		var skull_particles = CPUParticles2D.new()
		particle_parent.add_child(skull_particles)
		
		# Configure skull particles
		skull_particles.z_index = 2
		skull_particles.amount = 1
		skull_particles.lifetime = 1.0
		skull_particles.one_shot = true
		skull_particles.explosiveness = 1.0
		skull_particles.direction = Vector2(0, -1)
		skull_particles.gravity = Vector2(0, -40)
		skull_particles.initial_velocity_min = 0.0
		skull_particles.initial_velocity_max = 0.0
		skull_particles.scale_amount_min = 15.0
		skull_particles.scale_amount_max = 15.0
		skull_particles.color = Color(0.3, 0.8, 0.1, 0.6)  # Greenish
		
		# Position skull
		skull_particles.global_position = position
		skull_particles.position.y -= 60  # Higher than the poison cloud
		skull_particles.emitting = true
		
		# Remove particles after they finish
		var timer = get_tree().create_timer(1.2)
		timer.timeout.connect(func(): 
			if is_instance_valid(poison_particles):
				poison_particles.queue_free()
			if is_instance_valid(skull_particles):
				skull_particles.queue_free()
		)
