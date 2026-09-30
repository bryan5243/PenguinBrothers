"""Extrae las piezas del escenario del Mundo 1 (Isla Palmera) desde su hoja de tiles.

Uso:
    python3 tools/sprites/extract_tileset.py
    godot --headless --path . --import
    godot --headless --path . -s tools/build_arenas.gd

Hoja: assets/references/worlds/world_01_tileset_isla_palmera.png (fondo azul marino, sin
transparencia). Cada pieza se recorta de su caja, se le quita el fondo (mismo método que los
enemigos: relleno desde el borde + color del panel), se ajusta a su caja visible y, si se indica,
se escala a su tamaño de juego (así las piezas que se repiten —tablones, suelo, muros— encajan
1:1 con la geometría de las arenas). Salida: assets/worlds/world_01/<pieza>.png + manifest.json.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extract_enemies import cut, rgba  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "assets/references/worlds/world_01_tileset_isla_palmera.png"
OUT = ROOT / "assets/worlds/world_01"

# nombre -> (caja x0, y0, x1, y1 en la hoja, altura final en px (None = tamaño original), uso
#           [, True = conservar todas las piezas grandes, no solo la principal])
PIECES = {
    # Plataformas y suelo (se repiten con NinePatch en las arenas)
    "plank": ((255, 551, 422, 590), 30, "plataforma atravesable (tablón con musgo)"),
    "plank_short": ((171, 553, 245, 589), 30, "plataforma corta"),
    "ground": ((518, 548, 630, 637), 64, "suelo de arena con hierba"),
    "ground_rock": ((633, 550, 722, 627), 64, "suelo de roca"),
    "stone_tile": ((448, 643, 515, 707), None, "bloque de piedra (muros)"),
    "rock_block": ((523, 803, 579, 894), None, "roca sólida (obstáculo)"),
    "stone_blocks": ((450, 803, 514, 894), None, "bloques de piedra (destruible duro)"),
    # Columnas y soportes (decoración bajo las plataformas)
    "post_rope": ((738, 556, 768, 688), None, "poste con cuerda"),
    "post_log": ((390, 638, 422, 757), None, "tronco con cuerdas"),
    "stone_pillar": ((930, 550, 978, 622), None, "columna de piedra"),
    # Barriles y cajas
    "barrel": ((998, 553, 1057, 619), None, "barril"),
    "barrel_red": ((1062, 625, 1119, 689), None, "barril rojo"),
    "crate": ((1128, 625, 1187, 689), None, "caja"),
    "crate_big": ((1000, 695, 1064, 764), None, "caja grande"),
    "barrel_broken": ((1192, 553, 1253, 621), None, "barril roto (efecto)"),
    # Plataformas giratorias (Fase 6)
    "rotating_disk": ((1285, 558, 1402, 607), None, "disco de la plataforma giratoria"),
    "rotating_platform": ((1285, 645, 1402, 758), None, "plataforma giratoria con pie"),
    # Decoración
    "palm": ((5, 803, 120, 1007), None, "palmera grande", True),
    "palm_2": ((113, 825, 224, 1007), None, "palmera"),
    "bush": ((228, 805, 307, 862), None, "arbusto"),
    "fern": ((43, 925, 92, 974), None, "helecho"),
    "rock": ((95, 923, 144, 974), None, "roca"),
    "bush_flower": ((160, 913, 232, 974), None, "arbusto con flor"),
    "rock_flat": ((235, 935, 299, 972), None, "roca plana"),
    "flowers": ((305, 935, 347, 969), None, "flores"),
    "plant": ((308, 828, 347, 887), None, "planta"),
    "sandcastle": ((363, 803, 447, 897), None, "castillo de arena"),
    "spike_fence": ((630, 908, 754, 1004), None, "valla de pinchos (peligro)"),
    "skull_sign": ((450, 900, 514, 1002), None, "cartel de calavera"),
    "sign_arrow": ((1058, 915, 1152, 1004), None, "cartel de flecha"),
    "flag": ((1175, 915, 1272, 1004), None, "bandera"),
    # Escaleras y puentes
    "ladder": ((958, 803, 1032, 1004), None, "escalera de madera"),
    "rope_ladder": ((893, 803, 947, 1004), None, "escalera de cuerda"),
    "rope_bridge": ((773, 813, 877, 894), None, "puente de cuerda"),
    # Objetos especiales (Fase 7)
    "key": ((1053, 815, 1119, 909), None, "llave"),
    "door": ((1118, 810, 1202, 914), None, "puerta de madera (cerrada)", True),
    "door_portal": ((1203, 810, 1287, 914), None, "puerta portal (abierta)", True),
}

BACKGROUND = (848, 8, 1536, 256)
ARENA = (960, 720)


def extract_piece(sheet: np.ndarray, box: tuple, height, keep_all: bool = False) -> Image.Image:
    x0, y0, x1, y1 = box
    cell = sheet[y0:y1, x0:x1]
    mask = cut(cell, keep_all)
    ys, xs = np.nonzero(mask)
    img = Image.fromarray(rgba(cell, mask)).crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    if height:
        w = max(1, round(img.width * height / img.height))
        img = img.resize((w, height), Image.LANCZOS)
    return img


def background(sheet: np.ndarray) -> Image.Image:
    x0, y0, x1, y1 = BACKGROUND
    img = Image.fromarray(sheet[y0:y1, x0:x1])
    scale = ARENA[1] / img.height
    img = img.resize((round(img.width * scale), ARENA[1]), Image.LANCZOS)
    left = (img.width - ARENA[0]) // 2
    img = img.crop((left, 0, left + ARENA[0], ARENA[1]))
    # Fondo algo suavizado y atenuado para que se lean bien los personajes delante.
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    img = ImageEnhance.Color(img).enhance(0.85)
    img = ImageEnhance.Brightness(img).enhance(0.9)
    return img


def main() -> None:
    sheet = np.array(Image.open(SHEET).convert("RGB"))
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"source": str(SHEET.relative_to(ROOT)), "pieces": {}}
    for name, spec in PIECES.items():
        box, height, desc = spec[:3]
        img = extract_piece(sheet, box, height, len(spec) > 3 and spec[3])
        img.save(OUT / f"{name}.png")
        manifest["pieces"][name] = {"size": [img.width, img.height], "use": desc}
    background(sheet).save(OUT / "background.png")
    manifest["background"] = {"size": list(ARENA), "use": "fondo de las arenas (isla, mar y playa)"}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    print(f"{len(PIECES)} piezas + fondo -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
