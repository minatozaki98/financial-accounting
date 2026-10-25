import importlib.util
from datetime import datetime, timezone
from pathlib import Path
import unittest


MODULE_PATH = Path(__file__).resolve().parents[2] / "scripts/phase4/cloud-jmeter/teardown.py"
SPEC = importlib.util.spec_from_file_location("teardown", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class FakeApi:
    def __init__(self, wrong_label=False):
        self.calls = []
        self.resources = {
            "/linode/instances/42": {"id": 42, "label": "jmeter-research-20261025-target", "region": "sg-sin-2"},
            "/vpcs/7": {"id": 7, "label": "jmeter-research-20261025", "region": "sg-sin-2"},
            "/networking/firewalls/9": {"id": 9, "label": "jmeter-research-20261025-fw"},
        }
        if wrong_label:
            self.resources["/linode/instances/42"]["label"] = "someone-elses-server"

    def request(self, method, path):
        self.calls.append((method, path))
        if method == "GET":
            return self.resources.get(path)
        self.resources.pop(path, None)
        return None


class TeardownTests(unittest.TestCase):
    def setUp(self):
        self.manifest = {
            "deadline_utc": "2026-10-25T00:00:00Z", "region": "sg-sin-2",
            "instances": [{"id": 42, "label": "jmeter-research-20261025-target"}],
            "vpc": {"id": 7, "label": "jmeter-research-20261025"},
            "firewall": {"id": 9, "label": "jmeter-research-20261025-fw"},
        }

    def test_deletes_only_manifest_resources_after_deadline(self):
        api = FakeApi()
        events = MODULE.teardown(self.manifest, api, datetime(2026, 10, 26, tzinfo=timezone.utc), wait_seconds=0)
        self.assertEqual(len(events), 3)
        self.assertEqual([call for call in api.calls if call[0] == "DELETE"],
                         [("DELETE", "/linode/instances/42"),
                          ("DELETE", "/networking/firewalls/9"),
                          ("DELETE", "/vpcs/7")])

    def test_refuses_wrong_resource_label(self):
        api = FakeApi(wrong_label=True)
        with self.assertRaises(ValueError):
            MODULE.teardown(self.manifest, api, datetime(2026, 10, 26, tzinfo=timezone.utc))
        self.assertFalse(any(method == "DELETE" for method, _ in api.calls))

    def test_waits_for_deadline(self):
        api = FakeApi()
        self.assertIn("deadline not reached", MODULE.teardown(
            self.manifest, api, datetime(2026, 10, 24, tzinfo=timezone.utc))[0])
        self.assertEqual(api.calls, [])


if __name__ == "__main__":
    unittest.main()
