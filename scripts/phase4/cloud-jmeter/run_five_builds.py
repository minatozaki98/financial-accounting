"""Prepare or run the controlled five-build financial-accounting comparison."""
import argparse
from contextlib import contextmanager
import hashlib
import json
from pathlib import Path
import re

from compare_matrix import gate_passes, primary, reanalyze_run, spread
from run_matrix import PROFILES, check_profiles, provider_ips, run_side

BUILDS = ("baseline", "gpt55", "luna", "terra", "sol")


def make_plan(builds, schema_dir):
    if set(builds) != set(BUILDS):
        raise ValueError("Expected baseline, gpt55, luna, terra and sol builds")
    for name, build in builds.items():
        if (not re.fullmatch(r"[a-f0-9]{40}", build["revision"]) or
                not re.fullmatch(r"sha256:[a-f0-9]{64}", build["image_id"]) or
                build["tag"] != f"financial-api:bench56-{name}"):
            raise ValueError(f"Invalid frozen build identity for {name}")
        schema = build["schema_sha256"]
        if schema is not None:
            path = schema_dir / f"bench56-{name}.sql"
            if hashlib.sha256(path.read_bytes()).hexdigest() != schema:
                raise ValueError(f"Post-restore SQL differs for {name}")
    hashes = {name: values["sha256"] for name, values in check_profiles().items()}
    blocks = []
    for index, profile in enumerate(PROFILES):
        for repeat in (1, 2, 3):
            start = (index + 2 * (repeat - 1)) % len(BUILDS)
            blocks.append(dict(profile=profile, repeat=repeat,
                               order=BUILDS[start:] + BUILDS[:start]))
    return dict(builds=builds, workloads=hashes, blocks=blocks)


def write_json(path, data):
    pending = path.with_suffix(".tmp")
    pending.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    pending.replace(path)


@contextmanager
def lock_evidence(evidence):
    # The controller runs on Windows. OS locks are released on process exit.
    import msvcrt
    with (evidence / "five-build.lock").open("a+b") as lock:
        lock.seek(0)
        msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
        try:
            yield
        finally:
            lock.seek(0)
            msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)


def execute(plan, state):
    manifest = json.loads((state / "cloud-session.json").read_text(encoding="utf-8-sig"))
    protocol = check_profiles()
    evidence = state / "evidence/matrix"
    evidence.mkdir(parents=True, exist_ok=True)
    fingerprint = hashlib.sha256(json.dumps(plan, sort_keys=True).encode()).hexdigest()
    with lock_evidence(evidence):
        stamp = evidence / "five-build-plan.json"
        if stamp.exists():
            if json.loads(stamp.read_text())["fingerprint"] != fingerprint:
                raise ValueError("Frozen plan differs from this session")
        elif any(p.name != "five-build.lock" for p in evidence.iterdir()):
            raise ValueError("Use a fresh experiment state for the five-build comparison")
        else:
            write_json(stamp, dict(fingerprint=fingerprint, plan=plan))
        ips = provider_ips(state, manifest)
        for block in plan["blocks"]:
            profile, repeat = block["profile"], block["repeat"]
            prefix = f"{profile}-r{repeat}"
            marker = evidence / f"{prefix}-five.json"
            if marker.exists():
                continue
            # Repeat an interrupted block in full to preserve same-block comparisons.
            attempts = [int(p.name.rsplit("-a", 1)[1]) for p in evidence.glob(prefix+"-bench56-*-a*") if p.is_dir()]
            attempt = max(attempts, default=0) + 1
            runs = {}
            for name in block["order"]:
                runs[name] = run_side(profile, repeat, "bench56-"+name, attempt, state,
                                      ips, protocol, manifest, plan["builds"][name]["image_id"],
                                      plan["builds"][name]["schema_sha256"])
            write_json(marker, dict(fingerprint=fingerprint, runs=runs))
        rows = []
        for profile, (users, ramp, hold, _) in PROFILES.items():
            for name in BUILDS:
                scores = []
                for repeat in (1, 2, 3):
                    block = json.loads((evidence / f"{profile}-r{repeat}-five.json").read_text())
                    if block["fingerprint"] != fingerprint:
                        raise ValueError("Run block does not match the frozen comparison")
                    run = block["runs"][name]
                    summary = reanalyze_run(evidence / run["run_id"], profile, users, ramp, hold)
                    if not summary["valid_run"]:
                        raise ValueError("Invalid scored run: "+run["run_id"])
                    scores.append(dict(run_id=run["run_id"], passed=gate_passes(summary, profile),
                                       **primary(summary, profile)))
                metrics = {key: spread([s[key] for s in scores]) for key in
                           ("p95_ms", "p99_ms", "requests_per_second", "error_pct", "drift_pct")
                           if all(s[key] is not None for s in scores)}
                rows.append(dict(profile=profile, build=name, runs=scores, metrics=metrics))
        # Subtract same-repetition reference values before computing the spread.
        by_key = {(row["profile"], row["build"]): row for row in rows}
        for row in rows:
            row["paired_differences"] = {}
            for ref in ("baseline", "gpt55"):
                if ref == row["build"]:
                    continue
                reference = by_key[row["profile"], ref]
                row["paired_differences"][ref] = {
                    metric: spread([run[metric] - other[metric] for run, other in
                                    zip(row["runs"], reference["runs"], strict=True)])
                    for metric in row["metrics"]
                }
        write_json(evidence / "five-build-results.json", rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--builds", required=True, type=Path)
    parser.add_argument("--execute", action="store_true", help="Run on an already provisioned target and generator")
    parser.add_argument("--state-dir", type=Path)
    parser.add_argument("--output", type=Path, help="Save the offline schedule")
    args = parser.parse_args()
    plan = make_plan(json.loads(args.builds.read_text(encoding="utf-8-sig")),
                     args.builds.parent / "schema")
    if args.output:
        write_json(args.output, plan)
    if args.execute:
        if args.state_dir is None:
            parser.error("--execute requires --state-dir")
        execute(plan, args.state_dir.resolve())
    else:
        print(json.dumps(plan, indent=2))


if __name__ == "__main__":
    main()
