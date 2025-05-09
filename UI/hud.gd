extends CanvasLayer
class_name HUD

signal PauseMenu
signal UpgradeMenu
signal DrillButtonHovered(player)
signal DrillButtonUnhovered
signal DrillSmashButtonHovered(player)
signal DrillSmashButtonUnhovered
signal LineShotButtonHovered(player)
signal LineShotButtonUnhovered
signal FireballButtonHovered(player)
signal FireballButtonUnhovered
signal BigDrillButtonHovered(player)
signal BigDrillButtonUnhovered
signal CloakButtonHovered(player)
signal CloakButtonUnhovered
signal DefendButtonHovered(player)
signal DefendButtonUnhovered
signal ChargeAttackButtonHovered(player)
signal ChargeAttackButtonUnhovered
signal EmergencyTeleportButtonHovered(player)
signal EmergencyTeleportButtonUnhovered
signal HealingAOEButtonHovered(player)
signal HealingAOEButtonUnhovered
signal FreezeAOEButtonHovered(player)
signal FreezeAOEButtonUnhovered
signal PoisonAOEButtonHovered(player)
signal PoisonAOEButtonUnhovered

# Reference to the current active player
var current_player: PlayerEntity = null

# Drilling visualization
var is_hovering_drill_button: bool = false
var is_hovering_drill_smash_button: bool = false
var is_hovering_line_shot_button: bool = false
var is_hovering_fireball_button: bool = false
var is_hovering_cloak_button: bool = false
var is_hovering_charge_attack_button: bool = false
var is_hovering_emergency_teleport_button: bool = false
var is_hovering_healing_aoe_button: bool = false
var is_hovering_freeze_aoe_button: bool = false
var is_hovering_poison_aoe_button: bool = false

func _ready() -> void:
	Global.hud = self
	
	# Initialize with current XP value
	update_xp_counter(Global.xp)
	
	# Initialize the upgrade button with a default disabled state
	# Will be properly updated once connected to the GameController
	set_upgrade_button_enabled(false)
	
	# Set up input processing for right-click and escape
	set_process_input(true)
	
	# Connect action buttons
	var action_drill = $Action/ActionMargin/ActionHBox/ActionDrill
	if action_drill:
		action_drill.gui_input.connect(_on_action_drill_input)
		# Connect to mouse enter/exit for hover detection
		action_drill.mouse_entered.connect(_on_action_drill_mouse_entered)
		action_drill.mouse_exited.connect(_on_action_drill_mouse_exited)
		# Set default tooltip
		action_drill.tooltip_text = "Drill"
	
	# Connect drill smash button
	var action_drill_smash = $Action/ActionMargin/ActionHBox/ActionDrillSmash
	if action_drill_smash:
		action_drill_smash.gui_input.connect(_on_action_drill_smash_input)
		# Connect to mouse enter/exit for hover detection
		action_drill_smash.mouse_entered.connect(_on_action_drill_smash_mouse_entered)
		action_drill_smash.mouse_exited.connect(_on_action_drill_smash_mouse_exited)
		# Set default tooltip
		action_drill_smash.tooltip_text = "Drill Smash"
	
	# Connect line shot button
	var action_line_shot = $Action/ActionMargin/ActionHBox/ActionLineShot
	if action_line_shot:
		action_line_shot.gui_input.connect(_on_action_line_shot_input)
		# Connect to mouse enter/exit for hover detection
		action_line_shot.mouse_entered.connect(_on_action_line_shot_mouse_entered)
		action_line_shot.mouse_exited.connect(_on_action_line_shot_mouse_exited)
		# Set default tooltip
		action_line_shot.tooltip_text = "Line Shot"
	
	# Connect fireball button
	var action_fireball = $Action/ActionMargin/ActionHBox/ActionFireball
	if action_fireball:
		action_fireball.gui_input.connect(_on_action_fireball_input)
		# Connect to mouse enter/exit for hover detection
		action_fireball.mouse_entered.connect(_on_action_fireball_mouse_entered)
		action_fireball.mouse_exited.connect(_on_action_fireball_mouse_exited)
		# Set default tooltip
		action_fireball.tooltip_text = "Fireball"
		
	# Connect cloak button
	var action_cloak = $Action/ActionMargin/ActionHBox/ActionCloak
	if action_cloak:
		action_cloak.gui_input.connect(_on_action_cloak_input)
		# Connect to mouse enter/exit for hover detection
		action_cloak.mouse_entered.connect(_on_action_cloak_mouse_entered)
		action_cloak.mouse_exited.connect(_on_action_cloak_mouse_exited)
		# Set default tooltip
		action_cloak.tooltip_text = "Cloak"
		
	# Connect big drill button
	var action_big_drill = $Action/ActionMargin/ActionHBox/ActionBigDrill
	if action_big_drill:
		action_big_drill.gui_input.connect(_on_action_big_drill_input)
		# Connect to mouse enter/exit for hover detection
		action_big_drill.mouse_entered.connect(_on_big_drill_button_hovered)
		action_big_drill.mouse_exited.connect(_on_big_drill_button_unhovered)
		# Set default tooltip
		action_big_drill.tooltip_text = "Big Drill"
	
	# Connect defend button
	var action_defend = $Action/ActionMargin/ActionHBox/ActionDefend
	if action_defend:
		action_defend.gui_input.connect(_on_action_defend_input)
		# Connect to mouse enter/exit for hover detection
		action_defend.mouse_entered.connect(_on_defend_button_mouse_entered)
		action_defend.mouse_exited.connect(_on_defend_button_mouse_exited)
		# Set default tooltip
		action_defend.tooltip_text = "Defend"
		
	# Connect charge attack button
	var action_charge_attack = $Action/ActionMargin/ActionHBox/ActionChargeAttack
	if action_charge_attack:
		action_charge_attack.gui_input.connect(_on_action_charge_attack_input)
		# Connect to mouse enter/exit for hover detection
		action_charge_attack.mouse_entered.connect(_on_action_charge_attack_mouse_entered)
		action_charge_attack.mouse_exited.connect(_on_action_charge_attack_mouse_exited)
		# Set default tooltip
		action_charge_attack.tooltip_text = "Charge Attack"
		
	# Connect emergency teleport button
	var action_emergency_teleport = $Action/ActionMargin/ActionHBox/ActionEmergencyTeleport
	if action_emergency_teleport:
		action_emergency_teleport.gui_input.connect(_on_action_emergency_teleport_input)
		# Connect to mouse enter/exit for hover detection
		action_emergency_teleport.mouse_entered.connect(_on_action_emergency_teleport_mouse_entered)
		action_emergency_teleport.mouse_exited.connect(_on_action_emergency_teleport_mouse_exited)
		# Set default tooltip
		action_emergency_teleport.tooltip_text = "Emergency Teleport"
		
	# Connect healing AOE button
	var action_healing_aoe = $Action/ActionMargin/ActionHBox/ActionHealingAOE
	if action_healing_aoe:
		action_healing_aoe.gui_input.connect(_on_action_healing_aoe_input)
		# Connect to mouse enter/exit for hover detection
		action_healing_aoe.mouse_entered.connect(_on_action_healing_aoe_mouse_entered)
		action_healing_aoe.mouse_exited.connect(_on_action_healing_aoe_mouse_exited)
		# Set default tooltip
		action_healing_aoe.tooltip_text = "Healing Splash"
		
	# Connect freeze AOE button
	var action_freeze_aoe = $Action/ActionMargin/ActionHBox/ActionFreezeAOE
	if action_freeze_aoe:
		action_freeze_aoe.gui_input.connect(_on_action_freeze_aoe_input)
		# Connect to mouse enter/exit for hover detection
		action_freeze_aoe.mouse_entered.connect(_on_action_freeze_aoe_mouse_entered)
		action_freeze_aoe.mouse_exited.connect(_on_action_freeze_aoe_mouse_exited)
		# Set default tooltip
		action_freeze_aoe.tooltip_text = "Freeze Zone"
		
	# Connect poison AOE button
	var action_poison_aoe = $Action/ActionMargin/ActionHBox/ActionPoisonAOE
	if action_poison_aoe:
		action_poison_aoe.gui_input.connect(_on_action_poison_aoe_input)
		# Connect to mouse enter/exit for hover detection
		action_poison_aoe.mouse_entered.connect(_on_action_poison_aoe_mouse_entered)
		action_poison_aoe.mouse_exited.connect(_on_action_poison_aoe_mouse_exited)
		# Set default tooltip
		action_poison_aoe.tooltip_text = "Poison Cloud"
		
	# Connect XP signal
	Global.xp_changed.connect(update_xp_counter)
	
	# End turn button
	var end_button = $End/EndMargin/EndButton
	if end_button:
		end_button.pressed.connect(_on_end_button_pressed)
	
	# Connect menu buttons
	$MenuMargin/HBoxContainer/ButtonMenu.pressed.connect(_on_button_menu_pressed)
	$MenuMargin/HBoxContainer/ButtonUpgrade.pressed.connect(_on_button_upgrade_pressed)
	
	# Connect to the game controller for better synchronization
	# We'll do this with a timer to ensure the game controller is fully initialized
	var init_timer = Timer.new()
	init_timer.wait_time = 0.5
	init_timer.one_shot = true
	init_timer.timeout.connect(_connect_to_game_controller)
	add_child(init_timer)
	init_timer.start()

# Connect to the game controller signals
func _connect_to_game_controller() -> void:
	var game_controller = get_node("/root").find_child("GameController", true, false)
	if game_controller:
		print("HUD: Connected to GameController signals")
		
		# Connect to any current_ability changes
		if not game_controller.is_connected("player_activated", Callable(self, "_on_game_controller_player_activated")):
			game_controller.connect("player_activated", _on_game_controller_player_activated)
		
		# Update our buttons immediately
		update_action_buttons()

# Called when the game controller activates a player
func _on_game_controller_player_activated(player) -> void:
	# This function gets called when the GameController activates a player
	# We already handle this through set_active_player normally, but this 
	# provides an extra update to ensure things are in sync
	update_action_buttons()

func _on_button_menu_pressed() -> void:
	PauseMenu.emit()
	
func _on_button_upgrade_pressed() -> void:
	UpgradeMenu.emit()

# Enable or disable the upgrade button based on whether there are enemies on the current level
func set_upgrade_button_enabled(enabled: bool) -> void:
	var upgrade_button = $MenuMargin/HBoxContainer/ButtonUpgrade
	if upgrade_button:
		upgrade_button.disabled = !enabled
		# Make the button semi-transparent when disabled
		if enabled:
			upgrade_button.modulate = Color(1, 1, 1, 1)  # Fully visible
			upgrade_button.tooltip_text = "Upgrade"
			
			# Enable the glow effect
			var glow_effect = upgrade_button.get_node("GlowEffect")
			if glow_effect:
				glow_effect.emitting = true
		else:
			upgrade_button.modulate = Color(1, 1, 1, 0.5)  # Semi-transparent
			upgrade_button.tooltip_text = "Clear all enemies on this level to upgrade"
			
			# Disable the glow effect
			var glow_effect = upgrade_button.get_node("GlowEffect")
			if glow_effect:
				glow_effect.emitting = false

# Handle clicking on the drill action button
func _on_action_drill_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var action_drill = $Action/ActionMargin/ActionHBox/ActionDrill
		# If button is disabled, don't process the click
		if action_drill.disabled:
			return
			
		# If we have a current player, try to use the drill ability
		if current_player and current_player.abilities.has("drill"):
			var success = current_player.use_ability("drill", null)  # Drill doesn't need a target
			print("HUD: Drill ability use " + ("succeeded" if success else "failed"))
			
			# If successful, make sure the button is reset
			if success:
				action_drill.modulate = Color(1, 1, 1, 1)  # Reset color
				
				# Get the GameController to make sure current_ability is cleared
				var game_controller = get_node("/root").find_child("GameController", true, false)
				if game_controller and game_controller.current_ability == "drill":
					game_controller.current_ability = ""
				
				# Force update of all buttons to reflect current state
				update_action_buttons()
			else:
				# If not successful, still update buttons to reflect current state
				update_action_buttons()

# Function to check if any ability is currently selected
func is_ability_selected() -> bool:
	var game_controller = get_node("/root").find_child("GameController", true, false)
	if game_controller and game_controller.current_ability != "":
		return true
	return false

# Show drill path when hovering over drill button
func _on_action_drill_mouse_entered() -> void:
	# Don't show hover effects if an ability is currently selected
	if is_ability_selected():
		return
		
	is_hovering_drill_button = true
	var action_drill = $Action/ActionMargin/ActionHBox/ActionDrill
	# Only show hover effect if button is not disabled
	if action_drill and not action_drill.disabled and current_player and current_player.abilities.has("drill"):
		print("HUD: Showing drill hover effect")
		DrillButtonHovered.emit(current_player)

# Hide drill path when no longer hovering over drill button
func _on_action_drill_mouse_exited() -> void:
	is_hovering_drill_button = false
	
	# Only clear highlights if no ability is selected
	var game_controller = get_node("/root").find_child("GameController", true, false)
	if not game_controller or game_controller.current_ability == "":
		DrillButtonUnhovered.emit()

# Handle clicking on the drill smash action button
func _on_action_drill_smash_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var action_drill_smash = $Action/ActionMargin/ActionHBox/ActionDrillSmash
		# If button is disabled, don't process the click
		if action_drill_smash.disabled:
			return
			
		# If we have a current player, check if they have the ability and highlight targets
		if current_player and current_player.abilities.has("drill_smash"):
			# Tell the GameController we're selecting a target for drill smash
			var game_controller = get_node("/root").find_child("GameController", true, false)
			if game_controller:
				# Toggle the ability if it's already active
				if game_controller.current_ability == "drill_smash":
					game_controller.cancel_current_ability()
					$Action/ActionMargin/ActionHBox/ActionDrillSmash.modulate = Color(1, 1, 1, 1)  # Reset color
					# Update buttons after canceling
					update_action_buttons()
					return
				
				# Check if player has enough action points for this ability
				if current_player.action_points < current_player.get_ability_cost("drill_smash"):
					print("HUD: Not enough action points for drill_smash")
					return
				
				game_controller.current_ability = "drill_smash"
				print("HUD: Set drill_smash as current ability")
				
				# Add visual feedback
				$Action/ActionMargin/ActionHBox/ActionDrillSmash.modulate = Color(1.3, 0.7, 0.7, 1)  # Highlight button
			
			current_player.highlight_drill_smash_targets()
			# The actual ability use will be handled by the tile selection
			
			# Update all buttons to reflect the current selection state
			update_action_buttons()

# Show drill smash targets when hovering over drill smash button
func _on_action_drill_smash_mouse_entered() -> void:
	# Don't show hover effects if an ability is currently selected
	if is_ability_selected():
		return
		
	is_hovering_drill_smash_button = true
	var action_drill_smash = $Action/ActionMargin/ActionHBox/ActionDrillSmash
	# Only show hover effect if button is not disabled
	if action_drill_smash and not action_drill_smash.disabled and current_player and current_player.abilities.has("drill_smash"):
		print("HUD: Showing drill_smash hover effect")
		DrillSmashButtonHovered.emit(current_player)
		current_player.highlight_drill_smash_targets()

# Hide drill smash targets when no longer hovering over drill smash button
func _on_action_drill_smash_mouse_exited() -> void:
	is_hovering_drill_smash_button = false
	
	# Only emit the unhover signal if we're not in drill_smash ability selection mode
	# and if no other ability is selected
	var game_controller = get_node("/root").find_child("GameController", true, false)
	if game_controller:
		if game_controller.current_ability == "":
			DrillSmashButtonUnhovered.emit()
		elif game_controller.current_ability == "drill_smash":
			print("HUD: Keeping drill_smash highlights active since ability is selected")
	else:
		DrillSmashButtonUnhovered.emit()

# Handle clicking on the line shot action button
func _on_action_line_shot_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var action_line_shot = $Action/ActionMargin/ActionHBox/ActionLineShot
		# If button is disabled, don't process the click
		if action_line_shot.disabled:
			return
			
		# If we have a current player, check if they have the ability and highlight targets
		if current_player and current_player.abilities.has("line_shot"):
			# Tell the GameController we're selecting a target for line shot
			var game_controller = get_node("/root").find_child("GameController", true, false)
			if game_controller:
				# Toggle the ability if it's already active
				if game_controller.current_ability == "line_shot":
					game_controller.cancel_current_ability()
					$Action/ActionMargin/ActionHBox/ActionLineShot.modulate = Color(1, 1, 1, 1)  # Reset color
					# Update buttons after canceling
					update_action_buttons()
					return
				
				# Check if player has enough action points for this ability
				if current_player.action_points < current_player.get_ability_cost("line_shot"):
					print("HUD: Not enough action points for line_shot")
					return
				
				game_controller.current_ability = "line_shot"
				print("HUD: Set line_shot as current ability")
				
				# Add visual feedback
				$Action/ActionMargin/ActionHBox/ActionLineShot.modulate = Color(0.7, 1.3, 0.7, 1)  # Highlight button
			
			current_player.highlight_line_shot_targets()
			# The actual ability use will be handled by the tile selection
			
			# Update all buttons to reflect the current selection state
			update_action_buttons()

# Show line shot targets when hovering over line shot button
func _on_action_line_shot_mouse_entered() -> void:
	# Don't show hover effects if an ability is currently selected
	if is_ability_selected():
		return
		
	is_hovering_line_shot_button = true
	var action_line_shot = $Action/ActionMargin/ActionHBox/ActionLineShot
	# Only show hover effect if button is not disabled
	if action_line_shot and not action_line_shot.disabled and current_player and current_player.abilities.has("line_shot"):
		print("HUD: Showing line_shot hover effect")
		LineShotButtonHovered.emit(current_player)
		current_player.highlight_line_shot_targets()

# Hide line shot targets when no longer hovering over line shot button
func _on_action_line_shot_mouse_exited() -> void:
	is_hovering_line_shot_button = false
	
	# Only emit the unhover signal if we're not in line_shot ability selection mode
	# and if no other ability is selected
	var game_controller = get_node("/root").find_child("GameController", true, false)
	if game_controller:
		if game_controller.current_ability == "":
			LineShotButtonUnhovered.emit()
		elif game_controller.current_ability == "line_shot":
			print("HUD: Keeping line_shot highlights active since ability is selected")
	else:
		LineShotButtonUnhovered.emit()

# Handle clicking on the fireball action button
func _on_action_fireball_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var action_fireball = $Action/ActionMargin/ActionHBox/ActionFireball
		# If button is disabled, don't process the click
		if action_fireball.disabled:
			return
			
		# If we have a current player, check if they have the ability and highlight targets
		if current_player and current_player.abilities.has("fireball"):
			# Tell the GameController we're selecting a target for fireball
			var game_controller = get_node("/root").find_child("GameController", true, false)
			if game_controller:
				# Toggle the ability if it's already active
				if game_controller.current_ability == "fireball":
					game_controller.cancel_current_ability()
					$Action/ActionMargin/ActionHBox/ActionFireball.modulate = Color(1, 1, 1, 1)  # Reset color
					# Update buttons after canceling
					update_action_buttons()
					return
				
				# Check if player has enough action points for this ability
				if current_player.action_points < current_player.get_ability_cost("fireball"):
					print("HUD: Not enough action points for fireball")
					return
				
				game_controller.current_ability = "fireball"
				print("HUD: Set fireball as current ability")
				
				# Add visual feedback
				$Action/ActionMargin/ActionHBox/ActionFireball.modulate = Color(1.3, 0.7, 0.7, 1)  # Highlight button with reddish tint
			
			current_player.highlight_fireball_targets()
			# The actual ability use will be handled by the tile selection
			
			# Update all buttons to reflect the current selection state
			update_action_buttons()

# Show fireball targets when hovering over fireball button
func _on_action_fireball_mouse_entered() -> void:
	# Don't show hover effects if an ability is currently selected
	if is_ability_selected():
		return
		
	var action_fireball = $Action/ActionMargin/ActionHBox/ActionFireball
	# Only show hover effect if button is not disabled
	if action_fireball and not action_fireball.disabled and current_player and current_player.abilities.has("fireball"):
		print("HUD: Showing fireball hover effect")
		FireballButtonHovered.emit(current_player)
		current_player.highlight_fireball_targets()

# Hide fireball targets when no longer hovering over fireball button
func _on_action_fireball_mouse_exited() -> void:
	# Only emit the unhover signal if we're not in fireball ability selection mode
	# and if no other ability is selected
	var game_controller = get_node("/root").find_child("GameController", true, false)
	if game_controller:
		if game_controller.current_ability == "":
			FireballButtonUnhovered.emit()
		elif game_controller.current_ability == "fireball":
			print("HUD: Keeping fireball highlights active since ability is selected")
	else:
		FireballButtonUnhovered.emit()

# Handle clicking on the cloak action button
func _on_action_cloak_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var action_cloak = $Action/ActionMargin/ActionHBox/ActionCloak
		# If button is disabled, don't process the click
		if action_cloak.disabled:
			return
			
		# If we have a current player, try to use the cloak ability
		if current_player and current_player.abilities.has("cloak"):
			var success = current_player.execute_ability("cloak", null)  # Cloak doesn't need a target
			print("HUD: Cloak ability use " + ("succeeded" if success else "failed"))
			
			# If successful, make sure the button is reset
			if success:
				action_cloak.modulate = Color(0.7, 0.7, 1.3, 1)  # Highlight with blue tint since it's active
				
				# Get the GameController to make sure current_ability is cleared
				var game_controller = get_node("/root").find_child("GameController", true, false)
				if game_controller:
					game_controller.current_ability = ""
				
				# Force update of all buttons to reflect current state
				update_action_buttons()
			else:
				# If not successful, still update buttons to reflect current state
				update_action_buttons()

# Show visual feedback when hovering over cloak button
func _on_action_cloak_mouse_entered() -> void:
	# Don't show hover effects if an ability is currently selected
	if is_ability_selected():
		return
		
	is_hovering_cloak_button = true
	var action_cloak = $Action/ActionMargin/ActionHBox/ActionCloak
	# Only show hover effect if button is not disabled
	if action_cloak and not action_cloak.disabled and current_player and current_player.abilities.has("cloak"):
		print("HUD: Showing cloak hover effect")
		CloakButtonHovered.emit(current_player)

# Hide visual feedback when no longer hovering over cloak button
func _on_action_cloak_mouse_exited() -> void:
	is_hovering_cloak_button = false
	
	# Only clear highlights if no ability is selected
	var game_controller = get_node("/root").find_child("GameController", true, false)
	if not game_controller or game_controller.current_ability == "":
		CloakButtonUnhovered.emit()

# Handle clicking on the defend action button
func _on_action_defend_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var action_defend = $Action/ActionMargin/ActionHBox/ActionDefend
		# If button is disabled, don't process the click
		if action_defend.disabled:
			return
			
		# If we have a current player, try to use the defend ability
		if current_player and current_player.abilities.has("defend"):
			var success = current_player.use_ability("defend", null)  # Defend doesn't need a target
			print("HUD: Defend ability use " + ("succeeded" if success else "failed"))
			
			# If successful, make sure the button is reset
			if success:
				action_defend.modulate = Color(0.7, 0.7, 1.2, 1)  # Highlight with blue tint since it's active
				
				# Get the GameController to make sure current_ability is cleared
				var game_controller = get_node("/root").find_child("GameController", true, false)
				if game_controller:
					game_controller.current_ability = ""
				
				# Force update of all buttons to reflect current state
				update_action_buttons()
			else:
				# If not successful, still update buttons to reflect current state
				update_action_buttons()

# Show visual feedback when hovering over defend button
func _on_defend_button_mouse_entered() -> void:
	# Don't show hover effects if an ability is currently selected
	if is_ability_selected():
		return
		
	var action_defend = $Action/ActionMargin/ActionHBox/ActionDefend
	# Only show hover effect if button is not disabled
	if action_defend and not action_defend.disabled and current_player and current_player.abilities.has("defend"):
		print("HUD: Showing defend hover effect")
		DefendButtonHovered.emit(current_player)

# Hide visual feedback when no longer hovering over defend button
func _on_defend_button_mouse_exited() -> void:
	# Only clear highlights if no ability is selected
	var game_controller = get_node("/root").find_child("GameController", true, false)
	if not game_controller or game_controller.current_ability == "":
		DefendButtonUnhovered.emit()

func get_end_turn_button():
	return $End/EndMargin/EndButton

# Updates the UI to show the current player's action points
func update_action_points(current: int, maximum: int) -> void:
	# Get all action point indicators
	var action_containers = $Info/InfoMargin/InfoVBox/ActHBox.get_children()
	
	# Skip the first child (it's the texture rect icon)
	for i in range(1, action_containers.size()):
		# i-1 is the index without the icon
		var point_index = i - 1
		
		# Check if this point should be active
		if point_index < current:
			action_containers[i].modulate = Color(1, 1, 1, 1) # Fully visible
		else:
			action_containers[i].modulate = Color(1, 1, 1, 0.3) # Dimmed
		
		# Hide the points beyond the maximum
		action_containers[i].visible = point_index < maximum

# Updates the UI to show the current player's health
func update_health_bar(current: int, maximum: int) -> void:
	# Get the health bar
	var health_bar = $Info/InfoMargin/InfoVBox/HealthBar
	
	# Update the value and max value
	health_bar.max_value = maximum
	health_bar.value = current
	
	# Optionally change the color based on health percentage
	var health_percent = float(current) / float(maximum)
	if health_percent < 0.3:
		health_bar.get("theme_override_styles/fill").bg_color = Color(0.8, 0.0, 0.0, 1.0) # Critical health (red)
	elif health_percent < 0.6:
		health_bar.get("theme_override_styles/fill").bg_color = Color(0.8, 0.8, 0.0, 1.0) # Low health (yellow)
	else:
		health_bar.get("theme_override_styles/fill").bg_color = Color(0.96, 0.07, 0.14, 1.0) # Normal health (game's default red)

# Updates the UI to show the current player's movement points
func update_movement_points(current: int, maximum: int) -> void:
	# Get all movement point indicators
	var move_containers = $Info/InfoMargin/InfoVBox/MoveHBox.get_children()
	
	# Skip the first child (it's the texture rect icon)
	for i in range(1, move_containers.size()):
		# i-1 is the index without the icon
		var point_index = i - 1
		
		# Check if this point should be active
		if point_index < current:
			move_containers[i].modulate = Color(1, 1, 1, 1) # Fully visible
		else:
			move_containers[i].modulate = Color(1, 1, 1, 0.3) # Dimmed
		
		# Hide the points beyond the maximum
		move_containers[i].visible = point_index < maximum

# Called when a player's ability is used - this will properly handle button deselection
func _on_player_ability_used(ability_name: String) -> void:
	print("HUD: Player used ability: " + ability_name)
	
	# Get the GameController to reset current_ability
	var game_controller = get_node("/root").find_child("GameController", true, false)
	if game_controller and game_controller.current_ability == ability_name:
		print("HUD: Resetting current ability in GameController")
		game_controller.current_ability = ""
		
	# Reset button appearances
	var action_drill = $Action/ActionMargin/ActionHBox/ActionDrill
	var action_drill_smash = $Action/ActionMargin/ActionHBox/ActionDrillSmash
	var action_line_shot = $Action/ActionMargin/ActionHBox/ActionLineShot
	var action_fireball = $Action/ActionMargin/ActionHBox/ActionFireball
	var action_cloak = $Action/ActionMargin/ActionHBox/ActionCloak
	var action_defend = $Action/ActionMargin/ActionHBox/ActionDefend
	var action_charge_attack = $Action/ActionMargin/ActionHBox/ActionChargeAttack
	var action_emergency_teleport = $Action/ActionMargin/ActionHBox/ActionEmergencyTeleport
	
	# Reset specific button based on which ability was used
	match ability_name:
		"drill":
			action_drill.modulate = Color(1, 1, 1, 1)
		"drill_smash":
			action_drill_smash.modulate = Color(1, 1, 1, 1)
		"line_shot":
			action_line_shot.modulate = Color(1, 1, 1, 1)
		"fireball":
			action_fireball.modulate = Color(1, 1, 1, 1)
		"cloak":
			action_cloak.modulate = Color(1, 1, 1, 1)
		"defend":
			action_defend.modulate = Color(1, 1, 1, 1)
		"charge_attack":
			action_charge_attack.modulate = Color(1, 1, 1, 1)
		"emergency_teleport":
			action_emergency_teleport.modulate = Color(1, 1, 1, 1)
	
	# Update all buttons
	update_action_buttons()

# Called when a player is activated - should be called by GameController
func set_active_player(player: PlayerEntity) -> void:
	# Disconnect from previous player if exists
	if current_player:
		if current_player.is_connected("action_points_changed", Callable(self, "update_action_points")):
			current_player.disconnect("action_points_changed", Callable(self, "update_action_points"))
		if current_player.is_connected("movement_points_changed", Callable(self, "update_movement_points")):
			current_player.disconnect("movement_points_changed", Callable(self, "update_movement_points"))
		if current_player.is_connected("health_changed", Callable(self, "update_health_bar")):
			current_player.disconnect("health_changed", Callable(self, "update_health_bar"))
		if current_player.is_connected("action_points_changed", Callable(self, "update_action_buttons")):
			current_player.disconnect("action_points_changed", Callable(self, "update_action_buttons"))
		if current_player.is_connected("ability_used", Callable(self, "update_action_buttons")):
			current_player.disconnect("ability_used", Callable(self, "update_action_buttons"))
		if current_player.is_connected("action_selection_changed", Callable(self, "update_action_buttons")):
			current_player.disconnect("action_selection_changed", Callable(self, "update_action_buttons"))
	
	# Store reference to the new player
	current_player = player
	
	if player:
		# Connect to the new player's signals
		current_player.connect("action_points_changed", update_action_points)
		current_player.connect("movement_points_changed", update_movement_points)
		current_player.connect("health_changed", update_health_bar)
		current_player.connect("action_points_changed", update_action_buttons)
		current_player.connect("ability_used", _on_player_ability_used)  # Use the new handler
		current_player.connect("action_selection_changed", update_action_buttons)
		
		# Update the UI immediately with current values
		update_action_points(player.action_points, player.max_action_points)
		update_movement_points(player.movement_points, player.max_movement_points)
		update_health_bar(player.current_health, player.max_health)
		
		# Update character image
		update_character_image(player)
		
		# Update action buttons based on player abilities
		update_action_buttons()
		
		# Display drilling indicator if player is drilling
		if player.is_drilling:
			show_drilling_indicator(player.drilling_turns_left)
		else:
			hide_drilling_indicator()
		
		# Update drill visualization if we're hovering the button
		if is_hovering_drill_button:
			DrillButtonHovered.emit(current_player)
	else:
		# Clear UI if no player is active
		update_action_points(0, 0)
		update_movement_points(0, 0)
		update_health_bar(0, 1) # Set to 0 with a max of 1 (empty bar)
		
		# Reset character image
		var image = $Info/InfoMargin/InfoVBox/CharImage
		image.self_modulate = Color(1.0, 1.0, 1.0, 0.5) # Dim the character image
		
		# Hide all action buttons
		update_action_buttons()
		
		# Hide drilling indicator
		hide_drilling_indicator()
		
		# Clear any drill visualization
		DrillButtonUnhovered.emit()

# Updates the character image based on the player type
func update_character_image(player: PlayerEntity) -> void:
	var image = $Info/InfoMargin/InfoVBox/CharImage
	
	# Use the player's profile texture and tint directly. If the player is damaged more than 50% use the damaged texture
	if player.current_health < player.max_health * 0.5:
		image.texture = player.damaged_profile_texture
	else:
		image.texture = player.profile_texture
	image.self_modulate = player.profile_tint

# Show a drilling indicator when a player is in the drilling state
func show_drilling_indicator(turns_left: int) -> void:
	# Get the drilling label
	var drill_label = $DrillIndicator/DrillLabel
	
	# Update the text to show the turns remaining
	drill_label.text = "DRILLING: " + str(turns_left) + " turns left"
	
	# Show the indicator
	$DrillIndicator.visible = true
	
	# Update action buttons as abilities may be restricted during drilling
	update_action_buttons()

# Hide the drilling indicator
func hide_drilling_indicator() -> void:
	# Hide the drilling indicator
	$DrillIndicator.visible = false
	
	# Update action buttons as abilities may become available again
	update_action_buttons()

# Updates the action buttons visibility and modulation based on the current player
func update_action_buttons(_cur=0, _max=0) -> void:
	# Get all action buttons
	var action_drill = $Action/ActionMargin/ActionHBox/ActionDrill
	var action_big_drill = $Action/ActionMargin/ActionHBox/ActionBigDrill
	var action_drill_smash = $Action/ActionMargin/ActionHBox/ActionDrillSmash
	var action_line_shot = $Action/ActionMargin/ActionHBox/ActionLineShot
	var action_fireball = $Action/ActionMargin/ActionHBox/ActionFireball
	var action_cloak = $Action/ActionMargin/ActionHBox/ActionCloak
	var action_defend = $Action/ActionMargin/ActionHBox/ActionDefend
	var action_charge_attack = $Action/ActionMargin/ActionHBox/ActionChargeAttack
	var action_emergency_teleport = $Action/ActionMargin/ActionHBox/ActionEmergencyTeleport
	var action_healing_aoe = $Action/ActionMargin/ActionHBox/ActionHealingAOE
	var action_freeze_aoe = $Action/ActionMargin/ActionHBox/ActionFreezeAOE
	var action_poison_aoe = $Action/ActionMargin/ActionHBox/ActionPoisonAOE
	
	# Get current selected ability if any
	var game_controller = get_node("/root").find_child("GameController", true, false)
	var current_ability = ""
	if game_controller:
		current_ability = game_controller.current_ability
	
	# Reset all tooltips to default before updating
	action_drill.tooltip_text = "Drill"
	action_big_drill.tooltip_text = "Big Drill"
	action_drill_smash.tooltip_text = "Drill Smash"
	action_line_shot.tooltip_text = "Line Shot"
	action_fireball.tooltip_text = "Fireball"
	action_cloak.tooltip_text = "Cloak"
	action_defend.tooltip_text = "Defend"
	action_charge_attack.tooltip_text = "Charge Attack"
	action_emergency_teleport.tooltip_text = "Emergency Teleport"
	action_healing_aoe.tooltip_text = "Healing Splash"
	action_freeze_aoe.tooltip_text = "Freeze Zone"
	action_poison_aoe.tooltip_text = "Poison Cloud"
	
	if current_player:
		print("HUD: Updating action buttons for player " + current_player.entity_name + 
			", AP: " + str(current_player.action_points) + "/" + str(current_player.max_action_points))
			
		# Force immediate visibility before checking conditions
		action_drill.visible = true
		action_big_drill.visible = true
		action_drill_smash.visible = true
		action_line_shot.visible = true
		action_fireball.visible = true
		action_cloak.visible = true
		action_defend.visible = true
		action_charge_attack.visible = true
		action_emergency_teleport.visible = true
		action_healing_aoe.visible = true
		action_freeze_aoe.visible = true
		action_poison_aoe.visible = true
	
		# Drill ability - available to all players
		if current_player.abilities.has("drill") and not current_player.is_drilling:
			action_drill.visible = true
			action_drill.tooltip_text = current_player.get_ability_description("drill")
			# Check if player has enough action points
			if current_player.action_points >= current_player.get_ability_cost("drill"):
				action_drill.modulate = Color(1, 1, 1, 1) # Fully visible
				action_drill.disabled = false
			else:
				action_drill.modulate = Color(0.5, 0.5, 0.5, 1) # Greyed out
				action_drill.disabled = true # Disable the button
				print("HUD: Disabling drill button - not enough AP")
		else:
			action_drill.visible = false
			action_drill.disabled = true
			print("HUD: Hiding drill button - ability not available")
			
		# Big Drill ability - only for HeavyPlayer
		if current_player.abilities.has("big_drill") and current_player is HeavyPlayer and not current_player.is_drilling:
			action_big_drill.visible = true
			action_big_drill.tooltip_text = current_player.get_ability_description("big_drill")
			# If it's the current selected ability, keep it highlighted
			if current_ability == "big_drill":
				action_big_drill.modulate = Color(0.7, 0.7, 1.3, 1)  # Highlighted with bluish tint
				action_big_drill.disabled = false
				print("HUD: Highlighting big drill button - ability active")
			# Check if player has enough action points
			elif current_player.action_points >= current_player.get_ability_cost("big_drill"):
				action_big_drill.modulate = Color(1, 1, 1, 1)  # Fully visible
				action_big_drill.disabled = false
			else:
				action_big_drill.modulate = Color(0.5, 0.5, 0.5, 1)  # Greyed out
				action_big_drill.disabled = true  # Disable the button
				print("HUD: Disabling big drill button - not enough AP")
		else:
			action_big_drill.visible = false
			action_big_drill.disabled = true
			print("HUD: Hiding big drill button - ability not available")
		
		# Drill Smash ability - only for HeavyPlayer
		if current_player.abilities.has("drill_smash") and not current_player.is_drilling:
			action_drill_smash.visible = true
			action_drill_smash.tooltip_text = current_player.get_ability_description("drill_smash")
			# If it's the current selected ability, keep it highlighted
			if current_ability == "drill_smash":
				action_drill_smash.modulate = Color(1.3, 0.7, 0.7, 1) # Highlighted
				action_drill_smash.disabled = false
				print("HUD: Highlighting drill_smash button - ability active")
			# Check if player has enough action points
			elif current_player.action_points >= current_player.get_ability_cost("drill_smash"):
				action_drill_smash.modulate = Color(1, 1, 1, 1) # Fully visible
				action_drill_smash.disabled = false
			else:
				action_drill_smash.modulate = Color(0.5, 0.5, 0.5, 1) # Greyed out
				action_drill_smash.disabled = true # Disable the button
				print("HUD: Disabling drill_smash button - not enough AP")
		else:
			action_drill_smash.visible = false
			action_drill_smash.disabled = true
			print("HUD: Hiding drill_smash button - ability not available")
		
		# Line Shot ability - only for ScoutPlayer
		if current_player.abilities.has("line_shot") and not current_player.is_drilling:
			action_line_shot.visible = true
			action_line_shot.tooltip_text = current_player.get_ability_description("line_shot")
			# If it's the current selected ability, keep it highlighted
			if current_ability == "line_shot":
				action_line_shot.modulate = Color(0.7, 1.3, 0.7, 1) # Highlighted
				action_line_shot.disabled = false
				print("HUD: Highlighting line_shot button - ability active")
			# Check if player has enough action points
			elif current_player.action_points >= current_player.get_ability_cost("line_shot"):
				action_line_shot.modulate = Color(1, 1, 1, 1) # Fully visible
				action_line_shot.disabled = false
			else:
				action_line_shot.modulate = Color(0.5, 0.5, 0.5, 1) # Greyed out
				action_line_shot.disabled = true # Disable the button
				print("HUD: Disabling line_shot button - not enough AP")
		else:
			action_line_shot.visible = false
			action_line_shot.disabled = true
			print("HUD: Hiding line_shot button - ability not available")
			
		# Cloak ability - only for ScoutPlayer
		if current_player.abilities.has("cloak") and not current_player.is_drilling:
			action_cloak.visible = true
			action_cloak.tooltip_text = current_player.get_ability_description("cloak")
			# If cloak is already active, keep it highlighted
			if current_player.is_cloaked:
				action_cloak.modulate = Color(0.7, 0.7, 1.3, 1) # Highlighted with blue tint
				action_cloak.disabled = true  # Can't activate it again while it's active
				print("HUD: Highlighting cloak button - cloak is active")
			# Check if player has enough action points
			elif current_player.action_points >= current_player.get_ability_cost("cloak"):
				action_cloak.modulate = Color(1, 1, 1, 1) # Fully visible
				action_cloak.disabled = false
			else:
				action_cloak.modulate = Color(0.5, 0.5, 0.5, 1) # Greyed out
				action_cloak.disabled = true # Disable the button
				print("HUD: Disabling cloak button - not enough AP")
		else:
			action_cloak.visible = false
			action_cloak.disabled = true
			print("HUD: Hiding cloak button - ability not available")
			
		# Fireball ability - only for WizardPlayer
		if current_player.abilities.has("fireball") and not current_player.is_drilling:
			action_fireball.visible = true
			action_fireball.tooltip_text = current_player.get_ability_description("fireball")
			# If it's the current selected ability, keep it highlighted
			if current_ability == "fireball":
				action_fireball.modulate = Color(1.3, 0.7, 0.7, 1) # Highlighted with reddish tint
				action_fireball.disabled = false
				print("HUD: Highlighting fireball button - ability active")
			# Check if player has enough action points
			elif current_player.action_points >= current_player.get_ability_cost("fireball"):
				action_fireball.modulate = Color(1, 1, 1, 1) # Fully visible
				action_fireball.disabled = false
			else:
				action_fireball.modulate = Color(0.5, 0.5, 0.5, 1) # Greyed out
				action_fireball.disabled = true # Disable the button
				print("HUD: Disabling fireball button - not enough AP")
		else:
			action_fireball.visible = false
			action_fireball.disabled = true
			print("HUD: Hiding fireball button - ability not available")
			
		# Defend ability - only for HeavyPlayer
		if current_player.abilities.has("defend") and not current_player.is_drilling:
			action_defend.visible = true
			action_defend.tooltip_text = current_player.get_ability_description("defend")
			# If defend is already active, keep it highlighted
			if current_player.defend_active:
				action_defend.modulate = Color(0.7, 0.7, 1.2, 1) # Highlighted with blue tint
				action_defend.disabled = true  # Can't activate it again while it's active
				print("HUD: Highlighting defend button - defend is active")
			# Check if player has enough action points
			elif current_player.action_points >= current_player.get_ability_cost("defend"):
				action_defend.modulate = Color(1, 1, 1, 1) # Fully visible
				action_defend.disabled = false
			else:
				action_defend.modulate = Color(0.5, 0.5, 0.5, 1) # Greyed out
				action_defend.disabled = true # Disable the button
				print("HUD: Disabling defend button - not enough AP")
		else:
			action_defend.visible = false
			action_defend.disabled = true
			print("HUD: Hiding defend button - ability not available")
			
		# Charge Attack ability - only for HeavyPlayer
		if current_player.abilities.has("charge_attack") and not current_player.is_drilling:
			action_charge_attack.visible = true
			action_charge_attack.tooltip_text = current_player.get_ability_description("charge_attack")
			# If it's the current selected ability, keep it highlighted
			if current_ability == "charge_attack":
				action_charge_attack.modulate = Color(1.3, 0.7, 0.7, 1) # Highlighted with reddish tint
				action_charge_attack.disabled = false
				print("HUD: Highlighting charge_attack button - ability active")
			# Check if player has enough action points
			elif current_player.action_points >= current_player.get_ability_cost("charge_attack"):
				action_charge_attack.modulate = Color(1, 1, 1, 1) # Fully visible
				action_charge_attack.disabled = false
			else:
				action_charge_attack.modulate = Color(0.5, 0.5, 0.5, 1) # Greyed out
				action_charge_attack.disabled = true # Disable the button
				print("HUD: Disabling charge_attack button - not enough AP")
		else:
			action_charge_attack.visible = false
			action_charge_attack.disabled = true
			print("HUD: Hiding charge_attack button - ability not available")
			
		# Emergency Teleport ability - only for ScoutPlayer
		if current_player.abilities.has("emergency_teleport") and not current_player.is_drilling:
			action_emergency_teleport.visible = true
			action_emergency_teleport.tooltip_text = current_player.get_ability_description("emergency_teleport")
			# If it's the current selected ability, keep it highlighted
			if current_ability == "emergency_teleport":
				action_emergency_teleport.modulate = Color(0.7, 0.7, 1.3, 1) # Highlighted with blue tint
				action_emergency_teleport.disabled = false
				print("HUD: Highlighting emergency_teleport button - ability active")
			# Check if player has enough action points
			elif current_player.action_points >= current_player.get_ability_cost("emergency_teleport"):
				action_emergency_teleport.modulate = Color(1, 1, 1, 1) # Fully visible
				action_emergency_teleport.disabled = false
			else:
				action_emergency_teleport.modulate = Color(0.5, 0.5, 0.5, 1) # Greyed out
				action_emergency_teleport.disabled = true # Disable the button
				print("HUD: Disabling emergency_teleport button - not enough AP")
		else:
			action_emergency_teleport.visible = false
			action_emergency_teleport.disabled = true
			print("HUD: Hiding emergency_teleport button - ability not available")
			
		# Healing AOE ability - only for WizardPlayer
		if current_player.abilities.has("healing_aoe") and not current_player.is_drilling:
			action_healing_aoe.visible = true
			action_healing_aoe.tooltip_text = current_player.get_ability_description("healing_aoe")
			# If it's the current selected ability, keep it highlighted
			if current_ability == "healing_aoe":
				action_healing_aoe.modulate = Color(0.7, 1.3, 0.7, 1) # Highlighted with green tint
				action_healing_aoe.disabled = false
				print("HUD: Highlighting healing_aoe button - ability active")
			# Check if player has enough action points
			elif current_player.action_points >= current_player.get_ability_cost("healing_aoe"):
				action_healing_aoe.modulate = Color(1, 1, 1, 1) # Fully visible
				action_healing_aoe.disabled = false
			else:
				action_healing_aoe.modulate = Color(0.5, 0.5, 0.5, 1) # Greyed out
				action_healing_aoe.disabled = true # Disable the button
				print("HUD: Disabling healing_aoe button - not enough AP")
		else:
			action_healing_aoe.visible = false
			action_healing_aoe.disabled = true
			print("HUD: Hiding healing_aoe button - ability not available")
			
		# Freeze AOE ability - only for WizardPlayer
		if current_player.abilities.has("freeze_aoe") and not current_player.is_drilling:
			action_freeze_aoe.visible = true
			action_freeze_aoe.tooltip_text = current_player.get_ability_description("freeze_aoe")
			# If it's the current selected ability, keep it highlighted
			if current_ability == "freeze_aoe":
				action_freeze_aoe.modulate = Color(0.7, 0.7, 1.3, 1) # Highlighted with blue tint
				action_freeze_aoe.disabled = false
				print("HUD: Highlighting freeze_aoe button - ability active")
			# Check if player has enough action points
			elif current_player.action_points >= current_player.get_ability_cost("freeze_aoe"):
				action_freeze_aoe.modulate = Color(1, 1, 1, 1) # Fully visible
				action_freeze_aoe.disabled = false
			else:
				action_freeze_aoe.modulate = Color(0.5, 0.5, 0.5, 1) # Greyed out
				action_freeze_aoe.disabled = true # Disable the button
				print("HUD: Disabling freeze_aoe button - not enough AP")
		else:
			action_freeze_aoe.visible = false
			action_freeze_aoe.disabled = true
			print("HUD: Hiding freeze_aoe button - ability not available")
			
		# Poison AOE ability - only for WizardPlayer
		if current_player.abilities.has("poison_aoe") and not current_player.is_drilling:
			action_poison_aoe.visible = true
			action_poison_aoe.tooltip_text = current_player.get_ability_description("poison_aoe")
			# If it's the current selected ability, keep it highlighted
			if current_ability == "poison_aoe":
				action_poison_aoe.modulate = Color(0.7, 1.0, 0.4, 1) # Highlighted with greenish tint
				action_poison_aoe.disabled = false
				print("HUD: Highlighting poison_aoe button - ability active")
			# Check if player has enough action points
			elif current_player.action_points >= current_player.get_ability_cost("poison_aoe"):
				action_poison_aoe.modulate = Color(1, 1, 1, 1) # Fully visible
				action_poison_aoe.disabled = false
			else:
				action_poison_aoe.modulate = Color(0.5, 0.5, 0.5, 1) # Greyed out
				action_poison_aoe.disabled = true # Disable the button
				print("HUD: Disabling poison_aoe button - not enough AP")
		else:
			action_poison_aoe.visible = false
			action_poison_aoe.disabled = true
			print("HUD: Hiding poison_aoe button - ability not available")
	else:
		# No active player, hide all buttons
		action_drill.visible = false
		action_drill.disabled = true
		action_big_drill.visible = false
		action_big_drill.disabled = true
		action_drill_smash.visible = false
		action_drill_smash.disabled = true
		action_line_shot.visible = false
		action_line_shot.disabled = true
		action_fireball.visible = false
		action_fireball.disabled = true
		action_cloak.visible = false
		action_cloak.disabled = true
		action_defend.visible = false
		action_defend.disabled = true
		action_charge_attack.visible = false
		action_charge_attack.disabled = true
		action_emergency_teleport.visible = false
		action_emergency_teleport.disabled = true
		print("HUD: Hiding all ability buttons - no active player")

# Event handler for when the big drill button is clicked
func _on_action_big_drill_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var action_big_drill = $Action/ActionMargin/ActionHBox/ActionBigDrill
		# If button is disabled, don't process the click
		if action_big_drill.disabled:
			return
			
		# If we have a current player, try to use the big drill ability
		if current_player and current_player.abilities.has("big_drill"):
			var success = current_player.use_ability("big_drill", null)  # Big drill doesn't need a target
			print("HUD: Big drill ability use " + ("succeeded" if success else "failed"))
			
			# If successful, make sure the button is reset
			if success:
				action_big_drill.modulate = Color(1, 1, 1, 1)  # Reset color
				
				# Get the GameController to make sure current_ability is cleared
				var game_controller = get_node("/root").find_child("GameController", true, false)
				if game_controller and game_controller.current_ability == "big_drill":
					game_controller.current_ability = ""
				
				# Force update of all buttons to reflect current state
				update_action_buttons()
			else:
				# If not successful, still update buttons to reflect current state
				update_action_buttons()

# Show big drill targets when hovering over big drill button
func _on_big_drill_button_hovered() -> void:
	# Don't show hover effects if an ability is currently selected
	if is_ability_selected():
		return
		
	var action_big_drill = $Action/ActionMargin/ActionHBox/ActionBigDrill
	# Only show hover effect if button is not disabled
	if action_big_drill and not action_big_drill.disabled and current_player and current_player.abilities.has("big_drill"):
		print("HUD: Showing big drill hover effect")
		BigDrillButtonHovered.emit(current_player)
		current_player.highlight_big_drill_targets()

# Clear highlights when unhovered
func _on_big_drill_button_unhovered() -> void:
	# Only clear highlights if no ability is selected
	var game_controller = get_node("/root").find_child("GameController", true, false)
	if not game_controller or game_controller.current_ability == "":
		emit_signal("BigDrillButtonUnhovered")
		print("HUD: Big drill button unhovered")
	elif game_controller.current_ability == "big_drill":
		print("HUD: Keeping big drill highlights active since ability is selected")

# Update the XP counter with the current value
func update_xp_counter(xp_value: int):
	# We don't need to set the XP value again since we're already using Global.xp
	# But we should make sure the XP display is updated
	var xp_scene = get_node("/root").find_child("XP", true, false)
	if xp_scene:
		xp_scene.update_xp()
		print("HUD: Updated XP counter to " + str(xp_value))
	else:
		print("HUD: Could not find XP scene to update")

# Handler for the charge attack button
func _on_action_charge_attack_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var action_charge_attack = $Action/ActionMargin/ActionHBox/ActionChargeAttack
		# If button is disabled, don't process the click
		if action_charge_attack.disabled:
			return
			
		# If we have a current player, check if they have the ability and highlight targets
		if current_player and current_player.abilities.has("charge_attack"):
			# Tell the GameController we're selecting a target for charge attack
			var game_controller = get_node("/root").find_child("GameController", true, false)
			if game_controller:
				# Toggle the ability if it's already active
				if game_controller.current_ability == "charge_attack":
					game_controller.cancel_current_ability()
					$Action/ActionMargin/ActionHBox/ActionChargeAttack.modulate = Color(1, 1, 1, 1)  # Reset color
					# Update buttons after canceling
					update_action_buttons()
					return
				
				# Check if player has enough action points for this ability
				if current_player.action_points < current_player.get_ability_cost("charge_attack"):
					print("HUD: Not enough action points for charge_attack")
					return
				
				game_controller.current_ability = "charge_attack"
				print("HUD: Set charge_attack as current ability")
				
				# Add visual feedback
				$Action/ActionMargin/ActionHBox/ActionChargeAttack.modulate = Color(1.3, 0.7, 0.7, 1)  # Highlight button
			
			current_player.highlight_charge_attack_targets()
			# The actual ability use will be handled by the tile selection
			
			# Update all buttons to reflect the current selection state
			update_action_buttons()

# Show charge attack targets when hovering over charge attack button
func _on_action_charge_attack_mouse_entered() -> void:
	# Don't show hover effects if an ability is currently selected
	if is_ability_selected():
		return
		
	is_hovering_charge_attack_button = true
	var action_charge_attack = $Action/ActionMargin/ActionHBox/ActionChargeAttack
	# Only show hover effect if button is not disabled
	if action_charge_attack and not action_charge_attack.disabled and current_player and current_player.abilities.has("charge_attack"):
		print("HUD: Showing charge_attack hover effect")
		ChargeAttackButtonHovered.emit(current_player)
		current_player.highlight_charge_attack_targets()

# Hide charge attack targets when no longer hovering over charge attack button
func _on_action_charge_attack_mouse_exited() -> void:
	is_hovering_charge_attack_button = false
	
	# Only clear highlights if no ability is selected or if this ability is not the current one
	var game_controller = get_node("/root").find_child("GameController", true, false)
	if not game_controller or game_controller.current_ability == "":
		ChargeAttackButtonUnhovered.emit()
	elif game_controller.current_ability == "charge_attack":
		print("HUD: Keeping charge_attack highlights active since ability is selected")

# End turn button
func _on_end_button_pressed() -> void:
	if current_player:
		current_player.end_turn()
		print("HUD: End turn button pressed for player " + current_player.entity_name)

# Handler for the emergency teleport button
func _on_action_emergency_teleport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var action_emergency_teleport = $Action/ActionMargin/ActionHBox/ActionEmergencyTeleport
		# If button is disabled, don't process the click
		if action_emergency_teleport.disabled:
			return
			
		# If we have a current player, try to use the emergency teleport ability
		if current_player and current_player.abilities.has("emergency_teleport"):
			var success = current_player.use_ability("emergency_teleport", null)  # Emergency teleport doesn't need a target
			print("HUD: Emergency teleport ability use " + ("succeeded" if success else "failed"))
			
			# If successful, make sure the button is reset
			if success:
				action_emergency_teleport.modulate = Color(1, 1, 1, 1)  # Reset color
				
				# Get the GameController to make sure current_ability is cleared
				var game_controller = get_node("/root").find_child("GameController", true, false)
				if game_controller and game_controller.current_ability == "emergency_teleport":
					game_controller.current_ability = ""
				
				# Force update of all buttons to reflect current state
				update_action_buttons()
			else:
				# If not successful, still update buttons to reflect current state
				update_action_buttons()

# Show emergency teleport info when hovering over emergency teleport button
func _on_action_emergency_teleport_mouse_entered() -> void:
	# Don't show hover effects if an ability is currently selected
	if is_ability_selected():
		return
		
	is_hovering_emergency_teleport_button = true
	var action_emergency_teleport = $Action/ActionMargin/ActionHBox/ActionEmergencyTeleport
	# Only show hover effect if button is not disabled
	if action_emergency_teleport and not action_emergency_teleport.disabled and current_player and current_player.abilities.has("emergency_teleport"):
		print("HUD: Showing emergency_teleport hover effect")
		EmergencyTeleportButtonHovered.emit(current_player)

# Hide emergency teleport info when no longer hovering over emergency teleport button
func _on_action_emergency_teleport_mouse_exited() -> void:
	is_hovering_emergency_teleport_button = false
	
	# Only clear highlights if no ability is selected
	var game_controller = get_node("/root").find_child("GameController", true, false)
	if not game_controller or game_controller.current_ability == "":
		EmergencyTeleportButtonUnhovered.emit()
	elif game_controller.current_ability == "emergency_teleport":
		print("HUD: Keeping emergency_teleport highlights active since ability is selected")

# Handling mouse enter/exit for healing AOE button
func _on_action_healing_aoe_mouse_entered() -> void:
	# Don't show hover effects if an ability is currently selected
	if is_ability_selected():
		return
		
	is_hovering_healing_aoe_button = true
	if current_player and current_player is WizardPlayer:
		emit_signal("HealingAOEButtonHovered", current_player)
		
func _on_action_healing_aoe_mouse_exited() -> void:
	is_hovering_healing_aoe_button = false
	
	# Only clear highlights if no ability is selected
	var game_controller = get_node("/root").find_child("GameController", true, false)
	if not game_controller or game_controller.current_ability == "":
		emit_signal("HealingAOEButtonUnhovered")
	elif game_controller.current_ability == "healing_aoe":
		print("HUD: Keeping healing_aoe highlights active since ability is selected")

# Handling mouse enter/exit for freeze AOE button
func _on_action_freeze_aoe_mouse_entered() -> void:
	# Don't show hover effects if an ability is currently selected
	if is_ability_selected():
		return
		
	is_hovering_freeze_aoe_button = true
	if current_player and current_player is WizardPlayer:
		emit_signal("FreezeAOEButtonHovered", current_player)
		
func _on_action_freeze_aoe_mouse_exited() -> void:
	is_hovering_freeze_aoe_button = false
	
	# Only clear highlights if no ability is selected
	var game_controller = get_node("/root").find_child("GameController", true, false)
	if not game_controller or game_controller.current_ability == "":
		emit_signal("FreezeAOEButtonUnhovered")
	elif game_controller.current_ability == "freeze_aoe":
		print("HUD: Keeping freeze_aoe highlights active since ability is selected")

# Handling mouse enter/exit for poison AOE button
func _on_action_poison_aoe_mouse_entered() -> void:
	# Don't show hover effects if an ability is currently selected
	if is_ability_selected():
		return
		
	is_hovering_poison_aoe_button = true
	if current_player and current_player is WizardPlayer:
		emit_signal("PoisonAOEButtonHovered", current_player)
		
func _on_action_poison_aoe_mouse_exited() -> void:
	is_hovering_poison_aoe_button = false
	
	# Only clear highlights if no ability is selected
	var game_controller = get_node("/root").find_child("GameController", true, false)
	if not game_controller or game_controller.current_ability == "":
		emit_signal("PoisonAOEButtonUnhovered")
	elif game_controller.current_ability == "poison_aoe":
		print("HUD: Keeping poison_aoe highlights active since ability is selected")

# Handle clicking on the healing AOE action button
func _on_action_healing_aoe_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var action_healing_aoe = $Action/ActionMargin/ActionHBox/ActionHealingAOE
		# If button is disabled, don't process the click
		if action_healing_aoe.disabled:
			return
			
		# If we have a current player, try to use the healing ability
		if current_player and current_player is WizardPlayer and current_player.abilities.has("healing_aoe"):
			# Get the GameController to set the current ability
			var game_controller = get_node("/root").find_child("GameController", true, false)
			if game_controller:
				print("HUD: Setting current ability to healing_aoe")
				game_controller.current_ability = "healing_aoe"
				# Highlight AOE targets for healing - uses same method as fireball now
				if current_player.has_method("highlight_aoe_targets"):
					current_player.highlight_aoe_targets()
				# Update button state
				action_healing_aoe.modulate = Color(1, 0.5, 0.5, 1)  # Highlight button
				update_action_buttons()  # Update other buttons

# Handle clicking on the freeze AOE action button
func _on_action_freeze_aoe_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var action_freeze_aoe = $Action/ActionMargin/ActionHBox/ActionFreezeAOE
		# If button is disabled, don't process the click
		if action_freeze_aoe.disabled:
			return
			
		# If we have a current player, try to use the freeze ability
		if current_player and current_player is WizardPlayer and current_player.abilities.has("freeze_aoe"):
			# Get the GameController to set the current ability
			var game_controller = get_node("/root").find_child("GameController", true, false)
			if game_controller:
				print("HUD: Setting current ability to freeze_aoe")
				game_controller.current_ability = "freeze_aoe"
				# Highlight AOE targets for freezing - uses same method as fireball now
				if current_player.has_method("highlight_aoe_targets"):
					current_player.highlight_aoe_targets()
				# Update button state
				action_freeze_aoe.modulate = Color(1, 0.5, 0.5, 1)  # Highlight button
				update_action_buttons()  # Update other buttons

# Handle clicking on the poison AOE action button
func _on_action_poison_aoe_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var action_poison_aoe = $Action/ActionMargin/ActionHBox/ActionPoisonAOE
		# If button is disabled, don't process the click
		if action_poison_aoe.disabled:
			return
			
		# If we have a current player, try to use the poison ability
		if current_player and current_player is WizardPlayer and current_player.abilities.has("poison_aoe"):
			# Get the GameController to set the current ability
			var game_controller = get_node("/root").find_child("GameController", true, false)
			if game_controller:
				print("HUD: Setting current ability to poison_aoe")
				game_controller.current_ability = "poison_aoe"
				# Highlight AOE targets for poison - uses same method as fireball now
				if current_player.has_method("highlight_aoe_targets"):
					current_player.highlight_aoe_targets()
				# Update button state
				action_poison_aoe.modulate = Color(1, 0.5, 0.5, 1)  # Highlight button
				update_action_buttons()  # Update other buttons

# Handle input events for right-click and escape key
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_current_ability()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_current_ability()

# Helper function to cancel the current ability
func _cancel_current_ability() -> void:
	var game_controller = get_node("/root").find_child("GameController", true, false)
	if game_controller and game_controller.current_ability != "":
		print("HUD: Canceling current ability via right-click or escape key")
		game_controller.cancel_current_ability()
		
		# Reset all ability button appearances
		var action_drill = $Action/ActionMargin/ActionHBox/ActionDrill
		var action_drill_smash = $Action/ActionMargin/ActionHBox/ActionDrillSmash
		var action_line_shot = $Action/ActionMargin/ActionHBox/ActionLineShot
		var action_fireball = $Action/ActionMargin/ActionHBox/ActionFireball
		var action_cloak = $Action/ActionMargin/ActionHBox/ActionCloak
		var action_defend = $Action/ActionMargin/ActionHBox/ActionDefend
		var action_big_drill = $Action/ActionMargin/ActionHBox/ActionBigDrill
		var action_charge_attack = $Action/ActionMargin/ActionHBox/ActionChargeAttack
		var action_emergency_teleport = $Action/ActionMargin/ActionHBox/ActionEmergencyTeleport
		var action_healing_aoe = $Action/ActionMargin/ActionHBox/ActionHealingAOE
		var action_freeze_aoe = $Action/ActionMargin/ActionHBox/ActionFreezeAOE
		var action_poison_aoe = $Action/ActionMargin/ActionHBox/ActionPoisonAOE
		
		# Reset all buttons to normal state
		action_drill.modulate = Color(1, 1, 1, 1)
		action_drill_smash.modulate = Color(1, 1, 1, 1)
		action_line_shot.modulate = Color(1, 1, 1, 1)
		action_fireball.modulate = Color(1, 1, 1, 1)
		action_cloak.modulate = Color(1, 1, 1, 1)
		action_defend.modulate = Color(1, 1, 1, 1)
		action_big_drill.modulate = Color(1, 1, 1, 1)
		action_charge_attack.modulate = Color(1, 1, 1, 1)
		action_emergency_teleport.modulate = Color(1, 1, 1, 1)
		action_healing_aoe.modulate = Color(1, 1, 1, 1)
		action_freeze_aoe.modulate = Color(1, 1, 1, 1)
		action_poison_aoe.modulate = Color(1, 1, 1, 1)
		
		# Update all buttons to reflect the current state
		update_action_buttons()
