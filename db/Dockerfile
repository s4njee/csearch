# Migrations image — the single schema mechanism for every cluster (E3 §3.1).
#
# Ships db/migrate.py, the full db/migrations/ chain, and db/seed/ so a Job can
# apply the identical migration sequence to netcup and freya. Bootstrap and
# ongoing migration are the same code path: migrate.py is idempotent — against
# an empty database it applies everything; against a current one it's a no-op.
#
# Base is pgvector/pgvector:pg18 (already cached on both clusters, so no extra
# pull) for a matching psql client; migrate.py shells out to psql per file.
FROM pgvector/pgvector:pg18

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /db
# Build context is the repo root (see build-images.yml).
COPY db/migrate.py ./migrate.py
COPY db/migrations ./migrations
COPY db/seed ./seed

# Run as the same non-root uid the DB pods use.
USER 999

# Connection comes from PG* env vars (or --dsn) supplied by the Job.
ENTRYPOINT ["python3", "migrate.py"]
