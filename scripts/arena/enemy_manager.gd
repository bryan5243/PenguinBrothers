class_name EnemyManager
extends Node2D
## Enemigos de UNA pantalla (contenedor "Enemies" de la Arena). Cuenta los enemigos vivos
## y los que aún van a aparecer (EnemySpawner, Fase 5) y emite `cleared` cuando no queda
## ninguno: en la pantalla A eso hace aparecer la llave.
##
## Contrato de un enemigo: estar en el grupo "enemies" y emitir `defeated` al morir (o
## simplemente salir del árbol).

signal cleared
signal enemy_count_changed(remaining: int)

const GROUP := &"enemies"

## Enemigos pendientes de aparecer (los spawners los reservan con add_pending()).
var pending := 0
var is_cleared := false
var _alive: Array[Node] = []
## Se ha registrado al menos un enemigo (una pantalla vacía no se «limpia» sola).
var _had_enemies := false


func _ready() -> void:
	child_entered_tree.connect(_on_child_entered)
	for child in get_children():
		_on_child_entered(child)


func register_enemy(enemy: Node) -> void:
	if _alive.has(enemy):
		return
	_alive.append(enemy)
	_had_enemies = true
	is_cleared = false
	if enemy.has_signal(&"defeated"):
		enemy.connect(&"defeated", _on_enemy_gone.bind(enemy), CONNECT_ONE_SHOT)
	enemy.tree_exiting.connect(_on_enemy_gone.bind(enemy), CONNECT_ONE_SHOT)
	enemy_count_changed.emit(remaining())


func add_pending(count: int) -> void:
	pending += count
	_had_enemies = _had_enemies or count > 0
	is_cleared = false


func consume_pending(count := 1) -> void:
	pending = maxi(0, pending - count)
	_check_cleared()


func remaining() -> int:
	return _alive.size() + pending


func _on_child_entered(child: Node) -> void:
	if child.is_in_group(GROUP):
		register_enemy(child)


## Admite `defeated` con o sin argumentos: el enemigo llega siempre como último argumento (bind).
func _on_enemy_gone(...args: Array) -> void:
	var target := args.back() as Node if not args.is_empty() else null
	if target == null or not _alive.has(target):
		return
	_alive.erase(target)
	enemy_count_changed.emit(remaining())
	_check_cleared()


func _check_cleared() -> void:
	if is_cleared or not _had_enemies or remaining() > 0:
		return
	is_cleared = true
	cleared.emit()
	EventBus.enemies_cleared.emit()
