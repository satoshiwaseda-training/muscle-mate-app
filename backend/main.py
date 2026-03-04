"""
Muscle Mate API - FastAPI エントリーポイント
"""
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from src.routers import workout, visualizer

load_dotenv()

app = FastAPI(
    title="Muscle Mate API",
    description="Gemini AIを使った筋トレメニュー生成API",
    version="0.1.0",
)

# CORS: 環境変数 ALLOWED_ORIGINS で本番ドメインを指定
_raw_origins = os.getenv("ALLOWED_ORIGINS", "*")
if _raw_origins == "*":
    allow_origins = ["*"]
else:
    allow_origins = [o.strip() for o in _raw_origins.split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
)

app.include_router(workout.router)
app.include_router(visualizer.router)


@app.get("/health")
async def health():
    return {"status": "ok", "service": "muscle-mate-api"}
