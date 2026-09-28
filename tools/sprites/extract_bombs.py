"""Extrae los sprites de bombas y de la explosión desde la hoja general.

Uso:
    pip install opencv-python-headless pillow numpy
    python3 tools/sprites/extract_bombs.py
    godot --headless --path . --import

La hoja (assets/references/characters/general_sheet_characters_enemies_bombs_items.png) no
tiene transparencia: el fondo es un panel azul muy oscuro.

- Bombas: se quita el fondo por relleno desde el borde (flood fill) con tolerancia de color;
  el contorno claro de cada bomba impide que el relleno entre en la esfera (aunque sea negra).
  Cada bomba se normaliza para que su ESFERA mida SPHERE_DIAMETER px y quede centrada en el
  lienzo (la mecha sobresale por arriba). Así la escena Bomb escala todas igual:
  escala = 2 * body_radius / SPHERE_DIAMETER.
- Explosión: el fondo se elimina por luminosidad (el efecto es luz sobre fondo oscuro) y
  cada fase se centra en un lienzo común.

Salida: assets/bombs/<id>.png, assets/effects/explosion/explosion_<n>.png y un manifest.json.
"""
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "assets/references/characters/general_sheet_characters_enemies_bombs_items.png"
SPHERE_DIAMETER = 48
BOMB_CANVAS = 96

# id -> caja (x0, y0, x1, y1) en la hoja
BOMBS = {
    "normal": (16, 283, 92, 372),
    "blue": (106, 283, 187, 372),
    "green": (198, 283, 277, 372),
    "black": (291, 283, 370, 372),
}
EXPLOSION = [
    (842, 305, 873, 336),
    (880, 303, 918, 340),
    (924, 298, 975, 346),
    (978, 290, 1040, 350),
    (1042, 280, 1128, 368),
]


def cut_bomb(rgb: np.ndarray) -> np.ndarray:
    """RGBA con el fondo eliminado por relleno desde el borde."""
    h, w = rgb.shape[:2]
    bg = np.median(np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]]), axis=0)
    dist = np.linalg.norm(rgb.astype(float) - bg, axis=2)
    bg_like = (dist < 60).astype(np.uint8)
    flood = np.zeros((h + 2, w + 2), np.uint8)
    reached = np.zeros((h, w), np.uint8)
    for x, y in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)] + [(x, 0) for x in range(0, w, 4)] + \
            [(x, h - 1) for x in range(0, w, 4)] + [(0, y) for y in range(0, h, 4)] + [(w - 1, y) for y in range(0, h, 4)]:
        if bg_like[y, x] and not reached[y, x]:
            img = bg_like.copy() * 255
            flood[:] = 0
            cv2.floodFill(img, flood, (x, y), 128, loDiff=0, upDiff=0, flags=4)
            reached |= (img == 128).astype(np.uint8)
    fg = reached == 0
    # Solo el componente principal (la bomba con su mecha).
    n, lab, stats, _ = cv2.connectedComponentsWithStats(fg.astype(np.uint8), 8)
    if n > 1:
        main = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        fg = lab == main
    # Rellena huecos cerrados y fuerza opaca la esfera (en bombas oscuras el relleno puede
    # colarse por el borde si el contorno claro se interrumpe).
    cx, cy, d = sphere_of(fg.astype(np.uint8) * 255)
    yy, xx = np.mgrid[0:h, 0:w]
    fg |= (xx - cx) ** 2 + (yy - cy) ** 2 <= (d / 2.0 - 0.5) ** 2
    holes = cv2.floodFill(fg.astype(np.uint8) * 255, np.zeros((h + 2, w + 2), np.uint8), (0, 0), 128)[1]
    fg |= holes == 0
    alpha = cv2.GaussianBlur(fg.astype(np.float32), (3, 3), 0.6)
    return np.dstack([rgb, (alpha * 255).astype(np.uint8)])


def sphere_of(alpha: np.ndarray) -> tuple:
    """Centro y diámetro de la esfera: la fila más ancha da el diámetro; el centro está a
    medio diámetro por encima de la base."""
    mask = alpha > 128
    ys, xs = np.nonzero(mask)
    bottom = ys.max()
    widths = mask.sum(axis=1)
    row = int(np.argmax(widths))
    cols = np.nonzero(mask[row])[0]
    diameter = float(cols.max() - cols.min() + 1)
    cx = float(cols.min() + cols.max()) / 2.0
    cy = bottom + 1 - diameter / 2.0
    return cx, cy, diameter


def cut_light(rgb: np.ndarray) -> np.ndarray:
    """RGBA para efectos luminosos sobre fondo oscuro: alfa según brillo sobre el fondo."""
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    v = hsv[..., 2].astype(float)
    bg_v = np.median(np.concatenate([v[0], v[-1], v[:, 0], v[:, -1]]))
    alpha = np.clip((v - bg_v - 25) / 90.0, 0, 1)
    # Des-premultiplica el color del fondo para evitar halos oscuros.
    out = rgb.astype(float)
    a = alpha[..., None]
    bg = np.median(np.concatenate([rgb[0], rgb[-1]]), axis=0)
    out = np.where(a > 0.01, (out - bg * (1 - a)) / np.maximum(a, 0.01), 0)
    return np.dstack([np.clip(out, 0, 255).astype(np.uint8), (alpha * 255).astype(np.uint8)])


def main() -> None:
    sheet = np.array(Image.open(SHEET).convert("RGB"))
    bombs_dir = ROOT / "assets/bombs"
    fx_dir = ROOT / "assets/effects/explosion"
    bombs_dir.mkdir(parents=True, exist_ok=True)
    fx_dir.mkdir(parents=True, exist_ok=True)
    manifest = {"source": str(SHEET.relative_to(ROOT)), "sphere_diameter": SPHERE_DIAMETER,
                "bomb_canvas": BOMB_CANVAS, "bombs": {}, "explosion": []}

    for bid, (x0, y0, x1, y1) in BOMBS.items():
        rgba = cut_bomb(sheet[y0:y1, x0:x1])
        cx, cy, d = sphere_of(rgba[..., 3])
        s = SPHERE_DIAMETER / d
        img = Image.fromarray(rgba).resize((round(rgba.shape[1] * s), round(rgba.shape[0] * s)), Image.LANCZOS)
        canvas = Image.new("RGBA", (BOMB_CANVAS, BOMB_CANVAS), (0, 0, 0, 0))
        canvas.alpha_composite(img, (round(BOMB_CANVAS / 2 - cx * s), round(BOMB_CANVAS / 2 - cy * s)))
        canvas.save(bombs_dir / f"{bid}.png")
        manifest["bombs"][bid] = {"file": f"assets/bombs/{bid}.png", "source_sphere_diameter": d}

    frames = [cut_light(sheet[y0:y1, x0:x1]) for (x0, y0, x1, y1) in EXPLOSION]
    size = max(max(f.shape[0], f.shape[1]) for f in frames) + 4
    for i, f in enumerate(frames, 1):
        canvas = np.zeros((size, size, 4), np.uint8)
        oy, ox = (size - f.shape[0]) // 2, (size - f.shape[1]) // 2
        canvas[oy:oy + f.shape[0], ox:ox + f.shape[1]] = f
        Image.fromarray(canvas).save(fx_dir / f"explosion_{i}.png")
        manifest["explosion"].append(f"assets/effects/explosion/explosion_{i}.png")
    manifest["explosion_canvas"] = size
    (ROOT / "assets/bombs/manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"{len(BOMBS)} bombas ({BOMB_CANVAS}px, esfera {SPHERE_DIAMETER}px), "
          f"{len(frames)} fases de explosión ({size}px)")


if __name__ == "__main__" and len(__import__("sys").argv) == 1:
    main()


# ---------------------------------------------------------------------------
# Hoja nueva (blue_penguin_moves_and_bombs.png, con transparencia): mecha animada y
# explosión propia para cada tipo. Uso:  python3 tools/sprites/extract_bombs.py sheet
SHEET2 = ROOT / "assets/references/characters/blue_penguin_moves_and_bombs.png"
EXPLOSION_CANVAS = 160
# tipo -> (cajas de la mecha, franjas x de la explosión), en píxeles de la hoja
SHEET2_TYPES = {
    # «Bomba normal (negra)» de la hoja -> tipo black del juego.
    "black": ([(12, 790, 78, 892), (90, 790, 156, 892), (170, 790, 236, 892), (254, 790, 322, 892),
               (338, 790, 404, 892), (422, 790, 488, 892)],
              [(10, 75), (75, 145), (145, 232), (232, 330), (330, 415), (415, 510)]),
    "blue": ([(526, 790, 590, 892), (616, 790, 680, 892), (702, 790, 772, 892), (796, 790, 864, 892),
              (892, 790, 962, 892)],
             [(520, 588), (588, 665), (665, 765), (765, 880), (880, 990)]),
    "green": ([(1000, 785, 1090, 895), (1113, 785, 1200, 895), (1218, 785, 1305, 895),
               (1321, 785, 1408, 895), (1428, 785, 1515, 895)],
              [(1005, 1085), (1085, 1170), (1170, 1275), (1275, 1385), (1385, 1510)]),
}
EXPLOSION_Y = (888, 1010)


def _main_component(alpha: np.ndarray) -> np.ndarray:
    mask = (alpha > 200).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    if n <= 1:
        return mask > 0
    return lab == 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))


def _sphere(alpha: np.ndarray) -> tuple:
    """Esfera de la bomba: fila más ancha en la parte alta del cuerpo (evita el polvo)."""
    comp = _main_component(alpha)
    ys = np.nonzero(comp)[0]
    top, bottom = ys.min(), ys.max()
    widths = comp.sum(axis=1)
    limit = int(bottom - (bottom - top) * 0.12)
    row = int(np.argmax(widths[:limit]))
    cols = np.nonzero(comp[row])[0]
    d = float(cols.max() - cols.min() + 1)
    return (cols.min() + cols.max()) / 2.0, row, d


def extract_sheet2() -> None:
    sheet = np.array(Image.open(SHEET2).convert("RGBA"))
    root_dir = ROOT / "assets/bombs"
    summary = {}
    for bid, (fuse_boxes, fx_cols) in SHEET2_TYPES.items():
        out = root_dir / bid
        out.mkdir(parents=True, exist_ok=True)
        # Mecha: la hoja dibuja la bomba con tamaños algo distintos en cada fotograma; como es
        # el mismo objeto, cada fotograma se ajusta para que la ESFERA mida SPHERE_DIAMETER y
        # quede centrada (así la bomba no «late» ni tiembla al animar la mecha).
        fuse_files = []
        for i, (x0, y0, x1, y1) in enumerate(fuse_boxes, 1):
            cell = sheet[y0:y1, x0:x1].copy()
            cx, cy, d = _sphere(cell[..., 3])
            scale = SPHERE_DIAMETER / d
            # Quita el polvo del suelo: lo que queda por debajo de la esfera.
            r = d / 2.0
            yy, xx = np.mgrid[0:cell.shape[0], 0:cell.shape[1]]
            below = (yy > cy + r * 0.75) & ((xx - cx) ** 2 + (yy - cy) ** 2 > (r + 1) ** 2)
            cell[below, 3] = 0
            img = Image.fromarray(cell)
            img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
            canvas = Image.new("RGBA", (BOMB_CANVAS, BOMB_CANVAS), (0, 0, 0, 0))
            canvas.alpha_composite(img, (round(BOMB_CANVAS / 2 - cx * scale), round(BOMB_CANVAS / 2 - cy * scale)))
            canvas.save(out / f"fuse_{i}.png")
            fuse_files.append(f"fuse_{i}.png")
        # Explosión: franjas de la hoja; escala única por tipo para que la fase más grande
        # quepa en el lienzo; cada fase se centra en su caja visible.
        cells = [sheet[EXPLOSION_Y[0]:EXPLOSION_Y[1], a:b].copy() for a, b in fx_cols]
        boxes = []
        for c in cells:
            ys, xs = np.nonzero(c[..., 3] > 40)
            boxes.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
        biggest = max(max(b[2] - b[0], b[3] - b[1]) for b in boxes)
        fx_scale = (EXPLOSION_CANVAS - 8) / biggest
        fx_files = []
        visible_diameter = 0.0
        for i, (c, b) in enumerate(zip(cells, boxes), 1):
            crop = Image.fromarray(c).crop(b)
            crop = crop.resize((max(1, round(crop.width * fx_scale)), max(1, round(crop.height * fx_scale))), Image.LANCZOS)
            canvas = Image.new("RGBA", (EXPLOSION_CANVAS, EXPLOSION_CANVAS), (0, 0, 0, 0))
            canvas.alpha_composite(crop, ((EXPLOSION_CANVAS - crop.width) // 2, (EXPLOSION_CANVAS - crop.height) // 2))
            canvas.save(out / f"explosion_{i}.png")
            fx_files.append(f"explosion_{i}.png")
            visible_diameter = max(visible_diameter, float(max(crop.width, crop.height)))
        manifest = {
            "source": str(SHEET2.relative_to(ROOT)),
            "sphere_diameter": SPHERE_DIAMETER,
            "explosion_diameter": visible_diameter,
            "animations": {
                "fuse": {"frames": fuse_files, "fps": 10, "loop": True},
                "explode": {"frames": fx_files, "fps": 16, "loop": False},
            },
        }
        (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        summary[bid] = (len(fuse_files), len(fx_files), visible_diameter)
    print("bombas (hoja nueva):", summary)


if __name__ == "__main__" and len(__import__("sys").argv) > 1 and __import__("sys").argv[1] == "sheet":
    extract_sheet2()
