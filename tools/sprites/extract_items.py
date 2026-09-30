"""Extrae objetos recogibles y del escenario para las fases arcade 4–5.

Uso:
    python3 tools/sprites/extract_items.py
    godot --headless --path . --import

- Frutas, armadura, botas, fuego y 1UP salen de la hoja general (sin transparencia): se
  quita el fondo con el mismo relleno desde el borde que las bombas (extract_bombs.cut_bomb
  sin forzar la esfera) y cada uno se ajusta a un cuadro de ITEM_SIZE px conservando la
  proporción (son objetos independientes).
- Caja rompible y bloque de piedra: misma hoja, a BLOCK_SIZE px.
- Barril: el barril lanzado de blue_penguin_full_animations.png (con transparencia), tumbado
  para rodar; se nivela girándolo con su eje principal y se ajusta a BARREL_SIZE px de ancho.
"""
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
GENERAL = ROOT / "assets/references/characters/general_sheet_characters_enemies_bombs_items.png"
FULL = ROOT / "assets/references/characters/blue_penguin_full_animations.png"
ITEM_SIZE = 44
BLOCK_SIZE = 48
BARREL_SIZE = 50

ITEMS = {
    "cherry": (12, 705, 68, 765), "banana": (72, 705, 128, 765), "orange": (140, 705, 196, 765),
    "apple": (210, 705, 268, 765), "grape": (280, 700, 334, 770), "watermelon": (346, 705, 408, 765),
    "pineapple": (414, 697, 466, 770), "melon": (480, 705, 536, 765), "cake": (550, 700, 610, 765),
    "armor": (636, 708, 700, 775), "boots": (712, 708, 780, 775), "fire": (800, 705, 864, 775),
    "one_up": (884, 718, 960, 772),
}
OBJECTS = {"crate": (582, 871, 650, 944), "stone_block": (662, 871, 727, 944)}


def remove_background(rgb: np.ndarray) -> np.ndarray:
    h, w = rgb.shape[:2]
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bg = np.median(border, axis=0)
    dist = np.linalg.norm(rgb.astype(float) - bg, axis=2)
    bg_like = ((dist < 55) * 255).astype(np.uint8)
    flood = bg_like.copy()
    mask = np.zeros((h + 2, w + 2), np.uint8)
    for x in range(w):
        for y in (0, h - 1):
            if flood[y, x] == 255:
                cv2.floodFill(flood, mask, (x, y), 128)
    for y in range(h):
        for x in (0, w - 1):
            if flood[y, x] == 255:
                cv2.floodFill(flood, mask, (x, y), 128)
    fg = flood != 128
    n, lab, stats, _ = cv2.connectedComponentsWithStats(fg.astype(np.uint8), 8)
    if n > 1:
        keep = np.zeros_like(fg)
        big = stats[1:, cv2.CC_STAT_AREA].max()
        for i in range(1, n):
            if stats[i, cv2.CC_STAT_AREA] >= big * 0.08:
                keep |= lab == i
        fg = keep
    alpha = cv2.GaussianBlur(fg.astype(np.float32), (3, 3), 0.6)
    return np.dstack([rgb, (alpha * 255).astype(np.uint8)])


def fit(rgba: np.ndarray, size: int) -> Image.Image:
    img = Image.fromarray(rgba)
    bbox = img.getbbox()
    img = img.crop(bbox)
    s = size / max(img.width, img.height)
    img = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(img, ((size - img.width) // 2, (size - img.height) // 2))
    return canvas


def barrel() -> Image.Image:
    sheet = np.array(Image.open(FULL).convert("RGBA"))
    cell = sheet[196:262, 1460:1528].copy()
    cell[..., 3] = np.where(cell[..., 3] > 200, 255, 0)   # quita las líneas de velocidad
    ys, xs = np.nonzero(cell[..., 3])
    pts = np.column_stack([xs, ys]).astype(np.float32)
    # Eje principal del barril tumbado: se gira para dejarlo horizontal.
    mean, eig = cv2.PCACompute(pts, mean=None)
    angle = float(np.degrees(np.arctan2(eig[0, 1], eig[0, 0])))
    if angle > 90:
        angle -= 180
    if angle < -90:
        angle += 180
    img = Image.fromarray(cell).rotate(angle, resample=Image.BICUBIC, expand=True)
    img = img.crop(img.getbbox())
    s = BARREL_SIZE / img.width
    return img.resize((BARREL_SIZE, max(1, round(img.height * s))), Image.LANCZOS)


def main() -> None:
    general = np.array(Image.open(GENERAL).convert("RGB"))
    manifest = {"items": {}, "objects": {}}
    for name, (x0, y0, x1, y1) in ITEMS.items():
        fit(remove_background(general[y0:y1, x0:x1]), ITEM_SIZE).save(ROOT / "assets/items" / f"{name}.png")
        manifest["items"][name] = f"assets/items/{name}.png"
    for name, (x0, y0, x1, y1) in OBJECTS.items():
        fit(remove_background(general[y0:y1, x0:x1]), BLOCK_SIZE).save(ROOT / "assets/objects" / f"{name}.png")
        manifest["objects"][name] = f"assets/objects/{name}.png"
    barrel().save(ROOT / "assets/objects/barrel.png")
    manifest["objects"]["barrel"] = "assets/objects/barrel.png"
    (ROOT / "assets/items/manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"{len(ITEMS)} objetos recogibles, {len(OBJECTS) + 1} objetos del escenario")


if __name__ == "__main__":
    main()
