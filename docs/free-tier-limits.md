# InfluxDB Cloud Serverless free plan limits

Limits as understood when this scaffold was written. Verify them against the
current InfluxData pricing and limits pages.

| Item | Limit |
|---|---|
| Writes | 5 MB per 5 minutes |
| Reads | 300 MB per 5 minutes |
| Buckets | 2 |
| Retention | 30 days |

Telegraf Controller free tier: 20 configurations, 100 agents.

## Write-cap arithmetic (measured)

Measured on 2026-10-30 with the shipped config on one host:

- One 30 s collection cycle = 40 points = 9,639 bytes of line protocol
  (including the host tag).
- 5 minutes / 30 s = 10 cycles, so about 96 kB per 5 minutes.
- 96 kB / 5 MB is about 1.9 percent of the write cap.

This replaces the earlier guess of 225 kB per 5 minutes.

The figure depends on series count. Adding per-CPU, per-interface, or
per-container series, more disks, or more containers raises it; re-measure
after any change to the config (see the internal_* metrics in
`critical-metrics.md`).

## Reads

Dashboards that query long ranges at short refresh intervals can consume the
read cap. Prefer downsampled or narrow queries.

## Unverified

- What happens to an inactive free account, and after how long.
- Exact behavior when a cap is exceeded (rejected writes versus throttling).
