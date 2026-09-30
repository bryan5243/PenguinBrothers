"""Extrae y normaliza los fotogramas de los enemigos del Mundo 1 desde sus hojas de referencia.

Uso:
    pip install opencv-python-headless pillow numpy
    python3 tools/sprites/extract_enemies.py            # todos
    python3 tools/sprites/extract_enemies.py small_crab # uno
    godot --headless --path . --import
    godot --headless --path . -s tools/build_sprite_frames.gd

Las hojas (assets/references/enemies/world_01_*.png) no tienen transparencia: cada fotograma
está en una celda de un panel azul oscuro. Por celda:
  1. fondo = mediana del borde de la celda; se marca como fondo lo que se parece a él
     (distancia de color < BG_TOLERANCE) y está conectado con el borde (relleno desde fuera),
  2. se queda el componente principal (+ piezas grandes dentro de su caja) y se rellenan huecos,
  3. ancla: base = fila más baja del cuerpo (enemigos de suelo) o centro del cuerpo (voladores);
     centro horizontal = centro de masa.
Todos los fotogramas de un enemigo van a un lienzo común sin re-escalar (como el pingüino),
en assets/enemies/<id>/processed/, con manifest.json para build_sprite_frames.gd.
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BG_TOLERANCE = 52
PADDING = 2
BIG_BG_AREA = 180

# Animaciones estándar de enemigo: idle, walk, attack, hurt, death, special.
# Cada fila: (animación, x0, x1, y0, y1, número de celdas, índices a usar (None = todas), fps, bucle)
ENEMIES = {
    "small_crab": {
        "sheet": "world_01_small_crab.png", "anchor": "bottom",
        "rows": [
            ("idle", 20, 755, 350, 442, 7, None, 8, True),
            ("walk", 775, 1518, 350, 442, 7, None, 12, True),
            ("run", 20, 755, 502, 598, 7, None, 16, True),
            ("attack", 775, 1518, 502, 598, 6, None, 14, False),
            ("hurt", 20, 755, 662, 765, 5, None, 10, False),
            ("death", 775, 1518, 662, 765, 5, None, 8, False),
        ],
    },
    "hermit_crab": {
        "sheet": "world_01_hermit_crab.png", "anchor": "bottom",
        "rows": [
            ("idle", 20, 755, 344, 437, 6, None, 8, True),
            ("walk", 770, 1518, 344, 437, 7, None, 12, True),
            ("run", 20, 755, 494, 590, 6, None, 14, True),
            ("attack", 770, 1518, 494, 590, 6, None, 14, False),
            ("special", 20, 755, 648, 760, 6, None, 10, False),   # defensa en el caparazón
            ("hurt", 770, 1518, 648, 760, 5, None, 10, False),
            ("death", 20, 825, 814, 942, 6, None, 8, False),
        ],
    },
    "seagull": {
        "sheet": "world_01_seagull.png", "anchor": "center",
        "rows": [
            ("idle", 20, 760, 345, 445, 6, None, 8, True),
            ("walk", 775, 1520, 345, 445, 7, None, 12, True),     # volar
            ("attack", 20, 760, 500, 610, 6, None, 12, True),     # picado
            ("hurt", 775, 1520, 500, 610, 6, [0, 1, 2, 3], 10, False),
            ("death", 20, 760, 662, 775, 5, None, 8, False),
        ],
    },
    "small_octopus": {
        "sheet": "world_01_small_octopus.png", "anchor": "bottom",
        "rows": [
            ("idle", 20, 760, 344, 440, 7, None, 8, True),
            ("walk", 776, 1518, 344, 440, 6, None, 10, True),     # nadar / avanzar
            ("attack", 20, 760, 496, 600, 6, [0, 1, 2, 3], 10, False),  # lanza tinta
            ("hurt", 776, 1518, 496, 600, 5, None, 10, False),
            ("death", 20, 760, 657, 765, 6, [0, 1, 2, 3, 4], 8, False),
        ],
        # Proyectil de tinta (celda 6 del ataque): sprite aparte, no animación del pulpo.
        "extra": {"ink": (636, 760, 520, 580)},
    },
}


def cut(cell: np.ndarray, keep_all: bool = False) -> np.ndarray:
    """Máscara booleana del personaje dentro de la celda. `keep_all` conserva todas las
    piezas grandes (objetos formados por partes separadas: palmera, puerta con arco...)."""
    h, w = cell.shape[:2]
    border = np.concatenate([cell[0], cell[-1], cell[:, 0], cell[:, -1]]).astype(float)
    bg = np.median(border, axis=0)
    dist = np.linalg.norm(cell.astype(float) - bg, axis=2)
    c = cell.astype(int)
    # Panel azul marino (con degradado): poco rojo y claramente azul. Los contornos oscuros de
    # los sprites son casi negros (poco azul), así que no entran.
    navy = (c[..., 0] < 45) & (c[..., 2] > 30) & (c[..., 2] > c[..., 0] + 25) & (c[..., 1] < c[..., 2])
    bg_like = ((dist < BG_TOLERANCE) | navy).astype(np.uint8)
    # Relleno desde el borde: solo es fondo lo parecido al fondo y conectado con fuera.
    n, lab, stats, _ = cv2.connectedComponentsWithStats(bg_like, 4)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    # También es fondo una zona grande parecida al fondo aunque quede encerrada (p. ej. entre
    # el cuerpo y un efecto de corte que toca el borde de la celda).
    edge |= {i for i in range(1, n) if stats[i, cv2.CC_STAT_AREA] >= BIG_BG_AREA}
    outside = np.isin(lab, list(edge))
    fg = ~outside
    fg = cv2.morphologyEx(fg.astype(np.uint8), cv2.MORPH_OPEN, np.ones((2, 2), np.uint8)) > 0
    n, lab, stats, _ = cv2.connectedComponentsWithStats(fg.astype(np.uint8), 8)
    if n <= 1:
        return fg
    main = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    x, y, bw, bh = stats[main, :4]
    keep = lab == main
    for i in range(1, n):
        if i == main or stats[i, cv2.CC_STAT_AREA] < 40:
            continue
        cx, cy, cw, ch = stats[i, :4]
        inside = cx >= x - 2 and cy >= y - 2 and cx + cw <= x + bw + 2 and cy + ch <= y + bh + 2
        if inside or (keep_all and stats[i, cv2.CC_STAT_AREA] >= 150):
            keep |= lab == i
    # Huecos interiores (ojos, brillos) que se parecían al fondo.
    # Solo son huecos las zonas vacías que NO tocan el borde de la celda.
    n2, lab2, _, _ = cv2.connectedComponentsWithStats((~keep).astype(np.uint8), 4)
    edge2 = set(np.unique(np.concatenate([lab2[0], lab2[-1], lab2[:, 0], lab2[:, -1]])))
    keep |= (lab2 > 0) & ~np.isin(lab2, list(edge2)) & ~(outside & (dist < BG_TOLERANCE))
    return keep


def rgba(cell: np.ndarray, mask: np.ndarray) -> np.ndarray:
    alpha = cv2.GaussianBlur(mask.astype(np.float32), (3, 3), 0.5)
    alpha[mask] = 1.0
    return np.dstack([cell, (alpha * 255).astype(np.uint8)])


def extract(enemy_id: str) -> None:
    cfg = ENEMIES[enemy_id]
    sheet = np.array(Image.open(ROOT / "assets/references/enemies" / cfg["sheet"]).convert("RGB"))
    out = ROOT / "assets/enemies" / enemy_id
    (out / "processed").mkdir(parents=True, exist_ok=True)
    frames = {}
    anims = {}
    for anim, x0, x1, y0, y1, count, use, fps, loop in cfg["rows"]:
        step = (x1 - x0) / count
        names = []
        for i in range(count):
            if use is not None and i not in use:
                continue
            cx0, cx1 = int(x0 + step * i) + 3, int(x0 + step * (i + 1)) - 3
            cell = sheet[y0:y1, cx0:cx1]
            mask = cut(cell)
            ys, xs = np.nonzero(mask)
            if xs.size < 80:
                continue
            name = f"{anim}_{len(names) + 1}"
            frames[name] = (cell, mask)
            names.append(name)
        anims[anim] = {"frames": [f"processed/{n}.png" for n in names], "fps": fps, "loop": loop}

    # Anclas y lienzo común (sin escalar).
    anchors = {}
    for name, (cell, mask) in frames.items():
        ys, xs = np.nonzero(mask)
        cx = float(xs.mean())
        cy = float(ys.max() + 1) if cfg["anchor"] == "bottom" else float((ys.min() + ys.max() + 1) / 2)
        anchors[name] = (cx, cy, xs.min(), xs.max() + 1, ys.min(), ys.max() + 1)
    half_w = max(max(a[0] - a[2], a[3] - a[0]) for a in anchors.values())
    up = max(a[1] - a[4] for a in anchors.values())
    down = max(a[5] - a[1] for a in anchors.values())
    W = int(np.ceil(half_w)) * 2 + PADDING * 2
    if cfg["anchor"] == "bottom":
        H = int(np.ceil(up)) + PADDING
        origin_y = H
    else:
        half_h = int(np.ceil(max(up, down)))
        H = half_h * 2 + PADDING * 2
        origin_y = H // 2
    for name, (cell, mask) in frames.items():
        cx, cy = anchors[name][:2]
        canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        canvas.alpha_composite(Image.fromarray(rgba(cell, mask)), (int(round(W / 2 - cx)), int(round(origin_y - cy))))
        canvas.save(out / "processed" / f"{name}.png")

    idle_mask = frames[next(n for n in frames if n.startswith("idle"))][1]
    ys, _ = np.nonzero(idle_mask)
    manifest = {
        "character": enemy_id,
        "source": f"assets/references/enemies/{cfg['sheet']}",
        "canvas": [W, H],
        "anchor": cfg["anchor"],
        "reference_height": int(ys.max() - ys.min() + 1),
        "animations": anims,
    }
    for key, (x0, x1, y0, y1) in cfg.get("extra", {}).items():
        cell = sheet[y0:y1, x0:x1]
        mask = cut(cell)
        ys, xs = np.nonzero(mask)
        crop = rgba(cell, mask)[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        Image.fromarray(crop).save(out / f"{key}.png")
        manifest[key] = f"{key}.png"
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    print(f"{enemy_id}: {len(frames)} fotogramas, lienzo {W}x{H}, ancla {cfg['anchor']}")


if __name__ == "__main__":
    for eid in (sys.argv[1:] or list(ENEMIES)):
        extract(eid)
