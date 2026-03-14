# ROADMAP: CYBER-CYCLE OBD Dashboard - Theme System

**Created:** 2026-03-14
**Granularity:** Coarse
**Total Phases:** 3

---

## Phases

- [ ] **Phase 1: Theme Infrastructure** - Foundation: ThemeProvider, ThemeColors model, 4 theme definitions, persistence
- [ ] **Phase 2: Widget Migration** - All widgets refactored to use dynamic theme colors
- [ ] **Phase 3: Settings & Auto-Switch** - Settings page UI, manual theme selection, sunrise/sunset auto-switch

---

## Phase Details

### Phase 1: Theme Infrastructure
**Goal:** Create theme system foundation with ThemeProvider, ThemeColors model, 4 theme definitions, and persistence layer

**Depends on:** Nothing (first phase)

**Requirements:** THME-01, THME-02, THME-03, THME-04, THME-05, THME-06, THME-07, THME-08

**Success Criteria (what must be TRUE):**
1. User can access app and see theme colors applied correctly (no flash on startup)
2. ThemeProvider manages current theme state and notifies listeners on change
3. 4 themes (Cyber Blue, Red, Orange, Light) are defined with all color tokens
4. Theme preference persists across app restarts
5. ThemeData in main.dart uses AppTheme constants (no duplication)

**Plans:** TBD

---

### Phase 2: Widget Migration
**Goal:** Refactor all widgets to use dynamic theme colors instead of hardcoded values

**Depends on:** Phase 1

**Requirements:** THME-15, THME-16, THME-17, THME-18, THME-19, THME-20

**Success Criteria (what must be TRUE):**
1. DashboardScreen displays correctly in all 4 themes
2. LogsScreen displays correctly in all 4 themes
3. BluetoothScanScreen displays correctly in all 4 themes
4. SettingsScreen displays correctly in all 4 themes
5. Gauge widgets (speed, RPM, combined) accept theme colors and display correctly

**Plans:** TBD

---

### Phase 3: Settings & Auto-Switch
**Goal:** Provide user-facing theme selection UI and automatic sunrise/sunset theme switching

**Depends on:** Phase 2

**Requirements:** THME-09, THME-10, THME-11, THME-12, THME-13, THME-14, THME-21, THME-22

**Success Criteria (what must be TRUE):**
1. Settings page shows theme selector with 4 theme options
2. User can select any theme and see immediate change (no app restart)
3. User can enable auto theme switch based on sunrise/sunset
4. App requests location permission for auto-switch (if not granted)
5. Status bar brightness syncs with theme (light theme = dark status bar, dark theme = light status bar)

**Plans:** TBD

---

## Coverage

| Phase | Requirements | Coverage |
|-------|--------------|----------|
| 1 - Theme Infrastructure | THME-01 to THME-08 | 8/22 |
| 2 - Widget Migration | THME-15 to THME-20 | 6/22 |
| 3 - Settings & Auto-Switch | THME-09 to THME-14, THME-21, THME-22 | 8/22 |

**Total:** 22/22 requirements mapped ✓

---

## Progress Table

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Theme Infrastructure | 0/1 | Not started | - |
| 2. Widget Migration | 0/1 | Not started | - |
| 3. Settings & Auto-Switch | 0/1 | Not started | - |

---

## Notes

- Phase 1 builds foundation - all other phases depend on ThemeProvider working correctly
- Phase 2 is the bulk of work - 40+ widget files need systematic refactoring
- Phase 3 combines user-facing features - settings UI and auto-switch are independent but can share planning
- Auto-switch requires location permission - graceful fallback if denied

---

*Last updated: 2026-03-14*
