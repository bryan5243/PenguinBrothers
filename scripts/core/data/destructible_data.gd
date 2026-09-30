class_name DestructibleData
extends Resource
## Objeto del escenario que se puede romper (caja, bloque, pared, barril...).
## Las bombas solo lo dañan si su poder de destrucción (ExplosionInfo.break_power) es al
## menos `hardness`: así no se destruye todo indiscriminadamente.

@export var id: StringName
@export var display_name := ""
@export var destructible := true
@export var max_health := 1
## Poder de destrucción mínimo: 1 = cualquier bomba, 2 = bomba de nivel 4 (poder especial).
@export var hardness := 1
## Puntos al romperlo (0 = los de ScoreTable.destructible).
@export var points := 0
@export var drop_table: DropTable
@export var texture: Texture2D
@export var size := Vector2(48, 48)
## Efecto al romperse: color de los fragmentos y sonido.
@export var debris_color := Color(0.62, 0.42, 0.22)
@export var break_sfx := "barrel_break"
