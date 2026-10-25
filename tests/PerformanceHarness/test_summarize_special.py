from pathlib import Path
import sys
import tempfile
import unittest


MODULE_DIR = Path(__file__).resolve().parents[2] / "scripts/phase4/cloud-jmeter"
sys.path.insert(0, str(MODULE_DIR))
from summarize_special import SPIKE_PHASES, summarize_soak, summarize_spike  # noqa: E402


HEADER = "timeStamp,allThreads,threadName,label,elapsed,success,responseCode\n"


class SpecialSummaryTests(unittest.TestCase):
    def test_spike_checks_base_peak_and_recovery_separately(self):
        with tempfile.TemporaryDirectory() as directory:
            jtl, log = Path(directory) / "spike.jtl", Path(directory) / "spike.log"
            rows = [HEADER]
            for name, (start, end, users) in SPIKE_PHASES.items():
                elapsed = {"base": 100, "peak": 200, "recovery": 110}[name]
                for second in range(start, end, 5):
                    rows.append(f"{1000 + second * 1000},{users},thread-{name},GET /accounts,{elapsed},true,200\n")
            jtl.write_text("".join(rows))
            log.write_text("INFO Running test (1000)\n")
            result = summarize_spike(jtl, log)
            self.assertTrue(result["valid_run"])
            self.assertEqual(result["recovery_p95_drift_pct"], 10)
            self.assertTrue(all(value["valid"] for value in result["concurrency"].values()))
            self.assertIn("legacy_first_last_20pct_samples", result)

    def test_soak_reports_drift_failure_without_invalidating_measurement(self):
        with tempfile.TemporaryDirectory() as directory:
            jtl, log = Path(directory) / "soak.jtl", Path(directory) / "soak.log"
            rows = [HEADER]
            for second in range(120, 2820, 5):
                elapsed = 130 if second >= 2220 else 100
                rows.append(f"{1000 + second * 1000},100,thread-a,GET /accounts,{elapsed},true,200\n")
            jtl.write_text("".join(rows))
            log.write_text("INFO Running test (1000)\n")
            result = summarize_soak(jtl, log)
            self.assertTrue(result["valid_run"])
            self.assertEqual(result["soak"]["p95_drift_pct"], 30)
            self.assertFalse(result["performance_gates"]["p95_drift_at_most_20"])
            self.assertEqual(result["legacy_first_last_20pct_samples"]["window_samples"], 108)


if __name__ == "__main__":
    unittest.main()
