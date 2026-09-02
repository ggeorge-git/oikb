FROM python:3.11-slim-bookworm AS builder

# Install system CA certificates
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Add corporate CA
COPY certs/company-ca-bundle.pem /usr/local/share/ca-certificates/company-ca.crt

# Rebuild Debian's CA trust store
RUN update-ca-certificates

COPY --from=docker.io/astral/uv:latest /uv /uvx /bin/

ENV UV_LINK_MODE=copy

WORKDIR /app

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --system-certs --extra all --no-install-project --no-dev

COPY pyproject.toml LICENSE README.md ./
COPY src/ ./src/

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --system-certs --extra all --no-dev


FROM python:3.11-slim-bookworm
LABEL org.opencontainers.image.description="CLI tool for syncing content to Open WebUI Knowledge Bases" \
      org.opencontainers.image.source="https://github.com/open-webui/oikb" \
      org.opencontainers.image.vendor="Open WebUI Inc." \
      org.opencontainers.image.licenses="MIT"
ENV PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1000 appuser \
    && useradd --uid 1000 --gid appuser --create-home --shell /usr/sbin/nologin appuser

COPY --from=builder --chown=appuser:appuser /app /app

WORKDIR /app

USER appuser

ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8080

ENTRYPOINT ["oikb"]
