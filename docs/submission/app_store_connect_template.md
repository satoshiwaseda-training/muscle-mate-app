# App Store Connect 入力テンプレート

提出時に App Store Connect の各フィールドに**コピペで使える完成済みテキスト**。提出計画書 v1.3 §5.3 §6 をもとに整理。

---

## 0. 入力前のチェックリスト

- [ ] Apple Developer Program 承認済
- [ ] Tax / Banking / W-8BEN 入力完了
- [ ] App ID `io.github.satoshiwaseda-training.musclemate` 登録済
- [ ] My Apps で「Muscle Mate」のアプリ枠作成済
- [ ] スクリーンショット 5 枚（1290×2796）準備済
- [ ] TestFlight でビルドアップロード + 暗号化情報回答済
- [ ] プライバシーポリシー URL がブラウザで 200 OK で見られる

---

## 1. App Information タブ

### Privacy Policy URL（必須）
```
https://satoshiwaseda-training.github.io/muscle-mate-app/legal/privacy_policy.html
```

### Subtitle（30 文字以内）
```
筋トレをもっと気軽に楽しく
```
（13 文字）

### Category
- **Primary Category**: `Health & Fitness`（ヘルスケア／フィットネス）
- **Secondary Category**: `Sports`（スポーツ）

### Content Rights
- 「Does your app contain, show, or access third-party content?」 → **No**

### Age Rating
質問票で以下を回答：

| 質問 | 回答 |
|---|---|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Sexual Content or Nudity | None |
| Profanity or Crude Humor | None |
| Alcohol, Tobacco, or Drug Use | None |
| Mature/Suggestive Themes | None |
| Simulated Gambling | None |
| Horror/Fear Themes | None |
| Medical/Treatment Information | **None**（フィットネス情報は医療助言ではないため） |
| Unrestricted Web Access | None |

→ 結果は **4+** になる想定

---

## 2. Pricing and Availability

| 項目 | 値 |
|---|---|
| Price Schedule | **Free**（無料） |
| Availability | All Territories（全地域） |
| Volume Purchase Program | OFF |
| Pre-Orders | OFF |

---

## 3. App Privacy（Privacy Details）

別ファイル `privacy_details_answer_sheet.md` の質問票をそのまま入力。

---

## 4. iOS App Version 1.0

### Version Information

#### App Name（ストア表示名・30 文字以内）
```
Muscle Mate - 筋トレ記録
```
（15 文字）

#### Promotional Text（170 文字以内・ストア掲載後も変更可）
```
筋トレの記録を、もっと気軽に。種目・重量・回数の記録から、論文ベースの最適メニュー提案まで。広告なし、ログイン不要、すぐ使える筋トレ記録アプリ。
```
（71 文字）

#### Description（4,000 文字以内）

```
Muscle Mateは、筋トレの記録をシンプルに管理するアプリです。

【できること】

■ 記録を残す
種目名・重量・回数・セット数を入力して、その日のトレーニングを記録します。

■ 履歴を確認する
これまでの記録を日付順に一覧で確認できます。

■ 自己ベストを確認する
種目ごとの最大重量を自動で表示します。どの種目でどれだけ上げられたか、一目で確認できます。

【特徴】

・シンプルな4画面構成
記録・履歴・ベスト・設定の4つの画面のみ。余計な機能はありません。

・端末内に記録を保存
記録データはお使いの端末内に保存されます。メニュー生成時のみサーバー側で一時的に処理し、永続保存は行いません。

・広告なし
広告は表示されません。

【こんな方に】
・筋トレの記録をシンプルに残したい方
・余計な機能が不要な方
・記録閲覧をすばやく済ませたい方

【データについて】
記録の保存先は端末内のみで、クラウド同期は行いません。メニュー生成・アドバイス取得には一時的なサーバー通信を使用します（送信内容はサーバーに永続保存しません）。
```

#### Keywords（100 文字以内・カンマ区切り）
```
筋トレ,トレーニング,記録,ワークアウト,筋肉,ジム,重量,ベンチプレス,スクワット,筋トレ記録
```

#### Support URL（必須）
```
https://satoshiwaseda-training.github.io/muscle-mate-app/legal/support.html
```

#### Marketing URL（任意）
```
https://satoshiwaseda-training.github.io/muscle-mate-app/
```

#### Version
```
1.0
```

#### Copyright（任意）
```
© 2026 Satoshi Takabayashi
```

---

## 5. What's New in This Version

```
バージョン 1.0.0

初回リリース。
筋トレの種目・重量・回数・セット数を記録し、履歴と自己ベストを確認できます。
論文ベースのメニュー提案、シンプルな4画面構成。
```

---

## 6. Build

TestFlight でアップロード済みのビルドを選択：
- Build: 1.0 (1)
- Active: ✓

### Export Compliance Information

| 項目 | 回答 |
|---|---|
| Does your app use encryption? | **Yes** |
| Does your app qualify for any of the exemptions provided in Category 5, Part 2 of the U.S. Export Administration Regulations? | **Yes** |
| Does your app implement any encryption algorithms that are proprietary or not accepted as standard by international standard bodies? | **No** |

→ HTTPS のみ使用なので **Standard Exemption** に該当。

> 💡 `Info.plist` に `ITSAppUsesNonExemptEncryption=false` を入れてあるので、ビルドごとの再回答は不要。

---

## 7. App Review Information

### Sign-In Information
- **Sign-in required**: **No**（ログイン不要）

### Contact Information
| 項目 | 値 |
|---|---|
| First Name | （あなたの名） |
| Last Name | （あなたの姓） |
| Phone Number | +81 90-XXXX-XXXX（実在する電話番号必須） |
| Email | （連絡可能なメールアドレス） |

### Notes（審査員向けメモ）
```
本アプリは筋トレ記録に特化したシンプルなアプリです。

・ログインは不要です。アプリを開くとすぐに使用できます。
・記録閲覧・履歴・ベスト確認は端末内のみで動作します。メニュー生成・アドバイス取得には HTTPS 通信が必要です（送信内容はサーバーに永続保存しません）。
・課金要素はありません。
・カメラ・マイク・位置情報などの権限は使用していません。
・第三者 AI サービスへの送信は本バージョンでは提供していません。

テスト手順:
1. アプリを起動する
2. 同意画面で 13 歳以上を確認してすすむ
3. ホーム画面の「+」ボタンをタップして「メニューを提案してもらう」を選択
4. 入力画面で目標を選んで「メニューを提案してもらう」をタップ
5. 「このセッションを開始」で記録モードに入り、種目を 1〜2 完了
6. 「履歴」タブで記録一覧を確認する
7. 「設定」タブで利用規約・プライバシーポリシーを確認する

サーバー API:
- ベース URL: https://muscle-mate-api.onrender.com
- POST /workout/generate でメニュー生成
- POST /workout/next で次回の進行提案
- POST /workout/advice で論文ベースのアドバイス取得
- GET /health でヘルスチェック
- データは永続保存しない（リクエストごとに破棄）
- HTTPS (TLS) のみ
```

### Attachment（任意）
- スクリーン録画があれば添付（マスト機能のデモ）

---

## 8. Phased Release / Manual Release

### Release
- **Manually release this version**（手動公開）

承認後、自分のタイミングで「Release Now」を押せる。

---

## 9. URL の最終確認

提出ボタンを押す前に、ブラウザで以下が 200 OK で見られることを確認：

| URL | チェック内容 |
|---|---|
| https://satoshiwaseda-training.github.io/muscle-mate-app/ | トップページ |
| https://satoshiwaseda-training.github.io/muscle-mate-app/legal/privacy_policy.html | プライバシーポリシー全文 |
| https://satoshiwaseda-training.github.io/muscle-mate-app/legal/support.html | サポート（FAQ）ページ |

ブラウザ実機（Safari + Chrome）両方で確認推奨。

---

## 10. Submit for Review

すべて入力完了後：

1. ページ上部の「**Save**」を押す
2. 「**Submit for Review**」ボタンを押す
3. 確認ダイアログで **Submit**
4. ステータスが「**Waiting for Review**」になる
5. 1〜2 営業日後にステータスが「**In Review**」または「**Approved**」「**Rejected**」に変わる

---

## 11. 販売者名表記について

Apple Developer Program 個人開発者の場合、**App Store の「販売者：◯◯」欄には Apple Developer Program に登録した Team Name（= Legal Name）がそのまま表示される**仕様。

本アプリの場合：
- Team Name: `SATOSHI Takabayashi`
- プライバシーポリシー §1: 「高林 聡（以下「開発者」）」（同一人物）
- About ダイアログ: 「© 2026 Satoshi Takabayashi」

販売者名・プライバシーポリシー・著作権表記すべてが**同一人物の表記で揃っており**、審査担当者から「販売者と開発者が違う」と指摘される心配なし。

> 💡 別名（DBA / 屋号）を表示したい場合は Apple Developer Support への申請が必要だが、個人開発者には基本的に承認されない。v1.0 では Legal Name 統一が最もシンプルで安全。
