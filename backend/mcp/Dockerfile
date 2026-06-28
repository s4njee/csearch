FROM python:3.11-slim-bookworm

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
# Hosted default: talk to the public API and serve MCP over HTTP.
ENV CSEARCH_API_BASE=https://api.csearch.org

COPY pyproject.toml /app/pyproject.toml
COPY src /app/src

RUN pip install --no-cache-dir .

# Run as an unprivileged user.
RUN useradd --create-home --uid 10001 appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

CMD ["csearch-mcp", "--http", "--host", "0.0.0.0", "--port", "8000"]
