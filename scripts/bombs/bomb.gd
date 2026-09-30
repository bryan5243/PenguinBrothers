class_name Bomb
extends CarryableBody
## Bomba arcade. Todos los tipos usan esta misma escena; lo que cambia es su BombData
## (daño, radio, mecha, botes, sprites de mecha y explosión...). Física controlada (ver
## CarryableBody): se coloca, se lanza, se deja caer, bota un número fijo de veces, rueda y
## frena; nada de simulación realista.
## Sale de un BombPool y vuelve a él al explotar (no se crea ni destruye en plena partida).
##
## Estados: POOLED (guardada) -> ARMED (mecha encendida, libre) <-> HELD (en manos de un
## jugador, la mecha sigue) -> EXPLODED -> POOLED.

signal exploded(bomb: Bomb)
signal returned_to_pool(bomb: Bomb)

enum State { POOLED, ARMED, HELD, EXPLODED }

const LAYER := 1 << 3        # capa 4: bombas
const MASK := 1 | (1 << 3) | (1 << 5)   # mundo, bombas, plataformas atravesables
const DEFAULT_EXPLOSION := preload("res://scenes/bombs/Explosion.tscn")

var data: BombData
var owner_index := -1
## Nivel de poder con el que se lanzó (1–4) y su multiplicador de alcance.
var power_level := 1
var radius_multiplier := 1.0
var state := State.POOLED
var fuse_left := 0.0
var pool: BombPool

var _detonate_timer := -1.0
var _blink_time := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var kick_area: Area2D = $KickArea
@onready var kick_shape: CollisionShape2D = $KickArea/Shape


func _ready() -> void:
	_go_to_pool()


## Configura la bomba según su tipo y el poder de quien la usa. Se llama al salir del pool.
func setup(bomb_data: BombData, bomb_owner: int, level := 1, radius_mult := 1.0) -> void:
	data = bomb_data
	owner_index = bomb_owner
	power_level = level
	radius_multiplier = radius_mult
	var circle := CircleShape2D.new()
	circle.radius = data.body_radius
	shape.shape = circle
	var kick_circle := CircleShape2D.new()
	kick_circle.radius = data.body_radius + 6.0
	kick_shape.shape = kick_circle
	apply_motion(data)
	var s := data.body_radius * 2.0 / data.texture_sphere_diameter
	sprite.scale = Vector2(s, s)
	if data.frames and data.frames.has_animation(&"fuse"):
		sprite.sprite_frames = data.frames
		sprite.animation = &"fuse"
	elif data.texture:
		var still := SpriteFrames.new()
		still.add_frame(&"default", data.texture)
		sprite.sprite_frames = still
		sprite.animation = &"default"


## Saca la bomba al mundo con la mecha encendida.
func arm_at(pos: Vector2, initial_velocity := Vector2.ZERO) -> void:
	state = State.ARMED
	fuse_left = data.fuse_time
	_detonate_timer = -1.0
	_blink_time = 0.0
	holder = null
	global_position = pos
	visible = true
	z_index = 0
	sprite.play()
	set_physics_process(true)
	_set_solid(true)
	launch(initial_velocity)


func can_be_picked_up() -> bool:
	return state == State.ARMED


func hold(by: Node) -> void:
	if state != State.ARMED:
		return
	state = State.HELD
	super.hold(by)


func release(initial_velocity: Vector2) -> void:
	if state != State.HELD:
		return
	state = State.ARMED
	super.release(initial_velocity)


func kick(direction: int, speed: float) -> bool:
	if state != State.ARMED:
		return false
	super.kick(direction, speed)
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
func apply_explosion(_info: ExplosionInfo) -> void:
	detonate(data.chain_delay if data else 0.0)


func make_explosion_info() -> ExplosionInfo:
	var info := ExplosionInfo.from_bomb(data, global_position, power_level, radius_multiplier, owner_index, self)
	if power_level >= Explosion.SPECIAL_LEVEL:
		info.damage += data.special_damage_bonus
		info.break_power += data.special_break_bonus
	return info


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
		arcade_step(delta)
		# Rueda visualmente según su velocidad (solo el dibujo).
		sprite.rotation += velocity.x / maxf(data.body_radius, 1.0) * delta if is_on_floor() else 0.0
		_check_kicks()


func _update_warning(delta: float) -> void:
	if fuse_left > data.fuse_warning_time:
		sprite.modulate = Color.WHITE
		return
	# Parpadeo cada vez más rápido en los últimos instantes.
	_blink_time += delta * lerpf(18.0, 6.0, fuse_left / maxf(data.fuse_warning_time, 0.01))
	sprite.modulate = Color(1.8, 0.7, 0.6) if int(_blink_time) % 2 == 0 else Color.WHITE


func _check_kicks() -> void:
	if not _kicks_enabled():
		return
	for body in kick_area.get_overlapping_bodies():
		var p := body as Player
		if p == null or not p.is_alive() or p.bombs.held_object != null or not p.is_on_floor():
			continue
		var dx := global_position.x - p.global_position.x
		var toward := signf(dx) == signf(p.velocity.x) and absf(p.velocity.x) >= p.config.kick_min_speed
		if toward and absf(velocity.x) < p.config.kick_speed * 0.5 and is_on_floor():
			kick(int(signf(dx)), p.config.kick_speed)
			return


func _explode() -> void:
	if state == State.EXPLODED or state == State.POOLED:
		return
	var info := make_explosion_info()
	var was_held_by := holder
	state = State.EXPLODED
	holder = null
	var fx: Explosion = pool.acquire_explosion() if pool else null
	if fx == null:
		fx = (data.explosion_effect if data.explosion_effect else DEFAULT_EXPLOSION).instantiate() as Explosion
		get_parent().add_child(fx)
	fx.trigger(info)
	if was_held_by and was_held_by.has_method("on_held_object_gone"):
		was_held_by.on_held_object_gone(self)
	exploded.emit(self)
	_go_to_pool()


func _go_to_pool() -> void:
	state = State.POOLED
	holder = null
	_saved_layers = Vector2i(-1, -1)
	visible = false
	z_index = 0
	sprite.stop()
	sprite.rotation = 0.0
	_set_solid(false)
	set_physics_process(false)
	velocity = Vector2.ZERO
	returned_to_pool.emit(self)


func _set_solid(solid: bool) -> void:
	collision_layer = LAYER if solid else 0
	collision_mask = MASK if solid else 0


## Las patadas dependen del ajuste del jugador (PlayerConfig.kick_enabled).
func _kicks_enabled() -> bool:
	for node in get_tree().get_nodes_in_group(&"players"):
		var p := node as Player
		if p and p.config and p.config.kick_enabled:
			return true
	return false
