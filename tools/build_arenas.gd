extends SceneTree
## Genera las pantallas arcade fijas (Arena) de las fases a partir de los diseños de abajo.
## Uso:  godot --headless --path . -s tools/build_arenas.gd
##
## Cada pantalla es una arena cerrada de 960x720 que se ve completa (sin cámara que siga):
## franja del marcador arriba (0–48), techo, paredes laterales, suelo y pisos de plataformas
## separados 112 px (el salto alcanza ~132 px). Arte del Mundo 1 «Isla Palmera» sacado de
## assets/worlds/world_01/ (tools/sprites/extract_tileset.py): fondo de isla y mar, tablones con
## musgo para las plataformas, suelo de arena con hierba, muros de piedra, rocas, postes y
## decoración. La colisión no depende del dibujo: son rectángulos exactos.

const ARENA := Vector2(960, 720)
const HUD_H := 48.0
const CEIL_H := 16.0
const WALL_W := 24.0
const FLOOR_Y := 672.0
const PLATFORM_H := 16.0

const ART := "res://assets/worlds/world_01/"
## Márgenes de los extremos de las piezas que se repiten en horizontal (NinePatch).
const PLANK_CAP := 14
const GROUND_CAP := 14

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
		# Enemigos: tipo, entrada, posición, retraso, intervalo, cantidad, máx. vivos, oleada.
		"spawners": [
			["small_crab", "LEFT", Vector2(0, 672), 1.5, 5.0, 2, 1, 1],
			["small_crab", "RIGHT", Vector2(960, 672), 3.0, 5.0, 2, 1, 1],
			["seagull", "POINT", Vector2(480, 150), 4.0, 6.0, 1, 1, 1],
			["hermit_crab", "TOP", Vector2(480, 0), 1.0, 4.0, 1, 1, 2],
			["small_octopus", "POINT", Vector2(820, 336), 2.0, 4.0, 1, 1, 2],
		],
		"decor": [["palm", Vector2(70, 672), 1.3], ["palm_2", Vector2(905, 672), 1.3, true],
			["sandcastle", Vector2(600, 672), 0.8], ["flag", Vector2(890, 336), 0.6],
			["bush", Vector2(470, 224), 0.7]],
		"front_decor": [["fern", Vector2(40, 676), 0.8], ["flowers", Vector2(230, 676), 0.8],
			["bush_flower", Vector2(760, 676), 0.8], ["rock_flat", Vector2(930, 678), 0.7]],
		"p1": Vector2(120, 672), "p2": Vector2(840, 672),
	},
	"res://scenes/stages/world_01/World01_Stage01_B.tscn": {
		"name": "World01_Stage01_B", "role": "B", "title": "1-1  PANTALLA B",
		"platforms": [[250, 710, 560], [24, 330, 448], [630, 936, 448],
			[330, 630, 336], [24, 250, 224], [710, 936, 224]],
		"blocks": [Rect2(24, 624, 64, 48), Rect2(872, 624, 64, 48)],
		"objects": [["barrel", Vector2(480, 540)], ["crate", Vector2(120, 448)], ["crate", Vector2(840, 448)],
			["stone_block", Vector2(480, 336)]],
		"spawners": [
			["small_crab", "TOP", Vector2(300, 0), 2.0, 6.0, 2, 1, 1],
			["seagull", "POINT", Vector2(700, 140), 5.0, 8.0, 1, 1, 1],
			["small_octopus", "POINT", Vector2(120, 224), 3.0, 6.0, 1, 1, 1],
		],
		"decor": [["palm_2", Vector2(120, 672), 1.25], ["palm", Vector2(850, 672), 1.25, true],
			["sign_arrow", Vector2(700, 224), 0.6], ["plant", Vector2(480, 560), 0.7],
			["rock", Vector2(620, 336), 0.8]],
		"front_decor": [["flowers", Vector2(300, 676), 0.8], ["fern", Vector2(690, 676), 0.8]],
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
	_decor(d.get("decor", []), -5)
	var solid := _body("Geometry", 1)
	# Techo bajo el marcador, paredes y suelo: arena cerrada.
	_rect_solid(solid, Rect2(0, HUD_H, ARENA.x, CEIL_H), "stone_tile")
	_rect_solid(solid, Rect2(0, HUD_H, WALL_W, ARENA.y - HUD_H), "stone_tile")
	_rect_solid(solid, Rect2(ARENA.x - WALL_W, HUD_H, WALL_W, ARENA.y - HUD_H), "stone_tile")
	_floor(solid, Rect2(0, FLOOR_Y, ARENA.x, ARENA.y - FLOOR_Y))
	for r in d["blocks"]:
		_rect_solid(solid, r, "rock_block", true)

	_supports(d["platforms"])
	var platforms := _body("Platforms", 1 << 5)
	for p in d["platforms"]:
		_platform(platforms, Rect2(p[0], p[2], p[1] - p[0], PLATFORM_H))
	_decor(d.get("front_decor", []), 4)

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

	var spawners := Node2D.new()
	spawners.name = "Spawners"
	_add(spawners, arena_root)
	var n := 0
	for sp in d.get("spawners", []):
		n += 1
		var es := Marker2D.new()
		es.set_script(load("res://scripts/enemies/enemy_spawner.gd"))
		es.name = "Spawner%d_%s" % [n, String(sp[0]).to_pascal_case()]
		es.position = sp[2]
		es.set("enemy_type", load("res://data/enemies/%s.tres" % sp[0]))
		es.set("entry", ["POINT", "LEFT", "RIGHT", "TOP"].find(sp[1]))
		es.set("spawn_delay", sp[3])
		es.set("interval", sp[4])
		es.set("count", sp[5])
		es.set("max_enemies", sp[6])
		es.set("wave", sp[7])
		_add(es, spawners)

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
	var sky := Sprite2D.new()
	sky.name = "Island"
	sky.texture = load(ART + "background.png")
	sky.centered = false
	_add(sky, bg)
	var label := Label.new()
	label.text = title
	label.position = Vector2(WALL_W + 12, HUD_H + CEIL_H + 6)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.2, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	_add(label, bg)


## Decoración sin colisión: [pieza, posición de la base (centro inferior), escala, volteada].
func _decor(items: Array, z: int) -> void:
	if items.is_empty():
		return
	var layer := Node2D.new()
	layer.name = "Decor" if z < 0 else "FrontDecor"
	layer.z_index = z
	_add(layer, arena_root)
	for it in items:
		var spr := Sprite2D.new()
		spr.texture = load(ART + "%s.png" % it[0])
		spr.centered = false
		var sc: float = it[2] if it.size() > 2 else 1.0
		spr.scale = Vector2(sc, sc)
		spr.flip_h = it.size() > 3 and it[3]
		spr.offset = Vector2(-spr.texture.get_width() * 0.5, -spr.texture.get_height())
		spr.position = it[1]
		_add(spr, layer)


## Postes bajo los extremos de las plataformas que no tienen nada debajo (andamios).
func _supports(platforms: Array) -> void:
	var layer := Node2D.new()
	layer.name = "Supports"
	layer.z_index = -6
	_add(layer, arena_root)
	var post := load(ART + "post_rope.png") as Texture2D
	for p in platforms:
		for x in [float(p[0]) + 18.0, float(p[1]) - 18.0]:
			if x < WALL_W + 10.0 or x > ARENA.x - WALL_W - 10.0:
				continue
			var top: float = p[2] + 20.0
			var bottom := FLOOR_Y
			for q in platforms:
				if q != p and x >= q[0] and x <= q[1] and q[2] > p[2]:
					bottom = minf(bottom, float(q[2]))
			var h := bottom - top
			if h < 30.0:
				continue
			var tr := TextureRect.new()
			tr.texture = post
			tr.stretch_mode = TextureRect.STRETCH_TILE
			var sc := 18.0 / post.get_width()
			tr.scale = Vector2(sc, sc)
			tr.size = Vector2(post.get_width(), h / sc)
			tr.position = Vector2(x - 9.0, top)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_add(tr, layer)


func _body(body_name: String, layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = layer
	body.collision_mask = 0
	_add(body, arena_root)
	return body


func _rect_solid(body: StaticBody2D, r: Rect2, piece: String, stretch := false) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	_add(cs, body)
	var tex := load(ART + "%s.png" % piece) as Texture2D
	var tr := TextureRect.new()
	tr.texture = tex
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if stretch:
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.size = r.size + Vector2(8, 6)
		tr.position = r.position - Vector2(4, 6)
	else:
		# Mosaico: la pieza se escala para que su lado corto encaje con el grosor del muro.
		var sc := minf(r.size.x, r.size.y) / minf(tex.get_width(), tex.get_height())
		sc = minf(sc, 0.6) if minf(r.size.x, r.size.y) > 30.0 else sc
		tr.stretch_mode = TextureRect.STRETCH_TILE
		tr.scale = Vector2(sc, sc)
		tr.size = r.size / sc
		tr.position = r.position
	_add(tr, body)


func _floor(body: StaticBody2D, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	_add(cs, body)
	var np := NinePatchRect.new()
	np.texture = load(ART + "ground.png")
	np.patch_margin_left = GROUND_CAP
	np.patch_margin_right = GROUND_CAP
	np.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	np.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	# La hierba sobresale un poco por encima del borde de colisión.
	np.position = Vector2(r.position.x, r.position.y - 12.0)
	np.size = Vector2(r.size.x, r.size.y + 12.0)
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(np, body)


func _platform(body: StaticBody2D, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	cs.one_way_collision = true
	_add(cs, body)
	var np := NinePatchRect.new()
	np.texture = load(ART + "plank.png")
	np.patch_margin_left = PLANK_CAP
	np.patch_margin_right = PLANK_CAP
	np.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	# El musgo de arriba queda al ras de la superficie en la que se pisa.
	np.position = Vector2(r.position.x, r.position.y - 3.0)
	np.size = Vector2(r.size.x, np.texture.get_height())
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(np, body)


func _poly(parent: Node, r: Rect2, color: Color) -> void:
	var p := Polygon2D.new()
	p.color = color
	p.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	_add(p, parent)
