# Referencias visuales

Hojas de diseño originales del proyecto. Godot ignora esta carpeta (`.gdignore`):
no se importan ni se incluyen en las exportaciones. Sirven como fuente para extraer
los fotogramas que sí usa el juego (en `assets/characters/`, `assets/enemies/`, etc.).

| Archivo | Contenido | Se usará en |
|---|---|---|
| `characters/blue_penguin_full_animations.png` | Pingüino azul (casco de aviador): todas las animaciones, especiales, direcciones, iconos y referencias de colisión. Con transparencia | Fuente actual del azul (`tools/sprites/extract_character_sheet.py`) |
| `characters/penguins_blue_pink_animations.png` | Pingüino azul y rosa: idle, caminar, correr, saltar, caer, aterrizar, agacharse, deslizarse, escalera, levantar/soltar barril, colocar bomba, expresiones, vista trasera, paleta | Fases 2–3 |
| `characters/general_sheet_characters_enemies_bombs_items.png` | Hoja general: personajes, bombas de colores, frutas, objetos, plataformas | Fases 4–5 |
| `enemies/world_01_small_crab.png` | Cangrejo pequeño: idle, caminar, correr, ataque, daño, muerte, efectos | Fase 8 |
| `enemies/world_01_seagull.png` | Gaviota: planear, volar, picado, aturdirse, caer, desaparecer, efectos | Fase 8 |
| `enemies/world_01_hermit_crab.png` | Cangrejo ermitaño: idle, caminar, correr, pinza, defensa en caparazón, daño, muerte | Fase 8 |
| `enemies/world_01_small_octopus.png` | Pulpo pequeño: idle, nadar, lanzar tinta, daño, muerte, efectos | Fase 8 |
| `enemies/world_01_enemies_animations.png` | Los 4 enemigos del Mundo 1 (versión anterior, resumen) | Fase 8 |
| `enemies/worlds_01_to_10_enemies_concepts.png` | Conceptos de enemigos de los 10 mundos | Fases 12–13 |
| `bosses/worlds_01_to_06_bosses.png` | Jefes de los mundos 1–6 (Orca Ninja, Águila Real, Leopardo, Tiburón, Oso Polar, Pingüino Robótico) con ataques | Fases 9, 12–13 |
| `worlds/worlds_01_to_06_sceneries.png` | Escenarios, tiles, fondos y decoración de los mundos 1–6 | Fases 7, 12–13 |
| `worlds/world_01_level_1_1_mockup.png` | Maqueta del nivel 1-1 "Playa Tropical" con HUD | Fases 6–7 |
| `ui/main_menu_design.png` | Diseño del menú principal | Fase 10 |
| `powers/powers_transformations.png` | 11 transformaciones de poder e íconos de objetos | Fases posteriores (poderes) |

