# Diseño del juego

## Visión

**Penguin Brothers – Edición Asiática** es un plataformas 2D *side-scrolling* de estilo arcade,
cooperativo local para dos jugadores. Dos pingüinos atraviesan 10 mundos de temática asiática
y natural usando bombas, barriles, objetos del escenario y poderes elementales.

- Género: plataformas arcade cooperativo.
- Jugadores: 1–2 locales (online no previsto por ahora).
- Estilo visual: sprites 2D coloridos con aspecto renderizado en 3D (no pixel art).
- Plataformas: Windows, Android, iOS/iPadOS; web opcional.
- Controles: teclado, mando y pantalla táctil.
- Resolución lógica: 1280×720, adaptable (16:9, 16:10, móvil, tablet, ultrawide).

## Personajes

| Jugador | Personaje | Rasgo |
|---|---|---|
| 1 | Pingüino azul (bufanda roja, mochila) | Valiente y equilibrado |
| 2 | Pingüino rosa (lazo, bufanda roja, mochila) | Ágil y rápida |

Referencia: `assets/references/characters/penguins_blue_pink_animations.png`.

## Pilares

1. **Bombas con física**: se lanzan, se colocan, ruedan, rebotan y se encadenan.
2. **Interacción con el escenario**: barriles y cajas se levantan, transportan y lanzan.
3. **Cooperación**: dos jugadores comparten pantalla; en el futuro, revivir, compartir objetos y ataques combinados.
4. **Progresión por mundos**: cada mundo tiene 4 enemigos propios y un jefe con fases.
5. **Poderes elementales originales**: fuego, hielo, electricidad, viento, oscuridad, fuerza, velocidad, invulnerabilidad.

## Arquitectura técnica

```
Main.tscn (raíz persistente)
└── ScreenRoot ── pantalla actual (BootScreen → menú → niveles)

Autoloads (siempre vivos, en este orden):
  EventBus      señales globales (desacopla gameplay, HUD, audio, guardado)
  SaveManager   guardado JSON en user://save_data.json (progreso + ajustes)
  AudioManager  música y efectos por clave; buses Music/SFX; tolera archivos faltantes
  InputManager  traduce comandos del jugador a acciones del Input Map
  GameManager   modo (individual/cooperativo), mundo/nivel actual, puntuaciones, vidas, pausa
```

### Principios

- **Modular**: cada sistema en su script; ningún script monolítico.
- **Datos separados de la lógica**: `Resource` configurables en `data/`.
- **Comunicación por señales** (`EventBus`) en vez de referencias cruzadas.
- **Componentes reutilizables**: `StateMachine`/`State`, `HealthComponent`.
- **Animación separada del movimiento**: los estados piden animaciones por nombre estándar.
- **Rendimiento móvil**: renderizador Compatibility, pooling para bombas/proyectiles/efectos (Fase 4+),
  partículas moderadas, texturas de tamaño razonable.

### Capas de física

| Capa | Nombre | Uso |
|---|---|---|
| 1 | world | Suelo y paredes sólidas |
| 2 | players | Pingüinos |
| 3 | enemies | Enemigos y jefes |
| 4 | bombs | Bombas |
| 5 | objects | Barriles, cajas, objetos físicos |
| 6 | platforms | Plataformas atravesables desde abajo |
| 7 | hazards | Pinchos, lava, agua dañina |
| 8 | pickups | Frutas y power-ups |

### Datos configurables

| Clase | Carpeta | Campos principales |
|---|---|---|
| `PlayerConfig` | `data/player/` | velocidades, aceleración, fricción, salto, gravedad, coyote time, buffer, deslizamiento, vida |
| `BombData` | `data/bombs/` | daño, radio, mecha, empuje, rebote, textura, efecto, sonido |
| `EnemyData` | `data/enemies/` | vida, velocidad, daño, alcance, puntuación, comportamiento |
| `BossData` | `data/bosses/` | EnemyData + umbrales de fase y multiplicadores |
| `PowerUpData` | `data/items/` | categoría, elemento, duración, valor, ícono |
| `WorldData` | `data/worlds/` | nombre, niveles, enemigos, jefe, música |

### Guardado

`user://save_data.json`, versionado. Secciones:
- `progress`: mundo y nivel desbloqueados, mejores puntuaciones, récord, vidas.
- `settings`: volumen de música y efectos, pantalla completa, vibración, controles táctiles, idioma.

Al cargar, los datos se fusionan con los valores por defecto (una versión nueva del juego
no rompe partidas anteriores).
