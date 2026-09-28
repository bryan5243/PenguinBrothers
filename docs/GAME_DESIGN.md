# Diseño del juego

## Visión

**Penguin Brothers – Edición Asiática** es un **arcade de pantalla fija** para 1 o 2 jugadores,
inspirado en la estructura del Penguin Brothers arcade de Subsino, con personajes, gráficos, nombres
y sonidos **originales** (no se copian sprites, música, efectos ni ROM del original).

- Género: arcade de acción cooperativo de pantalla fija (flip-screen). **No** es un plataformas con
  scroll, ni un juego tipo Mario, ni un metroidvania.
- Unidad de juego: **una arena cerrada que se ve completa**. Cámara fija; entre pantallas hay una
  transición arcade (fundido, destello, cortina), nunca un desplazamiento.
- Jugadores: 1–2 locales, ambos humanos (P1 teclado/mando 1, P2 teclado secundario/mando 2).
- Estilo visual: sprites 2D coloridos (no pixel art), prioridad absoluta: jugabilidad > gráficos.
- Plataformas: Windows, Android, iOS/iPadOS; web opcional. Controles: teclado, mando, táctil.
- Resolución lógica: **960×720 (4:3)**; en 16:9 se añaden barras laterales sin deformar.

### Bucle de una fase

```
PANTALLA A: aparecen enemigos → bombas → enemigos derrotados, barriles rotos → power-ups
            → sin enemigos: aparece la LLAVE → un jugador la recoge
      ↓ transición
PANTALLA B: aparece la PUERTA (+ enemigos y peligros) → llevar la llave hasta la puerta
      ↓
FASE COMPLETADA (bonificación por tiempo) → siguiente fase
```

Cada pantalla tiene tiempo límite (TIME): con poco tiempo el HUD avisa; a cero, todos pierden una
vida y la pantalla se repite. Sin vidas: GAME OVER → CONTINUE (vidas completas, puntuación a cero).
Las bombas no distinguen entre jugador, enemigo u objeto: el fuego amigo es parte de la estrategia.

## Personajes

| Jugador | Personaje | Rasgo |
|---|---|---|
| 1 | Pingüino azul (bufanda roja, mochila) | Valiente y equilibrado |
| 2 | Pingüino rosa (lazo, bufanda roja, mochila) | Ágil y rápida |

Referencia: `assets/references/characters/penguins_blue_pink_animations.png`.

## Pilares

1. **Bombas arcade**: se colocan, recogen, lanzan y dejan caer; física controlada (no realista),
   se encadenan y afectan a todos (fuego amigo). Niveles de poder 1–4.
2. **Arenas como puzles de acción**: dónde poner la bomba, dónde esconderse, cómo subir de piso
   (saltos y **plataformas giratorias** de 180°), qué barriles romper.
3. **Destrucción del escenario**: barriles, cajas, bloques y paredes con vida y botín (drop_table).
4. **Cooperación**: dos jugadores reales en la misma pantalla; se bloquean, se empujan, se suben
   uno encima del otro y se pueden dañar con las bombas.
5. **Progresión por mundos**: cada mundo tiene 4 enemigos propios y un jefe con fases en arena fija.
6. **Puntuación arcade**: SCORE 1/2, combos, bonificaciones por tiempo y pantalla, récord.
7. **Poderes elementales originales**: fuego, hielo, electricidad, viento, oscuridad, fuerza, velocidad, invulnerabilidad.

## Arquitectura técnica

```
Main.tscn (raíz persistente, transiciones arcade)
├── ScreenRoot ── pantalla actual: Título → Arena A → Arena B → Victoria / GAME OVER
└── Transition (fundido, destello, cortina)

Autoloads (siempre vivos, en este orden):
  EventBus      señales globales (desacopla gameplay, HUD, audio, guardado)
  SaveManager   guardado JSON en user://save_data.json (progreso, récord, ajustes)
  AudioManager  música y efectos por clave; buses Music/SFX; tolera archivos faltantes
  InputManager  traduce comandos del jugador a acciones del Input Map
  ScoreManager  SCORE 1/2, combos, bonificaciones (valores en data/score_table.tres)
  GameManager   modo (1 o 2 jugadores), mundo/fase, vidas, continues, pausa
  StageManager  flujo de la fase: pantallas A→B, tiempo, pantalla perdida, GAME OVER, victoria

Arena (una pantalla fija, scenes/stages/world_XX/WorldXX_StageYY_A.tscn)
  ├── escenario (Geometry sólido, Platforms atravesables)
  ├── BombPool        = BombManager de la pantalla (bombas y explosiones reutilizables)
  ├── Enemies         = EnemyManager (cuenta enemigos; sin enemigos → llave)
  ├── Items           llave, power-ups, barriles (fases 4–7)
  ├── PlayerSpawner   = PlayerManager (1 o 2 pingüinos en sus marcadores P1/P2)
  ├── ArcadeCamera    fija, solo tiembla con las explosiones
  └── HUD             ArcadeHUD
```

Correspondencia con los nombres del plan: *PlayerManager* → `PlayerSpawner` (por arena),
*EnemyManager* → `EnemyManager` (por arena), *BombManager* → `BombPool` (por arena),
*StageManager*, *ScoreManager*, *GameManager*, *AudioManager*, *SaveManager* → autoloads.

### Principios

- **Modular**: cada sistema en su script; ningún script monolítico.
- **Datos separados de la lógica**: `Resource` configurables en `data/`.
- **Comunicación por señales** (`EventBus`) en vez de referencias cruzadas.
- **Componentes reutilizables**: `StateMachine`/`State`, `HealthComponent`.
- **Animación separada del movimiento**: los estados piden animaciones por nombre estándar.
- **Rendimiento móvil**: renderizador Compatibility, pooling para bombas/proyectiles/efectos,
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
