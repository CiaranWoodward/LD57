extends CanvasLayer

var current_xp : int = 0

#Returns current XP
func get_xp() -> int :
	return current_xp
	
#Adds to current XP (negative numbers allowed). Returns 0 on success, 1 if unaffordable
func add_xp(amount) -> int :
	if (current_xp + amount <0) :
		return 1
	else :
		current_xp += amount
		$XPMargin/XPPanel/XPLabelMargin/XPHBox/XPValLabel.text = str(current_xp)
		return 0
	
