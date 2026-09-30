class_name Enemy
extends CharacterBody2D
## Enemigo arcade de pantalla fija. Una sola escena (Enemy.tscn) para todos: los datos
## (EnemyData) y el comportamiento (EnemyBehavior, elegido por `data.behavior`) lo definen.
##
## Estados (StateMachine, scripts/enemies/states/): Idle, Patrol, Chase, Attack, Hurt, Dead y
## Special (p. ej. esconderse en el caparazón). El enemigo llama él mismo a la máquina en
## cada frame físico: estado -> move_and_slide.
##
## Contrato con la arena: está en el grupo "enemies" y emite `defeated` al morir, así el
## EnemyManager sabe cuándo la pantalla queda limpia. Reacciona a bombas (apply_explosion),
## a barriles lanzados (take_damage) y hace daño a los jugadores por contacto y con su ataque.

signal defeated
signal damaged(amount: int)

const LAYER := 1 << 2                      # capa 3: enemigos
const GROUND_MASK := 1 | (1 << 5)          # mundo + plataformas atravesables
const PLATFORM_LAYER := 6
const PLAYER_LAYER := 1 << 1
## Aparece parpadeando y sin hacer daño durante este tiempo.
const SPAWN_GRACE := 0.6

@export var data: EnemyData

var behavior: EnemyBehavior
var facing := 1:
	set(value):
		if value != 0:
			facing = signi(value)
			if animator:
				animator.flip_h = facing < 0
## Quién le dio el último golpe (para puntos y combos).
var last_attacker := -1
var attack_cooldown := 0.0
var spawn_grace := SPAWN_GRACE
## Tiempo mínimo entre giros voluntarios (perseguir): evita que tiemble de lado a lado.
var turn_timer := 0.0
var rng := RandomNumberGenerator.new()
var _drop_timer := 0.0
var _gravity := 1750.0

@onready var visual_root: Node2D = $VisualRoot
@onready var animator: AnimatedSprite2D = $VisualRoot/Animator
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/Shape
@onready var health: HealthComponent = $Health
@onready var state_machine: StateMachine = $StateMachine


func _enter_tree() -> void:
	add_to_group(&"enemies")


func _ready() -> void:
	rng.randomize()
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 1750.0))
	collision_layer = LAYER
	collision_mask = 1 if data and data.flying else GROUND_MASK
	hitbox.collision_layer = 0
	hitbox.collision_mask = PLAYER_LAYER
	state_machine.auto_process = false
	if data:
		_setup_from_data()
	health.died.connect(_on_died)
	health.damaged.connect(func(amount: int, _s: Node) -> void: damaged.emit(amount))


func _setup_from_data() -> void:
	health.max_health = data.health
	health.invulnerability_time = data.hurt_invulnerability
	health.reset()
	var rect := RectangleShape2D.new()
	rect.size = data.body_size
	body_shape.shape = rect
	hitbox_shape.shape = rect
	var center_y := -data.body_size.y * 0.5 if not data.flying else 0.0
	body_shape.position = Vector2(0, center_y)
	hitbox_shape.position = body_shape.position
	if data.sprite_frames:
		animator.sprite_frames = data.sprite_frames
		var canvas := Vector2(data.sprite_frames.get_meta(&"canvas_size", Vector2i(64, 64)))
		var ref := float(data.sprite_frames.get_meta(&"reference_height", canvas.y))
		animator.offset = Vector2(0, -canvas.y * 0.5) if data.sprite_on_ground else Vector2.ZERO
		visual_root.scale = Vector2.ONE * (data.visual_height / maxf(ref, 1.0))
	behavior = EnemyBehavior.create(self)


func _physics_process(delta: float) -> void:
	if data == null:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	turn_timer = maxf(0.0, turn_timer - delta)
	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			set_collision_mask_value(PLATFORM_LAYER, true)
	if spawn_grace > 0.0:
		spawn_grace -= delta
		animator.visible = int(spawn_grace * 16.0) % 2 == 0 or spawn_grace <= 0.0
	state_machine.physics_update(delta)
	move_and_slide()
	if spawn_grace <= 0.0 and data.contact_damage and is_alive() and behavior.deals_contact_damage():
		_contact_damage()


# ------------------------------------------------------------------ utilidades para estados
func is_alive() -> bool:
	return not health.is_dead


## Reproduce una animación (idle si el enemigo no la tiene). `restart` la empieza de nuevo.
func play(anim: StringName, restart := false) -> void:
	if animator.sprite_frames == null:
		return
	var a := anim if animator.sprite_frames.has_animation(anim) else &"idle"
	if restart or animator.animation != a:
		animator.play(a)


## Giro voluntario (hacia el jugador): como mucho uno cada TURN_DELAY segundos.
const TURN_DELAY := 0.35


func turn_to(direction: int) -> void:
	if direction == 0 or direction == facing or turn_timer > 0.0:
		return
	facing = direction
	turn_timer = TURN_DELAY


func apply_gravity(delta: float) -> void:
	if data.flying:
		return
	velocity.y = minf(velocity.y + _gravity * delta, 950.0)


## Jugador vivo más cercano dentro del alcance de detección (o null).
func find_target() -> Player:
	var best: Player = null
	var best_d := data.detection_range
	for node in get_tree().get_nodes_in_group(&"players"):
		var p := node as Player
		if p == null or not p.is_alive() or not p.is_inside_tree():
			continue
		var d := p.global_position.distance_to(global_position)
		if d < best_d:
			best = p
			best_d = d
	return best


## ¿Hay suelo delante (para no caerse de la plataforma al patrullar)?
func ground_ahead(direction: int) -> bool:
	var from := global_position + Vector2(direction * (data.body_size.x * 0.5 + 4.0), -4.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 24), GROUND_MASK)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## ¿Hay otro enemigo justo delante en el mismo piso? (patrullando se dan la vuelta y no se
## amontonan).
func enemy_ahead(direction: int) -> bool:
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy
		if other == null or other == self or not other.is_alive() or other.data == null or other.data.flying:
			continue
		var dx := other.global_position.x - global_position.x
		if signf(dx) == direction and absf(dx) < data.body_size.x and absf(other.global_position.y - global_position.y) < 12.0:
			return true
	return false


func wall_ahead(direction: int) -> bool:
	return is_on_wall() and signf(get_wall_normal().x) == -direction


## ¿Está sobre una plataforma atravesable (puede bajar de ella)?
func on_one_way_platform() -> bool:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var body := col.get_collider() as CollisionObject2D
		if body and col.get_normal().y < -0.5 and body.get_collision_layer_value(PLATFORM_LAYER) \
				and not body.get_collision_layer_value(1):
			return true
	return false


func drop_through() -> void:
	set_collision_mask_value(PLATFORM_LAYER, false)
	_drop_timer = 0.3
	position.y += 2.0


# ------------------------------------------------------------------ daño
## Golpe directo (barril lanzado, ataque...). Devuelve true si se aplicó.
func take_damage(amount: int, source: Node = null) -> bool:
	if not is_alive() or spawn_grace > 0.0:
		return false
	if source and "owner_index" in source:
		var who: int = source.get("owner_index")
		if who >= 0:
			last_attacker = who
	var final := behavior.modify_damage(amount, source) if behavior else amount
	if final <= 0:
		behavior.on_blocked()
		return false
	if not health.take_damage(final, source):
		return false
	if is_alive():
		state_machine.transition_to(&"Hurt")
	return true


## Alcanzado por una explosión: daño + empuje. Las bombas no distinguen amigo/enemigo.
func apply_explosion(info: ExplosionInfo) -> void:
	if not is_alive():
		return
	if info.owner_index >= 0:
		last_attacker = info.owner_index
	var bonus := info.data.special_damage_bonus if info.power_level >= Explosion.SPECIAL_LEVEL else 0
	if take_damage(info.damage + bonus, info.source) and data.knockback_taken > 0.0:
		var dir := info.push_direction(global_position)
		velocity = Vector2(dir.x * info.knockback, -absf(info.knockback) * 0.4) * data.knockback_taken


func _contact_damage() -> void:
	for body in hitbox.get_overlapping_bodies():
		var p := body as Player
		if p and p.is_alive():
			p.take_damage(data.damage, self)


## Daño del ataque (pinza, picado...) a los jugadores dentro de `reach` delante.
func strike(reach: float) -> void:
	var center := global_position + Vector2(facing * reach * 0.5, -data.body_size.y * 0.5)
	for node in get_tree().get_nodes_in_group(&"players"):
		var p := node as Player
		if p and p.is_alive() and absf(p.global_position.x - center.x) <= reach * 0.5 + 14.0 \
				and absf(p.global_position.y - global_position.y) < 40.0:
			p.take_damage(data.damage, self)


func _on_died() -> void:
	state_machine.transition_to(&"Dead")


## Lo llama el estado Dead al terminar: puntos (con combo), botín, aviso y fuera.
func finish_death() -> void:
	var at := global_position + Vector2(0, -data.body_size.y)
	if last_attacker >= 0:
		ScoreManager.register_kill(last_attacker, data.score, at)
	if data.drop_table:
		var items := _items_parent()
		for item in data.drop_table.roll(rng):
			PowerUp.spawn(item, global_position + Vector2(0, -data.body_size.y * 0.5), items)
	EventBus.enemy_defeated.emit(data.id, global_position, last_attacker)
	AudioManager.play_sfx("enemy_defeated")
	BreakEffect.spawn(get_parent(), global_position + Vector2(0, -data.body_size.y * 0.5), data.death_color)
	defeated.emit()
	queue_free()


func _items_parent() -> Node:
	var arena := get_parent()
	while arena and not arena is Arena:
		arena = arena.get_parent()
	return arena.get_node("Items") if arena and arena.has_node("Items") else get_parent()
