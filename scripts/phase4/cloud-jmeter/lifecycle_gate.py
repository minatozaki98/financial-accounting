"""Prove sustained JMeter users from thread lifecycle events, independent of requests."""

from collections import Counter
from datetime import datetime
import math
import re


STAMP = "%Y-%m-%d %H:%M:%S,%f"
RUN_LINE = re.compile(r"^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d,\d{3}).*\bRunning test \((\d+)\)")
THREAD_LINE = re.compile(
    r"^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d,\d{3}).*JMeterThread: Thread (started|finished): (.+)$"
)


def _delta_ms(stamp: datetime, anchor: datetime) -> int:
    delta = stamp - anchor
    return delta.days * 86_400_000 + delta.seconds * 1_000 + delta.microseconds // 1_000


def analyze_lifecycle(log_text: str, target_users: int, test_start_ms: int,
                      start_second: int, end_second: int,
                      settle_seconds: int = 0) -> dict:
    """Require the target thread count throughout a scored window after settling."""
    anchors = [match for line in log_text.splitlines()
               if (match := RUN_LINE.match(line))]
    failures = []
    if len(anchors) != 1:
        return {"valid": False, "failures": ["missing_or_duplicate_test_anchor"],
                "target_users": target_users, "started_threads": 0,
                "finished_threads": 0, "active_at_window_start": None,
                "minimum_active": None, "maximum_active": None}
    anchor = datetime.strptime(anchors[0].group(1), STAMP)
    anchor_ms = int(anchors[0].group(2))
    if anchor_ms != test_start_ms:
        failures.append("test_anchor_mismatch")
    events = []
    starts = Counter()
    finishes = Counter()
    for line in log_text.splitlines():
        match = THREAD_LINE.match(line)
        if match is None:
            continue
        when = anchor_ms + _delta_ms(datetime.strptime(match.group(1), STAMP), anchor)
        action, name = match.group(2), match.group(3)
        events.append((when, 1 if action == "started" else -1, name))
        (starts if action == "started" else finishes)[name] += 1
    if not events:
        failures.append("missing_thread_lifecycle")
    if any(count != 1 for count in starts.values()) or any(count != 1 for count in finishes.values()):
        failures.append("duplicate_thread_event")
    if starts != finishes:
        failures.append("incomplete_thread_lifecycle")
    begin = test_start_ms + (start_second + settle_seconds) * 1_000
    end = test_start_ms + end_second * 1_000
    if begin >= end:
        failures.append("empty_scored_window")
    active = 0
    active_at_start = None
    minimum = None
    maximum = None
    # For events at the same millisecond, start before finish is conservative
    # for this experiment; duplicate and early-finish checks remain explicit.
    for when, change, _ in sorted(events, key=lambda item: (item[0], -item[1])):
        if when >= end:
            break
        if when > begin and active_at_start is None:
            active_at_start = active
            minimum = maximum = active
        active += change
        if active < 0:
            failures.append("thread_finished_before_start")
        if when <= begin:
            continue
        minimum = min(minimum, active)
        maximum = max(maximum, active)
    if active_at_start is None:
        active_at_start = active
        minimum = maximum = active
    if active_at_start != target_users:
        failures.append("target_not_active_at_window_start")
    if minimum < target_users:
        failures.append("early_thread_finish")
    if maximum > target_users:
        failures.append("extra_threads_during_window")
    return {
        "valid": not failures,
        "failures": sorted(set(failures)),
        "target_users": target_users,
        "started_threads": sum(starts.values()),
        "finished_threads": sum(finishes.values()),
        "active_at_window_start": active_at_start,
        "minimum_active": minimum,
        "maximum_active": maximum,
        "settle_seconds": settle_seconds,
    }


def reconcile_jtl_with_lifecycle(jtl: dict, lifecycle: dict) -> dict:
    """Use request bins as consistency/stall evidence, not a thread-count clock."""
    observed = jtl["bins_observed"]
    target = jtl["target_users"]
    failures = list(lifecycle["failures"])
    if observed == 0:
        failures.append("no_sampled_bins")
    elif jtl["full_bins"] < math.ceil(observed * 0.95):
        failures.append("insufficient_exact_sampled_bins")
    if (jtl["min_hold_active"] is not None and
            jtl["min_hold_active"] < math.ceil(target * 0.95)):
        failures.append("sampled_below_95_percent")
    return {
        **jtl,
        "valid": not failures,
        "failures": sorted(set(failures)),
        "jtl_missing_bins": jtl["hold_bins"] - observed,
        "jtl_diagnostics": jtl,
        "lifecycle": lifecycle,
    }
