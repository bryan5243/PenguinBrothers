class_name StageData
extends Resource
## Definición de una fase arcade: una serie corta de pantallas fijas (A, B...).
## Pantalla A: eliminar a todos los enemigos hace aparecer la llave. Pantalla B: llevar la
## llave a la puerta completa la fase (Fase 7 del plan arcade).
## StageManager la usa para encadenar pantallas, contar el tiempo y dar bonificaciones.

@export var id: StringName
@export var world := 1
@export var stage := 1
@export var display_name := ""
## Escenas de las pantallas, en orden (normalmente A y B).
@export_file("*.tscn") var screens: Array[String] = []
## Tiempo límite de cada pantalla en segundos (si falta, se usa default_time_limit).
@export var time_limits: Array[float] = []
@export var default_time_limit := 99.0
## Segundos restantes a partir de los cuales el HUD avisa (parpadeo, sonido).
@export var time_warning := 15.0
## Siguiente fase (vacío = fin del mundo / demo).
@export_file("*.tres") var next_stage := ""


func time_limit_for(screen_index: int) -> float:
	if screen_index >= 0 and screen_index < time_limits.size() and time_limits[screen_index] > 0.0:
		return time_limits[screen_index]
	return default_time_limit


func screen_count() -> int:
	return screens.size()
