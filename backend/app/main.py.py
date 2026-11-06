
from contextlib import asynccontextmanager

import psycopg
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.openapi.docs import (
    get_swagger_ui_html,
    get_swagger_ui_oauth2_redirect_html,
)

from app.config import get_settings
from app.database import open_pool, close_pool
from app.routers import auth, accounts, loans, dashboard, admin_records


@asynccontextmanager
async def lifespan(app: FastAPI):
    open_pool()
    try:
        yield
    finally:
        close_pool()


settings = get_settings()

app = FastAPI(
    title="Banking Transaction & Account Management API",
    version="0.1.0",
    description=(
        "Academic prototype API. Use synthetic data only; "
        "not for real banking."
    ),
    lifespan=lifespan,
    docs_url=None,
    redoc_url=None,
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)


app.include_router(auth.router)
app.include_router(accounts.router)
app.include_router(loans.router)
app.include_router(dashboard.router)
app.include_router(admin_records.router)


@app.get("/docs", include_in_schema=False)
async def custom_swagger_docs():
    return get_swagger_ui_html(
        openapi_url=app.openapi_url,
        title=f"{app.title} - Swagger UI",
        oauth2_redirect_url=app.swagger_ui_oauth2_redirect_url,
        swagger_js_url=(
            "https://unpkg.com/swagger-ui-dist@5/"
            "swagger-ui-bundle.js"
        ),
        swagger_css_url=(
            "https://unpkg.com/swagger-ui-dist@5/"
            "swagger-ui.css"
        ),
    )


@app.get(
    app.swagger_ui_oauth2_redirect_url,
    include_in_schema=False,
)
async def swagger_redirect():
    return get_swagger_ui_oauth2_redirect_html()


@app.exception_handler(psycopg.errors.RaiseException)
async def database_business_error_handler(
    request: Request,
    exc: psycopg.errors.RaiseException,
):
    return JSONResponse(
        status_code=409,
        content={
            "detail": (
                "The requested operation could not be completed "
                "under current banking rules"
            )
        },
    )


@app.exception_handler(psycopg.errors.UniqueViolation)
async def database_unique_error_handler(
    request: Request,
    exc: psycopg.errors.UniqueViolation,
):
    return JSONResponse(
        status_code=409,
        content={
            "detail": (
                "A record with the supplied identifier already exists"
            )
        },
    )


@app.exception_handler(psycopg.OperationalError)
async def database_unavailable_handler(
    request: Request,
    exc: psycopg.OperationalError,
):
    return JSONResponse(
        status_code=503,
        content={
            "detail": "Database service is temporarily unavailable"
        },
    )


@app.get("/health")
def health():
    return {"status": "ok"}
