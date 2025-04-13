@tool
extends PanelContainer

@export_multiline var ability_text: String = "Placeholder":
	set(value):
		ability_text = value
		if is_instance_valid($AbilityMargin/AbilityVBox/Label):
			$AbilityMargin/AbilityVBox/Label.text = value

@export var ability_name: String = "placeholder":
	set(value):
		ability_name = value

@export var ability_cost: int = 0:
	set(value):
		ability_cost = value
		if is_instance_valid($AbilityMargin/AbilityVBox/Cost):
			$AbilityMargin/AbilityVBox/Cost.text = str(value)
		if is_instance_valid($AbilityMargin/Button):
			_update_button_state()

@export_multiline var ability_tooltip: String = "Placeholder":
	set(value):
		ability_tooltip = value
		if is_instance_valid($AbilityMargin/Button):
			$AbilityMargin/Button.tooltip_text = value

var is_purchased: bool = false

signal button_pressed(button)

func _ready():
	$AbilityMargin/AbilityVBox/Label.text = ability_text
	$AbilityMargin/Button.tooltip_text = ability_tooltip
	$AbilityMargin/AbilityVBox/Cost.text = str(ability_cost)
	$AbilityMargin/Button.pressed.connect(_on_button_pressed)
	
	# Connect to Global's xp_changed signal
	Global.xp_changed.connect(_on_xp_changed)
	# Set initial button state
	_update_button_state()

func _on_button_pressed():
	if !is_purchased and Global.xp >= ability_cost:
		# Deduct XP
		Global.add_xp(-ability_cost)
		# Mark as purchased
		is_purchased = true
		# Update button appearance
		_update_button_state()
		# Emit the signal for any external handling
		button_pressed.emit(self)

func _on_xp_changed(_new_xp: int):
	_update_button_state()

func _update_button_state():
	if is_purchased:
		$AbilityMargin/Button.disabled = true
		$AbilityMargin/Button.text = "Purchased"
		$AbilityMargin/Button.modulate = Color(0.5, 0.7, 0.5)  # Gray out the button
	else:
		$AbilityMargin/Button.disabled = Global.xp < ability_cost
		$AbilityMargin/Button.text = "Purchase"
		$AbilityMargin/Button.modulate = Color(1, 1, 1)  # Reset to normal color
