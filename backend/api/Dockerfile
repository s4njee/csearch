FROM python:3.11-slim-bookworm

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
# Source of truth for explore queries lives in backend/scraper/explore.sql (so
# the Rust scraper and FastAPI app share one file). It's copied below; this env
# var lets the non-editable install find it regardless of site-packages layout.
ENV CSEARCH_EXPLORE_SQL=/app/sql/explore.sql

COPY backend/api/pyproject.toml /app/backend/api/pyproject.toml
COPY backend/api/src /app/backend/api/src
COPY backend/scraper/explore.sql /app/sql/explore.sql

# Non-editable install: the package is built into site-packages, not run from
# the source tree.
RUN pip install --no-cache-dir /app/backend/api

# Run as an unprivileged user.
RUN useradd --create-home --uid 10001 appuser \
    && chown -R appuser:appuser /app
USER appuser

EXPOSE 3000

# Liveness probe hits /livez (no external dependencies).
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:3000/livez', timeout=2).status == 200 else 1)"

CMD ["uvicorn", "csearch_api.main:app", "--host", "0.0.0.0", "--port", "3000"]
