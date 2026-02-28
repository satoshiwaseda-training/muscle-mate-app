"""
Gemini API サービス
- response_mime_type="application/json" でJSONを強制
- BIG3 MAXからトレーニング重量を計算してプロンプトに注入
- Pydantic でバリデーションし、AIの解析ミスを物理的に排除
"""
import json
import os
from dotenv import load_dotenv
import google.generativeai as genai
from pydantic import ValidationError

from src.schemas.workout import (
    WorkoutRequest,
    WorkoutPlan,
    WorkoutResponse,
    GEMINI_JSON_SCHEMA,
    INTENSITY_TABLE,
)

load_dotenv()

genai.configure(api_key=os.getenv("GOOGLE_API_KEY"))

MODEL_NAME = "gemini-2.0-flash"


def _calc_training_weights(req: WorkoutRequest) -> str:
    """
    BIG3 MAX から各目標の強度に基づいてトレーニング重量を計算し、
    プロンプトに注入するテキストブロックを生成する。
    """
    big3 = req.big3_max
    if not big3 or not big3.has_any():
        return ""

    intensity = INTENSITY_TABLE.get(req.goal.value, INTENSITY_TABLE["general_fitness"])
    lo, hi = intensity["range"]
    pct = intensity["primary"]

    lines = [
        "",
        "【パーソナライズ情報：BIG3 MAX重量と算出済みトレーニング重量】",
        f"目標「{intensity['label']}」の推奨強度: {lo}〜{hi}% 1RM（メインセット: {pct}%）",
        "",
    ]

    if big3.bench_press_max:
        w = round(big3.bench_press_max * pct / 100 / 2.5) * 2.5  # 2.5kg刻みに丸める
        lines.append(f"・ベンチプレス  1RM: {big3.bench_press_max}kg → メインセット重量: {w}kg")
    if big3.squat_max:
        w = round(big3.squat_max * pct / 100 / 2.5) * 2.5
        lines.append(f"・スクワット    1RM: {big3.squat_max}kg → メインセット重量: {w}kg")
    if big3.deadlift_max:
        w = round(big3.deadlift_max * pct / 100 / 2.5) * 2.5
        lines.append(f"・デッドリフト  1RM: {big3.deadlift_max}kg → メインセット重量: {w}kg")

    lines += [
        "",
        "上記の重量を基準に、メニュー内の対応種目には weight_kg を必ず設定してください。",
        "バリエーション種目（インクラインプレスなど）は元の重量の80〜90%を目安に設定してください。",
        "自重や重量計算ができない種目の weight_kg は null にしてください。",
    ]

    return "\n".join(lines)


def _build_prompt(req: WorkoutRequest) -> str:
    equipment_str = "、".join([e.value for e in req.equipment])
    age_str = f"{req.age}歳、" if req.age else ""
    notes_str = f"\n特記事項: {req.notes}" if req.notes else ""
    weight_block = _calc_training_weights(req)

    return f"""
あなたはプロのパーソナルトレーナーです。
以下の条件に基づき、最適な週間筋トレメニューをJSON形式で生成してください。

【ユーザー情報】
- {age_str}レベル: {req.level.value}
- 目標: {req.goal.value}
- 週{req.days_per_week}日トレーニング可能
- 使用可能な器具: {equipment_str}{notes_str}
{weight_block}

【出力形式】必ず以下のJSONスキーマに完全に従ってください。
余分なテキスト・説明・コードブロックは一切不要です。JSONのみを返してください。

{GEMINI_JSON_SCHEMA}

【重要なルール】
- day_of_week は week の中で重複させないこと
- reps は "8-12" や "30秒" のような文字列で表現すること
- weight_kg: BIG3情報がある場合は上記の算出値を使用。ない場合は null
- coaching_point は具体的で実践的な内容にすること（日本語）
- general_advice には食事・睡眠・回復のアドバイスを含めること（日本語）
- 全てのテキストフィールドは日本語で記述すること（name_en のみ英語）
""".strip()


async def generate_workout_plan(req: WorkoutRequest) -> WorkoutResponse:
    """
    Gemini でワークアウトプランを生成し、Pydantic でバリデーションして返す。
    """
    try:
        model = genai.GenerativeModel(
            model_name=MODEL_NAME,
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",  # JSON出力を強制
                temperature=0.7,
            ),
        )

        prompt = _build_prompt(req)
        response = model.generate_content(prompt)

        raw_text = response.text.strip()
        raw_dict = json.loads(raw_text)

        # Pydantic バリデーション（型・値・構造の不整合を検出）
        plan = WorkoutPlan.model_validate(raw_dict)

        return WorkoutResponse(success=True, plan=plan)

    except json.JSONDecodeError as e:
        return WorkoutResponse(
            success=False,
            error_message=f"AIの出力がJSON形式ではありませんでした: {str(e)}",
        )
    except ValidationError as e:
        return WorkoutResponse(
            success=False,
            error_message=f"AIの出力がスキーマに違反しています: {e.error_count()}件のエラー\n{e.errors(include_url=False)}",
        )
    except Exception as e:
        return WorkoutResponse(
            success=False,
            error_message=f"予期しないエラーが発生しました: {str(e)}",
        )
