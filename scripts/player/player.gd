class_name Player
extends CharacterBody2D
## Pingüino jugable. Coordina sus componentes:
##   PlayerInput     -> qué quiere hacer el jugador este frame
##   StateMachine    -> qué hace (Idle, Move, Jump, Fall, Land, Crouch, Slide, Climb, Hurt, Dead)
##   VisualRoot/PlayerAnimator -> cómo se ve (separado de la lógica y de la colisión)
##   GroundPoint     -> punto de apoyo (pies) = origen del jugador; el sprite se alinea a él
##   HealthComponent -> vida, daño e invulnerabilidad
##   PlayerBombs     -> bombas: lanzar, colocar, recoger, llevar, cambiar de tipo
## Aquí viven solo las utilidades compartidas por los estados (gravedad, control horizontal,
## temporizadores de salto, cuerpo agachado, escaleras). La lógica de cada acción está en su estado.
##
## Orden por frame físico: leer entrada -> temporizadores -> estado actual -> bombas ->
## move_and_slide -> bomba sostenida sigue a las manos.

signal facing_changed(direction: int)
signal respawned

enum Character { BLUE_PENGUIN, PINK_PENGUIN }

const PLATFORM_LAYER := 6
const PLAYER_COLORS: Array[Color] = [Color(0.45, 0.72, 1.0), Color(1.0, 0.55, 0.82)]
## Ancho de la plataforma sobre la cabeza (el compañero puede pararse encima).
const HEAD_PLATFORM_WIDTH := 30.0

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
## true: reaparece junto al compañero si está vivo y apoyado. false (arenas arcade):
## siempre en su punto de inicio.
var respawn_near_partner := true
## Los dos pingüinos chocan entre sí (se bloquean y se empujan). Lo activa la Arena.
var players_collide := false

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _drop_timer := 0.0

@onready var state_machine: StateMachine = $StateMachine
## Raíz visual: lleva la escala global única del personaje (PlayerConfig.visual_*).
@onready var visual_root: Node2D = $VisualRoot
@onready var animator: PlayerAnimator = $VisualRoot/Animator
@onready var ground_point: Marker2D = $GroundPoint
@onready var health: HealthComponent = $Health
@onready var bombs: PlayerBombs = $Bombs
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var ladder_detector: Area2D = $LadderDetector
@onready var ceiling_check: ShapeCast2D = $CeilingCheck
@onready var head_platform: AnimatableBody2D = $HeadPlatform
@onready var head_shape: CollisionShape2D = $HeadPlatform/Shape
@onready var tag: Label = $Tag


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
	_apply_visual_scale()
	bombs.setup(self)
	add_collision_exception_with(head_platform)
	# La plataforma de la cabeza se mueve a mano (top_level): un AnimatableBody2D sincronizado
	# con la física solo sigue sus propios movimientos, y así el motor calcula su velocidad
	# para llevar encima al compañero.
	head_platform.top_level = true
	head_platform.global_position = global_position
	_setup_tag()
	EventBus.player_spawned.emit(self, player_index)


func _physics_process(delta: float) -> void:
	input.update()
	_update_timers(delta)
	state_machine.physics_update(delta)
	bombs.handle_input()
	move_and_slide()
	if players_collide:
		_push_partner(delta)
	head_platform.global_position = global_position
	bombs.update_held()
	if global_position.y > fall_death_y and not health.is_dead:
		health.kill(null)


# ---------------------------------------------------------------- movimiento compartido
func apply_gravity(delta: float, multiplier := 1.0) -> void:
	velocity.y = minf(velocity.y + config.gravity * multiplier * delta, config.max_fall_speed)


## Acelera o frena hacia `target_speed` (px/s, con signo). Actualiza la orientación.
func apply_horizontal(delta: float, target_speed: float) -> void:
	if carried_object:
		target_speed *= config.carry_speed_multiplier
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
## Escala visual constante para todas las animaciones. La colisión no depende de ella.
func _apply_visual_scale() -> void:
	var s := animator.get_base_scale(config.visual_height, config.visual_scale)
	visual_root.scale = Vector2(s, s)
	visual_root.position = ground_point.position


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
## Cambia la forma física según el ESTADO (agachado / deslizándose), nunca según el
## tamaño del fotograma. `height` < 0 usa config.crouch_height.
func set_low_profile(low: bool, height := -1.0) -> void:
	is_low = low
	var capsule := body_shape.shape as CapsuleShape2D
	var h := config.body_height
	if low:
		h = config.crouch_height if height < 0.0 else height
	capsule.height = maxf(h, config.body_radius * 2.0)
	body_shape.position = Vector2(0.0, -h * 0.5)
	if head_shape:
		head_shape.position = Vector2(0.0, -h - config.head_platform_offset)


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


func take_damage(amount: int, source: Node = null) -> bool:
	return health.take_damage(amount, source)


## Dónde reaparecer: junto a un compañero vivo y apoyado (cooperativo) o en el punto de inicio.
func get_respawn_position() -> Vector2:
	if not respawn_near_partner:
		return spawn_position
	for other in get_tree().get_nodes_in_group(&"players"):
		var partner := other as Player
		if partner and partner != self and partner.is_alive() and partner.is_on_floor() \
				and not partner.state_machine.is_in(&"Climb"):
			return partner.global_position
	return spawn_position


func is_alive() -> bool:
	return not health.is_dead and visible


## Activa o desactiva la plataforma de la cabeza (se desactiva al morir).
func set_head_platform(enabled: bool) -> void:
	head_platform.collision_layer = (1 << (PLATFORM_LAYER - 1)) if enabled else 0


func respawn(at: Vector2 = get_respawn_position()) -> void:
	global_position = at
	velocity = Vector2.ZERO
	facing = 1
	health.reset()
	health.start_invulnerability(config.invulnerability_time)
	set_low_profile(false)
	set_platform_collision(true)
	collision_layer = 1 << 1
	_apply_collision_mask()
	visible = true
	set_head_platform(true)
	bombs.drop_held()
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
	bombs.drop_held()
	animator.flash()
	AudioManager.play_sfx("hurt")
	state_machine.transition_to(&"Hurt")


## Activa o desactiva el choque con el otro pingüino (capa 2 en la máscara).
func set_players_collide(enabled: bool) -> void:
	players_collide = enabled
	_apply_collision_mask()


func _apply_collision_mask() -> void:
	collision_mask = 1 | (1 << (PLATFORM_LAYER - 1))
	if players_collide:
		collision_mask |= 1 << 1


## Caminando contra el compañero en el suelo, lo empuja despacio (él choca con las paredes).
func _push_partner(delta: float) -> void:
	if absf(input.move_axis) < 0.2:
		return
	var dir := signf(input.move_axis)
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var partner := col.get_collider() as Player
		if partner == null or not partner.is_alive() or absf(col.get_normal().x) < 0.7:
			continue
		if signf(partner.global_position.x - global_position.x) != dir:
			continue
		partner.move_and_collide(Vector2(dir * config.push_speed * delta, 0.0))


## Alcanzado por una explosión (lo llama Explosion). Arcade: la bomba no distingue entre
## jugadores, enemigos u objetos; daña (si el tipo tiene `hurts_players`) y empuja.
func apply_explosion(info: ExplosionInfo) -> void:
	if not is_alive():
		return
	if info.hurts_players and take_damage(info.damage, info.source):
		return
	var dx := global_position.x - info.center.x
	var dir := signf(dx) if not is_zero_approx(dx) else float(-facing)
	velocity = Vector2(dir * info.knockback, -info.knockback * 0.6)
	var state_name := state_machine.current_state.name if state_machine.current_state else &""
	if state_name != &"Climb" and state_name != &"Hurt":
		state_machine.transition_to(&"Fall")


func _setup_tag() -> void:
	tag.text = "P%d" % (player_index + 1)
	tag.add_theme_color_override("font_color", PLAYER_COLORS[player_index])
	tag.visible = GameManager.is_coop()


func _on_died() -> void:
	EventBus.player_died.emit(player_index)
	if config.reset_bomb_power_on_death:
		bombs.reset_power()
	state_machine.transition_to(&"Dead")
