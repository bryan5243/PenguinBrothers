"""Prepara el fondo animado del Mundo 1 a partir de la hoja de 30 fotogramas.

Uso:
    python3 tools/sprites/extract_background_frames.py
    godot --headless --path . --import

Hoja: assets/references/worlds/world_01_background_frames.png (rejilla 5x6 con separadores
oscuros; cada fotograma lleva su número «NN/30» arriba a la izquierda).

Los fotogramas NO son una animación continua: cada uno es una variante de la misma playa
(los acantilados, las nubes y las palmeras cambian de uno a otro). Reproducidos seguidos
«hierven». Por eso:
  - base.png       = un fotograma fijo (tierra, cielo, cascadas, palmeras),
  - frame_NN.png   = los fotogramas normalizados al mismo tamaño,
  - sea_mask.png   = máscara suave de la franja de MAR: solo ahí se funden unos fotogramas con
                     otros (AnimatedBackdrop), así el agua y la espuma se mueven y el resto no.
Se recorta la franja superior de todos para quitar el número del fotograma.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "assets/references/worlds/world_01_background_frames.png"
OUT = ROOT / "assets/worlds/world_01/backdrop"
COLS = [(0, 306), (309, 613), (616, 920), (923, 1227), (1231, 1536)]
ROWS = [(0, 158), (162, 320), (324, 486), (489, 658), (661, 836), (839, 1015)]
SIZE = (306, 170)          # tamaño común (las filas de la hoja miden entre 158 y 176 px)
CROP_TOP = 26              # quita el número «NN/30»
BASE_FRAME = 16            # fotograma fijo de referencia (1..30)
SKIP = {1}                 # el 1 es muy distinto del resto (otra isla)
# Franja de mar en el fotograma normalizado (x0, y0, x1, y1), ya sin la franja recortada.
SEA = (18, 56, 286, 122)
FEATHER = 7


def main() -> None:
    sheet = Image.open(SHEET).convert("RGB")
    OUT.mkdir(parents=True, exist_ok=True)
    frames = []
    for (y0, y1) in ROWS:
        for (x0, x1) in COLS:
            cell = sheet.crop((x0, y0, x1, y1)).resize(SIZE, Image.LANCZOS)
            frames.append(cell.crop((0, CROP_TOP, SIZE[0], SIZE[1])))
    used = []
    for i, f in enumerate(frames, 1):
        if i in SKIP:
            continue
        name = f"frame_{i:02d}.png"
        f.save(OUT / name)
        used.append(name)
    frames[BASE_FRAME - 1].save(OUT / "base.png")
    w, h = frames[0].size
    mask = Image.new("L", (w, h), 0)
    x0, y0, x1, y1 = SEA
    mask.paste(255, (x0, y0, x1, y1))
    mask = mask.filter(ImageFilter.GaussianBlur(FEATHER))
    mask.save(OUT / "sea_mask.png")
    top = np.array(frames[BASE_FRAME - 1])[:4].reshape(-1, 3).mean(axis=0)
    manifest = {
        "source": str(SHEET.relative_to(ROOT)),
        "frame_size": [w, h],
        "base": "base.png",
        "frames": used,
        "sea_mask": "sea_mask.png",
        "sky_bottom": [round(float(c) / 255.0, 3) for c in top],
        "note": "fotogramas no continuos: solo se funden en la franja de mar",
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"{len(used)} fotogramas {w}x{h} + base + máscara -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
