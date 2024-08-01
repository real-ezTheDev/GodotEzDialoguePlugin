@tool
extends Panel

@onready var not_found_warn_lbl = $MarginContainer/HBoxContainer/NotFoundLbl

func warn_not_found():
	not_found_warn_lbl.visible = true

func clear_warn():
	not_found_warn_lbl.visible = false
