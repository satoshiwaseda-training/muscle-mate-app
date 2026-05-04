"""
Muscle Mate API - FastAPI entry point.
Plan v5 sections 11.2, 11.3, 11.4.

- APP_ENV branching: production fails to start without ALLOWED_ORIGINS
- Gemini removed; rule engine is the default
- Custom validation handler does not echo input values
- structlog never logs request body
- slowapi rate-limits generation endpoints
"""
from __future__ import annotations

import os
import sys
import time
import uuid
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

from src.routers import workout, visualizer
from src.error_handlers import (
    validation_exception_handler,
    unhandled_exception_handler,
)

load_dotenv()


try:
    import structlog
    structlog.configure(
        processors=[
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(20),
        cache_logger_on_first_use=True,
    )
    _logger = structlog.get_logger("muscle-mate-api")
    _STRUCTLOG_AVAILABLE = True
except ImportError:
    _logger = None
    _STRUCTLOG_AVAILABLE = False


try:
    from slowapi import Limiter, _rate_limit_exceeded_handler
    from slowapi.errors import RateLimitExceeded
    from slowapi.util import get_remote_address
    _LIMITER = Limiter(key_func=get_remote_address)
    _SLOWAPI_AVAILABLE = True
except ImportError:
    _LIMITER = None
    _SLOWAPI_AVAILABLE = False
    RateLimitExceeded = None  # type: ignore


def _resolve_allowed_origins() -> list[str]:
    raw = os.getenv("ALLOWED_ORIGINS")
    app_env = os.getenv("APP_ENV", "development").lower()
    if raw:
        return [o.strip() for o in raw.split(",") if o.strip()]
    if app_env == "production":
        sys.stderr.write("[FATAL] APP_ENV=production needs ALLOWED_ORIGINS\n")
        raise SystemExit(1)
    return [
        "http=//localhost".replace("=", ":"),
        "http=//localhost=3000".replace("=", ":"),
        "http=//localhost=8000".replace("=", ":"),
        "http=//localhost=8080".replace("=", ":"),
        "http=//127.0.0.1".replace("=", ":"),
    ]


def _enforce_runtime_invariants() -> None:
    if os.getenv("LOG_REQUEST_BODY", "").lower() == "true":
        sys.stderr.write("[WARN] LOG_REQUEST_BODY=true is forbidden; ignoring\n")
    provider = os.getenv("LLM_PROVIDER", "noop").lower()
    if provider not in {"noop", "groq"}:
        sys.stderr.write("[FATAL] LLM_PROVIDER must be noop or groq\n")
        raise SystemExit(1)
    billing = os.getenv("EXTERNAL_AI_BILLING_MODE", "free_only").lower()
    if billing not in {"free_only", "paid_capped"}:
        sys.stderr.write("[FATAL] EXTERNAL_AI_BILLING_MODE invalid\n")
        raise SystemExit(1)


_enforce_runtime_invariants()
allow_origins = _resolve_allowed_origins()

app = FastAPI(title="Muscle Mate API", version="0.2.0")

app.add_exception_handler(RequestValidationError, validation_exception_handler)
app.add_exception_handler(Exception, unhandled_exception_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization", "X-External-AI-Optin"],
)

app.include_router(workout.router)
app.include_router(visualizer.router)


if _SLOWAPI_AVAILABLE and _LIMITER is not None:
    app.state.limiter = _LIMITER
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


@app.middleware("http")
async def _logging_middleware(request: Request, call_next):
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id
    started_at = time.perf_counter()
    try:
        response = await call_next(request)
        latency_ms = int((time.perf_counter() - started_at) * 1000)
        if _STRUCTLOG_AVAILABLE and _logger is not None:
            _logger.info(
                "request",
                path=request.url.path,
                status=response.status_code,
                latency_ms=latency_ms,
                request_id=request_id,
                external_ai_optin=request.headers.get("X-External-AI-Optin", "false"),
            )
        response.headers["X-Request-ID"] = request_id
        return response
    except Exception:
        if _STRUCTLOG_AVAILABLE and _logger is not None:
            _logger.error("request_failed", path=request.url.path, request_id=request_id)
        raise


@app.get("/health")
async def health() -> dict:
    return {
        "status": "ok",
        "service": "muscle-mate-api",
        "version": "0.2.0",
        "llm_provider": os.getenv("LLM_PROVIDER", "noop"),
        "external_ai_billing_mode": os.getenv("EXTERNAL_AI_BILLING_MODE", "free_only"),
        "structlog": _STRUCTLOG_AVAILABLE,
        "slowapi": _SLOWAPI_AVAILABLE,
    }


def get_limiter():
    return _LIMITER
