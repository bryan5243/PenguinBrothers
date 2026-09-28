class_name Bomb
extends RigidBody2D
## Bomba base con física (rueda, rebota, se encadena). Todos los tipos usan esta misma
## escena; lo que cambia es su BombData (daño, radio, mecha, peso, rebote, sprite...).
## Las bombas salen de un BombPool y vuelven a él al explotar (no se crean ni destruyen
## durante la partida).
##
## Estados: POOLED (guardada) -> ARMED (mecha encendida, libre) <-> HELD (en manos de un
## jugador, la mecha sigue) -> EXPLODED -> POOLED.

signal exploded(bomb: Bomb)
signal returned_to_pool(bomb: Bomb)

enum State { POOLED, ARMED, HELD, EXPLODED }

const LAYER := 1 << 3        # capa 4: bombas
const MASK := 1 | (1 << 3) | (1 << 5)   # mundo, bombas, plataformas atravesables
## Punta de la mecha dentro de la textura (px desde el centro de la esfera, textura sin escalar).
const FUSE_TIP := Vector2(14.0, -34.0)
const DEFAULT_EXPLOSION := preload("res://scenes/bombs/Explosion.tscn")

var data: BombData
var owner_index := -1
var state := State.POOLED
var fuse_left := 0.0
var holder: Node = null
var pool: BombPool

var _detonate_timer := -1.0
var _blink_time := 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var sparks: CPUParticles2D = $Sparks
@onready var kick_area: Area2D = $KickArea
@onready var kick_shape: CollisionShape2D = $KickArea/Shape


func _ready() -> void:
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = false
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	_go_to_pool()


## Configura la bomba según su tipo. Se llama cada vez que sale del pool.
func setup(bomb_data: BombData, bomb_owner: int) -> void:
	data = bomb_data
	owner_index = bomb_owner
	var circle := CircleShape2D.new()
	circle.radius = data.body_radius
	shape.shape = circle
	var kick_circle := CircleShape2D.new()
	kick_circle.radius = data.body_radius + 6.0
	kick_shape.shape = kick_circle
	mass = data.mass
	gravity_scale = data.gravity_scale
	linear_damp = data.linear_damp
	var mat := PhysicsMaterial.new()
	mat.bounce = data.bounce
	mat.friction = data.friction
	physics_material_override = mat
	sprite.texture = data.texture
	var s := data.body_radius * 2.0 / data.texture_sphere_diameter
	sprite.scale = Vector2(s, s)
	sparks.position = FUSE_TIP * s


## Saca la bomba al mundo con la mecha encendida.
func arm_at(pos: Vector2, initial_velocity := Vector2.ZERO) -> void:
	state = State.ARMED
	fuse_left = data.fuse_time
	_detonate_timer = -1.0
	_blink_time = 0.0
	holder = null
	freeze = true
	global_position = pos
	rotation = 0.0
	visible = true
	sparks.emitting = true
	set_physics_process(true)
	_set_solid(true)
	freeze = false
	linear_velocity = initial_velocity
	angular_velocity = 0.0


## Un jugador la sostiene: deja de chocar y la mueve quien la lleva.
func hold(by: Node) -> void:
	if state != State.ARMED:
		return
	state = State.HELD
	holder = by
	freeze = true
	_set_solid(false)
	z_index = 5


## Suelta la bomba con una velocidad (lanzar, soltar, empujar).
func release(initial_velocity: Vector2) -> void:
	if state != State.HELD:
		return
	state = State.ARMED
	holder = null
	z_index = 0
	_set_solid(true)
	freeze = false
	linear_velocity = initial_velocity
	angular_velocity = initial_velocity.x / maxf(data.body_radius, 1.0)


## Patada: solo si está libre en el suelo o casi quieta.
func kick(direction: int, speed: float) -> bool:
	if state != State.ARMED:
		return false
	linear_velocity = Vector2(direction * speed, minf(linear_velocity.y, -60.0))
	AudioManager.play_sfx("bomb_kick")
	return true


func is_free() -> bool:
	return state == State.ARMED


## Detona ahora (delay 0) o tras `delay` segundos (reacción en cadena).
func detonate(delay := 0.0) -> void:
	if state == State.POOLED or state == State.EXPLODED:
		return
	if delay <= 0.0:
		_explode()
	elif _detonate_timer < 0.0 or delay < _detonate_timer:
		_detonate_timer = delay


## Alcanzada por otra explosión: reacción en cadena.
func apply_explosion(_center: Vector2, _other: BombData, _by_owner: int, _source: Node) -> void:
	detonate(data.chain_delay if data else 0.0)


func _physics_process(delta: float) -> void:
	if state != State.ARMED and state != State.HELD:
		return
	if _detonate_timer >= 0.0:
		_detonate_timer -= delta
		if _detonate_timer <= 0.0:
			_explode()
			return
	fuse_left -= delta
	if fuse_left <= 0.0:
		_explode()
		return
	_update_warning(delta)
	if state == State.ARMED:
		_check_kicks()


func _update_warning(delta: float) -> void:
	if fuse_left > data.fuse_warning_time:
		sprite.modulate = Color.WHITE
		return
	# Parpadeo cada vez más rápido en los últimos instantes.
	_blink_time += delta * lerpf(18.0, 6.0, fuse_left / maxf(data.fuse_warning_time, 0.01))
	sprite.modulate = Color(1.8, 0.7, 0.6) if int(_blink_time) % 2 == 0 else Color.WHITE


func _check_kicks() -> void:
	if not kick_area.monitoring:
		return
	for body in kick_area.get_overlapping_bodies():
		var p := body as Player
		if p == null or not p.is_alive() or p.bombs.held_bomb != null or not p.is_on_floor():
			continue
		var dx := global_position.x - p.global_position.x
		var toward := signf(dx) == signf(p.velocity.x) and absf(p.velocity.x) >= p.config.kick_min_speed
		if toward and absf(linear_velocity.x) < p.config.kick_speed * 0.5:
			kick(int(signf(dx)), p.config.kick_speed)
			return


func _explode() -> void:
	if state == State.EXPLODED or state == State.POOLED:
		return
	var center := global_position
	var was_held_by := holder
	state = State.EXPLODED
	holder = null
	var fx: Explosion = pool.acquire_explosion() if pool else null
	if fx == null:
		fx = (data.explosion_effect if data.explosion_effect else DEFAULT_EXPLOSION).instantiate() as Explosion
		get_parent().add_child(fx)
	fx.trigger(center, data, owner_index, self)
	if was_held_by and was_held_by.has_method("on_held_bomb_exploded"):
		was_held_by.on_held_bomb_exploded(self)
	exploded.emit(self)
	_go_to_pool()


func _go_to_pool() -> void:
	state = State.POOLED
	holder = null
	visible = false
	z_index = 0
	sparks.emitting = false
	freeze = true
	_set_solid(false)
	set_physics_process(false)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	returned_to_pool.emit(self)


func _set_solid(solid: bool) -> void:
	collision_layer = LAYER if solid else 0
	collision_mask = MASK if solid else 0
