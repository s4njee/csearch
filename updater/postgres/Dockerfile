FROM postgres:15

# Build this image from the repo root so the updater bootstrap is unambiguous:
# docker build -f updater/postgres/Dockerfile .
COPY updater/schema.sql /docker-entrypoint-initdb.d/001-schema.sql
