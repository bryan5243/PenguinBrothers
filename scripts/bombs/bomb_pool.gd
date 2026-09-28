class_name BombPool
extends Node2D
## Reserva de bombas y explosiones reutilizables (evita crear/destruir nodos en plena
## partida, importante en móvil). Cada nivel tiene uno (grupo "bomb_pool"); si falta, se
## crea uno automáticamente junto al primer jugador que lo pida.
## Debe estar en el origen del nivel: bombas y explosiones usan coordenadas globales.

const GROUP := &"bomb_pool"
const BOMB_SCENE := preload("res://scenes/bombs/Bomb.tscn")
const EXPLOSION_SCENE := preload("res://scenes/bombs/Explosion.tscn")

@export var initial_bombs := 8
@export var initial_explosions := 6

var _bombs: Array[Bomb] = []
var _explosions: Array[Explosion] = []


## Devuelve el pool del árbol de `node` (o crea uno en el nivel de `node`).
static func find_for(node: Node) -> BombPool:
	var existing := node.get_tree().get_first_node_in_group(GROUP) as BombPool
	if existing:
		return existing
	var pool := BombPool.new()
	pool.name = "BombPool"
	var parent := node.get_parent() if node.get_parent() else node
	parent.add_child(pool)
	return pool


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	for i in initial_bombs:
		_new_bomb()
	for i in initial_explosions:
		_new_explosion()


## Bomba lista para usar (configurada con `data`, todavía guardada: llama a arm_at()).
func acquire_bomb(data: BombData, owner_index: int) -> Bomb:
	var bomb: Bomb = null
	for b in _bombs:
		if b.state == Bomb.State.POOLED:
			bomb = b
			break
	if bomb == null:
		bomb = _new_bomb()
	bomb.setup(data, owner_index)
	return bomb


func acquire_explosion() -> Explosion:
	for e in _explosions:
		if not e.active:
			return e
	return _new_explosion()


## Bombas en juego (con la mecha encendida, libres o en manos de alguien).
func active_bombs() -> Array[Bomb]:
	var out: Array[Bomb] = []
	for b in _bombs:
		if b.state == Bomb.State.ARMED or b.state == Bomb.State.HELD:
			out.append(b)
	return out


func count_active(owner_index: int) -> int:
	var n := 0
	for b in active_bombs():
		if b.owner_index == owner_index:
			n += 1
	return n


func size() -> int:
	return _bombs.size()


func _new_bomb() -> Bomb:
	var bomb := BOMB_SCENE.instantiate() as Bomb
	bomb.pool = self
	bomb.name = "Bomb%d" % _bombs.size()
	add_child(bomb)
	_bombs.append(bomb)
	return bomb


func _new_explosion() -> Explosion:
	var fx := EXPLOSION_SCENE.instantiate() as Explosion
	fx.pool = self
	fx.name = "Explosion%d" % _explosions.size()
	add_child(fx)
	_explosions.append(fx)
	return fx
