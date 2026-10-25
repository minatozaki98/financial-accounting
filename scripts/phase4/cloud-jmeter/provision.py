"""Provision the two pre-priced Akamai benchmark VMs and record IDs immediately."""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path

from teardown import AkamaiApi


TYPE = "g6-dedicated-4"
REGION = "sg-sin-2"
HOURLY = 0.108
SUBNET_ID = 1080121
FIREWALL_ID = 222190138
LABEL_PREFIX = "jmeter-research-20261025-"
PRIVATE_IPS = {"target": "10.240.42.10", "generator": "10.240.42.11"}


def save_manifest(path: Path, data: dict) -> None:
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def list_instances(api) -> list[dict]:
    result = api.request("GET", "/linode/instances?page_size=500")
    if result["results"] > len(result["data"]):
        raise ValueError("instance list is paginated; refusing to guess account state")
    return result["data"]


def preflight(manifest: dict, api, now: datetime) -> None:
    deadline = datetime.fromisoformat(manifest["deadline_utc"].replace("Z", "+00:00"))
    if manifest["region"] != REGION or (deadline - now).total_seconds() < 12 * 3600:
        raise ValueError("wrong region or less than 12 hours remain before cost stop")
    if manifest["vpc"]["id"] != 713050 or manifest["firewall"]["id"] != FIREWALL_ID:
        raise ValueError("network IDs differ from the verified experiment network")
    plan = api.request("GET", f"/linode/types/{TYPE}")
    regional = next((price for price in plan.get("region_prices", []) if price["id"] == REGION), None)
    hourly = (regional or plan["price"])["hourly"]
    if plan["vcpus"] != 4 or plan["memory"] != 8192 or hourly != HOURLY:
        raise ValueError("server size or price changed")
    stock = api.request("GET", f"/regions/{REGION}/availability")
    if not any(entry.get("plan") == TYPE and entry.get("available") for entry in stock):
        raise ValueError("dedicated plan unavailable in Singapore 2")
    account_stock = api.request("GET", f"/account/availability/{REGION}")
    if "Linodes" not in account_stock["available"]:
        raise ValueError("account is not allowed to deploy Linodes in Singapore 2")
    if 24 * 2 * hourly * 1.07 >= manifest["operational_stop_usd"]:
        raise ValueError("24-hour cost would exceed operational stop")
    if len(manifest["instances"]) > 2:
        raise ValueError("manifest already contains more than two instances")


def create_instance(api, role: str, public_key: str) -> dict:
    label = LABEL_PREFIX + role
    payload = {
        "label": label,
        "region": REGION,
        "type": TYPE,
        "image": "linode/ubuntu24.04",
        "booted": True,
        "interface_generation": "linode",
        "interfaces": [{
            "firewall_id": FIREWALL_ID,
            "vpc": {"subnet_id": SUBNET_ID, "ipv4": {"addresses": [{
                "address": PRIVATE_IPS[role], "primary": True, "nat_1_1_address": "auto"
            }]}}
        }],
        "authorized_keys": [public_key],
        "backups_enabled": False,
        "disk_encryption": "enabled",
    }
    return api.request("POST", "/linode/instances", payload)


def provision(manifest: dict, api, public_key: str, path: Path) -> list[dict]:
    preflight(manifest, api, datetime.now(timezone.utc))
    existing = list_instances(api)
    recorded = {entry["label"]: entry for entry in manifest["instances"]}
    for role in ("target", "generator"):
        label = LABEL_PREFIX + role
        matches = [entry for entry in existing if entry["label"] == label]
        if len(matches) > 1:
            raise ValueError(f"duplicate instance label {label}")
        if matches:
            instance = matches[0]
            if instance["region"] != REGION or instance["type"] != TYPE:
                raise ValueError(f"existing {role} instance differs from frozen plan")
        else:
            instance = create_instance(api, role, public_key)
            existing.append(instance)
        if label not in recorded:
            entry = {"id": instance["id"], "label": label, "role": role,
                     "private_ip": PRIVATE_IPS[role], "created_utc": instance.get("created")}
            manifest["instances"].append(entry)
            save_manifest(path, manifest)
            recorded[label] = entry
        elif recorded[label]["id"] != instance["id"]:
            raise ValueError(f"recorded {role} ID differs from provider ID")
    return manifest["instances"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--token-file", type=Path, required=True)
    parser.add_argument("--public-key-file", type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    token = args.token_file.read_text(encoding="utf-8").strip()
    public_key = args.public_key_file.read_text(encoding="utf-8").strip()
    if len(token) != 64 or not public_key.startswith("ssh-ed25519 "):
        raise ValueError("token or SSH public key is malformed")
    entries = provision(manifest, AkamaiApi(token), public_key, args.manifest)
    for entry in entries:
        print(f"{entry['role']}: {entry['id']} ({entry['private_ip']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
