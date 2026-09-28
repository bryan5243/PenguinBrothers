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
