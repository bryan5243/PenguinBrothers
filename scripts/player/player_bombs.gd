class_name PlayerBombs
extends Node
## Bombas de un jugador: tipo equipado, munición, límite de bombas en juego, lanzar,
## colocar, recoger/llevar/soltar. Player lo llama cada frame físico:
##   handle_input() después del estado actual y update_held() después de move_and_slide().
## Las patadas las detecta la propia bomba (Bomb._check_kicks) al caminar contra ella.
##
## Controles (comandos de PlayerInput):
##   bomb             -> lanzar una bomba nueva (arriba + bomba: lanzamiento alto)
##   abajo + bomb     -> colocarla en el suelo delante de los pies
##   interact         -> recoger la bomba más cercana / lanzar la que lleva
##   abajo + interact -> soltar suavemente la que lleva (también abajo + bomb)
##   switch_bomb      -> siguiente tipo de bomba con munición

signal bomb_type_changed(data: BombData)

## Estados desde los que se pueden usar bombas.
const ACTION_STATES: Array[StringName] = [&"Idle", &"Move", &"Jump", &"Fall", &"Land", &"Crouch"]

var player: Player
var current_index := 0
## Munición por id de tipo (-1 = infinita).
var ammo := {}
var held_bomb: Bomb = null
var pool: BombPool


func setup(owner_player: Player) -> void:
	player = owner_player
	ammo.clear()
	for data in player.config.bomb_types:
		ammo[data.id] = data.ammo
	current_index = 0


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


func handle_input() -> void:
	var input := player.input
	if input.switch_bomb_pressed:
		switch_type()
	if not can_act():
		return
	if held_bomb:
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


## Mantiene la bomba sostenida en las manos del jugador.
func update_held() -> void:
	if held_bomb == null:
		return
	if held_bomb.state != Bomb.State.HELD or held_bomb.holder != self:
		_clear_held()
		return
	held_bomb.global_position = hold_position()


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


## Recoge la bomba libre más cercana (propia o del compañero).
func try_pick_up() -> Bomb:
	var best: Bomb = null
	var best_d := player.config.pickup_range
	var center := player.global_position + Vector2(0.0, -player.config.body_height * 0.4)
	for b in get_pool().active_bombs():
		if not b.is_free():
			continue
		var d := b.global_position.distance_to(center)
		if d <= best_d:
			best = b
			best_d = d
	if best == null:
		return null
	best.hold(self)
	held_bomb = best
	player.carried_object = best
	player.animator.carrying = true
	player.animator.play_oneshot(PlayerAnimator.LIFT)
	update_held()
	AudioManager.play_sfx("pickup")
	return best


func throw_held(high := false) -> void:
	if held_bomb == null:
		return
	var bomb := held_bomb
	_clear_held()
	bomb.release(_throw_velocity(high or player.input.up_held))
	player.animator.play_oneshot(PlayerAnimator.THROW)
	AudioManager.play_sfx("bomb_throw")


## Suelta la bomba sin lanzarla (abajo + interactuar, o al recibir daño / subir escalera).
func drop_held() -> void:
	if held_bomb == null:
		return
	var bomb := held_bomb
	_clear_held()
	var v := player.config.drop_velocity
	bomb.release(Vector2(v.x * player.facing + player.velocity.x * 0.5, v.y))


## La bomba explotó en las manos (Bomb avisa al que la sostiene).
func on_held_bomb_exploded(bomb: Bomb) -> void:
	if bomb == held_bomb:
		_clear_held()


# ------------------------------------------------------------------ internos
func _spawn(pos: Vector2, velocity := Vector2.ZERO) -> Bomb:
	var data := current_type()
	if data == null or int(ammo.get(data.id, -1)) == 0:
		return null
	var p := get_pool()
	if p.count_active(player.player_index) >= player.config.max_active_bombs:
		return null
	var bomb := p.acquire_bomb(data, player.player_index)
	bomb.arm_at(pos, velocity)
	if int(ammo[data.id]) > 0:
		ammo[data.id] = int(ammo[data.id]) - 1
		if int(ammo[data.id]) == 0:
			switch_type()
	return bomb


func _throw_velocity(high: bool) -> Vector2:
	var cfg := player.config
	var f := cfg.throw_up_force if high else cfg.throw_force
	return Vector2(f.x * player.facing + player.velocity.x * cfg.throw_inherit, f.y)


func _clear_held() -> void:
	held_bomb = null
	player.carried_object = null
	player.animator.carrying = false
