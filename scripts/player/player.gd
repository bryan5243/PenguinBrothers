class_name Player
extends CharacterBody2D
## Pingüino jugable. Coordina sus componentes:
##   PlayerInput     -> qué quiere hacer el jugador este frame
##   StateMachine    -> qué hace (Idle, Move, Jump, Fall, Land, Crouch, Slide, Climb, Hurt, Dead)
##   PlayerAnimator  -> cómo se ve (separado de la lógica)
##   HealthComponent -> vida, daño e invulnerabilidad
## Aquí viven solo las utilidades compartidas por los estados (gravedad, control horizontal,
## temporizadores de salto, cuerpo agachado, escaleras). La lógica de cada acción está en su estado.
##
## Orden por frame físico: leer entrada -> temporizadores -> estado actual -> move_and_slide.

signal facing_changed(direction: int)
signal respawned

enum Character { BLUE_PENGUIN, PINK_PENGUIN }

const PLATFORM_LAYER := 6

@export_range(0, 1) var player_index := 0
@export var character: Character = Character.BLUE_PENGUIN
@export var config: PlayerConfig

var input: PlayerInput
var facing := 1:
	set(value):
		if value != 0 and signi(value) != facing:
			facing = signi(value)
			if animator:
				animator.set_facing(facing)
			facing_changed.emit(facing)
var spawn_position := Vector2.ZERO
## Objeto cargado sobre la cabeza (barril, bomba). Lo gestionan los estados de carga (Fase 5).
var carried_object: Node2D = null
## Altura bajo la cual el jugador muere. Se inicializa desde config; el nivel puede cambiarla.
var fall_death_y := 1400.0
var is_low := false

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _drop_timer := 0.0

@onready var state_machine: StateMachine = $StateMachine
@onready var animator: PlayerAnimator = $Animator
@onready var health: HealthComponent = $Health
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var ladder_detector: Area2D = $LadderDetector
@onready var ceiling_check: ShapeCast2D = $CeilingCheck


func _ready() -> void:
	if config == null:
		config = PlayerConfig.new()
	input = PlayerInput.new(player_index)
	spawn_position = global_position
	fall_death_y = config.fall_death_y
	state_machine.auto_process = false
	_setup_body()
	health.max_health = config.max_health
	health.invulnerability_time = config.invulnerability_time
	health.reset()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.invulnerability_changed.connect(animator.set_blinking)
	animator.setup(character)
	EventBus.player_spawned.emit(self, player_index)


func _physics_process(delta: float) -> void:
	input.update()
	_update_timers(delta)
	state_machine.physics_update(delta)
	move_and_slide()
	if global_position.y > fall_death_y and not health.is_dead:
		health.kill(null)


# ---------------------------------------------------------------- movimiento compartido
func apply_gravity(delta: float, multiplier := 1.0) -> void:
	velocity.y = minf(velocity.y + config.gravity * multiplier * delta, config.max_fall_speed)


## Acelera o frena hacia `target_speed` (px/s, con signo). Actualiza la orientación.
func apply_horizontal(delta: float, target_speed: float) -> void:
	var on_floor := is_on_floor()
	var rate: float
	if is_zero_approx(target_speed):
		rate = config.friction if on_floor else config.air_friction
	elif signf(target_speed) != signf(velocity.x) and not is_zero_approx(velocity.x):
		# Girar se siente ágil: se usa el mayor entre aceleración y frenado.
		rate = maxf(config.acceleration, config.friction) if on_floor else config.air_acceleration
	else:
		rate = config.acceleration if on_floor else config.air_acceleration
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)


func face_input() -> void:
	if absf(input.move_axis) > 0.2:
		facing = signi(int(signf(input.move_axis)))


# ---------------------------------------------------------------- salto (coyote + buffer)
func _update_timers(delta: float) -> void:
	_coyote_timer = config.coyote_time if is_on_floor() else maxf(0.0, _coyote_timer - delta)
	if input.jump_pressed:
		_jump_buffer_timer = config.jump_buffer_time
	else:
		_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0 and not state_machine.is_in(&"Climb"):
			set_platform_collision(true)


func has_buffered_jump() -> bool:
	return _jump_buffer_timer > 0.0


func can_jump() -> bool:
	return has_buffered_jump() and (is_on_floor() or _coyote_timer > 0.0)


## Gasta el salto almacenado y el tiempo de coyote (para no saltar dos veces).
func consume_jump() -> void:
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0


# ---------------------------------------------------------------- plataformas atravesables
func is_on_platform() -> bool:
	if not is_on_floor():
		return false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var body := col.get_collider() as CollisionObject2D
		if body and col.get_normal().y < -0.5 and body.get_collision_layer_value(PLATFORM_LAYER) \
				and not body.get_collision_layer_value(1):
			return true
	return false


## Abajo + saltar sobre una plataforma: la atraviesa hacia abajo.
func drop_through_platform() -> void:
	consume_jump()
	set_platform_collision(false)
	_drop_timer = config.drop_through_time
	position.y += 2.0


func set_platform_collision(enabled: bool) -> void:
	set_collision_mask_value(PLATFORM_LAYER, enabled)


# ---------------------------------------------------------------- cuerpo agachado
func _setup_body() -> void:
	var capsule := CapsuleShape2D.new()
	capsule.radius = config.body_radius
	body_shape.shape = capsule
	var standing := CapsuleShape2D.new()
	standing.radius = config.body_radius - 2.0
	standing.height = config.body_height - 4.0
	ceiling_check.shape = standing
	ceiling_check.position = Vector2(0.0, -config.body_height * 0.5 - 1.0)
	ceiling_check.target_position = Vector2.ZERO
	ceiling_check.enabled = false
	set_low_profile(false)


## Reduce la altura del cuerpo al agacharse o deslizarse.
func set_low_profile(low: bool) -> void:
	is_low = low
	var capsule := body_shape.shape as CapsuleShape2D
	var h := config.crouch_height if low else config.body_height
	capsule.height = maxf(h, config.body_radius * 2.0)
	body_shape.position = Vector2(0.0, -h * 0.5)


## ¿Hay espacio para ponerse de pie?
func can_stand_up() -> bool:
	if not is_low:
		return true
	ceiling_check.force_shapecast_update()
	return not ceiling_check.is_colliding()


# ---------------------------------------------------------------- escaleras
func get_overlapping_ladder() -> Ladder:
	for area in ladder_detector.get_overlapping_areas():
		if area is Ladder:
			return area
	return null


## ¿Puede empezar a trepar? Arriba = desde abajo o en el aire; abajo = desde lo alto de la escalera.
func wants_ladder() -> Ladder:
	var ladder := get_overlapping_ladder()
	if ladder == null:
		return null
	var feet := global_position.y
	if input.up_held and feet > ladder.top_y() + 4.0:
		return ladder
	if input.crouch_held and is_on_floor() and absf(feet - ladder.top_y()) < 12.0:
		return ladder
	return null


# ---------------------------------------------------------------- vida
func is_carrying() -> bool:
	return carried_object != null and is_instance_valid(carried_object)


func take_damage(amount: int, source: Node = null) -> void:
	health.take_damage(amount, source)


func respawn(at: Vector2 = spawn_position) -> void:
	global_position = at
	velocity = Vector2.ZERO
	facing = 1
	health.reset()
	health.start_invulnerability(config.invulnerability_time)
	set_low_profile(false)
	set_platform_collision(true)
	collision_layer = 1 << 1
	collision_mask = 1 | (1 << (PLATFORM_LAYER - 1))
	visible = true
	animator.reset_visual()
	state_machine.transition_to(&"Idle")
	EventBus.player_respawned.emit(player_index)
	respawned.emit()


func _on_damaged(amount: int, source: Node) -> void:
	EventBus.player_damaged.emit(player_index, amount, health.current_health)
	if health.is_dead:
		return
	var dir := -float(facing)
	if source is Node2D:
		var dx := global_position.x - (source as Node2D).global_position.x
		if not is_zero_approx(dx):
			dir = signf(dx)
	velocity = Vector2(dir * config.knockback.x, config.knockback.y)
	animator.flash()
	AudioManager.play_sfx("hurt")
	state_machine.transition_to(&"Hurt")


func _on_died() -> void:
	EventBus.player_died.emit(player_index)
	state_machine.transition_to(&"Dead")
