FROM --platform=$BUILDPLATFORM node:22-alpine AS frontend-builder
WORKDIR /frontend
RUN npm install --global pnpm@10.32.1
COPY frontend/package.json frontend/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY frontend/ ./
RUN pnpm build

FROM python:3.11-slim-bookworm AS python-builder
WORKDIR /app
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.11-slim-bookworm AS runtime
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    TZ=Asia/Shanghai \
    DOCKER_ENV=true \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    DB_PATH=/app/data/xianyu_data.db \
    SQL_LOG_ENABLED=false \
    PATH="/opt/venv/bin:$PATH"
WORKDIR /app
LABEL org.opencontainers.image.source="https://github.com/mu-zi-lee/xianyu-super-butler" \
      org.opencontainers.image.title="闲鱼超级管家"

COPY --from=python-builder /opt/venv /opt/venv
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl nodejs chromium tini xvfb xauth \
        tzdata fonts-noto-cjk libgl1 libglib2.0-0 \
    && playwright install --with-deps chromium \
    && rm -rf /var/lib/apt/lists/*

COPY *.py ./
COPY utils/ ./utils/
COPY docker/ ./docker/
COPY captcha_control.html ./
COPY global_config.yml ./global_config.default.yml
COPY static/xianyu_js_version_2.js ./static/xianyu_js_version_2.js
COPY --from=frontend-builder /static/ ./static/

RUN mkdir -p /app/data \
    && ln -s /app/data/global_config.yml /app/global_config.yml \
    && ln -s /app/data/logs /app/logs \
    && ln -s /app/data/backups /app/backups \
    && ln -s /app/data/browser_data /app/browser_data \
    && ln -s /app/data/trajectory_history /app/trajectory_history \
    && ln -s /app/data/slider_cookies /app/slider_cookies \
    && ln -s /app/data/uploads /app/static/uploads

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl --fail --silent http://127.0.0.1:8080/health || exit 1
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/bin/sh", "/app/docker/entrypoint.sh"]
CMD ["python", "/app/Start.py"]
