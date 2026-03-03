"""
build_anatomy_model.py
======================
解剖学グレードの筋肉モデルを自律的に構築・品質検証するスクリプト。

フロー:
  1. Geminiに EEVEE / マテリアル / 照明パラメータを諮問
  2. 諮問結果を muscle_heatmap.blend.py に反映
  3. Blender ヘッドレスレンダリング実行
  4. Gemini Vision で品質評価（1〜10点）
  5. 8点未満なら改善パラメータを受け取り再レンダ（最大3回）
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

# ── パス定義 ─────────────────────────────────────────────────────────────────
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
BACKEND_DIR  = os.path.dirname(SCRIPT_DIR)
BLEND_SCRIPT = os.path.join(SCRIPT_DIR, "muscle_heatmap.blend.py")
RENDERS_DIR  = os.path.join(BACKEND_DIR, "renders")
OUTPUT_PNG   = os.path.join(RENDERS_DIR, "satoshi_anatomy.png")

os.makedirs(RENDERS_DIR, exist_ok=True)

# サトシさんの実績（BIG3 115/140/160kg）ベースの強度
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
}

# Blender 候補パス
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


# ── 1. Gemini パラメータ諮問 ─────────────────────────────────────────────────
def consult_gemini_for_params() -> dict:
    print("\n[Gemini諮問] レンダリングパラメータを要求中...")
    prompt = """
あなたはBlender 5.0 Cyclesレンダラーとプロの解剖学3Dアートの専門家です。
Shutterstockレベルの解剖学的筋肉ヒートマップをBlender Cyclesで作成するための
最適なパラメータをJSON形式で返してください。

レンダラー: Cycles + OIDN デノイザー（EEVEEではありません）
条件:
- 背景: 漆黒 (0,0,0)
- 高強度筋肉: マグマ内部発光 (Emission + SSS物理散乱融合)
  → CyclesのSSSは物理的に正確なので、低強度でもエッジに赤い透過光が出る
- 低強度筋肉: ネイビー・クリスタル感（Roughness低め、Specular高め）
- 筋線維テクスチャ: Base Colorに直接縞模様を注入済み（照明非依存）
- バンプマップ: Bump強度でさらに立体感を追加
- ボディビルコンテスト7点照明:
  Keyライト（温色・強め）/ Fillライト（冷色・弱め）
  Rim×2（輪郭を鮮明に）/ Top（頭頂から）/ Graze×2（側面かすめ角でバンプ強調）

以下のJSONスキーマを厳密に守って返してください（コードブロック不要、JSONのみ）:
{
  "material": {
    "sss_base": <float 0.15-0.30>,
    "sss_multiplier": <float 0.15-0.28>,
    "roughness": <float 0.20-0.40>,
    "specular": <float 0.45-0.75>,
    "bump_strength": <float 0.45-0.80>,
    "fiber_distortion": <float 1.5-3.5>,
    "emission_threshold": <float 0.20-0.40>,
    "emission_strength": <float 6.0-12.0>
  },
  "lighting": {
    "key_energy": <float 400-900>,
    "key_color": [<r 0.9-1.0>, <g 0.75-0.95>, <b 0.55-0.80>],
    "fill_energy": <float 50-160>,
    "fill_color": [<r 0.5-0.8>, <g 0.7-0.9>, <b 0.9-1.0>],
    "rim_R_energy": <float 1200-2800>,
    "rim_L_energy": <float 800-2000>,
    "top_energy": <float 150-450>
  },
  "reasoning": "<100文字以内の理由>"
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


# ── 2. Blender レンダリング ───────────────────────────────────────────────────
def run_blender_render(params: dict) -> bool:
    blender = find_blender()
    if not blender:
        print("[ERROR] Blenderが見つかりません")
        return False

    # JSON 入力ファイルを生成（v5.1: 1024×2048 高解像度）
    input_data = {
        "intensities": SATOSHI_INTENSITIES,
        "output_path": OUTPUT_PNG,
        "resolution_x": 1024,
        "resolution_y": 2048,
        "render_params": params,
    }
    json_path = os.path.join(RENDERS_DIR, "anatomy_input.json")
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
        timeout=900,  # Cycles CPU レンダーのため延長（v5.0）
    )
    elapsed = time.time() - t0
    log = proc.stdout.decode("utf-8", errors="replace")

    # ログ出力（重要行のみ）
    for line in log.splitlines():
        if any(k in line for k in ["===", ">>>", "ERROR", "WARN", "[1/", "[2/", "[3/", "[4/", "[5/", "[6/", "[7/", "Render"]):
            print(f"  {line}")

    print(f"  完了: {elapsed:.1f}秒  (exit={proc.returncode})")
    return os.path.exists(OUTPUT_PNG)


# ── 3. Gemini Vision 品質評価 ────────────────────────────────────────────────
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
この画像は Blender Cycles + OIDN デノイザーでレンダリングした解剖学的筋肉ヒートマップです。
筋線維テクスチャはBase Colorに直接注入（縞模様として常に視認可能）。
物理ベースSSS（エッジでの光透過）とEmission（高強度筋肉のマグマ発光）を実装。

Shutterstockレベルの解剖学図として以下を評価してください：

評価基準（合計スコア10点、各2点）:
1. 解剖学的正確さ - 筋肉の形状・位置・比率は正確か
2. 筋線維テクスチャ - 縞模様・バンドル構造・線維走行が視認できるか
3. SSS/発光表現 - 生体組織感（半透明エッジ）とマグマ発光の一体感
4. 照明・コントラスト - ドラマチックなスタジオ照明・筋肉の輪郭の鮮明さ
5. 全体ビジュアルインパクト - Shutterstockに掲載できるレベルか

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
    "ao_factor": <float or null>
  },
  "comment": "<100文字以内の総評>"
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


# ── 4. メインループ ───────────────────────────────────────────────────────────
def main():
    print("=" * 60)
    print("  Anatomy Grade Muscle Model - Autonomous Build Pipeline")
    print("=" * 60)

    # Step 1: Gemini諮問
    params = consult_gemini_for_params()

    best_score = 0
    max_iterations = 3

    for iteration in range(1, max_iterations + 1):
        print(f"\n{'='*60}")
        print(f"  ITERATION {iteration}/{max_iterations}")
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
        score = eval_result.get("score", 0)
        best_score = max(best_score, score)

        print(f"\n  ── Gemini品質評価 ──────────────────────────────────")
        print(f"  総合スコア: {score}/10  {'[PASS ✓]' if eval_result.get('pass') else '[改善要]'}")
        print(f"  解剖学:  {eval_result.get('anatomy_score', '-')}/10")
        print(f"  テクスチャ: {eval_result.get('texture_score', '-')}/10")
        print(f"  照明:    {eval_result.get('lighting_score', '-')}/10")
        print(f"  総評: {eval_result.get('comment', '')}")

        strengths = eval_result.get("strengths", [])
        if strengths:
            print("  [+] Good:")
            for s in strengths:
                print(f"    + {s}")

        improvements = eval_result.get("improvements", [])
        if improvements:
            print("  [-] Improve:")
            for imp in improvements:
                print(f"    > {imp}")

        # 合格判定
        if eval_result.get("pass"):
            print(f"\n  >>> 品質合格! スコア {score}/10 達成")
            break

        # パラメータ調整（次イテレーション用）
        adjustments = eval_result.get("blender_params_to_adjust", {})
        if adjustments and iteration < max_iterations:
            print(f"\n  パラメータ調整中...")
            if "material" not in params:
                params["material"] = {}
            if "lighting" not in params:
                params["lighting"] = {}
            if adjustments.get("bump_strength"):
                params["material"]["bump_strength"] = adjustments["bump_strength"]
                print(f"    bump_strength → {adjustments['bump_strength']}")
            if adjustments.get("emission_strength"):
                params["material"]["emission_strength"] = adjustments["emission_strength"]
                print(f"    emission_strength → {adjustments['emission_strength']}")
            if adjustments.get("rim_R_energy"):
                params["lighting"]["rim_R_energy"] = adjustments["rim_R_energy"]
                print(f"    rim_R_energy → {adjustments['rim_R_energy']}")
            if adjustments.get("ao_factor"):
                if "eevee" not in params:
                    params["eevee"] = {}
                # ao_factor は最低 1.5 を保証（0.2 など低すぎる値を弾く）
                safe_ao = max(1.5, float(adjustments["ao_factor"]))
                params["eevee"]["ao_factor"] = safe_ao
                print(f"    ao_factor → {safe_ao}")

    # 最終結果
    print(f"\n{'='*60}")
    print(f"  BUILD COMPLETE  最終スコア: {best_score}/10")
    print(f"  出力: {OUTPUT_PNG}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
