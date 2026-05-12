# Muscle Mate App

ルールベースの筋トレメニュー生成・記録アプリ。FastAPI（バックエンド）+ Flutter（iOS / Android）構成。
App Store 提出版 v1.0 はルール単独構成（外部 AI 不使用）。

## 本番環境

| サービス | URL |
|---|---|
| **バックエンド API** | https://muscle-mate-api.onrender.com |
| **プライバシーポリシー** | https://satoshiwaseda-training.github.io/muscle-mate-app/legal/privacy_policy.html |
| **サポート / FAQ** | https://satoshiwaseda-training.github.io/muscle-mate-app/legal/support.html |
| **GitHub Pages トップ** | https://satoshiwaseda-training.github.io/muscle-mate-app/ |

バックエンドは Render の無料枠で稼働中（15 分アイドルでスリープ、初回アクセス時 15〜30 秒の起動時間）。

## プロジェクト構成

```
muscle-mate-app/
├── backend/                       # FastAPI (Python 3.12)
│   ├── main.py                    # エントリーポイント (HTTPS / Render)
│   ├── requirements.txt           # fastapi / uvicorn / pydantic / structlog / slowapi
│   ├── Dockerfile                 # ローカル開発用 (Render は使わない)
│   └── src/
│       ├── routers/workout.py     # POST /workout/generate, /next, /advice
│       ├── services/
│       │   ├── rule_engine_service.py    # ルールベースのメニュー生成
│       │   ├── history_optimizer.py      # 履歴ベースの最適化（論文連携）
│       │   └── progression_service.py    # 次回提案ロジック
│       └── schemas/workout.py     # 共通 JSON スキーマ (Pydantic)
├── frontend/                      # Flutter (iOS / Android / Web)
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/                # WorkoutRequest / Response / Record
│   │   ├── services/              # api_service, local_storage, share_action
│   │   ├── screens/               # 各画面
│   │   └── widgets/               # muscle_visualizer (熊キャラクター), share_card_view
│   └── assets/ui/                 # マスコット画像・スクリーン素材
├── docs/
│   ├── legal/                     # プライバシーポリシー HTML/MD ソース
│   ├── submission/                # App Store 提出用テンプレ群
│   └── render_deployment_guide.md # Render デプロイ手順
├── knowledge/                     # 論文要約 MD・プログラム雛形 MD
├── render.yaml                    # Render Infrastructure as Code
└── .github/workflows/             # Python テスト CI
```

## ローカル開発

### 1. バックエンド起動

```bash
cd backend
pip install -r requirements.txt
APP_ENV=development LLM_PROVIDER=noop \
  ALLOWED_ORIGINS="http://127.0.0.1:8080,http://localhost:8080" \
  uvicorn main:app --reload --port 8000
```

### 2. Flutter web で動作確認

```bash
cd frontend
flutter pub get
flutter build web --release \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=ENABLE_EXTERNAL_AI=false
python3 -m http.server 8080 --directory build/web
```

Chrome で `http://127.0.0.1:8080/` を開く。

### 3. テスト実行

```bash
cd backend
pytest tests/ -v
```

81 件全てパス（68 ルールエンジン + 13 履歴最適化）。

## API エンドポイント

| メソッド | パス | 説明 |
|---|---|---|
| GET | `/health` | ヘルスチェック |
| POST | `/workout/generate` | メニュー生成（ルールベース） |
| POST | `/workout/next` | 次回の進行提案 |
| POST | `/workout/advice` | 論文ベースのアドバイス取得 |

### `/workout/generate` リクエスト例

```bash
curl -X POST https://muscle-mate-api.onrender.com/workout/generate \
  -H "Content-Type: application/json" \
  -H "X-External-AI-Optin: false" \
  -d '{
    "goal": "muscle_gain",
    "level": "beginner",
    "days_per_week": 1,
    "session_duration_minutes": 30,
    "equipment": ["barbell", "dumbbell"]
  }'
```

## iOS 提出ビルド

Apple Developer Program 加入後、Mac で：

```bash
cd frontend
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://muscle-mate-api.onrender.com \
  --dart-define=ENABLE_EXTERNAL_AI=false
```

出力先：`build/ios/ipa/*.ipa` → Transporter.app または Xcode Organizer で App Store Connect へアップロード。

詳細は [`docs/submission/`](./docs/submission/) を参照。

## デプロイ

- **バックエンド**: GitHub に push すると Render が自動でリビルド・再デプロイ（`render.yaml` 経由）
- **プライバシーポリシー**: `docs/legal/*.html` を更新して push すると GitHub Pages が反映

## ライセンス

論文の引用条件は [`knowledge/LICENSES.md`](./knowledge/LICENSES.md) を参照。
