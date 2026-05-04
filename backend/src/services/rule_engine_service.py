"""
ルールベースのメニュー生成エンジン（計画書 v5 §6.2 §3.1）

外部 AI を一切使わず、決定論的にメニューを生成するコアサービス。
- プログラム雛形（knowledge/programs/）からスプリットを選択
- BIG3 MAX × INTENSITY_TABLE で重量を算出
- 怪我履歴・痛みフラグから safety_flags / advisory を立てる
- 入力は永続化しない（呼び出し元で破棄）

このモジュールは外部ネットワーク呼び出しを行わない。`/workout/generate` の
`LLM_PROVIDER=noop`（既定）時のメイン実装であり、`groq` 時もスケルトン生成は
本サービスで完結し、文章のみが llm_service で上書きされる。
"""
from __future__ import annotations

from typing import List, Optional, Tuple

from src.schemas.workout import (
    Advisory,
    AdvisoryLevel,
    Big3Max,
    DayOfWeek,
    DaySession,
    Equipment,
    Exercise,
    Goal,
    INTENSITY_TABLE,
    Injury,
    InjurySeverity,
    Level,
    MuscleGroup,
    PriorityLift,
    WorkoutPlan,
    WorkoutRequest,
    WorkoutResponse,
)
from src.services import rag_service
from src.services import history_optimizer
from src.services.protein_calculator import calculate_protein


# ── 雛形カタログ（簡易）────────────────────────────────────────────────────
# 実体の MD は knowledge/programs/ にあるが、ルールエンジンが種目を組み立てる
# 際に参照する「コード上の対応表」をここに持つ。フェーズ 3 で knowledge/ から
# 動的に読み込むよう拡張する。

_DAYS_ORDER: List[DayOfWeek] = [
    DayOfWeek.MONDAY,
    DayOfWeek.TUESDAY,
    DayOfWeek.WEDNESDAY,
    DayOfWeek.THURSDAY,
    DayOfWeek.FRIDAY,
    DayOfWeek.SATURDAY,
    DayOfWeek.SUNDAY,
]


# ── ヘルパー ───────────────────────────────────────────────────────────────

def _round_to_2_5(weight: float) -> float:
    """2.5kg 刻みで丸める"""
    return round(weight / 2.5) * 2.5


def _calc_main_weight(one_rm: Optional[float], pct: float) -> Optional[float]:
    """1RM × % からメインセット重量を算出。1RM が None なら None を返す。"""
    if one_rm is None or one_rm <= 0:
        return None
    return _round_to_2_5(one_rm * pct / 100.0)


def _injured_regions(injuries: Optional[List[Injury]]) -> set[MuscleGroup]:
    """重症度 moderate 以上の部位は完全除外、mild は注意フラグのみ"""
    if not injuries:
        return set()
    return {i.region for i in injuries if i.severity != InjurySeverity.MILD}


def _intensity_for(goal: Goal) -> Tuple[float, str]:
    """目標から %1RM とラベルを取得"""
    info = INTENSITY_TABLE.get(goal.value, INTENSITY_TABLE["general_fitness"])
    return info["primary"], info["label"]


# ── スプリット選択 ──────────────────────────────────────────────────────────

def _choose_split(req: WorkoutRequest) -> str:
    """レベル × 週日数 × 目標 から雛形 ID を決定"""
    days = req.days_per_week
    level = req.level
    goal = req.goal
    priority = req.priority_lift or PriorityLift.NONE
    target_muscles = req.target_muscles or []

    # ターゲット筋群指定（最優先）→ 単日フォーカスセッション
    # 選んだ部位だけを集中的に攻める「今日の部位別メニュー」になる
    if target_muscles:
        return "focused_session"

    # BIG3 強化優先
    if priority != PriorityLift.NONE and level != Level.BEGINNER:
        return "strength_block_periodization"

    # 上級者・筋肥大狙いの高頻度
    if level == Level.ADVANCED and goal == Goal.MUSCLE_GAIN and days >= 5:
        return "advanced_ppl_hypertrophy"

    # 中級者の Upper/Lower
    if level == Level.INTERMEDIATE and days == 4:
        return "intermediate_upper_lower"

    # 既定: 初心者または週 ≤ 3 日
    return "beginner_full_body"


# ── 部位別の種目プール（target_muscles からフォーカスセッションを組む） ─────

def _normalize_targets(target_muscles: List[MuscleGroup]) -> set[MuscleGroup]:
    """ユーザー指定の筋群を正規化する。
    LEGS が指定されたら QUADS / HAMSTRINGS / GLUTES / CALVES もカバー対象に追加。
    FULL_BODY が指定されたらほぼ全部位を対象にする。
    """
    s: set[MuscleGroup] = set(target_muscles)
    if MuscleGroup.LEGS in s:
        s.update({
            MuscleGroup.QUADS, MuscleGroup.HAMSTRINGS,
            MuscleGroup.GLUTES, MuscleGroup.CALVES,
        })
    if MuscleGroup.FULL_BODY in s:
        s.update({
            MuscleGroup.CHEST, MuscleGroup.BACK, MuscleGroup.SHOULDERS,
            MuscleGroup.QUADS, MuscleGroup.HAMSTRINGS, MuscleGroup.GLUTES,
            MuscleGroup.BICEPS, MuscleGroup.TRICEPS, MuscleGroup.CORE,
        })
    return s


def _exercise_pool(big3: Optional[Big3Max], pct: float) -> List[Exercise]:
    """すべての種目プール。各種目の target_muscles で後から絞り込む。"""
    bench_w = _calc_main_weight(big3.bench_press_max if big3 else None, pct)
    squat_w = _calc_main_weight(big3.squat_max if big3 else None, pct)
    deadlift_w = _calc_main_weight(big3.deadlift_max if big3 else None, pct)
    rdl_w = _calc_main_weight(big3.deadlift_max if big3 else None, pct * 0.85)

    return [
        # ── 胸 ──
        Exercise(
            name_ja="ベンチプレス", name_en="Bench Press",
            sets=4, reps="6-10", rest_seconds=180,
            equipment=Equipment.BARBELL,
            target_muscles=[MuscleGroup.CHEST, MuscleGroup.TRICEPS],
            coaching_point="肩甲骨を寄せ、胸のやや下にバーを下ろす。",
            weight_kg=bench_w,
            progression_rule="linear_+2.5kg",
        ),
        Exercise(
            name_ja="インクラインダンベルプレス", name_en="Incline DB Press",
            sets=3, reps="8-12", rest_seconds=120,
            equipment=Equipment.DUMBBELL,
            target_muscles=[MuscleGroup.CHEST, MuscleGroup.SHOULDERS],
            coaching_point="ベンチ角度 30〜45 度。肩はすくめない。",
        ),
        Exercise(
            name_ja="ダンベルフライ", name_en="Dumbbell Fly",
            sets=3, reps="10-15", rest_seconds=90,
            equipment=Equipment.DUMBBELL,
            target_muscles=[MuscleGroup.CHEST],
            coaching_point="肘は軽く曲げ、胸の伸びを感じる範囲で。",
        ),
        Exercise(
            name_ja="ケーブルクロスオーバー", name_en="Cable Crossover",
            sets=3, reps="12-15", rest_seconds=60,
            equipment=Equipment.CABLE,
            target_muscles=[MuscleGroup.CHEST],
            coaching_point="肩を落として胸の収縮にフォーカス。",
        ),
        # ── 背中 ──
        Exercise(
            name_ja="デッドリフト", name_en="Deadlift",
            sets=3, reps="5", rest_seconds=210,
            equipment=Equipment.BARBELL,
            target_muscles=[
                MuscleGroup.BACK, MuscleGroup.HAMSTRINGS,
                MuscleGroup.GLUTES, MuscleGroup.LOWER_BACK,
            ],
            coaching_point="背中は中立、足全体で床を押す。",
            weight_kg=deadlift_w,
            progression_rule="linear_+2.5kg",
        ),
        Exercise(
            name_ja="ベントオーバーロウ", name_en="Bent-over Row",
            sets=4, reps="6-10", rest_seconds=120,
            equipment=Equipment.BARBELL,
            target_muscles=[MuscleGroup.BACK, MuscleGroup.BICEPS],
            coaching_point="背中はニュートラル、肘を後方に引く。",
        ),
        Exercise(
            name_ja="ラットプルダウン", name_en="Lat Pulldown",
            sets=3, reps="8-12", rest_seconds=90,
            equipment=Equipment.MACHINE,
            target_muscles=[MuscleGroup.BACK],
            coaching_point="肩甲骨の下制を意識し、胸に向かって引く。",
        ),
        Exercise(
            name_ja="シーテッドロウ", name_en="Seated Cable Row",
            sets=3, reps="10-12", rest_seconds=90,
            equipment=Equipment.CABLE,
            target_muscles=[MuscleGroup.BACK, MuscleGroup.BICEPS],
            coaching_point="肘を体側を通すように引く。",
        ),
        # ── 肩 ──
        Exercise(
            name_ja="オーバーヘッドプレス", name_en="Overhead Press",
            sets=4, reps="6-10", rest_seconds=150,
            equipment=Equipment.BARBELL,
            target_muscles=[MuscleGroup.SHOULDERS, MuscleGroup.TRICEPS],
            coaching_point="体幹を固め、頭上にロックアウト。",
        ),
        Exercise(
            name_ja="サイドレイズ", name_en="Side Lateral Raise",
            sets=3, reps="12-15", rest_seconds=60,
            equipment=Equipment.DUMBBELL,
            target_muscles=[MuscleGroup.SHOULDERS],
            coaching_point="肘を主導に挙げ、頂点で小指がやや上。",
        ),
        Exercise(
            name_ja="フェイスプル", name_en="Face Pull",
            sets=3, reps="12-15", rest_seconds=60,
            equipment=Equipment.CABLE,
            target_muscles=[MuscleGroup.SHOULDERS, MuscleGroup.BACK],
            coaching_point="肘を高く保ち、外旋を意識。",
        ),
        Exercise(
            name_ja="リアレイズ", name_en="Rear Delt Raise",
            sets=3, reps="12-15", rest_seconds=60,
            equipment=Equipment.DUMBBELL,
            target_muscles=[MuscleGroup.SHOULDERS, MuscleGroup.BACK],
            coaching_point="肩甲骨を寄せず、後部三角筋で挙げる。",
        ),
        # ── 脚（クアッド・ハム・尻・カーフ）──
        Exercise(
            name_ja="スクワット", name_en="Barbell Squat",
            sets=4, reps="6-10", rest_seconds=180,
            equipment=Equipment.BARBELL,
            target_muscles=[MuscleGroup.QUADS, MuscleGroup.GLUTES],
            coaching_point="重心は土踏まず、深くしゃがむ。",
            weight_kg=squat_w,
            progression_rule="linear_+2.5kg",
        ),
        Exercise(
            name_ja="ルーマニアンデッドリフト", name_en="Romanian Deadlift",
            sets=4, reps="6-10", rest_seconds=150,
            equipment=Equipment.BARBELL,
            target_muscles=[
                MuscleGroup.HAMSTRINGS, MuscleGroup.GLUTES,
                MuscleGroup.LOWER_BACK,
            ],
            coaching_point="股関節を後ろに引き、背中は中立。",
            weight_kg=rdl_w,
        ),
        Exercise(
            name_ja="レッグプレス", name_en="Leg Press",
            sets=3, reps="10-12", rest_seconds=120,
            equipment=Equipment.MACHINE,
            target_muscles=[MuscleGroup.QUADS, MuscleGroup.GLUTES],
            coaching_point="膝を完全にロックしない。",
        ),
        Exercise(
            name_ja="レッグカール", name_en="Leg Curl",
            sets=3, reps="10-12", rest_seconds=90,
            equipment=Equipment.MACHINE,
            target_muscles=[MuscleGroup.HAMSTRINGS],
            coaching_point="可動域全体を使う。",
        ),
        Exercise(
            name_ja="レッグエクステンション", name_en="Leg Extension",
            sets=3, reps="10-15", rest_seconds=90,
            equipment=Equipment.MACHINE,
            target_muscles=[MuscleGroup.QUADS],
            coaching_point="頂点で 1 秒静止し、四頭筋を絞る。",
        ),
        Exercise(
            name_ja="ヒップスラスト", name_en="Hip Thrust",
            sets=3, reps="8-12", rest_seconds=120,
            equipment=Equipment.BARBELL,
            target_muscles=[MuscleGroup.GLUTES, MuscleGroup.HAMSTRINGS],
            coaching_point="頂点で臀部を強く絞る。",
        ),
        Exercise(
            name_ja="カーフレイズ", name_en="Calf Raise",
            sets=3, reps="12-15", rest_seconds=60,
            equipment=Equipment.MACHINE,
            target_muscles=[MuscleGroup.CALVES],
            coaching_point="頂点で 1 秒静止。",
        ),
        # ── 二頭・三頭 ──
        Exercise(
            name_ja="バーベルカール", name_en="Barbell Curl",
            sets=3, reps="8-12", rest_seconds=60,
            equipment=Equipment.BARBELL,
            target_muscles=[MuscleGroup.BICEPS],
            coaching_point="肘を体側に固定する。",
        ),
        Exercise(
            name_ja="ハンマーカール", name_en="Hammer Curl",
            sets=3, reps="10-12", rest_seconds=60,
            equipment=Equipment.DUMBBELL,
            target_muscles=[MuscleGroup.BICEPS],
            coaching_point="親指を上に向けたまま挙げる。",
        ),
        Exercise(
            name_ja="トライセプスプッシュダウン", name_en="Triceps Pushdown",
            sets=3, reps="10-15", rest_seconds=60,
            equipment=Equipment.CABLE,
            target_muscles=[MuscleGroup.TRICEPS],
            coaching_point="肘の位置を固定する。",
        ),
        Exercise(
            name_ja="ダンベルフレンチプレス", name_en="DB French Press",
            sets=3, reps="10-12", rest_seconds=60,
            equipment=Equipment.DUMBBELL,
            target_muscles=[MuscleGroup.TRICEPS],
            coaching_point="肘を耳の横で固定し、肘から下だけ動かす。",
        ),
        # ── 体幹 ──
        Exercise(
            name_ja="プランク", name_en="Plank",
            sets=3, reps="30-60秒", rest_seconds=60,
            equipment=Equipment.BODYWEIGHT,
            target_muscles=[MuscleGroup.CORE],
            coaching_point="腰を反らさず一直線をキープ。",
        ),
        Exercise(
            name_ja="ハンギングレッグレイズ", name_en="Hanging Leg Raise",
            sets=3, reps="8-12", rest_seconds=90,
            equipment=Equipment.BODYWEIGHT,
            target_muscles=[MuscleGroup.CORE],
            coaching_point="反動を使わずに腹筋で引き上げる。",
        ),
    ]


def _build_focused_schedule(
    req: WorkoutRequest, pct: float, excluded: set[MuscleGroup]
) -> List[DaySession]:
    """target_muscles に応じた単日フォーカスセッションを組み立てる。

    - その日に集中して攻めたい部位の種目だけを選ぶ
    - 怪我履歴で除外された部位を含む種目は除く
    - 利用可能な器具のみフィルタ
    """
    targets = _normalize_targets(req.target_muscles or [])
    if not targets:
        return []

    pool = _exercise_pool(req.big3_max, pct)
    available_eq = set(req.equipment)

    # 1. 怪我除外
    pool = [e for e in pool if not (set(e.target_muscles) & excluded)]
    # 2. 器具絞り込み
    pool = [e for e in pool if e.equipment in available_eq]
    # 3. ターゲット筋群と一致する種目のみ
    matched = [e for e in pool if any(m in targets for m in e.target_muscles)]

    if not matched:
        return []

    # コンパウンド優先で並び替え（rest_seconds が大きい = 高負荷種目を先に）
    matched.sort(key=lambda e: -e.rest_seconds)

    # セッション時間に応じて種目数を調整（1 種目あたり約 8 分換算）
    avg_time_per_exercise = 8
    max_exercises = max(3, min(8, req.session_duration_minutes // avg_time_per_exercise))
    selected = matched[:max_exercises]

    # 「今日のセッション」として 1 日分の DaySession を返す
    # 曜日は便宜的に MONDAY を使う（UI 上は単日扱い）
    label = _label_targets(targets)
    return [
        DaySession(
            day_of_week=DayOfWeek.MONDAY,
            session_name=f"{label}フォーカス",
            target_muscles=sorted(targets, key=lambda m: m.value)[:6],
            estimated_duration_minutes=min(req.session_duration_minutes, 90),
            exercises=selected,
        )
    ]


def _label_targets(targets: set[MuscleGroup]) -> str:
    """筋群セットを日本語ラベルへ"""
    name_map = {
        MuscleGroup.CHEST: "胸",
        MuscleGroup.BACK: "背中",
        MuscleGroup.LOWER_BACK: "腰部",
        MuscleGroup.SHOULDERS: "肩",
        MuscleGroup.QUADS: "前太腿",
        MuscleGroup.HAMSTRINGS: "ハム",
        MuscleGroup.GLUTES: "臀部",
        MuscleGroup.CALVES: "ふくらはぎ",
        MuscleGroup.BICEPS: "二頭",
        MuscleGroup.TRICEPS: "三頭",
        MuscleGroup.CORE: "体幹",
        MuscleGroup.LEGS: "下半身",
        MuscleGroup.FULL_BODY: "全身",
    }
    parts = [name_map.get(m, m.value) for m in targets if m in name_map]
    if not parts:
        return "全身"
    if len(parts) >= 4:
        return "複合部位"
    return "・".join(parts[:3])


# ── 種目テンプレート（簡易・将来は knowledge/programs/ から動的読込）────────

def _exercises_full_body(big3: Optional[Big3Max], pct: float) -> List[Exercise]:
    bench_w = _calc_main_weight(big3.bench_press_max if big3 else None, pct)
    squat_w = _calc_main_weight(big3.squat_max if big3 else None, pct)
    return [
        Exercise(
            name_ja="スクワット", name_en="Barbell Squat",
            sets=3, reps="5-8", rest_seconds=180,
            equipment=Equipment.BARBELL,
            target_muscles=[MuscleGroup.QUADS, MuscleGroup.GLUTES],
            coaching_point="股関節主導で深くしゃがみ、膝はつま先方向へ。",
            weight_kg=squat_w,
            evidence_refs=[],
            progression_rule="linear_+2.5kg",
        ),
        Exercise(
            name_ja="ベンチプレス", name_en="Bench Press",
            sets=3, reps="5-8", rest_seconds=180,
            equipment=Equipment.BARBELL,
            target_muscles=[MuscleGroup.CHEST, MuscleGroup.TRICEPS],
            coaching_point="肩甲骨を寄せて胸を張り、バーは胸のやや下に下ろす。",
            weight_kg=bench_w,
            evidence_refs=[],
            progression_rule="linear_+2.5kg",
        ),
        Exercise(
            name_ja="ベントオーバーロウ", name_en="Bent-over Row",
            sets=3, reps="6-10", rest_seconds=120,
            equipment=Equipment.BARBELL,
            target_muscles=[MuscleGroup.BACK, MuscleGroup.BICEPS],
            coaching_point="背中はニュートラル、肘を後方に引く。",
            weight_kg=None,
            evidence_refs=[],
            progression_rule="linear_+2.5kg",
        ),
        Exercise(
            name_ja="プランク", name_en="Plank",
            sets=2, reps="30秒", rest_seconds=60,
            equipment=Equipment.BODYWEIGHT,
            target_muscles=[MuscleGroup.CORE],
            coaching_point="腰を反らさず一直線をキープ。",
            weight_kg=None,
            evidence_refs=[],
            progression_rule=None,
        ),
    ]


def _exercises_upper(big3: Optional[Big3Max], pct: float) -> List[Exercise]:
    bench_w = _calc_main_weight(big3.bench_press_max if big3 else None, pct)
    return [
        Exercise(
            name_ja="ベンチプレス", name_en="Bench Press",
            sets=4, reps="6-8", rest_seconds=180,
            equipment=Equipment.BARBELL,
            target_muscles=[MuscleGroup.CHEST, MuscleGroup.TRICEPS],
            coaching_point="フォーム最優先。重量は徐々に上げる。",
            weight_kg=bench_w,
            evidence_refs=[],
            progression_rule="linear_+2.5kg",
        ),
        Exercise(
            name_ja="ベントオーバーロウ", name_en="Bent-over Row",
            sets=4, reps="6-8", rest_seconds=180,
            equipment=Equipment.BARBELL,
            target_muscles=[MuscleGroup.BACK, MuscleGroup.BICEPS],
            coaching_point="腰を反らさず、肘を後方に引く。",
            weight_kg=None,
            evidence_refs=[],
            progression_rule="linear_+2.5kg",
        ),
        Exercise(
            name_ja="インクラインダンベルプレス", name_en="Incline DB Press",
            sets=3, reps="8-12", rest_seconds=120,
            equipment=Equipment.DUMBBELL,
            target_muscles=[MuscleGroup.CHEST, MuscleGroup.SHOULDERS],
            coaching_point="ベンチ角度 30〜45 度。肩をすくめない。",
            weight_kg=None,
            evidence_refs=[],
        ),
        Exercise(
            name_ja="ラットプルダウン", name_en="Lat Pulldown",
            sets=3, reps="8-12", rest_seconds=90,
            equipment=Equipment.MACHINE,
            target_muscles=[MuscleGroup.BACK],
            coaching_point="肩甲骨の下制を意識し、胸に向かって引く。",
            weight_kg=None,
            evidence_refs=[],
        ),
        Exercise(
            name_ja="サイドレイズ", name_en="Side Lateral Raise",
            sets=3, reps="12-15", rest_seconds=60,
            equipment=Equipment.DUMBBELL,
            target_muscles=[MuscleGroup.SHOULDERS],
            coaching_point="肘を主導に挙げ、頂点で小指がやや上。",
            weight_kg=None,
            evidence_refs=[],
        ),
    ]


def _exercises_lower(big3: Optional[Big3Max], pct: float) -> List[Exercise]:
    squat_w = _calc_main_weight(big3.squat_max if big3 else None, pct)
    deadlift_w = _calc_main_weight(big3.deadlift_max if big3 else None, pct * 0.9 / pct * pct)  # 同pct
    return [
        Exercise(
            name_ja="スクワット", name_en="Barbell Squat",
            sets=4, reps="6-8", rest_seconds=180,
            equipment=Equipment.BARBELL,
            target_muscles=[MuscleGroup.QUADS, MuscleGroup.GLUTES],
            coaching_point="重心は土踏まず、深くしゃがむ。",
            weight_kg=squat_w,
            evidence_refs=[],
            progression_rule="linear_+2.5kg",
        ),
        Exercise(
            name_ja="ルーマニアンデッドリフト", name_en="Romanian Deadlift",
            sets=4, reps="6-8", rest_seconds=180,
            equipment=Equipment.BARBELL,
            target_muscles=[MuscleGroup.HAMSTRINGS, MuscleGroup.GLUTES, MuscleGroup.LOWER_BACK],
            coaching_point="股関節を後ろに引き、背中は中立を維持。",
            weight_kg=_calc_main_weight(big3.deadlift_max if big3 else None, pct * 0.85),
            evidence_refs=[],
            progression_rule="linear_+2.5kg",
        ),
        Exercise(
            name_ja="レッグプレス", name_en="Leg Press",
            sets=3, reps="10-12", rest_seconds=120,
            equipment=Equipment.MACHINE,
            target_muscles=[MuscleGroup.QUADS, MuscleGroup.GLUTES],
            coaching_point="膝を完全にロックしない。",
            weight_kg=None,
            evidence_refs=[],
        ),
        Exercise(
            name_ja="レッグカール", name_en="Leg Curl",
            sets=3, reps="10-12", rest_seconds=90,
            equipment=Equipment.MACHINE,
            target_muscles=[MuscleGroup.HAMSTRINGS],
            coaching_point="可動域全体を使う。",
            weight_kg=None,
            evidence_refs=[],
        ),
        Exercise(
            name_ja="カーフレイズ", name_en="Calf Raise",
            sets=3, reps="12-15", rest_seconds=60,
            equipment=Equipment.MACHINE,
            target_muscles=[MuscleGroup.CALVES],
            coaching_point="頂点で 1 秒静止。",
            weight_kg=None,
            evidence_refs=[],
        ),
    ]


def _exercises_push(big3: Optional[Big3Max], pct: float) -> List[Exercise]:
    bench_w = _calc_main_weight(big3.bench_press_max if big3 else None, pct)
    return [
        Exercise(
            name_ja="ベンチプレス", name_en="Bench Press",
            sets=4, reps="5-7", rest_seconds=180,
            equipment=Equipment.BARBELL,
            target_muscles=[MuscleGroup.CHEST, MuscleGroup.TRICEPS],
            coaching_point="胸の最下点でわずかに静止。",
            weight_kg=bench_w,
            evidence_refs=[],
            progression_rule="linear_+2.5kg",
            safety_flags=["needs_spotter"] if bench_w and bench_w >= 100 else [],
        ),
        Exercise(
            name_ja="オーバーヘッドプレス", name_en="Overhead Press",
            sets=3, reps="6-8", rest_seconds=150,
            equipment=Equipment.BARBELL,
            target_muscles=[MuscleGroup.SHOULDERS, MuscleGroup.TRICEPS],
            coaching_point="体幹を固め、頭上にロックアウトする。",
            weight_kg=None,
            evidence_refs=[],
        ),
        Exercise(
            name_ja="インクラインダンベルプレス", name_en="Incline DB Press",
            sets=4, reps="8-10", rest_seconds=120,
            equipment=Equipment.DUMBBELL,
            target_muscles=[MuscleGroup.CHEST, MuscleGroup.SHOULDERS],
            coaching_point="ベンチ角度 30〜45 度。",
            weight_kg=None,
            evidence_refs=[],
        ),
        Exercise(
            name_ja="サイドレイズ", name_en="Side Lateral Raise",
            sets=3, reps="12-15", rest_seconds=60,
            equipment=Equipment.DUMBBELL,
            target_muscles=[MuscleGroup.SHOULDERS],
            coaching_point="肘主導で挙げる。",
            weight_kg=None,
            evidence_refs=[],
        ),
        Exercise(
            name_ja="トライセプスエクステンション", name_en="Triceps Extension",
            sets=3, reps="10-12", rest_seconds=90,
            equipment=Equipment.CABLE,
            target_muscles=[MuscleGroup.TRICEPS],
            coaching_point="肘の位置を固定する。",
            weight_kg=None,
            evidence_refs=[],
        ),
    ]


def _exercises_pull(big3: Optional[Big3Max], pct: float) -> List[Exercise]:
    deadlift_w = _calc_main_weight(big3.deadlift_max if big3 else None, pct)
    return [
        Exercise(
            name_ja="デッドリフト", name_en="Deadlift",
            sets=3, reps="5", rest_seconds=210,
            equipment=Equipment.BARBELL,
            target_muscles=[MuscleGroup.BACK, MuscleGroup.HAMSTRINGS, MuscleGroup.GLUTES, MuscleGroup.LOWER_BACK],
            coaching_point="背中は中立、足全体で床を押す。",
            weight_kg=deadlift_w,
            evidence_refs=[],
            progression_rule="linear_+2.5kg",
        ),
        Exercise(
            name_ja="懸垂またはラットプルダウン", name_en="Pullup / Lat Pulldown",
            sets=4, reps="6-10", rest_seconds=150,
            equipment=Equipment.BODYWEIGHT,
            target_muscles=[MuscleGroup.BACK, MuscleGroup.BICEPS],
            coaching_point="肩甲骨下制を意識し、胸を張る。",
            weight_kg=None,
            evidence_refs=[],
        ),
        Exercise(
            name_ja="シーテッドロウ", name_en="Seated Cable Row",
            sets=3, reps="8-12", rest_seconds=90,
            equipment=Equipment.CABLE,
            target_muscles=[MuscleGroup.BACK],
            coaching_point="肘は体側を通すように引く。",
            weight_kg=None,
            evidence_refs=[],
        ),
        Exercise(
            name_ja="フェイスプル", name_en="Face Pull",
            sets=3, reps="12-15", rest_seconds=60,
            equipment=Equipment.CABLE,
            target_muscles=[MuscleGroup.SHOULDERS, MuscleGroup.BACK],
            coaching_point="肘を高く保ち、外旋を意識。",
            weight_kg=None,
            evidence_refs=[],
        ),
        Exercise(
            name_ja="バーベルカール", name_en="Barbell Curl",
            sets=3, reps="10-12", rest_seconds=60,
            equipment=Equipment.BARBELL,
            target_muscles=[MuscleGroup.BICEPS],
            coaching_point="肘を体側に固定する。",
            weight_kg=None,
            evidence_refs=[],
        ),
    ]


# ── 怪我フィルタリング ──────────────────────────────────────────────────────

def _filter_injuries(exercises: List[Exercise], excluded: set[MuscleGroup]) -> List[Exercise]:
    """主動筋に excluded が含まれる種目を除外"""
    if not excluded:
        return exercises
    return [e for e in exercises if not (set(e.target_muscles) & excluded)]


# ── スプリット組み立て ──────────────────────────────────────────────────────

def _build_full_body_schedule(
    req: WorkoutRequest, pct: float, excluded: set[MuscleGroup]
) -> List[DaySession]:
    days = _DAYS_ORDER[: req.days_per_week]
    sessions: List[DaySession] = []
    for d in days:
        ex = _filter_injuries(_exercises_full_body(req.big3_max, pct), excluded)
        if not ex:
            continue
        sessions.append(
            DaySession(
                day_of_week=d,
                session_name="Full Body",
                target_muscles=[MuscleGroup.FULL_BODY],
                estimated_duration_minutes=min(req.session_duration_minutes, 60),
                exercises=ex,
            )
        )
    return sessions




def _build_upper_lower_schedule(
    req: WorkoutRequest, pct: float, excluded: set[MuscleGroup]
) -> List[DaySession]:
    """月: Upper / 火: Lower / 木: Upper / 金: Lower"""
    plan_days = [DayOfWeek.MONDAY, DayOfWeek.TUESDAY, DayOfWeek.THURSDAY, DayOfWeek.FRIDAY]
    types = ["upper", "lower", "upper", "lower"][: req.days_per_week]
    sessions: List[DaySession] = []
    for d, t in zip(plan_days[: req.days_per_week], types):
        if t == "upper":
            ex = _filter_injuries(_exercises_upper(req.big3_max, pct), excluded)
            name = "Upper"
            tm = [MuscleGroup.CHEST, MuscleGroup.BACK, MuscleGroup.SHOULDERS]
        else:
            ex = _filter_injuries(_exercises_lower(req.big3_max, pct), excluded)
            name = "Lower"
            tm = [MuscleGroup.QUADS, MuscleGroup.HAMSTRINGS, MuscleGroup.GLUTES]
        if not ex:
            continue
        sessions.append(
            DaySession(
                day_of_week=d,
                session_name=name,
                target_muscles=tm,
                estimated_duration_minutes=min(req.session_duration_minutes, 75),
                exercises=ex,
            )
        )
    return sessions


def _build_ppl_schedule(
    req: WorkoutRequest, pct: float, excluded: set[MuscleGroup]
) -> List[DaySession]:
    plan = [
        (DayOfWeek.MONDAY, "push"),
        (DayOfWeek.TUESDAY, "pull"),
        (DayOfWeek.WEDNESDAY, "legs"),
        (DayOfWeek.THURSDAY, "push"),
        (DayOfWeek.FRIDAY, "pull"),
        (DayOfWeek.SATURDAY, "legs"),
    ][: req.days_per_week]
    sessions: List[DaySession] = []
    for d, t in plan:
        if t == "push":
            ex = _filter_injuries(_exercises_push(req.big3_max, pct), excluded)
            name = "Push"
            tm = [MuscleGroup.CHEST, MuscleGroup.SHOULDERS, MuscleGroup.TRICEPS]
        elif t == "pull":
            ex = _filter_injuries(_exercises_pull(req.big3_max, pct), excluded)
            name = "Pull"
            tm = [MuscleGroup.BACK, MuscleGroup.BICEPS]
        else:
            ex = _filter_injuries(_exercises_lower(req.big3_max, pct), excluded)
            name = "Legs"
            tm = [MuscleGroup.QUADS, MuscleGroup.HAMSTRINGS, MuscleGroup.GLUTES]
        if not ex:
            continue
        sessions.append(
            DaySession(
                day_of_week=d,
                session_name=name,
                target_muscles=tm,
                estimated_duration_minutes=min(req.session_duration_minutes, 90),
                exercises=ex,
            )
        )
    return sessions


def _build_strength_block_schedule(
    req: WorkoutRequest, pct: float, excluded: set[MuscleGroup]
) -> List[DaySession]:
    """BIG3 強化ブロック周期化（簡易版・第 1 週相当 5x5）"""
    plan = [
        (DayOfWeek.MONDAY, "squat_focus"),
        (DayOfWeek.WEDNESDAY, "bench_focus"),
        (DayOfWeek.FRIDAY, "deadlift_focus"),
        (DayOfWeek.SATURDAY, "accessory"),
    ][: req.days_per_week]
    sessions: List[DaySession] = []
    big3 = req.big3_max
    week1_pct = 75.0
    bench_w = _calc_main_weight(big3.bench_press_max if big3 else None, week1_pct)
    squat_w = _calc_main_weight(big3.squat_max if big3 else None, week1_pct)
    deadlift_w = _calc_main_weight(big3.deadlift_max if big3 else None, week1_pct)

    for d, t in plan:
        if t == "squat_focus":
            ex = [
                Exercise(
                    name_ja="スクワット", name_en="Barbell Squat",
                    sets=5, reps="5", rest_seconds=210,
                    equipment=Equipment.BARBELL,
                    target_muscles=[MuscleGroup.QUADS, MuscleGroup.GLUTES],
                    coaching_point="ボリューム週。フォームを最優先。",
                    weight_kg=squat_w,
                    progression_rule="block_week1",
                ),
                Exercise(
                    name_ja="ルーマニアンデッドリフト", name_en="Romanian Deadlift",
                    sets=3, reps="6-8", rest_seconds=150,
                    equipment=Equipment.BARBELL,
                    target_muscles=[MuscleGroup.HAMSTRINGS, MuscleGroup.GLUTES],
                    coaching_point="背中は中立、ハムストリングを伸ばす。",
                ),
            ]
            tm = [MuscleGroup.QUADS, MuscleGroup.GLUTES, MuscleGroup.HAMSTRINGS]
            name = "Squat Focus"
        elif t == "bench_focus":
            ex = [
                Exercise(
                    name_ja="ベンチプレス", name_en="Bench Press",
                    sets=5, reps="5", rest_seconds=210,
                    equipment=Equipment.BARBELL,
                    target_muscles=[MuscleGroup.CHEST, MuscleGroup.TRICEPS],
                    coaching_point="ボリューム週。フォームを最優先。",
                    weight_kg=bench_w,
                    progression_rule="block_week1",
                ),
                Exercise(
                    name_ja="オーバーヘッドプレス", name_en="Overhead Press",
                    sets=3, reps="6-8", rest_seconds=150,
                    equipment=Equipment.BARBELL,
                    target_muscles=[MuscleGroup.SHOULDERS, MuscleGroup.TRICEPS],
                    coaching_point="補助。",
                ),
            ]
            tm = [MuscleGroup.CHEST, MuscleGroup.SHOULDERS, MuscleGroup.TRICEPS]
            name = "Bench Focus"
        elif t == "deadlift_focus":
            ex = [
                Exercise(
                    name_ja="デッドリフト", name_en="Deadlift",
                    sets=5, reps="5", rest_seconds=210,
                    equipment=Equipment.BARBELL,
                    target_muscles=[
                        MuscleGroup.BACK, MuscleGroup.HAMSTRINGS,
                        MuscleGroup.GLUTES, MuscleGroup.LOWER_BACK,
                    ],
                    coaching_point="ボリューム週。背中の中立を維持。",
                    weight_kg=deadlift_w,
                    progression_rule="block_week1",
                ),
            ]
            tm = [MuscleGroup.BACK, MuscleGroup.HAMSTRINGS, MuscleGroup.GLUTES]
            name = "Deadlift Focus"
        else:
            ex = _filter_injuries(_exercises_pull(big3, pct), excluded)
            tm = [MuscleGroup.BACK, MuscleGroup.BICEPS]
            name = "Accessory"
        ex = _filter_injuries(ex, excluded)
        if not ex:
            continue
        sessions.append(
            DaySession(
                day_of_week=d,
                session_name=name,
                target_muscles=tm,
                estimated_duration_minutes=min(req.session_duration_minutes, 75),
                exercises=ex,
            )
        )
    return sessions


# ── 公開API ────────────────────────────────────────────────────────────────

def build_workout_response(req: WorkoutRequest) -> WorkoutResponse:
    """ルールベースで WorkoutResponse を組み立てる。永続化しない。

    v1.0 拡張: req.recent_history が渡された場合、history_optimizer で
    論文ベースのヒューリスティクスを適用する（target_muscles 推奨・
    強度補正・提案根拠テキスト）。
    """
    try:
        # v1.0: 履歴ベースの最適化（recent_history が渡されたときのみ）
        history = req.recent_history
        history_suggested_targets = history_optimizer.suggest_target_muscles(req, history)
        if history_suggested_targets and not req.target_muscles:
            # 履歴から推奨ターゲットが導かれた場合、req を書き換える（コピーで安全に）
            req = req.model_copy(update={"target_muscles": history_suggested_targets})

        excluded = _injured_regions(req.injury_history)
        pct, label = _intensity_for(req.goal)
        # 復帰セッション or 痛み報告複数 → 強度を 90% に減衰
        if history_optimizer.should_reduce_intensity(history):
            pct = round(pct * 0.9, 1)

        split_id = _choose_split(req)

        if split_id == "focused_session":
            sessions = _build_focused_schedule(req, pct, excluded)
            target_label = _label_targets(_normalize_targets(req.target_muscles or []))
            plan_name = f"{target_label}フォーカス — {label}"
            duration_weeks = 4
        elif split_id == "advanced_ppl_hypertrophy":
            sessions = _build_ppl_schedule(req, pct, excluded)
            plan_name = f"PPL（筋肥大）— {label}"
            duration_weeks = 8
        elif split_id == "intermediate_upper_lower":
            sessions = _build_upper_lower_schedule(req, pct, excluded)
            plan_name = f"Upper / Lower — {label}"
            duration_weeks = 8
        elif split_id == "strength_block_periodization":
            sessions = _build_strength_block_schedule(req, pct, excluded)
            plan_name = "BIG3 強化ブロック周期化（Week 1: ボリューム）"
            duration_weeks = 4
        else:
            sessions = _build_full_body_schedule(req, pct, excluded)
            plan_name = f"Full Body — {label}"
            duration_weeks = 6

        if not sessions:
            return WorkoutResponse(
                success=True,
                plan=None,
                safety_flags=["session_suspended", "all_excluded_by_injury"],
                advisory=Advisory(
                    level=AdvisoryLevel.REST_OR_CONSULT,
                    title="今日はトレーニングを中止しましょう",
                    body=(
                        "怪我履歴により本日のセッションを安全に組み立てることができません。"
                        "軽い可動域運動と休養、医療専門家への相談をご検討ください。"
                    ),
                    actions=["rest", "mobility_easy", "consult_pro"],
                ),
                external_ai_used=False,
            )

        plan_safety_flags: List[str] = []
        if excluded and any(req.injury_history or []):
            plan_safety_flags.append("partial_skip")

        # RAG: 関連論文 ID を取得して各種目に付与
        evidence_ids: List[str] = []
        try:
            evidence_ids = rag_service.retrieve_evidence_ids(
                goal=req.goal, priority_lift=req.priority_lift, top_k=5,
            )
        except Exception:
            evidence_ids = []
        if evidence_ids:
            for sess in sessions:
                for ex in sess.exercises:
                    if not ex.evidence_refs:
                        ex.evidence_refs = list(evidence_ids)

        # v1.0: 履歴ベースの提案根拠テキストを生成
        rationale = history_optimizer.build_rationale(
            req, history, split_id, history_suggested_targets,
        )

        plan = WorkoutPlan(
            plan_name=plan_name,
            duration_weeks=duration_weeks,
            weekly_schedule=sessions,
            general_advice=_general_advice(req, label),
            safety_flags=plan_safety_flags,
            proposal_rationale=rationale,
        )

        advisory = Advisory(level=AdvisoryLevel.NONE)
        top_safety: List[str] = list(plan_safety_flags)
        if "partial_skip" in plan_safety_flags:
            advisory = Advisory(
                level=AdvisoryLevel.PARTIAL_SKIP,
                title="一部の種目を除外しました",
                body="申告された怪我履歴に基づき、影響のある種目を本日は除外しています。",
                actions=["acknowledge"],
            )

        return WorkoutResponse(
            success=True,
            plan=plan,
            safety_flags=top_safety,
            advisory=advisory,
            external_ai_used=False,
        )
    except Exception as e:
        return WorkoutResponse(
            success=False,
            plan=None,
            safety_flags=[],
            advisory=Advisory(level=AdvisoryLevel.NONE),
            external_ai_used=False,
            error_message=f"rule engine error: {type(e).__name__}",
        )


def _general_advice(req: WorkoutRequest, label: str) -> str:
    """総合アドバイス文（メニュー画面はシンプルに保つ）。
    栄養・カフェイン等は回復ラウンジで詳細表示する（v6 UX）。
    """
    parts = [
        f"目標『{label}』に合わせたメニューです。",
        "週内で同じ筋群を連続で叩かないよう休養を確保してください。",
        "痛みや違和感がある場合は中止し、医療専門家にご相談ください。",
    ]
    return " ".join(parts)
