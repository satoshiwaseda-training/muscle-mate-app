"""
Muscle Mate API - FastAPI エントリーポイント
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from src.routers import workout, visualizer

app = FastAPI(
    title="Muscle Mate API",
    description="Gemini AIを使った筋トレメニュー生成API",
    version="0.1.0",
)

# Flutter（ローカル開発・Codespace）からのアクセスを許可
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 本番では Flutter アプリのドメインに限定すること
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(workout.router)
app.include_router(visualizer.router)


@app.get("/health")
async def health():
    return {"status": "ok", "service": "muscle-mate-api"}
