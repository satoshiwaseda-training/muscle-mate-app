# リジェクト対応テンプレ集

万一審査で却下（Rejection）された場合の Resolution Center 返信テンプレ。提出計画書 v1.3 §8 の典型リジェクト 8 種類に対応。

---

## 共通ルール

- **返信期限**：受信から **48 時間以内**
- **返信言語**：**日本語＋英語の両方**を併記（Apple のレビュアーは英語話者）
- **トーン**：丁寧・事実ベース・反論しない
- **対応不可な仕様変更要求**：Resolution Center で議論を継続、必要なら Phone Call 申請も可
- **本格的な仕様変更が必要な場合**：バージョンを 1.0.1 に上げて再提出

---

## A. Guideline 5.1.1 — Privacy Policy の不備

### よくある指摘
- プライバシーポリシー URL が開けない
- 必須項目（データ収集、第三者送信、削除手段）の記載がない
- 日本語版のリンクが切れている

### 返信テンプレ（日本語）
```
ご指摘ありがとうございます。プライバシーポリシーの URL は以下です：
https://satoshiwaseda-training.github.io/muscle-mate-app/legal/privacy_policy.html

このページは GitHub Pages で静的ホストされており、現在もアクセス可能です（HTTP 200）。

本ポリシーには以下の必須事項を含みます：
- §2 収集する情報（端末内保存・サーバー一時処理）
- §3 メニュー生成のサーバー側処理
- §4 第三者 AI 未使用の明示
- §5 サーバー保存ポリシー
- §6 インフラメタデータ処理（CDN/WAF）
- §7 端末内データの削除手段
- §9 13 歳未満を対象としない方針
- §10 同意撤回手段
- §12 お問い合わせ窓口

ご確認の上、追加で必要な情報があればお知らせください。
```

### 返信テンプレ（英語）
```
Thank you for the feedback. Our Privacy Policy URL is:
https://satoshiwaseda-training.github.io/muscle-mate-app/legal/privacy_policy.html

This page is statically hosted on GitHub Pages and is accessible (HTTP 200).

The policy includes all required disclosures:
- §2 Data collected (device-local storage and ephemeral server processing)
- §3 Server-side menu generation processing
- §4 Explicit statement of no third-party AI usage in v1.0
- §5 No-server-persistence policy
- §6 Infrastructure metadata handling (CDN/WAF)
- §7 In-app data deletion controls
- §9 No targeting of users under 13
- §10 Consent withdrawal procedures
- §12 Contact information

Please let us know if you need any additional information.
```

---

## B. Guideline 5.1.1 — Sign in with Apple の要否

### よくある指摘
- 他のサインイン手段がある場合、Sign in with Apple も提供する必要がある（4.0 ガイドライン）

### 返信テンプレ（日本語）
```
本アプリ v1.0 はサインイン機能を一切実装していません。
ユーザーはアプリ起動後すぐに利用でき、アカウント作成・ログインは不要です。
ガイドライン 4.0 の Sign in with Apple 要件は、他のサードパーティ SSO（Google / Facebook 等）を提供する場合に該当しますが、本アプリではいかなるサードパーティ SSO も提供していません。

審査ノートにも記載の通り、本アプリは「ログイン不要・端末内データ＋一時サーバー処理」の構成です。
```

### 英語
```
Our v1.0 does not implement any sign-in features. Users can use the app immediately upon launch with no account creation or login required.
Guideline 4.0's Sign in with Apple requirement applies when third-party SSO (Google, Facebook, etc.) is offered, but our app offers no third-party SSO.

As noted in our review notes, this app uses a login-free architecture with device-local data and ephemeral server processing.
```

---

## C. Guideline 4.0 / 4.2 — 機能薄／Web View ラッパ疑い

### よくある指摘
- 「アプリの機能が薄い」「Web ページのラッパに見える」

### 返信テンプレ（日本語）
```
本アプリは Web View ラッパではなく、ネイティブ Flutter で実装した独立アプリです。

主要機能（すべてアプリ内で完結）:
1. トレーニング記録の作成・編集（端末内 SQLite）
2. 履歴一覧と日付検索（カレンダー UI）
3. 自己ベストの自動算出
4. 論文ベースのメニュー提案（rule_engine_service による決定論的処理）
5. 記録に基づく筋肉部位ビジュアライザ（カスタム描画）
6. シェア機能（端末内で画像生成 → Native Share Sheet）
7. 医療助言モーダル（怪我・痛み入力時の安全性確保）

サーバー通信は POST /workout/generate と POST /workout/next、POST /workout/advice の 3 エンドポイントのみで、いずれもアプリ内のロジック支援です。

機能のデモ動画を添付しました。ご確認ください。
```

### 英語
```
Our app is not a web view wrapper; it is a native Flutter implementation with the following primary features (all in-app):

1. Training record creation/editing (device-local SQLite)
2. History list with calendar-based date search
3. Automatic personal best calculation
4. Research-paper-based menu suggestions (deterministic via rule_engine_service)
5. Record-based muscle group visualizer (custom drawing)
6. Share feature (in-device image generation → Native Share Sheet)
7. Medical advisory modal (safety check on injury/pain input)

Server communication is limited to three endpoints (POST /workout/generate, /workout/next, /workout/advice), all of which support in-app logic.

A demo video is attached. Please review.
```

---

## D. Guideline 2.1 — 動作確認できない（API ダウン）

### よくある指摘
- 「サーバーに接続できなかった」

### 返信テンプレ（日本語）
```
ご指摘ありがとうございます。バックエンド API のサーバーログを確認しましたが、対象期間中の /health エンドポイントへの応答率は 99.9% を維持しており、メニュー生成エンドポイントも正常に応答していました。

レビュー時に一時的なネットワーク問題が発生した可能性があります。お手数ですが再審査をお願いします。

本アプリのサーバー API:
- /health: ヘルスチェック
- /workout/generate: メニュー生成
- /workout/next: 次回の進行ルール提案
- /workout/advice: 論文ベースのアドバイス取得

すべて HTTPS、応答時間 P95 < 500ms です。

引き続き審査期間中（提出後 5 日間）は定期メンテナンスを停止し、稼働率モニタを敷いています。
```

### 英語
```
Thank you for the feedback. We've verified our backend API server logs and the /health endpoint maintained 99.9% response rate during the review period; menu generation endpoints also responded normally.

A transient network issue may have occurred during your review. Please re-review.

Our app's server APIs:
- /health: health check
- /workout/generate: menu generation
- /workout/next: progression suggestions
- /workout/advice: research-based advice

All over HTTPS with P95 response time < 500ms.

We have suspended scheduled maintenance during the review period (5 days post-submission) and are actively monitoring uptime.
```

---

## E. Guideline 1.4.1 — 健康関連の主張

### よくある指摘
- 「医療効果を示唆する文言がある」
- 「断定的な健康主張がある」

### 返信テンプレ（日本語）
```
ご指摘ありがとうございます。本アプリは医療助言・診断・治療を提供しないことを明示しています。

該当する記述があればご指摘ください。以下の対応を取っています：

1. プライバシーポリシー §8 で「医療助言・診断・治療を提供するものではありません」と明記
2. 怪我・痛み入力時に医療モーダルを表示し「医療専門家にご相談ください」と案内
3. 説明文・キーワード・スクリーンショットから断定表現（「最強」「絶対」「治る」等）を除外
4. メニュー提案は論文の研究知見に基づく「目安」として提示

具体的な懸念箇所をご指摘いただければ、該当文言を修正のうえ再提出いたします。
```

### 英語
```
Thank you for the feedback. Our app explicitly disclaims providing medical advice, diagnosis, or treatment.

Please point out the specific wording you find concerning. We have taken the following measures:

1. Privacy Policy §8 explicitly states "this app does not provide medical advice, diagnosis, or treatment"
2. Injury/pain inputs trigger a medical advisory modal recommending consultation with healthcare professionals
3. Description, keywords, and screenshots avoid definitive claims ("strongest", "absolute", "cure", etc.)
4. Menu suggestions are presented as "guidelines" based on peer-reviewed research

If you can point us to specific phrasing of concern, we will revise and resubmit.
```

---

## F. Guideline 4.5.4 — Push の不要権限要求

### よくある指摘
- 「通知権限を要求しているが必要性が見えない」

### 返信テンプレ（日本語）
```
本アプリ v1.0 は通知機能（UNUserNotificationCenter）を一切呼び出していません。
Info.plist にも通知関連の記述はなく、Apple Push Notification service の設定もしていません。

ビルド成果物の解析結果でも通知関連のエントリは含まれていないことを確認しています。

ご指摘の挙動が再現する場合、具体的な状況（画面、操作手順）をご教示ください。
```

### 英語
```
Our v1.0 does not invoke any notification features (UNUserNotificationCenter).
There are no notification-related entries in Info.plist, nor is Apple Push Notification service configured.

Build artifact analysis confirms no notification-related entries.

If the behavior you observed is reproducible, please share the specific screen and steps.
```

---

## G. Metadata Rejection — スクリーンショット内容相違

### よくある指摘
- 「スクリーンショットがアプリの実際の機能と異なる」

### 返信テンプレ（日本語）
```
ご指摘ありがとうございます。スクリーンショット 5 枚はすべて、iPhone 16 Pro Max シミュレータの実機録画から書き出したもので、アプリの実装と完全に一致しています。

各スクリーンショットの対応:
- SS-01: ホーム画面（カレンダー UI、実装確認可能）
- SS-02: メニュー提案画面（rule_engine_service の出力例）
- SS-03: ワークアウトセッション画面（種目入力 UI）
- SS-04: 履歴詳細モーダル（筋肉部位ビジュアライザ）
- SS-05: 実績シェア画面（物理オブジェクト比較）

具体的にどの画像と機能の不一致をご指摘されているかご教示いただければ、対応いたします。
```

### 英語
```
Thank you for the feedback. All 5 screenshots are exported directly from iPhone 16 Pro Max simulator running our actual build and fully match the app's implementation.

Each screenshot corresponds to:
- SS-01: Home (calendar UI, verifiable in build)
- SS-02: Menu suggestion (rule_engine_service output)
- SS-03: Workout session (exercise input UI)
- SS-04: History detail modal (muscle group visualizer)
- SS-05: Share feature (physical object comparison)

Please specify which screenshot and feature you find inconsistent so we can address it.
```

---

## H. Export Compliance — 暗号化申告ミス

### よくある指摘
- 「暗号化使用の申告に誤りがある」

### 返信テンプレ（日本語）
```
本アプリは HTTPS（TLS）以外の暗号化を使用していません。
これは EAR Section 740.17(b)(3) の Standard Exemption に該当するため、Self-Classification の申告は不要です。

具体的には：
- HTTP 通信は使用しておらず、すべて HTTPS（TLS）
- 独自の暗号化アルゴリズム実装なし
- 暗号化を主目的とする機能なし
- iOS 標準の暗号化 API（CommonCrypto 等）も主機能としては使用なし

Info.plist に `ITSAppUsesNonExemptEncryption=false` を設定済みです。
```

### 英語
```
Our app does not use any encryption beyond HTTPS (TLS).
This qualifies for the Standard Exemption under EAR Section 740.17(b)(3); Self-Classification submission is not required.

Specifically:
- No HTTP traffic; all communication uses HTTPS (TLS)
- No custom encryption algorithm implementations
- No features primarily for encryption purposes
- No primary use of iOS standard encryption APIs (CommonCrypto, etc.)

`ITSAppUsesNonExemptEncryption=false` has been set in Info.plist.
```

---

## I. その他のリジェクト（汎用テンプレ）

### 返信テンプレ（日本語）
```
ご指摘ありがとうございます。

[ ここに具体的な対応内容を記載 ]

修正版を再提出いたしますので、改めてご審査をお願いします。
他に懸念事項があればお知らせください。
```

### 英語
```
Thank you for the feedback.

[ Describe specific actions taken ]

We will resubmit the corrected version for review. Please let us know if there are any additional concerns.
```

---

## ⚠️ 修正不可な要求への対応

「機能を追加してほしい」「他社アプリのような UI にしてほしい」など、Apple のガイドラインを超えた要求が来た場合：

### 返信テンプレ（日本語）
```
ご提案ありがとうございます。本機能は v1.0 のスコープ外ですが、ロードマップに登録し、将来のアップデート（v1.1 以降）で検討いたします。

現バージョンとしては、ガイドライン違反箇所のみ修正のうえ、再審査をお願いできますでしょうか。
```

### 英語
```
Thank you for the suggestion. This feature is out of scope for v1.0, but we will note it for the roadmap and consider it for a future update (v1.1 or later).

For the current version, may we kindly request re-review with only the guideline-violation issues addressed?
```

---

## 緊急時のエスカレーション

48 時間以内に解決しない場合：

1. **Resolution Center** で **Schedule a Call** を申請
2. 通話で 30 分以内に審査担当者と直接議論
3. 本格的な仕様変更が必要なら **バージョン 1.0.1** を作成して再提出

通話準備：
- 想定質問への英語回答を 10 個用意
- 画面共有でデモできる準備（Mac + iPhone 実機）
- 録音は禁止されているのでメモを取る

---

## 提出後のステータス変化

| ステータス | 意味 | アクション |
|---|---|---|
| Waiting for Review | 提出済・順番待ち | 待つ |
| In Review | 審査中（通常 24h） | 待つ |
| Pending Developer Release | 承認済・公開待ち | 「Release Now」を押す |
| Approved | 承認済（自動公開設定の場合） | — |
| **Rejected** | 却下 | 上記テンプレで対応 |
| Metadata Rejected | メタデータのみ却下 | 説明文・スクリーンショットを修正 |
| Removed from Sale | 公開後に取り下げ | Resolution Center で対応 |

---

## 参考情報

| 情報源 | URL |
|---|---|
| App Store Review Guidelines | https://developer.apple.com/app-store/review/guidelines/ |
| Resolution Center 操作 | App Store Connect → 該当バージョン → Resolution Center タブ |
| Standard Exemption 詳細 | https://www.bis.doc.gov/index.php/policy-guidance/encryption |
