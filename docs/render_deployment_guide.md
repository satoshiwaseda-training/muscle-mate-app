# Render バックエンドデプロイ手順書

`backend/` の FastAPI サーバーを Render で無料ホスティングする手順。所要 15〜30 分。

---

## 前提

- このリポジトリの `render.yaml` がリポジトリルートに配置済み
- GitHub アカウントを持っている
- backend のローカルテストは完了済（68 + 13 = 81 件 pass）

---

## 1. Render アカウント作成（5 分）

### 1-1. サインアップ
ブラウザで開く：
> 👉 **https://dashboard.render.com/register**

### 1-2. GitHub で認証
1. **「Continue with GitHub」** ボタンを押す
2. GitHub の認可ダイアログで **「Authorize Render」**
3. 戻ったら個人情報を最低限入力（無料プランなのでクレカ不要）

---

## 2. Blueprint からサービス作成（5 分）

`render.yaml` がリポジトリルートにあるので、Blueprint 機能で一発デプロイ：

### 2-1. New Blueprint Instance
1. Render ダッシュボード右上の **「New +」** → **「Blueprint」**
2. **「Connect a repository」** で `satoshiwaseda-training/muscle-mate-app` を選択
   - 表示されない場合は **「Configure GitHub App」** → このリポジトリへのアクセスを許可
3. Branch: `main` を選択
4. Render が `render.yaml` を自動検出して **muscle-mate-api** サービス定義を表示
5. **「Apply」** ボタン

### 2-2. デプロイ開始
- Render が自動で：
  1. リポジトリをクローン
  2. `backend/` に移動
  3. `pip install --upgrade pip && pip install -r requirements.txt`
  4. `uvicorn main:app --host 0.0.0.0 --port $PORT` で起動
  5. `/health` エンドポイントでヘルスチェック
- 進捗は「Logs」タブでリアルタイム表示
- 完了まで **5〜10 分**

---

## 3. デプロイ確認（2 分）

### 3-1. URL を確認
デプロイ完了後、サービス画面上部に URL が表示されます：

```
https://muscle-mate-api.onrender.com
```

（実際の URL はランダムな suffix が付くことがあります。「muscle-mate-api-XXXX.onrender.com」のような形）

### 3-2. ヘルスチェック
ブラウザまたはターミナルでテスト：

```bash
curl https://muscle-mate-api.onrender.com/health
```

期待される応答（最初のリクエストは 15 秒スリープ起動で遅い）：
```json
{
  "status": "ok",
  "service": "muscle-mate-api",
  "version": "0.2.0",
  "llm_provider": "noop",
  "external_ai_billing_mode": "free_only",
  "structlog": true,
  "slowapi": true
}
```

### 3-3. メニュー生成テスト
```bash
curl -X POST https://muscle-mate-api.onrender.com/workout/generate \
  -H "Content-Type: application/json" \
  -H "X-External-AI-Optin: false" \
  -d '{"goal":"general_fitness","level":"beginner","days_per_week":1,"session_duration_minutes":30,"equipment":["bodyweight"]}'
```

200 OK + JSON プランが返れば成功。

---

## 4. iOS ビルド時に使う API URL

Render URL が確定したら、その URL を私に教えてください。以下に反映します：

| 反映場所 | 値 |
|---|---|
| **Flutter ビルドコマンド** | `--dart-define=API_BASE_URL=https://muscle-mate-api.onrender.com` |
| **README.md** | 本番 URL の記載追加 |
| **submission docs** | 各テンプレに本番 URL を反映 |

---

## 5. 自動デプロイ動作確認

Render は GitHub と連携しているため、`main` ブランチに push すれば**自動で再デプロイ**されます：

1. ローカルでコード修正 → `git push origin main`
2. Render ダッシュボードの「Events」タブに「Deploy triggered」と表示
3. 5〜10 分で新バージョンに切替

---

## 6. 注意点・トラブルシューティング

### Free プランの制限
- **15 分アイドルでスリープ**：使われていないと自動で停止
- **初回アクセス時に 15〜30 秒の起動時間**：ユーザー体験的には許容範囲
- **750 時間/月**：1 ヶ月稼働しても 720 時間なので十分

### よくあるエラー

| エラー | 原因 | 対処 |
|---|---|---|
| `[FATAL] APP_ENV=production needs ALLOWED_ORIGINS` | 環境変数未設定 | render.yaml の envVars に含まれているので通常起こらない |
| `ModuleNotFoundError: No module named 'fastapi'` | requirements.txt 未インストール | rootDir が `backend` になっているか確認 |
| 起動に 1 分以上かかる | スリープ復帰時の正常動作 | 初回アクセス時のみ |
| /workout/generate が CORS エラー | ALLOWED_ORIGINS にクライアント origin が含まれていない | iOS アプリからは Origin ヘッダなしなので通常無関係 |

### スリープ防止（任意）
無料プランのスリープを防ぐには：
- **UptimeRobot**（無料）で 10 分ごとに /health にアクセスさせる
- 設定：5〜10 分間隔の HTTP ping で 24/7 起動状態にできる

ただし、Render の利用規約上「不要な常時起動はマナー違反」とされているため、TestFlight 期間中だけ有効化するなど節度を持って利用。

---

## 7. プラン昇格を検討するタイミング

将来的に有料プラン（$7/月）に移行を検討するタイミング：

| 状況 | 推奨プラン |
|---|---|
| 個人テスト・TestFlight 配信時 | Free で OK |
| App Store 申請・審査期間中 | Free でも審査担当者の数アクセスには耐えられる |
| 一般公開後 アクティブユーザー > 50 人 | **Starter ($7/月)** へ昇格推奨（スリープなし・専用 CPU） |
| アクティブユーザー > 500 人 | Pro ($25/月) 検討 |

---

## 8. 関連ファイル

| ファイル | 内容 |
|---|---|
| `/render.yaml` | デプロイ設定（このファイルを Render が読む） |
| `/backend/main.py` | FastAPI エントリーポイント |
| `/backend/requirements.txt` | Python 依存パッケージ |
| `/backend/Dockerfile` | （Render では使われない・ローカル Docker テスト用） |
