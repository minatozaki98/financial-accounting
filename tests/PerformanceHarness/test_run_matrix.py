from pathlib import Path
import sys
import tempfile
import unittest


MODULE_DIR = Path(__file__).resolve().parents[2] / "scripts/phase4/cloud-jmeter"
sys.path.insert(0, str(MODULE_DIR))
from run_matrix import check_profiles, matrix, next_attempt  # noqa: E402


class MatrixTests(unittest.TestCase):
    def test_three_alternating_pairs_for_each_profile(self):
        pairs = list(matrix())
        self.assertEqual(len(pairs), 15)
        for index in range(0, 15, 3):
            self.assertEqual([item[2] for item in pairs[index:index + 3]],
                             [("before", "after"), ("after", "before"),
                              ("before", "after")])

    def test_partial_pair_uses_new_attempt_without_overwriting_raw_data(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "p50-r1-before-a1").mkdir()
            self.assertEqual(next_attempt(root, "p50", 1), 2)

    def test_frozen_profile_hashes_match_files(self):
        self.assertEqual(len(check_profiles()), 5)


if __name__ == "__main__":
    unittest.main()
