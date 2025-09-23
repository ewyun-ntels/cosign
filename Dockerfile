############################
# 1) Build kaniko executor
############################
FROM golang:1.24-alpine AS kaniko-builder
RUN apk add --no-cache git ca-certificates
ARG KANIKO_VERSION=v1.25.0
WORKDIR /src
RUN git clone --depth=1 --branch "${KANIKO_VERSION}" https://github.com/chainguard-dev/kaniko.git .
# 정적 빌드
RUN CGO_ENABLED=0 GOFLAGS="-trimpath -buildvcs=false" \
    go build -o /out/executor ./cmd/executor

##########################
# 2) Build cosign (from local source)
##########################
FROM golang:1.24-alpine AS cosign-builder
RUN apk add --no-cache git ca-certificates
WORKDIR /src
# 캐시 최적화를 위해 go.mod/go.sum 먼저 복사
COPY go.mod go.sum ./
RUN go mod download
# 나머지 소스 복사
COPY . .
# Makefile에서 넘겨줄 LDFLAGS를 그대로 사용
ARG LDFLAGS=""
ENV CGO_ENABLED=0 GOFLAGS="-trimpath -buildvcs=false"
RUN go build -ldflags "$LDFLAGS" -o /out/cosign ./cmd/cosign

##########################
# 3) Final runtime
##########################
FROM alpine:3.20
RUN apk add --no-cache ca-certificates
WORKDIR /workspace

# 바이너리 배치
COPY --from=kaniko-builder  /out/executor /kaniko/executor
COPY --from=cosign-builder  /out/cosign   /usr/local/bin/cosign

RUN chmod +x /kaniko/executor /usr/local/bin/cosign

# 필요 시 사설 CA:
# COPY rootCA.crt /usr/local/share/ca-certificates/rootCA.crt
# RUN update-ca-certificates
