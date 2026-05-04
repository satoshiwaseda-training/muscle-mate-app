# ⏸ PAUSED — 審査通過モード中

## 停止日: 2026-04-05
## 停止理由: 外部Analyticsの実装禁止（review_mode.md参照）
## 再開条件: context/review_mode.md に定義されたモード解除条件の達成

## 停止中の禁止事項
- 外部AnalyticsツールのSDK追加・実装
- イベントトラッキングの実装
- KPIダッシュボードの構築

## 再開後の優先タスク（メモ）
- イベント計測設計（workout_start / workout_complete など9イベント）
- 週次KPIレポートの自動化

## 再開手順
1. CEOがreview_mode.mdに「モード解除」を記録する
2. CTOがAnalytics SDKの審査適合性を確認する（Firebaseを使わない代替を検討）
3. analytics部門がイベント設計を開始する
