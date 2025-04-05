class_name MedicPlayer
extends PlayerEntity

# Medic-specific properties
var healing_power: int = 2  # Base healing amount
var revive_range: int = 3   # Range for revive ability

func configure_player():
	entity_name = "Medic"
	max_action_points = 3
	action_points = max_action_points
	move_speed = 1.0
	abilities = ["heal", "revive"]
	max_health = 9
	current_health = 9

func get_ability_cost(ability_name: String) -> int:
	match ability_name:
		"heal": return 1
		"revive": return 2
		_: return super.get_ability_cost(ability_name)

func execute_ability(ability_name: String, target) -> bool:
	match ability_name:
		"heal":
			# Heal restores health to an ally
			if target is PlayerEntity:
				var distance = grid_position.distance_to(target.grid_position)
				if distance <= 4:  # Maximum range of 4 tiles
					# Apply healing effect
					target.heal_damage(healing_power)
					return true
			return false
			
		"revive":
			# Revive can bring back a defeated ally or give significant bonuses
			if target is PlayerEntity:
				var distance = grid_position.distance_to(target.grid_position)
				if distance <= revive_range:
					# If the target is defeated
					if target.is_defeated():
						target.revive(healing_power * 2)  # Bonus healing on revive
						return true
					# If not defeated, give a significant boost
					else:
						# Restore all action points
						target.action_points = target.max_action_points
						# Apply a protection status effect
						target.apply_status_effect("protected", 2)  # 2 turn protection
						return true
			return false
			
		_:
			return false

# Helper method to find allies in range
func get_allies_in_range(range_tiles: int) -> Array:
	var allies = []
	
	# Use the game_controller reference directly with assertion
	assert(game_controller != null, "MedicPlayer: " + entity_name + " - GameController reference not set")
	assert(game_controller is GameController, "MedicPlayer: " + entity_name + " - game_controller is not a GameController instance")
	
	for player in game_controller.player_entities:
		if player != self and grid_position.distance_to(player.grid_position) <= range_tiles:
			allies.append(player)
	
	return allies

# Override level up to focus on healing capabilities
func on_level_up():
	super.on_level_up()
	healing_power += 1  # Increase healing power
	if level % 3 == 0:  # Every 3 levels
		revive_range += 1  # Increase revive range 
