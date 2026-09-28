class_name BombData
extends Resource
## Definición de un tipo de bomba. La escena de bomba base (scenes/bombs/Bomb.tscn) lee
## estos datos; un tipo nuevo es solo un archivo .tres nuevo en data/bombs/ (lo crea
## tools/setup_project.gd para los tipos iniciales).

@export var id: StringName
@export var display_name := ""

@export_group("Explosión")
@export var damage := 1
@export var explosion_radius := 96.0
@export var knockback := 420.0
## Daña también a los jugadores, compañero incluido (arcade: la explosión no distingue).
## Desactivado, la explosión solo empuja a los jugadores.
@export var hurts_players := true
## Retraso al detonar por reacción en cadena (otra explosión la alcanza).
@export var chain_delay := 0.12
## Escena de efecto de explosión. Vacío = scenes/bombs/Explosion.tscn.
@export var explosion_effect: PackedScene
## Tinte del efecto de explosión.
@export var explosion_tint := Color.WHITE
@export var explode_sfx := "explosion"

@export_group("Mecha")
@export var fuse_time := 2.4
## Últimos segundos de mecha en los que la bomba parpadea como aviso.
@export var fuse_warning_time := 0.8

@export_group("Física")
## Radio de la esfera (colisión). El sprite se escala a este radio.
@export var body_radius := 12.0
@export var mass := 1.0
@export var gravity_scale := 1.8
## Rebote al chocar (0 = no rebota, 1 = rebote completo).
@export_range(0.0, 1.0) var bounce := 0.35
@export_range(0.0, 1.0) var friction := 0.7
## Frenado lineal (rodar sin fin se ve raro).
@export var linear_damp := 0.4

@export_group("Aspecto")
@export var texture: Texture2D
## Diámetro de la esfera dentro de `texture` (px). Ver tools/sprites/extract_bombs.py.
@export var texture_sphere_diameter := 48.0
@export var icon: Texture2D

@export_group("Munición")
## Cantidad inicial de munición (-1 = infinita).
@export var ammo := -1
