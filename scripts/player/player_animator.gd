class_name PlayerAnimator
extends AnimatedSprite2D
## Capa visual del jugador, separada de la lógica de movimiento.
## Los estados piden animaciones por nombre estándar; si el SpriteFrames todavía no
## tiene esa animación, se usa un respaldo en lugar de fallar.

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

## SpriteFrames por personaje. Se asignan en la Fase 2 con los sprites de assets/characters/.
@export var blue_penguin_frames: SpriteFrames
@export var pink_penguin_frames: SpriteFrames


func setup(character: int) -> void:
	var frames: SpriteFrames = blue_penguin_frames if character == 0 else pink_penguin_frames
	if frames:
		sprite_frames = frames
	play_animation(IDLE)


func play_animation(anim: StringName, restart := false) -> void:
	var resolved := resolve(anim)
	if resolved == &"":
		return
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


func set_facing(direction: int) -> void:
	flip_h = direction < 0
