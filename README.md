# Penguin Brothers – Edición Asiática

Videojuego 2D de plataformas *side-scrolling*, cooperativo local para dos jugadores,
desarrollado en **Godot 4.7** con **GDScript**. Dos pingüinos (azul y rosa) recorren
10 mundos usando bombas, barriles y poderes elementales.

Plataformas objetivo: Windows, Android, iOS/iPadOS (y web opcional).
Controles: teclado, mando y pantalla táctil.

## Estado

**Fase 1 – Arquitectura base: completada.** Ver [docs/ROADMAP.md](docs/ROADMAP.md).

Al ejecutar el proyecto se abre una pantalla de arranque con un probador de controles
en vivo para ambos jugadores. El jugador jugable llega en la Fase 2.

## Cómo abrirlo

1. Instala [Godot 4.7](https://godotengine.org/download) (versión estándar, no .NET).
2. En el administrador de proyectos: **Importar** → selecciona `project.godot`.
3. Pulsa **F5** para ejecutar.

## Pruebas

```bash
godot --headless --path . res://tests/SmokeTest.tscn
```
Termina con código 0 si todas las comprobaciones pasan.

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
tests/       Prueba de humo automatizada
tools/       Scripts de generación de configuración
```

## Documentación

- [GAME_DESIGN.md](docs/GAME_DESIGN.md) – visión general y arquitectura
- [GAMEPLAY.md](docs/GAMEPLAY.md) – controles, mecánicas, animaciones
- [WORLDS.md](docs/WORLDS.md) – los 10 mundos
- [ENEMIES.md](docs/ENEMIES.md) – enemigos y jefes
- [ROADMAP.md](docs/ROADMAP.md) – fases de desarrollo
- [AGENTS.md](AGENTS.md) – reglas para agentes de IA que trabajen en el repositorio
