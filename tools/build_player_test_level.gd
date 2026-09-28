extends SceneTree
## Genera scenes/worlds/test_level/PlayerTestLevel.tscn (nivel de prueba del jugador).
## Uso:  godot --headless --path . -s tools/build_player_test_level.gd
## La geometría usa placeholders de color; se sustituirá por tiles del Mundo 1 en la Fase 7.

const OUT := "res://scenes/worlds/test_level/PlayerTestLevel.tscn"
const GROUND_TOP := 640.0
const LEVEL_BOTTOM := 760.0
const LEVEL_WIDTH := 2700.0

const SAND := Color(0.87, 0.74, 0.5)
const GRASS := Color(0.36, 0.7, 0.3)
const WOOD := Color(0.62, 0.42, 0.22)
const STONE := Color(0.56, 0.56, 0.62)

var level_root: Node2D


func _initialize() -> void:
	level_root = Node2D.new()
	level_root.name = "PlayerTestLevel"
	level_root.set_script(load("res://scripts/worlds/player_test_level.gd"))

	_background()
	var solid := _body("Solid", 1)
	# Suelo con un vacío entre x=1500 y x=1650.
	_solid_rect(solid, Rect2(0, GROUND_TOP, 1500, LEVEL_BOTTOM - GROUND_TOP), true)
	_solid_rect(solid, Rect2(1650, GROUND_TOP, LEVEL_WIDTH - 1650, LEVEL_BOTTOM - GROUND_TOP), true)
	# Paredes laterales.
	_solid_rect(solid, Rect2(-40, -400, 40, 1160), false)
	_solid_rect(solid, Rect2(LEVEL_WIDTH, -400, 40, 1160), false)
	# Escalón para saltar.
	_solid_rect(solid, Rect2(1000, GROUND_TOP - 60, 128, 60), true)
	# Techo bajo: hueco de 48 px, solo se pasa agachado o deslizándose.
	_solid_rect(solid, Rect2(1900, 470, 300, 122), false)

	var platforms := _body("Platforms", 1 << 5)
	for r in [Rect2(250, 540, 192, 16), Rect2(520, 440, 256, 16), Rect2(840, 340, 160, 16),
			Rect2(1220, 400, 260, 16), Rect2(2300, 520, 220, 16)]:
		_platform(platforms, r)

	var ladder := (load("res://scenes/objects/Ladder.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	ladder.name = "Ladder"
	ladder.position = Vector2(1300, GROUND_TOP)
	ladder.set("height", GROUND_TOP - 400.0)
	_add(ladder, level_root)

	for s in [["Plataformas: abajo + saltar para bajar", Vector2(260, 470)],
			["Escalera: arriba / abajo", Vector2(1225, 330)],
			["Vacío", Vector2(1540, 560)],
			["Túnel: corre y agáchate para deslizarte", Vector2(1860, 420)],
			["Meta de prueba", Vector2(2560, 560)]]:
		var l := Label.new()
		l.text = s[0]
		l.position = s[1]
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", Color(0.1, 0.18, 0.3))
		_add(l, level_root)

	var player := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.position = Vector2(160, GROUND_TOP)
	_add(player, level_root)
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.position = Vector2(0, -80)
	cam.limit_left = -40
	cam.limit_right = int(LEVEL_WIDTH) + 40
	cam.limit_top = -200
	cam.limit_bottom = int(LEVEL_BOTTOM)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	_add(cam, player)

	var hud := CanvasLayer.new()
	hud.name = "DebugLayer"
	_add(hud, level_root)
	var label := Label.new()
	label.name = "DebugLabel"
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.2))
	label.add_theme_constant_override("outline_size", 6)
	_add(label, hud)
	var help := Label.new()
	help.name = "HelpLabel"
	help.text = "Mover: A/D o flechas · Saltar: Espacio/W · Agacharse: S · Esc: salir"
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 16.0
	help.offset_top = -40.0
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.2))
	help.add_theme_constant_override("outline_size", 6)
	_add(help, hud)

	var packed := PackedScene.new()
	var err := packed.pack(level_root)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
		err = ResourceSaver.save(packed, OUT)
	print("PlayerTestLevel: ", error_string(err))
	level_root.free()
	quit(0 if err == OK else 1)


func _add(node: Node, parent: Node) -> void:
	parent.add_child(node)
	node.owner = level_root


func _background() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Background"
	layer.layer = -10
	_add(layer, level_root)
	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.color = Color(0.52, 0.8, 0.96)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_add(sky, layer)
	var sea := ColorRect.new()
	sea.name = "Sea"
	sea.color = Color(0.2, 0.55, 0.85)
	sea.anchor_top = 0.62
	sea.anchor_right = 1.0
	sea.anchor_bottom = 1.0
	_add(sea, layer)


func _body(body_name: String, layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = layer
	body.collision_mask = 0
	_add(body, level_root)
	return body


func _solid_rect(body: StaticBody2D, r: Rect2, grass_top: bool) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	_add(cs, body)
	_poly(body, r, SAND if grass_top else STONE)
	if grass_top:
		_poly(body, Rect2(r.position, Vector2(r.size.x, 12)), GRASS)


func _platform(body: StaticBody2D, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	cs.one_way_collision = true
	_add(cs, body)
	_poly(body, r, WOOD)


func _poly(parent: Node, r: Rect2, color: Color) -> void:
	var p := Polygon2D.new()
	p.color = color
	p.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	_add(p, parent)
