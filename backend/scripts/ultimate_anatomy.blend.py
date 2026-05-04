"""
ultimate_anatomy.blend.py
=========================
解剖学的に正確な形状・位置・向きの楕円体で筋肉を表現するBlender Cyclesレンダラー。

改善点 (vs 旧 muscle_heatmap.blend.py):
  - 各筋肉を解剖学的に正確なアスペクト比の楕円体で表現（UV球体→楕円体）
  - 正確な解剖学的位置・回転を適用
  - 体幹構造要素（頭部・首・胴体・骨盤・四肢ベース）を追加
  - 1024x2048 Cycles + OIDN デノイザー
"""

import bpy
import math
import json
import sys
import os
from mathutils import Vector

# ── JSON パラメータ読み込み ───────────────────────────────────────────────
_argv = sys.argv
_json_path = _argv[_argv.index("--") + 1] if "--" in _argv else None

INPUT = {}
if _json_path:
    with open(_json_path, encoding="utf-8") as f:
        INPUT = json.load(f)

_rp = INPUT.get("render_params", {})
_m  = lambda k, d: _rp.get("material", {}).get(k, d)
_l  = lambda k, d: _rp.get("lighting", {}).get(k, d)

OUTPUT_PATH  = INPUT.get("output_path", "/tmp/satoshi_ultimate_anatomy.png")
RESOLUTION_X = INPUT.get("resolution_x", 1024)
RESOLUTION_Y = INPUT.get("resolution_y", 2048)
INTENSITIES  = INPUT.get("intensities", {
    "chest": 0.99, "back": 0.82, "shoulders": 0.75,
    "biceps": 0.42, "triceps": 0.58, "quads": 1.00,
    "hamstrings": 0.62, "glutes": 0.88, "calves": 0.48,
    "core": 0.72, "structure": 0.12,
})

P = {
    "bump_strength":  max(0.20, _m("bump_strength",  0.55)),
    "fiber_scale":    _m("fiber_scale",    6.0),
    "fiber_distort":  _m("fiber_distortion", 2.2),
    "em_threshold":   _m("emission_threshold", 0.25),
    "em_strength":    max(6.0, _m("emission_strength", 9.0)),
    "roughness":      _m("roughness",   0.28),
    "specular":       _m("specular",    0.60),
    "sss":            _m("sss_base",    0.20),
    "sss_mult":       _m("sss_multiplier", 0.18),
    "key_energy":     _l("key_energy",  600.0),
    "key_color":      _l("key_color",   [1.00, 0.88, 0.68]),
    "fill_energy":    _l("fill_energy",  70.0),
    "fill_color":     _l("fill_color",  [0.60, 0.80, 1.00]),
    "rim_R_energy":   _l("rim_R_energy", 2200.0),
    "rim_L_energy":   _l("rim_L_energy", 1400.0),
    "top_energy":     _l("top_energy",   280.0),
}

print("=" * 60)
print("  Ultimate Anatomy Renderer v1.0")
print("  (Anatomically accurate ellipsoid muscles)")
print("=" * 60)
print(f"  Output: {OUTPUT_PATH}")
print(f"  Res: {RESOLUTION_X}×{RESOLUTION_Y}")

# ── 筋肉定義テーブル ─────────────────────────────────────────────────────
# (name, location(x,y,z), scale(x,y,z), rotation_euler(rx,ry,rz), group, fiber_axis)
# 座標系: X=左右(+が右体側), Y=前後(+が前), Z=上下(+が上)
# 身長約1.75m, A-pose（腕を約30°外側に張り出した姿勢）

MUSCLE_TABLE = [
    # ── 体幹構造 (Structure: dark navy filler) ─────────────────────────
    # 頭部
    ("head",         ( 0.000,  0.000,  1.660), (0.098, 0.095, 0.113), ( 0.00,  0.00,  0.00), "structure", "Z"),
    # 首
    ("neck",         ( 0.000,  0.002,  1.515), (0.038, 0.036, 0.062), ( 0.00,  0.00,  0.00), "structure", "Z"),
    # 胴体（肋骨/上胴）
    ("torso_upper",  ( 0.000,  0.005,  1.200), (0.148, 0.108, 0.225), ( 0.00,  0.00,  0.00), "structure", "Z"),
    # 胴体（腰部/下胴）
    ("torso_lower",  ( 0.000, -0.005,  1.000), (0.118, 0.090, 0.090), ( 0.00,  0.00,  0.00), "structure", "Z"),
    # 骨盤
    ("pelvis",       ( 0.000, -0.015,  0.930), (0.138, 0.102, 0.050), ( 0.00,  0.00,  0.00), "structure", "Z"),
    # 脚のベース構造（大腿）
    ("thigh_L",      (-0.100,  0.002,  0.710), (0.058, 0.058, 0.235), ( 0.00,  0.05,  0.00), "structure", "Z"),
    ("thigh_R",      ( 0.100,  0.002,  0.710), (0.058, 0.058, 0.235), ( 0.00, -0.05,  0.00), "structure", "Z"),
    # 下腿（脛）
    ("shin_L",       (-0.098,  0.012,  0.328), (0.038, 0.038, 0.182), ( 0.00,  0.00,  0.00), "structure", "Z"),
    ("shin_R",       ( 0.098,  0.012,  0.328), (0.038, 0.038, 0.182), ( 0.00,  0.00,  0.00), "structure", "Z"),

    # ── 胸部 Chest (pectoralis major) ──────────────────────────────────
    # 扁平な横長楕円体、やや前傾・外側傾
    ("pec_L",        (-0.132,  0.105,  1.225), (0.172, 0.072, 0.128), ( 0.15,  0.00,  0.22), "chest",      "Y"),
    ("pec_R",        ( 0.132,  0.105,  1.225), (0.172, 0.072, 0.128), ( 0.15,  0.00, -0.22), "chest",      "Y"),

    # ── 背部 Back ───────────────────────────────────────────────────────
    # 広背筋 Latissimus dorsi: 縦長楕円体、側面に広がる
    ("lat_L",        (-0.222, -0.068,  1.115), (0.128, 0.078, 0.248), ( 0.00,  0.00,  0.24), "back",       "Z"),
    ("lat_R",        ( 0.222, -0.068,  1.115), (0.128, 0.078, 0.248), ( 0.00,  0.00, -0.24), "back",       "Z"),
    # 僧帽筋 Trapezius upper: 幅広く首元に
    ("trap_upper",   ( 0.000, -0.022,  1.432), (0.245, 0.062, 0.082), ( 0.00,  0.00,  0.00), "back",       "X"),
    # 僧帽筋 Trapezius lower: 中背部
    ("trap_lower",   ( 0.000, -0.045,  1.315), (0.198, 0.062, 0.092), ( 0.14,  0.00,  0.00), "back",       "X"),

    # ── 肩部 Shoulders (deltoids) ───────────────────────────────────────
    # 前部三角筋
    ("delt_ant_L",   (-0.268,  0.058,  1.378), (0.080, 0.080, 0.108), ( 0.00,  0.50,  0.00), "shoulders",  "Z"),
    # 中部三角筋 (最も外側・上腕を横に張る)
    ("delt_mid_L",   (-0.305,  0.002,  1.372), (0.076, 0.072, 0.108), ( 0.00,  0.50,  0.28), "shoulders",  "Z"),
    # 後部三角筋
    ("delt_pos_L",   (-0.275, -0.068,  1.358), (0.076, 0.070, 0.092), ( 0.00,  0.50,  0.00), "shoulders",  "Z"),
    # (右側はX軸ミラー + ryを反転)
    ("delt_ant_R",   ( 0.268,  0.058,  1.378), (0.080, 0.080, 0.108), ( 0.00, -0.50,  0.00), "shoulders",  "Z"),
    ("delt_mid_R",   ( 0.305,  0.002,  1.372), (0.076, 0.072, 0.108), ( 0.00, -0.50, -0.28), "shoulders",  "Z"),
    ("delt_pos_R",   ( 0.275, -0.068,  1.358), (0.076, 0.070, 0.092), ( 0.00, -0.50,  0.00), "shoulders",  "Z"),

    # ── 上腕 Upper Arms ─────────────────────────────────────────────────
    # 上腕二頭筋 Biceps: 前面・縦長楕円体、腕の傾きに合わせてry回転
    ("bicep_L",      (-0.388,  0.064,  1.202), (0.060, 0.054, 0.148), ( 0.00,  0.50,  0.00), "biceps",     "Z"),
    ("bicep_R",      ( 0.388,  0.064,  1.202), (0.060, 0.054, 0.148), ( 0.00, -0.50,  0.00), "biceps",     "Z"),
    # 上腕三頭筋 Triceps: 後面・やや太め縦長
    ("tricep_L",     (-0.382, -0.064,  1.198), (0.060, 0.064, 0.170), ( 0.00,  0.50,  0.00), "triceps",    "Z"),
    ("tricep_R",     ( 0.382, -0.064,  1.198), (0.060, 0.064, 0.170), ( 0.00, -0.50,  0.00), "triceps",    "Z"),

    # ── 前腕 Forearms ───────────────────────────────────────────────────
    ("forearm_L",    (-0.455,  0.022,  0.940), (0.045, 0.045, 0.160), ( 0.00,  0.46,  0.00), "biceps",     "Z"),
    ("forearm_R",    ( 0.455,  0.022,  0.940), (0.045, 0.045, 0.160), ( 0.00, -0.46,  0.00), "biceps",     "Z"),

    # ── 腹部・体幹 Core ─────────────────────────────────────────────────
    # 腹直筋 Rectus abdominis
    ("abs",          ( 0.000,  0.088,  1.062), (0.102, 0.056, 0.198), ( 0.00,  0.00,  0.00), "core",       "Z"),
    # 外腹斜筋 External oblique
    ("oblique_L",    (-0.118,  0.068,  1.052), (0.056, 0.048, 0.188), ( 0.00,  0.00,  0.16), "core",       "Z"),
    ("oblique_R",    ( 0.118,  0.068,  1.052), (0.056, 0.048, 0.188), ( 0.00,  0.00, -0.16), "core",       "Z"),

    # ── 大腿四頭筋 Quads ────────────────────────────────────────────────
    # 大腿直筋 Rectus femoris (前面中央, 最も前に突出)
    ("rf_L",         (-0.090,  0.088,  0.698), (0.062, 0.062, 0.272), ( 0.00,  0.05,  0.00), "quads",      "Z"),
    # 外側広筋 Vastus lateralis (外側)
    ("vl_L",         (-0.135,  0.046,  0.688), (0.066, 0.058, 0.258), ( 0.00,  0.05,  0.12), "quads",      "Z"),
    # 内側広筋 Vastus medialis (内側・やや低め, 膝上の涙滴)
    ("vm_L",         (-0.065,  0.046,  0.632), (0.056, 0.054, 0.222), ( 0.00,  0.05, -0.12), "quads",      "Z"),
    # (右側)
    ("rf_R",         ( 0.090,  0.088,  0.698), (0.062, 0.062, 0.272), ( 0.00, -0.05,  0.00), "quads",      "Z"),
    ("vl_R",         ( 0.135,  0.046,  0.688), (0.066, 0.058, 0.258), ( 0.00, -0.05, -0.12), "quads",      "Z"),
    ("vm_R",         ( 0.065,  0.046,  0.632), (0.056, 0.054, 0.222), ( 0.00, -0.05,  0.12), "quads",      "Z"),

    # ── ハムストリングス Hamstrings ──────────────────────────────────────
    ("ham_L",        (-0.098, -0.078,  0.692), (0.066, 0.065, 0.262), ( 0.00,  0.05,  0.00), "hamstrings", "Z"),
    ("ham_R",        ( 0.098, -0.078,  0.692), (0.066, 0.065, 0.262), ( 0.00, -0.05,  0.00), "hamstrings", "Z"),

    # ── 臀部 Glutes ─────────────────────────────────────────────────────
    # 大臀筋 Gluteus maximus: 大きな丸い形
    ("glute_L",      (-0.148, -0.095,  0.898), (0.130, 0.115, 0.148), ( 0.00,  0.00,  0.00), "glutes",     "Z"),
    ("glute_R",      ( 0.148, -0.095,  0.898), (0.130, 0.115, 0.148), ( 0.00,  0.00,  0.00), "glutes",     "Z"),
    # 中臀筋 Gluteus medius: 臀部上部
    ("glute_med_L",  (-0.168, -0.058,  0.972), (0.082, 0.072, 0.082), ( 0.00,  0.00,  0.00), "glutes",     "Z"),
    ("glute_med_R",  ( 0.168, -0.058,  0.972), (0.082, 0.072, 0.082), ( 0.00,  0.00,  0.00), "glutes",     "Z"),

    # ── 下腿 Calves ─────────────────────────────────────────────────────
    # 腓腹筋 Gastrocnemius
    ("calf_L",       (-0.098, -0.062,  0.318), (0.054, 0.068, 0.180), ( 0.00,  0.00,  0.00), "calves",     "Z"),
    ("calf_R",       ( 0.098, -0.062,  0.318), (0.054, 0.068, 0.180), ( 0.00,  0.00,  0.00), "calves",     "Z"),
]


# ── マグマカラーマップ ────────────────────────────────────────────────────
def intensity_to_rgb(t: float):
    """強度 0→1 をマグマカラーマップ (紺→赤→橙→白) に変換"""
    t = max(0.0, min(1.0, t))
    if t < 0.25:
        r = 0.0; g = 0.0; b = 0.30 + t * 2.40
    elif t < 0.50:
        u = (t - 0.25) / 0.25
        r = u * 0.80; g = 0.0; b = 0.90 - u * 0.90
    elif t < 0.75:
        u = (t - 0.50) / 0.25
        r = 0.80 + u * 0.20; g = u * 0.55; b = 0.0
    else:
        u = (t - 0.75) / 0.25
        r = 1.00; g = 0.55 + u * 0.45; b = u * 0.70
    return (r, g, b)


# ── シーンリセット ───────────────────────────────────────────────────────
def reset_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for block in list(bpy.data.meshes):   bpy.data.meshes.remove(block)
    for block in list(bpy.data.materials): bpy.data.materials.remove(block)
    for block in list(bpy.data.lights):   bpy.data.lights.remove(block)
    for block in list(bpy.data.cameras):  bpy.data.cameras.remove(block)
    print(">>> シーンリセット完了")


# ── Cycles マテリアル作成 ─────────────────────────────────────────────────
def make_cycles_material(name: str, r: float, g: float, b: float,
                          intensity: float, fiber_axis: str):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    N = mat.node_tree.nodes
    L = mat.node_tree.links
    N.clear()

    out  = N.new('ShaderNodeOutputMaterial')
    bsdf = N.new('ShaderNodeBsdfPrincipled')
    tc   = N.new('ShaderNodeTexCoord')

    # ── 筋線維テクスチャ → Base Color に直接注入 ─────────────────────
    # 筋線維方向に応じてバンド方向を決定
    fiber_dir = 'X' if fiber_axis in ('Z', 'Y') else 'Z'

    wav = N.new('ShaderNodeTexWave')
    wav.wave_type       = 'BANDS'
    wav.bands_direction = fiber_dir
    wav.inputs['Scale'].default_value      = P["fiber_scale"]
    wav.inputs['Distortion'].default_value = P["fiber_distort"]
    wav.inputs['Detail'].default_value     = 6.0
    wav.inputs['Detail Scale'].default_value = 2.0

    # ノイズ混合で有機的なバリエーション
    noise = N.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value     = 4.5
    noise.inputs['Detail'].default_value    = 5.0
    noise.inputs['Roughness'].default_value = 0.65

    mix_fib = N.new('ShaderNodeMixRGB')
    mix_fib.blend_type = 'MIX'
    mix_fib.inputs[0].default_value = 0.22  # 22% ノイズ混合

    # カラーランプ (LINEAR で鮮明なストライプ)
    ramp = N.new('ShaderNodeValToRGB')
    ramp.color_ramp.interpolation = 'LINEAR'
    dark = 0.30; light = 1.72
    ramp.color_ramp.elements[0].position = 0.15
    ramp.color_ramp.elements[0].color = (
        max(0.001, r * dark), max(0.001, g * dark), max(0.001, b * (dark + 0.04)), 1.0)
    ramp.color_ramp.elements[1].position = 0.85
    ramp.color_ramp.elements[1].color = (
        min(1.0, r * light), min(1.0, g * (light - 0.18)), min(1.0, b * (light - 0.32)), 1.0)

    L.new(tc.outputs['Object'], wav.inputs['Vector'])
    L.new(tc.outputs['Object'], noise.inputs['Vector'])
    L.new(wav.outputs['Color'],   mix_fib.inputs[1])
    L.new(noise.outputs['Color'], mix_fib.inputs[2])
    L.new(mix_fib.outputs['Color'], ramp.inputs['Fac'])
    L.new(ramp.outputs['Color'],  bsdf.inputs['Base Color'])

    # ── BSDF パラメータ ───────────────────────────────────────────────
    def _try(inputs, key, val):
        if key in inputs:
            try: inputs[key].default_value = val
            except: pass

    # SSS (物理的な半透明肌感)
    _try(bsdf.inputs, 'Subsurface Weight', P["sss"])
    if 'Subsurface Radius' in bsdf.inputs:
        bsdf.inputs['Subsurface Radius'].default_value = (0.060, 0.022, 0.008)
    if 'Subsurface Scale' in bsdf.inputs:
        bsdf.inputs['Subsurface Scale'].default_value = 0.05
    _try(bsdf.inputs, 'Subsurface IOR', 1.40)

    # Anisotropic (筋線維の異方性光沢)
    _try(bsdf.inputs, 'Anisotropic', 0.45)
    _try(bsdf.inputs, 'Anisotropic Rotation', 0.0)

    _try(bsdf.inputs, 'Roughness', P["roughness"])
    _try(bsdf.inputs, 'Specular IOR Level', P["specular"])
    _try(bsdf.inputs, 'IOR', 1.45)

    # Emission: 高強度筋肉のマグマ発光
    if intensity >= P["em_threshold"]:
        em_factor = (intensity - P["em_threshold"]) / (1.0 - P["em_threshold"])
        em_s = P["em_strength"] * em_factor * 0.55
        _try(bsdf.inputs, 'Emission Strength', em_s)
        if 'Emission Color' in bsdf.inputs:
            bsdf.inputs['Emission Color'].default_value = (
                min(1.0, r * 1.2), min(1.0, g * 0.8), min(1.0, b * 0.5), 1.0)

    # ── バンプマップ (筋線維の立体感) ───────────────────────────────
    bump_wav = N.new('ShaderNodeTexWave')
    bump_wav.wave_type       = 'BANDS'
    bump_wav.bands_direction = fiber_dir
    bump_wav.inputs['Scale'].default_value      = P["fiber_scale"] * 3.2
    bump_wav.inputs['Distortion'].default_value = 0.6
    L.new(tc.outputs['Object'], bump_wav.inputs['Vector'])

    bump = N.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value  = P["bump_strength"]
    bump.inputs['Distance'].default_value  = 0.018
    L.new(bump_wav.outputs['Fac'], bump.inputs['Height'])
    L.new(bump.outputs['Normal'], bsdf.inputs['Normal'])

    L.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    return mat


# ── 筋肉オブジェクト作成 ─────────────────────────────────────────────────
def create_muscle(name, loc, scale, rot_euler, group, fiber_axis):
    intensity = INTENSITIES.get(group, 0.5)
    r, g, b = intensity_to_rgb(intensity)

    # UV sphere (segments=32, rings=16) → 楕円体スケールで正確な筋肉形状
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=32,
        ring_count=16,
        radius=1.0,
        location=loc,
    )
    obj = bpy.context.active_object
    obj.name = name

    # 非一様スケールで楕円体化
    obj.scale        = scale
    obj.rotation_euler = rot_euler

    # トランスフォームをメッシュに焼き込み（法線・テクスチャ座標の正確性のため）
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)

    # スムースシェーディング適用
    bpy.ops.object.shade_smooth()

    # マテリアル割り当て
    mat = make_cycles_material(f"mat_{name}", r, g, b, intensity, fiber_axis)
    obj.data.materials.append(mat)

    return obj


# ── ライティング ─────────────────────────────────────────────────────────
def _add_light(name, ltype, loc, energy, color, spot_deg=None, size=1.0):
    bpy.ops.object.light_add(type=ltype, location=loc)
    light = bpy.context.active_object
    light.name = name
    light.data.energy = energy
    light.data.color  = color[:3]
    if ltype == 'AREA':
        light.data.size = size
    if ltype == 'SPOT' and spot_deg:
        light.data.spot_size = math.radians(spot_deg)
    # ボディ中心を向かせる
    target = Vector((0.0, 0.0, 1.10))
    direction = (target - Vector(loc)).normalized()
    light.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()


def setup_lighting():
    _add_light('key',     'AREA', (-1.50, -2.50,  2.40),
               P["key_energy"],   P["key_color"],   size=1.2)
    _add_light('fill',    'AREA', ( 1.80, -1.20,  1.60),
               P["fill_energy"],  P["fill_color"],  size=1.8)
    _add_light('rim_R',   'SPOT', (-1.20,  3.00,  2.20),
               P["rim_R_energy"], [1.00, 0.94, 0.82], spot_deg=32)
    _add_light('rim_L',   'SPOT', ( 1.40,  2.80,  2.00),
               P["rim_L_energy"], [0.78, 0.90, 1.00], spot_deg=32)
    _add_light('top',     'SPOT', ( 0.00, -0.50,  3.60),
               P["top_energy"],   [0.95, 0.95, 1.00], spot_deg=45)
    _add_light('graze_L', 'AREA', (-3.50,  0.00,  1.20),
               160.0,             [1.00, 0.96, 0.88], size=0.32)
    _add_light('graze_R', 'AREA', ( 3.50,  0.00,  1.20),
               160.0,             [1.00, 0.96, 0.88], size=0.32)
    print(">>> ライティング設定完了 (7点照明)")


# ── カメラ ───────────────────────────────────────────────────────────────
def setup_camera():
    # カメラ位置: ボディ正面やや斜め上から（筋肉全体が見える距離）
    cam_loc = (0.0, -3.60, 0.92)
    bpy.ops.object.camera_add(location=cam_loc)
    cam = bpy.context.active_object
    cam.name = "Camera"

    # ボディ中心（Z=1.05付近）に向ける
    target    = Vector((0.0, 0.0, 1.05))
    direction = (target - Vector(cam_loc)).normalized()
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()

    cam.data.lens        = 85    # ポートレートレンズ（歪み少）
    cam.data.sensor_width = 36
    bpy.context.scene.camera = cam
    print(f">>> カメラ設定完了  lens=85mm  loc={cam_loc}")


# ── Cycles レンダラー ────────────────────────────────────────────────────
def setup_renderer():
    scene = bpy.context.scene

    # エンジン
    scene.render.engine = 'CYCLES'
    scene.render.resolution_x = RESOLUTION_X
    scene.render.resolution_y = RESOLUTION_Y
    scene.render.film_transparent = False

    # 漆黒背景
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get('Background')
    if bg:
        bg.inputs['Color'].default_value    = (0, 0, 0, 1)
        bg.inputs['Strength'].default_value = 0.0

    # Cycles サンプリング
    cyc = scene.cycles
    cyc.samples              = 128
    cyc.use_adaptive_sampling  = True
    cyc.adaptive_min_samples   = 16
    cyc.adaptive_threshold     = 0.02

    # OIDN デノイザー
    cyc.use_denoising = True
    for dn in ('OPENIMAGEDENOISE', 'NLM'):
        try:
            cyc.denoiser = dn
            print(f">>> デノイザー: {dn}")
            break
        except Exception:
            continue

    # GPU → CPU フォールバック
    gpu_ok = False
    try:
        prefs = bpy.context.preferences.addons['cycles'].preferences
        for dev_type in ('OPTIX', 'CUDA', 'HIP', 'METAL'):
            try:
                prefs.compute_device_type = dev_type
                prefs.get_devices()
                scene.cycles.device = 'GPU'
                gpu_ok = True
                print(f">>> GPU使用: {dev_type}")
                break
            except Exception:
                continue
    except Exception:
        pass
    if not gpu_ok:
        scene.cycles.device = 'CPU'
        print(">>> CPU使用")

    print(f">>> Cycles設定完了  samples=128  res={RESOLUTION_X}×{RESOLUTION_Y}")


# ── メイン ───────────────────────────────────────────────────────────────
def main():
    reset_scene()

    print(f"\n>>> 筋肉オブジェクト作成中 ({len(MUSCLE_TABLE)}個)...")
    for i, (name, loc, scale, rot, group, fiber_axis) in enumerate(MUSCLE_TABLE):
        create_muscle(name, loc, scale, rot, group, fiber_axis)
        if (i + 1) % 10 == 0:
            print(f"    {i + 1}/{len(MUSCLE_TABLE)} 完了")
    print(f">>> 全筋肉オブジェクト作成完了")

    setup_lighting()
    setup_camera()
    setup_renderer()

    # 出力設定
    scene = bpy.context.scene
    scene.render.filepath = OUTPUT_PATH
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode  = 'RGB'
    scene.render.image_settings.color_depth = '8'

    print(f"\n>>> レンダリング開始...")
    bpy.ops.render.render(write_still=True)
    print(f">>> レンダリング完了: {OUTPUT_PATH}")


main()
