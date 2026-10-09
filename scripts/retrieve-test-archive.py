#!/usr/bin/env python3
"""Read Cumulus diagnostic reports into a private directory outside Git."""
import argparse
import base64
import json
import math
import uuid
import os
from pathlib import Path
import subprocess

BUNDLE = "com.example.cumulus.watchkitapp"
SOURCE = "Library/Application Support/Cumulus/TestArchive"
ALARM_SOURCE = "Library/Application Support/Cumulus/Alarm/record.json"


def private_destination(path):
    path = path.expanduser().resolve()
    if any((parent / ".git").exists() for parent in [path, *path.parents]):
        raise ValueError("Output must be outside every Git checkout, including ignored directories.")
    if path.exists():
        raise ValueError("Use a new private output directory; existing files are not overwritten.")
    path.mkdir(parents=True, mode=0o700)
    return path


def device_command(arguments, result):
    process = subprocess.run(["xcrun", "devicectl", *arguments, "--quiet", "--timeout", "60",
                              "--json-output", str(result)], capture_output=True, text=True, timeout=70)
    if process.returncode:
        # Device errors can include personal names. Keep them in the private output only.
        result.with_suffix(".error.txt").write_text(process.stderr + process.stdout)
        raise RuntimeError("Device read failed; inspect the private error file. No app was launched.")


def read_reports(directory):
    if not directory.is_dir():
        raise ValueError("Archive directory is unavailable; launch the updated app before retrieval.")
    reports, failures = [], []
    for path in sorted(directory.rglob("*.json")):
        try:
            if path.is_symlink() or path.stat().st_size > 512_000:
                raise ValueError("Invalid report file")
            report = json.loads(path.read_bytes())
            if not isinstance(report, dict) or report.get("schemaVersion") != 1:
                raise ValueError("Unsupported report schema")
            if report.get("id", "") + ".json" != path.name:
                raise ValueError("Report identity does not match file")
            diagnostics = report.get("diagnostics")
            if diagnostics is not None:
                decoded = base64.b64decode(diagnostics, validate=True)
                if len(decoded) > 350_000:
                    raise ValueError("Diagnostic payload exceeds the archive limit")
                report["diagnostics"] = json.loads(decoded)
            reports.append(report)
        except (OSError, ValueError, TypeError) as error:
            failures.append({"file": path.name, "error": type(error).__name__})
    return reports, failures



def read_alarm(path):
    if path.is_symlink() or path.stat().st_size > 64_000:
        raise ValueError("Invalid alarm record file")
    record = json.loads(path.read_bytes())
    phases = {"requesting", "scheduled", "hapticRequested", "cancellationRequested", "stopRequested",
              "cancelled", "stopped", "ended", "failed"}
    if not isinstance(record, dict) or record.get("phase") not in phases:
        raise ValueError("Invalid alarm record")
    if not isinstance(record.get("id"), str):
        raise ValueError("Invalid alarm identity")
    uuid.UUID(record["id"])
    dates = [record["fireDate"], record["createdAt"]]
    if record.get("hapticRequestedAt") is not None:
        dates.append(record["hapticRequestedAt"])
    events = record.get("events")
    if not isinstance(events, list) or len(events) > 40:
        raise ValueError("Invalid alarm history bound")
    event_ids, requests = set(), []
    for event in events:
        if not isinstance(event, dict) or not isinstance(event.get("message"), str) or len(event["message"]) > 500:
            raise ValueError("Invalid alarm event")
        if not isinstance(event.get("id"), str) or not isinstance(event.get("alarmID"), str):
            raise ValueError("Invalid alarm event identity")
        uuid.UUID(event["id"])
        uuid.UUID(event["alarmID"])
        if event["id"] in event_ids:
            raise ValueError("Duplicate alarm event")
        event_ids.add(event["id"])
        if any(type(event.get(key)) not in (int, float) or not math.isfinite(event[key]) for key in ("date", "fireDate")):
            raise ValueError("Invalid alarm event date")
        dates.extend([event["date"], event["fireDate"]])
        if event["message"].startswith("Haptic requested ("):
            offset = event["date"] - event["fireDate"]
            requests.append({"alarmID": event["alarmID"], "offsetSeconds": offset,
                             "requestWithin60Seconds": 0 <= offset <= 60})
    if any(type(date) not in (int, float) or not math.isfinite(date) for date in dates):
        raise ValueError("Invalid alarm date")
    if record["phase"] == "hapticRequested" and record.get("hapticRequestedAt") is None:
        raise ValueError("Haptic state lacks a request timestamp")
    return {"schemaVersion": 1, "dateEncoding": "Seconds since 2001-01-01T00:00:00Z (Foundation default)",
            "scope": "Separate fixed-alarm configuration and bounded lifecycle history; no sensor or HealthKit records",
            "evidenceLimit": "Offsets describe software requests, not perceived alerts, battery, or reliable waking",
            "record": record, "hapticRequests": requests}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path, help="New private directory outside Git")
    parser.add_argument("--device", help="Device identifier; default requires exactly one connected Apple Watch")
    parser.add_argument("--from-directory", type=Path, help="Evaluate an already retrieved archive without device access")
    parser.add_argument("--alarm-only", action="store_true", help="Read the separate fixed-alarm record instead of research reports")
    args = parser.parse_args()
    output = private_destination(args.output)
    os.umask(0o077)
    if args.from_directory:
        source = args.from_directory.expanduser().resolve()
        if source == output or output in source.parents or source in output.parents:
            raise ValueError("Input and output must be separate directories.")
    else:
        identifier = args.device
        if not identifier:
            result = output / "devices.json"
            device_command(["list", "devices"], result)
            devices = json.loads(result.read_bytes())["result"]["devices"]
            watches = [device for device in devices
                       if "Apple Watch" in device.get("hardwareProperties", {}).get("marketingName", "")
                       and device.get("connectionProperties", {}).get("tunnelState") == "connected"]
            if len(watches) != 1:
                raise RuntimeError("Exactly one connected Watch is required; otherwise specify --device.")
            identifier = watches[0]["identifier"]
        source = output / ("record.json" if args.alarm_only else "archive")
        device_command(["device", "copy", "from", "--device", identifier, "--source", ALARM_SOURCE if args.alarm_only else SOURCE,
                        "--domain-type", "appDataContainer", "--domain-identifier", BUNDLE,
                        "--destination", str(source)], output / "copy-result.json")
    if args.alarm_only:
        alarm = read_alarm(source / "record.json" if args.from_directory else source)
        destination = output / "alarm-evaluation.json"
        destination.write_text(json.dumps(alarm, indent=2, allow_nan=False) + "\n")
        print(f"Retrieved fixed-alarm history: {len(alarm['record']['events'])} events.")
        print(f"Private evaluation: {destination}")
        return
    reports, failures = read_reports(source)
    result = {"schemaVersion": 1, "dateEncoding": "Unix seconds, including fractions",
              "scope": "Diagnostic summaries only; no raw motion vectors or individual HealthKit records",
              "evidenceLimit": "Software states do not confirm perception, sleeping, wearing, or unrecorded conditions",
              "reports": reports, "unreadableReports": failures}
    (output / "evaluation.json").write_text(json.dumps(result, indent=2, allow_nan=False) + "\n")
    counts = {kind: sum(report.get("kind") == kind for report in reports)
              for kind in sorted({report.get("kind", "unknown") for report in reports})}
    print(f"Retrieved {len(reports)} diagnostic reports; {len(failures)} unreadable reports.")
    print(json.dumps(counts, sort_keys=True))
    print(f"Private evaluation: {output / 'evaluation.json'}")
    if failures:
        raise RuntimeError("Some reports could not be decoded; preserve the original files.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, RuntimeError, subprocess.TimeoutExpired) as error:
        raise SystemExit(str(error)) from error
