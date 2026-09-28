"""Extrae los fotogramas de un pingüino desde la hoja de referencia.

Uso:
    pip install "rembg[cpu]" opencv-python-headless pillow
    python3 tools/sprites/extract_penguin.py blue   # o pink

Genera en assets/characters/<personaje>/frames/ un PNG por fotograma, todos del mismo
tamaño de lienzo con los pies en el borde inferior y centrados en horizontal, y un
manifest.json que tools/build_sprite_frames.gd convierte en un SpriteFrames de Godot.

Pasos por fotograma: recorte de la celda, segmentación de fondo con rembg (u2net) a 3x,
componente principal, limpieza específica (polvo, escalera) y reducción a 1x con alfa
premultiplicado para evitar bordes oscuros.
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from rembg import new_session, remove

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "assets/references/characters/penguins_blue_pink_animations.png"
UPSCALE = 3
ALPHA_THRESHOLD = 110

# Desplazamiento vertical de cada fila de la hoja respecto al pingüino azul.
CHARACTERS = {
    "blue": {"folder": "blue_penguin", "dy_top": 0, "dy_ladder": 0},
    "pink": {"folder": "pink_penguin", "dy_top": 150, "dy_ladder": 140},
}

# Fotogramas derivados: nombre -> (origen, operación). La celda 3 de escalera sale
# mal segmentada; en vista de espalda es la pose 1 con el brazo contrario (reflejo).
DERIVED = {"climb_3": ("climb_1", "mirror")}

# (nombre, caja x0, y0, x1, y1 en la hoja para el pingüino azul, limpieza)
FRAMES = [
    ("idle_1", (248, 176, 338, 282), "top", []),
    ("walk_1", (350, 176, 422, 282), "top", []),
    ("walk_2", (420, 176, 492, 282), "top", []),
    ("walk_3", (486, 176, 559, 282), "top", ["dust"]),
    ("run_1", (561, 176, 639, 282), "top", ["dust"]),
    ("run_2", (636, 176, 714, 282), "top", ["dust"]),
    ("jump_1", (720, 170, 804, 282), "top", []),
    ("jump_2", (800, 170, 882, 282), "top", []),
    ("fall_1", (888, 176, 976, 282), "top", ["dust"]),
    ("land_1", (1018, 176, 1102, 282), "top", ["dust"]),
    ("crouch_1", (1148, 200, 1246, 282), "top", []),
    ("slide_1", (1264, 200, 1392, 282), "top", ["dust"]),
    ("slide_2", (1396, 200, 1520, 282), "top", ["dust", "snow"]),
    ("climb_1", (222, 474, 284, 584), "ladder", ["ladder"]),
    ("climb_2", (296, 474, 362, 584), "ladder", ["ladder"]),
    ("climb_4", (452, 474, 519, 584), "ladder", ["ladder"]),
]

ANIMATIONS = {
    "idle": {"frames": ["idle_1"], "fps": 1, "loop": True},
    "walk": {"frames": ["walk_1", "walk_2", "walk_3", "walk_2"], "fps": 10, "loop": True},
    "run": {"frames": ["run_1", "run_2"], "fps": 10, "loop": True},
    "jump": {"frames": ["jump_1", "jump_2"], "fps": 6, "loop": False},
    "fall": {"frames": ["fall_1"], "fps": 1, "loop": False},
    "land": {"frames": ["land_1"], "fps": 1, "loop": False},
    "crouch": {"frames": ["crouch_1"], "fps": 1, "loop": False},
    "slide": {"frames": ["slide_1", "slide_2"], "fps": 5, "loop": False},
    "climb": {"frames": ["climb_1", "climb_2", "climb_3", "climb_4"], "fps": 8, "loop": True},
}


def keep_largest(mask: np.ndarray) -> np.ndarray:
    n, lab, stats, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), 8)
    if n <= 1:
        return mask
    k = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    return lab == k


def fill_holes(mask: np.ndarray) -> np.ndarray:
    m = mask.astype(np.uint8) * 255
    h, w = m.shape
    flood = m.copy()
    ff = np.zeros((h + 2, w + 2), np.uint8)
    cv2.floodFill(flood, ff, (0, 0), 255)
    return (m | cv2.bitwise_not(flood)) > 0


def hsv(rgb: np.ndarray):
    h = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    return h[:, :, 0].astype(int), h[:, :, 1].astype(int), h[:, :, 2].astype(int)


def remove_dust(rgb, mask):
    """Quita nubes de polvo/nieve: gris-blanco poco saturado en la franja inferior lateral."""
    _, s, v = hsv(rgb)
    ys, xs = np.nonzero(mask)
    if len(ys) == 0:
        return mask
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    rows = np.arange(mask.shape[0])[:, None]
    low = rows > y0 + (y1 - y0) * 0.6
    dusty = (s < 40) & (v > 150) & low
    # El vientre blanco del pingüino está rodeado de azul; el polvo no.
    blue = body_colors(rgb)
    near_blue = cv2.dilate(blue.astype(np.uint8), np.ones((31, 31), np.uint8)) > 0
    cleaned = mask & ~(dusty & ~near_blue)
    return keep_largest(cleaned)


def remove_snow(rgb, mask):
    """Quita el rastro de nieve bajo el deslizamiento.

    En cada columna se recorre desde el píxel más bajo hacia arriba quitando el tramo
    blanco continuo: la nieve toca el suelo, mientras que el vientre y la mejilla quedan
    separados de ella por el color del cuerpo o por el contorno oscuro de la cara.
    """
    _, s, v = hsv(rgb)
    whiteish = (s < 70) & (v > 100)
    out = mask.copy()
    for x in range(mask.shape[1]):
        col = np.nonzero(out[:, x])[0]
        if len(col) == 0:
            continue
        y = col.max()
        while y >= 0 and out[y, x] and whiteish[y, x]:
            out[y, x] = False
            y -= 1
    out = cv2.morphologyEx(out.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8)) > 0
    return keep_largest(out)


def body_colors(rgb):
    """Píxeles propios del pingüino: azul/rosa del cuerpo, naranja de patas y pico, rojo de bufanda."""
    h, s, v = hsv(rgb)
    blue = (h >= 95) & (h <= 135) & (s > 70) & (v > 95)
    pink = ((h >= 140) | (h <= 5)) & (s > 60) & (v > 120)
    orange = (h >= 8) & (h <= 28) & (s > 120) & (v > 160)
    red = ((h <= 6) | (h >= 170)) & (s > 120) & (v > 90)
    return blue | pink | orange | red


def remove_ladder(rgb, mask):
    """Separa al pingüino de la escalera dibujada detrás.

    1. Silueta = colores del cuerpo (en la máscara de rembg) cerrados y rellenos: la mochila
       marrón queda dentro del contorno; largueros y peldaños quedan fuera.
    2. rembg confunde las patas con los peldaños, así que se añaden por color (naranja)
       las piezas que estén bajo el cuerpo.
    """
    body = body_colors(rgb) & mask
    body = keep_largest(cv2.morphologyEx(body.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((25, 25), np.uint8)) > 0)
    body = fill_holes(body)
    body = cv2.dilate(body.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
    result = keep_largest(mask & body)
    h, s, v = hsv(rgb)
    orange = (h >= 8) & (h <= 28) & (s > 110) & (v > 150)
    orange = cv2.morphologyEx(orange.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8)) > 0
    ys, xs = np.nonzero(result)
    n, lab, stats, cent = cv2.connectedComponentsWithStats(orange.astype(np.uint8), 8)
    for i in range(1, n):
        cx, cy = cent[i]
        if stats[i, cv2.CC_STAT_AREA] > 60 and xs.min() <= cx <= xs.max() and cy > (ys.min() + ys.max()) / 2:
            result |= lab == i
    return result


CLEANERS = {"dust": remove_dust, "snow": remove_snow, "ladder": remove_ladder}


def extract(character: str) -> None:
    cfg = CHARACTERS[character]
    out_dir = ROOT / "assets/characters" / cfg["folder"] / "frames"
    out_dir.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SHEET).convert("RGB")
    session = new_session("u2net")
    frames = {}
    for name, (x0, y0, x1, y1), row, cleaners in FRAMES:
        dy = cfg["dy_top"] if row == "top" else cfg["dy_ladder"]
        crop = sheet.crop((x0, y0 + dy, x1, y1 + dy))
        big = crop.resize((crop.width * UPSCALE, crop.height * UPSCALE), Image.LANCZOS)
        cut = np.array(remove(big, session=session))
        rgb = cut[:, :, :3].copy()
        mask = keep_largest(cut[:, :, 3] > ALPHA_THRESHOLD)
        for c in cleaners:
            mask = CLEANERS[c](rgb, mask)
        mask = fill_holes(mask) if "ladder" not in cleaners else mask
        rgba = np.dstack([np.array(big), (mask * 255).astype(np.uint8)])
        img = Image.fromarray(rgba, "RGBA")
        img = img.crop(img.getbbox())
        # Reducción con alfa premultiplicado (sin halos oscuros).
        small = img.convert("RGBa").resize(
            (max(1, round(img.width / UPSCALE)), max(1, round(img.height / UPSCALE))), Image.LANCZOS
        ).convert("RGBA")
        frames[name] = small
        print(f"  {name}: {small.size}")

    for name, (src, op) in DERIVED.items():
        if op == "mirror":
            frames[name] = frames[src].transpose(Image.FLIP_LEFT_RIGHT)

    # Lienzo común: pies abajo, centrado horizontal.
    width = max(f.width for f in frames.values()) + 4
    height = max(f.height for f in frames.values()) + 2
    width += width % 2
    for name, img in frames.items():
        canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        canvas.alpha_composite(img, ((width - img.width) // 2, height - img.height))
        canvas.save(out_dir / f"{name}.png", optimize=True)

    manifest = {
        "character": cfg["folder"],
        "canvas": [width, height],
        "source": str(SHEET.relative_to(ROOT)),
        "animations": {
            anim: {**data, "frames": [f"frames/{f}.png" for f in data["frames"]]}
            for anim, data in ANIMATIONS.items()
        },
    }
    (out_dir.parent / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
    print(f"{character}: {len(frames)} fotogramas, lienzo {width}x{height}")


if __name__ == "__main__":
    extract(sys.argv[1] if len(sys.argv) > 1 else "blue")
