"""The controlled plans must sustain comparable 50/100/500-user mixes."""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
BUILDER = ROOT / "scripts" / "phase4" / "cloud-jmeter" / "prepare_profiles.py"
SOURCE = ROOT / "Document" / "performance" / "jmeter" / "financial-api-load-test.jmx"


def group_values(path):
    root = ET.parse(path).getroot()
    values = []
    for group in root.iter("ThreadGroup"):
        props = {child.get("name"): child.text for child in group if child.get("name")}
        controller = group.find("./elementProp[@name='ThreadGroup.main_controller']")
        loops = controller.find("./stringProp[@name='LoopController.loops']")
        values.append((group.get("testname"), props, loops.text))
    return values


def plan_variables(path):
    variables = {}
    for item in ET.parse(path).iter("elementProp"):
        key = item.find("./stringProp[@name='Argument.name']")
        value = item.find("./stringProp[@name='Argument.value']")
        if key is not None and value is not None:
            variables[key.text] = value.text
    return variables


class ProfileBuilderTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.output = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def build(self):
        return subprocess.run(
            [sys.executable, str(BUILDER), "--source", str(SOURCE),
             "--output-dir", str(self.output)],
            text=True, capture_output=True, check=False,
        )

    def test_100_and_500_have_steady_duration_and_same_sampler_mix(self):
        result = self.build()
        self.assertEqual(result.returncode, 0, result.stderr)
        p100 = self.output / "financial-api-p100-controlled.jmx"
        p500 = self.output / "financial-api-p500-controlled.jmx"
        for plan, counts in ((p100, [70, 30]), (p500, [350, 150])):
            groups = group_values(plan)
            self.assertEqual([int(g[1]["ThreadGroup.num_threads"]) for g in groups], counts)
            variables = plan_variables(plan)
            self.assertEqual(variables["coreUsers"], str(counts[0]))
            self.assertEqual(variables["complexUsers"], str(counts[1]))
            for _, props, loops in groups:
                self.assertEqual(loops, "-1")
                self.assertEqual(props["ThreadGroup.scheduler"], "true")
                self.assertEqual(props["ThreadGroup.ramp_time"], "120")
                self.assertEqual(props["ThreadGroup.duration"], "750")
        samplers = lambda plan: [n.get("testname") for n in ET.parse(plan).iter("HTTPSamplerProxy")]
        self.assertEqual(samplers(p100), samplers(p500))

    def test_50_uses_the_same_core_complex_ratio(self):
        result = self.build()
        self.assertEqual(result.returncode, 0, result.stderr)
        groups = group_values(self.output / "financial-api-p50-controlled.jmx")
        self.assertEqual([int(g[1]["ThreadGroup.num_threads"]) for g in groups], [35, 15])

    def test_soak_holds_100_users_for_45_minutes(self):
        result = self.build()
        self.assertEqual(result.returncode, 0, result.stderr)
        groups = group_values(self.output / "financial-api-soak-controlled.jmx")
        self.assertEqual([int(g[1]["ThreadGroup.num_threads"]) for g in groups], [70, 30])
        self.assertTrue(all(g[1]["ThreadGroup.duration"] == "2850" for g in groups))

    def test_generated_plans_do_not_embed_the_old_default_password(self):
        result = self.build()
        self.assertEqual(result.returncode, 0, result.stderr)
        for plan in self.output.glob("*.jmx"):
            content = plan.read_text(encoding="utf-8")
            self.assertFalse("Admin@123" in content, plan.name)
            self.assertIn("${__P(password,)}", content)

    def test_mixed_flow_is_default_and_report_ids_are_in_get_urls(self):
        result = self.build()
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = self.output / "financial-api-p500-controlled.jmx"
        self.assertEqual(plan_variables(plan)["mode"], "${__P(mode,mixed)}")
        reports = [node for node in ET.parse(plan).iter("HTTPSamplerProxy")
                   if (node.get("testname") or "").startswith("GET /reports/")]
        self.assertEqual(len(reports), 4)
        for sampler in reports:
            path = sampler.find("./stringProp[@name='HTTPSampler.path']").text
            self.assertIn("?", path, sampler.get("testname"))
            self.assertIn("periodId=${periodId}", path)
            if sampler.get("testname") == "GET /reports/account-ledger":
                self.assertIn("accountId=${accountId}", path)
            arguments = sampler.find("./elementProp[@name='HTTPsampler.Arguments']/collectionProp")
            self.assertEqual(len(arguments), 0)

    def test_spike_adds_400_users_then_returns_to_100(self):
        result = self.build()
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = self.output / "financial-api-spike-controlled.jmx"
        self.assertTrue(plan.exists(), "the controlled spike profile is missing")
        groups = group_values(plan)
        self.assertEqual([int(g[1]["ThreadGroup.num_threads"]) for g in groups],
                         [70, 30, 280, 120])
        self.assertEqual([g[1]["ThreadGroup.delay"] for g in groups],
                         ["0", "0", "150", "150"])
        self.assertEqual([g[1]["ThreadGroup.ramp_time"] for g in groups],
                         ["30", "30", "30", "30"])
        self.assertEqual([g[1]["ThreadGroup.duration"] for g in groups],
                         ["840", "840", "360", "360"])
        self.assertTrue(all(g[2] == "-1" for g in groups))


if __name__ == "__main__":
    unittest.main()
