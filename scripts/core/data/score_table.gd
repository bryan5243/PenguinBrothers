class_name ScoreTable
extends Resource
## Valores de puntuación arcade (los usa ScoreManager). Un solo lugar para ajustarlos.

@export var enemy := 100
@export var barrel := 50
@export var destructible := 20
@export var power_up := 200
@export var key := 500
@export var screen_clear := 1000
@export var stage_clear := 3000
## Bonificación por cada segundo que sobra al completar una pantalla.
@export var time_bonus_per_second := 10

@export_group("Combo")
## Segundos entre derribos para encadenar un combo.
@export var combo_window := 1.2
## Multiplicador máximo (combo x2, x3... hasta este valor).
@export var max_combo := 8
