"""
アドバイス生成サービス（計画書 v5 + AI 提案フェーズ Step D）

- 純ルールベース。外部 AI 不使用。コスト 0
- knowledge/summaries/ のテーマ MD と calculated values から個別カードを生成
- 入力は永続化しない（呼び出し元で破棄）
"""
from __future__ import annotations

from typing import List, Optional

from src.schemas.advice import (
    AdviceCard,
    AdviceCategory,
    AdviceResponse,
    AdviceSeverity,
)
from src.schemas.log import SessionLog
from src.schemas.workout import (
    Equipment,
    Goal,
    InjurySeverity,
    Level,
    MuscleGroup,
    PriorityLift,
    WorkoutRequest,
)
from src.services.protein_calculator import (
    calculate_caffeine_dose_mg,
    calculate_protein,
)


# ── カード生成ロジック ──────────────────────────────────────────────────────

def _card_protein(req: WorkoutRequest) -> Optional[AdviceCard]:
    plan = calculate_protein(req.body_weight_kg, age=req.age)
    if plan is None:
        return None
    body = plan.summary_ja()
    body += " 卵黄ありの全卵・牛乳・ホエイなど完全タンパクを優先。"
    return AdviceCard(
        card_id="protein_intake_v1",
        category=AdviceCategory.PROTEIN_INTAKE,
        title="今日のタンパク質目安",
        body=body,
        numeric_targets={
            "daily_min_g": float(plan.daily_min_g),
            "daily_max_g": float(plan.daily_max_g),
            "per_meal_min_g": float(plan.per_meal_min_g),
            "per_meal_max_g": float(plan.per_meal_max_g),
            "post_workout_g": float(plan.post_workout_g),
            "meals_per_day": float(plan.meals_per_day),
        },
        evidence_refs=[
            "theme_protein_nutrition",
            "jager_2017_issn_protein",
        ],
        severity=AdviceSeverity.TIP,
    )


def _card_fat(req: WorkoutRequest) -> Optional[AdviceCard]:
    if req.goal != Goal.MUSCLE_GAIN:
        return None
    return AdviceCard(
        card_id="fat_balance_v1",
        category=AdviceCategory.FAT_BALANCE,
        title="脂質も削りすぎない",
        body=(
            "総エネルギーの 20〜35% を脂質から確保すると、"
            "テストステロンを健全な範囲に保ちやすくなります。"
            "極端な低脂肪は避けましょう。"
        ),
        numeric_targets={
            "fat_energy_pct_min": 20.0,
            "fat_energy_pct_max": 35.0,
        },
        evidence_refs=["theme_fat_testosterone"],
        severity=AdviceSeverity.TIP,
    )


def _card_caffeine(req: WorkoutRequest) -> Optional[AdviceCard]:
    dose = calculate_caffeine_dose_mg(req.body_weight_kg)
    hour = req.session_hour
    # 19 時以降は睡眠への影響を懸念し、注意トーンに切替
    is_evening = hour is not None and hour >= 19
    is_morning = hour is not None and hour <= 10

    if dose is None:
        if is_evening:
            return AdviceCard(
                card_id="caffeine_timing_v1",
                category=AdviceCategory.CAFFEINE_TIMING,
                title="夜のカフェインは避けたい",
                body=(
                    "夜のセッションでは、睡眠の質低下が肥大・回復を阻害します。"
                    "カフェインは控えるか、極少量（1〜2 mg/kg）に留めるのが安全です。"
                ),
                numeric_targets={},
                evidence_refs=["theme_caffeine"],
                severity=AdviceSeverity.WARNING,
            )
        return AdviceCard(
            card_id="caffeine_timing_v1",
            category=AdviceCategory.CAFFEINE_TIMING,
            title="カフェインのコツ",
            body=(
                "運動 30〜60 分前のカフェインは持久・スプリットに有効。"
                "個人差が大きいため初回は控えめから。就寝近くは避ける。"
            ),
            numeric_targets={},
            evidence_refs=["theme_caffeine"],
            severity=AdviceSeverity.INFO,
        )

    if is_evening:
        body = (
            f"夜（{hour}時）のセッションではカフェインの覚醒効果が睡眠を妨げ、"
            "回復・筋肥大を阻害する恐れがあります。"
            f"摂取するなら少量（{int(dose['starter_mg'] / 2)} mg 以下）に抑えるか、"
            "見送るのが無難です。"
        )
        severity = AdviceSeverity.WARNING
        title = "夜セッション: カフェインは控えめに"
    elif is_morning:
        body = (
            f"朝（{hour}時）のセッションは目覚めも兼ねてカフェインが有効。"
            f"運動 {dose['timing_min_before']}〜{dose['timing_max_before']} 分前に "
            f"{dose['standard_mg']} mg（コーヒー約 {dose['standard_coffee_cups']} 杯）が標準。"
            f"初めての場合は {dose['starter_mg']} mg（約 {dose['starter_coffee_cups']} 杯）から。"
        )
        severity = AdviceSeverity.TIP
        title = "朝セッション: カフェインを活用"
    else:
        body = (
            f"運動 {dose['timing_min_before']}〜{dose['timing_max_before']} 分前に "
            f"{dose['standard_mg']} mg（コーヒー約 {dose['standard_coffee_cups']} 杯）が標準。"
            f"初めての場合は {dose['starter_mg']} mg（約 {dose['starter_coffee_cups']} 杯）から。"
            " 就寝近くは避けてください。"
        )
        severity = AdviceSeverity.TIP
        title = "今日のカフェイン量"

    return AdviceCard(
        card_id="caffeine_timing_v1",
        category=AdviceCategory.CAFFEINE_TIMING,
        title=title,
        body=body,
        numeric_targets={
            "standard_mg": float(dose["standard_mg"]),
            "starter_mg": float(dose["starter_mg"]),
            "timing_min_before": float(dose["timing_min_before"]),
            "timing_max_before": float(dose["timing_max_before"]),
            "session_hour": float(hour) if hour is not None else -1.0,
        },
        evidence_refs=["theme_caffeine"],
        severity=severity,
    )


def _card_rest(req: WorkoutRequest) -> AdviceCard:
    return AdviceCard(
        card_id="rest_interval_v1",
        category=AdviceCategory.REST_INTERVAL,
        title="セット間休息のめやす",
        body=(
            "コンパウンド種目は 2〜3 分以上、"
            "アイソレーションは 1〜2 分が肥大・筋力ともに最適。"
            "ホルモン狙いの短休息は推奨されません。"
        ),
        numeric_targets={
            "compound_rest_seconds": 180.0,
            "isolation_rest_seconds": 90.0,
        },
        evidence_refs=["theme_rest_intervals"],
        severity=AdviceSeverity.INFO,
    )


def _card_equipment(req: WorkoutRequest) -> Optional[AdviceCard]:
    if req.level != Level.BEGINNER:
        return None
    has_barbell = Equipment.BARBELL in (req.equipment or [])
    if has_barbell:
        body = (
            "未経験者ではフリーウェイトの方が筋力・バランスの伸びが大きい傾向。"
            "ただしフォーム習得を最優先に、軽い重量から始めましょう。"
        )
    else:
        body = (
            "バーベルが使えない場合、ダンベルやマシンでも段階的に伸びます。"
            "フォーム重視で、無理せず種目を選んでください。"
        )
    return AdviceCard(
        card_id="equipment_guidance_v1",
        category=AdviceCategory.EQUIPMENT_GUIDANCE,
        title="初心者の器具選び",
        body=body,
        numeric_targets={},
        evidence_refs=["theme_equipment"],
        severity=AdviceSeverity.TIP,
    )


def _card_big3(req: WorkoutRequest) -> Optional[AdviceCard]:
    if req.priority_lift is None or req.priority_lift == PriorityLift.NONE:
        return None
    lift_label = {
        PriorityLift.BENCH: "ベンチプレス",
        PriorityLift.SQUAT: "スクワット",
        PriorityLift.DEADLIFT: "デッドリフト",
    }.get(req.priority_lift, "BIG3")

    years = req.years_of_training or 0.0
    if years < 1.0:
        # 初心者は線形進行を優先
        body = (
            f"{lift_label} は線形進行が最も効率的な時期です。"
            " 毎セッション +2.5kg で前進し、停滞したら同重量を再挑戦。"
            " ブロック周期化は 6 ヶ月〜1 年継続後に検討してください。"
        )
        increment = 2.5
    elif years < 3.0:
        # 中級者は 4 週ブロック周期化
        body = (
            f"{lift_label} を伸ばす 4 週ブロック周期化を推奨。"
            " 1 週目: 5×5 @ 75% 1RM（ボリューム）"
            " / 2 週目: 5×3 @ 82.5%（強度）"
            " / 3 週目: 3×2-3 @ 87.5%（ピーク）"
            " / 4 週目: 3×3 @ 65%（デロード）。"
            " 毎セッション増量上限は +2.5〜5kg。"
        )
        increment = 5.0
    else:
        # 上級者向け（>3 年経験）
        body = (
            f"{lift_label} 経験 {years:.0f} 年の上級者は伸び代が小さくなる時期です。"
            " 重量より「動作の質・スピード・代替種目（パウズ・テンポ）」で刺激変化を作り、"
            " デロードは 4〜6 週ごとに必ず挿入。年単位の小さな積み上げで構いません。"
        )
        increment = 2.5
    return AdviceCard(
        card_id="big3_progression_v1",
        category=AdviceCategory.BIG3_PROGRESSION,
        title=f"{lift_label} の伸ばし方",
        body=body,
        numeric_targets={
            "max_compound_increment_kg": increment,
            "block_weeks": 4.0,
            "years_of_training": years,
        },
        evidence_refs=[
            "theme_training_meta_analysis",
            "theme_hypertrophy_mechanisms",
        ],
        severity=AdviceSeverity.TIP,
    )


def _card_volume(req: WorkoutRequest) -> Optional[AdviceCard]:
    if req.goal != Goal.MUSCLE_GAIN:
        return None
    return AdviceCard(
        card_id="volume_target_v1",
        category=AdviceCategory.VOLUME_TARGET,
        title="週あたりのボリューム目安",
        body=(
            "筋肥大は週ボリュームに用量反応的に効きます。"
            "各筋群あたり週 10 セット以上（上限 20 セット程度まで）を目安に、"
            "メインセットは 70〜85% 1RM が無難です。"
        ),
        numeric_targets={
            "weekly_sets_per_muscle_min": 10.0,
            "weekly_sets_per_muscle_max": 20.0,
            "main_intensity_pct_min": 70.0,
            "main_intensity_pct_max": 85.0,
        },
        evidence_refs=[
            "theme_hypertrophy_mechanisms",
            "theme_training_meta_analysis",
        ],
        severity=AdviceSeverity.INFO,
    )


def _card_injury_care(req: WorkoutRequest):
    """怪我履歴がある場合のケア案内"""
    if not req.injury_history:
        return None
    # 重症度別に文言を分岐
    severe_or_moderate = [
        i for i in req.injury_history
        if i.severity in (InjurySeverity.MODERATE, InjurySeverity.SEVERE)
    ]
    mild = [
        i for i in req.injury_history
        if i.severity == InjurySeverity.MILD
    ]
    parts = []
    if severe_or_moderate:
        regions = "・".join({i.region.value for i in severe_or_moderate})
        parts.append(
            f"申告された部位（{regions}）は該当種目を除外しています。"
            " 痛みが続く場合は運動を中止し、医療専門家にご相談ください。"
        )
    if mild:
        regions = "・".join({i.region.value for i in mild})
        parts.append(
            f"軽度の部位（{regions}）は除外していませんが、"
            " 違和感が出たら即座に中止してください。"
        )
    parts.append(
        "可動域運動・有酸素・体幹は痛みのない範囲で継続して問題ありません。"
    )
    return AdviceCard(
        card_id="injury_care_v1",
        category=AdviceCategory.INJURY_CARE,
        title="怪我への配慮",
        body=" ".join(parts),
        numeric_targets={},
        evidence_refs=[],
        severity=AdviceSeverity.WARNING,
    )


def _card_weight_loss_diet(req: WorkoutRequest):
    """減量目的（weight_loss）のときの栄養カード"""
    if req.goal != Goal.WEIGHT_LOSS:
        return None
    body_parts = [
        "減量中はカロリー赤字を作りつつ、筋量維持のためタンパク質量を確保するのが鍵。",
        "1.6〜2.2 g/kg/日のタンパク質（筋肥大目安と同等以上）を保ち、",
        "脂質はエネルギー比 20〜30% を下回らないようにします。",
        "週あたり体重の 0.5〜1.0% 減を上限の目安に。",
    ]
    targets = {
        "protein_g_per_kg_min": 1.6,
        "protein_g_per_kg_max": 2.2,
        "fat_energy_pct_min": 20.0,
        "fat_energy_pct_max": 30.0,
        "weekly_loss_pct_max": 1.0,
    }
    if req.body_weight_kg:
        bw = req.body_weight_kg
        targets["weekly_loss_kg_max"] = round(bw * 0.01, 1)
        targets["protein_g_per_day_min"] = int(round(bw * 1.6))
        targets["protein_g_per_day_max"] = int(round(bw * 2.2))
        body_parts.append(
            f"あなたの体重では 1 日 {targets['protein_g_per_day_min']}〜"
            f"{targets['protein_g_per_day_max']} g、"
            f" 週減量上限は約 {targets['weekly_loss_kg_max']} kg が目安です。"
        )
    return AdviceCard(
        card_id="weight_loss_diet_v1",
        category=AdviceCategory.WEIGHT_LOSS_DIET,
        title="減量中の食事ポイント",
        body=" ".join(body_parts),
        numeric_targets=targets,
        evidence_refs=[
            "theme_protein_nutrition",
            "theme_fat_testosterone",
        ],
        severity=AdviceSeverity.TIP,
    )


def _card_muscle_group_focus(req: WorkoutRequest):
    """target_muscles 指定時に部位別の推奨セット数を返す"""
    if not req.target_muscles:
        return None
    # 表示用ラベル
    label_map = {
        MuscleGroup.CHEST: "胸",
        MuscleGroup.BACK: "背中",
        MuscleGroup.SHOULDERS: "肩",
        MuscleGroup.QUADS: "前太腿",
        MuscleGroup.HAMSTRINGS: "ハムストリング",
        MuscleGroup.GLUTES: "臀部",
        MuscleGroup.BICEPS: "二頭",
        MuscleGroup.TRICEPS: "三頭",
        MuscleGroup.CALVES: "ふくらはぎ",
        MuscleGroup.CORE: "体幹",
        MuscleGroup.LOWER_BACK: "腰部",
        MuscleGroup.LEGS: "下半身",
        MuscleGroup.FULL_BODY: "全身",
    }
    targets = req.target_muscles or []
    names = [label_map.get(m, m.value) for m in targets]
    body = (
        f"今日のターゲット: {', '.join(names)}。"
        " 筋肥大狙いなら各筋群あたり週 10〜20 セットが目安。"
        " 同じ筋群を週に分散させ、同日連続は避けてください。"
        " 1 種目 3〜5 セットを基準に組み立てます。"
    )
    return AdviceCard(
        card_id="muscle_group_focus_v1",
        category=AdviceCategory.MUSCLE_GROUP_FOCUS,
        title="ターゲット部位の組み立て方",
        body=body,
        numeric_targets={
            "weekly_sets_per_muscle_min": 10.0,
            "weekly_sets_per_muscle_max": 20.0,
            "sets_per_exercise_min": 3.0,
            "sets_per_exercise_max": 5.0,
        },
        evidence_refs=[
            "theme_hypertrophy_mechanisms",
            "theme_training_meta_analysis",
        ],
        severity=AdviceSeverity.TIP,
    )


def _card_session_trend(session_log):
    """直前 SessionLog から進捗・注意カードを生成。

    入力: SessionLog（任意）。None または None 同等なら None を返す。
    純ルール: 平均 RPE と痛み有無で文言切替。
    """
    if session_log is None or not getattr(session_log, "exercise_logs", None):
        return None
    sets = [s for el in session_log.exercise_logs for s in el.sets]
    if not sets:
        return None

    rpes = [s.rpe for s in sets if getattr(s, "rpe", None) is not None]
    has_pain = any(getattr(s, "pain", False) for s in sets)
    avg_rpe = sum(rpes) / len(rpes) if rpes else None
    max_rpe = max(rpes) if rpes else None

    if has_pain:
        body = (
            "前回セッションで痛みが報告されています。"
            " 今日は無理せず軽い可動域運動と休養を優先し、"
            " 続く場合は医療専門家にご相談ください。"
        )
        severity = AdviceSeverity.WARNING
        title = "前回の痛み報告: 慎重に"
    elif max_rpe is not None and max_rpe >= 9.0:
        body = (
            f"前回 RPE が最大 {max_rpe:.1f} と非常に高く、"
            " 蓄積疲労の兆候です。今日は重量 -10%、ボリューム -30% のデロード推奨。"
        )
        severity = AdviceSeverity.WARNING
        title = "デロード推奨"
    elif avg_rpe is not None and avg_rpe <= 6.5:
        body = (
            f"前回平均 RPE が {avg_rpe:.1f} と余裕あり。"
            " 次回は重量 +2.5kg（コンパウンド）または 1〜2 レップ追加で前進可能。"
        )
        severity = AdviceSeverity.TIP
        title = "余裕あり: 次は前進"
    else:
        body = (
            f"前回平均 RPE は {avg_rpe:.1f if avg_rpe else 'なし'}。"
            " 適切な強度を維持できています。今日もフォーム最優先で。"
        ) if avg_rpe else "前回ログを受領しました。今日もフォーム最優先で。"
        severity = AdviceSeverity.INFO
        title = "前回からの継続"

    return AdviceCard(
        card_id="session_trend_v1",
        category=AdviceCategory.SESSION_TREND,
        title=title,
        body=body,
        numeric_targets={
            "avg_rpe": float(avg_rpe) if avg_rpe is not None else -1.0,
            "max_rpe": float(max_rpe) if max_rpe is not None else -1.0,
            "pain_reported": 1.0 if has_pain else 0.0,
        },
        evidence_refs=["theme_training_meta_analysis"],
        severity=severity,
    )



def _card_safety() -> AdviceCard:
    return AdviceCard(
        card_id="safety_note_v1",
        category=AdviceCategory.SAFETY_NOTE,
        title="medical disclaimer",
        body=(
            "本アプリは情報提供を目的としたフィットネス支援であり、"
            "医療助言・診断・治療を提供するものではありません。"
            " 痛みや違和感がある場合は中止し、医療専門家にご相談ください。"
        ),
        numeric_targets={},
        evidence_refs=[],
        severity=AdviceSeverity.WARNING,
    )


# ── 公開 API ────────────────────────────────────────────────────────────────

def build_advice_response(
    req: WorkoutRequest,
    session_log: Optional[SessionLog] = None,
) -> AdviceResponse:
    """Pure rule-based personalized advice. No external AI."""
    try:
        cards: list = []
        for card in [
            _card_session_trend(session_log),
            _card_injury_care(req),
            _card_protein(req),
            _card_weight_loss_diet(req),
            _card_fat(req),
            _card_volume(req),
            _card_muscle_group_focus(req),
            _card_big3(req),
            _card_rest(req),
            _card_equipment(req),
            _card_caffeine(req),
        ]:
            if card is not None:
                cards.append(card)
        cards.append(_card_safety())
        cards = cards[:12]
        return AdviceResponse(
            success=True,
            cards=cards,
            external_ai_used=False,
        )
    except Exception as e:
        return AdviceResponse(
            success=False,
            cards=[],
            error_message=f"advice failed: {type(e).__name__}",
        )
