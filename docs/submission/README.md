# 提出準備ドキュメント

App Store 申請に必要な実務ドキュメント一式。Apple Developer Program 承認待ちの間に Claude が先回りで作成。

## ファイル一覧

| ファイル | 用途 | いつ使う |
|---|---|---|
| [`screenshot_guide.md`](./screenshot_guide.md) | スクリーンショット 5 枚の撮影手順書 | W3 開始時 |
| [`app_store_connect_template.md`](./app_store_connect_template.md) | App Store Connect の各フィールドにコピペで使える完成テキスト | W3 入力時 |
| [`privacy_details_answer_sheet.md`](./privacy_details_answer_sheet.md) | App Privacy（Privacy Nutrition Label）の質問票回答案 | W3 入力時 |
| [`rejection_response_templates.md`](./rejection_response_templates.md) | リジェクト時の返信テンプレ（日英） | W5 万が一の時 |

## 前提

- Bundle ID: `io.github.satoshiwaseda-training.musclemate`
- Privacy Policy URL: https://satoshiwaseda-training.github.io/muscle-mate-app/legal/privacy_policy.html
- Support URL: https://satoshiwaseda-training.github.io/muscle-mate-app/legal/support.html
- 開発者表示名（Team Name / App Store 販売者表記）: `SATOSHI Takabayashi` （Apple Developer Program に登録された Legal Name と一致）
- バックエンド本番 URL: **https://muscle-mate-api.onrender.com** （Render 無料枠で稼働中）

## 提出までのフロー

1. ✅ Apple Developer Program 申し込み（ユーザー対応・1〜2 営業日）
2. 🔜 Apple ID 認証 + Tax/Banking + W-8BEN（→ `app_store_connect_template.md` §0）
3. 🔜 Xcode で DEVELOPMENT_TEAM 設定 + ipa ビルド
4. 🔜 Transporter で TestFlight アップロード
5. 🔜 内部テスター登録 + 3 日間テスト（クラッシュ 0 件）
6. 🔜 スクリーンショット 5 枚（→ `screenshot_guide.md`）
7. 🔜 App Store Connect 入力（→ `app_store_connect_template.md`）
8. 🔜 Privacy Details 入力（→ `privacy_details_answer_sheet.md`）
9. 🔜 Submit for Review
10. 🔜 万が一却下されたら（→ `rejection_response_templates.md`）

## 関連ドキュメント

- [`docs/app_store_submission_plan_v1_3.docx`](../app_store_submission_plan_v1_3.docx) — 提出計画書本体
- [`docs/legal/privacy_policy_v1.md`](../legal/privacy_policy_v1.md) — プライバシーポリシー本文
- [`docs/legal/README.md`](../legal/README.md) — 公開 HTML の更新フロー
- [`cmo_marketing/appstore_copy_review_mode.md`](../../cmo_marketing/appstore_copy_review_mode.md) — App Store コピー（マーケティング側マスタ）
