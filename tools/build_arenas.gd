extends SceneTree
## Genera las pantallas arcade fijas (Arena) de las fases a partir de los diseños de abajo.
## Uso:  godot --headless --path . -s tools/build_arenas.gd
##
## Cada pantalla es una arena cerrada de 960x720 que se ve completa (sin cámara que siga):
## franja del marcador arriba (0–48), techo, paredes laterales, suelo y pisos de plataformas
## separados 112 px (el salto alcanza ~132 px). Escenario con colores provisionales del
## Mundo 1 «Isla Palmera»; los tiles definitivos llegan en la fase de Mundo 1.

const ARENA := Vector2(960, 720)
const HUD_H := 48.0
const CEIL_H := 16.0
const WALL_W := 24.0
const FLOOR_Y := 672.0
const PLATFORM_H := 16.0

const SKY := Color(0.53, 0.82, 0.97)
const SEA := Color(0.16, 0.55, 0.85)
const SAND := Color(0.9, 0.78, 0.52)
const SAND_DARK := Color(0.78, 0.64, 0.4)
const ROCK := Color(0.45, 0.44, 0.5)
const WOOD := Color(0.6, 0.4, 0.2)
const WOOD_EDGE := Color(0.42, 0.26, 0.12)

## Diseños: plataformas atravesables (x0, x1, y), bloques sólidos (Rect2) y marcadores.
const SCREENS := {
	"res://scenes/stages/world_01/World01_Stage01_A.tscn": {
		"name": "World01_Stage01_A", "role": "A", "title": "1-1  PANTALLA A",
		"platforms": [[24, 300, 560], [660, 936, 560], [330, 630, 448],
			[24, 260, 336], [700, 936, 336], [280, 680, 224]],
		"blocks": [Rect2(452, 624, 56, 48)],
		"objects": [["barrel", Vector2(330, 652)], ["barrel", Vector2(820, 540)], ["crate", Vector2(250, 560)],
			["crate", Vector2(140, 336)], ["stone_block", Vector2(480, 224)]],
		"p1": Vector2(120, 672), "p2": Vector2(840, 672),
	},
	"res://scenes/stages/world_01/World01_Stage01_B.tscn": {
		"name": "World01_Stage01_B", "role": "B", "title": "1-1  PANTALLA B",
		"platforms": [[250, 710, 560], [24, 330, 448], [630, 936, 448],
			[330, 630, 336], [24, 250, 224], [710, 936, 224]],
		"blocks": [Rect2(24, 624, 64, 48), Rect2(872, 624, 64, 48)],
		"objects": [["barrel", Vector2(480, 540)], ["crate", Vector2(120, 448)], ["crate", Vector2(840, 448)],
			["stone_block", Vector2(480, 336)]],
		"p1": Vector2(150, 672), "p2": Vector2(810, 672),
	},
}

var arena_root: Node2D


func _initialize() -> void:
	var ok := true
	for path in SCREENS:
		ok = _build(path, SCREENS[path]) and ok
	quit(0 if ok else 1)


func _build(path: String, d: Dictionary) -> bool:
	arena_root = Node2D.new()
	arena_root.name = d["name"]
	arena_root.set_script(load("res://scripts/arena/arena.gd"))
	arena_root.set("screen_role", d["role"])

	_background(d["title"])
	var solid := _body("Geometry", 1)
	# Techo bajo el marcador, paredes y suelo: arena cerrada.
	_rect_solid(solid, Rect2(0, HUD_H, ARENA.x, CEIL_H), ROCK)
	_rect_solid(solid, Rect2(0, HUD_H, WALL_W, ARENA.y - HUD_H), ROCK)
	_rect_solid(solid, Rect2(ARENA.x - WALL_W, HUD_H, WALL_W, ARENA.y - HUD_H), ROCK)
	_rect_solid(solid, Rect2(0, FLOOR_Y, ARENA.x, ARENA.y - FLOOR_Y), SAND)
	_poly(solid, Rect2(WALL_W, FLOOR_Y, ARENA.x - WALL_W * 2, 8), SAND_DARK)
	for r in d["blocks"]:
		_rect_solid(solid, r, ROCK)

	var platforms := _body("Platforms", 1 << 5)
	for p in d["platforms"]:
		_platform(platforms, Rect2(p[0], p[2], p[1] - p[0], PLATFORM_H))

	var pool := Node2D.new()
	pool.name = "BombPool"
	pool.set_script(load("res://scripts/bombs/bomb_pool.gd"))
	_add(pool, arena_root)

	var enemies := Node2D.new()
	enemies.name = "Enemies"
	enemies.set_script(load("res://scripts/arena/enemy_manager.gd"))
	_add(enemies, arena_root)

	var items := Node2D.new()
	items.name = "Items"
	_add(items, arena_root)
	# Barriles y objetos destruibles (barril: origen en el centro; caja/bloque: en la base).
	var counts := {}
	for o in d.get("objects", []):
		var kind: String = o[0]
		counts[kind] = counts.get(kind, 0) + 1
		var node: Node2D
		if kind == "barrel":
			node = (load("res://scenes/objects/Barrel.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		else:
			node = (load("res://scenes/objects/Destructible.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
			node.set("data", load("res://data/destructibles/%s.tres" % kind))
		node.name = "%s%d" % [kind.to_pascal_case(), counts[kind]]
		node.position = o[1]
		_add(node, items)

	var spawner := Node2D.new()
	spawner.name = "PlayerSpawner"
	spawner.set_script(load("res://scripts/worlds/player_spawner.gd"))
	_add(spawner, arena_root)
	for m in [["P1", d["p1"]], ["P2", d["p2"]]]:
		var marker := Marker2D.new()
		marker.name = m[0]
		marker.position = m[1]
		_add(marker, spawner)

	var cam := Camera2D.new()
	cam.name = "ArcadeCamera"
	cam.set_script(load("res://scripts/arena/arcade_camera.gd"))
	_add(cam, arena_root)

	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://scripts/arena/arcade_hud.gd"))
	_add(hud, arena_root)

	var packed := PackedScene.new()
	var err := packed.pack(arena_root)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		err = ResourceSaver.save(packed, path)
	print("%s: %s" % [path, error_string(err)])
	arena_root.free()
	return err == OK


func _add(node: Node, parent: Node) -> void:
	parent.add_child(node)
	node.owner = arena_root


func _background(title: String) -> void:
	var bg := Node2D.new()
	bg.name = "Background"
	bg.z_index = -10
	_add(bg, arena_root)
	_poly(bg, Rect2(0, 0, ARENA.x, ARENA.y), SKY)
	_poly(bg, Rect2(0, 470, ARENA.x, ARENA.y - 470), SEA)
	# Sol y un par de palmeras provisionales (formas simples).
	var sun := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 24:
		pts.append(Vector2(820, 150) + Vector2.from_angle(TAU * i / 24.0) * 38.0)
	sun.polygon = pts
	sun.color = Color(1.0, 0.93, 0.6)
	_add(sun, bg)
	for x in [150.0, 800.0]:
		_poly(bg, Rect2(x - 7, 470, 14, 202), Color(0.55, 0.38, 0.2))
		var leaf := Polygon2D.new()
		leaf.polygon = PackedVector2Array([Vector2(x - 70, 480), Vector2(x, 450), Vector2(x + 70, 480),
			Vector2(x + 30, 470), Vector2(x, 462), Vector2(x - 30, 470)])
		leaf.color = Color(0.2, 0.6, 0.25)
		_add(leaf, bg)
	var label := Label.new()
	label.text = title
	label.position = Vector2(WALL_W + 12, HUD_H + CEIL_H + 6)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.1, 0.2, 0.35, 0.6))
	_add(label, bg)


func _body(body_name: String, layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = layer
	body.collision_mask = 0
	_add(body, arena_root)
	return body


func _rect_solid(body: StaticBody2D, r: Rect2, color: Color) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	_add(cs, body)
	_poly(body, r, color)


func _platform(body: StaticBody2D, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	cs.one_way_collision = true
	_add(cs, body)
	_poly(body, r, WOOD)
	_poly(body, Rect2(r.position.x, r.end.y - 4, r.size.x, 4), WOOD_EDGE)


func _poly(parent: Node, r: Rect2, color: Color) -> void:
	var p := Polygon2D.new()
	p.color = color
	p.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	_add(p, parent)
