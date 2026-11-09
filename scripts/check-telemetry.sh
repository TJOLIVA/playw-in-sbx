#!/usr/bin/env bash
# Confirms that recent Playwright logs reached Loki (via Grafana). Exit 1 if none found.
set -euo pipefail

URL="${GRAFANA_URL:-http://127.0.0.1:3000}"
END=$(( $(date +%s) * 1000000000 ))

count=$(curl -fsS -m 10 -G "$URL/api/datasources/proxy/uid/loki/loki/api/v1/query" \
  --data-urlencode 'query=sum(count_over_time({service_name="playwright-tests"} |= "Run finished" [15m]))' \
  --data-urlencode "time=$END" | python3 -c '
import json, sys
r = json.load(sys.stdin).get("data", {}).get("result", [])
print(int(float(r[0]["value"][1])) if r else 0)')

if [ "$count" -ge 1 ]; then
  echo "Telemetry OK: $count run(s) in the last 15 minutes."
else
  echo "No Playwright telemetry found in Loki in the last 15 minutes." >&2
  exit 1
fi
