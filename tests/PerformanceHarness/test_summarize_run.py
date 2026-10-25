from pathlib import Path
import sys
import tempfile
import unittest


MODULE_DIR = Path(__file__).resolve().parents[2] / "scripts/phase4/cloud-jmeter"
sys.path.insert(0, str(MODULE_DIR))
from summarize_run import summarize  # noqa: E402


def short_lifecycle_log() -> str:
    return (
        "2026-10-25 00:00:00,000 INFO o.a.j.JMeter: Running test (1000)\n"
        "2026-10-25 00:00:00,000 INFO o.a.j.t.JMeterThread: Thread started: group 1-1\n"
        "2026-10-25 00:00:00,000 INFO o.a.j.t.JMeterThread: Thread started: group 1-2\n"
        "2026-10-25 00:00:11,000 INFO o.a.j.t.JMeterThread: Thread finished: group 1-1\n"
        "2026-10-25 00:00:11,000 INFO o.a.j.t.JMeterThread: Thread finished: group 1-2\n"
    )


class SummaryTests(unittest.TestCase):
    def test_request_gap_is_valid_when_thread_lifecycle_proves_full_hold(self):
        with tempfile.TemporaryDirectory() as directory:
            jtl, log = Path(directory) / "run.jtl", Path(directory) / "run.log"
            jtl.write_text("timeStamp,allThreads,threadName,label,elapsed,success,responseCode\n"
                           "2000,2,a,GET /accounts,10,true,200\n")
            log.write_text(
                "2026-10-25 00:00:00,000 INFO o.a.j.JMeter: Running test (1000)\n"
                "2026-10-25 00:00:00,100 INFO o.a.j.t.JMeterThread: Thread started: group 1-1\n"
                "2026-10-25 00:00:00,200 INFO o.a.j.t.JMeterThread: Thread started: group 1-2\n"
                "2026-10-25 00:00:12,000 INFO o.a.j.t.JMeterThread: Thread finished: group 1-1\n"
                "2026-10-25 00:00:12,100 INFO o.a.j.t.JMeterThread: Thread finished: group 1-2\n"
            )
            result = summarize(jtl, log, 2, 1, 10)
            self.assertTrue(result["valid_run"])
            self.assertEqual(result["concurrency"]["jtl_missing_bins"], 1)
            self.assertTrue(result["concurrency"]["lifecycle"]["valid"])

    def test_early_thread_finish_invalidates_run_despite_full_jtl_bins(self):
        with tempfile.TemporaryDirectory() as directory:
            jtl, log = Path(directory) / "run.jtl", Path(directory) / "run.log"
            jtl.write_text("timeStamp,allThreads,threadName,label,elapsed,success,responseCode\n"
                           "2000,2,a,GET /accounts,10,true,200\n"
                           "7000,2,b,GET /accounts,10,true,200\n")
            log.write_text(
                "2026-10-25 00:00:00,000 INFO o.a.j.JMeter: Running test (1000)\n"
                "2026-10-25 00:00:00,100 INFO o.a.j.t.JMeterThread: Thread started: group 1-1\n"
                "2026-10-25 00:00:00,200 INFO o.a.j.t.JMeterThread: Thread started: group 1-2\n"
                "2026-10-25 00:00:04,000 INFO o.a.j.t.JMeterThread: Thread finished: group 1-1\n"
                "2026-10-25 00:00:12,100 INFO o.a.j.t.JMeterThread: Thread finished: group 1-2\n"
            )
            result = summarize(jtl, log, 2, 1, 10)
            self.assertFalse(result["valid_run"])
            self.assertIn("early_thread_finish", result["concurrency"]["lifecycle"]["failures"])

    def test_clean_samples_are_valid_and_report_p95(self):
        with tempfile.TemporaryDirectory() as directory:
            jtl = Path(directory) / "run.jtl"
            log = Path(directory) / "run.log"
            jtl.write_text("timeStamp,allThreads,threadName,label,elapsed,success,responseCode\n"
                           "1000,2,a,GET /accounts,10,true,200\n"
                           "6000,2,b,GET /accounts,20,false,500\n")
            log.write_text(short_lifecycle_log())
            result = summarize(jtl, log, 2, 0, 10)
            self.assertTrue(result["valid_run"])
            self.assertEqual(result["hold"]["p95_ms"], 20)
            self.assertEqual(result["hold"]["error_pct"], 50)

    def test_jmeter_exception_invalidates_run_even_if_samples_succeed(self):
        with tempfile.TemporaryDirectory() as directory:
            jtl = Path(directory) / "run.jtl"
            log = Path(directory) / "run.log"
            jtl.write_text("timeStamp,allThreads,threadName,label,elapsed,success,responseCode\n"
                           "1000,2,a,GET /accounts,10,true,200\n"
                           "6000,2,b,GET /accounts,20,true,200\n")
            log.write_text(short_lifecycle_log() + "ERROR java.lang.StackOverflowError\n")
            result = summarize(jtl, log, 2, 0, 10)
            self.assertFalse(result["valid_run"])
            self.assertGreater(result["jmeter_log_error_count"], 0)


if __name__ == "__main__":
    unittest.main()
