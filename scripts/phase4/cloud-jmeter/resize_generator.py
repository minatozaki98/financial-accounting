"""Upgrade an insufficient 2 CPU generator to the cheapest 4 CPU dedicated plan."""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import time

from provision import save_manifest
from teardown import AkamaiApi, require_identity


def resize(state: Path, api) -> dict:
    manifest_path = state / "cloud-session.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    evidence = state / "evidence"
    required = ("pilot-small-p500.jtl", "pilot-small-p500.log",
                "pilot-small-target-metrics.jsonl", "pilot-small-generator-metrics.jsonl",
                "pilot-small-summary.json")
    if any(not (evidence / name).is_file() or (evidence / name).stat().st_size == 0
           for name in required):
        raise ValueError("small-generator pilot evidence must be copied locally before resize")
    deadline = datetime.fromisoformat(manifest["deadline_utc"].replace("Z", "+00:00"))
    if (deadline - datetime.now(timezone.utc)).total_seconds() < 12 * 3600:
        raise ValueError("less than 12 hours remain before cost stop")
    entry = next((item for item in manifest["instances"] if item["role"] == "generator"), None)
    if entry is None or entry["label"] != "jmeter-research-20261025-generator":
        raise ValueError("generator does not match this experiment")
    resource = api.request("GET", f"/linode/instances/{entry['id']}")
    if resource is None:
        raise ValueError("generator is absent")
    require_identity(resource, entry["id"], entry["label"], "sg-sin-2")
    if resource["type"] not in ("g6-dedicated-2", "g6-dedicated-4"):
        raise ValueError("unexpected generator plan")
    desired = api.request("GET", "/linode/types/g6-dedicated-4")
    regional = next((item for item in desired.get("region_prices", []) if item["id"] == "sg-sin-2"), None)
    if desired["vcpus"] != 4 or desired["memory"] != 8192 or (regional or desired["price"])["hourly"] != 0.108:
        raise ValueError("desired dedicated plan price or size changed")
    stock = api.request("GET", "/regions/sg-sin-2/availability")
    if not any(item.get("plan") == "g6-dedicated-4" and item.get("available") for item in stock):
        raise ValueError("desired 4 CPU plan is unavailable in Singapore 2")
    if resource["type"] == "g6-dedicated-2":
        if resource["status"] != "running":
            raise ValueError("generator is not running; inspect migration state")
        api.request("POST", f"/linode/instances/{entry['id']}/resize",
                    {"type": "g6-dedicated-4", "allow_auto_disk_resize": False,
                     "migration_type": "cold"})
        manifest["generator_resize_requested_utc"] = datetime.now(timezone.utc).isoformat()
        save_manifest(manifest_path, manifest)
    for _ in range(90):
        resource = api.request("GET", f"/linode/instances/{entry['id']}")
        if resource and resource["type"] == "g6-dedicated-4" and resource["status"] == "running":
            command = ["ssh.exe", "-i", str(state / "secrets/cloud-ssh-ed25519"),
                       "-o", "BatchMode=yes", "-o", "ConnectTimeout=8",
                       "-o", f"UserKnownHostsFile={state / 'secrets/known_hosts'}",
                       "-o", "StrictHostKeyChecking=yes", f"root@{resource['ipv4'][0]}",
                       "nproc; awk '/MemTotal/ {print $2}' /proc/meminfo"]
            guest = subprocess.run(command, capture_output=True, text=True, timeout=15)
            values = guest.stdout.split()
            if (guest.returncode == 0 and len(values) >= 2 and
                    values[0].isdigit() and values[1].isdigit() and
                    int(values[0]) == 4 and int(values[1]) >= 7_500_000):
                break
        time.sleep(10)
    else:
        raise TimeoutError("generator resize did not reach 4 CPU/8 GB in the guest OS")
    entry["plan"] = "g6-dedicated-4"
    entry["resized_utc"] = datetime.now(timezone.utc).isoformat()
    manifest["generator_hourly_usd"] = 0.108
    manifest["generator_cpu_cap"] = 4
    save_manifest(manifest_path, manifest)
    return entry


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-dir", type=Path, required=True)
    args = parser.parse_args()
    state = args.state_dir.resolve()
    token = (state / "secrets/akamai-token.txt").read_text().strip()
    if len(token) != 64:
        raise ValueError("API token is malformed")
    entry = resize(state, AkamaiApi(token))
    print(f"generator resized: {entry['id']} ({entry['plan']})")


if __name__ == "__main__":
    main()
