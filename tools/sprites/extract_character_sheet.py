"""Extrae y normaliza los fotogramas de un personaje desde una hoja de animaciones completa.

Uso:
    pip install opencv-python-headless pillow numpy
    python3 tools/sprites/extract_character_sheet.py blue_penguin
    godot --headless --path . --import
    godot --headless --path . -s tools/build_sprite_frames.gd

La hoja de referencia ya trae transparencia (los personajes tienen alfa ~255 y los
paneles de fondo ~70), así que no hace falta segmentar: basta con un umbral de alfa.

Por cada fotograma:
  1. Recorta la celda de la hoja y la guarda tal cual en  <personaje>/source/  (original).
  2. Aísla al personaje: umbral de alfa, borrado de objetos/efectos que no son del
     personaje (barril, bomba, escalera, nieve, estrellas, fuego) en zonas definidas a
     mano abajo, protegiendo los colores del cuerpo, y se queda con el componente
     principal.
  3. Calcula dos anclas:  línea de pies = fila más baja del personaje;
     centro horizontal = centro de masa de los píxeles azules del cuerpo (no le afectan
     la bufanda al viento ni los efectos).
  4. Coloca el dibujo SIN ESCALAR en un lienzo común a TODAS las animaciones, con la
     línea de pies en el borde inferior y el centro horizontal en la mitad del lienzo.
     Resultado en  <personaje>/processed/.

Así el origen del sprite (pies, centro) es el mismo punto en todos los fotogramas y el
personaje no cambia de tamaño ni «salta» al cambiar de animación. El tamaño final en el
juego lo decide una sola escala global (PlayerConfig.visual_height / reference_height).

También escribe <personaje>/manifest.json, que usa tools/build_sprite_frames.gd.
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ALPHA_THRESHOLD = 200
MIN_EXTRA_COMPONENT = 25  # píxeles; piezas menores sueltas se descartan
CANVAS_PADDING = 2
FILL_KERNEL = 15  # tamaño máximo de los huecos que se rellenan tras borrar un objeto

# ----------------------------------------------------------------- clases de color
# HSV de OpenCV: H 0–180, S y V 0–255.


def color_classes(rgb: np.ndarray) -> dict:
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    h, s, v = hsv[..., 0].astype(int), hsv[..., 1].astype(int), hsv[..., 2].astype(int)
    return {
        "blue": (h >= 95) & (h <= 132) & (s > 80) & (v > 50),
        "red": ((h <= 8) | (h >= 165)) & (s > 110) & (v > 60),
        "orange": (h > 6) & (h <= 22) & (s > 150) & (v > 205),   # patas, pico, manos
        "white": (s < 70) & (v > 150),
        "yellow": (h > 20) & (h <= 40) & (v > 150),
        "wood": (h > 5) & (h <= 26) & (s > 60) & (v <= 235),     # barril, escalera, cuero
        "grey": (s < 95) & (v > 40) & (v < 175),                  # bomba, aros del barril
        "dark": (v < 95),
    }


# --------------------------------------------------------------------- perfiles
# Coordenadas en píxeles de la hoja. Cada fotograma: celda (x0, y0, x1, y1) y una
# lista de borrados: {"rect": (x0, y0, x1, y1), "protect": [...]} borra todo lo que
# no sea de las clases protegidas; con "only": [...] borra solo esas clases.

GROUND_ANIMS = None  # todas las animaciones comparten la línea de pies

PROFILES = {
    "blue_penguin": {
        "sheet": "assets/references/characters/blue_penguin_full_animations.png",
        "reference": "idle_1",
        "frames": {
            # --- fila 0
            "idle_1": ((15, 36, 88, 154), []),
            "idle_2": ((88, 36, 155, 154), []),
            "idle_3": ((155, 36, 226, 154), []),
            "idle_4": ((226, 36, 294, 154), []),
            "walk_1": ((298, 36, 370, 154), []),
            "walk_2": ((370, 36, 438, 154), []),
            "walk_3": ((438, 36, 510, 154), []),
            "run_1": ((516, 36, 587, 154), [
                {"rect": (580, 126, 587, 154), "protect": []}]),
            "run_2": ((578, 36, 654, 154), [
                {"rect": (578, 136, 604, 154), "protect": ["orange", "blue"]},
                {"rect": (630, 124, 650, 154), "protect": ["orange", "blue"]}]),
            "run_3": ((650, 36, 721, 154), [
                {"rect": (698, 132, 721, 154), "only": ["white", "grey"]}]),
            "run_4": ((706, 36, 798, 154), [
                {"rect": (706, 126, 752, 154), "protect": ["orange", "blue"]}]),
            "jump_1": ((805, 36, 872, 154), []),
            "jump_2": ((872, 36, 938, 154), []),
            "jump_3": ((938, 36, 1012, 154), []),
            "fall_1": ((1020, 36, 1105, 154), []),
            "fall_2": ((1105, 36, 1172, 154), []),
            "land_1": ((1180, 36, 1250, 154), [
                {"rect": (1180, 138, 1250, 154), "protect": ["orange", "wood", "red"]}]),
            "land_2": ((1238, 36, 1312, 154), [
                {"rect": (1238, 136, 1312, 154), "protect": ["orange", "wood", "red"]}]),
            "land_3": ((1312, 36, 1388, 154), []),
            "crouch_1": ((1394, 60, 1455, 154), []),
            "crouch_2": ((1455, 60, 1522, 154), []),
            # --- fila 1
            "slide_1": ((12, 215, 125, 305), [
                {"rect": (12, 266, 62, 305), "protect": ["blue", "red", "orange"]},
                {"rect": (12, 283, 125, 305), "only": ["white"]}]),
            "slide_2": ((125, 215, 265, 305), [
                {"rect": (125, 266, 185, 305), "protect": ["blue", "red"]},
                {"rect": (125, 288, 265, 305), "only": ["white"]}]),
            "slide_3": ((265, 215, 402, 305), [
                {"rect": (265, 262, 300, 305), "protect": ["blue", "red"]},
                {"rect": (265, 290, 402, 305), "only": ["white"]}]),
            "climb_1": ((415, 188, 500, 310), [
                {"rect": (462, 188, 500, 224), "protect": []},
                {"rect": (482, 188, 500, 310), "protect": []},
                {"rect": (462, 224, 482, 310), "only": ["wood", "dark", "grey"]}]),
            "climb_2": ((500, 188, 575, 310), [
                {"rect": (531, 188, 575, 207), "protect": []},
                {"rect": (560, 188, 575, 310), "protect": []},
                {"rect": (531, 222, 560, 310), "only": ["wood", "dark", "grey"]}]),
            "climb_3": ((575, 188, 655, 310), [
                {"rect": (634, 188, 655, 310), "protect": []},
                {"rect": (615, 222, 634, 310), "only": ["wood", "dark", "grey"]}]),
            "climb_4": ((655, 188, 755, 310), [
                {"rect": (700, 188, 755, 215), "protect": []},
                {"rect": (717, 188, 755, 310), "protect": []},
                {"rect": (700, 240, 717, 310), "only": ["wood", "dark", "grey"]}]),
            # Barril: se borra y el hueco que deja dentro de la silueta se rellena
            # ("fill"); en el juego el objeto llevado se dibuja delante.
            "lift_1": ((766, 200, 882, 310), [
                {"rect": (812, 252, 872, 310), "only": ["wood", "dark", "grey", "yellow"], "fill": True}]),
            "lift_2": ((882, 200, 988, 310), [
                {"rect": (925, 246, 988, 310), "only": ["wood", "dark", "grey", "yellow"], "fill": True}]),
            "carry_1": ((994, 200, 1106, 310), [
                {"rect": (1040, 236, 1106, 292), "only": ["wood", "dark", "grey", "yellow"], "fill": True}]),
            "carry_2": ((1106, 196, 1210, 310), [
                {"rect": (1145, 220, 1210, 284), "only": ["wood", "dark", "grey", "yellow"], "fill": True}]),
            "throw_1": ((1216, 215, 1330, 310), []),
            "throw_2": ((1330, 215, 1462, 310), [
                {"rect": (1398, 240, 1462, 298), "only": ["wood", "dark", "grey", "yellow"], "fill": True}]),
            # --- fila 2 (bomba)
            "place_bomb_1": ((12, 360, 125, 468), [
                {"rect": (78, 396, 125, 468), "only": ["dark", "yellow", "white", "wood", "grey"], "fill": True}]),
            "place_bomb_2": ((125, 360, 225, 468), [
                {"rect": (165, 404, 225, 468), "only": ["dark", "yellow", "white", "wood", "grey"], "fill": True}]),
            "place_bomb_3": ((225, 360, 330, 468), [
                {"rect": (285, 386, 330, 468), "only": ["dark", "yellow", "white", "wood", "grey"], "fill": True}]),
            # --- fila 3
            "attack_1": ((16, 515, 134, 636), [
                {"rect": (92, 540, 134, 600), "protect": ["blue", "red"]}]),
            "attack_2": ((134, 515, 225, 636), [
                {"rect": (186, 580, 225, 610), "only": ["yellow", "white"]}]),
            "attack_3": ((225, 515, 318, 636), [
                {"rect": (276, 548, 318, 610), "protect": ["blue", "red"]}]),
            "attack_4": ((318, 515, 392, 636), [
                {"rect": (318, 548, 334, 610), "protect": ["blue", "red"]}]),
            "fire_attack_1": ((398, 515, 560, 636), [
                {"rect": (472, 530, 560, 610), "protect": ["blue", "red"]}]),
            "hurt_1": ((814, 515, 908, 636), []),
            "hurt_2": ((908, 515, 1002, 636), []),
            "hurt_3": ((1002, 515, 1088, 636), []),
            "hurt_4": ((1088, 515, 1160, 636), []),
            "death_1": ((1170, 540, 1287, 632), [
                {"rect": (1170, 614, 1287, 632), "only": ["white"]}]),
            "death_2": ((1287, 540, 1402, 632), [
                {"rect": (1287, 614, 1402, 632), "only": ["white"]}]),
            "death_3": ((1402, 555, 1528, 632), [
                {"rect": (1402, 614, 1528, 632), "only": ["white"]}]),
            # --- fila 4
            "victory_1": ((22, 680, 112, 818), []),
            "victory_2": ((112, 680, 214, 818), []),
            "victory_3": ((214, 680, 312, 818), []),
            "victory_4": ((312, 680, 412, 818), []),
        },
        # Nombres estándar del proyecto (docs/GAMEPLAY.md). Equivalencias con la
        # nomenclatura blue_penguin_*: ladder -> climb, pickup -> lift.
        "animations": {
            "idle": {"frames": ["idle_1", "idle_2", "idle_1", "idle_2"], "fps": 3, "loop": True},
            "walk": {"frames": ["walk_1", "walk_2", "walk_3", "walk_2"], "fps": 10, "loop": True},
            "run": {"frames": ["run_1", "run_2", "run_3", "run_4"], "fps": 12, "loop": True},
            "jump": {"frames": ["jump_1", "jump_2", "jump_3"], "fps": 10, "loop": False},
            "fall": {"frames": ["fall_1"], "fps": 1, "loop": False},
            "land": {"frames": ["land_1", "land_2", "land_3"], "fps": 24, "loop": False},
            "crouch": {"frames": ["crouch_1", "crouch_2"], "fps": 12, "loop": False},
            "slide": {"frames": ["slide_1", "slide_2", "slide_3"], "fps": 8, "loop": False},
            "climb": {"frames": ["climb_1", "climb_2", "climb_3", "climb_4"], "fps": 8, "loop": True},
            "lift": {"frames": ["lift_1", "lift_2"], "fps": 8, "loop": False},
            "carry": {"frames": ["carry_1", "carry_2"], "fps": 6, "loop": True},
            "throw": {"frames": ["throw_1", "throw_2"], "fps": 10, "loop": False},
            "place_bomb": {"frames": ["place_bomb_1", "place_bomb_2", "place_bomb_3"], "fps": 10, "loop": False},
            "hurt": {"frames": ["hurt_1", "hurt_2", "hurt_3", "hurt_4"], "fps": 10, "loop": True},
            "death": {"frames": ["death_1", "death_2", "death_3"], "fps": 5, "loop": False},
            "victory": {"frames": ["victory_1", "victory_2", "victory_3", "victory_4"], "fps": 6, "loop": True},
            "attack": {"frames": ["attack_1", "attack_2", "attack_3", "attack_4"], "fps": 12, "loop": False},
            "fire_attack": {"frames": ["fire_attack_1"], "fps": 1, "loop": False},
        },
        # Secciones de la hoja que no se extraen (motivo documentado).
        "skipped": {
            "swim": "el agua y las burbujas están fundidas con el personaje; hace falta arte sin fondo",
            "fire_attack_2": "las llamas envuelven al personaje",
            "bomb_wait / explosion_reaction": "poses de apoyo; no las usa ningún estado todavía",
            "specials": "auras de poder fundidas con el personaje (fase de poderes)",
        },
    },
}


# ---------------------------------------------------------------- procesamiento
def isolate(cell: np.ndarray, erase_ops: list, origin: tuple) -> np.ndarray:
    """Devuelve la máscara booleana del personaje dentro de la celda.
    Si un borrado tiene "fill", rellena (en `cell`, por inpainting) el hueco que el
    objeto borrado deja dentro de la silueta del personaje."""
    rgb = cell[..., :3]
    original = cell[..., 3] > ALPHA_THRESHOLD
    mask = original.copy()
    fill_zone = np.zeros_like(mask)
    classes = color_classes(rgb)
    ox, oy = origin
    for op in erase_ops:
        x0, y0, x1, y1 = op["rect"]
        region = np.zeros_like(mask)
        region[max(0, y0 - oy):max(0, y1 - oy), max(0, x0 - ox):max(0, x1 - ox)] = True
        if "only" in op:
            target = np.zeros_like(mask)
            for c in op["only"]:
                target |= classes[c]
        else:
            target = np.ones_like(mask)
            for c in op.get("protect", []):
                target &= ~classes[c]
        erased = region & target & mask
        mask &= ~erased
        if op.get("fill"):
            fill_zone |= erased
    # Abre un poco para cortar restos finos (bordes de escalera, chispas) y conserva el
    # componente principal más las piezas contenidas en su caja (bufanda, patas).
    opened = cv2.morphologyEx(mask.astype(np.uint8), cv2.MORPH_OPEN, np.ones((2, 2), np.uint8)) > 0
    n, lab, stats, _ = cv2.connectedComponentsWithStats(opened.astype(np.uint8), 8)
    if n <= 1:
        return opened
    main = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    x, y, w, h = stats[main, :4]
    keep = lab == main
    for i in range(1, n):
        if i == main or stats[i, cv2.CC_STAT_AREA] < MIN_EXTRA_COMPONENT:
            continue
        cx, cy, cw, ch = stats[i, :4]
        # Solo piezas contenidas en la caja del personaje: descarta restos del vecino.
        if cx >= x - 3 and cx + cw <= x + w + 3 and cy >= y - 3 and cy + ch <= y + h + 3:
            keep |= lab == i
    # Rellena huecos internos pequeños que haya dejado el borrado.
    holes = ~keep
    n2, lab2, st2, _ = cv2.connectedComponentsWithStats(holes.astype(np.uint8), 4)
    for i in range(1, n2):
        hx, hy, hw, hh, area = st2[i]
        touches = hx == 0 or hy == 0 or hx + hw == keep.shape[1] or hy + hh == keep.shape[0]
        if not touches and area < 30:
            keep |= (lab2 == i) & original
    if fill_zone.any():
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (FILL_KERNEL, FILL_KERNEL))
        closed = cv2.morphologyEx(keep.astype(np.uint8), cv2.MORPH_CLOSE, kernel) > 0
        gap = closed & ~keep & fill_zone
        if gap.any():
            # Solo se usan como referencia los píxeles del personaje.
            known = rgb.copy()
            known[~keep] = 0
            paint = (gap | ~keep).astype(np.uint8)
            restored = cv2.inpaint(known, paint, 4, cv2.INPAINT_TELEA)
            rgb[gap] = restored[gap]
            keep |= gap
    return keep


def anchors(cell: np.ndarray, mask: np.ndarray) -> tuple:
    ys, xs = np.nonzero(mask)
    bottom = int(ys.max())
    blue = color_classes(cell[..., :3])["blue"] & mask
    bx = np.nonzero(blue)[1]
    center_x = float(bx.mean()) if bx.size > 50 else float(xs.mean())
    return bottom, center_x


def main(name: str) -> None:
    profile = PROFILES[name]
    sheet = np.array(Image.open(ROOT / profile["sheet"]).convert("RGBA"))
    out = ROOT / "assets/characters" / name
    (out / "source").mkdir(parents=True, exist_ok=True)
    (out / "processed").mkdir(parents=True, exist_ok=True)

    items = {}
    for fname, (box, ops) in profile["frames"].items():
        x0, y0, x1, y1 = box
        cell = sheet[y0:y1, x0:x1].copy()
        Image.fromarray(cell).save(out / "source" / f"{fname}.png")
        mask = isolate(cell, ops, (x0, y0))
        bottom, cx = anchors(cell, mask)
        ys, xs = np.nonzero(mask)
        items[fname] = {"cell": cell, "mask": mask, "bottom": bottom, "cx": cx,
                        "left": cx - xs.min(), "right": xs.max() + 1 - cx, "top": bottom + 1 - ys.min()}

    half = int(np.ceil(max(max(i["left"], i["right"]) for i in items.values()))) + CANVAS_PADDING
    width = half * 2
    height = int(max(i["top"] for i in items.values())) + CANVAS_PADDING
    report = {}
    for fname, it in items.items():
        canvas = np.zeros((height, width, 4), np.uint8)
        rgba = it["cell"].copy()
        rgba[..., 3] = np.where(it["mask"], 255, 0)
        # Desplazamiento entero (sin re-muestreo): pies al borde inferior, centro al medio.
        dx = int(round(half - it["cx"]))
        dy = height - 1 - it["bottom"]
        ch, cw = rgba.shape[:2]
        sx0, sy0 = max(0, -dx), max(0, -dy)
        tx0, ty0 = max(0, dx), max(0, dy)
        w = min(cw - sx0, width - tx0)
        h = min(ch - sy0, height - ty0)
        src = rgba[sy0:sy0 + h, sx0:sx0 + w]
        dst = canvas[ty0:ty0 + h, tx0:tx0 + w]
        sel = src[..., 3] > 0
        dst[sel] = src[sel]
        Image.fromarray(canvas).save(out / "processed" / f"{fname}.png")
        ys, xs = np.nonzero(canvas[..., 3])
        report[fname] = {"visible": [int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1)]}

    ref = report[profile["reference"]]["visible"]
    manifest = {
        "character": name,
        "source": profile["sheet"],
        "canvas": [width, height],
        "anchor": "pies en el borde inferior, centro del cuerpo en la mitad horizontal",
        "reference_frame": profile["reference"],
        "reference_height": ref[3] - ref[1],
        "animations": {
            anim: {"frames": [f"processed/{f}.png" for f in data["frames"]],
                   "fps": data["fps"], "loop": data["loop"]}
            for anim, data in profile["animations"].items()
        },
        "frames": report,
        "skipped": profile["skipped"],
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    print(f"{name}: {len(items)} fotogramas, lienzo {width}x{height}, altura de referencia "
          f"{manifest['reference_height']} px")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "blue_penguin")
