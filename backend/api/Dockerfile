FROM golang:1.25-alpine AS builder
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /api ./cmd/api

FROM alpine:3.22
RUN addgroup -S sherwood && adduser -S sherwood -G sherwood && apk add --no-cache ca-certificates wget
COPY --from=builder /api /api
USER sherwood
EXPOSE 8080
ENTRYPOINT ["/api"]
