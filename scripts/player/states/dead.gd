extends PlayerState
## Muerte estilo arcade: salta, gira y cae fuera de la pantalla atravesando el escenario.
## Tras `respawn_delay` descuenta una vida y reaparece (junto al compañero en cooperativo);
## sin vidas queda eliminado y GameManager termina la partida si no queda nadie.

const DEATH_JUMP_RATIO := 0.8
const SPIN_SPEED := 9.0

var _timer := 0.0
var _finished := false


func enter(_message := {}) -> void:
	_timer = player.config.respawn_delay
	_finished = false
	player.set_low_profile(false)
	player.collision_layer = 0
	player.collision_mask = 0
	player.set_head_platform(false)
	player.velocity = Vector2(0.0, -player.config.jump_force * DEATH_JUMP_RATIO)
	player.animator.set_blinking(false)
	player.animator.play_animation(PlayerAnimator.DEATH, true)
	player.input.enabled = false
	AudioManager.play_sfx("hurt", 0.7)


func exit() -> void:
	player.input.enabled = true
	player.animator.rotation = 0.0


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.velocity.x = 0.0
	player.animator.rotation += SPIN_SPEED * delta * player.facing
	_timer -= delta
	if _timer > 0.0 or _finished:
		return
	_finished = true
	var lives_left: int = GameManager.change_lives(player.player_index, -1)
	if lives_left > 0:
		player.respawn()
	else:
		# Sin vidas: queda fuera. La partida termina cuando no queda ningún jugador.
		player.visible = false
		player.velocity = Vector2.ZERO
		player.tag.visible = false
		GameManager.eliminate_player(player.player_index)
