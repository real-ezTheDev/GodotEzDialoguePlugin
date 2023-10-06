@tool
extends EditorPlugin

const MainPanel = preload("res://addons/ez_dialogue/main_screen/main.tscn")
const PLUGIN_NAME = "EzDialogue"
const DIALOGUE_NODE_NAME = "EzDialogue"
const ICON = preload("icon.png")

var main_panel_instance: MainDiagPanel

func _enter_tree():
	add_custom_type(DIALOGUE_NODE_NAME, "Node", preload("ez_dialogue_node.gd"), ICON)

	main_panel_instance = MainPanel.instantiate()
	
	# Add the main panel to the editor's main viewport.
	get_editor_interface().get_editor_main_screen().add_child(main_panel_instance)

	# Hide the main panel
	_make_visible(false)

func _exit_tree():
	remove_custom_type(DIALOGUE_NODE_NAME)
	if main_panel_instance:
		main_panel_instance.queue_free()

func _ready():
	pass

func _has_main_screen():
	return true

func _make_visible(visible):
	if main_panel_instance:
		main_panel_instance.visible = visible

func _get_plugin_name():
	return PLUGIN_NAME
	
func _get_plugin_icon():
	return ICON

func _save_external_data():
	main_panel_instance.save()
