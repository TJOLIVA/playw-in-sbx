import type {
  FullConfig,
  FullResult,
  Reporter,
  Suite,
  TestCase,
  TestResult,
} from '@playwright/test/reporter';
import { randomBytes } from 'node:crypto';

/**
 * Minimal OTLP/HTTP (JSON) reporter: one log record per test result and one span per test,
 * plus a parent span for the run. No third-party dependencies.
 *
 * Config (environment):
 *   OTEL_EXPORTER_OTLP_ENDPOINT  base URL of the collector, default http://localhost:4318
 *   OTEL_SERVICE_NAME            default "playwright-tests"
 *   OTEL_LOG_MAX_ERROR_CHARS     truncate error text, default 2000
 *
 * Failures to export never fail the test run.
 */

type KV = { key: string; value: Record<string, unknown> };

const endpoint = (process.env.OTEL_EXPORTER_OTLP_ENDPOINT ?? 'http://localhost:4318').replace(/\/$/, '');
const serviceName = process.env.OTEL_SERVICE_NAME ?? 'playwright-tests';
const maxErr = Number(process.env.OTEL_LOG_MAX_ERROR_CHARS ?? 2000);

const hex = (bytes: number) => randomBytes(bytes).toString('hex');
const nano = (ms: number) => String(Math.round(ms * 1e6));
const attr = (key: string, v: string | number | boolean): KV => ({
  key,
  value: typeof v === 'string' ? { stringValue: v } : typeof v === 'boolean' ? { boolValue: v } : { intValue: String(v) },
});
// Strip ANSI colour codes that Playwright adds to error text.
const clean = (s: string) => s.replace(/\u001b\[[0-9;]*m/g, '').slice(0, maxErr);
const resource = { attributes: [attr('service.name', serviceName)] };

class OtlpReporter implements Reporter {
  private traceId = hex(16);
  private runSpanId = hex(8);
  private runStart = Date.now();
  private logs: Record<string, unknown>[] = [];
  private spans: Record<string, unknown>[] = [];

  onBegin(_config: FullConfig, suite: Suite) {
    this.runStart = Date.now();
    this.log('INFO', `Run started: ${suite.allTests().length} tests`, []);
  }

  onStdOut(chunk: string | Buffer, test?: TestCase) {
    this.log('INFO', String(chunk).trimEnd(), test ? [attr('test.title', test.title)] : []);
  }

  onStdErr(chunk: string | Buffer, test?: TestCase) {
    this.log('WARN', String(chunk).trimEnd(), test ? [attr('test.title', test.title)] : []);
  }

  onTestEnd(test: TestCase, result: TestResult) {
    const failed = result.status !== 'passed' && result.status !== 'skipped';
    const attrs = [
      attr('test.title', test.title),
      attr('test.file', test.location.file.split('/').slice(-2).join('/')),
      attr('test.project', test.parent.project()?.name ?? ''),
      attr('test.status', result.status),
      attr('test.retry', result.retry),
      attr('test.duration_ms', result.duration),
    ];
    const err = result.error?.message ? clean(result.error.message) : '';
    const spanId = hex(8);

    this.log(failed ? 'ERROR' : 'INFO', `${test.title}: ${result.status}${err ? `\n${err}` : ''}`, attrs, spanId);
    this.spans.push({
      traceId: this.traceId,
      spanId,
      parentSpanId: this.runSpanId,
      name: test.title,
      kind: 1,
      startTimeUnixNano: nano(result.startTime.getTime()),
      endTimeUnixNano: nano(result.startTime.getTime() + result.duration),
      attributes: attrs,
      status: { code: failed ? 2 : 1, message: failed ? err.slice(0, 200) : '' },
    });
  }

  async onEnd(result: FullResult) {
    const end = Date.now();
    this.log(result.status === 'passed' ? 'INFO' : 'ERROR', `Run finished: ${result.status}`, []);
    this.spans.push({
      traceId: this.traceId,
      spanId: this.runSpanId,
      name: 'playwright run',
      kind: 1,
      startTimeUnixNano: nano(this.runStart),
      endTimeUnixNano: nano(end),
      attributes: [attr('run.status', result.status)],
      status: { code: result.status === 'passed' ? 1 : 2 },
    });
    await Promise.all([
      this.post('/v1/logs', { resourceLogs: [{ resource, scopeLogs: [{ scope: { name: 'playwright-otlp-reporter' }, logRecords: this.logs }] }] }),
      this.post('/v1/traces', { resourceSpans: [{ resource, scopeSpans: [{ scope: { name: 'playwright-otlp-reporter' }, spans: this.spans }] }] }),
    ]);
  }

  printsToStdio() {
    return false;
  }

  private log(level: 'INFO' | 'WARN' | 'ERROR', body: string, attributes: KV[], spanId?: string) {
    this.logs.push({
      timeUnixNano: nano(Date.now()),
      severityText: level,
      severityNumber: level === 'INFO' ? 9 : level === 'WARN' ? 13 : 17,
      body: { stringValue: body },
      attributes,
      traceId: this.traceId,
      ...(spanId ? { spanId } : {}),
    });
  }

  private async post(path: string, payload: unknown) {
    try {
      const res = await fetch(`${endpoint}${path}`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(5000),
      });
      if (!res.ok) console.warn(`[otlp-reporter] ${path} -> HTTP ${res.status}`);
    } catch (e) {
      console.warn(`[otlp-reporter] could not reach ${endpoint}${path}: ${(e as Error).message}`);
    }
  }
}

export default OtlpReporter;
