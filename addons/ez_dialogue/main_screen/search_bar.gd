@tool
extends Panel

@onready var not_found_warn_lbl = $MarginContainer/HBoxContainer/NotFoundLbl

func warn_not_found():
	not_found_warn_lbl.text = "Not Found!"
	not_found_warn_lbl.add_theme_color_override("font_color", Color(0.8, 0.19, 0.0))
	not_found_warn_lbl.visible = true

func set_result_count(total: int, current: int = 0):
	if current > 0:
		not_found_warn_lbl.text = "%d/%d found" % [current, total]
	else:
		not_found_warn_lbl.text = "%d found" % total
	not_found_warn_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	not_found_warn_lbl.visible = true

func clear_warn():
	not_found_warn_lbl.visible = false
	not_found_warn_lbl.remove_theme_color_override("font_color")
