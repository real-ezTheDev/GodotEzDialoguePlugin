@tool
extends EditorPlugin

const MainPanel = preload("res://addons/ez_dialogue/main_screen/main.tscn")
const PLUGIN_NAME = "EzDialogue"
const DIALOGUE_NODE_NAME = "EzDialogue"
const ICON = preload("icon.png")
const EzdExportPlugin = preload("ezd_export_plugin.gd")

var main_panel_instance: MainDiagPanel
var _export_plugin: EditorExportPlugin

func _enter_tree():
	add_custom_type(DIALOGUE_NODE_NAME, "Node", preload("ez_dialogue_node.gd"), ICON)

	# Auto-bundle .ezd files into exports so consumers don't need an include filter.
	_export_plugin = EzdExportPlugin.new()
	add_export_plugin(_export_plugin)

	main_panel_instance = MainPanel.instantiate()

	# Add the main panel to the editor's main viewport.
	get_editor_interface().get_editor_main_screen().add_child(main_panel_instance)

	# Hide the main panel
	_make_visible(false)

func _exit_tree():
	remove_custom_type(DIALOGUE_NODE_NAME)
	if _export_plugin:
		remove_export_plugin(_export_plugin)
		_export_plugin = null
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
