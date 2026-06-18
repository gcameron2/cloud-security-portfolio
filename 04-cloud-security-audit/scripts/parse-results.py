#!/usr/bin/env python3
"""
Parse Prowler OCSF JSON output and produce a prioritized findings summary.
Usage: python parse-results.py <prowler-output.ocsf.json>
"""

import json
import sys
from collections import defaultdict

SEVERITY_ORDER = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3, "Informational": 4}


def load_findings(path: str) -> list[dict]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def summarize(findings: list[dict]) -> None:
    fails = [f for f in findings if f.get("status_code") == "FAIL"]
    passes = [f for f in findings if f.get("status_code") == "PASS"]

    by_severity = defaultdict(list)
    for f in fails:
        by_severity[f.get("severity", "Unknown")].append(f)

    print(f"\n{'='*60}")
    print(f"  PROWLER FINDINGS SUMMARY")
    print(f"{'='*60}")
    print(f"  Total checks: {len(findings)}")
    print(f"  PASS:         {len(passes)}")
    print(f"  FAIL:         {len(fails)}")
    print(f"{'='*60}\n")

    for severity in sorted(by_severity, key=lambda s: SEVERITY_ORDER.get(s, 99)):
        items = by_severity[severity]
        print(f"[{severity.upper()}] — {len(items)} finding(s)")
        print("-" * 50)
        for item in items:
            check = item.get("metadata", {}).get("event_code", "unknown")
            detail = item.get("status_detail", "No detail")
            print(f"  • {check}")
            print(f"    {detail}")
        print()


def export_csv(findings: list[dict], out_path: str) -> None:
    import csv
    fails = [f for f in findings if f.get("status_code") == "FAIL"]
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Severity", "Check ID", "Status", "Detail"])
        for item in sorted(fails, key=lambda x: SEVERITY_ORDER.get(x.get("severity", ""), 99)):
            writer.writerow([
                item.get("severity", ""),
                item.get("metadata", {}).get("event_code", ""),
                item.get("status_code", ""),
                item.get("status_detail", ""),
            ])
    print(f"CSV exported to: {out_path}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: python {sys.argv[0]} <prowler-output.ocsf.json> [--csv output.csv]")
        sys.exit(1)

    findings = load_findings(sys.argv[1])
    summarize(findings)

    if "--csv" in sys.argv:
        idx = sys.argv.index("--csv")
        if idx + 1 < len(sys.argv):
            export_csv(findings, sys.argv[idx + 1])
