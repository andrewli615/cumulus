import base64
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import uuid

spec = importlib.util.spec_from_file_location("archive", Path(__file__).parents[1] / "scripts/retrieve-test-archive.py")
archive = importlib.util.module_from_spec(spec)
spec.loader.exec_module(archive)


class RetrievalChecks(unittest.TestCase):
    def test_fractional_dates_and_diagnostic_decoding(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            report = {"id": "overnight-synthetic", "schemaVersion": 1, "kind": "overnight",
                      "createdAt": 100.12345, "diagnostics": base64.b64encode(
                          json.dumps({"count": 60000, "leadingGap": 5.42}).encode()).decode()}
            (path / "overnight-synthetic.json").write_text(json.dumps(report))
            reports, failures = archive.read_reports(path)
            self.assertFalse(failures)
            self.assertEqual(reports[0]["createdAt"], 100.12345)
            self.assertEqual(reports[0]["diagnostics"]["leadingGap"], 5.42)
            (path / "invalid.json").write_text("not-json")
            reports, failures = archive.read_reports(path)
            self.assertEqual(len(reports), 1)
            self.assertEqual(len(failures), 1)

    def test_alarm_history_and_reference_date_encoding(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "record.json"
            identifier = str(uuid.uuid4())
            record = {"id": identifier, "phase": "hapticRequested", "createdAt": 100,
                      "fireDate": 200, "hapticRequestedAt": 200.25,
                      "events": [{"id": str(uuid.uuid4()), "alarmID": identifier,
                                  "fireDate": 200, "date": 200.25,
                                  "message": "Haptic requested (default repeat interval)"}]}
            path.write_text(json.dumps(record))
            result = archive.read_alarm(path)
            self.assertIn("2001-01-01", result["dateEncoding"])
            self.assertEqual(result["hapticRequests"][0]["offsetSeconds"], 0.25)
            self.assertTrue(result["hapticRequests"][0]["requestWithin60Seconds"])
            record["replacementFireDate"] = 300
            record["phase"] = "cancellationRequested"
            path.write_text(json.dumps(record))
            self.assertEqual(archive.read_alarm(path)["record"]["replacementFireDate"], 300)
            record["phase"] = "stopped"
            path.write_text(json.dumps(record))
            with self.assertRaises(ValueError):
                archive.read_alarm(path)
            del record["replacementFireDate"]
            record["events"] *= 41
            path.write_text(json.dumps(record))
            with self.assertRaises(ValueError):
                archive.read_alarm(path)
            record["events"] = []
            record["fireDate"] = float("nan")
            path.write_text(json.dumps(record))
            with self.assertRaises(ValueError):
                archive.read_alarm(path)

    def test_git_guard_including_ignored_folders(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / ".git").mkdir()
            with self.assertRaises(ValueError):
                archive.private_destination(root / "PrivateData" / "reports")
            self.assertFalse((root / "PrivateData").exists())

    def test_missing_input_and_existing_output(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            with self.assertRaises(ValueError):
                archive.read_reports(root / "missing")
            with self.assertRaises(ValueError):
                archive.private_destination(root)
            (root / "wrong-name.json").write_text(json.dumps({"id": "sleep-other", "schemaVersion": 1}))
            reports, failures = archive.read_reports(root)
            self.assertFalse(reports)
            self.assertEqual(len(failures), 1)


if __name__ == "__main__":
    unittest.main()
