"""Write five-second host/container metrics without logging environment secrets."""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import time


def command(*args: str, timeout: int = 10) -> str:
    completed = subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=True)
    return completed.stdout


def key_values(content: str) -> dict[str, int]:
    result = {}
    for line in content.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[1].isdigit():
            result[parts[0].rstrip(":")] = int(parts[1])
    return result


def host_snapshot(previous_cpu):
    mem = key_values(Path("/proc/meminfo").read_text())
    virtual_memory = key_values(Path("/proc/vmstat").read_text())
    fields = Path("/proc/stat").read_text().splitlines()[0].split()[1:]
    cpu = [int(value) for value in fields]
    cpu_percent = None
    if previous_cpu is not None:
        total_delta = sum(cpu) - sum(previous_cpu)
        idle_delta = (cpu[3] + cpu[4]) - (previous_cpu[3] + previous_cpu[4])
        if total_delta > 0:
            cpu_percent = round(100 * (1 - idle_delta / total_delta), 2)
    return {
        "cpu_percent": cpu_percent,
        "available_kib": mem.get("MemAvailable"),
        "swap_used_kib": mem.get("SwapTotal", 0) - mem.get("SwapFree", 0),
        "swap_pages_in": virtual_memory.get("pswpin", 0),
        "swap_pages_out": virtual_memory.get("pswpout", 0),
        "load_average": Path("/proc/loadavg").read_text().split()[:3],
    }, cpu


def containers_snapshot():
    output = command("docker", "stats", "--no-stream", "--format", "{{json .}}")
    containers = []
    for line in output.splitlines():
        if not line.strip():
            continue
        item = json.loads(line)
        name = item.get("Name", "")
        if not name.startswith("jmeter-research-"):
            continue
        for file, key in (("cpu.stat", "cpu_stat"), ("memory.events", "memory_events")):
            try:
                item[key] = key_values(command("docker", "exec", name, "cat", f"/sys/fs/cgroup/{file}"))
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
                item[key] = None
        containers.append(item)
    return containers


def collect(output: Path, duration_seconds: int, interval_seconds: int = 5) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    deadline = time.monotonic() + duration_seconds
    previous_cpu = None
    with output.open("w", encoding="utf-8") as handle:
        while time.monotonic() < deadline:
            start = time.monotonic()
            host, previous_cpu = host_snapshot(previous_cpu)
            record = {"time_utc": datetime.now(timezone.utc).isoformat(), "host": host}
            try:
                record["containers"] = containers_snapshot()
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
                record["container_error"] = type(error).__name__
            handle.write(json.dumps(record, separators=(",", ":")) + "\n")
            handle.flush()
            time.sleep(max(0, interval_seconds - (time.monotonic() - start)))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--duration", type=int, required=True)
    args = parser.parse_args()
    if args.duration < 5 or args.duration > 4 * 3600:
        parser.error("duration must be between 5 seconds and 4 hours")
    collect(args.output, args.duration)


if __name__ == "__main__":
    main()
