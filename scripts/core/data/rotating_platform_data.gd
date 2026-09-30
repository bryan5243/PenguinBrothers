class_name RotatingPlatformData
extends Resource
## Ajustes de la plataforma giratoria (RotatingPlatform). Un tipo nuevo = un .tres en
## data/platforms/. La altura de lanzamiento de cada plataforma se puede ajustar en la escena
## (RotatingPlatform.launch_height) para que llegue justo al piso que le toca.

@export var id: StringName = &"rotating_platform"

@export_group("Giro")
## Temblor previo al giro (aviso).
@export var windup_time := 0.15
## Duración del giro (media vuelta del disco; el dibujo da la vuelta completa para acabar derecho).
@export var flip_time := 0.4
## Espera tras girar antes de poder volver a usarla.
@export var cooldown := 0.3
## Amplitud del temblor de aviso (px).
@export var shake_amplitude := 2.5

@export_group("Boca abajo")
## Girar hacia ABAJO mete a los de encima bajo el disco: cuelgan boca abajo y pueden
## desplazarse por debajo hasta `hang_time` segundos. Con ARRIBA (o saltar) la plataforma gira
## de vuelta y los deja encima; con ABAJO se sueltan; si no hacen nada, caen al acabar el tiempo.
@export var hang_time := 3.0
## Avisa (parpadeo) estos últimos segundos antes de soltarlo.
@export var hang_warning := 0.9
## Velocidad y aceleración al desplazarse colgado (más lento que andar, con inercia).
@export var hang_speed := 110.0
@export var hang_accel := 700.0
## Distancia mínima al borde del disco al desplazarse colgado.
@export var hang_margin := 10.0
## Pies del pingüino respecto al origen de la plataforma cuando cuelga (bajo el disco).
@export var hang_offset := Vector2(0.0, 22.0)
## Duración de la vuelta de regreso (la plataforma se endereza y deja a los colgados encima).
@export var revert_time := 0.35
## Pequeño salto con el que sale cada pingüino al volver a quedar encima.
@export var revert_hop := 230.0
## Inclinación máxima (rad) del cuerpo al balancearse colgado.
@export var hang_sway := 0.1

@export_group("Lanzamiento")
## Altura (px sobre la superficie) que alcanzan los pies de quien sale lanzado hacia arriba.
@export var launch_height := 150.0
## Velocidad hacia abajo con la que se suelta a los que estaban pegados.
@export var drop_speed := 120.0
## Velocidad vertical de los objetos (bombas, barriles) que salen despedidos al girar (~90 px de altura).
@export var object_launch_speed := 760.0

@export_group("Forma")
## Ancho de la superficie en la que se pisa (colisión); el dibujo se escala a este ancho.
@export var width := 104.0
@export var thickness := 16.0
## Altura de la zona encima de la superficie en la que se considera que algo va montado.
@export var rider_zone_height := 20.0
@export var texture: Texture2D
## Fracción del alto del dibujo, desde arriba, donde está la superficie (el borde del disco).
@export_range(0.0, 1.0) var texture_surface := 0.3
