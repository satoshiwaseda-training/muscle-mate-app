# Privacy Details 回答シート

App Store Connect の **App Privacy** セクション（通称 Privacy Nutrition Label）の質問票への回答案。提出計画書 v1.3 §5.3 「Privacy Details の ASC 入力欄マッピング」に対応。

---

## 0. 回答の前提（v1.0 仕様）

| 項目 | 状態 |
|---|---|
| 第三者 AI 送信 | **未使用**（LLM_PROVIDER=noop） |
| サーバー保存 | **しない**（メニュー生成リクエスト処理後すぐ破棄） |
| 端末内保存 | **する**（SharedPreferences / SQLite） |
| インフラメタデータ | CDN/WAF が IP / User-Agent をセキュリティ目的で一定期間保持 |
| トラッキング | **なし**（広告 ID 利用なし、外部追跡なし） |

---

## 1. Data Collection（データ収集の有無）

App Store Connect の最初の質問：

> Does your app, or any third-party partners your app integrates with, **collect data** from this app?

**回答: Yes（収集する）**

理由：メニュー生成時にユーザーの入力（目標・レベル・体重等）が一時的にサーバーに送信されるため。サーバー側で永続保存はしないが、Apple ガイダンス上「サーバーへ送信」自体が collected に該当する。

---

## 2. データタイプ別の回答

App Store Connect は次のカテゴリで聞いてくる：

### 2-1. Contact Info（連絡先情報）

| データ | 収集 | 理由 |
|---|---|---|
| Name | **No** | 氏名は収集しない |
| Email Address | **No** | メアドは収集しない |
| Phone Number | **No** | 電話番号は収集しない |
| Physical Address | **No** | 住所は収集しない |
| Other User Contact Info | **No** | その他連絡先なし |

### 2-2. Health & Fitness（健康・フィットネス）

| データ | 収集 | 用途 | Linked to User | Used for Tracking |
|---|---|---|---|---|
| Health | **Yes** | App Functionality | **No** | **No** |
| Fitness | **Yes** | App Functionality | **No** | **No** |

#### Health の詳細
- 収集する内容：体重 (`body_weight_kg`)、怪我履歴 (`injury_history`)、痛み報告 (`pain_flag`)
- 用途：**App Functionality**（メニュー生成のための入力）
- Linked to User：**No**（ユーザー識別子と紐付けない・サーバーで永続保存しない）
- Used for Tracking：**No**

#### Fitness の詳細
- 収集する内容：BIG3 MAX、目標、トレーニングレベル、トレーニング歴、トレーニング記録（`SessionLog`）
- 用途：**App Functionality**
- Linked to User：**No**
- Used for Tracking：**No**

### 2-3. Financial Info（金融情報）
すべて **No**（課金なし）

### 2-4. Location（位置情報）
すべて **No**（位置情報を取得しない）

### 2-5. Sensitive Info（機微情報）

| データ | 収集 | 注記 |
|---|---|---|
| Sensitive Info（種別） | **要 ASC 実画面確認** | injury_history, pain_flag, gender が該当する可能性。Apple のカテゴリ表記に従って Yes / No 判定 |

#### 補足
Apple の「Sensitive Info」カテゴリは具体的には：
- **Health** の一部としてカウントされる場合は、Health 側で申告済み（重複回答不要）
- ASC の質問票で「Sensitive Info」セクションが別立てで出てきた場合は、念のため `injury_history` を「Yes / App Functionality / Not Linked / Not Tracking」で申告

> 💡 **W3 で実画面を見て最終判定**。Apple のカテゴリ名・粒度は時々改訂されるため、提出時の質問文を直接読んで判断。

### 2-6. Contacts
すべて **No**

### 2-7. User Content（ユーザー生成コンテンツ）

| データ | 収集 | 用途 | Linked to User | Used for Tracking |
|---|---|---|---|---|
| Other User Content | **Yes** | App Functionality | **No** | **No** |

#### 該当データ
- `notes`（自由記述・最大 500 文字）
- 任意入力フィールド全般

### 2-8. Browsing History
**No**（ブラウジング履歴は扱わない）

### 2-9. Search History
**No**

### 2-10. Identifiers（識別子）

| データ | 収集 | 用途 |
|---|---|---|
| User ID | **No** | ユーザー識別子は使わない（ログイン機能なし） |
| Device ID | **No** | 広告 ID / 端末 ID は使わない |

### 2-11. Purchases
すべて **No**（課金なし）

### 2-12. Usage Data（利用状況データ）

| データ | 収集 | 用途 | Linked to User | Used for Tracking |
|---|---|---|---|---|
| Product Interaction | **No** | — | — | — |
| Advertising Data | **No** | — | — | — |
| Other Usage Data | **No** | — | — | — |

> 💡 アプリ内に分析（Firebase Analytics 等）を入れていないため。

### 2-13. Diagnostics（診断情報）

| データ | 収集 | 用途 | Linked to User | Used for Tracking |
|---|---|---|---|---|
| Crash Data | **No** | — | — | — |
| Performance Data | **No** | — | — | — |
| Other Diagnostic Data | **Yes** | App Functionality | **No** | **No** |

#### Other Diagnostic Data の内容
- IP アドレス・User-Agent 等（CDN/WAF が処理する通信メタデータ）
- 用途：App Functionality（セキュリティ・障害対応）

### 2-14. Other Data（その他）

| データ | 収集 | 用途 | Linked to User | Used for Tracking |
|---|---|---|---|---|
| Other Data Types | **Yes** | App Functionality | **No** | **No** |

#### 内容
- `goal`, `level`, `days_per_week`, `session_duration_minutes`, `equipment`, `target_muscles`, `priority_lift`, `years_of_training`, `session_hour`
- フィットネス嗜好設定全般
- 用途：App Functionality（メニュー生成のための設定）

---

## 3. 各データの目的（Purposes）

質問された場合の回答：

| Purpose | 該当 | 説明 |
|---|---|---|
| Third-Party Advertising | **No** | 広告なし |
| Developer's Advertising or Marketing | **No** | 広告なし |
| Analytics | **No** | アナリティクス未使用 |
| Product Personalization | **No** | パーソナライズ機能なし（提出計画書 v1.3 で禁止ワードに含まれているため使わない） |
| **App Functionality** | **Yes** | メニュー生成・記録管理という主要機能のため |
| Other Purposes | **No** | — |

---

## 4. Tracking 関連質問

### 「Do you or your third-party partners use this data to track users?」

**No（追跡しない）**

### App Tracking Transparency（ATT）プロンプト

ATT プロンプト（`AppTrackingTransparency.framework`）は実装していない（v1.0 ではトラッキングなし）。

iOS 14.5 以降のアプリで「データを他社サービスとリンクして広告に使う」場合のみ ATT が必要。本アプリは該当しない。

---

## 5. 個人情報を収集する第三者サービス

| サービス | 用途 | データ |
|---|---|---|
| なし | — | — |

第三者 SDK（Firebase / Google Analytics / Facebook SDK 等）は一切組み込んでいないため、サードパーティのデータ収集はゼロ。

---

## 6. 申告完了後のチェック

App Store Connect で申告内容が以下になることを確認：

| Privacy Nutrition Label | 表示 |
|---|---|
| **Data Linked to You** | （何も表示されない、または「Health & Fitness」だけ）|
| **Data Not Linked to You** | Health & Fitness、User Content、Diagnostics、Other Data |
| **Data Used to Track You** | （何も表示されない）|

「Data Linked to You」セクションが**何も表示されない**ことが理想。すべての収集データを「Not Linked」として申告しているため。

---

## 7. プライバシーポリシーとの整合確認

App Store Connect での申告内容と、公開しているプライバシーポリシー（`https://satoshiwaseda-training.github.io/muscle-mate-app/legal/privacy_policy.html`）の本文が**矛盾しないこと**を確認：

| ポリシー §X | ASC 申告 | 整合 |
|---|---|---|
| §2 端末内保存 | "not collected" として申告（端末ローカルのみ） | ✅ |
| §2 サーバー一時処理 | Health & Fitness / User Content / Other Data に Yes | ✅ |
| §3 ルールベース完結 | Other Data: App Functionality | ✅ |
| §4 第三者 AI 未使用 | サードパーティのデータ収集ゼロ | ✅ |
| §5 サーバー保存しない | Linked: No 申告と整合 | ✅ |
| §6 インフラメタデータ | Diagnostics / Other Diagnostic Data として申告 | ✅ |
| §9 13 歳ゲート | Age Rating 4+ + 13 歳未満を対象としない記載 | ✅ |

---

## 8. ASC 質問票で迷ったら

実際の質問文に迷ったら、以下の優先順位で判断：

1. **送信していなければ Not Collected**（端末内のみのデータ）
2. **送信しているがサーバーで永続保存しなければ Collected, Not Linked, Not Tracking**
3. **広告 ID や追跡識別子を使っていなければ Used for Tracking: No**
4. **すべての用途を「App Functionality」に集約**（Analytics や Personalization は使っていない）

---

## 9. よくある審査リジェクト → 事前回避

| よくあるリジェクト | 対策 |
|---|---|
| Data Collection Inconsistency | 上記 7 番のチェックリストを徹底 |
| Privacy Policy が短すぎる | `privacy_policy.html` は v5 §10.4 必須項目 12 章を含む |
| 第三者 SDK の申告漏れ | 第三者 SDK ゼロを再確認（`flutter pub deps` で依存ツリー確認） |
| Sensitive Info 申告漏れ | injury_history, pain_flag を Health 側で申告済み |

---

## 10. 提出時の最終確認

App Store Connect の Privacy Details ページ上部に表示される「Privacy Nutrition Label プレビュー」を確認：

```
Data Used to Track You: [なし]

Data Linked to You: [なし]

Data Not Linked to You:
  ・Health & Fitness
  ・User Content
  ・Diagnostics
  ・Other Data
```

これが理想の状態。表示が違えば回答を見直し。
