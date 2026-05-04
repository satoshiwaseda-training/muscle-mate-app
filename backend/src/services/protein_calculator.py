"""
タンパク質摂取目安の個別計算（純ルール・コスト 0）

knowledge/summaries/nutrition/theme_protein_nutrition.md の知見を反映:
- 総量 1.4-2.0 g/kg/日
- 1 食 0.25-0.40 g/kg（または 20-40 g）
- 全身トレ後は 0.5 g/kg まで引き上げ可

外部 AI には一切渡さない（計画書 §4.3）。サーバー内のみで使用。
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


# ── 定数（テーマMDと整合）──────────────────────────────────────────────────
DAILY_MIN_G_PER_KG = 1.4
DAILY_MAX_G_PER_KG = 2.0
PER_MEAL_MIN_G_PER_KG = 0.25
PER_MEAL_MAX_G_PER_KG = 0.40
POST_WORKOUT_FULL_BODY_G_PER_KG = 0.5
DEFAULT_MEALS_PER_DAY = 4

# 高齢者向け（>50 歳）は anabolic resistance により上限寄り
ELDERLY_AGE_THRESHOLD = 50


@dataclass(frozen=True)
class ProteinPlan:
    """個別計算結果"""
    daily_min_g: int
    daily_max_g: int
    per_meal_min_g: int
    per_meal_max_g: int
    meals_per_day: int
    post_workout_g: int
    elderly_adjusted: bool

    def summary_ja(self) -> str:
        """設定画面・アドバイス画面向けの 1 行サマリ"""
        if self.elderly_adjusted:
            return (
                f"高齢者は上限寄り推奨。1 日 {self.daily_max_g} g 程度、"
                f"1 食 {self.per_meal_max_g} g、"
                f"運動直後 {self.post_workout_g} g を目安に。"
            )
        return (
            f"1 日 {self.daily_min_g}〜{self.daily_max_g} g、"
            f"1 食 {self.per_meal_min_g}〜{self.per_meal_max_g} g を "
            f"{self.meals_per_day} 食で分配。"
            f"全身トレ直後は {self.post_workout_g} g まで増やしても OK。"
        )


def _round_g(grams: float) -> int:
    """g は 1 g 単位に丸める（小数は不要・実用性重視）"""
    return int(round(grams))


def calculate_protein(
    body_weight_kg: Optional[float],
    age: Optional[int] = None,
    meals_per_day: int = DEFAULT_MEALS_PER_DAY,
) -> Optional[ProteinPlan]:
    """体重と年齢からタンパク質目安を計算する。

    body_weight_kg が None なら計算不可（None を返す）。
    年齢が >= 50 なら上限寄りに調整。
    """
    if body_weight_kg is None or body_weight_kg <= 0:
        return None
    if not (20 <= body_weight_kg <= 300):
        return None  # 異常値を弾く

    elderly = age is not None and age >= ELDERLY_AGE_THRESHOLD

    daily_min = _round_g(body_weight_kg * DAILY_MIN_G_PER_KG)
    daily_max = _round_g(body_weight_kg * DAILY_MAX_G_PER_KG)
    per_meal_min = _round_g(body_weight_kg * PER_MEAL_MIN_G_PER_KG)
    per_meal_max = _round_g(body_weight_kg * PER_MEAL_MAX_G_PER_KG)
    post_workout = _round_g(body_weight_kg * POST_WORKOUT_FULL_BODY_G_PER_KG)

    return ProteinPlan(
        daily_min_g=daily_min,
        daily_max_g=daily_max,
        per_meal_min_g=per_meal_min,
        per_meal_max_g=per_meal_max,
        meals_per_day=meals_per_day,
        post_workout_g=post_workout,
        elderly_adjusted=elderly,
    )


def calculate_caffeine_dose_mg(body_weight_kg: Optional[float]) -> Optional[dict]:
    """5 mg/kg のカフェイン推奨量と 3 mg/kg の初回試行量を返す。

    Hodgson 2013 / Trexler 2016 に基づく。コーヒー杯数換算も含む。
    1 杯約 100 mg（ドリップコーヒー 240ml）として計算。
    """
    if body_weight_kg is None or body_weight_kg <= 0:
        return None
    if not (20 <= body_weight_kg <= 300):
        return None
    standard_mg = int(round(body_weight_kg * 5.0))
    starter_mg = int(round(body_weight_kg * 3.0))
    return {
        "standard_mg": standard_mg,
        "standard_coffee_cups": round(standard_mg / 100.0, 1),
        "starter_mg": starter_mg,
        "starter_coffee_cups": round(starter_mg / 100.0, 1),
        "timing_min_before": 30,
        "timing_max_before": 60,
    }
