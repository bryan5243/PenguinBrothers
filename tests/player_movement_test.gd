extends RefCounted
## Pruebas de movimiento del jugador sobre el nivel de prueba (Fase 2).
## Las ejecuta tests/smoke_test.gd; `t` es el nodo de prueba (check, wait_frames).

const TEST_LEVEL := "res://scenes/worlds/test_level/PlayerTestLevel.tscn"
const GROUND_Y := 640.0
const LADDER_TOP_Y := 400.0

var t: Node
var p: Player


func run(test: Node) -> void:
	t = test
	GameManager.start_new_game(GameManager.GameMode.SOLO)
	var level := (load(TEST_LEVEL) as PackedScene).instantiate()
	t.get_tree().root.add_child(level)
	p = level.player
	await t.wait_frames(20)
	t.check(p.is_on_floor() and _in(&"Idle"), "arranca de pie en el suelo")
	t.check(p.animator.animation == &"idle", "animación idle")

	await _walk_and_run()
	await _jumps()
	await _coyote_and_buffer()
	await _crouch_slide_crawl()
	await _ladder()
	await _drop_through()
	await _hurt()
	await _death_and_respawn()

	level.queue_free()
	await t.wait_frames(2)


# ---------------------------------------------------------------- escenarios
func _walk_and_run() -> void:
	await _place(Vector2(160, GROUND_Y))
	var x0 := p.global_position.x
	Input.action_press("p1_move_right")
	await t.wait_frames(20)
	t.check(p.global_position.x > x0 + 40.0 and _in(&"Move"), "camina a la derecha")
	t.check(p.animator.animation == &"walk" and p.facing == 1, "animación walk mirando a la derecha")
	await t.wait_frames(40)
	t.check(absf(p.velocity.x) > p.config.move_speed + 20.0, "pasa a correr tras moverse un rato")
	t.check(p.animator.animation == &"run", "animación run")
	Input.action_release("p1_move_right")
	await t.wait_frames(30)
	t.check(_in(&"Idle") and is_zero_approx(p.velocity.x), "frena hasta detenerse")
	Input.action_press("p1_move_left")
	await t.wait_frames(5)
	Input.action_release("p1_move_left")
	t.check(p.facing == -1 and p.animator.flip_h, "gira a la izquierda")


func _jumps() -> void:
	await _place(Vector2(160, GROUND_Y))
	Input.action_press("p1_jump")
	var full := await _measure_jump_height(40)
	Input.action_release("p1_jump")
	var expected := p.config.jump_force * p.config.jump_force / (2.0 * p.config.gravity)
	t.check(full > expected * 0.85 and full < expected * 1.1, "altura de salto completa (%.0f px)" % full)
	await _wait_until(func() -> bool: return p.is_on_floor(), 90)
	t.check(p.is_on_floor(), "vuelve al suelo tras saltar")

	await _place(Vector2(160, GROUND_Y))
	Input.action_press("p1_jump")
	await t.wait_frames(2)
	Input.action_release("p1_jump")
	var short := await _measure_jump_height(40)
	t.check(short < full * 0.7, "salto corto al soltar pronto (%.0f px)" % short)
	await _wait_until(func() -> bool: return p.is_on_floor(), 90)


func _coyote_and_buffer() -> void:
	# Coyote time: saltar justo después de salir de una plataforma.
	await _place(Vector2(425, 540))
	Input.action_press("p1_move_right")
	await _wait_until(func() -> bool: return _in(&"Fall"), 60)
	Input.action_release("p1_move_right")
	Input.action_press("p1_jump")
	await t.wait_frames(2)
	Input.action_release("p1_jump")
	t.check(_in(&"Jump") or p.velocity.y < 0.0, "coyote time permite saltar tras dejar el borde")
	await _wait_until(func() -> bool: return p.is_on_floor(), 120)

	# Jump buffering: pulsar saltar justo antes de tocar el suelo.
	await _place(Vector2(160, GROUND_Y - 90), false)
	await _wait_until(func() -> bool: return p.global_position.y > GROUND_Y - 22.0, 60)
	Input.action_press("p1_jump")
	await t.wait_frames(1)
	Input.action_release("p1_jump")
	await _wait_until(func() -> bool: return p.velocity.y < 0.0, 12)
	t.check(p.velocity.y < 0.0, "jump buffering salta al aterrizar")
	await _wait_until(func() -> bool: return p.is_on_floor(), 120)


func _crouch_slide_crawl() -> void:
	await _place(Vector2(160, GROUND_Y))
	Input.action_press("p1_crouch")
	await t.wait_frames(6)
	t.check(_in(&"Crouch") and p.is_low, "se agacha y reduce su cuerpo")
	t.check(p.animator.animation == &"crouch", "animación crouch")
	Input.action_release("p1_crouch")
	await t.wait_frames(4)
	t.check(_in(&"Idle") and not p.is_low, "se levanta al soltar")

	await _place(Vector2(160, GROUND_Y))
	Input.action_press("p1_move_right")
	await t.wait_frames(50)
	Input.action_press("p1_crouch")
	await t.wait_frames(3)
	t.check(_in(&"Slide") and absf(p.velocity.x) > p.config.run_speed, "corriendo + agacharse = deslizamiento")
	t.check(p.animator.animation == &"slide", "animación slide")
	Input.action_release("p1_move_right")
	Input.action_release("p1_crouch")
	await _wait_until(func() -> bool: return not _in(&"Slide"), 60)

	# Bajo el túnel no puede levantarse, pero puede gatear hasta salir.
	for a in InputManager.COMMANDS:
		Input.action_release("p1_" + a)
	p.set_low_profile(true)
	p.global_position = Vector2(2000, GROUND_Y)
	p.velocity = Vector2.ZERO
	p.state_machine.transition_to(&"Crouch")
	await t.wait_frames(6)
	t.check(_in(&"Crouch") and not p.can_stand_up(), "bajo un techo bajo sigue agachado")
	Input.action_press("p1_move_right")
	await _wait_until(func() -> bool: return _in(&"Idle") or _in(&"Move"), 200)
	Input.action_release("p1_move_right")
	t.check(p.global_position.x > 2200.0 and not p.is_low, "gatea hasta salir del túnel y se levanta")


func _ladder() -> void:
	await _place(Vector2(1300, GROUND_Y))
	Input.action_press("p1_up")
	await t.wait_frames(3)
	t.check(_in(&"Climb"), "sube a la escalera con arriba")
	t.check(p.animator.animation == &"climb", "animación climb")
	await _wait_until(func() -> bool: return not _in(&"Climb"), 120)
	Input.action_release("p1_up")
	await t.wait_frames(10)
	t.check(p.is_on_floor() and absf(p.global_position.y - LADDER_TOP_Y) < 3.0, "llega arriba y queda sobre la plataforma")

	Input.action_press("p1_crouch")
	await t.wait_frames(20)
	t.check(_in(&"Climb") and p.global_position.y > LADDER_TOP_Y + 20.0, "baja por la escalera desde arriba")
	Input.action_release("p1_crouch")
	Input.action_press("p1_jump")
	await t.wait_frames(2)
	Input.action_release("p1_jump")
	t.check(not _in(&"Climb"), "saltar suelta la escalera")
	await _wait_until(func() -> bool: return p.is_on_floor(), 120)


func _drop_through() -> void:
	await _place(Vector2(330, 540))
	t.check(p.is_on_platform(), "detecta que está sobre una plataforma")
	Input.action_press("p1_crouch")
	await t.wait_frames(3)
	Input.action_press("p1_jump")
	await t.wait_frames(15)
	Input.action_release("p1_jump")
	Input.action_release("p1_crouch")
	t.check(p.global_position.y > 560.0, "abajo + saltar atraviesa la plataforma")
	await _wait_until(func() -> bool: return p.is_on_floor(), 120)
	t.check(p.get_collision_mask_value(Player.PLATFORM_LAYER), "vuelve a chocar con plataformas")


func _hurt() -> void:
	await _place(Vector2(160, GROUND_Y))
	var enemy := Node2D.new()
	p.get_parent().add_child(enemy)
	enemy.global_position = Vector2(120, GROUND_Y)
	var hp := p.health.current_health
	p.take_damage(1, enemy)
	await t.wait_frames(2)
	t.check(_in(&"Hurt") and p.velocity.x > 0.0, "recibe daño con empuje alejándose del golpe")
	t.check(p.health.current_health == hp - 1 and p.health.is_invulnerable(), "pierde vida y queda invulnerable")
	p.take_damage(1, enemy)
	t.check(p.health.current_health == hp - 1, "no recibe daño durante la invulnerabilidad")
	await _wait_until(func() -> bool: return _in(&"Idle"), 90)
	t.check(_in(&"Idle"), "recupera el control tras el golpe")
	enemy.queue_free()
	p.health.reset()


func _death_and_respawn() -> void:
	var lives := GameManager.lives[0]
	await _place(Vector2(1575, 560), false)
	await _wait_until(func() -> bool: return _in(&"Dead"), 120)
	t.check(_in(&"Dead"), "caer al vacío mata al jugador")
	await _wait_until(func() -> bool: return not _in(&"Dead"), 150)
	t.check(GameManager.lives[0] == lives - 1, "pierde una vida")
	t.check(p.global_position.distance_to(p.spawn_position) < 2.0 and p.health.is_invulnerable(),
		"reaparece en el punto de inicio con invulnerabilidad")

	var over := [false]
	var on_over := func() -> void: over[0] = true
	EventBus.game_over.connect(on_over)
	GameManager.lives[0] = 1
	p.health.kill(null)
	await t.wait_frames(int(p.config.respawn_delay * 60.0) + 10)
	t.check(over[0], "sin vidas termina la partida")
	EventBus.game_over.disconnect(on_over)
	# El nivel reinicia tras la partida; esperar a que termine su temporizador.
	await t.wait_frames(130)


# ---------------------------------------------------------------- utilidades
func _in(state: StringName) -> bool:
	return p.state_machine.is_in(state)


func _place(pos: Vector2, settle := true) -> void:
	for a in InputManager.COMMANDS:
		Input.action_release("p1_" + a)
	p.global_position = pos
	p.velocity = Vector2.ZERO
	p.set_low_profile(false)
	p.set_platform_collision(true)
	p.state_machine.transition_to(&"Fall")
	if settle:
		await _wait_until(func() -> bool: return p.is_on_floor() and _in(&"Idle"), 60)
		await t.wait_frames(2)
	else:
		await t.wait_frames(1)


func _wait_until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await t.wait_frames(1)


func _measure_jump_height(frames: int) -> float:
	var start := p.global_position.y
	var top := start
	for i in frames:
		await t.wait_frames(1)
		top = minf(top, p.global_position.y)
	return start - top
