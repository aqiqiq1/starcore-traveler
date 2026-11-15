"""Shared layout/palette for the formal bridge-stone source.

Atlas rects are the single source for both generate_atlas.py and build_block.py.
1 source pixel = 1 world unit.  All modules are native pixels; the builder never
scales a module.
"""

PALETTE = {
    "OUT":    (60, 52, 57, 255),
    "DEEP":   (76, 67, 73, 255),
    "DARK":   (94, 82, 87, 255),
    "SHADE":  (112, 99, 101, 255),
    "MIDD":   (124, 110, 109, 255),
    "MID":    (136, 122, 120, 255),
    "MID2":   (147, 132, 127, 255),
    "LIGHT":  (159, 146, 138, 255),
    "LIGHT2": (172, 160, 151, 255),
    "TOP":    (186, 175, 163, 255),
    "TOPHI":  (198, 187, 174, 255),
    "BEAR":   (106, 94, 97, 255),
    "BEAR2":  (94, 84, 88, 255),
    "BEAR3":  (84, 76, 81, 255),
}

# name: [x, y, w, h]
MODULES = {
    # deck top plane (no joint owned; builder adds slab joints)
    "deck_top_96_a": [0,   0, 96, 3],
    "deck_top_96_b": [100, 0, 96, 3],
    "deck_top_64_a": [200, 0, 64, 3],
    "deck_top_64_b": [268, 0, 64, 3],

    # road front face, 7 px
    "deck_face_96_a": [0,   8, 96, 7],
    "deck_face_96_b": [100, 8, 96, 7],
    "deck_face_64_a": [200, 8, 64, 7],
    "deck_face_64_b": [268, 8, 64, 7],

    # thin/deep beam upper face, 8 px
    "beam_face_96_a": [0,   20, 96, 8],
    "beam_face_96_b": [100, 20, 96, 8],
    # dark lower beam body, 9 px
    "beam_lower_96_a": [0,   32, 96, 9],
    "beam_lower_96_b": [100, 32, 96, 9],

    # narrow under-eave / soffit shadow
    "soffit_96x2_a": [0,   44, 96, 2],
    "soffit_96x2_b": [100, 44, 96, 2],
    "soffit_96x3_a": [200, 44, 96, 3],
    "soffit_96x3_b": [300, 44, 96, 3],

    # bearing ashlar, 80x20, left + bottom mortar owned
    "block_mid2_a":  [0,   52, 80, 20],
    "block_mid2_b":  [84,  52, 80, 20],
    "block_mid_a":   [168, 52, 80, 20],
    "block_mid_b":   [252, 52, 80, 20],
    "block_midd_a":  [336, 52, 80, 20],
    "block_midd_b":  [420, 52, 80, 20],

    "block_bear_a":  [0,   76, 80, 20],
    "block_bear_b":  [84,  76, 80, 20],
    "block_bear2_a": [168, 76, 80, 20],
    "block_bear2_b": [252, 76, 80, 20],
    "block_light_a": [336, 76, 80, 20],
    "block_lit_a":   [420, 76, 80, 20],

    "block_chip_a":  [0,   100, 80, 20],
    "block_crack_a": [84,  100, 80, 20],
    "block_light_b": [168, 100, 80, 20],
    "block_dark_a":  [252, 100, 80, 20],

    # base course, 10 px, flat contact row
    "base_128_a": [0,   124, 128, 10],
    "base_128_b": [132, 124, 128, 10],
    "base_96_a":  [264, 124, 96, 10],
    "base_96_b":  [364, 124, 96, 10],
    "base_64_a":  [464, 124, 64, 10],
    "base_64_b":  [532, 124, 64, 10],

    # pier, 8 px modules; builder tiles them horizontally
    "pier_cap_8_a":  [0,  140, 8, 3],
    "pier_cap_8_b":  [12, 140, 8, 3],
    "pier_drum_8_a": [0,  148, 8, 12],
    "pier_drum_8_b": [12, 148, 8, 12],
    "pier_base_8_a": [0,  164, 8, 6],
    "pier_base_8_b": [12, 164, 8, 6],

    # broken core tiles (opaque; builder masks the outer silhouette)
    "break_core_right_24x40_a": [0,   176, 24, 40],
    "break_core_right_24x40_b": [28,  176, 24, 40],
    "break_core_right_24x40_c": [56,  176, 24, 40],
    "break_core_left_24x40_a":  [84,  176, 24, 40],
    "break_core_left_24x40_b":  [112, 176, 24, 40],
    "break_core_left_24x40_c":  [140, 176, 24, 40],

    # decals (transparent)
    "damp_24x14":   [0,  224, 24, 14],
    "crack_4x20":   [28, 224, 4, 20],
    "chip_8x6":     [36, 224, 8, 6],
    "weather_4x48": [48, 224, 4, 48],
}

ATLAS_SIZE = (640, 320)

BLOCK_FAMILIES = {
    "mid2":  ["block_mid2_a", "block_mid2_b"],
    "mid":   ["block_mid_a", "block_mid_b"],
    "midd":  ["block_midd_a", "block_midd_b"],
    "bear":  ["block_bear_a", "block_bear_b"],
    "bear2": ["block_bear2_a", "block_bear2_b"],
    "light": ["block_light_a", "block_light_b"],
    "lit":   ["block_lit_a"],
    "chip":  ["block_chip_a"],
    "crack": ["block_crack_a"],
    "dark":  ["block_dark_a"],
}

DECK_TOP = ["deck_top_96_a", "deck_top_96_b", "deck_top_64_a", "deck_top_64_b"]
DECK_FACE = ["deck_face_96_a", "deck_face_96_b", "deck_face_64_a", "deck_face_64_b"]
BEAM_FACE = ["beam_face_96_a", "beam_face_96_b"]
BEAM_LOWER = ["beam_lower_96_a", "beam_lower_96_b"]
SOFFIT2 = ["soffit_96x2_a", "soffit_96x2_b"]
SOFFIT3 = ["soffit_96x3_a", "soffit_96x3_b"]
BASE_PIECES = ["base_128_a", "base_96_a", "base_64_a", "base_128_b", "base_96_b", "base_64_b"]
PIER_CAP = ["pier_cap_8_a", "pier_cap_8_b"]
PIER_DRUM = ["pier_drum_8_a", "pier_drum_8_b"]
PIER_BASE = ["pier_base_8_a", "pier_base_8_b"]
