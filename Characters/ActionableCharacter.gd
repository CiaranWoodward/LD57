class_name ActionableCharacter
extends Node2D

signal turn_finished(character)
signal turn_started(character)

var is_turn_active: bool = false

# Called by the TurnSequencer to start this character's turn
func start_turn():
	print(self.name + ": Starting turn")
	is_turn_active = true
	emit_signal("turn_started", self)
	
	# Subclasses should override this method to implement their turn logic
	# and call finish_turn() when done

# Called when this character's turn is complete
func finish_turn():
	if not is_turn_active:
		return
		
	print(self.name + ": Finishing turn")
	is_turn_active = false
	emit_signal("turn_finished", self)
