"""
総挙上重量エンタメ変換サービス
Gemini と相談して決めた10段階の比較対象を使い、
ワクワクするメッセージを生成する
"""
from __future__ import annotations
from dataclasses import dataclass


@dataclass
class Comparison:
    name_ja: str
    name_en: str
    weight_kg: float
    unit_ja: str
    template: str   # {n} に数値が入る


# Gemini が提案した比較対象 (小 → 大 順)
COMPARISONS: list[Comparison] = [
    Comparison("ダンベル",               "Dumbbell",         10.0,       "個",  "ダンベル {n:.0f} 個分を持ち上げた！"),
    Comparison("冷蔵庫",                 "Refrigerator",     80.0,       "台",  "冷蔵庫 {n:.1f} 台分を動かす力！"),
    Comparison("グランドピアノ",           "Grand Piano",      300.0,      "台",  "グランドピアノ {n:.1f} 台分の優雅な重さ！"),
    Comparison("サラブレッド",            "Thoroughbred",     500.0,      "頭",  "サラブレッド {n:.1f} 頭分のパワーを発揮！"),
    Comparison("VWビートル",             "VW Beetle",        800.0,      "台",  "往年の名車ビートル {n:.1f} 台を持ち上げる腕力！"),
    Comparison("シロナガスクジラの舌",     "Blue Whale Tongue", 2700.0,   "個",  "クジラの舌 {n:.1f} 個分…想像を絶する怪力！"),
    Comparison("アフリカゾウ",            "African Elephant", 6000.0,     "頭",  "アフリカゾウ {n:.2f} 頭を持ち上げる怪力！"),
    Comparison("ファルコン9ロケット",      "Falcon 9",         549054.0,   "基",  "ファルコン9 を {n:.4f} 基打ち上げる推力！"),
    Comparison("スペースシャトル",         "Space Shuttle",    78000.0,    "機",  "スペースシャトル {n:.3f} 機分の重さを支えた！"),
    Comparison("自由の女神",              "Statue of Liberty", 204000.0,  "体",  "自由の女神 {n:.4f} 体分の重りを持ち上げた！"),
]


def pick_comparison(total_kg: float) -> Comparison:
    """
    総重量に最もフィットする比較対象を選ぶ。
    「n ≥ 0.5 を満たす比較の中で、最も重い（大きな）比較対象」を選択。
    → 「ゾウ1.9頭」>「スペースシャトル0.15機」のような直感的な表現を優先。
    """
    # n ≥ 0.5 かつ ≤ 200 の候補を探す
    candidates = [
        comp for comp in COMPARISONS
        if 0.5 <= total_kg / comp.weight_kg <= 200
    ]
    if candidates:
        # その中で最も重い比較対象（= n が最小 = スケールが大きい）を返す
        return max(candidates, key=lambda c: c.weight_kg)

    # 0.5 未満しかない場合は 0.05 以上で最大スケールを返す
    fallback = [
        comp for comp in COMPARISONS
        if 0.05 <= total_kg / comp.weight_kg
    ]
    return max(fallback, key=lambda c: c.weight_kg) if fallback else COMPARISONS[0]


def build_entertainment_result(total_kg: float) -> dict:
    """
    総挙上重量 (kg) を受け取り、エンタメ変換結果を返す。

    返り値:
        total_kg       : 合計重量
        comparison_name: 比較対象名（日本語）
        n              : 何個/頭/基分か
        unit           : 単位
        message        : 表示メッセージ
        grade          : パワーグレード ("Beast" / "Monster" / "Hero" / "Warrior")
    """
    comp = pick_comparison(total_kg)
    n = total_kg / comp.weight_kg
    message = comp.template.format(n=n)

    if total_kg >= 10000:
        grade, grade_color = "BEAST MODE", "#FF1744"
    elif total_kg >= 6000:
        grade, grade_color = "MONSTER", "#FF6D00"
    elif total_kg >= 3000:
        grade, grade_color = "HERO", "#FFD600"
    else:
        grade, grade_color = "WARRIOR", "#69F0AE"

    return {
        "total_kg": round(total_kg, 1),
        "comparison_name": comp.name_ja,
        "comparison_name_en": comp.name_en,
        "n": round(n, 4),
        "unit": comp.unit_ja,
        "message": message,
        "grade": grade,
        "grade_color": grade_color,
    }
