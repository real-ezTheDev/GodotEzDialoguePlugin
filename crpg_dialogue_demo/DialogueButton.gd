class_name DialogueButton extends Button

var choice_id = -1
signal dialogue_selected(choice_id: int)

func _on_pressed():
	dialogue_selected.emit(choice_id)
