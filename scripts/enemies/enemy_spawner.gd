@tool
class_name EnemySpawner
extends Marker2D
## Punto de aparición de enemigos de una pantalla. Configurable:
##   enemy_type   -> EnemyData del enemigo (data/enemies/*.tres)
##   entry        -> por dónde entra: un punto fijo, el borde izquierdo o derecho (a la altura
##                   del marcador) o desde arriba (cae desde el techo en la x del marcador)
##   spawn_delay  -> segundos antes del primero; interval entre uno y otro
##   count        -> total de enemigos que suelta; max_enemies -> vivos a la vez (0 = sin límite)
##   wave         -> oleada: solo empieza cuando el EnemyManager llega a esa oleada
## Va dentro del nodo «Spawners» de la Arena; los enemigos se crean dentro de «Enemies».

signal enemy_spawned(enemy: Enemy)

enum Entry { POINT, LEFT, RIGHT, TOP }

const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
## Margen desde las paredes de la arena al entrar por un lado.
const SIDE_MARGIN := 44.0
const TOP_Y := 90.0

@export var enemy_type: EnemyData
@export var entry: Entry = Entry.POINT
@export var spawn_delay := 1.0
@export var interval := 3.0
@export var count := 1
@export var max_enemies := 0
@export var wave := 1

var spawned := 0
var manager: EnemyManager
var _timer := 0.0
var _alive: Array[Enemy] = []
var _active := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_timer = spawn_delay


func is_finished() -> bool:
	return spawned >= count


func activate() -> void:
	_active = true


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _active or is_finished() or manager == null or enemy_type == null:
		return
	_alive = _alive.filter(func(e: Enemy) -> bool: return is_instance_valid(e) and e.is_alive())
	if max_enemies > 0 and _alive.size() >= max_enemies:
		return
	_timer -= delta
	if _timer <= 0.0:
		spawn()
		_timer = interval


## Crea el siguiente enemigo ya mismo. Devuelve el enemigo.
func spawn() -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.data = enemy_type
	enemy.position = spawn_position()
	enemy.facing = _entry_facing()
	enemy.name = "%s_%d" % [name, spawned + 1]
	spawned += 1
	_alive.append(enemy)
	manager.add_child(enemy)   # EnemyManager lo registra al entrar
	manager.consume_pending(1)
	BreakEffect.spawn(manager, enemy.position + Vector2(0, -enemy_type.body_size.y * 0.5), Color(1, 1, 1, 0.8))
	enemy_spawned.emit(enemy)
	return enemy


func spawn_position() -> Vector2:
	var arena_w := 960.0
	match entry:
		Entry.LEFT:
			return Vector2(SIDE_MARGIN, position.y)
		Entry.RIGHT:
			return Vector2(arena_w - SIDE_MARGIN, position.y)
		Entry.TOP:
			return Vector2(position.x, TOP_Y if not enemy_type.flying else position.y)
	return position


func _entry_facing() -> int:
	match entry:
		Entry.LEFT:
			return 1
		Entry.RIGHT:
			return -1
	return 1 if position.x < 480.0 else -1
