# syntax=docker/dockerfile:1.7

FROM --platform=$BUILDPLATFORM golang:1.25-trixie AS builder

ARG STASHSPHERE_REF=main
ARG TARGETOS=linux
ARG TARGETARCH

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git libmagic-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git init . \
    && git remote add origin https://github.com/stashsphere/stashsphere.git \
    && git fetch --depth 1 origin "${STASHSPHERE_REF}" \
    && git checkout --detach FETCH_HEAD

WORKDIR /src/backend
RUN --mount=type=cache,target=/go/pkg/mod go mod download
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=1 GOOS=${TARGETOS} GOARCH=${TARGETARCH:-amd64} \
    go build -trimpath -ldflags='-s -w' -o /out/stashsphere .

FROM debian:trixie-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash ca-certificates libmagic1 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 10001 --shell /bin/bash stashsphere

WORKDIR /app
COPY --from=builder /out/stashsphere /usr/local/bin/stashsphere
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY docker/default-config.yaml /usr/local/share/stashsphere/default-config.yaml

RUN chmod +x /usr/local/bin/entrypoint.sh \
    && mkdir -p /config /data/image_store /data/image_cache \
    && chown -R stashsphere:stashsphere /config /data /app

ENV STASHSPHERE_CONFIG_DIR=/config \
    STASHSPHERE_CONFIG_FILE=stashsphere.yaml \
    STASHSPHERE_SECRETS_FILE=secrets.yaml \
    STASHSPHERE_AUTO_CREATE_CONFIG=true \
    STASHSPHERE_AUTO_MIGRATE=true \
    STATE_DIRECTORY=/data \
    CACHE_DIRECTORY=/data

VOLUME ["/config", "/data/image_store", "/data/image_cache"]
EXPOSE 8081

USER stashsphere
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["serve"]
