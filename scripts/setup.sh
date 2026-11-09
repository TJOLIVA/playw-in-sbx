#!/usr/bin/env bash
# One-time (idempotent) setup of the QA sandboxes on a team member's Mac.
#   qa-obs  : Grafana LGTM stack (Loki, Tempo, Grafana) -> http://127.0.0.1:3000
#   qa-play : Playwright sandbox built from kits/playwright-qa
# Requires: sbx CLI, signed in (sbx login). No Docker Desktop needed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OBS="${QA_OBS_SANDBOX:-qa-obs}"
PLAY="${QA_PLAY_SANDBOX:-qa-play}"
OBS_TEMPLATE="docker.io/docker/sandbox-templates:shell-docker"

command -v sbx >/dev/null || { echo "sbx CLI not found. Install Docker Sandboxes first." >&2; exit 1; }

exists() { sbx ls 2>/dev/null | awk 'NR>1{print $1}' | grep -qx "$1"; }

echo "==> Checking sbx daemon"
sbx diagnose >/dev/null 2>&1 || { echo "sbx daemon not healthy; try: sbx daemon start" >&2; exit 1; }

echo "==> Observability sandbox ($OBS)"
if ! exists "$OBS"; then
  sbx create --name "$OBS" --template "$OBS_TEMPLATE" -p 3000:3000 -p 4318:4318 shell "$ROOT/observability"
fi
sbx exec -u 0 "$OBS" sh "$ROOT/observability/start.sh"

echo "==> Playwright sandbox ($PLAY)"
if ! exists "$PLAY"; then
  sbx create --name "$PLAY" --kit "$ROOT/kits/playwright-qa" shell "$ROOT"
fi
sbx exec "$PLAY" sh -c "cd '$ROOT' && npm ci && npx playwright install chromium"

echo "==> Waiting for Grafana"
"$ROOT/scripts/wait-for-grafana.sh"

echo "==> Smoke test (also proves telemetry reaches Grafana)"
"$ROOT/scripts/test.sh" --retries=0
"$ROOT/scripts/check-telemetry.sh"

echo "Setup complete. Dashboard: http://127.0.0.1:3000/d/playwright-qa"
