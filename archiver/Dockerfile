FROM alpine:latest
RUN apk --update upgrade && \
    apk add ca-certificates less zstd tar && \
    rm -rf /var/cache/apk/*

ENV ZSTD_CLEVEL=14
ENV ZSTD_NBTHREADS=8

COPY entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh
ENTRYPOINT ./entrypoint.sh
