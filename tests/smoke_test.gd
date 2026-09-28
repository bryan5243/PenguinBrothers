extends Node
## Prueba de humo de la arquitectura base (se ejecuta como escena, después de los autoloads).
## Uso:  godot --headless --path . res://tests/SmokeTest.tscn
## Termina con código 0 si todo pasa y 1 si algo falla.

var _failures: Array[String] = []
var _passed := 0


func _ready() -> void:
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  OK   ", description)
	else:
		_failures.append(description)
		print("  FAIL ", description)


func wait_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var root := get_tree().root
	print("== Autoloads")
	for name in ["EventBus", "SaveManager", "AudioManager", "InputManager", "GameManager"]:
		check(root.has_node(name), "autoload %s" % name)

	print("== Input Map")
	for p in ["p1_", "p2_"]:
		for cmd in InputManager.COMMANDS:
			var action: String = p + cmd
			check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(),
				"acción %s con eventos" % action)
	check(InputMap.has_action("pause"), "acción pause")
	check(InputMap.has_action("debug_overlay"), "acción debug_overlay")

	print("== Escenas")
	for path in _find_scenes("res://scenes"):
		var packed := load(path) as PackedScene
		var ok := packed != null and packed.can_instantiate()
		if ok:
			var inst := packed.instantiate()
			ok = inst != null
			inst.free()
		check(ok, "escena %s" % path)

	print("== Datos")
	var cfg := load("res://data/player/default_player_config.tres") as PlayerConfig
	check(cfg != null and cfg.jump_force > 0.0, "PlayerConfig por defecto")
	for i in range(1, 11):
		var w := GameManager.get_world_data(i)
		check(w != null and w.display_name != "" and w.enemy_ids.size() == 4 and w.boss_id != &"",
			"WorldData mundo %d" % i)
	check(GameManager.get_world_data(1).unlocked_by_default, "Mundo 1 desbloqueado por defecto")

	print("== Guardado")
	SaveManager.set_value("settings", "music_volume", 0.42)
	SaveManager.unlock_level(1, 3)
	check(SaveManager.save_game(), "guardar JSON")
	SaveManager.load_game()
	check(is_equal_approx(float(SaveManager.get_value("settings", "music_volume")), 0.42), "cargar ajuste guardado")
	check(int(SaveManager.get_value("progress", "unlocked_level")) == 3, "cargar progreso guardado")
	SaveManager.reset_progress()
	SaveManager.set_value("settings", "music_volume", 0.8)
	SaveManager.save_game()

	print("== Capa de entrada")
	GameManager.start_new_game(GameManager.GameMode.SOLO)
	Input.action_press("p2_jump")
	await wait_frames(1)
	check(InputManager.is_pressed(0, &"jump"), "individual: J1 acepta controles del J2")
	InputManager.set_coop(true)
	check(not InputManager.is_pressed(0, &"jump"), "cooperativo: J1 ignora controles del J2")
	check(InputManager.is_pressed(1, &"jump"), "cooperativo: J2 recibe su acción")
	Input.action_release("p2_jump")
	Input.action_press("p1_move_right", 0.6)
	await wait_frames(1)
	check(is_equal_approx(InputManager.get_move_axis(0), 0.6), "eje analógico")
	Input.action_release("p1_move_right")
	InputManager.set_coop(false)

	print("== Máquina de estados")
	var fsm := StateMachine.new()
	var a := State.new()
	a.name = "A"
	var b := State.new()
	b.name = "B"
	fsm.add_child(a)
	fsm.add_child(b)
	root.add_child(fsm)
	await wait_frames(2)
	check(fsm.is_in(&"A"), "estado inicial")
	fsm.transition_to(&"B")
	check(fsm.is_in(&"B"), "transición")
	fsm.queue_free()

	print("== Jugador")
	var player := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate() as Player
	player.player_index = 1
	player.character = Player.Character.PINK_PENGUIN
	root.add_child(player)
	await wait_frames(3)
	check(player.config != null and player.input != null, "componentes del jugador")
	check(player.health.current_health == player.config.max_health, "vida inicial")
	Input.action_press("p2_crouch")
	Input.action_press("p2_move_left")
	await wait_frames(2)
	check(player.input.crouch_held and player.input.move_axis < 0.0, "PlayerInput lee los comandos del jugador 2")
	Input.action_release("p2_crouch")
	Input.action_release("p2_move_left")
	player.take_damage(1, null)
	check(player.health.current_health == player.config.max_health - 1, "daño aplicado")
	player.take_damage(1, null)
	check(player.health.current_health == player.config.max_health - 1, "invulnerabilidad temporal")
	player.facing = -1
	check(player.animator.flip_h, "orientación del sprite")
	player.queue_free()

	print("== Sprites normalizados")
	var sprites: RefCounted = load("res://tests/sprite_normalization_test.gd").new()
	await sprites.run(self)

	print("== Movimiento del jugador")
	var movement: RefCounted = load("res://tests/player_movement_test.gd").new()
	await movement.run(self)

	print("== Cooperativo")
	var coop: RefCounted = load("res://tests/coop_test.gd").new()
	await coop.run(self)

	print("== Bombas")
	var bombs: RefCounted = load("res://tests/bomb_test.gd").new()
	await bombs.run(self)

	print("== Arcade: arquitectura y dos jugadores")
	var arcade: RefCounted = load("res://tests/arcade_test.gd").new()
	await arcade.run(self)

	print("== Escena Main")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main/Main.tscn", "Main es la escena principal")
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await wait_frames(10)
	check(main.current_screen != null and main.current_screen.name == "TitleScreen", "Main carga la pantalla de título")
	await wait_frames(30)
	main.queue_free()

	print("\n%d comprobaciones correctas, %d fallidas" % [_passed, _failures.size()])
	for f in _failures:
		print("  - ", f)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _find_scenes(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	for f in dir.get_files():
		if f.ends_with(".tscn"):
			result.append(dir_path.path_join(f))
	for d in dir.get_directories():
		result.append_array(_find_scenes(dir_path.path_join(d)))
	return result
