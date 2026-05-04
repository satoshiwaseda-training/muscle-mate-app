"""
独自エラーハンドラ（計画書 v5 §11.4）

FastAPI のデフォルト RequestValidationError ハンドラは `input` フィールドに
リクエスト本文の値を含めるため、永続化禁止ポリシーに違反する。本モジュールで
上書きし、入力値を一切返さない。
"""
from __future__ import annotations

from fastapi import Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


async def validation_exception_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    """RequestValidationError を input なしで返す。

    Pydantic v2 のデフォルトは [{"type", "loc", "msg", "input", "url", ...}] を返すが、
    ここでは {"type", "loc", "msg"} のみに削減する（`input` を含めない）。
    """
    safe_errors = []
    for err in exc.errors():
        safe_errors.append(
            {
                "type": err.get("type"),
                "loc": err.get("loc"),
                "msg": err.get("msg"),
            }
        )
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"errors": safe_errors},
    )


async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """予期しない例外。トレースバックや入力値を返さない。"""
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"errors": [{"type": "internal_error", "msg": "Internal Server Error"}]},
    )
