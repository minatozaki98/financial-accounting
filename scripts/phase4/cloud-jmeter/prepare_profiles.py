"""Build duration-bound JMeter plans from the existing endpoint workload."""

import argparse
import hashlib
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET


PROFILES = {
    "p50": (35, 15),
    "p100": (70, 30),
    "p500": (350, 150),
    "soak": (70, 30),
}


def set_property(group: ET.Element, name: str, value: str) -> None:
    item = next((child for child in group if child.get("name") == name), None)
    if item is None:
        raise ValueError(f"missing {name} in {group.get('testname')}")
    item.text = value


def build_profile(source: Path, output: Path, core: int, complex_users: int,
                  ramp_seconds: int, hold_seconds: int) -> str:
    tree = ET.parse(source)
    root = tree.getroot()
    groups = list(root.iter("ThreadGroup"))
    if len(groups) != 2:
        raise ValueError(f"expected two workload thread groups, found {len(groups)}")
    for group, count in zip(groups, (core, complex_users)):
        set_property(group, "ThreadGroup.num_threads", str(count))
        set_property(group, "ThreadGroup.ramp_time", str(ramp_seconds))
        set_property(group, "ThreadGroup.scheduler", "true")
        set_property(group, "ThreadGroup.duration", str(ramp_seconds + hold_seconds))
        set_property(group, "ThreadGroup.delay", "0")
        controller = group.find("./elementProp[@name='ThreadGroup.main_controller']")
        if controller is None:
            raise ValueError(f"missing loop controller in {group.get('testname')}")
        loop = controller.find("./stringProp[@name='LoopController.loops']")
        forever = controller.find("./boolProp[@name='LoopController.continue_forever']")
        if loop is None or forever is None:
            raise ValueError(f"missing loop properties in {group.get('testname')}")
        loop.text = "-1"
        forever.text = "true"

    fixed_variables = {
        "coreUsers": str(core),
        "complexUsers": str(complex_users),
        "coreRampUp": str(ramp_seconds),
        "complexRampUp": str(ramp_seconds),
        "loops": "-1",
        "complexLoops": "-1",
        "password": "${__P(password,)}",
    }
    for item in root.iter("elementProp"):
        name = item.find("./stringProp[@name='Argument.name']")
        value = item.find("./stringProp[@name='Argument.value']")
        if name is not None and value is not None and name.text in fixed_variables:
            value.text = fixed_variables[name.text]

    output.parent.mkdir(parents=True, exist_ok=True)
    tree.write(output, encoding="utf-8", xml_declaration=True)
    return hashlib.sha256(output.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--ramp-seconds", type=int, default=120)
    parser.add_argument("--hold-seconds", type=int, default=600)
    parser.add_argument("--soak-hold-seconds", type=int, default=2700)
    args = parser.parse_args()
    if args.ramp_seconds < 1 or args.hold_seconds < 1 or args.soak_hold_seconds < 1:
        parser.error("ramp and hold durations must be positive")
    try:
        manifest = {}
        for profile, (core, complex_users) in PROFILES.items():
            hold = args.soak_hold_seconds if profile == "soak" else args.hold_seconds
            output = args.output_dir / f"financial-api-{profile}-controlled.jmx"
            digest = build_profile(args.source, output, core, complex_users,
                                   args.ramp_seconds, hold)
            manifest[profile] = {
                "core_users": core,
                "complex_users": complex_users,
                "ramp_seconds": args.ramp_seconds,
                "hold_seconds": hold,
                "sha256": digest,
                "path": output.as_posix(),
            }
    except (OSError, ET.ParseError, ValueError) as exc:
        parser.error(str(exc))
    print(json.dumps(manifest, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
