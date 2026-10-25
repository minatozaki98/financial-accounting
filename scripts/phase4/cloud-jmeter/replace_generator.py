"""Replace the diagnostic generator with the cheaper proven-candidate tier."""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import time

from provision import save_manifest
from teardown import AkamaiApi, require_identity


SMALL_TYPE = "g6-dedicated-2"
SMALL_HOURLY = 0.054
GENERATOR_LABEL = "jmeter-research-20261025-generator"


def replace(state: Path, api, public_key: str) -> dict:
    manifest_path = state / "cloud-session.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    evidence = state / "evidence"
    required = ("pilot-p500.jtl", "pilot-p500.log", "pilot-p500-target-metrics.jsonl",
                "pilot-p500-generator-metrics.jsonl", "pilot-summary.json")
    if any(not (evidence / name).is_file() or (evidence / name).stat().st_size == 0
           for name in required):
        raise ValueError("diagnostic pilot evidence must be copied locally before replacement")
    deadline = datetime.fromisoformat(manifest["deadline_utc"].replace("Z", "+00:00"))
    if (deadline - datetime.now(timezone.utc)).total_seconds() < 16 * 3600:
        raise ValueError("insufficient time before cost stop for a new generator pilot")
    plan = api.request("GET", f"/linode/types/{SMALL_TYPE}")
    regional = next((item for item in plan.get("region_prices", []) if item["id"] == "sg-sin-2"), None)
    hourly = (regional or plan["price"])["hourly"]
    if plan["vcpus"] != 2 or plan["memory"] != 4096 or hourly != SMALL_HOURLY:
        raise ValueError("small dedicated generator size or price changed")
    stock = api.request("GET", "/regions/sg-sin-2/availability")
    if not any(item.get("plan") == SMALL_TYPE and item.get("available") for item in stock):
        raise ValueError("small dedicated generator is unavailable")
    old = next((item for item in manifest["instances"] if item["role"] == "generator"), None)
    if old is not None:
        if old["label"] != GENERATOR_LABEL or old.get("plan", "g6-dedicated-4") != "g6-dedicated-4":
            raise ValueError("current generator differs from the old dedicated tier")
        resource = api.request("GET", f"/linode/instances/{old['id']}")
        if resource is not None:
            if resource.get("type") != "g6-dedicated-4":
                raise ValueError("old generator type differs; refusing deletion")
            require_identity(resource, old["id"], GENERATOR_LABEL, "sg-sin-2")
            api.request("DELETE", f"/linode/instances/{old['id']}")
        for _ in range(60):
            if api.request("GET", f"/linode/instances/{old['id']}") is None:
                break
            time.sleep(5)
        else:
            raise TimeoutError("old generator was not deleted")
        manifest["instances"] = [item for item in manifest["instances"] if item["role"] != "generator"]
        manifest.setdefault("retired_instances", []).append({**old, "deleted_utc": datetime.now(timezone.utc).isoformat()})
        save_manifest(manifest_path, manifest)
    elif not any(item["label"] == GENERATOR_LABEL for item in manifest.get("retired_instances", [])):
        raise ValueError("no retired generator recorded; refusing ambiguous creation")

    payload = {
        "label": GENERATOR_LABEL,
        "region": "sg-sin-2",
        "type": SMALL_TYPE,
        "image": "linode/ubuntu24.04",
        "booted": True,
        "interface_generation": "linode",
        "interfaces": [{"firewall_id": manifest["firewall"]["id"],
                        "vpc": {"subnet_id": 1080121, "ipv4": {"addresses": [{
                            "address": "10.240.42.11", "primary": True, "nat_1_1_address": "auto"
                        }]}}}],
        "authorized_keys": [public_key],
        "backups_enabled": False,
        "disk_encryption": "enabled",
    }
    listed = api.request("GET", "/linode/instances?page_size=500")
    if listed["results"] > len(listed["data"]):
        raise ValueError("paginated instance list prevents safe recovery")
    matches = [item for item in listed["data"] if item["label"] == GENERATOR_LABEL]
    if len(matches) > 1:
        raise ValueError("duplicate generator labels")
    if matches:
        new = matches[0]
    else:
        try:
            new = api.request("POST", "/linode/instances", payload)
        except Exception:
            listed = api.request("GET", "/linode/instances?page_size=500")
            matches = [item for item in listed["data"] if item["label"] == GENERATOR_LABEL]
            if len(matches) != 1:
                raise
            new = matches[0]
    if new.get("type") != SMALL_TYPE or new.get("region") != "sg-sin-2":
        raise ValueError("created generator differs from the frozen smaller tier")
    entry = {"id": new["id"], "label": GENERATOR_LABEL, "role": "generator",
             "plan": SMALL_TYPE, "private_ip": "10.240.42.11", "created_utc": new.get("created")}
    manifest["instances"].append(entry)
    manifest["generator_hourly_usd"] = SMALL_HOURLY
    manifest["generator_cpu_cap"] = 2
    save_manifest(manifest_path, manifest)
    interfaces = api.request("GET", f"/linode/instances/{new['id']}/interfaces")["interfaces"]
    if (len(interfaces) != 1 or not interfaces[0].get("vpc") or
            interfaces[0]["vpc"].get("vpc_id") != manifest["vpc"]["id"] or
            interfaces[0]["vpc"].get("subnet_id") != 1080121 or
            interfaces[0]["vpc"]["ipv4"]["addresses"][0]["address"] != "10.240.42.11"):
        raise ValueError("new generator private interface differs from frozen network")
    return entry


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-dir", type=Path, required=True)
    args = parser.parse_args()
    state = args.state_dir.resolve()
    token = (state / "secrets/akamai-token.txt").read_text().strip()
    public_key = (state / "secrets/cloud-ssh-ed25519.pub").read_text().strip()
    if len(token) != 64 or not public_key.startswith("ssh-ed25519 "):
        raise ValueError("token or SSH key is malformed")
    entry = replace(state, AkamaiApi(token), public_key)
    print(f"new generator: {entry['id']} ({entry['plan']})")


if __name__ == "__main__":
    main()
