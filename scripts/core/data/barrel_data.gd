class_name BarrelData
extends DestructibleData
## Barril: destruible que además se recoge, se lleva y se lanza como arma (CarryableBody).

@export_group("Arma")
## Daño a los enemigos al golpearlos lanzado o rodando.
@export var hit_damage := 2
## Velocidad mínima para hacer daño al golpear.
@export var hit_min_speed := 120.0
## Se rompe al chocar con una pared a esta velocidad o más (0 = nunca).
@export var break_speed := 380.0
## Lanzamiento propio del barril: bajo y rasante para que ruede por el piso (el de las
## bombas es un arco). Arriba + lanzar sigue usando el lanzamiento alto del jugador.
@export var throw_force := Vector2(480.0, -170.0)

@export_group("Física arcade")
@export var gravity_scale := 1.8
@export_range(0.0, 1.0) var bounce := 0.2
@export var max_bounces := 1
@export var min_bounce_speed := 200.0
## Rueda: frena poco en el suelo.
@export var ground_friction := 260.0
@export_range(0.0, 1.0) var wall_bounce := 0.3
