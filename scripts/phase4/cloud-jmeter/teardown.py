"""Delete only the Akamai resources recorded for one JMeter session.

The token and resource manifest are separate local files. This script is safe to
run repeatedly and is suitable for a Windows scheduled cost-stop task.
"""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen


API = "https://api.linode.com/v4"
PROFILES = ("p50", "p100", "p500", "soak", "spike")


class AkamaiApi:
    def __init__(self, token: str):
        self.token = token

    def request(self, method: str, path: str, payload: dict | None = None):
        request = Request(
            API + path,
            method=method,
            data=json.dumps(payload).encode("utf-8") if payload is not None else None,
            headers={"Authorization": f"Bearer {self.token}", "Accept": "application/json",
                     "Content-Type": "application/json"},
        )
        try:
            with urlopen(request, timeout=30) as response:
                body = response.read()
                return json.loads(body) if body else None
        except HTTPError as error:
            if error.code == 404 and method == "GET":
                return None
            raise RuntimeError(f"Akamai API {method} {path} returned HTTP {error.code}") from None


def require_identity(resource: dict, expected_id: int, expected_label: str, region: str):
    if (resource.get("id") != expected_id or resource.get("label") != expected_label
            or resource.get("region") != region):
        raise ValueError(f"resource identity mismatch for ID {expected_id}; refusing deletion")


def require_complete_evidence(evidence: Path) -> None:
    """Refuse automatic deletion until all paired raw runs were copied locally."""
    for profile in PROFILES:
        for repeat in (1, 2, 3):
            marker = evidence / f"{profile}-r{repeat}-pair.json"
            if not marker.is_file():
                raise ValueError(f"missing paired evidence: {marker.name}")
            pair = json.loads(marker.read_text(encoding="utf-8"))
            runs = pair.get("runs", [])
            if len(runs) != 2 or {run.get("side") for run in runs} != {"before", "after"}:
                raise ValueError(f"incomplete paired evidence: {marker.name}")
            for run in runs:
                run_id = run.get("run_id")
                if not isinstance(run_id, str) or not run_id.startswith(f"{profile}-r{repeat}-"):
                    raise ValueError(f"unexpected run ID in {marker.name}")
                for name in ("run.jtl", "run.log", "sha256.json", "summary.json",
                             "resource-summary.json"):
                    path = evidence / run_id / name
                    if not path.is_file() or path.stat().st_size == 0:
                        raise ValueError(f"missing raw evidence: {run_id}/{name}")


def teardown(manifest: dict, api, now: datetime, force: bool = False,
             wait_seconds: float = 3, max_wait_seconds: float = 300) -> list[str]:
    deadline = datetime.fromisoformat(manifest["deadline_utc"].replace("Z", "+00:00"))
    if deadline.tzinfo is None or now.tzinfo is None:
        raise ValueError("deadline and current time must include UTC offset")
    if not force and now < deadline:
        return ["deadline not reached; no resources deleted"]
    if manifest["region"] != "sg-sin-2":
        raise ValueError("unexpected region; refusing deletion")
    events = []
    instances = manifest.get("instances", [])
    if len(instances) > 2 or len({entry["id"] for entry in instances}) != len(instances):
        raise ValueError("expected at most two unique experiment instances")
    for entry in instances:
        if not entry["label"].startswith("jmeter-research-20261025-"):
            raise ValueError("unexpected instance label; refusing deletion")
        resource = api.request("GET", f"/linode/instances/{entry['id']}")
        if resource is None:
            events.append(f"instance {entry['id']} already absent")
            continue
        require_identity(resource, entry["id"], entry["label"], manifest["region"])
        api.request("DELETE", f"/linode/instances/{entry['id']}")
        events.append(f"deleted instance {entry['id']}")

    for entry in instances:
        start = time.monotonic()
        while api.request("GET", f"/linode/instances/{entry['id']}") is not None:
            if time.monotonic() - start > max_wait_seconds:
                raise TimeoutError(f"instance {entry['id']} remains after deletion request")
            time.sleep(wait_seconds)

    firewall = manifest.get("firewall")
    if firewall:
        if firewall["label"] != "jmeter-research-20261025-fw":
            raise ValueError("unexpected firewall label; refusing deletion")
        resource = api.request("GET", f"/networking/firewalls/{firewall['id']}")
        if resource is not None:
            if resource.get("id") != firewall["id"] or resource.get("label") != firewall["label"]:
                raise ValueError("firewall identity mismatch; refusing deletion")
            api.request("DELETE", f"/networking/firewalls/{firewall['id']}")
            events.append(f"deleted firewall {firewall['id']}")
        else:
            events.append(f"firewall {firewall['id']} already absent")

    vpc = manifest.get("vpc")
    if vpc:
        if vpc["label"] != "jmeter-research-20261025":
            raise ValueError("unexpected VPC label; refusing deletion")
        resource = api.request("GET", f"/vpcs/{vpc['id']}")
        if resource is not None:
            require_identity(resource, vpc["id"], vpc["label"], manifest["region"])
            api.request("DELETE", f"/vpcs/{vpc['id']}")
            events.append(f"deleted VPC {vpc['id']}")
        else:
            events.append(f"VPC {vpc['id']} already absent")
    return events


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--token-file", type=Path, required=True)
    parser.add_argument("--now", action="store_true", help="tear down before deadline")
    parser.add_argument("--require-complete-evidence", type=Path,
                        help="refuse deletion until all 15 paired runs are copied locally")
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    token = args.token_file.read_text(encoding="utf-8").strip()
    if len(token) != 64:
        raise ValueError("API token file is missing or malformed")
    if args.require_complete_evidence is not None:
        require_complete_evidence(args.require_complete_evidence)
    events = teardown(manifest, AkamaiApi(token), datetime.now(timezone.utc), args.now)
    for event in events:
        print(event)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
