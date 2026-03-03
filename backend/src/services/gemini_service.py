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

    if req.target_muscles:
        muscles_str = "、".join(req.target_muscles)
        target_str = f"\n- 今日のターゲット筋群: {muscles_str}（このセッションはこれらの筋群を重点的に鍛えること）"
    else:
        target_str = ""

    effective_min = req.session_duration_minutes - 10  # ウォームアップ/クールダウン各5分
    effective_sec = effective_min * 60

    # days_per_week に応じてセッション数ルールを動的に生成
    _all_days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    if req.days_per_week == 1:
        session_rule = "- weekly_schedule の要素は1つのみ（単一セッション）"
        days_info = f"セッション予定時間: {req.session_duration_minutes}分（実質トレーニング時間: {effective_min}分）"
    else:
        _days = _all_days[: req.days_per_week]
        _days_str = "、".join(_days)
        session_rule = (
            f"- weekly_schedule には必ず {req.days_per_week} 日分のセッションを含めること（要素数={req.days_per_week}）\n"
            f"- 使用する曜日（この順番で）: {_days_str}\n"
            f"- 各セッションは異なる筋群を中心に構成すること（例: プッシュ日/プル日/レッグ日/全身日 など）\n"
            f"- 同じ曜日を2回使ってはいけない"
        )
        days_info = (
            f"週 {req.days_per_week} 日トレーニング / "
            f"1セッションあたり {req.session_duration_minutes}分（実質 {effective_min}分）"
        )

    return f"""
あなたはプロのパーソナルトレーナーです。
以下の条件に基づき、最適な週間筋トレプランをJSON形式で生成してください。

【ユーザー情報】
- {age_str}レベル: {req.level.value}
- 目標: {req.goal.value}
- {days_info}
- 使用可能な器具: {equipment_str}{target_str}{notes_str}
{weight_block}

【休憩時間の設定基準（各種文献に基づく推奨値）】
各種目の rest_seconds は以下を根拠に最適値を設定してください：

1. コンパウンド種目（多関節・大重量）→ 180秒
   対象: ベンチプレス、スクワット、デッドリフト、ショルダープレス、
         ベントオーバーロウ、チンアップ、ディップス、ラットプルダウン、
         レッグプレス、ルーマニアンデッドリフトなど
   根拠: NSCA・ACSM推奨（2〜5分）。神経系とPCr（クレアチンリン酸）の完全回復に必要。

2. 大筋群アイソレーション（背中・脚）→ 120秒
   対象: レッグエクステンション、レッグカール、シーテッドロウ、
         ケーブルロウ、ヒップスラスト、カーフレイズなど
   根拠: Willardson & Burkett (2006)。大筋群は局所的疲労の回復に要時間。

3. 中筋群アイソレーション（胸・肩）→ 90秒
   対象: ダンベルフライ、ペックデック、サイドレイズ、リアデルトなど
   根拠: NSCA「筋肥大目的では1〜2分が最適」。

4. 小筋群アイソレーション（上腕・体幹）→ 60〜75秒
   対象: バイセップカール、トライセップスプッシュダウン、クランチ、
         ハンマーカール、フェイスプルなど
   根拠: Schoenfeld et al. (2016)「小筋群は60秒で十分な回復が可能」。

5. 減量・持久力目的の場合: 全体的に30〜60秒短縮可（NSCAガイドライン）

【時間最適化の必須ルール（厳守）】
- 1セッション = ウォームアップ5分 + トレーニング{effective_min}分 + クールダウン5分（計{req.session_duration_minutes}分）
- 1セッションの実質トレーニング時間 = {effective_sec}秒
- 1セット実施時間の目安: 約45秒（セット間を除く）
- 各セッションの全種目・全セットの合計所要時間 ≦ {effective_sec}秒 になるよう種目数・セット数を調整すること
- 計算例: コンパウンド3種目×4セット → (45+180)×12 = 2700秒(45分)。余り時間でアイソレーションを追加。
- 時間内に収まらない場合はセット数を減らし、種目を厳選すること

【出力形式】必ず以下のJSONスキーマに完全に従ってください。
余分なテキスト・説明・コードブロックは一切不要です。JSONのみを返してください。

{GEMINI_JSON_SCHEMA}

【重要なルール】
{session_rule}
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
