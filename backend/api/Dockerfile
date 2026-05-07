FROM python:3.11-slim-bookworm

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY backend/api/pyproject.toml /app/backend/api/pyproject.toml
COPY backend/api/src /app/backend/api/src
# Source of truth lives in backend/scraper/explore.sql (so the Rust scraper
# and FastAPI app share one file). The API runtime expects it at
# /app/backend/api/sql/explore.sql.
COPY backend/scraper/explore.sql /app/backend/api/sql/explore.sql

RUN pip install --no-cache-dir -e /app/backend/api

EXPOSE 3000

CMD ["uvicorn", "csearch_api.main:app", "--host", "0.0.0.0", "--port", "3000"]
