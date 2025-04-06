extends CanvasLayer

signal back_pressed
signal music_vol_changed(volume)
signal sfx_vol_changed(volume)


func _on_button_pressed() -> void:
	back_pressed.emit()


func _on_h_slider_value_changed(value: float) -> void:
	music_vol_changed.emit($OptionsMargin/OptionsVBox/MusicVolVBox/MusicVolHSlider.value)


func _on_sfx_vol_h_slider_value_changed(value: float) -> void:
	sfx_vol_changed.emit($OptionsMargin/OptionsVBox/SFXVolVBox/SFXVolHSlider.value)
