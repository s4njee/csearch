FROM postgres:18

# Build this image from the repo root:
# docker build -f k8s/db/Dockerfile .
COPY backend/scraper/schema.sql /docker-entrypoint-initdb.d/001-schema.sql
