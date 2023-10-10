extends Node2D

signal roll_finished(roll_result)

func roll(category: String, dc: int):
	visible = true
	$DCNumber.text = str(dc)
	$CheckName.text = category + " Check"

func _on_button_pressed():
	roll_finished.emit(randi_range(1,20))
	visible = false
