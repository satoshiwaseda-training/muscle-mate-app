"""
Gemini API サービス
- response_mime_type="application/json" でJSONを強制
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
)

load_dotenv()

# Gemini クライアント初期化
genai.configure(api_key=os.getenv("GOOGLE_API_KEY"))

MODEL_NAME = "gemini-2.0-flash"


def _build_prompt(req: WorkoutRequest) -> str:
    equipment_str = "、".join([e.value for e in req.equipment])
    age_str = f"{req.age}歳、" if req.age else ""
    notes_str = f"\n特記事項: {req.notes}" if req.notes else ""

    return f"""
あなたはプロのパーソナルトレーナーです。
以下の条件に基づき、最適な週間筋トレメニューをJSON形式で生成してください。

【ユーザー情報】
- {age_str}レベル: {req.level.value}
- 目標: {req.goal.value}
- 週{req.days_per_week}日トレーニング可能
- 使用可能な器具: {equipment_str}{notes_str}

【出力形式】必ず以下のJSONスキーマに完全に従ってください。
余分なテキスト・説明・コードブロックは一切不要です。JSONのみを返してください。

{GEMINI_JSON_SCHEMA}

【重要なルール】
- day_of_week は week の中で重複させないこと
- reps は "8-12" や "30秒" のような文字列で表現すること
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

        # JSON パース
        raw_text = response.text.strip()
        raw_dict = json.loads(raw_text)

        # Pydantic バリデーション（ここで型・値の不整合を検出）
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
