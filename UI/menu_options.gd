extends CanvasLayer

signal back_pressed
signal vol_changed(volume)


func _on_button_pressed() -> void:
	back_pressed.emit()


func _on_h_slider_value_changed(value: float) -> void:
	vol_changed.emit($OptionsMargin/OptionsVBox/MusicVolVBox/MusicVolHSlider.value)
