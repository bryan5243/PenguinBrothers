class_name BombData
extends Resource
## Definición de un tipo de bomba. La escena de bomba base lee estos datos;
## un tipo nuevo es solo un archivo .tres nuevo en data/bombs/.

@export var id: StringName
@export var display_name := ""
@export var damage := 1
@export var explosion_radius := 96.0
@export var fuse_time := 2.4
@export var knockback := 420.0
## Rebote al chocar (0 = no rebota, 1 = rebote completo).
@export_range(0.0, 1.0) var bounce := 0.35
@export var friction := 0.7
@export var texture: Texture2D
@export var icon: Texture2D
## Escena de efecto de explosión (partículas, onda). Vacío = efecto por defecto.
@export var explosion_effect: PackedScene
@export var explode_sfx := "explosion"
## Cantidad inicial de munición cuando se recoge (-1 = infinita).
@export var ammo := -1
