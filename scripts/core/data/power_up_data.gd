class_name PowerUpData
extends Resource
## Definición de un objeto recogible o poder. Lo aplica Player.apply_power_up():
##   SCORE       -> puntos (score_value)
##   ARMOR       -> protección que absorbe `effect_value` golpes
##   SPEED       -> velocidad x`effect_value` durante `duration` s
##   EXTRA_LIFE  -> +1 vida
##   BOMB_POWER  -> sube un nivel de bomba (BOMB LEVEL 1–4)
##   ELEMENT, BOMB_AMMO -> previstos para los poderes elementales (aún sin efecto)

enum Category { SCORE, ARMOR, SPEED, ELEMENT, EXTRA_LIFE, BOMB_AMMO, BOMB_POWER }
enum Element { NONE, FIRE, ICE, ELECTRIC, WIND, DARK, STRENGTH, SPEED, INVULNERABLE }

@export var id: StringName
@export var display_name := ""
@export var category: Category = Category.SCORE
@export var element: Element = Element.NONE
## Segundos que dura el efecto (0 = instantáneo o permanente).
@export var duration := 0.0
## Valor del efecto: puntos para SCORE, multiplicador para SPEED, golpes para ARMOR...
@export var effect_value := 0.0
@export var score_value := 0
@export var icon: Texture2D
@export var pickup_sfx := "power_up"
## Segundos que permanece en el suelo antes de desaparecer (parpadea al final).
@export var lifetime := 10.0
