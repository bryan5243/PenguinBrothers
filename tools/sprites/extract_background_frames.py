"""Prepara el fondo animado del Mundo 1 a partir de los fotogramas FHD de la playa.

Uso:
    python3 tools/sprites/extract_background_frames.py
    godot --headless --path . --import
    godot --headless --path . -s tools/build_arenas.gd

Fuente: assets/references/worlds/world_01_background_fhd/frame_NN.png (10 fotogramas de
1672x941, misma cámara). Están alineados (desplazamiento < 1 px) pero no son idénticos: cada
uno se generó aparte, así que el cielo, la tierra y la vegetación «hierven» un poco si se
reproducen enteros. Solo el mar y la orilla cambian de verdad (olas y espuma). Por eso:
  - base.png      = el fotograma 1 (tierra, cielo, cascadas, palmeras quedan quietos),
  - frame_NN.png  = todos los fotogramas al tamaño de la arena,
  - sea_mask.png  = máscara suave de lo que se mueve (desviación entre fotogramas, limitada a
                    la franja del mar): solo ahí se funden unos con otros (AnimatedBackdrop).
Los fotogramas se escalan para cubrir `COVER_HEIGHT` px de alto y se recortan al ancho de la
arena (centrados), así el juego los dibuja 1:1.

(Antes se usaba la rejilla de 30 fotogramas pequeños world_01_background_frames.png, que no
forman una secuencia continua; queda en references/ como histórico.)
"""
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/references/worlds/world_01_background_fhd"
OUT = ROOT / "assets/worlds/world_01/backdrop"
ARENA_W = 960
COVER_HEIGHT = 672          # igual que AnimatedBackdrop.cover_height
BASE_FRAME = 1
# Franja donde puede haber movimiento, en fracción del alto de la imagen (mar y orilla).
SEA_BAND = (0.52, 0.93)
MOTION_BLUR = 9             # suavizado del mapa de movimiento (px de la fuente)
MOTION_THRESHOLD = 17.0     # desviación típica (0-255) a partir de la cual se considera mar
FEATHER = 18                # borde suave de la máscara (px de la fuente)


def fit(img: Image.Image) -> Image.Image:
    scale = COVER_HEIGHT / img.height
    w = round(img.width * scale)
    img = img.resize((w, COVER_HEIGHT), Image.LANCZOS)
    left = max(0, (w - ARENA_W) // 2)
    return img.crop((left, 0, left + min(w, ARENA_W), COVER_HEIGHT))


def sea_mask(gray: np.ndarray) -> np.ndarray:
    std = cv2.GaussianBlur(gray.std(axis=0), (0, 0), MOTION_BLUR)
    h = std.shape[0]
    band = np.zeros_like(std, dtype=bool)
    band[int(h * SEA_BAND[0]):int(h * SEA_BAND[1])] = True
    moving = ((std > MOTION_THRESHOLD) & band).astype(np.uint8)
    # Solo la zona grande del mar (fuera quedan brillos sueltos de la vegetación).
    n, lab, stats, _ = cv2.connectedComponentsWithStats(moving, 8)
    if n > 1:
        big = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        moving = (lab == big).astype(np.uint8)
    moving = cv2.morphologyEx(moving, cv2.MORPH_CLOSE, np.ones((41, 41), np.uint8))
    # Rellenar huecos (rocas dentro del mar: se funden también, están alineadas).
    inv = (1 - moving).astype(np.uint8)
    n2, lab2, _, _ = cv2.connectedComponentsWithStats(inv, 4)
    edge = set(np.unique(np.concatenate([lab2[0], lab2[-1], lab2[:, 0], lab2[:, -1]])))
    moving |= ((lab2 > 0) & ~np.isin(lab2, list(edge))).astype(np.uint8)
    soft = cv2.GaussianBlur(moving.astype(np.float32), (0, 0), FEATHER)
    return (np.clip(soft, 0.0, 1.0) * 255).astype(np.uint8)


def main() -> None:
    paths = sorted(SRC.glob("frame_*.png"))
    if len(paths) < 2:
        raise SystemExit(f"Faltan fotogramas en {SRC}")
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("frame_*.png"):
        old.unlink()
        imp = old.with_suffix(".png.import")
        if imp.exists():
            imp.unlink()
    src = [Image.open(p).convert("RGB") for p in paths]
    gray = np.stack([np.asarray(im.convert("L"), dtype=np.float32) for im in src])
    mask = fit(Image.fromarray(sea_mask(gray)).convert("RGB")).convert("L")
    mask.save(OUT / "sea_mask.png")
    used = []
    for i, im in enumerate(src, 1):
        name = f"frame_{i:02d}.png"
        fit(im).save(OUT / name)
        used.append(name)
    base = fit(src[BASE_FRAME - 1])
    base.save(OUT / "base.png")
    top = np.array(base)[:4].reshape(-1, 3).mean(axis=0)
    manifest = {
        "source": str(SRC.relative_to(ROOT)),
        "frame_size": list(base.size),
        "base": "base.png",
        "frames": used,
        "sea_mask": "sea_mask.png",
        "sky_bottom": [round(float(c) / 255.0, 3) for c in top],
        "note": "fotogramas alineados pero generados por separado: solo se funden en el mar",
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    cover = float((np.asarray(mask) > 128).mean())
    print(f"{len(used)} fotogramas {base.size[0]}x{base.size[1]} + base + máscara "
          f"({cover:.0%} animado) -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
