"""The system accessibility audits wait for the device campaign (owner ruling of 2026-11-13; feature UA-F10, FR-U10-042,
T-U10-031): the shared audit helper returns before `performAccessibilityAudit` unless `VC_RUN_AUDITS` is `1`, and no
other UI test source calls the system audit directly."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
UI = REPO / "Apps" / "VisualCore" / "Tests" / "UI"
SUPPORT = UI / "AppUITestSupport.swift"


def deferral_problems(support_text: str, others: dict[str, str]) -> list[str]:
    """Problems with the audit deferral: the guard missing or after the audit call, or a direct call elsewhere."""
    problems = []
    body = support_text.split("func audit(", 1)
    if len(body) < 2:
        return ["AppUITestSupport.swift has no audit(...) helper"]
    helper = body[1]
    guard = re.search(r'environment\["VC_RUN_AUDITS"\]\s*==\s*"1"\s*else\s*\{[^}]*return', helper)
    call = helper.find("performAccessibilityAudit")
    if not guard or call < 0 or guard.start() > call:
        problems.append("audit(...) does not return before performAccessibilityAudit unless VC_RUN_AUDITS is 1")
    for name, text in sorted(others.items()):
        code = "\n".join(line.split("//", 1)[0] for line in text.splitlines())
        if "performAccessibilityAudit" in code:
            problems.append(f"{name} calls performAccessibilityAudit directly")
    return problems


class AuditDeferralTests(unittest.TestCase):
    def sources(self):
        others = {str(p.relative_to(UI)): p.read_text() for p in UI.rglob("*.swift") if p != SUPPORT}
        return SUPPORT.read_text(), others

    def test_the_repository_defers_every_audit(self):
        support, others = self.sources()
        self.assertEqual(deferral_problems(support, others), [])

    def test_a_missing_guard_is_found(self):
        support, others = self.sources()
        planted = support.replace('environment["VC_RUN_AUDITS"] == "1"', 'environment["OTHER"] == "1"')
        self.assertTrue(deferral_problems(planted, others))

    def test_a_direct_call_elsewhere_is_found(self):
        support, others = self.sources()
        others = dict(others, **{"Planted.swift": "func f() { try app.performAccessibilityAudit() }"})
        self.assertIn("Planted.swift calls performAccessibilityAudit directly", deferral_problems(support, others))


if __name__ == "__main__":
    unittest.main()
