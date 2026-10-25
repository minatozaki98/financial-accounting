from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import sys
import tempfile
import unittest


MODULE_DIR = Path(__file__).resolve().parents[2] / "scripts/phase4/cloud-jmeter"
sys.path.insert(0, str(MODULE_DIR))
import provision  # noqa: E402


class FakeApi:
    def __init__(self):
        self.created = []

    def request(self, method, path, payload=None):
        if path == "/linode/types/g6-dedicated-4":
            return {"vcpus": 4, "memory": 8192, "price": {"hourly": 0.108}, "region_prices": []}
        if path == "/regions/sg-sin-2/availability":
            return [{"plan": "g6-dedicated-4", "available": True}]
        if path == "/account/availability/sg-sin-2":
            return {"available": ["Linodes"]}
        if method == "GET" and path.startswith("/linode/instances?"):
            return {"results": len(self.created), "data": list(self.created)}
        if method == "POST" and path == "/linode/instances":
            assert payload["interfaces"][0]["firewall_id"] == 222190138
            assert payload["interfaces"][0]["vpc"]["ipv4"]["addresses"][0]["nat_1_1_address"] == "auto"
            assert payload["backups_enabled"] is False
            result = {"id": 100 + len(self.created), "label": payload["label"],
                      "region": payload["region"], "type": payload["type"],
                      "created": "2026-10-25T07:00:00"}
            self.created.append(result)
            return result
        raise AssertionError((method, path))


class ProvisionTests(unittest.TestCase):
    def test_records_each_instance_immediately(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            manifest = {
                "deadline_utc": (datetime.now(timezone.utc) + timedelta(hours=24)).isoformat(),
                "region": "sg-sin-2", "operational_stop_usd": 80,
                "vpc": {"id": 713050}, "firewall": {"id": 222190138}, "instances": [],
            }
            api = FakeApi()
            entries = provision.provision(manifest, api, "ssh-ed25519 test", path)
            self.assertEqual([entry["role"] for entry in entries], ["target", "generator"])
            self.assertEqual(len(json.loads(path.read_text())["instances"]), 2)
            self.assertEqual(len(api.created), 2)

    def test_price_change_stops_before_creation(self):
        class ChangedPriceApi(FakeApi):
            def request(self, method, path, payload=None):
                if path == "/linode/types/g6-dedicated-4":
                    return {"vcpus": 4, "memory": 8192, "price": {"hourly": 0.2}, "region_prices": []}
                return super().request(method, path, payload)

        manifest = {
            "deadline_utc": (datetime.now(timezone.utc) + timedelta(hours=24)).isoformat(),
            "region": "sg-sin-2", "operational_stop_usd": 80,
            "vpc": {"id": 713050}, "firewall": {"id": 222190138}, "instances": [],
        }
        api = ChangedPriceApi()
        with self.assertRaises(ValueError):
            provision.preflight(manifest, api, datetime.now(timezone.utc))
        self.assertEqual(api.created, [])


if __name__ == "__main__":
    unittest.main()
