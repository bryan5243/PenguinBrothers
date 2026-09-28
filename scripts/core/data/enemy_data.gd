class_name EnemyData
extends Resource
## Definición configurable de un enemigo. El comportamiento concreto lo decide
## la escena del enemigo a partir de `behavior` y de sus estados de IA.

enum Behavior { WALKER, SHELL, FLYER, SWIMMER, HOPPER, TURRET }

@export var id: StringName
@export var display_name := ""
@export var world := 1
@export var behavior: Behavior = Behavior.WALKER
@export var health := 1
@export var speed := 90.0
@export var damage := 1
@export var attack_range := 48.0
@export var detection_range := 260.0
@export var attack_cooldown := 1.5
@export var score := 100
@export var flying := false
@export var sprite_frames: SpriteFrames
## Ítems que puede soltar al morir (ids de PowerUpData).
@export var drops: Array[StringName] = []
