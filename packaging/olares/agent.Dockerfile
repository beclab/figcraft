# syntax=docker/dockerfile:1
# Olares agent image: figcraft-cli's headless stdio MCP server behind supergateway (Streamable HTTP).
# Build from the repository root: docker build -f packaging/olares/agent.Dockerfile .
# CI checks storytold/craft-fonts out into ./craft-fonts first; the runtime image has no system
# fonts, so text layout relies on the embedded ones.
ARG RUST_VERSION=1.99
ARG NODE_VERSION=22-bookworm-slim

FROM rust:${RUST_VERSION}-slim-bookworm AS builder
WORKDIR /src
COPY . .
ARG CARGO_BUILD_JOBS=4
ARG CRAFT_FONTS_DIR=/src/craft-fonts
ARG FIGCRAFT_DEFAULT_SERVER=
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/src/target \
    FIGCRAFT_DEFAULT_SERVER="$FIGCRAFT_DEFAULT_SERVER" cargo build --release --locked -p figcraft-cli \
    && install -m 0755 target/release/figcraft-cli /usr/local/bin/figcraft-cli

FROM node:${NODE_VERSION} AS runtime
ARG SUPERGATEWAY_VERSION=4.1.0
RUN npm install -g --omit=dev "supergateway@${SUPERGATEWAY_VERSION}" \
    && npm cache clean --force \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && install -d -o 1000 -g 1000 /data/files
COPY --from=builder /usr/local/bin/figcraft-cli /usr/local/bin/figcraft-cli
COPY LICENSE-MIT LICENSE-APACHE NOTICE ATTRIBUTION.md /usr/share/doc/figcraft/
# figcraft-cli mcp has no root-confinement flags: the /data/files mount is the only boundary.
ENV HOME=/tmp \
    MCP_PORT=8090
USER 1000:1000
WORKDIR /data/files
EXPOSE 8090
CMD ["sh", "-c", "exec supergateway --stdio \"figcraft-cli mcp\" --outputTransport streamableHttp --stateful --sessionTimeout 1800000 --port $MCP_PORT --healthEndpoint /healthz"]
