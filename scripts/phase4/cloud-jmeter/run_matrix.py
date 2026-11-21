"""Run frozen before/after JMeter pairs on the two temporary Akamai VMs."""

import argparse
import ctypes
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import time

from summarize_run import START_PATTERN, summarize
from summarize_metrics import summarize as summarize_metrics
from summarize_special import summarize_soak, summarize_spike
from teardown import AkamaiApi


ROOT = Path(__file__).resolve().parents[3]
DEFAULT_STATE = ROOT / ".superpowers/sdd/2026-10-23-cloud-jmeter-experiment"
PROFILES = {
    "p50": (50, 120, 600, 30),
    "p100": (100, 120, 600, 30),
    "p500": (500, 120, 600, 30),
    "soak": (100, 120, 2700, 30),
    "spike": (500, 30, 780, 30),
}


def matrix():
    for profile in PROFILES:
        for repeat in (1, 2, 3):
            order = ("after", "before") if repeat == 2 else ("before", "after")
            yield profile, repeat, order


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check_profiles() -> dict:
    manifest_path = ROOT / "Document/performance/jmeter/controlled/manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    for profile in PROFILES:
        item = manifest[profile]
        path = ROOT / item["path"]
        if sha256(path) != item["sha256"]:
            raise ValueError(f"local {profile} JMX hash differs from frozen manifest")
    return manifest


def run_command(command: list[str], timeout: int = 60, output: Path | None = None) -> str:
    if output is None:
        result = subprocess.run(command, text=True, capture_output=True, timeout=timeout)
        if result.returncode:
            raise RuntimeError(f"command failed ({result.returncode}): {result.stderr[-600:]}")
        return result.stdout.strip()
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as handle:
        result = subprocess.run(command, text=True, stdout=handle, stderr=subprocess.STDOUT,
                                timeout=timeout)
    if result.returncode:
        raise RuntimeError(f"command failed ({result.returncode}); see {output}")
    return ""


def ssh_args(ip: str, state: Path) -> list[str]:
    return ["ssh.exe", "-i", str(state / "secrets/cloud-ssh-ed25519"),
            "-o", "BatchMode=yes", "-o", f"UserKnownHostsFile={state / 'secrets/known_hosts'}",
            "-o", "StrictHostKeyChecking=yes", "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=3", f"root@{ip}"]


def ssh(ip: str, state: Path, remote: str, timeout: int = 60,
        output: Path | None = None) -> str:
    return run_command(ssh_args(ip, state) + [remote], timeout, output)


def scp(ip: str, state: Path, remote: str, local: Path) -> None:
    local.parent.mkdir(parents=True, exist_ok=True)
    command = ["scp.exe", "-q", "-i", str(state / "secrets/cloud-ssh-ed25519"),
               "-o", "BatchMode=yes", "-o", f"UserKnownHostsFile={state / 'secrets/known_hosts'}",
               "-o", "StrictHostKeyChecking=yes", f"root@{ip}:{remote}", str(local)]
    run_command(command, timeout=180)


def prepare_run_directories(target: str, generator: str, state: Path,
                            remote: str) -> None:
    """Create result paths before either host starts a metrics collector."""
    for ip in (target, generator):
        ssh(ip, state, f"mkdir -p {remote}")


def provider_ips(state: Path, manifest: dict) -> dict[str, str]:
    token = (state / "secrets/akamai-token.txt").read_text(encoding="utf-8").strip()
    api = AkamaiApi(token)
    ips = {}
    for entry in manifest["instances"]:
        resource = api.request("GET", f"/linode/instances/{entry['id']}")
        if (resource is None or resource["label"] != entry["label"] or
                resource["type"] != entry.get("plan", "g6-dedicated-4") or resource["region"] != "sg-sin-2" or
                resource["status"] != "running"):
            raise ValueError(f"{entry['role']} VM differs from frozen environment")
        ips[entry["role"]] = resource["ipv4"][0]
    if set(ips) != {"target", "generator"}:
        raise ValueError("exactly target and generator VMs are required")
    return ips


def check_budget(manifest: dict, next_duration: int, state: Path) -> None:
    now = datetime.now(timezone.utc)
    deadline = datetime.fromisoformat(manifest["deadline_utc"].replace("Z", "+00:00"))
    started = datetime.fromisoformat(manifest["started_utc"].replace("Z", "+00:00"))
    if (deadline - now).total_seconds() < next_duration + 1800:
        raise RuntimeError("next run may cross the 24-hour cost stop")
    projected = (now - started).total_seconds() / 3600 + (next_duration + 1800) / 3600
    projected *= (manifest["target_hourly_usd"] + manifest["generator_hourly_usd"]) * 1.07
    token = (state / "secrets/akamai-token.txt").read_text(encoding="utf-8").strip()
    account = AkamaiApi(token).request("GET", "/account")
    accrued = float(account["balance_uninvoiced"])
    # Akamai rounds usage up to the nearest hour; keep a whole-hour margin on
    # each VM instead of treating the listed rate as exact per-second billing.
    next_cost = (math.ceil((next_duration + 1800) / 3600) + 1) * (
        manifest["target_hourly_usd"] + manifest["generator_hourly_usd"]) * 1.07
    if accrued >= manifest["total_budget_usd"]:
        raise RuntimeError("Akamai accrued charges reached the hard total budget")
    if max(projected, accrued + next_cost) >= manifest["operational_stop_usd"]:
        raise RuntimeError(f"projected charges reach the ${manifest['operational_stop_usd']} operational stop")


def next_attempt(evidence: Path, profile: str, repeat: int) -> int:
    pattern = re.compile(rf"^{re.escape(profile)}-r{repeat}-(?:before|after)-a(\d+)$")
    attempts = [int(match.group(1)) for item in evidence.iterdir()
                if (match := pattern.match(item.name))]
    return max(attempts, default=0) + 1


def run_side(profile: str, repeat: int, side: str, attempt: int, state: Path,
             ips: dict[str, str], protocol: dict, manifest: dict,
             expected_image: str | None = None) -> dict:
    target, generator = ips["target"], ips["generator"]
    users, ramp, hold, guard = PROFILES[profile]
    duration = ramp + hold + guard
    check_budget(manifest, duration, state)
    run_id = f"{profile}-r{repeat}-{side}-a{attempt}"
    local = state / "evidence/matrix" / run_id
    local.mkdir(parents=True, exist_ok=False)
    remote = f"/opt/jmeter-research/results/matrix/{run_id}"
    ssh(target, state, f"bash /opt/jmeter-research/restore-db.sh {side}",
        timeout=150, output=local / "restore.log")
    if expected_image is None:
        image_manifest = json.loads((ROOT / "Document/experiments/jmeter-cloud-20261023/container-images.json").read_text())
        expected_image = image_manifest["built_api_images"][side]
    actual_image = ssh(target, state, "docker inspect jmeter-research-api-1 --format={{.Image}}")
    if actual_image != expected_image:
        raise ValueError(f"{side} API image differs from frozen source build")
    ssh(target, state, "bash /opt/jmeter-research/db-state.sh",
        timeout=60, output=local / "db-state-before.txt")
    remote_hash = ssh(generator, state, f"sha256sum /opt/jmeter-research/plans/financial-api-{profile}-controlled.jmx").split()[0]
    if remote_hash != protocol[profile]["sha256"]:
        raise ValueError(f"remote {profile} JMX hash differs from frozen protocol")
    for role, ip in (("target", target), ("generator", generator)):
        ssh(ip, state, "ps -eo pid,comm,pcpu,rss --sort=-pcpu | head -n 20; docker ps",
            output=local / f"{role}-processes-before.txt")
    prepare_run_directories(target, generator, state, remote)
    for role, ip in (("target", target), ("generator", generator)):
        metrics = f"/opt/jmeter-research/results/matrix/{run_id}-{role}-metrics.jsonl"
        collector_log = f"/opt/jmeter-research/results/matrix/{run_id}-{role}-collector.log"
        ssh(ip, state, f"nohup python3 /opt/jmeter-research/collect_metrics.py "
            f"--output {metrics} --duration {duration + 40} >{collector_log} 2>&1 </dev/null &")
    plan = f"/plans/financial-api-{profile}-controlled.jmx"
    ssh(generator, state,
        "cd /opt/jmeter-research && docker compose --env-file .env -f compose-generator.yaml "
        f"run --rm --name jmeter-research-jmeter jmeter -n -t {plan} "
        f"-q /run-config/user.properties -l /results/matrix/{run_id}/run.jtl "
        f"-j /results/matrix/{run_id}/run.log",
        timeout=duration + 240, output=local / "console.log")
    for role, ip in (("target", target), ("generator", generator)):
        ssh(ip, state, "ps -eo pid,comm,pcpu,rss --sort=-pcpu | head -n 20; docker ps",
            output=local / f"{role}-processes-after.txt")
    time.sleep(45)
    for filename in ("run.jtl", "run.log"):
        scp(generator, state, f"{remote}/{filename}", local / filename)
    for role, ip in (("target", target), ("generator", generator)):
        scp(ip, state, f"/opt/jmeter-research/results/matrix/{run_id}-{role}-metrics.jsonl",
            local / f"{role}-metrics.jsonl")
    ssh(target, state, "bash /opt/jmeter-research/db-state.sh",
        timeout=60, output=local / "db-state-after.txt")
    starts = START_PATTERN.findall((local / "run.log").read_text(encoding="utf-8", errors="replace"))
    if len(starts) != 1:
        raise ValueError(f"one JMeter start timestamp required for {run_id}")
    test_start_ms = int(starts[0])
    hold_start, hold_end = ((180, 480) if profile == "spike" else (ramp, ramp + hold))
    resource = {
        role: {
            "full": summarize_metrics(local / f"{role}-metrics.jsonl"),
            "scored_hold": summarize_metrics(local / f"{role}-metrics.jsonl",
                                             test_start_ms + hold_start * 1000,
                                             test_start_ms + hold_end * 1000),
        }
        for role in ("target", "generator")
    }
    (local / "resource-summary.json").write_text(json.dumps(resource, indent=2) + "\n")
    for role in ("target", "generator"):
        full = resource[role]["full"]
        if (full["host_min_available_mib"] < 1024 or
                full["host_max_swap_total_mib"] != 0 or
                full["host_swap_pages_in_delta"] != 0 or
                full["host_swap_pages_out_delta"] != 0):
            raise RuntimeError(f"{role} host lost memory headroom or used swap in {run_id}")
        if any(item["oom_kill_delta"] not in (None, 0)
               for item in full["containers"].values()):
            raise RuntimeError(f"container OOM kill observed on {role} in {run_id}")
    jmeter_resource = resource["generator"]["scored_hold"]["containers"].get("jmeter-research-jmeter")
    jmeter_full = resource["generator"]["full"]["containers"].get("jmeter-research-jmeter")
    generator_cpu_cap = manifest.get("generator_cpu_cap", 4)
    if (jmeter_resource is None or jmeter_full is None or
            jmeter_resource["cpu_effective_cores_p95"] is None or
            jmeter_resource["cpu_effective_cores_p95"] >= 0.9 * generator_cpu_cap or
            jmeter_resource["cpu_throttled_period_fraction"] is None or
            jmeter_resource["cpu_throttled_period_fraction"] > 0.01 or
            jmeter_full["memory_peak_pct_of_limit"] >= 95):
        raise RuntimeError(f"JMeter generator headroom failed in {run_id}")
    hashes = {path.name: sha256(path) for path in local.iterdir() if path.is_file()}
    (local / "sha256.json").write_text(json.dumps(hashes, indent=2) + "\n")
    if profile == "soak":
        summary = summarize_soak(local / "run.jtl", local / "run.log")
    elif profile == "spike":
        summary = summarize_spike(local / "run.jtl", local / "run.log")
    else:
        summary = summarize(local / "run.jtl", local / "run.log", users, ramp, hold)
    (local / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    if not summary["valid_run"]:
        raise RuntimeError(f"invalid {run_id} concurrency/log gate; pair must be rerun")
    return {"run_id": run_id, "side": side, "profile": profile,
            "api_image_id": actual_image,
            "protocol_sha256": protocol[profile]["sha256"], "summary": summary,
            "resources": resource, "hashes": hashes}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-dir", type=Path, default=DEFAULT_STATE)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--max-pairs", type=int, default=15)
    args = parser.parse_args()
    pairs = list(matrix())
    if args.dry_run:
        print(json.dumps({"pairs": [{"profile": p, "repeat": r, "order": o} for p, r, o in pairs],
                          "load_hours": round(sum(2 * sum(PROFILES[p][1:]) for p, _, _ in pairs) / 3600, 2)}))
        return
    if sys.platform == "win32":
        # Keep this temporary experiment orchestration running while Windows is idle.
        ctypes.windll.kernel32.SetThreadExecutionState(0x80000000 | 0x00000001)
    state = args.state_dir.resolve()
    manifest = json.loads((state / "cloud-session.json").read_text(encoding="utf-8-sig"))
    protocol = check_profiles()
    ips = provider_ips(state, manifest)
    evidence = state / "evidence/matrix"
    evidence.mkdir(parents=True, exist_ok=True)
    started_pairs = 0
    for profile, repeat, order in pairs:
        marker = evidence / f"{profile}-r{repeat}-pair.json"
        if marker.exists():
            continue
        if started_pairs >= args.max_pairs:
            break
        attempt = next_attempt(evidence, profile, repeat)
        results = []
        for side in order:
            print(f"starting {profile} repeat {repeat} {side} attempt {attempt}", flush=True)
            results.append(run_side(profile, repeat, side, attempt, state, ips, protocol, manifest))
        marker.write_text(json.dumps({"profile": profile, "repeat": repeat,
                                      "attempt": attempt, "order": order,
                                      "runs": results}, indent=2) + "\n")
        print(f"completed pair {profile} repeat {repeat}", flush=True)
        started_pairs += 1
    if sys.platform == "win32":
        ctypes.windll.kernel32.SetThreadExecutionState(0x80000000)


if __name__ == "__main__":
    main()
