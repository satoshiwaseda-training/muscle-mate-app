# Muscle Mate App

Gemini AIを使った筋トレメニュー生成アプリ。
App Store / Google Play への公開を目標とした FastAPI + Flutter 構成。

## プロジェクト構成

```
muscle-mate-app/
├── backend/                  # FastAPI (Python)
│   ├── main.py               # エントリーポイント
│   ├── requirements.txt
│   ├── Dockerfile
│   └── src/
│       ├── routers/
│       │   └── workout.py    # POST /workout/generate
│       ├── services/
│       │   └── gemini_service.py  # Gemini API 連携
│       └── schemas/
│           └── workout.py    # 共通JSONスキーマ (Pydantic)
└── frontend/                 # Flutter (iOS / Android)
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── models/
        │   └── workout_plan.dart   # Dart モデル (スキーマと対応)
        ├── services/
        │   └── api_service.dart    # HTTP通信
        └── screens/
            ├── home_screen.dart
            └── workout_plan_screen.dart
```

## セットアップ

### 1. 環境変数

```bash
cp .env.example backend/.env
# backend/.env に GOOGLE_API_KEY を設定
```

### 2. バックエンド起動（Codespace）

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

### 3. Flutter 起動

```bash
cd frontend
flutter pub get
flutter run
```

## API エンドポイント

| メソッド | パス | 説明 |
|------|------|------|
| GET | /health | ヘルスチェック |
| POST | /workout/generate | ワークアウトプラン生成 |

### POST /workout/generate リクエスト例

```json
{
  "goal": "muscle_gain",
  "level": "beginner",
  "days_per_week": 3,
  "equipment": ["barbell", "dumbbell"]
}
```
