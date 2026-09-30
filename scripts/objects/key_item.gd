class_name KeyItem
extends Area2D
## La llave de la fase. Aparece en la pantalla A al limpiarla (cae con un destello hasta el
## suelo o plataforma), un jugador la recoge al tocarla y la lleva flotando sobre la cabeza
## hasta la puerta de la pantalla B. Si el portador muere, la llave cae donde murió y
## cualquiera puede recogerla. Quién la lleva se guarda en StageManager.carry_over para que
## pase de una pantalla a otra (y sobreviva a repetir la pantalla por el tiempo).

signal collected(key: KeyItem, player: Player)
signal dropped(key: KeyItem)

const SCENE_PATH := "res://scenes/items/KeyItem.tscn"
const DATA_PATH := "res://data/items/objective.tres"
const GROUP := &"keys"
const FLOOR_MASK := 1 | (1 << 5)
const FALL_SPEED := 520.0

enum State { FALLING, IDLE, CARRIED, USED }

var data: ObjectiveData
var state := State.FALLING
var holder: Player = null
var _vy := 0.0
var _target_y := 0.0
var _cooldown := 0.0
var _time := 0.0

@onready var sprite: Sprite2D = $Sprite


## Crea la llave en `pos` dentro de `parent` (normalmente Arena/Items), cayendo.
static func spawn(pos: Vector2, parent: Node, cooldown := 0.0) -> KeyItem:
	var key := (load(SCENE_PATH) as PackedScene).instantiate() as KeyItem
	key.position = pos
	key._cooldown = cooldown
	parent.add_child(key)
	return key


func _ready() -> void:
	add_to_group(GROUP)
	if data == null:
		data = load(DATA_PATH) as ObjectiveData
	collision_layer = 0
	collision_mask = 1 << 1
	monitorable = false
	sprite.texture = data.key_texture
	sprite.scale = Vector2.ONE * data.key_scale
	# El origen del nodo es el centro de la llave; el dibujo se levanta media altura al posarse.
	_vy = -240.0
	z_index = 3
	_find_floor.call_deferred()


func _find_floor() -> void:
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 900), FLOOR_MASK)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	var half := data.key_texture.get_height() * data.key_scale * 0.5
	_target_y = (hit["position"].y if hit else global_position.y) - half - 4.0


func is_carried() -> bool:
	return state == State.CARRIED


## Un jugador la coge (también lo usa la Arena B para devolverla a su portador).
func attach_to(player: Player) -> void:
	holder = player
	state = State.CARRIED
	StageManager.carry_over["key"] = true
	StageManager.carry_over["key_owner"] = player.player_index
	sprite.scale = Vector2.ONE * data.carry_scale
	sprite.position = Vector2.ZERO
	sprite.visible = true
	if not player.health.died.is_connected(_on_holder_died):
		player.health.died.connect(_on_holder_died)
	_follow()


## La puerta la gasta al abrirse.
func consume() -> void:
	state = State.USED
	holder = null
	StageManager.carry_over.erase("key")
	StageManager.carry_over.erase("key_owner")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.3)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	_time += delta
	match state:
		State.FALLING:
			_vy = minf(_vy + 1400.0 * delta, FALL_SPEED)
			global_position.y += _vy * delta
			if _vy > 0.0 and _target_y != 0.0 and global_position.y >= _target_y:
				global_position.y = _target_y
				state = State.IDLE
			_cooldown = maxf(0.0, _cooldown - delta)
		State.IDLE:
			_cooldown = maxf(0.0, _cooldown - delta)
			sprite.position.y = sin(_time * 6.0) * data.bob_height
			sprite.rotation = sin(_time * 3.0) * 0.08
			if _cooldown <= 0.0:
				_try_collect()
		State.CARRIED:
			if holder == null or not is_instance_valid(holder) or not holder.is_alive():
				_drop()
			else:
				_follow()


func _try_collect() -> void:
	for body in get_overlapping_bodies():
		var p := body as Player
		if p and p.is_alive():
			attach_to(p)
			ScoreManager.add_points(p.player_index, ScoreManager.table.key, global_position)
			AudioManager.play_sfx("key")
			collected.emit(self, p)
			return


func _follow() -> void:
	global_position = holder.global_position + data.carry_offset
	sprite.position.y = sin(_time * 6.0) * data.bob_height
	sprite.rotation = sin(_time * 3.0) * 0.12


func _on_holder_died() -> void:
	if state == State.CARRIED:
		_drop()


func _drop() -> void:
	if holder and is_instance_valid(holder) and holder.health.died.is_connected(_on_holder_died):
		holder.health.died.disconnect(_on_holder_died)
	var pos := global_position
	holder = null
	state = State.FALLING
	StageManager.carry_over.erase("key_owner")
	_cooldown = data.drop_cooldown
	sprite.scale = Vector2.ONE * data.key_scale
	sprite.rotation = 0.0
	_vy = -240.0
	global_position = pos
	_find_floor.call_deferred()
	dropped.emit(self)
