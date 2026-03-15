---
phase: 1
slug: theme-infrastructure
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-14
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test (built-in) |
| **Config file** | test/widget_test.dart (exists) |
| **Quick run command** | `flutter test` |
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
| 1-01-01 | 01 | 1 | THME-01 | manual | N/A | ⬜ pending |
| 1-01-02 | 01 | 1 | THME-02 | manual | N/A | ⬜ pending |
| 1-01-03 | 01 | 1 | THME-03 | manual | N/A | ⬜ pending |
| 1-01-04 | 01 | 1 | THME-04 | manual | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Verify `shared_preferences` dependency added to pubspec.yaml
- [ ] Verify test directory structure exists for theme tests

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Theme colors visually correct | THME-01 to THME-08 | Visual verification requires device/emulator | Launch app, verify all 4 themes display correctly |
| Theme persistence works | THME-04 | Requires app restart | Change theme, restart app, verify theme persisted |
| No startup flash | THME-01 | Timing verification | Launch app, observe no white flash before theme loads |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
