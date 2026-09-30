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
@export var cooldown := 0.6
## Amplitud del temblor de aviso (px).
@export var shake_amplitude := 2.5

@export_group("Boca abajo")
## Al girar hacia ABAJO los de encima dan la vuelta con ella y quedan pegados boca abajo a la
## parte de abajo durante este tiempo; luego caen. La plataforma sigue boca abajo ese tiempo.
@export var stick_time := 2.0
## Duración de la vuelta de regreso (la plataforma se endereza cuando los suelta).
@export var revert_time := 0.25
## Pies del pingüino respecto al origen de la plataforma cuando está pegado (bajo el disco).
@export var stick_offset := Vector2(0.0, 20.0)
## Separación horizontal entre dos pingüinos pegados a la vez.
@export var stick_spread := 26.0

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
