# Contract: clock source and clock core (A18-P01)

- **Source:** the only reader of the wall clock in production is `SystemClock.now`. Tests construct `FixedClock`.
  Nothing adds an offset.
- **Monitor:**
  - after `start()`, each notification named in `names` calls the handler exactly once with its kind; after `stop()`,
    none does;
  - an unnamed notification is ignored;
  - `start()` twice observes once.
- **Formatter:**
  - for each fixture (locale, zone, instant, preferences), `time` and `date` equal the expected text after mapping
    U+202F and U+00A0 to a space;
  - `ar_EG` digits are U+0660–U+0669;
  - "system" follows the locale (en_US 12-hour, de_DE 24-hour); h12 and h24 override it.
- **Spoken:** `spoken` contains the time text (with the period for 12-hour) and, when the date line is on, the date
  text.
- **Schedule:** the deadline is strictly greater than the instant. With seconds on, its second fraction is zero; with
  seconds off, its seconds are zero, in the clock's zone, including across both 2026 New York transitions.
- **DST:**
  - formatting each minute from 06:58 to 07:01 UTC on 2026-03-08 in New York never shows 02:xx;
  - from 05:58 to 07:00 UTC on 2026-11-01, 01:59 is shown twice, about an hour apart (at 05:59 and 06:59 UTC).
- **State:**
  - `time.changed` adds exactly one recomputation for each of the five kinds;
  - a burst of `time.speak` within 0.5 s posts at most one announcement, and the last is kept as pending;
  - no action other than `time.speak` produces an announcement.
