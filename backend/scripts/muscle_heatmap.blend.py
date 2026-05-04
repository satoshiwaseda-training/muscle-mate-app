"""
muscle_heatmap.blend.py  —  解剖学グレード 筋肉ヒートマップレンダラー v5.0
───────────────────────────────────────────────────────────────────────────
実行: blender --background --python muscle_heatmap.blend.py -- input.json

v5.0 変更点（v4.0からの改善）:
  [CRITICAL] Cycles + OIDN デノイザー  → 物理的に正確なSSS・バンプ描画
  [CRITICAL] 筋線維テクスチャをBase Colorに直接注入（照明非依存の視認性）
  [FIX]      SSS Radius を現実的な値(0.06m)に修正（v4の1.0mは過大）
  [FIX]      Anisotropic シェーダー廃止（効果なしと判定）
  [NEW]      Emission 1.5倍強化（マグマ内部発光感の向上）
  [NEW]      グレイジング照明2灯追加（バンプ縞の鮮明化）
"""

import bpy
import sys
import json
import math
import os
from mathutils import Vector, Euler

# ─────────────────────────────────────────────────────────────────────────────
# 0. ARGS / CONFIG
# ─────────────────────────────────────────────────────────────────────────────

argv = sys.argv
try:
    idx   = argv.index("--") + 1
    _path = argv[idx]
    with open(_path, "r", encoding="utf-8") as f:
        _data = json.load(f)
    INTENSITIES   = _data.get("intensities", {})
    OUTPUT_PATH   = _data.get("output_path", "muscle_anatomy.png")
    RES_X         = _data.get("resolution_x", 1024)
    RES_Y         = _data.get("resolution_y", 2048)
    RPARAMS       = _data.get("render_params", {})
except (ValueError, IndexError, FileNotFoundError):
    INTENSITIES = {
        "chest": 0.99, "back": 0.82, "shoulders": 0.75,
        "biceps": 0.42, "triceps": 0.58, "quads": 1.00,
        "hamstrings": 0.62, "glutes": 0.88, "calves": 0.48, "core": 0.72,
    }
    OUTPUT_PATH = "muscle_anatomy.png"
    RES_X, RES_Y = 768, 1536
    RPARAMS = {}

def _G(key): return INTENSITIES.get(key, 0.3)

# Gemini 推奨パラメータ（デフォルト + 上書き）
_m  = RPARAMS.get("material", {})
_e  = RPARAMS.get("eevee",    {})
_l  = RPARAMS.get("lighting", {})

P = {
    "sss_base":      _m.get("sss_base",          0.20),
    "sss_mult":      _m.get("sss_multiplier",     0.22),
    "roughness":     _m.get("roughness",          0.28),
    "specular":      _m.get("specular",           0.60),
    # v5.4: bump_strengthのガードを下げ（Gemini Visionの0.2提案を受け入れ可能に）
    "bump_strength": max(0.18, _m.get("bump_strength", 0.50)),  # 最低0.18保証
    "fiber_scale_c": 7.0,    # 幅広縞（v5.1で texture 8/10 実績）
    "fiber_scale_b": 22.0,   # Bump 用（細かい表面凹凸）
    "fiber_distort": _m.get("fiber_distortion",   2.2),
    "em_threshold":  _m.get("emission_threshold", 0.25),
    "em_strength":   max(7.0, _m.get("emission_strength", 9.0)),  # 最低7.0保証
    "cycles_samples":96,
    # v5.4: v5.0照明設定に戻す（lighting 8/10 実績） + fill を適度に保つ（テクスチャ視認性）
    "key_energy":    _l.get("key_energy",         520.0),
    "key_color":     _l.get("key_color",          [1.0, 0.88, 0.68]),
    "fill_energy":   _l.get("fill_energy",        65.0),   # v5.0実績値（70近辺）
    "fill_color":    _l.get("fill_color",         [0.62, 0.78, 1.0]),
    "rim_R_energy":  _l.get("rim_R_energy",       2000.0), # v5.0より少し強め
    "rim_L_energy":  _l.get("rim_L_energy",       1200.0),
    "top_energy":    _l.get("top_energy",         240.0),
    "graze_energy":  160.0,   # 控えめ（v5.0のない状態より少し追加）
}


# ─────────────────────────────────────────────────────────────────────────────
# 1. SCENE CLEAR
# ─────────────────────────────────────────────────────────────────────────────

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for D in [bpy.data.meshes, bpy.data.materials,
              bpy.data.lights, bpy.data.cameras]:
        for b in list(D):
            D.remove(b)


# ─────────────────────────────────────────────────────────────────────────────
# 2. MATERIAL SYSTEM
# ─────────────────────────────────────────────────────────────────────────────

def _try(inputs, name, val):
    if name in inputs:
        inputs[name].default_value = val
        return True
    return False


def _intensity_to_color(v):
    """強度 0→1 を色に変換（紺→深赤→オレンジ→白熱）"""
    if v < 0.25:
        t = v / 0.25
        return (0.02 + t * 0.08,  0.03 + t * 0.04,  0.15 + t * 0.06)
    elif v < 0.55:
        t = (v - 0.25) / 0.30
        return (0.10 + t * 0.52,  0.07 - t * 0.05,  0.21 - t * 0.18)
    elif v < 0.80:
        t = (v - 0.55) / 0.25
        return (0.62 + t * 0.28,  0.02 + t * 0.20,  0.03)
    else:
        t = (v - 0.80) / 0.20
        return (0.90 + t * 0.10,  0.22 + t * 0.73,  0.03 + t * 0.55)


def make_muscle_mat(name, intensity, fiber_axis='Z'):
    """
    v5.0 シェーダー:
      - 筋線維縞模様をBase Colorに直接注入（照明非依存の視認性）
      - Emission 1.5× 強化
      - SSS Radius を現実的な物理値に修正
      - Anisotropic 廃止（効果なし確認済み）
    """
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    N = mat.node_tree.nodes
    L = mat.node_tree.links
    N.clear()

    r, g, b = _intensity_to_color(intensity)

    # ── ノード配置 ────────────────────────────────────────────────────────────
    out   = N.new('ShaderNodeOutputMaterial'); out.location   = (1300, 0)
    mix   = N.new('ShaderNodeMixShader');      mix.location   = (1050, 0)
    bsdf  = N.new('ShaderNodeBsdfPrincipled'); bsdf.location  = (750,  200)
    emiss = N.new('ShaderNodeEmission');       emiss.location = (750, -220)
    tc    = N.new('ShaderNodeTexCoord');       tc.location    = (-900, 0)

    # ── [KEY FIX] 筋線維テクスチャ → Base Color（照明依存ゼロ） ─────────────
    # 長軸に沿って線維が走る → 縞方向は長軸と直交するX/Z方向に設定
    fiber_dir = 'X' if fiber_axis in ('Z', 'Y') else 'Z'

    wav_c = N.new('ShaderNodeTexWave');  wav_c.location = (-720, 280)
    wav_c.wave_type       = 'BANDS'
    wav_c.bands_direction = fiber_dir
    wav_c.inputs['Scale'].default_value            = P["fiber_scale_c"]  # 7: 幅広縞（視認性重視）
    wav_c.inputs['Distortion'].default_value       = P["fiber_distort"]  # 2.2: 生物的不規則性
    wav_c.inputs['Detail'].default_value           = 5.0
    wav_c.inputs['Detail Scale'].default_value     = 3.0
    wav_c.inputs['Detail Roughness'].default_value = 0.75
    L.new(tc.outputs['Object'], wav_c.inputs['Vector'])

    # Noise テクスチャ（25%混合で生物的な不規則性を追加）
    noise_c = N.new('ShaderNodeTexNoise');  noise_c.location = (-720, 60)
    noise_c.inputs['Scale'].default_value      = 3.5
    noise_c.inputs['Detail'].default_value     = 4.0
    noise_c.inputs['Roughness'].default_value  = 0.65
    noise_c.inputs['Distortion'].default_value = 0.2
    L.new(tc.outputs['Object'], noise_c.inputs['Vector'])

    # Wave + Noise を 75:25 で混合（生物的テクスチャ）
    mix_wav = N.new('ShaderNodeMixRGB');  mix_wav.location = (-490, 200)
    mix_wav.blend_type = 'MIX'
    mix_wav.inputs[0].default_value = 0.25   # 25% Noise
    L.new(wav_c.outputs['Color'],   mix_wav.inputs[1])
    L.new(noise_c.outputs['Color'], mix_wav.inputs[2])

    # Color Ramp: 暗い線維溝 ←→ 明るい線維束（コントラスト比 約5:1、LINEAR補間）
    ramp = N.new('ShaderNodeValToRGB'); ramp.location = (-260, 200)
    ramp.color_ramp.interpolation = 'LINEAR'   # EASEより鮮明なエッジ
    # 暗い溝（位置0.15）
    ramp.color_ramp.elements[0].position = 0.15
    ramp.color_ramp.elements[0].color    = (
        max(0.001, r * 0.32),
        max(0.001, g * 0.32),
        max(0.001, b * 0.36),
        1.0)
    # 明るい線維峰（位置0.85）
    ramp.color_ramp.elements[1].position = 0.85
    ramp.color_ramp.elements[1].color    = (
        min(1.0, r * 1.72),
        min(1.0, g * 1.55),
        min(1.0, b * 1.42),
        1.0)
    L.new(mix_wav.outputs['Color'], ramp.inputs['Fac'])

    # Base Color = 線維縞（常に視認可能）
    L.new(ramp.outputs['Color'], bsdf.inputs['Base Color'])

    # ── Principled BSDF パラメータ ────────────────────────────────────────────
    _try(bsdf.inputs, 'Roughness',          P["roughness"])
    _try(bsdf.inputs, 'Specular IOR Level', P["specular"])
    _try(bsdf.inputs, 'Specular',           P["specular"])
    _try(bsdf.inputs, 'Coat Weight',        0.15)
    _try(bsdf.inputs, 'Coat Roughness',     0.18)
    # Sheen: v5.4では廃止（効果が不安定なため）

    # SSS（物理的に正確な皮膚/筋肉の光散乱距離に修正）
    sss = min(0.45, P["sss_base"] + intensity * P["sss_mult"])
    _try(bsdf.inputs, 'Subsurface Weight', sss)
    _try(bsdf.inputs, 'Subsurface',        sss)
    if 'Subsurface Color' in bsdf.inputs:
        bsdf.inputs['Subsurface Color'].default_value = (0.90, 0.15, 0.05, 1.0)
    if 'Subsurface Radius' in bsdf.inputs:
        # Blender 1unit=1m スケールで約6cm(R), 2.2cm(G), 0.8cm(B) の散乱距離
        # v4の(1.0, 0.35, 0.08)は100cmで過大 → リアルな皮膚SSS値に修正
        bsdf.inputs['Subsurface Radius'].default_value = (0.060, 0.022, 0.008)
    if 'Subsurface Scale' in bsdf.inputs:
        bsdf.inputs['Subsurface Scale'].default_value = 0.05

    # ── Emission（マグマ内部発光）────────────────────────────────────────────
    em_str = max(0.0, (intensity - P["em_threshold"]) * P["em_strength"] * 1.5)
    emiss.inputs['Color'].default_value    = (
        min(1.0, r * 2.6 + 0.3),
        min(1.0, g * 1.5 + 0.05),
        min(1.0, b * 0.12),
        1.0)
    emiss.inputs['Strength'].default_value = em_str
    mix.inputs[0].default_value = min(0.65, intensity * 0.58)

    # ── Bump Map（表面微細凹凸：色縞と別スケールで立体感を加算） ─────────────
    wav_b = N.new('ShaderNodeTexWave');  wav_b.location = (-640, -140)
    wav_b.wave_type       = 'BANDS'
    wav_b.bands_direction = fiber_dir
    wav_b.inputs['Scale'].default_value            = P["fiber_scale_b"]  # 26: 細かいバンプ
    wav_b.inputs['Distortion'].default_value       = 1.8
    wav_b.inputs['Detail'].default_value           = 5.0
    wav_b.inputs['Detail Scale'].default_value     = 2.0
    wav_b.inputs['Detail Roughness'].default_value = 0.55
    L.new(tc.outputs['Object'], wav_b.inputs['Vector'])

    bmp = N.new('ShaderNodeBump'); bmp.location = (350, -80)
    bmp.inputs['Strength'].default_value = P["bump_strength"]
    bmp.inputs['Distance'].default_value = 0.012
    L.new(wav_b.outputs['Color'], bmp.inputs['Height'])
    L.new(bmp.outputs['Normal'],  bsdf.inputs['Normal'])

    # ── Shader Connections ────────────────────────────────────────────────────
    L.new(bsdf.outputs[0],  mix.inputs[1])
    L.new(emiss.outputs[0], mix.inputs[2])
    L.new(mix.outputs[0],   out.inputs[0])

    return mat


def make_base_mat(name):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    N = mat.node_tree.nodes
    L = mat.node_tree.links
    N.clear()
    out  = N.new('ShaderNodeOutputMaterial')
    bsdf = N.new('ShaderNodeBsdfPrincipled')
    bsdf.inputs['Base Color'].default_value = (0.09, 0.07, 0.10, 1.0)
    _try(bsdf.inputs, 'Roughness',         0.72)
    _try(bsdf.inputs, 'Subsurface Weight', 0.04)
    _try(bsdf.inputs, 'Subsurface',        0.04)
    L.new(bsdf.outputs[0], out.inputs[0])
    return mat


# ─────────────────────────────────────────────────────────────────────────────
# 3. GEOMETRY HELPERS
# ─────────────────────────────────────────────────────────────────────────────

def _subsurf(obj, lv=0, rv=1):
    bpy.ops.object.shade_smooth()
    m = obj.modifiers.new('Sub', 'SUBSURF')
    m.levels = lv; m.render_levels = rv
    return obj


def add_sphere(name, loc, scale, rot=(0, 0, 0), mat=None, seg=16, ring=10):
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=1.0, location=loc, segments=seg, ring_count=ring)
    o = bpy.context.active_object
    o.name = name; o.scale = scale
    o.rotation_euler = Euler(rot, 'XYZ')
    _subsurf(o, 1, 2)
    if mat: o.data.materials.append(mat)
    return o


def add_cyl(name, loc, radius, depth, scale=(1, 1, 1), rot=(0, 0, 0), mat=None, seg=12):
    bpy.ops.mesh.primitive_cylinder_add(
        radius=radius, depth=depth, location=loc, vertices=seg)
    o = bpy.context.active_object
    o.name = name; o.scale = scale
    o.rotation_euler = Euler(rot, 'XYZ')
    _subsurf(o, 1, 2)
    if mat: o.data.materials.append(mat)
    return o


# ─────────────────────────────────────────────────────────────────────────────
# 4. BASE BODY
# ─────────────────────────────────────────────────────────────────────────────

def create_body(bm):
    add_cyl('torso',     (0, 0, 1.12),    0.26, 0.65, scale=(1.0, 0.72, 1.0), mat=bm, seg=24)
    add_cyl('hips',      (0, 0, 0.875),   0.23, 0.14, scale=(1.1, 0.82, 1.0), mat=bm, seg=20)
    add_sphere('chest_d',(0, 0.05, 1.28), (0.27, 0.09, 0.14), mat=bm)
    add_sphere('head',   (0, 0, 1.72),    (1.0, 0.86, 1.0),   mat=bm, seg=16, ring=10)
    add_cyl('neck',      (0, 0, 1.565),   0.056, 0.10, scale=(1.0, 0.84, 1.0), mat=bm, seg=10)

    for sx, s in [(-1, 'L'), (1, 'R')]:
        ax = sx * 0.38
        add_cyl(f'ua_{s}',  (ax, -0.01, 1.22),       0.062, 0.36, mat=bm, seg=12)
        add_sphere(f'elb_{s}', (ax*1.07, -0.03, 1.07), (0.075, 0.075, 0.075), mat=bm, seg=10)
        add_cyl(f'la_{s}',  (ax*1.11, -0.055, 0.90), 0.048, 0.30, mat=bm, seg=10)
        add_sphere(f'hnd_{s}', (ax*1.16, -0.08, 0.77), (0.05, 0.03, 0.06),    mat=bm, seg=8)

    for sx, s in [(-1, 'L'), (1, 'R')]:
        tx = sx * 0.12
        add_cyl(f'thigh_{s}', (tx, 0.02, 0.67),   0.10,  0.43, scale=(1.0, 0.9, 1.0), mat=bm, seg=16)
        add_sphere(f'kn_{s}', (tx, 0.02, 0.485),   (0.085, 0.075, 0.085), mat=bm, seg=12)
        add_cyl(f'll_{s}',    (tx, -0.01, 0.275),  0.062, 0.36, scale=(1.0, 0.84, 1.0), mat=bm, seg=12)
        add_sphere(f'ank_{s}',(tx, -0.02, 0.085),  (0.058, 0.048, 0.055), mat=bm, seg=8)
        add_sphere(f'ft_{s}', (tx, 0.09, 0.055),   (0.06, 0.14, 0.04),    mat=bm, seg=8)


# ─────────────────────────────────────────────────────────────────────────────
# 5. INDIVIDUAL MUSCLE OBJECTS
# ─────────────────────────────────────────────────────────────────────────────

def create_muscles():
    _mc = {}
    def M(key, fd='Z'):
        k2 = f"{key}_{fd}"
        if k2 not in _mc:
            _mc[k2] = make_muscle_mat(f"mm_{key}", _G(key), fd)
        return _mc[k2]

    # ── 大胸筋（Pectoralis Major）水平線維 ──────────────────────────────
    add_sphere('pec_st_L', (-0.105, 0.170, 1.210), (0.158, 0.072, 0.128), (0.05,0, 0.20), M('chest','X'))
    add_sphere('pec_st_R', ( 0.105, 0.170, 1.210), (0.158, 0.072, 0.128), (0.05,0,-0.20), M('chest','X'))
    add_sphere('pec_cl_L', (-0.082, 0.155, 1.335), (0.115, 0.058, 0.080), (0.08,0, 0.15), M('chest','X'))
    add_sphere('pec_cl_R', ( 0.082, 0.155, 1.335), (0.115, 0.058, 0.080), (0.08,0,-0.15), M('chest','X'))
    add_sphere('pec_ab_L', (-0.115, 0.155, 1.120), (0.100, 0.060, 0.065), (0.05,0, 0.25), M('chest','X'))
    add_sphere('pec_ab_R', ( 0.115, 0.155, 1.120), (0.100, 0.060, 0.065), (0.05,0,-0.25), M('chest','X'))

    # ── 三角筋（Deltoid）3頭 ────────────────────────────────────────────
    add_sphere('dlt_a_L', (-0.285, 0.095, 1.385), (0.078, 0.075, 0.100), (0,0,0), M('shoulders','Y'))
    add_sphere('dlt_a_R', ( 0.285, 0.095, 1.385), (0.078, 0.075, 0.100), (0,0,0), M('shoulders','Y'))
    add_sphere('dlt_m_L', (-0.335, 0.000, 1.380), (0.068, 0.088, 0.106), (0,0,0), M('shoulders','Y'))
    add_sphere('dlt_m_R', ( 0.335, 0.000, 1.380), (0.068, 0.088, 0.106), (0,0,0), M('shoulders','Y'))
    add_sphere('dlt_p_L', (-0.305,-0.075, 1.370), (0.065, 0.065, 0.090), (0,0,0), M('shoulders','Y'))
    add_sphere('dlt_p_R', ( 0.305,-0.075, 1.370), (0.065, 0.065, 0.090), (0,0,0), M('shoulders','Y'))

    # ── 上腕二頭筋（Biceps）長頭 + 短頭 + 上腕筋 ─────────────────────
    add_sphere('bi_lg_L', (-0.385, 0.065, 1.230), (0.064, 0.075, 0.152), (0,0,0), M('biceps','Z'))
    add_sphere('bi_lg_R', ( 0.385, 0.065, 1.230), (0.064, 0.075, 0.152), (0,0,0), M('biceps','Z'))
    add_sphere('bi_sh_L', (-0.362, 0.042, 1.185), (0.046, 0.058, 0.122), (0,0,0), M('biceps','Z'))
    add_sphere('bi_sh_R', ( 0.362, 0.042, 1.185), (0.046, 0.058, 0.122), (0,0,0), M('biceps','Z'))
    add_sphere('br_L',    (-0.372, 0.020, 1.095), (0.042, 0.048, 0.085), (0,0,0), M('biceps','Z'))
    add_sphere('br_R',    ( 0.372, 0.020, 1.095), (0.042, 0.048, 0.085), (0,0,0), M('biceps','Z'))

    # ── 上腕三頭筋（Triceps）3頭 ─────────────────────────────────────
    add_sphere('tri_l_L',  (-0.395,-0.070, 1.225), (0.068, 0.062, 0.158), (0,0,0), M('triceps','Z'))
    add_sphere('tri_l_R',  ( 0.395,-0.070, 1.225), (0.068, 0.062, 0.158), (0,0,0), M('triceps','Z'))
    add_sphere('tri_lat_L',(-0.415,-0.040, 1.240), (0.055, 0.050, 0.128), (0,0,0), M('triceps','Z'))
    add_sphere('tri_lat_R',( 0.415,-0.040, 1.240), (0.055, 0.050, 0.128), (0,0,0), M('triceps','Z'))
    add_sphere('tri_med_L',(-0.380,-0.055, 1.150), (0.048, 0.042, 0.100), (0,0,0), M('triceps','Z'))
    add_sphere('tri_med_R',( 0.380,-0.055, 1.150), (0.048, 0.042, 0.100), (0,0,0), M('triceps','Z'))

    # ── 腹直筋（Rectus Abdominis）6パック ─────────────────────────────
    for ri, z_ab in enumerate([1.155, 1.060, 0.970]):
        sy = 0.046 - ri * 0.002
        add_sphere(f'ra_{ri}_L', (-0.046, 0.192, z_ab), (0.064, 0.042, sy), (0,0,0), M('core','Z'))
        add_sphere(f'ra_{ri}_R', ( 0.046, 0.192, z_ab), (0.064, 0.042, sy), (0,0,0), M('core','Z'))
    add_sphere('ra_3_L', (-0.044, 0.185, 0.880), (0.060, 0.038, 0.042), (0,0,0), M('core','Z'))
    add_sphere('ra_3_R', ( 0.044, 0.185, 0.880), (0.060, 0.038, 0.042), (0,0,0), M('core','Z'))

    # ── 腹斜筋 + 前鋸筋 ──────────────────────────────────────────────
    add_sphere('obl_L', (-0.195, 0.148, 1.010), (0.090, 0.042, 0.165), (0,0, 0.42), M('core','Y'))
    add_sphere('obl_R', ( 0.195, 0.148, 1.010), (0.090, 0.042, 0.165), (0,0,-0.42), M('core','Y'))
    add_sphere('ser_L', (-0.248, 0.108, 1.130), (0.036, 0.036, 0.125), (0,0, 0.18), M('core','Z'))
    add_sphere('ser_R', ( 0.248, 0.108, 1.130), (0.036, 0.036, 0.125), (0,0,-0.18), M('core','Z'))

    # ── 大腿四頭筋（Quadriceps）4頭 ───────────────────────────────────
    add_sphere('rf_L', (-0.102, 0.108, 0.698), (0.064, 0.076, 0.200), (0,0,0), M('quads','Z'))
    add_sphere('rf_R', ( 0.102, 0.108, 0.698), (0.064, 0.076, 0.200), (0,0,0), M('quads','Z'))
    add_sphere('vl_L', (-0.182, 0.052, 0.688), (0.078, 0.062, 0.192), (0.05,0,0), M('quads','Z'))
    add_sphere('vl_R', ( 0.182, 0.052, 0.688), (0.078, 0.062, 0.192), (0.05,0,0), M('quads','Z'))
    add_sphere('vm_L', (-0.065, 0.092, 0.562), (0.060, 0.065, 0.095), (0,0,-0.15), M('quads','Z'))
    add_sphere('vm_R', ( 0.065, 0.092, 0.562), (0.060, 0.065, 0.095), (0,0, 0.15), M('quads','Z'))
    add_sphere('vi_L', (-0.112, 0.062, 0.698), (0.052, 0.056, 0.168), (0,0,0), M('quads','Z'))
    add_sphere('vi_R', ( 0.112, 0.062, 0.698), (0.052, 0.056, 0.168), (0,0,0), M('quads','Z'))

    # ── 腓腹筋 + ヒラメ筋（Calf）────────────────────────────────────
    add_sphere('gc_mi_L', (-0.078,-0.048, 0.335), (0.054, 0.060, 0.134), (0,0,0), M('calves','Z'))
    add_sphere('gc_mi_R', ( 0.078,-0.048, 0.335), (0.054, 0.060, 0.134), (0,0,0), M('calves','Z'))
    add_sphere('gc_la_L', (-0.130,-0.055, 0.324), (0.048, 0.055, 0.120), (0,0,0), M('calves','Z'))
    add_sphere('gc_la_R', ( 0.130,-0.055, 0.324), (0.048, 0.055, 0.120), (0,0,0), M('calves','Z'))
    add_sphere('sol_L',   (-0.100,-0.038, 0.220), (0.064, 0.056, 0.098), (0,0,0), M('calves','Z'))
    add_sphere('sol_R',   ( 0.100,-0.038, 0.220), (0.064, 0.056, 0.098), (0,0,0), M('calves','Z'))

    # ── BACK MUSCLES ─────────────────────────────────────────────────
    # 広背筋（V字テーパー）
    add_sphere('lat_L', (-0.220,-0.122, 1.085), (0.162, 0.048, 0.215), (0.06, 0.18, 0.30), M('back','Y'))
    add_sphere('lat_R', ( 0.220,-0.122, 1.085), (0.162, 0.048, 0.215), (0.06,-0.18,-0.30), M('back','Y'))
    add_sphere('tm_L',  (-0.275,-0.090, 1.280), (0.072, 0.040, 0.068), (0, 0.15, 0.35),    M('back','Y'))
    add_sphere('tm_R',  ( 0.275,-0.090, 1.280), (0.072, 0.040, 0.068), (0,-0.15,-0.35),    M('back','Y'))

    # 僧帽筋（上・中・下）
    add_sphere('trap_u_L', (-0.145,-0.082, 1.435), (0.125, 0.044, 0.098), (0,0, 0.28), M('back','Y'))
    add_sphere('trap_u_R', ( 0.145,-0.082, 1.435), (0.125, 0.044, 0.098), (0,0,-0.28), M('back','Y'))
    add_sphere('trap_m',   (    0,-0.122, 1.285),  (0.210, 0.040, 0.112), (0,0,0),     M('back','X'))
    add_sphere('trap_l',   (    0,-0.112, 1.155),  (0.162, 0.036, 0.095), (0,0,0),     M('back','X'))

    # 大臀筋 + 中臀筋
    add_sphere('glu_L', (-0.132,-0.095, 0.855), (0.148, 0.080, 0.135), (0,0,0), M('glutes','X'))
    add_sphere('glu_R', ( 0.132,-0.095, 0.855), (0.148, 0.080, 0.135), (0,0,0), M('glutes','X'))
    add_sphere('gm_L',  (-0.175,-0.062, 0.935), (0.088, 0.055, 0.095), (0,0,0), M('glutes','X'))
    add_sphere('gm_R',  ( 0.175,-0.062, 0.935), (0.088, 0.055, 0.095), (0,0,0), M('glutes','X'))

    # ハムストリング（大腿二頭筋 + 半腱様筋）
    add_sphere('bf_L', (-0.142,-0.072, 0.675), (0.075, 0.060, 0.215), (0,0,0), M('hamstrings','Z'))
    add_sphere('bf_R', ( 0.142,-0.072, 0.675), (0.075, 0.060, 0.215), (0,0,0), M('hamstrings','Z'))
    add_sphere('st_L', (-0.092,-0.078, 0.672), (0.055, 0.055, 0.205), (0,0,0), M('hamstrings','Z'))
    add_sphere('st_R', ( 0.092,-0.078, 0.672), (0.055, 0.055, 0.205), (0,0,0), M('hamstrings','Z'))

    # 脊柱起立筋
    add_sphere('es_L', (-0.055,-0.115, 1.045), (0.045, 0.038, 0.245), (0,0,0), M('back','Z'))
    add_sphere('es_R', ( 0.055,-0.115, 1.045), (0.045, 0.038, 0.245), (0,0,0), M('back','Z'))


# ─────────────────────────────────────────────────────────────────────────────
# 6. STUDIO LIGHTING（グレイジング照明2灯追加）
# ─────────────────────────────────────────────────────────────────────────────

def _add_light(name, ltype, loc, energy, color, size=None, spot_deg=None):
    bpy.ops.object.light_add(type=ltype, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.data.energy = energy
    o.data.color  = tuple(color)
    if size and ltype == 'AREA':
        o.data.size = size
    if spot_deg and ltype == 'SPOT':
        o.data.spot_size  = math.radians(spot_deg)
        o.data.spot_blend = 0.25
    target = Vector((0.0, 0.0, 0.95))
    d = target - Vector(loc)
    if d.length > 0.001:
        o.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    return o


def setup_lighting():
    # メイン照明（3点）
    _add_light('key',   'AREA', (-1.40,-2.20, 2.25), P["key_energy"],   P["key_color"],   size=1.2)
    _add_light('fill',  'AREA', ( 1.80,-1.00, 1.55), P["fill_energy"],  P["fill_color"],  size=1.6)
    _add_light('rim_R', 'SPOT', (-1.00, 2.80, 2.05), P["rim_R_energy"], [1.00, 0.92, 0.80], spot_deg=32)
    _add_light('rim_L', 'SPOT', ( 1.20, 2.55, 1.88), P["rim_L_energy"], [0.75, 0.88, 1.00], spot_deg=32)
    _add_light('top',   'SPOT', ( 0.10,-0.40, 3.30), P["top_energy"],   [0.95, 0.95, 1.00], spot_deg=48)
    # グレイジング照明（かすめ角でバンプ縞を際立たせる）
    # カメラは-Y方向から撮影 → 側面(±X)からのかすめ光でフロント面のバンプが明瞭に
    _add_light('graze_L', 'AREA', (-3.20, 0.0, 1.10), P["graze_energy"], [1.00, 0.96, 0.88], size=0.30)
    _add_light('graze_R', 'AREA', ( 3.20, 0.0, 1.10), P["graze_energy"], [1.00, 0.96, 0.88], size=0.30)

    scene = bpy.context.scene
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get('Background')
    if bg:
        bg.inputs['Color'].default_value    = (0.0, 0.0, 0.0, 1.0)
        bg.inputs['Strength'].default_value = 0.0


# ─────────────────────────────────────────────────────────────────────────────
# 7. CAMERA
# ─────────────────────────────────────────────────────────────────────────────

def setup_camera():
    cam_loc = (-0.18, -3.75, 0.94)
    bpy.ops.object.camera_add(location=cam_loc)
    cam = bpy.context.active_object
    cam.name = 'anatomy_cam'
    target = Vector((0.0, 0.0, 0.94))
    d = target - Vector(cam_loc)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    cam.data.lens       = 52.0
    cam.data.clip_start = 0.1
    cam.data.clip_end   = 20.0
    bpy.context.scene.camera = cam


# ─────────────────────────────────────────────────────────────────────────────
# 8. CYCLES RENDERER（v5.0 主要変更点）
# ─────────────────────────────────────────────────────────────────────────────

def setup_renderer():
    """
    Cyclesレンダラー + OIDN デノイザー
    - 物理的に正確なSSS（エッジ透過・マグマ内部発光）
    - バンプマップが全照明角度で正確に描画される
    - 32サンプル + OIDN → 品質は128サンプル相当
    """
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'

    # v5.1: 高解像度（Cyclesが44秒と高速なので1024×2048に戻す）
    scene.render.resolution_x          = 1024
    scene.render.resolution_y          = 2048
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = OUTPUT_PATH

    # カラーマネジメント
    for vt in ('AgX', 'Filmic', 'Standard'):
        try:
            scene.view_settings.view_transform = vt
            break
        except Exception:
            continue
    scene.view_settings.look     = 'None'
    scene.view_settings.exposure = 0.20
    scene.view_settings.gamma    = 1.10

    # Cycles コア設定
    cyc = scene.cycles
    cyc.samples               = P["cycles_samples"]   # 32
    cyc.use_adaptive_sampling = True
    cyc.adaptive_min_samples  = 8
    cyc.adaptive_threshold    = 0.025

    # OIDN デノイザー（Intel Open Image Denoise）
    cyc.use_denoising = True
    for dn in ('OPENIMAGEDENOISE', 'NLM'):
        try:
            cyc.denoiser = dn
            print(f"  [Cycles] Denoiser: {dn}")
            break
        except Exception:
            continue

    # Caustics オフ（レンダリング高速化）
    for attr in ('caustics_reflective', 'caustics_refractive'):
        try: setattr(cyc, attr, False)
        except Exception: pass

    # GPU 優先 → CPU フォールバック
    gpu_ok = False
    for dev_type in ('OPTIX', 'CUDA', 'HIP', 'METAL'):
        try:
            prefs = bpy.context.preferences.addons['cycles'].preferences
            prefs.compute_device_type = dev_type
            prefs.get_devices()
            gpu_devs = [d for d in prefs.devices if d.type != 'CPU']
            if gpu_devs:
                for d in gpu_devs: d.use = True
                scene.cycles.device = 'GPU'
                print(f"  [Cycles] GPU ({dev_type}): {gpu_devs[0].name}")
                gpu_ok = True
                break
        except Exception:
            continue
    if not gpu_ok:
        scene.cycles.device = 'CPU'
        print("  [Cycles] CPU モード (GPUなし)")

    print(f"  [Cycles] samples={cyc.samples}, res=768x1536, denoiser=ON")


# ─────────────────────────────────────────────────────────────────────────────
# 9. COMPOSITING（グロー効果）
# ─────────────────────────────────────────────────────────────────────────────

def setup_compositing():
    scene = bpy.context.scene
    scene.use_nodes = True
    tree = getattr(scene, 'node_tree', None)
    if not tree:
        return
    try:
        tree.nodes.clear()
        rl  = tree.nodes.new('CompositorNodeRLayers');   rl.location  = (-400, 0)
        glr = tree.nodes.new('CompositorNodeGlare');     glr.location = (-100, 0)
        com = tree.nodes.new('CompositorNodeComposite'); com.location = ( 300, 0)
        glr.glare_type = 'FOG_GLOW'
        glr.quality    = 'HIGH'
        glr.threshold  = 0.60   # v5.2: 下げてグロー範囲を広げる
        glr.size       = 7
        tree.links.new(rl.outputs['Image'],  glr.inputs['Image'])
        tree.links.new(glr.outputs['Image'], com.inputs['Image'])
    except Exception as e:
        print(f"[WARN] Compositing: {e}")


# ─────────────────────────────────────────────────────────────────────────────
# 10. MAIN
# ─────────────────────────────────────────────────────────────────────────────

def main():
    print("\n=== Anatomy Grade Muscle Heatmap Renderer v5.0 ===")
    print(f"  Output  : {OUTPUT_PATH}")
    print(f"  Engine  : CYCLES + OIDN")
    print(f"  Samples : {P['cycles_samples']}")

    clear_scene()
    print("[1/7] Scene cleared")

    bm = make_base_mat('base')
    create_body(bm)
    print("[2/7] Body base created")

    create_muscles()
    print(f"[3/7] Muscles created  (objects: {len(bpy.data.objects)})")

    setup_lighting()
    print("[4/7] Studio lighting set up (7-point: key/fill/rim×2/top/graze×2)")

    setup_camera()
    print("[5/7] Camera positioned")

    setup_renderer()
    setup_compositing()
    print("[6/7] Cycles renderer configured")

    out_dir = os.path.dirname(os.path.abspath(OUTPUT_PATH))
    os.makedirs(out_dir, exist_ok=True)
    print(f"[7/7] Rendering -> {OUTPUT_PATH}")
    bpy.ops.render.render(write_still=True)

    if os.path.exists(OUTPUT_PATH):
        sz = os.path.getsize(OUTPUT_PATH) / 1024
        print(f"\n>>> SUCCESS: {OUTPUT_PATH}  ({sz:.1f} KB)")
    else:
        print("\n>>> ERROR: Output file not found!")


main()
