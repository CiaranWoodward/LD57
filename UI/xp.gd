extends CanvasLayer

var current_xp : int = 0
var total_xp : int = 0

#Returns current XP
func get_xp() -> int :
	return current_xp


func get_total_xp() -> int :
	return total_xp


func update_xp() -> void :
	$XPMargin/XPPanel/XPLabelMargin/XPHBox/XPValLabel.text = str(current_xp)


#Adds to current XP (negative numbers allowed). Returns 0 on success, 1 if unaffordable
func add_xp(amount) -> int :
	
	#Add all earned XP to total:
	if (amount > 0) :
		total_xp += amount

	#No change if trying to spend more than balance:
	if (current_xp + amount <0) :
		return 1
	else :
		current_xp += amount
		update_xp()
		return 0


func reset_xp() -> void :
	current_xp = 0
	total_xp = 0
	update_xp()
