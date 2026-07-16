"""
Crew Intelligence Platform — Python AI Microservices
Single FastAPI entry point. All phase routers mounted here.
"""
from contextlib import asynccontextmanager
import logging
import os
import uvicorn
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

from utils.firebase import initialize_firebase
from utils.version import SERVICE_VERSION
from utils.logging_config import setup_logging
from utils.auth import (
    verify_service_token,
    verify_firebase_auth,
    verify_service_or_user,
)

# ─── Logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
logger = logging.getLogger("cip.main")


# ─── Startup / Shutdown ───────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    setup_logging()  # P2/T6: structured, secret-redacting logs
    logger.info("🚀 CIP Python Services starting...")
    # Fail closed: the service holds crew roster / salary / identity data and
    # must never start without its service-auth secret configured. (0.1)
    if not os.getenv("INTERNAL_SERVICE_TOKEN"):
        logger.critical(
            "INTERNAL_SERVICE_TOKEN is not set — refusing to start (fail closed). "
            "Set it in the environment before launching the service."
        )
        raise RuntimeError("INTERNAL_SERVICE_TOKEN is required but not set")
    # T8 — surface missing recommended config early (warn, do not fail).
    for _var in ("ANTHROPIC_API_KEY", "ALLOWED_ORIGINS"):
        if not os.getenv(_var):
            logger.warning("Recommended env var %s is not set — related behavior may be degraded", _var)
    if os.getenv("ENV") == "production" and not [o for o in os.getenv("ALLOWED_ORIGINS", "").split(",") if o.strip()]:
        logger.warning("ENV=production but ALLOWED_ORIGINS is empty — all cross-origin requests will be blocked")
    initialize_firebase()
    logger.info("✅ Firebase initialized")
    logger.info("✅ Service authentication configured")
    yield
    logger.info("🛑 CIP Python Services shutting down")


# ─── App ──────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Crew Intelligence Platform — AI Services",
    description="Parsing · Legality · AI Assistant · Ranking · Auto-Bid · Intelligence · Layover · Trade Recommendations",
    version=SERVICE_VERSION,
    lifespan=lifespan,
    docs_url="/docs" if os.getenv("ENV") == "development" else None,
    redoc_url=None,
    openapi_url="/openapi.json" if os.getenv("ENV") == "development" else None,
)

# ─── Middleware ───────────────────────────────────────────────────────────────
app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in os.getenv("ALLOWED_ORIGINS", "").split(",") if o.strip()],
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)

# ─── Core routers (existing) ──────────────────────────────────────────────────
from parser.excel_parser      import router as parser_router
from parser.pdf_parser        import router as pdf_parser_router
from parser.prn_parser        import router as prn_router
from legality.engine          import router as legality_router
from ai.nlp_router            import router as ai_router
from ai.status_router         import router as ai_status_router
from ranking.scorer           import router as ranking_router
from auto_bid.engine          import router as auto_bid_router
from salary.calculator        import router as salary_router
from trade_intel.engine       import router as trade_intel_router
from trade_intel.whatsapp     import router as whatsapp_router

app.include_router(parser_router,       prefix="/v1/parser",      dependencies=[Depends(verify_service_token)], tags=["Parser — Excel"])
app.include_router(pdf_parser_router,   prefix="/v1/upload",      dependencies=[Depends(verify_service_or_user)], tags=["Parser — PDF"])
app.include_router(prn_router,          prefix="/v1/prn",         dependencies=[Depends(verify_service_or_user)], tags=["Parser — PRN"])
app.include_router(legality_router,     prefix="/v1/legality",    dependencies=[Depends(verify_service_or_user)], tags=["Legality Engine"])
app.include_router(ai_router,           prefix="/v1/ai",          dependencies=[Depends(verify_service_or_user)], tags=["AI Assistant"])
app.include_router(ai_status_router,    prefix="/v1/ai",          dependencies=[Depends(verify_service_or_user)], tags=["AI Status"])
app.include_router(ranking_router,      prefix="/v1/ranking",     dependencies=[Depends(verify_firebase_auth)], tags=["Smart Ranking"])
app.include_router(auto_bid_router,     prefix="/v1/auto-bid",    dependencies=[Depends(verify_service_or_user)], tags=["Auto Bid"])
app.include_router(salary_router,       prefix="/v1/salary",      dependencies=[Depends(verify_service_or_user)], tags=["Salary Calculator"])
app.include_router(trade_intel_router,  prefix="/v1/trade-intel", dependencies=[Depends(verify_firebase_auth)], tags=["Trade Intelligence"])
app.include_router(whatsapp_router,     prefix="/v1/whatsapp",    dependencies=[Depends(verify_service_or_user)], tags=["WhatsApp"])

# ─── Phase 2: PDF Intelligence Engine ─────────────────────────────────────────
from intelligence.router      import router as intelligence_router
app.include_router(intelligence_router, prefix="/v1/intelligence", dependencies=[Depends(verify_service_or_user)], tags=["PDF Intelligence"])
from filter_engine.router import router as filter_router  # noqa: E402
app.include_router(filter_router, prefix="/v1/lines", dependencies=[Depends(verify_service_or_user)], tags=["Line Search — Filter Engine"])
from roster_sync.router import router as roster_sync_router  # noqa: E402
app.include_router(roster_sync_router, prefix="/v1/roster-sync", dependencies=[Depends(verify_service_or_user)], tags=["Roster Sync"])

# ─── Phase 3: Layover Intelligence ────────────────────────────────────────────
from layover.router           import router as layover_router
app.include_router(layover_router,      prefix="/v1/layover",      dependencies=[Depends(verify_service_or_user)], tags=["Layover Intelligence"])

# ─── Trade Recommendation Engine ─────────────────────────────────────────────
from trade_engine.router      import router as trade_engine_router
app.include_router(trade_engine_router, prefix="/v1/trade",        dependencies=[Depends(verify_service_or_user)], tags=["Trade Recommendations"])

# ─── Rest & Legality Engine ───────────────────────────────────────────────────
from rest_engine.router       import router as rest_router
app.include_router(rest_router,         prefix="/v1/rest",         dependencies=[Depends(verify_firebase_auth)], tags=["Rest & Legality"])

# ─── Operational Knowledge Management System ─────────────────────────────────
from knowledge_engine.router  import router as knowledge_router
app.include_router(knowledge_router,    prefix="/v1/knowledge",    dependencies=[Depends(verify_firebase_auth)], tags=["Knowledge Engine"])

# ─── Subscription System ──────────────────────────────────────────────────────
from subscription_engine.router import router as subscription_router
app.include_router(subscription_router, prefix="/v1/subscription", tags=["Subscription"])


# ─── Health ───────────────────────────────────────────────────────────────────
@app.get("/health", tags=["Health"])
async def health():
    return {
        "status":  "healthy",
        "service": "cip-python-services",
        "version": "2.0.0",
        "phases":  ["core", "intelligence", "layover", "trade-recommendations"],
    }


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8080, reload=False)
