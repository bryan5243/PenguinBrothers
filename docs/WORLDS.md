# Mundos

Cada mundo tiene un `WorldData` en `data/worlds/world_XX.tres` y una carpeta de escenas en
`scenes/worlds/world_XX/`. Solo el Mundo 1 se desarrolla primero; los demás reutilizarán
su arquitectura (ver `docs/ROADMAP.md`).

| # | Mundo | Enemigos | Jefe | Estado |
|---|---|---|---|---|
| 1 | Isla Palmera | Cangrejo pequeño, Gaviota, Cangrejo ermitaño, Pulpo pequeño | Orca Ninja | Datos listos · niveles en Fase 7 |
| 2 | Templo Oriental | Monje rata, Murciélago, Serpiente, Guerrero tengu | Águila Real | Solo datos |
| 3 | Montaña Nevada | Foca guerrera, Conejo ártico, Yeti pequeño, Pingüino enemigo | Leopardo de las Nieves | Solo datos |
| 4 | Mar Profundo | Pez globo, Medusa, Anguila eléctrica, Calamar | Tiburón blanco | Solo datos |
| 5 | Zona Ártica | Pingüino motorizado, Búho polar, Morsa, Liebre ártica | Oso polar | Solo datos |
| 6 | Base Robótica | Robot patrulla, Dron volador, Robot oruga, Torre láser | Pingüino robótico | Solo datos |
| 7 | Bosque de Bambú | Panda guerrero, Mono ninja, Tanuki, Avispa gigante | Tigre de Amur | Solo datos |
| 8 | Volcán de Fuego | Lagarto ígneo, Murciélago de lava, Roca viviente, Elemental de fuego | Dragón de fuego | Solo datos |
| 9 | Ciudad Neón | Mono hacker, Perro robot, Nave voladora, Fantasma digital | Mega dron | Solo datos |
| 10 | Castillo Celestial | Pájaro del viento, Guerrero nube, Espíritu rayo, Kairyu | Dragón celestial | Solo datos |

Referencias visuales: `assets/references/worlds/worlds_01_to_06_sceneries.png`
(escenarios 1–6) y `assets/references/enemies/worlds_01_to_10_enemies_concepts.png`.
Los mundos 7–10 aún no tienen hoja de escenario.

## Mundo 1 – Isla Palmera

Primer mundo completamente jugable (Fases 7–9).

- **Escena principal**: `scenes/worlds/world_01/World01.tscn`.
- **Ambiente**: playa, palmeras, agua, plataformas de tierra con césped, puentes de madera,
  cajas, barriles, zonas submarinas, pinchos.
- **Nivel 1-1 "Playa Tropical"** (maqueta en `assets/references/worlds/world_01_level_1_1_mockup.png`):
  inicio con cartel "¡A la aventura!", plataformas escalonadas, puente sobre el agua,
  zona submarina con pulpo, cajas, frutas y meta al final. Desplazamiento horizontal.
- **Contenido mínimo del nivel de prueba**: inicio, suelo, plataformas, agua, puente,
  palmeras, barriles, cajas, frutas, enemigos, checkpoints, zona final y puerta/meta.
- **Jefe**: Orca Ninja, en una arena propia.

## Arte de las arenas del Mundo 1 (implementado)

Las pantallas de la 1-1 usan las piezas de `world_01_tileset_isla_palmera.png`, extraídas con
`python3 tools/sprites/extract_tileset.py` a `assets/worlds/world_01/` (37 piezas + `background.png`):

| Elemento | Pieza | Cómo se usa |
|---|---|---|
| Fondo | `backdrop/` (`AnimatedBackdrop`) | Isla, mar y playa animados: base fija escalada a la pantalla + franja del mar que funde entre fotogramas (shader `sea_crossfade`). `background.png` queda como fondo estático de respaldo |
| Plataformas atravesables | `plank.png` | NinePatch: extremos fijos y centro en mosaico, al ancho de cada plataforma |
| Suelo | `ground.png` | NinePatch a lo ancho; la hierba asoma sobre el borde de colisión |
| Techo y paredes | `stone_tile.png` | Mosaico de piedra |
| Rocas del suelo | `rock_block.png` | Estirada al bloque sólido |
| Andamios | `post_rope.png` | Postes automáticos bajo los extremos de las plataformas |
| Caja, barril, bloque de piedra | `crate.png`, `barrel.png`, `stone_blocks.png` | Objetos de la Fase 4 |
| Decoración | palmeras, arbustos, flores, castillo de arena, bandera, cartel... | Capa trasera (`Decor`) y delantera (`FrontDecor`), sin colisión |
| Reservadas | `rotating_disk.png`, `key.png`, `door.png`, `door_portal.png`, `ladder.png`, `spike_fence.png`... | Plataformas giratorias (F6), llave y puerta (F7), escaleras y peligros |

La colisión nunca depende del dibujo: las arenas siguen siendo rectángulos exactos definidos en
`tools/build_arenas.gd` (plataformas, bloques, decoración por pantalla en `decor` / `front_decor`).

## Fondo animado

`python3 tools/sprites/extract_background_frames.py` toma los 10 fotogramas FHD de
`assets/references/worlds/world_01_background_fhd/` (1672×941, misma cámara) y los deja en
`assets/worlds/world_01/backdrop/` a 960×672 (cubren la arena bajo el marcador, centrados):
`base.png` (fotograma 1), `frame_NN.png`, `sea_mask.png` y `manifest.json`. La máscara se calcula
con la desviación entre fotogramas dentro de la franja del mar (olas, espuma y orilla), suavizada.
`tools/build_arenas.gd` crea `Background/Backdrop` con `scripts/arena/animated_backdrop.gd`: la
base quieta y, encima, solo el mar fundiendo un fotograma con el siguiente (`frame_time`). Los
fotogramas están alineados pero generados por separado: reproducidos enteros, el cielo y la
vegetación temblarían, por eso solo se funde el mar.
