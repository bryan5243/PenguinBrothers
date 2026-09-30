extends RefCounted
## Pruebas de la Fase 6 arcade: plataformas giratorias (subir, bajar, dos jugadores, objetos,
## espera y datos). Las ejecuta tests/smoke_test.gd.

const STAGE := "res://data/stages/world_01_stage_01.tres"
const FLOOR_Y := 672.0

var t: Node
var arena: Arena
var p1: Player
var p2: Player
var rot_up: RotatingPlatform     # pantalla A, junto al tablón izquierdo (560 -> 448)
var rot_far: RotatingPlatform    # pantalla A, 448 -> 224


func run(test: Node) -> void:
	t = test
	StageManager.stage = load(STAGE) as StageData
	StageManager.screen_index = 0
	GameManager.start_new_game(GameManager.GameMode.COOP)
	arena = (load(StageManager.stage.screens[0]) as PackedScene).instantiate() as Arena
	for sp in arena.get_node("Spawners").get_children():
		sp.free()
	t.get_tree().root.add_child(arena)
	await t.wait_frames(10)
	p1 = arena.players[0]
	p2 = arena.players[1]
	rot_up = arena.get_node("Rotators/RotatingPlatform1") as RotatingPlatform
	rot_far = arena.get_node("Rotators/RotatingPlatform2") as RotatingPlatform
	await _place(p2, Vector2(880, FLOOR_Y))
	_data()
	await _flip_up()
	await _flip_down()
	await _cooldown_and_busy()
	await _both_players()
	await _objects_ride()
	await _no_input_no_flip()
	arena.queue_free()
	await t.wait_frames(2)
	StageManager.stage = null
	StageManager.phase = StageManager.Phase.IDLE


func _data() -> void:
	var data := load("res://data/platforms/rotating_platform.tres") as RotatingPlatformData
	t.check(data != null and data.flip_time > 0.0 and data.cooldown > 0.0 and data.texture != null,
		"RotatingPlatformData: giro, espera y dibujo como datos (.tres)")
	t.check(arena.get_node("Rotators").get_child_count() >= 2 and rot_up.is_ready(),
		"la pantalla A tiene plataformas giratorias listas")
	t.check(rot_up.get_collision_layer_value(6) and rot_up.shape_node.one_way_collision,
		"la superficie es atravesable desde abajo (capa de plataformas)")


func _flip_up() -> void:
	await _place(p1, rot_up.global_position)
	t.check(p1.is_on_floor() and absf(p1.global_position.y - rot_up.global_position.y) < 2.0,
		"el jugador se para sobre la plataforma giratoria")
	var started := [0]
	rot_up.flip_started.connect(func(d: int) -> void: started[0] = d)
	await _press("p1_up")
	t.check(rot_up.state == RotatingPlatform.State.WINDUP or rot_up.state == RotatingPlatform.State.FLIP,
		"arriba sobre la plataforma la activa")
	var top_y := p1.global_position.y
	for i in 70:
		await t.wait_frames(1)
		top_y = minf(top_y, p1.global_position.y)
	t.check(started[0] == RotatingPlatform.UP, "emite flip_started hacia arriba")
	t.check(top_y < rot_up.global_position.y - 120.0, "lanza al jugador hacia arriba (sube más que un salto normal)")
	for i in 90:
		if p1.is_on_floor():
			break
		await t.wait_frames(1)
	t.check(p1.is_on_floor() and absf(p1.global_position.y - 448.0) < 3.0,
		"aterriza en el piso de arriba (448)")


func _flip_down() -> void:
	# Desde el piso de arriba, otra plataforma abre hacia abajo.
	await _place(p1, rot_far.global_position)
	await t.wait_frames(rot_far.data.cooldown > 0.0 and int(rot_far.data.cooldown * 60.0) + 2)
	var y0 := p1.global_position.y
	await _press("p1_crouch")
	for i in 40:
		await t.wait_frames(1)
	t.check(p1.global_position.y > y0 + 20.0, "abajo sobre la plataforma: se abre y cae al piso de abajo")
	for i in 120:
		if p1.is_on_floor():
			break
		await t.wait_frames(1)
	t.check(p1.is_on_floor() and p1.global_position.y > rot_far.global_position.y + 50.0,
		"aterriza más abajo que la plataforma")


func _cooldown_and_busy() -> void:
	rot_up.state = RotatingPlatform.State.READY
	t.check(rot_up.start_flip(RotatingPlatform.UP), "start_flip acepta un giro cuando está lista")
	t.check(not rot_up.start_flip(RotatingPlatform.UP), "no acepta otro giro mientras gira")
	await t.wait_frames(int((rot_up.data.windup_time + rot_up.data.flip_time) * 60.0) + 6)
	t.check(rot_up.state == RotatingPlatform.State.COOLDOWN and not rot_up.is_ready(),
		"tras girar espera antes de poder usarse")
	t.check(not rot_up.shape_node.disabled, "la superficie vuelve a ser pisable tras el giro")
	await t.wait_frames(int(rot_up.data.cooldown * 60.0) + 6)
	t.check(rot_up.is_ready(), "vuelve a estar lista")
	rot_up.can_flip_down = false
	t.check(not rot_up.start_flip(RotatingPlatform.DOWN), "can_flip_down = false impide abrirse hacia abajo")
	rot_up.can_flip_down = true


func _both_players() -> void:
	await _place(p1, rot_up.global_position + Vector2(-20, 0))
	await _place(p2, rot_up.global_position + Vector2(20, 0))
	t.check(rot_up.riders().has(p1) and rot_up.riders().has(p2), "detecta a los dos jugadores encima")
	rot_up.start_flip(RotatingPlatform.UP)
	var best := [p1.global_position.y, p2.global_position.y]
	for i in 60:
		await t.wait_frames(1)
		best[0] = minf(best[0], p1.global_position.y)
		best[1] = minf(best[1], p2.global_position.y)
	t.check(best[0] < rot_up.global_position.y - 100.0 and best[1] < rot_up.global_position.y - 100.0,
		"con dos jugadores encima, salen lanzados los dos")
	await t.wait_frames(120)
	await _place(p2, Vector2(880, FLOOR_Y))
	await _place(p1, Vector2(120, FLOOR_Y))


func _objects_ride() -> void:
	await t.wait_frames(int(rot_up.data.cooldown * 60.0) + 40)
	var pool := arena.bomb_pool
	var bomb := pool.acquire_bomb(p1.bombs.current_type(), 0)
	bomb.arm_at(rot_up.global_position + Vector2(0, -14))
	bomb.fuse_left = 30.0
	await t.wait_frames(30)
	t.check(rot_up.riders().has(bomb), "una bomba en reposo encima cuenta como carga")
	rot_up.start_flip(RotatingPlatform.UP)
	var top := bomb.global_position.y
	for i in 40:
		await t.wait_frames(1)
		top = minf(top, bomb.global_position.y)
	t.check(top < rot_up.global_position.y - 60.0, "la bomba sale despedida al girar")
	bomb._go_to_pool()
	await t.wait_frames(int(rot_up.data.cooldown * 60.0) + 80)


func _no_input_no_flip() -> void:
	rot_up.state = RotatingPlatform.State.READY
	await _place(p1, rot_up.global_position)
	await t.wait_frames(30)
	t.check(rot_up.is_ready(), "sin pulsar nada la plataforma no gira sola")
	# Un jugador caminando por encima (sin arriba) no la activa.
	Input.action_press("p1_move_right")
	await t.wait_frames(6)
	Input.action_release("p1_move_right")
	t.check(rot_up.is_ready(), "caminar por encima no la activa")
	await _place(p1, Vector2(120, FLOOR_Y))


func _press(action: StringName) -> void:
	Input.action_press(action)
	await t.wait_frames(2)
	Input.action_release(action)
	await t.wait_frames(2)


func _place(pl: Player, pos: Vector2) -> void:
	for prefix in ["p1_", "p2_"]:
		for c in InputManager.COMMANDS:
			Input.action_release(prefix + c)
	pl.global_position = pos
	pl.velocity = Vector2.ZERO
	pl.facing = 1
	pl.set_low_profile(false)
	pl.state_machine.transition_to(&"Fall")
	for i in 60:
		if pl.is_on_floor() and pl.state_machine.is_in(&"Idle"):
			break
		await t.wait_frames(1)
	await t.wait_frames(2)
