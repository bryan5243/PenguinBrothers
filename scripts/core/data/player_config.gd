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
@export var jump_cut_speed := 400.0
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12

## Pausa breve tras aterrizar de una caída fuerte (no bloquea el movimiento).
@export var land_duration := 0.08
## Velocidad de caída mínima para mostrar la animación de aterrizaje.
@export var land_min_fall_speed := 380.0

@export_group("Acciones")
@export var slide_speed := 520.0
@export var slide_duration := 0.5
@export var slide_friction := 700.0
## Velocidad mínima (fracción de run_speed) para que agacharse se convierta en deslizamiento.
@export_range(0.0, 1.0) var slide_trigger_ratio := 0.85
## Velocidad al gatear agachado bajo un techo bajo (sin espacio para levantarse).
@export var crawl_speed := 110.0
@export var climb_speed := 180.0
## Tiempo que se ignoran las plataformas atravesables al bajar (abajo + saltar).
@export var drop_through_time := 0.25
@export var carry_speed_multiplier := 0.85
@export var throw_force := Vector2(440.0, -380.0)

@export_group("Cuerpo")
@export var body_radius := 16.0
@export var body_height := 60.0
@export var crouch_height := 38.0
## Altura extra de la plataforma de la cabeza sobre la colisión, para que el compañero
## quede apoyado sobre el dibujo (penacho incluido) y no hundido en él.
@export var head_platform_offset := 12.0

@export_group("Vida")
@export var max_health := 3
@export var invulnerability_time := 1.6
@export var knockback := Vector2(300.0, -420.0)
@export var hurt_duration := 0.45
## Si cae por debajo de esta altura muere (el nivel puede sobrescribirlo).
@export var fall_death_y := 1400.0
@export var respawn_delay := 1.5
