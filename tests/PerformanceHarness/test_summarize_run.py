from pathlib import Path
import sys
import tempfile
import unittest


MODULE_DIR = Path(__file__).resolve().parents[2] / "scripts/phase4/cloud-jmeter"
sys.path.insert(0, str(MODULE_DIR))
from summarize_run import summarize  # noqa: E402


class SummaryTests(unittest.TestCase):
    def test_clean_samples_are_valid_and_report_p95(self):
        with tempfile.TemporaryDirectory() as directory:
            jtl = Path(directory) / "run.jtl"
            log = Path(directory) / "run.log"
            jtl.write_text("timeStamp,allThreads,threadName,label,elapsed,success,responseCode\n"
                           "1000,2,a,GET /accounts,10,true,200\n"
                           "6000,2,b,GET /accounts,20,false,500\n")
            log.write_text("INFO Running test (1000)\n")
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
            log.write_text("INFO Running test (1000)\nERROR java.lang.StackOverflowError\n")
            result = summarize(jtl, log, 2, 0, 10)
            self.assertFalse(result["valid_run"])
            self.assertGreater(result["jmeter_log_error_count"], 0)


if __name__ == "__main__":
    unittest.main()
