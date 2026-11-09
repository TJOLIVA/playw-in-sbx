#!/usr/bin/env bash
# Run the Playwright tests inside the sandbox. Extra arguments go to `playwright test`.
#   scripts/test.sh                      all tests
#   scripts/test.sh tests/login.spec.ts  one file
#   BASE_URL=https://test.example scripts/test.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLAY="${QA_PLAY_SANDBOX:-qa-play}"

"$ROOT/scripts/wait-for-grafana.sh"   # telemetry is dropped if the observability sandbox is stopped

args=""
for a in "$@"; do args="$args '$a'"; done

sbx exec -e "BASE_URL=${BASE_URL:-}" "$PLAY" sh -c "cd '$ROOT' && npx playwright test $args"
