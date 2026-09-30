class_name PlayerConfig
extends Resource
## Parámetros de movimiento y vida del jugador.
## Todos los valores de ajuste del jugador viven aquí, no dispersos en el código.
## Unidades: píxeles y segundos (resolución lógica 1280x720).

@export_group("Movimiento")
@export var move_speed := 240.0
## Arcade: velocidad constante y respuesta inmediata al joystick. Correr queda desactivado
## salvo que se active aquí (el deslizamiento no depende de correr: ver `slide_enabled`).
@export var run_enabled := false
@export var run_speed := 340.0
## Segundos de movimiento continuo en el suelo antes de pasar a correr.
@export var run_delay := 0.55
@export var acceleration := 6000.0
@export var air_acceleration := 3600.0
@export var friction := 6000.0
@export var air_friction := 2400.0

@export_group("Salto")
## 680 con gravedad 1750 = salto de ~132 px: sube un piso de la arena (112 px).
@export var jump_force := 680.0
@export var gravity := 1750.0
@export var max_fall_speed := 950.0
## Velocidad vertical máxima al soltar el botón de salto (salto variable).
@export var jump_cut_speed := 400.0
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12

## Pausa breve tras aterrizar de una caída fuerte (no bloquea el movimiento).
@export var land_duration := 0.08
## Velocidad de caída mínima para mostrar la animación de aterrizaje.
@export var land_min_fall_speed := 380.0

@export_group("Acciones")
## Deslizarse: agacharse mientras se camina (o corre) lanza al pingüino sobre el vientre.
@export var slide_enabled := true
## Velocidad de salida del deslizamiento (si ya iba más rápido, conserva esa).
@export var slide_speed := 380.0
## Tiempo máximo deslizando; antes termina si la velocidad baja de `slide_min_speed`.
@export var slide_duration := 0.6
## Frenado: una parte fija (px/s²) y otra proporcional a la velocidad (1/s). Da un resbalón
## que empieza rápido y se va apagando, sin llegar a ser exagerado (~100 px).
@export var slide_friction := 260.0
@export var slide_drag := 3.2
@export var slide_min_speed := 70.0
## Tiempo (s) en llegar de la velocidad con la que entra a `slide_speed` (arranque suave).
@export var slide_ramp_time := 0.07
@export_subgroup("Empujar enemigos")
## Mientras se desliza es inmune a los ataques de los enemigos (contacto, pinza, picado,
## tinta) y empuja a los que toca sin dañarlos. Las bombas siguen haciendo daño.
@export var slide_immune_to_enemies := true
## El enemigo empujado sale a esta fracción de la velocidad del pingüino.
@export_range(0.0, 1.5) var slide_shove_ratio := 0.85
## Frenado extra (px/s²) que nota el pingüino mientras empuja a un enemigo.
@export var slide_shove_drag := 450.0
## Velocidad mínima para deslizarse, como fracción de la velocidad de marcha (`run_speed` si
## correr está activado, si no `move_speed`).
@export_range(0.0, 1.0) var slide_trigger_ratio := 0.85
## Velocidad al gatear agachado bajo un techo bajo (sin espacio para levantarse).
@export var crawl_speed := 110.0
@export var climb_speed := 180.0
## Tiempo que se ignoran las plataformas atravesables al bajar (abajo + saltar).
@export var drop_through_time := 0.25
@export var carry_speed_multiplier := 0.85
## Lanzamiento arcade corto: la bomba cae a ~70 px (algo más si se lanza saltando) y se queda.
@export var throw_force := Vector2(260.0, -300.0)

@export_group("Bombas")
## Tipos de bomba disponibles, en el orden de «cambiar bomba» (R / Y).
@export var bomb_types: Array[BombData] = []
## Máximo de bombas propias en juego a la vez.
@export var max_active_bombs := 3
## Niveles de poder de bomba (BOMB LEVEL 1–4): multiplicador del alcance de cada nivel.
## El nivel 4 es el «poder especial» (más daño y rompe objetos duros, ver BombData).
@export var bomb_power_radius: Array[float] = [1.0, 1.35, 1.7, 2.0]
## Al perder una vida se pierde el poder de bomba acumulado (arcade).
@export var reset_bomb_power_on_death := true
## Dónde sostiene la bomba (x hacia donde mira). Coincide con las manos de `carry`.
@export var bomb_hold_offset := Vector2(22.0, -30.0)
## Distancia horizontal a los pies a la que se coloca una bomba (abajo + bomba).
@export var bomb_place_distance := 26.0
## Lanzamiento mirando hacia arriba (arriba + bomba).
@export var throw_up_force := Vector2(80.0, -660.0)
## Parte de la velocidad del jugador que hereda la bomba lanzada.
@export_range(0.0, 1.0) var throw_inherit := 0.25
## Velocidad al soltar suavemente (abajo + interactuar/bomba con una bomba en la mano).
@export var drop_velocity := Vector2(40.0, -40.0)
## Alcance para recoger una bomba con Interactuar.
@export var pickup_range := 46.0
## Patada al caminar contra una bomba libre en el suelo.
## Patear bombas al caminar contra ellas. Desactivado en el arcade: una bomba colocada se
## queda donde se puso aunque pases por encima.
@export var kick_enabled := false
@export var kick_speed := 460.0
@export var kick_min_speed := 120.0

@export_group("Dos jugadores")
## Velocidad a la que un pingüino empuja al otro al caminar contra él (si chocan entre sí).
@export var push_speed := 110.0

@export_group("Cuerpo")
@export var body_radius := 16.0
@export var body_height := 60.0
@export var crouch_height := 38.0
## Altura de la colisión al deslizarse (cuerpo tumbado; mínimo 2 * body_radius).
@export var slide_height := 32.0
## Altura extra de la plataforma de la cabeza sobre la colisión, para que el compañero
## quede apoyado sobre el dibujo (penacho incluido) y no hundido en él.
@export var head_platform_offset := 12.0

@export_group("Visual")
## PLAYER_HEIGHT: altura lógica en pantalla (px) del fotograma de referencia (idle).
## Cada SpriteFrames guarda la altura de su fotograma de referencia; la escala visual es
## visual_height / reference_height * visual_scale, igual para TODAS las animaciones.
@export var visual_height := 74.0
## PLAYER_VISUAL_SCALE: único multiplicador global del tamaño visual (no afecta a la física).
@export var visual_scale := 1.0

@export_group("Vida")
@export var max_health := 3
@export var invulnerability_time := 1.6
@export var knockback := Vector2(300.0, -420.0)
@export var hurt_duration := 0.45
## Si cae por debajo de esta altura muere (el nivel puede sobrescribirlo).
@export var fall_death_y := 1400.0
@export var respawn_delay := 1.5
## Invulnerabilidad breve cuando la armadura absorbe un golpe.
@export var armor_break_invulnerability := 0.8
