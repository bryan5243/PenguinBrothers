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
        # Varias hojas: "full" (todas las acciones) y "moves" (movimiento con más fotogramas).
        # Cada hoja se escala con UN factor propio para que su idle mida lo mismo que el de la
        # hoja base; nunca se escala fotograma a fotograma.
        "sheets": {
            "full": "assets/references/characters/blue_penguin_full_animations.png",
            "moves": "assets/references/characters/blue_penguin_moves_and_bombs.png",
            "carry": "assets/references/characters/blue_penguin_carry_barrel.png",
        },
        # Hojas cuyo fondo NO es transparente (paneles oscuros opacos): se recorta cada celda con
        # rembg y se añade la madera del barril por color (rembg a veces lo descarta).
        "cutout_sheets": ["carry"],
        "base_sheet": "moves",
        # Fotograma de cada hoja que se usa para igualar la escala entre hojas.
        "sheet_reference": {"full": "idle_1", "moves": "mv_idle_1", "carry": "cb_ref"},
        "reference": "mv_idle_1",
        "frames": {
            # --- hoja "carry" (blue_penguin_carry_barrel.png): llevar un barril (va en el dibujo)
            "cb_ref": ((820, 45, 935, 185), [], "carry"),
            "cb_lift_1": ((155, 45, 290, 185), [], "carry"),
            "cb_lift_2": ((308, 45, 460, 185), [], "carry"),
            "cb_lift_3": ((466, 45, 625, 185), [], "carry"),
            "cb_lift_4": ((636, 45, 780, 185), [], "carry"),
            "cb_idle_1": ((820, 45, 935, 185), [], "carry"),
            "cb_idle_2": ((982, 45, 1102, 185), [], "carry"),
            "cb_idle_3": ((1122, 45, 1243, 185), [], "carry"),
            "cb_idle_4": ((1252, 45, 1378, 185), [], "carry"),
            "cb_idle_5": ((1392, 45, 1500, 185), [], "carry"),
            "cb_walk_1": ((32, 238, 168, 378), [], "carry"),
            "cb_walk_2": ((172, 238, 302, 378), [], "carry"),
            "cb_walk_3": ((303, 238, 432, 378), [], "carry"),
            "cb_walk_4": ((437, 238, 557, 378), [], "carry"),
            "cb_walk_5": ((550, 238, 667, 378), [], "carry"),
            "cb_walk_6": ((663, 238, 787, 378), [], "carry"),
            "cb_run_1": ((838, 238, 977, 378), [], "carry"),
            "cb_run_2": ((985, 238, 1112, 378), [], "carry"),
            "cb_run_3": ((1116, 238, 1242, 378), [], "carry"),
            "cb_run_4": ((1246, 238, 1376, 378), [], "carry"),
            "cb_run_5": ((1376, 238, 1502, 378), [], "carry"),
            "cb_jump_1": ((38, 425, 162, 575), [], "carry"),
            "cb_jump_2": ((172, 425, 302, 575), [], "carry"),
            "cb_jump_3": ((302, 425, 437, 575), [], "carry"),
            "cb_jump_4": ((442, 425, 572, 575), [], "carry"),
            "cb_jump_5": ((595, 425, 732, 575), [], "carry"),
            "cb_crouch_1": ((818, 455, 972, 585), [], "carry"),
            "cb_crouch_2": ((988, 455, 1142, 585), [], "carry"),
            "cb_crouch_3": ((1152, 455, 1312, 585), [], "carry"),
            "cb_crouch_4": ((1328, 455, 1492, 585), [], "carry"),
            "cb_throw_1": ((22, 622, 145, 760), [], "carry"),
            "cb_throw_2": ((152, 622, 272, 760), [], "carry"),
            "cb_throw_3": ((278, 622, 418, 760), [], "carry"),
            "cb_throw_4": ((428, 622, 562, 760), [], "carry"),
            "cb_drop_1": ((946, 622, 1082, 760), [], "carry"),
            "cb_drop_2": ((1284, 622, 1398, 760), [], "carry"),
            # --- hoja "moves" (blue_penguin_moves_and_bombs.png)
            "mv_idle_1": ((15, 38, 97, 148), [], "moves"),
            "mv_idle_2": ((114, 38, 195, 148), [], "moves"),
            "mv_idle_3": ((211, 40, 297, 150), [], "moves"),
            "mv_idle_4": ((311, 40, 400, 152), [], "moves"),
            "mv_walk_1": ((14, 184, 97, 286), [], "moves"),
            "mv_walk_2": ((123, 184, 208, 286), [], "moves"),
            "mv_walk_3": ((230, 184, 314, 286), [], "moves"),
            "mv_walk_4": ((336, 184, 419, 286), [], "moves"),
            "mv_walk_5": ((434, 183, 517, 287), [], "moves"),
            "mv_walk_6": ((532, 185, 614, 287), [], "moves"),
            "mv_walk_7": ((625, 181, 708, 286), [], "moves"),
            "mv_walk_8": ((713, 181, 809, 286), [], "moves"),
            "mv_walk_9": ((802, 180, 899, 283), [], "moves"),
            "mv_land_1": ((27, 480, 135, 575), [], "moves"),
            "mv_land_2": ((149, 477, 250, 576), [], "moves"),
            "mv_land_3": ((260, 476, 363, 578), [], "moves"),
            "mv_jump_1": ((433, 436, 546, 573), [], "moves"),
            "mv_jump_2": ((553, 433, 658, 560), [], "moves"),
            "mv_fall_1": ((668, 460, 776, 577), [], "moves"),
            "mv_fall_2": ((783, 472, 877, 577), [], "moves"),
            "mv_slide_1": ((880, 481, 1021, 576), [
                {"rect": (880, 540, 925, 576), "only": ["white", "grey"]}], "moves"),
            "mv_slide_2": ((1015, 496, 1179, 576), [
                {"rect": (1015, 520, 1075, 576), "only": ["white", "grey"]}], "moves"),
            "mv_slide_3": ((1178, 496, 1328, 576), [
                {"rect": (1178, 520, 1232, 576), "only": ["white", "grey"]}], "moves"),
            "mv_slide_4": ((1328, 493, 1493, 576), [
                {"rect": (1328, 520, 1385, 576), "only": ["white", "grey"]}], "moves"),
            "mv_crouch_1": ((16, 615, 116, 703), [], "moves"),
            "mv_crouch_2": ((131, 615, 232, 705), [], "moves"),
            "mv_crouch_3": ((256, 613, 358, 705), [], "moves"),
            # --- hoja "full" (blue_penguin_full_animations.png)
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
            "idle": {"frames": ["mv_idle_1", "mv_idle_2", "mv_idle_3", "mv_idle_4", "mv_idle_3", "mv_idle_2"],
                     "fps": 6, "loop": True},
            "walk": {"frames": ["mv_walk_%d" % i for i in range(1, 10)], "fps": 14, "loop": True},
            "run": {"frames": ["run_1", "run_2", "run_3", "run_4"], "fps": 12, "loop": True},
            "jump": {"frames": ["mv_jump_1", "mv_jump_2"], "fps": 8, "loop": False},
            "fall": {"frames": ["mv_fall_1", "mv_fall_2"], "fps": 6, "loop": False},
            "land": {"frames": ["mv_land_1", "mv_land_2"], "fps": 20, "loop": False},
            "crouch": {"frames": ["mv_crouch_1", "mv_crouch_2", "mv_crouch_3"], "fps": 14, "loop": False},
            "slide": {"frames": ["mv_slide_1", "mv_slide_2", "mv_slide_3", "mv_slide_4"], "fps": 10, "loop": False},
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
            # Llevando un barril (el barril va dibujado; el objeto se oculta mientras se lleva).
            "carry_barrel_lift": {"frames": ["cb_lift_2", "cb_lift_3", "cb_lift_4"], "fps": 10, "loop": False},
            "carry_barrel_idle": {"frames": ["cb_idle_1", "cb_idle_2", "cb_idle_3", "cb_idle_4", "cb_idle_5"], "fps": 6, "loop": True},
            "carry_barrel_walk": {"frames": ["cb_walk_%d" % i for i in range(1, 7)], "fps": 10, "loop": True},
            "carry_barrel_run": {"frames": ["cb_run_1", "cb_run_2", "cb_run_3", "cb_run_5"], "fps": 12, "loop": True},
            "carry_barrel_jump": {"frames": ["cb_jump_2", "cb_jump_3", "cb_jump_4"], "fps": 8, "loop": False},
            "carry_barrel_land": {"frames": ["cb_jump_5"], "fps": 10, "loop": False},
            "carry_barrel_crouch": {"frames": ["cb_crouch_1", "cb_crouch_2", "cb_crouch_3", "cb_crouch_4"], "fps": 12, "loop": False},
            "carry_barrel_throw": {"frames": ["cb_throw_1", "cb_throw_2", "cb_throw_3", "cb_throw_4"], "fps": 14, "loop": False},
            "carry_barrel_drop": {"frames": ["cb_drop_2"], "fps": 6, "loop": False},
        },
        # Secciones de la hoja que no se extraen (motivo documentado).
        "skipped": {
            "carry_barrel (hoja carry)": "lanzar 5–7 y soltar 3–4 muestran el barril ya separado: el objeto real se dibuja aparte; direcciones/vistas no se usan",
            "swim": "el agua y las burbujas están fundidas con el personaje; hace falta arte sin fondo",
            "fire_attack_2": "las llamas envuelven al personaje",
            "bomb_wait / explosion_reaction": "poses de apoyo; no las usa ningún estado todavía",
            "specials": "auras de poder fundidas con el personaje (fase de poderes)",
            "moves: idle 5-15, walk 10-14, correr": "variantes con polvo o giros; correr está desactivado en el arcade",
        },
    },
}


# ---------------------------------------------------------------- procesamiento
_REMBG_SESSION = None
_CUTOUT_CACHE = {}


def cutout_alpha(rgb: np.ndarray) -> np.ndarray:
    """Alfa para hojas con fondo opaco: rembg (a 2x) + la madera del barril por color, cerrada
    para unir los aros metálicos. Se cachea por contenido (el mismo recorte se pide varias veces)."""
    global _REMBG_SESSION
    key = hash(rgb.tobytes())
    if key in _CUTOUT_CACHE:
        return _CUTOUT_CACHE[key]
    from rembg import new_session, remove
    if _REMBG_SESSION is None:
        _REMBG_SESSION = new_session("u2net")
    img = Image.fromarray(rgb)
    big = img.resize((img.width * 2, img.height * 2), Image.LANCZOS)
    alpha = np.array(remove(big, session=_REMBG_SESSION).resize(img.size, Image.LANCZOS))[..., 3]
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV).astype(int)
    wood = (hsv[..., 0] >= 5) & (hsv[..., 0] <= 25) & (hsv[..., 1] > 110) & (hsv[..., 2] > 80)
    wood = cv2.morphologyEx(wood.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8)) > 0
    # Solo la madera que toca (o casi) lo que rembg ya encontró: evita manchas sueltas del fondo.
    near = cv2.dilate((alpha > 128).astype(np.uint8), np.ones((9, 9), np.uint8)) > 0
    n, lab, stats, _ = cv2.connectedComponentsWithStats(wood.astype(np.uint8), 8)
    add = np.zeros_like(wood)
    for i in range(1, n):
        comp = lab == i
        if stats[i, cv2.CC_STAT_AREA] > 150 and (comp & near).any():
            add |= comp
    out = np.where((alpha > 128) | add, 255, 0).astype(np.uint8)
    _CUTOUT_CACHE[key] = out
    return out


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
    sheet_paths = profile.get("sheets", {"full": profile.get("sheet")})
    sheets = {k: np.array(Image.open(ROOT / v).convert("RGBA")) for k, v in sheet_paths.items()}
    default_sheet = "full" if "full" in sheets else next(iter(sheets))
    out = ROOT / "assets/characters" / name
    (out / "source").mkdir(parents=True, exist_ok=True)
    (out / "processed").mkdir(parents=True, exist_ok=True)

    cutout_sheets = profile.get("cutout_sheets", [])

    def cut(entry):
        box, ops = entry[0], entry[1]
        sheet_key = entry[2] if len(entry) > 2 else default_sheet
        x0, y0, x1, y1 = box
        cell = sheets[sheet_key][y0:y1, x0:x1].copy()
        if sheet_key in cutout_sheets:
            cell[..., 3] = cutout_alpha(cell[..., :3])
        return sheet_key, cell, isolate(cell, ops, (x0, y0))

    # Un factor de escala por hoja (igualar el idle de referencia de cada hoja al de la base).
    scales = {k: 1.0 for k in sheets}
    base = profile.get("base_sheet", default_sheet)
    refs = profile.get("sheet_reference", {})
    if base in refs:
        _, _, base_mask = cut(profile["frames"][refs[base]])
        base_h = np.ptp(np.nonzero(base_mask)[0]) + 1
        for key, ref_name in refs.items():
            _, _, m = cut(profile["frames"][ref_name])
            scales[key] = base_h / (np.ptp(np.nonzero(m)[0]) + 1)

    items = {}
    for fname, entry in profile["frames"].items():
        sheet_key, cell, mask = cut(entry)
        Image.fromarray(cell).save(out / "source" / f"{fname}.png")
        s = scales[sheet_key]
        if abs(s - 1.0) > 1e-3:
            rgba = cell.copy()
            rgba[..., 3] = np.where(mask, 255, 0)
            size = (max(1, round(rgba.shape[1] * s)), max(1, round(rgba.shape[0] * s)))
            rgba = np.array(Image.fromarray(rgba).resize(size, Image.LANCZOS))
            mask = rgba[..., 3] > 127
            cell = rgba
        bottom, cx = anchors(cell, mask)
        ys, xs = np.nonzero(mask)
        items[fname] = {"cell": cell, "mask": mask, "bottom": bottom, "cx": cx, "sheet": sheet_key,
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
        report[fname] = {"sheet": it["sheet"],
                         "visible": [int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1)]}

    ref = report[profile["reference"]]["visible"]
    manifest = {
        "character": name,
        "source": sheet_paths,
        "sheet_scales": {k: round(v, 4) for k, v in scales.items()},
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
