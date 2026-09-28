extends RefCounted
## Pruebas del modo cooperativo (Fase 3) sobre el nivel de prueba.
## Las ejecuta tests/smoke_test.gd; `t` es el nodo de prueba (check, wait_frames).

const TEST_LEVEL := "res://scenes/worlds/test_level/PlayerTestLevel.tscn"
const GROUND_Y := 640.0

var t: Node
var level: Node
var p1: Player
var p2: Player


func run(test: Node) -> void:
	t = test
	await _gamepad_assignment()

	GameManager.start_new_game(GameManager.GameMode.COOP)
	level = (load(TEST_LEVEL) as PackedScene).instantiate()
	t.get_tree().root.add_child(level)
	await t.wait_frames(20)
	t.check(level.players.size() == 2, "cooperativo: aparecen 2 jugadores")
	p1 = level.players[0]
	p2 = level.players[1]
	t.check(p1.player_index == 0 and p2.player_index == 1, "índices de jugador 0 y 1")
	t.check(p1.character == Player.Character.BLUE_PENGUIN and p2.character == Player.Character.PINK_PENGUIN,
		"J1 es el pingüino azul y J2 el rosa")
	t.check(p2.animator.sprite_frames == p2.animator.pink_penguin_frames and p2.animator.sprite_frames != null,
		"J2 usa los sprites del pingüino rosa")
	t.check(p1.tag.visible and p2.tag.visible and p2.tag.text == "P2", "etiquetas P1/P2 visibles")

	await _independent_controls()
	await _camera()
	await _stand_on_partner()
	await _respawn_and_elimination()

	level.queue_free()
	await t.wait_frames(2)
	GameManager.start_new_game(GameManager.GameMode.SOLO)


func _gamepad_assignment() -> void:
	var im := InputManager
	im.set_coop(true)
	im.refresh_gamepads([3])
	t.check(im.gamepad_for_player(0) == im.NO_GAMEPAD and im.gamepad_for_player(1) == 3,
		"cooperativo con 1 mando: J1 teclado, J2 mando")
	t.check(_pad_device("p2_jump") == 3 and _pad_device("p1_jump") == im.NO_GAMEPAD, "Input Map reasignado")
	im.refresh_gamepads([0, 1])
	t.check(im.gamepad_for_player(0) == 0 and im.gamepad_for_player(1) == 1, "2 mandos: uno por jugador")
	im.set_coop(false)
	im.refresh_gamepads([2])
	t.check(im.gamepad_for_player(0) == 2, "individual con 1 mando: el mando es del J1")
	im.refresh_gamepads([])


func _independent_controls() -> void:
	await _place(p1, Vector2(400, GROUND_Y))
	await _place(p2, Vector2(700, GROUND_Y))
	var a := p1.global_position.x
	var b := p2.global_position.x
	Input.action_press("p1_move_right")
	await t.wait_frames(20)
	Input.action_release("p1_move_right")
	t.check(p1.global_position.x > a + 30.0 and absf(p2.global_position.x - b) < 1.0, "J1 se mueve solo con sus controles")
	await t.wait_frames(20)
	a = p1.global_position.x
	Input.action_press("p2_move_left")
	await t.wait_frames(20)
	Input.action_release("p2_move_left")
	t.check(p2.global_position.x < b - 30.0 and absf(p1.global_position.x - a) < 1.0, "J2 se mueve solo con sus controles")
	Input.action_press("p2_jump")
	await t.wait_frames(6)
	Input.action_release("p2_jump")
	t.check(p2.state_machine.is_in(&"Jump") and p1.is_on_floor(), "J2 salta sin que salte J1")
	await t.wait_frames(60)


func _camera() -> void:
	var cam: CoopCamera = level.camera
	await _place(p1, Vector2(500, GROUND_Y))
	await _place(p2, Vector2(600, GROUND_Y))
	await t.wait_frames(60)
	var mid := (p1.global_position.x + p2.global_position.x) * 0.5
	t.check(absf(cam.global_position.x - mid) < 4.0, "la cámara se centra entre ambos")
	t.check(cam.zoom.x > 0.97, "juntos: sin alejar la cámara")
	await _place(p2, Vector2(1450, GROUND_Y))
	await t.wait_frames(90)
	t.check(cam.zoom.x < 0.95 and cam.zoom.x >= cam.min_zoom - 0.001, "separados: la cámara se aleja (zoom %.2f)" % cam.zoom.x)
	await _place(p1, Vector2(100, GROUND_Y))
	await _place(p2, Vector2(2600, GROUND_Y))
	await t.wait_frames(90)
	var visible_width := t.get_viewport().get_visible_rect().size.x / cam.zoom.x
	t.check(p2.global_position.x - p1.global_position.x <= visible_width, "nadie sale de la pantalla")


func _stand_on_partner() -> void:
	# Juntos primero: separados más que la pantalla, la cámara retendría a J1.
	p2.global_position = Vector2(600, 400)
	await _place(p1, Vector2(600, GROUND_Y))
	await _place(p2, Vector2(600, 480), false)
	await t.wait_frames(60)
	var head_y := p1.global_position.y - p1.config.body_height - p1.config.head_platform_offset
	t.check(p2.is_on_floor() and absf(p2.global_position.y - head_y) < 4.0, "J2 se para sobre la cabeza de J1")
	var x0 := p2.global_position.x
	Input.action_press("p1_move_right")
	await t.wait_frames(20)
	Input.action_release("p1_move_right")
	await t.wait_frames(20)
	t.check(p2.global_position.x > x0 + 30.0 and p2.is_on_floor(), "J1 lleva a J2 encima al caminar")
	Input.action_press("p2_crouch")
	await t.wait_frames(3)
	Input.action_press("p2_jump")
	await t.wait_frames(4)
	Input.action_release("p2_jump")
	Input.action_release("p2_crouch")
	await t.wait_frames(50)
	t.check(p2.is_on_floor() and absf(p2.global_position.y - GROUND_Y) < 3.0, "J2 baja de la cabeza con abajo + saltar")


func _respawn_and_elimination() -> void:
	await _place(p1, Vector2(400, GROUND_Y))
	await _place(p2, Vector2(900, GROUND_Y))
	p1.health.kill(null)
	await t.wait_frames(int(p1.config.respawn_delay * 60.0) + 10)
	t.check(p1.is_alive() and p1.global_position.distance_to(p2.global_position) < 2.0,
		"J1 reaparece junto a su compañero")
	t.check(GameManager.lives[0] == GameManager.STARTING_LIVES - 1, "J1 perdió una vida")

	var over := [false]
	var on_over := func() -> void: over[0] = true
	EventBus.game_over.connect(on_over)
	GameManager.lives[0] = 1
	p1.health.kill(null)
	await t.wait_frames(int(p1.config.respawn_delay * 60.0) + 10)
	t.check(GameManager.eliminated[0] and not p1.visible, "J1 sin vidas queda eliminado")
	t.check(not over[0] and GameManager.is_player_active(1), "la partida sigue mientras J2 tenga vidas")
	var cam: CoopCamera = level.camera
	t.check(cam.targets.size() == 1 and cam.targets[0] == p2, "la cámara sigue solo al jugador que queda")
	GameManager.lives[1] = 1
	p2.health.kill(null)
	await t.wait_frames(int(p2.config.respawn_delay * 60.0) + 10)
	t.check(over[0], "sin jugadores activos termina la partida")
	EventBus.game_over.disconnect(on_over)
	await t.wait_frames(130)


# ---------------------------------------------------------------- utilidades
func _place(p: Player, pos: Vector2, settle := true) -> void:
	for prefix in ["p1_", "p2_"]:
		for a in InputManager.COMMANDS:
			Input.action_release(prefix + a)
	p.global_position = pos
	p.velocity = Vector2.ZERO
	p.set_low_profile(false)
	p.set_platform_collision(true)
	p.state_machine.transition_to(&"Fall")
	if settle:
		for i in 60:
			if p.is_on_floor() and p.state_machine.is_in(&"Idle"):
				break
			await t.wait_frames(1)
	await t.wait_frames(2)


func _pad_device(action: StringName) -> int:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			return ev.device
	return -100
