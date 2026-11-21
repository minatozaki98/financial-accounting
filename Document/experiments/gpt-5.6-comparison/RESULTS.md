# GPT-5.6 benchmark results

## Code quality

Every candidate passed all 98 original tests. The pre-fix revision had one bug and six code smells. GPT-5.5 retained one bug. Each GPT-5.6 variant reached zero open findings. See [SonarQube results and evidence](sonar/RESULTS.md).

## Security

Each figure below counts alert categories / alert instances. Counts include informational alerts. High and medium counts are instances across both modes.

| Candidate | ZAP spider | ZAP OpenAPI | High | Medium | Routes reached, spider / API | Swagger operations rendered |
|---|---:|---:|---:|---:|---:|---:|
| [Pre-fix](zap/fa-baseline) | 12 / 37 | 6 / 20 | 1 | 4 | 12 / 24 | 0 |
| [GPT-5.5](zap/fa-55-reference) | 5 / 13 | 4 / 18 | 1 | 0 | 12 / 24 | 0 |
| [GPT-5.6 Luna](zap/fa-56-luna) | 5 / 16 | 4 / 18 | 1 | 0 | 12 / 24 | 23 |
| [GPT-5.6 Terra](zap/fa-56-terra) | 4 / 15 | 4 / 18 | 0 | 0 | 12 / 24 | 23 |
| [GPT-5.6 Sol](zap/fa-56-sol) | 4 / 16 | 4 / 18 | 0 | 0 | 12 / 24 | 23 |

### Security candidate tests

| Candidate | Unit | Integration | Security attempts |
|---|---:|---:|---:|
| GPT-5.5 | 2/2 | 99/99 | Frozen reference |
| GPT-5.6 Luna | 2/2 | 97/97 | 3 |
| GPT-5.6 Terra | 2/2 | 98/98 | 2 |
| GPT-5.6 Sol | 2/2 | 100/100 | 2 |

### Interpretation

All five OpenAPI scans reached the same 24 method/path pairs, including the Swagger document. Each separately passed six anonymous access checks, three test-user creation checks, and seven role checks. The scanner successfully read the signed-in user endpoint. No tested business route had a High or Medium passive alert.

- Pre-fix — Vulnerable JS Library, Content Security Policy (CSP) Header Not Set, Missing Anti-clickjacking Header.
- GPT-5.5 — Vulnerable JS Library.
- GPT-5.6 Luna — Vulnerable JS Library.
- GPT-5.6 Terra — zero High or Medium findings in either scan.
- GPT-5.6 Sol — zero High or Medium findings in either scan.

Low and informational findings may remain in candidates with zero High and Medium findings. Alert instances can repeat across URLs. The reports contain scanner observations, including version-signature matches in the served Swagger bundle. They do not establish exploitability.

### Measurement conditions

ZAP 2.17.0 ran in two passive modes on the same local HTTP origin. The spider used the project baseline rules. The safe-mode OpenAPI import used the project API rules, a synthetic admin session, and the same API version header. A dedicated LocalDB database was restored from the same seeded backup before each measurement. Fresh GPT-5.5 numbers use the same modes as GPT-5.6. The historical active API-scan counts are a different measurement.

The browser smoke check counted actual Swagger operation panels rendered in headless Chrome. A zero means no operation panels rendered in this local configuration. The route coverage figures come from application request logs for scanner-origin traffic.

The [environment manifest](environment.json), [frozen source and ZAP results](zap), and [raw-report locations and hashes](zap/raw-index.json) accompany this comparison. Deployment and JMeter measurements are deferred.

Luna retained the High scanner finding on the Swagger bundle containing DOMPurify 3.4.16 after its third attempt. Terra and Sol served updated bundles and cleared that finding on .NET 8. Their one-instance difference in the spider scan came from informational cacheability observations.
