class_name ObjectiveData
extends Resource
## Ajustes de la llave (KeyItem) y la puerta de salida (ExitDoor) de una fase.

@export_group("Llave")
@export var key_texture: Texture2D
@export var key_scale := 0.55
## Escala y posición (respecto a los pies) mientras la lleva un pingüino.
@export var carry_scale := 0.42
@export var carry_offset := Vector2(0.0, -62.0)
## Tras soltarse (el portador murió) nadie puede recogerla durante este tiempo.
@export var drop_cooldown := 1.0
## Segundos entre que se recoge en la pantalla A y la transición a la B.
@export var pickup_to_transition := 0.9
@export var bob_height := 3.0

@export_group("Puerta")
@export var door_closed: Texture2D
@export var door_open: Texture2D
@export var door_scale := 0.9
## Segundos entre que se abre la puerta y se completa la fase.
@export var enter_delay := 0.8
## Alcance (px) desde el centro de la puerta para contar que el jugador «llega».
@export var door_reach := Vector2(34.0, 50.0)
