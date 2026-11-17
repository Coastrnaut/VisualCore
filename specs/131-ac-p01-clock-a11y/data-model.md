# Data model: A18-P01 (feature 131)

## VisualCore (`VisualCoreExperience`)

- `protocol ClockSource: Sendable { var now: Date { get } }`
- `SystemClock: ClockSource`: `now` is `Date()`, with no offset and no stored state.
- `FixedClock: ClockSource`: `now` is the injected instant; `advance(by:)` and `set(_:)` exist for tests.
- `enum TimeChangeKind: String, CaseIterable, Sendable`: foreground, significantTime, timeZone, locale, calendarDay.
- `final class TimeChangeMonitor`:
  - `init(center: NotificationCenter = .default, names: [Notification.Name: TimeChangeKind] = foundationNames,
    handler: @escaping @Sendable (TimeChangeKind) -> Void)`;
  - `start()` and `stop()`, with the read-only `isRunning`;
  - one handler call per posted notification;
  - `static let foundationNames` holds `.NSSystemTimeZoneDidChange` (timeZone),
    `NSLocale.currentLocaleDidChangeNotification` (locale) and `.NSCalendarDayChanged` (calendarDay).
- `VisualCoreExperienceHost`: `TimeChangeMonitor.applicationNames` holds `foundationNames` plus
  `UIApplication.significantTimeChangeNotification` (significantTime) and
  `UIApplication.willEnterForegroundNotification` (foreground).

## AmbientClockCore

- `ClockPreferences` (Codable, Equatable):
  - `hourCycle: HourCycle` ∈ {system, h12, h24} (default system);
  - `showSeconds: Bool` (default false) and `showDate: Bool` (default true);
  - `timeZone: ZonePolicy` and `locale: LocalePolicy`, each `.system` or `.fixed(String)`.
- Preferences file: an envelope of kind `a18.clock-preferences`, `schemaVersion` 1, holding the preferences.
  - Refusals (`PreferencesRefusal`): `damaged`, `newer-version`, `unknown-time-zone` (`TimeZone(identifier:)` is nil;
    the system's known list omits current names such as `Asia/Kolkata`), `unknown-locale` (not in `Locale.availableIdentifiers`) and `too-large`
    (above 4,096 bytes).
  - Each refusal has a sentence naming the value. A refusal leaves the defaults.
- `ClockEnvironment`: the resolved `Locale`, `TimeZone` and `Calendar`. Fixed policies win; otherwise the system's
  current values, captured when the environment is built.
- `ClockDisplay`: `time`, `date` (empty when the date line is off) and `spoken`.
- `ClockFormatter.display(at: Date, preferences:, environment:) -> ClockDisplay`, plus `usesTwelveHourClock(locale:)`.
- `ClockSchedule.nextDeadline(after: Date, showSeconds: Bool, calendar: Calendar) -> Date`, strictly later and on a
  boundary.
- `AmbientClockState`:
  - fields `now: Date?`, `preferences`, `display: ClockDisplay?`, `nextDeadline: Date?`, `recomputations: Int` and
    `planner: AnnouncementPlanner`;
  - actions:
    - `time.set(Date)` formats the instant and reschedules;
    - `time.changed(TimeChangeKind, systemLocale:, systemTimeZone:)` carries the device's locale and zone at the
      time of the event, rebuilds the environment, reformats the current instant and adds one
      recomputation;
    - `prefs.set(ClockPreferences)` reformats;
    - `time.speak(at: Double)` asks the planner and returns the posted announcement, if any.
  - `flushAnnouncement(at:)` posts the announcement the planner held back, once its interval has passed.
  - Equal actions give equal states.
