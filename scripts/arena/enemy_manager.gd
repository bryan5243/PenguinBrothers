class_name EnemyManager
extends Node2D
## Enemigos de UNA pantalla (contenedor "Enemies" de la Arena). Cuenta los enemigos vivos
## y los que aún van a aparecer (EnemySpawner, Fase 5) y emite `cleared` cuando no queda
## ninguno: en la pantalla A eso hace aparecer la llave.
##
## Contrato de un enemigo: estar en el grupo "enemies" y emitir `defeated` al morir (o
## simplemente salir del árbol).
##
## Oleadas: los EnemySpawner de la pantalla se registran con register_spawners(); primero
## actúan los de la oleada más baja y, cuando han soltado todos sus enemigos y no queda
## ninguno vivo, empieza la siguiente.

signal cleared
signal enemy_count_changed(remaining: int)
signal wave_started(wave: int)

const GROUP := &"enemies"

## Enemigos pendientes de aparecer (los spawners los reservan con add_pending()).
var pending := 0
var is_cleared := false
var _alive: Array[Node] = []
## Se ha registrado al menos un enemigo (una pantalla vacía no se «limpia» sola).
var _had_enemies := false
var current_wave := 0
var spawners: Array[EnemySpawner] = []


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


## Reserva los enemigos de todos los spawners (la pantalla no se limpia hasta derrotarlos a
## todos) y arranca la primera oleada.
func register_spawners(list: Array[EnemySpawner]) -> void:
	for sp in list:
		if spawners.has(sp):
			continue
		spawners.append(sp)
		sp.manager = self
		add_pending(maxi(0, sp.count - sp.spawned))
	_advance_wave()


func alive_count() -> int:
	return _alive.size()


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
	_advance_wave()
	_check_cleared()


func _physics_process(_delta: float) -> void:
	if not spawners.is_empty():
		_advance_wave()


## Pasa a la siguiente oleada cuando la actual ya soltó a todos y no queda nadie vivo.
func _advance_wave() -> void:
	var next := -1
	for sp in spawners:
		if not is_instance_valid(sp) or sp.is_finished():
			continue
		if sp.wave <= current_wave:
			return   # la oleada actual aún tiene enemigos por salir
		next = sp.wave if next < 0 else mini(next, sp.wave)
	if next < 0 or not _alive.is_empty():
		return
	current_wave = next
	for sp in spawners:
		if is_instance_valid(sp) and sp.wave == current_wave:
			sp.activate()
	wave_started.emit(current_wave)


func _check_cleared() -> void:
	if is_cleared or not _had_enemies or remaining() > 0:
		return
	is_cleared = true
	cleared.emit()
	EventBus.enemies_cleared.emit()
