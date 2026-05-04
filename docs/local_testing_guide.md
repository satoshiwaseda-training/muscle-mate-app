# ローカルでの動作確認ガイド

サンドボックスでは Flutter SDK が利用できないため、お手元の環境で以下の手順を実施してください。

## 前提

- Flutter SDK 3.3 以降
- Dart SDK 3.0 以降
- iOS シミュレータ（macOS）または Android Emulator
- Python 3.10+（バックエンド用）

## 1. バックエンド起動

```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# 環境変数（最低限）
export APP_ENV=development
export LLM_PROVIDER=noop
export EXTERNAL_AI_BILLING_MODE=free_only

uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

確認: ブラウザで `http://localhost:8000/health` → `{"status": "ok", ...}` が返る。

### バックエンドのテスト

```bash
cd backend
python -m pytest tests/ -v
```

期待値: **68 passed**

## 2. フロントエンド起動

```bash
cd frontend
flutter pub get
flutter analyze   # 静的解析
flutter test      # ユニット/ウィジェットテスト
```

### iOS シミュレータで起動

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

### Android Emulator で起動（Mac/Linux）

Android では `localhost` ではなく `10.0.2.2` を使用:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

### 実機で起動

開発機の IP（例: `192.168.1.100`）を確認して指定:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000
```

ファイアウォールで 8000 番ポートを開放しておく。

## 3. UI 動作確認チェックリスト

### 初回起動（同意画面）
- [ ] 「13 歳以上であることを確認します」チェックボックスがオフだと進めない
- [ ] チェックを入れると「同意してはじめる」が活性化
- [ ] プライバシーポリシーリンクから §4 外部 AI セクションが読める

### 設定画面
- [ ] 体重・年齢を入力して保存できる
- [ ] BIG3 MAX を入力して保存できる
- [ ] 「外部 AI 補強」トグルを ON すると確認ダイアログが表示される
- [ ] ダイアログでキャンセルするとトグルが OFF のまま
- [ ] ダイアログで同意するとトグルが ON になり SnackBar 表示

### メニュー生成（/workout/generate）
- [ ] 設定保存後にメニュー生成 → プラン画面が表示される
- [ ] 種目に重量（BIG3 MAX 入力時）が表示されている
- [ ] 怪我履歴を入力して生成 → 該当部位の種目が除外される（PARTIAL_SKIP バナー）
- [ ] 全部位を severe 怪我にして生成 → 「今日は中止しましょう」モーダル
- [ ] 設定で日本語アドバイス本文に【参考】と【タンパク質】が含まれる

### アドバイス画面（/workout/advice）
- [ ] 設定→アドバイスを見る で画面遷移
- [ ] カードが 6〜8 件表示される
- [ ] 体重 70kg 入力時、タンパク質カードに「98〜140g」表示
- [ ] 設定で目標を「減量」に変えてから再表示 → weight_loss_diet カード追加
- [ ] BIG3 強化リフトを設定→ big3_progression カード追加
- [ ] 怪我あり→ injury_care カード（WARNING・橙色）が先頭に
- [ ] 各カード末尾の「根拠」エビデンスを長押し → URL コピー SnackBar

### 同意トグル動作
- [ ] OFF 時: バックエンドログに `external_ai_optin: "false"` が記録
- [ ] ON 時: バックエンドログに `external_ai_optin: "true"` が記録
- [ ] OFF → ON → OFF と切替後、バックエンドが動作継続
- [ ] OFF にして「アカウントデータを削除」→ トグル状態もリセット

## 4. プライバシー検証

### バックエンドログ確認

```bash
cd backend
LLM_PROVIDER=noop uvicorn main:app --port 8000 2>&1 | tee /tmp/access.log

# 別ターミナルで /workout/generate を叩く
# 完了後にログを確認
grep -i "bench_press_max\|injury\|notes\|99999" /tmp/access.log
```

期待値: **何もヒットしないこと**（リクエスト本文がログに出ないことを保証）。

### カナリア検査（自動）

```bash
cd backend
PYTHONPATH=. python -m pytest tests/test_external_ai_guards.py::test_canary_not_leaked_in_validation_error -v
```

期待値: **PASS**

## 5. App Store / Google Play 提出前チェックリスト

計画書 v5 §13 のフェーズ 5 と一致。

- [ ] §7 ホワイトリストと §4.1／§4.4／§10.1.3／§10.3／§10.4／付録 C の文字列一致
- [ ] CI で禁止フィールド送信テスト緑
- [ ] CI でカナリア値漏えい検査緑
- [ ] CI で自動スキップ検査緑（§4.4 の各条件で `external_ai_used == false`）
- [ ] `LLM_PROVIDER=noop` で `/workout/generate` がルール単独で完結
- [ ] 痛み時の医療モーダルが表示される（`advisory.level == "rest_or_consult"` 経路）
- [ ] `WorkoutResponse` 拡張型（§6.4）に Flutter が分岐対応している
- [ ] 13 歳ゲートで `age` が SharedPreferences に保存されないこと（`age_gate_passed: bool` のみ）
- [ ] `APP_ENV=production` 時、`ALLOWED_ORIGINS` 未設定で起動失敗すること
- [ ] Privacy Details の **4 区分**（端末内／サーバー一時／第三者 AI／インフラメタデータ）が記入済み
- [ ] `assets/evidence_index.json` に許可スキーマ以外のキーがないこと
- [ ] `operational_records.md` に Groq ZDR 確認記録が直近 30 日以内に存在
- [ ] Groq 支払情報未登録 OR `MAX_EXTERNAL_AI_CALLS_PER_MONTH` ハードキャップ設定済み
- [ ] プライバシーポリシーにインフラメタデータ処理条項（§10.4 §6）と同意撤回の遡及不能性（§10.4 §4）が記載されている
- [ ] iOS / Android のビルドが成功する
- [ ] アイコン・スプラッシュが反映されている
- [ ] App Privacy Nutrition Label が新スキーマと整合
- [ ] 利用規約のテキストが現実装と整合

## 6. トラブルシューティング

### 「通信エラー」が出る

- バックエンドが起動しているか確認
- iOS シミュレータでは `localhost`、Android Emulator では `10.0.2.2`、実機では PC の LAN IP を `--dart-define=API_BASE_URL` で渡す
- ファイアウォールで 8000 番が許可されているか

### `flutter pub get` が遅い

- 国内 mirror を使う場合: `export PUB_HOSTED_URL=https://pub.flutter-io.cn`

### Android で HTTP が拒否される

- `android/app/src/main/AndroidManifest.xml` の `application` に `android:usesCleartextTraffic="true"`（開発時のみ）

### iOS で HTTP が拒否される

- `ios/Runner/Info.plist` に `NSAppTransportSecurity` の例外を追加（開発時のみ）

### 「アドバイスが表示されない」

- 設定画面で体重・年齢・目標・レベルを保存
- バックエンドが `/workout/advice` に応答しているか確認: `curl -X POST http://localhost:8000/workout/advice -H 'Content-Type: application/json' -d '{"goal":"muscle_gain","level":"intermediate","days_per_week":4,"session_duration_minutes":60,"equipment":["barbell"]}'`

## 7. 残作業（今後の実装候補）

- numeric_targets を使ったグラフ化（タンパク質バー、カフェイン量チャート等）
- 論文 MD の追加・人手レビュー
- カロリー計算（TDEE）と体脂肪率推定の追加
- セッション履歴からの長期トレンド可視化
- iOS / Android / Web の CI 自動ビルド
