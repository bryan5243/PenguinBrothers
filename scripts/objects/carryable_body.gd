class_name CarryableBody
extends CharacterBody2D
## Objeto arcade con «física controlada» que los jugadores pueden recoger, llevar, lanzar,
## soltar y patear: bombas (Bomb) y barriles (Barrel).
##
## No es una simulación realista (RigidBody2D): gravedad fija, un número limitado de botes
## con rebote fijo, frenado en el suelo y rebote en paredes, siempre igual. Así los lanzamientos
## son predecibles, como en un arcade. Los parámetros van en un Resource (BombData / BarrelData)
## y se copian aquí con apply_motion().
##
## Contrato para PlayerBombs: can_be_picked_up(), hold(by), release(velocity), kick(dir, speed).

signal landed(impact_speed: float)
signal hit_wall(impact_speed: float)

const GROUP := &"carryables"

## Multiplicador de la gravedad del proyecto.
var gravity_scale := 1.8
## Fracción de la velocidad vertical que conserva al botar (0 = no bota).
var bounce := 0.35
## Botes máximos tras cada lanzamiento.
var max_bounces := 2
## Velocidad vertical mínima para botar (por debajo se queda en el suelo).
var min_bounce_speed := 160.0
## Frenado horizontal en el suelo (px/s²).
var ground_friction := 900.0
## Fracción de la velocidad horizontal que conserva al chocar con una pared (sale rebotado).
var wall_bounce := 0.4
var max_fall_speed := 950.0

## Quién lo lleva (PlayerBombs), o null.
var holder: Node = null
var _bounces_left := 0
var _saved_layers := Vector2i(-1, -1)
var _gravity := 1750.0


func _enter_tree() -> void:
	add_to_group(GROUP)
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 1750.0))


## Copia los parámetros de movimiento de un Resource con los mismos nombres de campo.
func apply_motion(res: Resource) -> void:
	for key in ["gravity_scale", "bounce", "max_bounces", "min_bounce_speed", "ground_friction",
			"wall_bounce"]:
		if key in res:
			set(key, res.get(key))


func is_held() -> bool:
	return holder != null


## ¿Puede recogerlo un jugador ahora? (lo redefinen las subclases)
func can_be_picked_up() -> bool:
	return holder == null and visible


func hold(by: Node) -> void:
	holder = by
	velocity = Vector2.ZERO
	z_index = 5
	_set_carried_collision(true)


## Suelta con una velocidad (lanzar o dejar caer). Reinicia los botes.
func release(initial_velocity: Vector2) -> void:
	holder = null
	z_index = 0
	_set_carried_collision(false)
	launch(initial_velocity)


func launch(initial_velocity: Vector2) -> void:
	velocity = initial_velocity
	_bounces_left = max_bounces


func kick(direction: int, speed: float) -> bool:
	if holder != null:
		return false
	launch(Vector2(direction * speed, minf(velocity.y, -60.0)))
	return true


## Paso de movimiento arcade. Las subclases lo llaman desde _physics_process.
func arcade_step(delta: float) -> void:
	if holder != null:
		return
	velocity.y = minf(velocity.y + _gravity * gravity_scale * delta, max_fall_speed)
	var pre := velocity
	move_and_slide()
	if is_on_wall() and absf(pre.x) > 1.0:
		velocity.x = -pre.x * wall_bounce
		hit_wall.emit(absf(pre.x))
	if is_on_floor():
		if pre.y > 0.0:
			if pre.y >= min_bounce_speed and _bounces_left > 0:
				_bounces_left -= 1
				velocity.y = -pre.y * bounce
			landed.emit(pre.y)
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)


## Mientras se lleva no choca con nada (lo mueve quien lo lleva).
func _set_carried_collision(carried: bool) -> void:
	if carried:
		if _saved_layers.x < 0:
			_saved_layers = Vector2i(collision_layer, collision_mask)
		collision_layer = 0
		collision_mask = 0
	elif _saved_layers.x >= 0:
		collision_layer = _saved_layers.x
		collision_mask = _saved_layers.y
		_saved_layers = Vector2i(-1, -1)
