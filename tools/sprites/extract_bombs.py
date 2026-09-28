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


if __name__ == "__main__":
    main()
