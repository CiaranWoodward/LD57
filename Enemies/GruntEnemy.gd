class_name GruntEnemy
extends EnemyEntity

# Melee attack parameters
var melee_attack_damage: int = 2
var melee_attack_range: int = 1  # Attacks players in adjacent tiles
var attack_cooldown: int = 0  # Tracks turns since last attack

func _init():
	entity_name = "Grunt"
	entity_id = "grunt_" + str(randi())

func _ready():
	super._ready()
	enemy_type = EnemyType.GRUNT
	
	# Additional grunt-specific configuration
	move_speed = 0.8
	detection_range = 8
	aggression_level = 0.4
	max_health = 8
	current_health = 8
	
	xp_value = 20

# Override process_turn to check for melee attack opportunities
func process_turn(player_entities: Array):
	# Note: Freeze and status effect checks are handled in EnemyEntity.start_turn
	# If this method is being executed, the entity is not frozen or stunned
	
	# Reset movement
	is_moving = false
	path = []
	
	# Decrease attack cooldown if it's active
	if attack_cooldown > 0:
		attack_cooldown -= 1
	
	# Filter player entities to only include those on the same level
	var same_level_players = []
	for player in player_entities:
		if player.current_level == current_level:
			same_level_players.append(player)
	
	# Check for players in melee attack range
	if attack_cooldown == 0:  # Only attack if not on cooldown
		for player in same_level_players:
			var distance = grid_position.distance_to(player.grid_position)
			
			# If a player is within melee range, attack them
			if distance <= melee_attack_range:
				print("GruntEnemy: " + entity_name + " performing melee attack on " + player.entity_name)
				perform_melee_attack(player)
				attack_cooldown = 2  # Set cooldown to prevent attacking every turn
				return false  # No movement after attacking
	
	# If we didn't attack, use the standard enemy behavior
	return super.process_turn(player_entities)

# Perform a melee attack on the target entity
func perform_melee_attack(target_entity: Entity):
	if target_entity and !target_entity.is_dead:
		# Visual indication of attack (could be expanded with animations)
		modulate = Color(1.5, 0.3, 0.3, 1.0)  # Briefly flash red
		
		# Create a timer to reset the color
		var timer = get_tree().create_timer(0.2)
		timer.timeout.connect(func(): modulate = Color(1, 1, 1, 1))
		
		# Deal damage to the target
		target_entity.take_damage(melee_attack_damage)
		
		# Face the target
		var direction = target_entity.grid_position - grid_position
		update_facing_direction(Vector2(direction))
		
		print("GruntEnemy: " + entity_name + " dealt " + str(melee_attack_damage) + " damage to " + target_entity.entity_name)

# Override pursue_target to move to attack range but not into the player's tile
func pursue_target():
	# Only pursue if target is farther than melee range
	if target_entity and grid_position.distance_to(target_entity.grid_position) > melee_attack_range:
		super.pursue_target()
	else:
		# Already in range, don't move closer
		is_moving = false
		path = [] 
