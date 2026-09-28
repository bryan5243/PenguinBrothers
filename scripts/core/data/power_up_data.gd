class_name PowerUpData
extends Resource
## Definición de un objeto recogible o poder.

enum Category { SCORE, ARMOR, SPEED, ELEMENT, EXTRA_LIFE, BOMB_AMMO }
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
@export var pickup_sfx := "pickup"
