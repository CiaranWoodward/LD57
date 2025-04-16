extends CanvasLayer

# Returns current XP
func get_xp() -> int:
	return Global.xp

# Returns total XP earned (including spent XP)
func get_total_xp() -> int:
	return Global.total_xp_acquired

# Update the XP display
func update_xp() -> void:
	$XPMargin/XPPanel/XPLabelMargin/XPHBox/XPValLabel.text = str(Global.xp)

# Adds to XP (negative numbers allowed). Returns 0 on success, 1 if unaffordable
func add_xp(amount) -> int:
	# Use Global's add_xp functionality
	if amount < 0 && Global.xp + amount < 0:
		# Can't afford it
		return 1
	
	# Add the XP through Global
	Global.add_xp(amount)
	
	# No need to update UI here as Global's signal will trigger updates
	return 0

# Reset XP counters
func reset_xp() -> void:
	Global.reset_stats()

func _ready():
	# Connect to Global's XP changed signal to update the display
	Global.xp_changed.connect(_on_global_xp_changed)
	
	# Initial update
	update_xp()

# Handler for Global XP changes
func _on_global_xp_changed(_new_xp: int):
	update_xp()
