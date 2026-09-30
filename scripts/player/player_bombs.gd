class_name PlayerBombs
extends Node
## Bombas y objetos en las manos de un jugador: tipo de bomba equipado, munición, nivel de
## poder (BOMB LEVEL 1–4), límite de bombas en juego, lanzar, colocar, recoger / llevar /
## soltar cualquier CarryableBody (bombas y barriles). Player lo llama cada frame físico:
##   handle_input() después del estado actual y update_held() después de move_and_slide().
## Las patadas las detecta la propia bomba (Bomb._check_kicks) al caminar contra ella.
##
## Controles (comandos de PlayerInput):
##   bomb             -> lanzar una bomba nueva (arriba + bomba: lanzamiento alto)
##   abajo + bomb     -> colocarla en el suelo delante de los pies
##   interact         -> recoger la bomba o el barril más cercano / lanzar lo que lleva
##   abajo + interact -> soltar suavemente lo que lleva (también abajo + bomb)
##   switch_bomb      -> siguiente tipo de bomba con munición

signal bomb_type_changed(data: BombData)
signal power_level_changed(level: int)

## Estados desde los que se pueden usar bombas.
const ACTION_STATES: Array[StringName] = [&"Idle", &"Move", &"Jump", &"Fall", &"Land", &"Crouch"]
const MAX_LEVEL := 4

var player: Player
var current_index := 0
## Munición por id de tipo (-1 = infinita).
var ammo := {}
## Nivel de poder de las bombas (1–4).
var power_level := 1
## Lo que lleva en las manos (bomba o barril), o null.
var held_object: CarryableBody = null
## Atajo: la bomba que lleva, si lo que lleva es una bomba.
var held_bomb: Bomb:
	get:
		return held_object as Bomb
var pool: BombPool


func setup(owner_player: Player) -> void:
	player = owner_player
	ammo.clear()
	for data in player.config.bomb_types:
		ammo[data.id] = data.ammo
	current_index = 0
	power_level = 1


func current_type() -> BombData:
	var types := player.config.bomb_types
	if types.is_empty():
		return null
	return types[clampi(current_index, 0, types.size() - 1)]


func get_pool() -> BombPool:
	if pool == null or not is_instance_valid(pool) or not pool.is_inside_tree():
		pool = BombPool.find_for(player)
	return pool


func active_count() -> int:
	return get_pool().count_active(player.player_index)


func can_act() -> bool:
	return player.is_alive() and player.state_machine.current_state != null \
		and ACTION_STATES.has(player.state_machine.current_state.name)


# ------------------------------------------------------------------ nivel de poder
func radius_multiplier() -> float:
	var table := player.config.bomb_power_radius
	if table.is_empty():
		return 1.0
	return table[clampi(power_level - 1, 0, table.size() - 1)]


func set_power_level(level: int) -> void:
	var clamped := clampi(level, 1, MAX_LEVEL)
	if clamped == power_level:
		return
	power_level = clamped
	power_level_changed.emit(power_level)
	EventBus.bomb_level_changed.emit(player.player_index, power_level)


## Sube un nivel (power-up). Devuelve false si ya estaba al máximo.
func level_up() -> bool:
	if power_level >= MAX_LEVEL:
		return false
	set_power_level(power_level + 1)
	return true


func reset_power() -> void:
	set_power_level(1)


# ------------------------------------------------------------------ entrada
func handle_input() -> void:
	var input := player.input
	if input.switch_bomb_pressed:
		switch_type()
	if not can_act():
		return
	if held_object:
		if input.bomb_pressed or input.interact_pressed:
			if input.crouch_held:
				drop_held()
			else:
				throw_held()
		return
	if input.interact_pressed:
		try_pick_up()
	elif input.bomb_pressed:
		if input.crouch_held and player.is_on_floor():
			place_bomb()
		else:
			throw_new_bomb(input.up_held)


## Mantiene lo que lleva en las manos del jugador.
func update_held() -> void:
	if held_object == null:
		return
	if not is_instance_valid(held_object) or held_object.holder != self:
		_clear_held()
		return
	held_object.global_position = hold_position()


func hold_position() -> Vector2:
	var o := player.config.bomb_hold_offset
	return player.global_position + Vector2(o.x * player.facing, o.y)


# ------------------------------------------------------------------ acciones
func switch_type() -> bool:
	var types := player.config.bomb_types
	for step in range(1, types.size() + 1):
		var i := (current_index + step) % types.size()
		if int(ammo.get(types[i].id, -1)) != 0:
			if i == current_index:
				return false
			current_index = i
			AudioManager.play_sfx("bomb_switch")
			bomb_type_changed.emit(types[i])
			EventBus.bomb_type_changed.emit(player.player_index, types[i].id)
			return true
	return false


## Lanza una bomba nueva del tipo equipado. Devuelve la bomba o null si no se pudo.
func throw_new_bomb(high := false) -> Bomb:
	var bomb := _spawn(hold_position(), _throw_velocity(high))
	if bomb == null:
		return null
	player.animator.play_oneshot(PlayerAnimator.THROW)
	AudioManager.play_sfx("bomb_throw")
	return bomb


## Coloca una bomba quieta en el suelo, delante de los pies.
func place_bomb() -> Bomb:
	var data := current_type()
	if data == null:
		return null
	var pos := player.global_position + Vector2(player.config.bomb_place_distance * player.facing,
		-data.body_radius - 1.0)
	var bomb := _spawn(pos)
	if bomb == null:
		return null
	player.animator.play_oneshot(PlayerAnimator.PLACE_BOMB)
	AudioManager.play_sfx("bomb_place")
	return bomb


## Recoge el objeto libre más cercano: bomba (propia o del compañero) o barril.
func try_pick_up() -> CarryableBody:
	var best: CarryableBody = null
	var best_d := player.config.pickup_range
	var center := player.global_position + Vector2(0.0, -player.config.body_height * 0.4)
	for node in get_tree().get_nodes_in_group(CarryableBody.GROUP):
		var c := node as CarryableBody
		if c == null or not c.can_be_picked_up():
			continue
		var d := c.global_position.distance_to(center)
		if d <= best_d:
			best = c
			best_d = d
	if best == null:
		return null
	best.hold(self)
	held_object = best
	player.carried_object = best
	player.animator.carry_style = best.carry_style
	player.animator.carrying = true
	# Si el personaje lo lleva dibujado (animaciones carry_<estilo>_*), se oculta el objeto.
	best.set_art_visible(not player.animator.has_styled_carry(best.carry_style))
	player.animator.play_oneshot(PlayerAnimator.LIFT)
	update_held()
	AudioManager.play_sfx("pickup")
	return best


func throw_held(high := false) -> void:
	if held_object == null:
		return
	var obj := held_object
	_clear_held()
	obj.release(_throw_velocity(high or player.input.up_held, obj))
	if obj.has_method(&"on_thrown"):
		obj.on_thrown(player.player_index)
	player.animator.play_oneshot(PlayerAnimator.THROW, obj.carry_style)
	AudioManager.play_sfx("bomb_throw")


## Suelta lo que lleva sin lanzarlo (abajo + interactuar, o al recibir daño / subir escalera).
func drop_held() -> void:
	if held_object == null:
		return
	var obj := held_object
	_clear_held()
	var v := player.config.drop_velocity
	obj.release(Vector2(v.x * player.facing + player.velocity.x * 0.5, v.y))
	player.animator.play_oneshot(PlayerAnimator.DROP, obj.carry_style)


## Lo que llevaba explotó o se rompió en las manos.
func on_held_object_gone(obj: Node) -> void:
	if obj == held_object:
		_clear_held()


# ------------------------------------------------------------------ internos
func _spawn(pos: Vector2, velocity := Vector2.ZERO) -> Bomb:
	var data := current_type()
	if data == null or int(ammo.get(data.id, -1)) == 0:
		return null
	var p := get_pool()
	if p.count_active(player.player_index) >= player.config.max_active_bombs:
		return null
	var bomb := p.acquire_bomb(data, player.player_index, power_level, radius_multiplier())
	bomb.arm_at(pos, velocity)
	if int(ammo[data.id]) > 0:
		ammo[data.id] = int(ammo[data.id]) - 1
		if int(ammo[data.id]) == 0:
			switch_type()
	return bomb


func _throw_velocity(high: bool, obj: CarryableBody = null) -> Vector2:
	var cfg := player.config
	var f := cfg.throw_up_force if high else cfg.throw_force
	if not high and obj and obj.throw_force != Vector2.ZERO:
		f = obj.throw_force
	return Vector2(f.x * player.facing + player.velocity.x * cfg.throw_inherit, f.y)


func _clear_held() -> void:
	if held_object and is_instance_valid(held_object):
		held_object.set_art_visible(true)
	held_object = null
	player.carried_object = null
	player.animator.carrying = false
	player.animator.carry_style = &""
