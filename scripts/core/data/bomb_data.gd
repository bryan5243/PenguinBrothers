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
## Poder de destrucción base: los objetos con `hardness` mayor no se rompen (ver Destructible).
@export var break_power := 1
## Nivel de poder 4 («poder especial»): daño y poder de destrucción extra.
@export var special_damage_bonus := 1
@export var special_break_bonus := 1
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

@export_group("Física arcade")
## Radio de la esfera (colisión). El sprite se escala a este radio.
@export var body_radius := 12.0
## Física controlada (ver CarryableBody): gravedad, botes limitados y frenado fijos.
@export var gravity_scale := 1.8
## Fracción de velocidad vertical que conserva al botar (0 = no bota).
@export_range(0.0, 1.0) var bounce := 0.35
@export var max_bounces := 1
@export var min_bounce_speed := 160.0
## Frenado al tocar el suelo (px/s²): alto = se queda casi donde cae (arcade).
@export var ground_friction := 4000.0
## Fracción de velocidad horizontal al rebotar en una pared.
@export_range(0.0, 1.0) var wall_bounce := 0.3

@export_group("Aspecto")
## Animaciones «fuse» (mecha encendida) y «explode» (explosión). Ver extract_bombs.py.
@export var frames: SpriteFrames
## Imagen fija de respaldo (y para el HUD) si no hay `frames`.
@export var texture: Texture2D
## Diámetro de la esfera dentro de los fotogramas de la mecha (px).
@export var texture_sphere_diameter := 48.0
## Diámetro visible de la explosión dentro de sus fotogramas (px): se escala al radio.
@export var explosion_texture_diameter := 152.0
@export var icon: Texture2D
## Color del área de la explosión (círculo que marca el alcance real).
@export var area_color := Color(1.0, 0.6, 0.2)

@export_group("Munición")
## Cantidad inicial de munición (-1 = infinita).
@export var ammo := -1
