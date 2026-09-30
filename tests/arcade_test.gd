extends RefCounted
## Pruebas de la reconstrucción arcade: arquitectura (Fase 1) y dos jugadores (Fase 2).
## Las ejecuta tests/smoke_test.gd; `t` es el nodo de prueba (check, wait_frames).

const STAGE := "res://data/stages/world_01_stage_01.tres"
const FLOOR_Y := 672.0

var t: Node
var arena: Arena
var p1: Player
var p2: Player
var requested: Array[String] = []


func run(test: Node) -> void:
	t = test
	var on_request := func(path: String, _k: StringName) -> void: requested.append(path)
	EventBus.scene_change_requested.connect(on_request)
	_architecture()
	await _score_and_combo()
	await _arena_coop()
	await _solo_arena()
	await _stage_flow()
	await _main_transition()
	EventBus.scene_change_requested.disconnect(on_request)
	StageManager.stage = null
	StageManager.phase = StageManager.Phase.IDLE
	GameManager.start_new_game(GameManager.GameMode.SOLO)


# ------------------------------------------------------------------ Fase 1
func _architecture() -> void:
	var root := t.get_tree().root
	t.check(root.has_node("ScoreManager") and root.has_node("StageManager"), "autoloads ScoreManager y StageManager")
	t.check(ProjectSettings.get_setting("display/window/size/viewport_width") == 960
		and ProjectSettings.get_setting("display/window/size/viewport_height") == 720, "resolución lógica 4:3 (960x720)")
	t.check(ProjectSettings.get_setting("display/window/stretch/aspect", "keep") == "keep",
		"proporción fija: barras laterales en 16:9, sin deformar")
	var stage := load(STAGE) as StageData
	t.check(stage != null and stage.screen_count() == 2, "StageData del Mundo 1-1 con pantallas A y B")
	var exist := true
	for path in stage.screens:
		exist = exist and ResourceLoader.exists(path)
	t.check(exist, "las escenas de las pantallas existen")
	t.check(ScoreManager.table != null and ScoreManager.table.enemy > 0, "tabla de puntuación cargada")


func _score_and_combo() -> void:
	ScoreManager.reset()
	var got := ScoreManager.register_kill(0, 100) + ScoreManager.register_kill(0, 100) + ScoreManager.register_kill(0, 100)
	t.check(got == 600 and ScoreManager.combos[0] == 3 and ScoreManager.scores[0] == 600,
		"combo x2, x3: 100 + 200 + 300 puntos")
	await t.wait_frames(int(ScoreManager.table.combo_window * 60.0) + 5)
	t.check(ScoreManager.combos[0] == 0 and ScoreManager.register_kill(0, 100) == 100, "el combo caduca")
	ScoreManager.reset()


func _arena_coop() -> void:
	StageManager.stage = load(STAGE) as StageData
	StageManager.screen_index = 0
	GameManager.start_new_game(GameManager.GameMode.COOP)
	arena = await _load_arena(0)
	t.check(arena.players.size() == 2, "arena en 2 PLAYERS: dos pingüinos")
	p1 = arena.players[0]
	p2 = arena.players[1]
	t.check(p1.character == Player.Character.BLUE_PENGUIN and p2.character == Player.Character.PINK_PENGUIN,
		"P1 pingüino azul, P2 pingüino rosa")
	t.check(StageManager.phase == StageManager.Phase.PLAYING and StageManager.arena == arena,
		"la arena se registra y empieza la pantalla")
	var cam := arena.camera
	t.check(cam.is_current() and cam.global_position == arena.arena_size * 0.5 and cam.zoom == Vector2.ONE,
		"cámara fija que encuadra la arena completa")
	var backdrop := arena.get_node("Background/Backdrop") as AnimatedBackdrop
	var f0 := backdrop.current
	await t.get_tree().create_timer(backdrop.frame_time * 1.5).timeout
	t.check(backdrop.frames.size() >= 2 and backdrop.current != f0, "fondo animado: el mar cambia de fotograma")

	await _arcade_movement()
	await _walls_and_jump()
	await _players_block_and_push()
	await _stand_on_partner()
	await _friendly_fire_and_respawn()
	await _timer_and_hud()
	await _enemies_cleared()
	t.check(cam.global_position == arena.arena_size * 0.5, "la cámara no se movió en toda la prueba")
	arena.queue_free()
	await t.wait_frames(2)


func _arcade_movement() -> void:
	# (Pantalla A: hay una roca en el suelo entre x=452 y 508.)
	await _place(p1, Vector2(60, FLOOR_Y))
	await _place(p2, Vector2(700, FLOOR_Y))
	Input.action_press("p1_move_right")
	await t.wait_frames(4)
	t.check(p1.velocity.x >= p1.config.move_speed - 1.0, "respuesta inmediata: velocidad máxima en 4 frames")
	await t.wait_frames(60)
	t.check(absf(p1.velocity.x - p1.config.move_speed) < 1.0 and p1.animator.animation == &"walk",
		"velocidad constante arcade (no acelera a correr)")
	t.check(absf(p2.global_position.x - 700.0) < 1.0, "P2 no se mueve con los controles de P1")
	Input.action_release("p1_move_right")
	await t.wait_frames(3)
	t.check(is_zero_approx(p1.velocity.x), "frena al instante al soltar")
	var x2 := p2.global_position.x
	Input.action_press("p2_move_left")
	await t.wait_frames(20)
	Input.action_release("p2_move_left")
	t.check(p2.global_position.x < x2 - 40.0, "P2 se mueve con sus propios controles")


func _walls_and_jump() -> void:
	await _place(p2, Vector2(840, FLOOR_Y))
	await _place(p1, Vector2(200, FLOOR_Y))
	Input.action_press("p1_move_left")
	await t.wait_frames(60)
	Input.action_release("p1_move_left")
	t.check(p1.global_position.x >= 24.0 + p1.config.body_radius - 1.0 and p1.is_on_floor(),
		"arena cerrada: la pared izquierda detiene al pingüino")
	await _place(p1, Vector2(150, FLOOR_Y))
	Input.action_press("p1_jump")
	await t.wait_frames(40)
	Input.action_release("p1_jump")
	await t.wait_frames(30)
	t.check(p1.is_on_floor() and absf(p1.global_position.y - 560.0) < 2.0,
		"el salto sube un piso (atraviesa la plataforma por debajo)")


func _players_block_and_push() -> void:
	await _place(p1, Vector2(560, FLOOR_Y))
	await _place(p2, Vector2(630, FLOOR_Y))
	var x2 := p2.global_position.x
	Input.action_press("p1_move_right")
	var overlap := false
	for i in 50:
		await t.wait_frames(1)
		if p2.global_position.x - p1.global_position.x < p1.config.body_radius * 2.0 - 2.0:
			overlap = true
	Input.action_release("p1_move_right")
	t.check(not overlap, "los pingüinos se bloquean: no se atraviesan")
	var pushed := p2.global_position.x - x2
	t.check(pushed > 20.0 and pushed < p1.config.move_speed * 50.0 / 60.0 * 0.8,
		"caminar contra el compañero lo empuja despacio (%.0f px)" % pushed)


func _stand_on_partner() -> void:
	await _place(p1, Vector2(620, FLOOR_Y))
	p2.global_position = Vector2(620, 520)
	p2.velocity = Vector2.ZERO
	await t.wait_frames(60)
	var head_y := p1.global_position.y - p1.config.body_height - p1.config.head_platform_offset
	t.check(p2.is_on_floor() and absf(p2.global_position.y - head_y) < 4.0, "P2 puede subirse encima de P1")
	await _place(p2, Vector2(700, FLOOR_Y))


func _friendly_fire_and_respawn() -> void:
	await _place(p1, Vector2(300, FLOOR_Y))
	await _place(p2, Vector2(360, FLOOR_Y))
	var hp := p2.health.current_health
	var bomb := p1.bombs.place_bomb()
	bomb.detonate()
	t.check(p2.health.current_health < hp, "la bomba de P1 también daña a P2 (fuego amigo arcade)")
	p1.health.reset()
	p2.health.reset()
	await _place(p1, Vector2(600, FLOOR_Y))
	await _place(p2, Vector2(840, FLOOR_Y))
	var lives := GameManager.lives[0]
	p1.health.kill(null)
	await t.wait_frames(int(p1.config.respawn_delay * 60.0) + 10)
	t.check(p1.is_alive() and p1.global_position.distance_to(p1.spawn_position) < 2.0
		and p1.spawn_position == (arena.spawner.get_node("P1") as Marker2D).position,
		"reaparece en su punto de inicio (arcade), no junto al compañero")
	t.check(GameManager.lives[0] == lives - 1, "pierde una vida")
	await t.wait_frames(int(p1.config.invulnerability_time * 60.0))


func _timer_and_hud() -> void:
	var before := StageManager.time_left
	await t.wait_frames(30)
	t.check(StageManager.time_left < before - 0.4 and before <= 90.0, "el tiempo de la pantalla corre")
	t.check(arena.hud.get_time_text() == "TIME %02d" % int(ceilf(StageManager.time_left)), "el HUD muestra TIME")
	ScoreManager.add_points(1, 250)
	t.check(arena.hud.get_score_text(1) == "000250", "el HUD muestra SCORE 2")
	GameManager.set_paused(true)
	var x := p1.global_position.x
	var paused_time := StageManager.time_left
	Input.action_press("p1_move_right")
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	Input.action_release("p1_move_right")
	t.check(is_equal_approx(StageManager.time_left, paused_time) and is_equal_approx(p1.global_position.x, x),
		"en pausa no corre el tiempo ni se mueven los jugadores")
	GameManager.set_paused(false)
	var lives := [GameManager.lives[0], GameManager.lives[1]]
	requested.clear()
	StageManager.time_left = 0.2
	await t.wait_frames(20)
	t.check(GameManager.lives[0] == lives[0] - 1 and GameManager.lives[1] == lives[1] - 1,
		"TIME 00: los dos jugadores pierden una vida")
	t.check(requested.has(StageManager.current_screen_path()), "y se repite la pantalla")
	# La prueba sigue en esta arena: se vuelve a registrar.
	StageManager.register_arena(arena)


func _enemies_cleared() -> void:
	var cleared := [false]
	var on_cleared := func() -> void: cleared[0] = true
	EventBus.enemies_cleared.connect(on_cleared)
	var enemy := _FakeEnemy.new()
	arena.enemies.add_child(enemy)
	t.check(arena.enemies.remaining() == 1 and not cleared[0], "EnemyManager cuenta los enemigos")
	var score := ScoreManager.scores[0]
	enemy.defeated.emit()
	t.check(cleared[0] and arena.enemies.is_cleared, "sin enemigos: la pantalla queda limpia (-> llave, Fase 7)")
	t.check(ScoreManager.scores[0] == score + ScoreManager.table.screen_clear, "bonificación por limpiar la pantalla")
	EventBus.enemies_cleared.disconnect(on_cleared)
	enemy.queue_free()


func _solo_arena() -> void:
	GameManager.start_new_game(GameManager.GameMode.SOLO)
	var solo := await _load_arena(0)
	t.check(solo.players.size() == 1 and solo.players[0].character == Player.Character.BLUE_PENGUIN,
		"1 PLAYER: solo el pingüino azul")
	t.check(solo.hud.get_score_text(1) == "------", "el HUD marca el 2P como libre")
	solo.queue_free()
	await t.wait_frames(2)


func _stage_flow() -> void:
	GameManager.start_new_game(GameManager.GameMode.COOP)
	requested.clear()
	StageManager.start_stage(load(STAGE) as StageData)
	t.check(requested.back() == StageManager.stage.screens[0] and StageManager.screen_index == 0,
		"empezar la fase carga la pantalla A")
	var a := await _load_arena(0)
	StageManager.time_left = 40.0
	var score := ScoreManager.scores[0]
	StageManager.next_screen()
	t.check(StageManager.screen_index == 1 and requested.back() == StageManager.stage.screens[1],
		"completar la pantalla A pasa a la B (transición, sin scroll)")
	t.check(ScoreManager.scores[0] == score + 40 * ScoreManager.table.time_bonus_per_second,
		"bonificación por tiempo restante")
	a.queue_free()
	await t.wait_frames(2)
	var b := await _load_arena(1)
	StageManager.next_screen()
	t.check(StageManager.phase == StageManager.Phase.CLEARED and requested.back() == StageManager.VICTORY_SCREEN,
		"tras la última pantalla la fase se completa")
	b.queue_free()
	await t.wait_frames(2)
	# GAME OVER y CONTINUE
	GameManager.start_new_game(GameManager.GameMode.COOP)
	StageManager.stage = load(STAGE) as StageData
	GameManager.eliminate_player(0)
	GameManager.eliminate_player(1)
	t.check(StageManager.phase == StageManager.Phase.GAME_OVER and requested.back() == StageManager.GAME_OVER_SCREEN,
		"sin jugadores: GAME OVER")
	t.check(StageManager.continue_game() and not GameManager.eliminated[0]
		and GameManager.lives[1] == GameManager.STARTING_LIVES and ScoreManager.total() == 0,
		"CONTINUE: vidas completas, puntuación a cero y se repite la pantalla")


func _main_transition() -> void:
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	t.get_tree().root.add_child(main)
	await t.wait_frames(5)
	GameManager.request_scene("res://scenes/ui/VictoryScreen.tscn", &"wipe")
	await t.wait_frames(8)
	t.check(main.current_screen.name == "TitleScreen" and main.transition.is_covering(),
		"la transición tapa la pantalla antes de cambiarla")
	await t.wait_frames(40)
	t.check(main.current_screen.name == "VictoryScreen" and not main.transition.is_covering(),
		"y la destapa con la pantalla nueva")
	main.queue_free()
	await t.wait_frames(2)


# ---------------------------------------------------------------- utilidades
func _load_arena(index: int) -> Arena:
	var stage := load(STAGE) as StageData
	var a := (load(stage.screens[index]) as PackedScene).instantiate() as Arena
	# Sin barriles ni cajas: estas pruebas no deben depender del botín aleatorio.
	for item in a.get_node("Items").get_children():
		item.free()
	# Sin enemigos: estas pruebas no deben depender de ellos (ver enemy_test.gd).
	for sp in a.get_node("Spawners").get_children():
		sp.free()
	t.get_tree().root.add_child(a)
	await t.wait_frames(10)
	return a


func _place(pl: Player, pos: Vector2) -> void:
	for prefix in ["p1_", "p2_"]:
		for c in InputManager.COMMANDS:
			Input.action_release(prefix + c)
	pl.global_position = pos
	pl.velocity = Vector2.ZERO
	pl.set_low_profile(false)
	pl.state_machine.transition_to(&"Fall")
	for i in 60:
		if pl.is_on_floor() and pl.state_machine.is_in(&"Idle"):
			break
		await t.wait_frames(1)
	await t.wait_frames(2)


## Enemigo mínimo para probar el contrato de EnemyManager (grupo + señal `defeated`).
class _FakeEnemy extends Node2D:
	signal defeated

	func _init() -> void:
		add_to_group(&"enemies")
