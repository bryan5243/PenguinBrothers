class_name WorldData
extends Resource
## Definición de un mundo: nombre, niveles, enemigos y jefe.
## Añadir un mundo = crear su .tres en data/worlds/ y sus escenas en scenes/worlds/world_XX/.

@export var number := 1
@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Rutas de las escenas de nivel, en orden. El último suele ser la arena del jefe.
@export var level_scenes: Array[String] = []
@export var enemy_ids: Array[StringName] = []
@export var boss_id: StringName
@export var music_key := ""
@export var background: Texture2D
@export var unlocked_by_default := false
