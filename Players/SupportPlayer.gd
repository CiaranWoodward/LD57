class_name SupportPlayer
extends PlayerEntity

# Support-specific properties
var buff_strength: float = 1.2  # Multiplier for buff effects

func configure_player():
	entity_name = "Support"
	max_action_points = 3
	action_points = max_action_points
	move_speed = 0.9
	abilities = ["buff_ally", "debuff_enemy"]
	max_health = 10
	current_health = 10
	profile_tint = Color(0.3, 0.3, 0.8, 1.0)  # Bluish tint for Support

func get_ability_cost(ability_name: String) -> int:
	match ability_name:
		"buff_ally": return 1
		"debuff_enemy": return 1
		_: return super.get_ability_cost(ability_name)

func execute_ability(ability_name: String, target) -> bool:
	match ability_name:
		"buff_ally":
			# Buff ally increases an ally's effectiveness
			if target is PlayerEntity and target != self:
				# Apply buff effect
				if target.has_method("apply_status_effect"):
					# This would need to be implemented in PlayerEntity
					target.apply_status_effect("buffed", 2, buff_strength)  # 2 turn duration
					return true
				# Fallback if no status effect system
				elif target is PlayerEntity:
					# Give the target an extra action point
					target.action_points += 1
					return true
			return false
			
		"debuff_enemy":
			# Debuff enemy reduces its effectiveness
			if target is EnemyEntity:
				# Calculate success chance based on distance
				var distance = grid_position.distance_to(target.grid_position)
				if distance <= 5:  # Maximum range of 5 tiles
					# Apply debuff effect
					target.apply_status_effect("debuffed", 2)  # 2 turn duration
					return true
			return false
			
		_:
			return false

# Helper method to find allies in range
func get_allies_in_range(range_tiles: int) -> Array:
	var allies = []
	
	# Use the game_controller reference directly with assertion
	assert(game_controller != null, "SupportPlayer: " + entity_name + " - GameController reference not set")
	assert(game_controller is GameController, "SupportPlayer: " + entity_name + " - game_controller is not a GameController instance")
	
	for player in game_controller.player_entities:
		if player != self and grid_position.distance_to(player.grid_position) <= range_tiles:
			allies.append(player)
	
	return allies

# Support can provide passive benefits to nearby allies
func _process(delta):
	# This could be optimized to only run every few frames or on turn change
	var nearby_allies = get_allies_in_range(3)  # 3 tile radius
	
	# For a full implementation, you might apply small buffs to nearby allies
	# For now just a placeholder
	pass

# Override level up to focus on support abilities
func on_level_up():
	super.on_level_up()
	buff_strength += 0.1  # Increase buff effectiveness 
