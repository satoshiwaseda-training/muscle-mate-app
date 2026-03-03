"""
build_ultimate_anatomy.py
=========================
Skin Modifier ベースのフォトリアル解剖学モデルを自律的に構築・品質検証するスクリプト。

v2.0 改善点 (photoreal_anatomy.blend.py 使用):
  - Skin Modifier → 連続した人体メッシュ (楕円体集合から完全脱却)
  - フロント・ダブルバイセップスポーズ
  - フェース別マテリアル (筋肉ゾーン近傍距離で分類)
  - SSS + Anisotropic + Wave Bump → 生体組織感
  - 7点ハイコントラスト・スタジオ照明
  - スコア ≥ 8/10 になるまで最大 5回の自律イテレーション

フロー:
  1. Gemini にマテリアル/照明パラメータを諮問
  2. photoreal_anatomy.blend.py でBlender Cycles レンダリング
  3. Gemini Vision で品質評価 (1〜10点)
  4. 8点未満なら改善パラメータで再レンダ (最大5回)
  5. 最終画像を renders/ に保存
"""

import sys
import os
import json
import subprocess
import base64
import shutil
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv
load_dotenv()

import google.generativeai as genai
genai.configure(api_key=os.getenv("GOOGLE_API_KEY"))
model = genai.GenerativeModel("gemini-2.0-flash")

# ── パス定義 ─────────────────────────────────────────────────────────────
SCRIPT_DIR    = os.path.dirname(os.path.abspath(__file__))
BACKEND_DIR   = os.path.dirname(SCRIPT_DIR)
BLEND_SCRIPT  = os.path.join(SCRIPT_DIR, "photoreal_anatomy.blend.py")
RENDERS_DIR   = os.path.join(BACKEND_DIR, "renders")
OUTPUT_PNG    = os.path.join(RENDERS_DIR, "satoshi_ultimate_anatomy.png")

os.makedirs(RENDERS_DIR, exist_ok=True)

# サトシさんの強度プロファイル (BIG3 115/140/160kg)
SATOSHI_INTENSITIES = {
    "chest":      0.99,
    "back":       0.82,
    "shoulders":  0.75,
    "biceps":     0.42,
    "triceps":    0.58,
    "quads":      1.00,
    "hamstrings": 0.62,
    "glutes":     0.88,
    "calves":     0.48,
    "core":       0.72,
    "structure":  0.12,  # 体幹構造（ダークネイビー）
}

BLENDER_CANDIDATES = [
    r"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe",
    r"C:\Program Files\Blender Foundation\Blender 4.4\blender.exe",
    r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe",
    "/usr/bin/blender",
    "/Applications/Blender.app/Contents/MacOS/Blender",
]


def find_blender():
    found = shutil.which("blender")
    if found:
        return found
    for c in BLENDER_CANDIDATES:
        if os.path.exists(c):
            return c
    return None


# ── 1. Gemini パラメータ諮問 ─────────────────────────────────────────────
def consult_gemini_for_params() -> dict:
    print("\n[Gemini諮問] レンダリングパラメータを要求中...")
    prompt = """
あなたはBlender 5.0 Cyclesレンダラーとプロの解剖学3Dアートの専門家です。
今回のモデルは「Skin Modifierで生成した連続した人体メッシュ」（楕円体集合ではなく一枚の有機的な人体シルエット）です。
フロント・ダブルバイセップスポーズを取るボディビルダー（ベンチ115kg/スクワット140kg/デッドリフト160kgのBIG3選手）を
Shutterstockレベルの「生体組織感」でレンダリングするための最適なパラメータをJSON形式で返してください。

モデル仕様:
- Skin Modifier + Subdivision Surface (Lv3) → 連続した人体シルエット
- フロント・ダブルバイセップスポーズ（両腕横に広げて前腕を垂直上向き）
- 筋肉グループ別マテリアル（マグマカラーマップ: 低強度=紺→高強度=白橙）
- SSS + Anisotropic（筋線維光沢）+ Wave Bump テクスチャ
- Cycles + OIDN (128サンプル)
- 7点ハイコントラスト・スタジオ照明（漆黒背景）

重要な調整のポイント:
- bump_strength: 連続メッシュは楕円体より面が大きいため 0.45〜0.65 が適切
- fill_energy: ハイコントラストを維持するため 40〜70W に抑える
- rim_R_energy: 後方から輪郭を際立たせるため 2000〜3000W が推奨
- emission_strength: 高強度筋肉（クワッド/胸）のマグマ発光で立体感を出す

以下のJSONスキーマを厳密に守って返してください（コードブロック不要、JSONのみ）:
{
  "material": {
    "sss_base": <float 0.18-0.28>,
    "sss_multiplier": <float 0.15-0.25>,
    "roughness": <float 0.26-0.38>,
    "specular": <float 0.50-0.70>,
    "bump_strength": <float 0.45-0.65>,
    "fiber_distortion": <float 1.8-2.8>,
    "emission_threshold": <float 0.20-0.32>,
    "emission_strength": <float 7.0-14.0>
  },
  "lighting": {
    "key_energy": <float 500-900>,
    "key_color": [<r 0.90-1.0>, <g 0.80-0.95>, <b 0.60-0.80>],
    "fill_energy": <float 40-70>,
    "fill_color": [<r 0.5-0.8>, <g 0.7-0.9>, <b 0.9-1.0>],
    "rim_R_energy": <float 2000-3200>,
    "rim_L_energy": <float 1200-2200>,
    "top_energy": <float 250-480>
  },
  "reasoning": "<120文字以内の理由>"
}
"""
    try:
        resp = model.generate_content(
            prompt,
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                temperature=0.3,
            ),
        )
        params = json.loads(resp.text)
        print(f"  [OK] Gemini諮問完了: {params.get('reasoning', '')}")
        return params
    except Exception as e:
        print(f"  [WARN] Gemini諮問失敗: {e} → デフォルト値を使用")
        return {}


# ── 2. Blender レンダリング ───────────────────────────────────────────────
def run_blender_render(params: dict) -> bool:
    blender = find_blender()
    if not blender:
        print("[ERROR] Blenderが見つかりません")
        return False

    input_data = {
        "intensities":  SATOSHI_INTENSITIES,
        "output_path":  OUTPUT_PNG,
        "resolution_x": 1024,
        "resolution_y": 2048,
        "render_params": params,
    }
    json_path = os.path.join(RENDERS_DIR, "ultimate_input.json")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(input_data, f, ensure_ascii=False, indent=2)

    cmd = [
        blender,
        "--background",
        "--python", BLEND_SCRIPT,
        "--",
        json_path,
    ]

    print(f"\n[Blender] レンダリング開始...")
    print(f"  exe: {blender}")
    t0 = time.time()

    proc = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=1200,  # 20分 (Cycles CPU レンダー)
    )
    elapsed = time.time() - t0
    log = proc.stdout.decode("utf-8", errors="replace")

    # 重要なログのみ出力
    for line in log.splitlines():
        if any(k in line for k in [
            "===", ">>>", "ERROR", "WARN", "Traceback",
            "File \"", "Exception", "Render",
            "[1/", "[2/", "[3/", "[4/", "[5/", "[6/", "[7/",
            "完了", "開始", "設定",
        ]):
            print(f"  {line}")

    print(f"  完了: {elapsed:.1f}秒  (exit={proc.returncode})")

    # ファイル存在確認
    if not os.path.exists(OUTPUT_PNG):
        print("[ERROR] 出力PNGが生成されませんでした")
        return False

    # 最終更新時刻でキャッシュ利用を検出
    mtime = os.path.getmtime(OUTPUT_PNG)
    if time.time() - mtime > 60:
        print("[WARN] 出力PNGの更新時刻が古い（キャッシュ再利用の可能性）")

    return True


# ── 3. Gemini Vision 品質評価 ────────────────────────────────────────────
def evaluate_with_gemini_vision(png_path: str) -> dict:
    print("\n[品質評価] Gemini Visionで評価中...")
    try:
        with open(png_path, "rb") as f:
            img_bytes = f.read()

        img_part = {
            "mime_type": "image/png",
            "data": base64.b64encode(img_bytes).decode("utf-8"),
        }

        eval_prompt = """
この画像はBlender Cycles + OIDN でレンダリングしたボディビルダー筋肉ヒートマップです。

モデル仕様:
- 【重要】Skin Modifier + Subdivision Surface による「連続した一枚の人体メッシュ」
  （楕円体の集合ではなく、有機的に融合した人体シルエット）
- フロント・ダブルバイセップスポーズ（両腕水平外向き、前腕垂直上向き）
- 筋肉グループ別マテリアル: マグマカラーマップ (低強度=濃紺→高強度=白橙)
- Cycles物理SSS（生体組織の半透明感）+ Anisotropic（筋線維の光沢）
- Wave Bumpテクスチャ（筋繊維の立体感）
- 7点ハイコントラスト・スタジオ照明 / 漆黒背景

ベンチ115kg/スクワット140kg/デッドリフト160kg のBIG3アスリートとして評価してください:

評価基準（各2点、合計10点）:
1. 人体シルエットの自然さ - 連続した人体に見えるか（バラバラの球体集合ではないか）
2. 筋肉の存在感・カラーマップ - 高強度筋肉（胸・クワッド）が鮮やかに浮き上がっているか
3. 筋線維テクスチャ/SSS - 生体組織感・縞模様・凸凹が視認できるか
4. 照明とコントラスト - ドラマチックな影・輪郭光・立体感があるか
5. 全体ビジュアルインパクト - ボディビルダー解剖学図として成立するか

以下のJSONのみを返してください（コードブロック不要）:
{
  "score": <int 1-10>,
  "anatomy_score": <int 1-10>,
  "texture_score": <int 1-10>,
  "lighting_score": <int 1-10>,
  "pass": <bool: score >= 8>,
  "strengths": ["<良い点1>", "<良い点2>"],
  "improvements": ["<改善点1>", "<改善点2>", "<改善点3>"],
  "blender_params_to_adjust": {
    "bump_strength": <float or null>,
    "emission_strength": <float or null>,
    "rim_R_energy": <float or null>,
    "fill_energy": <float or null>
  },
  "comment": "<120文字以内の総評>"
}
"""
        resp = model.generate_content(
            [img_part, eval_prompt],
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                temperature=0.2,
            ),
        )
        result = json.loads(resp.text)
        return result
    except Exception as e:
        print(f"  [WARN] Vision評価失敗: {e}")
        return {"score": 0, "pass": False, "comment": str(e)}


# ── 4. メインループ ───────────────────────────────────────────────────────
def main():
    print("=" * 60)
    print("  Photoreal Anatomy - Autonomous Build Pipeline v2.0")
    print("  (Skin Modifier + Front Double Bicep + Photoreal Cycles)")
    print("=" * 60)

    # Step 1: Gemini パラメータ諮問
    params = consult_gemini_for_params()

    best_score  = 0
    best_png    = None
    max_iter    = 5

    for iteration in range(1, max_iter + 1):
        print(f"\n{'='*60}")
        print(f"  ITERATION {iteration}/{max_iter}")
        print(f"{'='*60}")

        # Step 2: レンダリング
        success = run_blender_render(params)
        if not success:
            print("[ERROR] レンダリング失敗")
            break

        size_kb = os.path.getsize(OUTPUT_PNG) / 1024
        print(f"\n  出力: {OUTPUT_PNG}")
        print(f"  サイズ: {size_kb:.1f} KB")

        # Step 3: 品質評価
        eval_result = evaluate_with_gemini_vision(OUTPUT_PNG)
        score       = eval_result.get("score", 0)

        if score > best_score:
            best_score = score
            # ベスト画像を別名で保存
            best_png = OUTPUT_PNG.replace(".png", f"_best{score}.png")
            import shutil as _sh
            _sh.copy2(OUTPUT_PNG, best_png)

        print(f"\n  ── Gemini 品質評価 ──────────────────────────────────")
        passed = eval_result.get("pass", False)
        print(f"  総合スコア: {score}/10  {'[PASS OK]' if passed else '[改善要]'}")
        print(f"  解剖学:     {eval_result.get('anatomy_score', '-')}/10")
        print(f"  テクスチャ: {eval_result.get('texture_score', '-')}/10")
        print(f"  照明:       {eval_result.get('lighting_score', '-')}/10")
        print(f"  総評: {eval_result.get('comment', '')}")

        for s in eval_result.get("strengths", []):
            print(f"    [+] {s}")
        for imp in eval_result.get("improvements", []):
            print(f"    [-] {imp}")

        # 合格判定 (8/10以上)
        if eval_result.get("pass"):
            print(f"\n  >>> 品質合格！スコア {score}/10 達成 [PASS OK]")
            break

        if iteration >= max_iter:
            break

        # ── パラメータ調整 (スケーリング補正付き) ──────────────────
        adj = eval_result.get("blender_params_to_adjust", {})
        if adj:
            print(f"\n  パラメータ調整中...")
            if "material" not in params: params["material"] = {}
            if "lighting" not in params: params["lighting"] = {}

            if adj.get("bump_strength") is not None:
                # Gemini が 0.2 以下を返しても現在値より下げない (テクスチャ弱化防止)
                cur = params["material"].get("bump_strength", 0.70)
                v = max(cur, max(0.45, float(adj["bump_strength"])))
                params["material"]["bump_strength"] = v
                print(f"    bump_strength     → {v:.3f}")

            if adj.get("emission_strength") is not None:
                v = max(8.0, float(adj["emission_strength"]))
                params["material"]["emission_strength"] = v
                print(f"    emission_strength → {v:.1f}")

            if adj.get("rim_R_energy") is not None:
                raw = float(adj["rim_R_energy"])
                # Geminiが誤スケール値(< 200)を返した場合は無視して現在値を維持
                if raw >= 200:
                    v = max(500.0, min(5000.0, raw))
                    params["lighting"]["rim_R_energy"] = v
                    print(f"    rim_R_energy      → {v:.0f}W")
                else:
                    print(f"    rim_R_energy      → skip (raw={raw} < 200W, 現在値維持)")

            if adj.get("fill_energy") is not None:
                raw = float(adj["fill_energy"])
                # fill はハイコントラストのため 15〜60W に制限
                if raw >= 15:
                    v = max(15.0, min(60.0, raw))
                    params["lighting"]["fill_energy"] = v
                    print(f"    fill_energy       → {v:.0f}W")
                else:
                    print(f"    fill_energy       → skip (raw={raw} < 15W)")

    # ── 最終結果 ─────────────────────────────────────────────────────────
    print(f"\n{'='*60}")
    print(f"  BUILD COMPLETE  最終スコア: {best_score}/10")
    print(f"  出力: {OUTPUT_PNG}")
    if best_png and os.path.exists(best_png):
        print(f"  ベスト: {best_png}")
    print(f"{'='*60}")

    if best_score < 8:
        print(f"\n  [INFO] スコア {best_score}/10 - 8点未満のまま終了")
        print(f"  [INFO] 次の改善候補:")
        print(f"    1. muscle_positions の微調整")
        print(f"    2. 楕円体スケールの見直し")
        print(f"    3. カメラアングルの変更")


if __name__ == "__main__":
    main()
