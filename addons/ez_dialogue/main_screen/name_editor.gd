@tool
extends LineEdit

signal name_changed(old_text: String, new_text: String)

@onready var old_text = ""

func load_field(_text: String):
	set_text(_text)
	old_text = _text

func _on_text_changed(new_text):
	name_changed.emit(old_text, new_text)
	old_text = new_text
