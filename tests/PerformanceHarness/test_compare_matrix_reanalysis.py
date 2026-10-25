"""Comparison must reprocess frozen raw files under one analysis protocol."""

import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest


MODULE_DIR = Path(__file__).resolve().parents[2] / "scripts/phase4/cloud-jmeter"
sys.path.insert(0, str(MODULE_DIR))
import compare_matrix  # noqa: E402
from summarize_run import summarize  # noqa: E402


def fixture(directory: Path) -> None:
    jtl, log = directory / "run.jtl", directory / "run.log"
    jtl.write_text("timeStamp,allThreads,threadName,label,elapsed,success,responseCode\n"
                   "2000,2,a,GET /accounts,10,true,200\n")
    log.write_text(
        "2026-10-25 00:00:00,000 INFO o.a.j.JMeter: Running test (1000)\n"
        "2026-10-25 00:00:00,100 INFO o.a.j.t.JMeterThread: Thread started: group 1-1\n"
        "2026-10-25 00:00:00,200 INFO o.a.j.t.JMeterThread: Thread started: group 1-2\n"
        "2026-10-25 00:00:12,000 INFO o.a.j.t.JMeterThread: Thread finished: group 1-1\n"
        "2026-10-25 00:00:12,100 INFO o.a.j.t.JMeterThread: Thread finished: group 1-2\n"
    )
    old = copy.deepcopy(summarize(jtl, log, 2, 1, 10))
    old["analysis_protocol_version"] = 1
    old["valid_run"] = False
    (directory / "summary.json").write_text(json.dumps(old))
    (directory / "sha256.json").write_text(json.dumps({
        name: hashlib.sha256((directory / name).read_bytes()).hexdigest()
        for name in ("run.jtl", "run.log")
    }))


class ReanalysisTests(unittest.TestCase):
    def test_old_rejection_is_reprocessed_without_changing_saved_metrics(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            fixture(directory)
            result = compare_matrix.reanalyze_run(directory, "p50", 2, 1, 10)
            self.assertTrue(result["valid_run"])
            self.assertEqual(result["analysis_protocol_version"], 2)
            self.assertEqual(result["concurrency"]["jtl_missing_bins"], 1)
            self.assertFalse(json.loads((directory / "summary.json").read_text())["valid_run"])

    def test_changed_raw_jtl_is_rejected_before_comparison(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            fixture(directory)
            with (directory / "run.jtl").open("a") as stream:
                stream.write("7000,2,b,GET /accounts,10,true,200\n")
            with self.assertRaisesRegex(ValueError, "hash"):
                compare_matrix.reanalyze_run(directory, "p50", 2, 1, 10)


if __name__ == "__main__":
    unittest.main()
