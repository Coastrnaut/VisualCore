# Research: A18-P01 (feature 131)

- **D1 VisualCore placement (clarification Q1):** the clock source and the monitor go into `VisualCoreExperience`,
  which is Foundation-only and host-tested. The two UIKit names are added in `VisualCoreExperienceHost`.
  - Rationale: there are two consumers (A14's "Now" and A18), and the core contract forbids clocks inside a core.
  - Alternative: app-local only. Rejected, because a copy per experience would drift.
- **D2 Formatting:** `DateFormatter.setLocalizedDateFormatFromTemplate`.
  - The template is `jmm` (system), `hmm a` (h12) or `HHmm` (h24), plus `ss` when seconds are shown. The date uses
    `dateStyle .full`.
  - The system hour cycle is detected with `DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale:)`: it
    contains `a` for a 12-hour locale.
  - Formatters are cached per (locale, zone, template).
  - Alternative: `Date.FormatStyle`. Not used, because templates make the hour cycle explicit across iOS 26 and 27.
- **D3 Schedule:** the next deadline is the next whole second (seconds on) or the next whole minute (seconds off),
  computed by arithmetic at the zone offset of the instant (`TimeZone.secondsFromGMT(for:)`): exact because every
  current offset is a whole number of minutes. Deadlines are always strictly later than the instant.
  `Calendar.nextDate` was the first idea and is not used.
- **D4 DST fixtures:** `America/New_York` in 2026:
  - spring forward on 2026-03-08: 01:59 → 03:00 (07:00 UTC);
  - fall back on 2026-11-01: 01:00–01:59 shown twice, the second time from 06:00 UTC.
  - `Asia/Kolkata` covers a half-hour offset.
- **D5 Comparison of text:** fixtures map U+202F and U+00A0 to a plain space before comparing, because operating
  system versions differ there. Digits and order stay exact.
- **D6 Announcements:** no automatic minute announcement; `time.speak` goes through `AnnouncementPlanner` at 0.5 s.
  The canvas label carries the spoken string (A18-P02).
- **D7 Reference regression:** at X-A18 (owner ruling of 2026-11-14), as for A17-P03.
- **D8 Rows that wait for the experience:** closing G-CLOCK, G-FORMAT and G-TIMEA11Y would make M06, M11, M12, M13 and
  M16 available, but the presenter that reads the source, sends `time.set` at each deadline and `time.changed` from
  the monitor, and the canvas label at every Dynamic Type size, come in A18-P02. These rows therefore also name
  G-OVERLAY, and none becomes available before the experience exists.
- **D9 The module's clock files:** the purity test of `VisualCoreExperience` (FR-U01-036, `scripts/test_scripts.py`)
  forbids `Date(`, `NotificationCenter` and `Locale`. It now names `ClockSource.swift` and `TimeChangeMonitor.swift`
  as the module's clock files, as UA-F05 named the storage files, and lets both import Synchronization. Every other
  file keeps the rule.
