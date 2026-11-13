#!/usr/bin/env bash
# Starts the observability sandbox if it is stopped (it stops when idle) and waits until the stack
# can actually ingest data: Grafana healthy, Loki ready and the OTLP receiver accepting requests.
set -euo pipefail

OBS="${QA_OBS_SANDBOX:-qa-obs}"
URL="${GRAFANA_URL:-http://127.0.0.1:3000}"
OTLP="${OTLP_URL:-http://127.0.0.1:4318}"

sbx exec "$OBS" true >/dev/null 2>&1 || true   # any exec starts a stopped sandbox

ready() {
  curl -fsS -m 3 -o /dev/null "$URL/api/health" &&
    curl -fsS -m 3 "$URL/api/datasources/proxy/uid/loki/ready" 2>/dev/null | grep -q ready &&
    curl -fsS -m 3 -o /dev/null -X POST -H 'content-type: application/json' -d '{}' "$OTLP/v1/logs"
}

for _ in $(seq 1 60); do
  if ready; then exit 0; fi
  sleep 3
done
echo "Observability stack not ready (Grafana $URL, OTLP $OTLP). Is sandbox '$OBS' created? Run scripts/setup.sh" >&2
exit 1
