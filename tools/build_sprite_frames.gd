extends SceneTree
## Construye un SpriteFrames por personaje (y por tipo de bomba) a partir de su manifest.json.
## Uso (después de importar los PNG):
##   godot --headless --path . --import
##   godot --headless --path . -s tools/build_sprite_frames.gd
## Recorre assets/characters/, assets/bombs/ y assets/enemies/ (*/manifest.json) y guarda
## <carpeta>_frames.tres al lado.

const CHARACTERS_DIR := "res://assets/characters"
const SOURCE_DIRS: Array[String] = ["res://assets/characters", "res://assets/bombs", "res://assets/enemies"]


func _initialize() -> void:
	var built := 0
	for root_dir in SOURCE_DIRS:
		var dir := DirAccess.open(root_dir)
		if dir == null:
			continue
		for folder in dir.get_directories():
			var base := root_dir.path_join(folder)
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
	# Datos de normalización: todos los fotogramas comparten lienzo (pies en el borde
	# inferior, centro del cuerpo en el centro). La altura de referencia es la del dibujo
	# visible del primer fotograma de idle; PlayerAnimator la usa para la escala global.
	var first_anim: StringName = &"idle" if frames.has_animation(&"idle") else frames.get_animation_names()[0]
	var first := frames.get_frame_texture(first_anim, 0)
	var canvas := Vector2i(first.get_width(), first.get_height())
	var reference_height := int(manifest.get("reference_height", 0))
	if reference_height <= 0:
		reference_height = first.get_image().get_used_rect().size.y
	var check_canvas := frames.has_animation(&"idle")
	for anim_name in frames.get_animation_names():
		if not check_canvas:
			break
		for i in frames.get_frame_count(anim_name):
			var t := frames.get_frame_texture(anim_name, i)
			if Vector2i(t.get_width(), t.get_height()) != canvas:
				push_error("%s/%s[%d]: el lienzo %dx%d no coincide con %s" % [folder, anim_name, i,
					t.get_width(), t.get_height(), canvas])
				return false
	frames.set_meta(&"canvas_size", canvas)
	frames.set_meta(&"reference_height", reference_height)
	for key in ["sphere_diameter", "explosion_diameter"]:
		if manifest.has(key):
			frames.set_meta(StringName(key), float(manifest[key]))
	var out := base.path_join("%s_frames.tres" % folder)
	var err := ResourceSaver.save(frames, out)
	print("  %s: %d animaciones, lienzo %s, altura de referencia %d -> %s (%s)" % [folder,
		animations.size(), canvas, reference_height, out, error_string(err)])
	return err == OK
