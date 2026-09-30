extends SceneTree
## Genera la configuración del proyecto (ajustes, autoloads, Input Map) y los datos base.
## Uso:  godot --headless --path . -s tools/setup_project.gd
## Es idempotente: se puede volver a ejecutar tras cambiar los controles aquí.

const DEADZONE := 0.25

## Teclado por jugador. En modo individual el Jugador 1 también usa las teclas del Jugador 2
## (ver InputManager), así las flechas funcionan jugando solo.
const KEYBOARD := {
	"p1": {
		"move_left": [KEY_A], "move_right": [KEY_D], "up": [KEY_W], "crouch": [KEY_S],
		"jump": [KEY_SPACE, KEY_W], "interact": [KEY_E], "bomb": [KEY_Q], "switch_bomb": [KEY_R],
	},
	"p2": {
		"move_left": [KEY_LEFT], "move_right": [KEY_RIGHT], "up": [KEY_UP], "crouch": [KEY_DOWN],
		"jump": [KEY_UP], "interact": [KEY_KP_1, KEY_SHIFT], "bomb": [KEY_KP_0, KEY_CTRL],
		"switch_bomb": [KEY_KP_2, KEY_ENTER],
	},
}
## Teclas modificadoras del Jugador 2: se usan las del lado derecho del teclado.
const RIGHT_SIDE_KEYS := [KEY_SHIFT, KEY_CTRL]

## Mando (mismo esquema para ambos; el dispositivo 0 es Jugador 1 y el 1 es Jugador 2).
const GAMEPAD_BUTTONS := {
	"move_left": [JOY_BUTTON_DPAD_LEFT], "move_right": [JOY_BUTTON_DPAD_RIGHT],
	"up": [JOY_BUTTON_DPAD_UP], "crouch": [JOY_BUTTON_DPAD_DOWN],
	"jump": [JOY_BUTTON_A], "bomb": [JOY_BUTTON_B], "interact": [JOY_BUTTON_X],
	"switch_bomb": [JOY_BUTTON_Y],
}
const GAMEPAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
	"up": [JOY_AXIS_LEFT_Y, -1.0], "crouch": [JOY_AXIS_LEFT_Y, 1.0],
}

const AUTOLOADS := [
	["EventBus", "res://scripts/core/event_bus.gd"],
	["SaveManager", "res://scripts/core/save_manager.gd"],
	["AudioManager", "res://scripts/core/audio_manager.gd"],
	["InputManager", "res://scripts/core/input_manager.gd"],
	["ScoreManager", "res://scripts/core/score_manager.gd"],
	["GameManager", "res://scripts/core/game_manager.gd"],
	["StageManager", "res://scripts/core/stage_manager.gd"],
]

const LAYERS := ["world", "players", "enemies", "bombs", "objects", "platforms", "hazards", "pickups"]

const WORLDS := [
	["isla_palmera", "Isla Palmera", "Playa, palmeras, agua, puentes y zonas submarinas.",
		["small_crab", "seagull", "hermit_crab", "small_octopus"], "orca_ninja"],
	["templo_oriental", "Templo Oriental", "Templos, faroles, tejados y jardines orientales.",
		["rat_monk", "bat", "snake", "tengu_warrior"], "royal_eagle"],
	["montana_nevada", "Montaña Nevada", "Cumbres heladas, nieve y pendientes resbaladizas.",
		["warrior_seal", "arctic_rabbit", "small_yeti", "enemy_penguin"], "snow_leopard"],
	["mar_profundo", "Mar Profundo", "Ruinas submarinas, corales y corrientes.",
		["pufferfish", "jellyfish", "electric_eel", "squid"], "great_white_shark"],
	["zona_artica", "Zona Ártica", "Hielo eterno, auroras y bases polares.",
		["motor_penguin", "polar_owl", "walrus", "arctic_hare"], "polar_bear"],
	["base_robotica", "Base Robótica", "Fábrica, cintas transportadoras y láseres.",
		["patrol_robot", "flying_drone", "tread_robot", "laser_tower"], "robot_penguin"],
	["bosque_bambu", "Bosque de Bambú", "Bosque denso de bambú y puentes colgantes.",
		["warrior_panda", "ninja_monkey", "tanuki", "giant_wasp"], "amur_tiger"],
	["volcan_fuego", "Volcán de Fuego", "Ríos de lava, rocas ardientes y ceniza.",
		["fire_lizard", "lava_bat", "living_rock", "fire_elemental"], "fire_dragon"],
	["ciudad_neon", "Ciudad Neón", "Rascacielos, carteles luminosos y tejados.",
		["hacker_monkey", "robot_dog", "flying_ship", "digital_ghost"], "mega_drone"],
	["castillo_celestial", "Castillo Celestial", "Castillo entre las nubes y templos del cielo.",
		["wind_bird", "cloud_warrior", "lightning_spirit", "kairyu"], "celestial_dragon"],
]


func _initialize() -> void:
	_configure_project()
	_configure_input()
	var err := ProjectSettings.save()
	print("project.godot guardado: ", error_string(err))
	_create_data()
	quit()


func _setting(key: String, value: Variant) -> void:
	ProjectSettings.set_setting(key, value)


func _configure_project() -> void:
	_setting("application/config/name", "Penguin Brothers – Edición Asiática")
	_setting("application/config/description", "Arcade de pantalla fija para 1 o 2 jugadores: pingüinos, bombas, enemigos, llave y puerta.")
	_setting("application/config/version", "0.1.0")
	_setting("application/run/main_scene", "res://scenes/main/Main.tscn")
	_setting("application/config/icon", "res://icon.svg")
	_setting("application/config/features", PackedStringArray(["4.7", "GL Compatibility"]))

	# Arcade 4:3: resolución lógica 960x720 (= 640x480 x1,5). Escala exacta a 1280x960 y
	# 1920x1440; en pantallas 16:9 se añaden barras laterales sin deformar el área jugable.
	_setting("display/window/size/viewport_width", 960)
	_setting("display/window/size/viewport_height", 720)
	_setting("display/window/stretch/mode", "canvas_items")
	_setting("display/window/stretch/aspect", "keep")
	_setting("display/window/handheld/orientation", 4)  # horizontal con sensor
	_setting("display/window/energy_saving/keep_screen_on", true)

	# Compatibility: funciona en Windows, Android, iOS y web, incluso en equipos modestos.
	_setting("rendering/renderer/rendering_method", "gl_compatibility")
	_setting("rendering/renderer/rendering_method.mobile", "gl_compatibility")
	_setting("rendering/textures/vram_compression/import_etc2_astc", true)
	_setting("rendering/environment/defaults/default_clear_color", Color(0.05, 0.16, 0.29))
	_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", false)

	_setting("physics/2d/default_gravity", 1750.0)
	_setting("physics/common/physics_ticks_per_second", 60)
	_setting("input_devices/pointing/emulate_touch_from_mouse", false)
	_setting("input_devices/pointing/emulate_mouse_from_touch", true)
	_setting("gui/common/drop_mouse_on_gui_input_disabled", true)

	for i in LAYERS.size():
		_setting("layer_names/2d_physics/layer_%d" % (i + 1), LAYERS[i])

	# Se borran y se vuelven a añadir para que el orden sea exactamente el de AUTOLOADS.
	for a in AUTOLOADS:
		if ProjectSettings.has_setting("autoload/" + a[0]):
			ProjectSettings.clear("autoload/" + a[0])
	for a in AUTOLOADS:
		_setting("autoload/" + a[0], "*" + a[1])


func _configure_input() -> void:
	for p in ["p1", "p2"]:
		var device := 0 if p == "p1" else 1
		for command in KEYBOARD[p]:
			var events: Array[InputEvent] = []
			for key in KEYBOARD[p][command]:
				var ev := InputEventKey.new()
				ev.device = -1
				ev.physical_keycode = key
				if p == "p2" and key in RIGHT_SIDE_KEYS:
					ev.location = KEY_LOCATION_RIGHT
				events.append(ev)
			for button in GAMEPAD_BUTTONS.get(command, []):
				var jb := InputEventJoypadButton.new()
				jb.device = device
				jb.button_index = button
				events.append(jb)
			if GAMEPAD_AXES.has(command):
				var jm := InputEventJoypadMotion.new()
				jm.device = device
				jm.axis = GAMEPAD_AXES[command][0]
				jm.axis_value = GAMEPAD_AXES[command][1]
				events.append(jm)
			_setting("input/%s_%s" % [p, command], {"deadzone": DEADZONE, "events": events})

	var pause_events: Array[InputEvent] = []
	for key in [KEY_ESCAPE, KEY_P]:
		var ev := InputEventKey.new()
		ev.device = -1
		ev.physical_keycode = key
		pause_events.append(ev)
	var start := InputEventJoypadButton.new()
	start.device = -1
	start.button_index = JOY_BUTTON_START
	pause_events.append(start)
	_setting("input/pause", {"deadzone": 0.5, "events": pause_events})

	# Solo depuración: muestra colisión, GroundPoint, centro y caja visual del jugador.
	var debug_key := InputEventKey.new()
	debug_key.device = -1
	debug_key.physical_keycode = KEY_F1
	_setting("input/debug_overlay", {"deadzone": 0.5, "events": [debug_key]})
	# Solo desarrollo: pasar a la siguiente pantalla de la fase.
	var next_key := InputEventKey.new()
	next_key.device = -1
	next_key.physical_keycode = KEY_F2
	_setting("input/debug_next_screen", {"deadzone": 0.5, "events": [next_key]})


## Tipos de bomba iniciales (hoja blue_penguin_moves_and_bombs.png: normal, pequeña, grande).
## id, nombre, carpeta de sprites, daño, radio, mecha, empuje, radio del cuerpo, rebote, color del área.
## El primero es el que se lleva equipado al empezar.
const BOMBS := [
	["black", "Bomba normal", "black", 2, 80.0, 2.4, 440.0, 13.0, 0.35, Color(1.0, 0.6, 0.2)],
	["blue", "Bomba azul (pequeña)", "blue", 1, 60.0, 1.8, 360.0, 11.0, 0.45, Color(0.35, 0.7, 1.0)],
	["green", "Bomba verde (grande)", "green", 3, 104.0, 2.8, 520.0, 15.0, 0.25, Color(0.4, 1.0, 0.45)],
]


## Power-ups: id, nombre, icono, categoría, valor del efecto, duración, puntos.
const POWER_UPS := [
	["cherry", "Cereza", "cherry", PowerUpData.Category.SCORE, 0.0, 0.0, 100],
	["banana", "Banana", "banana", PowerUpData.Category.SCORE, 0.0, 0.0, 200],
	["orange", "Naranja", "orange", PowerUpData.Category.SCORE, 0.0, 0.0, 300],
	["apple", "Manzana", "apple", PowerUpData.Category.SCORE, 0.0, 0.0, 500],
	["grape", "Uva", "grape", PowerUpData.Category.SCORE, 0.0, 0.0, 800],
	["watermelon", "Sandía", "watermelon", PowerUpData.Category.SCORE, 0.0, 0.0, 1000],
	["pineapple", "Piña", "pineapple", PowerUpData.Category.SCORE, 0.0, 0.0, 1500],
	["melon", "Melón", "melon", PowerUpData.Category.SCORE, 0.0, 0.0, 2000],
	["cake", "Pastel (vida extra)", "cake", PowerUpData.Category.EXTRA_LIFE, 1.0, 0.0, 0],
	["one_up", "1UP", "one_up", PowerUpData.Category.EXTRA_LIFE, 1.0, 0.0, 0],
	["armor", "Armadura", "armor", PowerUpData.Category.ARMOR, 1.0, 0.0, 0],
	["boots", "Botas de velocidad", "boots", PowerUpData.Category.SPEED, 1.4, 10.0, 0],
	["fire", "Fuego (poder de bomba)", "fire", PowerUpData.Category.BOMB_POWER, 1.0, 0.0, 0],
]
## Botín: id, objetos y pesos, probabilidad de soltar algo.
const DROPS := [
	["crate_drops", [["cherry", 3.0], ["banana", 2.0], ["orange", 1.5], ["apple", 1.0]], 0.6],
	["barrel_drops", [["cherry", 2.0], ["apple", 1.5], ["watermelon", 1.0], ["fire", 2.0],
		["boots", 1.0], ["armor", 1.0], ["one_up", 0.3]], 0.9],
	["enemy_drops", [["cherry", 3.0], ["banana", 2.0], ["orange", 1.5], ["fire", 1.0],
		["boots", 0.5], ["armor", 0.5]], 0.35],
]

## Enemigos del Mundo 1. Cada fila: campos de EnemyData que difieren del valor por defecto.
const ENEMIES := {
	"small_crab": {"display_name": "Cangrejo pequeño", "behavior": EnemyData.Behavior.WALKER,
		"health": 1, "speed": 70.0, "chase_speed": 125.0, "jump_force": 640.0, "attack_range": 44.0,
		"detection_range": 320.0, "score": 100, "visual_height": 40.0, "body_size": Vector2(40, 28),
		"death_color": Color(0.95, 0.3, 0.25)},
	"hermit_crab": {"display_name": "Cangrejo ermitaño", "behavior": EnemyData.Behavior.SHELL,
		"health": 2, "speed": 55.0, "chase_speed": 95.0, "attack_range": 46.0, "score": 200,
		"visual_height": 48.0, "body_size": Vector2(44, 34), "shell_armor": 1,
		"death_color": Color(0.75, 0.65, 0.3)},
	"seagull": {"display_name": "Gaviota", "behavior": EnemyData.Behavior.FLYER, "flying": true,
		"health": 1, "speed": 110.0, "attack_cooldown": 2.5, "detection_range": 700.0, "score": 150,
		"visual_height": 46.0, "body_size": Vector2(44, 30), "sprite_on_ground": false,
		"knockback_taken": 0.6, "death_color": Color(0.95, 0.95, 1.0)},
	"small_octopus": {"display_name": "Pulpo pequeño", "behavior": EnemyData.Behavior.SWIMMER,
		"health": 1, "speed": 45.0, "chase_speed": 45.0, "detection_range": 520.0,
		"attack_cooldown": 2.4, "attack_duration": 0.6, "attack_hit_time": 0.35,
		"projectile_speed": 260.0, "projectile_range": 480.0, "score": 150, "visual_height": 42.0,
		"body_size": Vector2(34, 32), "death_color": Color(1.0, 0.45, 0.55)},
}


func _create_items() -> void:
	var by_id := {}
	for p in POWER_UPS:
		var d := PowerUpData.new()
		d.id = StringName(p[0])
		d.display_name = p[1]
		d.icon = load("res://assets/items/%s.png" % p[2])
		d.category = p[3]
		d.effect_value = p[4]
		d.duration = p[5]
		d.score_value = p[6]
		var path := "res://data/powerups/%s.tres" % p[0]
		_save(d, path)
		by_id[p[0]] = load(path)
	var tables := {}
	for t in DROPS:
		var table := DropTable.new()
		var items: Array[PowerUpData] = []
		var weights: Array[float] = []
		for entry in t[1]:
			items.append(by_id[entry[0]])
			weights.append(entry[1])
		table.items = items
		table.weights = weights
		table.drop_chance = t[2]
		var path := "res://data/drops/%s.tres" % t[0]
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		_save(table, path)
		tables[t[0]] = load(path)
	var crate := DestructibleData.new()
	crate.id = &"crate"
	crate.display_name = "Caja"
	crate.texture = load("res://assets/objects/crate.png")
	crate.drop_table = tables["crate_drops"]
	_save(crate, "res://data/destructibles/crate.tres")
	var block := DestructibleData.new()
	block.id = &"stone_block"
	block.display_name = "Bloque de piedra"
	block.texture = load("res://assets/objects/stone_block.png")
	block.max_health = 2
	block.hardness = 2
	block.points = 150
	block.debris_color = Color(0.55, 0.55, 0.6)
	_save(block, "res://data/destructibles/stone_block.tres")
	var barrel := BarrelData.new()
	barrel.id = &"barrel"
	barrel.display_name = "Barril"
	barrel.texture = load("res://assets/objects/barrel.png")
	barrel.size = Vector2(44, 40)
	barrel.drop_table = tables["barrel_drops"]
	_save(barrel, "res://data/destructibles/barrel.tres")
	for enemy_id in ENEMIES:
		var e := EnemyData.new()
		e.id = StringName(enemy_id)
		e.world = 1
		for key in ENEMIES[enemy_id]:
			e.set(key, ENEMIES[enemy_id][key])
		e.sprite_frames = load("res://assets/enemies/%s/%s_frames.tres" % [enemy_id, enemy_id])
		e.drop_table = tables["enemy_drops"]
		if enemy_id == "small_octopus":
			e.projectile_texture = load("res://assets/enemies/small_octopus/ink.png")
		_save(e, "res://data/enemies/%s.tres" % enemy_id)


func _create_data() -> void:
	_create_items()
	var bomb_types: Array[BombData] = []
	for b in BOMBS:
		var data := BombData.new()
		data.id = StringName(b[0])
		data.display_name = b[1]
		var folder := "res://assets/bombs/%s/" % b[2]
		data.frames = load(folder + "%s_frames.tres" % b[2])
		data.texture = load(folder + "fuse_1.png")
		data.icon = data.texture
		data.damage = b[3]
		data.explosion_radius = b[4]
		data.fuse_time = b[5]
		data.knockback = b[6]
		data.body_radius = b[7]
		data.bounce = b[8]
		data.area_color = b[9]
		data.explosion_texture_diameter = float(data.frames.get_meta(&"explosion_diameter", 152.0))
		# Arcade: las bombas no distinguen entre jugador, enemigo u objeto.
		data.hurts_players = true
		var path := "res://data/bombs/%s_bomb.tres" % b[0]
		_save(data, path)
		bomb_types.append(load(path))
	var cfg := PlayerConfig.new()
	cfg.bomb_types = bomb_types
	_save(cfg, "res://data/player/default_player_config.tres")
	_save(ScoreTable.new(), "res://data/score_table.tres")
	var stage := StageData.new()
	stage.id = &"world_01_stage_01"
	stage.world = 1
	stage.stage = 1
	stage.display_name = "Isla Palmera 1-1"
	stage.screens = ["res://scenes/stages/world_01/World01_Stage01_A.tscn",
		"res://scenes/stages/world_01/World01_Stage01_B.tscn"] as Array[String]
	stage.time_limits = [90.0, 90.0] as Array[float]
	_save(stage, "res://data/stages/world_01_stage_01.tres")
	for i in WORLDS.size():
		var w: Array = WORLDS[i]
		var data := WorldData.new()
		data.number = i + 1
		data.id = StringName(w[0])
		data.display_name = w[1]
		data.description = w[2]
		var enemies: Array[StringName] = []
		for e in w[3]:
			enemies.append(StringName(e))
		data.enemy_ids = enemies
		data.boss_id = StringName(w[4])
		data.music_key = "music_world_%02d" % (i + 1)
		data.unlocked_by_default = i == 0
		_save(data, "res://data/worlds/world_%02d.tres" % (i + 1))


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	print("  ", path, ": ", error_string(err))
