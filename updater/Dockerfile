FROM golang:1.26-bookworm AS builder

WORKDIR /src/updater

COPY updater/go.mod updater/go.sum ./
RUN go mod download

COPY updater/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/updater .


FROM python:3.11-slim-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    postgresql-client \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    beautifulsoup4 \
    iso8601 \
    lxml \
    mechanize \
    python-dateutil \
    pytz \
    pyyaml \
    requests \
    rtyaml \
    scrapelib \
    xmltodict

COPY --from=builder /out/updater /usr/local/bin/updater
COPY updater/congress /opt/csearch/congress
COPY updater/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENV CONGRESSDIR=/srv/csearch
ENV POSTGRESURI=postgres

WORKDIR /srv/csearch

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/local/bin/updater"]
