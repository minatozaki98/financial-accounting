"""Checks that a named JMeter VU profile sustained its actual concurrency."""

import csv
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
GATE = ROOT / "scripts" / "phase4" / "cloud-jmeter" / "concurrency_gate.py"
START_MS = 1_000_000


class ConcurrencyGateTests(unittest.TestCase):
    def run_gate(self, samples, target=500):
        with tempfile.TemporaryDirectory() as temp_dir:
            jtl = Path(temp_dir) / "samples.jtl"
            with jtl.open("w", newline="", encoding="utf-8") as stream:
                writer = csv.DictWriter(
                    stream, fieldnames=["timeStamp", "allThreads", "threadName"]
                )
                writer.writeheader()
                writer.writerows(samples)
            result = subprocess.run(
                [
                    sys.executable,
                    str(GATE),
                    "--jtl",
                    str(jtl),
                    "--target-users",
                    str(target),
                    "--test-start-ms",
                    str(START_MS),
                    "--ramp-seconds",
                    "5",
                    "--hold-seconds",
                    "15",
                    "--bin-seconds",
                    "5",
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            return result, json.loads(result.stdout) if result.stdout else None

    def test_sustained_500_users_passes(self):
        samples = [
            {"timeStamp": START_MS + offset, "allThreads": 500, "threadName": f"user-{i}"}
            for i, offset in enumerate((5_100, 10_100, 15_100), 1)
        ]
        result, report = self.run_gate(samples)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(report["valid"])
        self.assertEqual(report["hold_bins"], 3)
        self.assertEqual(report["observed_peak"], 500)

    def test_500_threads_started_sequentially_does_not_pass(self):
        samples = [
            {
                "timeStamp": START_MS + 5_100 + (i % 3) * 5_000,
                "allThreads": 20,
                "threadName": f"user-{i}",
            }
            for i in range(500)
        ]
        result, report = self.run_gate(samples)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertFalse(report["valid"])
        self.assertEqual(report["observed_peak"], 20)
        self.assertEqual(report["unique_threads"], 500)

    def test_missing_hold_window_samples_fail(self):
        samples = [
            {"timeStamp": START_MS + 5_100, "allThreads": 500, "threadName": "user-1"}
        ]
        result, report = self.run_gate(samples)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("missing_samples", report["failures"])

    def test_drop_below_95_percent_fails(self):
        samples = [
            {"timeStamp": START_MS + 5_100, "allThreads": 500, "threadName": "user-1"},
            {"timeStamp": START_MS + 10_100, "allThreads": 470, "threadName": "user-2"},
            {"timeStamp": START_MS + 15_100, "allThreads": 500, "threadName": "user-3"},
        ]
        result, report = self.run_gate(samples)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("below_95_percent", report["failures"])


if __name__ == "__main__":
    unittest.main()
