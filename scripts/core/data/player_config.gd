class_name PlayerConfig
extends Resource
## Parámetros de movimiento y vida del jugador.
## Todos los valores de ajuste del jugador viven aquí, no dispersos en el código.
## Unidades: píxeles y segundos (resolución lógica 1280x720).

@export_group("Movimiento")
@export var move_speed := 240.0
@export var run_speed := 340.0
## Segundos de movimiento continuo en el suelo antes de pasar a correr.
@export var run_delay := 0.55
@export var acceleration := 2200.0
@export var air_acceleration := 1400.0
@export var friction := 2600.0
@export var air_friction := 600.0

@export_group("Salto")
@export var jump_force := 640.0
@export var gravity := 1750.0
@export var max_fall_speed := 950.0
## Velocidad vertical máxima al soltar el botón de salto (salto variable).
@export var jump_cut_speed := 240.0
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12

@export_group("Acciones")
@export var slide_speed := 520.0
@export var slide_duration := 0.5
@export var climb_speed := 180.0
@export var carry_speed_multiplier := 0.85
@export var throw_force := Vector2(440.0, -380.0)

@export_group("Vida")
@export var max_health := 3
@export var invulnerability_time := 1.6
@export var knockback := Vector2(300.0, -420.0)
@export var respawn_delay := 1.5
