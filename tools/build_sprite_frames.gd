extends SceneTree
## Construye un SpriteFrames por personaje a partir de su manifest.json.
## Uso (después de importar los PNG):
##   godot --headless --path . --import
##   godot --headless --path . -s tools/build_sprite_frames.gd
## Recorre assets/characters/*/manifest.json y guarda <personaje>_frames.tres al lado.

const CHARACTERS_DIR := "res://assets/characters"


func _initialize() -> void:
	var dir := DirAccess.open(CHARACTERS_DIR)
	if dir == null:
		push_error("No existe %s" % CHARACTERS_DIR)
		quit(1)
		return
	var built := 0
	for folder in dir.get_directories():
		var base := CHARACTERS_DIR.path_join(folder)
		var manifest_path := base.path_join("manifest.json")
		if not FileAccess.file_exists(manifest_path):
			continue
		if _build(base, folder, manifest_path):
			built += 1
	print("SpriteFrames generados: %d" % built)
	quit(0 if built > 0 else 1)


func _build(base: String, folder: String, manifest_path: String) -> bool:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary:
		push_error("Manifest inválido: %s" % manifest_path)
		return false
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var animations: Dictionary = manifest["animations"]
	for anim_name in animations:
		var data: Dictionary = animations[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(data["fps"]))
		frames.set_animation_loop(anim_name, bool(data["loop"]))
		for rel in data["frames"]:
			var tex := load(base.path_join(rel)) as Texture2D
			if tex == null:
				push_error("Falta el fotograma %s (¿ejecutaste --import?)" % base.path_join(rel))
				return false
			frames.add_frame(anim_name, tex)
	var out := base.path_join("%s_frames.tres" % folder)
	var err := ResourceSaver.save(frames, out)
	print("  %s: %d animaciones -> %s (%s)" % [folder, animations.size(), out, error_string(err)])
	return err == OK
