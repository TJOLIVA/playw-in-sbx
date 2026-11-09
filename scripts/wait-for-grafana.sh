#!/usr/bin/env bash
# Starts the observability sandbox if it is stopped (it stops when idle) and waits until Grafana answers.
set -euo pipefail

OBS="${QA_OBS_SANDBOX:-qa-obs}"
URL="${GRAFANA_URL:-http://127.0.0.1:3000}"

sbx exec "$OBS" true >/dev/null 2>&1 || true   # any exec starts a stopped sandbox

for _ in $(seq 1 60); do
  if curl -fsS -m 3 -o /dev/null "$URL/api/health"; then exit 0; fi
  sleep 3
done
echo "Grafana did not become healthy at $URL (is sandbox '$OBS' created? run scripts/setup.sh)" >&2
exit 1
