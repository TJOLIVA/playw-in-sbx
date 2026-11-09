#!/bin/sh
# Starts the Grafana LGTM stack (Loki, Tempo, Grafana, Prometheus, OTel collector).
# Run INSIDE the observability sandbox:  sbx exec -u 0 qa-obs sh <workspace>/start.sh
# Data lives in the "lgtm-data" Docker volume, so it survives container re-creation.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
IMAGE="${LGTM_IMAGE:-grafana/otel-lgtm:latest}"   # pin a version or digest for the team

docker rm -f lgtm >/dev/null 2>&1 || true
docker run -d --name lgtm --restart unless-stopped \
  -p 3000:3000 -p 4318:4318 \
  -v lgtm-data:/data \
  -v "$HERE/dashboards:/qa-dashboards:ro" \
  -v "$HERE/provisioning/qa-dashboards.yaml:/otel-lgtm/grafana/conf/provisioning/dashboards/qa-dashboards.yaml:ro" \
  "$IMAGE"
echo "Grafana: http://127.0.0.1:3000  (OTLP/HTTP: 4318)"
