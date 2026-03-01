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
    強度 0.0〜1.0 を Blender Linear color space の色に変換:
      0.0  → 暗い青黒
      0.4  → 深いブルー→オレンジへ遷移
      0.7  → 鮮やかなオレンジ
      0.9  → 真っ赤
      1.0  → ホワイトホット（オーバーブライト）
    """
    if intensity < 0.4:
        t = intensity / 0.4
        r = 0.01 + 0.09 * t
        g = 0.01 + 0.05 * t
        b = 0.05 + 0.20 * t
    elif intensity < 0.7:
        t = (intensity - 0.4) / 0.3
        r = 0.10 + 0.90 * t   # → 1.0
        g = 0.06 + 0.21 * t   # → 0.27
        b = 0.25 - 0.24 * t   # → 0.01
    elif intensity < 0.9:
        t = (intensity - 0.7) / 0.2
        r = 1.0
        g = 0.27 - 0.27 * t   # → 0
        b = 0.01
    else:
        t = (intensity - 0.9) / 0.1
        r = 1.0
        g = 0.0 + 1.0 * t
        b = 0.0 + 1.0 * t

    # Emission オーバーブライトでブルームが乗る
    bloom = 1.5 + intensity * 3.5
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
    # name: (center_x, center_y, center_z, scale_x, scale_y, scale_z)
    # 新ボディ座標系に合わせた配置
    "chest":       ( 0.00,  0.16,  0.44, 0.20, 0.07, 0.18),  # 胸郭前面
    "back":        ( 0.00, -0.16,  0.38, 0.20, 0.07, 0.22),  # 背面
    "shoulders_l": (-0.28,  0.00,  0.56, 0.09, 0.09, 0.09),
    "shoulders_r": ( 0.28,  0.00,  0.56, 0.09, 0.09, 0.09),
    "biceps_l":    (-0.31,  0.06,  0.38, 0.07, 0.07, 0.16),
    "biceps_r":    ( 0.31,  0.06,  0.38, 0.07, 0.07, 0.16),
    "triceps_l":   (-0.31, -0.06,  0.38, 0.07, 0.07, 0.16),
    "triceps_r":   ( 0.31, -0.06,  0.38, 0.07, 0.07, 0.16),
    "core":        ( 0.00,  0.13,  0.18, 0.16, 0.07, 0.18),  # 腹直筋
    "quads_l":     (-0.11,  0.09, -0.25, 0.10, 0.10, 0.24),  # 大腿前面
    "quads_r":     ( 0.11,  0.09, -0.25, 0.10, 0.10, 0.24),
    "hamstrings_l":(-0.11, -0.09, -0.25, 0.10, 0.10, 0.24),  # 大腿後面
    "hamstrings_r":( 0.11, -0.09, -0.25, 0.10, 0.10, 0.24),
    "glutes":      ( 0.00, -0.16,  0.00, 0.20, 0.10, 0.13),  # 臀部
    "calves_l":    (-0.10, -0.05, -0.68, 0.07, 0.07, 0.17),
    "calves_r":    ( 0.10, -0.05, -0.68, 0.07, 0.07, 0.17),
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


def _add_capsule(name: str, loc: tuple, scale: tuple, rot=(0,0,0)) -> bpy.types.Object:
    """UV球2個+円柱でカプセルを作成してメッシュ変換"""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=16, radius=1.0, depth=1.0, location=loc
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    if any(rot):
        obj.rotation_euler = rot
    bpy.ops.object.shade_smooth()
    return obj


def create_body_base() -> bpy.types.Object:
    """
    プリミティブメッシュで明確な人体シルエットを構築する。
    Metaball を廃棄して円柱+球の直接配置に変更。
    比率はサトシさん (180cm, マッチョ体型) を参考にした。
    """
    parts = []

    # ── 頭 ──────────────────────────────────────────────────
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.12, location=(0, 0, 0.88))
    head = bpy.context.active_object
    head.name = "B_Head"
    head.scale = (1.0, 0.95, 1.1)
    bpy.ops.object.shade_smooth()
    parts.append(head)

    # ── 首 ──────────────────────────────────────────────────
    parts.append(_add_capsule("B_Neck", (0, 0, 0.72), (0.055, 0.055, 0.09)))

    # ── 胸郭（上体）─────────────────────────────────────────
    parts.append(_add_capsule("B_Chest", (0, 0, 0.44), (0.20, 0.14, 0.24)))

    # ── 腹部 ────────────────────────────────────────────────
    parts.append(_add_capsule("B_Abdomen", (0, 0, 0.20), (0.16, 0.12, 0.18)))

    # ── 骨盤 ────────────────────────────────────────────────
    parts.append(_add_capsule("B_Pelvis", (0, 0, 0.01), (0.18, 0.13, 0.13)))

    # ── 肩（左右）──────────────────────────────────────────
    for x in [-0.26, 0.26]:
        parts.append(_add_capsule(f"B_Shoulder_{'L' if x<0 else 'R'}",
                                  (x, 0, 0.56), (0.07, 0.07, 0.07)))

    # ── 上腕（左右）────────────────────────────────────────
    for x in [-0.30, 0.30]:
        parts.append(_add_capsule(f"B_UpperArm_{'L' if x<0 else 'R'}",
                                  (x*1.05, 0, 0.38), (0.06, 0.06, 0.18)))

    # ── 前腕（左右）────────────────────────────────────────
    for x in [-0.30, 0.30]:
        parts.append(_add_capsule(f"B_ForeArm_{'L' if x<0 else 'R'}",
                                  (x*1.06, 0, 0.16), (0.05, 0.05, 0.15)))

    # ── 大腿（左右）────────────────────────────────────────
    for x in [-0.11, 0.11]:
        parts.append(_add_capsule(f"B_Thigh_{'L' if x<0 else 'R'}",
                                  (x, 0, -0.25), (0.10, 0.10, 0.25)))

    # ── 膝（左右）──────────────────────────────────────────
    for x in [-0.11, 0.11]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.08, location=(x, 0, -0.50))
        knee = bpy.context.active_object
        knee.name = f"B_Knee_{'L' if x<0 else 'R'}"
        bpy.ops.object.shade_smooth()
        parts.append(knee)

    # ── 下腿（左右）────────────────────────────────────────
    for x in [-0.10, 0.10]:
        parts.append(_add_capsule(f"B_Shin_{'L' if x<0 else 'R'}",
                                  (x, 0, -0.70), (0.07, 0.07, 0.19)))

    # 全パーツを Join
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
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
        segments=20, ring_count=10,
        radius=1.0,
        location=(cx, cy, cz),
    )
    obj = bpy.context.active_object
    obj.name = f"Muscle_{zone_key}"
    obj.scale = (sx, sy, sz)
    bpy.ops.object.shade_smooth()

    # Emission のみのシンプルなマテリアル（よりクリアな発光感）
    mat = bpy.data.materials.new(name=f"Mat_{zone_key}")
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    r, g, b = color_rgb

    # Principled BSDF（ベース）
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.location = (-300, 100)
    # Base Color は強度を抑えた版（clamped）
    bc = min(r * 0.3, 1.0), min(g * 0.3, 1.0), min(b * 0.3, 1.0)
    bsdf.inputs["Base Color"].default_value = (*bc, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.25
    bsdf.inputs["Metallic"].default_value = 0.08

    # Emission（高輝度、bloom素材）
    emission = nodes.new('ShaderNodeEmission')
    emission.location = (-300, -100)
    emission.inputs["Color"].default_value = (
        min(r, 10.0), min(g, 10.0), min(b, 10.0), 1.0
    )
    emission.inputs["Strength"].default_value = emission_strength * 1.5

    # MixShader: 強度が高いほど Emission 比率を増加
    fac = min(0.3 + (emission_strength / 5.0) * 0.6, 0.95)
    mix = nodes.new('ShaderNodeMixShader')
    mix.location = (0, 0)
    mix.inputs["Fac"].default_value = fac

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
    bpy.ops.object.camera_add(location=(0, -3.8, 0.05))
    cam = bpy.context.active_object
    cam.name = "Main_Camera"
    cam.rotation_euler = (math.radians(90), 0, 0)
    cam.data.type = 'PERSP'
    cam.data.lens = 38  # 全身がフレームインする焦点距離
    bpy.context.scene.camera = cam

    scene = bpy.context.scene
    scene.render.resolution_x = resolution_x
    scene.render.resolution_y = resolution_y
    scene.render.resolution_percentage = 100


def setup_eevee_renderer():
    """
    EEVEE レンダラーの最適設定 (Blender 4.x / 5.x 両対応)
    Gemini推奨: Bloom + Screen Space Reflections でパンプ感強調
    """
    scene = bpy.context.scene
    # Blender 5.0 では 'BLENDER_EEVEE'、4.2以前は 'BLENDER_EEVEE_NEXT' も可
    scene.render.engine = 'BLENDER_EEVEE'

    eevee = scene.eevee
    for attr, val in [
        ('use_bloom', True),
        ('bloom_threshold', 0.4),
        ('bloom_intensity', 1.2),
        ('bloom_radius', 5.0),
        ('use_ssr', True),
        ('ssr_quality', 0.5),
        ('taa_render_samples', 64),
    ]:
        try:
            setattr(eevee, attr, val)
        except AttributeError:
            pass

    # カラーマネジメント: Standard = トーンマッピングなし → 発光色が鮮やかになる
    try:
        scene.view_settings.view_transform = 'Standard'
        scene.view_settings.exposure = 0.0
        scene.view_settings.gamma = 1.0
    except Exception:
        pass

    # 背景色 (ダークスタジオ)
    try:
        world = bpy.data.worlds["World"]
        world.use_nodes = True
        bg_node = world.node_tree.nodes.get("Background")
        if bg_node:
            bg_node.inputs["Color"].default_value = (0.006, 0.006, 0.010, 1.0)
            bg_node.inputs["Strength"].default_value = 0.0
    except Exception:
        pass


def setup_compositing_glare():
    """
    Blender 5.0 対応のGlare設定。
    APIバージョン差異を吸収しつつcompositing glareを試みる。
    """
    scene = bpy.context.scene
    try:
        scene.use_nodes = True
    except Exception:
        pass

    # Blender 5.0+ では compositing_node_tree を使う
    tree = getattr(scene, 'compositing_node_tree', None)
    if tree is None:
        tree = getattr(scene, 'node_tree', None)
    if tree is None:
        return  # compositing非対応バージョンはスキップ

    nodes = tree.nodes
    links = tree.links
    nodes.clear()

    render_layers = nodes.new('CompositorNodeRLayers')
    render_layers.location = (-400, 0)

    glare = nodes.new('CompositorNodeGlare')
    glare.location = (-150, 0)
    glare.glare_type = 'FOG_GLOW'
    glare.threshold = 0.5
    glare.size = 7
    glare.mix = 0.8

    composite = nodes.new('CompositorNodeComposite')
    composite.location = (100, 0)

    links.new(render_layers.outputs["Image"], glare.inputs["Image"])
    links.new(glare.outputs["Image"], composite.inputs["Image"])


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

    # 4b. Compositing Glare (Bloom代替)
    setup_compositing_glare()

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
