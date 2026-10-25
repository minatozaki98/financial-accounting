"""A paired run must prepare collector output paths on both cloud hosts."""

from pathlib import Path
import sys
import unittest
from unittest.mock import call, patch


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "phase4" / "cloud-jmeter"))
import run_matrix


class RunMatrixDirectoryTests(unittest.TestCase):
    def test_prepares_run_directory_on_target_and_generator(self):
        state = Path("test-state")
        remote = "/opt/jmeter-research/results/matrix/p50-r1-before-a2"
        with patch.object(run_matrix, "ssh") as remote_ssh:
            run_matrix.prepare_run_directories("target-ip", "generator-ip", state, remote)
        self.assertEqual(remote_ssh.call_args_list, [
            call("target-ip", state, f"mkdir -p {remote}"),
            call("generator-ip", state, f"mkdir -p {remote}"),
        ])


if __name__ == "__main__":
    unittest.main()
