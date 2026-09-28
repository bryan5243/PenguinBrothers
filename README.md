# Penguin Brothers – Edición Asiática

Videojuego 2D de plataformas *side-scrolling*, cooperativo local para dos jugadores,
desarrollado en **Godot 4.7** con **GDScript**. Dos pingüinos (azul y rosa) recorren
10 mundos usando bombas, barriles y poderes elementales.

Plataformas objetivo: Windows, Android, iOS/iPadOS (y web opcional).
Controles: teclado, mando y pantalla táctil.

## Estado

**Fase 2 – Pingüino azul jugable: completada.** Ver [docs/ROADMAP.md](docs/ROADMAP.md).

Al ejecutar el proyecto se abre una pantalla de arranque con un probador de controles
en vivo y el botón **«Probar pingüino azul»**, que abre un nivel de prueba para caminar,
correr, saltar, agacharse, deslizarse, trepar escaleras y bajar de plataformas.

## Cómo abrirlo

1. Instala [Godot 4.7](https://godotengine.org/download) (versión estándar, no .NET).
2. En el administrador de proyectos: **Importar** → selecciona `project.godot`.
3. Pulsa **F5** para ejecutar.

## Pruebas

```bash
godot --headless --path . res://tests/SmokeTest.tscn
```
Termina con código 0 si todas las comprobaciones pasan.

## Sprites

Los fotogramas se extraen de las hojas de `assets/references/` con scripts de Python
(ver [docs/GAMEPLAY.md](docs/GAMEPLAY.md#sprites-del-pingüino-azul)) y se convierten en
`SpriteFrames` con `tools/build_sprite_frames.gd`.

## Regenerar configuración

Los ajustes del proyecto, los autoloads y el Input Map se generan con un script
(así se mantienen en un solo lugar y en el formato exacto de Godot 4.7):

```bash
godot --headless --path . -s tools/setup_project.gd
```

## Estructura

```
scenes/      Escenas (.tscn): main, player, enemies, bosses, objects, items, worlds/world_01..10, ui
scripts/     Código GDScript separado por dominio (core, player, enemies, ui, utilities...)
assets/      Arte del juego. assets/references/ contiene las hojas de diseño originales
audio/       music, sfx, voices (vacías: el audio se agregará después)
data/        Recursos .tres configurables (jugador, mundos; luego bombas, enemigos, poderes)
docs/        Documentación de diseño
tests/       Pruebas automatizadas (humo + movimiento del jugador)
tools/       Generación de configuración, SpriteFrames, nivel de prueba y extracción de sprites
```

## Documentación

- [GAME_DESIGN.md](docs/GAME_DESIGN.md) – visión general y arquitectura
- [GAMEPLAY.md](docs/GAMEPLAY.md) – controles, mecánicas, animaciones
- [WORLDS.md](docs/WORLDS.md) – los 10 mundos
- [ENEMIES.md](docs/ENEMIES.md) – enemigos y jefes
- [ROADMAP.md](docs/ROADMAP.md) – fases de desarrollo
- [AGENTS.md](AGENTS.md) – reglas para agentes de IA que trabajen en el repositorio
