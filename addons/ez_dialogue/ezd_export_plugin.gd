@tool
extends EditorExportPlugin
## Bundles every .ezd file in the project into the export PCK automatically, so
## games using EzDialogue don't have to add "*.ezd" to their export preset's
## include filter.
##
## .ezd files are parsed at runtime from their path via FileAccess (they are not
## imported Godot resources), so Godot's exporter would otherwise strip them as
## non-resource files — making dialogue silently fail to load in exported builds.
## Registered by the EzDialogue EditorPlugin while it is enabled.


func _get_name() -> String:
	return "EzDialogueEzdBundler"


## Inject all .ezd files at the start of every export.
func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	_bundle_ezd_files("res://")


func _bundle_ezd_files(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			# Skip the import cache; recurse everything else.
			if entry != "." and entry != ".." and entry != ".godot":
				_bundle_ezd_files(full_path)
		elif entry.get_extension().to_lower() == "ezd":
			var file := FileAccess.open(full_path, FileAccess.READ)
			if file:
				add_file(full_path, file.get_buffer(file.get_length()), false)
		entry = dir.get_next()
	dir.list_dir_end()
