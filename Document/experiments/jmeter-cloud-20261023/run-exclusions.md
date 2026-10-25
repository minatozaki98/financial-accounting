# Excluded controlled JMeter attempts

The study keeps raw files for failed attempts and excludes them from scored before/after pairs. Exclusion is based on the predeclared validity protocol, regardless of whether a partial latency result looks favorable.

| Attempt | Observation | Exclusion reason | Follow-up |
| --- | --- | --- | --- |
| `p50-r1-before-a1` | The 50-user JMeter run completed with zero reported request errors. Its JTL and JMeter log were copied locally. | The target host collector did not start because the runner created its results directory only on the generator. The required target CPU/memory record is absent, so resource validity cannot be established. | Fixed the shared runner in commit `340d108`; a focused test and live collector smoke passed on both VMs. Rerun the entire before/after pair as attempt `a2`. No source build, JMX file, dataset, or resource cap changed. |

No attempt in this table is used in the three-repeat comparison.
