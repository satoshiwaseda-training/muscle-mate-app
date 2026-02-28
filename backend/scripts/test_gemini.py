"""
scripts/test_gemini.py
======================
Gemini API の自律テストスクリプト。

【用途】
  - Claude Code が自分でGeminiを呼び出し、応答を検証する
  - 新機能開発時の「自己完結ループ」の起点として使う
  - FastAPI サーバー不要・直接サービス層を呼ぶ

【実行方法】
  cd backend
  .venv/Scripts/python scripts/test_gemini.py
"""

import sys
import os
import asyncio
import json
import time

# backend/ を sys.path に追加して src/ を import できるようにする
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.schemas.workout import (
    WorkoutRequest, Big3Max, Goal, Level, Equipment, INTENSITY_TABLE
)
from src.services.gemini_service import generate_workout_plan


# ── ANSI カラー（Windows コンソール対応） ──────────────────────────────────
class C:
    RESET  = "\033[0m"
    BOLD   = "\033[1m"
    GREEN  = "\033[92m"
    RED    = "\033[91m"
    YELLOW = "\033[93m"
    CYAN   = "\033[96m"
    GRAY   = "\033[90m"

def ok(msg):   print(f"  {C.GREEN}[PASS]{C.RESET} {msg}")
def fail(msg): print(f"  {C.RED}[FAIL]{C.RESET} {msg}")
def info(msg): print(f"  {C.CYAN}[INFO]{C.RESET} {msg}")
def warn(msg): print(f"  {C.YELLOW}[WARN]{C.RESET} {msg}")
def sep(title=""):
    line = "=" * 60
    if title:
        print(f"\n{C.BOLD}{line}{C.RESET}")
        print(f"{C.BOLD}  {title}{C.RESET}")
        print(f"{C.BOLD}{line}{C.RESET}")
    else:
        print(f"{C.GRAY}{'-' * 60}{C.RESET}")


# ── 期待値の計算（サービス層と同じロジック） ──────────────────────────────
def expected_weight(max_kg: float, goal: Goal) -> float:
    pct = INTENSITY_TABLE[goal.value]["primary"]
    return round(max_kg * pct / 100 / 2.5) * 2.5


# ── テストケース定義 ───────────────────────────────────────────────────────
TEST_CASES = [
    {
        "name": "サトシ標準テスト (筋肥大・中級・4日)",
        "request": WorkoutRequest(
            goal=Goal.MUSCLE_GAIN,
            level=Level.INTERMEDIATE,
            days_per_week=4,
            equipment=[Equipment.BARBELL, Equipment.DUMBBELL],
            big3_max=Big3Max(
                bench_press_max=115.0,
                squat_max=140.0,
                deadlift_max=160.0,
            ),
        ),
        "checks": {
            "bench_expected_kg":   expected_weight(115.0, Goal.MUSCLE_GAIN),
            "squat_expected_kg":   expected_weight(140.0, Goal.MUSCLE_GAIN),
            "deadlift_expected_kg": expected_weight(160.0, Goal.MUSCLE_GAIN),
            "min_days": 4,
            "max_days": 4,
        },
    },
    {
        "name": "BIG3なし（重量=null）テスト (初心者・自重のみ・3日)",
        "request": WorkoutRequest(
            goal=Goal.GENERAL,
            level=Level.BEGINNER,
            days_per_week=3,
            equipment=[Equipment.BODYWEIGHT],
            big3_max=None,
        ),
        "checks": {
            "all_weight_null": True,  # big3がないので全種目 weight_kg = null
            "min_days": 3,
            "max_days": 3,
        },
    },
]


# ── 単一テストケースの実行・検証 ──────────────────────────────────────────
async def run_test(case: dict) -> dict:
    req = case["request"]
    checks = case["checks"]
    results = {"name": case["name"], "passed": 0, "failed": 0, "errors": []}

    sep(f"TEST: {case['name']}")

    # API 呼び出し
    info(f"Gemini ({req.goal.value} / {req.level.value} / {req.days_per_week}days) を呼び出し中...")
    t0 = time.time()
    response = await generate_workout_plan(req)
    elapsed = time.time() - t0
    info(f"応答時間: {elapsed:.1f}秒")

    # 成功フラグチェック
    if not response.success:
        fail(f"API失敗: {response.error_message}")
        results["failed"] += 1
        results["errors"].append(response.error_message)
        return results

    ok("response.success == True")
    results["passed"] += 1

    plan = response.plan

    # ── プラン基本情報 ──────────────────────────────────────
    sep()
    info(f"プラン名: {plan.plan_name}")
    info(f"推奨期間: {plan.duration_weeks}週間")
    info(f"セッション数: {len(plan.weekly_schedule)}日")

    # 日数チェック
    actual_days = len(plan.weekly_schedule)
    if checks.get("min_days") and actual_days < checks["min_days"]:
        fail(f"セッション数が少ない: {actual_days} < {checks['min_days']}")
        results["failed"] += 1
    elif checks.get("max_days") and actual_days > checks["max_days"]:
        fail(f"セッション数が多い: {actual_days} > {checks['max_days']}")
        results["failed"] += 1
    else:
        ok(f"セッション数OK: {actual_days}日")
        results["passed"] += 1

    # ── 種目一覧と weight_kg 検証 ──────────────────────────
    sep()
    bench_found = squat_found = deadlift_found = False

    for day in plan.weekly_schedule:
        print(f"\n  {C.BOLD}[{day.day_of_week.upper()}] {day.session_name}{C.RESET}  "
              f"({day.estimated_duration_minutes}分 / {len(day.exercises)}種目)")
        for ex in day.exercises:
            w_str = f"  {C.YELLOW}{ex.weight_kg}kg{C.RESET}" if ex.weight_kg else "  weight=null"
            print(f"    {ex.name_ja:<22} {ex.sets}set x {ex.reps:<8}{w_str}")

            name = ex.name_ja
            w = ex.weight_kg

            # ベンチプレス重量チェック（バリエーション種目は除外）
            BENCH_EXCLUDES = ("インクライン", "デクライン", "クローズ", "ナロー", "ダンベル")
            is_main_bench = "ベンチプレス" in name and not any(x in name for x in BENCH_EXCLUDES)
            if is_main_bench:
                bench_found = True
                if "bench_expected_kg" in checks:
                    expected = checks["bench_expected_kg"]
                    if w == expected:
                        ok(f"ベンチプレス weight_kg 正確: {w}kg == {expected}kg")
                        results["passed"] += 1
                    else:
                        fail(f"ベンチプレス weight_kg 不一致: {w}kg != {expected}kg (許容: {expected})")
                        results["failed"] += 1

            # スクワット重量チェック
            if "スクワット" in name and "ダンベル" not in name:
                squat_found = True
                if "squat_expected_kg" in checks:
                    expected = checks["squat_expected_kg"]
                    if w == expected:
                        ok(f"スクワット weight_kg 正確: {w}kg == {expected}kg")
                        results["passed"] += 1
                    else:
                        fail(f"スクワット weight_kg 不一致: {w}kg != {expected}kg")
                        results["failed"] += 1

            # デッドリフト重量チェック
            if "デッドリフト" in name and "ルーマニアン" not in name and "ダンベル" not in name:
                deadlift_found = True
                if "deadlift_expected_kg" in checks:
                    expected = checks["deadlift_expected_kg"]
                    if w == expected:
                        ok(f"デッドリフト weight_kg 正確: {w}kg == {expected}kg")
                        results["passed"] += 1
                    else:
                        fail(f"デッドリフト weight_kg 不一致: {w}kg != {expected}kg")
                        results["failed"] += 1

            # BIG3なしテスト：全種目 weight_kg = null チェック
            if checks.get("all_weight_null") and w is not None:
                fail(f"{ex.name_ja}: big3_max=Noneなのに weight_kg={w} が設定されている")
                results["failed"] += 1

    if checks.get("all_weight_null"):
        ok("全種目 weight_kg=null (big3未入力時の正しい挙動)")
        results["passed"] += 1

    # ── Pydantic バリデーション通過確認 ────────────────────
    sep()
    try:
        from src.schemas.workout import WorkoutPlan
        WorkoutPlan.model_validate(plan.model_dump())
        ok("Pydantic スキーマバリデーション: 通過")
        results["passed"] += 1
    except Exception as e:
        fail(f"スキーマバリデーション失敗: {e}")
        results["failed"] += 1

    # ── general_advice チェック ─────────────────────────────
    if plan.general_advice and len(plan.general_advice) > 20:
        ok(f"general_advice: 存在する ({len(plan.general_advice)}文字)")
        results["passed"] += 1
    else:
        fail("general_advice が短すぎる or 空")
        results["failed"] += 1

    print(f"\n  {C.CYAN}アドバイス抜粋:{C.RESET} {plan.general_advice[:80]}...")

    return results


# ── メイン ─────────────────────────────────────────────────────────────────
async def main():
    sep("Muscle Mate - Gemini 自律テストスクリプト")
    print(f"  モデル: gemini-2.0-flash")
    print(f"  テストケース数: {len(TEST_CASES)}")

    all_results = []
    for case in TEST_CASES:
        result = await run_test(case)
        all_results.append(result)

    # ── 最終サマリー ───────────────────────────────────────
    sep("SUMMARY")
    total_pass = sum(r["passed"] for r in all_results)
    total_fail = sum(r["failed"] for r in all_results)

    for r in all_results:
        status = f"{C.GREEN}OK{C.RESET}" if r["failed"] == 0 else f"{C.RED}NG{C.RESET}"
        print(f"  [{status}] {r['name']}  "
              f"(PASS:{r['passed']} / FAIL:{r['failed']})")

    print(f"\n  {C.BOLD}合計: PASS {total_pass} / FAIL {total_fail}{C.RESET}")

    if total_fail == 0:
        print(f"\n  {C.GREEN}{C.BOLD}>>> 全テスト合格。自律開発環境は正常稼働中。{C.RESET}")
    else:
        print(f"\n  {C.RED}{C.BOLD}>>> {total_fail}件のテストが失敗。ログを確認してください。{C.RESET}")
        sys.exit(1)


if __name__ == "__main__":
    # Windows コンソールの ANSI カラーを有効化
    if sys.platform == "win32":
        os.system("")
    asyncio.run(main())
