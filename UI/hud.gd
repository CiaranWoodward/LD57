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

# Reference to the current active player
var current_player: PlayerEntity = null

# Drilling visualization
var is_hovering_drill_button: bool = false
var is_hovering_drill_smash_button: bool = false
var is_hovering_line_shot_button: bool = false

func _ready() -> void:
	Global.hud = self
	
	# Connect action buttons
	var action_drill = $Action/ActionMargin/ActionHBox/ActionDrill
	if action_drill:
		action_drill.gui_input.connect(_on_action_drill_input)
		# Connect to mouse enter/exit for hover detection
		action_drill.mouse_entered.connect(_on_action_drill_mouse_entered)
		action_drill.mouse_exited.connect(_on_action_drill_mouse_exited)
	
	# Connect drill smash button
	var action_drill_smash = $Action/ActionMargin/ActionHBox/ActionDrillSmash
	if action_drill_smash:
		action_drill_smash.gui_input.connect(_on_action_drill_smash_input)
		# Connect to mouse enter/exit for hover detection
		action_drill_smash.mouse_entered.connect(_on_action_drill_smash_mouse_entered)
		action_drill_smash.mouse_exited.connect(_on_action_drill_smash_mouse_exited)
	
	# Connect line shot button
	var action_line_shot = $Action/ActionMargin/ActionHBox/ActionLineShot
	if action_line_shot:
		action_line_shot.gui_input.connect(_on_action_line_shot_input)
		# Connect to mouse enter/exit for hover detection
		action_line_shot.mouse_entered.connect(_on_action_line_shot_mouse_entered)
		action_line_shot.mouse_exited.connect(_on_action_line_shot_mouse_exited)
	
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

# Show drill path when hovering over drill button
func _on_action_drill_mouse_entered() -> void:
	is_hovering_drill_button = true
	var action_drill = $Action/ActionMargin/ActionHBox/ActionDrill
	# Only show hover effect if button is not disabled
	if action_drill and not action_drill.disabled and current_player and current_player.abilities.has("drill"):
		print("HUD: Showing drill hover effect")
		DrillButtonHovered.emit(current_player)

# Hide drill path when no longer hovering over drill button
func _on_action_drill_mouse_exited() -> void:
	is_hovering_drill_button = false
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
			if current_player is HeavyPlayer:
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
	is_hovering_drill_smash_button = true
	var action_drill_smash = $Action/ActionMargin/ActionHBox/ActionDrillSmash
	# Only show hover effect if button is not disabled
	if action_drill_smash and not action_drill_smash.disabled and current_player and current_player.abilities.has("drill_smash") and current_player is HeavyPlayer:
		print("HUD: Showing drill_smash hover effect")
		DrillSmashButtonHovered.emit(current_player)
		current_player.highlight_drill_smash_targets()

# Hide drill smash targets when no longer hovering over drill smash button
func _on_action_drill_smash_mouse_exited() -> void:
	is_hovering_drill_smash_button = false
	
	# Only emit the unhover signal if we're not in drill_smash ability selection mode
	var game_controller = get_node("/root").find_child("GameController", true, false)
	if game_controller and game_controller.current_ability != "drill_smash":
		DrillSmashButtonUnhovered.emit()
	else:
		print("HUD: Keeping drill_smash highlights active since ability is selected")

# Handle clicking on the line shot action button
func _on_action_line_shot_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var action_line_shot = $Action/ActionMargin/ActionHBox/ActionLineShot
		# If button is disabled, don't process the click
		if action_line_shot.disabled:
			return
			
		# If we have a current player, check if they have the ability and highlight targets
		if current_player and current_player.abilities.has("line_shot"):
			if current_player is ScoutPlayer:
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
	is_hovering_line_shot_button = true
	var action_line_shot = $Action/ActionMargin/ActionHBox/ActionLineShot
	# Only show hover effect if button is not disabled
	if action_line_shot and not action_line_shot.disabled and current_player and current_player.abilities.has("line_shot") and current_player is ScoutPlayer:
		print("HUD: Showing line_shot hover effect")
		LineShotButtonHovered.emit(current_player)
		current_player.highlight_line_shot_targets()

# Hide line shot targets when no longer hovering over line shot button
func _on_action_line_shot_mouse_exited() -> void:
	is_hovering_line_shot_button = false
	
	# Only emit the unhover signal if we're not in line_shot ability selection mode
	var game_controller = get_node("/root").find_child("GameController", true, false)
	if game_controller and game_controller.current_ability != "line_shot":
		LineShotButtonUnhovered.emit()
	else:
		print("HUD: Keeping line_shot highlights active since ability is selected")

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
	
	# Reset specific button based on which ability was used
	match ability_name:
		"drill":
			action_drill.modulate = Color(1, 1, 1, 1)
		"drill_smash":
			action_drill_smash.modulate = Color(1, 1, 1, 1)
		"line_shot":
			action_line_shot.modulate = Color(1, 1, 1, 1)
	
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
		if current_player.is_connected("ability_used", Callable(self, "_on_player_ability_used")):
			current_player.disconnect("ability_used", Callable(self, "_on_player_ability_used"))
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
func update_action_buttons() -> void:
	# Get all action buttons
	var action_drill = $Action/ActionMargin/ActionHBox/ActionDrill
	var action_drill_smash = $Action/ActionMargin/ActionHBox/ActionDrillSmash
	var action_line_shot = $Action/ActionMargin/ActionHBox/ActionLineShot
	
	# Get current selected ability if any
	var game_controller = get_node("/root").find_child("GameController", true, false)
	var current_ability = ""
	if game_controller:
		current_ability = game_controller.current_ability
	
	if current_player:
		print("HUD: Updating action buttons for player " + current_player.entity_name + 
			", AP: " + str(current_player.action_points) + "/" + str(current_player.max_action_points))
			
		# Force immediate visibility before checking conditions
		action_drill.visible = true
		action_drill_smash.visible = true
		action_line_shot.visible = true
	
		# Drill ability - available to all players
		if current_player.abilities.has("drill") and not current_player.is_drilling:
			action_drill.visible = true
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
		
		# Drill Smash ability - only for HeavyPlayer
		if current_player.abilities.has("drill_smash") and current_player is HeavyPlayer and not current_player.is_drilling:
			action_drill_smash.visible = true
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
		if current_player.abilities.has("line_shot") and current_player is ScoutPlayer and not current_player.is_drilling:
			action_line_shot.visible = true
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
	else:
		# No active player, hide all buttons
		action_drill.visible = false
		action_drill.disabled = true
		action_drill_smash.visible = false
		action_drill_smash.disabled = true
		action_line_shot.visible = false
		action_line_shot.disabled = true
		print("HUD: Hiding all ability buttons - no active player")
