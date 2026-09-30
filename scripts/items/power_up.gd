class_name PowerUp
extends Area2D
## Objeto recogible (fruta, 1UP, armadura, botas, fuego...). Aparece al romper barriles o
## cajas y al derrotar enemigos: salta un poco, cae hasta el suelo o plataforma que tenga
## debajo y espera `lifetime` segundos (parpadea al final). Un jugador lo recoge al tocarlo.

signal collected(power_up: PowerUp, player: Player)

const SCENE_PATH := "res://scenes/items/PowerUp.tscn"
const FLOOR_MASK := 1 | (1 << 5)
const FALL_SPEED := 520.0
const BLINK_TIME := 2.5

var data: PowerUpData
var _life := 0.0
var _target_y := 0.0
var _vy := 0.0
var _landed := false

@onready var sprite: Sprite2D = $Sprite


## Crea un power-up en `pos` dentro de `parent` (normalmente Arena/Items).
static func spawn(power_data: PowerUpData, pos: Vector2, parent: Node) -> PowerUp:
	var item := (load(SCENE_PATH) as PackedScene).instantiate() as PowerUp
	item.data = power_data
	item.position = pos
	parent.add_child(item)
	return item


func _ready() -> void:
	collision_layer = 1 << 7   # capa 8: pickups
	collision_mask = 1 << 1    # jugadores
	body_entered.connect(_on_body_entered)
	if data:
		sprite.texture = data.icon
		_life = data.lifetime
	_vy = -260.0
	_find_floor.call_deferred()


func _find_floor() -> void:
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 900), FLOOR_MASK)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	_target_y = (hit["position"].y if hit else global_position.y) - 20.0


func _physics_process(delta: float) -> void:
	if not _landed:
		_vy = minf(_vy + 1400.0 * delta, FALL_SPEED)
		global_position.y += _vy * delta
		if _vy > 0.0 and _target_y != 0.0 and global_position.y >= _target_y:
			global_position.y = _target_y
			_landed = true
	sprite.position.y = sin(Time.get_ticks_msec() * 0.006) * 3.0 if _landed else 0.0
	if data and data.lifetime > 0.0:
		_life -= delta
		if _life <= 0.0:
			queue_free()
		elif _life < BLINK_TIME:
			sprite.visible = int(_life * 10.0) % 2 == 0


func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player == null or not player.is_alive() or data == null:
		return
	if player.apply_power_up(data):
		ScoreManager.add_points(player.player_index,
			data.score_value if data.score_value > 0 else ScoreManager.table.power_up, global_position)
		AudioManager.play_sfx(data.pickup_sfx)
		EventBus.power_up_collected.emit(player.player_index, data.id)
		collected.emit(self, player)
		queue_free()
