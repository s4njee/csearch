FROM golang:1.24.2-alpine AS build
WORKDIR /src

COPY backend/log-collector/go.mod ./
COPY backend/log-collector/main.go ./

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /out/log-collector .

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app

COPY --from=build /out/log-collector /app/log-collector

ENV LOG_COLLECTOR_DIR=/var/log/csearch-collector
ENV LOG_COLLECTOR_LISTEN_ADDR=:8080

EXPOSE 8080

ENTRYPOINT ["/app/log-collector"]
