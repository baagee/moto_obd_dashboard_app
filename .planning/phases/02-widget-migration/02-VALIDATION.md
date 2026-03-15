---
phase: 2
slug: widget-migration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-14
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test (built-in) |
| **Config file** | test/widget_test.dart (exists) |
| **Quick run command** | `flutter analyze` |
| **Full suite command** | `flutter analyze && flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter analyze` (fast feedback)
- **After every plan wave:** Run `flutter analyze && flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 2-01-01 | 01 | 1 | THME-15 | manual | N/A | ⬜ pending |
| 2-02-01 | 02 | 1 | THME-16 | manual | N/A | ⬜ pending |
| 2-02-02 | 02 | 1 | THME-17 | manual | N/A | ⬜ pending |
| 2-02-03 | 02 | 1 | THME-18 | manual | N/A | ⬜ pending |
| 2-03-01 | 03 | 2 | THME-20 | manual | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Verify migration patterns documented in RESEARCH.md
- [ ] Verify test directory structure exists

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| DashboardScreen displays correctly in all 4 themes | THME-16 | Visual verification requires device/emulator | Launch app in all 4 themes, verify all widgets render correctly |
| LogsScreen displays correctly in all 4 themes | THME-17 | Visual verification requires device/emulator | Navigate to Logs tab in all themes |
| BluetoothScanScreen displays correctly in all 4 themes | THME-18 | Visual verification requires device/emulator | Navigate to Devices tab in all themes |
| Gauge widgets display correctly in all themes | THME-20 | CustomPaint verification requires device | Check speed gauge, RPM gauge, combined gauge in all themes |
| All widgets use dynamic colors | THME-15 | Code review | grep for hardcoded Color(0xFF...) in widget files |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
