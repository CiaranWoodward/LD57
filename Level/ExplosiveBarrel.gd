class_name ExplosiveBarrel
extends BaseBombEnemy

func _init():
	entity_name = "Explosive Barrel"
	entity_id = "barrel_" + str(randi())

func _ready():
	super._ready()
	
	# Set the correct enemy type
	enemy_type = EnemyType.EXPLOSIVE_BARREL
	
	# Static configuration
	move_speed = 0.0  # Cannot move
	detection_range = 0  # Doesn't detect players
	aggression_level = 0.0  # No aggression
	max_health = 8
	current_health = 8
	
	# Explosion configuration
	explosion_radius = 2  # Larger explosion radius than bomb
	explosion_damage = 8  # More damage than regular bombs
	
	xp_value = 20

# Override process_turn to do nothing (barrels don't take actions)
func process_turn(player_entities: Array):
	# Static barrels don't move or take any actions
	return false

# Override pursue_target to do nothing (barrels don't move)
func pursue_target():
	# Do nothing - barrels don't move
	pass

# Override follow_patrol_path to do nothing (barrels don't patrol)
func follow_patrol_path():
	# Do nothing - barrels don't move
	pass

# Override take_damage to trigger explosion when damaged past a threshold
func take_damage(damage_amount: int) -> void:
	# First, apply damage normally
	super.take_damage(damage_amount)
	
	# Check if we should explode
	if current_health <= max_health / 2 and not has_exploded:
		print("ExplosiveBarrel: " + entity_name + " damaged and unstable!")
		modulate = Color(1.5, 0.8, 0.3, 1.0)  # Turn orange as warning
		
		# If health is very low, explode immediately
		if current_health <= 2:
			explode()
		# Otherwise, set a timer for delayed explosion
		else:
			var timer = get_tree().create_timer(1.0)
			timer.timeout.connect(func(): 
				if not has_exploded and not is_dead:
					explode()
			)

# Return the entity type for better debugging
func get_bomb_type() -> String:
	return "ExplosiveBarrel" 