# 2.16 Reproducible Cloud Performance Evaluation and Tail Latency

## Introduction to the Literature Review

Cloud-hosted performance results depend on both the application and the environment used to measure it. Papadopoulos et al. (2021) propose methodological principles for designing and reporting reproducible cloud performance studies, including clear metrics, experimental configuration, repeated observations, shared artifacts, and cost. Baresi et al. (2023) empirically examine VM performance variability across resources, isolation conditions, time, and cost. Together, these works explain why a before/after comparison needs to keep the cloud region, VM size, software images, dataset, and measurement protocol fixed within each pair and report variation across repetitions.

## Key Themes and Findings

The distribution of response times matters in addition to its average. Dean and Barroso (2013) explain how high latency in the tail of a Web service's response-time distribution can dominate user-visible behavior as scale and utilization increase. This supports reporting p95 and p99 latency alongside throughput and error rate. He et al. (2019) study statistical performance testing of cloud applications, reinforcing the need to interpret variable measurements through repeated observations rather than a single favorable run.

## Methodological Gap and Application to This Study

These publications do not prescribe the exact virtual-user counts, pass thresholds, or JMeter timing for this financial API. Those values are predeclared by the present study and must be checked against the actual run. In particular, a configured 500-thread profile is not evidence that 500 users were simultaneously active: the raw JMeter active-thread series must reach and sustain the target through the scored hold. The present study therefore uses the same two VMs and pinned container images for both frozen ASP.NET Core source revisions, restores one hashed synthetic SQL Server backup before every run, alternates the order of three paired repetitions, records container and host resource usage, and retains the raw result files. An unscored pilot checks the load generator before measurements are accepted. These controls implement the reproducibility concerns raised by Papadopoulos et al. (2021) and Baresi et al. (2023); the specific 5-second concurrency rule and timing buffers are this study's own safeguards.

## Critical Analysis

Dedicated virtual CPUs and container limits reduce avoidable interference, but they cannot eliminate all cloud variance. The three paired repetitions permit the report to show spread rather than claim universal performance from one machine. The same workload includes writes, so the database grows during a run; every run begins from the same backup, and resulting row counts must be reported as a limitation when interpreting throughput and latency. A result that fails the predeclared concurrency gate is excluded from the scored comparison even if its request errors are low.

## Verified References

- Papadopoulos, A. V., Versluis, L., Bauer, A., Herbst, N., von Kistowski, J., Ali-Eldin, A., Abad, C. L., Amaral, J. N., Tůma, P., & Iosup, A. (2021). Methodological principles for reproducible performance evaluation in cloud computing. *IEEE Transactions on Software Engineering, 47*(8), 1528–1543. https://doi.org/10.1109/TSE.2019.2927908
- Baresi, L., Dolci, T., Quattrocchi, G., & Rasi, N. (2023). A multi-faceted analysis of the performance variability of virtual machines. *Software: Practice and Experience, 53*(11), 2067–2091. https://doi.org/10.1002/spe.3244
- Dean, J., & Barroso, L. A. (2013). The tail at scale. *Communications of the ACM, 56*(2), 74–80. https://doi.org/10.1145/2408776.2408794
- He, S., Manns, G., Saunders, J., Wang, W., Pollock, L., & Soffa, M. L. (2019). A statistics-based performance testing methodology for cloud applications. *Proceedings of ESEC/FSE 2019*, 188–199. https://doi.org/10.1145/3338906.3338912
