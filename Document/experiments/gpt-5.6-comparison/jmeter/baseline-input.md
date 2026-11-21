Overall baseline JTL summary:

| Run | Samples | Throughput/s | Error rate | Avg ms | p95 ms | p99 ms | Max ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| p50 | 2050 | 53.35 | 0.00% | 11 | 24 | 61 | 685 |
| p100 | 4700 | 59.47 | 0.00% | 39 | 113 | 584 | 1758 |
| p500 | 12000 | 62.99 | 0.00% | 25 | 88 | 169 | 569 |
| soak | 104530 | 162.37 | 0.00% | 147 | 560 | 1244 | 5566 |
| spike | 46500 | 149.86 | 0.00% | 1299 | 4378 | 7621 | 16007 |

Endpoint-level baseline bottlenecks:

- `GET /reports/account-ledger` was the worst report endpoint in high-load runs: p100 p99 740 ms, p500 p99 348 ms, soak p99 2912 ms, spike p99 12300 ms.
- `GET /reports/trial-balance` was also high: p100 p99 923 ms, soak p99 1644 ms, spike p99 12148 ms.
- Read-heavy lookup/list endpoints drifted during soak/spike: `GET /accounts` soak p99 1224 ms and spike p99 6213 ms; `GET /journal-entries` soak p99 987 ms and spike p99 5241 ms.
- Soak drift: first high-throughput minutes had p99 966-1566 ms and later low-throughput buckets still had p99 up to 3372 ms.
- Spike recovery: p99 stayed above 4 seconds for most 10-second buckets until the final tail buckets; recovery was slow despite 0% errors.
