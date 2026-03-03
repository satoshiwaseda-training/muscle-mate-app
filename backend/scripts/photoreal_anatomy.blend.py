"""
photoreal_anatomy.blend.py v1.0
================================
Skin Modifier による連続人体メッシュ + フォトリアル Cycles レンダラー

旧楕円体集合アプローチからの改善点:
  - Skin Modifier → スケルトン全関節から一枚の連続した人体シルエットを生成
  - フロント・ダブルバイセップス ポーズ（両腕フレックス）
  - Subdivision Surface Lv3 による有機的な滑らかさ
  - フェース別マテリアル（筋肉ゾーン近傍距離でポリゴンを分類）
  - Cycles SSS + Anisotropic + Wave Bump → 生体組織感
  - 7点ハイコントラスト・スタジオ照明 / 漆黒背景
"""

import bpy
import bmesh
import math
import json
import sys
import os
from mathutils import Vector

# ── JSON 入力 ───────────────────────────────────────────────────────────────
_argv = sys.argv
_json_path = _argv[_argv.index("--") + 1] if "--" in _argv else None
INPUT = {}
if _json_path and os.path.exists(_json_path):
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
    "bump_strength":  max(0.45, _m("bump_strength",  0.70)),   # テクスチャ強化
    "fiber_scale":    _m("fiber_scale",    12.0),              # 線維帯を細かく
    "fiber_distort":  _m("fiber_distortion", 2.8),
    "em_threshold":   _m("emission_threshold", 0.15),          # より多くの筋肉が発光
    "em_strength":    max(8.0, _m("emission_strength", 13.0)), # 強い発光
    "roughness":      _m("roughness",   0.28),
    "specular":       _m("specular",    0.58),
    "sss":            _m("sss_base",    0.28),                 # SSS強化
    "sss_mult":       _m("sss_multiplier", 0.22),
    "key_energy":     _l("key_energy",  750.0),
    "key_color":      _l("key_color",   [1.00, 0.88, 0.68]),
    "fill_energy":    _l("fill_energy",  25.0),                # フィルを絞ってコントラスト増
    "fill_color":     _l("fill_color",  [0.60, 0.80, 1.00]),
    "rim_R_energy":   _l("rim_R_energy", 2800.0),
    "rim_L_energy":   _l("rim_L_energy", 1800.0),
    "top_energy":     _l("top_energy",   400.0),
}

print("=" * 60)
print("  Photoreal Anatomy Renderer v1.0")
print("  (Skin Modifier + Front Double Bicep Pose)")
print("=" * 60)
print(f"  Output: {OUTPUT_PATH}")
print(f"  Res:    {RESOLUTION_X}×{RESOLUTION_Y}")

# ── マグマカラーマップ ────────────────────────────────────────────────────
def intensity_to_rgb(t: float):
    t = max(0.0, min(1.0, t))
    if t < 0.25:
        r = 0.0;       g = 0.0;       b = 0.30 + t * 2.40
    elif t < 0.50:
        u = (t - 0.25) / 0.25
        r = u * 0.80;  g = 0.0;       b = 0.90 - u * 0.90
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
    for blk in list(bpy.data.meshes):    bpy.data.meshes.remove(blk)
    for blk in list(bpy.data.materials):bpy.data.materials.remove(blk)
    for blk in list(bpy.data.lights):   bpy.data.lights.remove(blk)
    for blk in list(bpy.data.cameras):  bpy.data.cameras.remove(blk)
    print(">>> シーンリセット完了")


# ── Cycles マテリアル ─────────────────────────────────────────────────────
def make_cycles_material(name: str, r: float, g: float, b: float,
                          intensity: float):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    N = mat.node_tree.nodes
    L = mat.node_tree.links
    N.clear()

    out  = N.new('ShaderNodeOutputMaterial')
    bsdf = N.new('ShaderNodeBsdfPrincipled')
    tc   = N.new('ShaderNodeTexCoord')

    # 筋線維テクスチャ → Base Color に直接注入
    wav = N.new('ShaderNodeTexWave')
    wav.wave_type       = 'BANDS'
    wav.bands_direction = 'Z'
    wav.inputs['Scale'].default_value      = P["fiber_scale"]
    wav.inputs['Distortion'].default_value = P["fiber_distort"]
    wav.inputs['Detail'].default_value     = 7.0
    wav.inputs['Detail Scale'].default_value = 2.5

    noise = N.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value     = 5.0
    noise.inputs['Detail'].default_value    = 6.0
    noise.inputs['Roughness'].default_value = 0.65

    mix_fib = N.new('ShaderNodeMixRGB')
    mix_fib.blend_type = 'MIX'
    mix_fib.inputs[0].default_value = 0.20  # 20% noise

    ramp = N.new('ShaderNodeValToRGB')
    ramp.color_ramp.interpolation = 'LINEAR'
    dk = 0.28; lt = 1.80
    ramp.color_ramp.elements[0].position = 0.15
    ramp.color_ramp.elements[0].color = (
        max(0.001, r * dk), max(0.001, g * dk), max(0.001, b * (dk + 0.04)), 1.0)
    ramp.color_ramp.elements[1].position = 0.85
    ramp.color_ramp.elements[1].color = (
        min(1.0, r * lt), min(1.0, g * (lt - 0.18)), min(1.0, b * (lt - 0.35)), 1.0)

    L.new(tc.outputs['Object'], wav.inputs['Vector'])
    L.new(tc.outputs['Object'], noise.inputs['Vector'])
    L.new(wav.outputs['Color'],   mix_fib.inputs[1])
    L.new(noise.outputs['Color'], mix_fib.inputs[2])
    L.new(mix_fib.outputs['Color'], ramp.inputs['Fac'])
    L.new(ramp.outputs['Color'], bsdf.inputs['Base Color'])

    def _try(inputs, key, val):
        if key in inputs:
            try: inputs[key].default_value = val
            except: pass

    # SSS — 生体組織の半透明感
    _try(bsdf.inputs, 'Subsurface Weight', P["sss"])
    if 'Subsurface Radius' in bsdf.inputs:
        bsdf.inputs['Subsurface Radius'].default_value = (0.060, 0.022, 0.008)
    if 'Subsurface Scale' in bsdf.inputs:
        bsdf.inputs['Subsurface Scale'].default_value  = 0.05
    _try(bsdf.inputs, 'Subsurface IOR', 1.40)

    # Anisotropic — 筋線維の光沢異方性
    _try(bsdf.inputs, 'Anisotropic',          0.50)
    _try(bsdf.inputs, 'Anisotropic Rotation', 0.0)

    _try(bsdf.inputs, 'Roughness',        P["roughness"])
    _try(bsdf.inputs, 'Specular IOR Level', P["specular"])
    _try(bsdf.inputs, 'IOR', 1.45)

    # Emission — 高活性筋肉のマグマ発光
    if intensity >= P["em_threshold"]:
        ef  = (intensity - P["em_threshold"]) / (1.0 - P["em_threshold"])
        ems = P["em_strength"] * ef * 0.50
        _try(bsdf.inputs, 'Emission Strength', ems)
        if 'Emission Color' in bsdf.inputs:
            bsdf.inputs['Emission Color'].default_value = (
                min(1.0, r * 1.3), min(1.0, g * 0.7), min(1.0, b * 0.4), 1.0)

    # Bump — 筋線維の立体感
    bwav = N.new('ShaderNodeTexWave')
    bwav.wave_type       = 'BANDS'
    bwav.bands_direction = 'Z'
    bwav.inputs['Scale'].default_value      = P["fiber_scale"] * 3.5
    bwav.inputs['Distortion'].default_value = 0.5
    L.new(tc.outputs['Object'], bwav.inputs['Vector'])

    bump = N.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = P["bump_strength"]
    bump.inputs['Distance'].default_value = 0.016
    L.new(bwav.outputs['Fac'],  bump.inputs['Height'])
    L.new(bump.outputs['Normal'], bsdf.inputs['Normal'])

    L.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    return mat


# ── スケルトン定義 (Front Double Bicep ポーズ) ─────────────────────────
# Format: (joint_name, (x, y, z), radius_m)
# 座標系: X=左右(+右体側), Y=前後(+前), Z=上下(+上)
# 身長約 1.75m。A-poseから両腕を横に広げ、肘を90°屈曲させてフォアアームを上向き
JOINTS_ORDER = [
    # ── 体軸 ──────────────────────────────────────────────────
    ('head',       ( 0.000,  0.000, 1.680), 0.104),
    ('neck',       ( 0.000,  0.000, 1.530), 0.048),
    ('chest',      ( 0.000,  0.022, 1.380), 0.150),
    ('spine_mid',  ( 0.000, -0.020, 1.180), 0.108),
    ('spine_low',  ( 0.000, -0.030, 1.010), 0.092),
    ('pelvis',     ( 0.000, -0.020, 0.900), 0.140),

    # ── 左腕 (Front Double Bicep: 上腕やや下向き → 肘で折り返し → 前腕垂直上向き) ──
    # 上腕は肩から外下へ (X-,Z-): ビッグV字シルエット
    ('l_shoul',    (-0.268,  0.008, 1.395), 0.082),
    ('l_uarm',     (-0.420, -0.005, 1.295), 0.072),   # 上腕: 肩より低い位置へ
    ('l_elbow',    (-0.455,  0.008, 1.230), 0.055),   # 肘: さらに下
    # 前腕: 肘から真上へ (X変化なし、Z上昇)
    ('l_farm',     (-0.452,  0.005, 1.380), 0.046),   # 前腕中間
    ('l_hand',     (-0.448,  0.002, 1.530), 0.038),   # 拳: 目の高さ

    # ── 右腕 (左右対称) ───────────────────────────────────────
    ('r_shoul',    ( 0.268,  0.008, 1.395), 0.082),
    ('r_uarm',     ( 0.420, -0.005, 1.295), 0.072),
    ('r_elbow',    ( 0.455,  0.008, 1.230), 0.055),
    ('r_farm',     ( 0.452,  0.005, 1.380), 0.046),
    ('r_hand',     ( 0.448,  0.002, 1.530), 0.038),

    # ── 左脚 ──────────────────────────────────────────────────
    ('l_hip',      (-0.122, -0.010, 0.868), 0.086),
    ('l_knee',     (-0.118,  0.010, 0.522), 0.062),
    ('l_ankle',    (-0.115,  0.018, 0.112), 0.038),
    ('l_foot',     (-0.112,  0.090, 0.025), 0.042),

    # ── 右脚 ──────────────────────────────────────────────────
    ('r_hip',      ( 0.122, -0.010, 0.868), 0.086),
    ('r_knee',     ( 0.118,  0.010, 0.522), 0.062),
    ('r_ankle',    ( 0.115,  0.018, 0.112), 0.038),
    ('r_foot',     ( 0.112,  0.090, 0.025), 0.042),
]

# スケルトン接続リスト
CONNECTIONS = [
    ('head', 'neck'), ('neck', 'chest'),
    ('chest', 'spine_mid'), ('spine_mid', 'spine_low'), ('spine_low', 'pelvis'),
    # 左腕
    ('chest', 'l_shoul'), ('l_shoul', 'l_uarm'), ('l_uarm', 'l_elbow'),
    ('l_elbow', 'l_farm'), ('l_farm', 'l_hand'),
    # 右腕
    ('chest', 'r_shoul'), ('r_shoul', 'r_uarm'), ('r_uarm', 'r_elbow'),
    ('r_elbow', 'r_farm'), ('r_farm', 'r_hand'),
    # 左脚
    ('pelvis', 'l_hip'), ('l_hip', 'l_knee'), ('l_knee', 'l_ankle'), ('l_ankle', 'l_foot'),
    # 右脚
    ('pelvis', 'r_hip'), ('r_hip', 'r_knee'), ('r_knee', 'r_ankle'), ('r_ankle', 'r_foot'),
]


# ── 筋肉ゾーン (フェース別マテリアル割り当て用) ──────────────────────────
# (中心座標, 影響半径, 筋肉グループ名)
MUSCLE_ZONES = [
    # 胸部 Pectoralis (前面に広く)
    (Vector((-0.145,  0.100, 1.250)), 0.255, 'chest'),
    (Vector(( 0.145,  0.100, 1.250)), 0.255, 'chest'),
    # 背部 Lat + Trap (後面に広く)
    (Vector((-0.220, -0.068, 1.115)), 0.270, 'back'),
    (Vector(( 0.220, -0.068, 1.115)), 0.270, 'back'),
    (Vector(( 0.000, -0.020, 1.440)), 0.240, 'back'),
    (Vector(( 0.000, -0.038, 1.260)), 0.195, 'back'),
    # 肩 Deltoid (全方向カバー)
    (Vector((-0.300,  0.005, 1.390)), 0.145, 'shoulders'),
    (Vector(( 0.300,  0.005, 1.390)), 0.145, 'shoulders'),
    # 上腕二頭筋 Biceps (前面の腕)
    (Vector((-0.415,  0.025, 1.350)), 0.110, 'biceps'),
    (Vector(( 0.415,  0.025, 1.350)), 0.110, 'biceps'),
    # 上腕三頭筋 Triceps (後面の腕)
    (Vector((-0.415, -0.035, 1.350)), 0.110, 'triceps'),
    (Vector(( 0.415, -0.035, 1.350)), 0.110, 'triceps'),
    # 前腕 forearm (bicepsグループ)
    (Vector((-0.443,  0.000, 1.445)), 0.090, 'biceps'),
    (Vector(( 0.443,  0.000, 1.445)), 0.090, 'biceps'),
    (Vector((-0.440,  0.000, 1.555)), 0.080, 'biceps'),
    (Vector(( 0.440,  0.000, 1.555)), 0.080, 'biceps'),
    # 腹部・体幹 Core (前面中央)
    (Vector(( 0.000,  0.090, 1.060)), 0.155, 'core'),
    (Vector((-0.120,  0.068, 1.045)), 0.115, 'core'),
    (Vector(( 0.120,  0.068, 1.045)), 0.115, 'core'),
    # 大腿四頭筋 Quads (太腿前面全体をカバー)
    (Vector((-0.115,  0.060, 0.700)), 0.175, 'quads'),
    (Vector(( 0.115,  0.060, 0.700)), 0.175, 'quads'),
    (Vector((-0.115,  0.050, 0.560)), 0.145, 'quads'),
    (Vector(( 0.115,  0.050, 0.560)), 0.145, 'quads'),
    # ハムストリングス (太腿後面全体をカバー)
    (Vector((-0.115, -0.068, 0.700)), 0.165, 'hamstrings'),
    (Vector(( 0.115, -0.068, 0.700)), 0.165, 'hamstrings'),
    (Vector((-0.115, -0.060, 0.570)), 0.145, 'hamstrings'),
    (Vector(( 0.115, -0.060, 0.570)), 0.145, 'hamstrings'),
    # 臀部 Glutes (後面全体)
    (Vector((-0.148, -0.095, 0.900)), 0.185, 'glutes'),
    (Vector(( 0.148, -0.095, 0.900)), 0.185, 'glutes'),
    # 下腿 Calves (前後ともに十分な半径でカバー)
    (Vector((-0.115,  0.000, 0.340)), 0.155, 'calves'),
    (Vector(( 0.115,  0.000, 0.340)), 0.155, 'calves'),
    (Vector((-0.115,  0.000, 0.220)), 0.145, 'calves'),
    (Vector(( 0.115,  0.000, 0.220)), 0.145, 'calves'),
]

def find_muscle_group(co: Vector) -> str:
    """頂点座標から最も近い筋肉グループを返す"""
    best_w = 0.0
    best_g = 'structure'
    for center, radius, group in MUSCLE_ZONES:
        d = (co - center).length
        if d < radius:
            w = (1.0 - d / radius) ** 2
            if w > best_w:
                best_w = w
                best_g = group
    return best_g


# ── Skin Modifier で人体メッシュ生成 ─────────────────────────────────────
def create_skin_body():
    """スケルトン辺から Skin Modifier で連続した人体メッシュを生成"""
    mesh = bpy.data.meshes.new("HumanBody")
    obj  = bpy.data.objects.new("HumanBody", mesh)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    if bpy.context.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')

    bm = bmesh.new()

    # 関節頂点を作成 (順序保持)
    name_to_idx = {}
    verts = []
    for i, (jname, jpos, jrad) in enumerate(JOINTS_ORDER):
        v = bm.verts.new(Vector(jpos))
        verts.append(v)
        name_to_idx[jname] = i

    # スケルトン接続辺を作成
    for a, b in CONNECTIONS:
        bm.edges.new([verts[name_to_idx[a]], verts[name_to_idx[b]]])

    bm.to_mesh(mesh)
    bm.free()
    mesh.update()

    # Skin Modifier 追加
    skin_mod = obj.modifiers.new("Skin", 'SKIN')
    skin_mod.use_smooth_shade = True

    # 各関節の皮膚半径を設定
    if mesh.skin_vertices and len(mesh.skin_vertices) > 0:
        skin_data = mesh.skin_vertices[0].data
        for i, (jname, jpos, jrad) in enumerate(JOINTS_ORDER):
            if i < len(skin_data):
                skin_data[i].radius = (jrad, jrad)
        # 頭頂・足先を ROOT としてメッシュを閉じる
        skin_data[name_to_idx['head']].use_root   = True
        skin_data[name_to_idx['l_foot']].use_root = True
        skin_data[name_to_idx['r_foot']].use_root = True
        skin_data[name_to_idx['l_hand']].use_root = True
        skin_data[name_to_idx['r_hand']].use_root = True
        print(f">>> Skin Modifier: {len(JOINTS_ORDER)}関節, 半径設定完了")
    else:
        print(">>> [WARN] skin_vertices layer が見つかりません")

    # Subdivision Surface (Smooth化)
    subsurf = obj.modifiers.new("Subsurf", 'SUBSURF')
    subsurf.levels        = 2
    subsurf.render_levels = 3
    subsurf.subdivision_type = 'CATMULL_CLARK'

    return obj, name_to_idx


# ── モディファイア適用 & 筋肉マテリアル割り当て ───────────────────────────
def apply_and_assign_materials(obj, intensities):
    """Skin/Subsurf を適用後、ポリゴン重心の近傍距離で筋肉マテリアルを割り当てる"""
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    if bpy.context.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')

    # モディファイア適用
    for mod_name in ['Skin', 'Subsurf']:
        try:
            bpy.ops.object.modifier_apply(modifier=mod_name)
            print(f">>> Modifier適用: {mod_name}")
        except Exception as e:
            print(f">>> [WARN] {mod_name} 適用失敗: {e}")

    bpy.ops.object.shade_smooth()

    mesh = obj.data

    # 筋肉グループ別マテリアル作成 & 登録
    GROUPS = ['chest', 'back', 'shoulders', 'biceps', 'triceps',
              'quads', 'hamstrings', 'glutes', 'calves', 'core', 'structure']
    mat_idx_map = {}
    for i, gname in enumerate(GROUPS):
        intensity = intensities.get(gname, 0.12)
        r, g, b   = intensity_to_rgb(intensity)
        mat = make_cycles_material(f"mat_{gname}", r, g, b, intensity)
        obj.data.materials.append(mat)
        mat_idx_map[gname] = i

    # ポリゴン別マテリアル割り当て
    assigned = {g: 0 for g in GROUPS}
    for poly in mesh.polygons:
        centroid = Vector((0.0, 0.0, 0.0))
        for vi in poly.vertices:
            centroid += mesh.vertices[vi].co
        centroid /= len(poly.vertices)
        grp = find_muscle_group(centroid)
        poly.material_index = mat_idx_map[grp]
        assigned[grp] += 1

    print(f">>> フェース別マテリアル割り当て完了  総ポリゴン数={len(mesh.polygons)}")
    for g, cnt in assigned.items():
        if cnt > 0:
            pct = cnt * 100 // len(mesh.polygons)
            print(f"    {g:12s}: {cnt:5d}面  ({pct}%)")


# ── 7点スタジオ照明 ───────────────────────────────────────────────────────
def _add_light(name, ltype, loc, energy, color, spot_deg=None, size=1.0):
    bpy.ops.object.light_add(type=ltype, location=loc)
    lt = bpy.context.active_object
    lt.name = name
    lt.data.energy = energy
    lt.data.color  = color[:3]
    if ltype == 'AREA':
        lt.data.size = size
    if ltype == 'SPOT' and spot_deg:
        lt.data.spot_size = math.radians(spot_deg)
    target    = Vector((0.0, 0.0, 1.15))
    direction = (target - Vector(loc)).normalized()
    lt.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()


def setup_lighting():
    # Key: 左斜め前から — 筋肉のカットを出す
    _add_light('key',     'AREA', (-1.80, -2.80,  2.60),
               P["key_energy"],   P["key_color"],   size=1.0)
    # Fill: 非常に弱く — ハイコントラストを維持
    _add_light('fill',    'AREA', ( 2.20, -1.40,  1.80),
               P["fill_energy"],  P["fill_color"],  size=2.0)
    # Rim R: 後右から — 輪郭を浮かび上がらせる
    _add_light('rim_R',   'SPOT', (-1.40,  3.20,  2.40),
               P["rim_R_energy"], [1.00, 0.94, 0.82], spot_deg=30)
    # Rim L: 後左から
    _add_light('rim_L',   'SPOT', ( 1.60,  3.00,  2.20),
               P["rim_L_energy"], [0.78, 0.90, 1.00], spot_deg=30)
    # Top: 真上から — 肩・僧帽筋のピーク強調
    _add_light('top',     'SPOT', ( 0.00, -0.80,  4.00),
               P["top_energy"],   [0.98, 0.98, 1.00], spot_deg=42)
    # Graze 左右: 横から筋肉の凸凹を際立たせる (掠め光)
    _add_light('graze_L', 'AREA', (-4.20,  0.00,  1.30),
               180.0, [1.00, 0.96, 0.88], size=0.28)
    _add_light('graze_R', 'AREA', ( 4.20,  0.00,  1.30),
               180.0, [1.00, 0.96, 0.88], size=0.28)
    print(">>> 7点スタジオ照明セットアップ完了")


# ── カメラ ───────────────────────────────────────────────────────────────
def setup_camera():
    # 正面右斜め25°から: 胸・肩・腕の立体感を出す (ボディビルダー撮影アングル)
    cam_loc = (0.35, -3.20, 1.10)
    bpy.ops.object.camera_add(location=cam_loc)
    cam = bpy.context.active_object
    cam.name = "Camera"
    target    = Vector((0.0, 0.0, 1.08))
    direction = (target - Vector(cam_loc)).normalized()
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    cam.data.lens         = 85     # ポートレートレンズ (歪み最小)
    cam.data.sensor_width = 36
    bpy.context.scene.camera = cam
    print(f">>> カメラ設定完了  lens=85mm  loc={cam_loc}  (3/4 front angle)")


# ── Cycles レンダラー ────────────────────────────────────────────────────
def setup_renderer():
    scene = bpy.context.scene
    scene.render.engine       = 'CYCLES'
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

    # Sampling
    cyc = scene.cycles
    cyc.samples              = 128
    cyc.use_adaptive_sampling  = True
    cyc.adaptive_min_samples   = 24
    cyc.adaptive_threshold     = 0.015

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

    print("\n>>> Step 1: Skin Modifier で連続人体メッシュを生成...")
    obj, name_to_idx = create_skin_body()
    print(f">>> Skin Modifier + Subsurf セットアップ完了")

    print("\n>>> Step 2: モディファイア適用 & 筋肉マテリアル割り当て...")
    apply_and_assign_materials(obj, INTENSITIES)

    print("\n>>> Step 3: ライティング・カメラ・レンダラー設定...")
    setup_lighting()
    setup_camera()
    setup_renderer()

    scene = bpy.context.scene
    scene.render.filepath = OUTPUT_PATH
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode  = 'RGB'
    scene.render.image_settings.color_depth = '8'

    print(f"\n>>> レンダリング開始... (Cycles CPU ~180秒)")
    bpy.ops.render.render(write_still=True)
    print(f">>> レンダリング完了: {OUTPUT_PATH}")


main()
