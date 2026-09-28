class_name PlayerAnimator
extends AnimatedSprite2D
## Capa visual del jugador, separada de la lógica de movimiento.
## Los estados piden animaciones por nombre estándar; si el SpriteFrames todavía no tiene
## esa animación se usa un respaldo en lugar de fallar. También gestiona efectos visuales
## que no afectan a la jugabilidad: parpadeo, destello de daño y estirar/aplastar.

## Nombres estándar de animación (ver docs/GAMEPLAY.md).
const IDLE := &"idle"
const WALK := &"walk"
const RUN := &"run"
const JUMP := &"jump"
const FALL := &"fall"
const LAND := &"land"
const CROUCH := &"crouch"
const SLIDE := &"slide"
const CLIMB := &"climb"
const LIFT := &"lift"
const CARRY := &"carry"
const THROW := &"throw"
const PLACE_BOMB := &"place_bomb"
const HURT := &"hurt"
const DEATH := &"death"
const VICTORY := &"victory"

## Respaldo cuando falta una animación.
const FALLBACKS := {
	&"run": &"walk", &"land": &"idle", &"crouch": &"idle", &"slide": &"crouch",
	&"climb": &"idle", &"lift": &"idle", &"carry": &"idle", &"throw": &"idle",
	&"place_bomb": &"crouch", &"hurt": &"fall", &"death": &"hurt",
	&"victory": &"idle", &"fall": &"jump", &"walk": &"idle", &"jump": &"idle",
}

@export var blue_penguin_frames: SpriteFrames
@export var pink_penguin_frames: SpriteFrames
## Escala del sprite respecto a los fotogramas extraídos.
@export var sprite_scale := 0.9
@export var blink_rate := 14.0
@export var squash_recovery := 12.0
@export var hurt_flash_color := Color(1.8, 0.55, 0.55)

var _blinking := false
var _blink_time := 0.0
var _squash := Vector2.ONE
var _flash_time := 0.0
var _facing := 1


func setup(character: int) -> void:
	var frames: SpriteFrames = blue_penguin_frames if character == 0 else pink_penguin_frames
	if frames:
		sprite_frames = frames
	centered = true
	_align_feet()
	reset_visual()
	play_animation(IDLE)


## El origen del nodo queda en los pies: los fotogramas tienen los pies en el borde inferior.
func _align_feet() -> void:
	if sprite_frames == null or not sprite_frames.has_animation(IDLE):
		return
	var tex := sprite_frames.get_frame_texture(IDLE, 0)
	if tex:
		offset = Vector2(0.0, -tex.get_height() * 0.5)


func play_animation(anim: StringName, restart := false) -> void:
	var resolved := resolve(anim)
	if resolved == &"":
		return
	speed_scale = 1.0
	if restart or animation != resolved or not is_playing():
		play(resolved)


## Devuelve la animación disponible más cercana a `anim`, o vacío si no hay ninguna.
func resolve(anim: StringName) -> StringName:
	if sprite_frames == null:
		return &""
	var current := anim
	for i in 6:
		if sprite_frames.has_animation(current):
			return current
		if not FALLBACKS.has(current):
			break
		current = FALLBACKS[current]
	return &""


## Ajusta la velocidad de la animación actual (p. ej. caminar según la velocidad real).
func set_playback_speed(value: float) -> void:
	speed_scale = maxf(0.0, value)


func set_facing(direction: int) -> void:
	_facing = direction
	flip_h = direction < 0


## Estira (valores > 1 en y) o aplasta (< 1) el sprite; vuelve solo a la normalidad.
func squash(amount: Vector2) -> void:
	_squash = amount


func flash() -> void:
	_flash_time = 0.15


func set_blinking(active: bool) -> void:
	_blinking = active
	_blink_time = 0.0
	if not active:
		visible = true


func reset_visual() -> void:
	rotation = 0.0
	_squash = Vector2.ONE
	_flash_time = 0.0
	_blinking = false
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE * sprite_scale


func _process(delta: float) -> void:
	_squash = _squash.lerp(Vector2.ONE, minf(1.0, delta * squash_recovery))
	scale = _squash * sprite_scale
	if _flash_time > 0.0:
		_flash_time -= delta
		modulate = hurt_flash_color
	else:
		modulate = Color.WHITE
	if _blinking:
		_blink_time += delta
		visible = int(_blink_time * blink_rate) % 2 == 0
