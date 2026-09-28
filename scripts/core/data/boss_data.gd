class_name BossData
extends EnemyData
## Jefe: amplía EnemyData con fases que se activan por porcentaje de vida restante.

## Porcentajes de vida (0–1) en los que empieza cada fase. Ej.: [1.0, 0.66, 0.33]
@export var phase_thresholds: PackedFloat32Array = PackedFloat32Array([1.0, 0.66, 0.33])
## Multiplicador de velocidad por fase (misma longitud que phase_thresholds).
@export var phase_speed_multipliers: PackedFloat32Array = PackedFloat32Array([1.0, 1.2, 1.45])
@export var reward_score := 5000
@export var music_key := "music_boss"
