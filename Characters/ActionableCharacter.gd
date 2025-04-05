class_name ActionableCharacter

extends Node

signal on_turn_finished

func _init() -> void:
	var turn_sequencer = get_node("TurnSequencer")
	on_turn_finished.connect(turn_sequencer._on_turn_finished())

func start_turn():
	push_error("Cannot be called from abstract base class")

func finish_turn():
	push_error("Cannot be called from abstract base class")
	on_turn_finished.emit()
