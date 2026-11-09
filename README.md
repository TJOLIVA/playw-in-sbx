# QA automation sandbox

Playwright tests that run inside a [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`) microVM, with logs and traces in Grafana. No Docker Desktop required.

```
Mac ── scripts/test.sh ──► qa-play sandbox (Playwright + Chromium, restricted network)
                               │  OTLP/HTTP → host :4318
                               ▼
                           qa-obs sandbox (Grafana LGTM: Loki, Tempo, Grafana) → http://127.0.0.1:3000
```

## First-time setup

1. Install the `sbx` CLI and sign in (`sbx login`). Use the same `sbx` version as the team (see "Versions").
2. `scripts/setup.sh` — creates both sandboxes, installs dependencies, runs a smoke test and checks that telemetry reached Grafana. The first run downloads large images and can take a long time.

## Daily use

| Task | Command |
| --- | --- |
| Run all tests | `scripts/test.sh` |
| Run one file | `scripts/test.sh tests/example.spec.ts` |
| Another environment | `BASE_URL=https://test-env.example scripts/test.sh` |
| Dashboard | http://127.0.0.1:3000/d/playwright-qa |
| Confirm telemetry arrived | `scripts/check-telemetry.sh` |

`qa-obs` stops itself when idle; `scripts/test.sh` restarts it first. Edit tests in your normal editor — the project folder is shared with the sandbox.

## Configuration and sharing

- `kits/playwright-qa/spec.yaml` — the sandbox mixin: tooling, allowed network hosts, telemetry endpoint. Add the host of the application under test to `permissions.network.allow`, and review changes like any code.
- `observability/` — Grafana stack start script and the provisioned "Playwright QA" dashboard.
- `reporters/otlp-reporter.ts` — sends one log per test result and one trace span per test. Enabled only when `OTEL_EXPORTER_OTLP_ENDPOINT` is set.
- Playwright is pinned to the same version in `package.json` and the kit. Change both together.

## Data handling

- Use test accounts and synthetic data only. Error messages are sent to Grafana logs and may contain page text.
- Never commit credentials. `.env` files are git-ignored. Use CI secrets/variables for anything sensitive.
- Grafana data stays on your machine in the `lgtm-data` volume inside `qa-obs`.

## CI

`.github/workflows/playwright.yml` runs the tests on pull requests and pushes to `main` and uploads the HTML report. Set the repository variable `BASE_URL` for the environment under test.

## Versions

Kits are experimental in `sbx` and kit versions can be incompatible across `sbx` releases. Current development version: sbx v0.50.1.
