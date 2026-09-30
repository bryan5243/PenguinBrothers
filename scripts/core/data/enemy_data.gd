class_name EnemyData
extends Resource
## Definición configurable de un enemigo arcade. Todos usan la misma escena
## (scenes/enemies/Enemy.tscn); `behavior` elige su comportamiento (EnemyBehavior) y el
## resto de campos lo ajustan. Un enemigo nuevo es un .tres nuevo en data/enemies/.
##
##   WALKER  -> camina, patrulla su piso, persigue, salta/baja plataformas, ataca con pinza
##   SHELL   -> WALKER que se esconde en el caparazón ante bombas o golpes (reduce el daño)
##   FLYER   -> vuela de pared a pared a su altura y cae en picado sobre los jugadores
##   SWIMMER -> (pulpo) WALKER lento que dispara tinta en línea recta
##   HOPPER, TURRET -> previstos para otros mundos (aún sin comportamiento propio)

enum Behavior { WALKER, SHELL, FLYER, SWIMMER, HOPPER, TURRET }

@export var id: StringName
@export var display_name := ""
@export var world := 1
@export var behavior: Behavior = Behavior.WALKER

@export_group("Combate")
@export var health := 1
## Daño por contacto y por ataque.
@export var damage := 1
@export var contact_damage := true
@export var attack_range := 48.0
@export var detection_range := 320.0
@export var attack_cooldown := 1.5
## Segundos de la animación de ataque; el golpe llega en `attack_hit_time`.
@export var attack_duration := 0.5
@export var attack_hit_time := 0.25
@export var hurt_duration := 0.35
## Invulnerabilidad breve tras un golpe (evita dobles golpes del mismo impacto).
@export var hurt_invulnerability := 0.25
## Multiplicador del empuje recibido de las explosiones (0 = no se mueve).
@export_range(0.0, 2.0) var knockback_taken := 1.0
@export var score := 100
## Botín al morir.
@export var drop_table: DropTable

@export_group("Movimiento")
@export var speed := 70.0
@export var chase_speed := 120.0
## Salto para subir un piso (0 = no salta).
@export var jump_force := 0.0
@export var can_drop_through := true
## Pausa entre patrullas (segundos, al azar entre ambos valores).
@export var idle_time := Vector2(0.4, 1.0)
@export var flying := false

@export_group("Caparazón (SHELL)")
## Distancia a una bomba encendida que le hace esconderse.
@export var shell_trigger_range := 110.0
@export var shell_time := 1.6
## Daño que absorbe el caparazón en cada golpe mientras está escondido.
@export var shell_armor := 1

@export_group("Vuelo (FLYER)")
@export var dive_speed := 420.0
@export var dive_return_speed := 160.0
## Distancia horizontal al jugador (debajo) a la que se lanza en picado.
@export var dive_trigger_width := 70.0

@export_group("Disparo (SWIMMER)")
@export var projectile_texture: Texture2D
@export var projectile_speed := 260.0
@export var projectile_range := 520.0

@export_group("Aspecto")
@export var sprite_frames: SpriteFrames
## Altura lógica en pantalla del fotograma de referencia (idle).
@export var visual_height := 44.0
## Tamaño de la colisión del cuerpo (independiente del dibujo).
@export var body_size := Vector2(40, 30)
## Los fotogramas tienen la base en el borde inferior (false = centrados: voladores).
@export var sprite_on_ground := true
@export var death_color := Color(0.95, 0.35, 0.3)
