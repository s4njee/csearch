FROM postgres:18

# Build this image from the repo root:
# docker build -f k8s/db/Dockerfile .
RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-18-pgvector \
    && rm -rf /var/lib/apt/lists/*
COPY backend/scraper/schema.sql /docker-entrypoint-initdb.d/001-schema.sql
