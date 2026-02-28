"""
Blender ヘッドレス・マッスルヒートマップレンダラー
─────────────────────────────────────────────────────────────
【実行方法】
  blender --background --python muscle_heatmap.blend.py -- /path/to/input.json

【入力 JSON 形式】
  {
    "intensities": {
      "chest": 0.85, "back": 0.60, "shoulders": 0.45,
      "biceps": 0.30, "triceps": 0.55, "quads": 0.70,
      "hamstrings": 0.65, "glutes": 0.75, "calves": 0.40, "core": 0.50
    },
    "output_path": "/path/to/output.png",
    "resolution_x": 512,
    "resolution_y": 1024
  }

【ライティング設定】
  Gemini に最適設定を相談した結果:
  - レンダラー: EEVEE (高速、モバイル表示に十分)
  - Key Light:  右上45° / Energy 5.0 / 暖色 (5500K)
  - Fill Light: 左側  / Energy 1.5 / 冷色 (7000K)
  - Rim Light:  背後  / Energy 3.0 / 白 (ハードエッジ強調)
  - HDRI背景:   ダークスタジオ (#0D0D0D)
  これにより筋肉の立体感と「パンプアップ感」が最大化される。
"""
import bpy
import json
import sys
import math
from mathutils import Vector, Color


# ── 引数解析 ───────────────────────────────────────────────────────────────

def _load_args() -> dict:
    argv = sys.argv
    try:
        sep = argv.index("--")
        json_path = argv[sep + 1]
    except (ValueError, IndexError):
        raise SystemExit("Usage: blender --background --python script.py -- input.json")
    with open(json_path, encoding="utf-8") as f:
        return json.load(f)


# ── カラーマッピング ────────────────────────────────────────────────────────

def _intensity_to_color(intensity: float) -> tuple[float, float, float]:
    """
    強度 0.0〜1.0 を色に変換:
      0.0  → 暗いグレー (#1A1A2E)
      0.3  → ダークブルー (#16213E)
      0.6  → オレンジ (#FF6D00)
      0.85 → 鮮やかなレッド (#FF1744)
      1.0  → ホワイトホット (#FFFFFF + bloom)
    """
    if intensity < 0.3:
        t = intensity / 0.3
        r = 0.10 + 0.05 * t
        g = 0.10 + 0.03 * t
        b = 0.18 + 0.12 * t
    elif intensity < 0.6:
        t = (intensity - 0.3) / 0.3
        r = 0.15 + 0.85 * t
        g = 0.13 + 0.30 * t
        b = 0.30 - 0.28 * t
    elif intensity < 0.85:
        t = (intensity - 0.6) / 0.25
        r = 1.0
        g = 0.43 - 0.43 * t
        b = 0.02
    else:
        t = (intensity - 0.85) / 0.15
        r = 1.0
        g = 0.0 + 1.0 * t
        b = 0.0 + 1.0 * t

    # Emission 強度に応じてブルーム感を出す (linear space)
    bloom = 1.0 + intensity * 2.0
    return (r * bloom, g * bloom, b * bloom)


def _emission_strength(intensity: float) -> float:
    """強度 0.0〜1.0 を Blender Emission Strength にマッピング"""
    return 0.2 + intensity * 4.8  # 0.2〜5.0


# ── 筋肉部位の頂点グループ → メッシュゾーン定義 ────────────────────────────

# 各筋肉のBounding Box (x_min, x_max, y_min, y_max, z_min, z_max) in local space
# 単純な「カプセル体」で筋肉部位を表現
# 実際のBlenderワークフローでは weight painting を使うが、
# ヘッドレスではプロシージャルに分割する

_MUSCLE_ZONES = {
    # name: (center_x, center_y, center_z, size_x, size_y, size_z)
    # Blender座標系: Z=上, Y=前, X=右
    "chest":      ( 0.00,  0.15,  0.40, 0.30, 0.10, 0.22),
    "back":       ( 0.00, -0.15,  0.30, 0.30, 0.10, 0.30),
    "shoulders_l":(-0.28,  0.00,  0.52, 0.12, 0.12, 0.12),
    "shoulders_r":( 0.28,  0.00,  0.52, 0.12, 0.12, 0.12),
    "biceps_l":   (-0.30,  0.05,  0.28, 0.08, 0.08, 0.18),
    "biceps_r":   ( 0.30,  0.05,  0.28, 0.08, 0.08, 0.18),
    "triceps_l":  (-0.30, -0.05,  0.28, 0.08, 0.08, 0.18),
    "triceps_r":  ( 0.30, -0.05,  0.28, 0.08, 0.08, 0.18),
    "core":       ( 0.00,  0.10,  0.16, 0.22, 0.10, 0.20),
    "quads_l":    (-0.12,  0.08, -0.20, 0.10, 0.10, 0.28),
    "quads_r":    ( 0.12,  0.08, -0.20, 0.10, 0.10, 0.28),
    "hamstrings_l":(-0.12,-0.08, -0.20, 0.10, 0.10, 0.28),
    "hamstrings_r":( 0.12,-0.08, -0.20, 0.10, 0.10, 0.28),
    "glutes":     ( 0.00, -0.18, -0.02, 0.24, 0.12, 0.16),
    "calves_l":   (-0.10, -0.05, -0.58, 0.07, 0.07, 0.18),
    "calves_r":   ( 0.10, -0.05, -0.58, 0.07, 0.07, 0.18),
}

# 筋肉グループ → ゾーン名のマッピング（対称展開）
_GROUP_TO_ZONES = {
    "chest":      ["chest"],
    "back":       ["back"],
    "shoulders":  ["shoulders_l", "shoulders_r"],
    "biceps":     ["biceps_l", "biceps_r"],
    "triceps":    ["triceps_l", "triceps_r"],
    "core":       ["core"],
    "quads":      ["quads_l", "quads_r"],
    "hamstrings": ["hamstrings_l", "hamstrings_r"],
    "glutes":     ["glutes"],
    "calves":     ["calves_l", "calves_r"],
}


# ── シーン構築 ──────────────────────────────────────────────────────────────

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for block in bpy.data.meshes:
        bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        bpy.data.materials.remove(block)


def create_body_base() -> bpy.types.Object:
    """人体の基本形状をプロシージャルに構築する"""
    # メタボール (Metaball) で有機的な人体シルエットを作成
    bpy.ops.object.metaball_add(type='CAPSULE', location=(0, 0, 0))
    torso = bpy.context.active_object
    torso.name = "Body_Torso"
    torso.data.resolution = 0.08
    torso.scale = (0.28, 0.18, 0.48)

    # 骨盤
    bpy.ops.object.metaball_add(type='CAPSULE', location=(0, 0, -0.06))
    pelvis = bpy.context.active_object
    pelvis.name = "Body_Pelvis"
    pelvis.scale = (0.24, 0.17, 0.28)

    # 頭
    bpy.ops.object.metaball_add(type='BALL', location=(0, 0, 0.82))
    head = bpy.context.active_object
    head.name = "Body_Head"
    head.scale = (0.13, 0.13, 0.16)

    # 首
    bpy.ops.object.metaball_add(type='CAPSULE', location=(0, 0, 0.68))
    neck = bpy.context.active_object
    neck.name = "Body_Neck"
    neck.scale = (0.07, 0.07, 0.10)

    # 腕（左右）
    for side, x in [("L", -0.35), ("R", 0.35)]:
        bpy.ops.object.metaball_add(type='CAPSULE', location=(x, 0, 0.35))
        arm_upper = bpy.context.active_object
        arm_upper.name = f"Body_Arm_Upper_{side}"
        arm_upper.scale = (0.07, 0.07, 0.20)
        arm_upper.rotation_euler.z = math.radians(90 if side == "L" else -90) * 0.3

        bpy.ops.object.metaball_add(type='CAPSULE', location=(x * 1.05, 0, 0.10))
        arm_lower = bpy.context.active_object
        arm_lower.name = f"Body_Arm_Lower_{side}"
        arm_lower.scale = (0.06, 0.06, 0.18)

    # 脚（左右）
    for side, x in [("L", -0.13), ("R", 0.13)]:
        bpy.ops.object.metaball_add(type='CAPSULE', location=(x, 0, -0.30))
        leg_upper = bpy.context.active_object
        leg_upper.name = f"Body_Leg_Upper_{side}"
        leg_upper.scale = (0.11, 0.11, 0.28)

        bpy.ops.object.metaball_add(type='CAPSULE', location=(x, 0, -0.68))
        leg_lower = bpy.context.active_object
        leg_lower.name = f"Body_Leg_Lower_{side}"
        leg_lower.scale = (0.08, 0.08, 0.22)

    # 全 Metaball を結合してメッシュ変換
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = torso
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join()
    body = bpy.context.active_object
    body.name = "HumanBody"
    return body


def create_base_material() -> bpy.types.Material:
    """人体のベースマテリアル（暗いスキン調）"""
    mat = bpy.data.materials.new(name="Body_Base")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()

    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.location = (0, 0)
    bsdf.inputs["Base Color"].default_value = (0.08, 0.06, 0.10, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.1
    bsdf.inputs["Roughness"].default_value = 0.6
    bsdf.inputs["Specular IOR Level"].default_value = 0.5

    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (200, 0)
    mat.node_tree.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    return mat


def create_muscle_object(
    zone_key: str,
    center: tuple,
    size: tuple,
    color_rgb: tuple,
    emission_strength: float,
) -> bpy.types.Object:
    """筋肉部位をカプセル形状で生成し Emission マテリアルを適用"""
    cx, cy, cz, sx, sy, sz = (*center, *size)

    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=16, ring_count=8,
        radius=1.0,
        location=(cx, cy, cz),
    )
    obj = bpy.context.active_object
    obj.name = f"Muscle_{zone_key}"
    obj.scale = (sx, sy, sz)

    # Smooth shading
    bpy.ops.object.shade_smooth()

    # Emission マテリアル
    mat = bpy.data.materials.new(name=f"Mat_{zone_key}")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    # Principled BSDF + Emission の混合
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.location = (-200, 100)
    r, g, b = color_rgb
    bsdf.inputs["Base Color"].default_value = (min(r, 1.0), min(g, 1.0), min(b, 1.0), 1.0)
    bsdf.inputs["Roughness"].default_value = 0.3
    bsdf.inputs["Metallic"].default_value = 0.05

    emission = nodes.new('ShaderNodeEmission')
    emission.location = (-200, -100)
    emission.inputs["Color"].default_value = (r, g, b, 1.0)
    emission.inputs["Strength"].default_value = emission_strength

    mix = nodes.new('ShaderNodeMixShader')
    mix.location = (0, 0)
    mix.inputs["Fac"].default_value = 0.4  # 40% Emission, 60% BSDF

    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (200, 0)

    links.new(bsdf.outputs["BSDF"], mix.inputs[1])
    links.new(emission.outputs["Emission"], mix.inputs[2])
    links.new(mix.outputs["Shader"], output.inputs["Surface"])

    obj.data.materials.append(mat)
    return obj


def setup_lighting():
    """
    Gemini推奨のスタジオライティングをセットアップ:
    Key + Fill + Rim の3点照明でパンプアップ感を最大化
    """
    # Key Light (右上45°、暖色)
    bpy.ops.object.light_add(type='AREA', location=(1.5, -1.0, 1.8))
    key = bpy.context.active_object
    key.name = "Key_Light"
    key.data.energy = 120.0
    key.data.color = (1.0, 0.92, 0.78)  # 5500K
    key.data.size = 0.8
    key.rotation_euler = (math.radians(45), 0, math.radians(30))

    # Fill Light (左側、冷色)
    bpy.ops.object.light_add(type='AREA', location=(-1.8, 0.5, 0.8))
    fill = bpy.context.active_object
    fill.name = "Fill_Light"
    fill.data.energy = 40.0
    fill.data.color = (0.78, 0.88, 1.0)  # 7000K
    fill.data.size = 1.5
    fill.rotation_euler = (math.radians(30), 0, math.radians(-40))

    # Rim Light (背後、白、ハードエッジ)
    bpy.ops.object.light_add(type='SPOT', location=(0.0, 2.0, 1.2))
    rim = bpy.context.active_object
    rim.name = "Rim_Light"
    rim.data.energy = 200.0
    rim.data.color = (1.0, 1.0, 1.0)
    rim.data.spot_size = math.radians(40)
    rim.data.spot_blend = 0.15
    rim.rotation_euler = (math.radians(-20), 0, math.radians(180))


def setup_camera(resolution_x: int, resolution_y: int):
    """フロントビューカメラのセットアップ"""
    bpy.ops.object.camera_add(location=(0, -2.8, 0.15))
    cam = bpy.context.active_object
    cam.name = "Main_Camera"
    cam.rotation_euler = (math.radians(90), 0, 0)
    cam.data.type = 'PERSP'
    cam.data.lens = 65  # 圧縮感を抑えた標準〜望遠
    bpy.context.scene.camera = cam

    # レンダリング解像度
    scene = bpy.context.scene
    scene.render.resolution_x = resolution_x
    scene.render.resolution_y = resolution_y
    scene.render.resolution_percentage = 100


def setup_eevee_renderer():
    """
    EEVEE レンダラーの最適設定
    Gemini推奨: Bloom + Screen Space Reflections でパンプ感強調
    """
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE_NEXT'

    eevee = scene.eevee
    eevee.use_bloom = True
    eevee.bloom_threshold = 0.6
    eevee.bloom_intensity = 0.8
    eevee.bloom_radius = 4.0
    eevee.use_ssr = True
    eevee.ssr_quality = 0.5
    eevee.taa_render_samples = 32

    # 背景色 (ダークスタジオ)
    world = bpy.data.worlds["World"]
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node:
        bg_node.inputs["Color"].default_value = (0.008, 0.008, 0.012, 1.0)
        bg_node.inputs["Strength"].default_value = 0.0


# ── メイン処理 ─────────────────────────────────────────────────────────────

def main():
    args = _load_args()
    intensities: dict[str, float] = args["intensities"]
    output_path: str = args["output_path"]
    res_x: int = args.get("resolution_x", 512)
    res_y: int = args.get("resolution_y", 1024)

    print(f"[muscle_heatmap] 強度データ受信: {intensities}")
    print(f"[muscle_heatmap] 出力先: {output_path}")

    # 1. シーンクリア
    clear_scene()

    # 2. ライティング
    setup_lighting()

    # 3. カメラ
    setup_camera(res_x, res_y)

    # 4. レンダラー設定
    setup_eevee_renderer()

    # 5. ベース人体
    body = create_body_base()
    base_mat = create_base_material()
    body.data.materials.append(base_mat)

    # 6. 筋肉部位オーバーレイ（発光エフェクト）
    for group, zones in _GROUP_TO_ZONES.items():
        intensity = intensities.get(group, 0.0)
        if intensity < 0.05:
            continue  # 非活性部位はスキップ

        color_rgb = _intensity_to_color(intensity)
        strength = _emission_strength(intensity)

        for zone_key in zones:
            if zone_key not in _MUSCLE_ZONES:
                continue
            cx, cy, cz, sx, sy, sz = _MUSCLE_ZONES[zone_key]
            create_muscle_object(
                zone_key=zone_key,
                center=(cx, cy, cz),
                size=(sx * 0.9, sy * 0.9, sz * 0.9),  # ベースより少し小さく
                color_rgb=color_rgb,
                emission_strength=strength,
            )
            print(f"  [{zone_key}] intensity={intensity:.2f}, strength={strength:.2f}")

    # 7. レンダリング
    bpy.context.scene.render.filepath = output_path
    bpy.context.scene.render.image_settings.file_format = 'PNG'
    bpy.ops.render.render(write_still=True)
    print(f"[muscle_heatmap] レンダリング完了: {output_path}")


main()
