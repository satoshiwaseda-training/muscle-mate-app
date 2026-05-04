# CTO成果物 — 審査通過モード データ構造・保存設計

## 前提
- 保存: ローカルのみ（SQLite 推奨）
- ネットワーク通信: 完全禁止
- SDK追加: 禁止（現在の pubspec.yaml / package.json から変更しない）
- エラーゼロ: 全操作でクラッシュなし

---

## 技術スタック（審査通過モード固定）

| 領域 | 採用技術 | 理由 |
|------|---------|------|
| フレームワーク | Flutter（既存） | 変更なし |
| ローカルDB | sqflite（Flutter）または SQLite.swift（iOS native） | ローカル保存・外部通信なし |
| 代替（軽量な場合） | shared_preferences | 単純なKey-Value保存が十分な場合 |
| ネットワーク | 使用禁止 | Info.plistで通信を無効化 |

### 採用判断: sqflite（SQLite）
- 種目名・重量・回数・セット数・日時の構造化データが必要
- 日付フィルタ・種目グループ化・最大値取得をSQLで処理できる
- shared_preferencesではクエリが複雑になりすぎる

---

## データモデル定義

### テーブル: workout_records

```sql
CREATE TABLE workout_records (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  exercise    TEXT    NOT NULL,          -- 種目名（例: "ベンチプレス"）
  weight      REAL    NOT NULL,          -- 重量kg（小数点対応）
  reps        INTEGER NOT NULL,          -- 回数
  sets        INTEGER NOT NULL,          -- セット数
  recorded_at TEXT    NOT NULL           -- 記録日時（ISO8601: "2026-04-05T14:30:00"）
);
```

**インデックス（パフォーマンス）:**
```sql
CREATE INDEX idx_recorded_at ON workout_records(recorded_at);
CREATE INDEX idx_exercise ON workout_records(exercise);
```

---

## クエリ定義

### 画面1: 今日の記録を取得
```sql
SELECT id, exercise, weight, reps, sets, recorded_at
FROM workout_records
WHERE date(recorded_at) = date('now', 'localtime')
ORDER BY recorded_at DESC;
```

### 画面2: 全履歴を日付降順で取得
```sql
SELECT id, exercise, weight, reps, sets, recorded_at
FROM workout_records
ORDER BY recorded_at DESC;
```

### 画面3: 種目ごとの最大重量を取得（ベスト）
```sql
SELECT exercise, MAX(weight) as best_weight, reps
FROM workout_records
GROUP BY exercise
ORDER BY exercise ASC;
```
※ MAX(weight)が同じ種目で複数ある場合は最新の記録を使用。

### 記録追加
```sql
INSERT INTO workout_records (exercise, weight, reps, sets, recorded_at)
VALUES (?, ?, ?, ?, datetime('now', 'localtime'));
```

### 記録削除（個別）
```sql
DELETE FROM workout_records WHERE id = ?;
```

### 全データ削除（設定画面）
```sql
DELETE FROM workout_records;
```

---

## バリデーション（アプリ層で実装）

| フィールド | 型 | 制約 | エラーメッセージ |
|-----------|-----|------|--------------|
| exercise | String | 1文字以上・50文字以内・空白のみ禁止 | 「種目名を入力してください」 |
| weight | double | 0.0超・999.9以下 | 「重量を正しく入力してください（0〜999）」 |
| reps | int | 1以上・999以下 | 「回数を正しく入力してください（1〜999）」 |
| sets | int | 1以上・99以下 | 「セット数を正しく入力してください（1〜99）」 |

**バリデーションのタイミング:**
- 保存ボタンタップ時にのみ実行（入力中はリアルタイムバリデーションしない）
- エラーがある場合は該当フィールド下にエラーテキストを赤字表示
- 保存は実行しない

---

## DB初期化フロー

```dart
// アプリ起動時に1回だけ実行
Future<void> initDatabase() async {
  final db = await openDatabase(
    'muscle_mate.db',
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE workout_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          exercise TEXT NOT NULL,
          weight REAL NOT NULL,
          reps INTEGER NOT NULL,
          sets INTEGER NOT NULL,
          recorded_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_recorded_at ON workout_records(recorded_at)'
      );
      await db.execute(
        'CREATE INDEX idx_exercise ON workout_records(exercise)'
      );
    },
  );
  return db;
}
```

---

## エラーハンドリング方針

| エラー種別 | 対応 |
|-----------|------|
| DB初期化失敗 | アラートダイアログ「アプリを再起動してください」を表示してアプリを終了しない |
| INSERT失敗 | 「保存に失敗しました。再度お試しください。」をSnackBarで表示 |
| DELETE失敗 | 「削除に失敗しました。再度お試しください。」をSnackBarで表示 |
| 予期しない例外 | try-catchで全て捕捉・クラッシュ禁止・エラーログをローカルのみに出力 |

**クラッシュゼロ原則:**
全ての非同期処理にtry-catchを必須とする。
catchブロックでは必ずユーザーへのフィードバックを行い、アプリを継続させる。

---

## Info.plist / AndroidManifest 設定

### iOS (Info.plist)
```xml
<!-- ネットワーク通信の明示的な無効化 -->
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <false/>
</dict>

<!-- 使用しない権限は記載しない（記載すると審査で質問される） -->
<!-- NSCameraUsageDescription → 削除 -->
<!-- NSMicrophoneUsageDescription → 削除 -->
<!-- NSLocationWhenInUseUsageDescription → 削除 -->
<!-- NSPhotoLibraryUsageDescription → 削除 -->
<!-- NSHealthShareUsageDescription → 削除 -->
```

### Android (AndroidManifest.xml)
```xml
<!-- INTERNET パーミッションを削除（または記載しない） -->
<!-- <uses-permission android:name="android.permission.INTERNET" /> ← 削除 -->
```

---

## 依存パッケージ（追加禁止・現状維持）

審査通過モード中は `pubspec.yaml` に新規パッケージを追加しない。
sqfliteが未導入の場合のみ以下を追加する（それ以外の追加は禁止）：

```yaml
dependencies:
  sqflite: ^2.3.0      # ローカルDB（追加許可）
  path: ^1.9.0         # DBファイルパス取得（sqfliteの依存）
```

---

## 受け入れ基準（CTO）

- [ ] DBファイルがローカルに作成される
- [ ] 記録の追加・取得・削除が正常動作する
- [ ] アプリ再起動後もデータが保持される
- [ ] 全データ削除後にDB内のデータが0件になる
- [ ] ネットワークリクエストが一切発生しない（Charlesなどで確認）
- [ ] 全操作でクラッシュが発生しない
- [ ] 不正入力（空文字・負数）でクラッシュが発生しない
- [ ] Info.plistに不要な権限記述がない
