---
phase: 3
slug: settings-auto-switch
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-15
---

# Phase 3 — Validation Strategy

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
| 3-01-01 | 01 | 1 | THME-09 | manual | N/A | ⬜ pending |
| 3-01-02 | 01 | 1 | THME-10 | manual | N/A | ⬜ pending |
| 3-01-03 | 01 | 1 | THME-11 | manual | N/A | ⬜ pending |
| 3-01-04 | 01 | 1 | THME-19 | manual | N/A | ⬜ pending |
| 3-02-01 | 02 | 2 | THME-12 | manual | N/A | ⬜ pending |
| 3-02-02 | 02 | 2 | THME-13 | manual | N/A | ⬜ pending |
| 3-02-03 | 02 | 2 | THME-14 | manual | N/A | ⬜ pending |
| 3-03-01 | 03 | 3 | THME-21 | manual | N/A | ⬜ pending |
| 3-03-02 | 03 | 3 | THME-22 | manual | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Verify geolocator dependency added to pubspec.yaml
- [ ] Verify sunrise/sunset calculation logic implemented

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Theme selector displays 4 options | THME-09, THME-10 | Visual verification | Navigate to Settings, verify 4 theme options visible |
| Theme switches immediately | THME-11 | Runtime verification | Select theme, verify immediate UI change |
| Auto-switch triggers at sunrise | THME-12, THME-13 | Time-dependent | Enable auto-switch, wait for sunrise time |
| Status bar matches theme | THME-21, THME-22 | Visual verification | Switch themes, verify status bar brightness changes |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
